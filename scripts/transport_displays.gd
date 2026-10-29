extends "res://scripts/cockpit_displays.gd"


func _init() -> void:
	screen_shader = preload("res://shaders/mfd_screen_raw.gdshader")


func _setup() -> void:
	create_screen("DYNAMIC_MFD_LEFT", "navigation", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_CENTER_RIGHT", "engine", Vector2i(512, 512))
	create_screen("DYNAMIC_MFD_RIGHT", "fms", Vector2i(512, 512))
