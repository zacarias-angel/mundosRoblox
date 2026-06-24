-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/TeamManager
-- Contexto: Servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local TeamManager = {}

local TEAM_SIZE = 5
local MAX_EVOLUTION = 3

local EVOLUTION_COST = {
	[1] = { bits = 500, minerals = 10, levelRequired = 20 },
	[2] = { bits = 2500, minerals = 30, levelRequired = 40 },
}

local XP_BY_RARITY = {
	common = 10,
	rare = 25,
	epic = 60,
	legendary = 150,
}

local EVO_XP_MULTIPLIER = {
	[1] = 1.0,
	[2] = 1.75,
	[3] = 3.0,
}

local LEVEL_XP_MILESTONES = {
	{ level = 1, xp = 0 },
	{ level = 5, xp = 40 },
	{ level = 10, xp = 120 },
	{ level = 15, xp = 260 },
	{ level = 20, xp = 500 },
	{ level = 21, xp = 650 },
	{ level = 25, xp = 950 },
	{ level = 30, xp = 1450 },
	{ level = 35, xp = 2200 },
	{ level = 40, xp = 3200 },
	{ level = 41, xp = 3800 },
	{ level = 45, xp = 5000 },
	{ level = 50, xp = 6800 },
	{ level = 55, xp = 9200 },
	{ level = 60, xp = 12000 },
}

local MAX_LEVEL = 60

local function getXPForLevel(targetLevel)
	local safeLevel = math.clamp(math.floor(tonumber(targetLevel) or 1), 1, MAX_LEVEL)
	if safeLevel <= 1 then
		return 0
	end

	for i = 1, #LEVEL_XP_MILESTONES - 1 do
		local a = LEVEL_XP_MILESTONES[i]
		local b = LEVEL_XP_MILESTONES[i + 1]
		if safeLevel >= a.level and safeLevel <= b.level then
			local ratio = (safeLevel - a.level) / (b.level - a.level)
			return math.ceil(a.xp + (b.xp - a.xp) * ratio)
		end
	end

	return LEVEL_XP_MILESTONES[#LEVEL_XP_MILESTONES].xp
end

local function getLevelForXP(xp)
	local safeXP = math.max(0, math.floor(tonumber(xp) or 0))
	if safeXP <= 0 then
		return 1
	end

	for i = #LEVEL_XP_MILESTONES, 1, -1 do
		if safeXP >= LEVEL_XP_MILESTONES[i].xp then
			if i < #LEVEL_XP_MILESTONES then
				local a = LEVEL_XP_MILESTONES[i]
				local b = LEVEL_XP_MILESTONES[i + 1]
				local extraXP = safeXP - a.xp
				local xpPerLevel = (b.xp - a.xp) / (b.level - a.level)
				local extraLevels = math.floor(extraXP / xpPerLevel)
				return math.min(MAX_LEVEL, a.level + extraLevels)
			end
			return MAX_LEVEL
		end
	end

	return 1
end

local function getLevelMultiplier(level)
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, MAX_LEVEL)
	if safeLevel <= 5 then
		return 0.8
	elseif safeLevel <= 10 then
		return 1.0
	elseif safeLevel <= 15 then
		return 1.25
	elseif safeLevel <= 20 then
		return 1.5
	elseif safeLevel <= 30 then
		return 1.8
	elseif safeLevel <= 40 then
		return 2.2
	else
		return 3.0
	end
end

local function getEvolutionForLevel(level)
	local safeLevel = math.clamp(math.floor(tonumber(level) or 1), 1, MAX_LEVEL)
	if safeLevel <= 20 then
		return 1
	elseif safeLevel <= 40 then
		return 2
	else
		return 3
	end
end

local ELEMENT_EVOLUTION_MINERAL = {
	Fuego = "Magma Core",
	Agua = "Aqua Shard",
	Planta = "Root Crystal",
	Electricidad = "Volt Core",
	Roca = "Stone Heart",
}

local MINERAL_ATTRIBUTE_PREFIX = "Mineral_"
local BITS_ATTRIBUTE_NAME = "Bits"

local playerProfiles = {}

local function ensureFragmentsTable(profile)
	if type(profile.fragments) ~= "table" then
		profile.fragments = {}
	end
	return profile.fragments
end

local function ensureUnlockedMonstersTable(profile)
	if type(profile.unlockedMonsters) ~= "table" then
		profile.unlockedMonsters = {}
	end
	return profile.unlockedMonsters
