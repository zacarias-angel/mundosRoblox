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

function PetCubeService.spawnPlayerTeamCubes(player, team)
    -- Propósito: Mostrar 5 cubos del equipo activo cerca del jugador.
    -- Precondiciones:
    --   1. player debe ser instancia Player válida.
    --   2. team debe ser tabla de mascotas.
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

    local radius = 6
    for index, pet in ipairs(team) do
        local monsterData = MonstersData[pet.MonsterId]
        if monsterData then
            local element = monsterData.Element
            local template = templateFolder:FindFirstChild("Cube_" .. tostring(element))
            if template and template:IsA("Part") then
                local angle = math.rad((index - 1) * (360 / math.max(1, #team)))
                local offset = Vector3.new(math.cos(angle) * radius, 2.5, math.sin(angle) * radius)

                local cube = template:Clone()
                cube.Name = "PetCube_" .. tostring(index)
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
    end
end

return PetCubeService
