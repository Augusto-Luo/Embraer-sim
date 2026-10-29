extends RefCounted

const DEFAULTS = {
	"roll_rate": 2.0,
	"pitch_rate": 0.65,
	"yaw_rate": 0.30,
	"turn_coordination": 0.38,
	"speed_min": 45.0,
	"speed_max": 260.0,
	"thrust": 20.5,
	"drag": 0.00030,
	"throttle_response": 0.65,
	"throttle_brake_strength": 1.0,
	"input_response": 1.0,
	"stall_sink": 14.0,
	"camera_distance": 12.0,
	"camera_roll_follow": 0.22,
	"camera_fov_boost": 8.0,
	"camera_smoothing": 7.5,
	"audio_volume": 1.0,
	"invert_pitch": true,
	"view_sensitivity": 1.0,
	"gun_assist_strength": 0.65,
	"max_enemies": 3.0,
	"cloud_coverage": 0.65,
	"cloud_top": 2500.0,
	"cloud_quality": 1.0,
	"render_scale": 1.0,
	"fps_cap": 0,
	"volume_clouds": true,
	"sun_elevation": 24.0,
	"fog_density": 0.0,
	"hud_contrast": 0.65,
}

const FLIGHT_PRESET_KEYS = ["roll_rate", "pitch_rate", "yaw_rate", "turn_coordination", "input_response"]

const PRESETS = {
	"stable": {
		"roll_rate": 1.25,
		"pitch_rate": 0.45,
		"yaw_rate": 0.20,
		"turn_coordination": 0.28,
		"input_response": 0.75,
	},
	"agile": {
		"roll_rate": 3.0,
		"pitch_rate": 0.90,
		"yaw_rate": 0.45,
		"turn_coordination": 0.50,
		"input_response": 1.40,
	},
}

const KEY_DEFAULTS = {
	"throttle_up": KEY_UP,
	"throttle_down": KEY_DOWN,
	"roll_left": KEY_A,
	"roll_right": KEY_D,
	"pitch_up": KEY_W,
	"pitch_down": KEY_S,
	"yaw_left": KEY_Q,
	"yaw_right": KEY_E,
	"airbrake": KEY_SHIFT,
	"camera": KEY_C,
	"observe": KEY_V,
	"pause": KEY_P,
	"reset": KEY_R,
	"settings": KEY_TAB,
	"settings_close": KEY_ESCAPE,
	"help": KEY_H,
	"gun_fire": KEY_SPACE,
	"missile_fire": KEY_F,
	"target_next": KEY_T,
	"view_recenter": KEY_M,
	"cockpit": KEY_1,
	"cockpit_seat": KEY_2,
	"gear_toggle": KEY_G,
}

const PATH = "res://settings.cfg"
var storage_path = PATH
var values = DEFAULTS.duplicate()
var key_bindings = KEY_DEFAULTS.duplicate()
var profile_defaults = {}


func _init(path: String = PATH, defaults_override: Dictionary = {}) -> void:
	storage_path = path
	profile_defaults = defaults_override.duplicate()
	values.merge(profile_defaults, true)
	load_from_disk()


func load_from_disk() -> void:
	var config = ConfigFile.new()
	if config.load(storage_path) != OK:
		return
	for key in DEFAULTS:
		if not config.has_section_key("flight", key):
			continue
		var candidate = config.get_value("flight", key)
		if key == "max_enemies":
			values[key] = int(candidate)
		elif typeof(candidate) == typeof(DEFAULTS[key]):
			values[key] = candidate
	for action in KEY_DEFAULTS:
		if config.has_section_key("keybindings", action):
			var keycode = config.get_value("keybindings", action)
			if typeof(keycode) == TYPE_INT:
				key_bindings[action] = keycode


func save_to_disk() -> Error:
	var config = ConfigFile.new()
	for key in DEFAULTS:
		config.set_value("flight", key, values[key])
	for action in KEY_DEFAULTS:
		config.set_value("keybindings", action, key_bindings[action])
	var result = config.save(storage_path)
	if result != OK:
		push_warning("Unable to save flight settings: %s" % result)
	return result


func default_value(key: String) -> Variant:
	return profile_defaults.get(key, DEFAULTS.get(key))


func preset_values(name: String) -> Dictionary:
	if name not in ["stable", "balanced", "agile"]:
		return {}
	var preset = {}
	for key in FLIGHT_PRESET_KEYS:
		if name == "balanced":
			preset[key] = default_value(key)
		elif profile_defaults.is_empty():
			preset[key] = PRESETS[name][key]
		else:
			# Keep every handling preset relative to the transport profile.
			var scale = 0.8 if name == "stable" else 1.2
			preset[key] = float(default_value(key)) * scale
	return preset


func current_preset() -> String:
	for name in ["stable", "balanced", "agile"]:
		var preset = preset_values(name)
		var matches = true
		for key in FLIGHT_PRESET_KEYS:
			if not is_equal_approx(float(values[key]), float(preset[key])):
				matches = false
				break
		if matches:
			return name
	return "custom"


func apply_preset(name: String) -> Error:
	var preset = preset_values(name)
	if preset.is_empty():
		return ERR_INVALID_PARAMETER
	values.merge(preset, true)
	return save_to_disk()


func reset_section(keys: Array, actions: Array = []) -> Error:
	for key in keys:
		if DEFAULTS.has(key):
			values[key] = default_value(key)
	for action in actions:
		if KEY_DEFAULTS.has(action):
			key_bindings[action] = KEY_DEFAULTS[action]
	return save_to_disk()


func reset_defaults() -> Error:
	# The flight model holds these dictionaries, so preserve their references.
	return reset_section(DEFAULTS.keys(), KEY_DEFAULTS.keys())
