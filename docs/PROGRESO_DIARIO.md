# Progreso Diario - Mundos Roblox

Ultima actualizacion: 2026-06-29

---

## Dia 1 - 2026-06-13: Fase 1 - Fundacion de Economia

### Lo que se hizo

#### Datos y diseno
- [X] 9 Beastibits nuevos agregados a MonstersData.lua (total 20)
- [X] FragmentsData.lua creado (chances captura, drops fragmentos, costos craft)
- [X] SpawnMatrix.lua creado (distribucion por bioma, niveles, minerales)

#### Sistema de captura PvE
- [X] Captura directa post-combate con roll por rareza
- [X] Pity system: +5% acumulativo por fallo, reset al capturar
- [X] Fragmentos al fallar captura (Comun 5, Raro 15, Epico 25)
- [X] Drop de minerales al ganar PvE (20%, mapeado por elemento)

#### Persistencia
- [X] BackpackDataStore.server.lua creado (DataStore BackpackV1)
- [X] TeamManager actualizado: soporte para fragmentos y desbloqueo
- [X] Carga/guardado de inventario en PlayerAdded/PlayerRemoving

#### UI - Dashboard
- [X] RosterUI redisenado como dashboard con 5 tabs
- [X] PlayerStatusHUD se oculta al abrir dashboard
- [X] Boton toggle no se pisa con iconos Roblox

#### Fixes
- [X] CombatProjectileVfx movido a CombatRemoteSetup
- [X] Fallbacks si modulos no existen en Studio

---

## Dia 2 - 2026-06-23/24: Fase 2 - Alimentacion, Craft y PvP (EVOLUCION ELIMINADA 2026-06-30)

### Lo que se hizo

#### Sistema de niveles y XP (revisado 2026-06-30: sin evo, máx 50)
- [X] Niveles 1-50 con tabla de milestones interpolada
- [X] ~~Nivel determina evolucion~~ → ELIMINADO: sin evoluciones, solo niveles 1-50
- [X] ~~Para evolucionar requiere nivel 20 o nivel 40 + Bits + minerales~~ → ELIMINADO
- [X] Multiplicador de nivel del alimento al dar XP (0.8x a 3.0x)
- [X] Formula: XP = Base_Rareza x Mult_Nivel (ceil)
- [X] Costo en Bits por alimentacion: NivelActual × 15

#### Refactor de backpack (duplicados)
- [X] Backpack: `Unlocked (bool)` -> `Count (number)`
- [X] Capturar mismo Beastibit incrementa Count
- [X] Alimentar decrementa Count, borra si llega a 0
- [X] Validacion en Team: no mas copias de las disponibles
- [X] Persistencia de Count en BackpackDataStore (monsterCounts)

#### Sistema de evolucion → ELIMINADO (2026-06-30)
- [X] ~~evolveMonster~~ → ELIMINADO: los Beastibits ya no evolucionan
- [X] ~~Costos: 500/2500 Bits + 10/30 minerales~~ → ELIMINADO
- [X] ~~Mineral mapeado por elemento~~ → pendiente de redefinir uso de minerales

#### Sistema de alimentacion
- [X] feedMonster: sacrifica duplicado, da XP con formula completa
- [X] Protecciones: no equipo activo, no seguidor

#### Craft por fragmentos
- [X] craftMonster: gasta fragmentos por rareza para desbloquear

#### PvP: Titulos y Shields
- [X] 7 titulos: Rookie(0) a Bitlord(500)
- [X] Shield Charges max 3, +1 diario +1 semanal
- [X] Shield protege estrellas al perder PvP
- [X] Visibles en header del Dashboard

#### UI
- [X] Inventario como cuadricula (Beastibits con xN, minerales, fragmentos)
- [X] Beastibit tab con badges de cantidad xN
- [X] Craft tab: Nivel + XP, auto-refresh al sync
- [X] Pantalla resultado PvE: captura, fragmentos, minerales
- [X] Iconos de color como placeholder por elemento/rareza

