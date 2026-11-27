shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 accent : source_color = vec4(1.0);
uniform int pattern = 0;
uniform float age = 0.0;
uniform float strength = 1.0;
uniform float wave_radius = 0.7;

float noise_at(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.55);
}

void fragment() {
	vec2 plane = UV * 2.0 - 1.0;
	vec2 pixels = floor(plane * 44.0);
	float grain = noise_at(pixels);
	float r = length(plane);
	float angle = atan(plane.y, plane.x);
	float border = 1.0 - smoothstep(0.74, 1.0, r);
	float core = 1.0 - smoothstep(0.0, 0.80, r);
	float opacity = 0.0;
	float glow = 0.0;
	vec3 rgb = tint.rgb;
	if (pattern == 0) {
		float splash = 1.0 - smoothstep(wave_radius * 0.45, wave_radius, r);
		float flecks = smoothstep(0.82, 0.99, grain) * splash;
		opacity = splash * 0.38 + flecks * 0.32;
		rgb = mix(tint.rgb, accent.rgb, flecks * 0.75);
		glow = flecks * 0.35;
	} else if (pattern == 2) {
		float lanes = smoothstep(0.33, 0.93, sin(angle * 3.0 - age * 2.4 + r * 13.0) + grain * 0.14);
		opacity = lanes * border * 0.42 + core * 0.39;
		rgb = mix(tint.rgb, accent.rgb, lanes * 0.63);
		glow = lanes * 0.24;
	} else if (pattern == 5) {
		float flow = sin(plane.x * 13.0 + plane.y * 7.0 + age * 1.8) * sin(plane.y * 11.0 - age * 2.0);
		float wet = smoothstep(-0.52, 0.62, flow + grain * 0.23);
		float pool = 1.0 - smoothstep(0.49, 0.99, r + (wet - 0.5) * 0.19);
		float bubbles = smoothstep(0.94, 0.99, grain) * (0.55 + 0.45 * cos(age * 3.4 + grain * 82.0));
		opacity = pool * (0.30 + wet * 0.36 + bubbles * 0.23);
		rgb = mix(tint.rgb, accent.rgb, wet * 0.28 + bubbles * 0.53);
		glow = bubbles * 0.21;
	} else {
		float flow = sin(plane.x * 10.0 + plane.y * 5.0 + age * 1.8) * sin(plane.y * 8.0 - plane.x * 4.0 - age);
		float patches = smoothstep(-0.35, 0.82, flow + grain * 0.18);
		opacity = core * 0.24 + patches * border * 0.43;
		rgb = mix(tint.rgb, accent.rgb, patches * 0.58);
		glow = patches * 0.15;
	}
	ALBEDO = rgb + accent.rgb * glow * (0.78 + sin(age * 4.1 - angle * 3.0) * 0.22);
	ALPHA = opacity * strength * border;
}
