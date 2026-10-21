// Bolorina 21/10: agua parada/corrente (rio do alto e poco da queda), reflexo quente do poente.
shader_type spatial;
render_mode cull_disabled;
uniform vec2 fluxo = vec2(0.0, 0.25);
uniform vec3 raso : source_color = vec3(0.16, 0.34, 0.40);
uniform vec3 fundo : source_color = vec3(0.05, 0.10, 0.16);
uniform vec3 brilho : source_color = vec3(1.0, 0.62, 0.32);
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
varying vec3 w;
void vertex(){ w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = w.xz * 0.6 + fluxo * TIME;
	float o = n(p * 2.0) * 0.6 + n(p * 5.0 + 3.1) * 0.4;
	vec3 c = mix(fundo, raso, o);
	float cintila = smoothstep(0.78, 0.95, n(p * 9.0 - TIME * 0.4));
	ALBEDO = c;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	EMISSION = brilho * cintila * 0.6;
	NORMAL_MAP = vec3(0.5 + (o - 0.5) * 0.3, 0.5 + (n(p * 3.0) - 0.5) * 0.3, 1.0);
}
