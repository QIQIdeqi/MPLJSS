shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_add, depth_draw_never;

uniform sampler2D light_atlas : source_color, filter_nearest, repeat_disable;

void fragment() {
	vec4 light = texture(light_atlas, UV);
	ALBEDO = light.rgb;
	ALPHA = light.a;
}
