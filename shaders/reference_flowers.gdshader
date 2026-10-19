shader_type spatial;
render_mode cull_disabled;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*1.7+world.x*1.2+world.z)*VERTEX.y*0.10;
}
void fragment(){
 ALBEDO=COLOR.rgb;
 ROUGHNESS=0.9;
 BACKLIGHT=COLOR.rgb*0.28;
}
