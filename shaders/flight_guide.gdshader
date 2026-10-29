shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float progress = 0.0;
uniform float guide_time = 0.0;
uniform float ahead = 2600.0;
varying float route_distance;

void vertex() {
	route_distance = UV.x;
}

void fragment() {
	float relative = route_distance - progress;
	float window = smoothstep(20.0, 90.0, relative) * (1.0 - smoothstep(ahead * 0.65, ahead, relative));
	float dash = 1.0 - step(48.0, mod(route_distance, 90.0));
	float pulse = 0.82 + 0.18 * sin(route_distance * 0.009 - guide_time * 1.8);
	ALBEDO = mix(vec3(0.24, 0.78, 0.46), vec3(0.92, 0.70, 0.24), step(0.5, UV.y));
	ALPHA = window * dash * pulse * 0.58;
}
