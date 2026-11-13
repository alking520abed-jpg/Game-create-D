shader_type spatial;
// أرضية المدينة: شوارع، أرصفة، حدائق، مواقف، رمل - كلها مرسومة بالكود
uniform sampler2D block_tex : filter_nearest, repeat_disable;
uniform float night = 0.0;
const float CELL = 72.0;
const float HALF = 324.0;
const float N = 9.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = wp.xz;
	vec2 g = p + HALF;
	vec2 k = clamp(floor(g / CELL + 0.5), 0.0, N);
	vec2 d = abs(g - k * CELL);
	float n1 = noise(p * 0.9);
	float n2 = noise(p * 0.06);
	vec3 col;
	float rough = 0.95;
	bool on_v = d.x < 7.0 && abs(p.y) < HALF + 7.0;
	bool on_h = d.y < 7.0 && abs(p.x) < HALF + 7.0;
	bool in_city = abs(p.x) < HALF + 11.0 && abs(p.y) < HALF + 11.0;
	if (on_v || on_h) {
		col = vec3(0.115, 0.12, 0.135) * (0.8 + 0.35 * n1) * (0.9 + 0.2 * n2);
		rough = 0.8;
		bool inter = d.x < 7.0 && d.y < 7.0;
		if (!inter) {
			float across = on_v ? d.x : d.y;
			float al = on_v ? g.y : g.x;
			float dint = on_v ? d.y : d.x;
			if (across < 0.14 && fract(al / 6.0) < 0.55 && dint > 14.0) {
				col = vec3(0.85, 0.65, 0.12);
			}
			if (abs(across - 6.45) < 0.09 && dint > 12.5) {
				col = vec3(0.75);
			}
			if (dint > 8.3 && dint < 11.8 && across < 6.2 && fract(across / 1.3 + 0.25) < 0.5) {
				col = vec3(0.82);
			}
			if (abs(dint - 13.0) < 0.2 && across < 6.3) {
				col = vec3(0.75);
			}
		}
	} else if (in_city && (d.x < 11.0 || d.y < 11.0)) {
		vec2 t = fract(p / 1.25);
		float line = min(1.0, step(0.95, t.x) + step(0.95, t.y));
		col = vec3(0.62, 0.59, 0.54) * (0.9 + 0.14 * n1) * (1.0 - 0.18 * line);
		if (d.x < 7.35 || d.y < 7.35) {
			col = vec3(0.42, 0.42, 0.44);
		}
	} else if (in_city) {
		vec2 b = clamp(floor(g / CELL), 0.0, N - 1.0);
		float ty = floor(texture(block_tex, (b + 0.5) / N).r * 255.0 + 0.5);
		vec2 l = g - (b + 0.5) * CELL;
		if (ty == 1.0) {
			// حديقة
			float gn = noise(p * 0.35);
			col = mix(vec3(0.16, 0.42, 0.12), vec3(0.3, 0.55, 0.16), gn) * (0.85 + 0.3 * n1);
			float path = min(abs(l.x), abs(l.y));
			float ring = abs(length(l) - 9.0);
			if (path < 1.6 || ring < 1.3 || length(l) < 5.0) {
				col = vec3(0.7, 0.62, 0.48) * (0.85 + 0.3 * n1);
			}
		} else if (ty == 2.0) {
			// موقف سيارات
			col = vec3(0.2, 0.2, 0.22) * (0.85 + 0.3 * n1);
			float yy = abs(l.y);
			bool stall = (yy > 4.0 && yy < 9.5) || (yy > 15.5 && yy < 21.0);
			if (stall && abs(l.x) < 22.6 && abs(fract(l.x / 3.0 + 0.5) - 0.5) < 0.035) {
				col = vec3(0.8);
			}
		} else if (ty >= 3.0) {
			// ساحة مزخرفة
			vec2 q = l / 3.0;
			vec2 r = vec2(q.x + q.y, q.x - q.y) * 0.7071;
			vec2 f1 = abs(fract(q) - 0.5);
			vec2 f2 = abs(fract(r) - 0.5);
			float star = min(max(f1.x, f1.y), max(f2.x, f2.y));
			vec3 a = vec3(0.78, 0.7, 0.56);
			vec3 c2 = vec3(0.55, 0.36, 0.26);
			vec3 c3 = vec3(0.2, 0.45, 0.5);
			col = star < 0.2 ? c3 : (star < 0.3 ? c2 : a);
			col *= 0.88 + 0.2 * n1;
		} else {
			vec2 t = fract(p / 2.5);
			float line = min(1.0, step(0.97, t.x) + step(0.97, t.y));
			col = vec3(0.52, 0.51, 0.5) * (0.88 + 0.18 * n1) * (1.0 - 0.15 * line);
		}
	} else {
		// صحراء وشاطئ
		float rip = sin(p.x * 0.55 + n2 * 9.0 + p.y * 0.2) * 0.03;
		col = mix(vec3(0.8, 0.62, 0.38), vec3(0.9, 0.76, 0.5), n2) * (0.92 + 0.14 * n1) + rip;
		float beach = smoothstep(HALF + 11.0, HALF + 30.0, p.y);
		col = mix(col, vec3(0.93, 0.85, 0.66) * (0.94 + 0.1 * n1), beach);
		float wet = smoothstep(388.0, 399.0, p.y + sin(p.x * 0.08 + TIME * 0.6) * 1.5);
		col = mix(col, vec3(0.6, 0.52, 0.38), wet);
		rough = mix(0.95, 0.4, wet);
	}
	if (night > 0.01 && in_city) {
		// بقع ضوء أعمدة الإنارة
		vec2 m = (floor(g / CELL) + 0.5) * CELL;
		vec2 kk = k * CELL;
		vec2 q1 = g - vec2(kk.x + 6.8, m.y + 15.0);
		vec2 q2 = g - vec2(kk.x - 6.8, m.y - 15.0);
		vec2 q3 = g - vec2(m.x + 15.0, kk.y + 6.8);
		vec2 q4 = g - vec2(m.x - 15.0, kk.y - 6.8);
		float glow = exp(-dot(q1, q1) / 70.0) + exp(-dot(q2, q2) / 70.0) + exp(-dot(q3, q3) / 70.0) + exp(-dot(q4, q4) / 70.0);
		EMISSION = col * vec3(1.0, 0.82, 0.55) * glow * night * 1.6;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
