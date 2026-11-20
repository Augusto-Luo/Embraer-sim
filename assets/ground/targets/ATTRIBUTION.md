# Ground attack target assets

The three source GLB files were supplied by the user. Their embedded Sketchfab metadata lists the following authors and CC BY 4.0 licenses. The original files are unchanged; the game uses optimized derivatives.

## RTCW tiger

- Author: photon (that one larry), https://sketchfab.com/Professor_E12
- Source: https://sketchfab.com/3d-models/rtcw-tiger-a10ed2eaf5ad466b80ea619bed9f920f
- License: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
- Game derivative: `tank.glb`
- Changes: removed an unused helper sphere; normalized ground contact and scale; retained 15,237 triangles and the two 1024 px primary textures. Two targets share the imported resource.

## Rusty airbase fuel tank

- Author: LuddePudde, https://sketchfab.com/ludde5000
- Source: https://sketchfab.com/3d-models/rusty-airbase-fuel-tank-5ac257aee23e47e0a0f91a4e07a40692
- License: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
- Game derivative: `fuel.glb`
- Changes: normalized ground contact and scale; retained 2,532 triangles; resized the three 1024 px textures to 512 px. Four targets share the imported resource.

## Sovremenny-class destroyer

- Author: 42manako, https://sketchfab.com/42manako
- Source: https://sketchfab.com/3d-models/sovremenny-class-destroyer-bff5725e43b44a7595827c50b0b5f5cd
- License: CC BY 4.0, https://creativecommons.org/licenses/by/4.0/
- Game derivative: `ship.glb`
- Changes: collapse decimation to 15,102 triangles; normalized to a 120 m gameplay length around the authored waterline; resized textures to at most 512 px; disabled transmission. Two targets share the imported resource, do not cast real-time shadows and use opaque materials.

## Integration

Processing used Blender 5.2.1 and glTF 2.0 export. Target models are loaded only by level 4. Each target receives independent material instances for destruction tinting, while mesh and texture resources remain shared. Simplified hit volumes are defined in `scripts/ground_strike_target.gd`; the original 5 m gun and 6 m rocket tolerance is preserved.
