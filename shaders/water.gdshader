shader_type spatial;
uniform float night = 0.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float w = sin(p.x * 0.12 + TIME * 0.9) * 0.5 + sin(p.y * 0.2 - TIME * 1.3 + p.x * 0.05) * 0.5;
	float w2 = sin(p.x * 0.7 + p.y * 0.5 + TIME * 1.8) * sin(p.y * 0.9 - TIME * 1.1);
	float depth = smoothstep(400.0, 520.0, p.y);
	vec3 col = mix(vec3(0.16, 0.66, 0.68), vec3(0.03, 0.25, 0.48), depth);
	col += w2 * 0.035 + w * 0.02;
	float shore = p.y - 400.0 + sin(p.x * 0.08 + TIME * 0.6) * 1.5;
	float foam = smoothstep(3.5, 0.5, shore) + smoothstep(0.75, 1.0, w2 * w) * 0.25 * (1.0 - depth);
	col = mix(col, vec3(0.95), clamp(foam, 0.0, 1.0));
	ALBEDO = col * mix(1.0, 0.35, night);
	ROUGHNESS = 0.12;
	METALLIC = 0.2;
	SPECULAR = 0.6;
	NORMAL_MAP = vec3(0.5 + w2 * 0.12, 0.5 + w * 0.1, 1.0);
}
