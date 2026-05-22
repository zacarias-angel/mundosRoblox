# Ruta y Checklist de Desarrollo

Documento base: RESUMEN_JUEGO_ACTUALIZADO.md
Objetivo: definir la ruta de produccion sin codigo para sistemas de pets/monstruos, progresion y combate entre domadores.

## 1. Norte del proyecto

Meta de producto:

- Explorar mundos y biomas.
- Encontrar, combatir y capturar pets/monstruos.
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
- [ ] Definir cantidad objetivo de pets totales para version 1.
- [ ] Definir presupuesto de tiempo por sistema (combate, mundo, bestiario, VFX, UX).
- [ ] Definir criterios de MVP vs Post-MVP.

## 2.2 Bestiario y catalogo de pets

- [ ] Crear estructura del bestiario (ID unico, nombre, elemento, rareza, mundo, bioma, nivel minimo, evoluciones).
- [ ] Definir cantidad de pets por mundo.
- [ ] Definir pets por bioma dentro de cada mundo.
- [ ] Definir convivencia de especies por zona (quienes comparten spawn).
- [ ] Definir tabla de habitats y horarios/eventos si aplica.
- [ ] Definir estados del bestiario: visto, encontrado, capturado, evolucionado.
- [ ] Definir UI del bestiario con filtros (mundo, bioma, elemento, rareza, estado).

## 2.3 Progresion de pets

- [ ] Definir nivel maximo de pet para version 1.
- [ ] Definir curva de experiencia por nivel.
- [ ] Definir fuentes de experiencia (combate, entrenamiento, objetos).
- [ ] Definir reglas de subida de nivel por tipo de actividad.
- [ ] Definir sistema de 3 evoluciones por pet (condiciones y costos).
- [ ] Definir si todas las especies tienen exactamente 3 evoluciones o excepciones.
- [ ] Definir impacto de evolucion en stats, habilidades y apariencia.

## 2.4 Economia de captura y drops

- [ ] Definir que dropea al terminar una pantalla/encuentro.
- [ ] Definir chance base de drop por tipo de enemigo/pantalla.
- [ ] Definir si el pet se captura directo o se convierte en recurso de captura.
- [ ] Definir inventario de captura (espacio, limites, orden).
- [ ] Definir reglas de duplicados (fusion, convertir, vender, comida).
- [ ] Definir protecciones anti-frustracion (pity, garantias por racha).

## 2.5 Pets como comida/fusion

- [ ] Definir cuales pets pueden usarse como comida.
- [ ] Definir si hay pets protegidos que no pueden sacrificarse.
- [ ] Definir valor de comida por rareza, nivel y evolucion.
- [ ] Definir UI de confirmacion fuerte para evitar sacrificios accidentales.
- [ ] Definir costo en recursos para fusionar/alimentar.
- [ ] Definir limite diario/semanal si se necesita control economico.

## 2.6 Mundos, biomas y niveles

- [ ] Definir lista de mundos para version 1 (nombre, fantasia, dificultad).
- [ ] Definir biomas por mundo.
- [ ] Definir rango de niveles recomendado por mundo/bioma.
- [ ] Definir tabla de especies por mundo/bioma.
- [ ] Definir reglas de desbloqueo de mundo (historia, nivel, llaves, victorias).
- [ ] Definir progresion de dificultad entre mundos.

## 2.7 Spawn y comportamiento en el mundo

- [ ] Definir sistema de respawn de pets (tiempo, cupos, zonas, limpieza).
- [ ] Definir densidad minima/maxima por bioma.
- [ ] Definir reglas de spawn por rareza.
- [ ] Definir movimiento de pets en mundo (idle, patrulla, huida, persecucion).
- [ ] Definir reaccion al jugador (agresivo, neutro, evasivo).
- [ ] Definir estados de IA basicos por especie.
- [ ] Definir optimizacion y limites para rendimiento en servidores poblados.

## 2.8 Combate entre domadores (PvP)

