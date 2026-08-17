# Hospital Interior Asset Catalog

Coordinate catalog for every PNG in `Interior/Hospital/`.

## Coordinate conventions

Interior assets do not share one universal sprite size. Each source file below declares its own authoritative slot or tile size. Coordinates are source-image pixels with a top-left origin `(0, 0)` and rectangles written as `(x, y, width, height)` with exclusive right and bottom edges.

Visible-pixel bounds are included for furniture sheets to distinguish the usable artwork from transparent padding. They are measured relative to the listed source slot and are informational; the full source slot remains the default crop.

## File inventory

| File | Canvas | Authoritative unit | Count | Catalog approach |
|---|---:|---:|---:|---|
| [`BedHospital-Sheet.png`](<./BedHospital-Sheet.png>) | 128 × 64 | 64 × 64 slot | 2 | Full furniture slots |
| [`DoorsHospital-Sheet.png`](<./DoorsHospital-Sheet.png>) | 800 × 80 | 80 × 80 slot | 10 | Full furniture/door slots |
| [`Miscellaneous-Sheet.png`](<./Miscellaneous-Sheet.png>) | 3072 × 64 | 128 × 64 slot | 24 | Full furniture slots |
| [`TilesHospital.png`](<./TilesHospital.png>) | 320 × 256 | 16 × 16 tile | 118 non-empty / 320 total | Atomic non-empty tile cells |

## BedHospital-Sheet.png

Source: [`BedHospital-Sheet.png`](<./BedHospital-Sheet.png>)

- **Canvas:** 128 × 64 pixels
- **Layout:** 2 horizontal 64 × 64 slots
- **IDs:** `bed.slot00`–`bed.slot01`

| Asset ID | Source rectangle | Visible bbox within slot | Visual/type note |
|---|---|---|---|
| `bed.slot00` | `(0, 0, 64, 64)` | `(19, 7, 26, 42)` | Bed variant/orientation 00 |
| `bed.slot01` | `(64, 0, 64, 64)` | `(20, 7, 24, 37)` | Bed variant/orientation 01 |

## DoorsHospital-Sheet.png

Source: [`DoorsHospital-Sheet.png`](<./DoorsHospital-Sheet.png>)

- **Canvas:** 800 × 80 pixels
- **Layout:** 10 horizontal 80 × 80 slots
- **IDs:** `doors.slot00`–`doors.slot09`

| Asset ID | Source rectangle | Visible bbox within slot | Visual/type note |
|---|---|---|---|
| `doors.slot00` | `(0, 0, 80, 80)` | `(7, 31, 65, 49)` | Paneled unit / doorway variant 00 |
| `doors.slot01` | `(80, 0, 80, 80)` | `(7, 17, 65, 63)` | Open frame variant 01 |
| `doors.slot02` | `(160, 0, 80, 80)` | `(7, 31, 65, 49)` | Open frame variant 02 |
| `doors.slot03` | `(240, 0, 80, 80)` | `(37, 16, 5, 64)` | Narrow vertical trim variant 03 |
| `doors.slot04` | `(320, 0, 80, 80)` | `(37, 0, 5, 64)` | Narrow vertical trim variant 04 |
| `doors.slot05` | `(400, 0, 80, 80)` | `(35, 0, 9, 64)` | Double-divider trim variant 05 |
| `doors.slot06` | `(480, 0, 80, 80)` | `(4, 0, 38, 64)` | Paneled unit variant 06 |
| `doors.slot07` | `(560, 0, 80, 80)` | `(4, 0, 36, 46)` | Upper-panel variant 07 |
| `doors.slot08` | `(640, 0, 80, 80)` | `(22, 30, 36, 50)` | Closed door variant 08 |
| `doors.slot09` | `(720, 0, 80, 80)` | `(22, 3, 36, 64)` | Open doorway variant 09 |

## Miscellaneous-Sheet.png

Source: [`Miscellaneous-Sheet.png`](<./Miscellaneous-Sheet.png>)

- **Canvas:** 3072 × 64 pixels
- **Layout:** 24 horizontal 128 × 64 slots
- **IDs:** `misc.slot00`–`misc.slot23`

