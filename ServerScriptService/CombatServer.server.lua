-- Tipo: Script
-- Ubicación: ServerScriptService/CombatServer
-- Contexto: Servidor

--[[
    Servidor de combate match-3 por swap.
    El cliente solo propone un intercambio entre dos celdas adyacentes.
    El servidor valida el swap, resuelve matches, cascadas, gravedad y relleno.

    SEGURIDAD:
    - El cliente nunca decide el estado final del tablero.
    - El grid canónico vive solo en servidor.
    - Cada swap se revalida completamente en servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatGrid = require(Modules:WaitForChild("CombatGrid.module"))

local CombatFolder = ServerScriptService:WaitForChild("Combat")
local TeamManager = require(CombatFolder:WaitForChild("TeamManager"))
local MonsterCombat = require(CombatFolder:WaitForChild("MonsterCombat"))
local PetCubeService = require(CombatFolder:WaitForChild("PetCubeService"))
local PvpStarsService = require(CombatFolder:WaitForChild("PvpStarsService"))

local FragmentsDataModule = GameData:FindFirstChild("FragmentsData")
local FragmentsData = FragmentsDataModule and require(FragmentsDataModule) or {
    normalizeRarityKey = function(rarity)
        local lowered = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "") or "common"
        return lowered == "" and "common" or lowered
    end,
    getCaptureChance = function(rarity)
        local chances = { common = 0.60, rare = 0.40, epic = 0.05 }
        local key = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "common") or "common"
        return chances[key] or 0
    end,
    getFragmentDrop = function(rarity)
        local drops = { common = 5, rare = 15, epic = 25 }
        local key = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "common") or "common"
        return drops[key] or 0
    end,
    getFragmentCraftCost = function(rarity)
        local costs = { common = 30, rare = 80, epic = 150 }
        local key = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "common") or "common"
        return costs[key] or 999
    end,
}

local SpawnMatrixModule = GameData:FindFirstChild("SpawnMatrix")
local SpawnMatrix = SpawnMatrixModule and require(SpawnMatrixModule) or {}

local BackpackDataStoreModule = ServerScriptService:FindFirstChild("BackpackDataStore")
local BackpackDataStore = BackpackDataStoreModule and require(BackpackDataStoreModule) or {
    loadPlayerData = function(_player)
        return { unlockedMonsters = {}, fragments = {} }
    end,
    savePlayerData = function(_player, _unlockedMonsters, _fragments)
    end,
}

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatSubmit = RemoteEvents:WaitForChild("CombatSubmit")
local CombatSync = RemoteEvents:WaitForChild("CombatSync")
local CombatChallengeRequest = RemoteEvents:WaitForChild("CombatChallengeRequest")
local CombatChallengeResponse = RemoteEvents:WaitForChild("CombatChallengeResponse")
local CombatDuelState = RemoteEvents:WaitForChild("CombatDuelState")
local CombatRosterAction = RemoteEvents:WaitForChild("CombatRosterAction")
local CombatProjectileVfx = RemoteEvents:WaitForChild("CombatProjectileVfx")

local COLS, ROWS = CombatGrid.getSize()
local DAMAGE_PER_CELL = 10
local COMBAT_DEBUG = true
local CHALLENGE_DISTANCE = 10
local CHALLENGE_TIMEOUT = 15
local COUNTDOWN_SECONDS = 3
local COMBO_SCALE_OUT_TIME = 0.12
local COMBO_STAGGER_TIME = 0.06
local FALL_TWEEN_TIME = 0.24
local BOUNCE_DURATION = 0.12
local CASCADE_GAP_TIME = 0.08
local MONSTER_AI_SPECIAL_CHANCE = 0.25
local MONSTER_AI_SPECIAL_COOLDOWN_TURNS = 3
local MONSTER_AI_HIGH_COMBO_THRESHOLD = 7
local MONSTER_AI_PLAYER_LOW_HP_RATIO = 0.3
local MONSTER_AI_MONSTER_PRESSURE_HP_RATIO = 0.35

local playerStates = {}
local characterConnections = {}
local pendingChallenges = {}
local activeDuels = {}
local activeMonsterDuels = {}
local duelSequence = 0

local ELEMENTS_LIST = { "Fuego", "Agua", "Planta", "Electricidad", "Roca" }
local MONSTER_CHALLENGE_DISTANCE = 15
local MONSTER_AI_ATTACK_INTERVAL = 4
local MONSTER_TEAM_SIZE = 1
local MONSTER_UNIT_ATTACK_MULTIPLIER = 2.5
local MONSTER_UNIT_HP_MULTIPLIER = 3.5
local DUEL_PLAYER_DISTANCE = 40
local MONSTER_DUEL_PLAYER_DISTANCE = 34
local DUEL_SIDE_SHIFT = 8
local MONSTER_DUEL_SIDE_SHIFT = 8
local WORLD_LEFT_COMBAT_SHIFT_STUDS = 10
local GROUND_ALIGN_RAYCAST_HEIGHT = 40
local GROUND_ALIGN_RAYCAST_DEPTH = 220
local DEFAULT_HRP_GROUND_OFFSET = 3
local BITS_ATTRIBUTE_NAME = "Bits"
local ENERGY_ATTRIBUTE_NAME = "CaptureEnergy"
local ENERGY_MAX_ATTRIBUTE_NAME = "CaptureEnergyMax"
local PET_CUBES_WORLD_FOLDER = "PlayerPetCubes"
local VFX_PROJECTILE_SIZE = Vector3.new(1, 1, 1)
local VFX_PROJECTILE_TRAVEL_TIME = 0.35
local VFX_SEQUENCE_STEP_TIME = 0.65
local VFX_AFTER_UI_HIDE_DELAY = 1.1
local dbg

local ELEMENT_PROJECTILE_COLORS = {
    Fuego = Color3.fromRGB(255, 120, 40),
    Agua = Color3.fromRGB(70, 170, 255),
    Planta = Color3.fromRGB(90, 220, 110),
    Electricidad = Color3.fromRGB(255, 235, 80),
    Roca = Color3.fromRGB(170, 145, 110),
}

local MONSTER_PVE_ECONOMY_BY_RARITY = {
    common = { energyCost = 5, bitsReward = 50 },
    rare = { energyCost = 10, bitsReward = 120 },
    epic = { energyCost = 16, bitsReward = 260 },
    legendary = { energyCost = 24, bitsReward = 500 },
}

local PITY_BONUS_PER_FAIL = 0.05
local MINERAL_DROP_CHANCE = 0.20

local ELEMENT_TO_MINERAL = {
    Fuego = "Magma Core",
    Agua = "Aqua Shard",
    Planta = "Root Crystal",
    Electricidad = "Volt Core",
    Roca = "Stone Heart",
}

local function getPlayerPetCubePart(player, slot)
    -- Propósito: Obtener part visual del Beastibit por slot del jugador en duelo.
    -- Precondiciones:
    --   1. player debe ser Player válido.
    --   2. slot debe ser number.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: BasePart|nil
    local worldFolder = workspace:FindFirstChild(PET_CUBES_WORLD_FOLDER)
    if not worldFolder then
        return nil
    end

    local playerFolder = worldFolder:FindFirstChild(player.Name)
    if not playerFolder then
        return nil
    end

    local slotIndex = math.floor(tonumber(slot) or 0)
    local cube = playerFolder:FindFirstChild("PetCube_" .. tostring(slotIndex))
    if not cube and slotIndex >= 0 then
        cube = playerFolder:FindFirstChild("PetCube_" .. tostring(slotIndex + 1))
    end
    if not cube then
        for _, child in ipairs(playerFolder:GetChildren()) do
            if string.sub(child.Name, 1, 8) == "PetCube_" then
                cube = child
                break
            end
        end
    end
    if cube and cube:IsA("BasePart") then
        return cube
    end

    if cube and cube:IsA("Model") then
        local rootPart = cube.PrimaryPart
        if not rootPart or not rootPart:IsA("BasePart") then
            local preferredRoot = cube:FindFirstChild("HumanoidRootPart", true)
            if preferredRoot and preferredRoot:IsA("BasePart") then
                rootPart = preferredRoot
            else
                rootPart = cube:FindFirstChildWhichIsA("BasePart", true)
            end
        end

        if rootPart and rootPart:IsA("BasePart") then
            return rootPart
        end
    end

    return nil
end

local function getProjectileColorForElement(element)
    -- Propósito: Resolver color del proyectil según elemento del Beastibit.
    -- Precondiciones:
    --   1. element puede ser string o nil.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Color3
    if type(element) == "string" and ELEMENT_PROJECTILE_COLORS[element] then
        return ELEMENT_PROJECTILE_COLORS[element]
    end
    return Color3.fromRGB(255, 255, 255)
end

local function getPvpTargetPosition(opponent)
    -- Propósito: Obtener posición destino en PvP para impactar Beastibit objetivo.
    -- Precondiciones:
    --   1. opponent debe ser Player válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Vector3|nil
    local targetCube = getPlayerPetCubePart(opponent, 1)
    if targetCube then
        return targetCube.Position
    end

    if not opponent or not opponent.Character then
        return nil
    end
    local hrp = opponent.Character:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position
    end
    return nil
end

local function getPlayerTargetPosition(player)
    -- Propósito: Obtener posición destino sobre el jugador para impactos visuales.
    -- Precondiciones:
    --   1. player debe ser Player válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Vector3|nil
    local targetCube = getPlayerPetCubePart(player, 1)
    if targetCube then
        return targetCube.Position
    end

    if not player or not player.Character then
        return nil
    end

    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position
    end

    return nil
end

local function getPlayerIntAttribute(player, attributeName, fallback)
    -- Propósito: Leer un atributo numérico del jugador y normalizarlo a entero seguro.
    -- Precondiciones:
    --   1. player debe ser Player válido.
    --   2. attributeName debe ser string.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number
    local numeric = tonumber(player:GetAttribute(attributeName))
    if not numeric then
        return fallback
    end
    return math.floor(numeric)
end

local function normalizeMonsterRarity(rarity)
    -- Propósito: Normalizar rareza para lookup robusto de tabla económica PvE.
    -- Precondiciones:
    --   1. rarity puede ser string o nil.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: string
    if type(rarity) ~= "string" then
        return "common"
    end

    local lowered = string.lower(string.match(rarity, "^%s*(.-)%s*$") or "")
    if lowered == "" then
        return "common"
    end

    if MONSTER_PVE_ECONOMY_BY_RARITY[lowered] then
        return lowered
    end

    return "common"
end

