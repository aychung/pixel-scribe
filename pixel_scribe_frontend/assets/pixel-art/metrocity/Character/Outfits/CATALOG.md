# Outfit Asset Catalog

Coordinate catalog for every PNG in this directory.

## Shared sheet layout

All outfit sheets are 24 cells wide and use the same horizontal direction alignment as [`Character Model.png`](<../CharacterModel/Character Model.png>):

| Columns | Direction |
|---|---|
| `c00`–`c05` | Down-facing / front view |
| `c06`–`c11` | Right-facing profile |
| `c12`–`c17` | Up-facing / back view |
| `c18`–`c23` | Left-facing profile |

Horizontal cells are the same outfit type in different directions and animation frames. Each vertical row is a different outfit type or variant. All rectangles use source-image coordinates `(x, y, width, height)`, with a top-left origin and exclusive right/bottom edges. Every sheet cell is 32×32 pixels.

## File inventory

| File | Dimensions | Grid | Cells |
|---|---:|---:|---:|
| [Outfit1.png](<./Outfit1.png>) | 768 × 32 | 24 × 1 | 24 |
| [Outfit2.png](<./Outfit2.png>) | 768 × 32 | 24 × 1 | 24 |
| [Outfit3.png](<./Outfit3.png>) | 768 × 32 | 24 × 1 | 24 |
| [Outfit4.png](<./Outfit4.png>) | 768 × 32 | 24 × 1 | 24 |
| [Outfit5.png](<./Outfit5.png>) | 768 × 32 | 24 × 1 | 24 |
| [Outfit6.png](<./Outfit6.png>) | 768 × 32 | 24 × 1 | 24 |
| [Suit.png](<./Suit.png>) | 768 × 128 | 24 × 4 | 96 |
| [Suit1.png](<./Suit1.png>) | 768 × 160 | 24 × 5 | 120 |

## Outfit sheets

### Outfit1.png

Source: [Outfit1.png](<./Outfit1.png>)

- **Canvas:** 768 × 32 pixels
- **Grid:** 24 columns × 1 row
- **Cell size:** 32 × 32 pixels
- **Cell count:** 24
- **ID format:** `outfit1.r<row>.<direction>.f<frame>`

