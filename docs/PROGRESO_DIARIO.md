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

## Dia 2 - 2026-06-23/24: Fase 2 - Evolucion, Alimentacion, Craft y PvP

### Lo que se hizo

#### Sistema de niveles y XP (segun sistema_captura_y_economia.md)
- [X] Niveles 1-60 con tabla de milestones interpolada
- [X] Nivel determina evolucion (1-20=evo1, 21-40=evo2, 41-60=evo3)
- [X] Para evolucionar requiere nivel 20 o nivel 40 + Bits + minerales
- [X] Multiplicador de nivel del alimento al dar XP (0.8x a 3.0x)
- [X] Formula: XP = Base_Rareza x Mult_Evo x Mult_Nivel (ceil)

#### Refactor de backpack (duplicados)
- [X] Backpack: `Unlocked (bool)` -> `Count (number)`
- [X] Capturar mismo Beastibit incrementa Count
- [X] Alimentar decrementa Count, borra si llega a 0
- [X] Validacion en Team: no mas copias de las disponibles
- [X] Persistencia de Count en BackpackDataStore (monsterCounts)

#### Sistema de evolucion
- [X] evolveMonster: valida nivel + Bits + minerales
- [X] Costos: 500/2500 Bits + 10/30 minerales planetarios
- [X] Mineral mapeado por elemento

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
- [X] Craft tab: Nivel + XP + evolucion, auto-refresh al sync
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
- [ ] Ajustar balance de stats por evolucion
- [ ] Mostrar VFX al evolucionar un Beastibit
- [ ] Preparar modelos 3D para nuevos Beastibit
- [ ] Optimizar rendimiento movil del dashboard
- [ ] Validar anti-spam en acciones de craft/evolve

---

## Dia 3 (Continuacion) - Proxima Sesion

### Tareas pendientes

#### Prioridad alta - Estandar de modelos Beastibit
- [ ] Definir contrato tecnico obligatorio para que las animaciones funcionen en todos los modelos
- [ ] Documentar que necesita un modelo: Humanoid, rig (Motor6D/Skin), AnimationController/Animator
- [ ] Crear guia de preparacion de modelos para artistas (ver DOCUMENTO_FINAL_CONGELACION_V1.md seccion 7.12)
- [ ] Estandarizar FireBaby y todos los modelos futuros bajo el mismo contrato

#### Prioridad alta - Revision de combate
- [ ] Revisar el sistema de combate completo (PvE y PvP)
- [ ] Identificar y corregir bugs existentes
- [ ] Bug: al terminar la batalla el seguidor actual desaparece (no se vuelve a spawnear)
- [ ] Posicionar correctamente los modelos 3D en formacion de duelo

#### Evaluacion tecnica
- [ ] Evaluar si al batallar conviene abrir una nueva escena/espacio separado para no interferir con el mundo abierto
  - Ventaja: no hay colisiones con terreno, otros jugadores ni mobs salvajes
  - Desventaja: quita inmersion, requiere transicion de escena
  - Alternativa: mantener en el mismo mundo pero con zona segura y cleanup al terminar

#### Prioridad media
- [ ] Agregar iconos/imagenes reales a los Beastibit nuevos (MonstersData.img)
- [ ] Mejorar feedback visual de captura (exito/fallo) en pantalla de resultado

#### Prioridad baja
- [ ] Separar CombatServer en submodulos
- [ ] Ajustar balance de stats por evolucion
- [ ] Mostrar VFX al evolucionar un Beastibit
- [ ] Wandering/patrulla para Beastibits salvajes (animacion Idle + Walk lateral)
