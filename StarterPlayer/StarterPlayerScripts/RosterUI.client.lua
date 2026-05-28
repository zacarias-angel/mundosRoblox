-- Tipo: LocalScript
-- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
-- Contexto: Cliente

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))
local Modules = ReplicatedStorage:WaitForChild("Modules")
local BeastibitVisuals = require(Modules:WaitForChild("BeastibitVisuals.module"))

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatDuelState = RemoteEvents:WaitForChild("CombatDuelState")
local CombatRosterAction = RemoteEvents:WaitForChild("CombatRosterAction")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local rosterBackpack = {}
local rosterDuelTeam = {}
local selectedFollowerMonsterId = nil
local selectedBackpackMonsterId = nil
local duelActive = false
local backpackItemButtons = {}
local BACKPACK_COLUMNS = 4
local BACKPACK_CELL_SIZE = 78
local BACKPACK_CELL_PADDING = 8

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RosterUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local rosterToggleButton = Instance.new("TextButton")
rosterToggleButton.Name = "RosterToggleButton"
rosterToggleButton.AnchorPoint = Vector2.new(0, 0)
rosterToggleButton.Position = UDim2.new(0, 16, 0, 16)
rosterToggleButton.Size = UDim2.new(0, 152, 0, 34)
rosterToggleButton.BackgroundColor3 = Color3.fromRGB(40, 85, 160)
rosterToggleButton.BorderSizePixel = 0
rosterToggleButton.Font = Enum.Font.GothamBold
rosterToggleButton.TextSize = 15
rosterToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rosterToggleButton.Text = "Mochila [B]"
rosterToggleButton.Parent = screenGui
rosterToggleButton.ZIndex = 30
Instance.new("UICorner", rosterToggleButton).CornerRadius = UDim.new(0, 8)

local rosterOverlay = Instance.new("Frame")
rosterOverlay.Name = "RosterOverlay"
rosterOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
rosterOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
rosterOverlay.Size = UDim2.new(0, 740, 0, 430)
rosterOverlay.BackgroundColor3 = Color3.fromRGB(14, 17, 27)
rosterOverlay.BackgroundTransparency = 0.05
rosterOverlay.BorderSizePixel = 0
rosterOverlay.Visible = false
rosterOverlay.ZIndex = 70
rosterOverlay.Parent = screenGui
Instance.new("UICorner", rosterOverlay).CornerRadius = UDim.new(0, 14)

local rosterTitle = Instance.new("TextLabel")
rosterTitle.Name = "Title"
rosterTitle.Position = UDim2.new(0, 16, 0, 10)
rosterTitle.Size = UDim2.new(0.65, 0, 0, 34)
rosterTitle.BackgroundTransparency = 1
rosterTitle.Font = Enum.Font.GothamBlack
rosterTitle.TextSize = 24
rosterTitle.TextXAlignment = Enum.TextXAlignment.Left
rosterTitle.TextColor3 = Color3.fromRGB(255, 240, 160)
rosterTitle.Text = "Mochila de Beastibit"
rosterTitle.ZIndex = 71
rosterTitle.Parent = rosterOverlay

local rosterCloseButton = Instance.new("TextButton")
rosterCloseButton.Name = "CloseButton"
rosterCloseButton.AnchorPoint = Vector2.new(1, 0)
rosterCloseButton.Position = UDim2.new(1, -14, 0, 12)
rosterCloseButton.Size = UDim2.new(0, 80, 0, 28)
rosterCloseButton.BackgroundColor3 = Color3.fromRGB(145, 62, 62)
rosterCloseButton.BorderSizePixel = 0
rosterCloseButton.Font = Enum.Font.GothamBold
rosterCloseButton.TextSize = 14
rosterCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rosterCloseButton.Text = "Cerrar"
rosterCloseButton.ZIndex = 71
rosterCloseButton.Parent = rosterOverlay
Instance.new("UICorner", rosterCloseButton).CornerRadius = UDim.new(0, 7)

