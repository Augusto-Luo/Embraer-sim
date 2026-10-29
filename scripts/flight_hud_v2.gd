extends Control

signal camera_requested
signal pause_requested
signal reset_requested
signal settings_requested

const INK = Color(0.40, 1.0, 0.60, 0.98)
const MUTED = Color(0.45, 1.0, 0.68, 0.92)
const BRIGHT = Color(0.72, 1.0, 0.82, 1.0)
const AMBER = Color(1.0, 0.78, 0.46, 0.98)
const INSTRUMENT_FONT = preload("res://assets/fonts/VT323-Regular.ttf")
const PORTRAIT_TEXTURE = preload("res://assets/portraits/range_ctrl_hologram.png")
var state = {}
var combat = {}
var combat_enabled = true
var map_preview = false
var ground_attack = false
var pursuit_mode = false
var free_look_active = false
var contrast = 0.65
var paused = false
var wide = false
var camera_button
var pause_button
var restart_button
var settings_button
var help_label
var help_visible = true
var help_elapsed = 0.0
var last_size = Vector2.ZERO
var redraw_elapsed = 0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    camera_button = make_button("CHASE [C]", "camera")
    pause_button = make_button("PAUSE [P]", "pause")
    restart_button = make_button("RESTART [R]", "reset")
    settings_button = make_button("SETTINGS [TAB]", "settings")
    help_label = Label.new()
    help_label.text = "H HELP  ·  RMB LOOK  ·  M RESET VIEW  ·  T TARGET  ·  SPACE GUN  ·  F MISSILE  ·  V OBSERVE" if combat_enabled else "H HELP  ·  UP/DOWN THROTTLE  ·  Q/E STEER  ·  RMB LOOK  ·  V OBSERVE"
    if map_preview:
        help_label.text = "H HELP  ·  RMB LOOK  ·  V OBSERVE  ·  R RESTART"
    elif ground_attack:
        help_label.text = "T TARGET  ·  SPACE GUN  ·  F GUIDED ROCKET  ·  H HELP  ·  R RESTART"
    help_label.add_theme_font_override("font", INSTRUMENT_FONT)
    help_label.add_theme_font_size_override("font_size", 11)
    help_label.add_theme_color_override("font_color", MUTED)
    help_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.055, 0.035, 0.90))
    help_label.add_theme_constant_override("shadow_offset_x", 1)
    help_label.add_theme_constant_override("shadow_offset_y", 1)
    help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(help_label)


func make_button(label: String, action: String) -> Button:
    var button = Button.new()
    button.text = label
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_override("font", INSTRUMENT_FONT)
    button.add_theme_font_size_override("font_size", 11)
    button.add_theme_color_override("font_color", BRIGHT)
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color(0.02, 0.08, 0.055, 0.66)
    normal.border_color = Color(0.66, 0.90, 0.76, 0.28)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(2)
    var hover = normal.duplicate()
    hover.bg_color = Color(0.06, 0.16, 0.11, 0.86)
    hover.border_color = Color(0.82, 0.96, 0.87, 0.72)
    var pressed = normal.duplicate()
    pressed.bg_color = Color(0.10, 0.24, 0.16, 0.94)
    var focus = normal.duplicate()
    focus.border_color = Color(0.90, 1.0, 0.94, 0.95)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", focus)
    button.pressed.connect(_on_button_pressed.bind(action))
    add_child(button)
    return button


func _on_button_pressed(action: String) -> void:
    match action:
        "camera": camera_requested.emit()
        "pause": pause_requested.emit()
        "reset": reset_requested.emit()
        "settings": settings_requested.emit()


func set_settings_open(value: bool) -> void:
    settings_button.text = "CLOSE [ESC]" if value else "SETTINGS [TAB]"


func set_camera_mode(value: bool) -> void:
    wide = value
    camera_button.text = "WIDE [C]" if wide else "CHASE [C]"


func set_paused(value: bool) -> void:
    paused = value
    pause_button.text = "RESUME [P]" if paused else "PAUSE [P]"
    queue_redraw()


func toggle_help() -> void:
    help_visible = not help_visible
    help_elapsed = 0.0
    help_label.visible = help_visible


func update_contrast(value: float) -> void:
    contrast = clamp(value, 0.0, 1.0)


func update_state(value: Dictionary) -> void:
    state = value


