# Home Interior Asset Catalog

Coordinate catalog for every PNG in `Interior/Home/`.

## Coordinate conventions

Home interior sheets use variable furniture rectangles. The furniture sheets in this directory are packed into 64-pixel-wide slots, while the slot height is defined per file. `TilesHouse.png` is cataloged as a 16×16 atomic tile atlas.

Coordinates are source-image pixels with a top-left origin `(0, 0)`. Rectangles use `(x, y, width, height)` with exclusive right and bottom edges.

For furniture slots, visible-pixel bounds are measured from the alpha channel relative to each slot. The full source slot is the default crop and should be retained when composing furniture unless a trimmed crop is specifically needed.

## File inventory

| File | Canvas | Authoritative unit | Grid | Occupied assets |
|---|---:|---:|---:|---:|
| [`Bathroom-Sheet.png`](<./Bathroom-Sheet.png>) | 576 × 96 | 64 × 96 slot | 9 × 1 | 7 / 9 |
| [`Beds-Sheet.png`](<./Beds-Sheet.png>) | 256 × 256 | 64 × 64 slot | 4 × 4 | 16 / 16 |
| [`Beds1-Sheet.png`](<./Beds1-Sheet.png>) | 256 × 320 | 64 × 64 slot | 4 × 5 | 20 / 20 |
| [`Carpet-Sheet.png`](<./Carpet-Sheet.png>) | 320 × 64 | 64 × 64 slot | 5 × 1 | 5 / 5 |
| [`Chimney-Sheet.png`](<./Chimney-Sheet.png>) | 384 × 48 | 64 × 48 slot | 6 × 1 | 6 / 6 |
| [`Chimney1-Sheet.png`](<./Chimney1-Sheet.png>) | 256 × 32 | 64 × 32 slot | 4 × 1 | 4 / 4 |
| [`Cupboard-Sheet.png`](<./Cupboard-Sheet.png>) | 576 × 96 | 64 × 96 slot | 9 × 1 | 9 / 9 |
| [`Doors-Sheet.png`](<./Doors-Sheet.png>) | 1344 × 128 | 64 × 128 slot | 21 × 1 | 20 / 21 |
| [`Flowers-Sheet.png`](<./Flowers-Sheet.png>) | 384 × 96 | 64 × 96 slot | 6 × 1 | 6 / 6 |
| [`Kitchen-Sheet.png`](<./Kitchen-Sheet.png>) | 1152 × 96 | 64 × 96 slot | 18 × 1 | 14 / 18 |
| [`Kitchen1-Sheet.png`](<./Kitchen1-Sheet.png>) | 576 × 96 | 64 × 96 slot | 9 × 1 | 7 / 9 |
| [`Lights-Sheet.png`](<./Lights-Sheet.png>) | 384 × 64 | 64 × 64 slot | 6 × 1 | 6 / 6 |
| [`LivingRoom-Sheet.png`](<./LivingRoom-Sheet.png>) | 192 × 96 | 64 × 96 slot | 3 × 1 | 3 / 3 |
| [`LivingRoom1-Sheet.png`](<./LivingRoom1-Sheet.png>) | 384 × 960 | 64 × 64 slot | 6 × 15 | 75 / 90 |
| [`Miscellaneous-Sheet.png`](<./Miscellaneous-Sheet.png>) | 640 × 64 | 64 × 64 slot | 10 × 1 | 10 / 10 |
| [`Paintings-Sheet.png`](<./Paintings-Sheet.png>) | 320 × 32 | 64 × 32 slot | 5 × 1 | 5 / 5 |
| [`Paintings1-Sheet.png`](<./Paintings1-Sheet.png>) | 160 × 32 | 64 × 32 slot | 2 × 1 | 2 / 2 |
| [`TV-Sheet.png`](<./TV-Sheet.png>) | 256 × 96 | 64 × 96 slot | 4 × 1 | 4 / 4 |
| [`Windows-Sheet.png`](<./Windows-Sheet.png>) | 896 × 64 | 64 × 64 slot | 14 × 1 | 14 / 14 |
| [`TilesHouse.png`](<./TilesHouse.png>) | 512 × 512 | 16 × 16 tile | 32 × 32 | 412 / 1024 |

Furniture sheets contain 233 occupied slots out of 257; empty slots are retained in the occupancy maps for source-layout reference.

## Bathroom-Sheet.png

Source: [`Bathroom-Sheet.png`](<./Bathroom-Sheet.png>)

- **Canvas:** 576 × 96 pixels
- **Grid:** 9 columns × 1 rows of 64 × 96 slots
- **Cell count:** 9
- **Occupied slots:** 7
- **ID format:** `home.bathroom.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `#.#####.#` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.bathroom.r00.c00` | `(0, 0, 64, 96)` | `(35, 2, 26, 50)` |
| `home.bathroom.r00.c02` | `(128, 0, 64, 96)` | `(7, 13, 18, 39)` |
| `home.bathroom.r00.c03` | `(192, 0, 64, 96)` | `(15, 15, 49, 33)` |
| `home.bathroom.r00.c04` | `(256, 0, 64, 96)` | `(0, 15, 17, 33)` |
| `home.bathroom.r00.c05` | `(320, 0, 64, 96)` | `(3, 13, 26, 50)` |
| `home.bathroom.r00.c06` | `(384, 0, 64, 96)` | `(36, 27, 23, 21)` |
| `home.bathroom.r00.c08` | `(512, 0, 64, 96)` | `(1, 29, 30, 7)` |

## Beds-Sheet.png

Source: [`Beds-Sheet.png`](<./Beds-Sheet.png>)

- **Canvas:** 256 × 256 pixels
- **Grid:** 4 columns × 4 rows of 64 × 64 slots
- **Cell count:** 16
- **Occupied slots:** 16
- **ID format:** `home.beds.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `####` |
| `r01` | 64 | `####` |
| `r02` | 128 | `####` |
| `r03` | 192 | `####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.beds.r00.c00` | `(0, 0, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r00.c01` | `(64, 0, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r00.c02` | `(128, 0, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r00.c03` | `(192, 0, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r01.c00` | `(0, 64, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r01.c01` | `(64, 64, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r01.c02` | `(128, 64, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r01.c03` | `(192, 64, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r02.c00` | `(0, 128, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r02.c01` | `(64, 128, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r02.c02` | `(128, 128, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r02.c03` | `(192, 128, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r03.c00` | `(0, 192, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r03.c01` | `(64, 192, 64, 64)` | `(18, 7, 28, 42)` |
| `home.beds.r03.c02` | `(128, 192, 64, 64)` | `(11, 3, 42, 46)` |
| `home.beds.r03.c03` | `(192, 192, 64, 64)` | `(11, 3, 42, 46)` |

## Beds1-Sheet.png

Source: [`Beds1-Sheet.png`](<./Beds1-Sheet.png>)

- **Canvas:** 256 × 320 pixels
- **Grid:** 4 columns × 5 rows of 64 × 64 slots
- **Cell count:** 20
- **Occupied slots:** 20
- **ID format:** `home.beds1.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `####` |
| `r01` | 64 | `####` |
| `r02` | 128 | `####` |
| `r03` | 192 | `####` |
| `r04` | 256 | `####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.beds1.r00.c00` | `(0, 0, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r00.c01` | `(64, 0, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r00.c02` | `(128, 0, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r00.c03` | `(192, 0, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r01.c00` | `(0, 64, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r01.c01` | `(64, 64, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r01.c02` | `(128, 64, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r01.c03` | `(192, 64, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r02.c00` | `(0, 128, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r02.c01` | `(64, 128, 64, 64)` | `(20, 4, 24, 45)` |
| `home.beds1.r02.c02` | `(128, 128, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r02.c03` | `(192, 128, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r03.c00` | `(0, 192, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r03.c01` | `(64, 192, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r03.c02` | `(128, 192, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r03.c03` | `(192, 192, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r04.c00` | `(0, 256, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r04.c01` | `(64, 256, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r04.c02` | `(128, 256, 64, 64)` | `(11, 4, 42, 45)` |
| `home.beds1.r04.c03` | `(192, 256, 64, 64)` | `(11, 4, 42, 45)` |

## Carpet-Sheet.png

Source: [`Carpet-Sheet.png`](<./Carpet-Sheet.png>)

- **Canvas:** 320 × 64 pixels
- **Grid:** 5 columns × 1 rows of 64 × 64 slots
- **Cell count:** 5
- **Occupied slots:** 5
- **ID format:** `home.carpet.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `#####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.carpet.r00.c00` | `(0, 0, 64, 64)` | `(11, 0, 42, 64)` |
| `home.carpet.r00.c01` | `(64, 0, 64, 64)` | `(11, 0, 42, 64)` |
| `home.carpet.r00.c02` | `(128, 0, 64, 64)` | `(0, 0, 64, 64)` |
| `home.carpet.r00.c03` | `(192, 0, 64, 64)` | `(4, 4, 56, 54)` |
| `home.carpet.r00.c04` | `(256, 0, 64, 64)` | `(4, 4, 56, 54)` |

