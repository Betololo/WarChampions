shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, shadows_disabled;

uniform vec4 xray_color : source_color = vec4(1.0, 0.14, 0.12, 0.88);
uniform float outline_width = 0.045;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = xray_color.rgb;
	ALPHA = xray_color.a;
}
