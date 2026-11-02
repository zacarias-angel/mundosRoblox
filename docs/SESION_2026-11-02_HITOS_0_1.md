# Sesión de recuperación — 2026-11-02

Plan vigente: [PLAN_MAESTRO_ALPHA.md](PLAN_MAESTRO_ALPHA.md).
Place: `135994156281921`, primer mundo recorrible.
Alcance de hoy: hitos 0 y 1. **Arena/reubicación del combate dentro del mismo place: punto crítico P0.**

Estado del registro: **hitos 0 y 1 cerrados para esta etapa, con verificación de gameplay en Studio. Play detenido y viewport por defecto restaurado.**

## Decisiones cerradas con el creador

- Iniciales: SlimeFuego, LoboAgua, TortugaPlanta, HalconElectrico y GolemRoca.
- Capturables: FireBaby, Demonslime1 y Bloompup.
- Zonas: Forestal y Volcánica.
- Sin consumo de energía durante alpha; balance de alimento congelado hoy.
- Objetivo: escritorio, móvil horizontal y ocho jugadores por servidor.
- Hoy no se inicia persistencia avanzada, stats por nivel ni producción del catálogo.

## Respaldos y recuperación

- ZIP original conservado: `mundosRoblox.zip`. Contiene el CombatServer monolítico con el PvE previo.
- Respaldo interno: `ServerStorage/RecoveryBackups/Before_Hitos_0_1_2026_11_02`.
- Exportación local previa: `backups/before_hitos_0_1_2026_11_02/`: 31 fuentes Luau y manifiesto de jerarquía/escena.
- Exportación final: `backups/after_hitos_0_1_2026_11_02/`: 34 fuentes Luau y manifiesto final. Incluye ArenaService, CombatSettings y ArenaControls nuevos.
- Las fuentes corresponden al estado anterior a modificar; el respaldo interno contiene instancias clonadas con scripts desactivados.
- El manifiesto de escena guarda estructura y referencias; **no es un archivo `.rbxl` ni incluye mallas binarias**. El snapshot excluye Camera y los voxels de Terrain.
- Para revertir código: buscar la fuente por ruta en el manifiesto o el script equivalente del snapshot y restaurar `Source` en el original. Revisar el atributo `RecoveryOriginalDisabled` antes de reactivar un clon. No activar todo el respaldo simultáneamente.
- Guardar el place desde Studio conserva escena, arena y respaldo interno. No se publicó una nueva versión del juego.

## Cambios implementados

### Combate

- `MonsterDuel`: reconstrucción PvE usando el monolito como referencia, contratos del cliente actual y limpieza idempotente.
- Reserva del salvaje original; no se mueve del mundo. La arena usa un clon visual sin prompts/scripts.
- Inicio, countdown, IA, HP, captura/fragmentos/Bits, victoria, derrota, cancelación y timeout.
- Restauración del compañero seleccionado; cancelación/respawn no entregan premio.
- `GridResolver`: validar ruta → aplicar swaps → resolver cascadas → resumir elementos → calcular daño con `calculateTeamDamage`.
- Callback en `CombatGrid.resolveBoard` para resumir elementos antes de eliminar las fichas.
- Un turno activo por jugador; validación de fin de duelo después de esperas; revisión de tablero e ID de duelo para rechazar mensajes obsoletos.
- Payloads acotados a 128 pasos, enteros finitos y celdas adyacentes.
- Mutación del equipo sobre copia y bloqueo de acciones de roster durante combate.
- Limpieza de perfil/compañeros al desconectar. PvP competitivo queda desactivado por defecto en esta build de recuperación.

### Arena: punto crítico

