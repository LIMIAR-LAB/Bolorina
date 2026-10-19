# Notas de estilo — vídeo de referência
Fonte: "This Game Was Built Only With AI in 11 Weeks" (Stefan 3D AI), https://youtu.be/6a5VLKPlJRo, trecho 7:43–8:15, jogo mostrado: "Hollow Mire". Análise visual feita a partir do trecho baixado; itens marcados (incerto) não foram confirmados.

- Câmera ortográfica isométrica (~45° Y, 30–45° X). Tilt-shift forte: DoF desfocando topo e base, foco central no jogador (CameraAttributesPractical).
- Golden hour: luz dourada/laranja quente, sombras roxo/índigo frias; alto contraste e saturação (LUT/ajuste no WorldEnvironment).
- Sol do canto superior esquerdo, sombras longas para baixo-direita, bordas levemente suaves (PCF/PCSS).
- Sombra de contato em blob sob personagens (Decal). SSAO (incerto); cantos e grama densa mais escuros.
- Bloom forte: reflexo do sol na água, orbes, fogueira.
- Sem god rays volumétricos. Neblina leve/quente só como lavagem (incerto).
- Fogueira: OmniLight com cintilação por ruído; faíscas laranja rápidas subindo, vida curta.
- Vento: vertex shader com seno/ruído em grama, juncos e folhas.
- Água: plano com normal map rolando, especular alto (destaque estourando no bloom), espuma nas margens via profundidade.
- ORVALHO (efeito principal): pontos de 1–3 px brancos/cinza-claros, sem brilho, em espaço 3D (passam atrás de árvores, desfocam no DoF), caindo constante em diagonal do alto-direita para baixo-esquerda, velocidade moderada, densidade média, tela toda.
- Orbes ciano grandes com emissão forte flutuando devagar; vaga-lumes amarelo/laranja com bloom moderado na praça.
