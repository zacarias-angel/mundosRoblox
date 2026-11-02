# Retorno al proyecto: auditoría y propuesta de alpha

> Histórico desde 2026-11-02. Documento vigente: [Plan maestro de alpha](../PLAN_MAESTRO_ALPHA.md).

Fecha: 2026-11-02
Place inspeccionado: **primer mundo recorrible**, PlaceId `135994156281921`.

## 1. Conclusión

Hay una base valiosa: planeta recorrible, motor match-3, interfaz de colección/equipo, seguidores y módulos de progresión. Sin embargo, el código actual tiene conexiones rotas que impiden considerarlo listo para publicar. La documentación describe una versión anterior y exagera el estado actual de algunos sistemas.

Prioridad: recuperar un ciclo completo **entrar → explorar → combatir → capturar → mejorar equipo → guardar → volver a entrar** antes de ampliar contenido.

### Alcance de esta revisión

- Leídos los ocho documentos de `docs` y `lore/lore.txt`.
- Inspección de jerarquía, inventario de scripts, fuentes de los módulos centrales, templates y FireBaby.
- Capturas visuales del mapa en modo edición.
- Diagnóstico estático: **no se ejecutó un playtest ni se verificó persistencia en servidores publicados**. Las referencias de líneas corresponden al snapshot inspeccionado.
- Este documento registra observaciones y propuestas; no sustituye automáticamente las decisiones de diseño congeladas.

## 2. Bloqueantes comprobados en código

### P0 — El módulo PvE contiene una copia del módulo PvP

`ServerScriptService/Combat/MonsterDuel` tiene encabezado de DuelManager, define funciones `DuelManager.*` y devuelve `DuelManager` (línea 446). No implementa `onMonsterChallenged` ni `endMonsterDuel`.

Pero:

- `CombatServer.server` llama `MonsterDuel.onMonsterChallenged` al activar un prompt.
- `GridResolver:278` y `ChallengeHandler:368` llaman `endMonsterDuel`.

**Consecuencia:** las llamadas al flujo PvE fallarán por función inexistente. Captura, IA y recompensas no pueden darse por funcionales en este snapshot.

**Acción:** buscar la última implementación válida en historial/backups y recuperarla adaptando sus contratos. Si no existe, reconstruir el módulo con inicio, reserva del monstruo, combate, resultado y limpieza explícitos.

### P0 — El resolver no coincide con las APIs del tablero y daño

`ServerScriptService/Combat/GridResolver` llama:

| Llamada actual | Estado real del módulo |
|---|---|
| `CombatGrid.isPathValid` (178) | No existe. Existe `validateSwapPath(path)`, que devuelve `{valid, errors}`. |
| `CombatGrid.solveCombos` (190) | No existe. Existen `applySwapPath` y `resolveBoard`. |
| `MonsterCombat.calculateDamage` (209) | No existe. Existe `calculateTeamDamage(team, comboSummary)`. |

Además, el resolver valida la ruta pero no llama a `applySwapPath` antes de resolver el tablero. Espera `summary.grid`, aunque la API existente modifica el grid recibido y devuelve información de cascadas.

**Acción:** reconectar el flujo completo, no limitarse a renombrar funciones:

1. Validar payload, límites de longitud y adyacencia.
2. Aplicar los swaps al grid canónico clonado.
3. Resolver cascadas y conservar la información elemental necesaria para el daño.
4. Calcular daño con una única API.
5. Sincronizar grid, animaciones y resultado.
6. Impedir resoluciones simultáneas del mismo jugador y descartar tareas tardías de un duelo ya finalizado.

Hoy solo hay un intervalo mínimo de 0,15 s entre submits, y el handler hace `task.wait` durante la resolución sin un bloqueo de operación ni revalidación posterior del duelo. Esto requiere corregirse junto con las APIs.

### P0 — Persistencia vulnerable a pérdida de progreso

`BackpackDataStore`:

- Devuelve datos por defecto tanto si el jugador es nuevo como si `GetAsync` falla.
- Luego puede guardar ese perfil por defecto con `SetAsync` encima de datos anteriores.
- No hay reintentos ni autosave en el flujo inspeccionado.
- La búsqueda global no encontró `BindToClose`.
- Los DataStores están desactivados expresamente en Studio mediante `not RunService:IsStudio()`; un playtest normal no comprueba guardado real.

También falta persistir equipo, seguidor elegido, energía y timestamps de regeneración. La energía se inicializa al máximo en una sesión nueva. Las cargas y fechas de shields tampoco se guardan con las estrellas.

