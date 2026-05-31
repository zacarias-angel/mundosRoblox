-- Tipo: Script
-- Ubicación: ServerScriptService/EconomyState.server
-- Contexto: Servidor

local Players = game:GetService("Players")

local BITS_ATTRIBUTE_NAME = "Bits"
local ENERGY_ATTRIBUTE_NAME = "CaptureEnergy"
local ENERGY_MAX_ATTRIBUTE_NAME = "CaptureEnergyMax"
local ENERGY_TICK_SECONDS_ATTRIBUTE_NAME = "CaptureEnergyTickSeconds"
local ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME = "CaptureEnergyRegenAmount"
local NEXT_REGEN_AT_ATTRIBUTE_NAME = "CaptureEnergyNextRegenAt"

local DEFAULT_BITS = 0
local DEFAULT_ENERGY_MAX = 100
local DEFAULT_ENERGY_TICK_SECONDS = 12 * 60
local DEFAULT_ENERGY_REGEN_AMOUNT = 5

local LOOP_INTERVAL_SECONDS = 1

local function getServerTimestamp()
    -- Proposito: Obtener un timestamp confiable del servidor para calculos de regen.
    -- Precondiciones: Ninguna.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: number
    return workspace:GetServerTimeNow()
end

local function toInteger(value, fallback)
    -- Proposito: Normalizar cualquier valor numerico a entero seguro.
    -- Precondiciones:
    --   1. fallback debe ser number.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: number
    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end

    return math.floor(numeric)
end

local function clampMin(value, minValue)
    -- Proposito: Aplicar limite inferior para evitar valores invalidos.
    -- Precondiciones:
    --   1. value y minValue deben ser number.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: number
    if value < minValue then
        return minValue
    end

    return value
end

local function getEnergyConfig(player)
    -- Proposito: Leer y sanear maximo/tick de energia configurados en atributos.
    -- Precondiciones:
    --   1. player debe ser Player valido.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: number, number, number
    local maxEnergy = clampMin(toInteger(player:GetAttribute(ENERGY_MAX_ATTRIBUTE_NAME), DEFAULT_ENERGY_MAX), 1)
    local tickSeconds = clampMin(toInteger(player:GetAttribute(ENERGY_TICK_SECONDS_ATTRIBUTE_NAME), DEFAULT_ENERGY_TICK_SECONDS), 1)
    local regenAmount = clampMin(toInteger(player:GetAttribute(ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME), DEFAULT_ENERGY_REGEN_AMOUNT), 1)

    if player:GetAttribute(ENERGY_MAX_ATTRIBUTE_NAME) ~= maxEnergy then
        player:SetAttribute(ENERGY_MAX_ATTRIBUTE_NAME, maxEnergy)
    end

    if player:GetAttribute(ENERGY_TICK_SECONDS_ATTRIBUTE_NAME) ~= tickSeconds then
        player:SetAttribute(ENERGY_TICK_SECONDS_ATTRIBUTE_NAME, tickSeconds)
    end

    if player:GetAttribute(ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME) ~= regenAmount then
        player:SetAttribute(ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME, regenAmount)
    end

    return maxEnergy, tickSeconds, regenAmount
end

local function ensurePlayerEconomyAttributes(player)
    -- Proposito: Crear atributos base de economia para cada jugador al entrar.
    -- Precondiciones:
    --   1. player debe ser Player valido.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: nil
    local bits = clampMin(toInteger(player:GetAttribute(BITS_ATTRIBUTE_NAME), DEFAULT_BITS), 0)
    local maxEnergy, tickSeconds = getEnergyConfig(player)
    local energy = math.clamp(toInteger(player:GetAttribute(ENERGY_ATTRIBUTE_NAME), maxEnergy), 0, maxEnergy)
    local nextRegenAt = tonumber(player:GetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME))

    if player:GetAttribute(BITS_ATTRIBUTE_NAME) ~= bits then
        player:SetAttribute(BITS_ATTRIBUTE_NAME, bits)
    end

    if player:GetAttribute(ENERGY_ATTRIBUTE_NAME) ~= energy then
        player:SetAttribute(ENERGY_ATTRIBUTE_NAME, energy)
    end

    if type(nextRegenAt) ~= "number" then
        player:SetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME, getServerTimestamp() + tickSeconds)
    end
end

