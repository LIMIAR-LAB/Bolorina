shader_type spatial;
render_mode cull_disabled;
uniform float canopy_visibility=1.0;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(world.x*1.5+world.z+TIME*1.8)*0.025;
 VERTEX.y+=sin(world.z*1.3-TIME)*0.015;
}
void fragment(){
 float pattern=fract(sin(dot(floor(FRAGCOORD.xy/2.0),vec2(12.9898,78.233)))*43758.5453);
 if(pattern>canopy_visibility){discard;}
 vec3 leaf=pow(COLOR.rgb,vec3(2.2));
 ALBEDO=leaf;
 BACKLIGHT=leaf*0.22;
 ROUGHNESS=0.85;
 SPECULAR=0.15;
}
