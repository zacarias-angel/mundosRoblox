-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/DuelManager
-- Contexto: Servidor
--
-- Responsable del ciclo de vida de duelos PvP: setup, anclaje, countdown, finalización, VFX.

local DuelManager = {}
local CombatContext = require(script.Parent:WaitForChild("CombatContext"))

local function dbg(message)
	-- Propósito: Emitir logs de depuración del DuelManager.
	-- Precondiciones:
	--   1. message debe ser string.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if CombatContext and CombatContext.dbg then CombatContext.dbg(message) end
end

local function sendDuelState(player, data)
	-- Propósito: Enviar una actualización de estado de duelo a un cliente.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	--   2. data debe ser tabla serializable.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if not player then return end
	CombatContext.CombatDuelState:FireClient(player, data)
end

local function getPlayerPetCubePart(player, slot)
	-- Propósito: Obtener part visual del Beastibit por slot del jugador en duelo.
	-- Precondiciones:
	--   1. player debe ser Player válido.
	--   2. slot debe ser number.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: BasePart|nil
	local worldFolder = workspace:FindFirstChild(CombatContext.PET_CUBES_WORLD_FOLDER)
	if not worldFolder then return nil end
	local playerFolder = worldFolder:FindFirstChild(player.Name)
	if not playerFolder then return nil end
	local slotIndex = math.floor(tonumber(slot) or 0)
	local cube = playerFolder:FindFirstChild("PetCube_" .. tostring(slotIndex))
	if not cube and slotIndex >= 0 then
		cube = playerFolder:FindFirstChild("PetCube_" .. tostring(slotIndex + 1))
	end
	if not cube then
		for _, child in ipairs(playerFolder:GetChildren()) do
			if string.sub(child.Name, 1, 8) == "PetCube_" then
				cube = child
				break
			end
		end
	end
	if cube and cube:IsA("BasePart") then return cube end
	if cube and cube:IsA("Model") then
		local rootPart = cube.PrimaryPart
		if not rootPart or not rootPart:IsA("BasePart") then
			local preferredRoot = cube:FindFirstChild("HumanoidRootPart", true)
			if preferredRoot and preferredRoot:IsA("BasePart") then
				rootPart = preferredRoot
			else
				rootPart = cube:FindFirstChildWhichIsA("BasePart", true)
			end
		end
		if rootPart and rootPart:IsA("BasePart") then return rootPart end
	end
	return nil
end

local function getProjectileColorForElement(element)
	-- Propósito: Resolver color del proyectil según elemento del Beastibit.
	-- Precondiciones:
	--   1. element puede ser string o nil.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: Color3
	if type(element) == "string" and CombatContext.ELEMENT_PROJECTILE_COLORS[element] then
		return CombatContext.ELEMENT_PROJECTILE_COLORS[element]
	end
	return Color3.fromRGB(255, 255, 255)
end

function DuelManager.getPvpTargetPosition(opponent)
	-- Propósito: Obtener posición destino en PvP para impactar Beastibit objetivo.
	-- Precondiciones:
	--   1. opponent debe ser Player válido.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: Vector3|nil
	local targetCube = getPlayerPetCubePart(opponent, 1)
	if targetCube then return targetCube.Position end
	if not opponent or not opponent.Character then return nil end
	local hrp = opponent.Character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp.Position end
	return nil
end

function DuelManager.getPlayerTargetPosition(player)
	-- Propósito: Obtener posición destino sobre el jugador para impactos visuales.
	-- Precondiciones:
	--   1. player debe ser Player válido.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: Vector3|nil
	local targetCube = getPlayerPetCubePart(player, 1)
	if targetCube then return targetCube.Position end
	if not player or not player.Character then return nil end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp.Position end
	return nil
end

local function spawnProjectileVfx(startPos, targetPos, element)
	-- Propósito: Solicitar a clientes la reproducción local del proyectil para mayor suavidad.
	-- Precondiciones:
	--   1. startPos y targetPos deben ser Vector3.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if typeof(startPos) ~= "Vector3" or typeof(targetPos) ~= "Vector3" then return end
	CombatContext.CombatProjectileVfx:FireAllClients({
		startPos = startPos,
		targetPos = targetPos,
		element = element,
		size = CombatContext.VFX_PROJECTILE_SIZE,
		travelTime = CombatContext.VFX_PROJECTILE_TRAVEL_TIME,
		color = getProjectileColorForElement(element),
	})
