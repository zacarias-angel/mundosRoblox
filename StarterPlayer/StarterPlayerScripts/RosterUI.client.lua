-- Tipo: LocalScript
-- Ubicacion: StarterPlayer/StarterPlayerScripts/RosterUI.client
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
local rosterFragments = {}
local rosterEvolutions = {}
local rosterXP = {}
local playerPvpTitle = "Rookie"
local playerShieldCharges = 0
local playerPvpStars = 0

local OVERLAY_W = 780
local OVERLAY_H = 480
local TAB_BUTTON_H = 36
local NAV_HEIGHT = TAB_BUTTON_H + 16

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RosterUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ============================================================
-- BOTON TOGGLE
-- ============================================================
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
rosterToggleButton.Text = "Dashboard [B]"
rosterToggleButton.Parent = screenGui
rosterToggleButton.ZIndex = 30
Instance.new("UICorner", rosterToggleButton).CornerRadius = UDim.new(0, 8)

-- ============================================================
-- OVERLAY
-- ============================================================
local rosterOverlay = Instance.new("Frame")
rosterOverlay.Name = "RosterOverlay"
rosterOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
rosterOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
rosterOverlay.Size = UDim2.new(0, OVERLAY_W, 0, OVERLAY_H)
rosterOverlay.BackgroundColor3 = Color3.fromRGB(14, 17, 27)
rosterOverlay.BackgroundTransparency = 0.05
rosterOverlay.BorderSizePixel = 0
rosterOverlay.Visible = false
rosterOverlay.ZIndex = 70
rosterOverlay.Parent = screenGui
Instance.new("UICorner", rosterOverlay).CornerRadius = UDim.new(0, 14)

-- ============================================================
-- HEADER TITLE
-- ============================================================
local headerTitle = Instance.new("TextLabel")
headerTitle.Name = "HeaderTitle"
headerTitle.Position = UDim2.new(0, 16, 0, 10)
headerTitle.Size = UDim2.new(0.5, 0, 0, 24)
headerTitle.BackgroundTransparency = 1
headerTitle.Font = Enum.Font.GothamBlack
headerTitle.TextSize = 20
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.TextColor3 = Color3.fromRGB(255, 240, 160)
headerTitle.Text = "Dashboard"
headerTitle.ZIndex = 71
headerTitle.Parent = rosterOverlay

-- PvP Info line
local pvpInfoLabel = Instance.new("TextLabel")
pvpInfoLabel.Name = "PvpInfo"
pvpInfoLabel.AnchorPoint = Vector2.new(1, 0)
pvpInfoLabel.Position = UDim2.new(1, -90, 0, 12)
pvpInfoLabel.Size = UDim2.new(0, 220, 0, 20)
pvpInfoLabel.BackgroundTransparency = 1
pvpInfoLabel.Font = Enum.Font.GothamBold
pvpInfoLabel.TextSize = 13
pvpInfoLabel.TextXAlignment = Enum.TextXAlignment.Right
pvpInfoLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
pvpInfoLabel.Text = ""
pvpInfoLabel.ZIndex = 71
pvpInfoLabel.Parent = rosterOverlay

-- ============================================================
-- CLOSE BUTTON
-- ============================================================
local rosterCloseButton = Instance.new("TextButton")
rosterCloseButton.Name = "CloseButton"
rosterCloseButton.AnchorPoint = Vector2.new(1, 0)
rosterCloseButton.Position = UDim2.new(1, -14, 0, 10)
rosterCloseButton.Size = UDim2.new(0, 70, 0, 26)
rosterCloseButton.BackgroundColor3 = Color3.fromRGB(145, 62, 62)
rosterCloseButton.BorderSizePixel = 0
rosterCloseButton.Font = Enum.Font.GothamBold
rosterCloseButton.TextSize = 13
rosterCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rosterCloseButton.Text = "Cerrar"
rosterCloseButton.ZIndex = 71
rosterCloseButton.Parent = rosterOverlay
Instance.new("UICorner", rosterCloseButton).CornerRadius = UDim.new(0, 7)

-- ============================================================
-- NAV BAR
-- ============================================================
local TAB_NAMES = { "Inventario", "Beastibit", "Team", "Seguidor", "Craft" }
local tabButtons = {}
local tabFrames = {}
local tabRefreshers = {}
local currentTab = "Inventario"

local navBar = Instance.new("Frame")
navBar.Name = "NavBar"
navBar.Position = UDim2.new(0, 14, 0, NAV_HEIGHT - TAB_BUTTON_H - 2)
navBar.Size = UDim2.new(1, -28, 0, TAB_BUTTON_H)
navBar.BackgroundTransparency = 1
navBar.ZIndex = 71
navBar.Parent = rosterOverlay

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
navLayout.Padding = UDim.new(0, 4)
navLayout.Parent = navBar

