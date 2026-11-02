-- Tipo: ModuleScript
-- Ubicacion: ReplicatedStorage/GameData/FragmentsData
-- Contexto: Compartido

local FragmentsData = {}

FragmentsData.FRAGMENT_DROP_BY_RARITY = {
	common = 5,
	rare = 15,
	epic = 25,
}

FragmentsData.FRAGMENT_CRAFT_BY_RARITY = {
	common = 30,
	rare = 80,
	epic = 150,
}

FragmentsData.CAPTURE_CHANCE_BY_RARITY = {
	common = 0.60,
	rare = 0.40,
	epic = 0.05,
}

function FragmentsData.normalizeRarityKey(rarity)
	if type(rarity) ~= "string" then
		return "common"
	end

	local lowered = string.lower(string.match(rarity, "^%s*(.-)%s*$") or "")
	if lowered == "" then
		return "common"
	end

	return lowered
end

function FragmentsData.getCaptureChance(rarity)
	local key = FragmentsData.normalizeRarityKey(rarity)
	return FragmentsData.CAPTURE_CHANCE_BY_RARITY[key] or 0
end

function FragmentsData.getFragmentDrop(rarity)
	local key = FragmentsData.normalizeRarityKey(rarity)
	return FragmentsData.FRAGMENT_DROP_BY_RARITY[key] or 0
end

function FragmentsData.getFragmentCraftCost(rarity)
	local key = FragmentsData.normalizeRarityKey(rarity)
	return FragmentsData.FRAGMENT_CRAFT_BY_RARITY[key] or 999
end

return FragmentsData
