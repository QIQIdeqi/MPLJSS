shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray terrain_layers : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tile_lookup : repeat_disable, filter_nearest;
uniform vec2 map_origin;
uniform vec2 cell_size = vec2(1.0);
uniform float snow_cover : hint_range(0.0, 1.0);
varying vec2 world_ground;
varying vec2 terrain_relief;

float hash(vec2 point) {
	return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x), blend.y);
}

int terrain_at(ivec2 cell) {
	ivec2 grid = textureSize(tile_lookup, 0);
	if (any(lessThan(cell, ivec2(0))) || any(greaterThanEqual(cell, grid))) {
		return 0;
	}
	return int(round(texelFetch(tile_lookup, cell, 0).r));
}

vec4 surface_at(int layer, vec2 texcoords) {
	return vec4(texture(terrain_layers, vec3(texcoords, float(layer))).rgb, layer == 0 ? 0.94 : 0.43);
}

void vertex() {
	world_ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	terrain_relief = vec2(VERTEX.y, 1.0 - NORMAL.y);
}

void fragment() {
	vec2 position = world_ground;
	vec2 coarse = vec2(noise(position * 2.7), noise(position * 2.7 + vec2(27.4, 10.3)));
	vec2 fine = vec2(noise(position * 16.3), noise(position * 16.3 + vec2(9.7, 41.1)));
	vec2 grid = (position - map_origin) / cell_size;
	vec2 edge = smoothstep(vec2(0.12), vec2(0.86), abs(fract(grid) - 0.5) * 2.0);
	vec2 bend = edge * ((coarse - 0.5) * 0.62 + (fine - 0.5) * 0.14);

	// Interpolate between four generated cell centers, with bends confined to their shared edges.
	vec2 tile = grid - 0.5 + bend;
	ivec2 from = ivec2(floor(tile));
	vec2 blend = smoothstep(vec2(0.23), vec2(0.77), fract(tile));
	int a = terrain_at(from);
	int b = terrain_at(from + ivec2(1, 0));
	int c = terrain_at(from + ivec2(0, 1));
	int d = terrain_at(from + ivec2(1));
	vec2 texcoords = position * 0.86;
	vec4 surface = surface_at(a, texcoords);
	if (a != b || a != c || a != d) {
		surface = mix(mix(surface, surface_at(b, texcoords), blend.x),
			mix(surface_at(c, texcoords), surface_at(d, texcoords), blend.x), blend.y);
	}

	float grain = hash(floor(position * 74.0));
	float patch = sin(position.x * 2.65 + position.y * 1.37)
		* cos(position.y * 3.06 - position.x * 1.13);
	vec3 ground = surface.rgb * (0.975 + patch * 0.055);
	float hillside = smoothstep(0.12, 1.45, terrain_relief.x);
	float rock = hillside * smoothstep(0.025, 0.24, terrain_relief.y + (coarse.x - 0.5) * 0.16);
	float stratum = noise(vec2(position.x * 3.4, terrain_relief.x * 10.0 + position.y * 1.3));
	vec3 rock_color = mix(vec3(0.12, 0.15, 0.13), vec3(0.37, 0.34, 0.28), stratum * 0.78 + grain * 0.22);
	ground = mix(ground * mix(1.0, 0.72, hillside), rock_color, rock * 0.82);
	float spread = smoothstep(0.06, 0.62, snow_cover + grain * 0.26 + patch * 0.14 - 0.18);
	float coverage = min(snow_cover * 1.5, 1.0) * spread * surface.a;
	vec3 frost = mix(vec3(0.69, 0.79, 0.87), vec3(0.91, 0.95, 0.98), grain);
	ALBEDO = mix(ground, frost, coverage);
	ROUGHNESS = mix(0.90, 0.78, coverage);
}
