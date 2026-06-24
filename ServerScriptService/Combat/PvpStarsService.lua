-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/PvpStarsService
-- Contexto: Servidor

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PvpStarsService = {}

local DATASTORE_NAME = "PvpStarsV1"
local DATASTORE_KEY_PREFIX = "player_"
local LEADERSTATS_FOLDER_NAME = "leaderstats"
local STARS_VALUE_NAME = "PvpStars"
local STARS_ATTRIBUTE_NAME = "PvpStars"
local COUNTER_PART_NAME = "PvpShoulderCounterPart"
local COUNTER_FACE_GUI_PREFIX = "PvpShoulderCounterGui"
local COUNTER_LABEL_PREFIX = "CounterLabel"
local DEFAULT_STARS = 0
local WIN_STARS_DELTA = 1
local LOSS_STARS_DELTA = -1
local MIN_STARS = 0
local MAX_STARS = 999999
local COUNTER_PART_SIZE = Vector3.new(1.5, 0.55, 0.05)
local COUNTER_HEIGHT_OFFSET = 1.1
local COUNTER_ROTATION_DEGREES = -10
local MAX_SHIELD_CHARGES = 3
local DAILY_SHIELD_GRANT = 1
local WEEKLY_SHIELD_GRANT = 1
local SHIELD_CHARGES_ATTRIBUTE_NAME = "ShieldCharges"
local LAST_DAILY_GRANT_ATTRIBUTE = "ShieldLastDailyGrant"
local LAST_WEEKLY_GRANT_ATTRIBUTE = "ShieldLastWeeklyGrant"
local SECONDS_PER_DAY = 86400
local SECONDS_PER_WEEK = 604800

local PVP_TITLES = {
    { minStars = 0, title = "Rookie" },
    { minStars = 10, title = "Hunter" },
    { minStars = 25, title = "Tamer" },
    { minStars = 50, title = "Elite" },
    { minStars = 100, title = "Master" },
    { minStars = 200, title = "Legend" },
    { minStars = 500, title = "Bitlord" },
}

local starsDataStore = nil
local playerConnections = {}

if not RunService:IsStudio() then
    local ok, store = pcall(function()
        return DataStoreService:GetDataStore(DATASTORE_NAME)
    end)
    if ok then
        starsDataStore = store
    else
        warn("[PvpStarsService] No se pudo obtener DataStore: " .. tostring(store))
    end
end

local function clampStars(value)
    -- Propósito: Limitar el valor de estrellas al rango permitido.
    -- Precondiciones:
    --   1. value debe ser number.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: number
    local numeric = tonumber(value) or DEFAULT_STARS
    local rounded = math.floor(numeric)
    return math.clamp(rounded, MIN_STARS, MAX_STARS)
end

local function formatCounterText(stars)
    -- Propósito: Construir el texto final del contador mostrado en pantalla.
    -- Precondiciones:
    --   1. stars debe ser number.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: string
    return "⭐ N° " .. tostring(clampStars(stars))
end

local function getOrCreateLeaderstatsFolder(player)
    -- Propósito: Crear la carpeta leaderstats si aún no existe para el jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: Folder
    local folder = player:FindFirstChild(LEADERSTATS_FOLDER_NAME)
    if folder and folder:IsA("Folder") then
        return folder
    end

    folder = Instance.new("Folder")
    folder.Name = LEADERSTATS_FOLDER_NAME
    folder.Parent = player
    return folder
end

local function getOrCreateStarsValue(player)
    -- Propósito: Obtener o crear el IntValue de estrellas PvP del jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: IntValue
    local leaderstats = getOrCreateLeaderstatsFolder(player)
    local value = leaderstats:FindFirstChild(STARS_VALUE_NAME)
    if value and value:IsA("IntValue") then
        return value
    end

    value = Instance.new("IntValue")
    value.Name = STARS_VALUE_NAME
    value.Value = DEFAULT_STARS
    value.Parent = leaderstats
    return value
end

local function resolveShoulderPart(character)
    -- Propósito: Encontrar la parte más adecuada para anclar el contador del hombro.
    -- Precondiciones:
    --   1. character debe ser modelo del jugador.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: BasePart|nil
    local preferredPartNames = {
        "RightUpperArm",
        "Right Arm",
        "UpperTorso",
        "Torso",
        "Head",
    }

    for _, partName in ipairs(preferredPartNames) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end

