# Progreso Diario - Mundos Roblox

Ultima actualizacion: 2026-06-23

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
- [X] RosterUI redisenado como dashboard con 5 tabs:
  - Inventario (Bits, fragmentos, minerales)
  - Beastibit (coleccion completa, bloqueados en silueta negra)
  - Team (formacion 5 slots + seleccion)
  - Seguidor (elegir Beastibit acompanante)
  - Craft (seleccionar para evolucionar/alimentar - UI lista, logica pendiente)

#### Fixes
- [X] CombatProjectileVfx movido a CombatRemoteSetup (evita infinite yield)
- [X] BackpackDataStore/FragmentsData/SpawnMatrix con fallback si no existen en Studio
- [X] PlayerStatusHUD se oculta al abrir dashboard
- [X] Boton toggle no se pisa con iconos Roblox (topOffset >= 52)

---

### Proximas tareas (Dia 2)

#### Prioridad alta
- [X] Implementar logica de evolucion en servidor (costos Bits + minerales)
- [X] Implementar logica de alimentacion/XP en servidor
- [X] Conectar botones Evolucionar/Alimentar en tab Craft
- [X] Implementar craft por fragmentos (TeamManager.craftMonster)
- [X] Mostrar conteo de fragmentos en tab Craft para decidir si se puede craftear

#### Prioridad media
- [X] Implementar titulos PvP en servidor (Rookie, Hunter, Tamer, Elite, Master, Legend, Bitlord)
- [X] Mostrar titulo PvP en algun lado de la UI
- [X] Implementar Shield Charges (max 3, 1 diaria + 1 semanal)
- [X] Mostrar Shield Charges en UI

#### Prioridad baja
- [X] Crear ModuleScripts en Studio: BackpackDataStore, FragmentsData, SpawnMatrix
- [ ] Agregar iconos/imagenes reales a los Beastibit nuevos
- [ ] Mejorar feedback visual de captura (exito/fallo) en pantalla de resultado
- [ ] Separar CombatServer en submodulos

---

## Dia 2 - 2026-06-23: Fase 2 - Evolucion, Alimentacion, Craft y PvP

### Lo que se hizo

#### Sistema de evolucion
- [X] Logica de evolucion en servidor (TeamManager.evolveMonster)
- [X] Costos: Evo 1->2: 500 Bits + 10 minerales, Evo 2->3: 2500 Bits + 30 minerales
- [X] Mineral mapeado por elemento (Magma Core, Aqua Shard, Root Crystal, Volt Core, Stone Heart)
- [X] Validaciones: desbloqueado, no max evolucion, suficientes Bits/minerales

#### Sistema de alimentacion/XP
- [X] Logica de alimentacion en servidor (TeamManager.feedMonster)
- [X] XP por rareza: Comun 10, Raro 25, Epico 60, Legendario 150
- [X] Multiplicador por evolucion del alimento: Evo1 x1.0, Evo2 x1.75, Evo3 x3.0
- [X] Protecciones: no sacrificar equipo activo ni seguidor
- [X] Confirmacion visual en UI antes de sacrificar

#### Sistema de craft por fragmentos
- [X] Logica de craft en servidor (TeamManager.craftMonster)
- [X] Costos por rareza: Comun 30, Raro 80, Epico 150 fragmentos
- [X] Beastibit no desbloqueados con fragmentos suficientes se muestran en tab Craft
- [X] Boton de craftear conectado en UI

#### UI - Tab Craft
- [X] Conectados botones Evolucionar y Alimentar a acciones del servidor
- [X] Muestra nivel de evolucion actual y XP acumulada
- [X] Muestra conteo de fragmentos para decidir si se puede craftear
- [X] Overlay de seleccion de alimento con confirmacion
- [X] Muestra Beastibit no desbloqueados que se pueden craftear con fragmentos

#### Sistema PvP - Titulos y Shields
- [X] Titulos PvP implementados: Rookie (0), Hunter (10), Tamer (25), Elite (50), Master (100), Legend (200), Bitlord (500)
- [X] Titulo visible en header del Dashboard
- [X] Shield Charges implementados (max 3, 1 diaria + 1 semanal)
- [X] Regeneracion automatica de shields cada 30s
- [X] Shield se consume al perder PvP (protege estrellas)
- [X] Shield charges visibles en header del Dashboard

#### Persistencia
- [X] Bits y minerales persistidos en BackpackDataStore
- [X] Evoluciones y XP persistidos en BackpackDataStore
- [X] Carga/guardado completo en PlayerAdded/PlayerRemoving

#### Fixes
- [X] CombatServer: shield regen loop agregado
- [X] PvpStarsService: applyPvpDuelResult retorna shieldUsed
- [X] BackpackDataStore: savePlayerData acepta bits, minerals, evolutions, xp

---

### Proximas tareas (Dia 3)

#### Prioridad alta
- [ ] Agregar iconos/imagenes reales a los Beastibit nuevos
- [ ] Mejorar feedback visual de captura (exito/fallo) en pantalla de resultado
- [ ] Separar CombatServer en submodulos

#### Prioridad media
- [ ] Ajustar balance de stats por evolucion (multiplicadores de stats al evolucionar)
- [ ] Mostrar VFX al evolucionar un Beastibit
- [ ] Preparar modelos 3D para nuevos Beastibit

#### Prioridad baja
- [ ] Agregar animaciones de locomocion para companion
- [ ] Optimizar rendimiento movil del dashboard
- [ ] Validar anti-spam en acciones de craft/evolve

---

### Notas
- Los elementos del combate son 5: Fuego, Agua, Planta, Electricidad, Roca
- "Energia" es un bioma de Korvaxis, NO un elemento
- Bit Spheres eliminadas del diseno final
- 20 Beastibits totales: 14 Bitara Prime + 6 Korvaxis
