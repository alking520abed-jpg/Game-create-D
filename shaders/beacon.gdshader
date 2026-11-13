shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.2, 0.8);

void fragment() {
	float v = clamp(UV.y * 2.0, 0.0, 1.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0 + v * 6.0);
	ALBEDO = color.rgb;
	ALPHA = color.a * v * v * pulse;
}
