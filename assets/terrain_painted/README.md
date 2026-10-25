# Painted terrain kit

Derived from the user's `art_sources/slices/sliced/sliceNN_.png` files. Originals are untouched. Run `tools/prepare_painted_terrain.py` with Python and Pillow to rebuild the runtime copies. It retains the largest connected alpha component, drops detached neighboring-slice debris, and preserves the original canvas size. No AI repainting or resampling is applied to the source artwork.

`terrain_lab2.gd` defines two explicit anchor catalogs:

- `TOP_ANCHORS` locates the center of a cliff's top diamond, so its rock and vines hang below a floor cell.
- `FOOT_ANCHORS` locates a column or arch's ground contact, so it stands above the cell. The parent sits at that contact for Y sorting; the sprite is offset inside it.

Anchors are source pixel coordinates, multiplied by the sprite's scale. A new asset needs an anchor measured from its painted geometry. Image width, height, alpha bounds and center are insufficient because the slices include unequal margins and different amounts of foliage.

The board uses exact 60×34 diamonds, sampling the top face of slice 09 with source UV corners `(37, 1)`, `(73, 23)`, `(38, 44)`, `(1, 23)`. Those UVs are deliberately independent of the sprite's full rectangle. This covers the board without cracks or vertical walls between adjacent cells. Edge cliffs are separate sprites underneath. The scale and perspective of larger architectural slices vary slightly in the source art; those slices are used as perimeter decoration, rather than as arbitrary multi-cell paving.

The generator uses one-cell occupancy, a stable coordinate order and a local seeded RNG. It removes only cells that preserve connectivity and never removes a sample piece cell. Ledges join an existing neighboring cell. Full maps and broken maps use the same projection and anchor rules. Painted slices cannot orbit, and rotating or mirroring them would rotate their painted light and break the perspective.

Chess models remain 3D. Each distinct type and side gets a cached transparent 64×96 SubViewport, rendered once per instance and reused on regeneration. The camera projects the model's ground-level origin into portrait pixels; the 2D sprite subtracts that pixel location so its foot lands exactly on a floor center. The palette shader uses world normals and a fixed key direction matching the painted light. Elliptical contact shadows and alpha silhouette outlines are composited in 2D. Pieces and standing architecture sort by their shared ground positions.
