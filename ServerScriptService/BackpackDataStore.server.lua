-- Tipo: ModuleScript
-- Ubicacion: ServerScriptService/BackpackDataStore
-- Contexto: Servidor

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local BackpackDataStore = {}

local DATASTORE_NAME = "BackpackV1"
local DATASTORE_KEY_PREFIX = "player_"

local backpackStore = nil

if not RunService:IsStudio() then
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		backpackStore = store
	else
		warn("[BackpackDataStore] No se pudo obtener DataStore: " .. tostring(store))
	end
end

function BackpackDataStore.loadPlayerData(player)
	local data = {
		unlockedMonsters = {},
		fragments = {},
	}

	if not backpackStore then
		return data
	end

	local key = DATASTORE_KEY_PREFIX .. tostring(player.UserId)
	local ok, saved = pcall(function()
		return backpackStore:GetAsync(key)
	end)

	if ok and type(saved) == "table" then
		if type(saved.unlockedMonsters) == "table" then
			for monsterId, unlocked in pairs(saved.unlockedMonsters) do
				data.unlockedMonsters[monsterId] = unlocked == true
			end
		end
		if type(saved.fragments) == "table" then
			for monsterId, amount in pairs(saved.fragments) do
				data.fragments[monsterId] = math.max(0, math.floor(tonumber(amount) or 0))
			end
		end
	elseif not ok then
		warn("[BackpackDataStore] Error al cargar datos de " .. player.Name .. ": " .. tostring(saved))
	end

	return data
end

function BackpackDataStore.savePlayerData(player, unlockedMonsters, fragments)
	if not backpackStore then
		return
	end

	local data = {}
	if type(unlockedMonsters) == "table" then
		data.unlockedMonsters = {}
		for monsterId, unlocked in pairs(unlockedMonsters) do
			if unlocked == true then
				data.unlockedMonsters[monsterId] = true
			end
		end
	end
	if type(fragments) == "table" then
		data.fragments = {}
		for monsterId, amount in pairs(fragments) do
			local safeAmount = math.floor(tonumber(amount) or 0)
			if safeAmount > 0 then
				data.fragments[monsterId] = safeAmount
			end
		end
	end

	local key = DATASTORE_KEY_PREFIX .. tostring(player.UserId)
	local ok, err = pcall(function()
		backpackStore:SetAsync(key, data)
	end)
	if not ok then
		warn("[BackpackDataStore] Error al guardar datos de " .. player.Name .. ": " .. tostring(err))
	end
end

return BackpackDataStore
