shader_type spatial;
render_mode cull_disabled;
void vertex(){
 VERTEX.y+=sin(TIME*2.2+UV.y*5.0)*UV.y*0.05;
}
void fragment(){
 vec3 red=vec3(0.28,0.035,0.028);
 float stem=1.0-smoothstep(0.025,0.04,abs(UV.x-0.5));
 float ring=1.0-smoothstep(0.012,0.025,abs(length((UV-vec2(0.5,0.43))*vec2(1.0,1.8))-0.19));
 float mark=max(stem*step(0.25,UV.y)*step(UV.y,0.82),ring);
 ALBEDO=mix(red,vec3(0.72,0.48,0.17),mark);
 ROUGHNESS=0.95;
}