local rosterInfoLabel = Instance.new("TextLabel")
rosterInfoLabel.Name = "Info"
rosterInfoLabel.Position = UDim2.new(0, 16, 0, 46)
rosterInfoLabel.Size = UDim2.new(1, -32, 0, 22)
rosterInfoLabel.BackgroundTransparency = 1
rosterInfoLabel.Font = Enum.Font.Gotham
rosterInfoLabel.TextSize = 14
rosterInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
rosterInfoLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
rosterInfoLabel.Text = "Selecciona un Beastibit desbloqueado para usarlo de seguidor o en tus slots de duelo."
rosterInfoLabel.ZIndex = 71
rosterInfoLabel.Parent = rosterOverlay

local rosterStatusLabel = Instance.new("TextLabel")
rosterStatusLabel.Name = "Status"
rosterStatusLabel.Position = UDim2.new(0, 16, 0, 66)
rosterStatusLabel.Size = UDim2.new(1, -32, 0, 18)
rosterStatusLabel.BackgroundTransparency = 1
rosterStatusLabel.Font = Enum.Font.Gotham
rosterStatusLabel.TextSize = 12
rosterStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
rosterStatusLabel.TextColor3 = Color3.fromRGB(255, 192, 120)
rosterStatusLabel.Text = ""
rosterStatusLabel.ZIndex = 71
rosterStatusLabel.Parent = rosterOverlay

local backpackList = Instance.new("ScrollingFrame")
backpackList.Name = "BackpackList"
backpackList.Position = UDim2.new(0, 16, 0, 92)
backpackList.Size = UDim2.new(0, 360, 1, -108)
backpackList.BackgroundColor3 = Color3.fromRGB(20, 23, 36)
backpackList.BorderSizePixel = 0
backpackList.CanvasSize = UDim2.new(0, 0, 0, 0)
backpackList.ScrollBarThickness = 7
backpackList.ZIndex = 71
backpackList.Parent = rosterOverlay
Instance.new("UICorner", backpackList).CornerRadius = UDim.new(0, 10)

local backpackLayout = Instance.new("UIGridLayout")
backpackLayout.CellSize = UDim2.new(0, BACKPACK_CELL_SIZE, 0, BACKPACK_CELL_SIZE)
backpackLayout.CellPadding = UDim2.new(0, BACKPACK_CELL_PADDING, 0, BACKPACK_CELL_PADDING)
backpackLayout.FillDirection = Enum.FillDirection.Horizontal
backpackLayout.FillDirectionMaxCells = BACKPACK_COLUMNS
backpackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
backpackLayout.SortOrder = Enum.SortOrder.LayoutOrder
backpackLayout.Parent = backpackList

local formationPanel = Instance.new("Frame")
formationPanel.Name = "FormationPanel"
formationPanel.Position = UDim2.new(0, 390, 0, 92)
formationPanel.Size = UDim2.new(1, -406, 1, -108)
formationPanel.BackgroundColor3 = Color3.fromRGB(20, 23, 36)
formationPanel.BorderSizePixel = 0
formationPanel.ZIndex = 71
formationPanel.Parent = rosterOverlay
Instance.new("UICorner", formationPanel).CornerRadius = UDim.new(0, 10)

local selectedTitle = Instance.new("TextLabel")
selectedTitle.Name = "SelectedTitle"
selectedTitle.Position = UDim2.new(0, 12, 0, 10)
selectedTitle.Size = UDim2.new(0.5, -8, 0, 18)
selectedTitle.BackgroundTransparency = 1
selectedTitle.Font = Enum.Font.GothamBold
selectedTitle.TextSize = 12
selectedTitle.TextXAlignment = Enum.TextXAlignment.Left
selectedTitle.TextColor3 = Color3.fromRGB(220, 228, 245)
selectedTitle.Text = "Seleccionado"
selectedTitle.ZIndex = 72
selectedTitle.Parent = formationPanel

