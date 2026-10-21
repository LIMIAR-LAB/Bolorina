// Bolorina 21/10: rocha em estratos (triplanar), topo com musgo dourado, para os penhascos do mirante.
shader_type spatial;
uniform vec3 pedra_a : source_color = vec3(0.36, 0.30, 0.33);
uniform vec3 pedra_b : source_color = vec3(0.56, 0.46, 0.42);
uniform vec3 musgo : source_color = vec3(0.55, 0.50, 0.22);
uniform float topo_musgo = 0.72;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
varying vec3 w;
varying vec3 wn;
void vertex(){ w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment(){
	float estr = n(vec2(w.y * 1.6 + n(w.xz * 0.15) * 2.5, 0.0));
	float grao = n(w.xz * 2.0 + w.y) * 0.5 + n(vec2(w.x + w.z, w.y) * 3.0) * 0.5;
	vec3 c = mix(pedra_a, pedra_b, estr * 0.7 + grao * 0.3);
	c *= 0.85 + 0.15 * smoothstep(0.4, 0.6, n(vec2(w.y * 6.0, w.x * 0.2 + w.z * 0.2)));
	float m = smoothstep(topo_musgo, topo_musgo + 0.12, wn.y) * (0.6 + 0.4 * n(w.xz * 0.8));
	c = mix(c, musgo * (0.8 + 0.4 * grao), m);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
