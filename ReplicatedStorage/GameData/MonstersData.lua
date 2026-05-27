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
    StarterUnlocked = false,
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
    StarterUnlocked = false,
    BaseStats = {
        Attack = 188,
        HP = 3600,
        Speed = 1,
    },
}

return Monsters
