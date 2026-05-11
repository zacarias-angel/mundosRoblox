local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local boardContainer = script.Parent
local draggingCell = nil
local player = Players.LocalPlayer
local progressBar = boardContainer.Parent:FindFirstChild("ProgressBar")
local progressFill = progressBar:FindFirstChild("Fill")

local TIMER_DURATION = 5
local timerTween = nil
local isTimeUp = false
local boardSnapshot = {} -- 📌 Almacenará el estado inicial del tablero

-- Guardar el estado actual del tablero
local function saveBoardState()
	boardSnapshot = {} -- Reiniciamos la variable
	for _, cell in ipairs(boardContainer:GetChildren()) do
		if cell:IsA("ImageButton") then
			local x, y = cell.Name:match("Cell_(%d+)_(%d+)")
			x, y = tonumber(x), tonumber(y)
			if x and y then
				boardSnapshot[cell.Name] = {
					PetType = cell:GetAttribute("PetType"),
					Color = cell.BackgroundColor3
				}
			end
		end
	end
end

-- Restaurar el estado del tablero cuando el tiempo se agote
local function restoreBoardState()
	for _, cell in ipairs(boardContainer:GetChildren()) do
		if cell:IsA("ImageButton") and boardSnapshot[cell.Name] then
			cell:SetAttribute("PetType", boardSnapshot[cell.Name].PetType)
			cell.BackgroundColor3 = boardSnapshot[cell.Name].Color
		end
	end
end

-- Ocultar el cursor cuando el tiempo se agote
local function disableCursor()
	UserInputService.MouseIconEnabled = false
end

-- Mostrar el cursor de nuevo
local function enableCursor()
	UserInputService.MouseIconEnabled = true
end

-- Inicia la barra de progreso
local function startProgressBar()
	if progressBar and progressFill then
		progressFill.Size = UDim2.new(1, 0, 1, 0)
		timerTween = TweenService:Create(progressFill, TweenInfo.new(TIMER_DURATION), {
			Size = UDim2.new(0, 0, 1, 0)
		})
		timerTween:Play()
	end
end

-- Detener la barra de progreso
local function stopProgressBar()
	if timerTween then
		timerTween:Cancel()
		timerTween = nil
	end
	if progressFill then
		progressFill.Size = UDim2.new(1, 0, 1, 0)
	end
end

-- Función para revertir el movimiento si se acaba el tiempo
local function revertMoves()
	if draggingCell then
		print("⏳ Tiempo agotado, revirtiendo movimiento.")
		isTimeUp = true
		disableCursor() -- ❌ Desactivar cursor
		restoreBoardState() -- ⏪ Restaurar el tablero
		task.wait(0.5) -- Pequeña pausa visual
		stopProgressBar()
		enableCursor() -- ✅ Reactivar cursor
		isTimeUp = false
		draggingCell = nil
	end
end

-- Inicia el arrastre
local function startDragging(cell)
	if isTimeUp then return end

	saveBoardState() -- 🔹 Guardamos el estado inicial del tablero
	draggingCell = cell
	cell.ZIndex = 10
	startProgressBar()
	print("Drag iniciado en: ", cell.Name)

	-- Temporizador para cancelar el movimiento si el jugador no suelta a tiempo
	coroutine.wrap(function()
		task.wait(TIMER_DURATION)
		if draggingCell then
			revertMoves()
		end
	end)()

	-- Hover para intercambio
	for _, targetCell in ipairs(boardContainer:GetChildren()) do
		if targetCell:IsA("ImageButton") and targetCell ~= draggingCell then
			targetCell.MouseEnter:Connect(function()
				if draggingCell and not isTimeUp then
					-- Intercambio visual y lógico
					local tempColor = targetCell.BackgroundColor3
					targetCell.BackgroundColor3 = draggingCell.BackgroundColor3
					draggingCell.BackgroundColor3 = tempColor

					local tempPetType = targetCell:GetAttribute("PetType")
					targetCell:SetAttribute("PetType", draggingCell:GetAttribute("PetType"))
					draggingCell:SetAttribute("PetType", tempPetType)

					print("Intercambio realizado entre: ", draggingCell.Name, " y ", targetCell.Name)
					draggingCell = targetCell
				end
			end)
		end
	end
end

-- Finaliza el arrastre
local function stopDragging()
	if draggingCell and not isTimeUp then
		draggingCell.ZIndex = 1
		draggingCell = nil

		local BoardLogic = require(game.ReplicatedStorage.BoardLogic)
		local boardLogicInstance = BoardLogic.new(5)

		local function processCombinations()
			while true do
				local matches = boardLogicInstance:detectCombinations(boardContainer)

				if matches and #matches > 0 then
					print("Combinaciones detectadas:", #matches)
					boardLogicInstance:removeCombinations(matches, boardContainer)
					boardLogicInstance:applyGravity(boardContainer)
					boardLogicInstance:refillBoard(boardContainer)

					task.wait(0.5)
				else
					print("No se detectaron combinaciones.")
					break
				end
			end
		end

		processCombinations()
		stopProgressBar()
	end
end

-- Configurar eventos para las celdas
for _, cell in ipairs(boardContainer:GetChildren()) do
	if cell:IsA("ImageButton") then
		cell.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				startDragging(cell)
			end
		end)

		cell.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				stopDragging()
			end
		end)
	end
end
