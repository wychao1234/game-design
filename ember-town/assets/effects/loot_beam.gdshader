shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 light_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 2.0);
	float height_fade = pow(UV.y, 0.8);
	float shimmer = 0.88 + 0.12 * sin(TIME * 3.0 + UV.y * 7.0);
	ALBEDO = light_color.rgb;
	EMISSION = light_color.rgb * 1.2;
	ALPHA = edge * height_fade * shimmer * 0.52;
}
