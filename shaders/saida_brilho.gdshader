shader_type spatial;
// Marcador de saida no chao: faixa quente pulsante com setas (chevrons) correndo para fora da area.
// UV.x = atravessa a trilha, UV.y = 0 (dentro da area) -> 1 (saida).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 cor : source_color = vec4(1.0, 0.68, 0.3, 1.0);
uniform float intensidade = 1.8;

void fragment() {
	vec2 uv = UV;
	float borda = smoothstep(0.0, 0.22, uv.x) * smoothstep(0.0, 0.22, 1.0 - uv.x);
	float fundo = smoothstep(0.0, 0.2, uv.y) * smoothstep(0.0, 0.45, 1.0 - uv.y);
	float c = fract(uv.y * 2.2 - abs(uv.x - 0.5) * 1.4 - TIME * 0.55);
	float chev = smoothstep(0.0, 0.07, c) * smoothstep(0.3, 0.18, c);
	float pulso = 0.7 + 0.3 * sin(TIME * 2.6);
	float a = borda * fundo * (0.18 + 0.82 * chev) * pulso;
	ALBEDO = cor.rgb * intensidade;
	ALPHA = clamp(a * cor.a * 0.85, 0.0, 1.0);
}