end

function DuelManager.playPlayerAttackVfxSequence(attacker, damageByPet, targetPositionResolver)
	-- Propósito: Ejecutar secuencia de proyectiles por Beastibit atacante con daño > 0.
	-- Precondiciones:
	--   1. attacker debe ser Player válido.
	--   2. damageByPet debe ser tabla.
	--   3. targetPositionResolver debe ser función sin args que retorna Vector3|nil.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if not attacker or type(damageByPet) ~= "table" or type(targetPositionResolver) ~= "function" then return end
	task.spawn(function()
		local emittedCount = 0
		for _, petDamage in ipairs(damageByPet) do
			if type(petDamage) ~= "table" then continue end
			local dealt = tonumber(petDamage.damage) or 0
			if dealt <= 0 then continue end
			local slot = tonumber(petDamage.slot) or 1
			local sourceCube = getPlayerPetCubePart(attacker, slot)
			local targetPos = targetPositionResolver()
			if sourceCube and targetPos then
				spawnProjectileVfx(sourceCube.Position, targetPos, petDamage.element)
				emittedCount += 1
			end
			task.wait(CombatContext.VFX_SEQUENCE_STEP_TIME)
		end
		if emittedCount == 0 then
			dbg("VFX secuencia sin emisiones para " .. attacker.Name)
		end
	end)
end

local function getRootPosition(player)
	-- Propósito: Obtener posición del HumanoidRootPart de un jugador.
	-- Precondiciones:
	--   1. player debe ser instancia Player válida.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: Vector3|nil
	if not player.Character then return nil end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return nil end
	return hrp.Position
end

function DuelManager.getPlayersDistance(playerA, playerB)
	-- Propósito: Calcular distancia entre dos jugadores para validar desafío.
	-- Precondiciones:
	--   1. playerA y playerB deben ser válidos.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: number|nil
	local posA = getRootPosition(playerA)
	local posB = getRootPosition(playerB)
	if not posA or not posB then return nil end
	return (posA - posB).Magnitude
end

local function getGroundYAt(position, ignoreInstances)
	-- Propósito: Obtener altura de suelo en una posición usando raycast vertical.
	-- Precondiciones:
	--   1. position debe ser Vector3.
	--   2. ignoreInstances puede ser tabla de Instancias.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: number|nil
	if typeof(position) ~= "Vector3" then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filteredIgnore = {}
	if type(ignoreInstances) == "table" then
		for _, inst in ipairs(ignoreInstances) do
			if typeof(inst) == "Instance" then table.insert(filteredIgnore, inst) end
		end
	end
	params.FilterDescendantsInstances = filteredIgnore
	local origin = Vector3.new(position.X, position.Y + CombatContext.GROUND_ALIGN_RAYCAST_HEIGHT, position.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -CombatContext.GROUND_ALIGN_RAYCAST_DEPTH, 0), params)
	if not result then return nil end
	return result.Position.Y
end

local function alignTargetToGround(hrp, targetPos, ignoreInstances)
	-- Propósito: Ajustar Y de una posición objetivo para evitar hundir al jugador en el terreno.
	-- Precondiciones:
	--   1. hrp debe ser BasePart válida.
	--   2. targetPos debe ser Vector3.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: Vector3
	if not hrp or not hrp:IsA("BasePart") or typeof(targetPos) ~= "Vector3" then return targetPos end
	local currentGroundY = getGroundYAt(hrp.Position, ignoreInstances)
	local targetGroundY = getGroundYAt(targetPos, ignoreInstances)
	if not targetGroundY then return Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z) end
	local groundOffset = CombatContext.DEFAULT_HRP_GROUND_OFFSET
	if type(currentGroundY) == "number" then
		groundOffset = math.max(1.5, hrp.Position.Y - currentGroundY)
	end
	return Vector3.new(targetPos.X, targetGroundY + groundOffset, targetPos.Z)
end

