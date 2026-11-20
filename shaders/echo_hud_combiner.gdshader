shader_type spatial;
render_mode blend_add, depth_draw_never, unshaded, cull_back, fog_disabled, shadows_disabled;

uniform sampler2D symbol_texture : source_color, filter_linear, repeat_disable;
uniform mat4 mesh_to_aircraft;
uniform vec3 camera_local = vec3(0.35, 3.20, 7.0);
uniform vec2 left_field_center = vec2(-0.233, 0.153);
uniform vec2 right_field_center = vec2(0.244, 0.153);
uniform vec2 field_span = vec2(0.285, 0.235);
uniform float active_side = 1.0;
uniform float visibility_weight = 0.0;
uniform float symbol_gain = 1.00;

varying vec3 point_aircraft;
varying float pilot_face;

void vertex() {
	point_aircraft = (mesh_to_aircraft * vec4(VERTEX, 1.0)).xyz;
	pilot_face = -(mesh_to_aircraft * vec4(NORMAL, 0.0)).z;
}

void fragment() {
	// The source has duplicate front/back triangles. Only pilot-facing normals
	// emit, so alpha/additive layers cannot double up or show mirrored glyphs.
	if (pilot_face < 0.5 || point_aircraft.x * active_side < 0.0 || visibility_weight < 0.001) {
		discard;
	}
	vec3 ray = point_aircraft - camera_local;
	if (ray.z < 0.06) {
		discard;
	}
	// Direction, rather than glass UVs, fixes the virtual image at optical
	// infinity: head motion clips its field instead of stretching a decal.
	vec2 direction = vec2(-ray.x, -ray.y) / ray.z;
	vec2 center = active_side > 0.0 ? left_field_center : right_field_center;
	vec2 symbol_uv = vec2(0.5) + (direction - center) / field_span;
	if (any(lessThan(symbol_uv, vec2(0.0))) || any(greaterThan(symbol_uv, vec2(1.0)))) {
		discard;
	}
	vec4 symbol = texture(symbol_texture, symbol_uv);
	if (symbol.a < 0.001) {
		discard;
	}
	// SubViewport RGB already includes glyph coverage. Add it once; the
	// unshaded path uses ALBEDO, and a second alpha multiplication loses lines.
	ALBEDO = symbol.rgb * symbol_gain;
	ALPHA = visibility_weight;
}
