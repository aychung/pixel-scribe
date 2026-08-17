# Metrocity Sprite Asset Pack

## Purpose

This repository is a PNG sprite and tileset asset pack built around 32×32 base 2D pixel-art assets. Agents will gradually add Markdown catalogs so other agents can locate assets by exact source path and pixel coordinates.

Start with the root [CATALOG.md](<./CATALOG.md>) index to find the catalog for each asset family and directory.

## Asset layout

- `Character/` contains the character model, hair, outfits, and related sprites.
- `Interior/Home/` contains home interiors, furniture, decorations, and tiles.
- `Interior/Hospital/` contains hospital interiors, furniture, and tiles.
- `Interior/Demo/` contains demo or sequence images.

Preserve the existing directory structure, filenames, capitalization, spaces, and file extensions. Use repository-relative paths in documentation, and wrap paths containing spaces in Markdown link syntax correctly.

## Coordinate convention

Unless a catalog explicitly documents another convention:

- Coordinates refer to pixels in the original PNG file.
- The origin `(0, 0)` is the image's top-left pixel.
- Rectangles use zero-based `x, y, width, height` values.
- `x` and `y` identify the upper-left corner; the right and bottom edges are exclusive.
- Record the source image dimensions for every cataloged sheet.
- Do not infer pivots, animation timing, collision bounds, or intended names when they are not visible or documented. Mark them as unknown instead.

For a standalone image used as one asset, its default rectangle is the full image: `x: 0, y: 0, width: <image width>, height: <image height>`.

## Character-sheet alignment

Character hair and outfit sheets use the same horizontal direction layout as `Character/CharacterModel/Character Model.png` whenever they are 24 cells wide:

- columns `c00`–`c05`: down-facing / front view;
- columns `c06`–`c11`: right-facing profile;
- columns `c12`–`c17`: up-facing / back view;
- columns `c18`–`c23`: left-facing profile.

Within these sheets, horizontal cells are the same type shown in different directions and animation frames, while vertical rows represent different hair or outfit types/variants. Preserve this alignment when cataloging or composing assets with the character model.

## Character assembly

To create a character, layer a matching 32×32 hair cell and outfit cell on top of a 32×32 character-model cell:

1. Character model as the base layer.
2. Outfit above the character model.
3. Hair above the outfit.

For 24-column direction sheets, choose the same direction/frame column from all three sources and choose the desired vertical row/type independently. The source cells are already aligned in the same 32×32 canvas, so composite them at the same origin without resizing, repositioning, or trimming. Standalone 32×32 hair files are already canvas-sized and can be used as a single overlay cell.

## Cataloging requirements

Each catalog entry should include, when applicable:

- a stable asset name or ID;
- a link to the original PNG;
- the source image dimensions;
- the exact pixel rectangle (`x`, `y`, `width`, `height`);
- a short description and useful tags;
- notes about transparency, variants, or uncertainty.

Keep catalogs close to the assets they describe and link them from a higher-level index when one exists. Prefer one entry per usable sprite, tile, frame, or coherent asset group rather than vague descriptions of an entire sheet.

## Inspection and verification

Before documenting coordinates, inspect the original PNG at pixel level and verify the image dimensions. Visually check the rectangle against the source image after writing the entry. Do not resize, recompress, rename, move, or overwrite source PNGs as part of catalog work.

If an asset boundary is ambiguous because of padding, transparency, or overlapping pixels, record the ambiguity in the catalog rather than silently choosing a different convention.

## Change checklist

Before finishing a catalog change:

1. Confirm every referenced path exists and preserves its exact case.
2. Confirm every coordinate is inside the stated source image dimensions.
3. Confirm the Markdown links and tables render correctly, including paths with spaces.
4. Keep unrelated files and existing user changes untouched.
