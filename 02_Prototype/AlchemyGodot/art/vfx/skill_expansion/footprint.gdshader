shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 tint : source_color;
uniform vec4 accent : source_color;
uniform int shape = 0;
uniform float strength = 1.0;
uniform float age = 0.0;
uniform float wave = 0.0;
uniform vec2 heading = vec2(1.0, 0.0);
uniform float cone_cosine = 0.82;

float rim(float r, float target, float width) {
	return 1.0 - smoothstep(width * 0.3, width, abs(r - target));
}

void fragment() {
	vec2 raw = UV * 2.0 - 1.0;
	vec2 px = (floor(raw * 56.0) + 0.5) / 56.0;
	float r = length(px);
	float theta = atan(px.y, px.x);
	float grain = fract(sin(dot(floor(px * 56.0), vec2(42.5, 71.7))) * 57931.6);
	float shimmer = smoothstep(-0.62, 0.79, sin(theta * 8.0 + age * 6.0));
	float boundary = 1.0 - smoothstep(0.96, 1.0, length(raw));
	float ink = 0.0;
	float bright = 0.0;
	if (shape == 1) {
		float front = rim(r, wave, 0.042);
		float wake = rim(r, wave - 0.062, 0.063);
		ink = front * (0.66 + 0.34 * shimmer) + wake * 0.27;
		bright = front * (0.74 + 0.26 * shimmer);
	} else if (shape == 2) {
		float alignment = dot(px / max(r, 0.001), heading);
		float wedge = smoothstep(cone_cosine, cone_cosine + 0.038, alignment);
		float gust = rim(r, wave, 0.17);
		ink = wedge * (0.07 + 0.58 * gust + 0.17 * rim(r, 0.92, 0.073));
		bright = wedge * gust * (0.45 + shimmer * 0.49);
	} else {
		float puddle = 1.0 - smoothstep(0.5, 0.97, r);
		float glints = smoothstep(0.95, 0.99, grain) * (0.35 + 0.65 * pow(max(0.0, sin(age * 7.0 + grain * 89.0)), 2.0));
		float edge = rim(r + 0.017 * sin(theta * 11.0), 0.9, 0.067);
		ink = puddle * (0.16 + 0.26 * glints) + edge * (0.26 + 0.31 * shimmer);
		bright = edge * 0.8 + puddle * glints * 0.34;
	}
	ALBEDO = mix(tint.rgb, accent.rgb, clamp(bright, 0.0, 1.0));
	ALPHA = clamp(ink * strength * boundary, 0.0, 1.0);
}
