shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float d=length((UV-vec2(0.5))*2.0);
 ALBEDO=vec3(0.02,0.025,0.02);
 ALPHA=(1.0-smoothstep(0.1,1.0,d))*0.35;
}
