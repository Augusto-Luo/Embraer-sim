shader_type spatial;

uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ground_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D water_normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float map_size = 20000.0;
uniform float water_normal_strength = 0.22;
uniform vec3 haze_color : source_color = vec3(0.48, 0.58, 0.62);

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 map_uv = world_position.xz / map_size + 0.5;
	vec3 base = texture(ground_albedo, map_uv).rgb;
	float water = texture(ground_mask, map_uv).r;
	vec2 water_uv = world_position.xz / 180.0;
	vec3 wave_a = texture(water_normal_texture, water_uv + TIME * vec2(0.008, 0.003)).rgb;
	vec3 wave_b = texture(water_normal_texture, water_uv * 0.73 - TIME * vec2(0.004, 0.006)).rgb;
	vec3 waves = normalize(mix(vec3(0.5, 0.5, 1.0), (wave_a + wave_b) * 0.5, water_normal_strength));
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), waves, water);
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.93, 0.30, water);
	SPECULAR = mix(0.15, 0.55, water);
	METALLIC = 0.0;
	float camera_distance = length(VERTEX);
	float haze = smoothstep(7000.0, 22000.0, camera_distance) * 0.82;
	ALBEDO = mix(base, haze_color, haze);
}
