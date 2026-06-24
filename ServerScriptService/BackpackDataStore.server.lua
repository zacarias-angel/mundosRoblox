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
		bits = 0,
		minerals = {},
		monsterEvolutions = {},
		monsterXP = {},
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
		if type(saved.bits) == "number" then
			data.bits = math.max(0, math.floor(saved.bits))
		end
		if type(saved.minerals) == "table" then
			for mineralName, count in pairs(saved.minerals) do
				local safeCount = math.max(0, math.floor(tonumber(count) or 0))
				if safeCount > 0 then
					data.minerals[mineralName] = safeCount
				end
			end
		end
		if type(saved.monsterEvolutions) == "table" then
			for monsterId, evo in pairs(saved.monsterEvolutions) do
				local safeEvo = math.clamp(math.floor(tonumber(evo) or 1), 1, 3)
				data.monsterEvolutions[monsterId] = safeEvo
			end
		end
		if type(saved.monsterXP) == "table" then
			for monsterId, xp in pairs(saved.monsterXP) do
				local safeXP = math.max(0, math.floor(tonumber(xp) or 0))
				if safeXP > 0 then
					data.monsterXP[monsterId] = safeXP
				end
			end
		end
	elseif not ok then
		warn("[BackpackDataStore] Error al cargar datos de " .. player.Name .. ": " .. tostring(saved))
	end

	return data
end

function BackpackDataStore.savePlayerData(player, unlockedMonsters, fragments, bits, minerals, monsterEvolutions, monsterXP)
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
	if type(bits) == "number" then
		data.bits = math.max(0, math.floor(bits))
	end
	if type(minerals) == "table" then
		data.minerals = {}
		for mineralName, count in pairs(minerals) do
			local safeCount = math.max(0, math.floor(tonumber(count) or 0))
			if safeCount > 0 then
				data.minerals[mineralName] = safeCount
			end
		end
	end
	if type(monsterEvolutions) == "table" then
		data.monsterEvolutions = {}
		for monsterId, evo in pairs(monsterEvolutions) do
			local safeEvo = math.clamp(math.floor(tonumber(evo) or 1), 1, 3)
			if safeEvo > 1 then
				data.monsterEvolutions[monsterId] = safeEvo
			end
		end
	end
	if type(monsterXP) == "table" then
		data.monsterXP = {}
		for monsterId, xp in pairs(monsterXP) do
			local safeXP = math.max(0, math.floor(tonumber(xp) or 0))
			if safeXP > 0 then
				data.monsterXP[monsterId] = safeXP
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
