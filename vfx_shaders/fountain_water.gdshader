shader_type spatial;
render_mode cull_disabled;

uniform vec4 pool_deep : source_color = vec4(0.08, 0.44, 0.72, 0.88);
uniform vec4 pool_shallow : source_color = vec4(0.24, 0.82, 0.94, 0.92);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float ripple_speed : hint_range(0.5, 6.0) = 2.2;
uniform float ripple_density : hint_range(4.0, 40.0) = 16.0;

void vertex() {
	vec2 c_uv = UV - vec2(0.5);
	float dist = length(c_uv);
	float wave = sin(dist * ripple_density - TIME * ripple_speed) * 0.015;
	VERTEX.y += wave;
}

void fragment() {
	vec2 c_uv = UV - vec2(0.5);
	float dist = length(c_uv);

	float r1 = sin(dist * ripple_density - TIME * ripple_speed);
	float r2 = cos(dist * (ripple_density * 1.5) - TIME * (ripple_speed * 1.2) + 0.8);
	float ripple_comb = (r1 + r2 * 0.5) * 0.66;

	float angle = atan(c_uv.y, c_uv.x);
	float shimmer = sin(angle * 6.0 + TIME * 1.4) * 0.15;

	float foam = smoothstep(0.58, 0.90, ripple_comb + shimmer);

	vec3 col = mix(pool_deep.rgb, pool_shallow.rgb, clamp(0.5 + ripple_comb * 0.35, 0.0, 1.0));
	ALBEDO = mix(col, foam_color.rgb, foam * 0.55);
	ROUGHNESS = 0.16;
	SPECULAR = 0.80;
	ALPHA = 0.90;
}
