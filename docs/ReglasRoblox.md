--[[
========================================================
ESTÁNDAR INTERNO DE DESARROLLO
Proyecto en Roblox
Cumplimiento: OBLIGATORIO
========================================================

OBJETIVO:
Establecer reglas claras para estructurar, sugerir y desarrollar scripts,
animaciones, sistemas, UI/UX y lógica de servidor.

========================================================
1. ESTRUCTURA OFICIAL DE CARPETAS
========================================================

ReplicatedStorage/
├── Models/
├── Modules/
├── RemoteEvents/
└── Shared/

ServerScriptService/

StarterPlayer/
├── StarterPlayerScripts/
└── StarterCharacterScripts/

REGLAS:

• Models/ → Modelos reutilizables.
• Modules/ → ModuleScripts compartidos.
• RemoteEvents/ → Eventos cliente-servidor.
• Shared/ → Configuración global, constantes, versiones.

• ServerScriptService → SOLO lógica del servidor.
• StarterPlayerScripts → UI, input, cámara, efectos locales.
• StarterCharacterScripts → Animaciones y comportamiento del personaje.

========================================================
2. OBLIGATORIO EN CADA SCRIPT
========================================================

TODOS los scripts deben iniciar con:

-- Tipo: Script / LocalScript / ModuleScript
-- Ubicación: Ruta exacta
-- Contexto: Cliente / Servidor / Compartido

Si no está esta información → NO ES VÁLIDO.

========================================================
3. DOCUMENTACIÓN OBLIGATORIA EN CADA FUNCIÓN
========================================================

Cada función debe incluir dentro:

-- Propósito:
-- Precondiciones:
-- Ubicación:
-- Retorna: (si aplica)

Ejemplo:

local function ejemplo(parametro)
    -- Propósito: Explicar claramente qué hace.
    -- Precondiciones:
    --   1. parametro debe ser válido.
    --   2. Debe ejecutarse en el servidor.
    -- Ubicación: Ruta del script
    -- Retorna: número / boolean / nil
end

Sin documentación → No aprobado.

========================================================
4. REGLAS DE SEGURIDAD
========================================================

PRINCIPIO:

EL CLIENTE NUNCA TIENE AUTORIDAD.

• Nunca confiar en valores enviados por cliente.
• Todo debe validarse en servidor.
• Nunca dar recompensas desde LocalScript.
• Validar rangos numéricos.
• Validar existencia de objetos.
• Validar ownership del jugador.

RemoteEvents:
• Siempre en ReplicatedStorage/RemoteEvents.
• Siempre validados en ServerScriptService.
• Nunca ejecutar lógica crítica sin validación.

========================================================
5. CREACIÓN DE ELEMENTOS
========================================================

• Visual puro → Cliente.
• Afecta gameplay real → Servidor.
• Compartido → ReplicatedStorage.

========================================================
6. ANIMACIONES
========================================================

• Reproducción local → StarterCharacterScripts.
• Efecto con impacto real → Validación en servidor.

Siempre documentar propósito y precondiciones.

========================================================
7. UI / UX
========================================================

• UI siempre en StarterPlayerScripts.
• Separar:
    - Controlador UI
    - Lógica
    - Configuración

• No mezclar lógica crítica con UI.

========================================================
8. MODULES
========================================================

• Todo sistema grande debe modularizarse.
• No usar variables globales.
• Retornar tabla estructurada.
• No colocar validaciones críticas compartidas sin revalidar en servidor.

========================================================
9. CONVENCIONES DE CÓDIGO
========================================================

• Variables → camelCase
• Modules → PascalCase
• Constantes → MAYUSCULAS
• No usar wait() → usar task.wait()
• No usar spawn() → usar task.spawn()
• No usar prints en producción (usar módulo de debug)

========================================================
10. REGLA DE ORO
========================================================

Si un exploit puede abusarlo,
entonces está mal implementado.

========================================================
CHECKLIST FINAL ANTES DE ENTREGAR
========================================================

[ ] Tipo de script aclarado
[ ] Ubicación aclarada
[ ] Contexto aclarado
[ ] Funciones documentadas
[ ] Validaciones hechas
[ ] No hay lógica sensible en cliente
[ ] RemoteEvents validados
[ ] Código modular
[ ] Nombres consistentes
[ ] Sin prints innecesarios

========================================================
FIN DEL DOCUMENTO
========================================================
]]