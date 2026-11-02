-- Tipo: Script
-- Ubicación: ServerScriptService/CombatServer
-- Contexto: Servidor
--
-- Orquestador de combate. Los subsistemas están en ServerScriptService/Combat/:
--   DuelManager   - ciclo de vida PvP
--   MonsterDuel   - duelos PvE, IA, captura
--   GridResolver  - match-3, cascadas
--   ChallengeHandler - desafíos, roster, init

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatGrid = require(Modules:WaitForChild("CombatGrid.module"))

local CombatFolder = ServerScriptService:WaitForChild("Combat")
local TeamManager = require(CombatFolder:WaitForChild("TeamManager"))
local MonsterCombat = require(CombatFolder:WaitForChild("MonsterCombat"))
local PetCubeService = require(CombatFolder:WaitForChild("PetCubeService"))
local PvpStarsService = require(CombatFolder:WaitForChild("PvpStarsService"))

local FragmentsDataModule = GameData:FindFirstChild("FragmentsData")
local FragmentsData = FragmentsDataModule and require(FragmentsDataModule) or {
	getCaptureChance = function(rarity)
		local key = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "common") or "common"
		return ({ common = 0.60, rare = 0.40, epic = 0.05 })[key] or 0
	end,
	getFragmentDrop = function(rarity)
		local key = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "common") or "common"
		return ({ common = 5, rare = 15, epic = 25 })[key] or 0
	end,
	getFragmentCraftCost = function(rarity)
		local key = type(rarity) == "string" and string.lower(string.match(rarity, "^%s*(.-)%s*$") or "common") or "common"
		return ({ common = 30, rare = 80, epic = 150 })[key] or 999
	end,
}

local BackpackDataStoreModule = ServerScriptService:FindFirstChild("BackpackDataStore")
local BackpackDataStore = BackpackDataStoreModule and require(BackpackDataStoreModule) or {
	loadPlayerData = function(_player) return { unlockedMonsters = {}, fragments = {} } end,
	savePlayerData = function() end,
}

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatSubmit = RemoteEvents:WaitForChild("CombatSubmit")
local CombatChallengeRequest = RemoteEvents:WaitForChild("CombatChallengeRequest")
local CombatChallengeResponse = RemoteEvents:WaitForChild("CombatChallengeResponse")
local CombatDuelState = RemoteEvents:WaitForChild("CombatDuelState")
local CombatRosterAction = RemoteEvents:WaitForChild("CombatRosterAction")
local CombatProjectileVfx = RemoteEvents:WaitForChild("CombatProjectileVfx")
local CombatSync = RemoteEvents:WaitForChild("CombatSync")

local COLS, ROWS = CombatGrid.getSize()
local COMBAT_DEBUG = false
local BITS_ATTRIBUTE_NAME = "Bits"

-- ============================================================
-- CONTEXTO COMPARTIDO
-- ============================================================
local CombatContext = require(CombatFolder:WaitForChild("CombatContext"))

CombatContext.Players = Players
CombatContext.ReplicatedStorage = ReplicatedStorage
CombatContext.ServerScriptService = ServerScriptService
CombatContext.MonstersData = MonstersData
CombatContext.CombatGrid = CombatGrid
CombatContext.TeamManager = TeamManager
CombatContext.MonsterCombat = MonsterCombat
CombatContext.PetCubeService = PetCubeService
CombatContext.PvpStarsService = PvpStarsService
CombatContext.FragmentsData = FragmentsData
CombatContext.BackpackDataStore = BackpackDataStore
CombatContext.CombatSubmit = CombatSubmit
CombatContext.CombatChallengeRequest = CombatChallengeRequest
CombatContext.CombatChallengeResponse = CombatChallengeResponse
CombatContext.CombatDuelState = CombatDuelState
CombatContext.CombatRosterAction = CombatRosterAction
CombatContext.CombatProjectileVfx = CombatProjectileVfx
CombatContext.CombatSync = CombatSync
CombatContext.COLS = COLS
CombatContext.ROWS = ROWS
CombatContext.COMBAT_DEBUG = COMBAT_DEBUG
CombatContext.BITS_ATTRIBUTE_NAME = BITS_ATTRIBUTE_NAME

