-- estp estaba en el replicate storeage es de otro juego pero hace o mismo que queremos hacer en el nuestro, es la logica del tablero, detecta las combinaciones, las elimina, hace que las piezas caigan y rellena el tablero

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedData = require(ReplicatedStorage:WaitForChild("SharedData"))
local BoardLogic = {}
BoardLogic.__index = BoardLogic -- Asegura que las funciones se hereden correctamente

-- Inicializar el tablero
function BoardLogic.new(boardSize)
	local self = setmetatable({}, BoardLogic)
	self.boardSize = boardSize
	self.boardData = {} -- Inicializar la tabla de datos del tablero

	-- Inicializar boardData con una cuadrícula vacía
	for x = 1, self.boardSize do
		self.boardData[x] = {}
		for y = 1, self.boardSize do
			self.boardData[x][y] = nil -- Inicializar como vacío
		end
	end

	return self
end


function BoardLogic:removeCombinations(matches, boardContainer)
	for _, cell in ipairs(matches) do
		if cell then
			cell:SetAttribute("PetType", nil) -- Vaciar la celda
			cell.BackgroundColor3 = Color3.new(1, 1, 1) -- Restaurar color predeterminado (blanco)
			print("Celda eliminada: ", cell.Name)
		end
	end
end

-- Hace que las celdas caigan y retorna las posiciones que necesitan ser rellenadas
function BoardLogic:applyGravity(boardContainer)
	for x = 1, self.boardSize do
		for y = self.boardSize, 2, -1 do -- Recorrer de abajo hacia arriba
			local cell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. y)
			local aboveCell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. (y - 1))

			if cell and aboveCell and cell:GetAttribute("PetType") == nil then
				-- Mover la pieza desde la celda superior
				cell:SetAttribute("PetType", aboveCell:GetAttribute("PetType"))
				cell.BackgroundColor3 = aboveCell.BackgroundColor3
				aboveCell:SetAttribute("PetType", nil)
				aboveCell.BackgroundColor3 = Color3.new(1, 1, 1) -- Restaurar color predeterminado
			end
		end
	end
end

-- Método principal para manejar eliminaciones y relleno hasta que no queden combinaciones


function BoardLogic:refillBoard(boardContainer)
	for x = 1, self.boardSize do
		for y = self.boardSize, 1, -1 do -- Comenzar desde abajo hacia arriba
			local cell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. y)
			if cell and cell:GetAttribute("PetType") == nil then
				-- Buscar una celda en la misma columna más arriba para "bajarla"
				for aboveY = y - 1, 1, -1 do
					local aboveCell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. aboveY)
					if aboveCell and aboveCell:GetAttribute("PetType") ~= nil then
						-- Transferir el contenido de la celda superior
						cell:SetAttribute("PetType", aboveCell:GetAttribute("PetType"))
						cell.BackgroundColor3 = aboveCell.BackgroundColor3
						aboveCell:SetAttribute("PetType", nil)
						aboveCell.BackgroundColor3 = Color3.new(1, 1, 1) -- Resetear color (opcional)
						break
					end
				end

				-- Si no hay celdas por encima, generar una nueva
				if cell:GetAttribute("PetType") == nil then
					local randomColor = SharedData.availableColors[math.random(1, #SharedData.availableColors)]
					cell:SetAttribute("PetType", randomColor)
					cell.BackgroundColor3 = randomColor
					print("Celda rellenada:", cell.Name)
				end
			end
		end
	end
end


function BoardLogic:detectCombinations(boardContainer)
	local matches = {}

	-- Verificar filas
	for x = 1, self.boardSize do
		for y = 1, self.boardSize - 2 do
			local cell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. y)
			local nextCell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. (y + 1))
			local nextNextCell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. (y + 2))

			if cell and nextCell and nextNextCell and
				cell:GetAttribute("PetType") == nextCell:GetAttribute("PetType") and
				cell:GetAttribute("PetType") == nextNextCell:GetAttribute("PetType") then
				table.insert(matches, cell)
				table.insert(matches, nextCell)
				table.insert(matches, nextNextCell)
			end
		end
	end

	-- Verificar columnas
	for y = 1, self.boardSize do
		for x = 1, self.boardSize - 2 do
			local cell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. y)
			local nextCell = boardContainer:FindFirstChild("Cell_" .. (x + 1) .. "_" .. y)
			local nextNextCell = boardContainer:FindFirstChild("Cell_" .. (x + 2) .. "_" .. y)

			if cell and nextCell and nextNextCell and
				cell:GetAttribute("PetType") == nextCell:GetAttribute("PetType") and
				cell:GetAttribute("PetType") == nextNextCell:GetAttribute("PetType") then
				table.insert(matches, cell)
				table.insert(matches, nextCell)
				table.insert(matches, nextNextCell)
			end
		end
	end

	print("Combinaciones encontradas: ", #matches)
	return matches or {} -- Siempre retorna una tabla
end


-- Obtener el valor en una celda específica
function BoardLogic:getCell(x, y)
	local value = self.boardData[x] and self.boardData[x][y] or nil
	print("Valor de la celda (" .. x .. ", " .. y .. "): ", value)
	return value
end

-- Establecer el valor en una celda específica
function BoardLogic:setCell(x, y, petType)
	if self.boardData[x] and self.boardData[x][y] ~= nil then
		self.boardData[x][y] = petType
	end
end


-- Mostrar el estado del tablero (para debugging)
function BoardLogic:printBoard()
	for x = 1, self.boardSize do
		local row = {}
		for y = 1, self.boardSize do
			table.insert(row, self.boardData[x][y] or "Empty")
		end
		print(table.concat(row, " | "))
	end
end



return BoardLogic