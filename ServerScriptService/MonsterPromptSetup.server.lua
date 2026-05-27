-- Tipo: Script (Server)
-- Ubicación: ServerScriptService/MonsterPromptSetup
-- Contexto: Servidor

--[[
    Script dedicado a crear los ProximityPrompts de monstruos NPC.
    Separado de CombatServer para evitar problemas de timing y errores previos
    que impidan el setup del prompt.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Esperar a que los RemoteEvents estén listos antes de continuar
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local CombatDuelState = RemoteEvents and RemoteEvents:WaitForChild("CombatDuelState", 10)

local MONSTER_CHALLENGE_DISTANCE = 15
local MONSTER_TAG = "MonsterNPC"

-- Tabla de monstruos registrados: modelo -> true
local registeredModels = {}

local function isMonsterModel(model)
    -- Propósito: Determinar si un modelo debe tratarse como monstruo desafiante.
    -- Retorna: boolean
    if not model or not model:IsA("Model") then
        return false
    end

    if model:GetAttribute("IsMonster") == true then
        return true
    end

    if type(model:GetAttribute("MonsterId")) == "string" then
        return true
    end

    return CollectionService:HasTag(model, MONSTER_TAG)
end

local function getModelRoot(model)
    -- Propósito: Obtener la BasePart principal de un modelo para alojar el ProximityPrompt.
    -- Retorna: BasePart | nil
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    -- Buscar por nombre primero (más predecible)
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    -- Fallback: primera BasePart directa
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    -- Último recurso: cualquier BasePart en toda la jerarquía
    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function setupPromptOnModel(model)
    -- Propósito: Crear ProximityPrompt en el modelo monstruo.
    -- Precondiciones:
    --   1. model debe ser un Model con al menos un BasePart.
    -- Ubicación: ServerScriptService/MonsterPromptSetup
    -- Retorna: nil
    if registeredModels[model] then return end
    if not isMonsterModel(model) then return end

    -- Estandarizamos atributos para que CombatServer lo detecte sin depender de tags.
    model:SetAttribute("IsMonster", true)
    if type(model:GetAttribute("MonsterId")) ~= "string" then
        model:SetAttribute("MonsterId", model.Name)
    end

    local root = getModelRoot(model)
    if not root then
        warn("[MonsterPromptSetup] " .. model.Name .. " no tiene BasePart accesible")
        return
    end

    -- Eliminar prompt anterior si existe
    local existing = root:FindFirstChild("MonsterChallengePrompt")
    if existing then existing:Destroy() end

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "MonsterChallengePrompt"
    prompt.ObjectText = model.Name
    prompt.ActionText = "Desafiar"
    prompt.MaxActivationDistance = MONSTER_CHALLENGE_DISTANCE
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.Parent = root

    registeredModels[model] = true
    print("[MonsterPromptSetup] Prompt creado en " .. model.Name .. " -> parte: " .. root.Name)
end

-- Escanear todos los modelos actuales del Workspace
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("Model") then
        setupPromptOnModel(obj)
    end
end

-- Detectar nuevos monstruos añadidos al Workspace
workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.5)
    if obj:IsA("Model") then
        setupPromptOnModel(obj)
    end
end)

-- Detectar tags agregados en runtime (flujo recomendado para escalar contenido).
CollectionService:GetInstanceAddedSignal(MONSTER_TAG):Connect(function(instance)
    if instance and instance:IsA("Model") then
        task.wait(0.1)
        setupPromptOnModel(instance)
    end
end)

-- Escuchar activación del prompt
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
    if prompt.Name ~= "MonsterChallengePrompt" then return end

    -- Subir la jerarquía para encontrar el Model raíz del monstruo
    local current = prompt.Parent
    local monsterModel = nil
    while current and current ~= workspace do
        if current:IsA("Model") and current:GetAttribute("IsMonster") then
            monsterModel = current
            break
        end
        current = current.Parent
    end

    if not monsterModel then
        warn("[MonsterPromptSetup] PromptTriggered: no se encontró Model con IsMonster=true")
        return
    end

    print("[MonsterPromptSetup] " .. triggerPlayer.Name .. " desafió a " .. monsterModel.Name)

    -- Reenviar al CombatServer vía BindableEvent o directamente disparar el evento
    -- Usamos CombatDuelState para notificar al cliente que se inició el desafío (el CombatServer maneja la lógica)
    -- El CombatServer escucha ProximityPromptService.PromptTriggered independientemente
end)
