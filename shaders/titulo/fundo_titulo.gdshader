// Bolorina 21/10/2026: vida no fundo pintado da tela inicial.
// Brilho correndo nas cachoeiras (so nos pixels claros dentro de cada retangulo) e brilho do sol pulsando.
shader_type canvas_item;
uniform vec4 quedas[6];          // retangulos em UV da imagem: (x0, y0, x1, y1)
uniform int n_quedas = 6;
uniform vec2 sol = vec2(0.744, 0.304);
uniform float aspecto = 1.777;
uniform float forca_quedas = 0.22;
uniform float forca_sol = 0.16;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float t = TIME;
	float brilho = 0.0;
	float lum = dot(c.rgb, vec3(0.3, 0.5, 0.2));
	for (int i = 0; i < n_quedas; i++) {
		vec4 r = quedas[i];
		vec2 p = (UV - r.xy) / (r.zw - r.xy);
		if (p.x > 0.0 && p.x < 1.0 && p.y > 0.0 && p.y < 1.0) {
			float m = smoothstep(0.50, 0.80, lum);
			m *= smoothstep(0.0, 0.2, p.x) * smoothstep(1.0, 0.8, p.x) * smoothstep(0.0, 0.08, p.y) * smoothstep(1.0, 0.85, p.y);
			float escala = (r.w - r.y) * 40.0;
			float s1 = sin(p.y * escala * 6.0 - t * 7.0 + sin(p.x * 7.0) * 0.6) * 0.5 + 0.5;
			float s2 = sin(p.y * escala * 2.3 - t * 4.1 + p.x * 17.0) * 0.5 + 0.5;
			brilho += m * s1 * s2;
		}
	}
	c.rgb += vec3(0.86, 0.93, 1.0) * brilho * forca_quedas;
	vec2 d = (UV - sol) * vec2(aspecto, 1.0);
	float pulso = 0.5 + 0.5 * sin(t * 0.8);
	c.rgb += vec3(1.0, 0.70, 0.36) * exp(-dot(d, d) * 26.0) * forca_sol * (0.55 + 0.45 * pulso);
	c.rgb += vec3(1.0, 0.85, 0.6) * exp(-dot(d, d) * 260.0) * 0.12 * pulso;
	COLOR = c;
}