end

local function cloneTeam(team)
    -- Propósito: Clonar defensivamente una lista de mascotas del jugador.
    -- Precondiciones:
    --   1. team debe ser tabla.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local copy = {}
    for index, pet in ipairs(team) do
        copy[index] = {
            MonsterId = pet.MonsterId,
        }
    end
    return copy
end

local function cloneBackpack(backpack)
    -- Propósito: Clonar defensivamente la mochila de Beastibit del jugador.
    -- Precondiciones:
    --   1. backpack debe ser tabla.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local copy = {}
    for index, item in ipairs(backpack) do
        copy[index] = {
            MonsterId = item.MonsterId,
            Count = math.max(0, math.floor(tonumber(item.Count) or 0)),
        }
    end
    return copy
end

local function isMonsterUnlockedInBackpack(backpack, monsterId)
    -- Propósito: Verificar si un Beastibit está desbloqueado (tiene al menos 1 copia) en la mochila.
    -- Precondiciones:
    --   1. backpack debe ser tabla.
    --   2. monsterId debe ser string.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean
    if type(backpack) ~= "table" or type(monsterId) ~= "string" then
        return false
    end

    for _, item in ipairs(backpack) do
        if item.MonsterId == monsterId then
            local count = math.max(0, math.floor(tonumber(item.Count) or 0))
            return count > 0
        end
    end

    return false
end

local function getMonsterCountInBackpack(backpack, monsterId)
    if type(backpack) ~= "table" or type(monsterId) ~= "string" then
        return 0
    end

    for _, item in ipairs(backpack) do
        if item.MonsterId == monsterId then
            return math.max(0, math.floor(tonumber(item.Count) or 0))
        end
    end

    return 0
end

local function setMonsterCountInBackpack(backpack, monsterId, count)
    local safeCount = math.max(0, math.floor(tonumber(count) or 0))
    for _, item in ipairs(backpack) do
        if item.MonsterId == monsterId then
            item.Count = safeCount
            return safeCount
        end
    end
    table.insert(backpack, {
        MonsterId = monsterId,
        Count = safeCount,
    })
    return safeCount
end

local function getDefaultTeam()
    -- Propósito: Construir el equipo por defecto de 5 mascotas del jugador.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    return {
        { MonsterId = "SlimeFuego" },
        { MonsterId = "LoboAgua" },
        { MonsterId = "TortugaPlanta" },
        { MonsterId = "HalconElectrico" },
        { MonsterId = "GolemRoca" },
    }
end

local function buildDefaultBackpack()
    -- Propósito: Construir mochila inicial en base a MonstersData con flags StarterUnlocked.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local backpack = {}
    local sortedMonsterIds = {}

    for monsterId in pairs(MonstersData) do
        table.insert(sortedMonsterIds, monsterId)
    end
    table.sort(sortedMonsterIds)

    for _, monsterId in ipairs(sortedMonsterIds) do
        local data = MonstersData[monsterId]
        local starterCount = (data and data.StarterUnlocked == true) and 1 or 0
        table.insert(backpack, {
            MonsterId = monsterId,
            Count = starterCount,
        })
    end

    return backpack
end

local function chooseDefaultFollowerMonsterId(backpack, fallbackTeam)
    local preferredMonsterId = fallbackTeam[1] and fallbackTeam[1].MonsterId or nil
    if type(preferredMonsterId) == "string" and isMonsterUnlockedInBackpack(backpack, preferredMonsterId) then
        return preferredMonsterId
    end

    for _, item in ipairs(backpack) do
        local count = math.max(0, math.floor(tonumber(item.Count) or 0))
        if count > 0 and type(item.MonsterId) == "string" then
            return item.MonsterId
        end
    end

    if fallbackTeam[1] and type(fallbackTeam[1].MonsterId) == "string" then
        return fallbackTeam[1].MonsterId
    end

    return "SlimeFuego"
end

local function ensureBackpackHasTeamMonsters(backpack, team)
    for _, pet in ipairs(team) do
        local found = false
        for _, item in ipairs(backpack) do
            if item.MonsterId == pet.MonsterId then
                if getMonsterCountInBackpack(backpack, pet.MonsterId) <= 0 then
                    setMonsterCountInBackpack(backpack, pet.MonsterId, 1)
                end
                found = true
                break
            end
        end

        if not found then
            table.insert(backpack, {
                MonsterId = pet.MonsterId,
                Count = 1,
            })
        end
    end
