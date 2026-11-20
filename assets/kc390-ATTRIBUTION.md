# KC-390 training target attribution

- Original title: **Embraer KC-390 "Millennium"**
- Author: **KOG_THORNS** — https://sketchfab.com/ioai25312
- Source: https://sketchfab.com/3d-models/embraer-kc-390-millennium-ed745ffba2fe45b796cbc833116e3adc
- License: **Creative Commons Attribution 4.0 International (CC BY 4.0)** — https://creativecommons.org/licenses/by/4.0/

The author, source and license above were embedded in the user-supplied GLB.

`kc390-training.glb` is a modified version for this project's high-altitude chase training. Modifications: removed explicit cabin/cockpit contents, extended landing-gear meshes and invisible source-title geometry; reduced textures to a maximum of 512 px; removed extra PBR texture channels; made cockpit glass opaque; retained the exterior silhouette; baked transforms and centered the model in metres, with +Y up and +Z forward. These modifications were made for this project on 2026-10-27.

Rebuild with `python3 tools/optimize_kc390.py /path/to/embraer_kc-390_millennium.glb assets/kc390-training.glb`. See `kc390-training.report.json` for the optimization measurements.

## Cockpit runtime modifications (2026-10-30; HUD reuse 2026-11-02)

Levels 1 and 5 reuse the existing cockpit and original HUD-combiner meshes in `kc390-training-ready.glb`. In level 5 only, runtime material copies add dim green/amber backlighting to the original `painel` button and legend atlas. The panel background, model geometry and source GLB are not repainted or relocated. A low-energy local instrument wash is restricted to cockpit receivers. This night lighting and the encounter presentation remain exclusive to level 5; level 1 receives only the glass HUD reuse. Its ground operations, flight controls and transport parameters remain unchanged. Levels 2–4 retain their existing behavior.

The original combiner glass keeps its existing position and aperture. Its material is made more transparent and less green; only the HUD symbols emit light. Project-original `scripts/echo_hud_combiner.gd`, `scripts/echo_hud_symbology.gd` and `shaders/echo_hud_combiner.gdshader` are shared by levels 1 and 5, retaining their `echo_*` filenames to keep reuse limited. They generate a transparent instrument texture and project it by viewing direction, approximating a collimated optical display. This is a simplified simulation, not an exact reproduction of the KC-390's factory HUD or avionics. The source glass is offset from the aircraft boresight, so the true flight-path vector can fall outside its aperture; the display does not artificially center it.

The HUD contains only IAS in knots, barometric altitude in feet, heading, a pitch ladder, the flight-path vector derived from actual flight telemetry, vertical speed in feet per minute, and GEAR/BRAKE/STALL indications. Existing onboard MFD content and units are retained. In both levels, the left pilot and right copilot seats use their corresponding glass; instructor/exterior views and the level-5 reveal camera suppress the symbols. In level-5 `free_flight`, looking away with the mouse naturally removes the physical glass from view. This HUD reuse does not enable cockpit mouse-look in level 1. Pause and settings controls remain available, without restoring the former large screen-space tapes, attitude ladder or radar.

The HUD and cockpit-lighting scripts/shaders are original project code; they add no new external models, recordings, textures or fonts. The HUD reuses the bundled VT323 font under `fonts/VT323-OFL.txt`. All original model author, source and CC BY 4.0 license credits above remain applicable and unchanged.
