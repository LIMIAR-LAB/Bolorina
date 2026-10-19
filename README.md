# Ilha das Cinzas — laboratório 2.5D

Projeto independente em Godot 4.7.2. O Chrono Memories original foi apenas inspecionado.

**Versão V4:** personagens compactos originais, folhas iluminadas, pôr do sol em movimento, nove quadrados de cultivo com rega, árvore cortável e uma única jardineira com companhia opcional. [Plano para o layout alvo](docs/PLANO_LAYOUT_V4.md).

## Abrir

**Vilarejo de referência visual:** execute `Ver-vilarejo.ps1` ou abra `reference_village.tscn` e pressione F6 no editor. Dentro do jogo, F6 compara luz 3D nos sprites, F7 alterna as novas flores e L inicia o anoitecer. Cena independente, sem alterar o save. Guia: `docs/GUIA_VILAREJO_REFERENCIA.txt`. É uma primeira base de comparação, ainda abaixo do acabamento da imagem alvo.

**Atualização V6:** novos protagonistas compactos originais, caminhada/corrida/cultivo em oito direções, gato animado, telhas em relevo, trepadeiras, floreiras, cultivo inicial, margens de pedra, capim e água animada. Detalhes e limites: `docs/ARTE_V6.txt`. Capturas em `docs/vilarejo-referencia-dia.png` e `docs/vilarejo-referencia-noite.png`.
**Comparação de personagem articulado (experimental):** execute `Comparar-personagens.ps1` ou abra `articulated_comparison.tscn` e pressione F6 no editor. **T** alterna entre o sprite completo atual (`original_apprentice`) e o personagem articulado (peças pixel art em BoneAttachment3D sobre Skeleton3D), no mesmo lugar, com mesma câmera, velocidade e luz; o modo ativo aparece no rótulo do canto. **1/2/3** levam aos pontos de sol, sombra e lanterna (noite). E/R/F, WASD, Shift, F6 e L funcionam como no vilarejo. Sem save. Teste: `Godot --path . --script tests/articulated_comparison.gd` (com janela). Avaliação e números: [docs/COMPARACAO_ARTICULADO.md](docs/COMPARACAO_ARTICULADO.md). **G** (teste) transforma o protagonista em "armadura de adamantium nível 99", com aura e asas articuladas presas ao osso das costas; G de novo volta. Funciona nos dois modos e nas 8 direções. Arte PixelLab: 11 gerações da assinatura, detalhadas em `art/CREDITOS.md`. Teste: `Godot --path . --script tests/transformation_v99.gd`.

Importe project.godot no Godot 4.7.2 e pressione F5. O atalho Jogar.ps1 procura a instalação local; também aceita o parâmetro -GodotPath.

## Controles

- WASD: caminhar. Shift: correr.
- Roda do mouse: zoom suave. V: panorama. H: ocultar interface.
- L: iniciar pôr do sol contínuo de 35 segundos; à noite, retornar suavemente à tarde.
- E: plantar, colher, recolher madeira ou conversar.
- R: regar o quadrado selecionado. F: golpear a árvore de recurso.
- C: pedir companhia à jardineira ou dispensá-la. Conversar não ativa o acompanhamento.
- N: avançar um dia. F5: salvar. F8: variar a costa pela seed.
- Espaço: esquiva de teste. J: ataque simplificado.
- B perto da entrada ao sul: bancada de combate em um eixo; B retorna.

Para colher: escolha um quadrado da horta e pressione E, R, N, E. Apenas mudas regadas crescem no novo dia. A árvore junto da horta recebe três golpes com F; E recolhe a madeira perto do toco. O portão lateral dá acesso à árvore.

## Estado atual

O protagonista e a jardineira usam personagens novos e originais, com cabeça maior e corpo compacto, inspirados na proporção da referência. A movimentação usa física e colisão; a câmera mantém o ângulo fixo. A companhia é opcional com C e segue a trilha percorrida pelo jogador, sem criar uma cópia da NPC.


Terreno com patamares, rampas e costa determinística; casas com fundações niveladas; materiais PBR, árvores otimizadas e vegetação com vento. Phantom Camera e Simple Grass Textured estão integrados. A água usa reflexos de tela e probe, sem ray tracing.

A construção é modular no código; ainda não há posicionamento de edifícios pelo jogador. A vila tem pontos fixos de composição. A navegação dos NPCs e o combate são experimentais; o combate principal de Chrono ainda não foi portado. As animações finais de ataque e esquiva ainda não existem nesta identidade.

Save exclusivo em IlhaDasCinzasPrototype/island_v1.json, na pasta de dados do Godot. Persiste seed, dia, cada quadrado de cultivo, rega, colheitas, árvore cortada, madeira e recrutamento. O acompanhamento começa desativado ao abrir, para exigir um novo pedido explícito. Não lê saves de Chrono.

## Documentos e demonstração

