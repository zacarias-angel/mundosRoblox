-- Tipo: LocalScript
-- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
-- Contexto: Cliente

--[[
    UI cliente del tablero match-3 por swap.
    El jugador presiona una ficha, arrastra hacia una adyacente y al soltar
    envía un swap al servidor. El servidor valida, resuelve matches y sincroniza.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatGrid = require(Modules:WaitForChild("CombatGrid.module"))

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatSubmit = RemoteEvents:WaitForChild("CombatSubmit")
local CombatSync = RemoteEvents:WaitForChild("CombatSync")
local CombatChallengeRequest = RemoteEvents:WaitForChild("CombatChallengeRequest")
local CombatChallengeResponse = RemoteEvents:WaitForChild("CombatChallengeResponse")
local CombatDuelState = RemoteEvents:WaitForChild("CombatDuelState")

local COLS, ROWS = CombatGrid.getSize()
local CELL_SIZE = 64
local CELL_PADDING = 4
local TURN_TIME = 5
local DRAG_THRESHOLD = 20
local SWAP_COOLDOWN = 0.07
local COMBO_SCALE_OUT_TIME = 0.12
local COMBO_STAGGER_TIME = 0.06
local CASCADE_GAP_TIME = 0.08
local FALL_TWEEN_TIME = 0.24
local BOUNCE_DURATION = 0.12
local PULSE_DURATION = 0.15
local COMBO_WAIT_FADE_DELAY = 0.5
local COMBO_FINAL_FADE_TIME = 0.4
local CHALLENGE_DISTANCE = 10
local COMBAT_DEBUG = true
local IS_TOUCH_DEVICE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local MAX_DUEL_HP = 15000
local DUEL_INTRO_CARD_WIDTH = 320
local DUEL_INTRO_CARD_HEIGHT = 160
local DUEL_INTRO_SLIDE_TIME = 0.32
local DUEL_INTRO_IMPACT_TIME = 0.08
local DUEL_INTRO_HOLD_TIME = 0.5

local ELEMENT_COLORS = {
    Fuego = Color3.fromRGB(220, 60, 40),
    Agua = Color3.fromRGB(60, 140, 220),
    Planta = Color3.fromRGB(60, 180, 70),
    Electricidad = Color3.fromRGB(240, 210, 30),
    Roca = Color3.fromRGB(140, 120, 100),
}

local ELEMENT_LABELS = {
    Fuego = "🔥",
    Agua = "💧",
    Planta = "🌿",
    Electricidad = "⚡",
    Roca = "🪨",
}

local localGrid = nil
local isDragging = false
local isPrimaryMouseDown = false
local turnActive = false
local turnTimeLeft = 0
local stepCellSize = CELL_SIZE + CELL_PADDING
local dragStartGrid = nil
local dragPath = nil
local dragCurrentCell = nil
local dragStartPos = nil
local dragUnlocked = false
local lastHoverKey = nil
local lastSwapTime = 0
local lastRejectReason = nil
local lastRejectKey = nil
local isGridVisible = true
local isResolvingServerSync = false
local ghostFrame = nil
local currentComboText = nil
local currentComboCount = 0
local duelActive = false
local duelStarted = false
local duelSelfHP = 0
local duelEnemyHP = 0
local duelSelfStars = 0
local duelEnemyStars = 0
local duelOpponentName = "Sin oponente"
local duelOpponentUserId = nil
local duelOpponentKind = "player"
local duelIntroToken = 0
local duelIntroInProgress = false
local monsterPromptRestoreToken = 0
local pendingChallengerUserId = nil
local challengePromptRefs = {}

local function dbg(message)
    -- Propósito: Emitir logs de depuración del cliente de combate.
    -- Precondiciones:
    --   1. message debe ser string.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not COMBAT_DEBUG then
        return
    end
    warn("[CombatUI] " .. tostring(message))
end

local function cellKey(col, row)
    -- Propósito: Construir una clave única por celda.
    -- Precondiciones:
    --   1. col y row deben ser enteros válidos.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: string
    return col .. "," .. row
end

local function sameCell(cellA, cellB)
    -- Propósito: Comparar dos celdas por coordenadas.
    -- Precondiciones:
    --   1. cellA y cellB pueden ser nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: boolean
    if not cellA or not cellB then
        return false
    end
    return cellA.col == cellB.col and cellA.row == cellB.row
end

local function clearDragState()
    -- Propósito: Limpiar el estado local de arrastre/selección.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    isDragging = false
    dragStartGrid = nil
    dragPath = nil
    dragCurrentCell = nil
    dragStartPos = nil
    dragUnlocked = false
    lastHoverKey = nil
    lastSwapTime = 0
    lastRejectReason = nil
    lastRejectKey = nil
    if ghostFrame then ghostFrame.Visible = false end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombatUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "GridContainer"
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -20)
container.Size = UDim2.new(0, COLS * stepCellSize + 8, 0, ROWS * stepCellSize + 40)
container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
container.BackgroundTransparency = 0.2
container.BorderSizePixel = 0
container.Parent = screenGui
container.Visible = false

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = container

local timerBar = Instance.new("Frame")
timerBar.Name = "TimerBar"
timerBar.Position = UDim2.new(0, 4, 0, 4)
timerBar.Size = UDim2.new(1, -8, 0, 10)
timerBar.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
timerBar.BorderSizePixel = 0
timerBar.Parent = container
Instance.new("UICorner", timerBar).CornerRadius = UDim.new(0, 4)

local topHud = Instance.new("Frame")
topHud.Name = "TopHud"
topHud.AnchorPoint = Vector2.new(0.5, 0)
topHud.Position = UDim2.new(0.5, 0, 0, 20)
topHud.Size = UDim2.new(0, 540, 0, 80)
topHud.BackgroundTransparency = 1
topHud.Parent = screenGui

local selfHPLabel = Instance.new("TextLabel")
selfHPLabel.Name = "SelfHPLabel"
selfHPLabel.Position = UDim2.new(0, 0, 0, 0)
selfHPLabel.Size = UDim2.new(0, 260, 0, 20)
selfHPLabel.BackgroundTransparency = 1
selfHPLabel.TextXAlignment = Enum.TextXAlignment.Left
selfHPLabel.Font = Enum.Font.GothamBold
selfHPLabel.TextSize = 16
selfHPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
selfHPLabel.Text = "Tu vida: 0"
selfHPLabel.Parent = topHud

local selfHPBarBg = Instance.new("Frame")
selfHPBarBg.Name = "SelfHPBarBg"
selfHPBarBg.Position = UDim2.new(0, 0, 0, 24)
selfHPBarBg.Size = UDim2.new(0, 260, 0, 14)
selfHPBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
selfHPBarBg.BorderSizePixel = 0
selfHPBarBg.Parent = topHud
Instance.new("UICorner", selfHPBarBg).CornerRadius = UDim.new(0, 5)

local selfHPBarFill = Instance.new("Frame")
selfHPBarFill.Name = "SelfHPBarFill"
selfHPBarFill.Position = UDim2.new(0, 0, 0, 0)
selfHPBarFill.Size = UDim2.new(1, 0, 1, 0)
selfHPBarFill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
selfHPBarFill.BorderSizePixel = 0
selfHPBarFill.Parent = selfHPBarBg
Instance.new("UICorner", selfHPBarFill).CornerRadius = UDim.new(0, 5)

local enemyHPLabel = Instance.new("TextLabel")
enemyHPLabel.Name = "EnemyHPLabel"
enemyHPLabel.Position = UDim2.new(0, 280, 0, 0)
enemyHPLabel.Size = UDim2.new(0, 260, 0, 20)
enemyHPLabel.BackgroundTransparency = 1
enemyHPLabel.TextXAlignment = Enum.TextXAlignment.Right
enemyHPLabel.Font = Enum.Font.GothamBold
enemyHPLabel.TextSize = 16
enemyHPLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
enemyHPLabel.Text = "Rival: Sin oponente"
enemyHPLabel.Parent = topHud

local enemyHPBarBg = Instance.new("Frame")
enemyHPBarBg.Name = "EnemyHPBarBg"
enemyHPBarBg.Position = UDim2.new(0, 280, 0, 24)
enemyHPBarBg.Size = UDim2.new(0, 260, 0, 14)
enemyHPBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
enemyHPBarBg.BorderSizePixel = 0
enemyHPBarBg.Parent = topHud
Instance.new("UICorner", enemyHPBarBg).CornerRadius = UDim.new(0, 5)

local enemyHPBarFill = Instance.new("Frame")
enemyHPBarFill.Name = "EnemyHPBarFill"
enemyHPBarFill.Position = UDim2.new(0, 0, 0, 0)
enemyHPBarFill.Size = UDim2.new(1, 0, 1, 0)
enemyHPBarFill.BackgroundColor3 = Color3.fromRGB(220, 80, 80)
enemyHPBarFill.BorderSizePixel = 0
enemyHPBarFill.Parent = enemyHPBarBg
Instance.new("UICorner", enemyHPBarFill).CornerRadius = UDim.new(0, 5)

local enemyAvatarFrame = Instance.new("Frame")
enemyAvatarFrame.Name = "EnemyAvatarFrame"
enemyAvatarFrame.AnchorPoint = Vector2.new(1, 0)
enemyAvatarFrame.Position = UDim2.new(1, -20, 0, 20)
enemyAvatarFrame.Size = UDim2.new(0, 78, 0, 78)
enemyAvatarFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
enemyAvatarFrame.BackgroundTransparency = 0.15
enemyAvatarFrame.BorderSizePixel = 0
enemyAvatarFrame.Visible = false
enemyAvatarFrame.Parent = screenGui
enemyAvatarFrame.ZIndex = 20
Instance.new("UICorner", enemyAvatarFrame).CornerRadius = UDim.new(0, 10)

local enemyAvatarImage = Instance.new("ImageLabel")
enemyAvatarImage.Name = "EnemyAvatarImage"
enemyAvatarImage.Position = UDim2.new(0, 4, 0, 4)
enemyAvatarImage.Size = UDim2.new(1, -8, 1, -8)
enemyAvatarImage.BackgroundTransparency = 1
enemyAvatarImage.Image = ""
enemyAvatarImage.Parent = enemyAvatarFrame
enemyAvatarImage.ZIndex = 21
Instance.new("UICorner", enemyAvatarImage).CornerRadius = UDim.new(0, 8)

local enemyAvatarLabel = Instance.new("TextLabel")
enemyAvatarLabel.Name = "EnemyAvatarLabel"
enemyAvatarLabel.AnchorPoint = Vector2.new(1, 1)
enemyAvatarLabel.Position = UDim2.new(1, -6, 1, -4)
enemyAvatarLabel.Size = UDim2.new(1, -12, 0, 16)
enemyAvatarLabel.BackgroundTransparency = 0.35
enemyAvatarLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
enemyAvatarLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
enemyAvatarLabel.TextXAlignment = Enum.TextXAlignment.Right
enemyAvatarLabel.Font = Enum.Font.GothamBold
enemyAvatarLabel.TextSize = 12
enemyAvatarLabel.Text = "Rival"
enemyAvatarLabel.Parent = enemyAvatarFrame
enemyAvatarLabel.ZIndex = 22
Instance.new("UICorner", enemyAvatarLabel).CornerRadius = UDim.new(0, 6)

local duelStatusLabel = Instance.new("TextLabel")
duelStatusLabel.Name = "DuelStatusLabel"
duelStatusLabel.AnchorPoint = Vector2.new(0.5, 0)
duelStatusLabel.Position = UDim2.new(0.5, 0, 0, 110)
duelStatusLabel.Size = UDim2.new(0, 620, 0, 28)
duelStatusLabel.BackgroundTransparency = 1
duelStatusLabel.Font = Enum.Font.GothamBold
duelStatusLabel.TextSize = 18
duelStatusLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
duelStatusLabel.Text = "Acercate a otro jugador y usa el prompt para desafiar"
duelStatusLabel.Parent = screenGui

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "CountdownLabel"
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
countdownLabel.Size = UDim2.new(0, 220, 0, 80)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Font = Enum.Font.GothamBlack
countdownLabel.TextSize = 72
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countdownLabel.TextStrokeTransparency = 0.2
countdownLabel.Text = ""
countdownLabel.Visible = false
countdownLabel.Parent = screenGui

local duelIntroOverlay = Instance.new("Frame")
duelIntroOverlay.Name = "DuelIntroOverlay"
duelIntroOverlay.Size = UDim2.fromScale(1, 1)
duelIntroOverlay.Position = UDim2.fromScale(0, 0)
duelIntroOverlay.BackgroundColor3 = Color3.fromRGB(5, 8, 16)
duelIntroOverlay.BackgroundTransparency = 0.45
duelIntroOverlay.BorderSizePixel = 0
duelIntroOverlay.Visible = false
duelIntroOverlay.ZIndex = 40
duelIntroOverlay.Parent = screenGui

local duelIntroLeftCard = Instance.new("Frame")
duelIntroLeftCard.Name = "LeftCard"
duelIntroLeftCard.AnchorPoint = Vector2.new(0, 0.5)
duelIntroLeftCard.Position = UDim2.new(0, -DUEL_INTRO_CARD_WIDTH, 0.5, 0)
duelIntroLeftCard.Size = UDim2.new(0, DUEL_INTRO_CARD_WIDTH, 0, DUEL_INTRO_CARD_HEIGHT)
duelIntroLeftCard.BackgroundColor3 = Color3.fromRGB(44, 76, 138)
duelIntroLeftCard.BorderSizePixel = 0
duelIntroLeftCard.ZIndex = 41
duelIntroLeftCard.Parent = duelIntroOverlay
Instance.new("UICorner", duelIntroLeftCard).CornerRadius = UDim.new(0, 14)

local duelIntroLeftAvatar = Instance.new("ImageLabel")
duelIntroLeftAvatar.Name = "Avatar"
duelIntroLeftAvatar.Position = UDim2.new(0, 10, 0, 10)
duelIntroLeftAvatar.Size = UDim2.new(0, 96, 0, 96)
duelIntroLeftAvatar.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
duelIntroLeftAvatar.BorderSizePixel = 0
duelIntroLeftAvatar.Image = ""
duelIntroLeftAvatar.ZIndex = 42
duelIntroLeftAvatar.Parent = duelIntroLeftCard
Instance.new("UICorner", duelIntroLeftAvatar).CornerRadius = UDim.new(0, 10)

local duelIntroLeftFallback = Instance.new("TextLabel")
duelIntroLeftFallback.Name = "AvatarFallback"
duelIntroLeftFallback.Size = UDim2.fromScale(1, 1)
duelIntroLeftFallback.BackgroundTransparency = 1
duelIntroLeftFallback.Font = Enum.Font.GothamBlack
duelIntroLeftFallback.TextSize = 28
duelIntroLeftFallback.TextColor3 = Color3.fromRGB(255, 255, 255)
duelIntroLeftFallback.Text = "A"
duelIntroLeftFallback.ZIndex = 43
duelIntroLeftFallback.Parent = duelIntroLeftAvatar

local duelIntroLeftName = Instance.new("TextLabel")
duelIntroLeftName.Name = "Name"
duelIntroLeftName.Position = UDim2.new(0, 118, 0, 24)
duelIntroLeftName.Size = UDim2.new(1, -128, 0, 46)
duelIntroLeftName.BackgroundTransparency = 1
duelIntroLeftName.TextXAlignment = Enum.TextXAlignment.Left
duelIntroLeftName.TextYAlignment = Enum.TextYAlignment.Center
duelIntroLeftName.TextWrapped = true
duelIntroLeftName.Font = Enum.Font.GothamBlack
duelIntroLeftName.TextSize = 25
duelIntroLeftName.TextColor3 = Color3.fromRGB(255, 255, 255)
duelIntroLeftName.Text = "Domador A"
duelIntroLeftName.ZIndex = 42
duelIntroLeftName.Parent = duelIntroLeftCard

local duelIntroLeftStars = Instance.new("TextLabel")
duelIntroLeftStars.Name = "Stars"
duelIntroLeftStars.Position = UDim2.new(0, 118, 0, 78)
duelIntroLeftStars.Size = UDim2.new(1, -128, 0, 30)
duelIntroLeftStars.BackgroundTransparency = 1
duelIntroLeftStars.TextXAlignment = Enum.TextXAlignment.Left
duelIntroLeftStars.Font = Enum.Font.GothamBold
duelIntroLeftStars.TextSize = 18
duelIntroLeftStars.TextColor3 = Color3.fromRGB(255, 227, 116)
duelIntroLeftStars.Text = "Estrellas: 0"
duelIntroLeftStars.ZIndex = 42
duelIntroLeftStars.Parent = duelIntroLeftCard

local duelIntroRightCard = Instance.new("Frame")
duelIntroRightCard.Name = "RightCard"
duelIntroRightCard.AnchorPoint = Vector2.new(1, 0.5)
duelIntroRightCard.Position = UDim2.new(1, DUEL_INTRO_CARD_WIDTH, 0.5, 0)
duelIntroRightCard.Size = UDim2.new(0, DUEL_INTRO_CARD_WIDTH, 0, DUEL_INTRO_CARD_HEIGHT)
duelIntroRightCard.BackgroundColor3 = Color3.fromRGB(146, 52, 56)
duelIntroRightCard.BorderSizePixel = 0
duelIntroRightCard.ZIndex = 41
duelIntroRightCard.Parent = duelIntroOverlay
Instance.new("UICorner", duelIntroRightCard).CornerRadius = UDim.new(0, 14)

local duelIntroRightAvatar = Instance.new("ImageLabel")
duelIntroRightAvatar.Name = "Avatar"
duelIntroRightAvatar.AnchorPoint = Vector2.new(1, 0)
duelIntroRightAvatar.Position = UDim2.new(1, -10, 0, 10)
duelIntroRightAvatar.Size = UDim2.new(0, 96, 0, 96)
duelIntroRightAvatar.BackgroundColor3 = Color3.fromRGB(34, 10, 12)
duelIntroRightAvatar.BorderSizePixel = 0
duelIntroRightAvatar.Image = ""
duelIntroRightAvatar.ZIndex = 42
duelIntroRightAvatar.Parent = duelIntroRightCard
Instance.new("UICorner", duelIntroRightAvatar).CornerRadius = UDim.new(0, 10)

local duelIntroRightFallback = Instance.new("TextLabel")
duelIntroRightFallback.Name = "AvatarFallback"
duelIntroRightFallback.Size = UDim2.fromScale(1, 1)
duelIntroRightFallback.BackgroundTransparency = 1
duelIntroRightFallback.Font = Enum.Font.GothamBlack
duelIntroRightFallback.TextSize = 28
duelIntroRightFallback.TextColor3 = Color3.fromRGB(255, 255, 255)
duelIntroRightFallback.Text = "B"
duelIntroRightFallback.ZIndex = 43
duelIntroRightFallback.Parent = duelIntroRightAvatar

local duelIntroRightName = Instance.new("TextLabel")
duelIntroRightName.Name = "Name"
duelIntroRightName.Position = UDim2.new(0, 12, 0, 24)
duelIntroRightName.Size = UDim2.new(1, -128, 0, 46)
duelIntroRightName.BackgroundTransparency = 1
duelIntroRightName.TextXAlignment = Enum.TextXAlignment.Left
duelIntroRightName.TextYAlignment = Enum.TextYAlignment.Center
duelIntroRightName.TextWrapped = true
duelIntroRightName.Font = Enum.Font.GothamBlack
duelIntroRightName.TextSize = 25
duelIntroRightName.TextColor3 = Color3.fromRGB(255, 255, 255)
duelIntroRightName.Text = "Domador B"
duelIntroRightName.ZIndex = 42
duelIntroRightName.Parent = duelIntroRightCard

local duelIntroRightStars = Instance.new("TextLabel")
duelIntroRightStars.Name = "Stars"
duelIntroRightStars.Position = UDim2.new(0, 12, 0, 78)
duelIntroRightStars.Size = UDim2.new(1, -128, 0, 30)
duelIntroRightStars.BackgroundTransparency = 1
duelIntroRightStars.TextXAlignment = Enum.TextXAlignment.Left
duelIntroRightStars.Font = Enum.Font.GothamBold
duelIntroRightStars.TextSize = 18
duelIntroRightStars.TextColor3 = Color3.fromRGB(255, 227, 116)
duelIntroRightStars.Text = "Estrellas: 0"
duelIntroRightStars.ZIndex = 42
duelIntroRightStars.Parent = duelIntroRightCard

local duelIntroVsLabel = Instance.new("TextLabel")
duelIntroVsLabel.Name = "VS"
duelIntroVsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
duelIntroVsLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
duelIntroVsLabel.Size = UDim2.new(0, 170, 0, 120)
duelIntroVsLabel.BackgroundTransparency = 1
duelIntroVsLabel.Font = Enum.Font.GothamBlack
duelIntroVsLabel.TextSize = 88
duelIntroVsLabel.TextColor3 = Color3.fromRGB(255, 242, 156)
duelIntroVsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
duelIntroVsLabel.TextStrokeTransparency = 0.1
duelIntroVsLabel.Text = "VS"
duelIntroVsLabel.Visible = false
duelIntroVsLabel.ZIndex = 45
duelIntroVsLabel.Parent = duelIntroOverlay

local duelIntroVsScale = Instance.new("UIScale")
duelIntroVsScale.Scale = 0.6
duelIntroVsScale.Parent = duelIntroVsLabel

local challengePrompt = Instance.new("Frame")
challengePrompt.Name = "ChallengePrompt"
challengePrompt.AnchorPoint = Vector2.new(0.5, 0.5)
challengePrompt.Position = UDim2.new(0.5, 0, 0.55, 0)
challengePrompt.Size = UDim2.new(0, 420, 0, 120)
challengePrompt.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
challengePrompt.BackgroundTransparency = 0.15
challengePrompt.BorderSizePixel = 0
challengePrompt.Visible = false
challengePrompt.Parent = screenGui
Instance.new("UICorner", challengePrompt).CornerRadius = UDim.new(0, 10)

local challengeText = Instance.new("TextLabel")
challengeText.Name = "Text"
challengeText.Position = UDim2.new(0, 12, 0, 12)
challengeText.Size = UDim2.new(1, -24, 0, 62)
challengeText.BackgroundTransparency = 1
challengeText.Font = Enum.Font.GothamBold
challengeText.TextSize = 20
challengeText.TextWrapped = true
challengeText.TextColor3 = Color3.fromRGB(255, 255, 255)
challengeText.Text = ""
challengeText.Parent = challengePrompt

local challengeHint = Instance.new("TextLabel")
challengeHint.Name = "Hint"
challengeHint.Position = UDim2.new(0, 12, 0, 80)
challengeHint.Size = UDim2.new(1, -24, 0, 28)
challengeHint.BackgroundTransparency = 1
challengeHint.Font = Enum.Font.Gotham
challengeHint.TextSize = 16
challengeHint.TextColor3 = Color3.fromRGB(240, 220, 120)
challengeHint.Text = IS_TOUCH_DEVICE and "Usa los botones para responder" or "Y = Aceptar | N = Rechazar"
challengeHint.Parent = challengePrompt

local challengeAcceptButton = Instance.new("TextButton")
challengeAcceptButton.Name = "AcceptButton"
challengeAcceptButton.Position = UDim2.new(0, 12, 1, -40)
challengeAcceptButton.Size = UDim2.new(0.5, -18, 0, 28)
challengeAcceptButton.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
challengeAcceptButton.BorderSizePixel = 0
challengeAcceptButton.Font = Enum.Font.GothamBold
challengeAcceptButton.TextSize = 15
challengeAcceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
challengeAcceptButton.Text = "Aceptar"
challengeAcceptButton.Parent = challengePrompt
Instance.new("UICorner", challengeAcceptButton).CornerRadius = UDim.new(0, 6)

local challengeRejectButton = Instance.new("TextButton")
challengeRejectButton.Name = "RejectButton"
challengeRejectButton.Position = UDim2.new(0.5, 6, 1, -40)
challengeRejectButton.Size = UDim2.new(0.5, -18, 0, 28)
challengeRejectButton.BackgroundColor3 = Color3.fromRGB(170, 70, 70)
challengeRejectButton.BorderSizePixel = 0
challengeRejectButton.Font = Enum.Font.GothamBold
challengeRejectButton.TextSize = 15
challengeRejectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
challengeRejectButton.Text = "Rechazar"
challengeRejectButton.Parent = challengePrompt
Instance.new("UICorner", challengeRejectButton).CornerRadius = UDim.new(0, 6)

local gridFrame = Instance.new("Frame")
gridFrame.Name = "GridFrame"
gridFrame.Position = UDim2.new(0, 4, 0, 18)
gridFrame.Size = UDim2.new(0, COLS * stepCellSize, 0, ROWS * stepCellSize)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = container

local cellButtons = {}
local normalizePointerPosition

local function buildCells()
    -- Propósito: Construir la grilla visual completa del tablero.
    -- Precondiciones:
    --   1. gridFrame debe existir.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    for col = 1, COLS do
        cellButtons[col] = {}
        for row = 1, ROWS do
            local btn = Instance.new("ImageButton")
            btn.Name = "Cell_" .. col .. "_" .. row
            btn.Position = UDim2.new(0, (col - 1) * stepCellSize, 0, (row - 1) * stepCellSize)
            btn.Size = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Parent = gridFrame

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = btn

            local scale = Instance.new("UIScale")
            scale.Name = "Scale"
            scale.Scale = 1
            scale.Parent = btn

            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextScaled = true
            label.Font = Enum.Font.GothamBold
            label.Text = ""
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.Parent = btn

            cellButtons[col][row] = btn
        end
    end
end

buildCells()

-- Ghost: pieza flotante que sigue al cursor durante el drag
ghostFrame = Instance.new("Frame")
ghostFrame.Name = "DragGhost"
ghostFrame.Size = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
ghostFrame.AnchorPoint = Vector2.new(0.5, 0.5)
ghostFrame.Position = UDim2.new(0, 0, 0, 0)
ghostFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ghostFrame.BackgroundTransparency = 0.25
ghostFrame.BorderSizePixel = 0
ghostFrame.Visible = false
ghostFrame.ZIndex = 10
ghostFrame.Parent = screenGui
Instance.new("UICorner", ghostFrame).CornerRadius = UDim.new(0, 8)

local ghostLabel = Instance.new("TextLabel")
ghostLabel.Name = "Label"
ghostLabel.Size = UDim2.new(1, 0, 1, 0)
ghostLabel.BackgroundTransparency = 1
ghostLabel.TextScaled = true
ghostLabel.Font = Enum.Font.GothamBold
ghostLabel.Text = ""
ghostLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
ghostLabel.ZIndex = 11
ghostLabel.Parent = ghostFrame

local function showGhost(col, row, mousePos)
    if not localGrid or not col then
        ghostFrame.Visible = false
        return
    end
    local tile = localGrid[col] and localGrid[col][row]
    if not tile then
        ghostFrame.Visible = false
        return
    end
    ghostFrame.BackgroundColor3 = ELEMENT_COLORS[tile.elementType] or Color3.fromRGB(80, 80, 80)
    ghostLabel.Text = ELEMENT_LABELS[tile.elementType] or "?"
    local normalizedPos = normalizePointerPosition(mousePos)
    -- Pegar el ghost al cursor (ajuste por AnchorPoint centrado)
    ghostFrame.Position = UDim2.new(0, normalizedPos.X, 0, (normalizedPos.Y + CELL_SIZE))
    ghostFrame.Visible = true
end

local function hideGhost()
    ghostFrame.Visible = false
end

local function setGridInputEnabled(enabled)
    -- Propósito: Habilitar/deshabilitar inputs en todos los botones de la grilla y contenedor.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    container.Active = enabled
    gridFrame.Active = enabled
    for col = 1, COLS do
        for row = 1, ROWS do
            if cellButtons[col] and cellButtons[col][row] then
                cellButtons[col][row].Active = enabled
            end
        end
    end
end

local function refreshGridVisibility()
    -- Propósito: Mostrar tablero solo cuando el duelo esté activo e iniciado.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    container.Visible = duelActive and duelStarted and isGridVisible
    topHud.Visible = duelActive
    setGridInputEnabled(duelActive)
end

local function sanitizeStars(value)
    -- Propósito: Normalizar un valor de estrellas para mostrar en UI.
    -- Precondiciones:
    --   1. value puede ser number o nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: number
    local numeric = tonumber(value) or 0
    return math.max(0, math.floor(numeric))
end

local function resolvePlayerStars(targetPlayer)
    -- Propósito: Leer estrellas PvP de un jugador replicadas al cliente.
    -- Precondiciones:
    --   1. targetPlayer puede ser nil o Player válido.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: number
    if not targetPlayer then
        return 0
    end

    local attrStars = targetPlayer:GetAttribute("PvpStars")
    if type(attrStars) == "number" then
        return sanitizeStars(attrStars)
    end

    local leaderstats = targetPlayer:FindFirstChild("leaderstats")
    local starsValue = leaderstats and leaderstats:FindFirstChild("PvpStars")
    if starsValue and starsValue:IsA("IntValue") then
        return sanitizeStars(starsValue.Value)
    end

    return 0
end

local function updateDuelMeta(data)
    -- Propósito: Guardar metadata de duelo (tipo oponente y estrellas) para HUD/cinemática.
    -- Precondiciones:
    --   1. data debe ser tabla de estado parcial.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(data) ~= "table" then
        return
    end

    if type(data.opponentKind) == "string" then
        duelOpponentKind = data.opponentKind
    elseif type(data.opponentUserId) == "number" then
        duelOpponentKind = "player"
    end

    if type(data.selfStars) == "number" then
        duelSelfStars = sanitizeStars(data.selfStars)
    else
        duelSelfStars = resolvePlayerStars(player)
    end

    if type(data.opponentStars) == "number" then
        duelEnemyStars = sanitizeStars(data.opponentStars)
    elseif duelOpponentKind == "player" and type(data.opponentUserId) == "number" then
        local opponentPlayer = Players:GetPlayerByUserId(data.opponentUserId)
        duelEnemyStars = resolvePlayerStars(opponentPlayer)
    end
end

local function updateHPHud(selfHP, enemyHP, opponentName)
    -- Propósito: Actualizar barra de vida propia/rival en el HUD.
    -- Precondiciones:
    --   1. selfHP y enemyHP pueden ser nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(selfHP) == "number" then
        duelSelfHP = math.max(0, math.floor(selfHP))
    end
    if type(enemyHP) == "number" then
        duelEnemyHP = math.max(0, math.floor(enemyHP))
    end
    if type(opponentName) == "string" and opponentName ~= "" then
        duelOpponentName = opponentName
    end

    local maxHP = MAX_DUEL_HP
    local selfRatio = math.clamp(duelSelfHP / maxHP, 0, 1)
    local enemyRatio = math.clamp(duelEnemyHP / maxHP, 0, 1)
    selfHPBarFill.Size = UDim2.new(selfRatio, 0, 1, 0)
    enemyHPBarFill.Size = UDim2.new(enemyRatio, 0, 1, 0)

    selfHPLabel.Text = "Tu vida: " .. tostring(duelSelfHP) .. "  |  ⭐ " .. tostring(duelSelfStars)
    enemyHPLabel.Text = "Rival " .. tostring(duelOpponentName) .. "  |  ⭐ " .. tostring(duelEnemyStars) .. ": " .. tostring(duelEnemyHP)
end

local function fillDuelIntroCard(avatarImage, avatarFallback, nameLabel, starsLabel, displayName, stars, userId, fallbackText)
    -- Propósito: Cargar nombre, estrellas y avatar de una tarjeta de presentación de duelo.
    -- Precondiciones:
    --   1. avatarImage, avatarFallback, nameLabel, starsLabel deben existir.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    nameLabel.Text = tostring(displayName or "Domador")
    starsLabel.Text = "Estrellas: " .. tostring(sanitizeStars(stars))

    avatarImage.Image = ""
    avatarFallback.Text = tostring(fallbackText or "?")
    avatarFallback.Visible = true

    return type(userId) == "number" and userId or nil
end

local function applyIntroAvatarAsync(avatarImage, avatarFallback, userId, token)
    -- Propósito: Cargar avatar de tarjeta VS sin bloquear la animación.
    -- Precondiciones:
    --   1. userId debe ser number o nil.
    --   2. token debe corresponder al intro activo.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(userId) ~= "number" then
        return
    end

    task.spawn(function()
        local ok, content = pcall(function()
            return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
        end)

        if token ~= duelIntroToken then
            return
        end

        if ok and type(content) == "string" then
            avatarImage.Image = content
            avatarFallback.Visible = false
        end
    end)
end

local function setMonsterChallengePromptsEnabled(enabled)
    -- Propósito: Alternar prompts de monstruos (MonsterChallengePrompt) visibles para este cliente.
    -- Precondiciones:
    --   1. enabled debe ser boolean.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "MonsterChallengePrompt" then
            descendant.Enabled = enabled
        end
    end
end

local function suppressMonsterChallengePrompts(seconds)
    -- Propósito: Ocultar prompts de monstruos por unos segundos tras iniciar desafío.
    -- Precondiciones:
    --   1. seconds debe ser number > 0.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    local duration = tonumber(seconds) or 0
    if duration <= 0 then
        return
    end

    monsterPromptRestoreToken += 1
    local restoreToken = monsterPromptRestoreToken
    setMonsterChallengePromptsEnabled(false)

    task.delay(duration, function()
        if restoreToken ~= monsterPromptRestoreToken then
            return
        end
        if duelActive then
            return
        end
        setMonsterChallengePromptsEnabled(true)
    end)
end

local function hideDuelIntro()
    -- Propósito: Cerrar inmediatamente la cinemática VS si está visible.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    duelIntroToken += 1
    duelIntroInProgress = false
    duelIntroOverlay.Visible = false
end

local function playDuelIntro(data)
    -- Propósito: Animar entrada de tarjetas de ambos combatientes con choque y texto VS.
    -- Precondiciones:
    --   1. data debe ser tabla con información del oponente.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if duelIntroInProgress then
        return
    end

    duelIntroToken += 1
    local token = duelIntroToken
    duelIntroInProgress = true

    duelIntroOverlay.BackgroundTransparency = 0.45
    duelIntroOverlay.Visible = true
    duelIntroVsLabel.Visible = false
    duelIntroVsLabel.TextTransparency = 1
    duelIntroVsScale.Scale = 0.6

    duelIntroLeftCard.Position = UDim2.new(0, -DUEL_INTRO_CARD_WIDTH, 0.5, 0)
    duelIntroRightCard.Position = UDim2.new(1, DUEL_INTRO_CARD_WIDTH, 0.5, 0)

    local selfDisplayName = player.DisplayName
    if selfDisplayName == nil or selfDisplayName == "" then
        selfDisplayName = player.Name
    end

    local enemyDisplayName = duelOpponentName
    local enemyUserId = type(data.opponentUserId) == "number" and data.opponentUserId or nil
    local enemyFallback = "B"
    if duelOpponentKind == "monster" then
        enemyUserId = nil
        enemyFallback = "M"
    end

    local selfAvatarUserId = fillDuelIntroCard(
        duelIntroLeftAvatar,
        duelIntroLeftFallback,
        duelIntroLeftName,
        duelIntroLeftStars,
        selfDisplayName,
        duelSelfStars,
        player.UserId,
        "A"
    )
    local enemyAvatarUserId = fillDuelIntroCard(
        duelIntroRightAvatar,
        duelIntroRightFallback,
        duelIntroRightName,
        duelIntroRightStars,
        enemyDisplayName,
        duelEnemyStars,
        enemyUserId,
        enemyFallback
    )

    applyIntroAvatarAsync(duelIntroLeftAvatar, duelIntroLeftFallback, selfAvatarUserId, token)
    applyIntroAvatarAsync(duelIntroRightAvatar, duelIntroRightFallback, enemyAvatarUserId, token)

    local leftImpactPosition = UDim2.new(0.5, -DUEL_INTRO_CARD_WIDTH + 16, 0.5, 0)
    local rightImpactPosition = UDim2.new(0.5, DUEL_INTRO_CARD_WIDTH - 16, 0.5, 0)
    local leftSettlePosition = UDim2.new(0.5, -DUEL_INTRO_CARD_WIDTH - 24, 0.5, 0)
    local rightSettlePosition = UDim2.new(0.5, DUEL_INTRO_CARD_WIDTH + 24, 0.5, 0)

    local slideInfo = TweenInfo.new(DUEL_INTRO_SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local leftSlide = TweenService:Create(duelIntroLeftCard, slideInfo, { Position = leftImpactPosition })
    local rightSlide = TweenService:Create(duelIntroRightCard, slideInfo, { Position = rightImpactPosition })
    leftSlide:Play()
    rightSlide:Play()

    task.wait(DUEL_INTRO_SLIDE_TIME - 0.04)
    if token ~= duelIntroToken then
        duelIntroInProgress = false
        return
    end

    duelIntroVsLabel.Visible = true
    local vsInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(duelIntroVsScale, vsInfo, { Scale = 1 }):Play()
    TweenService:Create(duelIntroVsLabel, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()

    local impactInfo = TweenInfo.new(DUEL_INTRO_IMPACT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(duelIntroLeftCard, impactInfo, { Position = leftSettlePosition }):Play()
    TweenService:Create(duelIntroRightCard, impactInfo, { Position = rightSettlePosition }):Play()

    task.wait(DUEL_INTRO_HOLD_TIME)
    if token ~= duelIntroToken then
        duelIntroInProgress = false
        return
    end

    duelIntroInProgress = false
end

local function updateEnemyAvatar(userId, opponentName)
    -- Propósito: Mostrar mini avatar del contrincante en esquina superior derecha.
    -- Precondiciones:
    --   1. userId puede ser nil o number.
    --   2. opponentName puede ser nil o string.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    enemyAvatarLabel.Text = tostring(opponentName or "Rival")

    if type(userId) ~= "number" then
        duelOpponentUserId = nil
        enemyAvatarImage.Image = ""
        enemyAvatarFrame.Visible = false
        return
    end

    duelOpponentUserId = userId
    enemyAvatarFrame.Visible = true

    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    end)
    if ok and type(content) == "string" then
        enemyAvatarImage.Image = content
    end
end

local function resetDuelHud()
    -- Propósito: Reiniciar HUD de vida al estado base al terminar un duelo.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    duelSelfHP = MAX_DUEL_HP
    duelEnemyHP = MAX_DUEL_HP
    duelSelfStars = resolvePlayerStars(player)
    duelEnemyStars = 0
    duelOpponentName = "Sin oponente"
    duelOpponentUserId = nil
    duelOpponentKind = "player"
    updateHPHud(duelSelfHP, duelEnemyHP, duelOpponentName)
    updateEnemyAvatar(nil, nil)
end

local function requestChallengeToPlayer(targetPlayer)
    -- Propósito: Solicitar un desafío a un jugador específico.
    -- Precondiciones:
    --   1. targetPlayer debe ser un Player válido.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if duelActive or not targetPlayer or targetPlayer == player then
        return
    end

    CombatChallengeRequest:FireServer({ targetUserId = targetPlayer.UserId })
    duelStatusLabel.Text = "Desafio enviado a " .. targetPlayer.Name
end

local function respondToChallenge(accepted)
    -- Propósito: Responder al desafío pendiente con aceptar/rechazar.
    -- Precondiciones:
    --   1. accepted debe ser boolean.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(accepted) ~= "boolean" then
        return
    end

    if not pendingChallengerUserId then
        return
    end

    CombatChallengeResponse:FireServer({
        challengerUserId = pendingChallengerUserId,
        accepted = accepted,
    })
    challengePrompt.Visible = false
    pendingChallengerUserId = nil
end

local containerScale = Instance.new("UIScale")
containerScale.Name = "MobileScale"
containerScale.Scale = 1
containerScale.Parent = container

local function applyTouchLayout()
    -- Propósito: Ajustar layout táctil para no bloquear joystick en móvil.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not IS_TOUCH_DEVICE then
        return
    end

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(720, 1280)
    local baseWidth = COLS * stepCellSize + 8
    containerScale.Scale = math.clamp((viewport.X - 24) / baseWidth, 0.7, 1)

    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.new(0.5, 0, 0.48, 0)

    topHud.Position = UDim2.new(0.5, 0, 0, 10)
    duelStatusLabel.Position = UDim2.new(0.5, 0, 0, 94)
    challengePrompt.Position = UDim2.new(0.5, 0, 0.43, 0)
end

local function setChallengePromptsEnabled(enabled)
    -- Propósito: Habilitar o deshabilitar prompts de desafío según estado de duelo.
    -- Precondiciones:
    --   1. enabled debe ser boolean.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    for _, data in pairs(challengePromptRefs) do
        if data and data.prompt and data.prompt.Parent then
            data.prompt.Enabled = enabled
        end
    end
end

local function clearChallengePromptForPlayer(targetPlayer)
    -- Propósito: Limpiar prompt local asociado a un jugador.
    -- Precondiciones:
    --   1. targetPlayer debe ser Player válido.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    local data = challengePromptRefs[targetPlayer]
    if not data then
        return
    end

    if data.triggerConn then
        data.triggerConn:Disconnect()
    end

    if data.prompt then
        data.prompt:Destroy()
    end

    challengePromptRefs[targetPlayer] = nil
end

local function ensureChallengePromptForPlayer(targetPlayer)
    -- Propósito: Crear prompt de proximidad para desafiar a otro jugador.
    -- Precondiciones:
    --   1. targetPlayer debe ser distinto al jugador local.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if targetPlayer == player then
        return
    end

    local character = targetPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        clearChallengePromptForPlayer(targetPlayer)
        return
    end

    local existing = challengePromptRefs[targetPlayer]
    if existing and existing.prompt and existing.prompt.Parent == hrp then
        existing.prompt.Enabled = not duelActive
        existing.prompt.ObjectText = targetPlayer.Name
        return
    end

    clearChallengePromptForPlayer(targetPlayer)

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "CombatChallengePrompt"
    prompt.ActionText = "Desafiar"
    prompt.ObjectText = targetPlayer.Name
    prompt.MaxActivationDistance = CHALLENGE_DISTANCE
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Enabled = not duelActive
    prompt.Parent = hrp

    local triggerConn = prompt.Triggered:Connect(function(triggerPlayer)
        if triggerPlayer ~= player then
            return
        end
        requestChallengeToPlayer(targetPlayer)
    end)

    challengePromptRefs[targetPlayer] = {
        prompt = prompt,
        triggerConn = triggerConn,
    }
end

local function bindChallengePrompts()
    -- Propósito: Vincular prompts de desafío al ciclo de vida de jugadores.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            -- Intentar ahora y también con delay por si el personaje aún no replicó
            task.spawn(function()
                ensureChallengePromptForPlayer(otherPlayer)
                if not (otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")) then
                    task.wait(1)
                    ensureChallengePromptForPlayer(otherPlayer)
                end
            end)
            otherPlayer.CharacterAdded:Connect(function()
                task.wait(0.1)
                ensureChallengePromptForPlayer(otherPlayer)
            end)
        end
    end

    Players.PlayerAdded:Connect(function(otherPlayer)
        if otherPlayer == player then
            return
        end

        task.spawn(function()
            ensureChallengePromptForPlayer(otherPlayer)
            if not (otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart")) then
                task.wait(1)
                ensureChallengePromptForPlayer(otherPlayer)
            end
        end)
        otherPlayer.CharacterAdded:Connect(function()
            task.wait(0.1)
            ensureChallengePromptForPlayer(otherPlayer)
        end)
    end)

    Players.PlayerRemoving:Connect(function(otherPlayer)
        clearChallengePromptForPlayer(otherPlayer)
    end)
end

applyTouchLayout()
bindChallengePrompts()
resetDuelHud()
setGridInputEnabled(false)
topHud.Visible = false

task.delay(3, function()
    if duelStatusLabel.Text == "Acercate a otro jugador y usa el prompt para desafiar" then
        duelStatusLabel.Text = ""
    end
end)


if IS_TOUCH_DEVICE and workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        applyTouchLayout()
    end)
end

challengeAcceptButton.MouseButton1Click:Connect(function()
    respondToChallenge(true)
end)

challengeRejectButton.MouseButton1Click:Connect(function()
    respondToChallenge(false)
end)

local function renderGrid()
    -- Propósito: Refrescar colores, labels y bordes de toda la grilla.
    -- Precondiciones:
    --   1. localGrid debe ser un tablero válido.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not localGrid then
        return
    end

    for col = 1, COLS do
        for row = 1, ROWS do
            local btn = cellButtons[col][row]
            local tile = localGrid[col] and localGrid[col][row]
            local label = btn:FindFirstChild("Label")
            local scale = btn:FindFirstChild("Scale")

            if scale then
                scale.Scale = 1
            end

            -- Mientras se arrastra, la celda de la ficha levantada se ve vacía.
            if isDragging and dragCurrentCell
            and dragCurrentCell.col == col and dragCurrentCell.row == row then
                btn.BorderSizePixel = 0
                btn.BorderColor3 = Color3.fromRGB(255, 255, 255)
                btn.BackgroundTransparency = 0
                btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                label.Text = ""
                continue
            end

            btn.BorderSizePixel = 0
            btn.BorderColor3 = Color3.fromRGB(255, 255, 255)
            btn.BackgroundTransparency = 0

            if tile then
                btn.BackgroundColor3 = ELEMENT_COLORS[tile.elementType] or Color3.fromRGB(80, 80, 80)
                label.Text = ELEMENT_LABELS[tile.elementType] or "?"
            else
                btn.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
                label.Text = ""
            end
        end
    end
end

local function renderSelection()
    -- Propósito: Resaltar la ficha inicial y la posición actual del drag.
    -- Precondiciones:
    --   1. cellButtons debe estar construido.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if dragPath and dragPath[1] then
        local originCell = dragPath[1]
        local originBtn = cellButtons[originCell.col][originCell.row]
        originBtn.BorderSizePixel = 3
        originBtn.BorderColor3 = Color3.fromRGB(255, 255, 255)
        originBtn.BackgroundTransparency = 0.18
    end

    if dragCurrentCell then
        local dc = dragCurrentCell.col
        local dr = dragCurrentCell.row
        if dc >= 1 and dc <= COLS and dr >= 1 and dr <= ROWS then
            local targetBtn = cellButtons[dc][dr]
            targetBtn.BorderSizePixel = 3
            targetBtn.BorderColor3 = Color3.fromRGB(255, 230, 90)
            targetBtn.BackgroundTransparency = 0.18
        end
    end
end

local function rerender()
    -- Propósito: Redibujar tablero y selección en el orden correcto.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    renderGrid()
    renderSelection()
end

local function copyTile(tile)
    -- Propósito: Copiar una ficha para mutaciones locales de animación.
    -- Precondiciones:
    --   1. tile puede ser nil o tabla con elementType.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: table|nil
    if not tile then
        return nil
    end
    return {
        elementType = tile.elementType,
    }
end

local function createFloatingTile(elementType, centerPos)
    -- Propósito: Crear una ficha visual temporal para animar caídas.
    -- Precondiciones:
    --   1. centerPos debe ser Vector2 válido en pantalla.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: Frame
    local ghost = Instance.new("Frame")
    ghost.Name = "CascadeGhost"
    ghost.AnchorPoint = Vector2.new(0.5, 0.5)
    ghost.Size = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE)
    ghost.Position = UDim2.new(0, centerPos.X, 0, centerPos.Y)
    ghost.BackgroundColor3 = ELEMENT_COLORS[elementType] or Color3.fromRGB(80, 80, 80)
    ghost.BorderSizePixel = 0
    ghost.ZIndex = 12
    ghost.Parent = screenGui
    Instance.new("UICorner", ghost).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = ELEMENT_LABELS[elementType] or "?"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.ZIndex = 13
    label.Parent = ghost

    return ghost
end

local function playTweensAndWait(tweens)
    -- Propósito: Ejecutar un lote de tweens y esperar su finalización.
    -- Precondiciones:
    --   1. tweens debe ser una lista de Tween.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if #tweens == 0 then
        return
    end

    for _, tween in ipairs(tweens) do
        tween:Play()
    end

    task.wait(FALL_TWEEN_TIME + 0.02)
end

local function createComboCounter()
    -- Proposito: Crear elemento unico de contador de combo.
    -- Precondiciones: Ninguna.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: TextLabel
    if currentComboText then
        currentComboText:Destroy()
    end

    local textFrame = Instance.new("TextLabel")
    textFrame.Name = "ComboCounter"
    textFrame.AnchorPoint = Vector2.new(0, 0)
    textFrame.Size = UDim2.new(0, 140, 0, 40)
    textFrame.Position = UDim2.new(0, 8, 0, -45)
    textFrame.BackgroundTransparency = 1
    textFrame.TextScaled = true
    textFrame.Font = Enum.Font.GothamBlack
    textFrame.Text = ""
    textFrame.TextColor3 = Color3.fromRGB(255, 230, 90)
    textFrame.TextStrokeTransparency = 0.25
    textFrame.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textFrame.TextTransparency = 0
    textFrame.ZIndex = 15
    textFrame.Parent = container

    local scale = Instance.new("UIScale")
    scale.Name = "Scale"
    scale.Scale = 1
    scale.Parent = textFrame

    return textFrame
end

local function pulseComboText()
    -- Proposito: Animar latido del contador (escala 1 a 1.1 a 1).
    -- Precondiciones:
    --   1. currentComboText debe existir.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not currentComboText then
        return
    end

    local scale = currentComboText:FindFirstChild("Scale")
    if not scale then
        return
    end

    local pulseInfo = TweenInfo.new(PULSE_DURATION, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
    local pulseTween = TweenService:Create(scale, pulseInfo, { Scale = 1.1 })
    pulseTween:Play()

    task.spawn(function()
        task.wait(PULSE_DURATION * 0.5)
        local backInfo = TweenInfo.new(PULSE_DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local backTween = TweenService:Create(scale, backInfo, { Scale = 1 })
        backTween:Play()
    end)
end

local function hideComboTextWithFade()
    -- Proposito: Desvanecer el contador despues de delay.
    -- Precondiciones:
    --   1. currentComboText debe existir.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not currentComboText then
        return
    end

    task.wait(COMBO_WAIT_FADE_DELAY)

    local fadeInfo = TweenInfo.new(COMBO_FINAL_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local fadeTween = TweenService:Create(currentComboText, fadeInfo, { TextTransparency = 1 })
    fadeTween:Play()

    task.spawn(function()
        task.wait(COMBO_FINAL_FADE_TIME + 0.02)
        if currentComboText then
            currentComboText:Destroy()
            currentComboText = nil
        end
    end)
end

local function animateComboScaleOut(combo)
    -- Propósito: Hacer desaparecer una combinación con tween de escala 1 a 0.
    -- Precondiciones:
    --   1. combo debe contener celdas válidas.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(combo) ~= "table" then
        return
    end

    local tweens = {}
    local tweenInfo = TweenInfo.new(COMBO_SCALE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    for _, cell in ipairs(combo) do
        local col = cell.col
        local row = cell.row
        if cellButtons[col] and cellButtons[col][row] and localGrid and localGrid[col] and localGrid[col][row] then
            local scale = cellButtons[col][row]:FindFirstChild("Scale")
            if scale then
                scale.Scale = 1
                table.insert(tweens, TweenService:Create(scale, tweenInfo, { Scale = 0 }))
            end
        end
    end

    for _, tween in ipairs(tweens) do
        tween:Play()
    end

    task.wait(COMBO_SCALE_OUT_TIME + 0.01)

    for _, cell in ipairs(combo) do
        local col = cell.col
        local row = cell.row
        if localGrid and localGrid[col] then
            localGrid[col][row] = nil
        end
        if cellButtons[col] and cellButtons[col][row] then
            local scale = cellButtons[col][row]:FindFirstChild("Scale")
            if scale then
                scale.Scale = 1
            end
        end
    end

    rerender()
    task.wait(COMBO_STAGGER_TIME)
end

local function registerResolvedCombo(showComboCounter)
    -- Proposito: Actualizar el contador al resolverse una combinacion individual.
    -- Precondiciones:
    --   1. showComboCounter debe ser boolean.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    currentComboCount += 1
    if not showComboCounter or currentComboCount < 2 then
        return
    end

    if not currentComboText then
        currentComboText = createComboCounter()
    end

    currentComboText.Text = "Combo x" .. tostring(currentComboCount)
    pulseComboText()
end

local function animateCascadeCombos(cascade, showComboCounter)
    -- Propósito: Animar combos de una cascada respetando su orden de detección.
    -- Precondiciones:
    --   1. cascade.combos debe ser lista o nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(cascade) ~= "table" or type(cascade.combos) ~= "table" then
        return
    end

    for _, combo in ipairs(cascade.combos) do
        animateComboScaleOut(combo)
        registerResolvedCombo(showComboCounter)
    end
end

local function animateCascadeGravity(cascade)
    -- Propósito: Animar caída de fichas y relleno tras eliminar combinaciones.
    -- Precondiciones:
    --   1. localGrid debe representar el estado posterior a eliminación.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(cascade) ~= "table" or not localGrid then
        return
    end

    local movimientos = type(cascade.movimientos) == "table" and cascade.movimientos or {}
    local nuevas = type(cascade.nuevas) == "table" and cascade.nuevas or {}
    if #movimientos == 0 and #nuevas == 0 then
        return
    end

    local oldGrid = CombatGrid.cloneGrid(localGrid)

    for _, move in ipairs(movimientos) do
        if localGrid[move.fromCol] then
            localGrid[move.fromCol][move.fromRow] = nil
        end
    end
    rerender()

    local tweenInfo = TweenInfo.new(FALL_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tweens = {}
    local floatingTiles = {}

    for _, move in ipairs(movimientos) do
        local tile = oldGrid[move.fromCol] and oldGrid[move.fromCol][move.fromRow]
        local sourceBtn = cellButtons[move.fromCol] and cellButtons[move.fromCol][move.fromRow]
        local targetBtn = cellButtons[move.toCol] and cellButtons[move.toCol][move.toRow]
        if tile and sourceBtn and targetBtn then
            local sourcePos = sourceBtn.AbsolutePosition
            local targetPos = targetBtn.AbsolutePosition
            local floating = createFloatingTile(tile.elementType, Vector2.new(sourcePos.X + (CELL_SIZE * 0.5), sourcePos.Y + (CELL_SIZE * 0.5)))
            table.insert(floatingTiles, floating)
            table.insert(tweens, TweenService:Create(
                floating,
                tweenInfo,
                { Position = UDim2.new(0, targetPos.X + (CELL_SIZE * 0.5), 0, targetPos.Y + (CELL_SIZE * 0.5)) }
            ))
        end
    end

    for _, newTile in ipairs(nuevas) do
        local targetBtn = cellButtons[newTile.col] and cellButtons[newTile.col][newTile.row]
        if targetBtn then
            local targetPos = targetBtn.AbsolutePosition
            local spawnOffset = stepCellSize * (newTile.row + 1)
            local startPos = Vector2.new(targetPos.X + (CELL_SIZE * 0.5), targetPos.Y + (CELL_SIZE * 0.5) - spawnOffset)
            local floating = createFloatingTile(newTile.elementType, startPos)
            table.insert(floatingTiles, floating)
            table.insert(tweens, TweenService:Create(
                floating,
                tweenInfo,
                { Position = UDim2.new(0, targetPos.X + (CELL_SIZE * 0.5), 0, targetPos.Y + (CELL_SIZE * 0.5)) }
            ))
        end
    end

    playTweensAndWait(tweens)

    local bounceInfo = TweenInfo.new(BOUNCE_DURATION, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
    local bounceTweens = {}
    for _, floating in ipairs(floatingTiles) do
        table.insert(bounceTweens, TweenService:Create(floating, bounceInfo, { Size = UDim2.new(0, CELL_SIZE, 0, CELL_SIZE) }))
        floating.Size = UDim2.new(0, CELL_SIZE * 1.15, 0, CELL_SIZE * 1.15)
    end
    for _, tween in ipairs(bounceTweens) do
        tween:Play()
    end
    task.wait(BOUNCE_DURATION + 0.01)

    local nextGrid = CombatGrid.cloneGrid(oldGrid)
    for _, move in ipairs(movimientos) do
        local movedTile = oldGrid[move.fromCol] and oldGrid[move.fromCol][move.fromRow]
        nextGrid[move.fromCol][move.fromRow] = nil
        nextGrid[move.toCol][move.toRow] = copyTile(movedTile)
    end

    for _, newTile in ipairs(nuevas) do
        nextGrid[newTile.col][newTile.row] = {
            elementType = newTile.elementType,
        }
    end

    localGrid = nextGrid
    for _, floating in ipairs(floatingTiles) do
        floating:Destroy()
    end
    rerender()
end

local function animateServerCascades(cascades, finalGrid)
    -- Proposito: Ejecutar la secuencia completa de cascadas reportadas por servidor.
    -- Precondiciones:
    --   1. cascades debe ser lista.
    -- Ubicacion: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(cascades) ~= "table" or #cascades == 0 then
        localGrid = finalGrid
        rerender()
        return
    end

    local totalCombos = 0
    for _, cascade in ipairs(cascades) do
        if type(cascade.combos) == "table" then
            totalCombos = totalCombos + #cascade.combos
        end
    end

    local showComboCounter = totalCombos >= 2

    currentComboCount = 0

    for cascadeIndex, cascade in ipairs(cascades) do
        dbg("animando cascada " .. tostring(cascadeIndex) .. " con " .. tostring(type(cascade.combos) == "table" and #cascade.combos or 0) .. " combos")

        animateCascadeCombos(cascade, showComboCounter)
        animateCascadeGravity(cascade)
        task.wait(CASCADE_GAP_TIME)
    end

    if showComboCounter and currentComboText then
        task.spawn(hideComboTextWithFade)
    end

    localGrid = finalGrid
    rerender()
end

function normalizePointerPosition(pointerPos)
    -- Propósito: Normalizar coordenadas de input al espacio de ScreenGui.
    -- Precondiciones:
    --   1. pointerPos debe incluir X e Y.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: Vector2
    local insetTopLeft = GuiService:GetGuiInset()
    return Vector2.new(pointerPos.X - insetTopLeft.X, pointerPos.Y - insetTopLeft.Y)
end

local function getCellFromMouse(mousePos)
    -- Propósito: Obtener celda por cálculo matemático dentro del GridFrame.
    -- Precondiciones:
    --   1. mousePos debe tener X e Y.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: number|nil col, number|nil row
    local normalizedPos = normalizePointerPosition(mousePos)
    local gridPos = gridFrame.AbsolutePosition
    local gridSize = gridFrame.AbsoluteSize

    local localX = normalizedPos.X - gridPos.X
    local localY = normalizedPos.Y - gridPos.Y

    if localX < 0 or localY < 0 or localX > gridSize.X or localY > gridSize.Y then
        return nil, nil
    end

    local step = CELL_SIZE + CELL_PADDING
    local offsetX = localX % step
    local offsetY = localY % step

    -- Ignorar zonas de padding para evitar cambios de celda accidentales.
    if offsetX > CELL_SIZE or offsetY > CELL_SIZE then
        return nil, nil
    end

    local col = math.floor(localX / step) + 1
    local row = math.floor(localY / step) + 1

    if col < 1 or col > COLS or row < 1 or row > ROWS then
        return nil, nil
    end

    return col, row
end

local function setReject(key, reason)
    -- Propósito: Deduplicar logs de rechazo durante el drag.
    -- Precondiciones:
    --   1. key y reason deben ser strings.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if lastRejectReason ~= reason or lastRejectKey ~= key then
        dbg("rechazo en " .. key .. ": " .. reason)
        lastRejectReason = reason
        lastRejectKey = key
    end
end

local function setDragTarget(col, row)
    -- Propósito: Extender la ruta de swaps con una nueva celda adyacente.
    -- Precondiciones:
    --   1. dragCurrentCell debe existir.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not dragCurrentCell or not dragPath then
        return false
    end

    -- Ignorar coordenadas fuera del tablero
    if col < 1 or col > COLS or row < 1 or row > ROWS then
        return false
    end

    local key = cellKey(col, row)
    if dragCurrentCell.col == col and dragCurrentCell.row == row then
        return false
    end

    local nextCell = { col = col, row = row }
    if #dragPath >= 2 then
        local previousCell = dragPath[#dragPath - 1]
        if sameCell(previousCell, nextCell) then
            CombatGrid.swapCells(localGrid, dragCurrentCell, previousCell)
            table.remove(dragPath, #dragPath)
            dragCurrentCell = { col = previousCell.col, row = previousCell.row }
            dbg("backtrack swap -> fila " .. previousCell.row .. " col " .. previousCell.col)
            rerender()
            return true
        end
    end

    if not CombatGrid.areAdjacent(dragCurrentCell.col, dragCurrentCell.row, col, row) then
        setReject(cellKey(col, row), "swap no adyacente")
        return false
    end

    CombatGrid.swapCells(localGrid, dragCurrentCell, nextCell)
    table.insert(dragPath, nextCell)
    dragCurrentCell = nextCell
    dbg("swap aplicado= fila " .. row .. " col " .. col .. " | path=" .. tostring(#dragPath))
    rerender()
    return true
end

local function startTurn(col, row)
    -- Propósito: Iniciar un turno de arrastre con swaps sucesivos.
    -- Precondiciones:
    --   1. localGrid debe existir.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if turnActive or not localGrid then
        return
    end

    if isResolvingServerSync then
        return
    end

    if not duelStarted then
        return
    end

    turnActive = true
    isDragging = true
    turnTimeLeft = TURN_TIME
    dragStartGrid = CombatGrid.cloneGrid(localGrid)
    dragPath = { { col = col, row = row } }
    dragCurrentCell = { col = col, row = row }
    dragStartPos = UserInputService:GetMouseLocation()
    dragUnlocked = false
    lastHoverKey = nil
    lastSwapTime = 0
    lastRejectReason = nil
    lastRejectKey = nil

    dbg("turno iniciado en fila " .. row .. " col " .. col)
    rerender()
end

local function submitTurn()
    -- Propósito: Enviar la ruta completa de swaps al servidor y cerrar el turno local.
    -- Precondiciones:
    --   1. turnActive debe ser true.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if not turnActive then
        return
    end

    if isResolvingServerSync then
        return
    end

    if not duelStarted then
        return
    end

    turnActive = false
    isDragging = false
    timerBar.Size = UDim2.new(1, -8, 0, 10)

    if dragPath and #dragPath >= 2 then
        dbg("enviando path con " .. tostring(#dragPath) .. " celdas")
        CombatSubmit:FireServer({
            path = dragPath,
        })
    else
        dbg("turno descartado sin swaps ejecutados")
        if dragStartGrid then
            localGrid = dragStartGrid
        end
    end

    clearDragState()
    rerender()
end

local function connectCellInput()
    -- Propósito: Conectar input mouse/touch sobre la grilla.
    -- Precondiciones:
    --   1. cellButtons debe estar construido.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    for col = 1, COLS do
        for row = 1, ROWS do
            local btn = cellButtons[col][row]
            local c, r = col, row

            btn.MouseButton1Down:Connect(function()
                if not localGrid then
                    return
                end
                isPrimaryMouseDown = true
                dbg("MouseButton1Down en fila " .. r .. " col " .. c)
                startTurn(c, r)
            end)

            btn.MouseEnter:Connect(function()
                -- Propósito: Aplicar swap al entrar a una celda durante drag de mouse.
                -- Precondiciones:
                --   1. Debe existir un drag activo con botón principal presionado.
                -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
                -- Retorna: nil
                if not isDragging or not isPrimaryMouseDown or not dragCurrentCell then
                    return
                end

                local now = os.clock()
                if now - lastSwapTime < SWAP_COOLDOWN then
                    return
                end

                local targetKey = cellKey(c, r)
                if targetKey == lastHoverKey then
                    return
                end
                lastHoverKey = targetKey

                if not CombatGrid.areAdjacent(dragCurrentCell.col, dragCurrentCell.row, c, r) then
                    return
                end

                dbg("objetivo drag fila " .. r .. " col " .. c)
                local didSwap = setDragTarget(c, r)
                if didSwap then
                    lastSwapTime = now
                    dragStartPos = UserInputService:GetMouseLocation()
                end
            end)

            btn.TouchTap:Connect(function()
                if not localGrid then
                    return
                end
                dbg("TouchTap en fila " .. r .. " col " .. c)
                startTurn(c, r)
            end)
        end
    end

    RunService.RenderStepped:Connect(function()
        if not isDragging or not isPrimaryMouseDown or not dragCurrentCell then
            return
        end

        local mousePos = UserInputService:GetMouseLocation()
        showGhost(dragCurrentCell.col, dragCurrentCell.row, mousePos)
    end)

    UserInputService.InputBegan:Connect(function(input, _gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPrimaryMouseDown = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isPrimaryMouseDown = false
            ghostFrame.Visible = false
            dbg("MouseButton1Up")
            if isDragging then
                submitTurn()
            end
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.R then
            -- Propósito: Alternar visibilidad del tablero con tecla R.
            -- Precondiciones: container debe existir.
            -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
            -- Retorna: nil
            isGridVisible = not isGridVisible
            refreshGridVisibility()
            dbg("Tablero " .. (isGridVisible and "mostrado" or "oculto"))
        elseif input.KeyCode == Enum.KeyCode.Y then
            respondToChallenge(true)
        elseif input.KeyCode == Enum.KeyCode.N then
            respondToChallenge(false)
        end
    end)

    UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
        if gameProcessed then
            return
        end

        if not isDragging then
            return
        end
        showGhost(dragCurrentCell.col, dragCurrentCell.row, touch.Position)

        local now = os.clock()
        if now - lastSwapTime < SWAP_COOLDOWN then
            return
        end

        if not dragStartPos then
            dragStartPos = touch.Position
            return
        end

        local delta = touch.Position - dragStartPos
        if delta.Magnitude < DRAG_THRESHOLD then
            return
        end

        local hoverCol, hoverRow = getCellFromMouse(touch.Position)
        if not hoverCol or not hoverRow then
            return
        end

        if not CombatGrid.areAdjacent(dragCurrentCell.col, dragCurrentCell.row, hoverCol, hoverRow) then
            return
        end

        local col = hoverCol
        local row = hoverRow

        local targetKey = cellKey(col, row)
        if targetKey == lastHoverKey then
            return
        end
        lastHoverKey = targetKey

        dbg("objetivo touch fila " .. row .. " col " .. col)
        local didSwap = setDragTarget(col, row)
        if didSwap then
            lastSwapTime = now
            dragStartPos = touch.Position
        end
    end)

    UserInputService.TouchEnded:Connect(function(_touch, gameProcessed)
        if gameProcessed then
            return
        end

        if isDragging then
            submitTurn()
        end
    end)
end

connectCellInput()

RunService.Heartbeat:Connect(function(dt)
    if not turnActive then
        return
    end

    turnTimeLeft -= dt
    local ratio = math.clamp(turnTimeLeft / TURN_TIME, 0, 1)
    timerBar.Size = UDim2.new(ratio, -8 * ratio, 0, 10)

    if ratio > 0.5 then
        timerBar.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    elseif ratio > 0.25 then
        timerBar.BackgroundColor3 = Color3.fromRGB(240, 200, 40)
    else
        timerBar.BackgroundColor3 = Color3.fromRGB(220, 60, 40)
    end

    if turnTimeLeft <= 0 then
        submitTurn()
    end
end)

local function onCombatSync(data)
    -- Propósito: Recibir el grid canónico actualizado desde servidor.
    -- Precondiciones:
    --   1. data.grid debe ser tabla.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(data) ~= "table" or type(data.grid) ~= "table" then
        warn("[CombatUI] CombatSync recibió datos inválidos")
        return
    end

    dbg("CombatSync recibido" .. (data.reason and (" | " .. tostring(data.reason)) or ""))
    clearDragState()

    if type(data.duelActive) == "boolean" then
        duelActive = data.duelActive
    end
    if type(data.duelStarted) == "boolean" then
        duelStarted = data.duelStarted
    end
    setChallengePromptsEnabled(not duelActive)
    updateHPHud(data.selfHP or data.playerTotalHP, data.enemyHP, data.opponentName)
    refreshGridVisibility()

    local hasCascades = type(data.cascades) == "table" and #data.cascades > 0
    if not hasCascades or not localGrid then
        localGrid = data.grid
        rerender()
        return
    end

    if isResolvingServerSync then
        localGrid = data.grid
        rerender()
        return
    end

    isResolvingServerSync = true
    task.spawn(function()
        animateServerCascades(data.cascades, data.grid)
        isResolvingServerSync = false
    end)
end

CombatSync.OnClientEvent:Connect(onCombatSync)

CombatDuelState.OnClientEvent:Connect(function(data)
    -- Propósito: Actualizar UI de desafío/duelo según estados enviados por servidor.
    -- Precondiciones:
    --   1. data debe ser tabla válida.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: nil
    if type(data) ~= "table" or type(data.type) ~= "string" then
        return
    end

    if data.type == "challenge-received" then
        pendingChallengerUserId = data.challengerUserId
        challengeText.Text = tostring(data.challengerName) .. " te desafia a combatir"
        challengePrompt.Visible = true
        duelStatusLabel.Text = "Desafio recibido"
        return
    end

    if data.type == "challenge-sent" then
        duelStatusLabel.Text = "Desafio enviado a " .. tostring(data.targetName)
        if data.opponentKind == "monster" then
            suppressMonsterChallengePrompts(data.hideMonsterPromptSeconds or 4)
        end
        task.delay(3, function()
            if duelStatusLabel.Text == "Desafio enviado a " .. tostring(data.targetName) then
                duelStatusLabel.Text = ""
            end
        end)
        return
    end

    if data.type == "duel-intro" then
        duelActive = true
        duelStarted = false
        challengePrompt.Visible = false
        pendingChallengerUserId = nil
        countdownLabel.Visible = false
        countdownLabel.Text = ""
        setChallengePromptsEnabled(false)
        updateDuelMeta(data)
        updateHPHud(data.selfHP, data.enemyHP, data.opponentName)
        updateEnemyAvatar(data.opponentUserId, data.opponentName)
        if data.opponentKind == "monster" then
            setMonsterChallengePromptsEnabled(false)
        end
        task.spawn(function()
            playDuelIntro(data)
        end)
        duelStatusLabel.Text = "Preparando combate"
        refreshGridVisibility()
        return
    end

    if data.type == "challenge-declined" then
        duelStatusLabel.Text = tostring(data.targetName) .. " rechazo el desafio"
        task.delay(3, function()
            if duelStatusLabel.Text == tostring(data.targetName) .. " rechazo el desafio" then
                duelStatusLabel.Text = ""
            end
        end)
        return
    end

    if data.type == "challenge-expired" then
        challengePrompt.Visible = false
        pendingChallengerUserId = nil
        duelStatusLabel.Text = "El desafio expiro"
        task.delay(3, function()
            if duelStatusLabel.Text == "El desafio expiro" then
                duelStatusLabel.Text = ""
            end
        end)
        return
    end

    if data.type == "challenge-failed" then
        local msg = "No se pudo iniciar desafio: " .. tostring(data.reason)
        duelStatusLabel.Text = msg
        task.delay(3, function()
            if duelStatusLabel.Text == msg then
                duelStatusLabel.Text = ""
            end
        end)
        return
    end

    if data.type == "countdown" then
        duelActive = true
        duelStarted = false
        challengePrompt.Visible = false
        pendingChallengerUserId = nil
        setChallengePromptsEnabled(false)
        updateDuelMeta(data)
        updateHPHud(data.selfHP, data.enemyHP, data.opponentName)
        updateEnemyAvatar(data.opponentUserId, data.opponentName)
        if data.opponentKind == "monster" then
            setMonsterChallengePromptsEnabled(false)
        end
        countdownLabel.Visible = true
        countdownLabel.Text = tostring(data.value)
        duelStatusLabel.Text = "Combate inicia en " .. tostring(data.value)
        refreshGridVisibility()
        return
    end

    if data.type == "duel-started" then
        duelActive = true
        duelStarted = true
        setChallengePromptsEnabled(false)
        countdownLabel.Visible = false
        countdownLabel.Text = ""
        updateDuelMeta(data)
        hideDuelIntro()
        updateHPHud(data.selfHP, data.enemyHP, data.opponentName)
        updateEnemyAvatar(data.opponentUserId, data.opponentName)
        if data.opponentKind == "monster" then
            setMonsterChallengePromptsEnabled(false)
        end
        duelStatusLabel.Text = "Combate iniciado"
        refreshGridVisibility()
        return
    end

    if data.type == "duel-update" then
        updateDuelMeta(data)
        updateHPHud(data.selfHP, data.enemyHP, data.opponentName)
        updateEnemyAvatar(data.opponentUserId, data.opponentName)
        return
    end

    if data.type == "monster-attack" then
        -- Propósito: Mostrar el ataque del monstruo NPC en la UI y actualizar barras de HP.
        -- Precondiciones:
        --   1. data debe tener element, comboCount, damage, selfHP, enemyHP, opponentName.
        -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
        updateDuelMeta(data)
        updateHPHud(data.selfHP, data.enemyHP, data.opponentName)
        duelStatusLabel.Text = tostring(data.opponentName)
            .. " ataco con " .. tostring(data.element)
            .. " x" .. tostring(data.comboCount)
            .. "  (-" .. tostring(data.damage) .. " hp)"
        return
    end

    if data.type == "duel-ended" then
        duelActive = false
        duelStarted = false
        isResolvingServerSync = false
        hideDuelIntro()
        clearDragState()
        challengePrompt.Visible = false
        pendingChallengerUserId = nil
        setChallengePromptsEnabled(true)
        countdownLabel.Visible = false
        countdownLabel.Text = ""
        resetDuelHud()
        refreshGridVisibility()
        setMonsterChallengePromptsEnabled(true)
        local endMsg
        if type(data.winnerUserId) == "number" and data.winnerUserId == player.UserId then
            endMsg = "Victoria"
        elseif type(data.winnerUserId) == "number" then
            endMsg = "Derrota"
        else
            endMsg = "Combate finalizado"
        end
        duelStatusLabel.Text = endMsg
        task.delay(3, function()
            if duelStatusLabel.Text == endMsg then
                duelStatusLabel.Text = ""
            end
        end)
        return
    end
end)
