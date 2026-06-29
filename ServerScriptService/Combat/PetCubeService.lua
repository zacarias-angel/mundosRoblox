-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/PetCubeService
-- Contexto: Servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local PetCubeService = {}

local TEMPLATE_FOLDER_NAME = "PetCubeTemplates"
local MODEL_TEMPLATE_FOLDER_NAME = "BeastibitTemplates"
local WORLD_FOLDER_NAME = "PlayerPetCubes"

local FOLLOW_DISTANCE = 3.5
local FOLLOW_SIDE_OFFSET = 0
local FOLLOW_HEIGHT_FROM_GROUND = 1.1
local FOLLOW_LERP_BASE_SPEED = 5.5
local FOLLOW_CATCHUP_SPEED = 6.5
local FOLLOW_CATCHUP_DISTANCE = 8
local FOLLOW_TELEPORT_DISTANCE = 30
local FOLLOW_POSITION_EPSILON = 0.02
local FOLLOW_RAYCAST_HEIGHT = 10
local FOLLOW_RAYCAST_DEPTH = 30

local elementColors = {
    Fuego = Color3.fromRGB(220, 60, 40),
    Agua = Color3.fromRGB(60, 140, 220),
    Planta = Color3.fromRGB(60, 180, 70),
    Electricidad = Color3.fromRGB(240, 210, 30),
    Roca = Color3.fromRGB(140, 120, 100),
}

local followerStatesByUserId = {}

local function ensureFolder(parent, name)
    -- Propósito: Obtener o crear una carpeta por nombre dentro de un padre.
    -- Precondiciones:
    --   1. parent debe ser instancia válida.
    --   2. name debe ser string.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("Folder") then
        return existing
    end

    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function getTemplateFolder()
    -- Propósito: Obtener o crear carpeta de templates de cubos en servidor.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Folder
    return ensureFolder(ServerStorage, TEMPLATE_FOLDER_NAME)
end

local function getModelTemplateFolder()
    -- Propósito: Obtener o crear carpeta de templates de modelos Beastibit en servidor.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Folder
    return ensureFolder(ServerStorage, MODEL_TEMPLATE_FOLDER_NAME)
end

local function getWorldFolder()
    -- Propósito: Obtener o crear carpeta global de cubos visuales en workspace.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Folder
    return ensureFolder(Workspace, WORLD_FOLDER_NAME)
end

local function stopFollowerTracking(player)
    -- Propósito: Detener y limpiar seguimiento activo del Beastibit de un jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    local state = followerStatesByUserId[player.UserId]
    if not state then
        return
    end

    followerStatesByUserId[player.UserId] = nil

    if state.connection then
        state.connection:Disconnect()
        state.connection = nil
    end

    if state.followerState and state.followerState.animations then
        stopCompanionAnimations(state.followerState.animations)
    end
end

local function getFollowUpVector(hrp, followerState)
    -- Propósito: Resolver vector "arriba" para follow (planetario o global).
    -- Precondiciones:
    --   1. hrp debe ser BasePart válida.
    --   2. followerState puede incluir usePlanetUp.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Vector3
    if followerState and followerState.usePlanetUp == false then
        return Vector3.new(0, 1, 0)
    end

    local up = hrp.CFrame.UpVector
    if up.Magnitude < 1e-4 then
        return Vector3.new(0, 1, 0)
    end

    return up.Unit
end

local function projectOnPlane(vector, normal)
    -- Propósito: Proyectar un vector en el plano tangente definido por normal.
    -- Precondiciones:
    --   1. vector y normal deben ser Vector3 válidos.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Vector3
    return vector - (normal * vector:Dot(normal))
end

local function getFollowForwardVector(hrp, upVector)
    -- Propósito: Resolver forward tangente para mantener follow estable en planetas.
    -- Precondiciones:
    --   1. hrp debe ser BasePart válida.
    --   2. upVector debe estar normalizado.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Vector3
    local forward = projectOnPlane(hrp.CFrame.LookVector, upVector)
    if forward.Magnitude < 1e-4 then
        forward = projectOnPlane(hrp.CFrame.RightVector:Cross(upVector), upVector)
    end
    if forward.Magnitude < 1e-4 then
        forward = Vector3.new(0, 0, -1)
    end

    return forward.Unit
