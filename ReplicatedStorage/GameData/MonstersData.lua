-- Tipo: ModuleScript
-- Ubicación: ReplicatedStorage/GameData/MonstersData
-- Contexto: Compartido

local Monsters = {}

Monsters.SlimeFuego = {
    Name = "Slime de Fuego",
    Element = "Fuego",
    Rarity = "Common",
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
    BaseStats = {
        Attack = 200,
        HP = 5000,
        Speed = 1,
    },
}

return Monsters
