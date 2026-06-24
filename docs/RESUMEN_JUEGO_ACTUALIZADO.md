# Resumen Del Juego Actualizado

Fecha de actualizacion: 2026-06-23

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
- StarterPlayer/StarterPlayerScripts/RosterUI.client.lua
- ServerScriptService/CombatServer.server.lua
- ServerScriptService/CombatRemoteSetup.server.lua
- ServerScriptService/MonsterPromptSetup.server.lua
- ServerScriptService/Combat/TeamManager.lua
- ServerScriptService/Combat/MonsterCombat.lua
- ServerScriptService/Combat/PetCubeService.lua
- ServerScriptService/Combat/PvpStarsService.lua
- ServerScriptService/EconomyState.server.lua
- ServerScriptService/BackpackDataStore.server.lua
- ReplicatedStorage/Modules/CombatGrid.module.lua
- ReplicatedStorage/Modules/BeastibitVisuals.module.lua
- ReplicatedStorage/Modules/Debug.lua
- ReplicatedStorage/GameData/MonstersData.lua
- ReplicatedStorage/GameData/FragmentsData.lua
- ReplicatedStorage/GameData/SpawnMatrix.lua

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
- El NPC usa Beastibit salvaje de unidad unica (x1) para PvE.
- Vida del salvaje en PvE: HP base x3.5.
- Daño del salvaje en PvE: Attack base x combo x2.5.
- Si el elemento elegido por IA no coincide con el elemento real del salvaje, el ataque es miss (0 daño).
- El proyectil del salvaje se emite como 1 disparo por ataque (no rafaga por combo).
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
- Ajustes finos de layout movil (HUD/board) y escalado visual de piezas temporales (drag + cascadas) en progreso.
- Mensaje flotante de ataque NPC removido para mejorar lectura del tablero en combate.
- Sacudida breve de camara en impacto de Beastibit salvaje (solo efecto visual local).

## 3.5 UI de Mochila y Formacion (separada de CombatUI)

Estado: FUNCIONAL BASE

- La mochila/formacion se movio a un LocalScript independiente: StarterPlayer/StarterPlayerScripts/RosterUI.client.lua.
- La comunicacion cliente-servidor se mantiene por eventos (CombatRosterAction y estados roster-sync/roster-error en CombatDuelState).
- Se elimino la dependencia de mochila dentro de CombatUI para reducir complejidad y evitar limite de registros locales en Luau.
- La UI de mochila ahora usa ranuras cuadradas en grid (no lista de texto).
- La vista de seleccionado, seguidor y slots del team usa celdas cuadradas preparadas para imagen por Beastibit.
- Soporta fallback seguro de imagen si el Beastibit no tiene AssetId.
- Se ajusto safe area para evitar superposicion con el menu nativo de Roblox.
- La resolucion de imagen por Beastibit ahora contempla evolucion (img.evo1/evo2/evo3 + evoActual) y mantiene fallback legacy.

## 3.6 Beastibit seguidor 3D (nuevo avance)

Estado: IMPLEMENTADO (BASE ESTABLE)

Archivo principal: ServerScriptService/Combat/PetCubeService.lua

Funcionalidad actual:

- Spawn hibrido: intenta modelo 3D por Beastibit y si falla usa cubo por elemento como fallback seguro.
- Fuente de modelos en ServerStorage/BeastibitTemplates (con fallback temporal a Workspace para transicion).
- Separacion explicita companion vs salvaje:
  - Companion clonado marca IsCompanion=true e IsMonster=false.
  - Se elimina MonsterChallengePrompt heredado en el clon companion.
  - MonsterPromptSetup evita crear prompt en companions y en PlayerPetCubes.
- Follow organico en servidor con lerp/catch-up/teleport de seguridad.
- Follow adaptado a gravedad planetaria (usa UpVector local del personaje, no eje Y global).
- Configuracion de follow y orientacion movida a MonstersData por especie (CompanionFollow), evitando depender de muchos atributos en el modelo template.

## 3.7 Sistema de Captura, Fragmentos y Minerales (Fase 1)

Estado: IMPLEMENTADO

Archivos nuevos: FragmentsData.lua, SpawnMatrix.lua, BackpackDataStore.server.lua

### 3.7.1 Captura directa post-combate PvE

- Al ganar un duelo PvE, se lanza roll de captura segun rareza del Beastibit salvaje.
- Chances base: Comun 60%, Raro 40%, Epico 5%. Legendario no se captura directo.
- Pity system: +5% acumulativo por fallo (por rareza), se resetea al capturar.

### 3.7.2 Fragmentos al fallar captura

- Si falla la captura, el jugador recibe fragmentos de esa especie.
- Drops: Comun 5, Raro 15, Epico 25 fragmentos.
- Craft por fragmentos: Comun 30, Raro 80, Epico 150 fragmentos.