`TeamManager` reconstruye la mochila sobre los regalos `StarterUnlocked` y solo se guardan cantidades positivas. Una especie inicial consumida hasta cero puede reaparecer al reconectar porque su ausencia en el guardado vuelve a tomar el valor inicial.

**Acción:** un servicio de perfil con estado de carga explícito, protección contra guardado tras fallo de carga, esquema versionado, exclusión de sesiones concurrentes, reintentos, autosave y cierre. `UpdateAsync` por sí solo no resuelve la concurrencia: hace falta una política de sesión y migración. Conservar la compatibilidad con `BackpackV1` y `PvpStarsV1`.

## 3. Arreglos de prioridad alta

### Progresión sin efecto en combate

- `TeamManager:13`: máximo actual **50**, no 60.
- No existe `evolveMonster` en el módulo actual ni acción de evolución en `ChallengeHandler`.
- Alimentar cuesta `nivel objetivo × 15 Bits` y otorga XP por rareza y nivel; no usa multiplicador de evolución.
- `calculateTeamHP` suma únicamente `BaseStats.HP`.
- `MonsterCombat.calculateTeamDamage` y el resolver usan ataque base sin nivel.

**Resultado:** el jugador puede gastar copias y Bits para subir un número que no aumenta su poder de combate.

**Propuesta:** para la primera alpha, conservar niveles como único crecimiento y conectar una fórmula central de stats efectivos a HP y daño. Posponer evolución visual y minerales hasta que ese crecimiento tenga una utilidad clara. Esta simplificación necesita aprobarse porque cambia el diseño congelado.

La XP es por **especie**, no por criatura individual. Conviene documentar esa regla y mantenerla en esta primera versión si queremos evitar inventarios con IDs individuales.

### Formación de duelo incompatible con parte del planeta

`DuelManager:181–219,267–292` y `PetCubeService:894–928` usan raycast vertical, plano XZ y `Vector3.new(0,1,0)` como arriba. El follower sí utiliza orientación local del planeta.

**Resultado esperado:** la formación puede funcionar cerca del polo superior y quedar mal orientada o posicionada en los laterales/inferior.

**Propuesta de simplificación:** arenas de combate prearmadas dentro del mismo place, con posiciones y cámara controladas, y retorno al punto original. Esto reduce el problema de terreno, orientación y colisiones. Debe probarse la transición con el controlador de gravedad. No requiere crear otro place ni depender de un teletransporte entre servidores.

### Seguidor al terminar combate

`DuelManager:331` restaura con `spawnPlayerTeamCubes(participant, team)` sin pasar la especie seleccionada. `PetCubeService:820–824` usa entonces el primer miembro del equipo.

Está comprobada la pérdida de selección en ese camino; el reporte histórico de desaparición total todavía requiere reproducirse. El camino PvE no puede evaluarse hasta reparar `MonsterDuel`.

### Acciones de roster y estado mutable

- `applyDuelSlotSelection` modifica `state.team` antes de completar todas las validaciones: un rechazo puede dejar esa tabla alterada.
- Cambiar slots, alimentar y craftear no tienen un guard general de duelo activo ni límites de frecuencia.
- Seleccionar follower solo comprueba PvP activo.
- `cleanPlayerState` no llama a `TeamManager.clearTeam` ni a `PetCubeService.clearPlayerCubes`.

**Acción:** validar sobre copias, aplicar cambios de forma atómica, definir qué acciones se permiten durante duelo y centralizar limpieza al desconectar/respawnear.

### Shields y abandono PvP

- `PvpStarsService:487–503` toma fechas faltantes como cero y calcula concesiones desde ese origen; puede rellenar cargas repetidamente cada vez que se consumen, en lugar de respetar el calendario real.
- `DuelManager` envía `starsDelta=-1` incluso cuando el shield evita perder estrellas.
- Las estrellas solo se aplican con motivo `hp-depleted`; abandonar produce `player-left` y evita esa penalización.

**Propuesta:** dejar ranking competitivo fuera de la primera prueba pública hasta cerrar abandono, límites y persistencia. Puede conservarse PvP amistoso si supera QA.

## 4. Modelos y presentación: estado real

### Inventario observado

