# Comparação: sprite completo × personagem articulado (experimental)

Data: 19/10/2026. Godot 4.7.2 Forward+, notebook com RTX 4050 Laptop. Cena isolada: `articulated_comparison.tscn` (herda o vilarejo de referência V6, sem save). `main.tscn`, `reference_village.tscn`, sprites PixelLab e save não foram alterados.

## 1. Objetivo e método

Testar a técnica descrita pelos desenvolvedores de Alabaster Dawn ("base frame built using special billboards placed along a 3D skeleton… same system we used to animate the arms and legs of our characters") contra o sprite completo atual do protagonista V4 (`original_apprentice`), com tudo o mais igual.

- **Esqueleto:** `Skeleton3D` criado por código com 17 ossos (raiz, quadril, tronco, cabeça, braço/antebraço/mão dos dois lados, ferramenta, coxa/canela/pé dos dois lados). Um `BoneAttachment3D` por osso.
- **Peças:** 18 `Sprite3D` de pixel art: tronco e cabeça (5 vistas desenhadas, espelhadas para o lado oeste), braço, antebraço, manga, mão, coxa, canela e bota (3 vistas) por lado, mais machado e regador na mão direita. Membros têm versão "encurtada" usada quando a projeção do osso fica abaixo de 72% do comprimento.
- **Projeção:** cada peça fica no mesmo plano voltado à câmera que o sprite completo, gira apenas no plano da tela pelo ângulo projetado do osso, e é ordenada por camada + profundidade do grupo do membro. Posições encaixadas na grade de texels. Escala do corpo compensa a inclinação da câmera (Y × 1,2247), para manter a altura desenhada de 44 px = 1,28 m (0,02909 m/px, igual ao sprite).
- **Animações:** procedurais no `AnimationPlayer`: idle 1,6 s, walk 0,5 s, run 0,4 s, tend 0,8 s, water 1,0 s, chop 0,62 s (impacto em ~0,32 s). A altura do quadril é recalculada por chave para o pé mais baixo tocar o chão.
- **Paridade:** o articulado espelha o `ActorVisual` original oculto (direção, animação, modulate, sombreamento). A física, a câmera, a velocidade, a luz de preenchimento (`PreenchimentoDoSprite`, transferida para o corpo físico), o material, as camadas e a sombra de contato são os mesmos nos dois modos. Rega e machado chamam `farm.interact()` e `cut_tree.hit()` reais.
- **Arte:** desenhada por código (`art/characters/experimental_articulated/source/gerar_pecas.py`, Python + Pillow), paleta amostrada do aprendiz V4, articulações, mãos, rosto e vistas alternativas desenhados à mão no gerador; nenhum recorte do sprite existente. Folha das peças: `docs/articulado-pecas.png`. Sem serviços pagos.

## 2. Como abrir e alternar

- `Comparar-personagens.ps1` ou abrir `articulated_comparison.tscn` e pressionar F6 no editor.
- **T** alterna o modo; o rótulo no canto superior direito mostra "MODO ATIVO: SPRITE COMPLETO (ATUAL)" ou "MODO ATIVO: ARTICULADO (EXPERIMENTAL)".
- **1 / 2 / 3**: pontos de sol, sombra e lanterna (o 3 ajusta a hora para 20h12).
- WASD, Shift, E (plantar/colher), R (regar), F (machado), F6 (luz 3D nos sprites), L (anoitecer) como no vilarejo.
- Teste: `Godot --path . --script res://tests/articulated_comparison.gd` (com janela; sem janela roda as verificações não visuais). Vídeo: `tests/articulated_movie.gd` com `--write-movie`.

## 3. Resultados comprovados (teste com janela, 113/113 verificações)

Log: `work/articulado-teste.log`; dados: `docs/articulado-resultados.json`. Único aviso no encerramento: "7 RIDs of type Texture were leaked", pré-existente.

