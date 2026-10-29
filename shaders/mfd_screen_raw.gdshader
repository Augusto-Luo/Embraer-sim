shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D screen_texture : source_color, filter_linear_mipmap_anisotropic;


void fragment() {
	vec4 screen_color = texture(screen_texture, UV);
	ALBEDO = screen_color.rgb;
}
