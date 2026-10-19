shader_type spatial;
// Telegrafo do golpe inimigo: borda vermelha + disco que enche ate o golpe.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float progresso = 0.0;
uniform float golpe = 0.0;
void fragment() {
	float d = length((UV - vec2(0.5)) * 2.0);
	float borda = smoothstep(0.86, 0.93, d) * (1.0 - smoothstep(0.97, 1.0, d));
	float disco = (1.0 - smoothstep(progresso - 0.04, progresso, d)) * step(d, 1.0);
	vec3 cor = vec3(1.0, 0.16, 0.08);
	float a = borda * 0.9 + disco * (0.18 + 0.25 * progresso);
	a = mix(a, (1.0 - smoothstep(0.9, 1.0, d)) * 0.85, golpe);
	ALBEDO = mix(cor, vec3(1.0, 0.7, 0.4), golpe) * 1.6;
	ALPHA = clamp(a, 0.0, 1.0);
}
