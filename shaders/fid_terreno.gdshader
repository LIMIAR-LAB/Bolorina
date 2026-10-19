shader_type spatial;
// Terreno modular: COLOR = pesos (r caminho, g terra/horta, b rocha), a = sulcos do campo arado.
uniform sampler2D grama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pedra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D terra : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rocha : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tom_grama : source_color = vec3(0.42,0.52,0.20);
uniform vec3 tom_pedra : source_color = vec3(0.86,0.70,0.50);
uniform vec3 tom_terra : source_color = vec3(0.55,0.38,0.24);
uniform vec3 tom_rocha : source_color = vec3(0.45,0.45,0.42);
varying vec3 world;
varying vec3 wn;
void vertex(){ world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; wn=(MODEL_MATRIX*vec4(NORMAL,0.0)).xyz; }
void fragment(){
 vec2 uv=world.xz;
 vec3 g=texture(grama,uv*0.35).rgb*tom_grama*1.6;
 float var=texture(grama,uv*0.05).g;
 g*=mix(0.75,1.2,var);
 vec3 c=texture(pedra,uv*0.42).rgb*tom_pedra*1.35;
 vec3 t=texture(terra,uv*0.3).rgb*tom_terra*1.4;
 float sulco=0.5+0.5*sin(world.x*5.2);
 t*=mix(1.0,mix(0.62,1.12,sulco),COLOR.a);
 vec2 side=abs(wn.x)>abs(wn.z)?world.zy:world.xy;
 vec3 r=texture(rocha,side*0.22).rgb*tom_rocha*1.3;
 float steep=smoothstep(0.55,0.85,1.0-normalize(wn).y);
 vec3 a=mix(g,c,COLOR.r);
 a=mix(a,t,COLOR.g);
 a=mix(a,r,max(COLOR.b,steep));
 ALBEDO=a;
 ROUGHNESS=0.92;
 SPECULAR=0.2;
}