## Chimney-Sheet.png

Source: [`Chimney-Sheet.png`](<./Chimney-Sheet.png>)

- **Canvas:** 384 × 48 pixels
- **Grid:** 6 columns × 1 rows of 64 × 48 slots
- **Cell count:** 6
- **Occupied slots:** 6
- **ID format:** `home.chimney.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `######` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.chimney.r00.c00` | `(0, 0, 64, 48)` | `(7, 7, 57, 39)` |
| `home.chimney.r00.c01` | `(64, 0, 64, 48)` | `(0, 7, 64, 39)` |
| `home.chimney.r00.c02` | `(128, 0, 64, 48)` | `(0, 7, 57, 39)` |
| `home.chimney.r00.c03` | `(192, 0, 64, 48)` | `(7, 7, 57, 39)` |
| `home.chimney.r00.c04` | `(256, 0, 64, 48)` | `(0, 7, 64, 39)` |
| `home.chimney.r00.c05` | `(320, 0, 64, 48)` | `(0, 7, 57, 39)` |

## Chimney1-Sheet.png

Source: [`Chimney1-Sheet.png`](<./Chimney1-Sheet.png>)

- **Canvas:** 256 × 32 pixels
- **Grid:** 4 columns × 1 rows of 64 × 32 slots
- **Cell count:** 4
- **Occupied slots:** 4
- **ID format:** `home.chimney1.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.chimney1.r00.c00` | `(0, 0, 64, 32)` | `(2, 11, 61, 21)` |
| `home.chimney1.r00.c01` | `(64, 0, 64, 32)` | `(2, 11, 61, 21)` |
| `home.chimney1.r00.c02` | `(128, 0, 64, 32)` | `(2, 11, 61, 21)` |
| `home.chimney1.r00.c03` | `(192, 0, 64, 32)` | `(2, 11, 61, 21)` |

## Cupboard-Sheet.png

Source: [`Cupboard-Sheet.png`](<./Cupboard-Sheet.png>)

- **Canvas:** 576 × 96 pixels
- **Grid:** 9 columns × 1 rows of 64 × 96 slots
- **Cell count:** 9
- **Occupied slots:** 9
- **ID format:** `home.cupboard.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `#########` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.cupboard.r00.c00` | `(0, 0, 64, 96)` | `(21, 18, 22, 30)` |
| `home.cupboard.r00.c01` | `(64, 0, 64, 96)` | `(14, 18, 37, 30)` |
| `home.cupboard.r00.c02` | `(128, 0, 64, 96)` | `(14, 18, 35, 30)` |
| `home.cupboard.r00.c03` | `(192, 0, 64, 96)` | `(12, 16, 40, 52)` |
| `home.cupboard.r00.c04` | `(256, 0, 64, 96)` | `(14, 20, 36, 43)` |
| `home.cupboard.r00.c05` | `(320, 0, 64, 96)` | `(14, 29, 36, 34)` |
| `home.cupboard.r00.c06` | `(384, 0, 64, 96)` | `(22, 16, 20, 32)` |
| `home.cupboard.r00.c07` | `(448, 0, 64, 96)` | `(22, 7, 20, 41)` |
| `home.cupboard.r00.c08` | `(512, 0, 64, 96)` | `(22, 7, 20, 41)` |

## Doors-Sheet.png

Source: [`Doors-Sheet.png`](<./Doors-Sheet.png>)

- **Canvas:** 1344 × 128 pixels
- **Grid:** 21 columns × 1 rows of 64 × 128 slots
- **Cell count:** 21
- **Occupied slots:** 20
- **ID format:** `home.doors.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `##########.##########` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.doors.r00.c00` | `(0, 0, 64, 128)` | `(31, 15, 33, 49)` |
| `home.doors.r00.c01` | `(64, 0, 64, 128)` | `(0, 15, 64, 49)` |
| `home.doors.r00.c02` | `(128, 0, 64, 128)` | `(0, 15, 33, 49)` |
| `home.doors.r00.c03` | `(192, 0, 64, 128)` | `(31, 15, 33, 49)` |
| `home.doors.r00.c04` | `(256, 0, 64, 128)` | `(0, 15, 64, 49)` |
| `home.doors.r00.c05` | `(320, 0, 64, 128)` | `(0, 15, 33, 49)` |
| `home.doors.r00.c06` | `(384, 0, 64, 128)` | `(31, 15, 33, 49)` |
| `home.doors.r00.c07` | `(448, 0, 64, 128)` | `(0, 15, 64, 49)` |
| `home.doors.r00.c08` | `(512, 0, 64, 128)` | `(0, 15, 33, 49)` |
| `home.doors.r00.c09` | `(576, 0, 64, 128)` | `(45, 4, 6, 60)` |
| `home.doors.r00.c11` | `(704, 0, 64, 128)` | `(13, 4, 32, 60)` |
| `home.doors.r00.c12` | `(768, 0, 64, 128)` | `(19, 4, 32, 60)` |
| `home.doors.r00.c13` | `(832, 0, 64, 128)` | `(63, 15, 1, 49)` |
| `home.doors.r00.c14` | `(896, 0, 64, 128)` | `(0, 15, 33, 49)` |
| `home.doors.r00.c15` | `(960, 0, 64, 128)` | `(31, 15, 33, 49)` |
| `home.doors.r00.c16` | `(1024, 0, 64, 128)` | `(0, 15, 64, 49)` |
| `home.doors.r00.c17` | `(1088, 0, 64, 128)` | `(0, 0, 33, 64)` |
| `home.doors.r00.c18` | `(1152, 0, 64, 128)` | `(31, 15, 33, 49)` |
| `home.doors.r00.c19` | `(1216, 0, 64, 128)` | `(0, 15, 64, 49)` |
| `home.doors.r00.c20` | `(1280, 0, 64, 128)` | `(0, 0, 33, 64)` |

## Flowers-Sheet.png

Source: [`Flowers-Sheet.png`](<./Flowers-Sheet.png>)

- **Canvas:** 384 × 96 pixels
- **Grid:** 6 columns × 1 rows of 64 × 96 slots
- **Cell count:** 6
- **Occupied slots:** 6
- **ID format:** `home.flowers.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `######` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.flowers.r00.c00` | `(0, 0, 64, 96)` | `(22, 3, 20, 43)` |
| `home.flowers.r00.c01` | `(64, 0, 64, 96)` | `(25, 23, 14, 23)` |
| `home.flowers.r00.c02` | `(128, 0, 64, 96)` | `(25, 22, 14, 24)` |
| `home.flowers.r00.c03` | `(192, 0, 64, 96)` | `(25, 23, 14, 22)` |
| `home.flowers.r00.c04` | `(256, 0, 64, 96)` | `(25, 22, 14, 23)` |
| `home.flowers.r00.c05` | `(320, 0, 64, 96)` | `(27, 28, 9, 17)` |

## Kitchen-Sheet.png

Source: [`Kitchen-Sheet.png`](<./Kitchen-Sheet.png>)

- **Canvas:** 1152 × 96 pixels
- **Grid:** 18 columns × 1 rows of 64 × 96 slots
- **Cell count:** 18
- **Occupied slots:** 14
- **ID format:** `home.kitchen.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `#.##.##.########.#` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.kitchen.r00.c00` | `(0, 0, 64, 96)` | `(36, 17, 24, 13)` |
| `home.kitchen.r00.c02` | `(128, 0, 64, 96)` | `(0, 21, 33, 34)` |
| `home.kitchen.r00.c03` | `(192, 0, 64, 96)` | `(31, 21, 33, 34)` |
| `home.kitchen.r00.c05` | `(320, 0, 64, 96)` | `(1, 15, 18, 20)` |
| `home.kitchen.r00.c06` | `(384, 0, 64, 96)` | `(34, 16, 16, 19)` |
| `home.kitchen.r00.c08` | `(512, 0, 64, 96)` | `(1, 25, 18, 10)` |
| `home.kitchen.r00.c09` | `(576, 0, 64, 96)` | `(31, 20, 33, 35)` |
| `home.kitchen.r00.c10` | `(640, 0, 64, 96)` | `(0, 20, 1, 35)` |
| `home.kitchen.r00.c11` | `(704, 0, 64, 96)` | `(0, 10, 32, 86)` |
| `home.kitchen.r00.c12` | `(768, 0, 64, 96)` | `(31, 21, 33, 34)` |
| `home.kitchen.r00.c13` | `(832, 0, 64, 96)` | `(0, 21, 64, 34)` |
| `home.kitchen.r00.c14` | `(896, 0, 64, 96)` | `(0, 29, 33, 22)` |
| `home.kitchen.r00.c15` | `(960, 0, 64, 96)` | `(36, 0, 24, 48)` |
| `home.kitchen.r00.c17` | `(1088, 0, 64, 96)` | `(4, 0, 24, 48)` |

