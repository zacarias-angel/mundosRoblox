# Beastibit — Plan maestro de la primera alpha

Versión: 1.2 · Fecha: 2026-11-02.
Estado: **hito 0 preparado y hito 1 recuperado/verificado en Studio; sesión cerrada en modo edición**.
Place de referencia: **primer mundo recorrible**, `135994156281921`.

Este documento reemplaza las decisiones MVP, congelación V1, resúmenes, rutas, economía, especificación UI y reglas técnicas anteriores. El historial se conserva en [descarte/](descarte/README.md).

## 1. Objetivo del lanzamiento

Publicar una alpha pequeña y completa donde un jugador nuevo pueda:

**Entrar → entender su objetivo → explorar → combatir con match-3 → capturar → mejorar su equipo → salir y volver conservando su progreso.**

La propuesta distintiva es explorar un pequeño planeta con gravedad propia y coleccionar criaturas digital-orgánicas llamadas **Beastibits**, usando un combate match-3 por arrastre.

### Qué significa estar listo

- El recorrido inicial se entiende sin ayuda del creador.
- El combate puede completarse y repetirse sin atascar personaje, cámara o interfaz.
- Capturar y mejorar tienen consecuencias visibles y útiles.
- El progreso sobrevive al reingreso y no se sobrescribe cuando falla una carga.
- El recorrido funciona con controles táctiles y rendimiento medido en dispositivos objetivo.

## 2. Alcance aprobado

| Área | Primera alpha | Fuera del lanzamiento inicial |
|---|---|---|
| Mundo | Bitara Prime: un planeta, una aldea y dos zonas de exploración terminadas | Korvaxis y resto de biomas |
| Criaturas | Ocho especies terminadas: cinco iniciales y tres obtenibles explorando | Catálogo completo de 21 especies |
| Combate | PvE match-3, validado y resuelto en servidor | Ranked PvP y matchmaking |
| Escenario de combate | Arena controlada dentro del mismo place, con retorno al punto de origen | Duelos sobre cualquier pendiente del mundo y otro place de combate |
| Equipo | Cinco slots y los cinco elementos existentes | Rediseñar el tamaño del equipo |
| Progresión | Nivel por especie con efecto real en ataque y vida; máximo de referencia actual: 50 | Evoluciones y variantes visuales de evolución |
| Economía | Bits, captura directa, fragmentos y duplicados como alimento | Bit Spheres, minerales como requisito y tienda compleja |
| Compañero | Una criatura seleccionada que sigue al jugador y se recupera al terminar duelo | Varios compañeros simultáneos |
| Salvajes | Aparición limitada por zona, idle y respawn | Patrulla, huida y persecución complejas |
| Interfaz | Colección/detalle, equipo e inventario | Dashboard de cinco pestañas independientes como requisito |
| Historia | Tutorial y reparación de un pequeño nodo del BitCore | Campaña extensa |
| Publicación | Primero alpha cerrada, después ampliación de acceso | Lanzamiento masivo sin pruebas previas |

**PvP amistoso es opcional:** solo entra si supera QA y no retrasa el ciclo PvE. El lanzamiento no depende de estrellas, títulos ni shields.

### Política de energía para esta etapa

Decisión aprobada para la alpha: **sin consumo de energía al combatir**. El PvE recuperado no descuenta energía. El HUD/atributos antiguos pueden seguir presentes hasta la simplificación de interfaz; no representan un requisito para iniciar encuentros. No se adopta un balance diario de energía para esta versión.

### Catálogo y zonas

Catálogo y zonas aprobados al cerrar el hito 0:

| Rol | Especies |
|---|---|
| Iniciales | SlimeFuego, LoboAgua, TortugaPlanta, HalconElectrico, GolemRoca |
| Obtenibles explorando | FireBaby, Demonslime1, Bloompup |
| Zonas | Forestal y Volcánica |

La selección queda cerrada como diseño. Ajustar regalos iniciales, visibilidad del catálogo y spawns sigue siendo trabajo de contenido/integración; no darlo por completado por figurar en esta tabla.

