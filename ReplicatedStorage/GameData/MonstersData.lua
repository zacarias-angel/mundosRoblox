-- Tipo: ModuleScript
-- Ubicación: ReplicatedStorage/GameData/MonstersData
-- Contexto: Compartido

local Monsters = {}

local function createDefaultEvolutionImages()
    -- Propósito: Crear arreglo base de 3 slots de imagen para evoluciones.
    -- Precondiciones: Ninguna.
    -- Ubicación: ReplicatedStorage/GameData/MonstersData
    -- Retorna: table
    return {
        "rbxassetid://0",
        "rbxassetid://0",
        "rbxassetid://0",
    }
end

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
    img = {
        evo1 = "rbxassetid://0",
        evo2 = "rbxassetid://0",
        evo3 = "rbxassetid://0",
    },
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
	 
	evoActual = 1,
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
    img = {
        evo1 = "rbxassetid://0",
        evo2 = "rbxassetid://0",
        evo3 = "rbxassetid://0",
    },
    evoActual = 1,
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
}

for monsterId, monsterData in pairs(Monsters) do
    -- Propósito: Garantizar nuevos campos visuales y de evolución para todos los Beastibit.
    -- Precondiciones:
    --   1. monsterData debe ser tabla válida.
    -- Ubicación: ReplicatedStorage/GameData/MonstersData
    -- Retorna: nil
    if type(monsterData.Img) ~= "table" then
        monsterData.Img = createDefaultEvolutionImages()
    end

    if #monsterData.Img < 3 then
        for i = #monsterData.Img + 1, 3 do
            monsterData.Img[i] = "rbxassetid://0"
        end
    end

    if type(monsterData.img) ~= "table" then
        monsterData.img = {
            evo1 = monsterData.Img[1] or "rbxassetid://0",
            evo2 = monsterData.Img[2] or "rbxassetid://0",
            evo3 = monsterData.Img[3] or "rbxassetid://0",
        }
    else
        if type(monsterData.img.evo1) ~= "string" or monsterData.img.evo1 == "" then
            monsterData.img.evo1 = monsterData.Img[1] or "rbxassetid://0"
        end
        if type(monsterData.img.evo2) ~= "string" or monsterData.img.evo2 == "" then
            monsterData.img.evo2 = monsterData.Img[2] or "rbxassetid://0"
        end
        if type(monsterData.img.evo3) ~= "string" or monsterData.img.evo3 == "" then
            monsterData.img.evo3 = monsterData.Img[3] or "rbxassetid://0"
        end
    end

    local evoRaw = monsterData.evoActual
    if type(evoRaw) ~= "number" then
        evoRaw = monsterData.Evo
    end
    local normalizedEvo = math.floor(tonumber(evoRaw) or 1)
    normalizedEvo = math.clamp(normalizedEvo, 1, 3)
    monsterData.evoActual = normalizedEvo
    monsterData.Evo = normalizedEvo

    monsterData.Img[1] = monsterData.img.evo1
    monsterData.Img[2] = monsterData.img.evo2
    monsterData.Img[3] = monsterData.img.evo3

    if type(monsterData.ModelTemplate) ~= "string" or monsterData.ModelTemplate == "" then
        monsterData.ModelTemplate = monsterId
    end
end

return Monsters
