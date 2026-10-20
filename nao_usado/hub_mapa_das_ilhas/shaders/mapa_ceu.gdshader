shader_type canvas_item;
// Céu do mapa das ilhas: crepúsculo de cinzas, estrelas, nuvens em fbm e mar de cinza embaixo.
uniform float velocidade = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * ruido(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.012 * velocidade;
	vec3 topo = vec3(0.06, 0.05, 0.14);
	vec3 meio = vec3(0.27, 0.14, 0.25);
	vec3 baixo = vec3(0.86, 0.43, 0.24);
	vec3 c = mix(topo, meio, smoothstep(0.0, 0.62, uv.y));
	c = mix(c, baixo, smoothstep(0.55, 1.0, uv.y) * 0.8);
	vec2 ce = floor(uv * vec2(420.0, 236.0));
	float est = step(0.9965, hash(ce)) * (1.0 - smoothstep(0.0, 0.5, uv.y));
	est *= 0.55 + 0.45 * sin(TIME * (1.0 + hash(ce + 3.1) * 3.0) + hash(ce) * 30.0);
	c += vec3(est) * 0.8;
	float n = fbm(uv * vec2(2.6, 4.6) + vec2(t * 3.0, 0.0));
	float n2 = fbm(uv * vec2(5.5, 8.5) - vec2(t * 5.0, t));
	float nuvem = smoothstep(0.5, 0.86, n) * 0.6;
	c = mix(c, mix(vec3(0.50, 0.34, 0.44), vec3(1.0, 0.70, 0.50), uv.y), nuvem * (0.35 + uv.y * 0.6));
	c = mix(c, vec3(1.0, 0.80, 0.62), smoothstep(0.62, 0.9, n2) * 0.16 * uv.y);
	float mar = smoothstep(0.84, 1.0, uv.y);
	vec3 cinza = vec3(0.32, 0.19, 0.18) + 0.16 * fbm(uv * vec2(22.0, 7.0) + vec2(t * 9.0, 0.0));
	c = mix(c, cinza, mar * 0.65);
	vec2 q = uv - 0.5;
	c *= 1.0 - dot(q, q) * 0.85;
	COLOR = vec4(c, 1.0);
}
