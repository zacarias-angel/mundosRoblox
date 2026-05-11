-- Tipo: ModuleScript
-- Ubicación: ReplicatedStorage/Modules/Debug
-- Contexto: Compartido

--[[
    Módulo de debug centralizado.
    En producción cambiar MODO_DEBUG a false para silenciar todos los logs.

    USO:
        local Debug = require(ReplicatedStorage.Modules.Debug)
        Debug.log("MiScript", "mensaje de prueba")
        Debug.warn("MiScript", "advertencia")
        Debug.err("MiScript",  "error crítico")

    NIVELES:
        log  → información general (azul en consola)
        warn → advertencias (amarillo)
        err  → errores críticos (rojo, siempre visible aunque MODO_DEBUG = false)
]]

local Debug = {}

-- ============================================================
-- CONFIGURACIÓN
-- ============================================================
local MODO_DEBUG = true    -- ← poner false en producción para silenciar logs/warns

-- ============================================================
-- API PÚBLICA
-- ============================================================

function Debug.log(origen, mensaje, ...)
    -- Propósito: Imprimir un mensaje informativo en la consola de Roblox Studio.
    -- Precondiciones:
    --   1. MODO_DEBUG debe ser true para que el mensaje sea visible.
    --   2. origen y mensaje deben ser strings no vacíos.
    -- Ubicación: ReplicatedStorage/Modules/Debug
    -- Retorna: nil

    if not MODO_DEBUG then return end
    local extra = ... and tostring(...) or ""
    print(string.format("[DEBUG][%s] %s %s", origen, tostring(mensaje), extra))
end

function Debug.warn(origen, mensaje, ...)
    -- Propósito: Imprimir una advertencia en la consola de Roblox Studio.
    -- Precondiciones:
    --   1. MODO_DEBUG debe ser true para que la advertencia sea visible.
    -- Ubicación: ReplicatedStorage/Modules/Debug
    -- Retorna: nil

    if not MODO_DEBUG then return end
    local extra = ... and tostring(...) or ""
    warn(string.format("[WARN][%s] %s %s", origen, tostring(mensaje), extra))
end

function Debug.err(origen, mensaje, ...)
    -- Propósito: Imprimir un error en la consola. Siempre visible,
    --            independientemente de MODO_DEBUG, porque es crítico.
    -- Precondiciones:
    --   1. origen y mensaje deben ser strings no vacíos.
    -- Ubicación: ReplicatedStorage/Modules/Debug
    -- Retorna: nil

    local extra = ... and tostring(...) or ""
    warn(string.format("[ERROR][%s] %s %s", origen, tostring(mensaje), extra))
end

return Debug
