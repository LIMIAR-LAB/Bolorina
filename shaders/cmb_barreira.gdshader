shader_type spatial;
// Barreira da porta fechada: cortina vermelha com faixas que sobem.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float aberto = 0.0;
void fragment() {
	float faixa = 0.5 + 0.5 * sin(UV.y * 30.0 + TIME * 4.0);
	float borda = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	float a = (0.25 + 0.35 * faixa) * borda * (1.0 - UV.y * 0.6) * (1.0 - aberto);
	ALBEDO = vec3(1.0, 0.2, 0.08) * 1.8;
	ALPHA = clamp(a, 0.0, 1.0);
}
