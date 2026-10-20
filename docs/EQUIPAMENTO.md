# Equipamento da Vale (roupas, armaduras e capacetes)

Tela **I** (em qualquer área: fazenda, vila, masmorra e arena). Pausa o jogo enquanto aberta.
O que a Vale veste aparece no mundo (fazenda, vila, masmorra) e no combate (parada, correndo e
nos golpes). Feito em 19/10/2026. A primeira versão não usou geração paga; depois os capacetes e as armaduras
de couro e malha passaram a usar a arte gerada no PixelLab (ver "Peças do PixelLab" abaixo).

## Controles

| Tecla / mouse | Ação |
|---|---|
| **I** | abre / fecha (Esc também fecha) |
| Setas ou WASD | escolhe a peça na mochila |
| **Enter** / **F** / clique na peça | veste (ou tira, se já está vestida) |
| **X** / Backspace / clique no slot | tira a peça daquele slot |
| **Q / E** ou ◀ ▶ | gira a prévia (8 direções) |
| Espaço | prévia andando / parada |

No HUD fica o selo "**I** Equipamento" (canto inferior direito). A tecla I estava livre em todas as áreas
(Tab já é a câmera da vila/fazenda; K é horizonte/especial; G é a forma Adamantium).

## Slots e peças iniciais

Slots: **Cabeça**, **Corpo**, **Pernas**, **Acessório**. Corpo e pernas nunca ficam vazios: tirar volta
para a roupa de aprendiz / calça de lida. A defesa soma e reduz cada dano no combate (mínimo 1).

| Peça | Slot | DEF | Visual |
|---|---|---|---|
| Roupa de aprendiz (vestida) | corpo | 0 | arte base |
| Túnica do pescador | corpo | 1 | camisa azul |
| Camisa do lenhador | corpo | 1 | camisa vermelha |
| Bata das cinzas | corpo | 2 | camisa roxo-acinzentada |
| Peitoral de adamantium | corpo | 5 | camisa + colete com a paleta metálica da armadura v99 |
| Couraça do caçador | corpo | 3 | **PixelLab**: gibão de couro, ombreira, correia, cinto com bolsa, braçadeiras |
| Cota de malha do guarda | corpo | 4 | **PixelLab**: malha cinza, tabardo vermelho, grevas (east/north adaptadas, ver abaixo) |
| Calça de lida (vestida) | pernas | 0 | arte base |
| Calça anil | pernas | 1 | calça azul-anil |
| Calça cáqui | pernas | 1 | calça cor de areia |
| Grevas de adamantium | pernas | 3 | calça + botas metálicas |
| Capuz de couro | cabeça | 1 | **PixelLab**: capuz costurado, franja aparecendo |
| Elmo de ferro | cabeça | 2 | **PixelLab**: elmo redondo, aba rebitada, proteção de nariz |
| Elmo de adamantium | cabeça | 4 | **PixelLab**: prata-azulado, runa ciano, crista curta |
| Amuleto de brasa | acessório | 1 | sem visual (arte futura) |

Todas começam na mochila (save novo ou save antigo). Couraça e cota entraram depois: um save que já tem a
chave `equipamento` as recebe ao carregar (`Equipamento.NOVAS`). Loja/baús não foram ligados (não era trivial: a loja
usa as teclas 1-5 fixas). Para dar uma peça depois: `Equipamento.ganhar(estado.equipamento, "id")`.

## Auditoria da arte da Vale (antes deste trabalho)

| Pasta | Conteúdo | Cobertura |
|---|---|---|
| `original_vale_v6/` | idle (rotations) 8 dir × 1; **run** 8 × 8; tend 8 × 5; walk/walking 8 × 8 (corpo antigo, não usado: a vila anda com os quadros de run); picking_up 8 × 5 (fora do manifest) | completa (8 direções) |
| `vale_combate_gamelab/` | slash_combo, dash, hit, special × 6 dir (SE/E/NE geradas, SW/W/NW espelhadas; sem N/S) × 49 quadros, 112 px | 6 direções |
| `vale_combate_v6pal/` | as mesmas 24 folhas com a paleta da V6 (usadas no combate) | 6 direções |
| `vale_combate_armadura/` | as 24 folhas com o corpo de adamantium (golpes transformado, `x_*`) | 6 direções |
| `experimental_adamantium_v99/` | outro corpo (derivado do aprendiz V4, com capa), 8 rotações + caminhada 8 × 6, asas | forma G (`a_*`) |
| `experimental_articulated/adamantium/` | peças do boneco articulado (só a cena de comparação) | — |

