shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float age = 0.0;

float tongue(vec2 point, vec2 center, vec2 size, float lean) {
	vec2 local = (point - center) / size;
	local.x -= local.y * lean;
	return 1.0 - dot(local, local);
}

void fragment() {
	vec2 uv = (floor(UV * vec2(44.0, 30.0)) + 0.5) / vec2(44.0, 30.0);
	vec2 point = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y);
	float burst = clamp(age / 0.19, 0.0, 1.0);
	float bloom = smoothstep(0.0, 0.19, burst);
	float melt = smoothstep(0.42, 1.0, burst);
	point.x /= mix(0.30, 1.0, bloom);
	point.y /= mix(0.32, 1.0, bloom);
	float center = tongue(point, vec2(0.05, 0.45 + melt * 0.25), vec2(0.23, 0.39), 0.38);
	float left = tongue(point, vec2(-0.29, 0.31 + melt * 0.10), vec2(0.29, 0.20), -0.86);
	float right = tongue(point, vec2(0.37, 0.25 + melt * 0.14), vec2(0.24, 0.14), 0.54);
	float flicker = sin(uv.x * 54.0 + uv.y * 37.0 + floor(burst * 8.0)) * 0.16;
	float flame = max(center, max(left, right)) + flicker - melt * 0.64;
	vec3 rim = vec3(0.62, 0.095, 0.026);
	vec3 middle = vec3(1.0, 0.33, 0.065);
	vec3 core = vec3(1.0, 0.69, 0.31);
	ALBEDO = mix(rim, middle, step(0.29, flame));
	ALBEDO = mix(ALBEDO, core, step(0.70, flame) * (1.0 - melt));
	ALPHA = step(0.0, flame) * (1.0 - melt) * 0.93;
}
