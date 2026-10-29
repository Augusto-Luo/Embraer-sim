shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D cloud_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 0.55;


void fragment() {
	vec4 cloud = texture(cloud_texture, UV);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = cloud.rgb;
	ALPHA = cloud.a * opacity * smoothstep(0.025, 0.18, facing);
}