| Asset ID | Source rectangle | Visible bbox within slot | Visual/type note |
|---|---|---|---|
| `misc.slot00` | `(0, 0, 128, 64)` | `(54, 18, 20, 30)` | Miscellaneous asset slot 00 |
| `misc.slot01` | `(128, 0, 128, 64)` | `(57, 12, 14, 35)` | Miscellaneous asset slot 01 |
| `misc.slot02` | `(256, 0, 128, 64)` | `(39, 21, 52, 23)` | Miscellaneous asset slot 02 |
| `misc.slot03` | `(384, 0, 128, 64)` | `(54, 23, 20, 6)` | Miscellaneous asset slot 03 |
| `misc.slot04` | `(512, 0, 128, 64)` | `(57, 21, 14, 18)` | Miscellaneous asset slot 04 |
| `misc.slot05` | `(640, 0, 128, 64)` | `(57, 19, 15, 25)` | Miscellaneous asset slot 05 |
| `misc.slot06` | `(768, 0, 128, 64)` | `(56, 4, 14, 50)` | Miscellaneous asset slot 06 |
| `misc.slot07` | `(896, 0, 128, 64)` | `(33, 15, 62, 25)` | Miscellaneous asset slot 07 |
| `misc.slot08` | `(1024, 0, 128, 64)` | `(51, 24, 25, 17)` | Miscellaneous asset slot 08 |
| `misc.slot09` | `(1152, 0, 128, 64)` | `(57, 23, 12, 16)` | Miscellaneous asset slot 09 |
| `misc.slot10` | `(1280, 0, 128, 64)` | `(53, 20, 22, 27)` | Miscellaneous asset slot 10 |
| `misc.slot11` | `(1408, 0, 128, 64)` | `(47, 33, 34, 14)` | Miscellaneous asset slot 11 |
| `misc.slot12` | `(1536, 0, 128, 64)` | `(47, 33, 34, 14)` | Miscellaneous asset slot 12 |
| `misc.slot13` | `(1664, 0, 128, 64)` | `(47, 33, 34, 14)` | Miscellaneous asset slot 13 |
| `misc.slot14` | `(1792, 0, 128, 64)` | `(47, 33, 34, 14)` | Miscellaneous asset slot 14 |
| `misc.slot15` | `(1920, 0, 128, 64)` | `(62, 41, 9, 7)` | Miscellaneous asset slot 15 |
| `misc.slot16` | `(2048, 0, 128, 64)` | `(55, 36, 18, 10)` | Miscellaneous asset slot 16 |
| `misc.slot17` | `(2176, 0, 128, 64)` | `(58, 28, 12, 18)` | Miscellaneous asset slot 17 |
| `misc.slot18` | `(2304, 0, 128, 64)` | `(57, 17, 13, 20)` | Miscellaneous asset slot 18 |
| `misc.slot19` | `(2432, 0, 128, 64)` | `(48, 17, 32, 20)` | Miscellaneous asset slot 19 |
| `misc.slot20` | `(2560, 0, 128, 64)` | `(3, 15, 122, 45)` | Miscellaneous asset slot 20 |
| `misc.slot21` | `(2688, 0, 128, 64)` | `(3, 15, 122, 45)` | Miscellaneous asset slot 21 |
| `misc.slot22` | `(2816, 0, 128, 64)` | `(3, 15, 122, 45)` | Miscellaneous asset slot 22 |
| `misc.slot23` | `(2944, 0, 128, 64)` | `(49, 18, 30, 33)` | Miscellaneous asset slot 23 |

## TilesHospital.png

Source: [`TilesHospital.png`](<./TilesHospital.png>)

- **Canvas:** 320 × 256 pixels
- **Grid:** 20 columns × 16 rows
- **Atomic tile size:** 16 × 16 pixels
- **Total cells:** 320
- **Non-empty cells:** 118
- **ID format:** `tiles.r<row>.c<column>`

This file is cataloged as an atomic 16×16 tile atlas. Some visual wall, floor, and trim pieces span multiple neighboring cells; those compositions should be assembled from the listed cell coordinates rather than treated as one inferred furniture rectangle.

### Non-empty cell map

The following map uses `#` for a non-empty 16×16 cell and `.` for a fully transparent cell. Rows and columns are zero-based.

| Row | Source `y` | Occupancy columns `c00`–`c19` |
|---|---:|---|
| `r00` | 0 | `....................` |
| `r01` | 16 | `....................` |
| `r02` | 32 | `....................` |
| `r03` | 48 | `....................` |
| `r04` | 64 | `####.###.####.#####.` |
| `r05` | 80 | `####.###.####.#####.` |
| `r06` | 96 | `####.###.####.#####.` |
| `r07` | 112 | `####.###.####.#####.` |
| `r08` | 128 | `#...........#.#...#.` |
| `r09` | 144 | `#.....##.##.#.#...#.` |
| `r10` | 160 | `..###.##.##.........` |
| `r11` | 176 | `#.###.##.##.#....###` |
| `r12` | 192 | `..##..##.##.....##..` |
| `r13` | 208 | `###.......###.###...` |
| `r14` | 224 | `..##.....##.....##..` |
| `r15` | 240 | `....................` |

### Non-empty tile coordinates

