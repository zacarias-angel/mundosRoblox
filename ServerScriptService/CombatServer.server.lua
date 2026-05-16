-- Tipo: Script
-- Ubicación: ServerScriptService/CombatServer
-- Contexto: Servidor

--[[
    Servidor de combate match-3 por swap.
    El cliente solo propone un intercambio entre dos celdas adyacentes.
    El servidor valida el swap, resuelve matches, cascadas, gravedad y relleno.

    SEGURIDAD:
    - El cliente nunca decide el estado final del tablero.
    - El grid canónico vive solo en servidor.
    - Cada swap se revalida completamente en servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatGrid = require(Modules:WaitForChild("CombatGrid.module"))

local CombatFolder = ServerScriptService:WaitForChild("Combat")
local TeamManager = require(CombatFolder:WaitForChild("TeamManager"))
local MonsterCombat = require(CombatFolder:WaitForChild("MonsterCombat"))
local PetCubeService = require(CombatFolder:WaitForChild("PetCubeService"))

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatSubmit = RemoteEvents:WaitForChild("CombatSubmit")
local CombatSync = RemoteEvents:WaitForChild("CombatSync")
local CombatChallengeRequest = RemoteEvents:WaitForChild("CombatChallengeRequest")
local CombatChallengeResponse = RemoteEvents:WaitForChild("CombatChallengeResponse")
local CombatDuelState = RemoteEvents:WaitForChild("CombatDuelState")

local COLS, ROWS = CombatGrid.getSize()
local DAMAGE_PER_CELL = 10
local COMBAT_DEBUG = true
local CHALLENGE_DISTANCE = 10
local CHALLENGE_TIMEOUT = 15
local COUNTDOWN_SECONDS = 3
local COMBO_SCALE_OUT_TIME = 0.12
local COMBO_STAGGER_TIME = 0.06
local FALL_TWEEN_TIME = 0.24
local BOUNCE_DURATION = 0.12
local CASCADE_GAP_TIME = 0.08

local playerStates = {}
local characterConnections = {}
local pendingChallenges = {}
local activeDuels = {}
local duelSequence = 0

local function dbg(message)
    -- Propósito: Emitir logs de depuración del servidor de combate.
    -- Precondiciones:
    --   1. message debe ser string.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not COMBAT_DEBUG then
        return
    end
    warn("[CombatServer] " .. tostring(message))
end

local function sendDuelState(player, data)
    -- Propósito: Enviar una actualización de estado de duelo a un cliente.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. data debe ser tabla serializable.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not player then
        return
    end
    CombatDuelState:FireClient(player, data)
end

local function getRootPosition(player)
    -- Propósito: Obtener posición del HumanoidRootPart de un jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Vector3|nil
    if not player.Character then
        return nil
    end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        return nil
    end
    return hrp.Position
end

local function getPlayersDistance(playerA, playerB)
    -- Propósito: Calcular distancia entre dos jugadores para validar desafío.
    -- Precondiciones:
    --   1. playerA y playerB deben ser válidos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number|nil
    local posA = getRootPosition(playerA)
    local posB = getRootPosition(playerB)
    if not posA or not posB then
        return nil
    end
    return (posA - posB).Magnitude
end

local function getDuelOpponent(player)
    -- Propósito: Obtener oponente del duelo activo de un jugador.
    -- Precondiciones:
    --   1. player puede o no estar en duelo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: Player|nil, table|nil
    local duel = activeDuels[player]
    if not duel then
        return nil, nil
    end

    if duel.playerA == player then
        return duel.playerB, duel
    end

    if duel.playerB == player then
        return duel.playerA, duel
    end

    return nil, nil
end

local function endDuel(duel, winner, reason)
    -- Propósito: Finalizar un duelo activo y notificar resultado a ambos jugadores.
    -- Precondiciones:
    --   1. duel debe ser tabla válida de duelo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel then
        return
    end

    local loser = nil
    if winner == duel.playerA then
        loser = duel.playerB
    elseif winner == duel.playerB then
        loser = duel.playerA
    end

    for _, participant in ipairs({ duel.playerA, duel.playerB }) do
        activeDuels[participant] = nil
        local state = playerStates[participant]
        if state then
            state.duelId = nil
            state.duelActive = false
            state.duelStarted = false
        end
    end

    sendDuelState(duel.playerA, {
        type = "duel-ended",
        winnerUserId = winner and winner.UserId or nil,
        reason = reason or "duel-ended",
    })
    sendDuelState(duel.playerB, {
        type = "duel-ended",
        winnerUserId = winner and winner.UserId or nil,
        reason = reason or "duel-ended",
    })

    if winner and loser then
        dbg("duelo finalizado: " .. winner.Name .. " venció a " .. loser.Name)
    end
end

local function startDuelCountdown(duel)
    -- Propósito: Ejecutar countdown 3-2-1 y habilitar combate al finalizar.
    -- Precondiciones:
    --   1. duel debe estar activo y con dos jugadores válidos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if not duel then
        return
    end

    for seconds = COUNTDOWN_SECONDS, 1, -1 do
        if activeDuels[duel.playerA] ~= duel or activeDuels[duel.playerB] ~= duel then
            return
        end

        sendDuelState(duel.playerA, {
            type = "countdown",
            value = seconds,
            opponentName = duel.playerB.Name,
            selfHP = duel.hpByUserId[duel.playerA.UserId],
            enemyHP = duel.hpByUserId[duel.playerB.UserId],
        })

        sendDuelState(duel.playerB, {
            type = "countdown",
            value = seconds,
            opponentName = duel.playerA.Name,
            selfHP = duel.hpByUserId[duel.playerB.UserId],
            enemyHP = duel.hpByUserId[duel.playerA.UserId],
        })

        task.wait(1)
    end

    duel.started = true
    local stateA = playerStates[duel.playerA]
    local stateB = playerStates[duel.playerB]
    if stateA then
        stateA.duelStarted = true
    end
    if stateB then
        stateB.duelStarted = true
    end

    sendDuelState(duel.playerA, {
        type = "duel-started",
        opponentName = duel.playerB.Name,
        selfHP = duel.hpByUserId[duel.playerA.UserId],
        enemyHP = duel.hpByUserId[duel.playerB.UserId],
    })

    sendDuelState(duel.playerB, {
        type = "duel-started",
        opponentName = duel.playerA.Name,
        selfHP = duel.hpByUserId[duel.playerB.UserId],
        enemyHP = duel.hpByUserId[duel.playerA.UserId],
    })
end

local function isValidSwapPayload(payload)
    -- Propósito: Validar forma básica del payload enviado por cliente.
    -- Precondiciones:
    --   1. payload debe ser tabla.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: boolean
    if type(payload) ~= "table" then
        return false
    end

    if type(payload.path) ~= "table" or #payload.path < 2 then
        return false
    end

    for _, cell in ipairs(payload.path) do
        if type(cell) ~= "table" then
            return false
        end

        local values = { cell.col, cell.row }
        for _, value in ipairs(values) do
            if type(value) ~= "number" or value ~= math.floor(value) then
                return false
            end
        end

        if cell.col < 1 or cell.col > COLS or cell.row < 1 or cell.row > ROWS then
            return false
        end
    end

    return true
end

local function createStableGrid()
    -- Propósito: Crear un tablero inicial sin matches ya presentes.
    -- Precondiciones:
    --   1. CombatGrid.newGrid y CombatGrid.findMatches deben existir.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table
    local attempts = 0
    while attempts < 20 do
        attempts += 1
        local grid = CombatGrid.newGrid()
        local matches = CombatGrid.findMatches(grid)
        if not matches.hasMatches then
            return grid
        end
    end

    return CombatGrid.newGrid()
end

local function appendComboSummary(summary, combos, grid)
    -- Propósito: Acumular total de combos y elementos activados del movimiento.
    -- Precondiciones:
    --   1. summary debe ser tabla válida.
    --   2. combos debe ser tabla o nil.
    --   3. grid debe ser tablero válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(combos) ~= "table" then
        return
    end

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
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: table
    local list = {}
    for element, isActive in pairs(activatedElements) do
        if isActive then
            table.insert(list, element)
        end
    end
    table.sort(list)
    return list
end

local function syncPlayer(player, extraData)
    -- Propósito: Enviar el estado canónico actual del grid al cliente.
    -- Precondiciones:
    --   1. player debe tener estado activo.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    if not state then
        return
    end

    local payload = {
        grid = state.grid,
    }

    if type(extraData) == "table" then
        for key, value in pairs(extraData) do
            payload[key] = value
        end
    end

    CombatSync:FireClient(player, payload)
end

local function estimateCascadeAnimationDuration(cascades)
    -- Propósito: Estimar duración cliente de animación de cascadas para sincronizar daño.
    -- Precondiciones:
    --   1. cascades debe ser lista o nil.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: number
    if type(cascades) ~= "table" or #cascades == 0 then
        return 0
    end

    local totalTime = 0
    for _, cascade in ipairs(cascades) do
        local combos = type(cascade.combos) == "table" and cascade.combos or {}
        local comboCount = #combos
        totalTime += comboCount * (COMBO_SCALE_OUT_TIME + COMBO_STAGGER_TIME)

        local hasGravity = (type(cascade.movimientos) == "table" and #cascade.movimientos > 0)
            or (type(cascade.nuevas) == "table" and #cascade.nuevas > 0)
        if hasGravity then
            totalTime += FALL_TWEEN_TIME + BOUNCE_DURATION
        end

        totalTime += CASCADE_GAP_TIME
    end

    return totalTime
end

local function spawnPlayerPetCubes(player)
    -- Propósito: Spawnear cubos de equipo para el personaje actual del jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    local team = state and state.team or TeamManager.getOrCreateTeam(player)
    task.wait(0.1)
    PetCubeService.spawnPlayerTeamCubes(player, team)
end

local function bindCharacterSpawn(player)
    -- Propósito: Conectar spawn de cubos al respawn y al personaje actual.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end

    characterConnections[player] = player.CharacterAdded:Connect(function()
        spawnPlayerPetCubes(player)
    end)

    if player.Character then
        spawnPlayerPetCubes(player)
    end
end

local function initPlayerState(player)
    -- Propósito: Inicializar el tablero y metadatos del jugador.
    -- Precondiciones:
    --   1. player debe ser válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local team = TeamManager.getOrCreateTeam(player)
    local isTeamValid, teamReason = TeamManager.validateTeam(team)

    playerStates[player] = {
        grid = createStableGrid(),
        lastSubmit = 0,
        team = team,
        teamValid = isTeamValid,
        teamReason = teamReason,
        duelId = nil,
        duelActive = false,
        duelStarted = false,
    }

    PetCubeService.spawnPlayerTeamCubes(player, team)

    local teamHP = TeamManager.calculateTeamHP(team)

    dbg("estado inicial creado para " .. player.Name)
    syncPlayer(player, {
        reason = "initial-sync",
        teamValid = isTeamValid,
        teamReason = teamReason,
        playerTotalHP = teamHP,
        duelActive = false,
        duelStarted = false,
    })
end

local function cleanPlayerState(player)
    -- Propósito: Liberar estado del jugador al desconectarse.
    -- Precondiciones:
    --   1. player debe ser válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local opponent, duel = getDuelOpponent(player)
    if duel and opponent then
        endDuel(duel, opponent, "player-left")
    end

    pendingChallenges[player] = nil
    for targetPlayer, challengeData in pairs(pendingChallenges) do
        if challengeData and challengeData.challenger == player then
            pendingChallenges[targetPlayer] = nil
        end
    end

    TeamManager.clearTeam(player)
    PetCubeService.clearPlayerCubes(player)
    if characterConnections[player] then
        characterConnections[player]:Disconnect()
        characterConnections[player] = nil
    end
    playerStates[player] = nil
end

local function onCombatChallengeRequest(player, payload)
    -- Propósito: Procesar solicitud de desafío a jugador cercano.
    -- Precondiciones:
    --   1. payload.targetUserId debe ser number.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(payload) ~= "table" or type(payload.targetUserId) ~= "number" then
        return
    end

    local targetPlayer = Players:GetPlayerByUserId(payload.targetUserId)
    if not targetPlayer or targetPlayer == player then
        sendDuelState(player, { type = "challenge-failed", reason = "target-invalid" })
        return
    end

    if activeDuels[player] or activeDuels[targetPlayer] then
        sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
        return
    end

    local distance = getPlayersDistance(player, targetPlayer)
    if not distance or distance > CHALLENGE_DISTANCE then
        sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
        return
    end

    pendingChallenges[targetPlayer] = {
        challenger = player,
        createdAt = os.clock(),
    }

    sendDuelState(player, {
        type = "challenge-sent",
        targetName = targetPlayer.Name,
    })

    sendDuelState(targetPlayer, {
        type = "challenge-received",
        challengerName = player.Name,
        challengerUserId = player.UserId,
        timeout = CHALLENGE_TIMEOUT,
    })

    task.spawn(function()
        task.wait(CHALLENGE_TIMEOUT)
        local challengeData = pendingChallenges[targetPlayer]
        if challengeData and challengeData.challenger == player then
            pendingChallenges[targetPlayer] = nil
            sendDuelState(player, { type = "challenge-failed", reason = "challenge-timeout" })
            sendDuelState(targetPlayer, { type = "challenge-expired", challengerName = player.Name })
        end
    end)
end

local function onCombatChallengeResponse(player, payload)
    -- Propósito: Procesar aceptación o rechazo de un desafío recibido.
    -- Precondiciones:
    --   1. payload.accepted debe ser boolean.
    --   2. payload.challengerUserId debe ser number.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    if type(payload) ~= "table" then
        return
    end

    if type(payload.accepted) ~= "boolean" or type(payload.challengerUserId) ~= "number" then
        return
    end

    local challengeData = pendingChallenges[player]
    if not challengeData or not challengeData.challenger then
        return
    end

    local challenger = challengeData.challenger
    if challenger.UserId ~= payload.challengerUserId then
        return
    end

    pendingChallenges[player] = nil

    if not payload.accepted then
        sendDuelState(challenger, {
            type = "challenge-declined",
            targetName = player.Name,
        })
        sendDuelState(player, {
            type = "challenge-rejected-local",
            challengerName = challenger.Name,
        })
        return
    end

    if activeDuels[challenger] or activeDuels[player] then
        sendDuelState(challenger, { type = "challenge-failed", reason = "duel-busy" })
        sendDuelState(player, { type = "challenge-failed", reason = "duel-busy" })
        return
    end

    local distance = getPlayersDistance(challenger, player)
    if not distance or distance > CHALLENGE_DISTANCE then
        sendDuelState(challenger, { type = "challenge-failed", reason = "target-too-far" })
        sendDuelState(player, { type = "challenge-failed", reason = "target-too-far" })
        return
    end

    local challengerState = playerStates[challenger]
    local targetState = playerStates[player]
    if not challengerState or not targetState then
        return
    end

    local teamA = challengerState.team or TeamManager.getOrCreateTeam(challenger)
    local teamB = targetState.team or TeamManager.getOrCreateTeam(player)
    local validA = TeamManager.validateTeam(teamA)
    local validB = TeamManager.validateTeam(teamB)
    if not validA or not validB then
        sendDuelState(challenger, { type = "challenge-failed", reason = "team-invalid" })
        sendDuelState(player, { type = "challenge-failed", reason = "team-invalid" })
        return
    end

    duelSequence += 1
    local duelId = "duel-" .. tostring(duelSequence)
    local duel = {
        id = duelId,
        playerA = challenger,
        playerB = player,
        started = false,
        hpByUserId = {
            [challenger.UserId] = TeamManager.calculateTeamHP(teamA),
            [player.UserId] = TeamManager.calculateTeamHP(teamB),
        },
    }

    activeDuels[challenger] = duel
    activeDuels[player] = duel

    challengerState.duelId = duelId
    challengerState.duelActive = true
    challengerState.duelStarted = false
    targetState.duelId = duelId
    targetState.duelActive = true
    targetState.duelStarted = false

    task.spawn(function()
        startDuelCountdown(duel)
    end)
end

local function printGrid(grid)
    -- Imprime el estado del tablero en consola (por filas)
    for row = 1, ROWS do
        local rowStr = ""
        for col = 1, COLS do
            local tile = grid[col][row]
            if tile and tile.elementType then
                rowStr = rowStr .. string.sub(tile.elementType, 1, 1) .. " "
            else
                rowStr = rowStr .. ". "
            end
        end
        print("[CombatServer][GRID] " .. rowStr)
    end
end

local function printCombos(combos, label)
    if not combos or #combos == 0 then
        print("[CombatServer][COMBO] " .. (label or "") .. " (ninguna)")
        return
    end
    for i, combo in ipairs(combos) do
        local cells = {}
        for _, cell in ipairs(combo) do
            table.insert(cells, "("..cell.col..","..cell.row..")")
        end
        print("[CombatServer][COMBO] " .. (label or "") .. " #"..i..": " .. table.concat(cells, ", "))
    end
end

local function onCombatSubmit(player, payload)
    -- Propósito: Procesar una ruta de swaps enviada por el cliente.
    -- Precondiciones:
    --   1. player debe tener estado inicializado.
    --   2. payload.path debe describir swaps adyacentes consecutivos.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    local state = playerStates[player]
    if not state then
        warn("[CombatServer] Submit de jugador sin estado: " .. player.Name)
        return
    end

    local opponent, duel = getDuelOpponent(player)
    if not duel then
        syncPlayer(player, {
            rejected = true,
            reason = "duel-not-active",
            duelActive = false,
            duelStarted = false,
        })
        return
    end

    if not duel.started then
        syncPlayer(player, {
            rejected = true,
            reason = "duel-not-started",
            duelActive = true,
            duelStarted = false,
        })
        return
    end

    local team = state.team or TeamManager.getOrCreateTeam(player)
    local isTeamValid, teamReason = TeamManager.validateTeam(team)
    state.team = team
    state.teamValid = isTeamValid
    state.teamReason = teamReason

    if not isTeamValid then
        syncPlayer(player, {
            rejected = true,
            reason = "team-invalid",
            teamValid = false,
            teamReason = teamReason,
            playerTotalHP = TeamManager.calculateTeamHP(team),
        })
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
        warn("[CombatServer] Payload inválido de: " .. player.Name)
        syncPlayer(player, { rejected = true, reason = "invalid-payload" })
        return
    end

    local validation = CombatGrid.validateSwapPath(payload.path)
    if validation.errors and #validation.errors > 0 then
        dbg("validation notes: " .. table.concat(validation.errors, " | "))
    end

    if not validation.valid then
        syncPlayer(player, {
            rejected = true,
            reason = validation.errors[1] or "invalid-swap",
        })
        return
    end

    print("\n[CombatServer] ===== TURNO DE " .. player.Name .. " =====")
    print("[CombatServer] TABLERO ORIGINAL:")
    printGrid(state.grid)
    print("[CombatServer] SWAPS ejecutados:")
    for i, swap in ipairs(payload.path) do
        print("  Paso "..i..": ("..swap.col..","..swap.row..")")
    end

    local executedSwaps = CombatGrid.applySwapPath(state.grid, payload.path)
    local comboSummary = {
        totalCombos = 0,
        activatedElements = {},
    }

    -- Log de cascadas
    local resolution = { cascades = {}, totalEliminadas = 0, totalCascades = 0 }
    local safetyCounter = 0
    while safetyCounter < 20 do
        safetyCounter = safetyCounter + 1
        local matches = CombatGrid.findMatches(state.grid)
        if not matches.hasMatches then
            break
        end
        appendComboSummary(comboSummary, matches.combos, state.grid)
        print("[CombatServer] CASCADA "..safetyCounter.." - combinaciones:")
        printCombos(matches.combos, "CASCADA "..safetyCounter)
        local eliminadas = CombatGrid.aplicarCombos(state.grid, matches.combos)
        print("[CombatServer] Eliminadas: " .. #eliminadas)
        print("[CombatServer] TABLERO tras eliminar:")
        printGrid(state.grid)
        local gravityResult = CombatGrid.aplicarGravedad(state.grid)
        print("[CombatServer] TABLERO tras gravedad+relleno:")
        printGrid(state.grid)
        table.insert(resolution.cascades, {
            combos = matches.combos,
            eliminadas = eliminadas,
            movimientos = gravityResult.movimientos,
            nuevas = gravityResult.nuevas,
            totalCells = #eliminadas,
        })
        resolution.totalEliminadas = resolution.totalEliminadas + #eliminadas
    end
    resolution.totalCascades = #resolution.cascades
    local boardDamage = resolution.totalEliminadas * DAMAGE_PER_CELL

    local combatDamage = MonsterCombat.calculateTeamDamage(team, comboSummary)
    local playerTotalHP = TeamManager.calculateTeamHP(team)

    local enemyHP = opponent and (duel.hpByUserId[opponent.UserId] or 0) or nil
    local selfHP = duel and duel.hpByUserId[player.UserId] or playerTotalHP
    local animationDelay = estimateCascadeAnimationDuration(resolution.cascades)

    if opponent and combatDamage.totalDamage > 0 then
        task.delay(animationDelay, function()
            if activeDuels[player] ~= duel or activeDuels[opponent] ~= duel or not duel.started then
                return
            end

            local opponentCurrentHP = duel.hpByUserId[opponent.UserId] or 0
            local nextHP = math.max(0, math.floor(opponentCurrentHP - combatDamage.totalDamage))
            duel.hpByUserId[opponent.UserId] = nextHP

            sendDuelState(opponent, {
                type = "duel-update",
                opponentName = player.Name,
                selfHP = duel.hpByUserId[opponent.UserId],
                enemyHP = duel.hpByUserId[player.UserId],
                lastDamageReceived = combatDamage.totalDamage,
            })

            sendDuelState(player, {
                type = "duel-update",
                opponentName = opponent.Name,
                selfHP = duel.hpByUserId[player.UserId],
                enemyHP = duel.hpByUserId[opponent.UserId],
                lastDamageDealt = combatDamage.totalDamage,
            })

            if nextHP <= 0 then
                endDuel(duel, player, "hp-depleted")
            end
        end)
    end

    dbg(
        "turno "
        .. player.Name
        .. " | totalCombos="
        .. tostring(comboSummary.totalCombos)
        .. " | elementos="
        .. table.concat(getActivatedElementsList(comboSummary.activatedElements), ",")
        .. " | damageTotal="
        .. tostring(combatDamage.totalDamage)
    )

    print("[CombatServer] ===== FIN TURNO " .. player.Name .. " =====\n")

    syncPlayer(player, {
        path = payload.path,
        swaps = executedSwaps,
        cascades = resolution.cascades,
        totalCells = resolution.totalEliminadas,
        totalCascades = resolution.totalCascades,
        damage = combatDamage.totalDamage,
        boardDamage = boardDamage,
        comboSummary = {
            totalCombos = comboSummary.totalCombos,
            activatedElements = getActivatedElementsList(comboSummary.activatedElements),
        },
        combatResult = {
            totalDamage = combatDamage.totalDamage,
            damageByPet = combatDamage.damageByPet,
            playerTotalHP = playerTotalHP,
            enemyHP = enemyHP,
        },
        teamValid = true,
        teamReason = "ok",
        duelActive = state.duelActive,
        duelStarted = state.duelStarted,
        selfHP = selfHP,
        enemyHP = enemyHP,
        opponentName = opponent and opponent.Name or nil,
        reason = resolution.totalEliminadas > 0 and "path-resolved" or "path-no-matches",
    })
end

Players.PlayerAdded:Connect(function(player)
    initPlayerState(player)
    bindCharacterSpawn(player)
end)

Players.PlayerRemoving:Connect(function(player)
    cleanPlayerState(player)
end)

CombatSubmit.OnServerEvent:Connect(onCombatSubmit)
CombatChallengeRequest.OnServerEvent:Connect(onCombatChallengeRequest)
CombatChallengeResponse.OnServerEvent:Connect(onCombatChallengeResponse)

for _, player in ipairs(Players:GetPlayers()) do
    if not playerStates[player] then
        initPlayerState(player)
    end
    bindCharacterSpawn(player)
end
