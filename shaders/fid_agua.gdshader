shader_type spatial;
render_mode cull_disabled;
// Agua do rio: normais rolando, especular alto e espuma nas margens (UV.y 0..1 atravessa o rio).
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float efeitos = 1.0;
uniform vec3 raso : source_color = vec3(0.16,0.33,0.33);
uniform vec3 fundo : source_color = vec3(0.03,0.10,0.14);
varying vec3 world;
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(world.x*1.1+world.z*1.7+TIME*1.3)*0.02*efeitos;
}
void fragment(){
 vec2 uv=world.xz*0.18;
 vec3 na=texture(normal_a,uv+vec2(TIME*0.035,TIME*0.02)*efeitos).rgb;
 vec3 nb=texture(normal_b,uv*1.7-vec2(TIME*0.02,-TIME*0.045)*efeitos).rgb;
 vec3 n=normalize(mix(vec3(0.5,0.5,1.0),(na+nb)*0.5,0.85*efeitos+0.15));
 float borda=min(UV.y,1.0-UV.y);
 float prof=smoothstep(0.0,0.35,borda);
 vec3 cor=mix(raso,fundo,prof);
 float ruido=texture(normal_a,uv*3.0+vec2(TIME*0.05,0.0)).r;
 float espuma=(1.0-smoothstep(0.02,0.11,borda))*smoothstep(0.35,0.7,ruido)*efeitos;
 ALBEDO=mix(cor,vec3(0.78,0.80,0.72),espuma*0.75);
 float brilho=pow(clamp(texture(normal_b,uv*4.0+vec2(-TIME*0.08,TIME*0.03)*efeitos).g,0.0,1.0),14.0)*(1.0-espuma);
 EMISSION=vec3(1.0,0.78,0.45)*brilho*1.6;
 ROUGHNESS=mix(0.06,0.6,espuma);
 METALLIC=0.0;
 SPECULAR=0.9;
 NORMAL_MAP=n;
 NORMAL_MAP_DEPTH=0.9;
}