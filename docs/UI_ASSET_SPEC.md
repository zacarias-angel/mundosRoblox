# Especificacion de Assets UI - Contrato Tecnico

Fecha: 2026-06-13

---

## Regla de oro

> **El script busca los elementos por `Name`. Si el nombre no coincide exactamente, el script crea el elemento desde cero.** Para reemplazar un asset con diseño personalizado, insertalo en Studio con el nombre y jerarquia exacta indicados abajo **antes** de que el script se ejecute.

Todos los scripts usan `FindFirstChild("NombreExacto")` o `WaitForChild("NombreExacto")`. Respetar mayusculas, minusculas y guiones.

---

## 1. RosterUI (Dashboard)

**ScreenGui:** `RosterUI` dentro de `PlayerGui`

### 1.1 Overlay principal

```
PlayerGui
└── RosterUI (ScreenGui)
    ├── RosterToggleButton (TextButton)     → boton para abrir/cerrar
    └── RosterOverlay (Frame)               → panel completo, Visible=false por defecto
        ├── HeaderTitle (TextLabel)         → titulo de la pestana activa
        ├── CloseButton (TextButton)        → boton cerrar [X]
        ├── NavBar (Frame)                  → barra de navegacion
        │   ├── NavBtn_Inventario (TextButton)
        │   ├── NavBtn_Beastibit (TextButton)
        │   ├── NavBtn_Team (TextButton)
        │   ├── NavBtn_Seguidor (TextButton)
        │   └── NavBtn_Craft (TextButton)
        └── ContentFrame (Frame)            → area de contenido de tabs
            ├── Tab_Inventario (Frame)
            ├── Tab_Beastibit (Frame)
            ├── Tab_Team (Frame)
            ├── Tab_Seguidor (Frame)
            └── Tab_Craft (Frame)
```

### 1.2 Medidas y posiciones clave

| Elemento | Posicion | Tamaño |
|----------|----------|--------|
| `RosterToggleButton` | `{0, 16}{0, topOffset}` | `{0, 152}{0, 34}` |
| `RosterOverlay` | `{0.5, 0}{0.5, 0}` (Anchor 0.5,0.5) | `{0, 780}{0, 480}` |
| `HeaderTitle` | `{0, 16}{0, 10}` | `{0.5, 0}{0, 24}` |
| `CloseButton` | `{1, -14}{0, 10}` (Anchor 1,0) | `{0, 70}{0, 26}` |
| `NavBar` | `{0, 14}{0, 48}` | `{1, -28}{0, 36}` |
| `ContentFrame` | `{0, 14}{0, 88}` | `{1, -28}{1, -102}` |

### 1.3 Tab: Inventario

```
Tab_Inventario
└── InvScroll (ScrollingFrame)   → {0,8}{0,8} size {1,-16}{1,-16}
    ├── Section_Bits (Frame)     → {1,0}{0,52}
    │   ├── SectionTitle (TextLabel)
    │   └── Row_Bits (Frame)     → {1,0}{0,44}
    │       ├── Icon (ImageLabel) → {0,6}{0,4} {0,36}{0,36}
    │       ├── Name (TextLabel)  → {0,48}{0,6} {1,-130}{0,32}
    │       └── Count (TextLabel) → {1,-8}{0,6} {0,80}{0,32} Anchor(1,0)
    ├── Section_Fragmentos (Frame)
    │   └── Row_Fragmento_{nombre} (Frame)  → se crean dinamicamente
    └── Section_Minerales (Frame)
        └── Row_{mineralName} (Frame)       → se crean dinamicamente
```

### 1.4 Tab: Beastibit (coleccion)

```
Tab_Beastibit
└── CollectionScroll (ScrollingFrame)   → {0,8}{0,8} size {1,-16}{1,-16}
    └── Card_{monsterId} (Frame)        → {0,90}{0,100}  (dinamicos x20)
        ├── Icon (ImageLabel)           → {0.5,-32}{0,6} {0,64}{0,64}
        ├── LockIcon (TextLabel)        → solo si esta bloqueado
        ├── RarityBar (Frame)           → {0,0}{0,80} {1,0}{0,3}
        └── Name (TextLabel)            → {0,4}{0,84} {1,-8}{0,16}
```

### 1.5 Tab: Team