local followerTitle = Instance.new("TextLabel")
followerTitle.Name = "FollowerTitle"
followerTitle.Position = UDim2.new(0.5, 8, 0, 10)
followerTitle.Size = UDim2.new(0.5, -20, 0, 18)
followerTitle.BackgroundTransparency = 1
followerTitle.Font = Enum.Font.GothamBold
followerTitle.TextSize = 12
followerTitle.TextXAlignment = Enum.TextXAlignment.Left
followerTitle.TextColor3 = Color3.fromRGB(160, 215, 255)
followerTitle.Text = "Seguidor"
followerTitle.ZIndex = 72
followerTitle.Parent = formationPanel

local selectedSlotFrame = Instance.new("ImageButton")
selectedSlotFrame.Name = "SelectedSlot"
selectedSlotFrame.Position = UDim2.new(0, 12, 0, 30)
selectedSlotFrame.Size = UDim2.new(0, 82, 0, 82)
selectedSlotFrame.BackgroundColor3 = Color3.fromRGB(48, 56, 86)
selectedSlotFrame.BorderSizePixel = 0
selectedSlotFrame.AutoButtonColor = false
selectedSlotFrame.Active = false
selectedSlotFrame.ZIndex = 72
selectedSlotFrame.Parent = formationPanel
Instance.new("UICorner", selectedSlotFrame).CornerRadius = UDim.new(0, 8)

local selectedSlotIcon = Instance.new("ImageLabel")
selectedSlotIcon.Name = "Icon"
selectedSlotIcon.Position = UDim2.new(0, 6, 0, 6)
selectedSlotIcon.Size = UDim2.new(1, -12, 1, -32)
selectedSlotIcon.BackgroundTransparency = 1
selectedSlotIcon.Image = "rbxassetid://0"
selectedSlotIcon.ZIndex = 73
selectedSlotIcon.Parent = selectedSlotFrame

local selectedSlotName = Instance.new("TextLabel")
selectedSlotName.Name = "Name"
selectedSlotName.AnchorPoint = Vector2.new(0.5, 1)
selectedSlotName.Position = UDim2.new(0.5, 0, 1, -4)
selectedSlotName.Size = UDim2.new(1, -8, 0, 20)
selectedSlotName.BackgroundTransparency = 0.3
selectedSlotName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
selectedSlotName.Font = Enum.Font.GothamBold
selectedSlotName.TextSize = 10
selectedSlotName.TextColor3 = Color3.fromRGB(255, 255, 255)
selectedSlotName.Text = "-"
selectedSlotName.ZIndex = 74
selectedSlotName.Parent = selectedSlotFrame
Instance.new("UICorner", selectedSlotName).CornerRadius = UDim.new(0, 5)

local selectedSlotBadge = Instance.new("TextLabel")
selectedSlotBadge.Name = "Badge"
selectedSlotBadge.Position = UDim2.new(0, 4, 0, 4)
selectedSlotBadge.Size = UDim2.new(0, 42, 0, 16)
selectedSlotBadge.BackgroundColor3 = Color3.fromRGB(39, 114, 66)
selectedSlotBadge.BackgroundTransparency = 0.2
selectedSlotBadge.Font = Enum.Font.GothamBold
selectedSlotBadge.TextSize = 9
selectedSlotBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
selectedSlotBadge.Text = "SEL"
selectedSlotBadge.ZIndex = 74
selectedSlotBadge.Visible = false
selectedSlotBadge.Parent = selectedSlotFrame
Instance.new("UICorner", selectedSlotBadge).CornerRadius = UDim.new(0, 4)

local followerSlotFrame = Instance.new("ImageButton")
followerSlotFrame.Name = "FollowerSlot"
followerSlotFrame.Position = UDim2.new(0.5, 8, 0, 30)
followerSlotFrame.Size = UDim2.new(0, 82, 0, 82)
followerSlotFrame.BackgroundColor3 = Color3.fromRGB(48, 56, 86)
followerSlotFrame.BorderSizePixel = 0
followerSlotFrame.AutoButtonColor = false
followerSlotFrame.Active = false
followerSlotFrame.ZIndex = 72
followerSlotFrame.Parent = formationPanel
Instance.new("UICorner", followerSlotFrame).CornerRadius = UDim.new(0, 8)

