shader_type spatial;
render_mode cull_disabled;
uniform float daylight=1.0;
varying vec3 world;
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=sin(world.x*1.2+world.z*2.0+TIME*1.4)*0.018;
}
void fragment(){
 float flow=sin(world.x*9.0+sin(world.z*14.0+TIME)*2.0-TIME*3.0);
 float glint=pow(max(0.0,flow),26.0)*pow(max(0.0,sin(world.z*21.0+world.x*1.3+TIME*1.3)),8.0);
 float edge=smoothstep(0.95,1.45,abs(world.z-7.5));
 ALBEDO=mix(vec3(0.035,0.15,0.18),vec3(0.14,0.26,0.25),edge);
 ALBEDO=mix(ALBEDO,mix(vec3(0.35,0.55,0.65),vec3(0.95,0.79,0.39),daylight),glint*0.8);
 EMISSION=vec3(0.65,0.52,0.26)*glint*daylight*0.18;
 ROUGHNESS=0.29;
 SPECULAR=0.3;
 NORMAL_MAP=normalize(vec3(sin(world.x*2.0+world.z*5.0-TIME*2.0)*0.1,cos(world.z*4.0+TIME)*0.08,1.0))*0.5+0.5;
 NORMAL_MAP_DEPTH=0.35;
}
