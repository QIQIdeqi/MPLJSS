shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float light = max(COLOR.r, max(COLOR.g, COLOR.b));
	// Light atlases have an opaque black matte. Store their intensity in alpha too
	// so the transparent combat viewport can be composited over the 3D ground.
	COLOR = vec4(COLOR.rgb / max(light, 0.001), COLOR.a * light);
}