| Item | Resultado medido |
|---|---|
| Estrutura | 17 ossos, 17 BoneAttachment3D, 18 peças; 6 animações esqueléticas |
| Densidade de pixel | 0,02909 m/px nos dois |
| Alternância T | posição, câmera e enquadramento idênticos; rótulo correto |
| Velocidade | caminhada 2,700 × 2,700 m (60 quadros); corrida 3,004 × 3,004 m (40 quadros) |
| 8 direções × andar/correr | direção e animação equivalentes; pé no chão entre −0,007 e +0,010 m; vista desenhada da cabeça e sobreposição de cabeça/braços/botas corretas em todas |
| Peças presas aos ossos | erro máximo 0,92 px na tela |
| Rega | `farm.interact()` real planta e rega; regador preso à mão (erro máx. 1,25 px) e guardado ao fim |
| Machado | `cut_tree.hit()` real; machado acompanha a mão (1,11 px); lâmina a 0,57 m do eixo do tronco no impacto; 3 golpes derrubam a árvore |
| Regressão | sprite completo continua regando pelo mesmo caminho |
| Save | cena não grava; save inalterado (não existia save) |

### Luz (fator = luminância com luz 3D ÷ luminância sem luz, mesma pose)

| Ponto | Chão (sem personagem) | Sprite | Articulado | Articulado/Sprite |
|---|---|---|---|---|
| Sol 16h | 0,468 | 0,708 | 0,679 | 0,959 |
| Sombra | 0,168 | 0,866 | 0,861 | 0,994 |
| Lanterna 20h12 | 0,318–0,322 | 1,338 | 1,360 | 1,016 |

Os dois modos reagem à luz da mesma forma (diferença ≤ 4,1%). A luminância bruta do articulado é maior porque a arte dele tem mais área clara (rosto maior, menos contorno), não por luz diferente. Montagem: `docs/articulado-luz-comparacao.png`.

### Desempenho (vsync desligado, 600 quadros por modo; multidão = +40 figurantes)

Duas rodadas com janela no mesmo notebook, mesma cena. A rodada A é a anterior (log sobrescrito; números anotados na hora); a rodada B é a do log atual `work/articulado-teste.log` e de `docs/articulado-resultados.json`:

| Métrica | Sprite (rodada A) | Articulado (A) | Sprite (rodada B) | Articulado (B) |
|---|---|---|---|---|
| Quadro médio / p95, 1 personagem | 7,67 / 8,31 ms | 7,62 / 8,05 ms | 13,00 / 17,20 ms | 11,95 / 13,42 ms |
| Draw calls, 1 personagem | 1245,5 | 1259,0 | 1228,1 | 1242,1 |
| Multidão 40: quadro médio / p95 | 7,62 / 8,01 ms | 7,66 / 8,22 ms | 12,35 / 14,56 ms | 15,71 / 22,01 ms |
| Multidão 40: draw calls | 1433,7 | 1916,0 | 1407,8 | 1905,2 |
| Atualização das peças (CPU) | — | 88,5 µs/quadro | — | 170,2 µs/quadro |

Nós: 2 (sprite) × 40 (articulado); instâncias visuais: 2 × 19. A rodada B foi feita logo após o notebook voltar de uma desconexão e é mais ruidosa em geral (o próprio sprite piorou de 7,7 para 13,0 ms), mas em ambas o custo por personagem articulado é real: cerca de **+12 draw calls por personagem** e ~0,1–0,2 ms de CPU por personagem. Com 1 personagem é irrelevante; com 40 figurantes a rodada B mostrou +27% no quadro médio e +51% no p95. Para NPCs em massa o sprite completo é mais barato.

## 4. Capturas e vídeo

- Dia: `docs/articulado-dia-sprite.png`, `docs/articulado-dia-articulado.png`
- Noite/lanterna: `docs/articulado-noite-sprite.png`, `docs/articulado-noite-articulado.png`
- Ações: `docs/articulado-rega.png`, `docs/articulado-machado.png`
- 8 direções (parado e andando, os dois modos): `docs/articulado-8-direcoes.png`
- Luz sol/sombra/lanterna: `docs/articulado-luz-comparacao.png`
- Peças: `docs/articulado-pecas.png`
- Vídeo: `docs/comparacao-articulado.mp4` (33 s, 1280×720, H.264, 8,7 MB; 995 quadros a 30 fps gravados pelo movie writer do Godot com física real; legendas indicam teleportes e mudança de hora). Limite: a câmera do vídeo está no zoom padrão do vilarejo, então o personagem aparece pequeno; os detalhes estão nas capturas aproximadas.

