shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 texture_scale = vec2(1.0);
uniform vec2 texture_offset = vec2(0.0);
uniform int surface_kind;
uniform float snow_cover : hint_range(0.0, 1.0);
instance uniform float card_opacity = 1.0;

float edge(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	vec2 r = p - a;
	return (d.x * r.y - d.y * r.x) / length(d);
}

float panel(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
	return smoothstep(-0.006, 0.009, min(min(edge(p, a, b), edge(p, b, c)),
		min(edge(p, c, d), edge(p, d, a))));
}

void fragment() {
	vec4 base = texture(albedo_texture, UV * texture_scale + texture_offset) * tint;
	if (surface_kind != 5) {
		if (base.a < 0.46) { discard; }
		ALPHA = card_opacity;
		ALPHA_HASH_SCALE = 1.0;
	}

	float mask = 1.0;
	if (surface_kind == 0) { // Oak foliage, leaving trunk and roots exposed.
		mask = (1.0 - smoothstep(0.47, 0.69, UV.y))
			* smoothstep(-0.055, 0.045, base.g - base.r);
	} else if (surface_kind == 1) { // Alchemy cottage.
		mask = panel(UV, vec2(0.30, 0.05), vec2(0.73, 0.18), vec2(0.55, 0.60), vec2(0.07, 0.44));
		mask *= 1.0 - panel(UV, vec2(0.60, 0.0), vec2(0.73, 0.0), vec2(0.73, 0.18), vec2(0.60, 0.18));
		mask *= 1.0 - panel(UV, vec2(0.30, 0.35), vec2(0.44, 0.37), vec2(0.44, 0.52), vec2(0.30, 0.48));
	} else if (surface_kind == 2) { // Warehouse.
		mask = panel(UV, vec2(0.35, 0.15), vec2(0.73, 0.0), vec2(1.0, 0.44), vec2(0.68, 0.60));
	} else if (surface_kind == 3) { // Workshop.
		mask = panel(UV, vec2(0.25, 0.27), vec2(0.68, 0.10), vec2(0.96, 0.38), vec2(0.56, 0.56));
		mask *= 1.0 - panel(UV, vec2(0.58, 0.0), vec2(0.74, 0.0), vec2(0.74, 0.20), vec2(0.58, 0.18));
	} else if (surface_kind == 4) { // Thatched houses.
		mask = panel(UV, vec2(0.23, 0.08), vec2(0.80, 0.24), vec2(0.58, 0.61), vec2(0.04, 0.47));
		mask *= 1.0 - panel(UV, vec2(0.68, 0.06), vec2(0.83, 0.06), vec2(0.83, 0.27), vec2(0.68, 0.21));
	} else if (surface_kind == 6) { // Well canopy.
		mask = panel(UV, vec2(0.19, 0.14), vec2(0.75, 0.0), vec2(0.96, 0.25), vec2(0.37, 0.39));
	}

	float luma = dot(base.rgb, vec3(0.30, 0.59, 0.11));
	vec2 cell = floor(UV * 105.0);
	float grain = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float drift = 0.36 * luma + 0.15 * grain;
	float coverage = snow_cover * smoothstep(0.22, 0.95, snow_cover + drift) * mask;
	float relief = clamp(luma * 1.35 + grain * 0.14, 0.0, 1.0);
	vec3 frost = mix(vec3(0.49, 0.61, 0.71), vec3(0.93, 0.97, 1.0), relief);
	ALBEDO = mix(base.rgb, frost, coverage * (0.85 + 0.15 * relief));
	ROUGHNESS = 0.94;
}