- Mantener cobertura de Fuego, Agua, Planta, Electricidad y Roca en las cinco especies iniciales.
- Seleccionar tres especies adicionales con motivos claros para explorarlas y capturarlas.
- FireBaby es el primer candidato a criatura patrón y pertenece al grupo capturable, no al grupo inicial.
- Los datos de especies fuera de alpha pueden conservarse, pero no deben aparecer como objetivos alcanzables.
- Revisar `StarterUnlocked`: actualmente hay nueve especies iniciales, lo que no coincide con este alcance.

## 3. Estado real al retomar

La revisión del 2026-11-02 fue estática y visual, en modo edición. **Todavía no valida jugabilidad, rendimiento ni guardado publicado.**

| Sistema | Evidencia encontrada | Estado |
|---|---|---|
| Mundo | Dos modelos Planet_A/Planet_B; aldea y decoración en el planeta principal | Base de prototipo |
| Arquitectura de combate | Orquestador y módulos DuelManager, MonsterDuel, GridResolver y ChallengeHandler | Separación realizada, integración rota |
| PvE | MonsterDuel devuelve un módulo con funciones PvP; faltan onMonsterChallenged/endMonsterDuel | Bloqueante |
| Tablero | Resolver llama isPathValid/solveCombos, ausentes en CombatGrid | Bloqueante |
| Daño | Resolver llama calculateDamage, pero MonsterCombat expone calculateTeamDamage | Bloqueante |
| Progresión | XP y alimentación; nivel máximo 50; sin evolveMonster | Parcial; nivel no aumenta stats de combate |
| Perfil | BackpackV1 y PvpStarsV1; GetAsync/SetAsync y guardado al salir | No apto aún para lanzamiento |
| Spawns | SpawnMatrix sin consumidor encontrado; monstruos colocados manualmente | Generación por zonas pendiente |
| Catálogo | 21 especies definidas | Datos, no 21 criaturas terminadas |
| Templates | Solo Demonslime1 en BeastibitTemplates | Producción de catálogo pendiente |
| FireBaby | Root, cuatro Motor6D, AnimationController y Animator; sin objetos Animation publicados en el modelo | Rig presente; animación sin completar |
| UI | CombatUI, RosterUI y HUD existentes | Base a validar y simplificar |

La [auditoría histórica](descarte/AUDITORIA_RETORNO_Y_PLAN_ALPHA_2026-11-02.md) conserva las referencias de código y riesgos detallados. La tabla anterior describe el estado **previo a reparar**; consultar el [registro de la sesión](SESION_2026-11-02_HITOS_0_1.md) y los hitos para el avance posterior.

## 4. Reglas del juego

### 4.1 Combate

- El cliente envía intención de jugada y presenta efectos; el servidor mantiene tablero, HP, resultado y recompensas.
- La ruta debe tener forma válida, coordenadas enteras y finitas, tamaño acotado y pasos adyacentes.
- Validar → aplicar swaps → resolver cascadas → resumir combos y elementos → calcular daño → sincronizar.
- Solo una resolución activa por jugador; asociar tareas y mensajes al duelo correspondiente.
- Tras cualquier espera, comprobar que el duelo siga activo antes de aplicar daño o premios.
- Iniciar un duelo reserva al salvaje y evita desafíos simultáneos sobre ese encuentro.
- Finalizar debe ser idempotente: premiar una vez y limpiar una vez.
- Victoria, derrota, desconexión, respawn, muerte y cancelación deben tener salida definida.
- No cambiar equipo ni consumir criaturas mientras el duelo usa ese equipo.

### 4.2 Captura y fragmentos

- La captura ocurre al ganar PvE, sin consumible externo.
- El fallo puede dar fragmentos de la especie para garantizar progreso acumulativo.
- Pity y fragmentos se mantienen como mecanismos de respaldo; sus valores son balance inicial, no promesas finales.
- El tutorial entrega una primera captura garantizada y explica la recompensa.
- Las recompensas se calculan en servidor y se incorporan al perfil antes de notificarlas como obtenidas.
- El resultado distingue captura nueva, duplicado, fragmentos y Bits.
- Solo se pueden conseguir especies incluidas en la alpha.