end

local function ensureEvolutionsTable(profile)
    if type(profile.monsterEvolutions) ~= "table" then
        profile.monsterEvolutions = {}
    end
    return profile.monsterEvolutions
end

local function ensureXPTable(profile)
    if type(profile.monsterXP) ~= "table" then
        profile.monsterXP = {}
    end
    return profile.monsterXP
end

local function getMonsterEvoInProfile(profile, monsterId)
    local evolutions = ensureEvolutionsTable(profile)
    return math.clamp(math.floor(tonumber(evolutions[monsterId]) or 1), 1, MAX_EVOLUTION)
end

local function getMonsterXPInProfile(profile, monsterId)
    local xp = ensureXPTable(profile)
    return math.max(0, math.floor(tonumber(xp[monsterId]) or 0))
end

local function getEvolutionMineralForMonster(monsterId)
    local data = MonstersData[monsterId]
    if not data then
        return nil
    end
    local element = data.Element
    if type(element) == "string" and ELEMENT_EVOLUTION_MINERAL[element] then
        return ELEMENT_EVOLUTION_MINERAL[element]
    end
    return nil
end

local function sanitizeMineralAttr(mineralName)
	if type(mineralName) ~= "string" then
		return ""
	end
	return string.gsub(mineralName, "%s+", "")
end

local function getPlayerMineralCount(player, mineralName)
	if type(mineralName) ~= "string" then
		return 0
	end
	local attrName = MINERAL_ATTRIBUTE_PREFIX .. sanitizeMineralAttr(mineralName)
	return math.max(0, math.floor(tonumber(player:GetAttribute(attrName)) or 0))
end

local function spendPlayerMineral(player, mineralName, amount)
	if type(mineralName) ~= "string" or amount <= 0 then
		return false
	end
	local attrName = MINERAL_ATTRIBUTE_PREFIX .. sanitizeMineralAttr(mineralName)
	local current = getPlayerMineralCount(player, mineralName)
	if current < amount then
		return false
	end
	player:SetAttribute(attrName, current - amount)
	return true
end

local function getPlayerBits(player)
    return math.max(0, math.floor(tonumber(player:GetAttribute(BITS_ATTRIBUTE_NAME)) or 0))
end

local function spendPlayerBits(player, amount)
    if amount <= 0 then
        return false
    end
    local current = getPlayerBits(player)
    if current < amount then
        return false
    end
    player:SetAttribute(BITS_ATTRIBUTE_NAME, current - amount)
    return true
end

local function getOrCreateProfile(player, savedData)
    -- Propósito: Obtener o inicializar perfil en memoria del jugador (equipo, mochila, seguidor, fragmentos, evoluciones, XP).
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. savedData puede ser nil o tabla con unlockedMonsters, fragments, bits, minerals, monsterEvolutions, monsterXP.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local existing = playerProfiles[player]
    if existing then
        return existing
    end

    local defaultTeam = getDefaultTeam()
    local backpack = buildDefaultBackpack()
    ensureBackpackHasTeamMonsters(backpack, defaultTeam)

    local unlockedMonsters = {}
    local fragments = {}
    local monsterEvolutions = {}
    local monsterXP = {}

    if type(savedData) == "table" then
        if type(savedData.unlockedMonsters) == "table" then
            for monsterId, unlocked in pairs(savedData.unlockedMonsters) do
                if MonstersData[monsterId] and unlocked == true then
                    unlockedMonsters[monsterId] = true
                end
            end
        end
        if type(savedData.fragments) == "table" then
            for monsterId, amount in pairs(savedData.fragments) do
                if MonstersData[monsterId] then
                    local safeAmount = math.max(0, math.floor(tonumber(amount) or 0))
                    if safeAmount > 0 then
                        fragments[monsterId] = safeAmount
                    end
                end
            end
        end
        if type(savedData.monsterEvolutions) == "table" then
            for monsterId, evo in pairs(savedData.monsterEvolutions) do
                if MonstersData[monsterId] then
                    monsterEvolutions[monsterId] = math.clamp(math.floor(tonumber(evo) or 1), 1, MAX_EVOLUTION)
                end
            end
        end
        if type(savedData.monsterXP) == "table" then
            for monsterId, xp in pairs(savedData.monsterXP) do
                if MonstersData[monsterId] then
                    local safeXP = math.max(0, math.floor(tonumber(xp) or 0))
                    if safeXP > 0 then
                        monsterXP[monsterId] = safeXP
                    end
                end
            end
        end
        if type(savedData.monsterCounts) == "table" then
            for monsterId, count in pairs(savedData.monsterCounts) do
                if MonstersData[monsterId] then
                    local safeCount = math.max(0, math.floor(tonumber(count) or 0))
                    setMonsterCountInBackpack(backpack, monsterId, safeCount)
                end
            end
        end
    end

    for _, item in ipairs(backpack) do
        local count = getMonsterCountInBackpack(backpack, item.MonsterId)
        if count > 0 then
            unlockedMonsters[item.MonsterId] = true
        end
    end

    local profile = {
        duelTeam = defaultTeam,
        backpack = backpack,
        selectedFollowerMonsterId = chooseDefaultFollowerMonsterId(backpack, defaultTeam),
        unlockedMonsters = unlockedMonsters,
        fragments = fragments,
        monsterEvolutions = monsterEvolutions,
        monsterXP = monsterXP,
    }

    playerProfiles[player] = profile
    return profile
