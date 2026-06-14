-- Tipo: ModuleScript
-- Ubicacion: ReplicatedStorage/GameData/SpawnMatrix
-- Contexto: Compartido

local SpawnMatrix = {}

SpawnMatrix.MUNDO_1 = "Bitara Prime"
SpawnMatrix.MUNDO_2 = "Korvaxis"

SpawnMatrix.BIOMES_MUNDO_1 = {
	Volcanico = {
		name = "Volcanico",
		levels = { min = 1, max = 8 },
		monsters = {
			"SlimeFuego",
			"ZorroBrasa",
			"Demonslime1",
		},
	},
	Oceanico = {
		name = "Oceanico",
		levels = { min = 3, max = 10 },
		monsters = {
			"LoboAgua",
			"MareaLince",
		},
	},
	Forestal = {
		name = "Forestal",
		levels = { min = 5, max = 12 },
		monsters = {
			"TortugaPlanta",
			"HongoGuardian",
			"Bloompup",
		},
	},
	Tormenta = {
		name = "Tormenta",
		levels = { min = 8, max = 16 },
		monsters = {
			"HalconElectrico",
			"RayoMantis",
		},
	},
}

SpawnMatrix.BIOMES_MUNDO_2 = {
	Montania = {
		name = "Montania",
		levels = { min = 15, max = 24 },
		monsters = {
			"GolemRoca",
			"ObsidianaToro",
			"Pebblit",
		},
	},
	Energia = {
		name = "Energia",
		levels = { min = 22, max = 35 },
		monsters = {
			"Sparkhog",
			"Stormram",
		},
	},
}

SpawnMatrix.MINERALES_MUNDO_1 = {
	Volcanico = "Magma Core",
	Oceanico = "Aqua Shard",
	Forestal = "Root Crystal",
	Tormenta = "Volt Core",
}

SpawnMatrix.MINERALES_MUNDO_2 = {
	Montania = "Stone Heart",
	["Energia"] = "Pulse Fragment",
}

SpawnMatrix.MINERAL_DROP_CHANCE = 0.20

function SpawnMatrix.getBiomeConfig(worldIndex, biomeName)
	local biomes
	if worldIndex == 1 then
		biomes = SpawnMatrix.BIOMES_MUNDO_1
	elseif worldIndex == 2 then
		biomes = SpawnMatrix.BIOMES_MUNDO_2
	else
		return nil
	end

	return biomes[biomeName]
end

function SpawnMatrix.getMineralForBiome(worldIndex, biomeName)
	local minerals
	if worldIndex == 1 then
		minerals = SpawnMatrix.MINERALES_MUNDO_1
	elseif worldIndex == 2 then
		minerals = SpawnMatrix.MINERALES_MUNDO_2
	else
		return nil
	end

	return minerals[biomeName]
end

return SpawnMatrix
