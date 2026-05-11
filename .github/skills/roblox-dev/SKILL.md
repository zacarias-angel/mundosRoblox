---
name: roblox-dev
description: "Estándar interno de desarrollo para proyectos Roblox. Usar cuando: crear scripts Lua, LocalScripts, ModuleScripts, animaciones, UI, RemoteEvents, sistemas de servidor o cliente en Roblox Studio. Aplica estructura de carpetas, cabecera obligatoria, documentación de funciones, seguridad cliente-servidor, convenciones de código y checklist final."
argument-hint: "Describe el sistema o script que quieres crear (ej: sistema de monedas, UI de inventario, animación de ataque)"
---

# Roblox Dev — Estándar Interno

## Cuándo usar este skill

- Crear o revisar cualquier Script / LocalScript / ModuleScript
- Diseñar sistemas de RemoteEvents
- Implementar UI, animaciones o lógica de gameplay
- Revisar código existente contra el estándar

---

## Estructura oficial de carpetas

```
ReplicatedStorage/
├── Models/        ← Modelos reutilizables
├── Modules/       ← ModuleScripts compartidos (PascalCase)
├── RemoteEvents/  ← Eventos cliente-servidor
└── Shared/        ← Config global, constantes, versiones

ServerScriptService/   ← SOLO lógica de servidor

StarterPlayer/
├── StarterPlayerScripts/      ← UI, input, cámara, efectos locales
└── StarterCharacterScripts/   ← Animaciones y comportamiento del personaje
```

---

## Procedimiento paso a paso

### 1. Determinar tipo y ubicación

Antes de escribir código, clasificar:

| ¿Qué hace? | Tipo | Ubicación |
|---|---|---|
| Solo visual / UI | LocalScript | StarterPlayerScripts |
| Animación del personaje | LocalScript | StarterCharacterScripts |
| Lógica de gameplay real | Script | ServerScriptService |
| Lógica compartida reutilizable | ModuleScript | ReplicatedStorage/Modules/ |
| Evento cliente↔servidor | RemoteEvent | ReplicatedStorage/RemoteEvents/ |

### 2. Cabecera obligatoria (TODOS los scripts)

```lua
-- Tipo: Script / LocalScript / ModuleScript
-- Ubicación: Ruta/Exacta/Del/Script
-- Contexto: Cliente / Servidor / Compartido
```

Sin esta cabecera → **NO ES VÁLIDO**.

### 3. Documentar cada función

```lua
local function nombreFuncion(parametro)
    -- Propósito: Qué hace exactamente esta función.
    -- Precondiciones:
    --   1. parametro debe ser válido y no nil.
    --   2. Debe ejecutarse en el servidor.
    -- Ubicación: Ruta/Del/Script
    -- Retorna: tipo / nil
end
```

Sin documentación → **No aprobado**.

### 4. Aplicar reglas de seguridad

**EL CLIENTE NUNCA TIENE AUTORIDAD.**

- Nunca confiar en valores enviados por cliente sin validar en servidor
- Nunca dar recompensas / modificar estado desde LocalScript
- Validar en servidor: rangos numéricos, existencia de objetos, ownership del jugador
- RemoteEvents: siempre en `ReplicatedStorage/RemoteEvents/`, siempre validados en `ServerScriptService`

```lua
-- ✅ CORRECTO — validación en servidor
remoteEvent.OnServerEvent:Connect(function(player, valor)
    -- Propósito: Validar y procesar petición del cliente.
    -- Precondiciones: valor debe ser número positivo, player debe existir.
    -- Ubicación: ServerScriptService/NombreScript
    if typeof(valor) ~= "number" or valor <= 0 or valor > MAX_VALOR then return end
    -- lógica segura aquí
end)

-- ❌ INCORRECTO — nunca ejecutar lógica crítica en cliente
remoteEvent.OnClientEvent:Connect(function(recompensa)
    darRecompensa(recompensa) -- PROHIBIDO
end)
```

### 5. Reglas por sistema

**Animaciones**
- Reproducción local → `StarterCharacterScripts`
- Efecto con impacto real en gameplay → validación adicional en servidor

**UI / UX**
- Siempre en `StarterPlayerScripts`
- Separar: Controlador UI / Lógica / Configuración
- No mezclar lógica crítica con UI
- **NO crear UI desde script con imágenes hardcodeadas** → Solicitar al usuario que suba la imagen a Roblox y proporcione el Asset ID, o usar un placeholder (`rbxassetid://0`) hasta que se entregue

**Modules**
- Todo sistema grande → modularizar en `ReplicatedStorage/Modules/`
- No usar variables globales
- Retornar tabla estructurada
- No poner validaciones críticas compartidas sin revalidar en servidor

### 6. Convenciones de código

| Elemento | Convención |
|---|---|
| Variables | `camelCase` |
| Módulos | `PascalCase` |
| Constantes | `MAYUSCULAS` |
| Esperas | `task.wait()` (nunca `wait()`) |
| Hilos | `task.spawn()` (nunca `spawn()`) |
| Debug | Módulo de debug (nunca `print()` en producción) |

---

## Regla de oro

> Si un exploit puede abusarlo, está mal implementado.

---

## Checklist final (verificar antes de entregar)

```
[ ] Tipo de script aclarado en cabecera
[ ] Ubicación aclarada en cabecera
[ ] Contexto aclarado en cabecera
[ ] Todas las funciones documentadas (Propósito / Precondiciones / Ubicación / Retorna)
[ ] Validaciones de seguridad en servidor
[ ] No hay lógica sensible en cliente
[ ] RemoteEvents validados server-side
[ ] Código modularizado si el sistema es grande
[ ] Nombres en convención correcta (camelCase / PascalCase / MAYUSCULAS)
[ ] Sin prints innecesarios en producción
[ ] UI sin imágenes hardcodeadas (se solicitó Asset ID o se usó placeholder)
```
