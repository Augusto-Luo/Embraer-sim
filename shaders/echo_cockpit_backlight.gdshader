shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_back, fog_disabled, shadows_disabled;

// This pass follows the actual painel UVs. It lights colored button faces
// and tiny keypad glyphs, while preserving the dark panel and live MFDs.
uniform sampler2D legend_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float backlight_energy : hint_range(0.0, 1.5) = 0.72;
uniform vec4 green_light : source_color = vec4(0.28, 0.88, 0.51, 1.0);
uniform vec4 amber_light : source_color = vec4(0.95, 0.64, 0.22, 1.0);

void fragment() {
	vec3 paint = texture(legend_atlas, UV).rgb;
	float green = smoothstep(0.06, 0.20, paint.g - max(paint.r, paint.b));
	green *= smoothstep(0.08, 0.25, paint.g);
	float amber = smoothstep(0.10, 0.26, min(paint.r, paint.g) - paint.b);
	amber *= smoothstep(0.18, 0.40, min(paint.r, paint.g));
	// The atlas's upper-left blocks are baked screen pictures, not lamps.
	float outside_screens = min(1.0, step(0.52, UV.x) + step(0.47, UV.y));
	green *= outside_screens;
	amber *= outside_screens;
	float top_keypad = step(0.52, UV.x) * (1.0 - step(0.65, UV.x)) * (1.0 - step(0.10, UV.y));
	float left_keypad = (1.0 - step(0.12, UV.x)) * step(0.47, UV.y) * (1.0 - step(0.58, UV.y));
	float glyph = smoothstep(0.65, 0.90, min(paint.r, min(paint.g, paint.b)));
	glyph *= max(top_keypad, left_keypad) * 0.55;
	float mask = max(max(green, amber), glyph);
	if (mask < 0.003) {
		discard;
	}
	vec3 tint = mix(green_light.rgb, amber_light.rgb, amber / max(0.001, green + amber));
	// Forward+ unshaded output comes from ALBEDO. Keep button glow restrained.
	ALBEDO = tint * backlight_energy * 0.22;
	ALPHA = mask;
}
