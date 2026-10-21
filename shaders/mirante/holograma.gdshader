// Bolorina 21/10 (passo 2): holograma neon (linhas de varredura, cintilacao, bordas brilhantes).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 cor : source_color = vec3(0.2, 0.9, 1.0);
uniform float forca = 1.4;
uniform sampler2D textura : source_color, filter_nearest;
uniform bool usa_textura = false;
void fragment(){
	float linhas = 0.65 + 0.35 * sin(UV.y * 160.0 - TIME * 6.0);
	float cint = 0.85 + 0.15 * sin(TIME * 23.0) * sin(TIME * 7.0);
	float borda = max(smoothstep(0.06, 0.0, min(UV.x, 1.0 - UV.x)), smoothstep(0.06, 0.0, min(UV.y, 1.0 - UV.y)));
	float base = 0.18 + borda * 0.9;
	if (usa_textura) { vec4 t = texture(textura, UV); base = max(base * 0.4, t.a * (0.4 + dot(t.rgb, vec3(0.33)))); }
	float sobe = 1.0 - UV.y * 0.35;
	ALBEDO = cor * base * linhas * cint * forca * sobe;
}
