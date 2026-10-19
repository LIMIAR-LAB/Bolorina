shader_type spatial;
render_mode cull_disabled;
varying float height;
void vertex(){
 height=VERTEX.y;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*1.5+world.x*0.7+world.z)*height*0.045;
}
void fragment(){
 ALBEDO=mix(vec3(0.1,0.18,0.045),vec3(0.39,0.5,0.15),clamp(height*3.0,0.0,1.0));
 ROUGHNESS=0.82;
 BACKLIGHT=vec3(0.1,0.15,0.05);
}