local function resolveCounterAnchorPart(character)
    -- Propósito: Obtener la parte estable del personaje usada para seguir la posición del contador.
    -- Precondiciones:
    --   1. character debe ser modelo del jugador.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: BasePart|nil
    local preferredPartNames = {
        "HumanoidRootPart",
        "UpperTorso",
        "Torso",
    }

    for _, partName in ipairs(preferredPartNames) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end

local function getShoulderOffset(shoulderPart)
    -- Propósito: Calcular el offset local del contador según el tipo de rig detectado.
    -- Precondiciones:
    --   1. shoulderPart debe ser BasePart válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: Vector3
    if not shoulderPart then
        return Vector3.new(0.7, 0.8 + COUNTER_HEIGHT_OFFSET, 0)
    end

    if shoulderPart.Name == "RightUpperArm" then
        return Vector3.new(0.75, 0.55 + COUNTER_HEIGHT_OFFSET, 0)
    end

    if shoulderPart.Name == "Right Arm" then
        return Vector3.new(0.85, 0.9 + COUNTER_HEIGHT_OFFSET, 0)
    end

    return Vector3.new(0.95, 1.05 + COUNTER_HEIGHT_OFFSET, 0)
end

local function getCounterLocalCFrame(shoulderPart)
    -- Propósito: Construir el CFrame local completo del contador con offset y rotación fija.
    -- Precondiciones:
    --   1. shoulderPart puede ser BasePart válida o nil.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: CFrame
    return CFrame.new(getShoulderOffset(shoulderPart)) * CFrame.Angles(0, 0, math.rad(COUNTER_ROTATION_DEGREES))
end

local function getOrCreateCounterPart(character, shoulderPart)
    -- Propósito: Crear una pieza invisible fija sobre el hombro para alojar el texto y futuros VFX.
    -- Precondiciones:
    --   1. character debe ser modelo válido.
    --   2. shoulderPart debe ser BasePart válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: Part
    local counterPart = character:FindFirstChild(COUNTER_PART_NAME)
    if counterPart and counterPart:IsA("BasePart") then
        return counterPart
    end

    counterPart = Instance.new("Part")
    counterPart.Name = COUNTER_PART_NAME
    counterPart.Size = COUNTER_PART_SIZE
    counterPart.Transparency = 1
    counterPart.CanCollide = false
    counterPart.CanQuery = false
    counterPart.CanTouch = false
    counterPart.Anchored = false
    counterPart.Massless = true
    counterPart.CastShadow = false
    counterPart.Parent = character

    counterPart.CFrame = CFrame.new(shoulderPart.Position) * getCounterLocalCFrame(shoulderPart)

    return counterPart
end

local function ensureCounterFollowWeld(character, counterPart, shoulderPart)
    -- Propósito: Soldar el contador a una parte estable del personaje para evitar retraso visual.
    -- Precondiciones:
    --   1. character debe ser modelo válido.
    --   2. counterPart debe ser BasePart válida.
    --   3. shoulderPart debe ser BasePart válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    local anchorPart = resolveCounterAnchorPart(character) or shoulderPart
    if not anchorPart then
        return
    end

    local existingWeld = counterPart:FindFirstChild("ShoulderCounterWeld")
    if existingWeld and existingWeld:IsA("WeldConstraint") then
        existingWeld.Part0 = counterPart
        existingWeld.Part1 = anchorPart
    else
        local weld = Instance.new("WeldConstraint")
        weld.Name = "ShoulderCounterWeld"
        weld.Part0 = counterPart
        weld.Part1 = anchorPart
        weld.Parent = counterPart
    end

    counterPart.CFrame = anchorPart.CFrame * getCounterLocalCFrame(shoulderPart)
end

local function getCounterLabel(surfaceGui, suffix)
    -- Propósito: Asegurar que el SurfaceGui tenga un TextLabel para renderizar el contador.
    -- Precondiciones:
    --   1. surfaceGui debe ser instancia SurfaceGui válida.
    --   2. suffix debe ser string no vacío.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: TextLabel
    local labelName = COUNTER_LABEL_PREFIX .. suffix
    local label = surfaceGui:FindFirstChild(labelName)
    if label and label:IsA("TextLabel") then
        return label
    end

    label = Instance.new("TextLabel")
    label.Name = labelName
    label.Parent = surfaceGui
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 230, 80)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    return label
end