- [ ] Definir formato oficial de duelo (bo1/bo3, tiempo, reglas de empate).
- [ ] Definir escalado de matchmaking (si aplica).
- [ ] Definir recompensas por victoria/derrota ademas de estrellas.
- [ ] Definir penalizaciones por abandono/desconexion.
- [ ] Definir ranking por temporadas (si aplica).

## 2.9 Poderes y VFX

- [ ] Definir lista de poderes por elemento.
- [ ] Definir timing de VFX por evento (inicio ataque, impacto, critico, KO).
- [ ] Definir capas de feedback (VFX, SFX, texto dano, shake, UI).
- [ ] Definir niveles de calidad grafica (bajo/medio/alto).
- [ ] Definir version de VFX MVP (simple) y version avanzada (post-MVP).

## 2.10 UX/UI y guias

- [ ] Diseñar UI del bestiario completa.
- [ ] Diseñar UI de captura, evolucion y alimentacion.
- [ ] Diseñar UI de progresion por mundo/bioma.
- [ ] Diseñar guia de domador (tutorial progresivo por etapas).
- [ ] Definir mensajes de onboarding para nuevos sistemas.

## 2.11 Datos y balance

- [ ] Definir esquema de datos maestro para especies y progresion.
- [ ] Definir versionado de datos para futuras expansiones.
- [ ] Definir metodologia de balance (objetivos por tier/rareza).
- [ ] Definir metricas a monitorear (uso de pets, winrate, retencion por mundo).

## 2.12 QA y publicacion

- [ ] Definir plan de pruebas funcionales por sistema.
- [ ] Definir plan de pruebas de balance.
- [ ] Definir plan de pruebas de rendimiento (movil y servidor).
- [ ] Definir checklist de salida por version.

## 3. Ruta Recomendada (sin codigo)

## Fase 0: Fundacion de diseño (1 semana)

Objetivo:

- Congelar reglas base del juego para evitar retrabajo.

Entregables:

- Documento de loop principal.
- Documento de mundos/biomas.
- Documento de progresion de pets (nivel + evolucion + comida).
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

- Se puede responder: cuantos pets hay, donde salen y como progresan.

## Fase 2: Captura, drops y progreso del jugador (1-2 semanas)

Objetivo:

- Cerrar la economia de obtencion y crecimiento.

Entregables:

- Reglas finales de drops por pantalla.
- Reglas de captura y duplicados.
- Reglas de alimentacion/fusion y restricciones.
- Curva de experiencia y costos de evolucion.

Criterio de cierre:

- El jugador puede conseguir pets, subirlos y evolucionarlos sin huecos de diseño.

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

1. Cerrar cantidad de mundos y pets del MVP.
2. Cerrar reglas de captura/drop y duplicados.
3. Cerrar regla exacta de 3 evoluciones por especie.
4. Cerrar politica de comida/fusion de pets.
5. Cerrar matriz mundo/bioma/nivel para spawn.

## 5. Decision Log (para ir llenando)

- [ ] Decision 001: cantidad de mundos MVP.
- [ ] Decision 002: cantidad total de especies MVP.
- [ ] Decision 003: regla final de captura por pantalla.
- [ ] Decision 004: politica de duplicados y comida.
- [ ] Decision 005: requisitos finales de evolucion.
- [ ] Decision 006: recompensas PvP finales.
- [ ] Decision 007: baseline de VFX MVP.

## 6. Riesgos que hay que controlar

- Riesgo de sobrecarga de sistemas si no se congela primero la economia de progresion.
- Riesgo de desbalance fuerte si no se define tiering por rareza temprano.
- Riesgo de retrabajo de UI si no se cierran reglas de captura/evolucion antes.
- Riesgo de lag de servidor si el sistema de respawn no nace con limites.

## 7. Regla operativa para seguir

No pasar a implementacion tecnica de una fase sin cerrar sus reglas de diseño y su checklist minimo.