### 3.7.3 Minerales planetarios

- Drop de mineral al ganar PvE (20% chance), mapeado por elemento del Beastibit.
- Minerales Bitara Prime: Magma Core (Fuego), Aqua Shard (Agua), Root Crystal (Planta), Volt Core (Electricidad).
- Minerales Korvaxis: Stone Heart (Roca), Pulse Fragment (asignado al bioma Energia).

### 3.7.4 Persistencia de inventario

- DataStore BackpackV1 guarda Beastibits desbloqueados y fragmentos por jugador.
- TeamManager administra perfil en memoria con unlockedMonsters y fragments.
- Flujo: carga al entrar (BackpackDataStore.loadPlayerData) y guardado al salir (savePlayerData).
- Roster-sync envia fragmentos al cliente para la UI de mochila.

### 3.7.5 Beastibits totales (20 especies)

- Mundo 1 - Bitara Prime: 14 especies (SlimeFuego, LoboAgua, TortugaPlanta, HalconElectrico, GolemRoca, Demonslime1, ZorroBrasa, MareaLince, HongoGuardian, RayoMantis, ObsidianaToro, Bloompup, Infervex, Leviacode).
- Mundo 2 - Korvaxis: 6 especies (Elderthorn, Titanox, Nullbyte, Pebblit, Sparkhog, Stormram).
- Elementos: Fuego, Agua, Planta, Electricidad, Roca (5 elementos).
- Rarezas: Common (10), Rare (5), Epic (3), Legendary (2).
- SpawnMatrix.lua define distribucion por bioma y rango de niveles.

## 3.8 Recurso de Captura y Energia

- Energia de captura: max 100, regenera +5 cada 12 min (~4h para llenar).
- Consumo de energia al iniciar duelo PvE: Comun 5, Raro 10, Epico 16, Legendario 24.
- Bits: moneda principal, se obtienen al ganar duelos PvE.
- Bit Spheres: ELIMINADAS del diseno final. No existe recurso de captura externo.

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
- Sin impacto en poder de combate: las estrellas NO aumentan ataque, vida ni stats.

Direccion de diseno confirmada (congelada V1):

- Las estrellas funcionan como prestigio/ranking social.
- Titulos PvP definidos: Rookie (0), Hunter (10), Tamer (25), Elite (50), Master (100), Legend (200), Bitlord (500).
- Shield Charges: maximo 3, obtencion 1 diaria + 1 semanal, se consume al perder (excepto en 0 estrellas).
- Los titulos y Shield Charges estan pendientes de implementacion en codigo.

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
7. Separacion de UI de mochila/formacion en script dedicado (RosterUI.client) para desacoplar de CombatUI.
8. Migracion de mochila y team a interfaz por ranuras cuadradas en grid, preparada para imagen por Beastibit.
9. Ajuste de safe area de UI de mochila para respetar topbar/menu nativo de Roblox.
10. Integracion de BeastibitVisuals.module para unificar seleccion de imagen por evolucion en UI.
11. Implementacion de Beastibit seguidor 3D con fallback automatico a cubo por seguridad.
12. Separacion companion/salvaje para evitar prompts de desafio en Beastibit seguidores.
13. Ajuste de follow para gravedad planetaria usando ejes locales del personaje.
14. Configuracion de follow por especie en MonstersData (CompanionFollow).
15. Ajuste de CombatUI para movil: reubicacion/escala del tablero y HUD para mejorar lectura en horizontal.
16. Correccion de escala en piezas temporales de drag/cascada para que coincidan con el tablero reducido en movil.
17. Eliminacion del texto flotante de ataque NPC en HUD para reducir ruido visual durante duelo.
18. PvE rebalanceado a salvaje unidad unica (x1) en lugar de equipo simulado x5.
19. Multiplicadores PvE aplicados al salvaje: HP x3.5 y daño por ataque x2.5 * combo.
20. Regla de miss elemental en IA NPC: elemento no correspondiente aplica 0 daño.
21. Ajuste de VFX NPC: 1 proyectil por ataque del salvaje (aunque combo sea alto).
22. Integracion de camera shake corto al impacto del salvaje en cliente.
23. Sistema de captura directa post-combate PvE con pity por rareza.
24. Fragmentos al fallar captura y sistema de craft por fragmentos.
25. Drops de minerales planetarios al ganar PvE.
26. Persistencia de inventario Beastibit y fragmentos con DataStore BackpackV1.
27. 20 Beastibits definidos: nuevas especies Bloompup, Pebblit, Sparkhog, Stormram, Infervex, Leviacode, Elderthorn, Titanox, Nullbyte.
28. SpawnMatrix con distribucion por bioma, niveles y minerales por planeta.
29. Eliminacion de Bit Spheres: captura directa sin recurso externo.

## 7. Lo Que Falta O Requiere Pulido