end

local function getFollowRightVector(forwardVector, upVector)
    -- Propósito: Obtener eje right tangente a partir de forward y up.
    -- Precondiciones:
    --   1. forwardVector y upVector deben estar normalizados.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Vector3
    local right = forwardVector:Cross(upVector)
    if right.Magnitude < 1e-4 then
        right = Vector3.new(1, 0, 0)
    end
    return right.Unit
end

local function getFollowerConfigValue(followerState, key, defaultValue)
    -- Propósito: Leer valor de configuración por seguidor con fallback a valor global.
    -- Precondiciones:
    --   1. followerState puede ser nil.
    --   2. key debe ser string válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: number
    if followerState and type(followerState[key]) == "number" then
        return followerState[key]
    end
    return defaultValue
end

local function resolveCompanionFollowConfig(monsterData)
    -- Propósito: Resolver configuración de seguimiento/orientación desde MonsterData.
    -- Precondiciones:
    --   1. monsterData puede ser nil o tabla.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: table
    local cfg = {}
    local source = nil
    if type(monsterData) == "table" and type(monsterData.CompanionFollow) == "table" then
        source = monsterData.CompanionFollow
    end

    cfg.usePlanetUp = true
    if source and type(source.UsePlanetUp) == "boolean" then
        cfg.usePlanetUp = source.UsePlanetUp
    end

    cfg.yawOffsetDeg = tonumber(source and source.YawOffsetDeg) or 0
    cfg.pitchOffsetDeg = tonumber(source and source.PitchOffsetDeg) or 0
    cfg.rollOffsetDeg = tonumber(source and source.RollOffsetDeg) or 0

    cfg.followDistance = tonumber(source and source.Distance) or FOLLOW_DISTANCE
    cfg.followSideOffset = tonumber(source and source.SideOffset) or FOLLOW_SIDE_OFFSET
    cfg.followHeightFromGround = tonumber(source and source.HeightOffset) or FOLLOW_HEIGHT_FROM_GROUND
    cfg.followLerpBaseSpeed = tonumber(source and source.LerpSpeed) or FOLLOW_LERP_BASE_SPEED
    cfg.followCatchupSpeed = tonumber(source and source.CatchupSpeed) or FOLLOW_CATCHUP_SPEED
    cfg.followCatchupDistance = tonumber(source and source.CatchupDistance) or FOLLOW_CATCHUP_DISTANCE
    cfg.followTeleportDistance = tonumber(source and source.TeleportDistance) or FOLLOW_TELEPORT_DISTANCE

    return cfg
end

local function resolveCompanionAnimations(model)
    -- Proposito: Detectar AnimationController en el modelo clonado y cargar tracks de Idle/Walk.
    -- Precondiciones:
    --   1. model debe ser Model valido.
    -- Ubicacion: ServerScriptService/Combat/PetCubeService
    -- Retorna: table|nil
    local ac = model:FindFirstChildOfClass("AnimationController")
    if not ac then
        return nil
    end

    local idleTrack = nil
    local walkTrack = nil
    local otherTracks = {}

    for _, child in ipairs(ac:GetChildren()) do
        if child:IsA("Animation") and type(child.AnimationId) == "string" and child.AnimationId ~= "" then
            local ok, track = pcall(function()
                return ac:LoadAnimation(child)
            end)
            if ok and track then
                track:Stop(0)
                local lowerName = string.lower(child.Name)
                if lowerName:find("idle") or lowerName:find("quieto") or lowerName:find("stand") then
                    idleTrack = track
                elseif lowerName:find("walk") or lowerName:find("run") or lowerName:find("caminar") or lowerName:find("andar") or lowerName:find("move") then
                    walkTrack = track
                else
                    table.insert(otherTracks, track)
                end
            end
        end
    end

    if not walkTrack and #otherTracks > 0 then
        walkTrack = otherTracks[1]
        table.remove(otherTracks, 1)
    end
    if not idleTrack and #otherTracks > 0 then
        idleTrack = otherTracks[1]
        table.remove(otherTracks, 1)
    end

    if not walkTrack and not idleTrack then
        return nil
    end

    return {
        idleTrack = idleTrack,
        walkTrack = walkTrack,
    }
