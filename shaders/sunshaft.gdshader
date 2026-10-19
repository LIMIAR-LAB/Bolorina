shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
uniform float intensity=1.0;
void fragment(){
 float edge=pow(max(0.0,sin(UV.x*3.14159265)),3.0);
 float length_fade=smoothstep(0.02,0.2,UV.y)*(1.0-smoothstep(0.7,1.0,UV.y));
 float streak=0.8+sin(UV.x*27.0+UV.y*1.8)*0.2;
 ALBEDO=vec3(1.0,0.8,0.45);
 ALPHA=edge*length_fade*streak*0.075*intensity;
}
