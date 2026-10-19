shader_type spatial;
render_mode cull_disabled;
// Estandarte vermelho com emblema de arvore (tronco + copa + raizes) e balanco ao vento.
uniform float vento = 1.0;
void vertex(){
 VERTEX.x+=sin(TIME*2.0+UV.y*5.0)*UV.y*0.06*vento;
}
void fragment(){
 vec2 p=UV-vec2(0.5,0.45);
 vec3 red=vec3(0.36,0.04,0.035)*(0.85+0.15*sin(UV.y*40.0));
 float trunk=(1.0-smoothstep(0.03,0.045,abs(p.x)))*step(-0.05,p.y)*step(p.y,0.28);
 float crown=1.0-smoothstep(0.0,0.02,abs(length(p*vec2(1.0,1.25)-vec2(0.0,-0.12))-0.2));
 float branch=(1.0-smoothstep(0.015,0.03,abs(abs(p.x)-(-p.y+0.02)*0.8)))*step(-0.18,p.y)*step(p.y,0.02);
 float roots=(1.0-smoothstep(0.015,0.03,abs(abs(p.x)-(p.y-0.22)*0.9)))*step(0.22,p.y)*step(p.y,0.33);
 float mark=max(max(trunk,crown),max(branch,roots));
 float hem=step(0.92,UV.y)*step(0.5,fract(UV.x*6.0));
 if(hem>0.5 && UV.y>0.96){discard;}
 ALBEDO=mix(red,vec3(0.85,0.62,0.28),mark);
 ROUGHNESS=0.95;
}