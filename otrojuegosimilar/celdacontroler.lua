
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedData = require(ReplicatedStorage:WaitForChild("SharedData"))

-- Configuración del tablero
local boardSize = 5 -- Tamaño del tablero (puedes ajustarlo)
local boardContainer = script.Parent -- Contenedor del tablero en la GUI
local availableColors = SharedData.availableColors
local cellTemplate = SharedData.cellTemplate


-- Verificar si hay combinaciones iniciales
local function hasInitialCombination(boardContainer)
	for x = 1, boardSize do
		for y = 1, boardSize do
			local cell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. y)
			if cell then
				-- Verificar filas
				local rightCell = boardContainer:FindFirstChild("Cell_" .. (x + 1) .. "_" .. y)
				local rightRightCell = boardContainer:FindFirstChild("Cell_" .. (x + 2) .. "_" .. y)

				if rightCell and rightRightCell and
					cell:GetAttribute("PetType") == rightCell:GetAttribute("PetType") and
					cell:GetAttribute("PetType") == rightRightCell:GetAttribute("PetType") then
					return true
				end

				-- Verificar columnas
				local downCell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. (y + 1))
				local downDownCell = boardContainer:FindFirstChild("Cell_" .. x .. "_" .. (y + 2))

				if downCell and downDownCell and
					cell:GetAttribute("PetType") == downCell:GetAttribute("PetType") and
					cell:GetAttribute("PetType") == downDownCell:GetAttribute("PetType") then
					return true
				end
			end
		end
	end
	return false
end

local function createBoard()
	repeat
		-- Limpiar tablero actual
		for _, child in ipairs(boardContainer:GetChildren()) do
			if child:IsA("ImageButton") then
				child:Destroy()
			end
		end

		-- Generar nuevo tablero
		for x = 1, boardSize do
			for y = 1, boardSize do
				-- Crear plantilla de celda
				local cell = SharedData.createCellTemplate()
				cell.Parent = boardContainer
				cell:SetAttribute("PosX", x)
				cell:SetAttribute("PosY", y)

				-- Asignar un color aleatorio
				local randomColor = SharedData.availableColors[math.random(1, #SharedData.availableColors)]
				cell.BackgroundColor3 = randomColor
				cell:SetAttribute("PetType", randomColor)
				cell.Name = "Cell_" .. x .. "_" .. y
			end
		end
	until not hasInitialCombination(boardContainer)
end

-- Crear el tablero
createBoard()