Não existiam variantes de roupa nem arte de capacete: as "variantes" eram só as paletas (v6pal/armadura).
A armadura v99 não serve como roupa de vestir no corpo V6 (proporções e capa diferentes); por isso a versão
de vestir é a paleta dela aplicada ao corpo da V6 (o mesmo método das folhas `vale_combate_armadura`).

## Como funciona (paper-doll por camadas)

- **Dados**: `scripts/ilha/equipamento.gd` (catálogo `ITENS`: id, nome, slot, defesa, camadas, descrição;
  `equipar/desequipar/alternar/defesa/camadas/normalizar`).
- **Save**: chave nova `"equipamento": {"possui": [...], "equipado": {slot: id}}` no mesmo
  `user://ilha_fazenda_v1.json` (versão continua 1). Save sem a chave → equipamento inicial; ids inválidos
  são corrigidos. `user://island_v1.json` não é tocado.
- **Camadas** (`tools/vale_trajes.py` → `art/characters/vale_trajes/`): para cada peça, uma folha
  transparente só com os pixels que ela troca, alinhada quadro a quadro com a arte base:
  `camadas/<peça>/vila.png` (atlas dos 176 quadros do manifest) e `camadas/<peça>/combate/*.png`
  (24 folhas de golpes). Classes de cor da paleta V6: camisa, calça, pele, cabelo, colete/botas, contorno;
  no combate a lâmina da espada e a poeira são filtradas por forma (componentes finos ou longe do tronco).
- **Composição** (`scripts/ilha/equipamento_visual.gd`): base + camadas na ordem pernas → corpo →
  acessório → cabeça, com `Image.blend_rect`, em cache por combinação. Troca os quadros do
  `AnimatedSprite3D` da Vale (vila/fazenda/masmorra) e, no combate, idle/corrida + `c_*` (golpes).
  Sem peças = texturas originais exatamente de volta.
- **Forma Adamantium (G)**: usa `a_*` e `x_*`, que não são tocadas → a transformação cobre o visual;
  ao sair volta o vestido (testado).
- **Tela**: `scripts/ilha/equipamento_tela.gd`, montada pelo `jogo_ilha.gd` (`vestir_atual()` a cada troca de área).
- **Peça nova** (ex.: arte gerada depois): criar a camada no mesmo formato (atlas da vila + folhas de combate)
  e registrar em `indice.json` + `ITENS`. Um capacete gerado por direção pode ser carimbado em todos os quadros
  com a âncora da cabeça que `vale_trajes.py` já calcula (caixa do cabelo por quadro).

Ícones 16×16 no estilo da barra da fazenda: `tools/icones_equip.py` → `art/ui/icones_equip/` (prévia `docs/equip-icones.png`).

## Testes

`tests/equipamento_testes.gd` (79 verificações): vestir/tirar, ordem das camadas, defesa, save novo/antigo/ida e volta,
tela (I abre e pausa, Enter veste, I fecha e grava), quadros trocados na vila (todas as 176 posições), fazenda,
combate (golpes compostos, defesa reduz o dano), forma G por cima e volta ao vestido, arte base de volta sem peças,
saves reais intactos; peças do PixelLab (camada no índice, muda a Vale nas 8 direções, fica do lado certo da
cintura, máscara de apagar funciona, folha de combate composta). `EQ_CAP=1` (com janela) grava `docs/equip-{antes,tela,depois,fazenda,combate}.png`.

```
Godot --headless --path . --script res://tests/equipamento_testes.gd
```

## Peças do PixelLab (capacetes e armaduras)

Geração (autorizada pelo usuário): `tools/pixellab_equip.py`, PixelLab `/edit-image-pixen` em cima das rotações
48 px da V6, 5 vistas por peça (south, south-east, east, north-east, north). Registro com prompt, seed, job e
saldo em `work/pixellab_equip/geracoes.json`; imagens em `work/pixellab_equip/<peça>/<vista>.png`.
26 gerações usadas de um teto de 30. `capuz_couro/north_rejeitada13.png` foi descartada.

Integração (local, grátis): `tools/vale_pecas_pixellab.py` (importa as classes de cor de `vale_trajes.py`).
1. **Recorte**: cada imagem é alinhada com a rotação original da mesma vista (deslocamento de até 3 px medido
   na parte que a peça não toca; só o elmo de adamantium precisou, 1 px) e só a diferença vira camada:
   capacete = diferença acima do pescoço ligada à cabeça; armadura = diferença do pescoço para baixo.
   Onde a peça **tira** pixels da Vale (cabelo que sobrava fora do elmo) sai uma máscara de apagar.
