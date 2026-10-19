shader_type spatial;
render_mode cull_disabled;
// Folhagem com balanco de vento (cor por vertice x cor da instancia).
uniform float vento = 1.0;
uniform float altura_ref = 1.0;
uniform float forca = 0.07;
void vertex(){
 vec3 w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float k=clamp(VERTEX.y/altura_ref,0.0,1.0);
 float s=sin(TIME*1.6+w.x*0.55+w.z*0.35)+0.45*sin(TIME*3.3+w.x*1.7-w.z*0.9);
 VERTEX.x+=s*forca*k*vento;
 VERTEX.z+=s*forca*0.6*k*vento;
}
void fragment(){
 vec3 c=pow(COLOR.rgb,vec3(2.2));
 ALBEDO=c;
 BACKLIGHT=c*0.3;
 ROUGHNESS=0.88;
 SPECULAR=0.15;
}