local function getMonsterPveEconomyConfig(monsterId)
    -- Propósito: Resolver costo de energía y recompensa de Bits según rareza del Beastibit salvaje.
    -- Precondiciones:
    --   1. monsterId debe ser string válido presente en MonstersData.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table, string
    local monsterData = MonstersData[monsterId]
    local rarityKey = normalizeMonsterRarity(type(monsterData) == "table" and monsterData.Rarity or nil)
    local config = MONSTER_PVE_ECONOMY_BY_RARITY[rarityKey] or MONSTER_PVE_ECONOMY_BY_RARITY.common

    return {
        energyCost = math.max(0, math.floor(tonumber(config.energyCost) or 0)),
        bitsReward = math.max(0, math.floor(tonumber(config.bitsReward) or 0)),
    }, rarityKey
end

local function consumePlayerEnergyForMonsterDuel(player, energyCost)
    -- Propósito: Descontar energía del jugador para iniciar un duelo PvE de forma segura.
    -- Precondiciones:
    --   1. player debe ser Player válido.
    --   2. energyCost debe ser number >= 0.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: boolean, number, number
    local maxEnergy = math.max(1, getPlayerIntAttribute(player, ENERGY_MAX_ATTRIBUTE_NAME, 100))
    local currentEnergy = math.clamp(getPlayerIntAttribute(player, ENERGY_ATTRIBUTE_NAME, maxEnergy), 0, maxEnergy)
    local safeCost = math.max(0, math.floor(tonumber(energyCost) or 0))

    if currentEnergy < safeCost then
        return false, currentEnergy, safeCost
    end

    local nextEnergy = currentEnergy - safeCost
    player:SetAttribute(ENERGY_ATTRIBUTE_NAME, nextEnergy)
    return true, nextEnergy, safeCost
end

local function awardPlayerBits(player, bitsDelta)
    -- Propósito: Sumar Bits al jugador al finalizar recompensas de PvE.
    -- Precondiciones:
    --   1. player debe ser Player válido.
    --   2. bitsDelta debe ser number.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number, number
    local safeDelta = math.max(0, math.floor(tonumber(bitsDelta) or 0))
    local currentBits = math.max(0, getPlayerIntAttribute(player, BITS_ATTRIBUTE_NAME, 0))
    local nextBits = currentBits + safeDelta
    player:SetAttribute(BITS_ATTRIBUTE_NAME, nextBits)
    return safeDelta, nextBits
end

local function spawnProjectileVfx(startPos, targetPos, element)
    -- Propósito: Solicitar a clientes la reproducción local del proyectil para mayor suavidad.
    -- Precondiciones:
    --   1. startPos y targetPos deben ser Vector3.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if typeof(startPos) ~= "Vector3" or typeof(targetPos) ~= "Vector3" then
        return
    end 

    CombatProjectileVfx:FireAllClients({
        startPos = startPos,
        targetPos = targetPos,
        element = element,
        size = VFX_PROJECTILE_SIZE,
        travelTime = VFX_PROJECTILE_TRAVEL_TIME,
        color = getProjectileColorForElement(element),
    })
end

local function playPlayerAttackVfxSequence(attacker, damageByPet, targetPositionResolver)
    -- Propósito: Ejecutar secuencia de proyectiles por Beastibit atacante con daño > 0.
    -- Precondiciones:
    --   1. attacker debe ser Player válido.
    --   2. damageByPet debe ser tabla.
    --   3. targetPositionResolver debe ser función sin args que retorna Vector3|nil.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not attacker or type(damageByPet) ~= "table" or type(targetPositionResolver) ~= "function" then
        return
    end

    task.spawn(function()
        local emittedCount = 0

        for _, petDamage in ipairs(damageByPet) do
            if type(petDamage) ~= "table" then
                continue
            end

            local dealt = tonumber(petDamage.damage) or 0
            if dealt <= 0 then
                continue
            end

            local slot = tonumber(petDamage.slot) or 1
            local sourceCube = getPlayerPetCubePart(attacker, slot)
            local targetPos = targetPositionResolver()

            if sourceCube and targetPos then
                spawnProjectileVfx(sourceCube.Position, targetPos, petDamage.element)
                emittedCount += 1
            else
                dbg(
                    "VFX omitido: source="
                    .. tostring(sourceCube ~= nil)
                    .. " target="
                    .. tostring(targetPos ~= nil)
                    .. " slot="
                    .. tostring(slot)
                )
            end

            task.wait(VFX_SEQUENCE_STEP_TIME)
        end

        if emittedCount == 0 then
            dbg("VFX secuencia sin emisiones para " .. attacker.Name)
        end
    end)
end