## 5. Avaliação visual (julgamento, não medição)

- O sprite completo PixelLab tem mais detalhe desenhado por quadro (cabelo com mechas, olhos, bolsa, cinto, dobras). As peças articuladas, desenhadas por código, ficaram mais simples: cabeça redonda e lisa, rosto mínimo. **A diferença de qualidade vem principalmente da arte das peças, não da técnica**; não foi possível neste trabalho produzir peças com o mesmo acabamento.
- Pontos fortes do articulado: movimento contínuo (sem limite de quadros), ferramentas presas de verdade à mão, virar para o alvo, uma única arte reaproveitável para novas ações (rega e machado foram feitas só com chaves de animação), mesma resposta à luz.
- Pontos fracos: pixels girados criam leve cintilação nos membros em diagonal; o pé desliza um pouco em relação ao chão (sem IK); as vistas laterais e de costas dependem de poucas vistas desenhadas; silhueta mais "boneco".

## 6. Limitações conhecidas

- O sprite completo não trava o movimento durante o machado; o articulado trava (estende `action_timer`) e vira para a árvore. O efeito da ação (`hit`/`interact`) acontece ao apertar a tecla nos dois modos; no articulado a batida visual ocorre ~0,32 s depois.
- O `ActorVisual` original continua processando (oculto) no modo articulado, para manter a mesma lógica; isso soma um pouco ao custo medido.
- A escolha automática dos pontos de sol/sombra usa raios de física, que não enxergam sombras de copas; por isso a sombra é validada pelo brilho do chão na captura (0,168 × 0,468).
- O morador da praça (que também usa `original_apprentice`) fica oculto nesta cena para não duplicar o personagem.
- Só o protagonista foi feito; NPCs não foram migrados. Corte por profundidade entre peças e cenário próximo (cercas, telhado) segue o plano único do sprite, como o sprite completo.
- Meshy AI não foi usado (serviço pago por créditos). Ele ajudaria apenas em props 3D, não em peças de pixel art. Blender não foi necessário.

## 7. Recomendação

**Híbrido.** Manter os sprites completos PixelLab como padrão para personagens e NPCs (melhor arte, mais barato em massa) e usar o esqueleto articulado só onde ele dá algo que o sprite não consegue barato: ferramentas e itens presos à mão, ações novas sem gerar folhas de 8 direções, e talvez cenas de perto do protagonista. Uma variante promissora (proposta, não implementada) é um sprite completo para corpo/cabeça com braços e ferramenta articulados por cima, aproveitando o detalhe do PixelLab.

Comprovado aqui: paridade de física, câmera, velocidade e luz; pés no chão e ferramentas na mão nas 8 direções; integração com rega e machado reais; custo por personagem. **Proposta, não comprovada:** que peças desenhadas por um artista alcancem a qualidade do sprite completo; o modo híbrido sprite + braços; IK de pé. Não há evidência para afirmar fidelidade percentual à referência.

## 8. Teste de transformação "Armadura de adamantium nível 99" (tecla G)

Teste pedido pelo usuário, feito na mesma cena de comparação (`articulated_comparison.tscn`). **G** transforma e **G** de novo volta; a tecla não estava em uso. O rótulo do canto ganha a linha "FORMA TESTE: ADAMANTIUM NV 99 + AURA + ASAS | G". Nada é salvo.

