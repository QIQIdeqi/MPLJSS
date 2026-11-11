shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform sampler2D coin : source_color, filter_nearest, repeat_disable;
uniform float offset_phase;

void fragment() {
	vec4 base = texture(coin, UV);
	float travel = fract(TIME / 2.7 + offset_phase) * 3.8 - 0.7;
	float stripe = 1.0 - smoothstep(0.025, 0.12, abs(UV.x + 0.52 * UV.y - travel));
	ALBEDO = base.rgb + vec3(1.0, 0.67, 0.24) * stripe * 0.72;
	ALPHA = base.a;
	ALPHA_SCISSOR_THRESHOLD = 0.35;
}
