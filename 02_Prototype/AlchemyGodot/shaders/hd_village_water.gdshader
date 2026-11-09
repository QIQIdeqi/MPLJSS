shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.27, 0.60, 0.55, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.26, 0.29, 1.0);
uniform vec4 foam_color : source_color = vec4(0.69, 0.86, 0.75, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.36;

void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float flow = UV.x - TIME * flow_speed;
	float ripple = sin(flow * 28.0 + sin(UV.y * 31.0) * 2.0);
	float cross_wave = cos(flow * 15.0 - UV.y * 66.0);
	float crest = smoothstep(0.80, 1.32, ripple * 0.70 + cross_wave * 0.46);
	float edge_wave = smoothstep(0.81, 1.0, across + ripple * 0.052) * mix(0.55, 1.0, cross_wave * 0.5 + 0.5);
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.18, 1.0, across));
	ALBEDO = mix(water, foam_color.rgb, crest * 0.34 + edge_wave * 0.32);
	EMISSION = water * 0.13;
	ROUGHNESS = 0.31;
	SPECULAR = 0.60;
}
