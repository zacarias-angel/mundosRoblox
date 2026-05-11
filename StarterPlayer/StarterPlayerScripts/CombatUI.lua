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

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatGrid = require(Modules:WaitForChild("CombatGrid.module"))

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local CombatSubmit = RemoteEvents:WaitForChild("CombatSubmit")
local CombatSync = RemoteEvents:WaitForChild("CombatSync")

local COLS, ROWS = CombatGrid.getSize()
local CELL_SIZE = 64
local CELL_PADDING = 4
local TURN_TIME = 5
local DRAG_THRESHOLD = 20
local SWAP_COOLDOWN = 0.07
local COMBAT_DEBUG = true

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

local gridFrame = Instance.new("Frame")
gridFrame.Name = "GridFrame"
gridFrame.Position = UDim2.new(0, 4, 0, 18)
gridFrame.Size = UDim2.new(0, COLS * stepCellSize, 0, ROWS * stepCellSize)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = container

local cellButtons = {}
local ghostFrame = nil  -- Pieza flotante que sigue al cursor durante drag

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
    ghostFrame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
    ghostFrame.Visible = true
end

local function hideGhost()
    ghostFrame.Visible = false
end

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

local function getCellFromMouse(mousePos)
    -- Propósito: Obtener celda por cálculo matemático dentro del GridFrame.
    -- Precondiciones:
    --   1. mousePos debe tener X e Y.
    -- Ubicación: StarterPlayer/StarterPlayerScripts/CombatUI
    -- Retorna: number|nil col, number|nil row
    local gridPos = gridFrame.AbsolutePosition
    local gridSize = gridFrame.AbsoluteSize

    local localX = mousePos.X - gridPos.X
    local localY = mousePos.Y - gridPos.Y

    if localX < 0 or localY < 0 or localX > gridSize.X or localY > gridSize.Y then
        return nil, nil
    end

    local step = CELL_SIZE + CELL_PADDING
    local col = math.floor(localX / step) + 1
    local row = math.floor(localY / step) + 1

    if col < 1 or col > COLS or row < 1 or row > ROWS then
        return nil, nil
    end

    return col, row
end

local getDragDirection

function getDragDirection(delta)
    if math.abs(delta.X) > math.abs(delta.Y) then
        if delta.X > 0 then
            return 1, 0 -- derecha
        else
            return -1, 0 -- izquierda
        end
    else
        if delta.Y > 0 then
            return 0, 1 -- abajo
        else
            return 0, -1 -- arriba
        end
    end
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
        setReject(cellKey(row, col), "swap no adyacente")
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

        local now = os.clock()
        if now - lastSwapTime < SWAP_COOLDOWN then
            return
        end

        if not dragStartPos then
            dragStartPos = mousePos
            return
        end

        local delta = mousePos - dragStartPos
        if delta.Magnitude < DRAG_THRESHOLD then
            return
        end

        local dx, dy = getDragDirection(delta)
        local targetCol = dragCurrentCell.col + dx
        local targetRow = dragCurrentCell.row + dy

        local hoverCol, hoverRow = getCellFromMouse(mousePos)
        if hoverCol ~= targetCol or hoverRow ~= targetRow then
            return
        end

        local targetKey = cellKey(targetCol, targetRow)
        if targetKey == lastHoverKey then
            return
        end
        lastHoverKey = targetKey

        dbg("objetivo drag fila " .. targetRow .. " col " .. targetCol)
        local didSwap = setDragTarget(targetCol, targetRow)
        if didSwap then
            lastSwapTime = now
            dragStartPos = mousePos
        end
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

    UserInputService.TouchMoved:Connect(function(touch, _gameProcessed)
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

        local dx, dy = getDragDirection(delta)
        local col = dragCurrentCell.col + dx
        local row = dragCurrentCell.row + dy

        local hoverCol, hoverRow = getCellFromMouse(touch.Position)
        if hoverCol ~= col or hoverRow ~= row then
            return
        end

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

    UserInputService.TouchEnded:Connect(function(_touch, _gameProcessed)
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

    localGrid = data.grid
    dbg("CombatSync recibido" .. (data.reason and (" | " .. tostring(data.reason)) or ""))
    clearDragState()
    rerender()
end

CombatSync.OnClientEvent:Connect(onCombatSync)