local function getOrCreateSurfaceGui(counterPart, face, suffix)
    -- Propósito: Obtener un SurfaceGui fijo en una cara de la pieza para mostrar el texto del contador.
    -- Precondiciones:
    --   1. counterPart debe ser BasePart válida.
    --   2. face debe ser Enum.NormalId válido.
    --   3. suffix debe ser string no vacío.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: SurfaceGui
    local guiName = COUNTER_FACE_GUI_PREFIX .. suffix
    local surfaceGui = counterPart:FindFirstChild(guiName)
    if surfaceGui and surfaceGui:IsA("SurfaceGui") then
        return surfaceGui
    end

    surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = guiName
    surfaceGui.Parent = counterPart
    surfaceGui.Face = face
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.PixelsPerStud = 80
    surfaceGui.CanvasSize = Vector2.new(120, 40)
    surfaceGui.AlwaysOnTop = true
    return surfaceGui
end

local function ensureCharacterCounter(player, character)
    -- Propósito: Crear o actualizar el contador visible sobre el hombro del personaje.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. character debe ser modelo del jugador.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    if not player or not character or character.Parent == nil then
        return
    end

    local shoulderPart = resolveShoulderPart(character)
    if not shoulderPart then
        return
    end

    local legacyBillboard = character:FindFirstChild("PvpShoulderCounter")
    if legacyBillboard and legacyBillboard:IsA("BillboardGui") then
        legacyBillboard:Destroy()
    end

    local counterPart = getOrCreateCounterPart(character, shoulderPart)
    counterPart.Anchored = false
    ensureCounterFollowWeld(character, counterPart, shoulderPart)

    local frontGui = getOrCreateSurfaceGui(counterPart, Enum.NormalId.Front, "Front")
    local backGui = getOrCreateSurfaceGui(counterPart, Enum.NormalId.Back, "Back")
    local counterText = formatCounterText(PvpStarsService.getStars(player))

    local frontLabel = getCounterLabel(frontGui, "Front")
    frontLabel.Text = counterText

    local backLabel = getCounterLabel(backGui, "Back")
    backLabel.Text = counterText
end

local function loadPlayerStars(player)
    -- Propósito: Cargar desde DataStore las estrellas PvP del jugador al entrar.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: number
    local loadedStars = DEFAULT_STARS
    if starsDataStore then
        local key = DATASTORE_KEY_PREFIX .. tostring(player.UserId)
        local ok, data = pcall(function()
            return starsDataStore:GetAsync(key)
        end)
        if ok and type(data) == "number" then
            loadedStars = clampStars(data)
        elseif not ok then
            warn("[PvpStarsService] Error al cargar estrellas de " .. player.Name .. ": " .. tostring(data))
        end
    end

    PvpStarsService.setStars(player, loadedStars)
    return loadedStars
end

local function savePlayerStars(player)
    -- Propósito: Guardar en DataStore las estrellas PvP del jugador al salir.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    if not starsDataStore then
        return
    end

    local key = DATASTORE_KEY_PREFIX .. tostring(player.UserId)
    local stars = PvpStarsService.getStars(player)
    local ok, err = pcall(function()
        starsDataStore:SetAsync(key, stars)
    end)
    if not ok then
        warn("[PvpStarsService] Error al guardar estrellas de " .. player.Name .. ": " .. tostring(err))
    end
end

