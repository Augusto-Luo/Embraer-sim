shader_type sky;
render_mode use_half_res_pass;

uniform float coverage = 0.55;
uniform float cloud_top = 2500.0;
uniform float quality = 1.0;
uniform float cloud_time = 0.0;
uniform float cloud_base = -1500.0;
uniform vec3 cloud_focus = vec3(0.0);
uniform float clear_radius = 0.0;

vec3 sun_direction() {
	if (LIGHT0_ENABLED) {
		return normalize(LIGHT0_DIRECTION);
	}
	return normalize(vec3(-0.35, 0.42, 0.84));
}

vec3 background(vec3 dir) {
	float up = clamp(dir.y, 0.0, 1.0);
	vec3 horizon = vec3(0.14, 0.23, 0.34);
	vec3 zenith = vec3(0.035, 0.085, 0.17);
	vec3 color = mix(horizon, zenith, pow(up, 0.42));
	float sun_dot = max(dot(dir, sun_direction()), 0.0);
	float halo = pow(sun_dot, 48.0) * 0.28 + pow(sun_dot, 650.0) * 0.85;
	return color + vec3(1.0, 0.88, 0.66) * halo;
}

float hash31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
			mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
			mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float value = 0.0;
	float amplitude = 0.52;
	for (int octave = 0; octave < 4; octave++) {
		value += noise3(p) * amplitude;
		p = p * 2.03 + vec3(13.7, 7.1, 5.3);
		amplitude *= 0.5;
	}
	return value;
}

float cloud_density(vec3 p) {
	if (p.y < cloud_base || p.y > cloud_top) {
		return 0.0;
	}
	float height = clamp((p.y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	float profile = smoothstep(0.0, 0.07, height) * (1.0 - smoothstep(0.78, 1.0, height));
	vec3 q = p * vec3(0.00078, 0.00068, 0.00078);
	q.xz += cloud_time * vec2(0.0015, 0.0008);
	vec2 warp = vec2(
		noise3(p * 0.00018 + vec3(7.3, 2.1, 5.7)),
		noise3(p * 0.00018 + vec3(1.9, 8.4, 3.2))
	);
	q.xz += (warp - 0.5) * 1.25;
	q.y += (warp.x - warp.y) * 0.45;
	float large = fbm(q);
	float erosion = noise3(q * 3.8 + vec3(3.4, 1.2, 8.9));
	float shape = large - erosion * 0.055;
	float threshold = 0.59 - clamp(coverage, 0.05, 0.95) * 0.14;
	threshold += smoothstep(0.35, 1.0, height) * 0.12;
	float field = smoothstep(threshold, threshold + 0.075, shape);
	float opening = clear_radius > 0.0 ? smoothstep(clear_radius * 0.45, clear_radius, distance(p, cloud_focus)) : 1.0;
	return field * profile * 2.0 * opening;
}

float cloud_shadow_density(vec3 p) {
	if (p.y < cloud_base || p.y > cloud_top) {
		return 0.0;
	}
	float height = clamp((p.y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
	float profile = smoothstep(0.0, 0.07, height) * (1.0 - smoothstep(0.78, 1.0, height));
	vec3 q = p * vec3(0.00078, 0.00068, 0.00078);
	q.xz += cloud_time * vec2(0.0015, 0.0008);
	float large = noise3(q) * 0.65 + noise3(q * 2.03 + vec3(13.7, 7.1, 5.3)) * 0.35;
	float threshold = 0.63 - clamp(coverage, 0.05, 0.95) * 0.14;
	threshold += smoothstep(0.35, 1.0, height) * 0.10;
	float field = smoothstep(threshold, threshold + 0.16, large - 0.03);
	float opening = clear_radius > 0.0 ? smoothstep(clear_radius * 0.45, clear_radius, distance(p, cloud_focus)) : 1.0;
	return field * profile * 2.0 * opening;
}

vec4 render_clouds(vec3 dir) {
	vec3 bg = background(dir);
	vec3 start = POSITION;
	float t0 = 0.0;
	float t1 = 12000.0;
	if (abs(dir.y) > 0.0004) {
		float a = (cloud_base - start.y) / dir.y;
		float b = (cloud_top - start.y) / dir.y;
		t0 = max(0.0, min(a, b));
		t1 = min(12000.0, max(a, b));
	} else if (start.y < cloud_base || start.y > cloud_top) {
		t1 = 0.0;
	}
	vec3 accum = vec3(0.0);
	float transmittance = 1.0;
	if (t1 > t0) {
		int steps = quality < 0.5 ? 80 : (quality < 1.5 ? 144 : 192);
		float step_size = (t1 - t0) / float(steps);
		float jitter = 0.5 + (noise3(dir * 180.0) - 0.5) * 0.50;
		t0 += step_size * jitter;
		vec3 sun = sun_direction();
		float view_sun = max(dot(dir, sun), 0.0);
		for (int index = 0; index < 192; index++) {
			if (index >= steps || transmittance < 0.025) {
				break;
			}
			float distance = t0 + (float(index) + 0.5) * step_size;
			vec3 p = start + dir * distance;
			float density = cloud_density(p);
			if (density > 0.015) {
				float shadow_density = cloud_shadow_density(p + sun * 320.0);
				float shade = exp(-shadow_density * 0.85);
				float height = clamp((p.y - cloud_base) / max(cloud_top - cloud_base, 1.0), 0.0, 1.0);
				float phase = 0.04 + 0.96 * pow(view_sun, 12.0);
				float rim = (1.0 - smoothstep(0.12, 0.95, density)) * phase * 0.55;
				vec3 base = mix(vec3(0.055, 0.070, 0.095), vec3(0.42, 0.47, 0.54), shade);
				base *= mix(0.65, 1.05, height);
				vec3 color = mix(base, vec3(1.0, 0.98, 0.93), rim);
				float alpha = 1.0 - exp(-density * step_size * 0.055);
				accum += color * alpha * transmittance;
				transmittance *= 1.0 - alpha;
			}
		}
	}
	return vec4(accum + bg * transmittance, 1.0);
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = background(EYEDIR);
	} else if (AT_HALF_RES_PASS) {
		vec4 result = render_clouds(EYEDIR);
		COLOR = result.rgb;
		ALPHA = 1.0;
	} else {
		COLOR = HALF_RES_COLOR.rgb;
	}
}
