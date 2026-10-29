# KC-390 training target attribution

- Original title: **Embraer KC-390 "Millennium"**
- Author: **KOG_THORNS** — https://sketchfab.com/ioai25312
- Source: https://sketchfab.com/3d-models/embraer-kc-390-millennium-ed745ffba2fe45b796cbc833116e3adc
- License: **Creative Commons Attribution 4.0 International (CC BY 4.0)** — https://creativecommons.org/licenses/by/4.0/

The author, source and license above were embedded in the user-supplied GLB.

`kc390-training.glb` is a modified version for this project's high-altitude chase training. Modifications: removed explicit cabin/cockpit contents, extended landing-gear meshes and invisible source-title geometry; reduced textures to a maximum of 512 px; removed extra PBR texture channels; made cockpit glass opaque; retained the exterior silhouette; baked transforms and centered the model in metres, with +Y up and +Z forward. These modifications were made for this project on 2026-10-27.

Rebuild with `python3 tools/optimize_kc390.py /path/to/embraer_kc-390_millennium.glb assets/kc390-training.glb`. See `kc390-training.report.json` for the optimization measurements.
