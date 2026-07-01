# Decisiones MVP Alpha V1

Fecha: 2026-06-12
Estado: Definición de diseño (Fase 0 - Fundación)

---

## 1. Scope del Alpha

| Variable | Decisión |
|----------|----------|
| Planetas | **2** |
| Beastibits totales | **20** (10 común + 5 raro + 5 épico/legendario) |
| Biomas Mundo 1 | **4** (los del tablero match-3) |
| Biomas Mundo 2 | **2** (uno específico + uno mixto) |
| Sistema de captura | Según `lore/sistema_captura_y_economia.md` |

---

## 2. Planetas y Biomas

### Mundo 1 (starter, dificultad baja-media)

| Bioma | Elemento | Dificultad |
|-------|----------|------------|
| Volcánico | Fuego | Baja |
| Oceánico | Agua | Baja |
| Forestal | Planta | Baja |
| Tormenta | Electricidad | Media |

### Mundo 2 (avanzado, dificultad media-alta)

| Bioma | Elemento | Dificultad |
|-------|----------|------------|
| Montaña | Roca | Media |
| Energía | Mixto/Neutral | Alta |

---

## 3. Distribución de Beastibits

### Mundo 1 (14 especies)

| Rareza | Cantidad | Ya existen | Faltan crear |
|--------|----------|-----------|-------------|
| Común | 7 | SlimeFuego, LoboAgua, TortugaPlanta, HalcónEléctrico, ZorroBrasa, MareaLince | 1 más |
| Raro | 3 | Demonslime1 (Fuego), HongoGuardian (Planta), RayoMantis (Eléctrico) | 0 |
| Épico/Legendario | 3 | 0 | 3 nuevos |

### Mundo 2 (6 especies)

| Rareza | Cantidad | Ya existen | Faltan crear |
|--------|----------|-----------|-------------|
| Común | 3 | GolemRoca | 2 más |
| Raro | 2 | ObsidianaToro (Roca) | 1 más |
| Épico/Legendario | 2 | 0 | 2 nuevos |

### Pendientes de diseño
- [ ] Crear 3 Beastibits comunes nuevos (1 Mundo 1, 2 Mundo 2)
- [ ] Crear 1 Beastibit raro nuevo (Mundo 2)
- [ ] Crear 5 Beastibits épico/legendarios (3 Mundo 1, 2 Mundo 2)
- [ ] Definir nombre, stats base y modelo 3D para cada uno (sin evoluciones)

---

## 4. Economía (basado en `sistema_captura_y_economia.md`)

### 4.1 Recursos

| Recurso | Función |
|---------|---------|
| **Bits** | Moneda principal (alimentación, items, inventario) |
| **Capture Energy** | Energía para intentar captura (máx 100 diario) |
| **Bit Spheres** | Recurso consumible de captura (reemplaza captura gratis) |
| **Minerales Planetarios** | Materiales (específicos por planeta, uso pendiente de redefinir) |

### 4.2 Energía de captura (CORREGIR vs código)

**Doc actual dice**: +1 cada 12 min → ~20h para llenar
**Código en `EconomyState.server.lua`**: +5 cada 12 min → ~4h para llenar

**Sugerencia**: Mantener el +5 del código para alpha (ritmo más ágil, ~5-6 capturas comunes/día) y actualizar el doc.

### 4.3 Costos de captura

| Tipo | Energía | Bits |
|------|---------|------|
| Común | 5 | 50 |
| Raro | 10 | 120 |
| Épico | 16 | 260 |
| Legendario | 24 | 500 |

### 4.4 Recursos de captura

**Nombre sugerido**: **Bit Spheres** (más corto, alineado con "Bits")

Los Bit Spheres se obtienen por drops, recompensas y eventos. No hay captura gratis (excepto tutorial/historia).

### 4.5 Drops por tipo de encuentro (propuesta nueva)

| Tipo encuentro | Bits base | Chance Bit Sphere | Chance mineral |
|---------------|-----------|-------------------|----------------|
| Común | 30-60 | 15% | 10% |
| Raro | 80-150 | 25% | 20% |
| Élite | 200-400 | 40% | 35% |
| Jefe | 500-1000 | 60% (mín 1) | 50% |

---

## 5. Progresión de Beastibit

### 5.1 Niveles y XP (máx nivel 50)

| Rareza | XP Base al alimentar |
|--------|---------------------|
| Común | 10 |
| Raro | 25 |
| Épico | 60 |
| Legendario | 150 |

Fórmula XP: `XP Final = XP Base × MultNivel`

Costo Bits: `NivelActual × 15` (se paga al alimentar, además del duplicado sacrificado)

- El nivel del Beastibit usado como comida también multiplica la XP

### 5.2 Sin evoluciones

Los Beastibits **no evolucionan**. Suben de nivel (1 a 50) pero mantienen una sola forma. Esto elimina los costos de Bits + minerales para evolución.

### 5.3 Protecciones

- No se puede sacrificar: favoritos, equipo activo, Beastibits de historia
- Pity de captura: +5% chance acumulativa por fallo, reset al capturar

---

## 6. PvP y Ranking

### 6.1 Estrellas PvP (ya implementado)

- Victoria: +1 estrella
- Derrota: -1 estrella (mín 0)
- **Sin impacto en stats** (prestigio social puro)

### 6.2 Pendientes PvP

- [ ] Tabla de títulos por hitos de estrellas
- [ ] Shield Charges (protectores de estrella, cargas limitadas)
- [ ] Reglas de abandono/desconexión/empate
- [ ] Recompensas adicionales por victoria (Bits, energía, Bit Spheres)

---

## 7. Lo que falta definir para cerrar Fase 0

| # | Decisión | Prioridad |
|---|----------|-----------|
| 1 | Nombre oficial de los 2 planetas | Alta |
| 2 | Nombre de los 4 minerales planetarios (uno por bioma Mundo 1) | Alta |
| 3 | Nombre de los 2 minerales del Mundo 2 | Alta |
| 4 | Las 3 especies comunes nuevas (stats base, sin evo) | Alta |
| 5 | La 1 especie rara nueva (stats base, sin evo) | Alta |
| 6 | Las 5 especies épico/legendarias (stats base, sin evo) | Alta |
| 7 | Distribución exacta de especies por bioma | Alta |
| 8 | Niveles de spawn por bioma | Media |
| 9 | Títulos PvP por hitos de estrellas | Media |
| 10 | Valores de Shield Charges | Media |
| 11 | Alinear doc de energía con código (+5 cada 12 min) | Baja |

---

## 8. Siguiente paso técnico (post-diseño)

Una vez cerradas las decisiones de diseño arriba, el próximo paso técnico sería:
1. Implementar sistema de inventario de Beastibits con DataStore
2. Implementar drops post-combate PvE (Bits, Bit Spheres, minerales)
3. Implementar lógica de captura (consumir Bit Sphere + energía, roll de éxito)
4. Conectar sistema de niveles/XP por alimentación
5. ~~Conectar costos de evolución (Bits + minerales)~~ → ELIMINADO (sin evoluciones)

---

## 9. Notas técnicas

- El sistema de energía ya corre en `EconomyState.server.lua` con atributos por jugador
- Los atributos de Bits están listos, falta conectarlos a recompensas reales
- `MonstersData.lua` ya tiene 11 Beastibits definidos con stats base, imágenes y modelos
- `PetCubeService.lua` ya maneja spawn de seguidores 3D
- El motor match-3 y duelos PvP/PvE están funcionales
- Las estrellas PvP ya persisten en DataStore
