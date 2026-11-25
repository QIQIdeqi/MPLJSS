shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 tint : source_color = vec4(0.65, 0.5, 0.85, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float fill = 1.0 - smoothstep(0.6, 1.0, radius);
	float edge = 1.0 - smoothstep(0.003, 0.013, abs(radius - 0.98));
	ALBEDO = tint.rgb;
	ALPHA = (fill * 0.11 + edge * 0.32) * opacity;
}
