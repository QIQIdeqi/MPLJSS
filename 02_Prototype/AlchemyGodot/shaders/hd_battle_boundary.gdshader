shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	float sweep = pow(max(sin(UV.x * TAU * 3.0 - TIME * 1.6), 0.0), 18.0);
	ALBEDO = mix(vec3(0.84, 0.25, 0.28), vec3(1.0, 0.55, 0.45), sweep);
	ALPHA = COLOR.a * (0.56 + sweep * 0.22);
}
