# Character Model Asset Catalog

Coordinate catalog for every PNG in this directory.

## Asset inventory

| File | Dimensions | Grid | Cells | Description |
|---|---:|---:|---:|---|
| [`Character Model.png`](<./Character Model.png>) | 768 × 192 | 24 × 6 | 144 | Character model direction and animation sheet |
| [`Shadow.png`](<./Shadow.png>) | 32 × 32 | 1 × 1 | 1 | Ground shadow sprite |

## Shared conventions

- Coordinates use the source PNG's top-left pixel as `(0, 0)`.
- Rectangles use `(x, y, width, height)` with exclusive right and bottom edges.
- Character model cells are 32 × 32 pixels and tile the 768 × 192 source image edge-to-edge.
- The character model's horizontal direction groups are `c00`–`c05` down/front, `c06`–`c11` right, `c12`–`c17` up/back, and `c18`–`c23` left.
- The transparent padding around each sprite is part of its source cell and should be retained unless a caller specifically needs a trimmed visible-pixel rectangle.

## Character Model.png

Source: [`Character Model.png`](<./Character Model.png>)

### Sheet summary

- **Canvas:** 768 × 192 pixels
- **Format:** RGBA PNG with transparent background
- **Cell size:** 32 × 32 pixels
- **Grid:** 24 columns × 6 rows
- **Total cells:** 144
- **Gutters:** none

### Naming convention

Each catalog ID uses this form:

```text
character.r<row>.<direction>.f<frame>
```

For example, `character.r02.right.f04` is row `r02`, the right-facing direction group, frame `f04`.

The frame number is the left-to-right source order within a direction group. It is not labeled with a timing or animation name because the source file does not provide animation metadata.

### Palette rows

These labels are descriptive catalog identifiers, not source-defined character names.

| Row ID | Source `y` | Visual note |
|---|---:|---|
| `r00` | 0 | Light warm palette |
| `r01` | 32 | Pale pink/cream palette |
| `r02` | 64 | Light warm peach palette |
| `r03` | 96 | Medium brown palette |
| `r04` | 128 | Pale cream/pink palette |
| `r05` | 160 | Dark brown palette |

### Direction groups

Each direction has six consecutive frames.

| Direction ID | Visual orientation | Columns | Source `x` range |
|---|---|---|---:|
| `down` | Down-facing / front view | `c00`–`c05` | 0–160 |
| `right` | Right-facing profile | `c06`–`c11` | 192–352 |
| `up` | Up-facing / back view | `c12`–`c17` | 384–544 |
| `left` | Left-facing profile | `c18`–`c23` | 576–736 |

### Complete coordinate index

All rectangles below are in source-image coordinates and use `(x, y, 32, 32)`.

#### Down-facing / front view

Columns `c00`–`c05`.

| Palette row | `f00 / c00` | `f01 / c01` | `f02 / c02` | `f03 / c03` | `f04 / c04` | `f05 / c05` |
|---|---|---|---|---|---|---|
| `r00` | `character.r00.down.f00`<br>`(0, 0, 32, 32)` | `character.r00.down.f01`<br>`(32, 0, 32, 32)` | `character.r00.down.f02`<br>`(64, 0, 32, 32)` | `character.r00.down.f03`<br>`(96, 0, 32, 32)` | `character.r00.down.f04`<br>`(128, 0, 32, 32)` | `character.r00.down.f05`<br>`(160, 0, 32, 32)` |
| `r01` | `character.r01.down.f00`<br>`(0, 32, 32, 32)` | `character.r01.down.f01`<br>`(32, 32, 32, 32)` | `character.r01.down.f02`<br>`(64, 32, 32, 32)` | `character.r01.down.f03`<br>`(96, 32, 32, 32)` | `character.r01.down.f04`<br>`(128, 32, 32, 32)` | `character.r01.down.f05`<br>`(160, 32, 32, 32)` |
| `r02` | `character.r02.down.f00`<br>`(0, 64, 32, 32)` | `character.r02.down.f01`<br>`(32, 64, 32, 32)` | `character.r02.down.f02`<br>`(64, 64, 32, 32)` | `character.r02.down.f03`<br>`(96, 64, 32, 32)` | `character.r02.down.f04`<br>`(128, 64, 32, 32)` | `character.r02.down.f05`<br>`(160, 64, 32, 32)` |
| `r03` | `character.r03.down.f00`<br>`(0, 96, 32, 32)` | `character.r03.down.f01`<br>`(32, 96, 32, 32)` | `character.r03.down.f02`<br>`(64, 96, 32, 32)` | `character.r03.down.f03`<br>`(96, 96, 32, 32)` | `character.r03.down.f04`<br>`(128, 96, 32, 32)` | `character.r03.down.f05`<br>`(160, 96, 32, 32)` |
| `r04` | `character.r04.down.f00`<br>`(0, 128, 32, 32)` | `character.r04.down.f01`<br>`(32, 128, 32, 32)` | `character.r04.down.f02`<br>`(64, 128, 32, 32)` | `character.r04.down.f03`<br>`(96, 128, 32, 32)` | `character.r04.down.f04`<br>`(128, 128, 32, 32)` | `character.r04.down.f05`<br>`(160, 128, 32, 32)` |
| `r05` | `character.r05.down.f00`<br>`(0, 160, 32, 32)` | `character.r05.down.f01`<br>`(32, 160, 32, 32)` | `character.r05.down.f02`<br>`(64, 160, 32, 32)` | `character.r05.down.f03`<br>`(96, 160, 32, 32)` | `character.r05.down.f04`<br>`(128, 160, 32, 32)` | `character.r05.down.f05`<br>`(160, 160, 32, 32)` |

