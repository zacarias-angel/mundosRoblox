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

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatGrid = require(Modules:WaitForChild("CombatGrid.module"))

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatSubmit = RemoteEvents:WaitForChild("CombatSubmit")
local CombatSync = RemoteEvents:WaitForChild("CombatSync")

local COLS, ROWS = CombatGrid.getSize()
local DAMAGE_PER_CELL = 10
local COMBAT_DEBUG = true

local playerStates = {}

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

local function initPlayerState(player)
    -- Propósito: Inicializar el tablero y metadatos del jugador.
    -- Precondiciones:
    --   1. player debe ser válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    playerStates[player] = {
        grid = createStableGrid(),
        lastSubmit = 0,
    }

    dbg("estado inicial creado para " .. player.Name)
    syncPlayer(player, { reason = "initial-sync" })
end

local function cleanPlayerState(player)
    -- Propósito: Liberar estado del jugador al desconectarse.
    -- Precondiciones:
    --   1. player debe ser válido.
    -- Ubicación: ServerScriptService/CombatServer
    -- Retorna: nil
    playerStates[player] = nil
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

    -- Log de cascadas
    local gridSnapshot = CombatGrid.cloneGrid(state.grid)
    local resolution = { cascades = {}, totalEliminadas = 0, totalCascades = 0 }
    local safetyCounter = 0
    while safetyCounter < 20 do
        safetyCounter = safetyCounter + 1
        local matches = CombatGrid.findMatches(state.grid)
        if not matches.hasMatches then
            break
        end
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
    local damage = resolution.totalEliminadas * DAMAGE_PER_CELL

    print("[CombatServer] ===== FIN TURNO " .. player.Name .. " =====\n")

    syncPlayer(player, {
        path = payload.path,
        swaps = executedSwaps,
        cascades = resolution.cascades,
        totalCells = resolution.totalEliminadas,
        totalCascades = resolution.totalCascades,
        damage = damage,
        reason = resolution.totalEliminadas > 0 and "path-resolved" or "path-no-matches",
    })
end

Players.PlayerAdded:Connect(function(player)
    initPlayerState(player)
end)

Players.PlayerRemoving:Connect(function(player)
    cleanPlayerState(player)
end)

CombatSubmit.OnServerEvent:Connect(onCombatSubmit)

for _, player in ipairs(Players:GetPlayers()) do
    if not playerStates[player] then
        initPlayerState(player)
    end
end
