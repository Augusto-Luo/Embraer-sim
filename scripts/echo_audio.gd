extends Node

# Original synthesized samples are loaded once before the encounter begins.
const AUDIO_ROOT = "res://assets/audio/halloween/"
const SAMPLE_FILES = {
	"static": "radio-static.wav",
	"echo": "echo-ping.wav",
	"thunder_far": "thunder-far.wav",
	"thunder_near": "thunder-near.wav",
	"pressure": "pressure-pass.wav",
}
const CUE_DB = {"static": -27.0, "echo": -30.0, "thunder_far": -29.0, "thunder_near": -22.0, "pressure": -29.0}
var controller
var drone: AudioStreamPlayer
var cue_players: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var current_stage = "night_flight"
var held = true
var next_voice = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for kind in SAMPLE_FILES:
		var sample = load(AUDIO_ROOT + SAMPLE_FILES[kind])
		if sample is AudioStream:
			samples[kind] = sample
	drone = AudioStreamPlayer.new()
	var source = load(AUDIO_ROOT + "cabin-drone.wav")
	if source is AudioStreamWAV:
		var loop: AudioStreamWAV = source.duplicate()
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		drone.stream = loop
	add_child(drone)
	drone.volume_db = -43.0
	if drone.stream != null:
		drone.play()
	# Pressure, thunder and radio can overlap without interrupting one another.
	for index in range(6):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		cue_players.append(voice)
	set_held(held)


func restart() -> void:
	current_stage = "night_flight"
	next_voice = 0
	for voice in cue_players:
		voice.stop()
		voice.stream = null
	if drone != null:
		drone.stop()
		drone.volume_db = -43.0
		if drone.stream != null:
			drone.play()
	set_held(held)


func audio_enabled() -> bool:
	return controller != null and float(controller.settings.values.audio_volume) > 0.0


func play_cue(kind: String) -> void:
	if held or not audio_enabled() or cue_players.is_empty() or not samples.has(kind):
		return
	var slot: AudioStreamPlayer = null
	for voice in cue_players:
		if not voice.playing:
			slot = voice
			break
	if slot == null:
		slot = cue_players[next_voice]
		next_voice = (next_voice + 1) % cue_players.size()
	slot.stop()
	slot.stream = samples[kind]
	var volume = float(CUE_DB.get(kind, -30.0))
	slot.set_meta("cue_db", volume)
	slot.set_meta("cue_kind", kind)
	slot.volume_db = volume
	slot.stream_paused = false
	slot.play()


func set_held(value: bool) -> void:
	held = value
	if drone != null:
		drone.stream_paused = held
	for voice in cue_players:
		voice.stream_paused = held


func _process(dt: float) -> void:
	if drone == null:
		return
	var enabled = audio_enabled()
	var active = current_stage in ["contact", "escort", "lost_contact", "monster_reveal"]
	var target_db = -80.0 if not enabled else (-38.0 if active else -43.0)
	if not held:
		drone.volume_db = move_toward(drone.volume_db, target_db, dt * 5.0)
	for voice in cue_players:
		voice.volume_db = float(voice.get_meta("cue_db", -30.0)) if enabled else -80.0


func _exit_tree() -> void:
	if is_instance_valid(drone):
		drone.stop()
		drone.stream = null
	for voice in cue_players:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
	samples.clear()
