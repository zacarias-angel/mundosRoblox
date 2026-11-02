-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/ChallengeHandler
-- Contexto: Servidor
--
-- Responsable de desafíos PvP, estado de roster, inicialización de jugadores, regeneración de shields.

local ChallengeHandler = {}
local CombatContext = require(script.Parent:WaitForChild("CombatContext"))

local function dbg(message)
	if CombatContext and CombatContext.dbg then CombatContext.dbg(message) end
end

local function sendDuelState(player, data)
	-- Propósito: Enviar una actualización de estado de duelo a un cliente.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	--   2. data debe ser tabla serializable.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if not player then return end
	CombatContext.CombatDuelState:FireClient(player, data)
end

-- ============================================================
-- ROSTER STATE
-- ============================================================

function ChallengeHandler.sendRosterState(player, reason)
	-- Propósito: Enviar al cliente el estado actual de mochila, seguidor, equipo de duelo, fragmentos, XP, titulo y shields.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	local state = CombatContext.playerStates[player]
	if not state then return end
	local team = CombatContext.TeamManager.getOrCreateTeam(player)
	local backpack = CombatContext.TeamManager.getBackpack(player)
	local selectedFollowerMonsterId = CombatContext.TeamManager.getSelectedFollowerMonsterId(player)
	local allFragments = CombatContext.TeamManager.getAllFragments(player)
	local xp = {}
	local levels = {}
	for _, item in ipairs(backpack) do
		local count = math.max(0, math.floor(tonumber(item.Count) or 0))
		if count > 0 then
			xp[item.MonsterId] = CombatContext.TeamManager.getMonsterXP(player, item.MonsterId)
			levels[item.MonsterId] = CombatContext.TeamManager.getMonsterLevel(player, item.MonsterId)
		end
	end
	local shieldCharges = CombatContext.PvpStarsService.getShieldCharges(player)
	local pvpTitle = CombatContext.PvpStarsService.getTitleForPlayer(player)
	local stars = CombatContext.PvpStarsService.getStars(player)
	state.team = team
	state.backpack = backpack
	state.followMonsterId = selectedFollowerMonsterId
	sendDuelState(player, {
		type = "roster-sync", reason = reason or "sync",
		duelTeam = team, backpack = backpack,
		selectedFollowerMonsterId = selectedFollowerMonsterId,
		fragments = allFragments,
		monsterXP = xp, monsterLevels = levels,
		shieldCharges = shieldCharges, pvpTitle = pvpTitle, pvpStars = stars,
	})
end

local function applyDuelSlotSelection(player, payload)
	-- Propósito: Reemplazar un slot del equipo de 5 usando un Beastibit desbloqueado.
	-- Precondiciones:
	--   1. payload.slotIndex debe ser número entre 1 y 5.
	--   2. payload.monsterId debe existir y estar desbloqueado.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if type(payload.slotIndex) ~= "number" or type(payload.monsterId) ~= "string" then
		sendDuelState(player, { type = "roster-error", reason = "invalid-payload" })
		return
	end
	local slotIndex = math.floor(payload.slotIndex)
	if slotIndex < 1 or slotIndex > 5 then
		sendDuelState(player, { type = "roster-error", reason = "invalid-slot" })
		return
	end
	if CombatContext.MonstersData[payload.monsterId] == nil then
		sendDuelState(player, { type = "roster-error", reason = "monster-data-missing" })
		return
	end
	local state = CombatContext.playerStates[player]
	if not state then return end
	local team = state.team or CombatContext.TeamManager.getOrCreateTeam(player)
	local monsterUnlocked = CombatContext.TeamManager.isMonsterUnlocked(player, payload.monsterId)
	if not monsterUnlocked then
		sendDuelState(player, { type = "roster-error", reason = "monster-locked" })
		return
	end
	team[slotIndex] = { MonsterId = payload.monsterId }
	local usageCounts = {}
	for _, pet in ipairs(team) do
		if pet and pet.MonsterId then
			usageCounts[pet.MonsterId] = (usageCounts[pet.MonsterId] or 0) + 1
		end
	end
	local backpack = state.backpack or CombatContext.TeamManager.getBackpack(player)
	for monsterId, used in pairs(usageCounts) do
		local owned = 0
		for _, item in ipairs(backpack) do
			if item.MonsterId == monsterId then owned = math.max(0, math.floor(tonumber(item.Count) or 0)); break end
		end
		if used > owned then
			sendDuelState(player, { type = "roster-error", reason = "not-enough-copies" })
			return
		end
	end
	local _, reason = CombatContext.TeamManager.setTeam(player, team)
	if reason ~= "ok" then
		sendDuelState(player, { type = "roster-error", reason = reason or "team-invalid" })
		return
	end
	state.team = team
	ChallengeHandler.sendRosterState(player, "slot-updated")
