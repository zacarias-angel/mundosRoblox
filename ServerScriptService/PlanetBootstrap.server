-- Tipo: Script
-- Ubicacion: ServerScriptService
-- Se ejecuta en: Servidor
-- Nombre sugerido: PlanetBootstrap

local AUTO_CREATE_STARTER_PLANETS = true
local DEFAULT_GRAVITY_ACCEL = 120
local DEFAULT_INFLUENCE_MULTIPLIER = 3.2
local DEFAULT_SURFACE_OFFSET = 3.9

--[[
Funcion: ensurePlanetsFolder

Proposito:
Crea la carpeta Workspace/Planets para agrupar planetas recorribles.

Precondiciones:
- Debe ejecutarse en servidor.

Requiere:
- workspace disponible.

Devuelve:
- Folder Planets.
]]
local function ensurePlanetsFolder()
	local folder = workspace:FindFirstChild("Planets")
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "Planets"
	folder.Parent = workspace
	return folder
end

--[[
Funcion: ensurePlanetModel

Proposito:
Crea o actualiza un planeta con Sphere, GravityCenter y atributos de gravedad.

Precondiciones:
- Debe ejecutarse en servidor.

Requiere:
- Workspace/Planets existente.

Devuelve:
- Model planeta creado o existente.
]]
local function findPlanetSurfacePart(planet)
	local preferredName = planet:GetAttribute("SurfacePartName")
	if type(preferredName) == "string" and preferredName ~= "" then
		local preferred = planet:FindFirstChild(preferredName, true)
		if preferred and preferred:IsA("BasePart") then
			return preferred
		end
	end

	local sphere = planet:FindFirstChild("Sphere", true)
	if sphere and sphere:IsA("BasePart") then
		return sphere
	end

	if planet.PrimaryPart and planet.PrimaryPart:IsA("BasePart") then
		return planet.PrimaryPart
	end

	local bestPart = nil
	local bestVolume = -1
	for _, descendant in ipairs(planet:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "GravityCenter" then
			local size = descendant.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				bestVolume = volume
				bestPart = descendant
			end
		end
	end

	return bestPart
end

--[[
Funcion: ensurePlanetModel

Proposito:
Configura un planeta existente sin modificar su malla/superficie y crea GravityCenter si falta.

Precondiciones:
- planet debe ser Model.

Requiere:
- Debe existir al menos un BasePart de superficie.

Devuelve:
- Model planeta configurado o nil.
]]
local function ensurePlanetModel(planet, definition)
	local surfacePart = findPlanetSurfacePart(planet)
	if not surfacePart then
		warn("PlanetBootstrap: planeta sin superficie valida -> " .. planet.Name)
		return nil
	end

	local effectiveRadius = math.max(surfacePart.Size.X, surfacePart.Size.Y, surfacePart.Size.Z) * 0.5

	planet:SetAttribute("PlanetId", planet.Name)
	if type(planet:GetAttribute("GravityAccel")) ~= "number" then
		planet:SetAttribute("GravityAccel", definition.gravityAccel or DEFAULT_GRAVITY_ACCEL)
	end
	if type(planet:GetAttribute("InfluenceRadius")) ~= "number" then
		local influenceMultiplier = definition.influenceMultiplier or DEFAULT_INFLUENCE_MULTIPLIER
		planet:SetAttribute("InfluenceRadius", effectiveRadius * influenceMultiplier)
	end
	if type(planet:GetAttribute("SurfaceOffset")) ~= "number" then
		planet:SetAttribute("SurfaceOffset", definition.surfaceOffset or DEFAULT_SURFACE_OFFSET)
	end
	if type(planet:GetAttribute("SurfacePartName")) ~= "string" then
		planet:SetAttribute("SurfacePartName", surfacePart.Name)
	end

	local gravityCenter = planet:FindFirstChild("GravityCenter")
	if not gravityCenter then
		gravityCenter = Instance.new("Part")
		gravityCenter.Name = "GravityCenter"
		gravityCenter.Anchored = true
		gravityCenter.CanCollide = false
		gravityCenter.Transparency = 1
		gravityCenter.Size = Vector3.new(1, 1, 1)
		gravityCenter.Parent = planet
	end
	gravityCenter.Position = surfacePart.Position

	return planet
end

--[[
Funcion: createStarterPlanets

Proposito:
Genera un set inicial de planetas separados para pruebas de viaje entre mundos.

Precondiciones:
- Debe ejecutarse en servidor.

Requiere:
- Funciones ensurePlanetsFolder y ensurePlanetModel.

Devuelve:
- table con planetas generados.
]]
local function createStarterPlanets()
	local planetsFolder = ensurePlanetsFolder()
	local definitions = {
		{
			name = "Planet_A",
			position = Vector3.new(0, 0, 0),
			radius = 200,
			color = Color3.fromRGB(84, 155, 66),
			material = Enum.Material.Grass,
			gravityAccel = 120,
			influenceMultiplier = 3.4,
			surfaceOffset = 3.9,
		},
		{
			name = "Planet_B",
			position = Vector3.new(900, 120, 0),
			radius = 75,
			color = Color3.fromRGB(214, 178, 122),
			material = Enum.Material.Sand,
			gravityAccel = 105,
			influenceMultiplier = 3.1,
			surfaceOffset = 3.6,
		},
		{
			name = "Planet_C",
			position = Vector3.new(1720, -60, 260),
			radius = 130,
			color = Color3.fromRGB(120, 128, 170),
			material = Enum.Material.Slate,
			gravityAccel = 138,
			influenceMultiplier = 3.0,
			surfaceOffset = 4.2,
		},
	}

	local created = {}
	for _, definition in ipairs(definitions) do
		local planet = planetsFolder:FindFirstChild(definition.name)
		if not planet then
			planet = Instance.new("Model")
			planet.Name = definition.name
			planet.Parent = planetsFolder

			local sphere = Instance.new("Part")
			sphere.Name = "Sphere"
			sphere.Shape = Enum.PartType.Ball
			sphere.Anchored = true
			sphere.Size = Vector3.new(definition.radius * 2, definition.radius * 2, definition.radius * 2)
			sphere.Material = definition.material
			sphere.Color = definition.color
			sphere.Position = definition.position
			sphere.Parent = planet
		end

		local configured = ensurePlanetModel(planet, definition)
		if configured then
			table.insert(created, configured)
		end
	end

	return created
end

--[[
Funcion: configureExistingPlanets

Proposito:
Configura planetas ya creados manualmente en Workspace/Planets sin regenerar geometria.

Precondiciones:
- Workspace/Planets debe existir.

Requiere:
- Planetas de tipo Model.

Devuelve:
- table con planetas configurados.
]]
local function configureExistingPlanets()
	local planetsFolder = ensurePlanetsFolder()
	local configured = {}
	for _, child in ipairs(planetsFolder:GetChildren()) do
		if child:IsA("Model") then
			local result = ensurePlanetModel(child, {})
			if result then
				table.insert(configured, result)
			end
		end
	end
	return configured
end

local planets = configureExistingPlanets()
if AUTO_CREATE_STARTER_PLANETS and #planets == 0 then
	planets = createStarterPlanets()
end

print(string.format("PlanetBootstrap: %d planetas listos en Workspace/Planets", #planets))
