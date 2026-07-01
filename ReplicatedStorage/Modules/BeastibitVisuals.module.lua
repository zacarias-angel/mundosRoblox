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

function BeastibitVisuals.getImageByMonsterData(monsterData)
	-- Propósito: Resolver imagen de Beastibit (una sola forma, sin evoluciones).
	-- Precondiciones:
	--   1. monsterData puede ser tabla o nil.
	-- Ubicación: ReplicatedStorage/Modules/BeastibitVisuals.module
	-- Retorna: string
	if type(monsterData) ~= "table" then
		return "rbxassetid://0"
	end

	local image = normalizeAssetId(monsterData.Image)
	if image ~= "rbxassetid://0" then
		return image
	end

	if type(monsterData.img) == "table" then
		image = normalizeAssetId(monsterData.img.evo1 or monsterData.img.evo2 or monsterData.img.evo3)
		if image ~= "rbxassetid://0" then
			return image
		end
	end

	if type(monsterData.Img) == "table" and #monsterData.Img >= 1 then
		image = normalizeAssetId(monsterData.Img[1])
		if image ~= "rbxassetid://0" then
			return image
		end
	end

	local legacy = monsterData.Icon or monsterData.Thumbnail or monsterData.ImageId
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