```
Tab_Team
├── TeamInfo (TextLabel)         → {0,12}{0,8} {1,-24}{0,22}
├── TeamSlots (Frame)            → {0,12}{0,36} {1,-24}{0,90}
│   ├── SlotTitle (TextLabel)
│   └── TeamSlotsGrid (Frame)    → {0,8}{0,26} {1,-16}{0,56}
│       ├── TeamSlot_1 (ImageButton) → {0,56}{0,56}
│       ├── TeamSlot_2 (ImageButton)
│       ├── TeamSlot_3 (ImageButton)
│       ├── TeamSlot_4 (ImageButton)
│       └── TeamSlot_5 (ImageButton)
│           ├── Icon (ImageLabel) → {0,4}{0,4} {1,-8}{1,-22}
│           ├── Name (TextLabel)  → {0.5,0}{1,-1} {1,-4}{0,14} Anchor(0.5,1)
│           └── Badge (TextLabel) → {0,3}{0,3} {0,20}{0,12}
├── BackpackTitle (TextLabel)    → {0,12}{0,134} {1,-24}{0,20}
└── TeamBackpackScroll (ScrollingFrame) → {0,12}{0,158} {1,-24}{1,-170}
    └── TBItem_{monsterId} (ImageButton) → {0,74}{0,74} (dinamicos)
        ├── Icon (ImageLabel)
        └── Name (TextLabel)
```

### 1.6 Tab: Seguidor

```
Tab_Seguidor
├── SeguidorInfo (TextLabel)          → {0,12}{0,8} {1,-24}{0,22}
├── CurrentFollower (Frame)           → {0,12}{0,36} {0,120}{0,130}
│   ├── CurFollowerTitle (TextLabel)  → {0,0}{0,6} {1,0}{0,18}
│   ├── Icon (ImageLabel)             → {0,15}{0,28} {0,90}{0,90}
│   └── Name (TextLabel)              → {0,4}{0,118} {1,-8}{0,14}
└── FollowerScroll (ScrollingFrame)   → {0,144}{0,36} {1,-156}{1,-48}
    └── FollowerCard_{monsterId} (ImageButton) → {0,80}{0,90} (dinamicos)
        ├── Icon (ImageLabel)
        ├── Name (TextLabel)
        └── FollowerBadge (TextLabel) → solo si es el seguidor activo
```

### 1.7 Tab: Craft

```
Tab_Craft
├── CraftInfo (TextLabel)                  → {0,12}{0,8} {1,-24}{0,22}
├── CraftSelectionScroll (ScrollingFrame)  → {0,12}{0,36} {0,340}{1,-48}
│   └── CraftSel_{monsterId} (ImageButton) → {0,74}{0,74} (dinamicos)
│       ├── Icon (ImageLabel)
│       └── Name (TextLabel)
└── CraftDetail (Frame)                    → {0,362}{0,36} {1,-374}{1,-48}
    ├── CraftDetailIcon (ImageLabel)       → {0,12}{0,12} {0,80}{0,80}
    ├── CraftDetailName (TextLabel)        → {0,100}{0,14} {1,-112}{0,24}
    ├── CraftDetailEvo (TextLabel)         → {0,100}{0,40} {1,-112}{0,18}
    ├── CraftDetailFrags (TextLabel)       → {0,100}{0,60} {1,-112}{0,18}
    └── CraftDetailActions (Frame)         → {0,12}{1,-80} {1,-24}{0,68}
        ├── EvolveButton (TextButton)      → {0,0}{0,0} {1,0}{0,30}
        └── FeedButton (TextButton)        → {0,0}{0,36} {1,0}{0,30}
```

---

## 2. CombatUI

**ScreenGui:** `CombatUI` dentro de `PlayerGui`

### 2.1 Jerarquia

```
PlayerGui
└── CombatUI (ScreenGui)
    ├── GridContainer (Frame)           → tablero match-3
    │   ├── TimerBar (Frame)            → barra de tiempo del turno
    │   ├── GridFrame (Frame)           → grilla 5x5
    │   │   └── Cell_{col}_{row} (ImageButton) x25
    │   │       ├── Scale (UIScale)
    │   │       └── Label (TextLabel)
    │   ├── ComboCounter (TextLabel)    → contador de combos
    │   │   └── Scale (UIScale)
    │   └── MobileScale (UIScale)
    ├── TopHud (Frame)                  → HUD superior
    │   ├── SelfHPLabel (TextLabel)
    │   ├── SelfHPBarBg (Frame)
    │   │   └── SelfHPBarFill (Frame)
    │   ├── EnemyHPLabel (TextLabel)
    │   ├── EnemyHPBarBg (Frame)
    │   │   └── EnemyHPBarFill (Frame)
    ├── EnemyAvatarFrame (Frame)
    │   ├── EnemyAvatarImage (ImageLabel)
    │   └── EnemyAvatarLabel (TextLabel)
    ├── DuelStatusLabel (TextLabel)
    ├── CountdownLabel (TextLabel)
    ├── DuelIntroOverlay (Frame)        → pantalla VS
    │   ├── LeftCard (Frame)
    │   │   ├── Avatar (ImageLabel)
    │   │   │   └── AvatarFallback (TextLabel)
    │   │   ├── Name (TextLabel)
    │   │   └── Stars (TextLabel)
    │   ├── RightCard (Frame)
    │   │   ├── Avatar (ImageLabel)
    │   │   │   └── AvatarFallback (TextLabel)
    │   │   ├── Name (TextLabel)
    │   │   └── Stars (TextLabel)
    │   └── VS (TextLabel)              → "VS" central
    ├── ChallengePrompt (Frame)         → popup de desafio PvP
    │   ├── Text (TextLabel)
    │   ├── Hint (TextLabel)
    │   ├── AcceptButton (TextButton)
    │   └── RejectButton (TextButton)
    ├── DuelResultOverlay (Frame)       → pantalla de resultado
    │   └── ResultCard (Frame)
    │       ├── ResultTitle (TextLabel)
    │       ├── StarsDelta (TextLabel)
    │       ├── StarsTotal (TextLabel)
    │       ├── Separator (Frame)
    │       ├── DropsArea (Frame)
    │       │   └── DropsLabel (TextLabel)
    │       └── ContinueButton (TextButton)
    └── DragGhost (Frame)               → pieza al arrastrar
        └── Label (TextLabel)
```