function DuelManager.getDuelOpponent(player)
	-- Propósito: Obtener oponente del duelo activo de un jugador.
	-- Precondiciones:
	--   1. player puede o no estar en duelo.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: Player|nil, table|nil
	local duel = CombatContext.activeDuels[player]
	if not duel then return nil, nil end
	if duel.playerA == player then return duel.playerB, duel end
	if duel.playerB == player then return duel.playerA, duel end
	return nil, nil
end

function DuelManager.setupDuelParticipants(duel)
	-- Propósito: Posicionar ambos domadores anclados, enfrentados y en distancia fija para el duelo PvP.
	-- Precondiciones:
	--   1. duel debe tener playerA y playerB válidos.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if not duel or not duel.playerA or not duel.playerB then return end
	local charA = duel.playerA.Character
	local charB = duel.playerB.Character
	if not charA or not charB then return end
	local hrpA = charA:FindFirstChild("HumanoidRootPart")
	local hrpB = charB:FindFirstChild("HumanoidRootPart")
	local humA = charA:FindFirstChildOfClass("Humanoid")
	local humB = charB:FindFirstChildOfClass("Humanoid")
	if not hrpA or not hrpB or not hrpA:IsA("BasePart") or not hrpB:IsA("BasePart") then return end

	duel.anchorStateByUserId = duel.anchorStateByUserId or {}
	duel.anchorStateByUserId[duel.playerA.UserId] = {
		wasAnchored = hrpA.Anchored,
		walkSpeed = humA and humA.WalkSpeed or nil,
		jumpPower = humA and humA.JumpPower or nil,
		autoRotate = humA and humA.AutoRotate or nil,
		platformStand = humA and humA.PlatformStand or nil,
	}
	duel.anchorStateByUserId[duel.playerB.UserId] = {
		wasAnchored = hrpB.Anchored,
		walkSpeed = humB and humB.WalkSpeed or nil,
		jumpPower = humB and humB.JumpPower or nil,
		autoRotate = humB and humB.AutoRotate or nil,
		platformStand = humB and humB.PlatformStand or nil,
	}

	local center = (hrpA.Position + hrpB.Position) * 0.5
	local dir = hrpB.Position - hrpA.Position
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1e-4 then
		dir = Vector3.new(hrpA.CFrame.LookVector.X, 0, hrpA.CFrame.LookVector.Z)
	end
	if dir.Magnitude < 1e-4 then dir = Vector3.new(0, 0, -1) end
	local forward = dir.Unit
	local right = forward:Cross(Vector3.new(0, 1, 0))
	if right.Magnitude < 1e-4 then right = Vector3.new(1, 0, 0) else right = right.Unit end
	local sideShift = -right * CombatContext.DUEL_SIDE_SHIFT

	local worldLeftShift = Vector3.new(-CombatContext.WORLD_LEFT_COMBAT_SHIFT_STUDS, 0, 0)
	local posA = center - (forward * (CombatContext.DUEL_PLAYER_DISTANCE * 0.5))
	local posB = center + (forward * (CombatContext.DUEL_PLAYER_DISTANCE * 0.5))
	posA += sideShift; posB += sideShift
	posA += worldLeftShift; posB += worldLeftShift
	local pvpIgnore = { charA, charB }
	posA = alignTargetToGround(hrpA, posA, pvpIgnore)
	posB = alignTargetToGround(hrpB, posB, pvpIgnore)

	hrpA.Anchored = true; hrpB.Anchored = true
	hrpA.AssemblyLinearVelocity = Vector3.zero; hrpB.AssemblyLinearVelocity = Vector3.zero
	hrpA.AssemblyAngularVelocity = Vector3.zero; hrpB.AssemblyAngularVelocity = Vector3.zero
	hrpA.CFrame = CFrame.lookAt(posA, posB, Vector3.new(0, 1, 0))
	hrpB.CFrame = CFrame.lookAt(posB, posA, Vector3.new(0, 1, 0))

	if humA then humA.AutoRotate = false; humA.WalkSpeed = 0; humA.JumpPower = 0; humA.PlatformStand = true end
	if humB then humB.AutoRotate = false; humB.WalkSpeed = 0; humB.JumpPower = 0; humB.PlatformStand = true end

	local stateA = CombatContext.playerStates[duel.playerA]
	local stateB = CombatContext.playerStates[duel.playerB]
	local teamA = stateA and stateA.team or CombatContext.TeamManager.getOrCreateTeam(duel.playerA)
	local teamB = stateB and stateB.team or CombatContext.TeamManager.getOrCreateTeam(duel.playerB)

	CombatContext.PetCubeService.spawnPlayerTeamDuelLine(duel.playerA, teamA, hrpB.Position)
	CombatContext.PetCubeService.spawnPlayerTeamDuelLine(duel.playerB, teamB, hrpA.Position)