end

function TeamManager.validateTeam(team)
    -- Propósito: Validar que el equipo tenga exactamente 5 mascotas válidas.
    -- Precondiciones:
    --   1. team debe ser tabla.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean isValid, string reason
    if type(team) ~= "table" then
        return false, "team-no-table"
    end

    if #team ~= TEAM_SIZE then
        return false, "team-size-invalid"
    end

    for index, pet in ipairs(team) do
        if type(pet) ~= "table" or type(pet.MonsterId) ~= "string" then
            return false, "team-pet-invalid-" .. tostring(index)
        end

        if MonstersData[pet.MonsterId] == nil then
            return false, "team-monster-missing-" .. tostring(index)
        end
    end

    return true, "ok"
end

function TeamManager.getOrCreateTeam(player)
    -- Propósito: Obtener o crear el equipo activo en memoria para un jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local profile = getOrCreateProfile(player)
    return cloneTeam(profile.duelTeam)
end

function TeamManager.getTeam(player)
    -- Propósito: Obtener el equipo actual sin crear uno nuevo.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table|nil
    local profile = playerProfiles[player]
    if not profile then
        return nil
    end
    return cloneTeam(profile.duelTeam)
end

function TeamManager.setTeam(player, team)
    -- Propósito: Reemplazar el equipo activo de duelo del jugador.
    -- Precondiciones:
    --   1. team debe pasar validateTeam.
    --   2. No puede usar mas copias de un Beastibit de las que tiene.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean isValid, string reason
    local isValid, reason = TeamManager.validateTeam(team)
    if not isValid then
        return false, reason
    end

    local profile = getOrCreateProfile(player)

    local usageCounts = {}
    for _, pet in ipairs(team) do
        usageCounts[pet.MonsterId] = (usageCounts[pet.MonsterId] or 0) + 1
    end

    for monsterId, used in pairs(usageCounts) do
        local owned = getMonsterCountInBackpack(profile.backpack, monsterId)
        if used > owned then
            return false, "not-enough-copies"
        end
    end

    profile.duelTeam = cloneTeam(team)
    ensureBackpackHasTeamMonsters(profile.backpack, profile.duelTeam)

    if not isMonsterUnlockedInBackpack(profile.backpack, profile.selectedFollowerMonsterId) then
        profile.selectedFollowerMonsterId = chooseDefaultFollowerMonsterId(profile.backpack, profile.duelTeam)
    end

    return true, "ok"
end

function TeamManager.getBackpack(player)
    -- Propósito: Obtener copia de la mochila del jugador con estados desbloqueado/bloqueado.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local profile = getOrCreateProfile(player)
    return cloneBackpack(profile.backpack)
end

function TeamManager.getSelectedFollowerMonsterId(player)
    -- Propósito: Obtener el Beastibit que sigue al jugador fuera de duelo.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: string
    local profile = getOrCreateProfile(player)
    return profile.selectedFollowerMonsterId
end

function TeamManager.setSelectedFollowerMonsterId(player, monsterId)
    -- Propósito: Cambiar Beastibit seguidor activo si está desbloqueado en la mochila.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. monsterId debe estar desbloqueado para el jugador.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean isValid, string reason
    if type(monsterId) ~= "string" then
        return false, "invalid-monster-id"
    end

    if MonstersData[monsterId] == nil then
        return false, "monster-data-missing"
    end

    local profile = getOrCreateProfile(player)
    if not isMonsterUnlockedInBackpack(profile.backpack, monsterId) then
        return false, "monster-locked"
    end

    profile.selectedFollowerMonsterId = monsterId
    return true, "ok"
