shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.2, 0.45, 0.85, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.72;
uniform float cloak_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 cloak_tint = vec3(0.55, 0.88, 1.0) * (0.4 + 0.6 * sin(TIME * 8.0 + VERTEX.y * 6.0));
	ALBEDO = mix(albedo_color.rgb, cloak_tint, cloak_amount * 0.75);
	EMISSION = rim_color.rgb * fresnel * (rim_strength * 0.35 + cloak_amount * 0.85);
	ROUGHNESS = 0.68;
	METALLIC = 0.05;
	ALPHA = mix(1.0, 0.18 + fresnel * 0.45, cloak_amount);
}

void light() {
	// Stylized Half-Lambert wrap lighting + crisp Cartoon Rim Light
	float n_dot_l = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float half_lambert = n_dot_l * n_dot_l;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * half_lambert * 0.95;
	DIFFUSE_LIGHT += rim_color.rgb * LIGHT_COLOR * fresnel * rim_strength * 0.45;
}
