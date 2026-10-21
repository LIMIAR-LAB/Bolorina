// Bolorina 21/10: feixe de luz (god ray falso) aditivo, some nas bordas e na ponta.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform vec3 cor : source_color = vec3(1.0, 0.7, 0.4);
uniform float forca = 0.18;
void fragment(){
	float lados = sin(UV.x * 3.14159);
	float ponta = smoothstep(1.0, 0.0, UV.y) * smoothstep(0.0, 0.15, UV.y);
	float pulso = 0.8 + 0.2 * sin(TIME * 0.6 + UV.x * 4.0);
	ALBEDO = cor * forca * lados * lados * ponta * pulso;
}
