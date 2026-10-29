shader_type spatial;

uniform sampler2D water_normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 city_half_size = vec2(578.6, 512.4);
uniform vec2 city_center = vec2(0.0);
uniform float ocean_time = 0.0;
uniform float map_scale = 1.0;
uniform vec3 haze_color : source_color = vec3(0.43, 0.57, 0.66);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 edge = max(abs(world_position.xz - city_center) - city_half_size, vec2(0.0));
	float offshore = length(edge);
	float shallow = 1.0 - smoothstep(60.0 * map_scale, 230.0 * map_scale, offshore);
	vec2 water_uv = world_position.xz / 130.0;
	vec3 a = texture(water_normal_texture, water_uv + ocean_time * vec2(0.009, 0.003)).rgb;
	vec3 b = texture(water_normal_texture, water_uv * 0.73 - ocean_time * vec2(0.004, 0.006)).rgb;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), (a + b) * 0.5, 0.10);
	NORMAL_MAP_DEPTH = 0.35;
	vec3 water = mix(vec3(0.025, 0.105, 0.16), vec3(0.075, 0.24, 0.26), shallow);
	float haze = smoothstep(17000.0, 48000.0, length(VERTEX)) * 0.92;
	ALBEDO = mix(water, haze_color, haze);
	ROUGHNESS = 0.62;
	SPECULAR = 0.20;
	METALLIC = 0.0;
}
