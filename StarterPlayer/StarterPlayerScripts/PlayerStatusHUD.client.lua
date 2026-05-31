-- Tipo: LocalScript
-- Ubicación: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
-- Contexto: Cliente

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local BITS_ATTRIBUTE_NAME = "Bits"
local ENERGY_ATTRIBUTE_NAME = "CaptureEnergy"
local ENERGY_MAX_ATTRIBUTE_NAME = "CaptureEnergyMax"
local ENERGY_TICK_SECONDS_ATTRIBUTE_NAME = "CaptureEnergyTickSeconds"
local ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME = "CaptureEnergyRegenAmount"
local NEXT_REGEN_AT_ATTRIBUTE_NAME = "CaptureEnergyNextRegenAt"

local HUD_WIDTH = 220
local HUD_HEIGHT = 92
local SAFE_PADDING = 12
local TOP_OFFSET_UNDER_ROSTER = 56

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local combatDuelState = remoteEvents:WaitForChild("CombatDuelState")

local duelActive = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerStatusHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 25
screenGui.Parent = playerGui

local rootFrame = Instance.new("Frame")
rootFrame.Name = "Root"
rootFrame.AnchorPoint = Vector2.new(0, 0)
rootFrame.Position = UDim2.new(0, 16, 0, 72)
rootFrame.Size = UDim2.new(0, HUD_WIDTH, 0, HUD_HEIGHT)
rootFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
rootFrame.BackgroundTransparency = 0.1
rootFrame.BorderSizePixel = 0
rootFrame.ZIndex = 100
rootFrame.Parent = screenGui
Instance.new("UICorner", rootFrame).CornerRadius = UDim.new(0, 10)

local bitsCard = Instance.new("Frame")
bitsCard.Name = "BitsCard"
bitsCard.Position = UDim2.new(0, 8, 0, 8)
bitsCard.Size = UDim2.new(1, -16, 0, 34)
bitsCard.BackgroundColor3 = Color3.fromRGB(28, 38, 62)
bitsCard.BorderSizePixel = 0
bitsCard.ZIndex = 101
bitsCard.Parent = rootFrame
Instance.new("UICorner", bitsCard).CornerRadius = UDim.new(0, 8)

local bitsTitle = Instance.new("TextLabel")
bitsTitle.Name = "Title"
bitsTitle.Position = UDim2.new(0, 10, 0, 3)
bitsTitle.Size = UDim2.new(0, 90, 1, -6)
bitsTitle.BackgroundTransparency = 1
bitsTitle.Font = Enum.Font.GothamBold
bitsTitle.TextSize = 13
bitsTitle.TextXAlignment = Enum.TextXAlignment.Left
bitsTitle.TextColor3 = Color3.fromRGB(255, 224, 138)
bitsTitle.Text = "Bits"
bitsTitle.ZIndex = 102
bitsTitle.Parent = bitsCard

local bitsValueLabel = Instance.new("TextLabel")
bitsValueLabel.Name = "Value"
bitsValueLabel.AnchorPoint = Vector2.new(1, 0.5)
bitsValueLabel.Position = UDim2.new(1, -10, 0.5, 0)
bitsValueLabel.Size = UDim2.new(0, 110, 0, 20)
bitsValueLabel.BackgroundTransparency = 1
bitsValueLabel.Font = Enum.Font.GothamBlack
bitsValueLabel.TextSize = 15
bitsValueLabel.TextXAlignment = Enum.TextXAlignment.Right
bitsValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
bitsValueLabel.Text = "0"
bitsValueLabel.ZIndex = 102
bitsValueLabel.Parent = bitsCard

local energyCard = Instance.new("Frame")
energyCard.Name = "EnergyCard"
energyCard.Position = UDim2.new(0, 8, 0, 48)
energyCard.Size = UDim2.new(1, -16, 0, 36)
energyCard.BackgroundColor3 = Color3.fromRGB(26, 52, 48)
energyCard.BorderSizePixel = 0
energyCard.ZIndex = 101
energyCard.Parent = rootFrame
Instance.new("UICorner", energyCard).CornerRadius = UDim.new(0, 8)