end

function TeamManager.clearTeam(player)
    -- Propósito: Liberar el equipo en memoria cuando un jugador se desconecta.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: nil
    playerProfiles[player] = nil
end

function TeamManager.initializePlayer(player, savedData)
    -- Propósito: Inicializar el perfil completo del jugador con datos persistidos.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. savedData puede ser nil o tabla con unlockedMonsters y fragments.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    return getOrCreateProfile(player, savedData)
end

function TeamManager.isMonsterUnlocked(player, monsterId)
    -- Propósito: Verificar si un Beastibit está desbloqueado para el jugador.
    -- Precondiciones:
    --   1. monsterId debe ser string válido.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean
    if type(monsterId) ~= "string" then
        return false
    end
    local profile = getOrCreateProfile(player)
    if profile.unlockedMonsters[monsterId] then
        return true
    end
    return isMonsterUnlockedInBackpack(profile.backpack, monsterId)
end

function TeamManager.unlockMonster(player, monsterId)
    -- Propósito: Incrementar el contador de un Beastibit en el perfil del jugador (+1 copia).
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean wasFirstCopy
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return false
    end

    local profile = getOrCreateProfile(player)
    local wasZero = not isMonsterUnlockedInBackpack(profile.backpack, monsterId)

    profile.unlockedMonsters[monsterId] = true

    local currentCount = getMonsterCountInBackpack(profile.backpack, monsterId)
    setMonsterCountInBackpack(profile.backpack, monsterId, currentCount + 1)

    return wasZero
end

function TeamManager.addFragments(player, monsterId, amount)
    -- Propósito: Sumar fragmentos de un Beastibit al perfil del jugador.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. amount debe ser number >= 0.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: number totalFragments
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return 0
    end

    local safeAmount = math.max(0, math.floor(tonumber(amount) or 0))
    if safeAmount <= 0 then
        return 0
    end

    local profile = getOrCreateProfile(player)
    local fragments = ensureFragmentsTable(profile)

    local current = tonumber(fragments[monsterId]) or 0
    local nextAmount = current + safeAmount
    fragments[monsterId] = nextAmount

    return nextAmount
end

function TeamManager.getFragments(player, monsterId)
    -- Propósito: Obtener la cantidad de fragmentos de un Beastibit.
    -- Precondiciones:
    --   1. monsterId debe ser string.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: number
    if type(monsterId) ~= "string" then
        return 0
    end

    local profile = getOrCreateProfile(player)
    local fragments = ensureFragmentsTable(profile)
    return math.max(0, tonumber(fragments[monsterId]) or 0)
end

function TeamManager.spendFragments(player, monsterId, amount)
    -- Propósito: Gastar fragmentos de un Beastibit si hay suficientes.
    -- Precondiciones:
    --   1. monsterId debe ser string.
    --   2. amount debe ser number > 0.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean success, number remaining
    if type(monsterId) ~= "string" then
        return false, 0
    end

    local safeAmount = math.max(0, math.floor(tonumber(amount) or 0))
    if safeAmount <= 0 then
        return false, 0
    end

    local profile = getOrCreateProfile(player)
    local fragments = ensureFragmentsTable(profile)
    local current = tonumber(fragments[monsterId]) or 0

    if current < safeAmount then
        return false, current
    end

    local remaining = current - safeAmount
    fragments[monsterId] = remaining
    return true, remaining
end

function TeamManager.getUnlockedMonsters(player)
    -- Propósito: Obtener la lista de IDs de Beastibits desbloqueados.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local profile = getOrCreateProfile(player)
    local list = {}
    for monsterId, unlocked in pairs(profile.unlockedMonsters) do
        if unlocked == true then
            table.insert(list, monsterId)
        end
    end
    return list
end

function TeamManager.getAllFragments(player)
    -- Propósito: Obtener todos los fragmentos del jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table
    local profile = getOrCreateProfile(player)
    local fragments = ensureFragmentsTable(profile)
    local copy = {}
    for monsterId, amount in pairs(fragments) do
        if amount > 0 then
            copy[monsterId] = amount
        end
    end
    return copy
end