## Kitchen1-Sheet.png

Source: [`Kitchen1-Sheet.png`](<./Kitchen1-Sheet.png>)

- **Canvas:** 576 × 96 pixels
- **Grid:** 9 columns × 1 rows of 64 × 96 slots
- **Cell count:** 9
- **Occupied slots:** 7
- **ID format:** `home.kitchen1.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `#.##.####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.kitchen1.r00.c00` | `(0, 0, 64, 96)` | `(42, 7, 12, 25)` |
| `home.kitchen1.r00.c02` | `(128, 0, 64, 96)` | `(10, 12, 12, 20)` |
| `home.kitchen1.r00.c03` | `(192, 0, 64, 96)` | `(40, 9, 14, 23)` |
| `home.kitchen1.r00.c05` | `(320, 0, 64, 96)` | `(10, 9, 14, 23)` |
| `home.kitchen1.r00.c06` | `(384, 0, 64, 96)` | `(25, 15, 39, 33)` |
| `home.kitchen1.r00.c07` | `(448, 0, 64, 96)` | `(0, 15, 64, 33)` |
| `home.kitchen1.r00.c08` | `(512, 0, 64, 96)` | `(0, 15, 39, 29)` |

## Lights-Sheet.png

Source: [`Lights-Sheet.png`](<./Lights-Sheet.png>)

- **Canvas:** 384 × 64 pixels
- **Grid:** 6 columns × 1 rows of 64 × 64 slots
- **Cell count:** 6
- **Occupied slots:** 6
- **ID format:** `home.lights.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `######` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.lights.r00.c00` | `(0, 0, 64, 64)` | `(24, 13, 16, 19)` |
| `home.lights.r00.c01` | `(64, 0, 64, 64)` | `(24, 13, 16, 19)` |
| `home.lights.r00.c02` | `(128, 0, 64, 64)` | `(24, 0, 16, 32)` |
| `home.lights.r00.c03` | `(192, 0, 64, 64)` | `(26, 9, 12, 17)` |
| `home.lights.r00.c04` | `(256, 0, 64, 64)` | `(26, 9, 12, 17)` |
| `home.lights.r00.c05` | `(320, 0, 64, 64)` | `(26, 9, 12, 17)` |

## LivingRoom-Sheet.png

Source: [`LivingRoom-Sheet.png`](<./LivingRoom-Sheet.png>)

- **Canvas:** 192 × 96 pixels
- **Grid:** 3 columns × 1 rows of 64 × 96 slots
- **Cell count:** 3
- **Occupied slots:** 3
- **ID format:** `home.livingroom.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `###` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.livingroom.r00.c00` | `(0, 0, 64, 96)` | `(25, 15, 39, 30)` |
| `home.livingroom.r00.c01` | `(64, 0, 64, 96)` | `(0, 10, 64, 35)` |
| `home.livingroom.r00.c02` | `(128, 0, 64, 96)` | `(0, 10, 33, 34)` |

## LivingRoom1-Sheet.png

Source: [`LivingRoom1-Sheet.png`](<./LivingRoom1-Sheet.png>)

