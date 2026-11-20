shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float opacity = 0.38;
uniform float uv_rotation = 0.0;
uniform float depth_softness = 8.0;
uniform vec4 cloud_tint : source_color = vec4(1.0);
// Defaults preserve the original daylight cards in every other mission.
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float lightning_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 lightning_direction = vec3(-0.55, 0.35, 0.76);
varying vec3 world_cloud_position;


void vertex() {
	mat4 billboard_world = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	world_cloud_position = (billboard_world * vec4(VERTEX, 1.0)).xyz;
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard_world;
}


void fragment() {
	vec2 centered = UV - 0.5;
	float cs = cos(uv_rotation);
	float sn = sin(uv_rotation);
	vec2 cloud_uv = vec2(cs * centered.x - sn * centered.y, sn * centered.x + cs * centered.y) + 0.5;
	vec4 cloud = texture(cloud_texture, cloud_uv);
	float night = clamp(night_factor, 0.0, 1.0);
	if (night > 0.0) {
		// Two existing mip levels soften the dense small patterns at night.
		// Daylight keeps its original texture lookup and silhouette.
		vec4 soft_cloud = mix(textureLod(cloud_texture, cloud_uv, 2.0), textureLod(cloud_texture, cloud_uv, 4.0), 0.55);
		cloud = mix(cloud, soft_cloud, night * 0.82);
		float luminance = dot(cloud.rgb, vec3(0.2126, 0.7152, 0.0722));
		cloud.rgb = mix(cloud.rgb, vec3(0.58 + luminance * 0.22), night);
	}
	float scene_depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth_raw, 1.0);
	vec3 scene_view = scene_position.xyz / scene_position.w;
	float scene_depth = -scene_view.z;
	float fragment_depth = -VERTEX.z;
	float intersection_fade = clamp((scene_depth - fragment_depth) / depth_softness, 0.0, 1.0);
	float camera_fade = smoothstep(2.0, 12.0, fragment_depth);
	float distance_fade = 1.0 - smoothstep(2300.0, 3200.0, fragment_depth);
	float alpha = cloud.a * opacity * intersection_fade * camera_fade * distance_fade;
	if (alpha < 0.003) {
		discard;
	}
	vec3 card_color = cloud.rgb * cloud_tint.rgb;
	if (night > 0.0 && lightning_strength > 0.0) {
		vec3 to_cloud = normalize(world_cloud_position - CAMERA_POSITION_WORLD);
		float alignment = dot(to_cloud, normalize(lightning_direction));
		float lobe = smoothstep(0.48, 0.96, alignment) * 0.30 + smoothstep(0.90, 0.999, alignment) * 0.70;
		card_color += cloud.rgb * vec3(0.30, 0.43, 0.61) * lobe * clamp(lightning_strength, 0.0, 1.0) * night;
	}
	ALBEDO = card_color;
	ALPHA = alpha;
}
