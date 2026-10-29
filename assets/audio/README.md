# Combat sounds

The three replacement MP3 files were supplied by the user on 2026-10-29.
They are copied byte for byte; the originals in Downloads are unchanged.

| Game file | Supplied file | Duration | Use |
| --- | --- | ---: | --- |
| `gun.mp3` | `machine gun.mp3` | 1.632 s | Player cannon burst |
| `missile.mp3` | `rocket.mp3` | 1.848 s | Guided rocket/missile launch |
| `explosion.mp3` | `explode.mp3` | 5.120 s | Target destruction |

`lock.mp3` retains the existing lock tone. Engine and wind loops are unchanged.

Air combat, pursuit and interception share `combat_director.gd`; ground attack
uses `ground_strike_director.gd`. Both load these same files. Cannon playback
uses `gun_fire_audio.gd`: one voice loops a private copy of the burst stream
while successful shots renew it. It fades out within 0.12 s of the last shot,
stops while the mission is held, and is disposed on restart. Rockets and
explosions remain nonlooping one-shot sounds at the existing volume levels.

`tests/test_weapon_audio.gd` verifies the real native audio path for both
directors, including sustained fire beyond the sample duration, release,
pause, empty ammunition, one-shots and restart cleanup. Run it without
`--headless`; gameplay headless tests deliberately skip sound loading.
