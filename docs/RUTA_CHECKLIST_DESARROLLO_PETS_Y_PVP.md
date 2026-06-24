# Ruta y Checklist de Desarrollo

Documento base: RESUMEN_JUEGO_ACTUALIZADO.md
Objetivo: definir la ruta de produccion sin codigo para sistemas de Beastibit, progresion y combate entre domadores.

Terminologia oficial:

- Beastibit = termino general para pet/mascota/monstruo.

## 1. Norte del proyecto

Meta de producto:

- Explorar mundos y biomas.
- Encontrar, combatir y capturar Beastibit.
- Progresar por niveles, evoluciones y equipo.
- Competir en combates de domadores con buen feedback visual.

Pilares:

- Claridad de progresion (siempre saber que desbloquea el jugador).
- Balance entre rareza, poder y accesibilidad.
- Contenido escalable por mundos/temporadas.

## 2. Checklist Maestro

## 2.1 Diseño global (bloqueante)

- [ ] Definir vision final del ciclo principal: explorar -> combatir -> capturar -> progresar -> desafiar.
- [ ] Definir cantidad objetivo de mundos para version 1.
- [ ] Definir cantidad objetivo de Beastibit totales para version 1.
- [ ] Definir presupuesto de tiempo por sistema (combate, mundo, bestiario, VFX, UX).
- [ ] Definir criterios de MVP vs Post-MVP.

## 2.2 Bestiario y catalogo de Beastibit

- [ ] Crear estructura del bestiario (ID unico, nombre, elemento, rareza, mundo, bioma, nivel minimo, evoluciones).
- [ ] Definir cantidad de Beastibit por mundo.
- [ ] Definir Beastibit por bioma dentro de cada mundo.
- [ ] Definir convivencia de especies por zona (quienes comparten spawn).
- [ ] Definir tabla de habitats y horarios/eventos si aplica.
- [ ] Definir estados del bestiario: visto, encontrado, capturado, evolucionado.
- [ ] Definir UI del bestiario con filtros (mundo, bioma, elemento, rareza, estado).

## 2.3 Progresion de Beastibit

- [ ] Definir nivel maximo de Beastibit para version 1.
- [ ] Definir curva de experiencia por nivel.
- [ ] Definir fuentes de experiencia (combate, entrenamiento, objetos).
- [ ] Definir reglas de subida de nivel por tipo de actividad.
- [ ] Definir sistema de 3 evoluciones por Beastibit (condiciones y costos).
- [ ] Definir si todas las especies tienen exactamente 3 evoluciones o excepciones.
- [ ] Definir impacto de evolucion en stats, habilidades y apariencia.

## 2.4 Economia de captura y drops

- [x] Definir que dropea al terminar una pantalla/encuentro.
- [x] Definir chance base de drop por tipo de enemigo/pantalla.
- [x] Definir si el Beastibit se captura directo o se convierte en recurso de captura. (Regla base: no captura gratis; usar recurso dedicado tipo Bit Spheres/Capture Cores, con excepciones de tutorial/historia)
- [x] Definir inventario de captura (espacio, limites, orden).
- [x] Definir reglas de duplicados (fusion, convertir, vender, comida). (Direccion confirmada: duplicados como comida/progreso; fusion deja de ser sistema principal)
- [x] Definir protecciones anti-frustracion (pity, garantias por racha).

## 2.5 Beastibit como comida/fusion

- [x] Definir cuales Beastibit pueden usarse como comida. (Base: duplicados, comunes y repetidos)
- [x] Definir si hay Beastibit protegidos que no pueden sacrificarse. (Base: favoritos, equipo activo, Beastibit de historia)
- [x] Definir valor de comida por rareza, nivel y evolucion.
- [x] Definir UI de confirmacion fuerte para evitar sacrificios accidentales.
- [x] Definir costo en recursos para alimentar/evolucionar. (Sin fusion como sistema principal)
- [ ] Definir limite diario/semanal si se necesita control economico.

## 2.6 Mundos, biomas y niveles

- [ ] Definir lista de mundos para version 1 (nombre, fantasia, dificultad).
- [ ] Definir biomas por mundo.
- [ ] Definir rango de niveles recomendado por mundo/bioma.
- [ ] Definir tabla de especies por mundo/bioma.
- [ ] Definir reglas de desbloqueo de mundo (historia, nivel, llaves, victorias).
- [ ] Definir progresion de dificultad entre mundos.

## 2.7 Spawn y comportamiento en el mundo

- [ ] Definir sistema de respawn de Beastibit (tiempo, cupos, zonas, limpieza).
- [ ] Definir densidad minima/maxima de Beastibit por bioma.
- [ ] Definir reglas de spawn por rareza.
- [ ] Definir movimiento de Beastibit en mundo (idle, patrulla, huida, persecucion).
- [ ] Definir reaccion al jugador (agresivo, neutro, evasivo).
- [x] Definir estados de IA basicos por especie. (Baseline tecnico implementado en combate NPC: sesgo elemental + fases por HP + especial con cooldown + anti-rachas)
- [x] Separar Beastibit companion de Beastibit salvaje para evitar prompts/flows cruzados. (Companion marca IsCompanion=true + IsMonster=false y MonsterPromptSetup excluye companions)
- [ ] Definir optimizacion y limites para rendimiento en servidores poblados.

