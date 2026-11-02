-- Tipo: ModuleScript
-- Ubicacion: ReplicatedStorage > Modules
-- Se ejecuta en: Compartido
-- Nombre sugerido: PlanetGravityMath

local PlanetGravityMath = {}

--[[
Funcion: validateVector

Proposito:
Valida que un Vector3 sea válido y no tenga magnitud cero.

Precondiciones:
- vector debe ser un Vector3.

Devuelve:
- boolean indicando si el vector es válido.
]]
local function validateVector(vector)
	return typeof(vector) == "Vector3" and vector.Magnitude > 1e-5
end

--[[
Funcion: getGravityDirection

Proposito:
Calcula direccion unitaria desde el jugador hacia el centro de gravedad.

Precondiciones:
- hrpPosition y centerPosition deben ser Vector3 válidos.

Requiere:
- Distancia mayor a cero entre ambas posiciones.

Devuelve:
- Vector3 unitario apuntando al centro o Vector3.zero si no es válido.
]]
function PlanetGravityMath.getGravityDirection(hrpPosition, centerPosition)
	if not validateVector(hrpPosition) or not validateVector(centerPosition) then
		warn("PlanetGravityMath: Posiciones inválidas en getGravityDirection")
		return Vector3.zero
	end

	local offset = centerPosition - hrpPosition
	if offset.Magnitude < 1e-5 then
		return Vector3.new(0, -1, 0)
	end
	return offset.Unit
end

--[[
Funcion: projectOnTangent

Proposito:
Proyecta un vector en el plano tangente definido por upVector.

Precondiciones:
- worldMove y upVector deben ser Vector3 válidos.

Requiere:
- upVector no debe ser cero.

Devuelve:
- Vector3 en tangente o Vector3.zero si no es válido.
]]
function PlanetGravityMath.projectOnTangent(worldMove, upVector)
	if not validateVector(worldMove) or not validateVector(upVector) then
		warn("PlanetGravityMath: Vectores inválidos en projectOnTangent")
		return Vector3.zero
	end

	return worldMove - upVector * worldMove:Dot(upVector)
end

return PlanetGravityMath
