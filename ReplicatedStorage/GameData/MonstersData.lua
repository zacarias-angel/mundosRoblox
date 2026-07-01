-- Tipo: ModuleScript
-- Ubicación: ReplicatedStorage/GameData/MonstersData
-- Contexto: Compartido

local Monsters = {}

Monsters.SlimeFuego = {
    Name = "Slime de Fuego",
    Element = "Fuego",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 150,
        HP = 3000,
        Speed = 1,
    },
}

Monsters.FireBaby = {
	Name = "FireBaby",
	Element = "Fuego",
	Rarity = "Common",
	StarterUnlocked = true,
	BaseStats = {
		Attack = 150,
		HP = 3000,
		Speed = 1,
	},
	Image = "rbxassetid://0",
}
Monsters.LoboAgua = {
    Name = "Lobo de Agua",
    Element = "Agua",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 145,
        HP = 3000,
        Speed = 1,
    },
}

Monsters.TortugaPlanta = {
    Name = "Tortuga Planta",
    Element = "Planta",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 140,
        HP = 3000,
        Speed = 1,
    },
}

Monsters.HalconElectrico = {
    Name = "Halcon Electrico",
    Element = "Electricidad",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 155,
        HP = 3000,
        Speed = 1,
    },
}

Monsters.GolemRoca = {
    Name = "Golem de Roca",
    Element = "Roca",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 160,
        HP = 3000,
        Speed = 1,
    },
}

Monsters.Demonslime1 = {
	Name = "Demon Slime",
	Element = "Fuego",
	Rarity = "Rare",
	Image = "rbxassetid://133572570435726",
	CompanionFollow = {
		UsePlanetUp = true,
		YawOffsetDeg = 180,
		PitchOffsetDeg = -90,
		RollOffsetDeg = 0,

		Distance = 3.3,
		SideOffset = 0,
		HeightOffset = 3.25,

		LerpSpeed = 6,
		CatchupSpeed = 8,
		CatchupDistance = 7,
		TeleportDistance = 24,
	},
	 
	ModelTemplate = "Demonslime1",
	StarterUnlocked = true,
	BaseStats = {
		Attack = 200,
		HP = 5000,
		Speed = 1,
	},
}

Monsters.ZorroBrasa = {
    Name = "Zorro Brasa",
    Element = "Fuego",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 165,
        HP = 2900,
        Speed = 1,
    },
}

Monsters.MareaLince = {
    Name = "Marea Lince",
    Element = "Agua",
    Rarity = "Common",
    StarterUnlocked = true,
    BaseStats = {
        Attack = 162,
        HP = 2950,
        Speed = 1,
    },
}

Monsters.HongoGuardian = {
    Name = "Hongo Guardian",
    Element = "Planta",
    Rarity = "Rare",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 175,
        HP = 3400,
        Speed = 1,
    },
}

Monsters.RayoMantis = {
    Name = "Rayo Mantis",
    Element = "Electricidad",
    Rarity = "Rare",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 182,
        HP = 3250,
        Speed = 1,
    },
}

Monsters.ObsidianaToro = {
    Name = "Obsidiana Toro",
    Element = "Roca",
    Rarity = "Rare",
    Image = "rbxassetid://0",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 188,
        HP = 3600,
        Speed = 1,
    },
}

Monsters.Bloompup = {
    Name = "Bloompup",
    Element = "Planta",
    Rarity = "Common",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 142,
        HP = 3050,
        Speed = 1,
    },
}

Monsters.Pebblit = {
    Name = "Pebblit",
    Element = "Roca",
    Rarity = "Common",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 155,
        HP = 3100,
        Speed = 1,
    },
}

Monsters.Sparkhog = {
    Name = "Sparkhog",
    Element = "Electricidad",
    Rarity = "Common",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 158,
        HP = 2950,
        Speed = 1,
    },
}

Monsters.Stormram = {
    Name = "Stormram",
    Element = "Electricidad",
    Rarity = "Rare",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 185,
        HP = 3500,
        Speed = 1,
    },
}

Monsters.Infervex = {
    Name = "Infervex",
    Element = "Fuego",
    Rarity = "Epic",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 230,
        HP = 5500,
        Speed = 1,
    },
}

Monsters.Leviacode = {
    Name = "Leviacode",
    Element = "Agua",
    Rarity = "Epic",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 225,
        HP = 5600,
        Speed = 1,
    },
}

Monsters.Elderthorn = {
    Name = "Elderthorn",
    Element = "Planta",
    Rarity = "Epic",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 220,
        HP = 5800,
        Speed = 1,
    },
}

Monsters.Titanox = {
    Name = "Titanox",
    Element = "Roca",
    Rarity = "Legendary",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 260,
        HP = 6500,
        Speed = 1,
    },
}

Monsters.Nullbyte = {
    Name = "Nullbyte",
    Element = "Electricidad",
    Rarity = "Legendary",
    StarterUnlocked = false,
    BaseStats = {
        Attack = 255,
        HP = 6200,
        Speed = 1,
    },
    img = "rbxassetid://0"
}

for monsterId, monsterData in pairs(Monsters) do
	-- Propósito: Garantizar campos mínimos para todos los Beastibit.
	-- Precondiciones:
	--   1. monsterData debe ser tabla válida.
	-- Ubicación: ReplicatedStorage/GameData/MonstersData
	-- Retorna: nil

	if type(monsterData.Image) ~= "string" or monsterData.Image == "" then
		if type(monsterData.img) == "table" then
			monsterData.Image = monsterData.img.evo1 or monsterData.img.evo2 or monsterData.img.evo3
		end
		if (not monsterData.Image or monsterData.Image == "") and type(monsterData.Img) == "table" and #monsterData.Img >= 1 then
			monsterData.Image = monsterData.Img[1]
		end
		if not monsterData.Image or monsterData.Image == "" then
			monsterData.Image = "rbxassetid://0"
		end
	end

	if type(monsterData.ModelTemplate) ~= "string" or monsterData.ModelTemplate == "" then
		monsterData.ModelTemplate = monsterId
	end
end

return Monsters