for _, tabName in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.Name = "NavBtn_" .. tabName
	btn.Size = UDim2.new(0, 100, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(35, 40, 60)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(180, 190, 210)
	btn.Text = tabName
	btn.ZIndex = 72
	btn.Parent = navBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	tabButtons[tabName] = btn
end

-- ============================================================
-- CONTENT AREA
-- ============================================================
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Position = UDim2.new(0, 14, 0, NAV_HEIGHT + 4)
contentFrame.Size = UDim2.new(1, -28, 1, -NAV_HEIGHT - 18)
contentFrame.BackgroundColor3 = Color3.fromRGB(18, 21, 33)
contentFrame.BorderSizePixel = 0
contentFrame.ZIndex = 71
contentFrame.Parent = rosterOverlay
Instance.new("UICorner", contentFrame).CornerRadius = UDim.new(0, 10)

local function createTabFrame(tabName)
	local frame = Instance.new("Frame")
	frame.Name = "Tab_" .. tabName
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 72
	frame.Visible = false
	frame.Parent = contentFrame
	tabFrames[tabName] = frame
	return frame
end

-- ============================================================
-- HELPERS
-- ============================================================
local function getMonsterDisplayName(monsterId)
	if type(monsterId) ~= "string" then return "-" end
	local data = MonstersData[monsterId]
	if data and type(data.Name) == "string" and data.Name ~= "" then
		return data.Name
	end
	return monsterId
end

local function getMonsterImage(monsterId)
	return BeastibitVisuals.getImageByMonsterId(MonstersData, monsterId)
end

local function getMonsterRarity(monsterId)
	local data = MonstersData[monsterId]
	if data and type(data.Rarity) == "string" then
		return string.lower(data.Rarity)
	end
	return "common"
end

local RARITY_COLORS = {
	common = Color3.fromRGB(140, 145, 155),
	rare = Color3.fromRGB(80, 160, 220),
	epic = Color3.fromRGB(180, 80, 220),
	legendary = Color3.fromRGB(255, 180, 40),
}

local ELEMENT_COLORS = {
	Fuego = Color3.fromRGB(220, 60, 40),
	Agua = Color3.fromRGB(60, 140, 220),
	Planta = Color3.fromRGB(60, 180, 70),
	Electricidad = Color3.fromRGB(240, 210, 30),
	Roca = Color3.fromRGB(140, 120, 100),
}

-- ============================================================
-- INVENTARIO TAB
-- ============================================================
local function buildInventarioTab()
	local tab = createTabFrame("Inventario")

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "InvScroll"
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.BackgroundTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 400)
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 73
	scroll.Parent = tab

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	local function addSection(title, layoutOrder)
		local sectionFrame = Instance.new("Frame")
		sectionFrame.Name = "Section_" .. title
		sectionFrame.Size = UDim2.new(1, 0, 0, 36)
		sectionFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
		sectionFrame.BorderSizePixel = 0
		sectionFrame.LayoutOrder = layoutOrder
		sectionFrame.ZIndex = 74
		sectionFrame.Parent = scroll
		Instance.new("UICorner", sectionFrame).CornerRadius = UDim.new(0, 8)

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "SectionTitle"
		titleLabel.Position = UDim2.new(0, 10, 0, 8)
		titleLabel.Size = UDim2.new(1, -20, 0, 20)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 14
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextColor3 = Color3.fromRGB(255, 220, 130)
		titleLabel.Text = title
		titleLabel.ZIndex = 75
		titleLabel.Parent = sectionFrame

		return sectionFrame
	end

	local function addItemRow(parent, icon, name, count, layoutOrder)
		local row = Instance.new("Frame")
		row.Name = "Row_" .. name
		row.Size = UDim2.new(1, 0, 0, 44)
		row.BackgroundColor3 = Color3.fromRGB(26, 30, 46)
		row.BorderSizePixel = 0
		row.ZIndex = 75
		row.Parent = parent
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local itemIcon = Instance.new("ImageLabel")
		itemIcon.Name = "Icon"
		itemIcon.Position = UDim2.new(0, 6, 0, 4)
		itemIcon.Size = UDim2.new(0, 36, 0, 36)
		itemIcon.BackgroundTransparency = 1
		itemIcon.Image = icon
		itemIcon.ZIndex = 76
		itemIcon.Parent = row

		local itemName = Instance.new("TextLabel")
		itemName.Name = "Name"
		itemName.Position = UDim2.new(0, 48, 0, 6)
		itemName.Size = UDim2.new(1, -130, 0, 32)
		itemName.BackgroundTransparency = 1
		itemName.Font = Enum.Font.GothamBold
		itemName.TextSize = 14
		itemName.TextXAlignment = Enum.TextXAlignment.Left
		itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
		itemName.Text = name
		itemName.ZIndex = 76
		itemName.Parent = row

		local itemCount = Instance.new("TextLabel")
		itemCount.Name = "Count"
		itemCount.AnchorPoint = Vector2.new(1, 0)
		itemCount.Position = UDim2.new(1, -8, 0, 6)
		itemCount.Size = UDim2.new(0, 80, 0, 32)
		itemCount.BackgroundTransparency = 1
		itemCount.Font = Enum.Font.GothamBold
		itemCount.TextSize = 16
		itemCount.TextXAlignment = Enum.TextXAlignment.Right
		itemCount.TextColor3 = Color3.fromRGB(255, 230, 100)
		itemCount.Text = tostring(count)
		itemCount.ZIndex = 76
		itemCount.Parent = row

		return row
	end

	-- Bits section
	local bitsSection = addSection("Bits", 1)
	local bitsRow = addItemRow(bitsSection, "rbxassetid://0", "Bits", 0, 1)
	bitsSection.Size = UDim2.new(1, 0, 0, 52)

	-- Fragmentos section
	local fragSection = addSection("Fragmentos", 2)
	local fragRows = {}

	-- Minerales section
	local minSection = addSection("Minerales", 3)
	local minRows = {}

	tabRefreshers["Inventario"] = function()
		local bits = tonumber(player:GetAttribute("Bits")) or 0
		bitsRow:FindFirstChild("Count").Text = tostring(bits)

		for _, row in ipairs(fragRows) do
			row:Destroy()
		end
		fragRows = {}

		local sortedFrags = {}
		for monsterId, amount in pairs(rosterFragments) do
			if amount > 0 then
				table.insert(sortedFrags, { monsterId = monsterId, amount = amount })
			end
		end
		table.sort(sortedFrags, function(a, b) return a.amount > b.amount end)

		local fragY = 52
		for _, entry in ipairs(sortedFrags) do
			local row = addItemRow(fragSection, getMonsterImage(entry.monsterId),
				"Fragmento " .. getMonsterDisplayName(entry.monsterId), entry.amount, 1)
			row.Position = UDim2.new(0, 0, 0, fragY)
			row.LayoutOrder = nil
			fragY = fragY + 48
			table.insert(fragRows, row)
		end
		fragSection.Size = UDim2.new(1, 0, 0, math.max(52, fragY + 4))

		for _, row in ipairs(minRows) do
			row:Destroy()
		end
		minRows = {}

		local mineralNames = { "Magma Core", "Aqua Shard", "Root Crystal", "Volt Core", "Stone Heart", "Pulse Fragment" }
		local minY = 52
		for _, minName in ipairs(mineralNames) do
			local count = tonumber(player:GetAttribute("Mineral_" .. minName)) or 0
			if count > 0 then
				local row = addItemRow(minSection, "rbxassetid://0", minName, count, 1)
				row.Position = UDim2.new(0, 0, 0, minY)
				row.LayoutOrder = nil
				minY = minY + 48
				table.insert(minRows, row)
			end
		end
		minSection.Size = UDim2.new(1, 0, 0, math.max(52, minY + 4))

		local totalH = 52 + 8 + fragSection.Size.Y.Offset + 16 + minSection.Size.Y.Offset + 24
		scroll.CanvasSize = UDim2.new(0, 0, 0, totalH)
	end
end

