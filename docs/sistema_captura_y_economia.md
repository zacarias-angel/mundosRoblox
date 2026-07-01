# Sistema Numerico De Economia, Energia y XP Beastibit

Version: Balance Simplificado V2 (sin evoluciones, max nivel 50)
Estado: Propuesta jugable base

> **REVISIÓN 2026-06-30**: Se eliminan las evoluciones. Los Beastibits tienen una sola forma. Nivel máximo reducido a 50. Fórmula de XP simplificada (sin multiplicador de evolución). Costos de evolución eliminados.

## 1. Objetivos Del Sistema

Este sistema busca:

- Dar valor real a capturar Beastibit.
- Evitar inflacion de progreso.
- Hacer que cada duplicado tenga utilidad.
- Mantener ritmo diario saludable.
- Permitir progresion constante sin romper balance.
- Separar claramente economia, captura y alimentacion.

## 2. Recursos Principales

## 2.1 Bits

Moneda principal del juego.

Usos:

- Alimentar Beastibits (costo incremental por nivel).
- Comprar items.
- Expandir inventario.
- Crafting futuro.
- Reparaciones/eventos futuros.

## 2.2 Capture Energy

Energia usada para capturar Beastibit.

Reglas:

- Maximo diario: 100.
- Regeneracion: +1 cada 12 minutos.
- Recuperacion completa aproximada: 20 horas.

Fuentes adicionales:

- Login diario.
- Eventos.
- Pase.
- Recompensas PvP.
- Objetivos semanales.

## 2.3 Minerales Planetarios

Materiales (uso pendiente de redefinir, antes: evolución).

Ejemplos:

- Cristal Magma.
- Core Plasma.
- Raiz Lunar.
- Void Shard.
- Neon Crystal.

Objetivo:

- Pendiente de redefinir (antes: evolución).
- Posibles usos futuros: crafting, venta por Bits, intercambio.

## 3. Costos De Captura

## 3.1 Tabla Base

| Tipo | Energia | Bits |
|---|---:|---:|
| Comun | 5 | 50 |
| Raro | 10 | 120 |
| Epico | 16 | 260 |
| Legendario | 24 | 500 |

## 3.2 Captura Garantizada

No existe captura garantizada normalmente.

Excepciones:

- Tutorial.
- Historia principal.
- Eventos especiales.

## 3.3 Bonus De Primera Captura

Primera vez capturando especie:

- +50 Bits.
- +1 material aleatorio.
- Registro en Bestiario.

## 4. Sistema De XP Por Alimentacion

## 4.1 Filosofia

La progresion principal ocurre alimentando duplicados.

Reglas:

- Todos los Beastibit sirven como comida.
- Rarezas mas altas valen mas.
- Niveles altos aportan bonus adicional.
- Sin multiplicador de evolucion (los Beastibits no evolucionan).

## 4.2 Costo en Bits por Alimentacion

Cada vez que se alimenta un Beastibit, se requiere un costo en Bits ademas del duplicado sacrificado.

Formula:

$$
Costo\ Bits = NivelActual \times 15
$$

Donde `NivelActual` es el nivel del Beastibit que recibe la comida (antes de ganar XP).

| Nivel | Costo Bits |
|---|---:|
| 1 | 15 |
| 5 | 75 |
| 10 | 150 |
| 15 | 225 |
| 20 | 300 |
| 25 | 375 |
| 30 | 450 |
| 35 | 525 |
| 40 | 600 |
| 45 | 675 |
| 49 | 735 |

Proposito del costo:

- Dar uso constante a los Bits (sink de economia).
- Hacer que cada alimentacion sea una decision con peso.
- Evitar que el jugador suba Bestibitis muy rapido sin jugar.
- Ritmo: nivel bajo se paga con 1 victoria, nivel alto requiere farmear.

## 5. XP Base Por Rareza

| Rareza | XP Base |
|---|---:|
| Comun | 10 |
| Raro | 25 |
| Epico | 60 |
| Legendario | 150 |

## 6. Multiplicador Por Nivel

| Nivel | Multiplicador |
|---|---:|
| 1 - 5 | x0.8 |
| 6 - 10 | x1.0 |
| 11 - 15 | x1.25 |
| 16 - 20 | x1.5 |
| 21 - 30 | x1.8 |
| 31 - 40 | x2.2 |
| 41 - 50 | x3.0 |

## 7. Formula Final De XP

Formula:

$$
XP\ Final = XP\ Base\ Rareza \times Multiplicador\ Nivel
$$

Regla de redondeo: hacia arriba.

## 8. Ejemplos Reales

## 8.1 Comun Nivel 3

Calculo: $10 \times 0.8$

Resultado: 8 XP

## 8.2 Comun Nivel 15

Calculo: $10 \times 1.25$

Resultado: 13 XP

## 8.3 Raro Nivel 15

Calculo: $25 \times 1.25$

Resultado: 32 XP

## 8.4 Epico Nivel 40

Calculo: $60 \times 2.2$

Resultado: 132 XP

## 8.5 Legendario Nivel 50

Calculo: $150 \times 3.0$

Resultado: 450 XP

## 9. Costos De Nivel

## 9.1 XP Requerida Por Nivel

| Nivel | XP Total |
|---|---:|
| 1 | 0 |
| 5 | 40 |
| 10 | 120 |
| 15 | 260 |
| 20 | 500 |
| 25 | 950 |
| 30 | 1450 |
| 35 | 2200 |
| 40 | 3200 |
| 45 | 5000 |
| 50 | 6800 |

## 10. Valor De Duplicados

Los duplicados nunca deben sentirse basura.

Usos:

- XP.
- Venta.
- Reciclaje.
- Crafting.
- Misiones futuras.

## 11. Sistema Anti Frustracion

## 13.1 Pity De Captura

Cada captura fallida:

- +5% chance acumulativa temporal.

Reset:

- Al capturar exitosamente.

## 13.2 Proteccion De Favoritos

No se puede alimentar:

- Favoritos.
- Equipo activo.
- Beastibit historia/evento.

Sin confirmacion manual.

## 12. Economia Recomendada

Ritmo diario esperado.

Jugador casual:

- 8 a 15 capturas diarias.
- Varios niveles por dia.
- Progreso visible todos los dias.

Jugador hardcore:

- Farm de minerales.
- Optimizar XP.
- Buscar Beastibit raros.
- PvP competitivo.