Referencia de balance a comprobar al reconstruir PvE:

| Rareza | Captura base | Fragmentos al fallar | Fragmentos para craft |
|---|---:|---:|---:|
| Común | 60 % | 5 | 30 |
| Rara | 40 % | 15 | 80 |
| Épica | 5 % | 25 | 150 |

La tabla épica solo se activa si una de las especies elegidas la requiere. No introduce épicos ni legendarios como obligación del lanzamiento. Referencia previa de pity: +5 puntos porcentuales por fallo; validar su alcance, tope y persistencia antes de activarlo.

### 4.3 Niveles y alimento

- Cantidad de copias y XP compartida por especie: no hay criaturas con identificadores individuales en esta alpha.
- Una función central de **stats efectivos** determina ataque y HP por especie y nivel. La usan PvE, equipo y cualquier PvP incluido.
- Mostrar el efecto de mejorar: stats anteriores/nuevos y progreso hacia el siguiente nivel.
- Confirmación clara antes de consumir: especie, cantidad, coste y XP recibida.
- Nunca consumir copias necesarias para el equipo ni dejar inválida la selección del compañero.
- Definir y validar el caso de alimentar con una copia de la misma especie; no confundir una copia sobrante con consumir la criatura objetivo.
- No cobrar alimento ni Bits cuando el objetivo ya alcanzó el límite.
- Evitar ciclos de transferencia de XP que permitan generar progreso artificial al reciclar alimento entrenado.

Referencia actual de código, pendiente de balance: XP base común/rara/épica/legendaria 10/25/60/150, multiplicador de nivel del alimento y coste en Bits igual a nivel objetivo × 15. Ya no existe multiplicador de evolución. No restaurar por accidente la fórmula antigua.

### 4.4 Recursos fuera de alcance

- No introducir Bit Spheres.
- Los minerales no se necesitan para progresar en esta alpha; ocultar su interfaz si no tienen uso.
- Conservar datos históricos al migrar perfiles, aunque una función esté desactivada.
- Los sistemas diferidos no deben bloquear el tutorial ni consumir espacio principal de UI.

## 5. Arquitectura y reglas técnicas

### Responsabilidades

| Componente | Responsabilidad |
|---|---|
| CombatServer | Inicialización y conexiones; no duplicar resolución de combate |
| MonsterDuel | Ciclo PvE, reserva de salvaje, IA, resultado y petición de recompensas |
| GridResolver + CombatGrid | Validación de ruta, swaps, cascadas y sincronización |
| MonsterCombat / stats compartidos | Única fórmula de stats efectivos y daño |
| TeamManager | Colección, cantidades, equipo, compañero y progresión |
| Servicio de perfil | Carga, migración, sesión, persistencia y guardado |
| Servicio de spawn | Población y respawn por zona |
| Presentación de compañero/duelo | Modelos, animaciones y limpieza visual |
| Cliente | UI, input, cámara, sonido y VFX |

Esta tabla describe responsabilidades, no obliga a renombrar todos los scripts. Reutilizar módulos válidos y corregir sus contratos antes de ampliar la arquitectura.

### Persistencia obligatoria

- Esquema versionado y migración compatible con BackpackV1 y PvpStarsV1.
- Diferenciar jugador nuevo, carga correcta y fallo de carga.
- No habilitar economía sobre un perfil sin carga confirmada ni guardar valores iniciales tras un error.
- Estrategia de sesión concurrente; UpdateAsync por sí solo no sustituye esa protección.
- Reintentos acotados, autosave, guardado al salir y BindToClose.
- Guardar cantidades cero correctamente y conceder regalos iniciales una sola vez.
- Persistir XP, copias, Bits, fragmentos, equipo y compañero seleccionado; añadir pity/energía si están activos.
- Preservar campos de sistemas diferidos durante la migración.
- Probar en un entorno publicado de prueba con datos separados de producción. En el código actual los DataStores se omiten en Studio.