end

function ChallengeHandler.onCombatRosterAction(player, payload)
	-- Propósito: Despachar acciones del dashboard: request, follower, slot, feed, craft.
	-- Precondiciones:
	--   1. payload.action debe ser string válido.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if type(payload) ~= "table" or type(payload.action) ~= "string" then
		sendDuelState(player, { type = "roster-error", reason = "invalid-payload" })
		return
	end

	if payload.action == "request" then
		ChallengeHandler.sendRosterState(player, "request")
		return
	end

	if payload.action == "select-follower" then
		if type(payload.monsterId) ~= "string" then
			sendDuelState(player, { type = "roster-error", reason = "invalid-monster-id" })
			return
		end
		if CombatContext.activeDuels[player] then
			sendDuelState(player, { type = "roster-error", reason = "duel-active" })
			return
		end
		local ok, reason = CombatContext.TeamManager.setSelectedFollowerMonsterId(player, payload.monsterId)
		if not ok then
			sendDuelState(player, { type = "roster-error", reason = reason or "invalid-follower" })
			return
		end
		local state = CombatContext.playerStates[player]
		if state then state.followMonsterId = CombatContext.TeamManager.getSelectedFollowerMonsterId(player) end
		CombatContext.PetCubeService.spawnPlayerTeamCubes(player, state and state.team or CombatContext.TeamManager.getOrCreateTeam(player), state and state.followMonsterId)
		ChallengeHandler.sendRosterState(player, "follower-updated")
		return
	end

	if payload.action == "set-duel-slot" then
		applyDuelSlotSelection(player, payload)
		return
	end

	if payload.action == "feed" then
		if type(payload.targetMonsterId) ~= "string" or type(payload.foodMonsterId) ~= "string" then
			sendDuelState(player, { type = "roster-error", reason = "invalid-monster-ids" })
			return
		end
		local success, reason, xpGained, newXP = CombatContext.TeamManager.feedMonster(player, payload.targetMonsterId, payload.foodMonsterId)
		if not success then
			sendDuelState(player, { type = "roster-error", reason = reason or "feed-failed" })
			return
		end
		sendDuelState(player, { type = "feed-result", xpGained = xpGained, newXP = newXP })
		ChallengeHandler.sendRosterState(player, "feed")
		return
	end

	if payload.action == "craft" then
		if type(payload.monsterId) ~= "string" then
			sendDuelState(player, { type = "roster-error", reason = "invalid-monster-id" })
			return
		end
		local success, reason = CombatContext.TeamManager.craftMonster(player, payload.monsterId)
		if not success then
			sendDuelState(player, { type = "roster-error", reason = reason or "craft-failed" })
			return
		end
		ChallengeHandler.sendRosterState(player, "craft")
		return
	end

	sendDuelState(player, { type = "roster-error", reason = "unknown-action" })
end

-- ============================================================
-- CHALLENGES PvP
-- ============================================================

