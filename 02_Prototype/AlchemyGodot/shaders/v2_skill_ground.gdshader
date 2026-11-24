shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 accent : source_color = vec4(1.0);
uniform int pattern = 0;
uniform float age = 0.0;
uniform float strength = 1.0;
uniform float wave_radius = 0.7;

float ring(float radius, float center, float width) {
	return 1.0 - smoothstep(width * 0.26, width, abs(radius - center));
}

float noise_at(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.55);
}

void fragment() {
	vec2 plane = UV * 2.0 - 1.0;
	vec2 pixels = floor(plane * 44.0);
	float grain = noise_at(pixels);
	float r = length(plane);
	float angle = atan(plane.y, plane.x);
	float border = 1.0 - smoothstep(0.87, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.80, r);
	float breakup = smoothstep(-0.70, 0.85, sin(angle * 7.0 + age * 3.0));
	float opacity = 0.0;
	float edge_light = 0.0;
	vec3 rgb = tint.rgb;
	if (pattern == 0) {
		float rim = ring(r, wave_radius + sin(angle * 9.0) * 0.028, 0.044);
		opacity = (rim * (0.35 + breakup * 0.65) + core * 0.31) * 0.69;
		rgb = mix(tint.rgb, accent.rgb, rim * 0.65);
		edge_light = rim * breakup * 0.86;
	} else if (pattern == 1) {
		float scallop = sin(angle * 6.0 + 0.8) * 0.059 + sin(angle * 13.0) * 0.04;
		float pool = 1.0 - smoothstep(0.69, 0.88, r + scallop);
		float edge = ring(r + scallop, 0.78, 0.056);
		float bubbles = smoothstep(0.95, 0.99, grain) * (0.5 + 0.5 * cos(age * 4.0 + grain * 90.0));
		opacity = pool * (0.25 + core * 0.39 + bubbles * 0.34) + edge * 0.51;
		rgb = mix(tint.rgb, accent.rgb, edge * 0.58 + bubbles * 0.3);
		edge_light = edge * breakup * 0.30 + bubbles * 0.19;
	} else if (pattern == 2) {
		float lanes = smoothstep(0.55, 0.94, sin(angle - age * 2.4 + r * 12.0) * sin(angle * 3.0 + 1.0));
		float outer = ring(r, 0.78, 0.043) * (0.48 + breakup * 0.52);
		float inner = ring(r, 0.29 + sin(age * 2.5) * 0.034, 0.035);
		opacity = (lanes * border * 0.44 + outer * 0.69 + inner * 0.46 + core * 0.45);
		rgb = mix(tint.rgb, accent.rgb, max(outer, lanes) * 0.76);
		edge_light = max(outer * 0.64, inner * 0.50);
	} else if (pattern == 3) {
		float outer = ring(r, 0.84, 0.041) * (0.38 + 0.62 * sin(angle * 3.0 - age * 3.1) * sin(angle * 3.0 - age * 3.1));
		float inner = ring(r, 0.64, 0.034) * (0.50 + 0.50 * cos(angle * 3.0 + age * 4.3));
		opacity = outer * 0.86 + inner * 0.79 + core * 0.25;
		rgb = mix(tint.rgb, accent.rgb, max(outer, inner));
		edge_light = max(outer, inner) * 0.83;
	} else if (pattern == 5) {
		float scallop = sin(angle * 6.0 + 0.8) * 0.060 + sin(angle * 11.0) * 0.027;
		float wet_edge = r + scallop;
		float pool = 1.0 - smoothstep(0.79, 0.88, wet_edge);
		float rim = ring(wet_edge, 0.79, 0.064) * (0.56 + 0.44 * breakup);
		float bubbles = smoothstep(0.97, 0.997, grain) * pool;
		opacity = max(pool * (0.64 + core * 0.15), rim * 0.88);
		rgb = mix(tint.rgb, accent.rgb, min(1.0, rim * 0.95 + bubbles * 0.28));
		edge_light = max(rim * 0.57, bubbles * 0.28);
	} else {
		float flow = sin(plane.x * 10.0 + plane.y * 5.0 + age * 1.8) * sin(plane.y * 8.0 - plane.x * 4.0 - age);
		float patches = smoothstep(-0.35, 0.82, flow + grain * 0.18);
		float edge = ring(r, 0.78 + 0.07 * sin(angle * 4.0 + age), 0.18);
		opacity = core * 0.24 + patches * border * 0.40 + edge * 0.12;
		rgb = mix(tint.rgb, accent.rgb, patches * 0.58);
		edge_light = edge * patches * 0.28;
	}
	ALBEDO = rgb + accent.rgb * edge_light * (0.78 + sin(age * 4.1 - angle * 3.0) * 0.22);
	ALPHA = opacity * strength * border;
}
