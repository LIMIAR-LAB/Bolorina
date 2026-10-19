shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 world;
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float wind=sin(world.x*0.7+world.z*0.45+TIME*1.4)+sin(world.z*1.6-TIME*2.1)*0.3;
 VERTEX.x+=wind*0.022;
 VERTEX.z+=sin(world.x+TIME)*0.012;
}
void fragment(){
 vec4 tex=texture(leaf_albedo,UV);
 float leaf_light=dot(tex.rgb,vec3(0.2126,0.7152,0.0722));
 ALBEDO=mix(tex.rgb,leaf_light*vec3(0.8,1.25,0.5),0.55);
 ALPHA=tex.a;
 ALPHA_SCISSOR_THRESHOLD=0.42;
 NORMAL_MAP=texture(leaf_normal,UV).rgb;
 NORMAL_MAP_DEPTH=0.55;
 ROUGHNESS=0.53;
 SPECULAR=0.42;
 BACKLIGHT=leaf_light*vec3(0.85,1.15,0.22)*1.3;
}