func update_training_keys(bindings: Dictionary) -> void:
    if combat_enabled or help_label == null:
        return
    var up = OS.get_keycode_string(int(bindings.throttle_up)).to_upper()
    var down = OS.get_keycode_string(int(bindings.throttle_down)).to_upper()
    var gear = OS.get_keycode_string(int(bindings.gear_toggle)).to_upper()
    help_label.text = "H HELP  ·  %s THR +  ·  %s THR -  ·  %s GEAR  ·  RMB LOOK" % [up, down, gear]
    last_size = Vector2.ZERO


func update_combat(value: Dictionary) -> void:
    combat = value


func set_free_look(active: bool) -> void:
    free_look_active = active


func _process(dt: float) -> void:
    if last_size != size:
        last_size = size
        layout()
    if help_visible:
        help_elapsed += dt
        if help_elapsed > 8.0:
            help_visible = false
            help_label.visible = false
    redraw_elapsed += dt
    if redraw_elapsed >= 1.0 / 30.0:
        redraw_elapsed = 0.0
        queue_redraw()


func layout() -> void:
    var margin = max(22.0, size.x * 0.025)
    restart_button.position = Vector2(size.x - margin - 432, 20)
    restart_button.size = Vector2(108, 28)
    camera_button.position = Vector2(size.x - margin - 316, 20)
    camera_button.size = Vector2(96, 28)
    pause_button.position = Vector2(size.x - margin - 212, 20)
    pause_button.size = Vector2(96, 28)
    settings_button.position = Vector2(size.x - margin - 108, 20)
    settings_button.size = Vector2(108, 28)
    var help_width = help_label.get_minimum_size().x
    help_label.position = Vector2((size.x - help_width) * 0.5, size.y - 34)