local followerSlotIcon = Instance.new("ImageLabel")
followerSlotIcon.Name = "Icon"
followerSlotIcon.Position = UDim2.new(0, 6, 0, 6)
followerSlotIcon.Size = UDim2.new(1, -12, 1, -32)
followerSlotIcon.BackgroundTransparency = 1
followerSlotIcon.Image = "rbxassetid://0"
followerSlotIcon.ZIndex = 73
followerSlotIcon.Parent = followerSlotFrame

local followerSlotName = Instance.new("TextLabel")
followerSlotName.Name = "Name"
followerSlotName.AnchorPoint = Vector2.new(0.5, 1)
followerSlotName.Position = UDim2.new(0.5, 0, 1, -4)
followerSlotName.Size = UDim2.new(1, -8, 0, 20)
followerSlotName.BackgroundTransparency = 0.3
followerSlotName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
followerSlotName.Font = Enum.Font.GothamBold
followerSlotName.TextSize = 10
followerSlotName.TextColor3 = Color3.fromRGB(255, 255, 255)
followerSlotName.Text = "-"
followerSlotName.ZIndex = 74
followerSlotName.Parent = followerSlotFrame
Instance.new("UICorner", followerSlotName).CornerRadius = UDim.new(0, 5)

local followerSlotBadge = Instance.new("TextLabel")
followerSlotBadge.Name = "Badge"
followerSlotBadge.Position = UDim2.new(0, 4, 0, 4)
followerSlotBadge.Size = UDim2.new(0, 50, 0, 16)
followerSlotBadge.BackgroundColor3 = Color3.fromRGB(38, 132, 173)
followerSlotBadge.BackgroundTransparency = 0.2
followerSlotBadge.Font = Enum.Font.GothamBold
followerSlotBadge.TextSize = 9
followerSlotBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
followerSlotBadge.Text = "FOLLOW"
followerSlotBadge.ZIndex = 74
followerSlotBadge.Visible = false
followerSlotBadge.Parent = followerSlotFrame
Instance.new("UICorner", followerSlotBadge).CornerRadius = UDim.new(0, 4)

local chooseFollowerButton = Instance.new("TextButton")
chooseFollowerButton.Name = "ChooseFollowerButton"
chooseFollowerButton.Position = UDim2.new(0, 12, 0, 120)
chooseFollowerButton.Size = UDim2.new(1, -24, 0, 34)
chooseFollowerButton.BackgroundColor3 = Color3.fromRGB(62, 137, 94)
chooseFollowerButton.BorderSizePixel = 0
chooseFollowerButton.Font = Enum.Font.GothamBold
chooseFollowerButton.TextSize = 15
chooseFollowerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
chooseFollowerButton.Text = "Elegir como seguidor"
chooseFollowerButton.ZIndex = 72
chooseFollowerButton.Parent = formationPanel
Instance.new("UICorner", chooseFollowerButton).CornerRadius = UDim.new(0, 8)

local formationTitle = Instance.new("TextLabel")
formationTitle.Name = "FormationTitle"
formationTitle.Position = UDim2.new(0, 12, 0, 162)
formationTitle.Size = UDim2.new(1, -24, 0, 22)
formationTitle.BackgroundTransparency = 1
formationTitle.Font = Enum.Font.GothamBold
formationTitle.TextSize = 15
formationTitle.TextXAlignment = Enum.TextXAlignment.Left
formationTitle.TextColor3 = Color3.fromRGB(255, 220, 150)
formationTitle.Text = "Formación de duelo (5 slots)"
formationTitle.ZIndex = 72
formationTitle.Parent = formationPanel

local slotButtons = {}
local teamGrid = Instance.new("Frame")
teamGrid.Name = "TeamGrid"
teamGrid.Position = UDim2.new(0, 12, 0, 188)
teamGrid.Size = UDim2.new(1, -24, 0, 58)
teamGrid.BackgroundTransparency = 1
teamGrid.ZIndex = 72
teamGrid.Parent = formationPanel

