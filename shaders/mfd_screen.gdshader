shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D screen_texture : source_color, filter_linear_mipmap_anisotropic;


void fragment() {
	vec2 rotated_uv = vec2(UV.y, 1.0 - UV.x);
	vec4 screen_color = texture(screen_texture, rotated_uv);
	ALBEDO = screen_color.rgb;
}
