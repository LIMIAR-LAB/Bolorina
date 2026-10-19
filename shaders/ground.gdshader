shader_type spatial;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D path_normal : hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment() {
 vec3 grass = texture(grass_tex,world_pos.xz*0.28).rgb;
 vec3 path = texture(path_tex,world_pos.xz*0.36).rgb;
 float main_path = 1.0-smoothstep(1.05,2.1,abs(world_pos.x));
 float cross_path = 1.0-smoothstep(0.6,1.6,abs(world_pos.z+1.3));
 float patch = sin(world_pos.x*1.7)*sin(world_pos.z*2.3)*0.13;
 float blend = clamp(max(main_path,cross_path)+patch,0.0,1.0);
 vec3 ground = mix(grass*vec3(0.62,1.03,0.59),path*vec3(0.93,0.88,0.78),blend);
 vec3 stone = texture(rock_tex,world_pos.xy*0.25).rgb;
 ALBEDO = mix(stone*0.65,ground,smoothstep(0.4,0.82,world_normal.y));
 NORMAL_MAP = mix(texture(grass_normal,world_pos.xz*0.28).rgb,texture(path_normal,world_pos.xz*0.36).rgb,blend);
 NORMAL_MAP_DEPTH = 0.6;
 ROUGHNESS = mix(0.94,0.48,(1.0-smoothstep(1.5,3.0,abs(world_pos.z-7.5)))*blend);
}