function ChallengeHandler.onCombatChallengeRequest(player, payload)
	-- Propósito: Procesar solicitud de desafío PvP entre dos jugadores.
	-- Precondiciones:
	--   1. payload.targetUserId debe ser number válido.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if type(payload) ~= "table" or type(payload.targetUserId) ~= "number" then return end
	local targetPlayer = CombatContext.Players:GetPlayerByUserId(payload.targetUserId)
	if not targetPlayer or targetPlayer == player then
		sendDuelState(player, { type = "challenge-failed", reason = "target-invalid" })
		return
	end
	if CombatContext.activeDuels[player] or CombatContext.activeDuels[targetPlayer] or CombatContext.activeMonsterDuels[player] or CombatContext.activeMonsterDuels[targetPlayer] then
		sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
		return
	end
	local dist = CombatContext.DuelManager.getPlayersDistance(player, targetPlayer)
	if not dist or dist > CombatContext.CHALLENGE_DISTANCE then
		sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
		return
	end
	local team = CombatContext.playerStates[player] and CombatContext.playerStates[player].team or CombatContext.TeamManager.getOrCreateTeam(player)
	local isValid, reason = CombatContext.TeamManager.validateTeam(team)
	if not isValid then
		sendDuelState(player, { type = "challenge-failed", reason = "team-invalid" })
		return
	end
	sendDuelState(player, { type = "challenge-sent", targetName = targetPlayer.Name })
	sendDuelState(targetPlayer, { type = "challenge-received", challengerName = player.Name, challengerUserId = player.UserId })
	local challenge = { challenger = player, target = targetPlayer, timestamp = os.clock() }
	CombatContext.pendingChallenges[targetPlayer] = challenge
	task.delay(CombatContext.CHALLENGE_TIMEOUT, function()
		if CombatContext.pendingChallenges[targetPlayer] == challenge then
			CombatContext.pendingChallenges[targetPlayer] = nil
			sendDuelState(player, { type = "challenge-failed", reason = "challenge-timeout" })
			sendDuelState(targetPlayer, { type = "challenge-expired", challengerName = player.Name })
		end
	end)
end

function ChallengeHandler.onCombatChallengeResponse(player, payload)
	-- Propósito: Procesar respuesta a un desafío PvP (aceptar/rechazar) e iniciar duelo si se acepta.
	-- Precondiciones:
	--   1. payload.challengerUserId debe ser number.
	--   2. payload.accepted debe ser boolean.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if type(payload) ~= "table" or type(payload.challengerUserId) ~= "number" or type(payload.accepted) ~= "boolean" then return end
	local challenge = CombatContext.pendingChallenges[player]
	if not challenge or challenge.challenger.UserId ~= payload.challengerUserId then
		sendDuelState(player, { type = "challenge-failed", reason = "no-pending-challenge" })
		return
	end
	CombatContext.pendingChallenges[player] = nil
	local challenger = challenge.challenger
	if not payload.accepted then
		sendDuelState(challenger, { type = "challenge-declined", targetName = player.Name })
		sendDuelState(player, { type = "challenge-declined", targetName = challenger.Name })
		return
	end
	if CombatContext.activeDuels[challenger] or CombatContext.activeDuels[player] or CombatContext.activeMonsterDuels[challenger] or CombatContext.activeMonsterDuels[player] then
		sendDuelState(challenger, { type = "challenge-failed", reason = "duel-busy" })
		sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
		return
	end
	local dist = CombatContext.DuelManager.getPlayersDistance(challenger, player)
	if not dist or dist > CombatContext.CHALLENGE_DISTANCE then
		sendDuelState(challenger, { type = "challenge-failed", reason = "target-too-far" })
		sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
		return
	end
	local teamA = CombatContext.playerStates[challenger] and CombatContext.playerStates[challenger].team or CombatContext.TeamManager.getOrCreateTeam(challenger)
	local teamB = CombatContext.playerStates[player] and CombatContext.playerStates[player].team or CombatContext.TeamManager.getOrCreateTeam(player)
	if not CombatContext.TeamManager.validateTeam(teamA) then
		sendDuelState(challenger, { type = "challenge-failed", reason = "team-invalid" })
		sendDuelState(player, { type = "challenge-failed", reason = "team-invalid" })
		return
	end
	if not CombatContext.TeamManager.validateTeam(teamB) then
		sendDuelState(challenger, { type = "challenge-failed", reason = "team-invalid" })
		sendDuelState(player, { type = "challenge-failed", reason = "team-invalid" })
		return
	end

	local hpA = CombatContext.TeamManager.calculateTeamHP(teamA)
	local hpB = CombatContext.TeamManager.calculateTeamHP(teamB)
	local duel = {
		playerA = challenger, playerB = player,
		hpByUserId = { [challenger.UserId] = hpA, [player.UserId] = hpB },
		started = false,
	}
	CombatContext.activeDuels[challenger] = duel
	CombatContext.activeDuels[player] = duel
	CombatContext.duelSequence += 1
	local stateA = CombatContext.playerStates[challenger]
	local stateB = CombatContext.playerStates[player]
	if stateA then stateA.duelId = CombatContext.duelSequence; stateA.duelActive = true; stateA.duelStarted = false end
	if stateB then stateB.duelId = CombatContext.duelSequence; stateB.duelActive = true; stateB.duelStarted = false end

	task.spawn(function() CombatContext.DuelManager.startDuelCountdown(duel) end)