- **Canvas:** 384 × 960 pixels
- **Grid:** 6 columns × 15 rows of 64 × 64 slots
- **Cell count:** 90
- **Occupied slots:** 75
- **ID format:** `home.livingroom1.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `####.#` |
| `r01` | 64 | `####.#` |
| `r02` | 128 | `####.#` |
| `r03` | 192 | `####.#` |
| `r04` | 256 | `####.#` |
| `r05` | 320 | `####.#` |
| `r06` | 384 | `####.#` |
| `r07` | 448 | `####.#` |
| `r08` | 512 | `####.#` |
| `r09` | 576 | `####.#` |
| `r10` | 640 | `####.#` |
| `r11` | 704 | `####.#` |
| `r12` | 768 | `####.#` |
| `r13` | 832 | `####.#` |
| `r14` | 896 | `####.#` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.livingroom1.r00.c00` | `(0, 0, 64, 64)` | `(24, 21, 40, 26)` |
| `home.livingroom1.r00.c01` | `(64, 0, 64, 64)` | `(0, 21, 64, 26)` |
| `home.livingroom1.r00.c02` | `(128, 0, 64, 64)` | `(0, 25, 40, 21)` |
| `home.livingroom1.r00.c03` | `(192, 0, 64, 64)` | `(41, 1, 15, 46)` |
| `home.livingroom1.r00.c05` | `(320, 0, 64, 64)` | `(9, 1, 15, 46)` |
| `home.livingroom1.r01.c00` | `(0, 64, 64, 64)` | `(24, 53, 40, 11)` |
| `home.livingroom1.r01.c01` | `(64, 64, 64, 64)` | `(0, 53, 64, 11)` |
| `home.livingroom1.r01.c02` | `(128, 64, 64, 64)` | `(0, 57, 40, 7)` |
| `home.livingroom1.r01.c03` | `(192, 64, 64, 64)` | `(41, 33, 15, 31)` |
| `home.livingroom1.r01.c05` | `(320, 64, 64, 64)` | `(9, 33, 15, 31)` |
| `home.livingroom1.r02.c00` | `(0, 128, 64, 64)` | `(24, 0, 40, 15)` |
| `home.livingroom1.r02.c01` | `(64, 128, 64, 64)` | `(0, 0, 64, 15)` |
| `home.livingroom1.r02.c02` | `(128, 128, 64, 64)` | `(0, 0, 40, 14)` |
| `home.livingroom1.r02.c03` | `(192, 128, 64, 64)` | `(41, 0, 15, 15)` |
| `home.livingroom1.r02.c05` | `(320, 128, 64, 64)` | `(9, 0, 15, 15)` |
| `home.livingroom1.r03.c00` | `(0, 192, 64, 64)` | `(24, 21, 40, 26)` |
| `home.livingroom1.r03.c01` | `(64, 192, 64, 64)` | `(0, 21, 64, 26)` |
| `home.livingroom1.r03.c02` | `(128, 192, 64, 64)` | `(0, 25, 40, 21)` |
| `home.livingroom1.r03.c03` | `(192, 192, 64, 64)` | `(41, 1, 15, 46)` |
| `home.livingroom1.r03.c05` | `(320, 192, 64, 64)` | `(9, 1, 15, 46)` |
| `home.livingroom1.r04.c00` | `(0, 256, 64, 64)` | `(24, 53, 40, 11)` |
| `home.livingroom1.r04.c01` | `(64, 256, 64, 64)` | `(0, 53, 64, 11)` |
| `home.livingroom1.r04.c02` | `(128, 256, 64, 64)` | `(0, 57, 40, 7)` |
| `home.livingroom1.r04.c03` | `(192, 256, 64, 64)` | `(41, 33, 15, 31)` |
| `home.livingroom1.r04.c05` | `(320, 256, 64, 64)` | `(9, 33, 15, 31)` |
| `home.livingroom1.r05.c00` | `(0, 320, 64, 64)` | `(24, 0, 40, 15)` |
| `home.livingroom1.r05.c01` | `(64, 320, 64, 64)` | `(0, 0, 64, 15)` |
| `home.livingroom1.r05.c02` | `(128, 320, 64, 64)` | `(0, 0, 40, 14)` |
| `home.livingroom1.r05.c03` | `(192, 320, 64, 64)` | `(41, 0, 15, 15)` |
| `home.livingroom1.r05.c05` | `(320, 320, 64, 64)` | `(9, 0, 15, 15)` |
| `home.livingroom1.r06.c00` | `(0, 384, 64, 64)` | `(24, 21, 40, 26)` |
| `home.livingroom1.r06.c01` | `(64, 384, 64, 64)` | `(0, 21, 64, 26)` |
| `home.livingroom1.r06.c02` | `(128, 384, 64, 64)` | `(0, 25, 40, 21)` |
| `home.livingroom1.r06.c03` | `(192, 384, 64, 64)` | `(41, 1, 15, 46)` |
| `home.livingroom1.r06.c05` | `(320, 384, 64, 64)` | `(9, 1, 15, 46)` |
| `home.livingroom1.r07.c00` | `(0, 448, 64, 64)` | `(24, 53, 40, 11)` |
| `home.livingroom1.r07.c01` | `(64, 448, 64, 64)` | `(0, 53, 64, 11)` |
| `home.livingroom1.r07.c02` | `(128, 448, 64, 64)` | `(0, 57, 40, 7)` |
| `home.livingroom1.r07.c03` | `(192, 448, 64, 64)` | `(41, 33, 15, 31)` |
| `home.livingroom1.r07.c05` | `(320, 448, 64, 64)` | `(9, 33, 15, 31)` |
| `home.livingroom1.r08.c00` | `(0, 512, 64, 64)` | `(24, 0, 40, 15)` |
| `home.livingroom1.r08.c01` | `(64, 512, 64, 64)` | `(0, 0, 64, 15)` |
| `home.livingroom1.r08.c02` | `(128, 512, 64, 64)` | `(0, 0, 40, 14)` |
| `home.livingroom1.r08.c03` | `(192, 512, 64, 64)` | `(41, 0, 15, 15)` |
| `home.livingroom1.r08.c05` | `(320, 512, 64, 64)` | `(9, 0, 15, 15)` |
| `home.livingroom1.r09.c00` | `(0, 576, 64, 64)` | `(24, 21, 40, 26)` |
| `home.livingroom1.r09.c01` | `(64, 576, 64, 64)` | `(0, 21, 64, 26)` |
| `home.livingroom1.r09.c02` | `(128, 576, 64, 64)` | `(0, 25, 40, 21)` |
| `home.livingroom1.r09.c03` | `(192, 576, 64, 64)` | `(41, 1, 15, 46)` |
| `home.livingroom1.r09.c05` | `(320, 576, 64, 64)` | `(9, 1, 15, 46)` |
| `home.livingroom1.r10.c00` | `(0, 640, 64, 64)` | `(24, 53, 40, 11)` |
| `home.livingroom1.r10.c01` | `(64, 640, 64, 64)` | `(0, 53, 64, 11)` |
| `home.livingroom1.r10.c02` | `(128, 640, 64, 64)` | `(0, 57, 40, 7)` |
| `home.livingroom1.r10.c03` | `(192, 640, 64, 64)` | `(41, 33, 15, 31)` |
| `home.livingroom1.r10.c05` | `(320, 640, 64, 64)` | `(9, 33, 15, 31)` |
| `home.livingroom1.r11.c00` | `(0, 704, 64, 64)` | `(24, 0, 40, 15)` |
| `home.livingroom1.r11.c01` | `(64, 704, 64, 64)` | `(0, 0, 64, 15)` |
| `home.livingroom1.r11.c02` | `(128, 704, 64, 64)` | `(0, 0, 40, 14)` |
| `home.livingroom1.r11.c03` | `(192, 704, 64, 64)` | `(41, 0, 15, 15)` |
| `home.livingroom1.r11.c05` | `(320, 704, 64, 64)` | `(9, 0, 15, 15)` |
| `home.livingroom1.r12.c00` | `(0, 768, 64, 64)` | `(24, 21, 40, 26)` |
| `home.livingroom1.r12.c01` | `(64, 768, 64, 64)` | `(0, 21, 64, 26)` |
| `home.livingroom1.r12.c02` | `(128, 768, 64, 64)` | `(0, 25, 40, 21)` |
| `home.livingroom1.r12.c03` | `(192, 768, 64, 64)` | `(41, 1, 15, 46)` |
| `home.livingroom1.r12.c05` | `(320, 768, 64, 64)` | `(9, 1, 15, 46)` |
| `home.livingroom1.r13.c00` | `(0, 832, 64, 64)` | `(24, 53, 40, 11)` |
| `home.livingroom1.r13.c01` | `(64, 832, 64, 64)` | `(0, 53, 64, 11)` |
| `home.livingroom1.r13.c02` | `(128, 832, 64, 64)` | `(0, 57, 40, 7)` |
| `home.livingroom1.r13.c03` | `(192, 832, 64, 64)` | `(41, 33, 15, 31)` |
| `home.livingroom1.r13.c05` | `(320, 832, 64, 64)` | `(9, 33, 15, 31)` |
| `home.livingroom1.r14.c00` | `(0, 896, 64, 64)` | `(24, 0, 40, 15)` |
| `home.livingroom1.r14.c01` | `(64, 896, 64, 64)` | `(0, 0, 64, 15)` |
| `home.livingroom1.r14.c02` | `(128, 896, 64, 64)` | `(0, 0, 40, 14)` |
| `home.livingroom1.r14.c03` | `(192, 896, 64, 64)` | `(41, 0, 15, 15)` |
| `home.livingroom1.r14.c05` | `(320, 896, 64, 64)` | `(9, 0, 15, 15)` |

## Miscellaneous-Sheet.png

Source: [`Miscellaneous-Sheet.png`](<./Miscellaneous-Sheet.png>)

- **Canvas:** 640 × 64 pixels
- **Grid:** 10 columns × 1 rows of 64 × 64 slots
- **Cell count:** 10
- **Occupied slots:** 10
- **ID format:** `home.miscellaneous.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `##########` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.miscellaneous.r00.c00` | `(0, 0, 64, 64)` | `(20, 17, 25, 33)` |
| `home.miscellaneous.r00.c01` | `(64, 0, 64, 64)` | `(20, 17, 25, 33)` |
| `home.miscellaneous.r00.c02` | `(128, 0, 64, 64)` | `(20, 17, 25, 33)` |
| `home.miscellaneous.r00.c03` | `(192, 0, 64, 64)` | `(20, 17, 25, 33)` |
| `home.miscellaneous.r00.c04` | `(256, 0, 64, 64)` | `(16, 29, 33, 26)` |
| `home.miscellaneous.r00.c05` | `(320, 0, 64, 64)` | `(26, 31, 12, 21)` |
| `home.miscellaneous.r00.c06` | `(384, 0, 64, 64)` | `(25, 31, 12, 21)` |
| `home.miscellaneous.r00.c07` | `(448, 0, 64, 64)` | `(27, 12, 11, 21)` |
| `home.miscellaneous.r00.c08` | `(512, 0, 64, 64)` | `(15, 17, 35, 39)` |
| `home.miscellaneous.r00.c09` | `(576, 0, 64, 64)` | `(15, 35, 35, 21)` |

## Paintings-Sheet.png

Source: [`Paintings-Sheet.png`](<./Paintings-Sheet.png>)

- **Canvas:** 320 × 32 pixels
- **Grid:** 5 columns × 1 rows of 64 × 32 slots
- **Cell count:** 5
- **Occupied slots:** 5
- **ID format:** `home.paintings.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `#####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.paintings.r00.c00` | `(0, 0, 64, 32)` | `(9, 7, 46, 17)` |
| `home.paintings.r00.c01` | `(64, 0, 64, 32)` | `(9, 4, 46, 24)` |
| `home.paintings.r00.c02` | `(128, 0, 64, 32)` | `(9, 2, 46, 26)` |
| `home.paintings.r00.c03` | `(192, 0, 64, 32)` | `(7, 7, 50, 21)` |
| `home.paintings.r00.c04` | `(256, 0, 64, 32)` | `(7, 7, 50, 21)` |

## Paintings1-Sheet.png

Source: [`Paintings1-Sheet.png`](<./Paintings1-Sheet.png>)

- **Canvas:** 160 × 32 pixels
- **Grid:** 2 columns × 1 rows of 64 × 32 slots
- **Cell count:** 2
- **Occupied slots:** 2
- **ID format:** `home.paintings1.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `##` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.paintings1.r00.c00` | `(0, 0, 64, 32)` | `(1, 0, 54, 32)` |
| `home.paintings1.r00.c01` | `(64, 0, 64, 32)` | `(9, 7, 46, 17)` |

## TV-Sheet.png

Source: [`TV-Sheet.png`](<./TV-Sheet.png>)

- **Canvas:** 256 × 96 pixels
- **Grid:** 4 columns × 1 rows of 64 × 96 slots
- **Cell count:** 4
- **Occupied slots:** 4
- **ID format:** `home.tv.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `####` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.tv.r00.c00` | `(0, 0, 64, 96)` | `(20, 0, 24, 29)` |
| `home.tv.r00.c01` | `(64, 0, 64, 96)` | `(20, 0, 24, 29)` |
| `home.tv.r00.c02` | `(128, 0, 64, 96)` | `(8, 2, 48, 27)` |
| `home.tv.r00.c03` | `(192, 0, 64, 96)` | `(8, 2, 48, 26)` |

## Windows-Sheet.png

Source: [`Windows-Sheet.png`](<./Windows-Sheet.png>)

- **Canvas:** 896 × 64 pixels
- **Grid:** 14 columns × 1 rows of 64 × 64 slots
- **Cell count:** 14
- **Occupied slots:** 14
- **ID format:** `home.windows.r<row>.c<column>`

### Slot occupancy

Rows and columns are zero-based. `#` contains non-transparent pixels; `.` is fully transparent.

| Row | Source `y` | Occupancy columns |
|---|---:|---|
| `r00` | 0 | `##############` |

### Occupied slot coordinates

| Asset ID | Source rectangle | Visible bbox within slot |
|---|---|---|
| `home.windows.r00.c00` | `(0, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c01` | `(64, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c02` | `(128, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c03` | `(192, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c04` | `(256, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c05` | `(320, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c06` | `(384, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c07` | `(448, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c08` | `(512, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c09` | `(576, 0, 64, 64)` | `(14, 15, 36, 40)` |
| `home.windows.r00.c10` | `(640, 0, 64, 64)` | `(0, 9, 64, 5)` |
| `home.windows.r00.c11` | `(704, 0, 64, 64)` | `(2, 9, 60, 44)` |
| `home.windows.r00.c12` | `(768, 0, 64, 64)` | `(0, 9, 64, 44)` |
| `home.windows.r00.c13` | `(832, 0, 64, 64)` | `(0, 9, 64, 44)` |

