shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 3.5;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.45;
uniform float cloak_amount : hint_range(0.0, 1.0) = 0.0;
uniform float specular_roughness : hint_range(0.05, 1.0) = 0.65;

void fragment() {
	vec3 base = albedo_color.rgb * COLOR.rgb;
	if (use_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = base;
	EMISSION = rim_color.rgb * fresnel * (rim_strength * 0.14);
	ROUGHNESS = clamp(specular_roughness, 0.05, 1.0);
	METALLIC = mix(0.28, 0.0, clamp((ROUGHNESS - 0.18) / 0.32, 0.0, 1.0));
}

void light() {
	// TF2 / Battlefield Heroes stylized warped Half-Lambert with warm highlights & cool shadow ramp
	float ndl = dot(NORMAL, LIGHT);
	float wrap = ndl * 0.5 + 0.5;
	float ramp = smoothstep(0.16, 0.78, wrap);
	vec3 shadow_col = ALBEDO * vec3(0.44, 0.48, 0.60);
	vec3 lit_col = min(ALBEDO * vec3(1.00, 0.98, 0.94), vec3(0.94));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float rim_suppress = 1.0 - smoothstep(0.70, 0.95, max(ALBEDO.r, max(ALBEDO.g, ALBEDO.b))) * 0.55;
	DIFFUSE_LIGHT += mix(shadow_col, lit_col, ramp) * LIGHT_COLOR * ATTENUATION * 0.64;
	DIFFUSE_LIGHT += rim_color.rgb * LIGHT_COLOR * fresnel * rim_strength * 0.22 * rim_suppress * clamp(dot(NORMAL, vec3(0.0, 1.0, 0.0)) * 0.5 + 0.5, 0.0, 1.0);

	// Crisp cel specular strictly gated to glossy parts (sunglasses, helmets, boots, metal <= 0.48); zero on matte (>= 0.55)
	float gloss_mask = 1.0 - smoothstep(0.38, 0.54, ROUGHNESS);
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, half_vec), 0.0);
	float shininess = mix(112.0, 32.0, clamp((ROUGHNESS - 0.10) / 0.42, 0.0, 1.0));
	float spec_band = smoothstep(0.28, 0.58, pow(ndh, shininess));
	float spec_strength = mix(0.68, 0.16, clamp((ROUGHNESS - 0.15) / 0.35, 0.0, 1.0)) * gloss_mask * (1.0 - cloak_amount * 0.90);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec_band * spec_strength * max(ndl, 0.0);
}