#### Right-facing profile

Columns `c06`–`c11`.

| Palette row | `f00 / c06` | `f01 / c07` | `f02 / c08` | `f03 / c09` | `f04 / c10` | `f05 / c11` |
|---|---|---|---|---|---|---|
| `r00` | `character.r00.right.f00`<br>`(192, 0, 32, 32)` | `character.r00.right.f01`<br>`(224, 0, 32, 32)` | `character.r00.right.f02`<br>`(256, 0, 32, 32)` | `character.r00.right.f03`<br>`(288, 0, 32, 32)` | `character.r00.right.f04`<br>`(320, 0, 32, 32)` | `character.r00.right.f05`<br>`(352, 0, 32, 32)` |
| `r01` | `character.r01.right.f00`<br>`(192, 32, 32, 32)` | `character.r01.right.f01`<br>`(224, 32, 32, 32)` | `character.r01.right.f02`<br>`(256, 32, 32, 32)` | `character.r01.right.f03`<br>`(288, 32, 32, 32)` | `character.r01.right.f04`<br>`(320, 32, 32, 32)` | `character.r01.right.f05`<br>`(352, 32, 32, 32)` |
| `r02` | `character.r02.right.f00`<br>`(192, 64, 32, 32)` | `character.r02.right.f01`<br>`(224, 64, 32, 32)` | `character.r02.right.f02`<br>`(256, 64, 32, 32)` | `character.r02.right.f03`<br>`(288, 64, 32, 32)` | `character.r02.right.f04`<br>`(320, 64, 32, 32)` | `character.r02.right.f05`<br>`(352, 64, 32, 32)` |
| `r03` | `character.r03.right.f00`<br>`(192, 96, 32, 32)` | `character.r03.right.f01`<br>`(224, 96, 32, 32)` | `character.r03.right.f02`<br>`(256, 96, 32, 32)` | `character.r03.right.f03`<br>`(288, 96, 32, 32)` | `character.r03.right.f04`<br>`(320, 96, 32, 32)` | `character.r03.right.f05`<br>`(352, 96, 32, 32)` |
| `r04` | `character.r04.right.f00`<br>`(192, 128, 32, 32)` | `character.r04.right.f01`<br>`(224, 128, 32, 32)` | `character.r04.right.f02`<br>`(256, 128, 32, 32)` | `character.r04.right.f03`<br>`(288, 128, 32, 32)` | `character.r04.right.f04`<br>`(320, 128, 32, 32)` | `character.r04.right.f05`<br>`(352, 128, 32, 32)` |
| `r05` | `character.r05.right.f00`<br>`(192, 160, 32, 32)` | `character.r05.right.f01`<br>`(224, 160, 32, 32)` | `character.r05.right.f02`<br>`(256, 160, 32, 32)` | `character.r05.right.f03`<br>`(288, 160, 32, 32)` | `character.r05.right.f04`<br>`(320, 160, 32, 32)` | `character.r05.right.f05`<br>`(352, 160, 32, 32)` |

#### Up-facing / back view

Columns `c12`–`c17`.

| Palette row | `f00 / c12` | `f01 / c13` | `f02 / c14` | `f03 / c15` | `f04 / c16` | `f05 / c17` |
|---|---|---|---|---|---|---|
| `r00` | `character.r00.up.f00`<br>`(384, 0, 32, 32)` | `character.r00.up.f01`<br>`(416, 0, 32, 32)` | `character.r00.up.f02`<br>`(448, 0, 32, 32)` | `character.r00.up.f03`<br>`(480, 0, 32, 32)` | `character.r00.up.f04`<br>`(512, 0, 32, 32)` | `character.r00.up.f05`<br>`(544, 0, 32, 32)` |
| `r01` | `character.r01.up.f00`<br>`(384, 32, 32, 32)` | `character.r01.up.f01`<br>`(416, 32, 32, 32)` | `character.r01.up.f02`<br>`(448, 32, 32, 32)` | `character.r01.up.f03`<br>`(480, 32, 32, 32)` | `character.r01.up.f04`<br>`(512, 32, 32, 32)` | `character.r01.up.f05`<br>`(544, 32, 32, 32)` |
| `r02` | `character.r02.up.f00`<br>`(384, 64, 32, 32)` | `character.r02.up.f01`<br>`(416, 64, 32, 32)` | `character.r02.up.f02`<br>`(448, 64, 32, 32)` | `character.r02.up.f03`<br>`(480, 64, 32, 32)` | `character.r02.up.f04`<br>`(512, 64, 32, 32)` | `character.r02.up.f05`<br>`(544, 64, 32, 32)` |
| `r03` | `character.r03.up.f00`<br>`(384, 96, 32, 32)` | `character.r03.up.f01`<br>`(416, 96, 32, 32)` | `character.r03.up.f02`<br>`(448, 96, 32, 32)` | `character.r03.up.f03`<br>`(480, 96, 32, 32)` | `character.r03.up.f04`<br>`(512, 96, 32, 32)` | `character.r03.up.f05`<br>`(544, 96, 32, 32)` |
| `r04` | `character.r04.up.f00`<br>`(384, 128, 32, 32)` | `character.r04.up.f01`<br>`(416, 128, 32, 32)` | `character.r04.up.f02`<br>`(448, 128, 32, 32)` | `character.r04.up.f03`<br>`(480, 128, 32, 32)` | `character.r04.up.f04`<br>`(512, 128, 32, 32)` | `character.r04.up.f05`<br>`(544, 128, 32, 32)` |
| `r05` | `character.r05.up.f00`<br>`(384, 160, 32, 32)` | `character.r05.up.f01`<br>`(416, 160, 32, 32)` | `character.r05.up.f02`<br>`(448, 160, 32, 32)` | `character.r05.up.f03`<br>`(480, 160, 32, 32)` | `character.r05.up.f04`<br>`(512, 160, 32, 32)` | `character.r05.up.f05`<br>`(544, 160, 32, 32)` |

