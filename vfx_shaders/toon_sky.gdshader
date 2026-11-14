shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.14, 0.52, 0.96);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.87, 1.0);
uniform vec3 ground_bottom_color : source_color = vec3(0.10, 0.42, 0.66);
uniform vec3 ground_horizon_color : source_color = vec3(0.62, 0.87, 1.0);

uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.86);
uniform float sun_disk_size : hint_range(0.005, 0.1) = 0.038;

uniform vec3 cloud_color_lit : source_color = vec3(1.0, 0.99, 0.95);
uniform vec3 cloud_color_shadow : source_color = vec3(0.70, 0.76, 0.90);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_speed = 0.012;
uniform float cloud_scale = 1.6;

// Procedural 2D hash
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// 2D Gradient Noise with smooth quintic Hermite interpolation
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
		    dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
		    dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// 4-octave Fractional Brownian Motion for layered billowing cumulus
float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		val += amp * (gnoise(p) * 0.5 + 0.5);
		p = rot * p * 2.05 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return val;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	// Base celestial gradient
	vec3 col;
	if (y >= 0.0) {
		float h = clamp(y, 0.0, 1.0);
		col = mix(horizon_color, zenith_color, pow(h, 0.72));
	} else {
		float gh = clamp(-y, 0.0, 1.0);
		col = mix(ground_horizon_color, ground_bottom_color, pow(gh, 0.68));
	}

	// Sun disk and warm halo (LIGHT0)
	if (LIGHT0_ENABLED) {
		float sun_dot = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		float sun_disc = smoothstep(1.0 - sun_disk_size * 0.02, 1.0, sun_dot);
		float sun_halo = pow(sun_dot, 32.0) * 0.55 + pow(sun_dot, 8.0) * 0.22;
		col += (sun_color * sun_disc * 2.0 + sun_color * sun_halo);
	}

	// Stylized billowing cartoon cumulus clouds above horizon
	if (y > 0.015) {
		float denom = max(y + 0.12, 0.05);
		vec2 cuv = (dir.xz / denom) * cloud_scale;
		cuv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.5);

		// Bilayer FBM for billowy cartoon clumps
		float n1 = fbm(cuv);
		float n2 = fbm(cuv * 2.1 + vec2(3.1, 7.3) - vec2(TIME * cloud_speed * 0.4));
		float cloud_val = n1 * 0.68 + n2 * 0.32;

		// Cel-stepped cloud edge and density
		float density = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.22, cloud_val);

		// Stepped shading: sunlit tops vs periwinkle underside
		float shade_sample = fbm(cuv + vec2(0.08, -0.06));
		float light_factor = smoothstep(0.42, 0.62, cloud_val - shade_sample * 0.5 + 0.28);
		vec3 cloud_rgb = mix(cloud_color_shadow, cloud_color_lit, light_factor);

		// Smooth horizon falloff to prevent clipping at the horizon line
		float horizon_fade = smoothstep(0.015, 0.18, y);
		float alpha = density * horizon_fade;

		col = mix(col, cloud_rgb, alpha);
	}

	COLOR = col;
}
