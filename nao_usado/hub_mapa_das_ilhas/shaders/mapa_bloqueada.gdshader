shader_type canvas_item;
// Ilha bloqueada no mapa: dessatura e escurece (quantidade 0..1).
uniform float quantidade : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(l), vec3(l) * vec3(0.78, 0.8, 0.95), 0.5) * 0.78;
	COLOR = vec4(mix(c.rgb, g, quantidade), c.a);
}
