-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/GridResolver
-- Contexto: Servidor
--
-- Responsable de la lógica del tablero match-3: validación de swaps, cascadas, resolución de combos, daño.

local GridResolver = {}
local CombatContext = require(script.Parent:WaitForChild("CombatContext"))

local function dbg(message)
	-- Propósito: Emitir logs de depuración del GridResolver.
	-- Precondiciones:
	--   1. message debe ser string.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: nil
	if CombatContext and CombatContext.dbg then CombatContext.dbg(message) end
end

local function syncPlayer(player, extraData)
	-- Propósito: Enviar el estado canónico actual del grid al cliente.
	-- Precondiciones:
	--   1. player debe tener estado activo.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: nil
	local state = CombatContext.playerStates[player]
	if not state then return end
	local payload = { grid = state.grid }
	if type(extraData) == "table" then
		for key, value in pairs(extraData) do payload[key] = value end
	end
	CombatContext.CombatSync:FireClient(player, payload)
end

local function isValidSwapPayload(payload)
	-- Propósito: Validar forma básica del payload enviado por cliente.
	-- Precondiciones:
	--   1. payload debe ser tabla.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: boolean
	if type(payload) ~= "table" then return false end
	if type(payload.path) ~= "table" or #payload.path < 2 then return false end
	for _, cell in ipairs(payload.path) do
		if type(cell) ~= "table" then return false end
		local values = { cell.col, cell.row }
		for _, value in ipairs(values) do
			if type(value) ~= "number" or value ~= math.floor(value) then return false end
		end
		if cell.col < 1 or cell.col > CombatContext.COLS or cell.row < 1 or cell.row > CombatContext.ROWS then return false end
	end
	return true
end

function GridResolver.createStableGrid()
	-- Propósito: Crear un tablero inicial sin matches ya presentes.
	-- Precondiciones:
	--   1. CombatGrid.newGrid y CombatGrid.findMatches deben existir.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: table
	local attempts = 0
	while attempts < 20 do
		attempts += 1
		local grid = CombatContext.CombatGrid.newGrid()
		local matches = CombatContext.CombatGrid.findMatches(grid)
		if not matches.hasMatches then return grid end
	end
	return CombatContext.CombatGrid.newGrid()
end

local function appendComboSummary(summary, combos, grid)
	-- Propósito: Acumular total de combos y elementos activados del movimiento.
	-- Precondiciones:
	--   1. summary debe ser tabla válida.
	--   2. combos debe ser tabla o nil.
	--   3. grid debe ser tablero válido.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: nil
	if type(combos) ~= "table" then return end
	for _, combo in ipairs(combos) do
		summary.totalCombos += 1
		if type(combo) == "table" and combo[1] then
			local anchor = combo[1]
			local tile = grid[anchor.col] and grid[anchor.col][anchor.row]
			if tile and type(tile.elementType) == "string" then
				summary.activatedElements[tile.elementType] = true
			end
		end
	end
end

local function getActivatedElementsList(activatedElements)
	-- Propósito: Convertir el set de elementos activados en lista serializable.
	-- Precondiciones:
	--   1. activatedElements debe ser tabla set.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: table
	local list = {}
	for element, isActive in pairs(activatedElements) do
		if isActive then table.insert(list, element) end
	end
	table.sort(list)
	return list
end