end

local function stopCompanionAnimations(animationState)
    -- Proposito: Detener y limpiar tracks de animacion del companion.
    -- Precondiciones:
    --   1. animationState puede ser nil.
    -- Ubicacion: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    if not animationState then return end
    if animationState.idleTrack then
        pcall(function() animationState.idleTrack:Stop(0.1) end)
    end
    if animationState.walkTrack then
        pcall(function() animationState.walkTrack:Stop(0.1) end)
    end
end

local function resolveDuelLineConfig(monsterData)
    -- Propósito: Resolver offsets exclusivos para formación en línea de duelo.
    -- Precondiciones:
    --   1. monsterData puede ser nil o tabla.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: table
    local cfg = {
        sideOffsetStuds = 0,
        heightOffsetStuds = 0,
        forwardOffsetStuds = 0,
        yawOffsetDeg = 0,
        pitchOffsetDeg = 0,
        rollOffsetDeg = 0,
    }

    if type(monsterData) ~= "table" or type(monsterData.DuelLinePlacement) ~= "table" then
        return cfg
    end

    local source = monsterData.DuelLinePlacement
    cfg.sideOffsetStuds = tonumber(source.SideOffsetStuds) or 0
    cfg.heightOffsetStuds = tonumber(source.HeightOffsetStuds) or 0
    cfg.forwardOffsetStuds = tonumber(source.ForwardOffsetStuds) or 0
    cfg.yawOffsetDeg = tonumber(source.YawOffsetDeg) or 0
    cfg.pitchOffsetDeg = tonumber(source.PitchOffsetDeg) or 0
    cfg.rollOffsetDeg = tonumber(source.RollOffsetDeg) or 0
    return cfg
end

local function computeFollowerGoalPosition(hrp, raycastParams, followerState)
    -- Propósito: Calcular destino orgánico del Beastibit detrás del jugador con ajuste a suelo.
    -- Precondiciones:
    --   1. hrp debe ser BasePart válida.
    --   2. raycastParams debe ser RaycastParams válida.
    --   3. followerState puede incluir flags de follow.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Vector3
    local upVector = getFollowUpVector(hrp, followerState)
    local forward = getFollowForwardVector(hrp, upVector)
    local right = getFollowRightVector(forward, upVector)
    local followDistance = getFollowerConfigValue(followerState, "followDistance", FOLLOW_DISTANCE)
    local followSideOffset = getFollowerConfigValue(followerState, "followSideOffset", FOLLOW_SIDE_OFFSET)
    local followHeightFromGround = getFollowerConfigValue(followerState, "followHeightFromGround", FOLLOW_HEIGHT_FROM_GROUND)

    local basePosition = hrp.Position
        - (forward * followDistance)
        + (right * followSideOffset)

    local raycastOrigin = basePosition + (upVector * FOLLOW_RAYCAST_HEIGHT)
    local raycastDirection = -upVector * FOLLOW_RAYCAST_DEPTH
    local result = Workspace:Raycast(raycastOrigin, raycastDirection, raycastParams)
    if result then
        return result.Position + (upVector * followHeightFromGround)
    end

    return basePosition + (upVector * followHeightFromGround)
end

local function buildFollowerTargetCFrame(position, hrp, followerState)
    -- Propósito: Construir CFrame objetivo estable en gravedad planetaria.
    -- Precondiciones:
    --   1. position debe ser Vector3 válida.
    --   2. hrp debe ser BasePart válida.
    --   3. followerState puede incluir flags de follow.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: CFrame
    local upVector = getFollowUpVector(hrp, followerState)
    local toPlayer = projectOnPlane(hrp.Position - position, upVector)

    if toPlayer.Magnitude < 1e-4 then
        toPlayer = getFollowForwardVector(hrp, upVector)
    end

    return CFrame.lookAt(position, position + toPlayer.Unit, upVector)
