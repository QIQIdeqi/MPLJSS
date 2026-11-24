shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 pixel = texture(sprite_texture, UV);
	ALBEDO = mix(pixel.rgb, vec3(1.0, 0.12, 0.10), 0.72);
	ALPHA = pixel.a * opacity;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}