end

function DuelManager.restoreDuelParticipants(duel)
	-- Propósito: Restaurar movilidad y estado original de ambos domadores al terminar duelo PvP.
	-- Precondiciones:
	--   1. duel puede contener estados previos de anclaje.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if not duel then return end
	local participants = { duel.playerA, duel.playerB }
	for _, participant in ipairs(participants) do
		if participant and participant.Character then
			local hrp = participant.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = participant.Character:FindFirstChildOfClass("Humanoid")
			local previousState = duel.anchorStateByUserId and duel.anchorStateByUserId[participant.UserId]
			if hrp and hrp:IsA("BasePart") then
				hrp.Anchored = previousState and previousState.wasAnchored or false
			end
			if humanoid and previousState then
				if type(previousState.walkSpeed) == "number" then humanoid.WalkSpeed = previousState.walkSpeed end
				if type(previousState.jumpPower) == "number" then humanoid.JumpPower = previousState.jumpPower end
				if type(previousState.autoRotate) == "boolean" then humanoid.AutoRotate = previousState.autoRotate end
				if type(previousState.platformStand) == "boolean" then humanoid.PlatformStand = previousState.platformStand
				else humanoid.PlatformStand = false end
			end
			local participantState = CombatContext.playerStates[participant]
			local team = participantState and participantState.team or CombatContext.TeamManager.getOrCreateTeam(participant)
			CombatContext.PetCubeService.spawnPlayerTeamCubes(participant, team)
		end
	end
end

function DuelManager.endDuel(duel, winner, reason)
	-- Propósito: Finalizar un duelo activo y notificar resultado a ambos jugadores.
	-- Precondiciones:
	--   1. duel debe ser tabla válida de duelo.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if not duel then return end
	local loser = nil
	if winner == duel.playerA then loser = duel.playerB
	elseif winner == duel.playerB then loser = duel.playerA end

	DuelManager.restoreDuelParticipants(duel)

	for _, participant in ipairs({ duel.playerA, duel.playerB }) do
		CombatContext.activeDuels[participant] = nil
		local state = CombatContext.playerStates[participant]
		if state then
			state.duelId = nil
			state.duelActive = false
			state.duelStarted = false
		end
	end

	if winner and loser and reason == "hp-depleted" then
		local winnerStars, loserStars, shieldUsed = CombatContext.PvpStarsService.applyPvpDuelResult(winner, loser)
		dbg("duelo finalizado: " .. winner.Name .. " venció a " .. loser.Name
			.. " | estrellas => " .. winner.Name .. ":" .. tostring(winnerStars)
			.. " / " .. loser.Name .. ":" .. tostring(loserStars)
			.. (shieldUsed and " [SHIELD]" or ""))

		sendDuelState(winner, {
			type = "duel-ended", winnerUserId = winner.UserId,
			opponentName = loser.Name, opponentUserId = loser.UserId,
			opponentKind = "player", starsDelta = 1,
			newSelfStars = winnerStars, shieldUsed = shieldUsed or false,
		})
		sendDuelState(loser, {
			type = "duel-ended", winnerUserId = winner.UserId,
			opponentName = winner.Name, opponentUserId = winner.UserId,
			opponentKind = "player", starsDelta = -1,
			newSelfStars = loserStars, shieldUsed = shieldUsed or false,
		})
		return
	end

	local reasonMsg = reason or "duel-ended"
	sendDuelState(duel.playerA, {
		type = "duel-ended", winnerUserId = winner and winner.UserId or nil,
		opponentName = duel.playerB.Name, opponentUserId = duel.playerB.UserId,
		opponentKind = "player", reason = reasonMsg,
	})
	sendDuelState(duel.playerB, {
		type = "duel-ended", winnerUserId = winner and winner.UserId or nil,
		opponentName = duel.playerA.Name, opponentUserId = duel.playerA.UserId,
		opponentKind = "player", reason = reasonMsg,
	})