2. **Espelho**: west / south-west / north-west = east / south-east / north-east espelhadas.
3. **Carimbo em todos os quadros** (176 da vila/fazenda e 1176 do combate): a cabeça (capacete) ou o tronco
   (armadura) da rotação é casado por cor com cada quadro (escala 0,84 a 1,08 e deslocamento), e a peça vai junto.
   Nos golpes com efeito (arco branco, fogo do especial) a âncora usa o maior bloco de cabelo e, quando casa
   melhor, o encaixe do quadro anterior da mesma folha. Armadura: o tronco é carimbado e cortado ao corpo
   do quadro; pernas e braços balançando recebem a tabela de cores aprendida nas vistas (cor original para cor
   da peça). As rotações das 5 vistas entram exatamente como o PixelLab desenhou.
4. **Saída**: `camadas/<peça>/vila.png`, `vila_apagar.png`, `combate/`, `combate_apagar/` e a entrada no
   `indice.json` (`"fonte": "pixellab"`). `equipamento_visual.gd` aplica a máscara de apagar
   (`Image.blit_rect_mask` com imagem transparente) antes de desenhar a peça. Prévia:
   `docs/equip-pixellab-vistas.png` (8 direções paradas + um quadro de corrida por peça).

Correções feitas por código (a arte gerada veio errada nestas vistas):
- **capuz_couro north-east** (e north-west, espelhada): o PixelLab desenhou o rosto de frente dentro do capuz.
  Pele e olhos viraram couro, com o sombreado da nuca original.
- **elmo_ferro north** e **north-east**: rosto e proteção de nariz numa vista de costas. Foram tirados da
  camada; ali aparece a nuca original por baixo da aba.
- **malha_guarda east e north**: não foram geradas (east falhou; north ficou sem resposta, ver abaixo).
  Foram **adaptadas**: tabela de cores da vista vizinha (east vem de south-east + north-east; north de north-east)
  aplicada na rotação original. Ficam sem os detalhes de forma (tabardo, ombros), só as cores da malha.
  As três vistas geradas da malha também não combinam entre si (de frente o vermelho é um lenço no pescoço,
  de lado a calça fica vermelha, de costas é um tabardo).
- O job de `malha_guarda north` foi enviado e contado, mas o processo parou antes da resposta. Com a chave
  na variável de ambiente, `python tools/pixellab_equip.py . --recuperar` busca esse resultado sem gastar.

Para refazer as camadas depois de trocar uma imagem: `python tools/vale_pecas_pixellab.py .` (cerca de 1 min).
`tools/vale_trajes.py` não gera mais os capacetes provisórios e preserva no índice as camadas do PixelLab.

## Proposta de arte paga (histórico: os 3 capacetes e as 2 armaduras já foram gerados)

Recomendação: **PixelLab** (a Vale V6 foi feita lá; `edit-image-pixen` edita em cima do sprite real e mantém o
tamanho de 48 px). Gamelab só vale para golpes animados, e é caro.

| Pacote | O que gerar | Ferramenta | Custo estimado |
|---|---|---|---|
| 3 capacetes (gorro de couro, elmo de ferro, elmo de adamantium) | cada um sobre as rotações V6 em 5 vistas (S, SE, E, NE, N; SW/W/NW espelhadas) | PixelLab `/edit-image-pixen` 48×48 | 3 × 5 = **15 gerações** |
| 2 armaduras (ex.: couraça de couro do caçador, cota de ferro do guarda) | 5 vistas cada sobre as rotações V6; corrida/agir/golpes recebem a peça por transferência de paleta/região por código (como o adamantium) | PixelLab `/edit-image-pixen` | 2 × 5 = **10 gerações** |
| (opcional) animação própria de uma armadura | personagem novo + corrida 8 direções + agir 8 direções | PixelLab `/create-character-v3` + `/characters/animations` | ≈ 1 + 8 + 8 = **17 gerações** por armadura (vira troca de folha inteira, não camada) |
| (não recomendado) golpes animados de uma armadura | 3 imagens base + 4 golpes × 3 direções (vídeo) | Gamelab | 3 × 1 + 12 × 4 = **51 créditos** (conta ≈ 56; da autorização de 60 sobram só 5) |

Total recomendado: **≈ 25 gerações PixelLab** (registro de 19/10: ≈ 696 restantes na assinatura; US$ 0).
Processamento depois da geração (local, grátis): diferença contra a rotação base → carimbo por vista →
camada em todos os 176 quadros da vila e 1176 do combate com a âncora da cabeça/tronco já calculada.