### Integración y limpieza

- Validar antes de modificar: trabajar sobre copias y confirmar operaciones de forma atómica.
- Limitar frecuencia y tamaño de los mensajes remotos.
- Restaurar posición, movilidad, cámara y compañero elegido al salir de arena.
- Limpiar conexiones, estados, clones, reservas y tareas al finalizar o desconectarse.
- Evitar depender de búsquedas de templates en Workspace en la versión de lanzamiento.
- Mantener logs útiles de errores y desactivar ruido de debug para publicación.

### Convenciones de trabajo

- Servidor: reglas y datos sensibles. Cliente: presentación e input. Compartido: datos y lógica reutilizable apropiada.
- Remotes en ReplicatedStorage/RemoteEvents; templates de servidor en ServerStorage/BeastibitTemplates.
- Usar task.wait/task.spawn y evitar bucles sin cesión de ejecución.
- Documentar responsabilidad y contratos de módulos; comentar decisiones y casos difíciles sin repetir plantillas extensas en cada función trivial.
- Cambios pequeños y verificables. Respaldar/exportar scripts y place antes de reparaciones amplias.

## 6. Pipeline de modelos y dirección visual

### Criatura patrón

Terminar una sola criatura de punta a punta antes de producir las restantes. FireBaby es el primer candidato a evaluar porque ya tiene rig.

Contrato de modelo:

- Model, PrimaryPart/root estable, frente local -Z y arriba +Y.
- Pivote y escala coherentes; evitar offsets extremos como sustituto de una buena importación.
- Partes rígidas unidas correctamente; articulación mediante Motor6D o huesos según el rig.
- No anclar indiscriminadamente todas las piezas de un rig articulado.
- Animator y referencias explícitas a animaciones publicadas y autorizadas.
- Idle/Walk y feedback de ataque/impacto adecuados a la criatura; las criaturas simples pueden usar animación procedural.
- Sin scripts ajenos al contrato ni prompts heredados en los clones de compañero.
- Mismo template probado como salvaje, compañero y participante de arena.
- Icono propio obtenido del aspecto definitivo.

### Mundo

- Bitara Prime: low-poly estilizado, escala consistente y acentos digitales del BitCore.
- Aldea con llegada, guía y salida hacia la primera zona claramente identificables.
- Dos zonas con paletas, siluetas y especies distintas.
- Caminos e hitos visibles sobre la curvatura; evitar exploración de grandes áreas vacías.
- Arena con cámara, posiciones y superficie controladas; validar transición con gravedad custom.
- **Punto crítico P0:** ubicación y optimización funcional del combate dentro del mismo place. Mantener separación entre duelos, cupo acotado, streaming del origen, devolución exacta, limpieza de clones y exclusión del controlador planetario durante la arena. No cerrar hito 1 si el personaje queda atrapado o la cámara/gravedad interfieren.
- Sustituir placeholders como Kirby por criaturas propias.
- Mantener modelos de prueba identificados y separados del contenido de producción.

### UI y audio

- Colección con detalle de criatura, stats, nivel, cantidad y acciones pertinentes.
- Equipo de cinco slots e inventario de recursos activos.
- Seleccionar compañero y alimentar desde el detalle, evitando pestañas redundantes.
- Una fuente de estado, sin reglas de progresión duplicadas en la UI.
- Respetar safe areas, legibilidad y tamaño táctil; probar los dispositivos objetivo.
- Feedback claro de arrastre, combo, daño, captura, derrota y mejora; sonidos esenciales antes de efectos decorativos.
- El antiguo contrato de nombres/jerarquías UI es referencia histórica, no una garantía de compatibilidad. Inspeccionar el cliente antes de reemplazar interfaces.

## 7. Lore aplicado al primer recorrido

Premisa original: el **BitCore** era una red viva digital-orgánica que conectaba planetas. La **Corruption** fracturó esa red y sus fragmentos dieron origen a los Beastibits.

Recorrido de alpha:

1. Llegada a Bitara Prime y descubrimiento de un nodo dañado.
2. Un guardián presenta una meta breve y enseña el combate mediante un encuentro guiado.
3. Primera captura garantizada y explicación de colección/equipo.
4. Exploración para conseguir otra especie y mejorar el equipo.
5. Reparación de un pequeño nodo como cierre del recorrido inicial.
6. Korvaxis aparece como destino futuro, sin prometer acceso disponible.

El tutorial se puede retomar tras desconectarse y no vuelve a conceder recompensas ya entregadas.

## 8. Plan de ejecución

No hay fechas de entrega comprometidas. Se avanza por hitos verificables, sin producir todo el catálogo mientras el combate sigue bloqueado.

### Hito 0 — Preparar la recuperación · preparación completada

- [x] Crear respaldo interno de scripts/instancias y exportar fuentes originales a una ubicación versionable. No equivale a exportar un archivo binario `.rbxl`.
- [x] Revisar `mundosRoblox.zip` y localizar la implementación PvE anterior a la modularización.
- [x] Cerrar los ocho IDs del catálogo y los dos biomas de alpha.
- [x] Cerrar política de energía: sin consumo. Congelar por hoy el balance actual del alimento; revisar stats/costes en hito 2.
- [x] Definir objetivos: escritorio, móvil horizontal y ocho jugadores por servidor. La prueba de carga con ocho clientes corresponde a QA posterior.

**Cierre de preparación:** respaldo recuperable en Studio, fuentes originales en `backups/before_hitos_0_1_2026_11_02/`, catálogo y zonas cerrados. Antes de cerrar Studio hay que guardar el place; la exportación de fuentes no contiene las mallas binarias ni sustituye ese guardado.

### Hito 1 — Recuperar un combate completo · P0 · verificado en Studio

- [x] Restaurar/reconstruir MonsterDuel con funciones PvE reales.
- [x] Reconectar validateSwapPath, applySwapPath, resolveBoard y cálculo de daño.
- [x] Asegurar resumen elemental correcto antes de perder información de fichas eliminadas.
- [x] Añadir exclusión de resoluciones, límites de payload y validación de duelo tras esperas.
- [x] Probar inicio, jugada, cascadas, daño, victoria y derrota.
- [x] Implementar arena controlada y retorno seguro al mundo, con foco de streaming del origen.
- [x] Restaurar el compañero seleccionado y limpiar efectos/estados al terminar.
- [x] Resolver muerte, respawn, desconexión y cancelación sin bloqueos ni premios dobles.

**Cierre en Studio:** combate completo común ganado con HP normal, derrota rara con HP normal, combates consecutivos, combate tras respawn, cancelación durante resolución, muerte y desconexión por Kick. Recompensa única y ocho slots disponibles tras desconectar. Ver [evidencia de sesión](SESION_2026-11-02_HITOS_0_1.md). No equivale a validación de balance, datos publicados o carga con ocho clientes.

### Hito 2 — Hacer confiable y útil el progreso · P0

- [ ] Implementar servicio de perfil y migraciones sin perder campos anteriores.
- [ ] Proteger carga, sesión concurrente, autosave y cierre de servidor.
- [ ] Corregir cantidades cero y concesión única de iniciales.
- [ ] Guardar equipo, compañero y demás estado activo.
- [ ] Integrar stats efectivos por nivel en vida y daño.
- [ ] Validar captura, duplicados, fragmentos, craft y alimento con costes consistentes.
- [ ] Cerrar la UI de resultado y mejora con valores reales del servidor.
- [ ] Corregir mutación anticipada de equipo, acciones durante duelo y limpieza al salir.

**Cierre:** capturar, equipar, mejorar, salir y reingresar en servidor publicado de prueba conserva exactamente el estado. Una carga fallida no sobrescribe datos. Subir de nivel cambia los stats efectivos.

### Hito 3 — Terminar una porción representativa del juego · P1

