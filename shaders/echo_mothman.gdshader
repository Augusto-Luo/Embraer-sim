shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform sampler2D wing_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D wing_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float eye_energy : hint_range(0.0, 12.0) = 0.0;
uniform float lower_eye_energy : hint_range(0.0, 12.0) = 0.0;
uniform float surface_fill : hint_range(0.0, 1.0) = 0.0;
uniform float body_visibility : hint_range(0.0, 1.0) = 0.08;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float body_opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 color = texture(wing_texture, UV).rgb;
	float red_pattern = smoothstep(0.05, 0.30, color.r - max(color.g, color.b) * 1.25);
	// Both rings live in one atlas. Only the upper large ring awakens first.
	float upper_eye = (1.0 - smoothstep(0.58, 0.68, UV.y));
	float eye_mask = red_pattern * upper_eye;
	float lower_mask = red_pattern * (1.0 - upper_eye);
	vec3 surface_color = color + vec3(0.025, 0.030, 0.045) * surface_fill;
	ALBEDO = surface_color * mix(0.72, 0.035, red_pattern) * body_visibility;
	NORMAL_MAP = texture(wing_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	// The source texture supplies the broken outer ring and dark pupil.
	EMISSION = color * (eye_mask * eye_energy + lower_mask * lower_eye_energy);
	// No opaque black wing silhouette before the lightning reveal. The ring
	// center remains a real gap, so clouds behind the wing stay visible there.
	float awake_eye = eye_mask * step(0.001, eye_energy) + lower_mask * step(0.001, lower_eye_energy);
	ALPHA = max(awake_eye, body_opacity) * opacity;
}