## Limites conhecidos

- Camisas e calças coloridas são recolorações da roupa base: mesma silhueta.
- Peças do PixelLab: a arte é de uma pose parada por vista. Na corrida, no agir e nos golpes ela é carimbada
  e acompanha a cabeça/tronco, mas não se deforma com a animação (ex.: a ombreira não gira com o braço).
  O combate (desenho do Gamelab, um pouco menor) usa a peça reescalada; pode sobrar 1 ou 2 px de cabelo nas
  bordas do elmo em alguns quadros. No giro do especial a Vale vira de frente por alguns quadros, mas a
  folha é de uma direção só, então o capacete continua o daquela direção.
- Cota de malha: vistas east/north adaptadas por cor e vistas geradas com o vermelho em lugares diferentes.
- O peitoral/grevas de adamantium são paleta metálica no corpo V6 (prata-azulado claro, sem placas desenhadas).
- Combate: o filtro da espada é heurístico; pode sobrar 1-2 px recoloridos na lâmina em poucos quadros.
  Agir (tend) agachado: a divisão colete/botas por altura pode errar 1-2 px.
- Acessório não tem visual. Loja/baús não dão peças (todas começam na mochila).
- Abrir o editor importa ~250 PNGs novos de `vale_trajes/` (inofensivo). Num export, as folhas-base do combate
  (`vale_combate_*`, com `.gdignore`) já não vão no pacote — isso é anterior a este trabalho.

## Vale única (20/10/2026)

A Vale da vila, da fazenda, da masmorra e a parada/corrida da arena passaram a usar o **mesmo desenho dos golpes**
(Gamelab), sem espada fora do combate: `art/characters/vale_unica/` (mesmo formato de `original_vale_v6`,
que continua intacta). Gerado no Gamelab (projeto 32737) com autorização do usuário: 5 poses base sem espada
(5 créditos) + correndo em 5 vistas e agir em 4 vistas (9 vídeos, 36 créditos) = **41 créditos**. Registro em
`work/vale_unica/jobs.json`; bases e vídeos em `work/vale_unica/`. Recorte local: `tools/vale_unica_quadros.py`
(chroma magenta, redução por área, paleta da V6, pés embaixo, altura 45 px parada e na corrida, oeste espelhado,
agir de costas = agir do nordeste).

Código: `scripts/modular/vale_fidelidade.gd` (`PASTA = "vale_unica"`, altura de referência 45 px em tudo) e
`scripts/combate/jogador_combate.gd` (`PASTA_BASE`, `PX_IDLE` = 45 px). Para voltar à V6, trocar essas duas
constantes e o `BASE_VILA` de `tools/vale_trajes.py`, e rodar `vale_trajes.py` + `vale_pecas_pixellab.py`.

Equipamento: as 12 camadas foram refeitas em cima da Vale única. `vale_trajes.py` lê a base nova, mas mede as
cores também na V6 (as folhas do combate continuam na paleta da V6); a camisa só é trocada da altura do pescoço
para baixo (os olhos da Vale única são verde-azulados). As peças do PixelLab continuam recortadas contra a V6 e
são carimbadas em todos os quadros (as rotações não entram mais "exatas").

Testes ajustados para a base nova (não para esconder falha): `combate_testes` mede a escala na pasta ativa
(`PASTA_BASE`), `combate_vale_consistencia` espera idle de 45 px, `fidelity_mechanics` espera `vale_unica`, e
`equipamento_testes` ignora diferenças em pixels transparentes (o import do Godot preenche o RGB invisível).
Resultado: equipamento 79/79, combate 53/54 (a falha antiga do `.import`), consistência 4/4, fidelity 23/23,
fazenda_extras 27/27.

## Conjuntos da forja e slots novos (noite de 20/10/2026)
Slots: cabeça, corpo, pernas, acessório, **mãos, pés, escudo, arma** (tela com 8 caixas em 2 colunas). Conjuntos de
cobre, ferro e prata de túmulo (capacete, peitoral, luvas, botas, escudo, espada) feitos na forja de Porto Velho
(`scripts/economia/forja.gd`, `data/forja/`). Camadas só por cor: `tools/vale_conjuntos.py`. Escudo e espada não
aparecem fora do combate. Encantos do Arquimago somam +1 de defesa na peça (`equipamento.encantos`). Ver
`docs/NOITE_RELATORIO.md`.