-- ============================================================
-- BEASTIBIT COLLECTION TAB
-- ============================================================
local function buildBeastibitTab()
	local tab = createTabFrame("Beastibit")

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CollectionScroll"
	scroll.Position = UDim2.new(0, 8, 0, 8)
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.BackgroundTransparency = 1
	scroll.CanvasSize = UDim2.new(0, 0, 0, 300)
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 73
	scroll.Parent = tab

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 90, 0, 100)
	gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.FillDirectionMaxCells = 7
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scroll

	local collectionCards = {}

	tabRefreshers["Beastibit"] = function()
		for _, card in ipairs(collectionCards) do
			card:Destroy()
		end
		collectionCards = {}

		local sortedIds = {}
		for monsterId in pairs(MonstersData) do
			table.insert(sortedIds, monsterId)
		end
		table.sort(sortedIds)

		local unlockedSet = {}
		for _, item in ipairs(rosterBackpack) do
			if item.Unlocked == true then
				unlockedSet[item.MonsterId] = true
			end
		end

		for i, monsterId in ipairs(sortedIds) do
			local data = MonstersData[monsterId]
			local unlocked = unlockedSet[monsterId] == true
			local rarityKey = getMonsterRarity(monsterId)

			local card = Instance.new("Frame")
			card.Name = "Card_" .. monsterId
			card.Size = UDim2.new(0, 90, 0, 100)
			card.BackgroundColor3 = unlocked and Color3.fromRGB(28, 32, 50) or Color3.fromRGB(20, 20, 26)
			card.BorderSizePixel = 0
			card.LayoutOrder = i
			card.ZIndex = 74
			card.Parent = scroll
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

			local icon = Instance.new("ImageLabel")
			icon.Name = "Icon"
			icon.Position = UDim2.new(0.5, -32, 0, 6)
			icon.Size = UDim2.new(0, 64, 0, 64)
			icon.BackgroundTransparency = 1
			icon.Image = unlocked and getMonsterImage(monsterId) or "rbxassetid://0"
			icon.ImageColor3 = unlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
			icon.ZIndex = 75
			icon.Parent = card
			Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 6)

			if not unlocked then
				local lockOverlay = Instance.new("TextLabel")
				lockOverlay.Name = "LockIcon"
				lockOverlay.Position = UDim2.new(0, 0, 0, 22)
				lockOverlay.Size = UDim2.new(0, 64, 0, 30)
				lockOverlay.BackgroundTransparency = 1
				lockOverlay.Font = Enum.Font.GothamBold
				lockOverlay.TextSize = 24
				lockOverlay.TextColor3 = Color3.fromRGB(180, 180, 180)
				lockOverlay.Text = "?"
				lockOverlay.ZIndex = 76
				lockOverlay.Parent = card
			end

			local rarityBar = Instance.new("Frame")
			rarityBar.Name = "RarityBar"
			rarityBar.Position = UDim2.new(0, 0, 0, 80)
			rarityBar.Size = UDim2.new(1, 0, 0, 3)
			rarityBar.BackgroundColor3 = RARITY_COLORS[rarityKey] or Color3.fromRGB(140, 145, 155)
			rarityBar.BorderSizePixel = 0
			rarityBar.ZIndex = 75
			rarityBar.Parent = card

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Name"
			nameLabel.Position = UDim2.new(0, 4, 0, 84)
			nameLabel.Size = UDim2.new(1, -8, 0, 16)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 10
			nameLabel.TextColor3 = unlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
			nameLabel.Text = getMonsterDisplayName(monsterId)
			nameLabel.ZIndex = 75
			nameLabel.Parent = card

			table.insert(collectionCards, card)
		end

		local rows = math.ceil(#sortedIds / 7)
		scroll.CanvasSize = UDim2.new(0, 0, 0, rows * 108)
	end
end

-- ============================================================
-- TEAM TAB
-- ============================================================
local function buildTeamTab()
	local tab = createTabFrame("Team")

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "TeamInfo"
	infoLabel.Position = UDim2.new(0, 12, 0, 8)
	infoLabel.Size = UDim2.new(1, -24, 0, 22)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 13
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
	infoLabel.Text = "Selecciona un Beastibit desbloqueado y asignalo a un slot de tu equipo de duelo (5 slots)."
	infoLabel.ZIndex = 73
	infoLabel.Parent = tab

	-- Team slots
	local teamSlotsFrame = Instance.new("Frame")
	teamSlotsFrame.Name = "TeamSlots"
	teamSlotsFrame.Position = UDim2.new(0, 12, 0, 36)
	teamSlotsFrame.Size = UDim2.new(1, -24, 0, 90)
	teamSlotsFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	teamSlotsFrame.BorderSizePixel = 0
	teamSlotsFrame.ZIndex = 73
	teamSlotsFrame.Parent = tab
	Instance.new("UICorner", teamSlotsFrame).CornerRadius = UDim.new(0, 10)

	local slotTitle = Instance.new("TextLabel")
	slotTitle.Name = "SlotTitle"
	slotTitle.Position = UDim2.new(0, 8, 0, 6)
	slotTitle.Size = UDim2.new(1, -16, 0, 18)
	slotTitle.BackgroundTransparency = 1
	slotTitle.Font = Enum.Font.GothamBold
	slotTitle.TextSize = 12
	slotTitle.TextXAlignment = Enum.TextXAlignment.Left
	slotTitle.TextColor3 = Color3.fromRGB(255, 220, 150)
	slotTitle.Text = "Formacion de duelo"
	slotTitle.ZIndex = 74
	slotTitle.Parent = teamSlotsFrame

	local teamSlotButtons = {}
	local teamSlotsGrid = Instance.new("Frame")
	teamSlotsGrid.Name = "TeamSlotsGrid"
	teamSlotsGrid.Position = UDim2.new(0, 8, 0, 26)
	teamSlotsGrid.Size = UDim2.new(1, -16, 0, 56)
	teamSlotsGrid.BackgroundTransparency = 1
	teamSlotsGrid.ZIndex = 74
	teamSlotsGrid.Parent = teamSlotsFrame

	local teamSlotsLayout = Instance.new("UIGridLayout")
	teamSlotsLayout.CellSize = UDim2.new(0, 56, 0, 56)
	teamSlotsLayout.CellPadding = UDim2.new(0, 12, 0, 0)
	teamSlotsLayout.FillDirection = Enum.FillDirection.Horizontal
	teamSlotsLayout.FillDirectionMaxCells = 5
	teamSlotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	teamSlotsLayout.Parent = teamSlotsGrid

	local function paintSlotCard(btn, monsterId, badgeText, isSelected)
		local icon = btn:FindFirstChild("Icon")
		local nameLabel = btn:FindFirstChild("Name")
		local badge = btn:FindFirstChild("Badge")
		if not icon or not nameLabel or not badge then return end

		local displayName = getMonsterDisplayName(monsterId)
		icon.Image = getMonsterImage(monsterId)
		nameLabel.Text = displayName

		if isSelected then
			btn.BackgroundColor3 = Color3.fromRGB(74, 118, 176)
			icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(48, 56, 86)
			icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end

		badge.Visible = true
		badge.Text = badgeText
	end

	for slotIndex = 1, 5 do
		local slotBtn = Instance.new("ImageButton")
		slotBtn.Name = "TeamSlot_" .. slotIndex
		slotBtn.LayoutOrder = slotIndex
		slotBtn.Size = UDim2.new(0, 56, 0, 56)
		slotBtn.BackgroundColor3 = Color3.fromRGB(48, 56, 86)
		slotBtn.BorderSizePixel = 0
		slotBtn.AutoButtonColor = true
		slotBtn.ZIndex = 74
		slotBtn.Parent = teamSlotsGrid
		Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 8)

		local slotIcon = Instance.new("ImageLabel")
		slotIcon.Name = "Icon"
		slotIcon.Position = UDim2.new(0, 4, 0, 4)
		slotIcon.Size = UDim2.new(1, -8, 1, -22)
		slotIcon.BackgroundTransparency = 1
		slotIcon.Image = "rbxassetid://0"
		slotIcon.ZIndex = 75
		slotIcon.Parent = slotBtn

		local slotName = Instance.new("TextLabel")
		slotName.Name = "Name"
		slotName.AnchorPoint = Vector2.new(0.5, 1)
		slotName.Position = UDim2.new(0.5, 0, 1, -1)
		slotName.Size = UDim2.new(1, -4, 0, 14)
		slotName.BackgroundTransparency = 0.3
		slotName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		slotName.Font = Enum.Font.GothamBold
		slotName.TextSize = 8
		slotName.TextColor3 = Color3.fromRGB(255, 255, 255)
		slotName.Text = tostring(slotIndex)
		slotName.ZIndex = 76
		slotName.Parent = slotBtn
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
		slotBadge.ZIndex = 76
		slotBadge.Parent = slotBtn
		Instance.new("UICorner", slotBadge).CornerRadius = UDim.new(0, 3)

		slotBtn.MouseButton1Click:Connect(function()
			if not selectedBackpackMonsterId then return end
			CombatRosterAction:FireServer({
				action = "set-duel-slot",
				slotIndex = slotIndex,
				monsterId = selectedBackpackMonsterId,
			})
		end)

		teamSlotButtons[slotIndex] = slotBtn
	end

	-- Backpack grid for team assignment
	local backpackTitle = Instance.new("TextLabel")
	backpackTitle.Name = "BackpackTitle"
	backpackTitle.Position = UDim2.new(0, 12, 0, 134)
	backpackTitle.Size = UDim2.new(1, -24, 0, 20)
	backpackTitle.BackgroundTransparency = 1
	backpackTitle.Font = Enum.Font.GothamBold
	backpackTitle.TextSize = 12
	backpackTitle.TextXAlignment = Enum.TextXAlignment.Left
	backpackTitle.TextColor3 = Color3.fromRGB(185, 195, 215)
	backpackTitle.Text = "Beastibits desbloqueados (click para seleccionar, luego click en slot)"
	backpackTitle.ZIndex = 73
	backpackTitle.Parent = tab

	local teamBackpackScroll = Instance.new("ScrollingFrame")
	teamBackpackScroll.Name = "TeamBackpackScroll"
	teamBackpackScroll.Position = UDim2.new(0, 12, 0, 158)
	teamBackpackScroll.Size = UDim2.new(1, -24, 1, -170)
	teamBackpackScroll.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	teamBackpackScroll.BorderSizePixel = 0
	teamBackpackScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	teamBackpackScroll.ScrollBarThickness = 6
	teamBackpackScroll.ZIndex = 73
	teamBackpackScroll.Parent = tab
	Instance.new("UICorner", teamBackpackScroll).CornerRadius = UDim.new(0, 10)

	local teamBackpackGrid = Instance.new("UIGridLayout")
	teamBackpackGrid.CellSize = UDim2.new(0, 74, 0, 74)
	teamBackpackGrid.CellPadding = UDim2.new(0, 6, 0, 6)
	teamBackpackGrid.FillDirection = Enum.FillDirection.Horizontal
	teamBackpackGrid.FillDirectionMaxCells = 8
	teamBackpackGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	teamBackpackGrid.SortOrder = Enum.SortOrder.LayoutOrder
	teamBackpackGrid.Parent = teamBackpackScroll

	local teamBackpackButtons = {}

	tabRefreshers["Team"] = function()
		for _, btn in ipairs(teamBackpackButtons) do
			btn:Destroy()
		end
		teamBackpackButtons = {}

		for i = 1, 5 do
			local pet = rosterDuelTeam[i]
			local monsterId = pet and pet.MonsterId or nil
			local badgeText = tostring(i)
			local isSel = selectedBackpackMonsterId ~= nil and selectedBackpackMonsterId == monsterId
			paintSlotCard(teamSlotButtons[i], monsterId, badgeText, isSel)
		end

		local idx = 0
		for _, item in ipairs(rosterBackpack) do
			if item.Unlocked == true then
				idx = idx + 1
				local monsterId = item.MonsterId
				local btn = Instance.new("ImageButton")
				btn.Name = "TBItem_" .. monsterId
				btn.Size = UDim2.new(0, 74, 0, 74)
				btn.LayoutOrder = idx
				btn.BackgroundColor3 = Color3.fromRGB(50, 68, 108)
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = true
				btn.ZIndex = 74
				btn.Parent = teamBackpackScroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

				local bIcon = Instance.new("ImageLabel")
				bIcon.Name = "Icon"
				bIcon.Position = UDim2.new(0, 5, 0, 5)
				bIcon.Size = UDim2.new(1, -10, 1, -30)
				bIcon.BackgroundTransparency = 1
				bIcon.Image = getMonsterImage(monsterId)
				bIcon.ZIndex = 75
				bIcon.Parent = btn

				local bName = Instance.new("TextLabel")
				bName.Name = "Name"
				bName.AnchorPoint = Vector2.new(0.5, 1)
				bName.Position = UDim2.new(0.5, 0, 1, -4)
				bName.Size = UDim2.new(1, -8, 0, 20)
				bName.BackgroundTransparency = 0.25
				bName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				bName.Font = Enum.Font.GothamBold
				bName.TextSize = 8
				bName.TextColor3 = Color3.fromRGB(255, 255, 255)
				bName.Text = getMonsterDisplayName(monsterId)
				bName.ZIndex = 76
				bName.Parent = btn
				Instance.new("UICorner", bName).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					selectedBackpackMonsterId = monsterId
					tabRefreshers["Team"]()
				end)

				if selectedBackpackMonsterId == monsterId then
					btn.BackgroundColor3 = Color3.fromRGB(74, 118, 176)
				end

				table.insert(teamBackpackButtons, btn)
			end
		end

		local rows = math.max(1, math.ceil(idx / 8))
		teamBackpackScroll.CanvasSize = UDim2.new(0, 0, 0, rows * 80)
	end