- [ ] Validar criatura patrón en sus tres usos y crear su icono.
- [ ] Completar los otros siete modelos con el mismo pipeline.
- [ ] Terminar aldea, dos zonas y sus recorridos.
- [ ] Implementar spawn por zona con cupos, reserva y respawn.
- [ ] Vincular especies y dificultad al recorrido real; eliminar IDs inválidos de encuentros.
- [ ] Implementar tutorial retomable, primera captura y reparación del nodo.
- [ ] Simplificar UI y añadir feedback/sonido esencial.
- [ ] Ocultar especies y sistemas fuera de alcance.

**Cierre:** un jugador ajeno al proyecto completa el recorrido inicial sin instrucciones del creador. Todas las especies anunciadas son alcanzables y tienen presentación terminada.

### Hito 4 — QA y alpha cerrada · P1

- [ ] Probar móvil y escritorio: exploración, drag, cámara, UI, captura y mejora.
- [ ] Medir rendimiento en dispositivos y concurrencia definidos; fijar ajustes según resultados.
- [ ] Probar combates repetidos, desconexiones, reingreso, respawn y cierre de servidor.
- [ ] Verificar reservas de salvajes entre varios jugadores y ausencia de premios duplicados.
- [ ] Probar mensajes remotos inválidos, excesivos y fuera de estado.
- [ ] Si entra PvP amistoso, probar con dos jugadores y sin dependencia de ranking/shields.
- [ ] Medir entrada, tutorial, primera batalla, primera captura y primera mejora.
- [ ] Preparar nombre/presentación de alpha, descripción, icono y miniaturas de gameplay real.
- [ ] Abrir a un grupo pequeño y registrar problemas observados.
- [ ] Corregir bloqueantes antes de ampliar acceso.

**Cierre:** sin pérdidas de progreso, combates atascados ni bloqueos del recorrido; pruebas registradas y rendimiento aceptado en los objetivos definidos.

## 9. Decisiones pendientes acotadas

| Decisión | Cuándo cerrar | Recomendación |
|---|---|---|
| Coste y XP del alimento; copias de la misma especie | Hito 2 | Balance actual congelado durante recuperación; proteger copias en uso y evitar reciclaje de XP abusivo |
| Fórmula de stats por nivel y duración de batalla objetivo | Hitos 0–2 | Una fórmula central, simple y comprobable |
| Inclusión de PvP amistoso | Hito 4 | Solo si pasa QA sin retrasar PvE |

Estas decisiones no reabren dos planetas, catálogo completo ni evoluciones para la primera alpha.

## 10. Después de la alpha

Orden sujeto a resultados de las pruebas:

1. Ajustar tutorial, combate y progreso según abandonos y uso real.
2. Ampliar zonas y catálogo con el pipeline ya validado.
3. Introducir evolución y minerales con función clara.
4. Preparar Korvaxis como expansión.
5. Recuperar PvP competitivo con reglas de abandono, protección de datos y ranking coherentes.
6. Incorporar eventos, comportamiento avanzado de salvajes y monetización después de validar el ciclo principal.

## 11. Registro de cambios y evidencia

| Fecha | Cambio | Evidencia / estado |
|---|---|---|
| 2026-11-02 | Auditoría de documentación y place | Inspección estática y capturas; sin playtest |
| 2026-11-02 | Creador aprueba dirección reducida y unificación documental | Aprobación en conversación |
| 2026-11-02 | Se crea este plan y se archivan nueve documentos anteriores | Cambio documental; no implementa cambios del juego |
| 2026-11-02 | Cierre de preparación del hito 0 y recuperación de PvE/arena | Catálogo, zonas y objetivo aprobados; ver registro de sesión para pruebas y estado de cierre |
| 2026-11-02 | Cierre de hito 1 en Studio | Evidencia local en `backups/qa_hito1_final_2026_11_02/`; 34 fuentes finales exportadas y Play detenido |

Para cada cierre futuro registrar: hito/tarea, qué se cambió, dónde se probó, resultado y problemas pendientes.

**Sesión cerrada por hoy. Próxima sesión: hito 2, persistencia protegida y progreso útil. Guardar el place en Studio antes de cerrar la aplicación.**
