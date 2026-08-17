# Pixel Scribe pixel-art assets

This directory contains the pixel-art sources used by the frontend. The current
renderer uses the purchased Metrocity pack under `metrocity/`; the generated
`office-*.png` atlases below are retained as the original Pixel Scribe baseline.

## Current runtime pack

Metrocity preserves the pack's source names and case. Do not rename, resize, or
recompress these files as part of frontend work.

- `metrocity/Interior/Home/TilesHouse.png` supplies 16 × 16 atomic wall tiles.
- The Home sheets supply native 64 px-wide furniture slots for kitchen units,
  cupboards, miscellaneous furniture, plants, carpets, windows, and paintings.
- `metrocity/Character/CharacterModel/Character Model.png`,
  `metrocity/Character/Outfits/Suit.png`, and
  `metrocity/Character/Hair/Hairs.png` are layered 32 × 32 character sheets.

The world remains a 16 px logical grid. Furniture is drawn at its catalogued
native slot size, while each character is assembled from one model, outfit, and
hair cell at the same 32 × 32 origin in that order. The current MVP uses the
front-facing frame because movement and directional animation are outside its
scope. All runtime images use nearest-neighbor sampling.

## Historical generated atlases

| File | Final size | Cell layout | Intended cell size |
| --- | ---: | --- | ---: |
| `office-tiles-16.png` | 128 × 128 px | 8 columns × 8 rows | 16 × 16 px |
| `office-tiles-v2-16.png` | 128 × 128 px | 8 columns × 8 rows | 16 × 16 px |
| `office-avatars-16.png` | 128 × 64 px | 8 columns × 4 rows | 16 × 16 px |

The generated tile atlas contained floor variants, walls, windows, desks,
seating, plants, storage, office equipment, rugs, and decor. The generated
avatar atlas contained 32 fixed-pose office avatars with varied hair, skin
tones, clothing, and accessories. These historical sheets use a uniform deep
navy backdrop in unused cell space and have no labels, grid lines, or gutters.

## Provenance and permission

- Creator: OpenAI built-in image generation tool, commissioned by the Pixel
  Scribe project through Codex on 2026-08-15 and 2026-08-16. The project team
  selected and prepared the final atlas files.
- Source: three fresh, prompt-only generations; no reference images, existing
  art, Pixel Agents artwork, or third-party asset pack was supplied. The
  current tile atlas is the 2026-08-16 generation; the avatar atlas remains
  the original 2026-08-15 generation.
- Generation mode: built-in `image_gen` tool, generate mode (not CLI; no edit
  target or reference image).
- License: CC0 1.0 dedication for these final atlas files by the Pixel Scribe
  project maintainers. The files may be copied, modified, bundled, and
  redistributed without attribution.
- Distribution permission: explicitly permitted in this repository, in the
  compiled frontend, and in redistributed source or binary deployments.
- Modifications: the current tile source (1254 × 1254 px) was resized with
  ImageMagick using the point/nearest-neighbor filter only to become 128 × 128
  px. The baseline tile source (1254 × 1254 px) and avatar source (1774 × 887
  px) were prepared the same way. No pixels were painted procedurally, no
  objects were added or removed, and no source artwork was copied.
- Source-generation records: tile generation output
  `exec-5f16c136-6850-4b4a-a4e3-0ec09786c519.png` for the current atlas;
  baseline tile output `exec-4658ffe7-4e5b-44eb-9cd6-1e193a8e9d66.png`; avatar
  output `exec-378b5f5f-6cff-4688-bfe7-01a1fa3ac1b6.png` (all retained by the
  built-in image-generation workspace record).

## Exact final prompts

The following are the final prompts sent to the built-in tool. They are part
of the provenance record and intentionally call for original work rather than
matching any existing asset set.

### Current tile atlas (v2)

```text
Use case: stylized-concept
Asset type: original pixel-art tile atlas for a browser virtual-office canvas
Primary request: Create a completely original high-resolution master tile atlas for a cozy, busy top-down pixel-art office. Arrange exactly 8 columns by 8 rows of equal square cells. Every cell contains exactly one tile or one small piece of office furniture/decor, fully contained in its cell. Include multiple warm wood and muted carpet floor variants, wall and corner pieces, windows, doorway, desks, chairs, monitors, bookshelves, filing cabinets, plants, lamps, sofas, coffee table, rug pieces, whiteboard, clock, and a few deliberately empty cells.
Scene/backdrop: one perfectly uniform deep navy background (#12182a) filling all unused space in every cell
Subject: compact top-down office tile atlas, one asset per cell, designed to be reduced to 16x16 logical pixels
Style/medium: crisp hand-authored pixel art, hard-edged clusters, strong dark outlines, limited palette, readable silhouettes, classic 16-bit game asset discipline
Composition/framing: exact 8x8 equal-cell atlas, orthogonal top-down view, centered assets with generous padding, no asset crosses a cell boundary
Lighting/mood: warm, playful, lived-in shared office; tiny highlights on wood, glass, screens, and leaves
Color palette: walnut brown, dusty terracotta, slate blue, sage green, cream, mustard, charcoal navy outlines, restrained contrast
Materials/textures: simple intentional pixel clusters; wood grain, carpet flecks, paper stacks, plant leaves, monitor glow
Text (verbatim): ""
Constraints: original work; redistributable; no brands, logos, named characters, copyrighted art, game imitation, UI, labels, or watermark; preserve exact equal cell boundaries; must remain legible after nearest-neighbor reduction to 16x16 per cell
Avoid: visible grid lines, gutters, seams, borders, uneven cells, perspective, gradients, blur, anti-aliasing, photorealism, text, watermark
```

