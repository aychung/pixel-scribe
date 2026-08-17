# Hair Asset Catalog

Coordinate catalog for every PNG in this directory.

## Shared sheet layout

The 24-cell-wide sheets use the same horizontal direction alignment as [`Character Model.png`](<../CharacterModel/Character Model.png>):

| Columns | Direction |
|---|---|
| `c00`–`c05` | Down-facing / front view |
| `c06`–`c11` | Right-facing profile |
| `c12`–`c17` | Up-facing / back view |
| `c18`–`c23` | Left-facing profile |

Horizontal cells are the same hair type in different directions and animation frames. Each vertical row is a different hair type or variant. All rectangles use source-image coordinates `(x, y, width, height)`, with a top-left origin and exclusive right/bottom edges. Every sheet cell is 32×32 pixels.

## File inventory

| File | Dimensions | Grid | Cells |
|---|---:|---:|---:|
| [Hair.png](<./Hair.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair1.png](<./Hair1.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair2.png](<./Hair2.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair3.png](<./Hair3.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair4.png](<./Hair4.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair5.png](<./Hair5.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair6.png](<./Hair6.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair7.png](<./Hair7.png>) | 32 × 32 | 1 × 1 | 1 |
| [Hair_v2.png](<./Hair_v2.png>) | 768 × 160 | 24 × 5 | 120 |
| [Hairs.png](<./Hairs.png>) | 768 × 256 | 24 × 8 | 192 |

## Standalone 32×32 hair sprites

### Hair.png

