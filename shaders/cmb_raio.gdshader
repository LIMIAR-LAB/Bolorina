shader_type spatial;
// Raio de Adamantium: energia aditiva sem luz. Nucleo branco-ciano em HDR (o glow faz o bloom),
// bordas azuis, faixas rolando ao longo do feixe. Tambem usado no orbe de carga.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 cor = vec3(0.45, 0.9, 1.0);
uniform float intensidade = 3.0;
uniform float alfa = 1.0;
uniform float rolagem = 1.0;
uniform float faixas = 40.0;
void fragment() {
	float f = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float nucleo = pow(f, 1.6);
	float ondas = 0.78 + 0.22 * sin(UV.y * faixas - TIME * rolagem * 38.0) * (0.6 + 0.4 * sin(UV.x * 18.85 + TIME * 7.0));
	ALBEDO = cor * intensidade * nucleo * ondas * alfa;
	ALPHA = clamp(nucleo * alfa, 0.0, 1.0);
}
