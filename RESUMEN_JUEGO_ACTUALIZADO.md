# Resumen Del Juego Actualizado

Fecha de actualizacion: 2026-05-22

Terminologia oficial:

- Beastibit = termino general para pet/mascota/monstruo.

## 1. Vision General

El proyecto combina dos sistemas principales:

1. Combate match-3 por arrastre de fichas, con autoridad total del servidor.
2. Movimiento con gravedad planetaria personalizada para personaje.

Arquitectura actual:

- El cliente propone input y muestra animaciones/UI.
- El servidor valida acciones, resuelve logica real y sincroniza estado canonico.
- La logica de tablero y gravedad esta modularizada en ReplicatedStorage/Modules.

## 2. Inventario Actual De Scripts

## 2.1 Combate Match-3 y Duelos

- StarterPlayer/StarterPlayerScripts/CombatUI.lua
- ServerScriptService/CombatServer.server.lua
- ServerScriptService/CombatRemoteSetup.server.lua
- ServerScriptService/MonsterPromptSetup.server.lua
- ServerScriptService/Combat/TeamManager.lua
- ServerScriptService/Combat/MonsterCombat.lua
- ServerScriptService/Combat/PetCubeService.lua
- ServerScriptService/Combat/PvpStarsService.lua
- ReplicatedStorage/Modules/CombatGrid.module.lua
- ReplicatedStorage/Modules/Debug.lua
- ReplicatedStorage/GameData/MonstersData.lua

## 2.2 Gravedad Planetaria

- StarterPlayer/StarterCharacterScripts/PlanetGravityController.client
- ServerScriptService/PlanetGravityServer.server.lua
- ServerScriptService/PlanetBootstrap.server.lua
- ReplicatedStorage/Modules/PlanetGravityMath.module.lua
- ReplicatedStorage/Modules/PlanetRegistry.module

## 2.3 Referencias Antiguas (prototipo previo)

- otrojuegosimilar/boarlogi.lua
- otrojuegosimilar/celdacontroler.lua
- otrojuegosimilar/dragandrop.lua

## 3. Estado Tecnico Del Combate

## 3.1 Flujo PvP entre jugadores

Estado: FUNCIONAL

- Existe desafio por proximidad entre jugadores.
- Se valida distancia y disponibilidad de duelo en servidor.
- Hay flujo completo: challenge sent, received, accepted/declined, timeout, countdown, duel started, duel ended.
- Vida de ambos lados se calcula desde equipos de Beastibit (TeamManager + MonstersData).
- El dano se aplica desde combos procesados por el servidor, no por cliente.

## 3.2 Flujo PvE contra monstruo NPC

Estado: FUNCIONAL

- MonsterPromptSetup crea prompts en modelos marcados como monstruo.
- CombatServer detecta trigger del prompt y arranca duelo NPC.
- El NPC tiene equipo simulado de Beastibit (x5) y ataques periodicos con IA v1 equilibrada.
- El cliente recibe eventos de ataque NPC y actualiza HUD.

Detalles IA NPC v1 (combate):

- Sesgo elemental por especie: la IA prioriza el elemento base del monstruo.
- Combos por fase de HP:
  - Fase normal: rango moderado.
  - Fase de presion (HP del monstruo bajo): rango mas alto.
  - Fase de remate seguro (HP del jugador bajo): rango reducido para evitar frustracion.
- Ataque especial con cooldown por turnos: puede lanzar picos controlados de combo con enfriamiento.
- Anti-rachas: se limita repeticion de combos altos consecutivos.
- Variacion de elemento entre turnos: se reduce repeticion del mismo elemento seguidamente.

## 3.3 Motor Match-3

Estado: FUNCIONAL Y MODULAR

- Grid canonico en servidor por jugador.
- Validacion de payload de path y adyacencia.
- Aplicacion de ruta de swaps en servidor.
- Deteccion de matches horizontales/verticales.
- Eliminacion, gravedad, relleno y cascadas con safety cap.
- Resumen de combos por elemento para dano de monstruos del equipo.

## 3.4 UI y Animaciones de combate

Estado: FUNCIONAL Y PULIDO BASE

- Drag con mouse y touch.
- Preview local de swaps durante arrastre.
- Animacion secuencial de combos.
- Animacion de caida, entrada de nuevas fichas y rebote.
- Contador visual de combo progresivo.
- HUD de vida propio y rival.
- Estados visuales de countdown/inicio/fin de duelo.
- Layout tactil para movil.

## 4. Sistema De Estrellas PvP (nuevo avance)

Estado: IMPLEMENTADO

Archivo principal: ServerScriptService/Combat/PvpStarsService.lua

Funcionalidad actual:

