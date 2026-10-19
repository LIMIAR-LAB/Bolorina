shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform float canopy_visibility=1.0;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(world.x*1.5+world.z+TIME*1.8)*0.025;
 VERTEX.y+=sin(world.z*1.3-TIME)*0.015;
}
void fragment(){
 float screen_pattern=fract(sin(dot(floor(FRAGCOORD.xy/2.0),vec2(12.9898,78.233)))*43758.5453);
 if(screen_pattern>canopy_visibility){discard;}
 ALBEDO=COLOR.rgb;
 BACKLIGHT=COLOR.rgb*vec3(0.9,1.0,0.45);
 ROUGHNESS=0.62;
 SPECULAR=0.36;
}
