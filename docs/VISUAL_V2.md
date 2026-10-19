# Cena visual 2.5D — 18/10/2026

A referencia modular foi traduzida para uma primeira cena navegavel em Godot. O resultado ainda e um estudo de composicao, escala e movimento, com modelos de edificios simples; nao equivale ao acabamento da imagem de conceito.

## Implementado

- Terreno 3D com patamares elevados ao norte, costa baixa ao sul e conexoes por rampas. Lotes das casas nivelados para receber fundacoes.
- Casas feitas por uma mesma funcao modular: paredes texturizadas, telhado de duas aguas, empenas, vigas, alpendres, janelas iluminadas e chamine. Uma casa aparece em construcao.
- Canteiros, cercas, poco, barris, ponte de madeira, arco em ruinas e ilhas com torres no horizonte, todos em geometria 3D.
- Pedra, madeira, telhas e terreno com texturas PBR; arvores e samambaias de modelos CC0. Materiais com mipmaps para reduzir cintilacao distante.
- Grama instanciada com vento pelo Simple Grass Textured; areas de exclusao para lotes e caminhos.
- Arvores simplificadas localmente: de 1.072.212 para 107.221 faces por modelo, preservando o original CC0 e usando uma copia otimizada na cena.
- Iluminacao quente, ceu HDRI, nevoa distante, sombras, oclusao ambiente e brilho leve. Renderer Forward+ testado na RTX 4050 local.
- Sprites reais animados: Aren (112 quadros), Sir Brann (16) e Elowen (36), copiados dos pacotes locais do usuario. Fontes originais permanecem intocadas. Aren possui idle, caminhada, corrida, esquiva e ataque. Sao animacoes laterais com espelhamento, ainda sem oito direcoes de exploracao.
- Phantom Camera com seguimento amortecido, rotacao gradual e zoom suave. HUD compacta e modo panorama.

## Controles

WASD movimenta em relacao a camera; Shift corre; Espaco esquiva; J ataca; E interage. Q/R giram a camera, roda do mouse ajusta zoom, V alterna panorama, H oculta a interface. N avanca o dia. B perto da ruina antiga de teste ainda acessa a bancada de combate lateral; nao e o foco desta cena.

O modo de exploracao deixou de aplicar ataques automaticos do inimigo para permitir avaliar o design com calma. O combate simplificado permanece na arena. Save de cultivo/dia/recrutamento preserva o formato anterior.

## Facilitadores pesquisados

| Recurso | Estado | Uso / decisao |
|---|---|---|
| Phantom Camera v0.11.0.3 | Instalado e usado | Seguimento/amortecimento 3D; MIT; tag oficial cb6e0966ac305202c47f1d1a81c105966e29da96 |
| Simple Grass Textured v2.1.0 | Instalado e usado | MultiMesh e vento; MIT; textura de grama CC0; tag e14bdcf17c5c965094f8f464fb26421eb888f8fc |
| Terrain3D | Pesquisado | Ferramenta candidata para esculpir e pintar o terreno na proxima iteracao; nao instalado nesta cena |
| ProtonScatter | Pesquisado | Candidato a distribuir props pelo editor; nao instalado, sem dependencia de suas texturas de demonstracao |

Fontes: [Phantom Camera](https://github.com/ramokz/phantom-camera/releases/tag/v0.11.0.3), [instalacao](https://phantom-camera.dev/overview/installation), [Simple Grass Textured](https://github.com/IcterusGames/SimpleGrassTextured/tree/v2.1.0), [Terrain3D](https://terrain3d.readthedocs.io/en/stable/), [ProtonScatter](https://github.com/HungryProton/scatter).

## Limites para a proxima decisao de design

A construcao e modular no codigo, mas ainda nao ha interface para o jogador posicionar edificios. Os marcos do horizonte sao modelos simples. O terreno usa uma malha com colisao e mascara procedural, nao um editor Terrain3D. A vegetacao tem exclusoes geometricas para a composicao atual; remocao dinamica por construcao ainda precisa ser implementada. O acompanhante ainda nao possui navegacao que contorne obstaculos.

Os personagens de Chrono foram usados para validar a mistura visual e animacao; isso nao aprova a ligacao narrativa entre os universos. A identidade final de personagens, as oito direcoes e o refinamento dos modelos de edificios continuam em aberto.

Verificacao: suite de sistemas basicos, teste de subida real pela rampa, selecao de animacoes, integracao dos addons e captura GPU. Registros atuais ficam em work/; screenshots em docs/prototipo.png e docs/panorama.png. Amostra curta de FPS, quando registrada, nao substitui um teste prolongado de desempenho.