**Montagem híbrida:**
- **Corpo:** no modo sprite, troca o `SpriteFrames` do aprendiz V4 pela armadura gerada na PixelLab, com parado, caminhada e corrida nas 8 direções. O pé de cada quadro fica no chão pelo mesmo pivô do V4. No modo articulado, as 18 peças trocam para variantes recoloridas por código (`experimental_articulated/adamantium/`).
- **Asas:** duas peças de pixel art (a geração simétrica dividida ao meio). Ficam em um `Skeleton3D` próprio (`costas` → `asa_esquerda`/`asa_direita`, um `BoneAttachment3D` por asa). O osso das costas segue o alto das costas: no sprite, a 25 px acima do pé no plano do sprite; no articulado, a linha dos ombros do esqueleto mais 8,5 px, acompanhando o balanço do tronco. As asas batem devagar (1,5 s parado, 0,95 s andando, 0,62 s correndo). Ficam atrás do corpo nas vistas de frente e de lado e na frente nas vistas de costas (N, NE, NO); nas vistas laterais ficam estreitadas (55%).
- **Aura:** 56 partículas CPU aditivas e sem iluminação subindo de um anel, mais um anel pixelado no chão (`shaders/aura_ring.gdshader`). **Não há nenhuma luz**: a aura não ilumina o cenário nem os sprites. Ela só soma brilho onde é desenhada. Medido no recorte de 150×150 px em volta do personagem: dia 0,292 com aura × 0,289 sem aura; noite 0,296 × 0,279. Nas medições de luz das seções 3 e 6 a transformação fica desligada, então elas não mudam.

**Arte:** PixelLab pela API oficial, com a assinatura do usuário. Foram **11 gerações** (saldo de 706,8 para 695,8 de 4800, créditos em dólar em US$ 0,00): edição da armadura sobre o aprendiz (1), 8 rotações v3 (1), caminhada por template em 8 direções (8) e asas (1). Detalhes em `art/CREDITOS.md` e `art/characters/experimental_adamantium_v99/source/pixellab/geracoes.json`.

**Resultados medidos** (`tests/transformation_v99.gd`, com janela; log em `work/v99-teste.log`; dados em `docs/adamantium-resultados.json`): **127/127**.

| Item | Resultado |
|---|---|
| Alternância G | ida e volta nos dois modos; posição e câmera inalteradas; o sprite volta ao `original_apprentice` V4 |
| Armadura | 24 animações (parado, caminhada e corrida × 8); linha do pé confere com cada quadro (diferença máx. ≤ 1 px); pixel 0,0291 → próximo do original |
| 8 direções × andar/correr | direção e animação da armadura corretas; pé no chão (sprite: pivô por quadro; articulado: −0,007 a +0,009 m) |
| Asas | presas ao osso (erro 0,00 px); osso das costas segue o corpo (0,00 px); ordem correta frente/costas; batem em todas as direções; ponto mais baixo +0,026 m (sprite) e −0,007 m (articulado) |
| Mecânicas | rega real (`farm.interact()`) transformado nos dois modos; machado real (`cut_tree.hit()`) |
| Regressão | comparação 113/113 e vilarejo V6 47/47 de novo, com a transformação no projeto |
| Desempenho (400 quadros × 2, vsync off) | normal 10,82 ms (p95 11,83), 1265,7 draw calls; transformado 10,79 ms (p95 11,88), 1272,2 draw calls (+6,6); diferença de tempo dentro do ruído |

Capturas: `docs/adamantium-dia-normal.png`, `docs/adamantium-dia-transformado.png`, `docs/adamantium-noite-normal.png`, `docs/adamantium-noite-transformado.png`, `docs/adamantium-dia-articulado-transformado.png`. Montagens: `docs/adamantium-comparacao.png` e `docs/adamantium-8-direcoes.png`. Clipe: `docs/transformacao-adamantium.mp4` (17,6 s, 1280×720, 4,0 MB).

**Limitações:**
- **Animações:** a PixelLab gerou só parado e caminhada. A corrida é a caminhada mais rápida, e a forma armada não tem animação própria de cultivo, rega ou machado no modo sprite (o personagem fica no quadro parado enquanto a ferramenta age).
- **Asas:**
  - São uma única imagem frontal/de costas (simétrica). Nas vistas laterais são apenas estreitadas, sem desenho de perfil.
  - Usam densidade de pixel menor que a do corpo (escala 0,58), então os pixels das asas são menores.
  - A ordem é por vista (atrás ou na frente do corpo inteiro), não por pena.
- **Peças articuladas:** no modo articulado são só recoloração por código, bem inferiores à armadura PixelLab.
- **Aura:** as partículas são CPU e um pouco aleatórias entre execuções. O brilho dela não entra nos testes de luz.
- **Escopo:** é um teste, sem efeito de jogo (sem nível, atributos ou save) e sem animação de transição (troca instantânea com uma rajada de partículas).