end

-- ============================================================
-- SEGUIDOR TAB
-- ============================================================
local function buildSeguidorTab()
	local tab = createTabFrame("Seguidor")

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "SeguidorInfo"
	infoLabel.Position = UDim2.new(0, 12, 0, 8)
	infoLabel.Size = UDim2.new(1, -24, 0, 22)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 13
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
	infoLabel.Text = "Elige que Beastibit te seguira en el mundo abierto."
	infoLabel.ZIndex = 73
	infoLabel.Parent = tab

	local currentFollowerFrame = Instance.new("Frame")
	currentFollowerFrame.Name = "CurrentFollower"
	currentFollowerFrame.Position = UDim2.new(0, 12, 0, 36)
	currentFollowerFrame.Size = UDim2.new(0, 120, 0, 130)
	currentFollowerFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	currentFollowerFrame.BorderSizePixel = 0
	currentFollowerFrame.ZIndex = 73
	currentFollowerFrame.Parent = tab
	Instance.new("UICorner", currentFollowerFrame).CornerRadius = UDim.new(0, 10)

	local curFollowerTitle = Instance.new("TextLabel")
	curFollowerTitle.Name = "CurFollowerTitle"
	curFollowerTitle.Position = UDim2.new(0, 0, 0, 6)
	curFollowerTitle.Size = UDim2.new(1, 0, 0, 18)
	curFollowerTitle.BackgroundTransparency = 1
	curFollowerTitle.Font = Enum.Font.GothamBold
	curFollowerTitle.TextSize = 11
	curFollowerTitle.TextColor3 = Color3.fromRGB(160, 215, 255)
	curFollowerTitle.Text = "Seguidor actual"
	curFollowerTitle.ZIndex = 74
	curFollowerTitle.Parent = currentFollowerFrame

	local curFollowerIcon = Instance.new("ImageLabel")
	curFollowerIcon.Name = "Icon"
	curFollowerIcon.Position = UDim2.new(0, 15, 0, 28)
	curFollowerIcon.Size = UDim2.new(0, 90, 0, 90)
	curFollowerIcon.BackgroundTransparency = 1
	curFollowerIcon.Image = "rbxassetid://0"
	curFollowerIcon.ZIndex = 74
	curFollowerIcon.Parent = currentFollowerFrame

	local curFollowerName = Instance.new("TextLabel")
	curFollowerName.Name = "Name"
	curFollowerName.Position = UDim2.new(0, 4, 0, 118)
	curFollowerName.Size = UDim2.new(1, -8, 0, 14)
	curFollowerName.BackgroundTransparency = 1
	curFollowerName.Font = Enum.Font.GothamBold
	curFollowerName.TextSize = 10
	curFollowerName.TextColor3 = Color3.fromRGB(255, 255, 255)
	curFollowerName.Text = "Ninguno"
	curFollowerName.ZIndex = 74
	curFollowerName.Parent = currentFollowerFrame

	local followerScroll = Instance.new("ScrollingFrame")
	followerScroll.Name = "FollowerScroll"
	followerScroll.Position = UDim2.new(0, 144, 0, 36)
	followerScroll.Size = UDim2.new(1, -156, 1, -48)
	followerScroll.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	followerScroll.BorderSizePixel = 0
	followerScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	followerScroll.ScrollBarThickness = 6
	followerScroll.ZIndex = 73
	followerScroll.Parent = tab
	Instance.new("UICorner", followerScroll).CornerRadius = UDim.new(0, 10)

	local followerGrid = Instance.new("UIGridLayout")
	followerGrid.CellSize = UDim2.new(0, 80, 0, 90)
	followerGrid.CellPadding = UDim2.new(0, 6, 0, 6)
	followerGrid.FillDirection = Enum.FillDirection.Horizontal
	followerGrid.FillDirectionMaxCells = 6
	followerGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	followerGrid.SortOrder = Enum.SortOrder.LayoutOrder
	followerGrid.Parent = followerScroll

	local followerCardButtons = {}

	tabRefreshers["Seguidor"] = function()
		curFollowerIcon.Image = getMonsterImage(selectedFollowerMonsterId)
		curFollowerName.Text = getMonsterDisplayName(selectedFollowerMonsterId)

		for _, btn in ipairs(followerCardButtons) do
			btn:Destroy()
		end
		followerCardButtons = {}

		local idx = 0
		for _, item in ipairs(rosterBackpack) do
			if item.Unlocked == true then
				idx = idx + 1
				local monsterId = item.MonsterId
				local isFollower = selectedFollowerMonsterId == monsterId

				local card = Instance.new("ImageButton")
				card.Name = "FollowerCard_" .. monsterId
				card.Size = UDim2.new(0, 80, 0, 90)
				card.LayoutOrder = idx
				card.BackgroundColor3 = isFollower and Color3.fromRGB(38, 132, 173) or Color3.fromRGB(50, 68, 108)
				card.BorderSizePixel = 0
				card.AutoButtonColor = true
				card.ZIndex = 74
				card.Parent = followerScroll
				Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

				local cIcon = Instance.new("ImageLabel")
				cIcon.Name = "Icon"
				cIcon.Position = UDim2.new(0, 6, 0, 4)
				cIcon.Size = UDim2.new(1, -12, 1, -28)
				cIcon.BackgroundTransparency = 1
				cIcon.Image = getMonsterImage(monsterId)
				cIcon.ZIndex = 75
				cIcon.Parent = card

				local cName = Instance.new("TextLabel")
				cName.Name = "Name"
				cName.AnchorPoint = Vector2.new(0.5, 1)
				cName.Position = UDim2.new(0.5, 0, 1, -3)
				cName.Size = UDim2.new(1, -6, 0, 18)
				cName.BackgroundTransparency = 0.25
				cName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				cName.Font = Enum.Font.GothamBold
				cName.TextSize = 9
				cName.TextColor3 = Color3.fromRGB(255, 255, 255)
				cName.Text = getMonsterDisplayName(monsterId)
				cName.ZIndex = 76
				cName.Parent = card
				Instance.new("UICorner", cName).CornerRadius = UDim.new(0, 4)

				if isFollower then
					local followerBadge = Instance.new("TextLabel")
					followerBadge.Name = "FollowerBadge"
					followerBadge.Position = UDim2.new(0, 4, 0, 4)
					followerBadge.Size = UDim2.new(0, 44, 0, 14)
					followerBadge.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
					followerBadge.BackgroundTransparency = 0.2
					followerBadge.Font = Enum.Font.GothamBold
					followerBadge.TextSize = 8
					followerBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
					followerBadge.Text = "ACTIVO"
					followerBadge.ZIndex = 77
					followerBadge.Parent = card
					Instance.new("UICorner", followerBadge).CornerRadius = UDim.new(0, 3)
				end

				card.MouseButton1Click:Connect(function()
					CombatRosterAction:FireServer({
						action = "select-follower",
						monsterId = monsterId,
					})
				end)

				table.insert(followerCardButtons, card)
			end
		end

		local rows = math.max(1, math.ceil(idx / 6))
		followerScroll.CanvasSize = UDim2.new(0, 0, 0, rows * 96)
	end
