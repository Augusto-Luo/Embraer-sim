shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float opacity = 0.38;
uniform float uv_rotation = 0.0;
uniform float depth_softness = 8.0;


void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}


void fragment() {
	vec2 centered = UV - 0.5;
	float cs = cos(uv_rotation);
	float sn = sin(uv_rotation);
	vec2 cloud_uv = vec2(cs * centered.x - sn * centered.y, sn * centered.x + cs * centered.y) + 0.5;
	vec4 cloud = texture(cloud_texture, cloud_uv);
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
	ALBEDO = cloud.rgb;
	ALPHA = alpha;
}
