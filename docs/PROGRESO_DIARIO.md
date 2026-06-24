# Progreso Diario - Mundos Roblox

Ultima actualizacion: 2026-06-24

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

### Proximas tareas (Dia 3)

#### Prioridad alta
- [ ] Agregar iconos/imagenes reales a los Beastibit nuevos
- [ ] Mejorar feedback visual de captura (exito/fallo) en pantalla de resultado
- [ ] Separar CombatServer en submodulos

#### Prioridad media
- [ ] Ajustar balance de stats por evolucion
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
- Niveles 1-60 continuos, evolucion desbloquea por rango de nivel