func text(position: Vector2, value: String, font_size: int = 13, color: Color = INK) -> void:
    var scaled_size = int(round(font_size * (1.18 if font_size >= 18 else 1.10)))
    var glow = Color(0.18, 1.0, 0.42, color.a * 0.22)
    draw_string(INSTRUMENT_FONT, position + Vector2(0.4, 0.4), value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, glow)
    var shadow = Color(0.0, 0.055, 0.035, color.a * 0.95)
    draw_string(INSTRUMENT_FONT, position + Vector2(1, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, shadow)
    draw_string(INSTRUMENT_FONT, position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled_size, color)


func panel(rect: Rect2, border: bool = true) -> void:
    var background = Color(0.005, 0.035, 0.025, 0.20 + contrast * 0.45)
    draw_rect(rect, background, true)
    if border:
        draw_rect(rect, Color(0.18, 1.0, 0.42, 0.12), false, 3.0)
        draw_rect(rect, Color(0.32, 1.0, 0.58, 0.54), false, 1.0)


func glow_line(from: Vector2, to: Vector2, color: Color, width: float = 1.2) -> void:
    draw_line(from, to, Color(0.18, 1.0, 0.42, color.a * 0.18), width + 2.0, true)
    draw_line(from, to, color, width, true)


func dash_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
    var delta = to - from
    var length = delta.length()
    if length <= 0.0:
        return
    var direction = delta / length
    var offset = 0.0
    while offset < length:
        var end = min(offset + 5.0, length)
        glow_line(from + direction * offset, from + direction * end, color, width)
        offset += 9.0


func format_time(seconds: float) -> String:
    var total = max(0, int(seconds))
    return "%02d:%02d" % [int(total / 60), total % 60]


func corner_box(center: Vector2, half: float, color: Color) -> void:
    var left = center.x - half
    var right = center.x + half
    var top = center.y - half
    var bottom = center.y + half
    var length = half * 0.45
    for x_sign in [-1.0, 1.0]:
        for y_sign in [-1.0, 1.0]:
            var corner = Vector2(center.x + x_sign * half, center.y + y_sign * half)
            draw_line(corner, corner - Vector2(x_sign * length, 0), color, 1.4, true)
            draw_line(corner, corner - Vector2(0, y_sign * length), color, 1.4, true)
    draw_line(Vector2(left, center.y), Vector2(left + 5, center.y), color, 1.2, true)
    draw_line(Vector2(right - 5, center.y), Vector2(right, center.y), color, 1.2, true)


func aircraft_icon(center: Vector2) -> void:
    # Nose-up EMB-314 outline, traced from a top-down Super Tucano reference.
    var nose = center + Vector2(0, -52)
    for angle in [0.0, 72.0, 144.0, 216.0, 288.0]:
        var direction = Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
        glow_line(nose, nose + direction * 9.0, BRIGHT, 1.0)
    draw_arc(nose, 2.0, 0.0, TAU, 12, BRIGHT, 1.0, true)

    var left = [Vector2(0, -52), Vector2(-2, -48), Vector2(-3, -40), Vector2(-4, -28), Vector2(-4, -16), Vector2(-5, -8), Vector2(-5, 16), Vector2(-3, 30), Vector2(-3, 42), Vector2(0, 48)]
    var right = [Vector2(0, -52), Vector2(2, -48), Vector2(3, -40), Vector2(4, -28), Vector2(4, -16), Vector2(5, -8), Vector2(5, 16), Vector2(3, 30), Vector2(3, 42), Vector2(0, 48)]
    for index in range(left.size() - 1):
        glow_line(center + left[index], center + left[index + 1], BRIGHT, 1.0)
        glow_line(center + right[index], center + right[index + 1], BRIGHT, 1.0)

    # Long tandem canopy and tapered low wing.
    glow_line(center + Vector2(-2, -34), center + Vector2(-3, -16), MUTED, 1.0)
    glow_line(center + Vector2(3, -16), center + Vector2(2, -34), MUTED, 1.0)
    glow_line(center + Vector2(-3, -16), center + Vector2(3, -16), MUTED, 1.0)
    for side in [-1, 1]:
        glow_line(center + Vector2(side * 5, -22), center + Vector2(side * 48, -16), BRIGHT, 1.0)
        glow_line(center + Vector2(side * 48, -16), center + Vector2(side * 48, 0), BRIGHT, 1.0)
        glow_line(center + Vector2(side * 48, 0), center + Vector2(side * 5, -2), BRIGHT, 1.0)
        glow_line(center + Vector2(side * 5, -2), center + Vector2(side * 5, -22), BRIGHT, 1.0)

    # Smaller horizontal stabilizer and a single vertical fin.
    for side in [-1, 1]:
        glow_line(center + Vector2(side * 3, 32), center + Vector2(side * 20, 40), BRIGHT, 1.0)
        glow_line(center + Vector2(side * 20, 40), center + Vector2(side * 20, 45), BRIGHT, 1.0)
        glow_line(center + Vector2(side * 20, 45), center + Vector2(side * 3, 44), BRIGHT, 1.0)
        glow_line(center + Vector2(side * 3, 44), center + Vector2(side * 3, 32), BRIGHT, 1.0)
    glow_line(center + Vector2(0, 30), center + Vector2(-3, 44), BRIGHT, 1.0)
    glow_line(center + Vector2(-3, 44), center + Vector2(0, 48), BRIGHT, 1.0)
    glow_line(center + Vector2(0, 48), center + Vector2(3, 44), BRIGHT, 1.0)
    glow_line(center + Vector2(3, 44), center + Vector2(0, 30), BRIGHT, 1.0)

    # Two lengthwise stores per wing: teardrop tank inboard, finned store outboard.
    for side in [-1, 1]:
        var inner = center + Vector2(side * 54, -2)
        var tank_points = [
            inner + Vector2(0, -12),
            inner + Vector2(side * 2.5, -6),
            inner + Vector2(side * 2.5, 8),
            inner + Vector2(0, 14),
            inner + Vector2(-side * 2.5, 8),
            inner + Vector2(-side * 2.5, -6),
        ]
        for index in range(tank_points.size()):
            glow_line(tank_points[index], tank_points[(index + 1) % tank_points.size()], MUTED, 1.0)
        var outer = center + Vector2(side * 32, 24)
        glow_line(outer + Vector2(0, -10), outer + Vector2(0, 12), MUTED, 1.0)
        glow_line(outer + Vector2(-3, -7), outer + Vector2(3, -7), MUTED, 1.0)
        glow_line(outer + Vector2(-4, 10), outer + Vector2(4, 10), MUTED, 1.0)
        glow_line(outer + Vector2(-4, 12), outer + Vector2(4, 12), MUTED, 1.0)


func draw_enemy_name_tag(contact: Dictionary, screen: Vector2, selected: bool) -> void:
    var label_size = Vector2(124, 48) if selected else Vector2(92, 28)
    var label_origin = screen + (Vector2(36, -18) if selected else Vector2(12, -12))
    label_origin.x = clamp(label_origin.x, 8.0, size.x - label_size.x - 8.0)
    label_origin.y = clamp(label_origin.y, 108.0, size.y - label_size.y - 96.0)
    var color = (AMBER if combat.get("locked", false) else BRIGHT) if selected else MUTED
    draw_rect(Rect2(label_origin, label_size), Color(0.005, 0.030, 0.020, 0.86), true)
    draw_rect(Rect2(label_origin, label_size), Color(color, 0.58), false, 1.0)
    if selected:
        text(label_origin + Vector2(7, 21), str(contact.id), 18, color)
        text(label_origin + Vector2(7, 40), "%.1f KM" % (float(contact.distance) / 1000.0), 13, MUTED)
    else:
        text(label_origin + Vector2(6, 19), str(contact.id), 14, color)


func draw_pursuit_target(contact: Dictionary) -> void:
    var point: Vector2 = contact.screen
    # Keep the aircraft itself clear of lock rings, pitch ticks and text.
    draw_rect(Rect2(point - Vector2(29, 29), Vector2(58, 58)), Color(0.01, 0.025, 0.02, 0.7), false, 3.0)
    corner_box(point, 29.0, AMBER)
    var label_origin = point + Vector2(44, -46)
    label_origin.x = clamp(label_origin.x, 12.0, size.x - 162.0)
    label_origin.y = clamp(label_origin.y, 130.0, size.y - 120.0)
    draw_rect(Rect2(label_origin, Vector2(150, 64)), Color(0.01, 0.035, 0.025, 0.90), true)
    draw_rect(Rect2(label_origin, Vector2(150, 64)), Color(AMBER, 0.48), false, 1.0)
    text(label_origin + Vector2(9, 24), str(contact.id), 21, AMBER)
    text(label_origin + Vector2(9, 47), "%.0f M" % contact.distance, 15, BRIGHT)
    text(label_origin + Vector2(91, 47), "LOCK" if combat.get("locked", false) else "TRACK", 12, MUTED)


func draw_gun_reticle(fallback_center: Vector2) -> void:
    if not combat.get("gun_reticle_visible", true):
        return
    var point: Vector2 = combat.get("gun_reticle_screen", fallback_center)
    var snapped = combat.get("reticle_snapped", false)
    var color = AMBER if snapped else BRIGHT
    var radius = 10.0 if snapped else 7.0
    draw_arc(point, radius, 0.0, TAU, 28, color, 1.8 if snapped else 1.1, true)
    glow_line(point + Vector2(-23, 0), point + Vector2(-radius - 4, 0), color, 1.3)
    glow_line(point + Vector2(radius + 4, 0), point + Vector2(23, 0), color, 1.3)
    glow_line(point + Vector2(0, -23), point + Vector2(0, -radius - 4), color, 1.3)
    draw_circle(point, 1.4, color)
    if snapped:
        text(point + Vector2(-38, 39), "AIM HOLD %.1f" % float(combat.get("gun_assist_remaining", 0.0)), 12, AMBER)
    elif combat.get("gun_assist", false):
        text(point + Vector2(-28, 35), "AIM PULL", 11, BRIGHT)


func offscreen_edge(direction: Vector2) -> Vector2:
    var center = Vector2(size.x * 0.5, size.y * 0.5)
    var margin = max(22.0, size.x * 0.025)
    var left = margin + 34.0
    var right = size.x - margin - 190.0
    var top = 124.0
    var bottom = size.y - 142.0
    var ray = direction.normalized()
    if ray.length_squared() < 0.001:
        ray = Vector2.DOWN
    var candidates = []
    if ray.x > 0.0001:
        candidates.append((right - center.x) / ray.x)
    elif ray.x < -0.0001:
        candidates.append((left - center.x) / ray.x)
    if ray.y > 0.0001:
        candidates.append((bottom - center.y) / ray.y)
    elif ray.y < -0.0001:
        candidates.append((top - center.y) / ray.y)
    var distance = INF
    for candidate in candidates:
        if candidate > 0.0:
            distance = min(distance, candidate)
    return center + ray * (distance if is_finite(distance) else 0.0)


func draw_offscreen_contact(contact: Dictionary, index: int) -> void:
    var direction: Vector2 = contact.get("indicator_direction", Vector2.DOWN)
    if direction.length_squared() < 0.001:
        direction = Vector2.DOWN
    direction = direction.normalized()
    var edge = offscreen_edge(direction)
    var selected = bool(contact.get("selected", false))
    var attacking = bool(contact.get("attacking", false))
    var color = AMBER if selected or attacking else BRIGHT
    var tangent = Vector2(-direction.y, direction.x)
    var lane = float((index % 5) - 2) * 44.0
    if abs(direction.y) > 0.70:
        lane *= 3.4
    var label_size = Vector2(148, 44)
    var label_center = edge - direction * 38.0 + tangent * lane
    var label_position = label_center - label_size * 0.5
    label_position.x = clamp(label_position.x, 8.0, size.x - label_size.x - 8.0)
    label_position.y = clamp(label_position.y, 108.0, size.y - label_size.y - 104.0)
    draw_rect(Rect2(label_position, label_size), Color(0.005, 0.025, 0.018, 0.90), true)
    draw_rect(Rect2(label_position, label_size), Color(color, 0.82), false, 1.2)

    var tip = edge + direction * 13.0
    var base = edge - direction * 9.0
    var shoulder = tangent * (10.0 if selected else 8.0)
    var arrow = PackedVector2Array([tip, base + shoulder, base - shoulder])
    draw_polygon(arrow, PackedColorArray([Color(color, 0.38)]))
    for corner in range(3):
        glow_line(arrow[corner], arrow[(corner + 1) % 3], color, 2.4 if selected else 1.8)

    text(label_position + Vector2(8, 20), str(contact.id), 16, color)
    if selected:
        text(label_position + Vector2(114, 19), "TGT", 11, AMBER)
    var tag = "ATK" if attacking else ("REAR" if contact.get("behind", false) else "OFF")
    text(label_position + Vector2(8, 36), "%.1f KM  %s" % [float(contact.distance) / 1000.0, tag], 12, color)


func draw_ground_contact(contact: Dictionary) -> void:
    if not contact.on_screen:
        if contact.selected:
            draw_offscreen_contact(contact, 2)
        return
    var point: Vector2 = contact.screen
    if contact.selected:
        corner_box(point, 24.0, AMBER if combat.get("locked", false) else INK)
        var progress = float(combat.get("lock_progress", 0.0))
        draw_arc(point, 31.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, AMBER, 1.4, true)
        text(point + Vector2(34, -20), str(contact.id), 16, BRIGHT)
        text(point + Vector2(34, -3), "%.0f M" % float(contact.distance), 12, MUTED)
        var hp = float(contact.get("hp", combat.get("target_hp", 0.0)))
        var hp_max = maxf(1.0, float(contact.get("max_hp", 120.0)))
        var bar = Rect2(point + Vector2(34, 5), Vector2(72, 4))
        draw_rect(bar, Color(0.005, 0.025, 0.018, 0.85))
        draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp / hp_max, bar.size.y)), AMBER)
        text(point + Vector2(34, 25), "LOCK" if combat.get("locked", false) else "TRACK %d%%" % int(progress * 100.0), 10, AMBER)
    else:
        draw_rect(Rect2(point - Vector2(5, 5), Vector2(10, 10)), MUTED, false, 1.0)