local function disconnectPlayerSignals(player)
    -- Propósito: Desconectar eventos ligados al jugador para evitar fugas de memoria.
    -- Precondiciones:
    --   1. player puede o no tener conexiones registradas.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    local connections = playerConnections[player]
    if not connections then
        return
    end

    for _, connection in ipairs(connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    playerConnections[player] = nil
end

local function connectPlayerSignals(player)
    -- Propósito: Escuchar respawns y cambios de valor para refrescar el contador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    disconnectPlayerSignals(player)

    local connections = {}
    local starsValue = getOrCreateStarsValue(player)

    table.insert(connections, player.CharacterAdded:Connect(function(character)
        ensureCharacterCounter(player, character)
    end))

    table.insert(connections, starsValue:GetPropertyChangedSignal("Value"):Connect(function()
        if player.Character then
            ensureCharacterCounter(player, player.Character)
        end
    end))

    playerConnections[player] = connections

    if player.Character then
        ensureCharacterCounter(player, player.Character)
    end
end

function PvpStarsService.getStars(player)
    -- Propósito: Obtener el valor actual de estrellas PvP del jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: number
    local starsValue = getOrCreateStarsValue(player)
    return clampStars(starsValue.Value)
end

function PvpStarsService.setStars(player, stars)
    -- Propósito: Asignar estrellas PvP al jugador y actualizar sus representaciones.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. stars debe ser number.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: number
    local normalized = clampStars(stars)
    local starsValue = getOrCreateStarsValue(player)
    starsValue.Value = normalized
    player:SetAttribute(STARS_ATTRIBUTE_NAME, normalized)

    if player.Character then
        ensureCharacterCounter(player, player.Character)
    end

    return normalized
end

function PvpStarsService.getPvpTitle(stars)
    local safeStars = clampStars(stars)
    local currentTitle = PVP_TITLES[1].title
    for _, entry in ipairs(PVP_TITLES) do
        if safeStars >= entry.minStars then
            currentTitle = entry.title
        end
    end
    return currentTitle
end

function PvpStarsService.getTitleForPlayer(player)
    return PvpStarsService.getPvpTitle(PvpStarsService.getStars(player))
end

function PvpStarsService.getShieldCharges(player)
    return math.max(0, math.min(MAX_SHIELD_CHARGES,
        math.floor(tonumber(player:GetAttribute(SHIELD_CHARGES_ATTRIBUTE_NAME)) or 0)))
end

function PvpStarsService.setShieldCharges(player, charges)
    local safe = math.clamp(math.floor(tonumber(charges) or 0), 0, MAX_SHIELD_CHARGES)
    player:SetAttribute(SHIELD_CHARGES_ATTRIBUTE_NAME, safe)
    return safe
end

function PvpStarsService.applyShieldRegen(player, now)
    local serverNow = tonumber(now) or os.time()
    local charges = PvpStarsService.getShieldCharges(player)
    if charges >= MAX_SHIELD_CHARGES then
        return charges
    end

    local lastDaily = tonumber(player:GetAttribute(LAST_DAILY_GRANT_ATTRIBUTE)) or 0
    if serverNow - lastDaily >= SECONDS_PER_DAY then
        local added = 0
        while serverNow - (lastDaily + added * SECONDS_PER_DAY) >= SECONDS_PER_DAY and charges < MAX_SHIELD_CHARGES do
            charges = charges + DAILY_SHIELD_GRANT
            added = added + 1
        end
        if added > 0 then
            player:SetAttribute(LAST_DAILY_GRANT_ATTRIBUTE, lastDaily + added * SECONDS_PER_DAY)
        end
    end

    local lastWeekly = tonumber(player:GetAttribute(LAST_WEEKLY_GRANT_ATTRIBUTE)) or 0
    if serverNow - lastWeekly >= SECONDS_PER_WEEK and charges < MAX_SHIELD_CHARGES then
        charges = math.min(MAX_SHIELD_CHARGES, charges + WEEKLY_SHIELD_GRANT)
        player:SetAttribute(LAST_WEEKLY_GRANT_ATTRIBUTE, lastWeekly + SECONDS_PER_WEEK)
    end

    return PvpStarsService.setShieldCharges(player, charges)
end

function PvpStarsService.consumeShieldOnLoss(player)
    local currentStars = PvpStarsService.getStars(player)
    if currentStars <= 0 then
        return 0
    end

    local charges = PvpStarsService.getShieldCharges(player)
    if charges > 0 then
        charges = PvpStarsService.setShieldCharges(player, charges - 1)
        return charges
    end

    return 0
end

function PvpStarsService.applyPvpDuelResult(winner, loser)
    -- Propósito: Aplicar variación de estrellas por resultado de duelo PvP.
    -- Precondiciones:
    --   1. winner y loser deben ser Player válidos.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: number|nil, number|nil, boolean
    local winnerStars = nil
    local loserStars = nil
    local shieldUsed = false

    if winner then
        winnerStars = PvpStarsService.setStars(winner, PvpStarsService.getStars(winner) + WIN_STARS_DELTA)
    end

    if loser then
        local charges = PvpStarsService.getShieldCharges(loser)
        if charges > 0 and PvpStarsService.getStars(loser) > 0 then
            PvpStarsService.setShieldCharges(loser, charges - 1)
            shieldUsed = true
            loserStars = PvpStarsService.getStars(loser)
        else
            loserStars = PvpStarsService.setStars(loser, PvpStarsService.getStars(loser) + LOSS_STARS_DELTA)
        end
    end

    return winnerStars, loserStars, shieldUsed
end

function PvpStarsService.onPlayerAdded(player)
    -- Propósito: Inicializar estrellas PvP y contador visual al entrar el jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    getOrCreateLeaderstatsFolder(player)
    getOrCreateStarsValue(player)
    loadPlayerStars(player)
    connectPlayerSignals(player)
end

function PvpStarsService.onPlayerRemoving(player)
    -- Propósito: Persistir estrellas y liberar conexiones al salir el jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PvpStarsService
    -- Retorna: nil
    savePlayerStars(player)
    disconnectPlayerSignals(player)
end

return PvpStarsService