#### Fixes
- [X] Mineral names sin espacios en atributos Roblox
- [X] Validacion de copias al asignar Team slots
- [X] Auto-refresh detalle Craft al recibir roster-sync
- [X] Label viejo eliminado que rompia layout resultado PvE
- [X] CombatUI: showDuelResult recibe y muestra captureResult

---

## Dia 3 - 2026-06-29: Animacion de Companion (intento) y Estandar de Modelos

### Lo que se hizo

#### Animacion de companion (FireBaby) - IMPLEMENTADO, PENDIENTE DE MODELO
- [X] `resolveCompanionAnimations()` agregado a PetCubeService: detecta AnimationController en el modelo clonado, carga Idle/Walk por nombre heuristico
- [X] `createFollowerModel()` carga las animaciones al spawnear y las guarda en `followerState.animations`
- [X] `stepFollower()` reproduce Idle si esta quieto, Walk con AdjustSpeed si se mueve
- [X] `stopFollowerTracking()` limpia tracks al destruir el companion
- [ ] **NO FUNCIONO**: el modelo FireBaby no reprodujo la animacion de caminar. El codigo esta listo pero el modelo no cumple los requisitos tecnicos para que AnimationController funcione (falta rig, Humanoid, o estructura de huesos correcta).

### Tareas Pausadas (Dia 3)

- [ ] Agregar iconos/imagenes reales a los Beastibit nuevos
- [ ] Mejorar feedback visual de captura (exito/fallo) en pantalla de resultado
- [ ] Separar CombatServer en submodulos
- [ ] ~~Ajustar balance de stats por evolucion~~ → ELIMINADO (sin evoluciones)
- [ ] ~~Mostrar VFX al evolucionar un Beastibit~~ → ELIMINADO (sin evoluciones)
- [ ] Preparar modelos 3D para nuevos Beastibit
- [ ] Optimizar rendimiento movil del dashboard
- [ ] Validar anti-spam en acciones de craft/evolve

---

## Dia 4 - 2026-06-30: Simplificacion - Sin evoluciones, nivel max 50, costo Bits en alimentacion

### Lo que se hizo

#### Eliminacion de evoluciones (todos los scripts)
- [X] TeamManager: removido evolveMonster, MAX_EVOLUTION, EVOLUTION_COST, EVO_XP_MULTIPLIER, ELEMENT_EVOLUTION_MINERAL, getEvolutionForLevel, getEvolutionMineralForMonster, getMonsterEvolution, ensureEvolutionsTable
- [X] TeamManager: feedMonster ahora usa formula simplificada (sin mult de evo) y cobra Bits = NivelActual x 15
- [X] TeamManager: MAX_LEVEL cambiado de 60 a 50, tabla de milestones reducida
- [X] MonstersData: removido createDefaultEvolutionImages, campos img.evo1/evo2/evo3, evoActual, normalizacion de evo
- [X] BeastibitVisuals.module: removido getEvolutionStage, simplificado getImageByMonsterData (una sola imagen)
- [X] BackpackDataStore: removido monsterEvolutions de load/save
- [X] CombatServer: removido handler de accion "evolve", removido evolutions de roster-sync, actualizado save
- [X] RosterUI.client: removido EvolveButton, Craft tab muestra Nivel y costo Bits en vez de Evo X/3

#### Costo de alimentacion en Bits
- [X] Formula: `NivelActual x 15` Bits por cada alimentacion
- [X] Visible en UI del Craft tab: "Costo alimentar: X Bits"
- [X] Validacion en servidor: spendPlayerBits antes de sacrificar duplicado

#### Evaluacion de zona segura para batallas
- [X] Confirmado: setupDuelParticipants (PvP) y setupMonsterDuelParticipant (PvE) ya implementan anclaje de jugadores
- [X] Ambos modos congelan movimiento (WalkSpeed=0, JumpPower=0, PlatformStand=true, AutoRotate=false)
- [X] Restauracion al terminar duelo en restoreDuelParticipants y endMonsterDuel
- [X] No se requiere escena separada: la zona segura ya funciona en el mismo mundo