end

local function setFollowerPivot(followerState, targetCFrame)
    -- Propósito: Mover el seguidor (Part o Model) al CFrame indicado.
    -- Precondiciones:
    --   1. followerState debe tener mover y referencia válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    if followerState.isModel then
        local offset = followerState.orientationOffset or CFrame.new()
        followerState.instance:PivotTo(targetCFrame * offset)
    else
        followerState.instance.CFrame = targetCFrame
    end
end

local function getFollowerPosition(followerState)
    -- Propósito: Obtener posición actual del seguidor independientemente de su tipo.
    -- Precondiciones:
    --   1. followerState debe tener rootPart válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Vector3
    if followerState.isModel then
        return followerState.instance:GetPivot().Position
    end

    return followerState.rootPart.Position
end

local function createFollowerPart(template, spawnPos, hrp, playerFolder, companionConfig)
    -- Propósito: Crear seguidor visual basado en Part para fallback seguro.
    -- Precondiciones:
    --   1. template debe ser Part válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: table|nil
    local part = template:Clone()
    part.Name = "PetCube_Follower"
    part.Anchored = true
    part.Massless = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    local spawnFollowerState = {
        isModel = false,
        usePlanetUp = companionConfig.usePlanetUp,
        followDistance = companionConfig.followDistance,
        followSideOffset = companionConfig.followSideOffset,
        followHeightFromGround = companionConfig.followHeightFromGround,
    }
    part.CFrame = buildFollowerTargetCFrame(spawnPos, hrp, spawnFollowerState)
    part.Parent = playerFolder

    return {
        instance = part,
        rootPart = part,
        isModel = false,
        usePlanetUp = companionConfig.usePlanetUp,
        orientationOffset = CFrame.new(),
        followDistance = companionConfig.followDistance,
        followSideOffset = companionConfig.followSideOffset,
        followHeightFromGround = companionConfig.followHeightFromGround,
        followLerpBaseSpeed = companionConfig.followLerpBaseSpeed,
        followCatchupSpeed = companionConfig.followCatchupSpeed,
        followCatchupDistance = companionConfig.followCatchupDistance,
        followTeleportDistance = companionConfig.followTeleportDistance,
    }
end

    local function createFollowerModel(templateModel, spawnPos, hrp, playerFolder, companionConfig)
    -- Propósito: Crear seguidor visual basado en Model con validaciones de runtime.
    -- Precondiciones:
    --   1. templateModel debe ser Model válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: table|nil
    local model = templateModel:Clone()
    model.Name = "Beastibit_Follower"
    model:SetAttribute("IsMonster", false)
    model:SetAttribute("IsCompanion", true)
    pcall(function()
        model:SetAttribute("MonsterId", nil)
    end)

    local orientationOffset = CFrame.Angles(
        math.rad(companionConfig.pitchOffsetDeg),
        math.rad(companionConfig.yawOffsetDeg),
        math.rad(companionConfig.rollOffsetDeg)
    )

    local hasBasePart = false
    local firstBasePart = nil
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "MonsterChallengePrompt" then
            descendant:Destroy()
            continue
        end

        if descendant:IsA("BasePart") then
            hasBasePart = true
            if not firstBasePart then
                firstBasePart = descendant
            end
            descendant.Anchored = true
            descendant.Massless = true
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        end
    end

    if not hasBasePart then
        model:Destroy()
        return nil
    end

    if not model.PrimaryPart then
        local preferredRoot = model:FindFirstChild("HumanoidRootPart", true)
        if preferredRoot and preferredRoot:IsA("BasePart") then
            model.PrimaryPart = preferredRoot
        elseif firstBasePart then
            model.PrimaryPart = firstBasePart
        end
    end

    if not model.PrimaryPart and firstBasePart then
        model.PrimaryPart = firstBasePart
    end

    local spawnFollowerState = {
        isModel = true,
        usePlanetUp = companionConfig.usePlanetUp,
        followDistance = companionConfig.followDistance,
        followSideOffset = companionConfig.followSideOffset,
        followHeightFromGround = companionConfig.followHeightFromGround,
    }
    model:PivotTo(buildFollowerTargetCFrame(spawnPos, hrp, spawnFollowerState) * orientationOffset)
    model.Parent = playerFolder

    local rootPart = model.PrimaryPart
    if not rootPart or not rootPart:IsA("BasePart") then
        model:Destroy()
        return nil
    end

    local animations = resolveCompanionAnimations(model)

    return {
        instance = model,
        rootPart = rootPart,
        isModel = true,
        orientationOffset = orientationOffset,
        usePlanetUp = companionConfig.usePlanetUp,
        followDistance = companionConfig.followDistance,
        followSideOffset = companionConfig.followSideOffset,
        followHeightFromGround = companionConfig.followHeightFromGround,
        followLerpBaseSpeed = companionConfig.followLerpBaseSpeed,
        followCatchupSpeed = companionConfig.followCatchupSpeed,
        followCatchupDistance = companionConfig.followCatchupDistance,
        followTeleportDistance = companionConfig.followTeleportDistance,
        animations = animations,
    }
