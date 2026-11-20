extends "res://scripts/flight_settings.gd"

# Mission 05 now flies a transport. Convert legacy fighter preferences in memory.
# The settings file is only updated when the user chooses to edit settings.
const KCProfile = preload("res://scripts/transport_profile.gd")
const LEGACY = {
	"roll_rate": 2.0, "pitch_rate": 0.65, "yaw_rate": 0.29,
	"turn_coordination": 0.38, "input_response": 1.0,
	"thrust": 20.5, "drag": 0.0003, "speed_min": 45.0,
	"speed_max": 260.0, "throttle_response": 0.65,
	"throttle_brake_strength": 1.0, "stall_sink": 14.0,
}

func _init() -> void:
	var profile = KCProfile.SETTINGS.duplicate()
	profile["camera_distance"] = 24.0
	super._init("res://settings-level5.cfg", profile)
	var config = ConfigFile.new()
	if config.load(storage_path) != OK or int(config.get_value("mission", "echo_profile_version", 0)) >= 1:
		return
	for key in LEGACY:
		if not config.has_section_key("flight", key):
			continue
		values[key] = float(KCProfile.SETTINGS[key]) * float(values[key]) / float(LEGACY[key])
	if config.has_section_key("flight", "camera_distance"):
		values.camera_distance = clamp(float(values.camera_distance) * 24.0 / 11.5, 8.0, 32.0)

func save_to_disk() -> Error:
	var result = super.save_to_disk()
	if result != OK:
		return result
	var config = ConfigFile.new()
	result = config.load(storage_path)
	if result != OK:
		return result
	config.set_value("mission", "echo_profile_version", 1)
	return config.save(storage_path)
