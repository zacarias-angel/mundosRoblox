-- Tipo: ModuleScript
-- Ubicacion: ReplicatedStorage > Modules
-- Se ejecuta en: Compartido
-- Nombre sugerido: PlanetRegistry

local PlanetRegistry = {}

local DEFAULT_INFLUENCE_MULTIPLIER = 3.2
local DEFAULT_GRAVITY_ACCEL = 120
local DEFAULT_SURFACE_OFFSET = 3.9

--[[
Funcion: isPlanetModel

Proposito:
Valida si un modelo tiene la estructura minima para comportarse como planeta.

Precondiciones:
- model puede ser nil.

Requiere:
- Ninguno.

Devuelve:
- boolean.
]]
function PlanetRegistry.isPlanetModel(model)
	if not model or not model:IsA("Model") then
		return false
	end
	return model:FindFirstChild("GravityCenter") ~= nil and PlanetRegistry.getPlanetSurfacePart(model) ~= nil
end

--[[
Funcion: getPlanetSurfacePart

Proposito:
Obtiene el BasePart que representa la superficie del planeta (MeshPart o Part).

Precondiciones:
- model valido.

Requiere:
- Puede usar atributo SurfacePartName, Sphere, PrimaryPart o parte de mayor volumen.

Devuelve:
- BasePart o nil.
]]
function PlanetRegistry.getPlanetSurfacePart(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local preferredName = model:GetAttribute("SurfacePartName")
	if type(preferredName) == "string" and preferredName ~= "" then
		local preferred = model:FindFirstChild(preferredName, true)
		if preferred and preferred:IsA("BasePart") then
			return preferred
		end
	end

	local sphere = model:FindFirstChild("Sphere", true)
	if sphere and sphere:IsA("BasePart") then
		return sphere
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	local bestPart = nil
	local bestVolume = -1
	for _, descendant in ipairs(model:GetDescendants()) do
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
Funcion: getPlanetRadius

Proposito:
Obtiene el radio de la esfera principal del planeta.

Precondiciones:
- model debe tener un Part llamado Sphere.

Requiere:
- Sphere de tipo BasePart.

Devuelve:
- number (radio) o nil.
]]
function PlanetRegistry.getPlanetRadius(model)
	local surfacePart = PlanetRegistry.getPlanetSurfacePart(model)
	if not surfacePart then
		return nil
	end
	return math.max(surfacePart.Size.X, surfacePart.Size.Y, surfacePart.Size.Z) * 0.5
end

--[[
Funcion: getInfluenceRadius

Proposito:
Obtiene radio de influencia gravitatoria del planeta.

Precondiciones:
- model valido.

Requiere:
- Atributo InfluenceRadius opcional.

Devuelve:
- number (radio de influencia).
]]
function PlanetRegistry.getInfluenceRadius(model)
	local attr = model and model:GetAttribute("InfluenceRadius")
	if type(attr) == "number" and attr > 0 then
		return attr
	end

	local radius = PlanetRegistry.getPlanetRadius(model)
	if not radius then
		return 0
	end
	return radius * DEFAULT_INFLUENCE_MULTIPLIER
end

--[[
Funcion: getGravityAccel

Proposito:
Obtiene aceleracion de gravedad configurada por planeta.

Precondiciones:
- model valido.

Requiere:
- Atributo GravityAccel opcional.

Devuelve:
- number.
]]
function PlanetRegistry.getGravityAccel(model)
	local attr = model and model:GetAttribute("GravityAccel")
	if type(attr) == "number" and attr > 0 then
		return attr
	end
	return DEFAULT_GRAVITY_ACCEL
end

--[[
Funcion: getSurfaceOffset

Proposito:
Obtiene el offset objetivo sobre la superficie para posicion del personaje.

Precondiciones:
- model valido.

Requiere:
- Atributo SurfaceOffset opcional.

Devuelve:
- number.
]]
function PlanetRegistry.getSurfaceOffset(model)
	local attr = model and model:GetAttribute("SurfaceOffset")
	if type(attr) == "number" and attr >= 0 then
		return attr
	end
	return DEFAULT_SURFACE_OFFSET
end

--[[
Funcion: collectPlanets

Proposito:
Recolecta todos los planetas validos desde Workspace.Planets y fallback legacy Workspace.Planet.

Precondiciones:
- workspaceRef valido.

Requiere:
- Carpeta Workspace > Planets opcional.

Devuelve:
- table con modelos de planeta.
]]
function PlanetRegistry.collectPlanets(workspaceRef)
	local planets = {}
	local planetsFolder = workspaceRef:FindFirstChild("Planets")
	if planetsFolder and planetsFolder:IsA("Folder") then
		for _, child in ipairs(planetsFolder:GetChildren()) do
			if PlanetRegistry.isPlanetModel(child) then
				table.insert(planets, child)
			end
		end
	end

	local legacyPlanet = workspaceRef:FindFirstChild("Planet")
	if legacyPlanet and PlanetRegistry.isPlanetModel(legacyPlanet) then
		table.insert(planets, legacyPlanet)
	end

	return planets
end

--[[
Funcion: getBestPlanetForPosition

Proposito:
Devuelve el planeta activo para una posicion considerando prioridad por zona de influencia.

Precondiciones:
- position debe ser Vector3.
- workspaceRef debe ser Workspace.

Requiere:
- Planetas con GravityCenter y Sphere.

Devuelve:
- table o nil con:
  model, gravityCenter, sphere, radius, influenceRadius, gravityAccel, surfaceOffset, centerDistance.
]]
function PlanetRegistry.getBestPlanetForPosition(position, workspaceRef)
	local planets = PlanetRegistry.collectPlanets(workspaceRef)
	local best = nil
	local bestDistanceToSurface = math.huge

	for _, model in ipairs(planets) do
		local gravityCenter = model:FindFirstChild("GravityCenter")
		local surfacePart = PlanetRegistry.getPlanetSurfacePart(model)
		if gravityCenter and gravityCenter:IsA("BasePart") and surfacePart then
			local radius = PlanetRegistry.getPlanetRadius(model)
			if radius and radius > 0 then
				local centerDistance = (position - gravityCenter.Position).Magnitude
				local influenceRadius = PlanetRegistry.getInfluenceRadius(model)
				if centerDistance <= influenceRadius then
					local distanceToSurface = math.abs(centerDistance - radius)
					if distanceToSurface < bestDistanceToSurface then
						bestDistanceToSurface = distanceToSurface
						best = {
							model = model,
							gravityCenter = gravityCenter,
							sphere = surfacePart,
							radius = radius,
							influenceRadius = influenceRadius,
							gravityAccel = PlanetRegistry.getGravityAccel(model),
							surfaceOffset = PlanetRegistry.getSurfaceOffset(model),
							centerDistance = centerDistance,
						}
					end
				end
			end
		end
	end

	return best
end

return PlanetRegistry