-- Estado compartido
CombatContext.playerStates = {}
CombatContext.pendingChallenges = {}
CombatContext.activeDuels = {}
CombatContext.activeMonsterDuels = {}
CombatContext.duelSequence = 0
CombatContext.pityCapture = {}

-- Constantes
CombatContext.ENERGY_ATTRIBUTE_NAME = "CaptureEnergy"
CombatContext.ENERGY_MAX_ATTRIBUTE_NAME = "CaptureEnergyMax"
CombatContext.CHALLENGE_DISTANCE = 10
CombatContext.CHALLENGE_TIMEOUT = 15
CombatContext.COUNTDOWN_SECONDS = 3
CombatContext.COMBO_SCALE_OUT_TIME = 0.12
CombatContext.COMBO_STAGGER_TIME = 0.06
CombatContext.FALL_TWEEN_TIME = 0.24
CombatContext.BOUNCE_DURATION = 0.12
CombatContext.CASCADE_GAP_TIME = 0.08
CombatContext.DUEL_PLAYER_DISTANCE = 40
CombatContext.MONSTER_DUEL_PLAYER_DISTANCE = 34
CombatContext.DUEL_SIDE_SHIFT = 8
CombatContext.MONSTER_DUEL_SIDE_SHIFT = 8
CombatContext.WORLD_LEFT_COMBAT_SHIFT_STUDS = 10
CombatContext.GROUND_ALIGN_RAYCAST_HEIGHT = 40
CombatContext.GROUND_ALIGN_RAYCAST_DEPTH = 220
CombatContext.DEFAULT_HRP_GROUND_OFFSET = 3
CombatContext.PET_CUBES_WORLD_FOLDER = "PlayerPetCubes"
CombatContext.VFX_PROJECTILE_SIZE = Vector3.new(1, 1, 1)
CombatContext.VFX_PROJECTILE_TRAVEL_TIME = 0.35
CombatContext.VFX_SEQUENCE_STEP_TIME = 0.65
CombatContext.MONSTER_AI_ATTACK_INTERVAL = 4
CombatContext.MONSTER_AI_SPECIAL_CHANCE = 0.25
CombatContext.MONSTER_AI_SPECIAL_COOLDOWN_TURNS = 3
CombatContext.MONSTER_AI_HIGH_COMBO_THRESHOLD = 7
CombatContext.MONSTER_AI_PLAYER_LOW_HP_RATIO = 0.3
CombatContext.MONSTER_AI_MONSTER_PRESSURE_HP_RATIO = 0.35
CombatContext.MONSTER_TEAM_SIZE = 1
CombatContext.MONSTER_UNIT_ATTACK_MULTIPLIER = 2.5
CombatContext.MONSTER_UNIT_HP_MULTIPLIER = 3.5
CombatContext.ELEMENTS_LIST = { "Fuego", "Agua", "Planta", "Electricidad", "Roca" }
CombatContext.ELEMENT_PROJECTILE_COLORS = {
	Fuego = Color3.fromRGB(255, 120, 40), Agua = Color3.fromRGB(70, 170, 255),
	Planta = Color3.fromRGB(90, 220, 110), Electricidad = Color3.fromRGB(255, 235, 80),
	Roca = Color3.fromRGB(170, 145, 110),
}
CombatContext.ELEMENT_TO_MINERAL = {
	Fuego = "Magma Core", Agua = "Aqua Shard", Planta = "Root Crystal",
	Electricidad = "Volt Core", Roca = "Stone Heart",
}
CombatContext.MONSTER_PVE_ECONOMY_BY_RARITY = {
	common = { energyCost = 5, bitsReward = 50 }, rare = { energyCost = 10, bitsReward = 120 },
	epic = { energyCost = 16, bitsReward = 260 }, legendary = { energyCost = 24, bitsReward = 500 },
}
CombatContext.PITY_BONUS_PER_FAIL = 0.05
CombatContext.MINERAL_DROP_CHANCE = 0.20