## 2.8 Combate entre domadores (PvP)

- [ ] Definir formato oficial de duelo (bo1/bo3, tiempo, reglas de empate).
- [ ] Definir escalado de matchmaking (si aplica).
- [ ] Definir recompensas por victoria/derrota ademas de estrellas.
- [ ] Definir penalizaciones por abandono/desconexion.
- [ ] Definir ranking por temporadas (si aplica).
- [x] Definir rol de estrellas PvP en combate. (Solo prestigio/ranking social: +1 al ganar PvP, -1 al perder PvP, sin bonus de stats)
- [x] Definir hitos de titulos por estrellas PvP.
- [x] Definir fuentes y limites de Shield Charges (protectores de estrella por cargas limitadas).

## 2.9 Poderes y VFX

- [ ] Definir lista de poderes por elemento.
- [ ] Definir timing de VFX por evento (inicio ataque, impacto, critico, KO).
- [x] Definir baseline tecnico de feedback PvE inmediato. (Proyectil unico del salvaje por ataque + shake de camara corto al impacto)
- [ ] Definir capas de feedback (VFX, SFX, texto dano, shake, UI).
- [ ] Definir niveles de calidad grafica (bajo/medio/alto).
- [ ] Definir version de VFX MVP (simple) y version avanzada (post-MVP).

## 2.10 UX/UI y guias

- [ ] Diseñar UI del bestiario completa.
- [ ] Diseñar UI de captura, evolucion y alimentacion.
- [ ] Diseñar UI de progresion por mundo/bioma.
- [ ] Diseñar guia de domador (tutorial progresivo por etapas).
- [ ] Definir mensajes de onboarding para nuevos sistemas.
- [x] Implementar base tecnica de UI de mochila/formacion en script cliente separado de CombatUI.
- [x] Migrar mochila y slots de team a ranuras cuadradas (grid) preparadas para imagen por Beastibit.
- [x] Ajustar UI de mochila a safe area para no superponerse al menu nativo/topbar de Roblox.

## 2.11 Datos y balance

- [ ] Definir esquema de datos maestro para especies y progresion.
- [x] Definir esquema base de visual companion por especie en data. (MonstersData: img/evoActual + CompanionFollow)
- [ ] Definir contrato tecnico obligatorio para modelos 3D Beastibit (PrimaryPart, orientacion, pivote, uniones).
- [ ] Definir convencion unica de jerarquia para templates (Root, geometry, attachments).
- [ ] Definir guia de escala y volumen visual por tier/rareza para evitar outliers.
- [ ] Definir validacion de DuelLinePlacement como ajuste fino y no como parche estructural.
- [ ] Definir versionado de datos para futuras expansiones.
- [ ] Definir metodologia de balance (objetivos por tier/rareza).
- [ ] Definir metricas a monitorear (uso de Beastibit, winrate, retencion por mundo).

## 2.12 QA y publicacion

- [ ] Definir plan de pruebas funcionales por sistema.
- [ ] Definir plan de pruebas de balance.
- [ ] Definir plan de pruebas de rendimiento (movil y servidor).
- [ ] Incluir test obligatorio de modelos Beastibit: follower + linea de duelo PvP + linea de duelo PvE.
- [ ] Incluir test obligatorio de VFX desde slot 1 (BasePart y Model).
- [ ] Incluir test de estabilidad estructural: sin piezas sueltas al spawnear.
- [ ] Definir checklist de salida por version.

## 3. Ruta Recomendada (sin codigo)

## Fase 0: Fundacion de diseño (1 semana)

Objetivo:

- Congelar reglas base del juego para evitar retrabajo.

Entregables:

- Documento de loop principal.
- Documento de mundos/biomas.
- Documento de progresion de Beastibit (nivel + evolucion + comida).
- Documento de reglas de captura y drops.

Criterio de cierre:

- Ningun sistema grande sin reglas definidas.

## Fase 1: Bestiario y contenido base (1-2 semanas)

Objetivo:

- Definir catalogo inicial jugable completo.

Entregables:

- Lista oficial de especies para version 1.
- Distribucion por mundo y bioma.
- Tabla de rarezas y niveles.
- Arbol de 3 evoluciones por especie.

Criterio de cierre:

- Se puede responder: cuantos Beastibit hay, donde salen y como progresan.

## Fase 2: Captura, drops y progreso del jugador (1-2 semanas)

Objetivo:

- Cerrar la economia de obtencion y crecimiento.

Entregables:

- Reglas finales de drops por pantalla.
- Reglas de captura y duplicados.
- Reglas de alimentacion/fusion y restricciones.
- Curva de experiencia y costos de evolucion.

Criterio de cierre:

- El jugador puede conseguir Beastibit, subirlos y evolucionarlos sin huecos de diseño.

## Fase 3: Spawn e IA de mundo (1-2 semanas)

