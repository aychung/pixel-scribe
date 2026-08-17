# Metrocity Asset Catalog Index

This is the root navigation page for the PNG asset catalogs. Open the linked folder catalog for exact source rectangles, asset IDs, grid layouts, and visible-pixel bounds.

## Catalogs at a glance

| Catalog | Contains | Coordinate model |
|---|---|---|
| [Character Model](<./Character/CharacterModel/CATALOG.md>) | `Character Model.png` and `Shadow.png` | 32×32 character cells; one 32×32 shadow cell |
| [Hair](<./Character/Hair/CATALOG.md>) | Standalone hair sprites, `Hair_v2.png`, and `Hairs.png` | Standalone 32×32 cells; 32×32 cells in 24-column direction sheets |
| [Outfits](<./Character/Outfits/CATALOG.md>) | `Outfit1.png`–`Outfit6.png`, `Suit.png`, and `Suit1.png` | 32×32 cells in 24-column direction sheets |
| [Home Interior](<./Interior/Home/CATALOG.md>) | Bathroom, beds, carpets, chimneys, cupboards, doors, flowers, kitchens, lights, living rooms, miscellaneous props, paintings, TV, windows, and house tiles | Variable 64-pixel-wide furniture slots; 16×16 atomic house tiles |
| [Hospital Interior](<./Interior/Hospital/CATALOG.md>) | Beds, doors, miscellaneous props, and hospital tiles | 64×64, 80×80, 128×64 furniture slots; 16×16 atomic hospital tiles |

## Find assets by purpose

| Looking for | Open this catalog | Relevant sections/files |
|---|---|---|
| Base character sprites and palette rows | [Character Model](<./Character/CharacterModel/CATALOG.md>) | `Character Model.png` |
| A ground shadow under a character | [Character Model](<./Character/CharacterModel/CATALOG.md>) | `Shadow.png` |
| Hair overlays or hair variants | [Hair](<./Character/Hair/CATALOG.md>) | `Hair.png`–`Hair7.png`, `Hair_v2.png`, `Hairs.png` |
| Clothing or uniform variants | [Outfits](<./Character/Outfits/CATALOG.md>) | `Outfit1.png`–`Outfit6.png`, `Suit.png`, `Suit1.png` |
| Home beds and bedroom furniture | [Home Interior](<./Interior/Home/CATALOG.md>) | `Beds-Sheet.png`, `Beds1-Sheet.png` |
| Home bathroom fixtures | [Home Interior](<./Interior/Home/CATALOG.md>) | `Bathroom-Sheet.png` |
| Home carpets and floor patterns | [Home Interior](<./Interior/Home/CATALOG.md>) | `Carpet-Sheet.png`, `TilesHouse.png` |
| Home chimneys and fireplaces | [Home Interior](<./Interior/Home/CATALOG.md>) | `Chimney-Sheet.png`, `Chimney1-Sheet.png` |
| Home cupboards and kitchen assets | [Home Interior](<./Interior/Home/CATALOG.md>) | `Cupboard-Sheet.png`, `Kitchen-Sheet.png`, `Kitchen1-Sheet.png` |
| Home doors and windows | [Home Interior](<./Interior/Home/CATALOG.md>) | `Doors-Sheet.png`, `Windows-Sheet.png` |
| Home plants, lights, paintings, TV, and small props | [Home Interior](<./Interior/Home/CATALOG.md>) | `Flowers-Sheet.png`, `Lights-Sheet.png`, `Paintings-Sheet.png`, `Paintings1-Sheet.png`, `TV-Sheet.png`, `Miscellaneous-Sheet.png` |
| Hospital beds | [Hospital Interior](<./Interior/Hospital/CATALOG.md>) | `BedHospital-Sheet.png` |
| Hospital doors and wall/door pieces | [Hospital Interior](<./Interior/Hospital/CATALOG.md>) | `DoorsHospital-Sheet.png` |
| Hospital small props | [Hospital Interior](<./Interior/Hospital/CATALOG.md>) | `Miscellaneous-Sheet.png` |
| Hospital floors, walls, and trim tiles | [Hospital Interior](<./Interior/Hospital/CATALOG.md>) | `TilesHospital.png` |

## Shared conventions

- Read [AGENTS.md](<./AGENTS.md>) before adding or changing catalogs.
- Character, hair, and outfit direction sheets use the shared horizontal order: down/front, right, up/back, left.
- Interior furniture uses the source-specific slot size documented in its catalog; do not assume every interior asset is 32×32.
- Tile atlases are cataloged as atomic 16×16 cells when larger visual groupings are not source-defined.
- Coordinates are source-image pixels with a top-left origin and use `(x, y, width, height)` rectangles with exclusive right and bottom edges.
