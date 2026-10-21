// Bolorina 21/10 (passo 2): chao do planalto do Mirante. Grama dourada com manchas, flores miudas
// e a trilha de terra serpenteando ate o altar (em coordenadas locais da malha).
shader_type spatial;
uniform vec3 grama_a : source_color = vec3(0.36, 0.42, 0.16);
uniform vec3 grama_b : source_color = vec3(0.62, 0.58, 0.22);
uniform vec3 terra : source_color = vec3(0.50, 0.36, 0.24);
uniform vec3 pedra : source_color = vec3(0.58, 0.52, 0.46);
uniform float trilha_z0 = -15.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
varying vec3 l;
void vertex(){ l = VERTEX; }
void fragment(){
	vec2 p = l.xz;
	float m = n(p * 0.35) * 0.6 + n(p * 1.3) * 0.3 + n(p * 6.0) * 0.1;
	vec3 c = mix(grama_a, grama_b, smoothstep(0.3, 0.75, m));
	// tufos escuros e claros
	c *= 0.86 + 0.22 * n(p * 9.0);
	// flores miudas
	vec2 cel = floor(p * 3.0);
	float fl = step(0.93, h(cel)) * smoothstep(0.32, 0.12, length(fract(p * 3.0) - 0.5));
	vec3 cor_flor = mix(vec3(0.95, 0.85, 0.55), vec3(0.85, 0.45, 0.55), h(cel + 3.1));
	c = mix(c, cor_flor, fl * 0.9);
	// trilha ate o altar
	float cx = sin(p.y * 0.22) * 1.3;
	float d = abs(p.x - cx) + (n(p * 2.0) - 0.5) * 0.5;
	float t = smoothstep(1.25, 0.9, d) * step(trilha_z0, p.y);
	vec3 ct = mix(terra, pedra, step(0.62, n(p * 2.6)) * 0.7);
	c = mix(c, ct * (0.85 + 0.25 * n(p * 7.0)), t);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
