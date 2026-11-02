-- Tipo: Script
-- Ubicacion: ServerScriptService
-- Se ejecuta en: Servidor
-- Nombre sugerido: PlanetGravityServer

--[[
Funcion: initGlobalGravity

Proposito:
Desactiva la gravedad global para permitir gravedad personalizada.

Precondiciones:a
- Debe ejecutarse en servidor.

Requiere:
- workspace disponible.

Devuelve:
- nil
]]
local function initGlobalGravity()
	workspace.Gravity = 0
end

initGlobalGravity()