func draw_strike_sites(origin: Vector2) -> void:
    panel(Rect2(origin, Vector2(208, 79)))
    text(origin + Vector2(12, 20), "MANUAL AIM", 13, BRIGHT)
    for index in range(combat.get("sites", []).size()):
        var site = combat.sites[index]
        text(origin + Vector2(12, 42 + index * 22), "%s  %d/%d" % [str(site.get("name", "SITE")), int(site.get("destroyed", 0)), int(site.get("total", 4))], 12, MUTED)


func _draw() -> void:
    if state.is_empty():
        return
    var margin = max(22.0, size.x * 0.025)
    text(Vector2(margin, 32), "TIME " + format_time(state.get("time", 0.0)), 12, MUTED)
    if ground_attack:
        text(Vector2(margin, 52), "TARGETS %d/%d" % [int(combat.get("destroyed_targets", 0)), int(combat.get("total_targets", 8))], 12, INK)
        text(Vector2(margin, 72), "DESTRUCTION %d%%" % int(round(float(combat.get("destruction", 0.0)) * 100.0)), 12, INK)
        draw_strike_sites(Vector2(margin, 152))
    elif combat_enabled:
        text(Vector2(margin, 52), "KILLS %d" % int(combat.get("kills", 0)), 12, MUTED)
        text(Vector2(margin, 72), "TGT: " + str(combat.get("target_id", "---")), 12, INK)
    else:
        text(Vector2(margin, 52), "ISLAND RECON / MAP PREVIEW" if map_preview else "AIRFIELD / RWY 36", 12, INK)
    text(Vector2(margin, 92), "INVINCIBLE TRAINING / " + ("EMB-314" if combat_enabled or map_preview else "KC-390"), 10, MUTED)

    if ground_attack:
        var message = str(combat.get("comms_text", ""))
        if combat.get("completed", false):
            message = "ALL TARGETS DESTROYED"
        if not message.is_empty():
            var message_width = maxf(220.0, float(message.length()) * 8.0 + 24.0)
            var message_origin = Vector2((size.x - message_width) * 0.5, 20)
            panel(Rect2(message_origin, Vector2(message_width, 34)))
            text(message_origin + Vector2(12, 23), message, 15, AMBER if combat.get("completed", false) else BRIGHT)
    elif combat_enabled:
        text(Vector2(size.x * 0.5 - 70, 30), str(combat.get("comms_name", "RANGE CONTROL")), 12, MUTED)
        text(Vector2(size.x * 0.5 - 116, 52), "<< " + str(combat.get("comms_text", "TRAINING AIRSPACE")) + " >>", 13, INK)
        var portrait = Rect2(Vector2(size.x - margin - 142, 62), Vector2(142, 112))
        panel(portrait)
        var portrait_image = Rect2(portrait.position + Vector2(5, 5), Vector2(132, 80))
        draw_texture_rect_region(PORTRAIT_TEXTURE, portrait_image, Rect2(32, 32, 960, 600), Color(0.82, 1.0, 0.88, 0.96))
        for scan_y in range(int(portrait_image.position.y) + 2, int(portrait_image.end.y), 4):
            glow_line(Vector2(portrait_image.position.x, scan_y), Vector2(portrait_image.end.x, scan_y), Color(0.20, 0.85, 0.42, 0.10), 0.6)
        draw_rect(portrait_image, Color(0.35, 1.0, 0.58, 0.42), false, 1.0)
        text(portrait.position + Vector2(12, 96), "RANGE CTRL", 11, INK)
        text(portrait.position + Vector2(12, 108), "TEST RANGE", 8, MUTED)

    var speed_position = Vector2(size.x * 0.32, size.y * 0.31)
    panel(Rect2(speed_position + Vector2(-9, -4), Vector2(92, 66)))
    text(speed_position, "SPEED", 12, MUTED)
    text(speed_position + Vector2(0, 28), str(int(state.get("speedKmh", 0.0))), 23, BRIGHT)
    text(speed_position + Vector2(0, 50), "KM/H", 9, MUTED)

    var alt_position = Vector2(size.x * 0.68, size.y * 0.31)
    panel(Rect2(alt_position + Vector2(-9, -4), Vector2(92, 66)))
    text(alt_position, "ALT", 12, MUTED)
    text(alt_position + Vector2(0, 28), str(int(state.get("position", [0, 0, 0])[1])), 23, BRIGHT)
    text(alt_position + Vector2(0, 50), "MSL / M", 9, MUTED)

    var center = Vector2(size.x * 0.5, size.y * 0.48)
    var pitch_deg = rad_to_deg(state.get("pitch", 0.0))
    var bank_deg = rad_to_deg(state.get("bank", 0.0))
    if not pursuit_mode:
        draw_arc(center, 54.0, -deg_to_rad(30.0 + bank_deg), deg_to_rad(30.0 - bank_deg), 20, MUTED, 1.0, true)
    draw_set_transform(center, -state.get("bank", 0.0), Vector2.ONE)
    for ladder_angle in ([] if pursuit_mode else [-20, -10, 0, 10, 20]):
        var y = (pitch_deg - ladder_angle) * 2.2
        var label = "%+d" % ladder_angle if ladder_angle != 0 else "0"
        glow_line(Vector2(-98, y), Vector2(-42, y), MUTED, 1.0)
        glow_line(Vector2(42, y), Vector2(98, y), MUTED, 1.0)
        glow_line(Vector2(-98, y), Vector2(-98, y + 5), MUTED, 1.0)
        glow_line(Vector2(98, y), Vector2(98, y + 5), MUTED, 1.0)
        text(Vector2(-122, y + 4), label, 8, MUTED)
        text(Vector2(104, y + 4), label, 8, MUTED)
    draw_set_transform(Vector2.ZERO)
    text(center + Vector2(-48, 64), "P %d°  B %d°" % [int(pitch_deg), int(bank_deg)], 11, MUTED)

    if free_look_active:
        var notice = Vector2(size.x * 0.5 - 82, 102)
        panel(Rect2(notice, Vector2(164, 28)))
        text(notice + Vector2(12, 19), "FREE LOOK · M RESET", 11, AMBER)

    var offscreen_index = 0
    for contact in combat.get("contacts", []):
        if ground_attack:
            draw_ground_contact(contact)
            continue
        var screen = contact.screen
        if pursuit_mode and contact.selected and contact.on_screen:
            draw_pursuit_target(contact)
            continue
        if contact.on_screen:
            if contact.selected:
                corner_box(screen, 28.0, AMBER if combat.get("locked", false) else INK)
                var progress = float(combat.get("lock_progress", 0.0))
                draw_arc(screen, 35.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, AMBER, 2.0, true)
                draw_circle(screen, 1.8, BRIGHT)
                text(screen + Vector2(-32, -42), "LOCKED" if combat.get("locked", false) else "TRACK %d%%" % int(progress * 100.0), 10, AMBER if combat.get("locked", false) else MUTED)
                draw_enemy_name_tag(contact, screen, true)
            else:
                var diamond = PackedVector2Array([screen + Vector2(0, -6), screen + Vector2(6, 0), screen + Vector2(0, 6), screen + Vector2(-6, 0)])
                draw_polygon(diamond, PackedColorArray([MUTED]))
                draw_enemy_name_tag(contact, screen, false)
        else:
            draw_offscreen_contact(contact, offscreen_index)
            offscreen_index += 1

    if combat.get("lead_visible", false) and not combat.get("reticle_snapped", false):
        var lead = combat.lead_screen
        if Rect2(Vector2.ZERO, size).has_point(lead):
            var lead_color = BRIGHT if combat.get("gun_assist", false) else AMBER
            draw_arc(lead, 7.0, 0.0, TAU, 20, lead_color, 1.2, true)
            if not pursuit_mode:
                draw_line(lead + Vector2(-11, 0), lead + Vector2(11, 0), lead_color, 1.0, true)
                draw_line(lead + Vector2(0, -11), lead + Vector2(0, 11), lead_color, 1.0, true)
            if not combat.get("gun_solution_valid", true):
                text(lead + Vector2(12, -8), "OUT OF RANGE", 9, MUTED)

    if combat_enabled:
        draw_gun_reticle(center)

    if combat.get("hit_marker", false):
        for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
            draw_line(center + direction * 6.0, center + direction * 13.0, AMBER, 2.0, true)

    var nav = Vector2(margin + 72, size.y - 112)
    panel(Rect2(nav - Vector2(72, 72), Vector2(144, 144)))
    for radius in [58, 38, 18]:
        draw_arc(nav, radius, 0.0, TAU, 64, MUTED, 1.0, true)
    for angle in [0.0, 90.0, 180.0, 270.0]:
        var direction = Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
        glow_line(nav + direction * 62.0, nav + direction * 66.0, MUTED, 1.0)
    glow_line(nav + Vector2(-66, 0), nav + Vector2(66, 0), MUTED, 1.0)
    glow_line(nav + Vector2(0, -66), nav + Vector2(0, 66), MUTED, 1.0)
    draw_circle(nav, 4.0, Color(0.20, 1.0, 0.45, 0.35))
    glow_line(nav, nav + Vector2(24, -52), Color(0.30, 1.0, 0.55, 0.35), 1.0)
    draw_circle(nav, 1.8, BRIGHT)
    draw_set_transform(nav, -deg_to_rad(state.get("heading", 0.0)), Vector2.ONE)
    text(Vector2(-5, -48), "N", 11, BRIGHT)
    text(Vector2(46, 3), "E", 9, MUTED)
    text(Vector2(-4, 52), "S", 9, MUTED)
    text(Vector2(-52, 3), "W", 9, MUTED)
    draw_set_transform(Vector2.ZERO)
    draw_polygon(PackedVector2Array([nav + Vector2(0, -13), nav + Vector2(-6, 9), nav + Vector2(0, 5), nav + Vector2(6, 9)]), PackedColorArray([BRIGHT]))
    for contact in combat.get("contacts", []):
        var point = nav + contact.radar
        var color = AMBER if contact.selected else MUTED
        draw_polygon(PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0)]), PackedColorArray([color]))
        if contact.selected:
            text(point + Vector2(8, 3), contact.id, 9, AMBER)
    if state.get("outsideBoundary", false):
        draw_arc(nav, 68, 0.0, TAU, 64, AMBER, 1.6, true)
    text(nav + Vector2(-48, 88), ("RANGE 5 KM / %03d°" if combat_enabled else "HEADING / %03d°") % int(state.get("heading", 0.0)), 10, MUTED)

    var transport = state.get("gearEnabled", false)
    var right = Vector2(size.x - margin - 150, size.y - (162 if transport else 140))
    panel(Rect2(right - Vector2(8, 10), Vector2(158, 106 if transport else 84)))
    text(right, "LEVER" if transport else "THR", 11, MUTED)
    text(right + Vector2(88, 0), "%d%%" % int(state.get("throttle", 0.0) * 100.0), 12, BRIGHT)
    if transport:
        text(right + Vector2(0, 20), "POWER", 11, MUTED)
        text(right + Vector2(88, 20), "%d%%" % int(state.get("enginePower", 0.0) * 100.0), 12, BRIGHT)
    var vs_row = 40 if transport else 24
    var agl_row = 60 if transport else 48
    text(right + Vector2(0, vs_row), "VS", 11, MUTED)
    text(right + Vector2(88, vs_row), "%+.1f" % state.get("verticalSpeed", 0.0), 12, BRIGHT)
    text(right + Vector2(0, agl_row), "AGL", 11, MUTED)
    text(right + Vector2(88, agl_row), "%d M" % int(max(0.0, state.get("agl", 0.0))), 12, BRIGHT)
    if state.get("airbrake", false):
        text(right + Vector2(0, 82 if transport else 70), "BRAKE" if transport and state.get("onGround", false) else "AIRBRAKE", 10, AMBER)

    if combat_enabled:
        if ground_attack:
            var target_status = Vector2(size.x - margin - 132, size.y * 0.26)
            text(target_status, "TARGET HP", 13, MUTED)
            text(target_status + Vector2(0, 28), "%d / %d" % [int(combat.get("target_hp", 0)), int(combat.get("target_max_hp", 120))], 17, BRIGHT)
        else:
            var rwr = Vector2(size.x - margin - 132, size.y * 0.26)
            text(rwr, "RWR", 13, INK)
            text(rwr + Vector2(0, 42), "MISSILE" if combat.get("threat", false) else "CLEAR", 13, AMBER if combat.get("threat", false) else MUTED)
            glow_line(rwr + Vector2(78, -4), rwr + Vector2(84, 0), AMBER if combat.get("threat", false) else INK, 1.2)
            glow_line(rwr + Vector2(84, 0), rwr + Vector2(78, 4), AMBER if combat.get("threat", false) else INK, 1.2)

        var weapons = Vector2(size.x - margin - 132, size.y * 0.40)
        text(weapons, "GUN", 15, INK)
        text(weapons + Vector2(82, 0), str(combat.get("gun_ammo", 0)), 15, BRIGHT)
        text(weapons + Vector2(0, 22), ">RKT" if ground_attack else ">MSL", 15, INK)
        text(weapons + Vector2(82, 22), str(combat.get("missile_ammo", 0)), 15, BRIGHT)
        text(weapons + Vector2(0, 44), "TRACK", 15, INK)
        text(weapons + Vector2(82, 44), str(combat.get("active_missiles", 0)), 15, BRIGHT)
        dash_line(weapons + Vector2(0, 66), weapons + Vector2(48, 66), MUTED, 1.0)
        dash_line(weapons + Vector2(64, 66), weapons + Vector2(96, 66), MUTED, 1.0)
        text(weapons + Vector2(0, 88), "DOWN" if ground_attack else "KILLS", 15, INK)
        text(weapons + Vector2(82, 88), str(combat.get("kills", 0)), 15, BRIGHT)
        text(weapons + Vector2(0, 110), "MODE", 15, INK)
        text(weapons + Vector2(82, 110), "INV", 15, BRIGHT)
        if not ground_attack:
            aircraft_icon(weapons + Vector2(56, 170))

    var warning = str(combat.get("warning", ""))
    if combat.get("threat", false):
        warning = "MISSILE INBOUND"
    elif warning.is_empty() and state.get("stall", false):
        warning = "STALL · NOSE DOWN"
    elif warning.is_empty() and state.get("lowAltitude", false) and combat_enabled:
        warning = "LOW ALTITUDE · PULL UP"
    elif warning.is_empty() and state.get("outsideBoundary", false):
        warning = "LEAVING TEST RANGE"
    if not warning.is_empty():
        var warning_width = 18 * warning.length() * 0.62
        text(Vector2(size.x * 0.5 - warning_width * 0.5, size.y * 0.14), warning, 17, AMBER)

    if paused or state.get("crashed", false):
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.035, 0.02, 0.66))
        var panel_rect = Rect2(Vector2(size.x * 0.5 - 140, size.y * 0.5 - 64), Vector2(280, 128))
        panel(panel_rect)
        var title = "PAUSED" if paused else "CRASHED"
        var subtitle = "Flight state frozen" if paused else "Reset to test airspace"
        text(panel_rect.position + Vector2(92, 38), title, 20, BRIGHT)
        text(panel_rect.position + Vector2(42, 74), subtitle, 12, MUTED)
        text(panel_rect.position + Vector2(62, 104), "P / R TO CONTINUE", 11, INK)