local function chooseWeightedElement(weights)
    -- Propósito: Elegir un elemento usando pesos acumulados para IA de monstruo.
    -- Precondiciones:
    --   1. weights debe ser tabla element->peso.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: string
    local totalWeight = 0
    for _, element in ipairs(ELEMENTS_LIST) do
        totalWeight += math.max(0, tonumber(weights[element]) or 0)
    end

    if totalWeight <= 0 then
        return ELEMENTS_LIST[math.random(1, #ELEMENTS_LIST)]
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, element in ipairs(ELEMENTS_LIST) do
        cumulative += math.max(0, tonumber(weights[element]) or 0)
        if roll <= cumulative then
            return element
        end
    end

    return ELEMENTS_LIST[#ELEMENTS_LIST]
end

local function buildMonsterElementWeights(monsterId)
    -- Propósito: Construir sesgo elemental de IA según elemento/rareza del monstruo.
    -- Precondiciones:
    --   1. monsterId debe ser string válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table
    local weights = {}
    for _, element in ipairs(ELEMENTS_LIST) do
        weights[element] = 1
    end

    local monsterData = MonstersData[monsterId]
    if not monsterData then
        return weights
    end

    local preferredElement = monsterData.Element
    if type(preferredElement) == "string" and weights[preferredElement] then
        local preferredWeight = 3
        if monsterData.Rarity == "Rare" then
            preferredWeight = 4
        end
        weights[preferredElement] = preferredWeight
    end

    return weights
end

local function chooseMonsterComboCount(duel)
    -- Propósito: Elegir cantidad de combos IA por fase de HP, especial y anti-rachas.
    -- Precondiciones:
    --   1. duel debe ser duelo NPC con aiState inicializado.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number comboCount, boolean usedSpecial
    local aiState = duel.aiState
    local playerHpRatio = 1
    local monsterHpRatio = 1

    if type(duel.playerMaxHP) == "number" and duel.playerMaxHP > 0 then
        playerHpRatio = math.clamp(duel.playerHP / duel.playerMaxHP, 0, 1)
    end
    if type(duel.monsterMaxHP) == "number" and duel.monsterMaxHP > 0 then
        monsterHpRatio = math.clamp(duel.monsterHP / duel.monsterMaxHP, 0, 1)
    end

    local minCombo = 2
    local maxCombo = 5
    if monsterHpRatio <= MONSTER_AI_MONSTER_PRESSURE_HP_RATIO then
        minCombo = 4
        maxCombo = 7
    end
    if playerHpRatio <= MONSTER_AI_PLAYER_LOW_HP_RATIO then
        minCombo = 2
        maxCombo = 4
    end

    local useSpecial = false
    if aiState.specialCooldown <= 0 and playerHpRatio > MONSTER_AI_PLAYER_LOW_HP_RATIO then
        if math.random() < MONSTER_AI_SPECIAL_CHANCE then
            minCombo = 7
            maxCombo = 9
            useSpecial = true
        end
    end

    if aiState.highComboStreak >= 2 then
        minCombo = 2
        maxCombo = 5
        useSpecial = false
    end

    local comboCount = math.random(minCombo, maxCombo)
    if playerHpRatio <= MONSTER_AI_PLAYER_LOW_HP_RATIO then
        comboCount = math.min(comboCount, 5)
    end

    if useSpecial then
        aiState.specialCooldown = MONSTER_AI_SPECIAL_COOLDOWN_TURNS
    elseif aiState.specialCooldown > 0 then
        aiState.specialCooldown -= 1
    end

    if comboCount >= MONSTER_AI_HIGH_COMBO_THRESHOLD then
        aiState.highComboStreak += 1
    else
        aiState.highComboStreak = 0
    end

    return comboCount, useSpecial
end

local function buildMonsterAiAttack(duel)
    -- Propósito: Generar ataque de IA con sesgo elemental y control de dificultad.
    -- Precondiciones:
    --   1. duel debe tener aiState y elementWeights.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: string element, number comboCount, boolean usedSpecial
    local aiState = duel.aiState
    aiState.turnIndex += 1

    local element = chooseWeightedElement(aiState.elementWeights)
    if aiState.lastElement == element and math.random() < 0.25 then
        local guardCounter = 0
        while element == aiState.lastElement and guardCounter < 4 do
            element = chooseWeightedElement(aiState.elementWeights)
            guardCounter += 1
        end
    end

    local comboCount, usedSpecial = chooseMonsterComboCount(duel)
    aiState.lastElement = element
    aiState.lastComboCount = comboCount

    return element, comboCount, usedSpecial
end

local function calculateWildMonsterUnitDamage(monsterId, comboCount, chosenElement)
    -- Propósito: Calcular daño de Beastibit salvaje como unidad única con multiplicador PvE.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. comboCount debe ser number >= 0.
    --   3. chosenElement debe ser string.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number damage, boolean elementMatched, string monsterElement
    local monsterData = MonstersData[monsterId]
    local monsterElement = type(monsterData) == "table" and tostring(monsterData.Element or "Desconocido") or "Desconocido"
    local elementMatched = (type(chosenElement) == "string" and chosenElement == monsterElement)
    if not elementMatched then
        return 0, false, monsterElement
    end

    local baseAttack = 0
    if type(monsterData) == "table"
        and type(monsterData.BaseStats) == "table"
        and type(monsterData.BaseStats.Attack) == "number" then
        baseAttack = monsterData.BaseStats.Attack
    end

    local combos = math.max(0, math.floor(tonumber(comboCount) or 0))
    local damage = math.floor(baseAttack * combos * MONSTER_UNIT_ATTACK_MULTIPLIER)
    return math.max(0, damage), true, monsterElement
end

local function calculateWildMonsterMaxHP(monsterId)
    -- Propósito: Calcular vida máxima del Beastibit salvaje con multiplicador PvE.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number
    local monsterData = MonstersData[monsterId]
    if type(monsterData) ~= "table" or type(monsterData.BaseStats) ~= "table" then
        return 0
    end

    local baseHP = tonumber(monsterData.BaseStats.HP) or 0
    return math.max(0, math.floor(baseHP * MONSTER_UNIT_HP_MULTIPLIER))
end

dbg = function(message)
    -- Propósito: Emitir logs de depuración del servidor de combate.
    -- Precondiciones:
    --   1. message debe ser string.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not COMBAT_DEBUG then
        return
    end
    warn("[CombatServer] " .. tostring(message))
end

local function sendDuelState(player, data)
    -- Propósito: Enviar una actualización de estado de duelo a un cliente.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. data debe ser tabla serializable.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not player then
        return
    end
    CombatDuelState:FireClient(player, data)
end

local function getRootPosition(player)
    -- Propósito: Obtener posición del HumanoidRootPart de un jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Vector3|nil
    if not player.Character then
        return nil
    end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        return nil
    end
    return hrp.Position
end

local function getPlayersDistance(playerA, playerB)
    -- Propósito: Calcular distancia entre dos jugadores para validar desafío.
    -- Precondiciones:
    --   1. playerA y playerB deben ser válidos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number|nil
    local posA = getRootPosition(playerA)
    local posB = getRootPosition(playerB)
    if not posA or not posB then
        return nil
    end
    return (posA - posB).Magnitude
end

local function getGroundYAt(position, ignoreInstances)
    -- Propósito: Obtener altura de suelo en una posición usando raycast vertical.
    -- Precondiciones:
    --   1. position debe ser Vector3.
    --   2. ignoreInstances puede ser tabla de Instancias.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number|nil
    if typeof(position) ~= "Vector3" then
        return nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local filteredIgnore = {}
    if type(ignoreInstances) == "table" then
        for _, inst in ipairs(ignoreInstances) do
            if typeof(inst) == "Instance" then
                table.insert(filteredIgnore, inst)
            end
        end
    end
    params.FilterDescendantsInstances = filteredIgnore

    local origin = Vector3.new(position.X, position.Y + GROUND_ALIGN_RAYCAST_HEIGHT, position.Z)
    local result = workspace:Raycast(origin, Vector3.new(0, -GROUND_ALIGN_RAYCAST_DEPTH, 0), params)
    if not result then
        return nil
    end
    return result.Position.Y
end

local function alignTargetToGround(hrp, targetPos, ignoreInstances)
    -- Propósito: Ajustar Y de una posición objetivo para evitar hundir al jugador en el terreno.
    -- Precondiciones:
    --   1. hrp debe ser BasePart válida.
    --   2. targetPos debe ser Vector3.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Vector3
    if not hrp or not hrp:IsA("BasePart") or typeof(targetPos) ~= "Vector3" then
        return targetPos
    end

    local currentGroundY = getGroundYAt(hrp.Position, ignoreInstances)
    local targetGroundY = getGroundYAt(targetPos, ignoreInstances)
    if not targetGroundY then
        return Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)
    end

    local groundOffset = DEFAULT_HRP_GROUND_OFFSET
    if type(currentGroundY) == "number" then
        groundOffset = math.max(1.5, hrp.Position.Y - currentGroundY)
    end

    return Vector3.new(targetPos.X, targetGroundY + groundOffset, targetPos.Z)
end

local function getDuelOpponent(player)
    -- Propósito: Obtener oponente del duelo activo de un jugador.
    -- Precondiciones:
    --   1. player puede o no estar en duelo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Player|nil, table|nil
    local duel = activeDuels[player]
    if not duel then
        return nil, nil
    end

    if duel.playerA == player then
        return duel.playerB, duel
    end

    if duel.playerB == player then
        return duel.playerA, duel
    end

    return nil, nil
end

local function setupDuelParticipants(duel)
    -- Propósito: Posicionar ambos domadores anclados, enfrentados y en distancia fija para el duelo PvP.
    -- Precondiciones:
    --   1. duel debe tener playerA y playerB válidos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel or not duel.playerA or not duel.playerB then
        return
    end

    local charA = duel.playerA.Character
    local charB = duel.playerB.Character
    if not charA or not charB then
        return
    end

    local hrpA = charA:FindFirstChild("HumanoidRootPart")
    local hrpB = charB:FindFirstChild("HumanoidRootPart")
    local humA = charA:FindFirstChildOfClass("Humanoid")
    local humB = charB:FindFirstChildOfClass("Humanoid")
    if not hrpA or not hrpB or not hrpA:IsA("BasePart") or not hrpB:IsA("BasePart") then
        return
    end

    duel.anchorStateByUserId = duel.anchorStateByUserId or {}
    duel.anchorStateByUserId[duel.playerA.UserId] = {
        wasAnchored = hrpA.Anchored,
        walkSpeed = humA and humA.WalkSpeed or nil,
        jumpPower = humA and humA.JumpPower or nil,
        autoRotate = humA and humA.AutoRotate or nil,
        platformStand = humA and humA.PlatformStand or nil,
    }
    duel.anchorStateByUserId[duel.playerB.UserId] = {
        wasAnchored = hrpB.Anchored,
        walkSpeed = humB and humB.WalkSpeed or nil,
        jumpPower = humB and humB.JumpPower or nil,
        autoRotate = humB and humB.AutoRotate or nil,
        platformStand = humB and humB.PlatformStand or nil,
    }

    local center = (hrpA.Position + hrpB.Position) * 0.5
    local dir = hrpB.Position - hrpA.Position
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 1e-4 then
        dir = Vector3.new(hrpA.CFrame.LookVector.X, 0, hrpA.CFrame.LookVector.Z)
    end
    if dir.Magnitude < 1e-4 then
        dir = Vector3.new(0, 0, -1)
    end
    local forward = dir.Unit
    local right = forward:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 1e-4 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end
    local sideShift = -right * DUEL_SIDE_SHIFT

    local worldLeftShift = Vector3.new(-WORLD_LEFT_COMBAT_SHIFT_STUDS, 0, 0)
    local posA = center - (forward * (DUEL_PLAYER_DISTANCE * 0.5))
    local posB = center + (forward * (DUEL_PLAYER_DISTANCE * 0.5))
    posA += sideShift
    posB += sideShift
    posA += worldLeftShift
    posB += worldLeftShift
    local pvpIgnore = { charA, charB }
    posA = alignTargetToGround(hrpA, posA, pvpIgnore)
    posB = alignTargetToGround(hrpB, posB, pvpIgnore)

    hrpA.Anchored = true
    hrpB.Anchored = true
    hrpA.AssemblyLinearVelocity = Vector3.zero
    hrpB.AssemblyLinearVelocity = Vector3.zero
    hrpA.AssemblyAngularVelocity = Vector3.zero
    hrpB.AssemblyAngularVelocity = Vector3.zero
    hrpA.CFrame = CFrame.lookAt(posA, posB, Vector3.new(0, 1, 0))
    hrpB.CFrame = CFrame.lookAt(posB, posA, Vector3.new(0, 1, 0))

    if humA then
        humA.AutoRotate = false
        humA.WalkSpeed = 0
        humA.JumpPower = 0
        humA.PlatformStand = true
    end

    if humB then
        humB.AutoRotate = false
        humB.WalkSpeed = 0
        humB.JumpPower = 0
        humB.PlatformStand = true
    end

    local stateA = playerStates[duel.playerA]
    local stateB = playerStates[duel.playerB]
    local teamA = stateA and stateA.team or TeamManager.getOrCreateTeam(duel.playerA)
    local teamB = stateB and stateB.team or TeamManager.getOrCreateTeam(duel.playerB)

    PetCubeService.spawnPlayerTeamDuelLine(duel.playerA, teamA, hrpB.Position)
    PetCubeService.spawnPlayerTeamDuelLine(duel.playerB, teamB, hrpA.Position)
end

local function restoreDuelParticipants(duel)
    -- Propósito: Restaurar movilidad y estado original de ambos domadores al terminar duelo PvP.
    -- Precondiciones:
    --   1. duel puede contener estados previos de anclaje.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel then
        return
    end

    local participants = { duel.playerA, duel.playerB }
    for _, participant in ipairs(participants) do
        if participant and participant.Character then
            local hrp = participant.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = participant.Character:FindFirstChildOfClass("Humanoid")
            local previousState = duel.anchorStateByUserId and duel.anchorStateByUserId[participant.UserId]

            if hrp and hrp:IsA("BasePart") then
                hrp.Anchored = previousState and previousState.wasAnchored or false
            end

            if humanoid and previousState then
                if type(previousState.walkSpeed) == "number" then
                    humanoid.WalkSpeed = previousState.walkSpeed
                end
                if type(previousState.jumpPower) == "number" then
                    humanoid.JumpPower = previousState.jumpPower
                end
                if type(previousState.autoRotate) == "boolean" then
                    humanoid.AutoRotate = previousState.autoRotate
                end
                if type(previousState.platformStand) == "boolean" then
                    humanoid.PlatformStand = previousState.platformStand
                else
                    humanoid.PlatformStand = false
                end
            end

            local participantState = playerStates[participant]
            local team = participantState and participantState.team or TeamManager.getOrCreateTeam(participant)
            PetCubeService.spawnPlayerTeamCubes(participant, team)
        end
    end
end

local function endDuel(duel, winner, reason)
    -- Propósito: Finalizar un duelo activo y notificar resultado a ambos jugadores.
    -- Precondiciones:
    --   1. duel debe ser tabla válida de duelo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel then
        return
    end

    local loser = nil
    if winner == duel.playerA then
        loser = duel.playerB
    elseif winner == duel.playerB then
        loser = duel.playerA
    end

    restoreDuelParticipants(duel)

    for _, participant in ipairs({ duel.playerA, duel.playerB }) do
        activeDuels[participant] = nil
        local state = playerStates[participant]
        if state then
            state.duelId = nil
            state.duelActive = false
            state.duelStarted = false
        end
    end

    if winner and loser and reason == "hp-depleted" then
        local winnerStars, loserStars, shieldUsed = PvpStarsService.applyPvpDuelResult(winner, loser)
        local loserTitle = PvpStarsService.getTitleForPlayer(loser)
        local loserShields = PvpStarsService.getShieldCharges(loser)
        local winnerTitle = PvpStarsService.getTitleForPlayer(winner)
        dbg(
            "duelo finalizado: "
            .. winner.Name
            .. " venció a "
            .. loser.Name
            .. " | estrellas => "
            .. winner.Name
            .. ":"
            .. tostring(winnerStars)
            .. " / "
            .. loser.Name
            .. ":"
            .. tostring(loserStars)
            .. (shieldUsed and " [SHIELD]" or "")
        )
        sendDuelState(winner, {
            type = "duel-ended",
            winnerUserId = winner.UserId,
            opponentUserId = loser.UserId,
            reason = "hp-depleted",
            newSelfStars = winnerStars,
            starsDelta = 1,
            selfTitle = winnerTitle,
        })
        sendDuelState(loser, {
            type = "duel-ended",
            winnerUserId = winner.UserId,
            opponentUserId = winner.UserId,
            reason = "hp-depleted",
            newSelfStars = loserStars,
            starsDelta = shieldUsed and 0 or -1,
            shieldUsed = shieldUsed,
            selfTitle = loserTitle,
            shieldCharges = loserShields,
        })
        return
    end

    sendDuelState(duel.playerA, {
        type = "duel-ended",
        winnerUserId = winner and winner.UserId or nil,
        opponentUserId = duel.playerB and duel.playerB.UserId or nil,
        reason = reason or "duel-ended",
        newSelfStars = nil,
        starsDelta = 0,
    })
    sendDuelState(duel.playerB, {
        type = "duel-ended",
        winnerUserId = winner and winner.UserId or nil,
        opponentUserId = duel.playerA and duel.playerA.UserId or nil,
        reason = reason or "duel-ended",
        newSelfStars = nil,
        starsDelta = 0,
    })

    if winner and loser then
        dbg("duelo finalizado: " .. winner.Name .. " venció a " .. loser.Name)
    end
end

local function startDuelCountdown(duel)
    -- Propósito: Ejecutar countdown 3-2-1 y habilitar combate al finalizar.
    -- Precondiciones:
    --   1. duel debe estar activo y con dos jugadores válidos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel then
        return
    end

    setupDuelParticipants(duel)

    sendDuelState(duel.playerA, {
        type = "duel-intro",
        opponentKind = "player",
        opponentName = duel.playerB.Name,
        opponentUserId = duel.playerB.UserId,
        selfHP = duel.hpByUserId[duel.playerA.UserId],
        enemyHP = duel.hpByUserId[duel.playerB.UserId],
        selfStars = PvpStarsService.getStars(duel.playerA),
        opponentStars = PvpStarsService.getStars(duel.playerB),
    })

    sendDuelState(duel.playerB, {
        type = "duel-intro",
        opponentKind = "player",
        opponentName = duel.playerA.Name,
        opponentUserId = duel.playerA.UserId,
        selfHP = duel.hpByUserId[duel.playerB.UserId],
        enemyHP = duel.hpByUserId[duel.playerA.UserId],
        selfStars = PvpStarsService.getStars(duel.playerB),
        opponentStars = PvpStarsService.getStars(duel.playerA),
    })

    for seconds = COUNTDOWN_SECONDS, 1, -1 do
        if activeDuels[duel.playerA] ~= duel or activeDuels[duel.playerB] ~= duel then
            return
        end

        sendDuelState(duel.playerA, {
            type = "countdown",
            value = seconds,
            opponentKind = "player",
            opponentName = duel.playerB.Name,
            opponentUserId = duel.playerB.UserId,
            selfHP = duel.hpByUserId[duel.playerA.UserId],
            enemyHP = duel.hpByUserId[duel.playerB.UserId],
            selfStars = PvpStarsService.getStars(duel.playerA),
            opponentStars = PvpStarsService.getStars(duel.playerB),
        })

        sendDuelState(duel.playerB, {
            type = "countdown",
            value = seconds,
            opponentKind = "player",
            opponentName = duel.playerA.Name,
            opponentUserId = duel.playerA.UserId,
            selfHP = duel.hpByUserId[duel.playerB.UserId],
            enemyHP = duel.hpByUserId[duel.playerA.UserId],
            selfStars = PvpStarsService.getStars(duel.playerB),
            opponentStars = PvpStarsService.getStars(duel.playerA),
        })

        task.wait(1)
    end

    duel.started = true
    local stateA = playerStates[duel.playerA]
    local stateB = playerStates[duel.playerB]
    if stateA then
        stateA.duelStarted = true
    end
    if stateB then
        stateB.duelStarted = true
    end

    sendDuelState(duel.playerA, {
        type = "duel-started",
        opponentKind = "player",
        opponentName = duel.playerB.Name,
        opponentUserId = duel.playerB.UserId,
        selfHP = duel.hpByUserId[duel.playerA.UserId],
        enemyHP = duel.hpByUserId[duel.playerB.UserId],
        selfStars = PvpStarsService.getStars(duel.playerA),
        opponentStars = PvpStarsService.getStars(duel.playerB),
    })

    sendDuelState(duel.playerB, {
        type = "duel-started",
        opponentKind = "player",
        opponentName = duel.playerA.Name,
        opponentUserId = duel.playerA.UserId,
        selfHP = duel.hpByUserId[duel.playerB.UserId],
        enemyHP = duel.hpByUserId[duel.playerA.UserId],
        selfStars = PvpStarsService.getStars(duel.playerB),
        opponentStars = PvpStarsService.getStars(duel.playerA),
    })
end

local function isValidSwapPayload(payload)
    -- Propósito: Validar forma básica del payload enviado por cliente.
    -- Precondiciones:
    --   1. payload debe ser tabla.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: boolean
    if type(payload) ~= "table" then
        return false
    end

    if type(payload.path) ~= "table" or #payload.path < 2 then
        return false
    end

    for _, cell in ipairs(payload.path) do
        if type(cell) ~= "table" then
            return false
        end

        local values = { cell.col, cell.row }
        for _, value in ipairs(values) do
            if type(value) ~= "number" or value ~= math.floor(value) then
                return false
            end
        end

        if cell.col < 1 or cell.col > COLS or cell.row < 1 or cell.row > ROWS then
            return false
        end
    end

    return true
end

local function createStableGrid()
    -- Propósito: Crear un tablero inicial sin matches ya presentes.
    -- Precondiciones:
    --   1. CombatGrid.newGrid y CombatGrid.findMatches deben existir.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table
    local attempts = 0
    while attempts < 20 do
        attempts += 1
        local grid = CombatGrid.newGrid()
        local matches = CombatGrid.findMatches(grid)
        if not matches.hasMatches then
            return grid
        end
    end

    return CombatGrid.newGrid()
end

local function appendComboSummary(summary, combos, grid)
    -- Propósito: Acumular total de combos y elementos activados del movimiento.
    -- Precondiciones:
    --   1. summary debe ser tabla válida.
    --   2. combos debe ser tabla o nil.
    --   3. grid debe ser tablero válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(combos) ~= "table" then
        return
    end

    for _, combo in ipairs(combos) do
        summary.totalCombos += 1
        if type(combo) == "table" and combo[1] then
            local anchor = combo[1]
            local tile = grid[anchor.col] and grid[anchor.col][anchor.row]
            if tile and type(tile.elementType) == "string" then
                summary.activatedElements[tile.elementType] = true
            end
        end
    end
end

local function getActivatedElementsList(activatedElements)
    -- Propósito: Convertir el set de elementos activados en lista serializable.
    -- Precondiciones:
    --   1. activatedElements debe ser tabla set.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table
    local list = {}
    for element, isActive in pairs(activatedElements) do
        if isActive then
            table.insert(list, element)
        end
    end
    table.sort(list)
    return list
end

local function syncPlayer(player, extraData)
    -- Propósito: Enviar el estado canónico actual del grid al cliente.
    -- Precondiciones:
    --   1. player debe tener estado activo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    if not state then
        return
    end

    local payload = {
        grid = state.grid,
    }

    if type(extraData) == "table" then
        for key, value in pairs(extraData) do
            payload[key] = value
        end
    end

    CombatSync:FireClient(player, payload)
end

local function estimateCascadeAnimationDuration(cascades)
    -- Propósito: Estimar duración cliente de animación de cascadas para sincronizar daño.
    -- Precondiciones:
    --   1. cascades debe ser lista o nil.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number
    if type(cascades) ~= "table" or #cascades == 0 then
        return 0
    end

    local totalTime = 0
    for _, cascade in ipairs(cascades) do
        local combos = type(cascade.combos) == "table" and cascade.combos or {}
        local comboCount = #combos
        totalTime += comboCount * (COMBO_SCALE_OUT_TIME + COMBO_STAGGER_TIME)

        local hasGravity = (type(cascade.movimientos) == "table" and #cascade.movimientos > 0)
            or (type(cascade.nuevas) == "table" and #cascade.nuevas > 0)
        if hasGravity then
            totalTime += FALL_TWEEN_TIME + BOUNCE_DURATION
        end

        totalTime += CASCADE_GAP_TIME
    end

    return totalTime
end

local function spawnPlayerPetCubes(player)
    -- Propósito: Spawnear cubos de equipo para el personaje actual del jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    local team = state and state.team or TeamManager.getOrCreateTeam(player)
    local selectedFollowerMonsterId = (state and state.followMonsterId)
        or TeamManager.getSelectedFollowerMonsterId(player)
    task.wait(0.1)
    PetCubeService.spawnPlayerTeamCubes(player, team, selectedFollowerMonsterId)
end

local function bindCharacterSpawn(player)
    -- Propósito: Conectar spawn de cubos al respawn y al personaje actual.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end

    characterConnections[player] = player.CharacterAdded:Connect(function()
        spawnPlayerPetCubes(player)
    end)

    if player.Character then
        spawnPlayerPetCubes(player)
    end
end

local function initPlayerState(player)
    -- Propósito: Inicializar el tablero y metadatos del jugador.
    -- Precondiciones:
    --   1. player debe ser válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local team = TeamManager.getOrCreateTeam(player)
    local backpack = TeamManager.getBackpack(player)
    local selectedFollowerMonsterId = TeamManager.getSelectedFollowerMonsterId(player)
    local isTeamValid, teamReason = TeamManager.validateTeam(team)

    playerStates[player] = {
        grid = createStableGrid(),
        lastSubmit = 0,
        team = team,
        backpack = backpack,
        followMonsterId = selectedFollowerMonsterId,
        teamValid = isTeamValid,
        teamReason = teamReason,
        duelId = nil,
        duelActive = false,
        duelStarted = false,
    }

    PetCubeService.spawnPlayerTeamCubes(player, team, selectedFollowerMonsterId)

    local teamHP = TeamManager.calculateTeamHP(team)

    dbg("estado inicial creado para " .. player.Name)
    syncPlayer(player, {
        reason = "initial-sync",
        teamValid = isTeamValid,
        teamReason = teamReason,
        duelTeam = team,
        backpack = backpack,
        selectedFollowerMonsterId = selectedFollowerMonsterId,
        playerTotalHP = teamHP,
        duelActive = false,
        duelStarted = false,
    })
end

-- ============================================================
-- SISTEMA DE DUELO CONTRA MONSTRUO NPC
-- ============================================================

local function buildMonsterNpcTeam(monsterId, size)
    -- Propósito: Construir un equipo NPC de (size) monstruos del mismo tipo.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. size debe ser number positivo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table
    if type(monsterId) ~= "string" or monsterId == "" then
        return {}
    end
    if MonstersData[monsterId] == nil then
        return {}
    end

    local safeSize = math.max(1, math.floor(tonumber(size) or 1))
    local team = {}
    for i = 1, safeSize do
        table.insert(team, { MonsterId = monsterId })
    end
    return team
end

local function resolveMonsterId(rawMonsterId)
    -- Propósito: Normalizar MonsterId de atributos/modelos para lookup robusto en MonstersData.
    -- Precondiciones:
    --   1. rawMonsterId puede ser string o nil.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: string|nil
    if type(rawMonsterId) ~= "string" then
        return nil
    end

    local trimmed = string.match(rawMonsterId, "^%s*(.-)%s*$")
    if trimmed == "" then
        return nil
    end

    if MonstersData[trimmed] ~= nil then
        return trimmed
    end

    local compact = string.gsub(trimmed, "%s+", "")
    if MonstersData[compact] ~= nil then
        return compact
    end

    local loweredTrimmed = string.lower(trimmed)
    local loweredCompact = string.lower(compact)
    for knownMonsterId in pairs(MonstersData) do
        local loweredKnown = string.lower(knownMonsterId)
        if loweredKnown == loweredTrimmed or loweredKnown == loweredCompact then
            return knownMonsterId
        end
    end

    return trimmed
end

local function endMonsterDuel(player, reason, winner)
    -- Propósito: Finalizar duelo contra NPC y notificar resultado al cliente.
    -- Precondiciones:
    --   1. player debe estar registrado en activeMonsterDuels.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local duel = activeMonsterDuels[player]
    if not duel then return end

    if duel.player then
        if duel.anchorStateByUserId and duel.anchorStateByUserId[duel.player.UserId] then
            local participant = duel.player
            local previousState = duel.anchorStateByUserId[participant.UserId]
            if participant.Character then
                local hrp = participant.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = participant.Character:FindFirstChildOfClass("Humanoid")

                if hrp and hrp:IsA("BasePart") then
                    hrp.Anchored = previousState.wasAnchored or false
                end

                if humanoid then
                    if type(previousState.walkSpeed) == "number" then
                        humanoid.WalkSpeed = previousState.walkSpeed
                    end
                    if type(previousState.jumpPower) == "number" then
                        humanoid.JumpPower = previousState.jumpPower
                    end
                    if type(previousState.autoRotate) == "boolean" then
                        humanoid.AutoRotate = previousState.autoRotate
                    end
                    if type(previousState.platformStand) == "boolean" then
                        humanoid.PlatformStand = previousState.platformStand
                    else
                        humanoid.PlatformStand = false
                    end
                end

                local participantState = playerStates[participant]
                local team = participantState and participantState.team or TeamManager.getOrCreateTeam(participant)
                PetCubeService.spawnPlayerTeamCubes(participant, team)
            end
        end
    end

    activeMonsterDuels[player] = nil

    local state = playerStates[player]
    if state then
        state.duelId = nil
        state.duelActive = false
        state.duelStarted = false
    end

    local winnerUserId = nil
    local bitsDelta = 0
    local newBitsTotal = math.max(0, getPlayerIntAttribute(player, BITS_ATTRIBUTE_NAME, 0))
    local captureResult = nil
    local fragmentsAwarded = 0
    local mineralAwarded = nil

    if winner == "player" then
        winnerUserId = player.UserId
        local rewardedBits, bitsTotal = awardPlayerBits(player, duel.bitsRewardOnWin)
        bitsDelta = rewardedBits
        newBitsTotal = bitsTotal

        local monsterData = MonstersData[duel.monsterId]
        if monsterData then
            local rarityKey = normalizeMonsterRarity(monsterData.Rarity)
            local baseChance = FragmentsData.getCaptureChance(rarityKey)

            local pityAttr = "CapturePity_" .. rarityKey
            local currentPity = getPlayerIntAttribute(player, pityAttr, 0)
            local pityBonus = currentPity * PITY_BONUS_PER_FAIL
            local finalChance = math.min(1.0, baseChance + pityBonus)

            if math.random() <= finalChance then
                local wasNew = TeamManager.unlockMonster(player, duel.monsterId)
                captureResult = {
                    captured = true,
                    monsterId = duel.monsterId,
                    wasNew = wasNew,
                }
                player:SetAttribute(pityAttr, 0)
            else
                local fragDrop = FragmentsData.getFragmentDrop(rarityKey)
                if fragDrop > 0 then
                    fragmentsAwarded = TeamManager.addFragments(player, duel.monsterId, fragDrop)
                end
                captureResult = {
                    captured = false,
                    monsterId = duel.monsterId,
                    fragmentsDropped = fragDrop,
                }
                player:SetAttribute(pityAttr, currentPity + 1)
            end

            if monsterData.Element and ELEMENT_TO_MINERAL[monsterData.Element] and math.random() <= MINERAL_DROP_CHANCE then
                local mineralName = ELEMENT_TO_MINERAL[monsterData.Element]
                local mineralAttr = "Mineral_" .. string.gsub(mineralName, "%s+", "")
                local currentMinerals = getPlayerIntAttribute(player, mineralAttr, 0)
                player:SetAttribute(mineralAttr, currentMinerals + 1)
                mineralAwarded = {
                    name = mineralName,
                    total = currentMinerals + 1,
                }
            end
        end
    end

    sendDuelState(player, {
        type = "duel-ended",
        winnerUserId = winnerUserId,
        reason = reason or "duel-ended",
        bitsDelta = bitsDelta,
        newBits = newBitsTotal,
        energyCost = duel.energyCostOnStart,
        monsterRarity = duel.monsterRarity,
        captureResult = captureResult,
        fragmentsAwarded = fragmentsAwarded,
        mineralAwarded = mineralAwarded,
    })

    dbg("duelo NPC finalizado: " .. player.Name .. " | razon=" .. tostring(reason) .. " | ganador=" .. tostring(winner))
end

local function setupMonsterDuelParticipant(duel)
    -- Propósito: Posicionar y anclar al jugador frente al monstruo para duelo NPC y formar Beastibit en línea.
    -- Precondiciones:
    --   1. duel debe tener player y monsterRoot válidos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel or not duel.player or not duel.monsterRoot then
        return
    end

    local player = duel.player
    local character = player.Character
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hrp:IsA("BasePart") then
        return
    end

    local monsterPos = duel.monsterRoot.Position
    local flatDir = Vector3.new(hrp.Position.X - monsterPos.X, 0, hrp.Position.Z - monsterPos.Z)
    if flatDir.Magnitude < 1e-4 then
        flatDir = Vector3.new(0, 0, -1)
    end
    local forward = flatDir.Unit

    local worldLeftShift = Vector3.new(-WORLD_LEFT_COMBAT_SHIFT_STUDS, 0, 0)
    local targetPos = monsterPos + (forward * MONSTER_DUEL_PLAYER_DISTANCE)
    targetPos = Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)

    duel.anchorStateByUserId = duel.anchorStateByUserId or {}
    duel.anchorStateByUserId[player.UserId] = {
        wasAnchored = hrp.Anchored,
        walkSpeed = humanoid and humanoid.WalkSpeed or nil,
        jumpPower = humanoid and humanoid.JumpPower or nil,
        autoRotate = humanoid and humanoid.AutoRotate or nil,
        platformStand = humanoid and humanoid.PlatformStand or nil,
    }

    local right = forward:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 1e-4 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end
    targetPos += (-right * MONSTER_DUEL_SIDE_SHIFT)
    targetPos += worldLeftShift
    targetPos = alignTargetToGround(hrp, targetPos, { character, duel.monsterModel })

    hrp.Anchored = true
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = CFrame.lookAt(targetPos, Vector3.new(monsterPos.X, targetPos.Y, monsterPos.Z), Vector3.new(0, 1, 0))

    if humanoid then
        humanoid.AutoRotate = false
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.PlatformStand = true
    end

    local participantState = playerStates[player]
    local team = participantState and participantState.team or TeamManager.getOrCreateTeam(player)
    PetCubeService.spawnPlayerTeamDuelLine(player, team, monsterPos)
end

local function startMonsterAI(player, duel)
    -- Propósito: Loop IA del monstruo: atacar por intervalos con perfil elemental y dificultad controlada.
    -- Precondiciones:
    --   1. duel debe ser duelo NPC activo con started=true.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    task.spawn(function()
        while activeMonsterDuels[player] == duel and duel.started do
            task.wait(MONSTER_AI_ATTACK_INTERVAL)

            if activeMonsterDuels[player] ~= duel or not duel.started then
                break
            end

            local element, comboCount, usedSpecial = buildMonsterAiAttack(duel)

            local damage, elementMatched, monsterElement = calculateWildMonsterUnitDamage(duel.monsterId, comboCount, element)

            local targetPos = getPlayerTargetPosition(player)
            if duel.monsterRoot and duel.monsterRoot:IsA("BasePart") and targetPos and elementMatched then
                local monsterSourcePos = duel.monsterRoot.Position
                task.spawn(function()
                    if activeMonsterDuels[player] ~= duel or not duel.started then
                        return
                    end
                    spawnProjectileVfx(monsterSourcePos, targetPos, element)
                end)
            elseif not elementMatched then
                dbg(
                    "NPC miss: elemento elegido="
                    .. tostring(element)
                    .. " distinto a elemento real="
                    .. tostring(monsterElement)
                )
            else
                dbg(
                    "VFX NPC omitido: source="
                    .. tostring(duel.monsterRoot ~= nil)
                    .. " target="
                    .. tostring(targetPos ~= nil)
                )
            end

            duel.playerHP = math.max(0, duel.playerHP - damage)

            sendDuelState(player, {
                type = "monster-attack",
                opponentKind = "monster",
                monsterName = duel.monsterName,
                opponentMonsterId = duel.monsterId,
                element = element,
                comboCount = comboCount,
                attackTag = elementMatched and (usedSpecial and "special" or "basic") or "miss",
                damage = damage,
                selfHP = duel.playerHP,
                enemyHP = duel.monsterHP,
                opponentName = duel.monsterName,
                selfStars = PvpStarsService.getStars(player),
                opponentStars = duel.monsterStars,
            })

            dbg(
                "NPC ataco a "
                .. player.Name
                .. " | "
                .. element
                .. " x"
                .. comboCount
                .. (usedSpecial and " [SPECIAL]" or "")
                .. (not elementMatched and " [MISS]" or "")
                .. " = "
                .. damage
                .. " | playerHP="
                .. duel.playerHP
            )

            if duel.playerHP <= 0 then
                endMonsterDuel(player, "hp-depleted", "monster")
                break
            end
        end
    end)
end

local function startMonsterDuelCountdown(player, duel)
    -- Propósito: Ejecutar countdown 3-2-1 antes de iniciar el combate contra el NPC.
    -- Precondiciones:
    --   1. duel debe tener started=false y estar activo en activeMonsterDuels.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    task.spawn(function()
        setupMonsterDuelParticipant(duel)

        sendDuelState(player, {
            type = "duel-intro",
            opponentKind = "monster",
            opponentName = duel.monsterName,
            opponentMonsterId = duel.monsterId,
            selfHP = duel.playerHP,
            enemyHP = duel.monsterHP,
            selfStars = PvpStarsService.getStars(player),
            opponentStars = duel.monsterStars,
        })

        for seconds = COUNTDOWN_SECONDS, 1, -1 do
            if activeMonsterDuels[player] ~= duel then return end

            sendDuelState(player, {
                type = "countdown",
                value = seconds,
                opponentKind = "monster",
                opponentName = duel.monsterName,
                opponentMonsterId = duel.monsterId,
                selfHP = duel.playerHP,
                enemyHP = duel.monsterHP,
                selfStars = PvpStarsService.getStars(player),
                opponentStars = duel.monsterStars,
            })
            task.wait(1)
        end

        if activeMonsterDuels[player] ~= duel then return end

        duel.started = true
        local state = playerStates[player]
        if state then
            state.duelStarted = true
        end

        sendDuelState(player, {
            type = "duel-started",
            opponentKind = "monster",
            opponentName = duel.monsterName,
            opponentMonsterId = duel.monsterId,
            selfHP = duel.playerHP,
            enemyHP = duel.monsterHP,
            selfStars = PvpStarsService.getStars(player),
            opponentStars = duel.monsterStars,
        })

        startMonsterAI(player, duel)
    end)
end

local function onMonsterChallenged(player, monsterModel)
    -- Propósito: Procesar desafío del jugador a un monstruo NPC via ProximityPrompt.
    -- Precondiciones:
    --   1. monsterModel debe ser un Model en Workspace con atributo MonsterId.
    --   2. El jugador debe estar dentro de MONSTER_CHALLENGE_DISTANCE.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not player or not monsterModel then return end

    if activeDuels[player] or activeMonsterDuels[player] then
        sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
        return
    end

    local playerPos = getRootPosition(player)
    if not playerPos then return end

    local monsterRoot = monsterModel:FindFirstChild("HumanoidRootPart")
        or monsterModel:FindFirstChildWhichIsA("BasePart", true)
    if not monsterRoot then
        warn("[CombatServer] onMonsterChallenged: " .. monsterModel.Name .. " no tiene BasePart")
        return
    end

    local dist = (playerPos - monsterRoot.Position).Magnitude
    if dist > MONSTER_CHALLENGE_DISTANCE then
        sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
        return
    end

    local state = playerStates[player]
    if not state then return end

    local rawMonsterId = monsterModel:GetAttribute("MonsterId") or monsterModel.Name
    local monsterId = resolveMonsterId(rawMonsterId)
    local playerTeam = state.team or TeamManager.getOrCreateTeam(player)
    local monsterTeam = buildMonsterNpcTeam(monsterId, MONSTER_TEAM_SIZE)

    local isTeamValid = TeamManager.validateTeam(playerTeam)
    if not isTeamValid then
        sendDuelState(player, { type = "challenge-failed", reason = "team-invalid" })
        return
    end

    if type(monsterId) ~= "string" or monsterId == "" or MonstersData[monsterId] == nil or #monsterTeam <= 0 then
        dbg(
            "MonsterId no encontrado en MonstersData: "
            .. tostring(monsterId)
            .. " (raw="
            .. tostring(rawMonsterId)
            .. ")"
        )
        sendDuelState(player, { type = "challenge-failed", reason = "monster-data-missing" })
        return
    end

    local economyConfig, rarityKey = getMonsterPveEconomyConfig(monsterId)
    local canSpendEnergy, currentEnergy, requiredEnergy = consumePlayerEnergyForMonsterDuel(player, economyConfig.energyCost)
    if not canSpendEnergy then
        sendDuelState(player, {
            type = "challenge-failed",
            reason = "energy-low",
            currentEnergy = currentEnergy,
            requiredEnergy = requiredEnergy,
            monsterRarity = rarityKey,
        })
        return
    end

    local playerHP = TeamManager.calculateTeamHP(playerTeam)
    local monsterHP = calculateWildMonsterMaxHP(monsterId)

    duelSequence += 1
    local duel = {
        id = "npc-" .. tostring(duelSequence),
        player = player,
        monsterModel = monsterModel,
        monsterRoot = monsterRoot,
        monsterName = monsterModel.Name,
        monsterId = monsterId,
        monsterRarity = rarityKey,
        energyCostOnStart = requiredEnergy,
        bitsRewardOnWin = economyConfig.bitsReward,
        monsterStars = 0,
        monsterTeam = monsterTeam,
        playerHP = playerHP,
        playerMaxHP = playerHP,
        monsterHP = monsterHP,
        monsterMaxHP = monsterHP,
        aiState = {
            turnIndex = 0,
            lastElement = nil,
            lastComboCount = 0,
            highComboStreak = 0,
            specialCooldown = 0,
            elementWeights = buildMonsterElementWeights(monsterId),
        },
        started = false,
    }

    activeMonsterDuels[player] = duel
    state.duelId = duel.id
    state.duelActive = true
    state.duelStarted = false

    dbg("desafio NPC aceptado: " .. player.Name .. " vs " .. monsterModel.Name .. " (1x " .. monsterId .. ")")

    sendDuelState(player, {
        type = "challenge-sent",
        targetName = monsterModel.Name,
        opponentKind = "monster",
        hideMonsterPromptSeconds = COUNTDOWN_SECONDS + 1,
    })

    startMonsterDuelCountdown(player, duel)
end

local function cleanPlayerState(player)
    -- Propósito: Liberar estado del jugador al desconectarse.
    -- Precondiciones:
    --   1. player debe ser válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local opponent, duel = getDuelOpponent(player)
    if duel and opponent then
        endDuel(duel, opponent, "player-left")
    end

    if activeMonsterDuels[player] then
        endMonsterDuel(player, "player-left", "monster")
    end

    pendingChallenges[player] = nil
    for targetPlayer, challengeData in pairs(pendingChallenges) do
        if challengeData and challengeData.challenger == player then
            pendingChallenges[targetPlayer] = nil
        end
    end

    TeamManager.clearTeam(player)
    PetCubeService.clearPlayerCubes(player)
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end
    playerStates[player] = nil
end

local function onCombatChallengeRequest(player, payload)
    -- Propósito: Procesar solicitud de desafío a jugador cercano.
    -- Precondiciones:
    --   1. payload.targetUserId debe ser number.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(payload) ~= "table" or type(payload.targetUserId) ~= "number" then
        return
    end

    local targetPlayer = Players:GetPlayerByUserId(payload.targetUserId)
    if not targetPlayer or targetPlayer == player then
        sendDuelState(player, { type = "challenge-failed", reason = "target-invalid" })
        return
    end

    if activeDuels[player] or activeDuels[targetPlayer] then
        sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
        return
    end

    local distance = getPlayersDistance(player, targetPlayer)
    if not distance or distance > CHALLENGE_DISTANCE then
        sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
        return
    end

    pendingChallenges[targetPlayer] = {
        challenger = player,
        createdAt = os.clock(),
    }

    sendDuelState(player, {
        type = "challenge-sent",
        targetName = targetPlayer.Name,
    })

    sendDuelState(targetPlayer, {
        type = "challenge-received",
        challengerName = player.Name,
        challengerUserId = player.UserId,
        timeout = CHALLENGE_TIMEOUT,
    })

    task.spawn(function()
        task.wait(CHALLENGE_TIMEOUT)
        local challengeData = pendingChallenges[targetPlayer]
        if challengeData and challengeData.challenger == player then
            pendingChallenges[targetPlayer] = nil
            sendDuelState(player, { type = "challenge-failed", reason = "challenge-timeout" })
            sendDuelState(targetPlayer, { type = "challenge-expired", challengerName = player.Name })
        end
    end)
end

local function onCombatChallengeResponse(player, payload)
    -- Propósito: Procesar aceptación o rechazo de un desafío recibido.
    -- Precondiciones:
    --   1. payload.accepted debe ser boolean.
    --   2. payload.challengerUserId debe ser number.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(payload) ~= "table" then
        return
    end

    if type(payload.accepted) ~= "boolean" or type(payload.challengerUserId) ~= "number" then
        return
    end

    local challengeData = pendingChallenges[player]
    if not challengeData or not challengeData.challenger then
        return
    end

    local challenger = challengeData.challenger
    if challenger.UserId ~= payload.challengerUserId then
        return
    end

    pendingChallenges[player] = nil

    if not payload.accepted then
        sendDuelState(challenger, {
            type = "challenge-declined",
            targetName = player.Name,
        })
        sendDuelState(player, {
            type = "challenge-rejected-local",
            challengerName = challenger.Name,
        })
        return
    end

    if activeDuels[challenger] or activeDuels[player] then
        sendDuelState(challenger, { type = "challenge-failed", reason = "duel-busy" })
        sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
        return
    end

    local distance = getPlayersDistance(challenger, player)
    if not distance or distance > CHALLENGE_DISTANCE then
        sendDuelState(challenger, { type = "challenge-failed", reason = "target-too-far" })
        sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
        return
    end

    local challengerState = playerStates[challenger]
    local targetState = playerStates[player]
    if not challengerState or not targetState then
        return
    end

    local teamA = challengerState.team or TeamManager.getOrCreateTeam(challenger)
    local teamB = targetState.team or TeamManager.getOrCreateTeam(player)
    local validA = TeamManager.validateTeam(teamA)
    local validB = TeamManager.validateTeam(teamB)
    if not validA or not validB then
        sendDuelState(challenger, { type = "challenge-failed", reason = "team-invalid" })
        sendDuelState(player, { type = "challenge-failed", reason = "team-invalid" })
        return
    end

    duelSequence += 1
    local duelId = "duel-" .. tostring(duelSequence)
    local duel = {
        id = duelId,
        playerA = challenger,
        playerB = player,
        started = false,
        hpByUserId = {
            [challenger.UserId] = TeamManager.calculateTeamHP(teamA),
            [player.UserId] = TeamManager.calculateTeamHP(teamB),
        },
    }

    activeDuels[challenger] = duel
    activeDuels[player] = duel

    challengerState.duelId = duelId
    challengerState.duelActive = true
    challengerState.duelStarted = false
    targetState.duelId = duelId
    targetState.duelActive = true
    targetState.duelStarted = false

    task.spawn(function()
        startDuelCountdown(duel)
    end)
end

local function sendRosterState(player, reason)
    -- Propósito: Enviar al cliente el estado actual de mochila, seguidor, equipo de duelo, fragmentos, evoluciones, XP, titulo y shields.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    if not state then
        return
    end

    local team = TeamManager.getOrCreateTeam(player)
    local backpack = TeamManager.getBackpack(player)
    local selectedFollowerMonsterId = TeamManager.getSelectedFollowerMonsterId(player)
    local allFragments = TeamManager.getAllFragments(player)

	local xp = {}
	local levels = {}
	for _, item in ipairs(backpack) do
		local count = math.max(0, math.floor(tonumber(item.Count) or 0))
		if count > 0 then
			xp[item.MonsterId] = TeamManager.getMonsterXP(player, item.MonsterId)
			levels[item.MonsterId] = TeamManager.getMonsterLevel(player, item.MonsterId)
		end
	end

    local shieldCharges = PvpStarsService.getShieldCharges(player)
    local pvpTitle = PvpStarsService.getTitleForPlayer(player)
    local stars = PvpStarsService.getStars(player)

    state.team = team
    state.backpack = backpack
    state.followMonsterId = selectedFollowerMonsterId

    sendDuelState(player, {
        type = "roster-sync",
        reason = reason or "sync",
        duelTeam = team,
        backpack = backpack,
        selectedFollowerMonsterId = selectedFollowerMonsterId,
        fragments = allFragments,
        monsterXP = xp,
        monsterLevels = levels,
        shieldCharges = shieldCharges,
        pvpTitle = pvpTitle,
        pvpStars = stars,
    })
end

local function applyDuelSlotSelection(player, payload)
    -- Propósito: Reemplazar un slot del equipo de 5 usando un Beastibit desbloqueado.
    -- Precondiciones:
    --   1. payload.slotIndex debe ser número entre 1 y 5.
    --   2. payload.monsterId debe existir y estar desbloqueado.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(payload.slotIndex) ~= "number" or type(payload.monsterId) ~= "string" then
        sendDuelState(player, { type = "roster-error", reason = "invalid-payload" })
        return
    end

    local slotIndex = math.floor(payload.slotIndex)
    if slotIndex < 1 or slotIndex > 5 then
        sendDuelState(player, { type = "roster-error", reason = "invalid-slot" })
        return
    end

    if MonstersData[payload.monsterId] == nil then
        sendDuelState(player, { type = "roster-error", reason = "monster-data-missing" })
        return
    end

    local backpack = TeamManager.getBackpack(player)
    local isUnlocked = false
    for _, item in ipairs(backpack) do
        if item.MonsterId == payload.monsterId and (math.max(0, math.floor(tonumber(item.Count) or 0)) > 0) then
            isUnlocked = true
            break
        end
    end

    if not isUnlocked then
        sendDuelState(player, { type = "roster-error", reason = "monster-locked" })
        return
    end

    local monsterCount = 0
    for _, item in ipairs(backpack) do
        if item.MonsterId == payload.monsterId then
            monsterCount = math.max(0, math.floor(tonumber(item.Count) or 0))
            break
        end
    end

    local currentTeam = TeamManager.getOrCreateTeam(player)
    local usedInTeam = 0
    for i, pet in ipairs(currentTeam) do
        if i ~= slotIndex and pet and pet.MonsterId == payload.monsterId then
            usedInTeam = usedInTeam + 1
        end
    end

    if usedInTeam >= monsterCount then
        sendDuelState(player, { type = "roster-error", reason = "not-enough-copies" })
        return
    end

    currentTeam[slotIndex] = {
        MonsterId = payload.monsterId,
    }

    local isValid, reason = TeamManager.setTeam(player, currentTeam)
    if not isValid then
        sendDuelState(player, { type = "roster-error", reason = reason or "team-invalid" })
        return
    end

    local state = playerStates[player]
    if state then
        state.team = TeamManager.getOrCreateTeam(player)
    end

    sendRosterState(player, "duel-team-updated")
end

local function onCombatRosterAction(player, payload)
    -- Propósito: Procesar acciones de mochila/formación enviadas por el cliente.
    -- Precondiciones:
    --   1. payload.action debe ser string válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(payload) ~= "table" or type(payload.action) ~= "string" then
        return
    end

    local state = playerStates[player]
    if not state then
        return
    end

    if state.duelActive then
        sendDuelState(player, { type = "roster-error", reason = "duel-active" })
        return
    end

    if payload.action == "request" then
        sendRosterState(player, "manual-request")
        return
    end

    if payload.action == "select-follower" then
        local isValid, reason = TeamManager.setSelectedFollowerMonsterId(player, payload.monsterId)
        if not isValid then
            sendDuelState(player, { type = "roster-error", reason = reason or "invalid-follower" })
            return
        end

        state.followMonsterId = TeamManager.getSelectedFollowerMonsterId(player)
        PetCubeService.spawnPlayerTeamCubes(player, state.team or TeamManager.getOrCreateTeam(player), state.followMonsterId)
        sendRosterState(player, "follower-updated")
        return
    end

	if payload.action == "set-duel-slot" then
		applyDuelSlotSelection(player, payload)
		return
	end

	if payload.action == "feed" then
        if type(payload.targetMonsterId) ~= "string" or type(payload.foodMonsterId) ~= "string" then
            sendDuelState(player, { type = "roster-error", reason = "invalid-monster-ids" })
            return
        end
        local success, reason, xpGained, newXP = TeamManager.feedMonster(player, payload.targetMonsterId, payload.foodMonsterId)
        if not success then
            sendDuelState(player, { type = "roster-error", reason = reason or "feed-failed" })
            return
        end
        sendDuelState(player, {
            type = "feed-result",
            targetMonsterId = payload.targetMonsterId,
            foodMonsterId = payload.foodMonsterId,
            xpGained = xpGained,
            newXP = newXP,
        })
        sendRosterState(player, "fed")
        return
    end

    if payload.action == "craft" then
        if type(payload.monsterId) ~= "string" then
            sendDuelState(player, { type = "roster-error", reason = "invalid-monster-id" })
            return
        end
        local success, reason = TeamManager.craftMonster(player, payload.monsterId)
        if not success then
            sendDuelState(player, { type = "roster-error", reason = reason or "craft-failed" })
            return
        end
        sendRosterState(player, "crafted")
        return
    end

    sendDuelState(player, { type = "roster-error", reason = "unknown-action" })
end

local function printGrid(grid)
    -- Imprime el estado del tablero en consola (por filas)
    for row = 1, ROWS do
        local rowStr = ""
        for col = 1, COLS do
            local tile = grid[col][row]
            if tile and tile.elementType then
                rowStr = rowStr .. string.sub(tile.elementType, 1, 1) .. " "
            else
                rowStr = rowStr .. ". "
            end
        end
        print("[CombatServer][GRID] " .. rowStr)
    end
end

local function printCombos(combos, label)
    if not combos or #combos == 0 then
        print("[CombatServer][COMBO] " .. (label or "") .. " (ninguna)")
        return
    end
    for i, combo in ipairs(combos) do
        local cells = {}
        for _, cell in ipairs(combo) do
            table.insert(cells, "("..cell.col..","..cell.row..")")
        end
        print("[CombatServer][COMBO] " .. (label or "") .. " #"..i..": " .. table.concat(cells, ", "))
    end
end

local function onCombatSubmit(player, payload)
    -- Propósito: Procesar una ruta de swaps enviada por el cliente.
    -- Precondiciones:
    --   1. player debe tener estado inicializado.
    --   2. payload.path debe describir swaps adyacentes consecutivos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    if not state then
        warn("[CombatServer] Submit de jugador sin estado: " .. player.Name)
        return
    end

    local monsterDuel = activeMonsterDuels[player]
    local opponent, duel = getDuelOpponent(player)
    if not duel and not monsterDuel then
        syncPlayer(player, {
            rejected = true,
            reason = "duel-not-active",
            duelActive = false,
            duelStarted = false,
        })
        return
    end

    local isMonsterDuel = (monsterDuel ~= nil and duel == nil)
    if isMonsterDuel then
        if not monsterDuel.started then
            syncPlayer(player, { rejected = true, reason = "duel-not-started", duelActive = true, duelStarted = false })
            return
        end
    elseif not duel.started then
        syncPlayer(player, {
            rejected = true,
            reason = "duel-not-started",
            duelActive = true,
            duelStarted = false,
        })
        return
    end

    local team = state.team or TeamManager.getOrCreateTeam(player)
    local isTeamValid, teamReason = TeamManager.validateTeam(team)
    state.team = team
    state.teamValid = isTeamValid
    state.teamReason = teamReason

    if not isTeamValid then
        syncPlayer(player, {
            rejected = true,
            reason = "team-invalid",
            teamValid = false,
            teamReason = teamReason,
            playerTotalHP = TeamManager.calculateTeamHP(team),
        })
        return
    end

    dbg("submit recibido de " .. player.Name)

    local now = os.clock()
    if (now - state.lastSubmit) < 0.15 then
        warn("[CombatServer] Submit demasiado rápido de: " .. player.Name)
        return
    end
    state.lastSubmit = now

    if not isValidSwapPayload(payload) then
        warn("[CombatServer] Payload inválido de: " .. player.Name)
        syncPlayer(player, { rejected = true, reason = "invalid-payload" })
        return
    end

    local validation = CombatGrid.validateSwapPath(payload.path)
    if validation.errors and #validation.errors > 0 then
        dbg("validation notes: " .. table.concat(validation.errors, " | "))
    end

    if not validation.valid then
        syncPlayer(player, {
            rejected = true,
            reason = validation.errors[1] or "invalid-swap",
        })
        return
    end

    print("\n[CombatServer] ===== TURNO DE " .. player.Name .. " =====")
    print("[CombatServer] TABLERO ORIGINAL:")
    printGrid(state.grid)
    print("[CombatServer] SWAPS ejecutados:")
    for i, swap in ipairs(payload.path) do
        print("  Paso "..i..": ("..swap.col..","..swap.row..")")
    end

    local executedSwaps = CombatGrid.applySwapPath(state.grid, payload.path)
    local comboSummary = {
        totalCombos = 0,
        activatedElements = {},
    }

    -- Log de cascadas
    local resolution = { cascades = {}, totalEliminadas = 0, totalCascades = 0 }
    local safetyCounter = 0
    while safetyCounter < 20 do
        safetyCounter = safetyCounter + 1
        local matches = CombatGrid.findMatches(state.grid)
        if not matches.hasMatches then
            break
        end
        appendComboSummary(comboSummary, matches.combos, state.grid)
        print("[CombatServer] CASCADA "..safetyCounter.." - combinaciones:")
        printCombos(matches.combos, "CASCADA "..safetyCounter)
        local eliminadas = CombatGrid.aplicarCombos(state.grid, matches.combos)
        print("[CombatServer] Eliminadas: " .. #eliminadas)
        print("[CombatServer] TABLERO tras eliminar:")
        printGrid(state.grid)
        local gravityResult = CombatGrid.aplicarGravedad(state.grid)
        print("[CombatServer] TABLERO tras gravedad+relleno:")
        printGrid(state.grid)
        table.insert(resolution.cascades, {
            combos = matches.combos,
            eliminadas = eliminadas,
            movimientos = gravityResult.movimientos,
            nuevas = gravityResult.nuevas,
            totalCells = #eliminadas,
        })
        resolution.totalEliminadas = resolution.totalEliminadas + #eliminadas
    end
    resolution.totalCascades = #resolution.cascades
    local boardDamage = resolution.totalEliminadas * DAMAGE_PER_CELL

    local combatDamage = MonsterCombat.calculateTeamDamage(team, comboSummary)
    local playerTotalHP = TeamManager.calculateTeamHP(team)

    local enemyHP = nil
    local selfHP = playerTotalHP
    if isMonsterDuel then
        enemyHP = monsterDuel.monsterHP
        selfHP = monsterDuel.playerHP
    elseif duel then
        enemyHP = opponent and (duel.hpByUserId[opponent.UserId] or 0) or nil
        selfHP = duel.hpByUserId[player.UserId] or playerTotalHP
    end
    local animationDelay = estimateCascadeAnimationDuration(resolution.cascades)

    if combatDamage.totalDamage > 0 then
        if isMonsterDuel then
            task.delay(animationDelay, function()
                if activeMonsterDuels[player] ~= monsterDuel or not monsterDuel.started then
                    return
                end

                task.wait(VFX_AFTER_UI_HIDE_DELAY)
                if activeMonsterDuels[player] ~= monsterDuel or not monsterDuel.started then
                    return
                end

                playPlayerAttackVfxSequence(player, combatDamage.damageByPet, function()
                    if activeMonsterDuels[player] ~= monsterDuel then
                        return nil
                    end
                    return monsterDuel.monsterRoot and monsterDuel.monsterRoot.Position or nil
                end)

                local nextHP = math.max(0, math.floor(monsterDuel.monsterHP - combatDamage.totalDamage))
                monsterDuel.monsterHP = nextHP
                enemyHP = nextHP
                sendDuelState(player, {
                    type = "duel-update",
                    opponentKind = "monster",
                    opponentName = monsterDuel.monsterName,
                    opponentMonsterId = monsterDuel.monsterId,
                    selfHP = monsterDuel.playerHP,
                    enemyHP = nextHP,
                    lastDamageDealt = combatDamage.totalDamage,
                    selfStars = PvpStarsService.getStars(player),
                    opponentStars = monsterDuel.monsterStars,
                })
                if nextHP <= 0 then
                    endMonsterDuel(player, "hp-depleted", "player")
                end
            end)
        elseif opponent then
            task.delay(animationDelay, function()
                if activeDuels[player] ~= duel or activeDuels[opponent] ~= duel or not duel.started then
                    return
                end

                task.wait(VFX_AFTER_UI_HIDE_DELAY)
                if activeDuels[player] ~= duel or activeDuels[opponent] ~= duel or not duel.started then
                    return
                end

                playPlayerAttackVfxSequence(player, combatDamage.damageByPet, function()
                    if activeDuels[player] ~= duel or activeDuels[opponent] ~= duel then
                        return nil
                    end
                    return getPvpTargetPosition(opponent)
                end)

                local opponentCurrentHP = duel.hpByUserId[opponent.UserId] or 0
                local nextHP = math.max(0, math.floor(opponentCurrentHP - combatDamage.totalDamage))
                duel.hpByUserId[opponent.UserId] = nextHP

                sendDuelState(opponent, {
                    type = "duel-update",
                    opponentKind = "player",
                    opponentName = player.Name,
                    opponentUserId = player.UserId,
                    selfHP = duel.hpByUserId[opponent.UserId],
                    enemyHP = duel.hpByUserId[player.UserId],
                    lastDamageReceived = combatDamage.totalDamage,
                    selfStars = PvpStarsService.getStars(opponent),
                    opponentStars = PvpStarsService.getStars(player),
                })

                sendDuelState(player, {
                    type = "duel-update",
                    opponentKind = "player",
                    opponentName = opponent.Name,
                    opponentUserId = opponent.UserId,
                    selfHP = duel.hpByUserId[player.UserId],
                    enemyHP = duel.hpByUserId[opponent.UserId],
                    lastDamageDealt = combatDamage.totalDamage,
                    selfStars = PvpStarsService.getStars(player),
                    opponentStars = PvpStarsService.getStars(opponent),
                })

                if nextHP <= 0 then
                    endDuel(duel, player, "hp-depleted")
                end
            end)
        end
    end

    dbg(
        "turno "
        .. player.Name
        .. " | totalCombos="
        .. tostring(comboSummary.totalCombos)
        .. " | elementos="
        .. table.concat(getActivatedElementsList(comboSummary.activatedElements), ",")
        .. " | damageTotal="
        .. tostring(combatDamage.totalDamage)
    )

    print("[CombatServer] ===== FIN TURNO " .. player.Name .. " =====\n")

    syncPlayer(player, {
        path = payload.path,
        swaps = executedSwaps,
        cascades = resolution.cascades,
        totalCells = resolution.totalEliminadas,
        totalCascades = resolution.totalCascades,
        damage = combatDamage.totalDamage,
        boardDamage = boardDamage,
        comboSummary = {
            totalCombos = comboSummary.totalCombos,
            activatedElements = getActivatedElementsList(comboSummary.activatedElements),
        },
        combatResult = {
            totalDamage = combatDamage.totalDamage,
            damageByPet = combatDamage.damageByPet,
            playerTotalHP = playerTotalHP,
            enemyHP = enemyHP,
        },
        teamValid = true,
        teamReason = "ok",
        duelActive = state.duelActive,
        duelStarted = state.duelStarted,
        selfHP = selfHP,
        enemyHP = enemyHP,
        opponentName = isMonsterDuel and monsterDuel.monsterName or (opponent and opponent.Name) or nil,
        reason = resolution.totalEliminadas > 0 and "path-resolved" or "path-no-matches",
    })
end

Players.PlayerAdded:Connect(function(player)
    local savedData = BackpackDataStore.loadPlayerData(player)
    TeamManager.initializePlayer(player, savedData)
    PvpStarsService.onPlayerAdded(player)

    if type(savedData) == "table" then
        if type(savedData.bits) == "number" then
            player:SetAttribute(BITS_ATTRIBUTE_NAME, math.max(0, math.floor(savedData.bits)))
        end
        if type(savedData.minerals) == "table" then
            for mineralName, count in pairs(savedData.minerals) do
                local safeCount = math.max(0, math.floor(tonumber(count) or 0))
                if safeCount > 0 then
                    player:SetAttribute("Mineral_" .. string.gsub(mineralName, "%s+", ""), safeCount)
                end
            end
        end
    end

    initPlayerState(player)
    bindCharacterSpawn(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local unlockedMonsters, fragments, bits, minerals, xp, monsterCounts = TeamManager.getProfileData(player)
	BackpackDataStore.savePlayerData(player, unlockedMonsters, fragments, bits, minerals, xp, monsterCounts)
    PvpStarsService.onPlayerRemoving(player)
    cleanPlayerState(player)
end)

CombatSubmit.OnServerEvent:Connect(onCombatSubmit)
CombatChallengeRequest.OnServerEvent:Connect(onCombatChallengeRequest)
CombatChallengeResponse.OnServerEvent:Connect(onCombatChallengeResponse)
CombatRosterAction.OnServerEvent:Connect(onCombatRosterAction)

for _, player in ipairs(Players:GetPlayers()) do
    local savedData = BackpackDataStore.loadPlayerData(player)
    TeamManager.initializePlayer(player, savedData)
    PvpStarsService.onPlayerAdded(player)

    if type(savedData) == "table" then
        if type(savedData.bits) == "number" then
            player:SetAttribute(BITS_ATTRIBUTE_NAME, math.max(0, math.floor(savedData.bits)))
        end
        if type(savedData.minerals) == "table" then
            for mineralName, count in pairs(savedData.minerals) do
                local safeCount = math.max(0, math.floor(tonumber(count) or 0))
                if safeCount > 0 then
                    player:SetAttribute("Mineral_" .. string.gsub(mineralName, "%s+", ""), safeCount)
                end
            end
        end
    end

    if not playerStates[player] then
        initPlayerState(player)
    end
    bindCharacterSpawn(player)
end

-- ============================================================
-- ESCUCHAR ACTIVACIÓN DE PROXIMITYPROMPT DE MONSTRUOS NPC
-- (La creación del prompt está en MonsterPromptSetup.server.lua)
-- ============================================================

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    -- Propósito: Detectar cuando un jugador activa el prompt de desafío a monstruo.
    -- Precondiciones:
    --   1. prompt.Name debe ser "MonsterChallengePrompt".
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if prompt.Name ~= "MonsterChallengePrompt" then return end

    -- Subir la jerarquía para encontrar el Model con IsMonster=true
    -- (el prompt puede estar en una parte anidada dentro del modelo)
    local current = prompt.Parent
    local monsterModel = nil
    while current and current ~= workspace do
        if current:IsA("Model") and current:GetAttribute("IsMonster") then
            monsterModel = current
            break
        end
        current = current.Parent
    end

    if not monsterModel then
        warn("[CombatServer] PromptTriggered: no se encontró Model con IsMonster=true para el prompt en " .. tostring(prompt.Parent and prompt.Parent.Name))
        return
    end

    onMonsterChallenged(player, monsterModel)
end)

-- ============================================================
-- SHIELD REGEN LOOP
-- ============================================================
local function runShieldRegenLoop()
    while true do
        task.wait(30)
        local now = os.time()
        for _, player in ipairs(Players:GetPlayers()) do
            PvpStarsService.applyShieldRegen(player, now)
        end
    end
end

task.spawn(runShieldRegenLoop)
