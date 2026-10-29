# Jamsil flight map asset

The supplied city is preserved as a recognizable three-dimensional city rather than rebuilt as boxes. The export retains the curved 555 m Lotte World Tower and open crown, the mall masses, Indoor Adventure's curved roof, Seokchon Lake's two basins and island holes, Magic Island's castle, coaster and taller rides, surrounding street layout, and original building footprints/heights.

## Verified game asset

| Metric | Export |
| --- | ---: |
| Source visible mesh triangles, counting repeated tree instances | 71,412,199 |
| Actual exported triangles | 948,094 |
| Exported vertices | 1,661,815 |
| Mesh instances | 14 |
| Material surfaces | 45 |
| Shared materials | 5 |
| Texture | One 256 × 256 facade tile |
| GLB size | 53,989,820 bytes (51.49 MiB) |
| Tree instances preserved at their original positions | 1,221 |

The triangle count is reduced by 98.67%. Counts above are measured from the exported GLB accessors, and independently verified after Godot import. Material surfaces describe the city geometry's base submissions; scene shadows and other render passes can add draws. Godot's scene importer generates mesh LODs and shadow meshes.

Each batched polygon preserves its source face ID through Blender's geometry validation. An assertion checks that every surviving face still references its original vertices before assigning colors/materials. A separate exported-geometry check verifies all 49 large city-grade triangles retain the source ground color; this catches triangular color contamination if a future geometry cleanup changes face order.

## Changes

- Removed the source's cameras, lights, world/HDR, rectangular substrate, render bevel/subdivision, and distant sub-metre benches, lamps, railings and visitors.
- Corrected inward winding in 211 original building shells (1,567 faces), so exterior walls remain visible with backface culling. The earlier export enabled culling without correcting these shells, causing missing walls.
- Restored seven previously discarded architectural skin batches (567,190 triangles), including glass, opaque cladding, window reveals and blinds. Original building shells, architectural skins and tower geometry bypass destructive collapse decimation. Only the dense micro-frame batches use the 256 px repeat tile mapped to 3.2 × 3.6 m source facade cells.
- Replaced approximately 68 million triangles of repeated trees with 30-triangle canopies and trunks, matching each source tree's location and bounds.
- Dissolved coplanar tessellation and reduced castle, rides and ordinary props. The theme park additionally clusters sub-32 cm masonry detail; its building and ride silhouettes remain derived from the source geometry.
- Replaced procedural noise/bump networks with five shared PBR materials plus per-vertex colors. Lake water has an explicit muted teal base color, roughness 0.48 and reduced specular; glazing is roughened for daylight readability.
- Split ordinary geometry into nine approximately 400 m spatial chunks. Five separately named landmark nodes remain identifiable and cull independently.
- Packed vertex colors to normalized 8-bit values, omitted unused UV buffers, and merged equivalent vertex records. No runtime compression extension or decoder is required.

## Coordinates and placement

The GLB is in Godot's Y-up convention, in source metres. Local city grade is `y = 0`; local lake water is `y = -3.96`; tower top is `y = 555`. Level 4 now applies a uniform runtime scale of **1.5** around city grade, then adds an 8 m elevation: `world = local * 1.5 + Vector3.UP * 8`. Collisions, lake masks, coastline, clouds and target layouts follow this transform. The resulting city footprint is approximately 1.736 × 1.537 km, with an 832.5 m tower and a 2.06 m lake surface.

Actual exported source bounds are `(-578.049, -6, -511.758)` to `(578.049, 555, 511.758)`. The source's full architectural footprint is approximately 1157.21 × 1024.76 m; removed thin facade rails account for the small difference from the export's 1156.10 × 1023.52 m extent.

Source Blender coordinates are converted using:

```text
godot.x = source.x + 64.299011
godot.y = source.z - 4
godot.z = -(source.y + 217.241516)
```

`city-manifest.json` includes exact bounds, the source transform, five landmark AABBs/node names, 92 obstacle AABBs, and 220 lake triangles in local XZ coordinates. The lake triangles preserve the island holes for ground queries; obstacle bounds are deliberately coarse and do not replace detailed mesh collision.

`validation.facade_recovery` records repaired shell counts and the restored architectural batches with triangle counts and surface areas. `review/city-refinement/facade-winding-audit.json` compares the actual old and new GLB wall triangles against two source buildings: all eight walls in each sample changed from inward to outward. Godot integration tests also inspect the imported triangles and verify the materials still use backface culling. Native front/rear facade views are recorded in `review/city-refinement/`; automatic LOD remains enabled.

## Reproduction and provenance

Run from the game project with Blender 5.2:

```sh
/Applications/Blender.app/Contents/MacOS/Blender \
  --background --factory-startup --disable-autoexec \
  --python tools/optimize_jamsil_city.py -- \
  --source ../Lotte_Jamsil_V5/Jamsil_05_Atmosphere_Detail.blend \
  --output assets/jamsil
```

The pipeline opens the source read-only and never saves a Blender file. It checks SHA-256 before and after export. Verified source hash:

```text
068b22d65b72e467888aeadacb282012024cc5984f721ce6cae3974c82cb3e99
```

The source was authored in Blender 5.2.2 and read with installed Blender 5.2.1; Blender emits a newer-file warning, but the exported geometry, landmarks and source hash pass validation. Native gameplay performance is measured in the integrated island scene separately.

See [ATTRIBUTION.md](ATTRIBUTION.md) for OpenStreetMap/ODbL and the source's Poly Haven CC0 attribution. The original HDR sky is excluded.