local function estimateCascadeAnimationDuration(cascades)
	-- Propósito: Estimar duración cliente de animación de cascadas para sincronizar daño.
	-- Precondiciones:
	--   1. cascades debe ser lista o nil.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: number
	if type(cascades) ~= "table" or #cascades == 0 then return 0 end
	local totalTime = 0
	for _, cascade in ipairs(cascades) do
		local combos = type(cascade.combos) == "table" and cascade.combos or {}
		local comboCount = #combos
		totalTime += comboCount * (CombatContext.COMBO_SCALE_OUT_TIME + CombatContext.COMBO_STAGGER_TIME)
		local hasGravity = (type(cascade.movimientos) == "table" and #cascade.movimientos > 0)
			or (type(cascade.nuevas) == "table" and #cascade.nuevas > 0)
		if hasGravity then totalTime += CombatContext.FALL_TWEEN_TIME + CombatContext.BOUNCE_DURATION end
		totalTime += CombatContext.CASCADE_GAP_TIME
	end
	return totalTime
end

function GridResolver.onCombatSubmit(player, payload)
	-- Propósito: Procesar una ruta de swaps enviada por el cliente, resolver combos y aplicar daño.
	-- Precondiciones:
	--   1. player debe tener estado inicializado.
	--   2. payload.path debe describir swaps adyacentes consecutivos.
	-- Ubicación: ServerScriptService/Combat/GridResolver
	-- Retorna: nil
	local state = CombatContext.playerStates[player]
	if not state then
		warn("[CombatServer] Submit de jugador sin estado: " .. player.Name)
		return
	end

	local monsterDuel = CombatContext.activeMonsterDuels[player]
	local opponent, duel = CombatContext.DuelManager.getDuelOpponent(player)
	if not duel and not monsterDuel then
		syncPlayer(player, { rejected = true, reason = "duel-not-active", duelActive = false, duelStarted = false })
		return
	end

	local isMonsterDuel = (monsterDuel ~= nil and duel == nil)
	local activeDuel = isMonsterDuel and monsterDuel or duel
	if not activeDuel.started then
		syncPlayer(player, { rejected = true, reason = "duel-not-started", duelActive = true, duelStarted = false })
		return
	end

	local team = state.team or CombatContext.TeamManager.getOrCreateTeam(player)
	local isTeamValid, teamReason = CombatContext.TeamManager.validateTeam(team)
	state.team = team
	state.teamValid = isTeamValid
	state.teamReason = teamReason

	if not isTeamValid then
		syncPlayer(player, { rejected = true, reason = "team-invalid", teamValid = false, teamReason = teamReason,
			playerTotalHP = CombatContext.TeamManager.calculateTeamHP(team) })
		return
	end

	dbg("submit recibido de " .. player.Name)

	local now = os.clock()
	if (now - state.lastSubmit) < 0.15 then
		warn("[CombatServer] Submit demasiado rápido de: " .. player.Name)
		return
	end
	state.lastSubmit = now

	if not isValidSwapPayload(payload) then
		syncPlayer(player, { rejected = true, reason = "invalid-payload" })
		return
	end

	local gridBefore = CombatContext.CombatGrid.cloneGrid(state.grid)
	local valid = CombatContext.CombatGrid.isPathValid(gridBefore, payload.path)
	if not valid then
		dbg("Path inválido de " .. player.Name)
		syncPlayer(player, { rejected = true, reason = "invalid-path" })
		return
	end

	local summary = {
		totalCombos = 0,
		activatedElements = {},
	}

	CombatContext.CombatGrid.solveCombos(gridBefore, summary, appendComboSummary)

	local cascades = summary.cascades
	state.grid = summary.grid

	local activeElements = getActivatedElementsList(summary.activatedElements)

	local damageByPet = {}
	local totalDamage = 0

	if summary.totalCombos > 0 then
		for slot, pet in ipairs(team) do
			local monsterId = pet.MonsterId
			local monsterData = CombatContext.MonstersData[monsterId]
			local baseAttack = 0
			if monsterData and type(monsterData.BaseStats) == "table" and type(monsterData.BaseStats.Attack) == "number" then
				baseAttack = monsterData.BaseStats.Attack
			end
			local element = monsterData and monsterData.Element or "Desconocido"
			local damage = CombatContext.MonsterCombat.calculateDamage(baseAttack, summary.totalCombos, activeElements, element)
			totalDamage += damage
			table.insert(damageByPet, { slot = slot, damage = damage, element = element })
		end
	end

	local targetPlayer = nil
	local isPvP = not isMonsterDuel
	if isPvP then targetPlayer = opponent end

	local animationWait = estimateCascadeAnimationDuration(cascades)
	if animationWait > 0 then task.wait(animationWait) end

	local syncData = {
		grid = state.grid,
		cascades = cascades,
		duelActive = true,
		duelStarted = true,
		opponentKind = isPvP and "player" or "monster",
		playerTotalHP = CombatContext.TeamManager.calculateTeamHP(team),
	}

	local selfHP = isPvP and duel.hpByUserId[player.UserId] or activeDuel.playerHP
	local enemyHP = isPvP and duel.hpByUserId[opponent.UserId] or activeDuel.monsterHP

	if isPvP then
		if totalDamage > 0 then
			local newEnemyHP = math.max(0, enemyHP - totalDamage)
			duel.hpByUserId[opponent.UserId] = newEnemyHP
			enemyHP = newEnemyHP

			CombatContext.DuelManager.playPlayerAttackVfxSequence(player, damageByPet, function()
				return CombatContext.DuelManager.getPlayerTargetPosition(opponent)
			end)

			if newEnemyHP <= 0 then
				CombatContext.DuelManager.endDuel(duel, player, "hp-depleted")
				syncPlayer(player, { grid = state.grid, cascades = cascades, duelActive = false, duelStarted = false,
					opponentName = opponent.Name, opponentKind = "player",
					selfHP = duel.hpByUserId[player.UserId], enemyHP = newEnemyHP,
					playerTotalHP = CombatContext.TeamManager.calculateTeamHP(team) })
				return
			end
		end

		syncData.selfHP = selfHP
		syncData.enemyHP = enemyHP
		syncData.opponentName = opponent.Name
		syncPlayer(player, syncData)

		if totalDamage > 0 then
			syncPlayer(opponent, {
				grid = opponent and CombatContext.playerStates[opponent] and CombatContext.playerStates[opponent].grid or state.grid,
				duelActive = true, duelStarted = true,
				opponentName = player.Name, opponentKind = "player",
				selfHP = enemyHP, enemyHP = selfHP,
				playerTotalHP = CombatContext.TeamManager.calculateTeamHP(team),
			})
		end
	else
		if totalDamage > 0 then
			local newMonsterHP = math.max(0, activeDuel.monsterHP - totalDamage)
			activeDuel.monsterHP = newMonsterHP

			CombatContext.DuelManager.playPlayerAttackVfxSequence(player, damageByPet, function()
				return activeDuel.monsterRoot and activeDuel.monsterRoot.Position
			end)

			if newMonsterHP <= 0 then
				CombatContext.MonsterDuel.endMonsterDuel(player, "hp-depleted", "player")
				syncPlayer(player, { grid = state.grid, cascades = cascades, duelActive = false, duelStarted = false,
					opponentName = activeDuel.monsterName, opponentKind = "monster",
					selfHP = activeDuel.playerHP, enemyHP = newMonsterHP,
					playerTotalHP = CombatContext.TeamManager.calculateTeamHP(team) })
				return
			end
		end

		syncData.selfHP = activeDuel.playerHP
		syncData.enemyHP = activeDuel.monsterHP
		syncData.opponentName = activeDuel.monsterName
		syncPlayer(player, syncData)
	end
end

return GridResolver