-- Utilidad de debug
function CombatContext.dbg(message)
	if not COMBAT_DEBUG then return end
	warn("[CombatServer] " .. tostring(message))
end

-- ============================================================
-- CARGAR SUBMODULOS (después de poblar CombatContext)
-- ============================================================
local DuelManager = require(CombatFolder:WaitForChild("DuelManager"))
local MonsterDuel = require(CombatFolder:WaitForChild("MonsterDuel"))
local GridResolver = require(CombatFolder:WaitForChild("GridResolver"))
local ChallengeHandler = require(CombatFolder:WaitForChild("ChallengeHandler"))

-- Referencias cruzadas entre submodulos
CombatContext.DuelManager = DuelManager
CombatContext.MonsterDuel = MonsterDuel
CombatContext.GridResolver = GridResolver
CombatContext.ChallengeHandler = ChallengeHandler
CombatContext.sendRosterState = ChallengeHandler.sendRosterState

-- ============================================================
-- WIRING: RemoteEvents
-- ============================================================
CombatSubmit.OnServerEvent:Connect(GridResolver.onCombatSubmit)
CombatChallengeRequest.OnServerEvent:Connect(ChallengeHandler.onCombatChallengeRequest)
CombatChallengeResponse.OnServerEvent:Connect(ChallengeHandler.onCombatChallengeResponse)
CombatRosterAction.OnServerEvent:Connect(ChallengeHandler.onCombatRosterAction)

-- ============================================================
-- WIRING: Monster Prompts
-- ============================================================
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt.Name ~= "MonsterChallengePrompt" then return end
	local current = prompt.Parent
	local monsterModel = nil
	while current and current ~= workspace do
		if current:IsA("Model") and current:GetAttribute("IsMonster") then
			monsterModel = current
			break
		end
		current = current.Parent
	end
	if not monsterModel then
		warn("[CombatServer] PromptTriggered: no se encontró Model con IsMonster=true")
		return
	end
	MonsterDuel.onMonsterChallenged(player, monsterModel)
end)

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
local function bindPlayerCleanup(player)
	player.AncestryChanged:Connect(function()
		if not player:IsDescendantOf(Players) then
			ChallengeHandler.cleanPlayerState(player)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	local savedData = BackpackDataStore.loadPlayerData(player)
	TeamManager.initializePlayer(player, savedData)

	if type(savedData) == "table" then
		if type(savedData.bits) == "number" then
			player:SetAttribute(BITS_ATTRIBUTE_NAME, math.max(0, math.floor(savedData.bits)))
		end
		if type(savedData.minerals) == "table" then
			for mineralName, count in pairs(savedData.minerals) do
				local safeCount = math.max(0, math.floor(tonumber(count) or 0))
				if safeCount > 0 then
					player:SetAttribute("Mineral_" .. string.gsub(mineralName, "%s+", ""), safeCount)
				end
			end
		end
	end

	ChallengeHandler.initPlayerState(player)
	PvpStarsService.onPlayerAdded(player)
	bindPlayerCleanup(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	local savedData = BackpackDataStore.loadPlayerData(player)
	TeamManager.initializePlayer(player, savedData)
	ChallengeHandler.initPlayerState(player)
	PvpStarsService.onPlayerAdded(player)
	bindPlayerCleanup(player)
end

Players.PlayerRemoving:Connect(function(player)
	local unlockedMonsters, fragments, bits, minerals, xp, monsterCounts = TeamManager.getProfileData(player)
	BackpackDataStore.savePlayerData(player, unlockedMonsters, fragments, bits, minerals, xp, monsterCounts)
	PvpStarsService.onPlayerRemoving(player)
	ChallengeHandler.cleanPlayerState(player)
end)

-- ============================================================
-- SHIELD REGEN
-- ============================================================
ChallengeHandler.runShieldRegenLoop()
