// Bolorina 21/10: cortina de agua da cachoeira. Faixas que descem, espuma nas bordas e no topo,
// borda iluminada pelo poente (emissao quente) para ler bem contra o ceu.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform float vel = 1.4;
uniform vec3 cor_fundo : source_color = vec3(0.10, 0.22, 0.30);
uniform vec3 cor_espuma : source_color = vec3(0.92, 0.90, 0.86);
uniform vec3 cor_poente : source_color = vec3(1.0, 0.62, 0.35);
uniform float semente = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	vec2 uv = UV;
	float col = n(vec2(uv.x * 38.0 + semente, 0.0)) * 0.6 + n(vec2(uv.x * 90.0 + semente, 1.0)) * 0.4;
	float desce = n(vec2(uv.x * 30.0 + semente, uv.y * 7.0 - TIME * vel * (0.8 + col * 0.6)));
	float faixa = smoothstep(0.35, 0.95, desce * 0.6 + col * 0.6);
	float topo = smoothstep(0.12, 0.0, uv.y);
	float base = smoothstep(0.82, 1.0, uv.y);
	float esp = clamp(faixa * 0.85 + topo + base * 0.9, 0.0, 1.0);
	vec3 c = mix(cor_fundo, cor_espuma, esp);
	ALBEDO = c;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	EMISSION = cor_poente * (0.10 + esp * 0.35) + c * 0.08;
	float bordas = smoothstep(0.0, 0.07, uv.x) * smoothstep(1.0, 0.93, uv.x);
	ALPHA = clamp(bordas * (0.72 + esp * 0.28), 0.0, 1.0);
}
