shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled;

uniform vec4 effect_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D glow_texture : source_color, filter_linear;
uniform bool billboard = true;
uniform bool use_texture = true;

void vertex() {
	if (billboard) {
		vec3 scale = vec3(
			length(MODELVIEW_MATRIX[0].xyz),
			length(MODELVIEW_MATRIX[1].xyz),
			length(MODELVIEW_MATRIX[2].xyz)
		);
		mat4 mv = MODELVIEW_MATRIX;
		mv[0].xyz = vec3(scale.x, 0.0, 0.0);
		mv[1].xyz = vec3(0.0, scale.y, 0.0);
		mv[2].xyz = vec3(0.0, 0.0, scale.z);
		POSITION = PROJECTION_MATRIX * mv * vec4(VERTEX, 1.0);
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	}
}

void fragment() {
	vec4 tex = use_texture ? texture(glow_texture, UV) : vec4(1.0);
	ALBEDO = effect_color.rgb * tex.rgb;
	ALPHA = effect_color.a * tex.a;
}