- **21 especies** definidas en `MonstersData`, incluyendo FireBaby, frente a las 20 de la documentación.
- Solo **un template** en `ServerStorage/BeastibitTemplates`: Demonslime1. Tiene dos partes ancladas y no tiene motores ni animaciones.
- La mayoría de imágenes son placeholders. FireBaby y Demonslime1 tienen IDs no cero; no se comprobó su disponibilidad en cliente.
- Hay modelos de prueba en Workspace y fallback que busca modelos allí. No equivale a tener un catálogo terminado.
- FireBaby tiene PrimaryPart, cuatro Motor6D, AnimationController y Animator. **No contiene objetos `Animation`** con IDs publicados.
- `resolveCompanionAnimations` busca `Animation` como hijos directos del AnimationController. Los guardados del editor no satisfacen ese contrato.
- `createFollowerModel:452` ancla todas las partes del clon: hay que revisar ese tratamiento para rigs Motor6D animados; no alcanza con agregar un AnimationId.

### Pipeline recomendado

1. Terminar **una criatura patrón** antes de multiplicar modelos.
2. Normalizar frente -Z, arriba +Y, pivote, escala y root.
3. Mantener piezas articuladas mediante Motor6D o usar un rig de huesos; reservar welds para piezas rígidas.
4. Usar `Animator` y referencias explícitas de Idle/Walk/Attack/Hit; publicar y verificar permisos de animaciones.
5. Probar el mismo modelo como salvaje, compañero y participante de duelo.
6. Generar su icono desde el modelo definitivo.
7. Duplicar el pipeline para las especies del lanzamiento.

Para criaturas simples se puede utilizar animación procedural de rebote/flotación en vez de rig complejo. Elegir el método por criatura y evitar mezclar reparaciones automáticas con uniones contradictorias.

### Dirección visual del mundo

Las capturas muestran una base de pequeño planeta atractivo, con aldea y vegetación concentradas en el hemisferio superior. Todavía hay grandes áreas poco trabajadas y mezcla de estilos/escala de assets.

Propuesta:

- Una aldea inicial pequeña con función clara: llegada, guía y objetivo de primer combate.
- Dos zonas de exploración bien diferenciadas para la primera alpha.
- Caminos, hitos y siluetas visibles sobre la curvatura.
- Identidad visual consistente: low-poly estilizado, paleta por bioma y acentos digitales del BitCore.
- Sustituir el placeholder llamado Kirby por una criatura propia coherente con el catálogo.
- Llevar modelos de prueba y decoración sin destino claro a una organización explícita de prototipo/producción.

No se midió rendimiento: complejidad de instancia y tamaño de scripts no permiten concluir FPS ni consumo de memoria por sí solos.

## 5. Spawns y contenido alcanzable

`SpawnMatrix` define biomas, rangos y especies, pero la búsqueda global solo encuentra referencias dentro de su propio módulo. No se encontró un consumidor que genere poblaciones por bioma.

En el Workspace se observaron monstruos colocados manualmente. Demonslime2 tiene `IsMonster=true` pero carece de MonsterId explícito; el setup le asignará su nombre y ese ID no existe en MonstersData.

La matriz no incluye FireBaby ni las cinco especies épicas/legendarias. Los rangos de nivel definidos allí no implican que los encuentros actuales los estén usando.

**Acción:** implementar población limitada por zonas, ID validado, pesos de aparición, reserva durante combate y respawn. Empezar con puntos fijos y comportamiento idle sencillo; patrullas complejas pueden esperar.

## 6. Simplificaciones propuestas para poder lanzar

No están aplicadas ni aprobadas todavía.

| Área | Primera alpha propuesta | Después |
|---|---|---|
| Mundo | Un planeta, aldea y dos zonas terminadas | Segundo planeta y resto de biomas |
| Catálogo | 5 iniciales coherentes con los cinco elementos + 3 capturables | Completar las 21 especies y ajustar el catálogo oficial |
| Equipo | Mantener los cinco slots del combate existente | Cambiar tamaño solo si las pruebas lo justifican |
| Crecimiento | Niveles con efecto real en stats | Evoluciones y sus variantes visuales |
| Recompensas | Bits, captura directa y fragmentos de respaldo | Minerales cuando tengan uso activo |
| Duplicados | Cantidad y XP compartida por especie, con confirmación al consumir | Instancias individuales si aportan valor real |
| Combate | PvE sólido; arena controlada en el mismo place | Ranked PvP y escenarios más complejos |
| Energía | Decidir si aporta valor a la alpha; nunca bloquear el tutorial | Balance diario basado en datos de uso |
| Salvajes | Spawn limitado por zona e idle legible | Patrulla, huida y eventos |
| UI | Colección/detalle, equipo e inventario; seguir/alimentar desde detalle | Más pestañas solo si hay necesidad |

