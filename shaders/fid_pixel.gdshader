shader_type canvas_item;
// Filtro pixel art: amostra em blocos de 2 px, quantiza a paleta e escurece contornos.
uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform float bloco = 2.0;
uniform float niveis = 28.0;
void fragment(){
 vec2 px=1.0/SCREEN_PIXEL_SIZE;
 vec2 cell=(floor(FRAGCOORD.xy/bloco)+0.5)*bloco;
 vec2 uv=cell*SCREEN_PIXEL_SIZE;
 vec3 c=texture(tela,uv).rgb;
 vec3 n=texture(tela,uv+vec2(bloco,0.0)*SCREEN_PIXEL_SIZE).rgb;
 vec3 s=texture(tela,uv+vec2(0.0,bloco)*SCREEN_PIXEL_SIZE).rgb;
 float edge=length(c-n)+length(c-s);
 c=floor(c*niveis+0.5)/niveis;
 c*=1.0-smoothstep(0.18,0.5,edge)*0.35;
 COLOR=vec4(c,1.0);
}