end

-- ============================================================
-- PLAYER INIT / CLEANUP
-- ============================================================

local function spawnPlayerPetCubes(player)
	-- Propósito: Spawnear cubos de equipo para el personaje actual del jugador.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	local state = CombatContext.playerStates[player]
	local team = state and state.team or CombatContext.TeamManager.getOrCreateTeam(player)
	local selectedFollowerMonsterId = (state and state.followMonsterId) or CombatContext.TeamManager.getSelectedFollowerMonsterId(player)
	task.wait(0.1)
	CombatContext.PetCubeService.spawnPlayerTeamCubes(player, team, selectedFollowerMonsterId)
end

local characterConnections = {}

local function bindCharacterSpawn(player)
	-- Propósito: Conectar spawn de cubos al respawn y al personaje actual.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if characterConnections[player] then characterConnections[player]:Disconnect(); characterConnections[player] = nil end
	characterConnections[player] = player.CharacterAdded:Connect(function() spawnPlayerPetCubes(player) end)
	if player.Character then spawnPlayerPetCubes(player) end
end

function ChallengeHandler.initPlayerState(player)
	-- Propósito: Inicializar el tablero y metadatos del jugador.
	-- Precondiciones:
	--   1. player debe ser válido.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	local team = CombatContext.TeamManager.getOrCreateTeam(player)
	local backpack = CombatContext.TeamManager.getBackpack(player)
	local selectedFollowerMonsterId = CombatContext.TeamManager.getSelectedFollowerMonsterId(player)
	local isTeamValid, teamReason = CombatContext.TeamManager.validateTeam(team)
	CombatContext.playerStates[player] = {
		grid = CombatContext.GridResolver.createStableGrid(),
		lastSubmit = 0,
		team = team,
		backpack = backpack,
		followMonsterId = selectedFollowerMonsterId,
		teamValid = isTeamValid,
		teamReason = teamReason,
		duelId = nil,
		duelActive = false,
		duelStarted = false,
	}
	bindCharacterSpawn(player)
end

function ChallengeHandler.cleanPlayerState(player)
	-- Propósito: Liberar el estado del jugador y finalizar duelos activos al desconectarse.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	if CombatContext.activeDuels[player] then
		local duel = CombatContext.activeDuels[player]
		local opponent = duel.playerA == player and duel.playerB or duel.playerA
		CombatContext.DuelManager.endDuel(duel, opponent, "player-left")
	end
	if CombatContext.activeMonsterDuels[player] then
		CombatContext.MonsterDuel.endMonsterDuel(player, "player-left", "monster")
	end
	CombatContext.pendingChallenges[player] = nil
	for otherPlayer, challenge in pairs(CombatContext.pendingChallenges) do
		if challenge.challenger == player then
			CombatContext.pendingChallenges[otherPlayer] = nil
			sendDuelState(otherPlayer, { type = "challenge-expired", challengerName = player.Name })
		end
	end
	CombatContext.playerStates[player] = nil
	if characterConnections[player] then characterConnections[player]:Disconnect(); characterConnections[player] = nil end
end

-- ============================================================
-- SHIELD REGEN
-- ============================================================

function ChallengeHandler.runShieldRegenLoop()
	-- Propósito: Ejecutar loop periódico de regeneración de Shield Charges.
	-- Precondiciones: Ninguna.
	-- Ubicación: ServerScriptService/Combat/ChallengeHandler
	-- Retorna: nil
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in ipairs(CombatContext.Players:GetPlayers()) do
				CombatContext.PvpStarsService.applyShieldRegen(player, os.time())
			end
		end
	end)
end

return ChallengeHandler