| Tile ID | Source rectangle |
|---|---|
| `tiles.r04.c00` | `(0, 64, 16, 16)` |
| `tiles.r04.c01` | `(16, 64, 16, 16)` |
| `tiles.r04.c02` | `(32, 64, 16, 16)` |
| `tiles.r04.c03` | `(48, 64, 16, 16)` |
| `tiles.r04.c05` | `(80, 64, 16, 16)` |
| `tiles.r04.c06` | `(96, 64, 16, 16)` |
| `tiles.r04.c07` | `(112, 64, 16, 16)` |
| `tiles.r04.c09` | `(144, 64, 16, 16)` |
| `tiles.r04.c10` | `(160, 64, 16, 16)` |
| `tiles.r04.c11` | `(176, 64, 16, 16)` |
| `tiles.r04.c12` | `(192, 64, 16, 16)` |
| `tiles.r04.c14` | `(224, 64, 16, 16)` |
| `tiles.r04.c15` | `(240, 64, 16, 16)` |
| `tiles.r04.c16` | `(256, 64, 16, 16)` |
| `tiles.r04.c17` | `(272, 64, 16, 16)` |
| `tiles.r04.c18` | `(288, 64, 16, 16)` |
| `tiles.r05.c00` | `(0, 80, 16, 16)` |
| `tiles.r05.c01` | `(16, 80, 16, 16)` |
| `tiles.r05.c02` | `(32, 80, 16, 16)` |
| `tiles.r05.c03` | `(48, 80, 16, 16)` |
| `tiles.r05.c05` | `(80, 80, 16, 16)` |
| `tiles.r05.c06` | `(96, 80, 16, 16)` |
| `tiles.r05.c07` | `(112, 80, 16, 16)` |
| `tiles.r05.c09` | `(144, 80, 16, 16)` |
| `tiles.r05.c10` | `(160, 80, 16, 16)` |
| `tiles.r05.c11` | `(176, 80, 16, 16)` |
| `tiles.r05.c12` | `(192, 80, 16, 16)` |
| `tiles.r05.c14` | `(224, 80, 16, 16)` |
| `tiles.r05.c15` | `(240, 80, 16, 16)` |
| `tiles.r05.c16` | `(256, 80, 16, 16)` |
| `tiles.r05.c17` | `(272, 80, 16, 16)` |
| `tiles.r05.c18` | `(288, 80, 16, 16)` |
| `tiles.r06.c00` | `(0, 96, 16, 16)` |
| `tiles.r06.c01` | `(16, 96, 16, 16)` |
| `tiles.r06.c02` | `(32, 96, 16, 16)` |
| `tiles.r06.c03` | `(48, 96, 16, 16)` |
| `tiles.r06.c05` | `(80, 96, 16, 16)` |
| `tiles.r06.c06` | `(96, 96, 16, 16)` |
| `tiles.r06.c07` | `(112, 96, 16, 16)` |
| `tiles.r06.c09` | `(144, 96, 16, 16)` |
| `tiles.r06.c10` | `(160, 96, 16, 16)` |
| `tiles.r06.c11` | `(176, 96, 16, 16)` |
| `tiles.r06.c12` | `(192, 96, 16, 16)` |
| `tiles.r06.c14` | `(224, 96, 16, 16)` |
| `tiles.r06.c15` | `(240, 96, 16, 16)` |
| `tiles.r06.c16` | `(256, 96, 16, 16)` |
| `tiles.r06.c17` | `(272, 96, 16, 16)` |
| `tiles.r06.c18` | `(288, 96, 16, 16)` |
| `tiles.r07.c00` | `(0, 112, 16, 16)` |
| `tiles.r07.c01` | `(16, 112, 16, 16)` |
| `tiles.r07.c02` | `(32, 112, 16, 16)` |
| `tiles.r07.c03` | `(48, 112, 16, 16)` |
| `tiles.r07.c05` | `(80, 112, 16, 16)` |
| `tiles.r07.c06` | `(96, 112, 16, 16)` |
| `tiles.r07.c07` | `(112, 112, 16, 16)` |
| `tiles.r07.c09` | `(144, 112, 16, 16)` |
| `tiles.r07.c10` | `(160, 112, 16, 16)` |
| `tiles.r07.c11` | `(176, 112, 16, 16)` |
| `tiles.r07.c12` | `(192, 112, 16, 16)` |
| `tiles.r07.c14` | `(224, 112, 16, 16)` |
| `tiles.r07.c15` | `(240, 112, 16, 16)` |
| `tiles.r07.c16` | `(256, 112, 16, 16)` |
| `tiles.r07.c17` | `(272, 112, 16, 16)` |
| `tiles.r07.c18` | `(288, 112, 16, 16)` |
| `tiles.r08.c00` | `(0, 128, 16, 16)` |
| `tiles.r08.c12` | `(192, 128, 16, 16)` |
| `tiles.r08.c14` | `(224, 128, 16, 16)` |
| `tiles.r08.c18` | `(288, 128, 16, 16)` |
| `tiles.r09.c00` | `(0, 144, 16, 16)` |
| `tiles.r09.c06` | `(96, 144, 16, 16)` |
| `tiles.r09.c07` | `(112, 144, 16, 16)` |
| `tiles.r09.c09` | `(144, 144, 16, 16)` |
| `tiles.r09.c10` | `(160, 144, 16, 16)` |
| `tiles.r09.c12` | `(192, 144, 16, 16)` |
| `tiles.r09.c14` | `(224, 144, 16, 16)` |
| `tiles.r09.c18` | `(288, 144, 16, 16)` |
| `tiles.r10.c02` | `(32, 160, 16, 16)` |
| `tiles.r10.c03` | `(48, 160, 16, 16)` |
| `tiles.r10.c04` | `(64, 160, 16, 16)` |
| `tiles.r10.c06` | `(96, 160, 16, 16)` |
| `tiles.r10.c07` | `(112, 160, 16, 16)` |
| `tiles.r10.c09` | `(144, 160, 16, 16)` |
| `tiles.r10.c10` | `(160, 160, 16, 16)` |
| `tiles.r11.c00` | `(0, 176, 16, 16)` |
| `tiles.r11.c02` | `(32, 176, 16, 16)` |
| `tiles.r11.c03` | `(48, 176, 16, 16)` |
| `tiles.r11.c04` | `(64, 176, 16, 16)` |
| `tiles.r11.c06` | `(96, 176, 16, 16)` |
| `tiles.r11.c07` | `(112, 176, 16, 16)` |
| `tiles.r11.c09` | `(144, 176, 16, 16)` |
| `tiles.r11.c10` | `(160, 176, 16, 16)` |
| `tiles.r11.c12` | `(192, 176, 16, 16)` |
| `tiles.r11.c17` | `(272, 176, 16, 16)` |
| `tiles.r11.c18` | `(288, 176, 16, 16)` |
| `tiles.r11.c19` | `(304, 176, 16, 16)` |
| `tiles.r12.c02` | `(32, 192, 16, 16)` |
| `tiles.r12.c03` | `(48, 192, 16, 16)` |
| `tiles.r12.c06` | `(96, 192, 16, 16)` |
| `tiles.r12.c07` | `(112, 192, 16, 16)` |
| `tiles.r12.c09` | `(144, 192, 16, 16)` |
| `tiles.r12.c10` | `(160, 192, 16, 16)` |
| `tiles.r12.c16` | `(256, 192, 16, 16)` |
| `tiles.r12.c17` | `(272, 192, 16, 16)` |
| `tiles.r13.c00` | `(0, 208, 16, 16)` |
| `tiles.r13.c01` | `(16, 208, 16, 16)` |
| `tiles.r13.c02` | `(32, 208, 16, 16)` |
| `tiles.r13.c10` | `(160, 208, 16, 16)` |
| `tiles.r13.c11` | `(176, 208, 16, 16)` |
| `tiles.r13.c12` | `(192, 208, 16, 16)` |
| `tiles.r13.c14` | `(224, 208, 16, 16)` |
| `tiles.r13.c15` | `(240, 208, 16, 16)` |
| `tiles.r13.c16` | `(256, 208, 16, 16)` |
| `tiles.r14.c02` | `(32, 224, 16, 16)` |
| `tiles.r14.c03` | `(48, 224, 16, 16)` |
| `tiles.r14.c09` | `(144, 224, 16, 16)` |
| `tiles.r14.c10` | `(160, 224, 16, 16)` |
| `tiles.r14.c16` | `(256, 224, 16, 16)` |
| `tiles.r14.c17` | `(272, 224, 16, 16)` |

## Lookup examples

- `bed.slot00` → crop `(0, 0, 64, 64)` from `BedHospital-Sheet.png`.
- `doors.slot08` → crop `(640, 0, 80, 80)` from `DoorsHospital-Sheet.png`.
- `misc.slot20` → crop `(2560, 0, 128, 64)` from `Miscellaneous-Sheet.png`.
- `tiles.r13.c14` → crop `(224, 208, 16, 16)` from `TilesHospital.png`.

## Verification notes

- BedHospital-Sheet.png divides exactly into 2 × 64×64 slots.
- DoorsHospital-Sheet.png divides exactly into 10 × 80×80 slots.
- Miscellaneous-Sheet.png divides exactly into 24 × 128×64 slots.
- TilesHospital.png divides exactly into 20 × 16 cells; 118 cells contain non-transparent pixels.

