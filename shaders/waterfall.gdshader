shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float lines=sin(world.z*37.0+sin(world.y*3.0+TIME*4.0))*0.5+0.5;
 float flow=sin(world.y*18.0+TIME*9.0+world.z*8.0)*0.5+0.5;
 ALBEDO=mix(vec3(0.08,0.16,0.18),vec3(0.49,0.58,0.54),lines*flow);
 ROUGHNESS=0.35;
 SPECULAR=0.5;
 NORMAL_MAP=vec3(0.5+lines*0.08,0.5+flow*0.08,1.0);
}
