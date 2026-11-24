shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.5) = 0.6;
uniform float rays : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	// Keep only the light card facing the camera. Its origin and size still come from the world transform.
	MODELVIEW_MATRIX = mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		MODELVIEW_MATRIX[3]
	);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float distance_to_core = length(uv);
	float halo = exp(-dot(uv, uv) * 4.7) * (1.0 - smoothstep(0.61, 1.0, distance_to_core));
	vec2 pixel = abs(floor(uv * 20.0 + 0.5) / 20.0);
	float core = 1.0 - smoothstep(0.045, 0.27, pixel.x + pixel.y);
	float cross_x = (1.0 - smoothstep(0.013, 0.087, pixel.y)) * (1.0 - smoothstep(0.13, 0.76, pixel.x));
	float cross_y = (1.0 - smoothstep(0.013, 0.087, pixel.x)) * (1.0 - smoothstep(0.10, 0.58, pixel.y));
	float glint = max(cross_x, cross_y) * rays;
	ALBEDO = mix(tint.rgb, mix(tint.rgb, vec3(1.0), 0.78), max(core, glint * 0.78));
	ALPHA = clamp((halo * 0.43 + core * 0.28 + glint * 0.46) * strength, 0.0, 1.0);
}