function TeamManager.getProfileData(player)
    -- Propósito: Obtener datos del perfil para persistencia.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table, table, number, table, table, table
    local profile = getOrCreateProfile(player)
    local unlockedMonsters = {}
    for monsterId, unlocked in pairs(profile.unlockedMonsters) do
        if unlocked == true then
            unlockedMonsters[monsterId] = true
        end
    end
    local fragments = {}
    local fragsTable = ensureFragmentsTable(profile)
    for monsterId, amount in pairs(fragsTable) do
        if amount > 0 then
            fragments[monsterId] = amount
        end
    end
    local bits = getPlayerBits(player)
    local minerals = {}
    for mineralName in pairs(ELEMENT_EVOLUTION_MINERAL) do
        local realName = ELEMENT_EVOLUTION_MINERAL[mineralName]
        local count = getPlayerMineralCount(player, realName)
        if count > 0 then
            minerals[realName] = count
        end
    end
    local evoTable = ensureEvolutionsTable(profile)
    local evolutions = {}
    for monsterId, evo in pairs(evoTable) do
        if evo > 1 then
            evolutions[monsterId] = evo
        end
    end
    local xpTable = ensureXPTable(profile)
    local xp = {}
    for monsterId, amount in pairs(xpTable) do
        if amount > 0 then
            xp[monsterId] = amount
        end
    end
    local monsterCounts = {}
    for _, item in ipairs(profile.backpack) do
        local count = getMonsterCountInBackpack(profile.backpack, item.MonsterId)
        if count > 0 then
            monsterCounts[item.MonsterId] = count
        end
    end
    return unlockedMonsters, fragments, bits, minerals, evolutions, xp, monsterCounts
end

function TeamManager.getMonsterEvolution(player, monsterId)
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return 1
    end
    local profile = getOrCreateProfile(player)
    return getMonsterEvoInProfile(profile, monsterId)
end

function TeamManager.getMonsterXP(player, monsterId)
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return 0
    end
    local profile = getOrCreateProfile(player)
    return getMonsterXPInProfile(profile, monsterId)
end

function TeamManager.getMonsterLevel(player, monsterId)
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return 1
    end
    local profile = getOrCreateProfile(player)
    local xp = getMonsterXPInProfile(profile, monsterId)
    return getLevelForXP(xp)
end

function TeamManager.evolveMonster(player, monsterId)
    -- Propósito: Evolucionar un Beastibit desbloqueado gastando Bits y minerales.
    -- Precondiciones:
    --   1. monsterId debe estar desbloqueado.
    --   2. No puede estar en evolucion maxima (3).
    --   3. Debe tener suficientes Bits y minerales.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean success, string reason, number newEvo
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return false, "monster-data-missing", 1
    end

    local profile = getOrCreateProfile(player)
    if not isMonsterUnlockedInBackpack(profile.backpack, monsterId) then
        return false, "monster-locked", 1
    end

    local currentEvo = getMonsterEvoInProfile(profile, monsterId)
    if currentEvo >= MAX_EVOLUTION then
        return false, "max-evolution", currentEvo
    end

    local cost = EVOLUTION_COST[currentEvo]
    if not cost then
        return false, "no-cost-defined", currentEvo
    end

    local currentXP = getMonsterXPInProfile(profile, monsterId)
    local currentLevel = getLevelForXP(currentXP)
    if currentLevel < cost.levelRequired then
        return false, "insufficient-level", currentEvo
    end

    local mineralName = getEvolutionMineralForMonster(monsterId)
    if not mineralName then
        return false, "no-mineral-mapping", currentEvo
    end

    if not spendPlayerBits(player, cost.bits) then
        return false, "insufficient-bits", currentEvo
    end

    if not spendPlayerMineral(player, mineralName, cost.minerals) then
        player:SetAttribute(BITS_ATTRIBUTE_NAME, getPlayerBits(player) + cost.bits)
        return false, "insufficient-minerals", currentEvo
    end

    local newEvo = currentEvo + 1
    ensureEvolutionsTable(profile)[monsterId] = newEvo
    return true, "ok", newEvo
end

