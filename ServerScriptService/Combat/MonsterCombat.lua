-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/MonsterCombat
-- Contexto: Servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local MonsterCombat = {}

local function elementWasActivated(element, activatedElements)
    -- Propósito: Verificar si un elemento apareció al menos una vez en la jugada.
    -- Precondiciones:
    --   1. element debe ser string.
    --   2. activatedElements debe ser tabla set.
    -- Ubicación: ServerScriptService/Combat/MonsterCombat
    -- Retorna: boolean
    return type(element) == "string" and type(activatedElements) == "table" and activatedElements[element] == true
end

function MonsterCombat.calculateTeamDamage(team, comboSummary)
    -- Propósito: Calcular daño total del equipo usando total de combos del movimiento.
    -- Precondiciones:
    --   1. team debe ser tabla de mascotas válidas.
    --   2. comboSummary.totalCombos debe ser number.
    --   3. comboSummary.activatedElements debe ser tabla set.
    -- Ubicación: ServerScriptService/Combat/MonsterCombat
    -- Retorna: table
    local totalDamage = 0
    local totalCombos = 0
    local activatedElements = {}

    if type(comboSummary) == "table" then
        if type(comboSummary.totalCombos) == "number" then
            totalCombos = math.max(0, math.floor(comboSummary.totalCombos))
        end
        if type(comboSummary.activatedElements) == "table" then
            activatedElements = comboSummary.activatedElements
        end
    end

    local damageByPet = {}

    for index, pet in ipairs(team) do
        local petDamage = 0
        local petElement = "Desconocido"
        local monsterName = "Desconocido"

        if type(pet) == "table" and type(pet.MonsterId) == "string" then
            local monsterData = MonstersData[pet.MonsterId]
            if monsterData then
                monsterName = monsterData.Name or pet.MonsterId
                petElement = monsterData.Element or "Desconocido"

                local baseAttack = 0
                if monsterData.BaseStats and type(monsterData.BaseStats.Attack) == "number" then
                    baseAttack = monsterData.BaseStats.Attack
                end

                if totalCombos > 0 and elementWasActivated(petElement, activatedElements) then
                    petDamage = math.floor(baseAttack * totalCombos)
                end
            end
        end

        totalDamage += petDamage

        table.insert(damageByPet, {
            slot = index,
            monsterId = pet.MonsterId,
            monsterName = monsterName,
            element = petElement,
            damage = petDamage,
        })
    end

    return {
        totalCombos = totalCombos,
        totalDamage = totalDamage,
        damageByPet = damageByPet,
    }
end

return MonsterCombat
