shader_type spatial;
// Trilha gasta (terra batida ou pedra), desenhada por cima do terreno como uma faixa.
// UV.x = 0..1 atravessando; UV.y = metros ao longo da trilha.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float pedra = 0.0;
uniform float pegadas = 1.0;
uniform float largura = 2.2;
uniform vec4 cor_terra : source_color = vec4(0.52, 0.40, 0.27, 1.0);
uniform vec4 cor_terra2 : source_color = vec4(0.42, 0.32, 0.21, 1.0);
uniform vec4 cor_pedra : source_color = vec4(0.62, 0.60, 0.55, 1.0);
uniform vec4 cor_junta : source_color = vec4(0.30, 0.27, 0.22, 1.0);

float h(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.55); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), u.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 m = vec2(UV.x * largura, UV.y);          // metros
	float centro = abs(UV.x - 0.5) * 2.0;           // 0 no meio, 1 na borda
	float n = ruido(m * 3.0) * 0.6 + ruido(m * 9.0) * 0.4;
	// borda irregular, gasta
	float a = 1.0 - smoothstep(0.62, 1.0, centro + (n - 0.5) * 0.45);
	vec3 terra = mix(cor_terra2.rgb, cor_terra.rgb, n);
	terra *= 0.92 + 0.12 * ruido(m * 22.0);
	vec3 c = terra;
	if (pedra > 0.5) {
		// lajes irregulares (celulas) com juntas escuras
		vec2 g = m * vec2(1.6, 1.8);
		vec2 gi = floor(g + vec2(0.0, mod(floor(g.x), 2.0) * 0.5));
		vec2 gf = fract(g + vec2(0.0, mod(floor(g.x), 2.0) * 0.5));
		float junta = smoothstep(0.0, 0.09, min(min(gf.x, 1.0 - gf.x), min(gf.y, 1.0 - gf.y)));
		vec3 laje = cor_pedra.rgb * (0.8 + 0.3 * h(gi));
		c = mix(terra, mix(cor_junta.rgb, laje, junta), 1.0 - smoothstep(0.55, 0.9, centro));
	}
	// pegadas leves alternando esquerda/direita a cada 0,45 m
	if (pegadas > 0.5) {
		float passo = floor(m.y / 0.45);
		float lado = mod(passo, 2.0) < 1.0 ? -0.16 : 0.16;
		vec2 q = vec2(m.x - largura * 0.5 - lado, fract(m.y / 0.45) * 0.45 - 0.22);
		float pe = 1.0 - smoothstep(0.7, 1.0, length(q / vec2(0.055, 0.11)));
		c *= 1.0 - pe * 0.22;
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	ALPHA = a * 0.92;
}
