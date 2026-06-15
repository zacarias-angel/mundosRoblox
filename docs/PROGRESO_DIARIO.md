# Progreso Diario - Mundos Roblox

Ultima actualizacion: 2026-06-13

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
- [ ] Implementar logica de evolucion en servidor (costos Bits + minerales)
- [ ] Implementar logica de alimentacion/XP en servidor
- [ ] Conectar botones Evolucionar/Alimentar en tab Craft
- [ ] Implementar craft por fragmentos (TeamManager.craftMonster)
- [ ] Mostrar conteo de fragmentos en tab Craft para decidir si se puede craftear

#### Prioridad media
- [ ] Implementar titulos PvP en servidor (Rookie, Hunter, Tamer, Elite, Master, Legend, Bitlord)
- [ ] Mostrar titulo PvP en algun lado de la UI
- [ ] Implementar Shield Charges (max 3, 1 diaria + 1 semanal)
- [ ] Mostrar Shield Charges en UI

#### Prioridad baja
- [X] Crear ModuleScripts en Studio: BackpackDataStore, FragmentsData, SpawnMatrix
- [ ] Agregar iconos/imagenes reales a los Beastibit nuevos
- [ ] Mejorar feedback visual de captura (exito/fallo) en pantalla de resultado
- [ ] Separar CombatServer en submodulos

---

### Notas
- Los elementos del combate son 5: Fuego, Agua, Planta, Electricidad, Roca
- "Energia" es un bioma de Korvaxis, NO un elemento
- Bit Spheres eliminadas del diseno final
- 20 Beastibits totales: 14 Bitara Prime + 6 Korvaxis