end

local function resolveModelTemplate(monsterId, monsterData)
    -- Propósito: Resolver template 3D a usar para un Beastibit.
    -- Precondiciones:
    --   1. monsterId debe ser string válido.
    --   2. monsterData puede incluir ModelTemplate opcional.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Model|nil
    local modelTemplateName = nil
    if type(monsterData) == "table" and type(monsterData.ModelTemplate) == "string" then
        modelTemplateName = monsterData.ModelTemplate
    else
        modelTemplateName = monsterId
    end

    if type(modelTemplateName) ~= "string" or modelTemplateName == "" then
        return nil
    end

    local modelTemplateFolder = getModelTemplateFolder()
    local fromServerStorage = modelTemplateFolder:FindFirstChild(modelTemplateName)
    if fromServerStorage and fromServerStorage:IsA("Model") then
        return fromServerStorage
    end

    -- Fallback de transición: permite probar con modelo ubicado en Workspace.
    local fromWorkspace = Workspace:FindFirstChild(modelTemplateName)
    if fromWorkspace and fromWorkspace:IsA("Model") then
        return fromWorkspace
    end

    return nil
end

local function createDuelLineModel(templateModel, spawnCFrame, playerFolder, hrp, index, duelLineConfig)
    -- Propósito: Crear Beastibit 3D en línea de duelo y soldarlo al jugador.
    -- Precondiciones:
    --   1. templateModel debe ser Model válida.
    --   2. spawnCFrame debe ser CFrame válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: boolean
    local model = templateModel:Clone()
    model.Name = "PetCube_" .. tostring(index)
    model:SetAttribute("IsMonster", false)
    model:SetAttribute("IsCompanion", true)
    pcall(function()
        model:SetAttribute("MonsterId", nil)
    end)

    local hasBasePart = false
    local firstBasePart = nil
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") and descendant.Name == "MonsterChallengePrompt" then
            descendant:Destroy()
            continue
        end

        if descendant:IsA("BasePart") then
            hasBasePart = true
            if not firstBasePart then
                firstBasePart = descendant
            end
            descendant.Anchored = false
            descendant.Massless = true
            descendant.CanCollide = false
            descendant.CanQuery = false
            descendant.CanTouch = false
        end
    end

    if not hasBasePart then
        model:Destroy()
        return false
    end

    if not model.PrimaryPart then
        local preferredRoot = model:FindFirstChild("HumanoidRootPart", true)
        if preferredRoot and preferredRoot:IsA("BasePart") then
            model.PrimaryPart = preferredRoot
        elseif firstBasePart then
            model.PrimaryPart = firstBasePart
        end
    end

    local rootPart = model.PrimaryPart
    if not rootPart or not rootPart:IsA("BasePart") then
        model:Destroy()
        return false
    end

    local cfg = duelLineConfig or {}
    local placementOffset = CFrame.new(
        tonumber(cfg.sideOffsetStuds) or 0,
        tonumber(cfg.heightOffsetStuds) or 0,
        tonumber(cfg.forwardOffsetStuds) or 0
    )
    local orientationOffset = CFrame.Angles(
        math.rad(tonumber(cfg.pitchOffsetDeg) or 0),
        math.rad(tonumber(cfg.yawOffsetDeg) or 0),
        math.rad(tonumber(cfg.rollOffsetDeg) or 0)
    )

    -- En duelo ignoramos offsets de follow y usamos solo offsets de DuelLinePlacement.
    model:PivotTo(spawnCFrame * placementOffset * orientationOffset)

    local autoWeldToRoot = true
    if cfg.autoWeldToRoot ~= nil then
        autoWeldToRoot = cfg.autoWeldToRoot == true
    end

    if autoWeldToRoot then
        for _, descendant in ipairs(model:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant ~= rootPart then
                local hasJoint = false
                for _, joint in ipairs(descendant:GetChildren()) do
                    if joint:IsA("WeldConstraint") then
                        hasJoint = true
                        break
                    end
                end

                if not hasJoint then
                    local partWeld = Instance.new("WeldConstraint")
                    partWeld.Name = "DuelLineRootWeld"
                    partWeld.Part0 = descendant
                    partWeld.Part1 = rootPart
                    partWeld.Parent = descendant
                end
            end
        end
    end

    model.Parent = playerFolder

    local weld = Instance.new("WeldConstraint")
    weld.Name = "FollowWeld"
    weld.Part0 = rootPart
    weld.Part1 = hrp
    weld.Parent = rootPart

    return true
end

local function startFollowerTracking(player, followerState, hrp, character)
    -- Propósito: Iniciar seguimiento con lerp/catch-up para evitar movimiento rígido del Beastibit.
    -- Precondiciones:
    --   1. player debe ser Player válido.
    --   2. followerState debe ser tabla con instance/rootPart válidos.
    --   3. hrp debe ser BasePart válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    stopFollowerTracking(player)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { followerState.instance, character }

    local function stepFollower(dt)
        if not followerState.instance.Parent or not followerState.rootPart.Parent or not hrp.Parent or not player.Parent then
            stopFollowerTracking(player)
            return
        end

        local goalPosition = computeFollowerGoalPosition(hrp, raycastParams, followerState)

        local currentPosition = getFollowerPosition(followerState)
        local toGoal = goalPosition - currentPosition
        local distanceToGoal = toGoal.Magnitude
        local followTeleportDistance = getFollowerConfigValue(followerState, "followTeleportDistance", FOLLOW_TELEPORT_DISTANCE)
        local followCatchupDistance = getFollowerConfigValue(followerState, "followCatchupDistance", FOLLOW_CATCHUP_DISTANCE)
        local followLerpBaseSpeed = getFollowerConfigValue(followerState, "followLerpBaseSpeed", FOLLOW_LERP_BASE_SPEED)
        local followCatchupSpeed = getFollowerConfigValue(followerState, "followCatchupSpeed", FOLLOW_CATCHUP_SPEED)

        local anims = followerState.animations

        if distanceToGoal <= FOLLOW_POSITION_EPSILON then
            if anims then
                if anims.walkTrack and anims.walkTrack.IsPlaying then
                    anims.walkTrack:Stop(0.15)
                end
                if anims.idleTrack and not anims.idleTrack.IsPlaying then
                    anims.idleTrack:Play(0.15)
                end
            end
            return
        end

        if anims then
            if anims.idleTrack and anims.idleTrack.IsPlaying then
                anims.idleTrack:Stop(0.15)
            end
            if anims.walkTrack then
                if not anims.walkTrack.IsPlaying then
                    anims.walkTrack:Play(0.15)
                end
                local speedScale = math.clamp(distanceToGoal / 3, 0.5, 1.5)
                anims.walkTrack:AdjustSpeed(speedScale)
            end
        end

        if distanceToGoal >= followTeleportDistance then
            setFollowerPivot(followerState, buildFollowerTargetCFrame(goalPosition, hrp, followerState))
            return
        end

        local followSpeed = followLerpBaseSpeed
        if distanceToGoal >= followCatchupDistance then
            followSpeed = followCatchupSpeed
        end

        local alpha = math.clamp(dt * followSpeed, 0, 1)
        local nextPosition = currentPosition:Lerp(goalPosition, alpha)

        setFollowerPivot(followerState, buildFollowerTargetCFrame(nextPosition, hrp, followerState))
    end

    local connection = RunService.Heartbeat:Connect(stepFollower)
    followerStatesByUserId[player.UserId] = {
        follower = followerState.instance,
        hrp = hrp,
        connection = connection,
        followerState = followerState,
    }
end

function PetCubeService.ensureElementTemplates()
    -- Propósito: Crear templates de cubos por elemento si todavía no existen.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    local templateFolder = getTemplateFolder()

    for element, color in pairs(elementColors) do
        local templateName = "Cube_" .. element
        local existing = templateFolder:FindFirstChild(templateName)
        if existing and existing:IsA("Part") then
            continue
        end

        local cube = Instance.new("Part")
        cube.Name = templateName
        cube.Shape = Enum.PartType.Block
        cube.Size = Vector3.new(2, 2, 2)
        cube.Material = Enum.Material.SmoothPlastic
        cube.Color = color
        cube.Anchored = true
        cube.CanCollide = false
        cube.TopSurface = Enum.SurfaceType.Smooth
        cube.BottomSurface = Enum.SurfaceType.Smooth
        cube.Parent = templateFolder
    end
end

function PetCubeService.ensureModelTemplateFolder()
    -- Propósito: Asegurar carpeta de modelos Beastibit en ServerStorage para flujo de templates.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    getModelTemplateFolder()
end

function PetCubeService.clearPlayerCubes(player)
    -- Propósito: Eliminar cubos visuales de un jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    stopFollowerTracking(player)

    local worldFolder = getWorldFolder()
    local playerFolder = worldFolder:FindFirstChild(player.Name)
    if playerFolder then
        playerFolder:Destroy()
    end
end

function PetCubeService.spawnPlayerTeamCubes(player, team, selectedFollowerMonsterId)
    -- Propósito: Mostrar 1 cubo seguidor del Beastibit seleccionado fuera de duelo.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. team debe ser tabla de mascotas.
    --   3. selectedFollowerMonsterId puede ser string o nil.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    if type(team) ~= "table" then
        return
    end

    PetCubeService.ensureElementTemplates()
    PetCubeService.ensureModelTemplateFolder()
    PetCubeService.clearPlayerCubes(player)

    local character = player.Character
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        return
    end

    local templateFolder = getTemplateFolder()
    local worldFolder = getWorldFolder()
    local playerFolder = Instance.new("Folder")
    playerFolder.Name = player.Name
    playerFolder.Parent = worldFolder

    local followerMonsterId = nil
    if type(selectedFollowerMonsterId) == "string" and MonstersData[selectedFollowerMonsterId] ~= nil then
        followerMonsterId = selectedFollowerMonsterId
    elseif type(team[1]) == "table" and type(team[1].MonsterId) == "string" then
        followerMonsterId = team[1].MonsterId
    end

    if type(followerMonsterId) ~= "string" then
        return
    end

    local monsterData = MonstersData[followerMonsterId]
    if not monsterData then
        return
    end

    local companionConfig = resolveCompanionFollowConfig(monsterData)

    local element = monsterData.Element
    local spawnRaycastParams = RaycastParams.new()
    spawnRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    spawnRaycastParams.FilterDescendantsInstances = { character }
    local spawnPos = computeFollowerGoalPosition(hrp, spawnRaycastParams, {
        usePlanetUp = companionConfig.usePlanetUp,
        followDistance = companionConfig.followDistance,
        followSideOffset = companionConfig.followSideOffset,
        followHeightFromGround = companionConfig.followHeightFromGround,
    })

    local followerState = nil

    local modelTemplate = resolveModelTemplate(followerMonsterId, monsterData)
    if modelTemplate then
        followerState = createFollowerModel(modelTemplate, spawnPos, hrp, playerFolder, companionConfig)
    end

    if not followerState then
        local template = templateFolder:FindFirstChild("Cube_" .. tostring(element))
        if template and template:IsA("Part") then
            followerState = createFollowerPart(template, spawnPos, hrp, playerFolder, companionConfig)
        end
    end

    if followerState then
        startFollowerTracking(player, followerState, hrp, character)
    end
end

function PetCubeService.spawnPlayerTeamDuelLine(player, team, enemyPosition)
    -- Propósito: Mostrar Beastibit del equipo en línea frente al domador mirando al contrincante.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. team debe ser tabla de mascotas.
    --   3. enemyPosition debe ser Vector3 válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
    if type(team) ~= "table" or typeof(enemyPosition) ~= "Vector3" then
        return
    end

    PetCubeService.ensureElementTemplates()
    PetCubeService.ensureModelTemplateFolder()
    PetCubeService.clearPlayerCubes(player)

    local character = player.Character
    if not character then
        return
    end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        return
    end

    local lookDir = enemyPosition - hrp.Position
    lookDir = Vector3.new(lookDir.X, 0, lookDir.Z)
    if lookDir.Magnitude < 1e-4 then
        lookDir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
    end
    if lookDir.Magnitude < 1e-4 then
        lookDir = Vector3.new(0, 0, -1)
    end
    local forward = lookDir.Unit

    local right = forward:Cross(Vector3.new(0, 1, 0))
    if right.Magnitude < 1e-4 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end

    local templateFolder = getTemplateFolder()
    local worldFolder = getWorldFolder()
    local playerFolder = Instance.new("Folder")
    playerFolder.Name = player.Name
    playerFolder.Parent = worldFolder

    local lineCount = math.max(1, #team)
    local centerIndex = (lineCount + 1) * 0.5
    local frontDistance = 4
    local sideSpacing = 3

    for index, pet in ipairs(team) do
        local monsterData = MonstersData[pet.MonsterId]
        if monsterData then
            local sideOffset = (index - centerIndex) * sideSpacing
            local offset = (forward * frontDistance) + (right * sideOffset) + Vector3.new(0, 2.5, 0)
            local worldPos = hrp.Position + offset
            local spawnCFrame = CFrame.lookAt(worldPos, worldPos + forward, Vector3.new(0, 1, 0))

            local didSpawnModel = false
            local modelTemplate = resolveModelTemplate(pet.MonsterId, monsterData)
            if modelTemplate then
                local duelLineConfig = resolveDuelLineConfig(monsterData)
                didSpawnModel = createDuelLineModel(modelTemplate, spawnCFrame, playerFolder, hrp, index, duelLineConfig)
            end

            if not didSpawnModel then
                local element = monsterData.Element
                local template = templateFolder:FindFirstChild("Cube_" .. tostring(element))
                if template and template:IsA("Part") then
                    local cube = template:Clone()
                    cube.Name = "PetCube_" .. tostring(index)
                    cube.Anchored = false
                    cube.Massless = true
                    cube.CanCollide = false
                    cube.CanQuery = false
                    cube.CanTouch = false
                    cube.CFrame = spawnCFrame

                    local weld = Instance.new("WeldConstraint")
                    weld.Name = "FollowWeld"
                    weld.Part0 = cube
                    weld.Part1 = hrp
                    weld.Parent = cube

                    cube.Parent = playerFolder
                end
            end
        end
    end
end

return PetCubeService