- Leaderstats con IntValue PvpStars.
- Atributo PvpStars en player.
- Persistencia con DataStore PvpStarsV1 (carga al entrar, guardado al salir).
- Regla de ranking PvP:
  - Victoria PvP por hp-depleted: +1 estrella.
  - Derrota PvP por hp-depleted: -1 estrella (con minimo 0).
- Integrado en CombatServer.endDuel para que aplique solo en PvP real.

Visual del contador:

- Se muestra como texto "star + N deg + numero" en SurfaceGui doble cara.
- Se monta sobre una parte invisible (PvpShoulderCounterPart).
- Follow usando WeldConstraint a parte estable del personaje (HumanoidRootPart con fallback).

Nota de estado:

- Este sistema ya existe y esta integrado al ciclo PlayerAdded/PlayerRemoving en CombatServer.

## 5. Estado Tecnico De Gravedad Planetaria

## 5.1 Servidor

- PlanetGravityServer pone workspace.Gravity = 0.
- PlanetBootstrap asegura Workspace/Planets.
- Si no hay planetas, genera Planet_A, Planet_B, Planet_C para pruebas.
- Configura atributos por planeta: GravityAccel, InfluenceRadius, SurfaceOffset, SurfacePartName.

## 5.2 Cliente (controlador)

- PlanetGravityController controla movimiento por fisica custom.
- Usa PlanetRegistry para planeta activo por influencia.
- Usa PlanetGravityMath para direccion de gravedad y tangente.
- Tiene fallback interno si los modulos no cargan al inicio.
- Incluye camara orbital, locomocion custom, salto, modo fly de test y logs de debug.

## 5.3 Modulos

- PlanetRegistry resuelve superficie, radio, influencia y planeta activo mas cercano a superficie.
- PlanetGravityMath concentra calculos vectoriales base.

## 6. Mejoras Recientes Confirmadas

1. Integracion de ranking PvP por estrellas dentro del resultado real de duelos.
2. Nueva capa visual de contador de estrellas sobre personaje para todos los jugadores.
3. Ajustes de posicion/rotacion del contador de estrellas para mejorar lectura.
4. Cambio de seguimiento del contador hacia patron soldado (tipo pet) para reducir delay.
5. Integracion de PvpStarsService dentro de CombatServer en alta y baja de jugadores.
6. IA NPC de combate v1 implementada con sesgo elemental, fases por HP, especial con cooldown y anti-rachas.

## 7. Lo Que Falta O Requiere Pulido

## 7.1 Combate

- Sincronizar aun mas fino el combo visual con cada sub-evento de cascada.
- Conectar dano/recompensas a sistema de progreso real (economia, inventario, nivel).
- Definir reglas de ranking para casos especiales:
  - desconexion en duelo
  - abandono
  - empate
- Balancear dano de MonsterCombat por stats y elementos.
- Afinar parametros de IA NPC v1 con telemetria (chances, cooldown, umbrales de HP y rangos de combo).

## 7.2 Estrellas PvP

- Afinar posicion exacta final del contador en todos los rigs (R6/R15, escalas distintas).
- Preparar capa VFX de estrellas (particulas, glow, feedback al subir/bajar).
- Considerar anti-spam y protecciones de write para DataStore a gran escala.

## 7.3 Gravedad planetaria

- Revisar y reducir logs de debug para produccion.
- Ajustar transiciones entre planetas para viajes largos y casos borde.
- Validar rendimiento en movil con varios planetas y mas jugadores.

## 7.4 Estructura y estandar

- Todavia hay scripts con print/warn directos en vez de pasar por modulo Debug.
- Existen scripts legacy en otrojuegosimilar que conviene archivar formalmente o mover a carpeta de referencia documentada.
- Conviene actualizar documentacion principal para reflejar el sistema de estrellas PvP ya implementado.

## 8. Riesgos Tecnicos Detectados

1. Persistencia DataStore: no hay estrategia de reintentos/cola para fallos temporales.
2. Logging en produccion: alto ruido de consola en varios scripts.
3. Complejidad creciente de CombatServer: conviene separar en sub-modulos (duelos, NPC, damage, sync).
4. PlanetGravityController es robusto pero largo; mantenimiento puede complicarse sin separar en modulos cliente.

## 9. Resumen Ejecutivo

Estado general del proyecto: SOLIDO Y JUGABLE.

- Combate match-3: funcional en servidor/cliente, con cascadas y animaciones.
- Duelos PvP/PvE: funcionales con estados completos.
- Gravedad planetaria: funcional con sistema avanzado de movimiento y camara.
- Nuevo progreso PvP por estrellas: implementado e integrado.

Siguiente foco recomendado:

1. Pulido final del contador de estrellas (anclaje visual perfecto en movimiento).
2. VFX/feedback de progreso PvP.
3. Limpieza de arquitectura y documentacion para escalar contenido.