local teamGridLayout = Instance.new("UIGridLayout")
teamGridLayout.CellSize = UDim2.new(0, 52, 0, 52)
teamGridLayout.CellPadding = UDim2.new(0, 6, 0, 0)
teamGridLayout.FillDirection = Enum.FillDirection.Horizontal
teamGridLayout.FillDirectionMaxCells = 5
teamGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
teamGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
teamGridLayout.Parent = teamGrid

for slotIndex = 1, 5 do
    local slotButton = Instance.new("ImageButton")
    slotButton.Name = "SlotButton_" .. tostring(slotIndex)
    slotButton.LayoutOrder = slotIndex
    slotButton.Size = UDim2.new(0, 52, 0, 52)
    slotButton.BackgroundColor3 = Color3.fromRGB(48, 56, 86)
    slotButton.BorderSizePixel = 0
    slotButton.AutoButtonColor = true
    slotButton.ZIndex = 72
    slotButton.Parent = teamGrid
    Instance.new("UICorner", slotButton).CornerRadius = UDim.new(0, 8)

    local slotIcon = Instance.new("ImageLabel")
    slotIcon.Name = "Icon"
    slotIcon.Position = UDim2.new(0, 4, 0, 4)
    slotIcon.Size = UDim2.new(1, -8, 1, -22)
    slotIcon.BackgroundTransparency = 1
    slotIcon.Image = "rbxassetid://0"
    slotIcon.ZIndex = 73
    slotIcon.Parent = slotButton

    local slotName = Instance.new("TextLabel")
    slotName.Name = "Name"
    slotName.AnchorPoint = Vector2.new(0.5, 1)
    slotName.Position = UDim2.new(0.5, 0, 1, -2)
    slotName.Size = UDim2.new(1, -4, 0, 14)
    slotName.BackgroundTransparency = 0.3
    slotName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    slotName.Font = Enum.Font.GothamBold
    slotName.TextSize = 8
    slotName.TextColor3 = Color3.fromRGB(255, 255, 255)
    slotName.Text = tostring(slotIndex)
    slotName.ZIndex = 74
    slotName.Parent = slotButton
    Instance.new("UICorner", slotName).CornerRadius = UDim.new(0, 4)

    local slotBadge = Instance.new("TextLabel")
    slotBadge.Name = "Badge"
    slotBadge.Position = UDim2.new(0, 3, 0, 3)
    slotBadge.Size = UDim2.new(0, 20, 0, 12)
    slotBadge.BackgroundColor3 = Color3.fromRGB(102, 70, 30)
    slotBadge.BackgroundTransparency = 0.2
    slotBadge.Font = Enum.Font.GothamBold
    slotBadge.TextSize = 8
    slotBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    slotBadge.Text = tostring(slotIndex)
    slotBadge.ZIndex = 74
    slotBadge.Visible = true
    slotBadge.Parent = slotButton
    Instance.new("UICorner", slotBadge).CornerRadius = UDim.new(0, 3)

    slotButtons[slotIndex] = slotButton
end

local rosterHintLabel = Instance.new("TextLabel")
rosterHintLabel.Name = "Hint"
rosterHintLabel.Position = UDim2.new(0, 12, 1, -22)
rosterHintLabel.Size = UDim2.new(1, -24, 0, 18)
rosterHintLabel.BackgroundTransparency = 1
rosterHintLabel.Font = Enum.Font.Gotham
rosterHintLabel.TextSize = 12
rosterHintLabel.TextXAlignment = Enum.TextXAlignment.Left
rosterHintLabel.TextColor3 = Color3.fromRGB(170, 176, 196)
rosterHintLabel.Text = "Tip: primero selecciona en mochila y luego pulsa un slot para asignar."
rosterHintLabel.ZIndex = 72
rosterHintLabel.Parent = formationPanel

local function getMonsterDisplayName(monsterId)
    -- Propósito: Resolver el nombre visible de un Beastibit usando MonstersData.
    -- Precondiciones:
    --   1. monsterId puede ser string o nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: string
    if type(monsterId) ~= "string" then
        return "-"
    end

    local data = MonstersData[monsterId]
    if data and type(data.Name) == "string" and data.Name ~= "" then
        return data.Name
    end

    return monsterId
