shader_type spatial;
// Anel da aura (teste Adamantium 99): aditivo, sem iluminacao, pixelado.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 tint = vec3(0.35, 0.9, 1.0);
uniform float pixels = 44.0;
void fragment() {
	vec2 uv = (floor(UV * pixels) + 0.5) / pixels - 0.5;
	float r = length(uv) * 2.0;
	float pulse = 0.5 + 0.5 * sin(TIME * 3.0 - r * 9.0);
	float band = smoothstep(0.62, 0.72, r) * (1.0 - smoothstep(0.86, 0.96, r));
	float inner = (1.0 - smoothstep(0.0, 0.7, r)) * 0.18;
	float a = (band * (0.55 + 0.45 * pulse) + inner) * 0.9;
	ALBEDO = tint * a;
	ALPHA = a;
}