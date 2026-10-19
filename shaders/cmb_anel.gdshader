shader_type spatial;
// Anel de fogo do especial (procedural): expande e some; laranja quente com borda clara.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float t = 0.0;
uniform vec3 cor : source_color = vec3(1.0, 0.45, 0.1);
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float d = length(p);
	float r = mix(0.15, 0.95, sqrt(clamp(t, 0.0, 1.0)));
	float w = mix(0.22, 0.05, t);
	float anel = 1.0 - smoothstep(0.0, w, abs(d - r));
	float ang = atan(p.y, p.x);
	float chama = 0.75 + 0.25 * sin(ang * 14.0 + t * 20.0);
	float a = anel * chama * (1.0 - t);
	ALBEDO = mix(cor, vec3(1.0, 0.9, 0.6), anel * 0.6) * 2.4;
	ALPHA = clamp(a, 0.0, 1.0);
}
