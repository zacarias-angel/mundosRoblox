-- Tipo: ModuleScript
-- Ubicación: ReplicatedStorage/Modules/CombatGrid
-- Contexto: Compartido

--[[
    Motor puro de tablero match-3 con intercambio (swap) entre fichas adyacentes.
    No depende de UI ni de instancias Roblox, por lo que puede correrse en cliente
    y servidor para validación, preview y resolución.

    TABLERO: 6 columnas x 5 filas (col=X, row=Y, row 1=arriba, row 5=abajo)
    MATCH: grupos horizontales o verticales de 3 o más fichas del mismo tipo.
    FLUJO: swap valido -> escaneo completo -> eliminación -> gravedad -> relleno -> cascadas.
]]

local CombatGrid = {}

local COLS = 6
local ROWS = 5
local MIN_COMBO = 3

local ELEMENT_TYPES = {"Fuego", "Agua", "Planta", "Electricidad", "Roca"}

local function isValidCell(col, row)
    -- Propósito: Verificar si una coordenada pertenece al tablero.
    -- Precondiciones:
    --   1. col y row deben ser números.
    -- Ubicación: ReplicatedStorage/Modules/CombatGrid
    -- Retorna: boolean
    return col >= 1 and col <= COLS and row >= 1 and row <= ROWS
end

local function cellKey(col, row)
    -- Propósito: Construir una clave única por celda.
    -- Precondiciones:
    --   1. col y row deben ser enteros válidos.
    -- Ubicación: ReplicatedStorage/Modules/CombatGrid
    -- Retorna: string
    return col .. "," .. row
end

local function areAdjacent(col1, row1, col2, row2)
    -- Propósito: Validar adyacencia ortogonal entre dos celdas.
    -- Precondiciones:
    --   1. Las coordenadas deben ser válidas.
    -- Ubicación: ReplicatedStorage/Modules/CombatGrid
    -- Retorna: boolean
    local dc = math.abs(col2 - col1)
    local dr = math.abs(row2 - row1)
    return (dc == 1 and dr == 0) or (dc == 0 and dr == 1)
end

local function copyTile(tile)
    -- Propósito: Copiar una ficha de forma defensiva.
    -- Precondiciones:
    --   1. tile puede ser nil o una tabla con elementType.
    -- Ubicación: ReplicatedStorage/Modules/CombatGrid
    -- Retorna: table o nil
    if not tile then
        return nil
    end
    return { elementType = tile.elementType }
end