## TilesHouse.png

Source: [`TilesHouse.png`](<./TilesHouse.png>)

- **Canvas:** 512 × 512 pixels
- **Grid:** 32 columns × 32 rows
- **Atomic tile size:** 16 × 16 pixels
- **Total cells:** 1024
- **Non-empty cells:** 412
- **ID format:** `tiles-house.r<row>.c<column>`

This file is cataloged as an atomic 16×16 tile atlas. Larger floors, walls, borders, and room pieces should be assembled from adjacent tile IDs instead of being treated as one inferred furniture rectangle.

### Non-empty cell map

The map uses `#` for a non-empty 16×16 cell and `.` for a fully transparent cell.

| Row | Source `y` | Occupancy columns `c00`–`c31` |
|---|---:|---|
| `r00` | 0 | `.###.....................###.###` |
| `r01` | 16 | `.###........###..........###.###` |
| `r02` | 32 | `.###........###..........###.###` |
| `r03` | 48 | `.###.....................###.###` |
| `r04` | 64 | `#..###.###.####.###.###.........` |
| `r05` | 80 | `#..###.###.####.###.###..###.###` |
| `r06` | 96 | `#..###.###.####.###.###..###.###` |
| `r07` | 112 | `#..###.###.####.###.###..###.###` |
| `r08` | 128 | `#.##..##......#.###.###..###.###` |
| `r09` | 144 | `#.##..##.#....#.###.###.........` |
| `r10` | 160 | `......................#..###.###` |
| `r11` | 176 | `..##..##...####.#.###.#..###.###` |
| `r12` | 192 | `.###..##.#...............###.###` |
| `r13` | 208 | `...........#..#...##.....###.###` |
| `r14` | 224 | `.###...###.#..#...##............` |
| `r15` | 240 | `...##.##..........##.###.###.###` |
| `r16` | 256 | `#....#....#.......##.###.###.###` |
| `r17` | 272 | `....###...........##.###.###.###` |
| `r18` | 288 | `#..##.##..#...###.##.###.###.###` |
| `r19` | 304 | `.....#........###...............` |
| `r20` | 320 | `#.........#.#######..#.........#` |
| `r21` | 336 | `#####.#####.#######..#####.#####` |
| `r22` | 352 | `..#.....#.....###......#.....#..` |
| `r23` | 368 | `#...###...#...###..#.#...###...#` |
| `r24` | 384 | `................................` |
| `r25` | 400 | `.####..####..#...#.####..####..#` |
| `r26` | 416 | `....####....#.....#...####......` |
| `r27` | 432 | `....#####.#.........#.#####.....` |
| `r28` | 448 | `....####..#####.#####.####......` |
| `r29` | 464 | `....####....#.....#...####......` |
| `r30` | 480 | `................................` |
| `r31` | 496 | `................................` |

### Non-empty tile coordinates