## 7.1 Combate

- [X] Conectar dano/recompensas a sistema de progreso real (captura, fragmentos, minerales, Bits).
- Sincronizar aun mas fino el combo visual con cada sub-evento de cascada.
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
- [X] Definir tabla final de titulos por hitos de estrellas.
- [X] Definir fuentes y limites de Shield Charges para no congelar la ladder.

## 7.3 Economia de captura y progresion Beastibit (FASE 2 - APLICADO)

- [X] Cerrar nombre final del recurso de captura: ELIMINADO (sin recurso externo, captura directa).
- [X] Cerrar tabla numerica de drops: fragmentos + minerales implementados.
- [X] Persistencia de inventario Beastibit con DataStore BackpackV1.
- [X] Sistema de captura directa con pity por rareza.
- [X] Cerrar tabla de XP por rareza para comida con duplicados (comun 10, raro 25, epico 60, legendario 150).
- [X] Cerrar costos de evolucion por planeta: 500/2500 Bits + 10/30 minerales.
- [X] Confirmar protecciones de seguridad para Beastibit favoritos/equipo/historia en alimentacion (equipo y seguidor protegidos).

## 7.4 Sistema de evolucion (FASE 2 - NUEVO)

Estado: IMPLEMENTADO

Archivo principal: ServerScriptService/Combat/TeamManager.lua

- Funcion evolveMonster con validaciones.
- Costos por etapa: Evo 1->2 (500 Bits + 10 minerales), Evo 2->3 (2500 Bits + 30 minerales).
- Mineral de evolucion mapeado por elemento: Fuego=Magma Core, Agua=Aqua Shard, Planta=Root Crystal, Electricidad=Volt Core, Roca=Stone Heart.
- Maximo 3 evoluciones por Beastibit.
- Tracking individual de nivel de evolucion por especie en perfil y DataStore.

## 7.5 Sistema de alimentacion y XP (FASE 2 - NUEVO)

Estado: IMPLEMENTADO

Archivo principal: ServerScriptService/Combat/TeamManager.lua

- Funcion feedMonster: sacrifica un Beastibit para dar XP a otro.
- XP base por rareza del alimento: Comun 10, Raro 25, Epico 60, Legendario 150.
- Multiplicador por evolucion del alimento: Evo1 x1.0, Evo2 x1.75, Evo3 x3.0.
- Protecciones: no se puede sacrificar equipo activo ni seguidor.
- Confirmacion visual en UI antes de sacrificar (overlay de seleccion).
- XP persistida en DataStore BackpackV1.

## 7.6 Sistema de craft por fragmentos (FASE 2 - NUEVO)

Estado: IMPLEMENTADO

Archivo principal: ServerScriptService/Combat/TeamManager.lua

- Funcion craftMonster: gasta fragmentos para desbloquear Beastibit.
- Costos: Comun 30, Raro 80, Epico 150 fragmentos.
- Beastibits no desbloqueados con fragmentos se muestran en tab Craft.
- Boton de craftear conectado en UI.

## 7.7 PvP - Titulos y Shield Charges (FASE 2 - NUEVO)

Estado: IMPLEMENTADO

Archivo principal: ServerScriptService/Combat/PvpStarsService.lua

- Titulos PvP: Rookie (0), Hunter (10), Tamer (25), Elite (50), Master (100), Legend (200), Bitlord (500).
- Shield Charges: max 3, regenera 1 diario + 1 semanal.
- Al perder PvP, si hay shield disponible se consume (no se pierden estrellas).
- Loop de regeneracion de shields cada 30s en CombatServer.
- Titulo y shields visibles en header del Dashboard.
- Persistencia en atributos del jugador (no DataStore separado).

## 7.8 Gravedad planetaria

- Revisar y reducir logs de debug para produccion.
- Ajustar transiciones entre planetas para viajes largos y casos borde.
- Validar rendimiento en movil con varios planetas y mas jugadores.

## 7.9 Estructura y estandar

- Todavia hay scripts con print/warn directos en vez de pasar por modulo Debug.
- Existen scripts legacy en otrojuegosimilar que conviene archivar formalmente o mover a carpeta de referencia documentada.
- Conviene actualizar documentacion principal para reflejar el sistema de estrellas PvP ya implementado.

## 7.10 Mochila y presentacion visual

- Cargar y validar AssetId final por Beastibit en MonstersData para reemplazar fallback visual.
- Ajustar estilo final de badges (LOCK/UNLOCK/FOLLOW/slot) y legibilidad en resoluciones pequenas.
- Evaluar drag and drop futuro para asignacion de team (actualmente por click/tap).

## 7.11 Beastibit seguidor 3D

- Calibrar valores CompanionFollow por especie para pose final (yaw/pitch/roll, distancia y altura).
- Estandarizar pivote/origen de modelos template para reducir offsets extremos.
- Preparar animaciones reales de locomocion companion (actualmente follow por PivotTo).

