shader_type spatial;
render_mode cull_back, depth_draw_always;

uniform vec4 shallow_color : source_color = vec4(0.12, 0.74, 0.88, 0.88);
uniform vec4 deep_color : source_color = vec4(0.04, 0.36, 0.64, 0.94);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);

void vertex() {
	float wave = sin(VERTEX.x * 0.18 + TIME * 1.8) * 0.22 + cos(VERTEX.z * 0.16 + TIME * 1.4) * 0.18;
	VERTEX.y += wave;
}

void fragment() {
	float pattern = sin(UV.x * 48.0 + TIME * 1.2) * cos(UV.y * 48.0 - TIME * 1.0);
	float foam = smoothstep(0.76, 0.95, pattern);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.55 + 0.45 * sin(TIME * 0.8 + UV.x * 16.0));
	ALBEDO = mix(col, foam_color.rgb, foam * 0.45);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
