-- Tipo: ModuleScript
-- Ubicacion: ReplicatedStorage > Modules
-- Se ejecuta en: Compartido
-- Nombre sugerido: PlanetGravityMath

local PlanetGravityMath = {}

--[[
Funcion: getGravityDirection

Proposito:
Calcula direccion unitaria desde el jugador hacia el centro de gravedad.

Precondiciones:
- hrpPosition y centerPosition deben ser Vector3 validos.

Requiere:
- Distancia mayor a cero entre ambas posiciones.

Devuelve:
- Vector3 unitario apuntando al centro.
]]
function PlanetGravityMath.getGravityDirection(hrpPosition, centerPosition)
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
- worldMove y upVector deben ser Vector3 validos.

Requiere:
- upVector no debe ser cero.

Devuelve:
- Vector3 en tangente.
]]
function PlanetGravityMath.projectOnTangent(worldMove, upVector)
	return worldMove - upVector * worldMove:Dot(upVector)
end

return PlanetGravityMath
