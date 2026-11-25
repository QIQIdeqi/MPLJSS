shader_type canvas_item;

uniform float remaining : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 point = UV - vec2(0.5);
	// UV.y points downward. The angle starts at twelve o'clock and increases clockwise.
	float turns = fract(atan(point.x, -point.y) / TAU + 1.0);
	float hand = 1.0 - remaining;
	float shadow = step(hand, turns);
	float edge = (1.0 - smoothstep(0.0, 0.012, abs(turns - hand))) * shadow;
	float partial = step(0.001, hand) * step(hand, 0.999);
	COLOR = mix(vec4(0.0, 0.0, 0.0, 0.78) * shadow, vec4(0.94, 0.77, 0.48, 0.76), edge * partial);
}