end

local function getMonsterImage(monsterId)
    -- Propósito: Resolver el asset id de imagen del Beastibit con fallback seguro.
    -- Precondiciones:
    --   1. monsterId puede ser string o nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: string
    return BeastibitVisuals.getImageByMonsterId(MonstersData, monsterId)
end

local function paintSlot(slot, monsterId, unlocked, badgeText, isSelected)
    -- Propósito: Pintar una ranura con imagen, nombre, badge y estado visual.
    -- Precondiciones:
    --   1. slot debe contener hijos Icon, Name y Badge.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    local icon = slot:FindFirstChild("Icon")
    local nameLabel = slot:FindFirstChild("Name")
    local badge = slot:FindFirstChild("Badge")

    if not icon or not nameLabel or not badge then
        return
    end

    local displayName = getMonsterDisplayName(monsterId)
    icon.Image = getMonsterImage(monsterId)
    nameLabel.Text = displayName

    if unlocked == false then
        slot.BackgroundColor3 = Color3.fromRGB(60, 52, 52)
        icon.ImageColor3 = Color3.fromRGB(120, 120, 120)
        nameLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
    elseif isSelected then
        slot.BackgroundColor3 = Color3.fromRGB(74, 118, 176)
        icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        slot.BackgroundColor3 = Color3.fromRGB(48, 56, 86)
        icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end

    badge.Visible = type(badgeText) == "string" and badgeText ~= ""
    badge.Text = tostring(badgeText or "")
end

local function setRosterStatus(text)
    -- Propósito: Actualizar el texto de estado local de la mochila.
    -- Precondiciones:
    --   1. text puede ser string o nil.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    rosterStatusLabel.Text = tostring(text or "")
end

local function clearBackpackButtons()
    -- Propósito: Destruir las filas dinámicas anteriores de la mochila.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    for _, button in ipairs(backpackItemButtons) do
        if button and button.Parent then
            button:Destroy()
        end
    end

    backpackItemButtons = {}
end

local function requestRosterSync()
    -- Propósito: Solicitar al servidor el estado actualizado de mochila y formación.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    CombatRosterAction:FireServer({ action = "request" })
end

local function setRosterVisible(visible)
    -- Propósito: Mostrar u ocultar el panel de mochila de forma segura.
    -- Precondiciones:
    --   1. visible debe ser boolean.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    if duelActive and visible == true then
        return
    end

    rosterOverlay.Visible = visible == true
    if rosterOverlay.Visible then
        setRosterStatus("")
        requestRosterSync()
    end
end

local function selectBackpackMonster(monsterId)
    -- Propósito: Guardar el Beastibit seleccionado en la mochila local.
    -- Precondiciones:
    --   1. monsterId debe ser string.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    selectedBackpackMonsterId = monsterId
end

