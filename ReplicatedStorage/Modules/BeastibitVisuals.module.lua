-- Tipo: ModuleScript
-- Ubicación: ReplicatedStorage/Modules/BeastibitVisuals.module
-- Contexto: Compartido

local BeastibitVisuals = {}

local function normalizeAssetId(raw)
    -- Propósito: Normalizar distintos formatos de id de imagen a string utilizable por ImageLabel.
    -- Precondiciones:
    --   1. raw puede ser number, string o nil.
    -- Ubicación: ReplicatedStorage/Modules/BeastibitVisuals.module
    -- Retorna: string
    if type(raw) == "number" then
        return "rbxassetid://" .. tostring(math.floor(raw))
    end

    if type(raw) ~= "string" or raw == "" then
        return "rbxassetid://0"
    end

    if string.find(raw, "rbxassetid://", 1, true) then
        return raw
    end

    local numeric = tonumber(raw)
    if numeric then
        return "rbxassetid://" .. tostring(math.floor(numeric))
    end

    return raw
end

local function getEvolutionStage(monsterData)
    -- Propósito: Resolver evolución actual de Beastibit con clamp seguro entre 1 y 3.
    -- Precondiciones:
    --   1. monsterData puede ser tabla o nil.
    -- Ubicación: ReplicatedStorage/Modules/BeastibitVisuals.module
    -- Retorna: number
    if type(monsterData) ~= "table" then
        return 1
    end

    local raw = monsterData.evoActual
    if type(raw) ~= "number" then
        raw = monsterData.Evo
    end

    local stage = tonumber(raw) or 1
    stage = math.floor(stage)
    return math.clamp(stage, 1, 3)
end

function BeastibitVisuals.getImageByMonsterData(monsterData)
    -- Propósito: Resolver imagen de Beastibit según su evolución actual y schema soportado.
    -- Precondiciones:
    --   1. monsterData puede ser tabla o nil.
    -- Ubicación: ReplicatedStorage/Modules/BeastibitVisuals.module
    -- Retorna: string
    if type(monsterData) ~= "table" then
        return "rbxassetid://0"
    end

    local stage = getEvolutionStage(monsterData)

    if type(monsterData.img) == "table" then
        local key = "evo" .. tostring(stage)
        local image = normalizeAssetId(monsterData.img[key])
        if image ~= "rbxassetid://0" then
            return image
        end
    end

    if type(monsterData.Img) == "table" then
        local image = normalizeAssetId(monsterData.Img[stage])
        if image ~= "rbxassetid://0" then
            return image
        end
    end

    local legacy = monsterData.Image or monsterData.ImageId or monsterData.Icon or monsterData.Thumbnail
    return normalizeAssetId(legacy)
end

function BeastibitVisuals.getImageByMonsterId(monstersData, monsterId)
    -- Propósito: Resolver imagen de Beastibit por MonsterId usando tabla de data.
    -- Precondiciones:
    --   1. monstersData debe ser tabla.
    --   2. monsterId puede ser string o nil.
    -- Ubicación: ReplicatedStorage/Modules/BeastibitVisuals.module
    -- Retorna: string
    if type(monstersData) ~= "table" or type(monsterId) ~= "string" then
        return "rbxassetid://0"
    end

    local monsterData = monstersData[monsterId]
    return BeastibitVisuals.getImageByMonsterData(monsterData)
end

return BeastibitVisuals
