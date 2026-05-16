-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/TeamManager
-- Contexto: Servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local TeamManager = {}

local TEAM_SIZE = 5

local playerTeams = {}

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
    local existing = playerTeams[player]
    if existing then
        return cloneTeam(existing)
    end

    local defaultTeam = getDefaultTeam()
    playerTeams[player] = defaultTeam
    return cloneTeam(defaultTeam)
end

function TeamManager.getTeam(player)
    -- Propósito: Obtener el equipo actual sin crear uno nuevo.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: table|nil
    local team = playerTeams[player]
    if not team then
        return nil
    end
    return cloneTeam(team)
end

function TeamManager.clearTeam(player)
    -- Propósito: Liberar el equipo en memoria cuando un jugador se desconecta.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/TeamManager
    -- Retorna: nil
    playerTeams[player] = nil
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