- `ArenaService` y `Workspace/CombatArenas`: ocho espacios con origen `(5000, 1000, 0)` y separación de 240 studs.
- Siete piezas estáticas por espacio: plataforma, cuatro bordes y dos pads. Se evita generar escenarios grandes por combate.
- Arenas persistentes para streaming; cada combate añade solo los visuales necesarios.
- Captura del CFrame/estado original del personaje; retorno y restauración de movilidad/anclaje al salir.
- Foco de replicación temporal en el punto de origen mediante AddReplicationFocus/RemoveReplicationFocus, para mantener cargada la zona de retorno.
- El controlador de gravedad cede movimiento y cámara durante la arena; vuelve a resolver el planeta al salir.
- Cámara lateral fija y tablero que se ajusta al viewport.
- Botón de salida accesible desde cliente; el servidor cancela sin recompensa.
- El cupo y la separación están implementados; esto **no sustituye una prueba con ocho clientes reales** ni constituye perfilado de rendimiento.

### Presentación y configuración

- `CombatUI`: protocolo ID/revisión, bloqueo mientras resuelve, máximos de HP reales, cancelación de animaciones tardías y reseteo de drag.
- Corrección de tablero recortado y pointer/ghost; ajuste móvil horizontal y estado de cancelación.
- `ArenaControls`: botón de salida, tamaño 144×44.
- `CombatSettings`: defaults de recuperación y snapshot por duelo. ConfigService opcional, desactivado por atributo `UseExperienceConfigs=false` mientras no haya claves publicadas.
- `StarterGui.ScreenOrientation=LandscapeSensor` acorde al objetivo móvil aprobado.
- Demonslime2 recibe ID válido `Demonslime1` para no iniciar encuentros con datos inexistentes.
- El catálogo inicial y el inventario visual completo se alinean en los hitos posteriores; elegir ocho especies no produjo ocho modelos terminados hoy.

## Pruebas y hallazgos

### Primeras pasadas

- Jugada real con mouse: cambió revisión y redujo HP del rival.
- Victoria acelerada para revisar cierre/premio; 120 Bits por Demon Slime, un compañero al volver.
- Cancelación: CFrame exacto al instante de retorno, sin Bits adicionales y conservando compañero seleccionado.
- Derrota por ataque NPC con vida de prueba reducida: retorno y limpieza correctos.
- Respawn durante duelo y nuevo combate posterior: limpieza y compañero recuperados.
- Payloads inválidos y cupo de arena: rechazados sin modificar tablero ni exceder ocho leases.
- Un primer solver de QA solo probaba swaps de dos celdas y no podía resolver todos los tableros. Se corrigió el harness para generar rutas legales de arrastre; no se confundió ese límite del solver con un fallo del combate.
- La pasada de vida completa ganó, pero mostró que la IA podía perder todos sus turnos si el jugador encadenaba resoluciones. Se corrigió para esperar el fin de la resolución y ejecutar el ataque pendiente, sin reiniciar el intervalo.
- Se añadió protección de streaming del retorno después de esas primeras pasadas; requiere la validación final de esta sesión.

### Validación final

Evidencia exportada: `backups/qa_hito1_final_2026_11_02/manifest.json` y tres fuentes de los scripts temporales de QA.

| Prueba | Resultado observado |
|---|---|
| Prompt real con E | Inicia duelo, posiciona en arena y habilita combate tras countdown |
| Arrastre real con mouse | Revisión 1 y daño autoritativo al rival; en una pasada: HP 17500 → 16910 |
| Victoria común con HP normal | FireBaby, 8 turnos automatizados mediante rutas legales; enemigo 0 HP, jugador 13875 HP |
| Premio de esa victoria | 50 Bits; segunda llamada de fin no repite recompensa |
| Derrota rara con HP normal | Demon Slime, 18 turnos; jugador 0 HP, rival 190 HP; retorno sin recompensa. Balance pendiente de hito 2 |
| Combate consecutivo | Otro encuentro se inicia y termina sin atasco |
| Cancelación por botón | Regreso al mundo, sin anclaje ni Bits nuevos |
| Cancelación exacta | CFrame de retorno coincide al instante con el registrado; sin focos de streaming sobrantes |
| Cancelar durante resolución | La tarea tardía no aplica daño/premio ni deja bloqueo |
| Submit duplicado | Revisión aumenta una vez, no dos |
| Payloads inválidos | Seis casos rechazados sin cambiar tablero: rango, adyacencia, NaN, campo faltante, duelo obsoleto y longitud excesiva |
| Cupo de arena | Ocho leases como máximo; el noveno falla sin crear otra arena |
| Muerte y respawn automático | Se limpia el duelo y reaparece el compañero |
| Respawn solicitado durante duelo | Estado y arena liberados; nuevo combate posterior posible |
| Desconexión durante duelo | Kick local: jugador/estado/duelo liberados, reserva retirada, carpeta de mascotas eliminada, 0 focos y ocho slots disponibles |