end

-- ============================================================
-- CRAFT TAB
-- ============================================================
local function buildCraftTab()
	local tab = createTabFrame("Craft")

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "CraftInfo"
	infoLabel.Position = UDim2.new(0, 12, 0, 8)
	infoLabel.Size = UDim2.new(1, -24, 0, 22)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 13
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.TextColor3 = Color3.fromRGB(185, 195, 215)
	infoLabel.Text = "Selecciona un Beastibit para evolucionarlo o usarlo como comida."
	infoLabel.ZIndex = 73
	infoLabel.Parent = tab

	-- Craft target selection (unlocked beastibits)
	local craftSelectionScroll = Instance.new("ScrollingFrame")
	craftSelectionScroll.Name = "CraftSelectionScroll"
	craftSelectionScroll.Position = UDim2.new(0, 12, 0, 36)
	craftSelectionScroll.Size = UDim2.new(0, 340, 1, -48)
	craftSelectionScroll.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	craftSelectionScroll.BorderSizePixel = 0
	craftSelectionScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
	craftSelectionScroll.ScrollBarThickness = 6
	craftSelectionScroll.ZIndex = 73
	craftSelectionScroll.Parent = tab
	Instance.new("UICorner", craftSelectionScroll).CornerRadius = UDim.new(0, 10)

	local craftSelectionGrid = Instance.new("UIGridLayout")
	craftSelectionGrid.CellSize = UDim2.new(0, 74, 0, 74)
	craftSelectionGrid.CellPadding = UDim2.new(0, 6, 0, 6)
	craftSelectionGrid.FillDirection = Enum.FillDirection.Horizontal
	craftSelectionGrid.FillDirectionMaxCells = 4
	craftSelectionGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	craftSelectionGrid.SortOrder = Enum.SortOrder.LayoutOrder
	craftSelectionGrid.Parent = craftSelectionScroll

	local craftTargetMonsterId = nil
	local craftTargetButtons = {}

	-- Craft detail panel
	local craftDetailFrame = Instance.new("Frame")
	craftDetailFrame.Name = "CraftDetail"
	craftDetailFrame.Position = UDim2.new(0, 362, 0, 36)
	craftDetailFrame.Size = UDim2.new(1, -374, 1, -48)
	craftDetailFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	craftDetailFrame.BorderSizePixel = 0
	craftDetailFrame.ZIndex = 73
	craftDetailFrame.Parent = tab
	Instance.new("UICorner", craftDetailFrame).CornerRadius = UDim.new(0, 10)

	local craftDetailIcon = Instance.new("ImageLabel")
	craftDetailIcon.Name = "CraftDetailIcon"
	craftDetailIcon.Position = UDim2.new(0, 12, 0, 12)
	craftDetailIcon.Size = UDim2.new(0, 80, 0, 80)
	craftDetailIcon.BackgroundTransparency = 1
	craftDetailIcon.Image = "rbxassetid://0"
	craftDetailIcon.ZIndex = 74
	craftDetailIcon.Parent = craftDetailFrame

	local craftDetailName = Instance.new("TextLabel")
	craftDetailName.Name = "CraftDetailName"
	craftDetailName.Position = UDim2.new(0, 100, 0, 14)
	craftDetailName.Size = UDim2.new(1, -112, 0, 24)
	craftDetailName.BackgroundTransparency = 1
	craftDetailName.Font = Enum.Font.GothamBlack
	craftDetailName.TextSize = 18
	craftDetailName.TextXAlignment = Enum.TextXAlignment.Left
	craftDetailName.TextColor3 = Color3.fromRGB(255, 255, 255)
	craftDetailName.Text = "Selecciona un Beastibit"
	craftDetailName.ZIndex = 74
	craftDetailName.Parent = craftDetailFrame

	local craftDetailEvo = Instance.new("TextLabel")
	craftDetailEvo.Name = "CraftDetailEvo"
	craftDetailEvo.Position = UDim2.new(0, 100, 0, 40)
	craftDetailEvo.Size = UDim2.new(1, -112, 0, 18)
	craftDetailEvo.BackgroundTransparency = 1
	craftDetailEvo.Font = Enum.Font.Gotham
	craftDetailEvo.TextSize = 12
	craftDetailEvo.TextXAlignment = Enum.TextXAlignment.Left
	craftDetailEvo.TextColor3 = Color3.fromRGB(180, 195, 220)
	craftDetailEvo.Text = "Evolucion: 1 / 3"
	craftDetailEvo.ZIndex = 74
	craftDetailEvo.Parent = craftDetailFrame

	local craftDetailXP = Instance.new("TextLabel")
	craftDetailXP.Name = "CraftDetailXP"
	craftDetailXP.Position = UDim2.new(0, 100, 0, 58)
	craftDetailXP.Size = UDim2.new(1, -112, 0, 18)
	craftDetailXP.BackgroundTransparency = 1
	craftDetailXP.Font = Enum.Font.Gotham
	craftDetailXP.TextSize = 12
	craftDetailXP.TextXAlignment = Enum.TextXAlignment.Left
	craftDetailXP.TextColor3 = Color3.fromRGB(160, 210, 130)
	craftDetailXP.Text = "XP: 0"
	craftDetailXP.ZIndex = 74
	craftDetailXP.Parent = craftDetailFrame

	local craftDetailFrags = Instance.new("TextLabel")
	craftDetailFrags.Name = "CraftDetailFrags"
	craftDetailFrags.Position = UDim2.new(0, 100, 0, 76)
	craftDetailFrags.Size = UDim2.new(1, -112, 0, 18)
	craftDetailFrags.BackgroundTransparency = 1
	craftDetailFrags.Font = Enum.Font.Gotham
	craftDetailFrags.TextSize = 12
	craftDetailFrags.TextXAlignment = Enum.TextXAlignment.Left
	craftDetailFrags.TextColor3 = Color3.fromRGB(220, 190, 100)
	craftDetailFrags.Text = "Fragmentos: 0"
	craftDetailFrags.ZIndex = 74
	craftDetailFrags.Parent = craftDetailFrame

	local craftDetailActions = Instance.new("Frame")
	craftDetailActions.Name = "CraftDetailActions"
	craftDetailActions.Position = UDim2.new(0, 12, 1, -120)
	craftDetailActions.Size = UDim2.new(1, -24, 0, 108)
	craftDetailActions.BackgroundTransparency = 1
	craftDetailActions.ZIndex = 74
	craftDetailActions.Parent = craftDetailFrame

	local evolveButton = Instance.new("TextButton")
	evolveButton.Name = "EvolveButton"
	evolveButton.Position = UDim2.new(0, 0, 0, 0)
	evolveButton.Size = UDim2.new(1, 0, 0, 32)
	evolveButton.BackgroundColor3 = Color3.fromRGB(160, 80, 200)
	evolveButton.BorderSizePixel = 0
	evolveButton.Font = Enum.Font.GothamBold
	evolveButton.TextSize = 14
	evolveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	evolveButton.Text = "Evolucionar (500 Bits + 10 minerales)"
	evolveButton.ZIndex = 75
	evolveButton.Parent = craftDetailActions
	Instance.new("UICorner", evolveButton).CornerRadius = UDim.new(0, 7)

	local feedButton = Instance.new("TextButton")
	feedButton.Name = "FeedButton"
	feedButton.Position = UDim2.new(0, 0, 0, 38)
	feedButton.Size = UDim2.new(1, 0, 0, 32)
	feedButton.BackgroundColor3 = Color3.fromRGB(180, 120, 40)
	feedButton.BorderSizePixel = 0
	feedButton.Font = Enum.Font.GothamBold
	feedButton.TextSize = 14
	feedButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	feedButton.Text = "Alimentar (sacrifica otro Beastibit)"
	feedButton.ZIndex = 75
	feedButton.Parent = craftDetailActions
	Instance.new("UICorner", feedButton).CornerRadius = UDim.new(0, 7)

	local craftButton = Instance.new("TextButton")
	craftButton.Name = "CraftButton"
	craftButton.Position = UDim2.new(0, 0, 0, 76)
	craftButton.Size = UDim2.new(1, 0, 0, 32)
	craftButton.BackgroundColor3 = Color3.fromRGB(80, 160, 100)
	craftButton.BorderSizePixel = 0
	craftButton.Font = Enum.Font.GothamBold
	craftButton.TextSize = 14
	craftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	craftButton.Text = "Craftear con fragmentos"
	craftButton.ZIndex = 75
	craftButton.Parent = craftDetailActions
	Instance.new("UICorner", craftButton).CornerRadius = UDim.new(0, 7)

	-- Feed confirmation
	local feedConfirmFrame = Instance.new("Frame")
	feedConfirmFrame.Name = "FeedConfirmFrame"
	feedConfirmFrame.Position = UDim2.new(0, 0, 1, -32)
	feedConfirmFrame.Size = UDim2.new(1, 0, 0, 32)
	feedConfirmFrame.BackgroundTransparency = 1
	feedConfirmFrame.Visible = false
	feedConfirmFrame.ZIndex = 76
	feedConfirmFrame.Parent = craftDetailFrame

	local feedConfirmText = Instance.new("TextLabel")
	feedConfirmText.Name = "FeedConfirmText"
	feedConfirmText.Position = UDim2.new(0, 0, 0, 0)
	feedConfirmText.Size = UDim2.new(0.55, 0, 1, 0)
	feedConfirmText.BackgroundTransparency = 1
	feedConfirmText.Font = Enum.Font.GothamBold
	feedConfirmText.TextSize = 11
	feedConfirmText.TextXAlignment = Enum.TextXAlignment.Left
	feedConfirmText.TextColor3 = Color3.fromRGB(255, 180, 80)
	feedConfirmText.Text = "Selecciona un Beastibit para sacrificar:"
	feedConfirmText.ZIndex = 77
	feedConfirmText.Parent = feedConfirmFrame

	local feedConfirmScroll = Instance.new("ScrollingFrame")
	feedConfirmScroll.Name = "FeedConfirmScroll"
	feedConfirmScroll.Position = UDim2.new(0, 0, 0, 36)
	feedConfirmScroll.Size = UDim2.new(1, 0, 0, 56)
	feedConfirmScroll.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
	feedConfirmScroll.BorderSizePixel = 0
	feedConfirmScroll.CanvasSize = UDim2.new(0, 0, 0, 56)
	feedConfirmScroll.ZIndex = 77
	feedConfirmScroll.Visible = false
	feedConfirmScroll.Parent = feedConfirmFrame
	Instance.new("UICorner", feedConfirmScroll).CornerRadius = UDim.new(0, 6)

	local feedConfirmGrid = Instance.new("UIGridLayout")
	feedConfirmGrid.CellSize = UDim2.new(0, 48, 0, 48)
	feedConfirmGrid.CellPadding = UDim2.new(0, 4, 0, 0)
	feedConfirmGrid.FillDirection = Enum.FillDirection.Horizontal
	feedConfirmGrid.FillDirectionMaxCells = 6
	feedConfirmGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	feedConfirmGrid.Parent = feedConfirmScroll

	local feedConfirmButtons = {}
	local feedConfirming = false

	evolveButton.MouseButton1Click:Connect(function()
		if not craftTargetMonsterId then return end
		CombatRosterAction:FireServer({
			action = "evolve",
			monsterId = craftTargetMonsterId,
		})
	end)

	feedButton.MouseButton1Click:Connect(function()
		if not craftTargetMonsterId then return end
		if feedConfirming then
			feedConfirmFrame.Visible = false
			feedConfirmScroll.Visible = false
			feedConfirming = false
			return
		end
		feedConfirming = true
		feedConfirmFrame.Visible = true
		feedConfirmScroll.Visible = true
		-- Populate food options
		for _, btn in ipairs(feedConfirmButtons) do
			btn:Destroy()
		end
		feedConfirmButtons = {}
		local idx = 0
		for _, item in ipairs(rosterBackpack) do
			if item.Unlocked == true and item.MonsterId ~= craftTargetMonsterId then
				-- Exclude team and follower
				local inTeam = false
				for _, pet in ipairs(rosterDuelTeam) do
					if pet and pet.MonsterId == item.MonsterId then
						inTeam = true
						break
					end
				end
				if not inTeam and item.MonsterId ~= selectedFollowerMonsterId then
					idx = idx + 1
					local fb = Instance.new("ImageButton")
					fb.Name = "FeedOpt_" .. item.MonsterId
					fb.Size = UDim2.new(0, 48, 0, 48)
					fb.LayoutOrder = idx
					fb.BackgroundColor3 = Color3.fromRGB(160, 60, 40)
					fb.BorderSizePixel = 0
					fb.AutoButtonColor = true
					fb.ZIndex = 78
					fb.Parent = feedConfirmScroll
					Instance.new("UICorner", fb).CornerRadius = UDim.new(0, 5)

					local fbIcon = Instance.new("ImageLabel")
					fbIcon.Name = "Icon"
					fbIcon.Position = UDim2.new(0, 4, 0, 4)
					fbIcon.Size = UDim2.new(1, -8, 1, -8)
					fbIcon.BackgroundTransparency = 1
					fbIcon.Image = getMonsterImage(item.MonsterId)
					fbIcon.ZIndex = 79
					fbIcon.Parent = fb

					local foodMonsterId = item.MonsterId
					fb.MouseButton1Click:Connect(function()
						CombatRosterAction:FireServer({
							action = "feed",
							targetMonsterId = craftTargetMonsterId,
							foodMonsterId = foodMonsterId,
						})
						feedConfirming = false
						feedConfirmFrame.Visible = false
						feedConfirmScroll.Visible = false
					end)
					table.insert(feedConfirmButtons, fb)
				end
			end
		end
		feedConfirmScroll.CanvasSize = UDim2.new(0, math.max(48, idx * 52), 0, 56)
	end)

	craftButton.MouseButton1Click:Connect(function()
		if not craftTargetMonsterId then return end
		CombatRosterAction:FireServer({
			action = "craft",
			monsterId = craftTargetMonsterId,
		})
	end)

	tabRefreshers["Craft"] = function()
		for _, btn in ipairs(craftTargetButtons) do
			btn:Destroy()
		end
		craftTargetButtons = {}

		local idx = 0
		for _, item in ipairs(rosterBackpack) do
			if item.Unlocked == true then
				idx = idx + 1
				local monsterId = item.MonsterId
				local isTarget = craftTargetMonsterId == monsterId

				local btn = Instance.new("ImageButton")
				btn.Name = "CraftSel_" .. monsterId
				btn.Size = UDim2.new(0, 74, 0, 74)
				btn.LayoutOrder = idx
				btn.BackgroundColor3 = isTarget and Color3.fromRGB(74, 118, 176) or Color3.fromRGB(50, 68, 108)
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = true
				btn.ZIndex = 74
				btn.Parent = craftSelectionScroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

				local cIcon = Instance.new("ImageLabel")
				cIcon.Name = "Icon"
				cIcon.Position = UDim2.new(0, 5, 0, 5)
				cIcon.Size = UDim2.new(1, -10, 1, -30)
				cIcon.BackgroundTransparency = 1
				cIcon.Image = getMonsterImage(monsterId)
				cIcon.ZIndex = 75
				cIcon.Parent = btn

				local cName = Instance.new("TextLabel")
				cName.Name = "Name"
				cName.AnchorPoint = Vector2.new(0.5, 1)
				cName.Position = UDim2.new(0.5, 0, 1, -4)
				cName.Size = UDim2.new(1, -8, 0, 20)
				cName.BackgroundTransparency = 0.25
				cName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				cName.Font = Enum.Font.GothamBold
				cName.TextSize = 8
				cName.TextColor3 = Color3.fromRGB(255, 255, 255)
				cName.Text = getMonsterDisplayName(monsterId)
				cName.ZIndex = 76
				cName.Parent = btn
				Instance.new("UICorner", cName).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					craftTargetMonsterId = monsterId
					local fragCount = rosterFragments[monsterId] or 0
					local evo = rosterEvolutions[monsterId] or 1
					local xp = rosterXP[monsterId] or 0
					craftDetailIcon.Image = getMonsterImage(monsterId)
					craftDetailName.Text = getMonsterDisplayName(monsterId)
					craftDetailEvo.Text = "Evolucion actual: " .. tostring(evo) .. " / 3"
					craftDetailXP.Text = "XP acumulada: " .. tostring(xp)
					craftDetailFrags.Text = "Fragmentos: " .. tostring(fragCount)
					tabRefreshers["Craft"]()
				end)

				table.insert(craftTargetButtons, btn)
			end
		end

		-- Show unlocked monsters with fragments > 0 that are not yet unlocked
		local unlockedSet = {}
		for _, item in ipairs(rosterBackpack) do
			if item.Unlocked == true then
				unlockedSet[item.MonsterId] = true
			end
		end
		for monsterId, fragCount in pairs(rosterFragments) do
			if fragCount > 0 and not unlockedSet[monsterId] and MonstersData[monsterId] then
				idx = idx + 1
				local isTarget = craftTargetMonsterId == monsterId

				local btn = Instance.new("ImageButton")
				btn.Name = "CraftSel_" .. monsterId
				btn.Size = UDim2.new(0, 74, 0, 74)
				btn.LayoutOrder = idx
				btn.BackgroundColor3 = isTarget and Color3.fromRGB(74, 118, 176) or Color3.fromRGB(30, 38, 58)
				btn.BorderSizePixel = 0
				btn.AutoButtonColor = true
				btn.ZIndex = 74
				btn.Parent = craftSelectionScroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

				local cIcon = Instance.new("ImageLabel")
				cIcon.Name = "Icon"
				cIcon.Position = UDim2.new(0, 5, 0, 5)
				cIcon.Size = UDim2.new(1, -10, 1, -30)
				cIcon.BackgroundTransparency = 1
				cIcon.Image = getMonsterImage(monsterId)
				cIcon.ImageColor3 = Color3.fromRGB(80, 80, 80)
				cIcon.ZIndex = 75
				cIcon.Parent = btn

				local cName = Instance.new("TextLabel")
				cName.Name = "Name"
				cName.AnchorPoint = Vector2.new(0.5, 1)
				cName.Position = UDim2.new(0.5, 0, 1, -4)
				cName.Size = UDim2.new(1, -8, 0, 20)
				cName.BackgroundTransparency = 0.25
				cName.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
				cName.Font = Enum.Font.GothamBold
				cName.TextSize = 8
				cName.TextColor3 = Color3.fromRGB(180, 180, 180)
				cName.Text = getMonsterDisplayName(monsterId) .. " (" .. tostring(fragCount) .. " frags)"
				cName.ZIndex = 76
				cName.Parent = btn
				Instance.new("UICorner", cName).CornerRadius = UDim.new(0, 4)

				btn.MouseButton1Click:Connect(function()
					craftTargetMonsterId = monsterId
					local fragCount2 = rosterFragments[monsterId] or 0
					craftDetailIcon.Image = getMonsterImage(monsterId)
					craftDetailIcon.ImageColor3 = Color3.fromRGB(80, 80, 80)
					craftDetailName.Text = getMonsterDisplayName(monsterId) .. " (no desbloqueado)"
					craftDetailEvo.Text = "Disponible por craft"
					craftDetailXP.Text = "Fragmentos necesarios: ver rareza"
					craftDetailFrags.Text = "Tienes: " .. tostring(fragCount2)
					tabRefreshers["Craft"]()
				end)

				table.insert(craftTargetButtons, btn)
			end
		end

		local rows = math.max(1, math.ceil(idx / 4))
		craftSelectionScroll.CanvasSize = UDim2.new(0, 0, 0, rows * 80)
	end