#### Left-facing profile

Columns `c18`–`c23`.

| Palette row | `f00 / c18` | `f01 / c19` | `f02 / c20` | `f03 / c21` | `f04 / c22` | `f05 / c23` |
|---|---|---|---|---|---|---|
| `r00` | `character.r00.left.f00`<br>`(576, 0, 32, 32)` | `character.r00.left.f01`<br>`(608, 0, 32, 32)` | `character.r00.left.f02`<br>`(640, 0, 32, 32)` | `character.r00.left.f03`<br>`(672, 0, 32, 32)` | `character.r00.left.f04`<br>`(704, 0, 32, 32)` | `character.r00.left.f05`<br>`(736, 0, 32, 32)` |
| `r01` | `character.r01.left.f00`<br>`(576, 32, 32, 32)` | `character.r01.left.f01`<br>`(608, 32, 32, 32)` | `character.r01.left.f02`<br>`(640, 32, 32, 32)` | `character.r01.left.f03`<br>`(672, 32, 32, 32)` | `character.r01.left.f04`<br>`(704, 32, 32, 32)` | `character.r01.left.f05`<br>`(736, 32, 32, 32)` |
| `r02` | `character.r02.left.f00`<br>`(576, 64, 32, 32)` | `character.r02.left.f01`<br>`(608, 64, 32, 32)` | `character.r02.left.f02`<br>`(640, 64, 32, 32)` | `character.r02.left.f03`<br>`(672, 64, 32, 32)` | `character.r02.left.f04`<br>`(704, 64, 32, 32)` | `character.r02.left.f05`<br>`(736, 64, 32, 32)` |
| `r03` | `character.r03.left.f00`<br>`(576, 96, 32, 32)` | `character.r03.left.f01`<br>`(608, 96, 32, 32)` | `character.r03.left.f02`<br>`(640, 96, 32, 32)` | `character.r03.left.f03`<br>`(672, 96, 32, 32)` | `character.r03.left.f04`<br>`(704, 96, 32, 32)` | `character.r03.left.f05`<br>`(736, 96, 32, 32)` |
| `r04` | `character.r04.left.f00`<br>`(576, 128, 32, 32)` | `character.r04.left.f01`<br>`(608, 128, 32, 32)` | `character.r04.left.f02`<br>`(640, 128, 32, 32)` | `character.r04.left.f03`<br>`(672, 128, 32, 32)` | `character.r04.left.f04`<br>`(704, 128, 32, 32)` | `character.r04.left.f05`<br>`(736, 128, 32, 32)` |
| `r05` | `character.r05.left.f00`<br>`(576, 160, 32, 32)` | `character.r05.left.f01`<br>`(608, 160, 32, 32)` | `character.r05.left.f02`<br>`(640, 160, 32, 32)` | `character.r05.left.f03`<br>`(672, 160, 32, 32)` | `character.r05.left.f04`<br>`(704, 160, 32, 32)` | `character.r05.left.f05`<br>`(736, 160, 32, 32)` |

## Shadow.png

Source: [`Shadow.png`](<./Shadow.png>)

| Asset ID | Source dimensions | Rectangle `(x, y, width, height)` | Description |
|---|---:|---|---|
| `shadow` | 32 × 32 | `(0, 0, 32, 32)` | Ground shadow sprite |

`Shadow.png` is one complete 32×32 cell with transparent padding around the shadow.

## Verification notes

- `Character Model.png`: `768 / 32 = 24` columns and `192 / 32 = 6` rows, covering 144 cells.
- `Shadow.png`: one 32×32 cell, covering 1 asset.
- The combined catalog covers every PNG in `Character/CharacterModel/`.