Source: [Hair.png](<./Hair.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair` | `(0, 0, 32, 32)` | Standalone hair sprite |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair1.png

Source: [Hair1.png](<./Hair1.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair1` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair2.png

Source: [Hair2.png](<./Hair2.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair2` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair3.png

Source: [Hair3.png](<./Hair3.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair3` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair4.png

Source: [Hair4.png](<./Hair4.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair4` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair5.png

Source: [Hair5.png](<./Hair5.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair5` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair6.png

Source: [Hair6.png](<./Hair6.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair6` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

### Hair7.png

Source: [Hair7.png](<./Hair7.png>)

| Asset ID | Rectangle `(x, y, width, height)` | Description |
|---|---|---|
| `hair.Hair7` | `(0, 0, 32, 32)` | Standalone hair variant |

This file is one complete 32×32 source cell and does not contain a horizontal direction strip.

## Hair_v2.png

Source: [Hair_v2.png](<./Hair_v2.png>)

- **Canvas:** 768 × 160 pixels
- **Grid:** 24 columns × 5 rows
- **Cell size:** 32 × 32 pixels
- **Cell count:** 120
- **ID format:** `hair-v2.r<row>.<direction>.f<frame>`

Vertical rows are different hair types or variants. The horizontal direction groups remain aligned with the character model sheet.

### Row mapping

| Row ID | Source `y` | Meaning |
|---|---:|---|
| `r00` | 0 | Hair type/variant row 00 |
| `r01` | 32 | Hair type/variant row 01 |
| `r02` | 64 | Hair type/variant row 02 |
| `r03` | 96 | Hair type/variant row 03 |
| `r04` | 128 | Hair type/variant row 04 |

### Down-facing / front view

Columns `c00`–`c05`.

| Palette/type row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `hair-v2.r00.down.f00`<br>`(0, 0, 32, 32)` | `hair-v2.r00.down.f01`<br>`(32, 0, 32, 32)` | `hair-v2.r00.down.f02`<br>`(64, 0, 32, 32)` | `hair-v2.r00.down.f03`<br>`(96, 0, 32, 32)` | `hair-v2.r00.down.f04`<br>`(128, 0, 32, 32)` | `hair-v2.r00.down.f05`<br>`(160, 0, 32, 32)` |
| `r01` | `hair-v2.r01.down.f00`<br>`(0, 32, 32, 32)` | `hair-v2.r01.down.f01`<br>`(32, 32, 32, 32)` | `hair-v2.r01.down.f02`<br>`(64, 32, 32, 32)` | `hair-v2.r01.down.f03`<br>`(96, 32, 32, 32)` | `hair-v2.r01.down.f04`<br>`(128, 32, 32, 32)` | `hair-v2.r01.down.f05`<br>`(160, 32, 32, 32)` |
| `r02` | `hair-v2.r02.down.f00`<br>`(0, 64, 32, 32)` | `hair-v2.r02.down.f01`<br>`(32, 64, 32, 32)` | `hair-v2.r02.down.f02`<br>`(64, 64, 32, 32)` | `hair-v2.r02.down.f03`<br>`(96, 64, 32, 32)` | `hair-v2.r02.down.f04`<br>`(128, 64, 32, 32)` | `hair-v2.r02.down.f05`<br>`(160, 64, 32, 32)` |
| `r03` | `hair-v2.r03.down.f00`<br>`(0, 96, 32, 32)` | `hair-v2.r03.down.f01`<br>`(32, 96, 32, 32)` | `hair-v2.r03.down.f02`<br>`(64, 96, 32, 32)` | `hair-v2.r03.down.f03`<br>`(96, 96, 32, 32)` | `hair-v2.r03.down.f04`<br>`(128, 96, 32, 32)` | `hair-v2.r03.down.f05`<br>`(160, 96, 32, 32)` |
| `r04` | `hair-v2.r04.down.f00`<br>`(0, 128, 32, 32)` | `hair-v2.r04.down.f01`<br>`(32, 128, 32, 32)` | `hair-v2.r04.down.f02`<br>`(64, 128, 32, 32)` | `hair-v2.r04.down.f03`<br>`(96, 128, 32, 32)` | `hair-v2.r04.down.f04`<br>`(128, 128, 32, 32)` | `hair-v2.r04.down.f05`<br>`(160, 128, 32, 32)` |

### Right-facing profile

Columns `c06`–`c11`.

| Palette/type row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `hair-v2.r00.right.f00`<br>`(192, 0, 32, 32)` | `hair-v2.r00.right.f01`<br>`(224, 0, 32, 32)` | `hair-v2.r00.right.f02`<br>`(256, 0, 32, 32)` | `hair-v2.r00.right.f03`<br>`(288, 0, 32, 32)` | `hair-v2.r00.right.f04`<br>`(320, 0, 32, 32)` | `hair-v2.r00.right.f05`<br>`(352, 0, 32, 32)` |
| `r01` | `hair-v2.r01.right.f00`<br>`(192, 32, 32, 32)` | `hair-v2.r01.right.f01`<br>`(224, 32, 32, 32)` | `hair-v2.r01.right.f02`<br>`(256, 32, 32, 32)` | `hair-v2.r01.right.f03`<br>`(288, 32, 32, 32)` | `hair-v2.r01.right.f04`<br>`(320, 32, 32, 32)` | `hair-v2.r01.right.f05`<br>`(352, 32, 32, 32)` |
| `r02` | `hair-v2.r02.right.f00`<br>`(192, 64, 32, 32)` | `hair-v2.r02.right.f01`<br>`(224, 64, 32, 32)` | `hair-v2.r02.right.f02`<br>`(256, 64, 32, 32)` | `hair-v2.r02.right.f03`<br>`(288, 64, 32, 32)` | `hair-v2.r02.right.f04`<br>`(320, 64, 32, 32)` | `hair-v2.r02.right.f05`<br>`(352, 64, 32, 32)` |
| `r03` | `hair-v2.r03.right.f00`<br>`(192, 96, 32, 32)` | `hair-v2.r03.right.f01`<br>`(224, 96, 32, 32)` | `hair-v2.r03.right.f02`<br>`(256, 96, 32, 32)` | `hair-v2.r03.right.f03`<br>`(288, 96, 32, 32)` | `hair-v2.r03.right.f04`<br>`(320, 96, 32, 32)` | `hair-v2.r03.right.f05`<br>`(352, 96, 32, 32)` |
| `r04` | `hair-v2.r04.right.f00`<br>`(192, 128, 32, 32)` | `hair-v2.r04.right.f01`<br>`(224, 128, 32, 32)` | `hair-v2.r04.right.f02`<br>`(256, 128, 32, 32)` | `hair-v2.r04.right.f03`<br>`(288, 128, 32, 32)` | `hair-v2.r04.right.f04`<br>`(320, 128, 32, 32)` | `hair-v2.r04.right.f05`<br>`(352, 128, 32, 32)` |

### Up-facing / back view

Columns `c12`–`c17`.

| Palette/type row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `hair-v2.r00.up.f00`<br>`(384, 0, 32, 32)` | `hair-v2.r00.up.f01`<br>`(416, 0, 32, 32)` | `hair-v2.r00.up.f02`<br>`(448, 0, 32, 32)` | `hair-v2.r00.up.f03`<br>`(480, 0, 32, 32)` | `hair-v2.r00.up.f04`<br>`(512, 0, 32, 32)` | `hair-v2.r00.up.f05`<br>`(544, 0, 32, 32)` |
| `r01` | `hair-v2.r01.up.f00`<br>`(384, 32, 32, 32)` | `hair-v2.r01.up.f01`<br>`(416, 32, 32, 32)` | `hair-v2.r01.up.f02`<br>`(448, 32, 32, 32)` | `hair-v2.r01.up.f03`<br>`(480, 32, 32, 32)` | `hair-v2.r01.up.f04`<br>`(512, 32, 32, 32)` | `hair-v2.r01.up.f05`<br>`(544, 32, 32, 32)` |
| `r02` | `hair-v2.r02.up.f00`<br>`(384, 64, 32, 32)` | `hair-v2.r02.up.f01`<br>`(416, 64, 32, 32)` | `hair-v2.r02.up.f02`<br>`(448, 64, 32, 32)` | `hair-v2.r02.up.f03`<br>`(480, 64, 32, 32)` | `hair-v2.r02.up.f04`<br>`(512, 64, 32, 32)` | `hair-v2.r02.up.f05`<br>`(544, 64, 32, 32)` |
| `r03` | `hair-v2.r03.up.f00`<br>`(384, 96, 32, 32)` | `hair-v2.r03.up.f01`<br>`(416, 96, 32, 32)` | `hair-v2.r03.up.f02`<br>`(448, 96, 32, 32)` | `hair-v2.r03.up.f03`<br>`(480, 96, 32, 32)` | `hair-v2.r03.up.f04`<br>`(512, 96, 32, 32)` | `hair-v2.r03.up.f05`<br>`(544, 96, 32, 32)` |
| `r04` | `hair-v2.r04.up.f00`<br>`(384, 128, 32, 32)` | `hair-v2.r04.up.f01`<br>`(416, 128, 32, 32)` | `hair-v2.r04.up.f02`<br>`(448, 128, 32, 32)` | `hair-v2.r04.up.f03`<br>`(480, 128, 32, 32)` | `hair-v2.r04.up.f04`<br>`(512, 128, 32, 32)` | `hair-v2.r04.up.f05`<br>`(544, 128, 32, 32)` |

### Left-facing profile

Columns `c18`–`c23`.

| Palette/type row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `hair-v2.r00.left.f00`<br>`(576, 0, 32, 32)` | `hair-v2.r00.left.f01`<br>`(608, 0, 32, 32)` | `hair-v2.r00.left.f02`<br>`(640, 0, 32, 32)` | `hair-v2.r00.left.f03`<br>`(672, 0, 32, 32)` | `hair-v2.r00.left.f04`<br>`(704, 0, 32, 32)` | `hair-v2.r00.left.f05`<br>`(736, 0, 32, 32)` |
| `r01` | `hair-v2.r01.left.f00`<br>`(576, 32, 32, 32)` | `hair-v2.r01.left.f01`<br>`(608, 32, 32, 32)` | `hair-v2.r01.left.f02`<br>`(640, 32, 32, 32)` | `hair-v2.r01.left.f03`<br>`(672, 32, 32, 32)` | `hair-v2.r01.left.f04`<br>`(704, 32, 32, 32)` | `hair-v2.r01.left.f05`<br>`(736, 32, 32, 32)` |
| `r02` | `hair-v2.r02.left.f00`<br>`(576, 64, 32, 32)` | `hair-v2.r02.left.f01`<br>`(608, 64, 32, 32)` | `hair-v2.r02.left.f02`<br>`(640, 64, 32, 32)` | `hair-v2.r02.left.f03`<br>`(672, 64, 32, 32)` | `hair-v2.r02.left.f04`<br>`(704, 64, 32, 32)` | `hair-v2.r02.left.f05`<br>`(736, 64, 32, 32)` |
| `r03` | `hair-v2.r03.left.f00`<br>`(576, 96, 32, 32)` | `hair-v2.r03.left.f01`<br>`(608, 96, 32, 32)` | `hair-v2.r03.left.f02`<br>`(640, 96, 32, 32)` | `hair-v2.r03.left.f03`<br>`(672, 96, 32, 32)` | `hair-v2.r03.left.f04`<br>`(704, 96, 32, 32)` | `hair-v2.r03.left.f05`<br>`(736, 96, 32, 32)` |
| `r04` | `hair-v2.r04.left.f00`<br>`(576, 128, 32, 32)` | `hair-v2.r04.left.f01`<br>`(608, 128, 32, 32)` | `hair-v2.r04.left.f02`<br>`(640, 128, 32, 32)` | `hair-v2.r04.left.f03`<br>`(672, 128, 32, 32)` | `hair-v2.r04.left.f04`<br>`(704, 128, 32, 32)` | `hair-v2.r04.left.f05`<br>`(736, 128, 32, 32)` |

## Hairs.png

Source: [Hairs.png](<./Hairs.png>)

- **Canvas:** 768 × 256 pixels
- **Grid:** 24 columns × 8 rows
- **Cell size:** 32 × 32 pixels
- **Cell count:** 192
- **ID format:** `hairs.r<row>.<direction>.f<frame>`

Vertical rows are different hair types or variants. The horizontal direction groups remain aligned with the character model sheet.

### Row mapping

| Row ID | Source `y` | Meaning |
|---|---:|---|
| `r00` | 0 | Hair type/variant row 00 |
| `r01` | 32 | Hair type/variant row 01 |
| `r02` | 64 | Hair type/variant row 02 |
| `r03` | 96 | Hair type/variant row 03 |
| `r04` | 128 | Hair type/variant row 04 |
| `r05` | 160 | Hair type/variant row 05 |
| `r06` | 192 | Hair type/variant row 06 |
| `r07` | 224 | Hair type/variant row 07 |

### Down-facing / front view

Columns `c00`–`c05`.

| Palette/type row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `hairs.r00.down.f00`<br>`(0, 0, 32, 32)` | `hairs.r00.down.f01`<br>`(32, 0, 32, 32)` | `hairs.r00.down.f02`<br>`(64, 0, 32, 32)` | `hairs.r00.down.f03`<br>`(96, 0, 32, 32)` | `hairs.r00.down.f04`<br>`(128, 0, 32, 32)` | `hairs.r00.down.f05`<br>`(160, 0, 32, 32)` |
| `r01` | `hairs.r01.down.f00`<br>`(0, 32, 32, 32)` | `hairs.r01.down.f01`<br>`(32, 32, 32, 32)` | `hairs.r01.down.f02`<br>`(64, 32, 32, 32)` | `hairs.r01.down.f03`<br>`(96, 32, 32, 32)` | `hairs.r01.down.f04`<br>`(128, 32, 32, 32)` | `hairs.r01.down.f05`<br>`(160, 32, 32, 32)` |
| `r02` | `hairs.r02.down.f00`<br>`(0, 64, 32, 32)` | `hairs.r02.down.f01`<br>`(32, 64, 32, 32)` | `hairs.r02.down.f02`<br>`(64, 64, 32, 32)` | `hairs.r02.down.f03`<br>`(96, 64, 32, 32)` | `hairs.r02.down.f04`<br>`(128, 64, 32, 32)` | `hairs.r02.down.f05`<br>`(160, 64, 32, 32)` |
| `r03` | `hairs.r03.down.f00`<br>`(0, 96, 32, 32)` | `hairs.r03.down.f01`<br>`(32, 96, 32, 32)` | `hairs.r03.down.f02`<br>`(64, 96, 32, 32)` | `hairs.r03.down.f03`<br>`(96, 96, 32, 32)` | `hairs.r03.down.f04`<br>`(128, 96, 32, 32)` | `hairs.r03.down.f05`<br>`(160, 96, 32, 32)` |
| `r04` | `hairs.r04.down.f00`<br>`(0, 128, 32, 32)` | `hairs.r04.down.f01`<br>`(32, 128, 32, 32)` | `hairs.r04.down.f02`<br>`(64, 128, 32, 32)` | `hairs.r04.down.f03`<br>`(96, 128, 32, 32)` | `hairs.r04.down.f04`<br>`(128, 128, 32, 32)` | `hairs.r04.down.f05`<br>`(160, 128, 32, 32)` |
| `r05` | `hairs.r05.down.f00`<br>`(0, 160, 32, 32)` | `hairs.r05.down.f01`<br>`(32, 160, 32, 32)` | `hairs.r05.down.f02`<br>`(64, 160, 32, 32)` | `hairs.r05.down.f03`<br>`(96, 160, 32, 32)` | `hairs.r05.down.f04`<br>`(128, 160, 32, 32)` | `hairs.r05.down.f05`<br>`(160, 160, 32, 32)` |
| `r06` | `hairs.r06.down.f00`<br>`(0, 192, 32, 32)` | `hairs.r06.down.f01`<br>`(32, 192, 32, 32)` | `hairs.r06.down.f02`<br>`(64, 192, 32, 32)` | `hairs.r06.down.f03`<br>`(96, 192, 32, 32)` | `hairs.r06.down.f04`<br>`(128, 192, 32, 32)` | `hairs.r06.down.f05`<br>`(160, 192, 32, 32)` |
| `r07` | `hairs.r07.down.f00`<br>`(0, 224, 32, 32)` | `hairs.r07.down.f01`<br>`(32, 224, 32, 32)` | `hairs.r07.down.f02`<br>`(64, 224, 32, 32)` | `hairs.r07.down.f03`<br>`(96, 224, 32, 32)` | `hairs.r07.down.f04`<br>`(128, 224, 32, 32)` | `hairs.r07.down.f05`<br>`(160, 224, 32, 32)` |

### Right-facing profile

Columns `c06`–`c11`.

| Palette/type row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `hairs.r00.right.f00`<br>`(192, 0, 32, 32)` | `hairs.r00.right.f01`<br>`(224, 0, 32, 32)` | `hairs.r00.right.f02`<br>`(256, 0, 32, 32)` | `hairs.r00.right.f03`<br>`(288, 0, 32, 32)` | `hairs.r00.right.f04`<br>`(320, 0, 32, 32)` | `hairs.r00.right.f05`<br>`(352, 0, 32, 32)` |
| `r01` | `hairs.r01.right.f00`<br>`(192, 32, 32, 32)` | `hairs.r01.right.f01`<br>`(224, 32, 32, 32)` | `hairs.r01.right.f02`<br>`(256, 32, 32, 32)` | `hairs.r01.right.f03`<br>`(288, 32, 32, 32)` | `hairs.r01.right.f04`<br>`(320, 32, 32, 32)` | `hairs.r01.right.f05`<br>`(352, 32, 32, 32)` |
| `r02` | `hairs.r02.right.f00`<br>`(192, 64, 32, 32)` | `hairs.r02.right.f01`<br>`(224, 64, 32, 32)` | `hairs.r02.right.f02`<br>`(256, 64, 32, 32)` | `hairs.r02.right.f03`<br>`(288, 64, 32, 32)` | `hairs.r02.right.f04`<br>`(320, 64, 32, 32)` | `hairs.r02.right.f05`<br>`(352, 64, 32, 32)` |
| `r03` | `hairs.r03.right.f00`<br>`(192, 96, 32, 32)` | `hairs.r03.right.f01`<br>`(224, 96, 32, 32)` | `hairs.r03.right.f02`<br>`(256, 96, 32, 32)` | `hairs.r03.right.f03`<br>`(288, 96, 32, 32)` | `hairs.r03.right.f04`<br>`(320, 96, 32, 32)` | `hairs.r03.right.f05`<br>`(352, 96, 32, 32)` |
| `r04` | `hairs.r04.right.f00`<br>`(192, 128, 32, 32)` | `hairs.r04.right.f01`<br>`(224, 128, 32, 32)` | `hairs.r04.right.f02`<br>`(256, 128, 32, 32)` | `hairs.r04.right.f03`<br>`(288, 128, 32, 32)` | `hairs.r04.right.f04`<br>`(320, 128, 32, 32)` | `hairs.r04.right.f05`<br>`(352, 128, 32, 32)` |
| `r05` | `hairs.r05.right.f00`<br>`(192, 160, 32, 32)` | `hairs.r05.right.f01`<br>`(224, 160, 32, 32)` | `hairs.r05.right.f02`<br>`(256, 160, 32, 32)` | `hairs.r05.right.f03`<br>`(288, 160, 32, 32)` | `hairs.r05.right.f04`<br>`(320, 160, 32, 32)` | `hairs.r05.right.f05`<br>`(352, 160, 32, 32)` |
| `r06` | `hairs.r06.right.f00`<br>`(192, 192, 32, 32)` | `hairs.r06.right.f01`<br>`(224, 192, 32, 32)` | `hairs.r06.right.f02`<br>`(256, 192, 32, 32)` | `hairs.r06.right.f03`<br>`(288, 192, 32, 32)` | `hairs.r06.right.f04`<br>`(320, 192, 32, 32)` | `hairs.r06.right.f05`<br>`(352, 192, 32, 32)` |
| `r07` | `hairs.r07.right.f00`<br>`(192, 224, 32, 32)` | `hairs.r07.right.f01`<br>`(224, 224, 32, 32)` | `hairs.r07.right.f02`<br>`(256, 224, 32, 32)` | `hairs.r07.right.f03`<br>`(288, 224, 32, 32)` | `hairs.r07.right.f04`<br>`(320, 224, 32, 32)` | `hairs.r07.right.f05`<br>`(352, 224, 32, 32)` |

### Up-facing / back view

Columns `c12`–`c17`.

| Palette/type row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `hairs.r00.up.f00`<br>`(384, 0, 32, 32)` | `hairs.r00.up.f01`<br>`(416, 0, 32, 32)` | `hairs.r00.up.f02`<br>`(448, 0, 32, 32)` | `hairs.r00.up.f03`<br>`(480, 0, 32, 32)` | `hairs.r00.up.f04`<br>`(512, 0, 32, 32)` | `hairs.r00.up.f05`<br>`(544, 0, 32, 32)` |
| `r01` | `hairs.r01.up.f00`<br>`(384, 32, 32, 32)` | `hairs.r01.up.f01`<br>`(416, 32, 32, 32)` | `hairs.r01.up.f02`<br>`(448, 32, 32, 32)` | `hairs.r01.up.f03`<br>`(480, 32, 32, 32)` | `hairs.r01.up.f04`<br>`(512, 32, 32, 32)` | `hairs.r01.up.f05`<br>`(544, 32, 32, 32)` |
| `r02` | `hairs.r02.up.f00`<br>`(384, 64, 32, 32)` | `hairs.r02.up.f01`<br>`(416, 64, 32, 32)` | `hairs.r02.up.f02`<br>`(448, 64, 32, 32)` | `hairs.r02.up.f03`<br>`(480, 64, 32, 32)` | `hairs.r02.up.f04`<br>`(512, 64, 32, 32)` | `hairs.r02.up.f05`<br>`(544, 64, 32, 32)` |
| `r03` | `hairs.r03.up.f00`<br>`(384, 96, 32, 32)` | `hairs.r03.up.f01`<br>`(416, 96, 32, 32)` | `hairs.r03.up.f02`<br>`(448, 96, 32, 32)` | `hairs.r03.up.f03`<br>`(480, 96, 32, 32)` | `hairs.r03.up.f04`<br>`(512, 96, 32, 32)` | `hairs.r03.up.f05`<br>`(544, 96, 32, 32)` |
| `r04` | `hairs.r04.up.f00`<br>`(384, 128, 32, 32)` | `hairs.r04.up.f01`<br>`(416, 128, 32, 32)` | `hairs.r04.up.f02`<br>`(448, 128, 32, 32)` | `hairs.r04.up.f03`<br>`(480, 128, 32, 32)` | `hairs.r04.up.f04`<br>`(512, 128, 32, 32)` | `hairs.r04.up.f05`<br>`(544, 128, 32, 32)` |
| `r05` | `hairs.r05.up.f00`<br>`(384, 160, 32, 32)` | `hairs.r05.up.f01`<br>`(416, 160, 32, 32)` | `hairs.r05.up.f02`<br>`(448, 160, 32, 32)` | `hairs.r05.up.f03`<br>`(480, 160, 32, 32)` | `hairs.r05.up.f04`<br>`(512, 160, 32, 32)` | `hairs.r05.up.f05`<br>`(544, 160, 32, 32)` |
| `r06` | `hairs.r06.up.f00`<br>`(384, 192, 32, 32)` | `hairs.r06.up.f01`<br>`(416, 192, 32, 32)` | `hairs.r06.up.f02`<br>`(448, 192, 32, 32)` | `hairs.r06.up.f03`<br>`(480, 192, 32, 32)` | `hairs.r06.up.f04`<br>`(512, 192, 32, 32)` | `hairs.r06.up.f05`<br>`(544, 192, 32, 32)` |
| `r07` | `hairs.r07.up.f00`<br>`(384, 224, 32, 32)` | `hairs.r07.up.f01`<br>`(416, 224, 32, 32)` | `hairs.r07.up.f02`<br>`(448, 224, 32, 32)` | `hairs.r07.up.f03`<br>`(480, 224, 32, 32)` | `hairs.r07.up.f04`<br>`(512, 224, 32, 32)` | `hairs.r07.up.f05`<br>`(544, 224, 32, 32)` |

### Left-facing profile

Columns `c18`–`c23`.

| Palette/type row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `hairs.r00.left.f00`<br>`(576, 0, 32, 32)` | `hairs.r00.left.f01`<br>`(608, 0, 32, 32)` | `hairs.r00.left.f02`<br>`(640, 0, 32, 32)` | `hairs.r00.left.f03`<br>`(672, 0, 32, 32)` | `hairs.r00.left.f04`<br>`(704, 0, 32, 32)` | `hairs.r00.left.f05`<br>`(736, 0, 32, 32)` |
| `r01` | `hairs.r01.left.f00`<br>`(576, 32, 32, 32)` | `hairs.r01.left.f01`<br>`(608, 32, 32, 32)` | `hairs.r01.left.f02`<br>`(640, 32, 32, 32)` | `hairs.r01.left.f03`<br>`(672, 32, 32, 32)` | `hairs.r01.left.f04`<br>`(704, 32, 32, 32)` | `hairs.r01.left.f05`<br>`(736, 32, 32, 32)` |
| `r02` | `hairs.r02.left.f00`<br>`(576, 64, 32, 32)` | `hairs.r02.left.f01`<br>`(608, 64, 32, 32)` | `hairs.r02.left.f02`<br>`(640, 64, 32, 32)` | `hairs.r02.left.f03`<br>`(672, 64, 32, 32)` | `hairs.r02.left.f04`<br>`(704, 64, 32, 32)` | `hairs.r02.left.f05`<br>`(736, 64, 32, 32)` |
| `r03` | `hairs.r03.left.f00`<br>`(576, 96, 32, 32)` | `hairs.r03.left.f01`<br>`(608, 96, 32, 32)` | `hairs.r03.left.f02`<br>`(640, 96, 32, 32)` | `hairs.r03.left.f03`<br>`(672, 96, 32, 32)` | `hairs.r03.left.f04`<br>`(704, 96, 32, 32)` | `hairs.r03.left.f05`<br>`(736, 96, 32, 32)` |
| `r04` | `hairs.r04.left.f00`<br>`(576, 128, 32, 32)` | `hairs.r04.left.f01`<br>`(608, 128, 32, 32)` | `hairs.r04.left.f02`<br>`(640, 128, 32, 32)` | `hairs.r04.left.f03`<br>`(672, 128, 32, 32)` | `hairs.r04.left.f04`<br>`(704, 128, 32, 32)` | `hairs.r04.left.f05`<br>`(736, 128, 32, 32)` |
| `r05` | `hairs.r05.left.f00`<br>`(576, 160, 32, 32)` | `hairs.r05.left.f01`<br>`(608, 160, 32, 32)` | `hairs.r05.left.f02`<br>`(640, 160, 32, 32)` | `hairs.r05.left.f03`<br>`(672, 160, 32, 32)` | `hairs.r05.left.f04`<br>`(704, 160, 32, 32)` | `hairs.r05.left.f05`<br>`(736, 160, 32, 32)` |
| `r06` | `hairs.r06.left.f00`<br>`(576, 192, 32, 32)` | `hairs.r06.left.f01`<br>`(608, 192, 32, 32)` | `hairs.r06.left.f02`<br>`(640, 192, 32, 32)` | `hairs.r06.left.f03`<br>`(672, 192, 32, 32)` | `hairs.r06.left.f04`<br>`(704, 192, 32, 32)` | `hairs.r06.left.f05`<br>`(736, 192, 32, 32)` |
| `r07` | `hairs.r07.left.f00`<br>`(576, 224, 32, 32)` | `hairs.r07.left.f01`<br>`(608, 224, 32, 32)` | `hairs.r07.left.f02`<br>`(640, 224, 32, 32)` | `hairs.r07.left.f03`<br>`(672, 224, 32, 32)` | `hairs.r07.left.f04`<br>`(704, 224, 32, 32)` | `hairs.r07.left.f05`<br>`(736, 224, 32, 32)` |

## Lookup examples

- `hair-v2.r02.right.f04` → crop `(320, 64, 32, 32)` from `Hair_v2.png`.
- `hairs.r07.left.f01` → crop `(608, 224, 32, 32)` from `Hairs.png`.
- `hair.Hair3` → crop `(0, 0, 32, 32)` from `Hair3.png`.

The catalog records source cells, including transparent padding. Do not trim or rename the original PNGs when using these coordinates.

