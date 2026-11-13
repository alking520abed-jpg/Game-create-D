shader_type spatial;
// عمارات: نوافذ ومحلات مرسومة بالكود، وتضيء في الليل
uniform float night = 0.0;
varying vec2 wuv;
varying float is_side;
varying float seed;
varying float bh;
varying float face_w;

void vertex() {
	vec3 size = INSTANCE_CUSTOM.xyz;
	seed = INSTANCE_CUSTOM.w;
	vec3 lp = VERTEX * size;
	bh = size.y;
	if (abs(NORMAL.y) > 0.5) {
		is_side = 0.0;
		wuv = lp.xz;
		face_w = 1.0;
	} else {
		is_side = 1.0;
		bool xf = abs(NORMAL.x) > 0.5;
		float u = xf ? lp.z : lp.x;
		face_w = xf ? size.z : size.x;
		wuv = vec2(u + face_w * 0.5, lp.y + size.y * 0.5);
	}
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	vec3 wall = COLOR.rgb;
	vec3 col = wall;
	float rough = 0.9;
	float metal = 0.0;
	vec3 emi = vec3(0.0);
	if (is_side < 0.5) {
		col = wall * 0.55;
		if (seed >= 0.0) {
			vec2 e = abs(fract(wuv / 4.0) - 0.5);
			col *= 0.9 + 0.1 * step(0.03, min(e.x, e.y));
		}
	} else if (seed >= 0.0) {
		float fw = 2.7;
		float fh = 3.3;
		float ncol = max(1.0, floor(face_w / fw));
		float cw = face_w / ncol;
		vec2 c = vec2(wuv.x / cw, wuv.y / fh);
		vec2 id = floor(c);
		vec2 f = fract(c);
		float style = fract(seed * 7.31);
		bool win = false;
		if (wuv.y < fh) {
			// الطابق الأرضي: محلات
			if (f.x > 0.07 && f.x < 0.93 && f.y > 0.1 && f.y < 0.7) {
				win = true;
			} else if (f.y > 0.76 && f.y < 0.95) {
				float hh = hash(vec2(id.x, seed));
				col = hh < 0.33 ? vec3(0.7, 0.16, 0.12) : (hh < 0.66 ? vec3(0.1, 0.4, 0.42) : vec3(0.85, 0.6, 0.15));
			}
		} else if (wuv.y < bh - 0.9) {
			if (style < 0.36) {
				win = f.x > 0.22 && f.x < 0.78 && f.y > 0.25 && f.y < 0.75;
			} else if (style < 0.68) {
				win = f.y > 0.3 && f.y < 0.78 && f.x > 0.04 && f.x < 0.96;
			} else {
				win = f.x > 0.05 && f.y > 0.07;
			}
		} else {
			col = wall * 0.8;
		}
		if (win) {
			float h = hash(id + seed * 13.7);
			vec3 day = mix(vec3(0.07, 0.13, 0.2), vec3(0.3, 0.5, 0.66), f.y * 0.8 + 0.2 * h);
			col = mix(day, day * 0.25, night);
			rough = 0.12;
			metal = 0.45;
			float lit = step(0.62, h) * night;
			if (wuv.y < fh) {
				lit = night;
			}
			vec3 warm = mix(vec3(1.0, 0.78, 0.4), vec3(0.75, 0.9, 1.0), step(0.86, h));
			emi = warm * lit * (0.45 + 0.5 * fract(h * 9.0));
			col = mix(col, warm * 0.5, lit * 0.6);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emi;
}