local function clampEconomyAttributes(player)
    -- Proposito: Revalidar atributos de economia si otro script escribe valores invalidos.
    -- Precondiciones:
    --   1. player debe ser Player valido.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: nil
    local bits = clampMin(toInteger(player:GetAttribute(BITS_ATTRIBUTE_NAME), DEFAULT_BITS), 0)
    local maxEnergy, tickSeconds = getEnergyConfig(player)
    local energy = math.clamp(toInteger(player:GetAttribute(ENERGY_ATTRIBUTE_NAME), maxEnergy), 0, maxEnergy)
    local nextRegenAt = tonumber(player:GetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME))

    if player:GetAttribute(BITS_ATTRIBUTE_NAME) ~= bits then
        player:SetAttribute(BITS_ATTRIBUTE_NAME, bits)
    end

    if player:GetAttribute(ENERGY_ATTRIBUTE_NAME) ~= energy then
        player:SetAttribute(ENERGY_ATTRIBUTE_NAME, energy)
    end

    if type(nextRegenAt) ~= "number" then
        player:SetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME, getServerTimestamp() + tickSeconds)
    end
end

local function applyEnergyRegen(player, now)
    -- Proposito: Aplicar regeneracion de energia por ticks segun el reloj del servidor.
    -- Precondiciones:
    --   1. player debe ser Player valido.
    --   2. now debe ser number con timestamp del servidor.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: nil
    local maxEnergy, tickSeconds, regenAmount = getEnergyConfig(player)
    local energy = math.clamp(toInteger(player:GetAttribute(ENERGY_ATTRIBUTE_NAME), maxEnergy), 0, maxEnergy)
    local nextRegenAt = tonumber(player:GetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME))

    if type(nextRegenAt) ~= "number" then
        nextRegenAt = now + tickSeconds
        player:SetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME, nextRegenAt)
    end

    if energy >= maxEnergy then
        if nextRegenAt < now then
            player:SetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME, now + tickSeconds)
        end
        return
    end

    if now < nextRegenAt then
        return
    end

    local elapsed = now - nextRegenAt
    local ticks = math.floor(elapsed / tickSeconds) + 1
    local newEnergy = math.min(maxEnergy, energy + (ticks * regenAmount))
    local newNextRegenAt = nextRegenAt + (ticks * tickSeconds)

    player:SetAttribute(ENERGY_ATTRIBUTE_NAME, newEnergy)

    if newEnergy >= maxEnergy then
        player:SetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME, now + tickSeconds)
    else
        player:SetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME, newNextRegenAt)
    end
end

local function onPlayerAdded(player)
    -- Proposito: Inicializar economia del jugador y dejar atributos listos para UI.
    -- Precondiciones:
    --   1. player debe ser Player valido.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: nil
    ensurePlayerEconomyAttributes(player)

    player:GetAttributeChangedSignal(BITS_ATTRIBUTE_NAME):Connect(function()
        clampEconomyAttributes(player)
    end)

    player:GetAttributeChangedSignal(ENERGY_ATTRIBUTE_NAME):Connect(function()
        clampEconomyAttributes(player)
    end)

    player:GetAttributeChangedSignal(ENERGY_MAX_ATTRIBUTE_NAME):Connect(function()
        clampEconomyAttributes(player)
    end)

    player:GetAttributeChangedSignal(ENERGY_TICK_SECONDS_ATTRIBUTE_NAME):Connect(function()
        clampEconomyAttributes(player)
    end)

    player:GetAttributeChangedSignal(ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME):Connect(function()
        clampEconomyAttributes(player)
    end)

    player:GetAttributeChangedSignal(NEXT_REGEN_AT_ATTRIBUTE_NAME):Connect(function()
        clampEconomyAttributes(player)
    end)
end

local function bootstrapExistingPlayers()
    -- Proposito: Inicializar jugadores ya conectados cuando el script empieza tarde.
    -- Precondiciones: Ninguna.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: nil
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
end

local function runEnergyLoop()
    -- Proposito: Ejecutar el loop central de regeneracion para todos los jugadores.
    -- Precondiciones: Ninguna.
    -- Ubicacion: ServerScriptService/EconomyState.server
    -- Retorna: nil
    while true do
        local now = getServerTimestamp()

        for _, player in ipairs(Players:GetPlayers()) do
            applyEnergyRegen(player, now)
        end

        task.wait(LOOP_INTERVAL_SECONDS)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
bootstrapExistingPlayers()
runEnergyLoop()
