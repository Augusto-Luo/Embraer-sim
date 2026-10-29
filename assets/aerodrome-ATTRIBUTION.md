# Aerodrome training asset

Source: **AERODROME** by **ririnhasra88**.

- Author: https://sketchfab.com/ririnhasra88
- Original model: https://sketchfab.com/3d-models/aerodrome-ec5a7b76380448f38a39e45f2e848d16
- License recorded in supplied GLB metadata: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
- User-supplied file: `aerodrome.glb`.

Derived file: `aerodrome-training.glb`.

Changes: baked static transforms; merged meshes sharing a material; removed unused UV data and expensive clearcoat/metallic treatment; converted emissive paint to ordinary matte paint; removed the disconnected sample aircraft floating outside the airfield. The original short runway pavement, white runway markings and runway numbers are removed so the game can build a longer training runway. Taxiway/apron geometry, yellow taxiway lines, windsock and the two parked aircraft are retained. No texture compression is needed because the source has no textures.

The model is normalized with the original runway midpoint at `(0, 0, 0)`, runway length along `+Z` and `+Y` up. Original runway deck is `y=0`. No global scale is applied; scene units are metres as interpreted from the supplied geometry.

Rebuild with:

```bash
python3 tools/optimize_aerodrome.py /path/to/aerodrome.glb
```

The original GLB remains unchanged. Full counts, normalization transform and original per-mesh bounds are in `aerodrome-training.report.json`.