end

function DuelManager.startDuelCountdown(duel)
	-- Propósito: Ejecutar countdown 3-2-1 y habilitar combate al finalizar.
	-- Precondiciones:
	--   1. duel debe estar activo y con dos jugadores válidos.
	-- Ubicación: ServerScriptService/Combat/DuelManager
	-- Retorna: nil
	if not duel then return end
	DuelManager.setupDuelParticipants(duel)

	sendDuelState(duel.playerA, { type = "duel-intro", opponentKind = "player",
		opponentName = duel.playerB.Name, opponentUserId = duel.playerB.UserId,
		selfHP = duel.hpByUserId[duel.playerA.UserId], enemyHP = duel.hpByUserId[duel.playerB.UserId],
		selfStars = CombatContext.PvpStarsService.getStars(duel.playerA), opponentStars = CombatContext.PvpStarsService.getStars(duel.playerB) })
	sendDuelState(duel.playerB, { type = "duel-intro", opponentKind = "player",
		opponentName = duel.playerA.Name, opponentUserId = duel.playerA.UserId,
		selfHP = duel.hpByUserId[duel.playerB.UserId], enemyHP = duel.hpByUserId[duel.playerA.UserId],
		selfStars = CombatContext.PvpStarsService.getStars(duel.playerB), opponentStars = CombatContext.PvpStarsService.getStars(duel.playerA) })

	for seconds = CombatContext.COUNTDOWN_SECONDS, 1, -1 do
		if CombatContext.activeDuels[duel.playerA] ~= duel or CombatContext.activeDuels[duel.playerB] ~= duel then return end
		sendDuelState(duel.playerA, { type = "countdown", value = seconds, opponentKind = "player",
			opponentName = duel.playerB.Name, opponentUserId = duel.playerB.UserId,
			selfHP = duel.hpByUserId[duel.playerA.UserId], enemyHP = duel.hpByUserId[duel.playerB.UserId],
			selfStars = CombatContext.PvpStarsService.getStars(duel.playerA), opponentStars = CombatContext.PvpStarsService.getStars(duel.playerB) })
		sendDuelState(duel.playerB, { type = "countdown", value = seconds, opponentKind = "player",
			opponentName = duel.playerA.Name, opponentUserId = duel.playerA.UserId,
			selfHP = duel.hpByUserId[duel.playerB.UserId], enemyHP = duel.hpByUserId[duel.playerA.UserId],
			selfStars = CombatContext.PvpStarsService.getStars(duel.playerB), opponentStars = CombatContext.PvpStarsService.getStars(duel.playerA) })
		task.wait(1)
	end

	duel.started = true
	local stateA = CombatContext.playerStates[duel.playerA]
	local stateB = CombatContext.playerStates[duel.playerB]
	if stateA then stateA.duelStarted = true end
	if stateB then stateB.duelStarted = true end

	sendDuelState(duel.playerA, { type = "duel-started", opponentKind = "player",
		opponentName = duel.playerB.Name, opponentUserId = duel.playerB.UserId,
		selfHP = duel.hpByUserId[duel.playerA.UserId], enemyHP = duel.hpByUserId[duel.playerB.UserId],
		selfStars = CombatContext.PvpStarsService.getStars(duel.playerA), opponentStars = CombatContext.PvpStarsService.getStars(duel.playerB) })
	sendDuelState(duel.playerB, { type = "duel-started", opponentKind = "player",
		opponentName = duel.playerA.Name, opponentUserId = duel.playerA.UserId,
		selfHP = duel.hpByUserId[duel.playerB.UserId], enemyHP = duel.hpByUserId[duel.playerA.UserId],
		selfStars = CombatContext.PvpStarsService.getStars(duel.playerB), opponentStars = CombatContext.PvpStarsService.getStars(duel.playerA) })

	local stateA = CombatContext.playerStates[duel.playerA]
	local stateB = CombatContext.playerStates[duel.playerB]
	if stateA then CombatContext.CombatSync:FireClient(duel.playerA, { grid = stateA.grid, duelActive = true, duelStarted = true }) end
	if stateB then CombatContext.CombatSync:FireClient(duel.playerB, { grid = stateB.grid, duelActive = true, duelStarted = true }) end
end

return DuelManager