local energyTitle = Instance.new("TextLabel")
energyTitle.Name = "Title"
energyTitle.Position = UDim2.new(0, 10, 0, 2)
energyTitle.Size = UDim2.new(0, 115, 0, 15)
energyTitle.BackgroundTransparency = 1
energyTitle.Font = Enum.Font.GothamBold
energyTitle.TextSize = 11
energyTitle.TextXAlignment = Enum.TextXAlignment.Left
energyTitle.TextColor3 = Color3.fromRGB(147, 247, 206)
energyTitle.Text = "Capture Energy"
energyTitle.ZIndex = 102
energyTitle.Parent = energyCard

local energyValueLabel = Instance.new("TextLabel")
energyValueLabel.Name = "Value"
energyValueLabel.AnchorPoint = Vector2.new(1, 0)
energyValueLabel.Position = UDim2.new(1, -10, 0, 2)
energyValueLabel.Size = UDim2.new(0, 90, 0, 15)
energyValueLabel.BackgroundTransparency = 1
energyValueLabel.Font = Enum.Font.GothamBold
energyValueLabel.TextSize = 11
energyValueLabel.TextXAlignment = Enum.TextXAlignment.Right
energyValueLabel.TextColor3 = Color3.fromRGB(235, 255, 243)
energyValueLabel.Text = "0/100"
energyValueLabel.ZIndex = 102
energyValueLabel.Parent = energyCard

local regenLabel = Instance.new("TextLabel")
regenLabel.Name = "RegenLabel"
regenLabel.Position = UDim2.new(0, 10, 0, 18)
regenLabel.Size = UDim2.new(1, -20, 0, 14)
regenLabel.BackgroundTransparency = 1
regenLabel.Font = Enum.Font.Gotham
regenLabel.TextSize = 10
regenLabel.TextXAlignment = Enum.TextXAlignment.Left
regenLabel.TextColor3 = Color3.fromRGB(205, 235, 222)
regenLabel.Text = "Recarga: --:--"
regenLabel.ZIndex = 102
regenLabel.Parent = energyCard

local function toInteger(value, fallback)
    -- Proposito: Convertir valores de atributos a enteros seguros para la UI.
    -- Precondiciones:
    --   1. fallback debe ser number.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: number
    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end

    return math.floor(numeric)
end

local function formatNumber(value)
    -- Proposito: Formatear enteros con separador de miles para lectura rapida.
    -- Precondiciones:
    --   1. value debe ser number.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: string
    local text = tostring(math.max(0, toInteger(value, 0)))
    local result = text

    while true do
        local replaced, count = string.gsub(result, "^(%-?%d+)(%d%d%d)", "%1.%2")
        result = replaced
        if count == 0 then
            break
        end
    end

    return result
end

local function formatCountdown(totalSeconds)
    -- Proposito: Convertir segundos restantes a mm:ss para el label de recarga.
    -- Precondiciones:
    --   1. totalSeconds debe ser number.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: string
    local seconds = math.max(0, math.floor(totalSeconds))
    local minutes = math.floor(seconds / 60)
    local remaining = seconds % 60
    return string.format("%02d:%02d", minutes, remaining)
end

local function applySafeAreaLayout()
    -- Proposito: Posicionar HUD respetando safe area y dejando espacio al boton de mochila.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    local insetTopLeft, _ = GuiService:GetGuiInset()
    rootFrame.Position = UDim2.new(
        0,
        insetTopLeft.X + SAFE_PADDING,
        0,
        insetTopLeft.Y + SAFE_PADDING + TOP_OFFSET_UNDER_ROSTER
    )
end

local function refreshHudValues()
    -- Proposito: Redibujar valores de Bits y Energy usando atributos del jugador local.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    local bits = math.max(0, toInteger(player:GetAttribute(BITS_ATTRIBUTE_NAME), 0))
    local maxEnergy = math.max(1, toInteger(player:GetAttribute(ENERGY_MAX_ATTRIBUTE_NAME), 100))
    local energy = math.clamp(toInteger(player:GetAttribute(ENERGY_ATTRIBUTE_NAME), maxEnergy), 0, maxEnergy)

    bitsValueLabel.Text = formatNumber(bits)
    energyValueLabel.Text = tostring(energy) .. "/" .. tostring(maxEnergy)