Objetivo:

- Hacer vivo el mundo con aparicion y movimiento coherente de especies.

Entregables:

- Matriz de spawn por bioma.
- Reglas de respawn (tiempo/cupo/rareza).
- Comportamientos base de movimiento y reaccion.
- Reglas de rendimiento por servidor.

Criterio de cierre:

- El mundo mantiene poblacion estable y comportamiento legible.

## Fase 4: PvP de domadores y presentacion (1-2 semanas)

Objetivo:

- Consolidar la capa competitiva y feedback de combate.

Entregables:

- Reglas finales de duelo y recompensas.
- Reglas de abandono y fairness.
- Lista de poderes y VFX MVP por elemento.
- Lineamientos de UX para lectura de combate.

Criterio de cierre:

- Combate entre domadores claro, justo y visualmente entendible.

## Fase 5: Balance, QA y salida (1 semana)

Objetivo:

- Estabilizar y preparar release.

Entregables:

- Ronda de balance por rareza/elemento.
- QA funcional integral.
- QA de rendimiento movil/servidor.
- Checklist de publicacion firmado.

Criterio de cierre:

- Build lista para jugadores externos.

## 4. Priorizacion Inmediata (siguiente paso)

Sprint siguiente recomendado:

1. Cerrar cantidad de mundos y Beastibit del MVP.
2. Cerrar reglas de captura/drop y duplicados.
3. Cerrar regla exacta de 3 evoluciones por especie.
4. Cerrar politica de comida/fusion de Beastibit.
5. Cerrar matriz mundo/bioma/nivel para spawn.

## 5. Decision Log (para ir llenando)

- [ ] Decision 001: cantidad de mundos MVP.
- [ ] Decision 002: cantidad total de especies MVP.
- [ ] Decision 003: regla final de captura por pantalla.
- [ ] Decision 004: politica de duplicados y comida.
- [ ] Decision 005: requisitos finales de evolucion.
- [ ] Decision 006: recompensas PvP finales.
- [ ] Decision 007: baseline de VFX MVP.
- [x] Decision 008: baseline IA de combate NPC v1 (sesgo elemental, fases de HP, especial con cooldown y anti-rachas).
- [x] Decision 009: companion follow configurado por especie en MonstersData (CompanionFollow) en lugar de atributos por modelo.
- [x] Decision 010: follow de companion adaptado a gravedad planetaria usando UpVector local.
- [x] Decision 011: estrellas PvP son prestigio social, sin impacto de poder (ataque/vida/stats).
- [x] Decision 012: captura base sin modo gratis; usar recurso dedicado de captura (nombre final pendiente).
- [x] Decision 013: duplicados se priorizan como comida para progresion de Beastibit.
- [x] Decision 014: fusion deja de ser sistema principal; progresion por niveles + evolucion con materiales planetarios.
- [x] Decision 015: protector de estrella sera por cargas limitadas (Shield Charges), no proteccion infinita.
- [x] Decision 016: PvE salvaje usa unidad unica (x1), no equipo NPC simulado x5.
- [x] Decision 017: formula PvE salvaje confirmada: HP base x3.5 y daño base x combo x2.5.
- [x] Decision 018: si el elemento elegido por IA no coincide con el elemento real del salvaje, ataque = miss (0 daño).
- [x] Decision 019: VFX PvE de ataque salvaje usa 1 proyectil por ataque, sin escalar cantidad por combo.
- [x] Decision 020: camera shake corto en cliente al impacto del salvaje como feedback visual.
- [x] Decision 021: evolucion cuesta Bits + minerales por etapa (500/10 y 2500/30), mineral mapeado por elemento.
- [x] Decision 022: XP por alimentacion usa rareza base (C10/R25/E60/L150) x multiplicador de evolucion del alimento.
- [x] Decision 023: craft por fragmentos desbloquea Beastibit non-tenidos (C30/R80/E150 frags).
- [x] Decision 024: titulos PvP en 7 hitos (Rookie 0, Hunter 10, Tamer 25, Elite 50, Master 100, Legend 200, Bitlord 500).
- [x] Decision 025: Shield Charges max 3, +1 diario +1 semanal, se consume al perder PvP protegiendo estrellas.
- [x] Decision 026: Bits y minerales persistidos en BackpackV1 junto con evoluciones y XP.
- [x] Decision 027: proteccion de alimento: no sacrificar equipo activo ni seguidor, confirmacion UI obligatoria.

## 6. Riesgos que hay que controlar

- Riesgo de sobrecarga de sistemas si no se congela primero la economia de progresion.
- Riesgo de desbalance fuerte si no se define tiering por rareza temprano.
- Riesgo de retrabajo de UI si no se cierran reglas de captura/evolucion antes.
- Riesgo de lag de servidor si el sistema de respawn no nace con limites.
- Riesgo de debt tecnico en placement/VFX si no se impone normalizacion de modelos 3D.

## 7. Regla operativa para seguir

No pasar a implementacion tecnica de una fase sin cerrar sus reglas de diseño y su checklist minimo.