end

-- ============================================================
-- BUILD ALL TABS
-- ============================================================
buildInventarioTab()
buildBeastibitTab()
buildTeamTab()
buildSeguidorTab()
buildCraftTab()

-- ============================================================
-- TAB SWITCHING
-- ============================================================
local function switchTab(tabName)
	currentTab = tabName
	headerTitle.Text = tabName

	for name, btn in pairs(tabButtons) do
		if name == tabName then
			btn.BackgroundColor3 = Color3.fromRGB(60, 110, 190)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 40, 60)
			btn.TextColor3 = Color3.fromRGB(180, 190, 210)
		end
	end

	for name, frame in pairs(tabFrames) do
		frame.Visible = (name == tabName)
	end

	local refresher = tabRefreshers[tabName]
	if refresher then
		refresher()
	end
end

for tabName, btn in pairs(tabButtons) do
	btn.MouseButton1Click:Connect(function()
		switchTab(tabName)
	end)
end

-- ============================================================
-- ROSTER DATA HANDLING
-- ============================================================
local function applyRosterState(data)
	rosterBackpack = type(data.backpack) == "table" and data.backpack or rosterBackpack
	rosterDuelTeam = type(data.duelTeam) == "table" and data.duelTeam or rosterDuelTeam
	rosterFragments = type(data.fragments) == "table" and data.fragments or rosterFragments
	rosterEvolutions = type(data.evolutions) == "table" and data.evolutions or rosterEvolutions
	rosterXP = type(data.monsterXP) == "table" and data.monsterXP or rosterXP

	if type(data.selectedFollowerMonsterId) == "string" then
		selectedFollowerMonsterId = data.selectedFollowerMonsterId
	end

	if type(data.pvpTitle) == "string" then
		playerPvpTitle = data.pvpTitle
	end

	if type(data.shieldCharges) == "number" then
		playerShieldCharges = data.shieldCharges
	end

	if type(data.pvpStars) == "number" then
		playerPvpStars = data.pvpStars
	end

	pvpInfoLabel.Text = "Estrellas: " .. tostring(playerPvpStars) .. " | " .. playerPvpTitle .. " | Shields: " .. tostring(playerShieldCharges)

	if not selectedBackpackMonsterId and selectedFollowerMonsterId then
		selectedBackpackMonsterId = selectedFollowerMonsterId
	end

	-- Refresh visible tab
	if rosterOverlay.Visible then
		switchTab(currentTab)
	end