end

local function refreshRegenLabel()
    -- Proposito: Actualizar el temporizador de recarga de energia visible en HUD.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    local maxEnergy = math.max(1, toInteger(player:GetAttribute(ENERGY_MAX_ATTRIBUTE_NAME), 100))
    local energy = math.clamp(toInteger(player:GetAttribute(ENERGY_ATTRIBUTE_NAME), maxEnergy), 0, maxEnergy)
    local tickSeconds = math.max(1, toInteger(player:GetAttribute(ENERGY_TICK_SECONDS_ATTRIBUTE_NAME), 12 * 60))
    local regenAmount = math.max(1, toInteger(player:GetAttribute(ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME), 5))
    local nextRegenAt = tonumber(player:GetAttribute(NEXT_REGEN_AT_ATTRIBUTE_NAME))

    if energy >= maxEnergy then
        regenLabel.Text = "Recarga +" .. tostring(regenAmount) .. ": Completa"
        return
    end

    if type(nextRegenAt) ~= "number" then
        regenLabel.Text = "Recarga +" .. tostring(regenAmount) .. ": --:--"
        return
    end

    local serverNow = workspace:GetServerTimeNow()
    local timeLeft = math.max(0, nextRegenAt - serverNow)

    if timeLeft <= 0 then
        timeLeft = tickSeconds
    end

    regenLabel.Text = "Recarga +" .. tostring(regenAmount) .. ": " .. formatCountdown(timeLeft)
end

local function refreshHudVisibility()
    -- Proposito: Mostrar u ocultar la UI persistente segun estado de duelo.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    rootFrame.Visible = not duelActive
end

local function handleDuelState(data)
    -- Proposito: Escuchar eventos de combate para ocultar/mostrar HUD persistente.
    -- Precondiciones:
    --   1. data debe ser tabla con campo type string.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    if type(data) ~= "table" or type(data.type) ~= "string" then
        return
    end

    if data.type == "duel-intro" or data.type == "countdown" or data.type == "duel-started" then
        duelActive = true
        refreshHudVisibility()
        return
    end

    if data.type == "duel-ended" or data.type == "challenge-declined" or data.type == "challenge-expired" or data.type == "challenge-failed" then
        duelActive = false
        refreshHudVisibility()
        return
    end
end

local function connectSignals()
    -- Proposito: Conectar cambios de atributos, viewport y remotos para refrescar HUD.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    local function onEconomyAttributeChanged()
        refreshHudValues()
        refreshRegenLabel()
    end

    player:GetAttributeChangedSignal(BITS_ATTRIBUTE_NAME):Connect(onEconomyAttributeChanged)
    player:GetAttributeChangedSignal(ENERGY_ATTRIBUTE_NAME):Connect(onEconomyAttributeChanged)
    player:GetAttributeChangedSignal(ENERGY_MAX_ATTRIBUTE_NAME):Connect(onEconomyAttributeChanged)
    player:GetAttributeChangedSignal(ENERGY_TICK_SECONDS_ATTRIBUTE_NAME):Connect(onEconomyAttributeChanged)
    player:GetAttributeChangedSignal(ENERGY_REGEN_AMOUNT_ATTRIBUTE_NAME):Connect(onEconomyAttributeChanged)
    player:GetAttributeChangedSignal(NEXT_REGEN_AT_ATTRIBUTE_NAME):Connect(onEconomyAttributeChanged)

    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applySafeAreaLayout)
    end

    combatDuelState.OnClientEvent:Connect(handleDuelState)

    RunService.Heartbeat:Connect(function()
        refreshRegenLabel()
    end)
end

local function init()
    -- Proposito: Inicializar HUD persistente de estado del jugador.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/PlayerStatusHUD.client
    -- Retorna: nil
    applySafeAreaLayout()
    refreshHudValues()
    refreshRegenLabel()
    refreshHudVisibility()
    connectSignals()
end

init()
