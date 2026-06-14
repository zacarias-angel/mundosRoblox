-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/TeamManager
-- Contexto: Servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local TeamManager = {}

local TEAM_SIZE = 5

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
            Unlocked = item.Unlocked == true,
        }
    end
    return copy
end

local function isMonsterUnlockedInBackpack(backpack, monsterId)
    -- Propósito: Verificar si un Beastibit está desbloqueado dentro de la mochila.
    -- Precondiciones:
    --   1. backpack debe ser tabla.
    --   2. monsterId debe ser string.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean
    if type(backpack) ~= "table" or type(monsterId) ~= "string" then
        return false
    end

    for _, item in ipairs(backpack) do
        if item.MonsterId == monsterId and item.Unlocked == true then
            return true
        end
    end

    return false
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
        table.insert(backpack, {
            MonsterId = monsterId,
            Unlocked = data and data.StarterUnlocked == true or false,
        })
    end

    return backpack
end

local function chooseDefaultFollowerMonsterId(backpack, fallbackTeam)
    -- Propósito: Elegir Beastibit seguidor por defecto priorizando desbloqueados en mochila.
    -- Precondiciones:
    --   1. backpack y fallbackTeam deben ser tablas.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: string
    local preferredMonsterId = fallbackTeam[1] and fallbackTeam[1].MonsterId or nil
    if type(preferredMonsterId) == "string" and isMonsterUnlockedInBackpack(backpack, preferredMonsterId) then
        return preferredMonsterId
    end

    for _, item in ipairs(backpack) do
        if item.Unlocked == true and type(item.MonsterId) == "string" then
            return item.MonsterId
        end
    end

    if fallbackTeam[1] and type(fallbackTeam[1].MonsterId) == "string" then
        return fallbackTeam[1].MonsterId
    end

    return "SlimeFuego"
end

local function ensureBackpackHasTeamMonsters(backpack, team)
    -- Propósito: Garantizar que los Beastibit del equipo existan y estén desbloqueados en mochila.
    -- Precondiciones:
    --   1. backpack y team deben ser tablas.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: nil
    for _, pet in ipairs(team) do
        local found = false
        for _, item in ipairs(backpack) do
            if item.MonsterId == pet.MonsterId then
                item.Unlocked = true
                found = true
                break
            end
        end

        if not found then
            table.insert(backpack, {
                MonsterId = pet.MonsterId,
                Unlocked = true,
            })
        end
    end
end

local function getOrCreateProfile(player, savedData)
    -- Propósito: Obtener o inicializar perfil en memoria del jugador (equipo, mochila, seguidor, fragmentos).
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. savedData puede ser nil o tabla con unlockedMonsters y fragments.
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
    end

    for _, item in ipairs(backpack) do
        if item.Unlocked == true then
            unlockedMonsters[item.MonsterId] = true
        end
    end

    local profile = {
        duelTeam = defaultTeam,
        backpack = backpack,
        selectedFollowerMonsterId = chooseDefaultFollowerMonsterId(backpack, defaultTeam),
        unlockedMonsters = unlockedMonsters,
        fragments = fragments,
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
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean isValid, string reason
    local isValid, reason = TeamManager.validateTeam(team)
    if not isValid then
        return false, reason
    end

    local profile = getOrCreateProfile(player)
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
    -- Propósito: Desbloquear un Beastibit en el perfil y mochila del jugador.
    -- Precondiciones:
    --   1. monsterId debe existir en MonstersData.
    --   2. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: boolean wasNewlyUnlocked
    if type(monsterId) ~= "string" or MonstersData[monsterId] == nil then
        return false
    end

    local profile = getOrCreateProfile(player)

    if profile.unlockedMonsters[monsterId] then
        return false
    end

    profile.unlockedMonsters[monsterId] = true

    local foundInBackpack = false
    for _, item in ipairs(profile.backpack) do
        if item.MonsterId == monsterId then
            item.Unlocked = true
            foundInBackpack = true
            break
        end
    end

    if not foundInBackpack then
        table.insert(profile.backpack, {
            MonsterId = monsterId,
            Unlocked = true,
        })
    end

    return true
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
    -- Retorna: table, table
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
    return unlockedMonsters, fragments
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