La derrota rara prueba el camino de derrota; no se alteró el balance para convertir ese caso en victoria. El harness definitivo valida victoria con un encuentro común, que es el recorrido inicial previsto.

### Pantalla y controles

- Ajuste probado en viewport de escritorio reducido y emulación **iPhone 17 Pro horizontal**.
- Configuración de juego: LandscapeSensor. CombatUI usa IgnoreGuiInset y DeviceSafeInsets.
- Medición de cliente en emulación: viewport 750×381; celdas de 45,64×45,64; botón de salida 144×44.
- Tablero visible y sin el recorte derecho de la primera pasada; salida colocada fuera del tablero.
- Emulación visual y uso de botón comprobados. Esto no acredita rendimiento ni precisión táctil en teléfono físico.
- Se restauró la simulación al viewport por defecto antes de finalizar.

### Observaciones del instrumental

- Los scripts de juego no mostraron errores de ejecución en la pasada final de gameplay.
- El intento de leer Source/exportar desde un Script normal de QA falló por capacidad de seguridad después de registrar la limpieza de desconexión. Se exportó correctamente desde el contexto de herramienta/plugin; no se trasladó ese acceso a la build.
- La primera automatización corta y la derrota rara se conservaron como evidencia de pasadas previas en sus carpetas `qa_hito1_first_pass_2026_11_02` y `qa_hito1_rare_defeat_2026_11_02`.

## Herramientas locales

- `tools/studio_snapshot_bridge.py`: puente HTTP limitado a localhost para exportar fuentes/manifiestos desde Studio. Se inicia solo durante la sesión y debe detenerse al cerrar.
- `tools/playtest_recovery.server.luau`: harness temporal de QA de gameplay, solo Studio. Se instala en el servidor de Play, usa BindableFunction en ServerStorage y desaparece al detener Play; no instala remotes de depuración en la build.
- La activación temporal de HTTP para exportaciones se restaura a su valor anterior tras cada operación.
- Al finalizar: HTTP restaurado a false, ningún script RecoveryQA en el DataModel de edición y puente local detenido.

## Cierre de hoy

- Hito 0: preparación, respaldo y decisiones completados.
- Hito 1: recuperación PvE y arena verificada en Studio, incluida limpieza de casos borde.
- Play detenido; viewport por defecto restaurado; orientación del juego conservada en horizontal.
- Fuentes anteriores, fuentes finales y evidencia de QA disponibles en disco.
- Se detiene el trabajo aquí: no se inicia hito 2 hoy.

## Pendientes que pertenecen a los siguientes hitos

- Persistencia protegida y prueba en servidor publicado: hito 2.
- Stats efectivos por nivel y balance definitivo: hito 2.
- Catálogo de ocho criaturas, spawns y producción visual: hito 3.
- Pruebas con ocho jugadores, dispositivo físico, red y perfilado: hito 4.
- Iconos/rigs definitivos y pulido artístico de arena/aldea: posteriores a recuperación funcional.
- Guardado del place en Studio antes de cerrar la aplicación; las exportaciones de fuentes son un respaldo adicional.