This one-row strip is one outfit type; its horizontal cells are direction and animation-frame variants.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Outfit type defined by Outfit1.png, row 00 |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `outfit1.r00.down.f00`<br>`(0, 0, 32, 32)` | `outfit1.r00.down.f01`<br>`(32, 0, 32, 32)` | `outfit1.r00.down.f02`<br>`(64, 0, 32, 32)` | `outfit1.r00.down.f03`<br>`(96, 0, 32, 32)` | `outfit1.r00.down.f04`<br>`(128, 0, 32, 32)` | `outfit1.r00.down.f05`<br>`(160, 0, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `outfit1.r00.right.f00`<br>`(192, 0, 32, 32)` | `outfit1.r00.right.f01`<br>`(224, 0, 32, 32)` | `outfit1.r00.right.f02`<br>`(256, 0, 32, 32)` | `outfit1.r00.right.f03`<br>`(288, 0, 32, 32)` | `outfit1.r00.right.f04`<br>`(320, 0, 32, 32)` | `outfit1.r00.right.f05`<br>`(352, 0, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `outfit1.r00.up.f00`<br>`(384, 0, 32, 32)` | `outfit1.r00.up.f01`<br>`(416, 0, 32, 32)` | `outfit1.r00.up.f02`<br>`(448, 0, 32, 32)` | `outfit1.r00.up.f03`<br>`(480, 0, 32, 32)` | `outfit1.r00.up.f04`<br>`(512, 0, 32, 32)` | `outfit1.r00.up.f05`<br>`(544, 0, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `outfit1.r00.left.f00`<br>`(576, 0, 32, 32)` | `outfit1.r00.left.f01`<br>`(608, 0, 32, 32)` | `outfit1.r00.left.f02`<br>`(640, 0, 32, 32)` | `outfit1.r00.left.f03`<br>`(672, 0, 32, 32)` | `outfit1.r00.left.f04`<br>`(704, 0, 32, 32)` | `outfit1.r00.left.f05`<br>`(736, 0, 32, 32)` |

### Outfit2.png

Source: [Outfit2.png](<./Outfit2.png>)

- **Canvas:** 768 × 32 pixels
- **Grid:** 24 columns × 1 row
- **Cell size:** 32 × 32 pixels
- **Cell count:** 24
- **ID format:** `outfit2.r<row>.<direction>.f<frame>`

This one-row strip is one outfit type; its horizontal cells are direction and animation-frame variants.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Outfit type defined by Outfit2.png, row 00 |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `outfit2.r00.down.f00`<br>`(0, 0, 32, 32)` | `outfit2.r00.down.f01`<br>`(32, 0, 32, 32)` | `outfit2.r00.down.f02`<br>`(64, 0, 32, 32)` | `outfit2.r00.down.f03`<br>`(96, 0, 32, 32)` | `outfit2.r00.down.f04`<br>`(128, 0, 32, 32)` | `outfit2.r00.down.f05`<br>`(160, 0, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `outfit2.r00.right.f00`<br>`(192, 0, 32, 32)` | `outfit2.r00.right.f01`<br>`(224, 0, 32, 32)` | `outfit2.r00.right.f02`<br>`(256, 0, 32, 32)` | `outfit2.r00.right.f03`<br>`(288, 0, 32, 32)` | `outfit2.r00.right.f04`<br>`(320, 0, 32, 32)` | `outfit2.r00.right.f05`<br>`(352, 0, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `outfit2.r00.up.f00`<br>`(384, 0, 32, 32)` | `outfit2.r00.up.f01`<br>`(416, 0, 32, 32)` | `outfit2.r00.up.f02`<br>`(448, 0, 32, 32)` | `outfit2.r00.up.f03`<br>`(480, 0, 32, 32)` | `outfit2.r00.up.f04`<br>`(512, 0, 32, 32)` | `outfit2.r00.up.f05`<br>`(544, 0, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `outfit2.r00.left.f00`<br>`(576, 0, 32, 32)` | `outfit2.r00.left.f01`<br>`(608, 0, 32, 32)` | `outfit2.r00.left.f02`<br>`(640, 0, 32, 32)` | `outfit2.r00.left.f03`<br>`(672, 0, 32, 32)` | `outfit2.r00.left.f04`<br>`(704, 0, 32, 32)` | `outfit2.r00.left.f05`<br>`(736, 0, 32, 32)` |

### Outfit3.png

Source: [Outfit3.png](<./Outfit3.png>)

- **Canvas:** 768 × 32 pixels
- **Grid:** 24 columns × 1 row
- **Cell size:** 32 × 32 pixels
- **Cell count:** 24
- **ID format:** `outfit3.r<row>.<direction>.f<frame>`

This one-row strip is one outfit type; its horizontal cells are direction and animation-frame variants.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Outfit type defined by Outfit3.png, row 00 |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `outfit3.r00.down.f00`<br>`(0, 0, 32, 32)` | `outfit3.r00.down.f01`<br>`(32, 0, 32, 32)` | `outfit3.r00.down.f02`<br>`(64, 0, 32, 32)` | `outfit3.r00.down.f03`<br>`(96, 0, 32, 32)` | `outfit3.r00.down.f04`<br>`(128, 0, 32, 32)` | `outfit3.r00.down.f05`<br>`(160, 0, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `outfit3.r00.right.f00`<br>`(192, 0, 32, 32)` | `outfit3.r00.right.f01`<br>`(224, 0, 32, 32)` | `outfit3.r00.right.f02`<br>`(256, 0, 32, 32)` | `outfit3.r00.right.f03`<br>`(288, 0, 32, 32)` | `outfit3.r00.right.f04`<br>`(320, 0, 32, 32)` | `outfit3.r00.right.f05`<br>`(352, 0, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `outfit3.r00.up.f00`<br>`(384, 0, 32, 32)` | `outfit3.r00.up.f01`<br>`(416, 0, 32, 32)` | `outfit3.r00.up.f02`<br>`(448, 0, 32, 32)` | `outfit3.r00.up.f03`<br>`(480, 0, 32, 32)` | `outfit3.r00.up.f04`<br>`(512, 0, 32, 32)` | `outfit3.r00.up.f05`<br>`(544, 0, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `outfit3.r00.left.f00`<br>`(576, 0, 32, 32)` | `outfit3.r00.left.f01`<br>`(608, 0, 32, 32)` | `outfit3.r00.left.f02`<br>`(640, 0, 32, 32)` | `outfit3.r00.left.f03`<br>`(672, 0, 32, 32)` | `outfit3.r00.left.f04`<br>`(704, 0, 32, 32)` | `outfit3.r00.left.f05`<br>`(736, 0, 32, 32)` |

### Outfit4.png

Source: [Outfit4.png](<./Outfit4.png>)

- **Canvas:** 768 × 32 pixels
- **Grid:** 24 columns × 1 row
- **Cell size:** 32 × 32 pixels
- **Cell count:** 24
- **ID format:** `outfit4.r<row>.<direction>.f<frame>`

This one-row strip is one outfit type; its horizontal cells are direction and animation-frame variants.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Outfit type defined by Outfit4.png, row 00 |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `outfit4.r00.down.f00`<br>`(0, 0, 32, 32)` | `outfit4.r00.down.f01`<br>`(32, 0, 32, 32)` | `outfit4.r00.down.f02`<br>`(64, 0, 32, 32)` | `outfit4.r00.down.f03`<br>`(96, 0, 32, 32)` | `outfit4.r00.down.f04`<br>`(128, 0, 32, 32)` | `outfit4.r00.down.f05`<br>`(160, 0, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `outfit4.r00.right.f00`<br>`(192, 0, 32, 32)` | `outfit4.r00.right.f01`<br>`(224, 0, 32, 32)` | `outfit4.r00.right.f02`<br>`(256, 0, 32, 32)` | `outfit4.r00.right.f03`<br>`(288, 0, 32, 32)` | `outfit4.r00.right.f04`<br>`(320, 0, 32, 32)` | `outfit4.r00.right.f05`<br>`(352, 0, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `outfit4.r00.up.f00`<br>`(384, 0, 32, 32)` | `outfit4.r00.up.f01`<br>`(416, 0, 32, 32)` | `outfit4.r00.up.f02`<br>`(448, 0, 32, 32)` | `outfit4.r00.up.f03`<br>`(480, 0, 32, 32)` | `outfit4.r00.up.f04`<br>`(512, 0, 32, 32)` | `outfit4.r00.up.f05`<br>`(544, 0, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `outfit4.r00.left.f00`<br>`(576, 0, 32, 32)` | `outfit4.r00.left.f01`<br>`(608, 0, 32, 32)` | `outfit4.r00.left.f02`<br>`(640, 0, 32, 32)` | `outfit4.r00.left.f03`<br>`(672, 0, 32, 32)` | `outfit4.r00.left.f04`<br>`(704, 0, 32, 32)` | `outfit4.r00.left.f05`<br>`(736, 0, 32, 32)` |

### Outfit5.png

Source: [Outfit5.png](<./Outfit5.png>)

- **Canvas:** 768 × 32 pixels
- **Grid:** 24 columns × 1 row
- **Cell size:** 32 × 32 pixels
- **Cell count:** 24
- **ID format:** `outfit5.r<row>.<direction>.f<frame>`

This one-row strip is one outfit type; its horizontal cells are direction and animation-frame variants.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Outfit type defined by Outfit5.png, row 00 |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `outfit5.r00.down.f00`<br>`(0, 0, 32, 32)` | `outfit5.r00.down.f01`<br>`(32, 0, 32, 32)` | `outfit5.r00.down.f02`<br>`(64, 0, 32, 32)` | `outfit5.r00.down.f03`<br>`(96, 0, 32, 32)` | `outfit5.r00.down.f04`<br>`(128, 0, 32, 32)` | `outfit5.r00.down.f05`<br>`(160, 0, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `outfit5.r00.right.f00`<br>`(192, 0, 32, 32)` | `outfit5.r00.right.f01`<br>`(224, 0, 32, 32)` | `outfit5.r00.right.f02`<br>`(256, 0, 32, 32)` | `outfit5.r00.right.f03`<br>`(288, 0, 32, 32)` | `outfit5.r00.right.f04`<br>`(320, 0, 32, 32)` | `outfit5.r00.right.f05`<br>`(352, 0, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `outfit5.r00.up.f00`<br>`(384, 0, 32, 32)` | `outfit5.r00.up.f01`<br>`(416, 0, 32, 32)` | `outfit5.r00.up.f02`<br>`(448, 0, 32, 32)` | `outfit5.r00.up.f03`<br>`(480, 0, 32, 32)` | `outfit5.r00.up.f04`<br>`(512, 0, 32, 32)` | `outfit5.r00.up.f05`<br>`(544, 0, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `outfit5.r00.left.f00`<br>`(576, 0, 32, 32)` | `outfit5.r00.left.f01`<br>`(608, 0, 32, 32)` | `outfit5.r00.left.f02`<br>`(640, 0, 32, 32)` | `outfit5.r00.left.f03`<br>`(672, 0, 32, 32)` | `outfit5.r00.left.f04`<br>`(704, 0, 32, 32)` | `outfit5.r00.left.f05`<br>`(736, 0, 32, 32)` |

### Outfit6.png

Source: [Outfit6.png](<./Outfit6.png>)

- **Canvas:** 768 × 32 pixels
- **Grid:** 24 columns × 1 row
- **Cell size:** 32 × 32 pixels
- **Cell count:** 24
- **ID format:** `outfit6.r<row>.<direction>.f<frame>`

This one-row strip is one outfit type; its horizontal cells are direction and animation-frame variants.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Outfit type defined by Outfit6.png, row 00 |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `outfit6.r00.down.f00`<br>`(0, 0, 32, 32)` | `outfit6.r00.down.f01`<br>`(32, 0, 32, 32)` | `outfit6.r00.down.f02`<br>`(64, 0, 32, 32)` | `outfit6.r00.down.f03`<br>`(96, 0, 32, 32)` | `outfit6.r00.down.f04`<br>`(128, 0, 32, 32)` | `outfit6.r00.down.f05`<br>`(160, 0, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `outfit6.r00.right.f00`<br>`(192, 0, 32, 32)` | `outfit6.r00.right.f01`<br>`(224, 0, 32, 32)` | `outfit6.r00.right.f02`<br>`(256, 0, 32, 32)` | `outfit6.r00.right.f03`<br>`(288, 0, 32, 32)` | `outfit6.r00.right.f04`<br>`(320, 0, 32, 32)` | `outfit6.r00.right.f05`<br>`(352, 0, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `outfit6.r00.up.f00`<br>`(384, 0, 32, 32)` | `outfit6.r00.up.f01`<br>`(416, 0, 32, 32)` | `outfit6.r00.up.f02`<br>`(448, 0, 32, 32)` | `outfit6.r00.up.f03`<br>`(480, 0, 32, 32)` | `outfit6.r00.up.f04`<br>`(512, 0, 32, 32)` | `outfit6.r00.up.f05`<br>`(544, 0, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `outfit6.r00.left.f00`<br>`(576, 0, 32, 32)` | `outfit6.r00.left.f01`<br>`(608, 0, 32, 32)` | `outfit6.r00.left.f02`<br>`(640, 0, 32, 32)` | `outfit6.r00.left.f03`<br>`(672, 0, 32, 32)` | `outfit6.r00.left.f04`<br>`(704, 0, 32, 32)` | `outfit6.r00.left.f05`<br>`(736, 0, 32, 32)` |

### Suit.png

Source: [Suit.png](<./Suit.png>)

- **Canvas:** 768 × 128 pixels
- **Grid:** 24 columns × 4 rows
- **Cell size:** 32 × 32 pixels
- **Cell count:** 96
- **ID format:** `suit.r<row>.<direction>.f<frame>`

Each vertical row is a different outfit type or variant; its horizontal cells remain aligned with the character model directions.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | Blue police-style uniform palette |
| `r01` | 32 | Red uniform palette |
| `r02` | 64 | Blue uniform palette |
| `r03` | 96 | Orange/blue uniform palette |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `suit.r00.down.f00`<br>`(0, 0, 32, 32)` | `suit.r00.down.f01`<br>`(32, 0, 32, 32)` | `suit.r00.down.f02`<br>`(64, 0, 32, 32)` | `suit.r00.down.f03`<br>`(96, 0, 32, 32)` | `suit.r00.down.f04`<br>`(128, 0, 32, 32)` | `suit.r00.down.f05`<br>`(160, 0, 32, 32)` |
| `r01` | `suit.r01.down.f00`<br>`(0, 32, 32, 32)` | `suit.r01.down.f01`<br>`(32, 32, 32, 32)` | `suit.r01.down.f02`<br>`(64, 32, 32, 32)` | `suit.r01.down.f03`<br>`(96, 32, 32, 32)` | `suit.r01.down.f04`<br>`(128, 32, 32, 32)` | `suit.r01.down.f05`<br>`(160, 32, 32, 32)` |
| `r02` | `suit.r02.down.f00`<br>`(0, 64, 32, 32)` | `suit.r02.down.f01`<br>`(32, 64, 32, 32)` | `suit.r02.down.f02`<br>`(64, 64, 32, 32)` | `suit.r02.down.f03`<br>`(96, 64, 32, 32)` | `suit.r02.down.f04`<br>`(128, 64, 32, 32)` | `suit.r02.down.f05`<br>`(160, 64, 32, 32)` |
| `r03` | `suit.r03.down.f00`<br>`(0, 96, 32, 32)` | `suit.r03.down.f01`<br>`(32, 96, 32, 32)` | `suit.r03.down.f02`<br>`(64, 96, 32, 32)` | `suit.r03.down.f03`<br>`(96, 96, 32, 32)` | `suit.r03.down.f04`<br>`(128, 96, 32, 32)` | `suit.r03.down.f05`<br>`(160, 96, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `suit.r00.right.f00`<br>`(192, 0, 32, 32)` | `suit.r00.right.f01`<br>`(224, 0, 32, 32)` | `suit.r00.right.f02`<br>`(256, 0, 32, 32)` | `suit.r00.right.f03`<br>`(288, 0, 32, 32)` | `suit.r00.right.f04`<br>`(320, 0, 32, 32)` | `suit.r00.right.f05`<br>`(352, 0, 32, 32)` |
| `r01` | `suit.r01.right.f00`<br>`(192, 32, 32, 32)` | `suit.r01.right.f01`<br>`(224, 32, 32, 32)` | `suit.r01.right.f02`<br>`(256, 32, 32, 32)` | `suit.r01.right.f03`<br>`(288, 32, 32, 32)` | `suit.r01.right.f04`<br>`(320, 32, 32, 32)` | `suit.r01.right.f05`<br>`(352, 32, 32, 32)` |
| `r02` | `suit.r02.right.f00`<br>`(192, 64, 32, 32)` | `suit.r02.right.f01`<br>`(224, 64, 32, 32)` | `suit.r02.right.f02`<br>`(256, 64, 32, 32)` | `suit.r02.right.f03`<br>`(288, 64, 32, 32)` | `suit.r02.right.f04`<br>`(320, 64, 32, 32)` | `suit.r02.right.f05`<br>`(352, 64, 32, 32)` |
| `r03` | `suit.r03.right.f00`<br>`(192, 96, 32, 32)` | `suit.r03.right.f01`<br>`(224, 96, 32, 32)` | `suit.r03.right.f02`<br>`(256, 96, 32, 32)` | `suit.r03.right.f03`<br>`(288, 96, 32, 32)` | `suit.r03.right.f04`<br>`(320, 96, 32, 32)` | `suit.r03.right.f05`<br>`(352, 96, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `suit.r00.up.f00`<br>`(384, 0, 32, 32)` | `suit.r00.up.f01`<br>`(416, 0, 32, 32)` | `suit.r00.up.f02`<br>`(448, 0, 32, 32)` | `suit.r00.up.f03`<br>`(480, 0, 32, 32)` | `suit.r00.up.f04`<br>`(512, 0, 32, 32)` | `suit.r00.up.f05`<br>`(544, 0, 32, 32)` |
| `r01` | `suit.r01.up.f00`<br>`(384, 32, 32, 32)` | `suit.r01.up.f01`<br>`(416, 32, 32, 32)` | `suit.r01.up.f02`<br>`(448, 32, 32, 32)` | `suit.r01.up.f03`<br>`(480, 32, 32, 32)` | `suit.r01.up.f04`<br>`(512, 32, 32, 32)` | `suit.r01.up.f05`<br>`(544, 32, 32, 32)` |
| `r02` | `suit.r02.up.f00`<br>`(384, 64, 32, 32)` | `suit.r02.up.f01`<br>`(416, 64, 32, 32)` | `suit.r02.up.f02`<br>`(448, 64, 32, 32)` | `suit.r02.up.f03`<br>`(480, 64, 32, 32)` | `suit.r02.up.f04`<br>`(512, 64, 32, 32)` | `suit.r02.up.f05`<br>`(544, 64, 32, 32)` |
| `r03` | `suit.r03.up.f00`<br>`(384, 96, 32, 32)` | `suit.r03.up.f01`<br>`(416, 96, 32, 32)` | `suit.r03.up.f02`<br>`(448, 96, 32, 32)` | `suit.r03.up.f03`<br>`(480, 96, 32, 32)` | `suit.r03.up.f04`<br>`(512, 96, 32, 32)` | `suit.r03.up.f05`<br>`(544, 96, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `suit.r00.left.f00`<br>`(576, 0, 32, 32)` | `suit.r00.left.f01`<br>`(608, 0, 32, 32)` | `suit.r00.left.f02`<br>`(640, 0, 32, 32)` | `suit.r00.left.f03`<br>`(672, 0, 32, 32)` | `suit.r00.left.f04`<br>`(704, 0, 32, 32)` | `suit.r00.left.f05`<br>`(736, 0, 32, 32)` |
| `r01` | `suit.r01.left.f00`<br>`(576, 32, 32, 32)` | `suit.r01.left.f01`<br>`(608, 32, 32, 32)` | `suit.r01.left.f02`<br>`(640, 32, 32, 32)` | `suit.r01.left.f03`<br>`(672, 32, 32, 32)` | `suit.r01.left.f04`<br>`(704, 32, 32, 32)` | `suit.r01.left.f05`<br>`(736, 32, 32, 32)` |
| `r02` | `suit.r02.left.f00`<br>`(576, 64, 32, 32)` | `suit.r02.left.f01`<br>`(608, 64, 32, 32)` | `suit.r02.left.f02`<br>`(640, 64, 32, 32)` | `suit.r02.left.f03`<br>`(672, 64, 32, 32)` | `suit.r02.left.f04`<br>`(704, 64, 32, 32)` | `suit.r02.left.f05`<br>`(736, 64, 32, 32)` |
| `r03` | `suit.r03.left.f00`<br>`(576, 96, 32, 32)` | `suit.r03.left.f01`<br>`(608, 96, 32, 32)` | `suit.r03.left.f02`<br>`(640, 96, 32, 32)` | `suit.r03.left.f03`<br>`(672, 96, 32, 32)` | `suit.r03.left.f04`<br>`(704, 96, 32, 32)` | `suit.r03.left.f05`<br>`(736, 96, 32, 32)` |

### Suit1.png

Source: [Suit1.png](<./Suit1.png>)

- **Canvas:** 768 × 160 pixels
- **Grid:** 24 columns × 5 rows
- **Cell size:** 32 × 32 pixels
- **Cell count:** 120
- **ID format:** `suit1.r<row>.<direction>.f<frame>`

Each vertical row is a different outfit type or variant; its horizontal cells remain aligned with the character model directions.

### Row mapping

| Row ID | Source `y` | Visual/type note |
|---|---:|---|
| `r00` | 0 | White outfit palette |
| `r01` | 32 | Pink outfit palette |
| `r02` | 64 | Blue outfit palette |
| `r03` | 96 | Cyan outfit palette |
| `r04` | 128 | Magenta outfit palette |

#### Down-facing / front view

Columns `c00`–`c05`.

| Outfit row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `suit1.r00.down.f00`<br>`(0, 0, 32, 32)` | `suit1.r00.down.f01`<br>`(32, 0, 32, 32)` | `suit1.r00.down.f02`<br>`(64, 0, 32, 32)` | `suit1.r00.down.f03`<br>`(96, 0, 32, 32)` | `suit1.r00.down.f04`<br>`(128, 0, 32, 32)` | `suit1.r00.down.f05`<br>`(160, 0, 32, 32)` |
| `r01` | `suit1.r01.down.f00`<br>`(0, 32, 32, 32)` | `suit1.r01.down.f01`<br>`(32, 32, 32, 32)` | `suit1.r01.down.f02`<br>`(64, 32, 32, 32)` | `suit1.r01.down.f03`<br>`(96, 32, 32, 32)` | `suit1.r01.down.f04`<br>`(128, 32, 32, 32)` | `suit1.r01.down.f05`<br>`(160, 32, 32, 32)` |
| `r02` | `suit1.r02.down.f00`<br>`(0, 64, 32, 32)` | `suit1.r02.down.f01`<br>`(32, 64, 32, 32)` | `suit1.r02.down.f02`<br>`(64, 64, 32, 32)` | `suit1.r02.down.f03`<br>`(96, 64, 32, 32)` | `suit1.r02.down.f04`<br>`(128, 64, 32, 32)` | `suit1.r02.down.f05`<br>`(160, 64, 32, 32)` |
| `r03` | `suit1.r03.down.f00`<br>`(0, 96, 32, 32)` | `suit1.r03.down.f01`<br>`(32, 96, 32, 32)` | `suit1.r03.down.f02`<br>`(64, 96, 32, 32)` | `suit1.r03.down.f03`<br>`(96, 96, 32, 32)` | `suit1.r03.down.f04`<br>`(128, 96, 32, 32)` | `suit1.r03.down.f05`<br>`(160, 96, 32, 32)` |
| `r04` | `suit1.r04.down.f00`<br>`(0, 128, 32, 32)` | `suit1.r04.down.f01`<br>`(32, 128, 32, 32)` | `suit1.r04.down.f02`<br>`(64, 128, 32, 32)` | `suit1.r04.down.f03`<br>`(96, 128, 32, 32)` | `suit1.r04.down.f04`<br>`(128, 128, 32, 32)` | `suit1.r04.down.f05`<br>`(160, 128, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Outfit row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `suit1.r00.right.f00`<br>`(192, 0, 32, 32)` | `suit1.r00.right.f01`<br>`(224, 0, 32, 32)` | `suit1.r00.right.f02`<br>`(256, 0, 32, 32)` | `suit1.r00.right.f03`<br>`(288, 0, 32, 32)` | `suit1.r00.right.f04`<br>`(320, 0, 32, 32)` | `suit1.r00.right.f05`<br>`(352, 0, 32, 32)` |
| `r01` | `suit1.r01.right.f00`<br>`(192, 32, 32, 32)` | `suit1.r01.right.f01`<br>`(224, 32, 32, 32)` | `suit1.r01.right.f02`<br>`(256, 32, 32, 32)` | `suit1.r01.right.f03`<br>`(288, 32, 32, 32)` | `suit1.r01.right.f04`<br>`(320, 32, 32, 32)` | `suit1.r01.right.f05`<br>`(352, 32, 32, 32)` |
| `r02` | `suit1.r02.right.f00`<br>`(192, 64, 32, 32)` | `suit1.r02.right.f01`<br>`(224, 64, 32, 32)` | `suit1.r02.right.f02`<br>`(256, 64, 32, 32)` | `suit1.r02.right.f03`<br>`(288, 64, 32, 32)` | `suit1.r02.right.f04`<br>`(320, 64, 32, 32)` | `suit1.r02.right.f05`<br>`(352, 64, 32, 32)` |
| `r03` | `suit1.r03.right.f00`<br>`(192, 96, 32, 32)` | `suit1.r03.right.f01`<br>`(224, 96, 32, 32)` | `suit1.r03.right.f02`<br>`(256, 96, 32, 32)` | `suit1.r03.right.f03`<br>`(288, 96, 32, 32)` | `suit1.r03.right.f04`<br>`(320, 96, 32, 32)` | `suit1.r03.right.f05`<br>`(352, 96, 32, 32)` |
| `r04` | `suit1.r04.right.f00`<br>`(192, 128, 32, 32)` | `suit1.r04.right.f01`<br>`(224, 128, 32, 32)` | `suit1.r04.right.f02`<br>`(256, 128, 32, 32)` | `suit1.r04.right.f03`<br>`(288, 128, 32, 32)` | `suit1.r04.right.f04`<br>`(320, 128, 32, 32)` | `suit1.r04.right.f05`<br>`(352, 128, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Outfit row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `suit1.r00.up.f00`<br>`(384, 0, 32, 32)` | `suit1.r00.up.f01`<br>`(416, 0, 32, 32)` | `suit1.r00.up.f02`<br>`(448, 0, 32, 32)` | `suit1.r00.up.f03`<br>`(480, 0, 32, 32)` | `suit1.r00.up.f04`<br>`(512, 0, 32, 32)` | `suit1.r00.up.f05`<br>`(544, 0, 32, 32)` |
| `r01` | `suit1.r01.up.f00`<br>`(384, 32, 32, 32)` | `suit1.r01.up.f01`<br>`(416, 32, 32, 32)` | `suit1.r01.up.f02`<br>`(448, 32, 32, 32)` | `suit1.r01.up.f03`<br>`(480, 32, 32, 32)` | `suit1.r01.up.f04`<br>`(512, 32, 32, 32)` | `suit1.r01.up.f05`<br>`(544, 32, 32, 32)` |
| `r02` | `suit1.r02.up.f00`<br>`(384, 64, 32, 32)` | `suit1.r02.up.f01`<br>`(416, 64, 32, 32)` | `suit1.r02.up.f02`<br>`(448, 64, 32, 32)` | `suit1.r02.up.f03`<br>`(480, 64, 32, 32)` | `suit1.r02.up.f04`<br>`(512, 64, 32, 32)` | `suit1.r02.up.f05`<br>`(544, 64, 32, 32)` |
| `r03` | `suit1.r03.up.f00`<br>`(384, 96, 32, 32)` | `suit1.r03.up.f01`<br>`(416, 96, 32, 32)` | `suit1.r03.up.f02`<br>`(448, 96, 32, 32)` | `suit1.r03.up.f03`<br>`(480, 96, 32, 32)` | `suit1.r03.up.f04`<br>`(512, 96, 32, 32)` | `suit1.r03.up.f05`<br>`(544, 96, 32, 32)` |
| `r04` | `suit1.r04.up.f00`<br>`(384, 128, 32, 32)` | `suit1.r04.up.f01`<br>`(416, 128, 32, 32)` | `suit1.r04.up.f02`<br>`(448, 128, 32, 32)` | `suit1.r04.up.f03`<br>`(480, 128, 32, 32)` | `suit1.r04.up.f04`<br>`(512, 128, 32, 32)` | `suit1.r04.up.f05`<br>`(544, 128, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Outfit row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `suit1.r00.left.f00`<br>`(576, 0, 32, 32)` | `suit1.r00.left.f01`<br>`(608, 0, 32, 32)` | `suit1.r00.left.f02`<br>`(640, 0, 32, 32)` | `suit1.r00.left.f03`<br>`(672, 0, 32, 32)` | `suit1.r00.left.f04`<br>`(704, 0, 32, 32)` | `suit1.r00.left.f05`<br>`(736, 0, 32, 32)` |
| `r01` | `suit1.r01.left.f00`<br>`(576, 32, 32, 32)` | `suit1.r01.left.f01`<br>`(608, 32, 32, 32)` | `suit1.r01.left.f02`<br>`(640, 32, 32, 32)` | `suit1.r01.left.f03`<br>`(672, 32, 32, 32)` | `suit1.r01.left.f04`<br>`(704, 32, 32, 32)` | `suit1.r01.left.f05`<br>`(736, 32, 32, 32)` |
| `r02` | `suit1.r02.left.f00`<br>`(576, 64, 32, 32)` | `suit1.r02.left.f01`<br>`(608, 64, 32, 32)` | `suit1.r02.left.f02`<br>`(640, 64, 32, 32)` | `suit1.r02.left.f03`<br>`(672, 64, 32, 32)` | `suit1.r02.left.f04`<br>`(704, 64, 32, 32)` | `suit1.r02.left.f05`<br>`(736, 64, 32, 32)` |
| `r03` | `suit1.r03.left.f00`<br>`(576, 96, 32, 32)` | `suit1.r03.left.f01`<br>`(608, 96, 32, 32)` | `suit1.r03.left.f02`<br>`(640, 96, 32, 32)` | `suit1.r03.left.f03`<br>`(672, 96, 32, 32)` | `suit1.r03.left.f04`<br>`(704, 96, 32, 32)` | `suit1.r03.left.f05`<br>`(736, 96, 32, 32)` |
| `r04` | `suit1.r04.left.f00`<br>`(576, 128, 32, 32)` | `suit1.r04.left.f01`<br>`(608, 128, 32, 32)` | `suit1.r04.left.f02`<br>`(640, 128, 32, 32)` | `suit1.r04.left.f03`<br>`(672, 128, 32, 32)` | `suit1.r04.left.f04`<br>`(704, 128, 32, 32)` | `suit1.r04.left.f05`<br>`(736, 128, 32, 32)` |

## Lookup examples

- `outfit1.r00.down.f00` → crop `(0, 0, 32, 32)` from `Outfit1.png`.
- `suit.r01.right.f03` → crop `(288, 32, 32, 32)` from `Suit.png`.
- `suit1.r04.left.f05` → crop `(736, 128, 32, 32)` from `Suit1.png`.

The catalog records source cells, including transparent padding. Do not trim or rename the original PNGs when using these coordinates.