end

local function requestRosterSync()
	CombatRosterAction:FireServer({ action = "request" })
end

local function setRosterVisible(visible)
	if duelActive and visible == true then return end
	rosterOverlay.Visible = visible == true

	local statusHud = playerGui:FindFirstChild("PlayerStatusHUD")
	if statusHud and statusHud:IsA("ScreenGui") then
		statusHud.Enabled = not (visible == true)
	end

	if rosterOverlay.Visible then
		requestRosterSync()
	end
end

local function handleDuelState(data)
	if type(data) ~= "table" or type(data.type) ~= "string" then return end

	if data.type == "roster-sync" then
		applyRosterState(data)
		return
	end

	if data.type == "roster-error" then
		return
	end

	if data.type == "feed-result" then
		requestRosterSync()
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

-- ============================================================
-- SAFE AREA
-- ============================================================
local function applySafeAreaLayout()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(720, 1280)
	local insetTopLeft, insetBottomRight = GuiService:GetGuiInset()
	local safePadding = 12
	local topOffset = math.max(insetTopLeft.Y + safePadding, 52)
	local safeWidth = math.max(320, viewport.X - insetTopLeft.X - insetBottomRight.X)
	local safeHeight = math.max(260, viewport.Y - insetTopLeft.Y - insetBottomRight.Y)

	rosterToggleButton.Position = UDim2.new(0, insetTopLeft.X + safePadding, 0, topOffset)
	rosterOverlay.Size = UDim2.new(
		0,
		math.min(OVERLAY_W, safeWidth - safePadding * 2),
		0,
		math.min(OVERLAY_H, safeHeight - safePadding * 2)
	)
	rosterOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
end

-- ============================================================
-- CONNECTIONS
-- ============================================================
rosterToggleButton.MouseButton1Click:Connect(function()
	setRosterVisible(not rosterOverlay.Visible)
end)

rosterCloseButton.MouseButton1Click:Connect(function()
	setRosterVisible(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
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

-- ============================================================
-- INIT
-- ============================================================
applySafeAreaLayout()
switchTab("Inventario")
task.delay(0.4, function()
	requestRosterSync()
end)