### Tile atlas

```text
Use case: stylized-concept
Asset type: original 16px pixel-art tile atlas for a browser canvas office game
Primary request: Create a completely original tile atlas sheet with 64 tiles arranged in exactly 8 columns and 8 rows. The canvas must contain only the tiles and a single uniform deep navy (#12182a) background; DO NOT draw grid lines, seams, gutters, borders, labels, or separators. Each tile occupies one exact equal square cell, never crosses into another cell. Design readable top-down office tiles: several wood and carpet floor variants, wall pieces, window, doorway, desk, chair, table, plant, lamp, bookshelf, monitor, rug, cabinet, and a few deliberately empty navy cells. This is an atlas source intended for nearest-neighbor downsampling to a 128x128 PNG where each tile is exactly 16x16 pixels.
Scene/backdrop: flat uniform deep navy atlas background inside every cell
Subject: original top-down office floors, walls, furniture, and decor, one object per cell
Style/medium: crisp limited-palette pixel art, hard-edged block clusters, no antialiasing, no painterly shading
Composition/framing: 8x8 equal square cells, no visible grid, no cell crossing, orthogonal top-down view
Lighting/mood: consistent soft office highlights encoded as pixel clusters
Color palette: walnut, slate blue, sage, cream, terracotta, charcoal outlines, restrained contrast
Materials/textures: simple intentional pixel texture only within each cell
Text (verbatim): ""
Constraints: exact equal cell layout; no grid lines or gutters; original work; redistributable; no brands, logos, named characters, copyrighted art, or imitation of any named game or asset pack; no Pixel Agents artwork
Avoid: visible seams, uneven cells, perspective, gradients, blur, anti-aliasing, text, watermark, photorealism
```

### Avatar atlas

```text
Use case: stylized-concept
Asset type: original small fixed-avatar atlas for a browser canvas office game
Primary request: Create a completely original avatar sprite atlas on a single uniform deep navy (#12182a) background, with exactly 8 columns and 4 rows of equal cells and exactly one small fixed top-down/three-quarter office avatar centered in each cell. The 32 avatars should be distinct in hair, skin, clothing colors, silhouette, and accessories while remaining simple and readable at 16x32 pixels after nearest-neighbor reduction. Keep every avatar fully inside its own cell with generous navy padding; no avatar may cross a cell boundary. No grid lines, seams, gutters, labels, UI, or borders. This is a source atlas intended for nearest-neighbor reduction to a 128x128 PNG: each final cell will be 16x32 pixels.
Scene/backdrop: flat uniform deep navy atlas background filling every cell
Subject: 32 original tiny office avatars, fixed poses, varied hair, skin tones, shirts, jackets, and accessories
Style/medium: crisp limited-palette pixel art, hard-edged block clusters, no antialiasing, no painterly rendering
Composition/framing: exact 8x4 equal-cell atlas, centered avatars, consistent scale and baseline, no visible grid
Lighting/mood: gentle readable highlights, friendly office mood
Color palette: warm diverse skin tones, dark and light hair, teal, rust, mustard, sage, cream, navy clothing, charcoal outlines
Materials/textures: minimal pixel clusters with clear silhouettes
Text (verbatim): ""
Constraints: original and redistributable; preserve exact equal cell boundaries; no brands, logos, copyrighted characters, named game or asset pack imitation, or Pixel Agents artwork; fixed poses only; no speech bubbles
Avoid: avatars crossing cells, uneven spacing, grid lines, gradients, blur, anti-aliasing, perspective scenery, text, watermark, photorealism
```

The avatar prompt requested 16×32 logical cells, but the generated source has
square cells and the final atlas is intentionally documented as 16×16. The
avatar silhouettes remain readable within those square cells; this note keeps
the record honest and prevents a future renderer from assuming a stretched
cell geometry.