local function refreshRosterUi()
    -- Propósito: Redibujar la mochila y la formación con el estado local actual.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    paintSlot(selectedSlotFrame, selectedBackpackMonsterId, true, "SEL", selectedBackpackMonsterId ~= nil)
    paintSlot(followerSlotFrame, selectedFollowerMonsterId, true, "FOLLOW", false)

    for slotIndex = 1, 5 do
        local pet = rosterDuelTeam[slotIndex]
        local monsterId = pet and pet.MonsterId or nil
        local badgeText = tostring(slotIndex)
        local isSelected = selectedBackpackMonsterId ~= nil and selectedBackpackMonsterId == monsterId
        paintSlot(slotButtons[slotIndex], monsterId, true, badgeText, isSelected)
    end

    clearBackpackButtons()

    for index, item in ipairs(rosterBackpack) do
        local monsterId = item.MonsterId
        local unlocked = item.Unlocked == true
        local button = Instance.new("ImageButton")
        local followerTag = selectedFollowerMonsterId == monsterId and "  [SEGUIDOR]" or ""

        button.Name = "BackpackItem_" .. tostring(index)
        button.Size = UDim2.new(0, BACKPACK_CELL_SIZE, 0, BACKPACK_CELL_SIZE)
        button.LayoutOrder = index
        button.BackgroundColor3 = unlocked and Color3.fromRGB(50, 68, 108) or Color3.fromRGB(52, 52, 58)
        button.BorderSizePixel = 0
        button.AutoButtonColor = unlocked
        button.ZIndex = 72
        button.Parent = backpackList
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

        local slotIcon = Instance.new("ImageLabel")
        slotIcon.Name = "Icon"
        slotIcon.Position = UDim2.new(0, 5, 0, 5)
        slotIcon.Size = UDim2.new(1, -10, 1, -30)
        slotIcon.BackgroundTransparency = 1
        slotIcon.Image = getMonsterImage(monsterId)
        slotIcon.ImageColor3 = unlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
        slotIcon.ZIndex = 73
        slotIcon.Parent = button

        local slotName = Instance.new("TextLabel")
        slotName.Name = "Name"
        slotName.AnchorPoint = Vector2.new(0.5, 1)
        slotName.Position = UDim2.new(0.5, 0, 1, -4)
        slotName.Size = UDim2.new(1, -6, 0, 20)
        slotName.BackgroundTransparency = 0.25
        slotName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        slotName.Font = Enum.Font.GothamBold
        slotName.TextSize = 9
        slotName.TextColor3 = unlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180)
        slotName.Text = tostring(getMonsterDisplayName(monsterId))
        slotName.ZIndex = 74
        slotName.Parent = button
        Instance.new("UICorner", slotName).CornerRadius = UDim.new(0, 4)

        local slotBadge = Instance.new("TextLabel")
        slotBadge.Name = "Badge"
        slotBadge.Position = UDim2.new(0, 4, 0, 4)
        slotBadge.Size = UDim2.new(0, 56, 0, 15)
        slotBadge.BackgroundColor3 = unlocked and Color3.fromRGB(39, 114, 66) or Color3.fromRGB(126, 81, 38)
        slotBadge.BackgroundTransparency = 0.2
        slotBadge.Font = Enum.Font.GothamBold
        slotBadge.TextSize = 8
        slotBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
        slotBadge.Text = unlocked and "UNLOCK" or "LOCK"
        slotBadge.ZIndex = 74
        slotBadge.Parent = button
        Instance.new("UICorner", slotBadge).CornerRadius = UDim.new(0, 4)

        if followerTag ~= "" then
            slotBadge.Text = "FOLLOW"
            slotBadge.BackgroundColor3 = Color3.fromRGB(38, 132, 173)
        end

        if selectedBackpackMonsterId == monsterId then
            button.BackgroundColor3 = unlocked and Color3.fromRGB(74, 118, 176) or Color3.fromRGB(85, 78, 78)
        end

        button.MouseButton1Click:Connect(function()
            if not unlocked then
                setRosterStatus("Este Beastibit está bloqueado")
                return
            end

            setRosterStatus("")
            selectBackpackMonster(monsterId)
            refreshRosterUi()
        end)

        table.insert(backpackItemButtons, button)
    end

    local rows = math.max(1, math.ceil(#rosterBackpack / BACKPACK_COLUMNS))
    local contentHeight = (rows * BACKPACK_CELL_SIZE) + ((rows - 1) * BACKPACK_CELL_PADDING) + 10
    backpackList.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end

local function applyRosterState(data)
    -- Propósito: Aplicar al cliente el estado de mochila recibido desde servidor.
    -- Precondiciones:
    --   1. data debe ser tabla serializable con backpack y duelTeam opcionales.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    rosterBackpack = type(data.backpack) == "table" and data.backpack or rosterBackpack
    rosterDuelTeam = type(data.duelTeam) == "table" and data.duelTeam or rosterDuelTeam

    if type(data.selectedFollowerMonsterId) == "string" then
        selectedFollowerMonsterId = data.selectedFollowerMonsterId
    end

    if not selectedBackpackMonsterId and selectedFollowerMonsterId then
        selectedBackpackMonsterId = selectedFollowerMonsterId
    end

    refreshRosterUi()
end

local function sendFollowerSelection()
    -- Propósito: Pedir al servidor que cambie el seguidor actual del jugador.
    -- Precondiciones:
    --   1. Debe haber un Beastibit seleccionado.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    if not selectedBackpackMonsterId then
        setRosterStatus("Selecciona un Beastibit de la mochila primero")
        return
    end

    CombatRosterAction:FireServer({
        action = "select-follower",
        monsterId = selectedBackpackMonsterId,
    })
end

local function sendSlotSelection(slotIndex)
    -- Propósito: Pedir al servidor que asigne el Beastibit seleccionado a un slot del duelo.
    -- Precondiciones:
    --   1. slotIndex debe ser number entre 1 y 5.
    --   2. Debe haber un Beastibit seleccionado.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    if not selectedBackpackMonsterId then
        setRosterStatus("Selecciona un Beastibit para asignar al slot")
        return
    end

    CombatRosterAction:FireServer({
        action = "set-duel-slot",
        slotIndex = slotIndex,
        monsterId = selectedBackpackMonsterId,
    })
end

local function handleDuelState(data)
    -- Propósito: Reaccionar a eventos de duelo y de mochila enviados por el servidor.
    -- Precondiciones:
    --   1. data debe ser tabla con campo type string.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    if type(data) ~= "table" or type(data.type) ~= "string" then
        return
    end

    if data.type == "roster-sync" then
        setRosterStatus("")
        applyRosterState(data)
        return
    end

    if data.type == "roster-error" then
        setRosterStatus("Mochila: " .. tostring(data.reason or "error"))
        return
    end

    if data.type == "duel-intro" or data.type == "countdown" or data.type == "duel-started" then
        duelActive = true
        setRosterVisible(false)
        rosterToggleButton.Visible = false
        return
    end

    if data.type == "duel-ended" or data.type == "challenge-declined" or data.type == "challenge-expired" then
        duelActive = false
        rosterToggleButton.Visible = true
        return
    end
end

local function applySafeAreaLayout()
    -- Propósito: Ajustar botón/panel de mochila respetando safe area (topbar/notch).
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(720, 1280)

    local insetTopLeft, insetBottomRight = GuiService:GetGuiInset()
    local safePadding = 12
    local safeWidth = math.max(320, viewport.X - insetTopLeft.X - insetBottomRight.X)
    local safeHeight = math.max(260, viewport.Y - insetTopLeft.Y - insetBottomRight.Y)

    rosterToggleButton.Position = UDim2.new(0, insetTopLeft.X + safePadding, 0, insetTopLeft.Y + safePadding)
    rosterOverlay.Size = UDim2.new(
        0,
        math.min(740, safeWidth - (safePadding * 2)),
        0,
        math.min(430, safeHeight - (safePadding * 2))
    )
    rosterOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
end

local function connectUi()
    -- Propósito: Conectar botones, teclas y remotos del panel de mochila.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    rosterToggleButton.MouseButton1Click:Connect(function()
        setRosterVisible(not rosterOverlay.Visible)
    end)

    rosterCloseButton.MouseButton1Click:Connect(function()
        setRosterVisible(false)
    end)

    chooseFollowerButton.MouseButton1Click:Connect(sendFollowerSelection)

    for slotIndex, slotButton in ipairs(slotButtons) do
        slotButton.MouseButton1Click:Connect(function()
            sendSlotSelection(slotIndex)
        end)
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.KeyCode == Enum.KeyCode.B then
            setRosterVisible(not rosterOverlay.Visible)
        end
    end)

    CombatDuelState.OnClientEvent:Connect(handleDuelState)

    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            applySafeAreaLayout()
        end)
    end
end

local function init()
    -- Propósito: Inicializar la UI independiente de mochila y pedir el primer sync.
    -- Precondiciones: Ninguna.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/RosterUI.client
    -- Retorna: nil
    applySafeAreaLayout()
    refreshRosterUi()
    connectUi()
    task.delay(0.4, function()
        requestRosterSync()
    end)
end

init()