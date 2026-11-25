shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float age = 0.0;

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float distance_from_hit = length(point);
	float angle = atan(point.y, point.x);
	float ripple_age = clamp(age / 0.34, 0.0, 1.0);
	float wave = mix(0.10, 0.95, 1.0 - pow(1.0 - ripple_age, 2.0));
	float broken_edge = sin(angle * 13.0) * 0.018 + sin(angle * 23.0) * 0.009;
	float ring = 1.0 - smoothstep(0.013, 0.065, abs(distance_from_hit - wave + broken_edge));
	ring *= mix(0.35, 1.0, smoothstep(-0.5, 0.65, sin(angle * 7.0 + 1.0)));
	float wash = exp(-distance_from_hit * distance_from_hit * 10.0) * exp(-age * 17.0);
	float light = wash * 0.52 + ring * (1.0 - ripple_age) * 0.55;
	ALBEDO = mix(vec3(0.95, 0.28, 0.075), vec3(1.0, 0.68, 0.31), wash);
	ALPHA = light * (1.0 - smoothstep(0.88, 1.0, distance_from_hit));
}