### 2.2 Medidas y posiciones clave

| Elemento | Posicion | Tamaño |
|----------|----------|--------|
| `GridContainer` | `{0.5, 0}{1, -20}` Anchor(0.5,1) | `{0, 344}{0, 318}` aprox |
| `TopHud` | `{0.5, 0}{0, 20}` Anchor(0.5,0) | `{0, 540}{0, 80}` |
| `DuelStatusLabel` | `{0.5, 0}{0, 110}` Anchor(0.5,0) | `{0, 620}{0, 28}` |
| `CountdownLabel` | `{0.5, 0}{0.35, 0}` Anchor(0.5,0) | `{0, 220}{0, 80}` |
| `EnemyAvatarFrame` | `{1, -20}{0, 20}` Anchor(1,0) | `{0, 78}{0, 78}` |
| `DuelIntroOverlay` | fullscreen `{1,0}{1,0}` | `{1,0}{1,0}` |
| `DuelResultOverlay` | fullscreen `{1,0}{1,0}` | `{1,0}{1,0}` |
| `ChallengePrompt` | `{0.5, 0}{0.55, 0}` Anchor(0.5,0) | `{0, 420}{0, 120}` |
| `DragGhost` | dinamico durante arrastre | `{0, 64}{0, 64}` |

---

## 3. PlayerStatusHUD

**ScreenGui:** `PlayerStatusHUD` dentro de `PlayerGui`

```
PlayerGui
└── PlayerStatusHUD (ScreenGui)
    └── Root (Frame)                  → {0,16}{0,72} {0,220}{0,92}
        ├── BitsCard (Frame)          → {0,8}{0,8} {1,-16}{0,34}
        │   ├── Title (TextLabel)
        │   └── Value (TextLabel)
        └── EnergyCard (Frame)        → {0,8}{0,48} {1,-16}{0,36}
            ├── Title (TextLabel)
            ├── Value (TextLabel)
            └── RegenLabel (TextLabel)
```

---

## 4. Como reemplazar con assets personalizados

### Metodo: Insertar antes de ejecutar

1. Abrir Roblox Studio
2. En `StarterPlayer > StarterPlayerScripts`, buscar el LocalScript (RosterUI, CombatUI, PlayerStatusHUD)
3. **Desactivar temporalmente el script** (Disabled = true)
4. En `StarterGui`, crear el ScreenGui con el nombre exacto y toda la jerarquia de hijos
5. Diseñar los assets visualmente (cambiar colores, imágenes, fuentes, tamaños)
6. Respetar los nombres exactos de cada elemento
7. Reactivar el script

### Que elementos son obligatorios

| Script | Elementos que DEBEN existir |
|--------|---------------------------|
| RosterUI | `RosterToggleButton`, `RosterOverlay`, `CloseButton`, `ContentFrame`, 5 `NavBtn_*`, 5 `Tab_*` |
| CombatUI | `GridContainer`, `GridFrame`, 25 `Cell_*`, `TopHud`, `DuelIntroOverlay`, `DuelResultOverlay`, `ChallengePrompt` |
| PlayerStatusHUD | `Root`, `BitsCard`, `EnergyCard` |

### Que elementos son opcionales (el script los crea si faltan)

- Elementos dentro de tabs (filas, cards, slots): el script los crea dinamicamente
- `DragGhost`, `CascadeGhost`, `ComboCounter`: los crea el script segun necesidad
- Labels de texto informativos (`TeamInfo`, `CraftInfo`, etc.)

### Notas importantes

- **El script busca por `FindFirstChild`**. Si el elemento existe con el nombre correcto, lo usa. Si no, lo crea con `Instance.new()`.
- Los elementos dinamicos (cards de Beastibit, filas de inventario) se recrean cada vez que se refresca la UI. No se pueden pre-diseñar individualmente, pero si se puede pre-diseñar **uno** como template y el script usara los colores/estilos del existente.
- **Nunca cambiar los nombres** de elementos que el script busca por nombre. Si queres renombrar visualmente algo, cambia el `.Text`, no el `.Name`.
- `UICorner` y `UIScale` los crea el script automaticamente, no hace falta incluirlos en el diseño personalizado.