## 7.12 Normalizacion de modelos Beastibit (nuevo)

Objetivo:

- Garantizar que todos los modelos 3D Beastibit entren al juego con el mismo contrato tecnico para evitar desfase, rotacion incorrecta, piezas separadas y fallos de VFX.

Contrato tecnico obligatorio por modelo (MVP):

- Debe ser un Model con al menos 1 BasePart valida.
- Debe tener PrimaryPart definida.
- Debe incluir una pieza root estable (nombre recomendado: HumanoidRootPart o Root).
- El frente del modelo debe quedar orientado a -Z local (estandar Roblox).
- El up del modelo debe quedar orientado a +Y local.
- El pivote del Model debe quedar centrado en el cuerpo principal (no en piezas auxiliares).
- Todas las piezas visuales deben estar rigidamente unidas al root (WeldConstraint/Motor6D/rig consistente).
- No dejar piezas sueltas sin union estructural.
- No usar partes Anchored dentro del template final para companions/duelo.
- Mantener escala consistente por especie segun guia de tamano (evitar outliers extremos).

Convencion de jerarquia recomendada:

- Model (nombre = MonsterId o ModelTemplate)
- RootPart (PrimaryPart)
- Geometry (mallas/piezas visuales)
- Attachments opcionales para VFX (Muzzle, HitOrigin) cuando aplique

Campos de ajuste por especie (solo para excepciones):

- CompanionFollow: offsets de seguimiento fuera de duelo.
- DuelLinePlacement: offsets exclusivos para fila de duelo.
- Regla: primero normalizar modelo en origen; offsets solo para ajuste fino, no para corregir modelos rotos.

Pipeline de validacion antes de publicar un modelo:

1. Verificar PrimaryPart, orientacion y pivote en template.
2. Verificar uniones internas (sin piezas sueltas).
3. Probar spawn como follower (mundo abierto).
4. Probar spawn en linea de duelo PvP y PvE.
5. Verificar origen de proyectil/VFX sobre slot 1.
6. Registrar offsets minimos en MonstersData solo si son necesarios.

Definicion de listo para produccion (Definition of Done):

- Modelo estable en follower y en duelo sin drift ni separacion.
- Rotacion correcta frente a rival en linea de duelo.
- Sin dependencia de correcciones agresivas runtime.
- VFX de ataque sale desde posicion coherente del Beastibit.
- Documentado en MonstersData con ModelTemplate y (si aplica) DuelLinePlacement.

## 8. Riesgos Tecnicos Detectados

1. Persistencia DataStore: dos DataStores activos (PvpStarsV1 y BackpackV1), sin estrategia de reintentos/cola para fallos temporales.
2. Logging en produccion: alto ruido de consola en varios scripts.
3. Complejidad creciente de CombatServer: conviene separar en sub-modulos (duelos, NPC, damage, sync, captura).
4. PlanetGravityController es robusto pero largo; mantenimiento puede complicarse sin separar en modulos cliente.
5. Variacion de pivote/orientacion entre modelos Beastibit puede requerir calibracion por especie.
6. Falta de contrato unico de modelos puede generar deuda tecnica en placement y VFX.

## 9. Resumen Ejecutivo

Estado general del proyecto: SOLIDO Y JUGABLE. FASE 2 DE PROGRESION COMPLETA.

- Combate match-3: funcional en servidor/cliente, con cascadas y animaciones.
- Duelos PvP/PvE: funcionales con estados completos.
- Captura PvE: directa post-combate con pity, fragmentos y minerales.
- Evolucion: gasta Bits + minerales, 3 etapas por Beastibit.
- Alimentacion/XP: sacrifica duplicados para dar XP, con multiplicadores por rareza/evo.
- Craft por fragmentos: desbloquea Beastibits usando fragmentos acumulados.
- PvP: estrellas con titulos (Rookie a Bitlord) y Shield Charges contra perdida.
- Persistencia: DataStore para PvP (estrellas) e inventario (backpack, fragmentos, bits, minerales, evoluciones, XP).
- Gravedad planetaria: funcional con sistema avanzado de movimiento y camara.
- Beastibit seguidor 3D: implementado con fallback, separacion companion/salvaje y base planet-aware.
- 20 Beastibits definidos en 2 planetas (Bitara Prime y Korvaxis), 5 elementos, 4 rarezas.

Siguiente foco recomendado:

1. Agregar iconos/imagenes reales a los Beastibit nuevos.
2. VFX/feedback de progreso (captura, evolucion).
3. Separar CombatServer en submodulos.
4. Ajustar balance de stats por evolucion.
5. Preparar modelos 3D para nuevos Beastibit.
6. Limpieza de arquitectura y documentacion para escalar contenido.
