# Halloween / ECO-13 synthesized sound assets

These three mono PCM WAV files were created for Embraer sim on 2026-10-30 using deterministic Python standard-library synthesis. No external recordings, music, voices, libraries or source audio were used. They are project-original assets.

- `cabin-drone.wav`: a four-second seamless combination of sine harmonics at 45, 67.5 and 113 Hz with a slow amplitude envelope. Used quietly under the existing engine and wind.
- `radio-static.wav`: a 0.95-second seeded noise burst with a 960 Hz carrier, envelope and band-emphasizing difference filter. It is a nonverbal radio cue.
- `echo-ping.wav`: a 1.8-second decaying 420/630 Hz dual tone with two quieter delayed repeats. It is a nonverbal identification cue.

Format: 22,050 Hz, mono, 16-bit PCM. Conversion: directly generated and written as WAV; Godot imports the files. These sounds contain no speech; all radio dialogue is readable in the mission HUD.

## Encounter additions

The following original sounds were synthesized for this project on 2026-10-30. Source: the included `generate_encounter_audio.py`, which uses seeded noise, oscillators, envelopes, simple filters and delayed tails from the Python standard library. No external recording, voice, sample pack or AI audio service is used. These three additions are made available under CC0 1.0 Universal: https://creativecommons.org/publicdomain/zero/1.0/ .

| File | Duration | Synthesis and use |
| --- | ---: | --- |
| `thunder-far.wav` | 6.0 s | Low-pass seeded noise with 37/53 Hz harmonics, a slow roll and quiet delayed tails; distant thunder after lightning. |
| `thunder-near.wav` | 5.5 s | A brief filtered crack followed by 31/47 Hz rumble and delayed tails; the nearer second thunder. |
| `pressure-pass.wav` | 7.0 s | A 27–37 Hz bass sweep with filtered displaced-air noise and soft onset/decay; a low passing-pressure cue under the engine and wind. |

All additions are 22,050 Hz, mono, 16-bit PCM WAV. They are generated directly in that format, with peaks normalized below clipping and soft endpoint fades. Run `python3 assets/audio/halloween/generate_encounter_audio.py` from the project root to reproduce them. Godot loads the six small mission samples once when the audio node enters the scene; timed cue playback performs no disk loading. The controller's existing master volume applies to all voices; pause, settings, observation and restart use the same hold/cleanup path.
