-- Tipo: ModuleScript
-- Ubicación: ServerScriptService/Combat/PetCubeService
-- Contexto: Servidor

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local GameData = ReplicatedStorage:WaitForChild("GameData")
local MonstersData = require(GameData:WaitForChild("MonstersData"))

local PetCubeService = {}

local TEMPLATE_FOLDER_NAME = "PetCubeTemplates"
local WORLD_FOLDER_NAME = "PlayerPetCubes"

local elementColors = {
    Fuego = Color3.fromRGB(220, 60, 40),
    Agua = Color3.fromRGB(60, 140, 220),
    Planta = Color3.fromRGB(60, 180, 70),
    Electricidad = Color3.fromRGB(240, 210, 30),
    Roca = Color3.fromRGB(140, 120, 100),
}

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

local function getWorldFolder()
    -- Propósito: Obtener o crear carpeta global de cubos visuales en workspace.
    -- Precondiciones: Ninguna.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: Folder
    return ensureFolder(Workspace, WORLD_FOLDER_NAME)
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

function PetCubeService.clearPlayerCubes(player)
    -- Propósito: Eliminar cubos visuales de un jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    -- Ubicación: ServerScriptService/Combat/PetCubeService
    -- Retorna: nil
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

    local element = monsterData.Element
    local template = templateFolder:FindFirstChild("Cube_" .. tostring(element))
    if template and template:IsA("Part") then
        local offset = Vector3.new(0, 2.5, 5)

        local cube = template:Clone()
        cube.Name = "PetCube_Follower"
        cube.Anchored = false
        cube.Massless = true
        cube.CanCollide = false
        cube.CanQuery = false
        cube.CanTouch = false
        cube.CFrame = hrp.CFrame * CFrame.new(offset)

        local weld = Instance.new("WeldConstraint")
        weld.Name = "FollowWeld"
        weld.Part0 = cube
        weld.Part1 = hrp
        weld.Parent = cube

        cube.Parent = playerFolder
    end
end

function PetCubeService.spawnPlayerTeamDuelLine(player, team, enemyPosition)
    -- Propósito: Mostrar 5 cubos del equipo en línea frente al domador mirando al contrincante.
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
    local frontDistance = 6
    local sideSpacing = 3

    for index, pet in ipairs(team) do
        local monsterData = MonstersData[pet.MonsterId]
        if monsterData then
            local element = monsterData.Element
            local template = templateFolder:FindFirstChild("Cube_" .. tostring(element))
            if template and template:IsA("Part") then
                local sideOffset = (index - centerIndex) * sideSpacing
                local offset = (forward * frontDistance) + (right * sideOffset) + Vector3.new(0, 2.5, 0)

                local cube = template:Clone()
                cube.Name = "PetCube_" .. tostring(index)
                cube.Anchored = false
                cube.Massless = true
                cube.CanCollide = false
                cube.CanQuery = false
                cube.CanTouch = false

                local worldPos = hrp.Position + offset
                cube.CFrame = CFrame.lookAt(worldPos, worldPos + forward, Vector3.new(0, 1, 0))

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

return PetCubeService