| Tile ID | Source rectangle |
|---|---|
| `tiles-house.r00.c01` | `(16, 0, 16, 16)` |
| `tiles-house.r00.c02` | `(32, 0, 16, 16)` |
| `tiles-house.r00.c03` | `(48, 0, 16, 16)` |
| `tiles-house.r00.c25` | `(400, 0, 16, 16)` |
| `tiles-house.r00.c26` | `(416, 0, 16, 16)` |
| `tiles-house.r00.c27` | `(432, 0, 16, 16)` |
| `tiles-house.r00.c29` | `(464, 0, 16, 16)` |
| `tiles-house.r00.c30` | `(480, 0, 16, 16)` |
| `tiles-house.r00.c31` | `(496, 0, 16, 16)` |
| `tiles-house.r01.c01` | `(16, 16, 16, 16)` |
| `tiles-house.r01.c02` | `(32, 16, 16, 16)` |
| `tiles-house.r01.c03` | `(48, 16, 16, 16)` |
| `tiles-house.r01.c12` | `(192, 16, 16, 16)` |
| `tiles-house.r01.c13` | `(208, 16, 16, 16)` |
| `tiles-house.r01.c14` | `(224, 16, 16, 16)` |
| `tiles-house.r01.c25` | `(400, 16, 16, 16)` |
| `tiles-house.r01.c26` | `(416, 16, 16, 16)` |
| `tiles-house.r01.c27` | `(432, 16, 16, 16)` |
| `tiles-house.r01.c29` | `(464, 16, 16, 16)` |
| `tiles-house.r01.c30` | `(480, 16, 16, 16)` |
| `tiles-house.r01.c31` | `(496, 16, 16, 16)` |
| `tiles-house.r02.c01` | `(16, 32, 16, 16)` |
| `tiles-house.r02.c02` | `(32, 32, 16, 16)` |
| `tiles-house.r02.c03` | `(48, 32, 16, 16)` |
| `tiles-house.r02.c12` | `(192, 32, 16, 16)` |
| `tiles-house.r02.c13` | `(208, 32, 16, 16)` |
| `tiles-house.r02.c14` | `(224, 32, 16, 16)` |
| `tiles-house.r02.c25` | `(400, 32, 16, 16)` |
| `tiles-house.r02.c26` | `(416, 32, 16, 16)` |
| `tiles-house.r02.c27` | `(432, 32, 16, 16)` |
| `tiles-house.r02.c29` | `(464, 32, 16, 16)` |
| `tiles-house.r02.c30` | `(480, 32, 16, 16)` |
| `tiles-house.r02.c31` | `(496, 32, 16, 16)` |
| `tiles-house.r03.c01` | `(16, 48, 16, 16)` |
| `tiles-house.r03.c02` | `(32, 48, 16, 16)` |
| `tiles-house.r03.c03` | `(48, 48, 16, 16)` |
| `tiles-house.r03.c25` | `(400, 48, 16, 16)` |
| `tiles-house.r03.c26` | `(416, 48, 16, 16)` |
| `tiles-house.r03.c27` | `(432, 48, 16, 16)` |
| `tiles-house.r03.c29` | `(464, 48, 16, 16)` |
| `tiles-house.r03.c30` | `(480, 48, 16, 16)` |
| `tiles-house.r03.c31` | `(496, 48, 16, 16)` |
| `tiles-house.r04.c00` | `(0, 64, 16, 16)` |
| `tiles-house.r04.c03` | `(48, 64, 16, 16)` |
| `tiles-house.r04.c04` | `(64, 64, 16, 16)` |
| `tiles-house.r04.c05` | `(80, 64, 16, 16)` |
| `tiles-house.r04.c07` | `(112, 64, 16, 16)` |
| `tiles-house.r04.c08` | `(128, 64, 16, 16)` |
| `tiles-house.r04.c09` | `(144, 64, 16, 16)` |
| `tiles-house.r04.c11` | `(176, 64, 16, 16)` |
| `tiles-house.r04.c12` | `(192, 64, 16, 16)` |
| `tiles-house.r04.c13` | `(208, 64, 16, 16)` |
| `tiles-house.r04.c14` | `(224, 64, 16, 16)` |
| `tiles-house.r04.c16` | `(256, 64, 16, 16)` |
| `tiles-house.r04.c17` | `(272, 64, 16, 16)` |
| `tiles-house.r04.c18` | `(288, 64, 16, 16)` |
| `tiles-house.r04.c20` | `(320, 64, 16, 16)` |
| `tiles-house.r04.c21` | `(336, 64, 16, 16)` |
| `tiles-house.r04.c22` | `(352, 64, 16, 16)` |
| `tiles-house.r05.c00` | `(0, 80, 16, 16)` |
| `tiles-house.r05.c03` | `(48, 80, 16, 16)` |
| `tiles-house.r05.c04` | `(64, 80, 16, 16)` |
| `tiles-house.r05.c05` | `(80, 80, 16, 16)` |
| `tiles-house.r05.c07` | `(112, 80, 16, 16)` |
| `tiles-house.r05.c08` | `(128, 80, 16, 16)` |
| `tiles-house.r05.c09` | `(144, 80, 16, 16)` |
| `tiles-house.r05.c11` | `(176, 80, 16, 16)` |
| `tiles-house.r05.c12` | `(192, 80, 16, 16)` |
| `tiles-house.r05.c13` | `(208, 80, 16, 16)` |
| `tiles-house.r05.c14` | `(224, 80, 16, 16)` |
| `tiles-house.r05.c16` | `(256, 80, 16, 16)` |
| `tiles-house.r05.c17` | `(272, 80, 16, 16)` |
| `tiles-house.r05.c18` | `(288, 80, 16, 16)` |
| `tiles-house.r05.c20` | `(320, 80, 16, 16)` |
| `tiles-house.r05.c21` | `(336, 80, 16, 16)` |
| `tiles-house.r05.c22` | `(352, 80, 16, 16)` |
| `tiles-house.r05.c25` | `(400, 80, 16, 16)` |
| `tiles-house.r05.c26` | `(416, 80, 16, 16)` |
| `tiles-house.r05.c27` | `(432, 80, 16, 16)` |
| `tiles-house.r05.c29` | `(464, 80, 16, 16)` |
| `tiles-house.r05.c30` | `(480, 80, 16, 16)` |
| `tiles-house.r05.c31` | `(496, 80, 16, 16)` |
| `tiles-house.r06.c00` | `(0, 96, 16, 16)` |
| `tiles-house.r06.c03` | `(48, 96, 16, 16)` |
| `tiles-house.r06.c04` | `(64, 96, 16, 16)` |
| `tiles-house.r06.c05` | `(80, 96, 16, 16)` |
| `tiles-house.r06.c07` | `(112, 96, 16, 16)` |
| `tiles-house.r06.c08` | `(128, 96, 16, 16)` |
| `tiles-house.r06.c09` | `(144, 96, 16, 16)` |
| `tiles-house.r06.c11` | `(176, 96, 16, 16)` |
| `tiles-house.r06.c12` | `(192, 96, 16, 16)` |
| `tiles-house.r06.c13` | `(208, 96, 16, 16)` |
| `tiles-house.r06.c14` | `(224, 96, 16, 16)` |
| `tiles-house.r06.c16` | `(256, 96, 16, 16)` |
| `tiles-house.r06.c17` | `(272, 96, 16, 16)` |
| `tiles-house.r06.c18` | `(288, 96, 16, 16)` |
| `tiles-house.r06.c20` | `(320, 96, 16, 16)` |
| `tiles-house.r06.c21` | `(336, 96, 16, 16)` |
| `tiles-house.r06.c22` | `(352, 96, 16, 16)` |
| `tiles-house.r06.c25` | `(400, 96, 16, 16)` |
| `tiles-house.r06.c26` | `(416, 96, 16, 16)` |
| `tiles-house.r06.c27` | `(432, 96, 16, 16)` |
| `tiles-house.r06.c29` | `(464, 96, 16, 16)` |
| `tiles-house.r06.c30` | `(480, 96, 16, 16)` |
| `tiles-house.r06.c31` | `(496, 96, 16, 16)` |
| `tiles-house.r07.c00` | `(0, 112, 16, 16)` |
| `tiles-house.r07.c03` | `(48, 112, 16, 16)` |
| `tiles-house.r07.c04` | `(64, 112, 16, 16)` |
| `tiles-house.r07.c05` | `(80, 112, 16, 16)` |
| `tiles-house.r07.c07` | `(112, 112, 16, 16)` |
| `tiles-house.r07.c08` | `(128, 112, 16, 16)` |
| `tiles-house.r07.c09` | `(144, 112, 16, 16)` |
| `tiles-house.r07.c11` | `(176, 112, 16, 16)` |
| `tiles-house.r07.c12` | `(192, 112, 16, 16)` |
| `tiles-house.r07.c13` | `(208, 112, 16, 16)` |
| `tiles-house.r07.c14` | `(224, 112, 16, 16)` |
| `tiles-house.r07.c16` | `(256, 112, 16, 16)` |
| `tiles-house.r07.c17` | `(272, 112, 16, 16)` |
| `tiles-house.r07.c18` | `(288, 112, 16, 16)` |
| `tiles-house.r07.c20` | `(320, 112, 16, 16)` |
| `tiles-house.r07.c21` | `(336, 112, 16, 16)` |
| `tiles-house.r07.c22` | `(352, 112, 16, 16)` |
| `tiles-house.r07.c25` | `(400, 112, 16, 16)` |
| `tiles-house.r07.c26` | `(416, 112, 16, 16)` |
| `tiles-house.r07.c27` | `(432, 112, 16, 16)` |
| `tiles-house.r07.c29` | `(464, 112, 16, 16)` |
| `tiles-house.r07.c30` | `(480, 112, 16, 16)` |
| `tiles-house.r07.c31` | `(496, 112, 16, 16)` |
| `tiles-house.r08.c00` | `(0, 128, 16, 16)` |
| `tiles-house.r08.c02` | `(32, 128, 16, 16)` |
| `tiles-house.r08.c03` | `(48, 128, 16, 16)` |
| `tiles-house.r08.c06` | `(96, 128, 16, 16)` |
| `tiles-house.r08.c07` | `(112, 128, 16, 16)` |
| `tiles-house.r08.c14` | `(224, 128, 16, 16)` |
| `tiles-house.r08.c16` | `(256, 128, 16, 16)` |
| `tiles-house.r08.c17` | `(272, 128, 16, 16)` |
| `tiles-house.r08.c18` | `(288, 128, 16, 16)` |
| `tiles-house.r08.c20` | `(320, 128, 16, 16)` |
| `tiles-house.r08.c21` | `(336, 128, 16, 16)` |
| `tiles-house.r08.c22` | `(352, 128, 16, 16)` |
| `tiles-house.r08.c25` | `(400, 128, 16, 16)` |
| `tiles-house.r08.c26` | `(416, 128, 16, 16)` |
| `tiles-house.r08.c27` | `(432, 128, 16, 16)` |
| `tiles-house.r08.c29` | `(464, 128, 16, 16)` |
| `tiles-house.r08.c30` | `(480, 128, 16, 16)` |
| `tiles-house.r08.c31` | `(496, 128, 16, 16)` |
| `tiles-house.r09.c00` | `(0, 144, 16, 16)` |
| `tiles-house.r09.c02` | `(32, 144, 16, 16)` |
| `tiles-house.r09.c03` | `(48, 144, 16, 16)` |
| `tiles-house.r09.c06` | `(96, 144, 16, 16)` |
| `tiles-house.r09.c07` | `(112, 144, 16, 16)` |
| `tiles-house.r09.c09` | `(144, 144, 16, 16)` |
| `tiles-house.r09.c14` | `(224, 144, 16, 16)` |
| `tiles-house.r09.c16` | `(256, 144, 16, 16)` |
| `tiles-house.r09.c17` | `(272, 144, 16, 16)` |
| `tiles-house.r09.c18` | `(288, 144, 16, 16)` |
| `tiles-house.r09.c20` | `(320, 144, 16, 16)` |
| `tiles-house.r09.c21` | `(336, 144, 16, 16)` |
| `tiles-house.r09.c22` | `(352, 144, 16, 16)` |
| `tiles-house.r10.c22` | `(352, 160, 16, 16)` |
| `tiles-house.r10.c25` | `(400, 160, 16, 16)` |
| `tiles-house.r10.c26` | `(416, 160, 16, 16)` |
| `tiles-house.r10.c27` | `(432, 160, 16, 16)` |
| `tiles-house.r10.c29` | `(464, 160, 16, 16)` |
| `tiles-house.r10.c30` | `(480, 160, 16, 16)` |
| `tiles-house.r10.c31` | `(496, 160, 16, 16)` |
| `tiles-house.r11.c02` | `(32, 176, 16, 16)` |
| `tiles-house.r11.c03` | `(48, 176, 16, 16)` |
| `tiles-house.r11.c06` | `(96, 176, 16, 16)` |
| `tiles-house.r11.c07` | `(112, 176, 16, 16)` |
| `tiles-house.r11.c11` | `(176, 176, 16, 16)` |
| `tiles-house.r11.c12` | `(192, 176, 16, 16)` |
| `tiles-house.r11.c13` | `(208, 176, 16, 16)` |
| `tiles-house.r11.c14` | `(224, 176, 16, 16)` |
| `tiles-house.r11.c16` | `(256, 176, 16, 16)` |
| `tiles-house.r11.c18` | `(288, 176, 16, 16)` |
| `tiles-house.r11.c19` | `(304, 176, 16, 16)` |
| `tiles-house.r11.c20` | `(320, 176, 16, 16)` |
| `tiles-house.r11.c22` | `(352, 176, 16, 16)` |
| `tiles-house.r11.c25` | `(400, 176, 16, 16)` |
| `tiles-house.r11.c26` | `(416, 176, 16, 16)` |
| `tiles-house.r11.c27` | `(432, 176, 16, 16)` |
| `tiles-house.r11.c29` | `(464, 176, 16, 16)` |
| `tiles-house.r11.c30` | `(480, 176, 16, 16)` |
| `tiles-house.r11.c31` | `(496, 176, 16, 16)` |
| `tiles-house.r12.c01` | `(16, 192, 16, 16)` |
| `tiles-house.r12.c02` | `(32, 192, 16, 16)` |
| `tiles-house.r12.c03` | `(48, 192, 16, 16)` |
| `tiles-house.r12.c06` | `(96, 192, 16, 16)` |
| `tiles-house.r12.c07` | `(112, 192, 16, 16)` |
| `tiles-house.r12.c09` | `(144, 192, 16, 16)` |
| `tiles-house.r12.c25` | `(400, 192, 16, 16)` |
| `tiles-house.r12.c26` | `(416, 192, 16, 16)` |
| `tiles-house.r12.c27` | `(432, 192, 16, 16)` |
| `tiles-house.r12.c29` | `(464, 192, 16, 16)` |
| `tiles-house.r12.c30` | `(480, 192, 16, 16)` |
| `tiles-house.r12.c31` | `(496, 192, 16, 16)` |
| `tiles-house.r13.c11` | `(176, 208, 16, 16)` |
| `tiles-house.r13.c14` | `(224, 208, 16, 16)` |
| `tiles-house.r13.c18` | `(288, 208, 16, 16)` |
| `tiles-house.r13.c19` | `(304, 208, 16, 16)` |
| `tiles-house.r13.c25` | `(400, 208, 16, 16)` |
| `tiles-house.r13.c26` | `(416, 208, 16, 16)` |
| `tiles-house.r13.c27` | `(432, 208, 16, 16)` |
| `tiles-house.r13.c29` | `(464, 208, 16, 16)` |
| `tiles-house.r13.c30` | `(480, 208, 16, 16)` |
| `tiles-house.r13.c31` | `(496, 208, 16, 16)` |
| `tiles-house.r14.c01` | `(16, 224, 16, 16)` |
| `tiles-house.r14.c02` | `(32, 224, 16, 16)` |
| `tiles-house.r14.c03` | `(48, 224, 16, 16)` |
| `tiles-house.r14.c07` | `(112, 224, 16, 16)` |
| `tiles-house.r14.c08` | `(128, 224, 16, 16)` |
| `tiles-house.r14.c09` | `(144, 224, 16, 16)` |
| `tiles-house.r14.c11` | `(176, 224, 16, 16)` |
| `tiles-house.r14.c14` | `(224, 224, 16, 16)` |
| `tiles-house.r14.c18` | `(288, 224, 16, 16)` |
| `tiles-house.r14.c19` | `(304, 224, 16, 16)` |
| `tiles-house.r15.c03` | `(48, 240, 16, 16)` |
| `tiles-house.r15.c04` | `(64, 240, 16, 16)` |
| `tiles-house.r15.c06` | `(96, 240, 16, 16)` |
| `tiles-house.r15.c07` | `(112, 240, 16, 16)` |
| `tiles-house.r15.c18` | `(288, 240, 16, 16)` |
| `tiles-house.r15.c19` | `(304, 240, 16, 16)` |
| `tiles-house.r15.c21` | `(336, 240, 16, 16)` |
| `tiles-house.r15.c22` | `(352, 240, 16, 16)` |
| `tiles-house.r15.c23` | `(368, 240, 16, 16)` |
| `tiles-house.r15.c25` | `(400, 240, 16, 16)` |
| `tiles-house.r15.c26` | `(416, 240, 16, 16)` |
| `tiles-house.r15.c27` | `(432, 240, 16, 16)` |
| `tiles-house.r15.c29` | `(464, 240, 16, 16)` |
| `tiles-house.r15.c30` | `(480, 240, 16, 16)` |
| `tiles-house.r15.c31` | `(496, 240, 16, 16)` |
| `tiles-house.r16.c00` | `(0, 256, 16, 16)` |
| `tiles-house.r16.c05` | `(80, 256, 16, 16)` |
| `tiles-house.r16.c10` | `(160, 256, 16, 16)` |
| `tiles-house.r16.c18` | `(288, 256, 16, 16)` |
| `tiles-house.r16.c19` | `(304, 256, 16, 16)` |
| `tiles-house.r16.c21` | `(336, 256, 16, 16)` |
| `tiles-house.r16.c22` | `(352, 256, 16, 16)` |
| `tiles-house.r16.c23` | `(368, 256, 16, 16)` |
| `tiles-house.r16.c25` | `(400, 256, 16, 16)` |
| `tiles-house.r16.c26` | `(416, 256, 16, 16)` |
| `tiles-house.r16.c27` | `(432, 256, 16, 16)` |
| `tiles-house.r16.c29` | `(464, 256, 16, 16)` |
| `tiles-house.r16.c30` | `(480, 256, 16, 16)` |
| `tiles-house.r16.c31` | `(496, 256, 16, 16)` |
| `tiles-house.r17.c04` | `(64, 272, 16, 16)` |
| `tiles-house.r17.c05` | `(80, 272, 16, 16)` |
| `tiles-house.r17.c06` | `(96, 272, 16, 16)` |
| `tiles-house.r17.c18` | `(288, 272, 16, 16)` |
| `tiles-house.r17.c19` | `(304, 272, 16, 16)` |
| `tiles-house.r17.c21` | `(336, 272, 16, 16)` |
| `tiles-house.r17.c22` | `(352, 272, 16, 16)` |
| `tiles-house.r17.c23` | `(368, 272, 16, 16)` |
| `tiles-house.r17.c25` | `(400, 272, 16, 16)` |
| `tiles-house.r17.c26` | `(416, 272, 16, 16)` |
| `tiles-house.r17.c27` | `(432, 272, 16, 16)` |
| `tiles-house.r17.c29` | `(464, 272, 16, 16)` |
| `tiles-house.r17.c30` | `(480, 272, 16, 16)` |
| `tiles-house.r17.c31` | `(496, 272, 16, 16)` |
| `tiles-house.r18.c00` | `(0, 288, 16, 16)` |
| `tiles-house.r18.c03` | `(48, 288, 16, 16)` |
| `tiles-house.r18.c04` | `(64, 288, 16, 16)` |
| `tiles-house.r18.c06` | `(96, 288, 16, 16)` |
| `tiles-house.r18.c07` | `(112, 288, 16, 16)` |
| `tiles-house.r18.c10` | `(160, 288, 16, 16)` |
| `tiles-house.r18.c14` | `(224, 288, 16, 16)` |
| `tiles-house.r18.c15` | `(240, 288, 16, 16)` |
| `tiles-house.r18.c16` | `(256, 288, 16, 16)` |
| `tiles-house.r18.c18` | `(288, 288, 16, 16)` |
| `tiles-house.r18.c19` | `(304, 288, 16, 16)` |
| `tiles-house.r18.c21` | `(336, 288, 16, 16)` |
| `tiles-house.r18.c22` | `(352, 288, 16, 16)` |
| `tiles-house.r18.c23` | `(368, 288, 16, 16)` |
| `tiles-house.r18.c25` | `(400, 288, 16, 16)` |
| `tiles-house.r18.c26` | `(416, 288, 16, 16)` |
| `tiles-house.r18.c27` | `(432, 288, 16, 16)` |
| `tiles-house.r18.c29` | `(464, 288, 16, 16)` |
| `tiles-house.r18.c30` | `(480, 288, 16, 16)` |
| `tiles-house.r18.c31` | `(496, 288, 16, 16)` |
| `tiles-house.r19.c05` | `(80, 304, 16, 16)` |
| `tiles-house.r19.c14` | `(224, 304, 16, 16)` |
| `tiles-house.r19.c15` | `(240, 304, 16, 16)` |
| `tiles-house.r19.c16` | `(256, 304, 16, 16)` |
| `tiles-house.r20.c00` | `(0, 320, 16, 16)` |
| `tiles-house.r20.c10` | `(160, 320, 16, 16)` |
| `tiles-house.r20.c12` | `(192, 320, 16, 16)` |
| `tiles-house.r20.c13` | `(208, 320, 16, 16)` |
| `tiles-house.r20.c14` | `(224, 320, 16, 16)` |
| `tiles-house.r20.c15` | `(240, 320, 16, 16)` |
| `tiles-house.r20.c16` | `(256, 320, 16, 16)` |
| `tiles-house.r20.c17` | `(272, 320, 16, 16)` |
| `tiles-house.r20.c18` | `(288, 320, 16, 16)` |
| `tiles-house.r20.c21` | `(336, 320, 16, 16)` |
| `tiles-house.r20.c31` | `(496, 320, 16, 16)` |
| `tiles-house.r21.c00` | `(0, 336, 16, 16)` |
| `tiles-house.r21.c01` | `(16, 336, 16, 16)` |
| `tiles-house.r21.c02` | `(32, 336, 16, 16)` |
| `tiles-house.r21.c03` | `(48, 336, 16, 16)` |
| `tiles-house.r21.c04` | `(64, 336, 16, 16)` |
| `tiles-house.r21.c06` | `(96, 336, 16, 16)` |
| `tiles-house.r21.c07` | `(112, 336, 16, 16)` |
| `tiles-house.r21.c08` | `(128, 336, 16, 16)` |
| `tiles-house.r21.c09` | `(144, 336, 16, 16)` |
| `tiles-house.r21.c10` | `(160, 336, 16, 16)` |
| `tiles-house.r21.c12` | `(192, 336, 16, 16)` |
| `tiles-house.r21.c13` | `(208, 336, 16, 16)` |
| `tiles-house.r21.c14` | `(224, 336, 16, 16)` |
| `tiles-house.r21.c15` | `(240, 336, 16, 16)` |
| `tiles-house.r21.c16` | `(256, 336, 16, 16)` |
| `tiles-house.r21.c17` | `(272, 336, 16, 16)` |
| `tiles-house.r21.c18` | `(288, 336, 16, 16)` |
| `tiles-house.r21.c21` | `(336, 336, 16, 16)` |
| `tiles-house.r21.c22` | `(352, 336, 16, 16)` |
| `tiles-house.r21.c23` | `(368, 336, 16, 16)` |
| `tiles-house.r21.c24` | `(384, 336, 16, 16)` |
| `tiles-house.r21.c25` | `(400, 336, 16, 16)` |
| `tiles-house.r21.c27` | `(432, 336, 16, 16)` |
| `tiles-house.r21.c28` | `(448, 336, 16, 16)` |
| `tiles-house.r21.c29` | `(464, 336, 16, 16)` |
| `tiles-house.r21.c30` | `(480, 336, 16, 16)` |
| `tiles-house.r21.c31` | `(496, 336, 16, 16)` |
| `tiles-house.r22.c02` | `(32, 352, 16, 16)` |
| `tiles-house.r22.c08` | `(128, 352, 16, 16)` |
| `tiles-house.r22.c14` | `(224, 352, 16, 16)` |
| `tiles-house.r22.c15` | `(240, 352, 16, 16)` |
| `tiles-house.r22.c16` | `(256, 352, 16, 16)` |
| `tiles-house.r22.c23` | `(368, 352, 16, 16)` |
| `tiles-house.r22.c29` | `(464, 352, 16, 16)` |
| `tiles-house.r23.c00` | `(0, 368, 16, 16)` |
| `tiles-house.r23.c04` | `(64, 368, 16, 16)` |
| `tiles-house.r23.c05` | `(80, 368, 16, 16)` |
| `tiles-house.r23.c06` | `(96, 368, 16, 16)` |
| `tiles-house.r23.c10` | `(160, 368, 16, 16)` |
| `tiles-house.r23.c14` | `(224, 368, 16, 16)` |
| `tiles-house.r23.c15` | `(240, 368, 16, 16)` |
| `tiles-house.r23.c16` | `(256, 368, 16, 16)` |
| `tiles-house.r23.c19` | `(304, 368, 16, 16)` |
| `tiles-house.r23.c21` | `(336, 368, 16, 16)` |
| `tiles-house.r23.c25` | `(400, 368, 16, 16)` |
| `tiles-house.r23.c26` | `(416, 368, 16, 16)` |
| `tiles-house.r23.c27` | `(432, 368, 16, 16)` |
| `tiles-house.r23.c31` | `(496, 368, 16, 16)` |
| `tiles-house.r25.c01` | `(16, 400, 16, 16)` |
| `tiles-house.r25.c02` | `(32, 400, 16, 16)` |
| `tiles-house.r25.c03` | `(48, 400, 16, 16)` |
| `tiles-house.r25.c04` | `(64, 400, 16, 16)` |
| `tiles-house.r25.c07` | `(112, 400, 16, 16)` |
| `tiles-house.r25.c08` | `(128, 400, 16, 16)` |
| `tiles-house.r25.c09` | `(144, 400, 16, 16)` |
| `tiles-house.r25.c10` | `(160, 400, 16, 16)` |
| `tiles-house.r25.c13` | `(208, 400, 16, 16)` |
| `tiles-house.r25.c17` | `(272, 400, 16, 16)` |
| `tiles-house.r25.c19` | `(304, 400, 16, 16)` |
| `tiles-house.r25.c20` | `(320, 400, 16, 16)` |
| `tiles-house.r25.c21` | `(336, 400, 16, 16)` |
| `tiles-house.r25.c22` | `(352, 400, 16, 16)` |
| `tiles-house.r25.c25` | `(400, 400, 16, 16)` |
| `tiles-house.r25.c26` | `(416, 400, 16, 16)` |
| `tiles-house.r25.c27` | `(432, 400, 16, 16)` |
| `tiles-house.r25.c28` | `(448, 400, 16, 16)` |
| `tiles-house.r25.c31` | `(496, 400, 16, 16)` |
| `tiles-house.r26.c04` | `(64, 416, 16, 16)` |
| `tiles-house.r26.c05` | `(80, 416, 16, 16)` |
| `tiles-house.r26.c06` | `(96, 416, 16, 16)` |
| `tiles-house.r26.c07` | `(112, 416, 16, 16)` |
| `tiles-house.r26.c12` | `(192, 416, 16, 16)` |
| `tiles-house.r26.c18` | `(288, 416, 16, 16)` |
| `tiles-house.r26.c22` | `(352, 416, 16, 16)` |
| `tiles-house.r26.c23` | `(368, 416, 16, 16)` |
| `tiles-house.r26.c24` | `(384, 416, 16, 16)` |
| `tiles-house.r26.c25` | `(400, 416, 16, 16)` |
| `tiles-house.r27.c04` | `(64, 432, 16, 16)` |
| `tiles-house.r27.c05` | `(80, 432, 16, 16)` |
| `tiles-house.r27.c06` | `(96, 432, 16, 16)` |
| `tiles-house.r27.c07` | `(112, 432, 16, 16)` |
| `tiles-house.r27.c08` | `(128, 432, 16, 16)` |
| `tiles-house.r27.c10` | `(160, 432, 16, 16)` |
| `tiles-house.r27.c20` | `(320, 432, 16, 16)` |
| `tiles-house.r27.c22` | `(352, 432, 16, 16)` |
| `tiles-house.r27.c23` | `(368, 432, 16, 16)` |
| `tiles-house.r27.c24` | `(384, 432, 16, 16)` |
| `tiles-house.r27.c25` | `(400, 432, 16, 16)` |
| `tiles-house.r27.c26` | `(416, 432, 16, 16)` |
| `tiles-house.r28.c04` | `(64, 448, 16, 16)` |
| `tiles-house.r28.c05` | `(80, 448, 16, 16)` |
| `tiles-house.r28.c06` | `(96, 448, 16, 16)` |
| `tiles-house.r28.c07` | `(112, 448, 16, 16)` |
| `tiles-house.r28.c10` | `(160, 448, 16, 16)` |
| `tiles-house.r28.c11` | `(176, 448, 16, 16)` |
| `tiles-house.r28.c12` | `(192, 448, 16, 16)` |
| `tiles-house.r28.c13` | `(208, 448, 16, 16)` |
| `tiles-house.r28.c14` | `(224, 448, 16, 16)` |
| `tiles-house.r28.c16` | `(256, 448, 16, 16)` |
| `tiles-house.r28.c17` | `(272, 448, 16, 16)` |
| `tiles-house.r28.c18` | `(288, 448, 16, 16)` |
| `tiles-house.r28.c19` | `(304, 448, 16, 16)` |
| `tiles-house.r28.c20` | `(320, 448, 16, 16)` |
| `tiles-house.r28.c22` | `(352, 448, 16, 16)` |
| `tiles-house.r28.c23` | `(368, 448, 16, 16)` |
| `tiles-house.r28.c24` | `(384, 448, 16, 16)` |
| `tiles-house.r28.c25` | `(400, 448, 16, 16)` |
| `tiles-house.r29.c04` | `(64, 464, 16, 16)` |
| `tiles-house.r29.c05` | `(80, 464, 16, 16)` |
| `tiles-house.r29.c06` | `(96, 464, 16, 16)` |
| `tiles-house.r29.c07` | `(112, 464, 16, 16)` |
| `tiles-house.r29.c12` | `(192, 464, 16, 16)` |
| `tiles-house.r29.c18` | `(288, 464, 16, 16)` |
| `tiles-house.r29.c22` | `(352, 464, 16, 16)` |
| `tiles-house.r29.c23` | `(368, 464, 16, 16)` |
| `tiles-house.r29.c24` | `(384, 464, 16, 16)` |
| `tiles-house.r29.c25` | `(400, 464, 16, 16)` |

## Lookup examples

- `home.beds.r02.c03` → crop `(192, 128, 64, 64)` from `Beds-Sheet.png`.
- `home.chimney.r00.c02` → crop `(128, 0, 64, 48)` from `Chimney-Sheet.png`.
- `home.livingroom1.r07.c05` → crop `(320, 448, 64, 64)` from `LivingRoom1-Sheet.png`.
- `tiles-house.r04.c03` → crop `(48, 64, 16, 16)` from `TilesHouse.png`.

## Verification notes

- All furniture sheets divide exactly into their documented 64-pixel-wide slots; slot heights range from 32 to 128 pixels.
- `LivingRoom1-Sheet.png` is a 6 × 15 grid of 64 × 64 slots, with 75 occupied slots.
- `TilesHouse.png` divides exactly into a 32 × 32 grid of 16 × 16 cells; 412 cells contain non-transparent pixels.