local function getRandomElementExcluding(excluded)
    -- Propósito: Elegir un tipo aleatorio evitando elementos prohibidos.
    -- Precondiciones:
    --   1. excluded debe ser un set opcional de tipos.
    -- Ubicación: ReplicatedStorage/Modules/CombatGrid
    -- Retorna: string
    local candidates = {}

    for _, elementType in ipairs(ELEMENT_TYPES) do
        if not excluded[elementType] then
            table.insert(candidates, elementType)
        end
    end

    if #candidates == 0 then
        return ELEMENT_TYPES[math.random(1, #ELEMENT_TYPES)]
    end

    return candidates[math.random(1, #candidates)]
end

local function collectUniqueCells(combos)
    -- Propósito: Deduplicar celdas que aparecen en múltiples matches cruzados.
    -- Precondiciones:
    --   1. combos debe ser una lista de listas de celdas.
    -- Ubicación: ReplicatedStorage/Modules/CombatGrid
    -- Retorna: table cells, number total
    local seen = {}
    local cells = {}

    for _, combo in ipairs(combos) do
        for _, cell in ipairs(combo) do
            local key = cellKey(cell.col, cell.row)
            if not seen[key] then
                seen[key] = true
                table.insert(cells, { col = cell.col, row = cell.row })
            end
        end
    end

    return cells, #cells
end

--[[
Función: newGrid

Propósito:
Crea un tablero nuevo sin matches iniciales visibles.

Precondiciones:
1. math.random debe estar disponible.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table grid[col][row] = { elementType = string }
]]
function CombatGrid.newGrid()
    local grid = {}

    for col = 1, COLS do
        grid[col] = {}
        for row = 1, ROWS do
            local excluded = {}

            if col >= 3 then
                local leftA = grid[col - 1][row]
                local leftB = grid[col - 2][row]
                if leftA and leftB and leftA.elementType == leftB.elementType then
                    excluded[leftA.elementType] = true
                end
            end

            if row >= 3 then
                local upA = grid[col][row - 1]
                local upB = grid[col][row - 2]
                if upA and upB and upA.elementType == upB.elementType then
                    excluded[upA.elementType] = true
                end
            end

            grid[col][row] = {
                elementType = getRandomElementExcluding(excluded),
            }
        end
    end

    return grid
end

--[[
Función: cloneGrid

Propósito:
Clonar completamente un tablero para hacer validaciones sin mutar el original.

Precondiciones:
1. grid debe ser un tablero válido.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table
]]
function CombatGrid.cloneGrid(grid)
    local copy = {}

    for col = 1, COLS do
        copy[col] = {}
        for row = 1, ROWS do
            copy[col][row] = copyTile(grid[col][row])
        end
    end

    return copy
end

--[[
Función: areAdjacent

Propósito:
Exponer la validación de adyacencia ortogonal para UI y servidor.

Precondiciones:
1. Las coordenadas deben ser números válidos.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: boolean
]]
function CombatGrid.areAdjacent(col1, row1, col2, row2)
    return areAdjacent(col1, row1, col2, row2)
end

--[[
Función: swapCells

Propósito:
Intercambiar dos fichas del tablero.

Precondiciones:
1. grid debe ser un tablero válido.
2. fromCell y toCell deben tener col y row válidos.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: nil
]]
function CombatGrid.swapCells(grid, fromCell, toCell)
    local temp = grid[fromCell.col][fromCell.row]
    grid[fromCell.col][fromCell.row] = grid[toCell.col][toCell.row]
    grid[toCell.col][toCell.row] = temp
end

--[[
Función: findMatches

Propósito:
Recorrer el tablero completo buscando matches horizontales y verticales de 3 o más.

Precondiciones:
1. grid debe ser un tablero válido.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con hasMatches, combos, matchedCells y totalCells.
]]
function CombatGrid.findMatches(grid)
    local result = {
        hasMatches = false,
        combos = {},
        matchedCells = {},
        totalCells = 0,
    }

    for row = 1, ROWS do
        local col = 1
        while col <= COLS do
            local tile = grid[col][row]
            if not tile then
                col += 1
            else
                local runType = tile.elementType
                local runStart = col
                local runLength = 1

                while (col + runLength) <= COLS do
                    local nextTile = grid[col + runLength][row]
                    if not nextTile or nextTile.elementType ~= runType then
                        break
                    end
                    runLength += 1
                end

                if runLength >= MIN_COMBO then
                    local combo = {}
                    for scanCol = runStart, runStart + runLength - 1 do
                        table.insert(combo, { col = scanCol, row = row })
                    end
                    table.insert(result.combos, combo)
                end

                col = runStart + runLength
            end
        end
    end

    for col = 1, COLS do
        local row = 1
        while row <= ROWS do
            local tile = grid[col][row]
            if not tile then
                row += 1
            else
                local runType = tile.elementType
                local runStart = row
                local runLength = 1

                while (row + runLength) <= ROWS do
                    local nextTile = grid[col][row + runLength]
                    if not nextTile or nextTile.elementType ~= runType then
                        break
                    end
                    runLength += 1
                end

                if runLength >= MIN_COMBO then
                    local combo = {}
                    for scanRow = runStart, runStart + runLength - 1 do
                        table.insert(combo, { col = col, row = scanRow })
                    end
                    table.insert(result.combos, combo)
                end

                row = runStart + runLength
            end
        end
    end

    result.matchedCells, result.totalCells = collectUniqueCells(result.combos)
    result.hasMatches = result.totalCells > 0
    return result
end

--[[
Función: validateSwap

Propósito:
Validar un intercambio entre dos celdas adyacentes y confirmar si produce matches.

Precondiciones:
1. grid debe ser un tablero válido.
2. fromCell y toCell deben contener col y row.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con valid, errors y previewMatches.
]]
function CombatGrid.validateSwap(grid, fromCell, toCell)
    local result = {
        valid = false,
        errors = {},
        previewMatches = nil,
    }

    if type(fromCell) ~= "table" or type(toCell) ~= "table" then
        table.insert(result.errors, "payload de swap inválido")
        return result
    end

    if not isValidCell(fromCell.col, fromCell.row) or not isValidCell(toCell.col, toCell.row) then
        table.insert(result.errors, "swap fuera del tablero")
        return result
    end

    if fromCell.col == toCell.col and fromCell.row == toCell.row then
        table.insert(result.errors, "swap sobre la misma celda")
        return result
    end

    if not areAdjacent(fromCell.col, fromCell.row, toCell.col, toCell.row) then
        table.insert(result.errors, "swap no adyacente")
        return result
    end

    local previewGrid = CombatGrid.cloneGrid(grid)
    CombatGrid.swapCells(previewGrid, fromCell, toCell)
    local previewMatches = CombatGrid.findMatches(previewGrid)
    result.previewMatches = previewMatches

    if not previewMatches.hasMatches then
        table.insert(result.errors, "swap sin matches")
        return result
    end

    result.valid = true
    return result
end

--[[
Función: validateSwapPath

Propósito:
Validar una ruta completa de swaps adyacentes realizada durante un drag.

Precondiciones:
1. path debe ser una lista de celdas con al menos 2 entradas.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con valid y errors.
]]
function CombatGrid.validateSwapPath(path)
    local result = {
        valid = false,
        errors = {},
    }

    if type(path) ~= "table" or #path < 2 then
        table.insert(result.errors, "ruta de swap inválida")
        return result
    end

    for index, cell in ipairs(path) do
        if type(cell) ~= "table" or type(cell.col) ~= "number" or type(cell.row) ~= "number" then
            table.insert(result.errors, "celda inválida en índice " .. tostring(index))
            return result
        end

        if not isValidCell(cell.col, cell.row) then
            table.insert(result.errors, "celda fuera del tablero en índice " .. tostring(index))
            return result
        end

        if index > 1 then
            local previous = path[index - 1]
            if not areAdjacent(previous.col, previous.row, cell.col, cell.row) then
                table.insert(result.errors, "salto no adyacente en índice " .. tostring(index))
                return result
            end
        end
    end

    result.valid = true
    return result
end

--[[
Función: applySwapPath

Propósito:
Aplicar secuencialmente todos los swaps adyacentes definidos por una ruta.

Precondiciones:
1. grid debe ser un tablero válido.
2. path debe haber sido validada previamente.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con swaps ejecutados.
]]
function CombatGrid.applySwapPath(grid, path)
    local swaps = {}

    for index = 1, #path - 1 do
        local fromCell = path[index]
        local toCell = path[index + 1]
        CombatGrid.swapCells(grid, fromCell, toCell)
        table.insert(swaps, {
            from = { col = fromCell.col, row = fromCell.row },
            to = { col = toCell.col, row = toCell.row },
        })
    end

    return swaps
end

--[[
Función: aplicarCombos

Propósito:
Eliminar del tablero todas las celdas pertenecientes a los matches detectados.

Precondiciones:
1. grid debe ser un tablero válido.
2. combos debe ser una lista de matches.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con celdas eliminadas.
]]
function CombatGrid.aplicarCombos(grid, combos)
    local eliminadas = {}
    local seen = {}

    for _, combo in ipairs(combos) do
        for _, cell in ipairs(combo) do
            local key = cellKey(cell.col, cell.row)
            if not seen[key] then
                seen[key] = true
                table.insert(eliminadas, { col = cell.col, row = cell.row })
                grid[cell.col][cell.row] = nil
            end
        end
    end

    return eliminadas
end

--[[
Función: aplicarGravedad

Propósito:
Compactar fichas hacia abajo y rellenar huecos superiores con nuevas fichas aleatorias.

Precondiciones:
1. grid debe ser un tablero válido.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con movimientos y nuevas fichas.
]]
function CombatGrid.aplicarGravedad(grid)
    local movimientos = {}
    local nuevas = {}

    for col = 1, COLS do
        local stack = {}

        for row = 1, ROWS do
            if grid[col][row] then
                table.insert(stack, {
                    elementType = grid[col][row].elementType,
                    originalRow = row,
                })
            end
        end

        for row = 1, ROWS do
            grid[col][row] = nil
        end

        local targetRow = ROWS
        for index = #stack, 1, -1 do
            local tile = stack[index]
            grid[col][targetRow] = { elementType = tile.elementType }
            if tile.originalRow ~= targetRow then
                table.insert(movimientos, {
                    fromCol = col,
                    fromRow = tile.originalRow,
                    toCol = col,
                    toRow = targetRow,
                })
            end
            targetRow -= 1
        end

        for row = 1, targetRow do
            local elementType = ELEMENT_TYPES[math.random(1, #ELEMENT_TYPES)]
            grid[col][row] = { elementType = elementType }
            table.insert(nuevas, {
                col = col,
                row = row,
                elementType = elementType,
            })
        end
    end

    return {
        movimientos = movimientos,
        nuevas = nuevas,
    }
end

--[[
Función: resolveBoard

Propósito:
Resolver todas las cascadas del tablero hasta dejarlo estable.

Precondiciones:
1. grid debe ser un tablero válido.

Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table con cascades, totalEliminadas y totalCascades.
]]
function CombatGrid.resolveBoard(grid)
    local result = {
        cascades = {},
        totalEliminadas = 0,
        totalCascades = 0,
    }

    local safetyCounter = 0
    while safetyCounter < 20 do
        safetyCounter += 1

        local matches = CombatGrid.findMatches(grid)
        if not matches.hasMatches then
            break
        end

        local eliminadas = CombatGrid.aplicarCombos(grid, matches.combos)
        local gravityResult = CombatGrid.aplicarGravedad(grid)

        table.insert(result.cascades, {
            combos = matches.combos,
            eliminadas = eliminadas,
            movimientos = gravityResult.movimientos,
            nuevas = gravityResult.nuevas,
            totalCells = #eliminadas,
        })

        result.totalEliminadas += #eliminadas
    end

    result.totalCascades = #result.cascades
    return result
end

--[[
Función: getElementTypes

Propósito:
Devolver la lista de tipos de ficha disponibles.

Precondiciones: Ninguna.
Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: table
]]
function CombatGrid.getElementTypes()
    local copy = {}
    for _, elementType in ipairs(ELEMENT_TYPES) do
        table.insert(copy, elementType)
    end
    return copy
end

--[[
Función: getSize

Propósito:
Devolver dimensiones del tablero.

Precondiciones: Ninguna.
Ubicación: ReplicatedStorage/Modules/CombatGrid
Retorna: number cols, number rows
]]
function CombatGrid.getSize()
    return COLS, ROWS
end

return CombatGrid
