shader_type canvas_item;

uniform float offset_phase = 0.0;

void fragment() {
	vec4 base = COLOR;
	float travel = fract(TIME / 2.7 + offset_phase) * 3.8 - 0.7;
	float stripe = 1.0 - smoothstep(0.025, 0.12, abs(UV.x + 0.52 * UV.y - travel));
	COLOR = vec4(base.rgb + vec3(1.0, 0.67, 0.24) * stripe * 0.72, base.a);
}