function TeamManager.feedMonster(player, targetMonsterId, foodMonsterId)
    -- Propósito: Alimentar un Beastibit con otro Beastibit duplicado para ganar XP.
    -- Precondiciones:
    --   1. Ambos deben estar desbloqueados.
    --   2. No se puede alimentar a si mismo.
    --   3. No se puede sacrificar el que esta en el equipo activo.
    --   4. foodMonsterId se elimina del perfil del jugador.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean success, string reason, number xpGained, number newXP
    if type(targetMonsterId) ~= "string" or type(foodMonsterId) ~= "string" then
        return false, "invalid-monster-ids", 0, 0
    end

    if targetMonsterId == foodMonsterId then
        return false, "cannot-feed-self", 0, 0
    end

    if MonstersData[targetMonsterId] == nil or MonstersData[foodMonsterId] == nil then
        return false, "monster-data-missing", 0, 0
    end

    local profile = getOrCreateProfile(player)

    if not isMonsterUnlockedInBackpack(profile.backpack, targetMonsterId) then
        return false, "target-locked", 0, 0
    end

    if not isMonsterUnlockedInBackpack(profile.backpack, foodMonsterId) then
        return false, "food-locked", 0, 0
    end

    local currentFoodCount = getMonsterCountInBackpack(profile.backpack, foodMonsterId)

    local teamCopies = 0
    for _, pet in ipairs(profile.duelTeam) do
        if pet.MonsterId == foodMonsterId then
            teamCopies = teamCopies + 1
        end
    end

    if currentFoodCount - 1 < teamCopies then
        return false, "food-in-team", 0, 0
    end

    local foodData = MonstersData[foodMonsterId]
    local rarityKey = type(foodData.Rarity) == "string" and string.lower(foodData.Rarity) or "common"
    local xpBase = XP_BY_RARITY[rarityKey] or 10

    local foodEvo = getMonsterEvoInProfile(profile, foodMonsterId)
    local evoMult = EVO_XP_MULTIPLIER[foodEvo] or 1.0

    local foodXP = getMonsterXPInProfile(profile, foodMonsterId)
    local foodLevel = getLevelForXP(foodXP)
    local levelMult = getLevelMultiplier(foodLevel)

    local xpGained = math.ceil(xpBase * evoMult * levelMult)

    setMonsterCountInBackpack(profile.backpack, foodMonsterId, currentFoodCount - 1)
    if currentFoodCount <= 1 then
        profile.unlockedMonsters[foodMonsterId] = nil
    end

    local xpTable = ensureXPTable(profile)
    local currentXP = getMonsterXPInProfile(profile, targetMonsterId)
    local newXP = currentXP + xpGained
    xpTable[targetMonsterId] = newXP

    if profile.selectedFollowerMonsterId == foodMonsterId then
        profile.selectedFollowerMonsterId = chooseDefaultFollowerMonsterId(profile.backpack, profile.duelTeam)
    end

    return true, "ok", xpGained, newXP
end

function TeamManager.craftMonster(player, monsterId)
    -- Propósito: Craftear un Beastibit gastando fragmentos acumulados.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. Debe tener suficientes fragmentos segun su rareza.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean success, string reason
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return false, "monster-data-missing"
    end

    local profile = getOrCreateProfile(player)
    if isMonsterUnlockedInBackpack(profile.backpack, monsterId) then
        return false, "already-unlocked"
    end

    local data = MonstersData[monsterId]
    local rarityKey = type(data.Rarity) == "string" and string.lower(data.Rarity) or "common"

    local FragmentsDataModule = game:GetService("ReplicatedStorage"):WaitForChild("GameData"):FindFirstChild("FragmentsData")
    local craftCost = 999
    if FragmentsDataModule then
        local FragmentsData = require(FragmentsDataModule)
        craftCost = FragmentsData.getFragmentCraftCost(rarityKey)
    end

    local currentFragments = TeamManager.getFragments(player, monsterId)
    if currentFragments < craftCost then
        return false, "insufficient-fragments"
    end

    local spentOk, remaining = TeamManager.spendFragments(player, monsterId, craftCost)
    if not spentOk then
        return false, "spend-failed"
    end

    TeamManager.unlockMonster(player, monsterId)
    return true, "ok"
end

function TeamManager.calculateTeamHP(team)
    -- Propósito: Calcular la vida total del jugador sumando HP de sus 5 mascotas.
    -- Precondiciones:
    --   1. team debe ser tabla válida de mascotas.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: number
    local totalHP = 0

    for _, pet in ipairs(team) do
        local monster = MonstersData[pet.MonsterId]
        if monster and monster.BaseStats and type(monster.BaseStats.HP) == "number" then
            totalHP += monster.BaseStats.HP
        end
    end

    return totalHP
end

return TeamManager
