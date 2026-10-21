// Bolorina 21/10: ceu de por do sol pintado (fundo que acompanha a camera). Nuvens, sol com halo HDR
// (o glow do WorldEnvironment faz o brilho) e tres camadas de montanhas em silhueta.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
uniform float horizonte = 0.55;
uniform vec2 sol = vec2(0.5, 0.52);
uniform vec3 cor_topo : source_color = vec3(0.09, 0.07, 0.20);
uniform vec3 cor_meio : source_color = vec3(0.52, 0.22, 0.38);
uniform vec3 cor_horizonte : source_color = vec3(1.0, 0.60, 0.28);
uniform vec3 cor_bruma : source_color = vec3(0.42, 0.22, 0.30);
uniform float aspecto = 1.78;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++){ v += a*n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment(){
	vec2 uv = UV;
	float y = uv.y;
	// gradiente do ceu
	float t = clamp((y) / horizonte, 0.0, 1.0);
	vec3 c = mix(cor_topo, cor_meio, smoothstep(0.0, 0.65, t));
	c = mix(c, cor_horizonte, smoothstep(0.55, 1.0, t));
	vec2 d = vec2((uv.x - sol.x) * aspecto, uv.y - sol.y);
	float r = length(d);
	// halo grande do sol
	c += cor_horizonte * 0.9 * exp(-r * 5.0);
	c += vec3(1.0, 0.75, 0.45) * 0.6 * exp(-r * 14.0);
	// nuvens em faixas
	vec2 q = vec2(uv.x * 3.0 + TIME * 0.004, y * 14.0);
	float nv = fbm(q + fbm(q * 0.7) * 1.4);
	float faixa = smoothstep(0.15, 0.9, t) * (1.0 - smoothstep(0.92, 1.0, t));
	float nuvem = smoothstep(0.52, 0.78, nv) * faixa;
	vec3 cor_nuvem = mix(vec3(0.35, 0.16, 0.30), vec3(1.0, 0.55, 0.35), smoothstep(0.4, 1.0, t)) + vec3(1.0, 0.6, 0.3) * exp(-r * 4.0) * 0.8;
	c = mix(c, cor_nuvem, nuvem * 0.8);
	// disco do sol (HDR, por cima das nuvens finas)
	c = mix(c, vec3(6.0, 4.2, 2.4), smoothstep(0.042, 0.034, r) * (1.0 - nuvem * 0.6));
	// abaixo do horizonte: bruma
	if (y > horizonte) { c = mix(cor_horizonte * 0.8, cor_bruma, smoothstep(horizonte, 1.0, y)); }
	// montanhas (3 camadas, mais escuras na frente)
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float alt = horizonte + 0.012 + fi * 0.012 - (0.17 - 0.045 * fi) * fbm(vec2(uv.x * (2.2 + fi * 1.9) + fi * 7.3, fi * 3.1));
		float dentro = smoothstep(alt - 0.002, alt + 0.002, y);
		vec3 cm = mix(cor_horizonte * 0.7, vec3(0.09, 0.05, 0.12), 0.30 + fi * 0.30);
		cm += vec3(1.0, 0.5, 0.25) * exp(-r * 6.0) * (0.45 - fi * 0.14);
		c = mix(c, cm, dentro);
	}
	ALBEDO = c;
}