- [Plano do layout alvo e mudanças V4](docs/PLANO_LAYOUT_V4.md)
- [Histórico da identidade V3](docs/VISUAL_V3.md)
- [Demonstração de cultivo e corte V4](docs/demonstracao-v4.mp4)
- [Luz nas folhas e pôr do sol V4](docs/por-do-sol-v4.mp4)
- [Validação V4](docs/VALIDACAO_V4.md)
- [Proposta inicial, engine e roadmap](docs/PROPOSTA.md)
- [Fontes e licenças](art/CREDITOS.md)
- [Game Brief BMAD](./_bmad-output/planning-artifacts/briefs/brief-IlhaDasCinzas-2026-10-18/brief.md)

BMAD core 6.12.4 e Game Dev Studio 0.7.2 configurados no projeto. As skills locais estão em .agents/skills e o módulo em _bmad/gds.

Testes: Godot --headless --path . --script tests/smoke.gd e tests/visual_scene.gd. A rodada V4 passou em 513 verificações de sistemas, 35 de cena/movimento e 25 de interações novas (573 no total). O teste de sistemas restaura o save anterior ao finalizar.


## Cena de fidelidade visual

`fidelity_village.tscn`: por padrao a camera SEGUE a Vale (mesmo angulo iso/tamanho do enquadramento V7, zona morta de 1,25 m, roda do mouse = zoom). **Tab** alterna para a camera TRAVADA no enquadramento da referencia (`docs/referencia-usuario.png`); a legenda inferior mostra o modo. As capturas/pontuacao (`tests/fidelity_capture.gd`, perf, probe) sempre usam o modo travado (`FID_CAMERA=travada` tambem forca). O liga/desliga a sobreposicao, - / + ajusta opacidade, P pisca. Protagonista: Vale V6 via `scripts/modular/vale_fidelidade.gd` (andar usa o corpo de `run/`, porque `walk/` do V6 e outro corpo, mais magro; altura normalizada: idle 48 px / demais 45 px = 1,48 m em todas as 8 direcoes; verificado em `tests/fidelity_mechanics.gd`). Pontuacao: `python tools/fidelidade_pontuacao.py <captura.png> [prefixo]`. Relatorio: `docs/fidelidade-fase1.md`.

## Prototipo de combate

`combat_arena.tscn` (cena separada, nao usa o save): `.\Jogar-combate.ps1`. Mover WASD, atacar LMB/J (combo de 3), dash Espaco/Shift, especial RMB/K, G (LB) forma Adamantium, transformado: segurar Q/RMB (RT) = Raio de Adamantium, R reinicia, F2 piloto, F3 desempenho, F4 caixas de golpe. Detalhes, valores de sensacao, escala e desempenho: `docs/COMBATE.md`. Testes: `godot --path . --headless --script res://tests/combate_testes.gd` (54/54) e `tests/combate_adamantium_testes.gd` (36/36).

## Vila de fidelidade: crepusculo e interiores (19/10)

**Crepusculo sem "fosco".** O veu chapado vinha da nevoa volumetrica + nevoa de profundidade sob a camera ortografica (a 90 m): um veu uniforme que achatava o contraste local. Agora: nevoa volumetrica desligada, nevoa exponencial indigo bem fraca, ambiente indigo, sol ambar, bloom nitido (glow_bloom 0, limiar HDR 1.0), vinheta leve. Valores em `scripts/modular/efeitos_fidelidade.gd` (chaves `crep_*`, sobrescreviveis em `docs/fidelidade-camera.json` ou temporariamente com `FID_CONFIG_EXTRA='{"crep_exposicao":1.3}'`). `"grade_v1": true` volta ao grade antigo.
Medicao (captura travada 1600x900 vs referencia): contraste local 6,1 -> 8,2 (ref 8,45); L* medio 30,6 -> 30,0 (ref 30,6).

**Interiores (E na porta).** `scripts/modular/interiores.gd`: E perto da porta de uma casa -> fade -> sala em corte estilo Stardew; E no capacho -> fade -> volta a porta. Grade de 1 m, mobilia modular por catalogo (`MOVEIS`: cama, mesa, cadeira, estante, lareira, tapete, bau, caixote, barril, planta, lampiao, janela, quadro). Plantas por dados: `CASA_VALE` (mobiliada, casa 1) e `MODELO` (template reutilizavel, demais casas). Luz quente de lareira/lampioes, janelas com luz fria do crepusculo, sol desligado dentro. Nada e salvo.
Teste: `tests/fidelity_interiores.gd` (19/19: grade sem sobreposicao, catalogo, luzes, fade, entrar/sair, colisao, camera, template, save intocado). Capturas: `docs/fid-interior-casa.png`, `docs/fid-interior-modelo.png`.

## Jogo conectado (Fazenda + Vila + Combate)

- Atajo: `Jogar-ilha.ps1` (cena `jogo_ilha.tscn`). Comeca na fazenda.
- Controles e areas: `docs/ILHA.md`. Cercas: `docs/CERCAS.md`.
- Save novo: `user://ilha_fazenda_v1.json` (nao toca `island_v1.json`).
- Capturas: `docs/fazenda-*.png`, `docs/vila-cercas-*.png`, combate com Vale V6pal.