No regalar todas las especies elegidas para capturar: revisar `StarterUnlocked` antes de fijar el catálogo. Actualmente hay nueve especies marcadas como iniciales.

## 7. Lore convertido en experiencia

`lore/lore.txt` aporta BitCore, Corruption y criaturas nacidas de fragmentos. Falta convertir esa premisa en una meta visible.

Propuesta de primer recorrido:

1. Llegás a Bitara Prime y encontrás un fragmento del BitCore dañado.
2. Un guardián explica el tablero durante un encuentro guiado.
3. Conseguís una primera captura garantizada de tutorial, con recompensa clara.
4. Equipás la criatura y ves una mejora real al progresar.
5. Reparás un pequeño nodo tras completar objetivos de la zona.
6. Se muestra Korvaxis como siguiente destino futuro.

Con esto el lore orienta la exploración sin necesitar una campaña extensa para el estreno.

## 8. Orden de trabajo y criterios de cierre

### Etapa A — Recuperar la build

- [ ] Respaldar/exportar scripts y place; recuperar el último PvE válido.
- [ ] Corregir MonsterDuel y contratos GridResolver/CombatGrid/MonsterCombat.
- [ ] Cerrar bloqueo de resolución, límites de payload y eventos tardíos.
- [ ] Validar inicio, jugada, daño, victoria/derrota y salida de duelo.
- [ ] Recuperar movilidad, cámara y seguidor elegido al terminar.

**Cierre:** un combate PvE completo ejecutado en Studio sin errores, repetible tras otro combate y tras respawn.

### Etapa B — Progreso confiable

- [ ] Perfil persistente con migraciones y protección frente a fallo de carga.
- [ ] Corregir cantidades cero, regalos iniciales y carga de preferencias.
- [ ] Stats efectivos por nivel y coste/recompensa legibles.
- [ ] Resolver política de energía, shields y abandono según alcance aprobado.

**Cierre:** completar captura y mejora, salir y volver en servidor de prueba publicado conservando exactamente progreso y preferencias. Probar fallo de carga sin sobrescribir datos.

### Etapa C — Primera porción terminada del juego

- [ ] Una criatura patrón validada y luego el catálogo reducido.
- [ ] Aldea, dos zonas, spawns y arena coherentes.
- [ ] Tutorial breve con primer objetivo y primera captura.
- [ ] Feedback de combate/captura/mejora y sonidos esenciales.
- [ ] UI legible y controles táctiles en dispositivos objetivo.

**Cierre:** alguien que no conoce el proyecto entiende qué hacer y completa el recorrido sin ayuda del creador.

### Etapa D — Prueba externa y publicación

- [ ] QA de desconexión, muerte/respawn, repetición de combates y sesiones simultáneas.
- [ ] Prueba real de PvP con dos jugadores si entra en la alpha.
- [ ] Medición en móvil y con concurrencia objetivo del servidor.
- [ ] Medir entrada, tutorial completado, primera batalla, primera captura y primera mejora para detectar abandonos.
- [ ] Página del juego, nombre, descripción, icono y miniaturas del gameplay real.
- [ ] Alpha cerrada con un grupo pequeño; corregir bloqueos antes de ampliar acceso.

**Cierre:** no hay pérdidas de datos, combates atascados ni bloqueos del recorrido inicial; se dispone de resultados de pruebas, no solo checklist documental.

## 9. Documentación y mantenimiento

- `RESUMEN_JUEGO_ACTUALIZADO.md` ya no es una descripción fiel: dice evolución/nivel 60 y modularización pendiente; el place tiene nivel 50, sin evolución y combate ya separado.
- `DECISIONES_MVP_V1.md` y `RUTA_CHECKLIST...` conservan Bit Spheres; el documento de congelación las eliminó.
- `sistema_captura_y_economia.md` conserva regeneración +1; código y congelación dicen +5.
- El registro del problema de animación atribuye el fallo a un rig ausente, pero FireBaby actualmente sí tiene rig.

Mantener un único documento de alcance vigente, un backlog priorizado y el diario como histórico. Separar claramente **diseñado**, **implementado**, **probado en Studio** y **verificado en servidor publicado**.

Simplificar también las reglas internas: conservar comentarios útiles y contratos de módulos; revisar la obligación de repetir cuatro campos dentro de cada función trivial, que añade mucho volumen sin verificar comportamiento.

Siguiente intervención recomendada: **Etapa A, recuperar MonsterDuel y reparar el contrato del tablero**. Después, persistencia. Luego modelado y ampliación del mundo.
