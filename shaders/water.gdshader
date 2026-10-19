shader_type spatial;
render_mode cull_disabled;
uniform bool stream_mode = false;
varying vec3 world_pos;
void vertex() {
 world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y += sin(VERTEX.x*0.3+TIME*0.6)*0.08+sin(VERTEX.z*0.5-TIME*0.4)*0.05;
}
void fragment() {
 float wave = sin(world_pos.x*2.0+sin(world_pos.z*0.8+TIME)*1.8+TIME*0.6);
 float streak = pow(max(0.0,wave),14.0)*0.025;
 ALBEDO = vec3(0.025,0.065,0.075)+vec3(streak*0.8,streak,streak);
 METALLIC = 0.0;
 ROUGHNESS = stream_mode ? 0.27 : 0.42;
 SPECULAR = stream_mode ? 0.32 : 0.2;
 float foam = stream_mode ? smoothstep(0.85,1.42,abs(world_pos.z-7.5)) : 0.0;
 ALBEDO = mix(ALBEDO,vec3(0.4,0.48,0.43),foam*0.6);
 NORMAL_MAP = vec3(0.5+sin(world_pos.x*0.48+world_pos.z*0.2+TIME)*0.02,0.5+cos(world_pos.z*0.38+world_pos.x*0.12-TIME)*0.02,1.0);
}


