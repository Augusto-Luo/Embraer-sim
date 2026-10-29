extends AudioStreamPlayer

# The supplied sample is a continuous burst. Keep one voice alive only while
# actual shots are being emitted, instead of stacking the full burst per shot.
const RELEASE_SECONDS = 0.12
const FADE_SECONDS = 0.02
var remaining = 0.0
var firing_volume_db = -13.0


func configure(source: AudioStreamMP3) -> void:
	stream = source.duplicate()
	stream.loop = true
	max_polyphony = 1


func pulse(volume: float) -> void:
	remaining = RELEASE_SECONDS
	firing_volume_db = volume
	volume_db = firing_volume_db
	if not playing:
		play()


func _process(dt: float) -> void:
	var director = get_parent()
	var held = director.is_held() if director.has_method("is_held") else bool(director.hold)
	if held:
		remaining = 0.0
		stop()
		return
	remaining = maxf(0.0, remaining - dt)
	if remaining <= 0.0:
		stop()
	elif remaining < FADE_SECONDS:
		volume_db = firing_volume_db + linear_to_db(remaining / FADE_SECONDS)
