# Mapas de NPC: Porto Velho, Vila dos Orcs e Cidade Fantasma

Três mapas grandes e **independentes** para *Ilha das Cinzas*. Foram feitos com assets **CC0** gratuitos (Quaternius, Kenney e Poly Haven) junto com o kit modular que já existe no projeto (`scripts/modular/`). **Nada foi ligado ao `main.tscn`**. Tudo fica em pastas novas; o único arquivo existente tocado é o `project.godot` (+2 linhas para o plugin de diálogos, veja `README_DIALOGOS.md`).

| Mapa | Cena | Tamanho | Clima |
|---|---|---|---|
| Porto Velho (vila grande) | `scenes/vila_grande/vila_grande.tscn` | ~120×120 m (ilha R≈58 m) | Hora dourada (16h36) |
| Vila dos Orcs | `scenes/vila_orcs/vila_orcs.tscn` | ~90×90 m (ilha R≈44 m) | Pôr do sol ocre/vermelho, brasas |
| Cidade Fantasma | `scenes/cidade_fantasma/cidade_fantasma.tscn` | ~100×100 m (ilha R≈48 m) | Noite, lua, névoa violeta, cinzas |

Feito e testado no **Godot 4.7.2** (Forward+). As três cenas carregam sem erros.

## Como abrir

1. Abra o projeto no Godot 4.7.2. Na primeira vez, ele importa os modelos novos de `art/models/`.
2. Abra uma das cenas acima e aperte **F6** ("Executar cena atual").

Controles do jogador provisório (uma cápsula chamada `SubstituirPeloSpriteDaVale`, para trocar pelo personagem/sprite real do jogo):

- **WASD / setas**: andar (o movimento é relativo à câmera isométrica)
- **Roda do mouse**: zoom
- **Tab**: alterna entre a visão geral da ilha e a câmera do jogador
- **F12**: salva uma captura em `user://`

A câmera é a mesma do jogo: ortográfica, yaw 45°, offset (24, 24, 24), size 21,5.

## Estrutura

```
scenes/vila_grande/vila_grande.tscn        Porto Velho
scenes/vila_orcs/vila_orcs.tscn            Vila dos Orcs
scenes/cidade_fantasma/cidade_fantasma.tscn
scripts/vila_grande/
  mapa_cc0.gd                 raiz comum das 3 cenas (@export_file layout)
  mundo_cc0.gd                terreno/rio/detalhes (estende scripts/modular/vila_modular.gd)
  construtor_quaternius.gd    monta casas com o Medieval Village MegaKit (andares, enxaimel, ruína)
  estruturas.gd               torre do arquimago, doca, dirigível, paliçada, totens, fogueiras,
                              cabanas e salão orc, capela em ruínas, lápides, lanternas espectrais
  vila_grande_layout.json     layout do Porto Velho
  vila_orcs_layout.json       layout da Vila dos Orcs
  cidade_fantasma_layout.json layout da Cidade Fantasma
tools/vila_grande_layouts.py       gerador determinístico dos 3 JSON
tools/vila_grande_curar_assets.py  curadoria dos packs baixados (texturas 1024, roughness 0.9, recolor)
art/models/quaternius_vila_medieval/  art/models/quaternius_natureza/  art/models/quaternius_props/
art/models/kenney_fantasy_town/  art/models/shrub_02/  art/models/rock_moss_set_01/
art/models/boulder_01/  art/models/tree_stump_01/
art/CREDITOS_VILA_GRANDE.md        créditos e licenças (todos CC0)
```

## Editar e regerar

Os layouts são JSON, então dá para editar à mão: casas (`edificios`), modelos soltos (`modelos`), peças do kit (`pecas`), estruturas especiais (`especiais`), marcadores (`marcadores`), clima (`tema`) e câmeras de captura (`capturas`). Para regerar tudo a partir do script:

```
python3 tools/vila_grande_layouts.py
```

A curadoria dos packs originais só é necessária se você quiser trocar ou adicionar modelos. Baixe os zips listados em `art/CREDITOS_VILA_GRANDE.md` e ajuste os caminhos no topo do script:

```
python3 tools/vila_grande_curar_assets.py
```

Para gerar as prévias sem abrir o editor:

```
VG_CAPTURA=/caminho/saida godot --path . --rendering-driver vulkan scenes/vila_orcs/vila_orcs.tscn
```

Isso salva uma imagem por câmera listada em `capturas` e fecha o Godot.

## Marcadores de NPC e spawn

Cada mapa tem nós `Marker3D` dentro de `Marcadores`, com o **nome igual ao id do NPC**:

- Os NPCs ficam no grupo `npc_marcador`.
- Os pontos de spawn ficam no grupo `spawn`.
- Cada nó tem os metadados `papel` e `descricao`.

Os ids dos marcadores são **os mesmos ids dos diálogos** (`dialogos/<id>.dialogue`), então cada marcador vira um morador que conversa (veja a seção abaixo). Na integração, cinco marcadores foram renomeados: `ferreiro_porto`→`ferreiro`, `arquimago_velho`→`arquimago`, `capitao_dirigivel`→`capitao`, `condessa_vampira`→`condessa`, `lobisomem_eremita`→`lobisomem`, e foi criado o `dragao`.

No código: `$VilaGrande.marcador("mira")` devolve o nó. Também dá para usar `get_tree().get_nodes_in_group("npc_marcador")`.

**Porto Velho (Vila Grande)** (`scenes/vila_grande/vila_grande.tscn`)

| id | x, z | papel | onde |
|---|---|---|---|
| `spawn_jogador` | 0, 14 | spawn | Chegada pela estrada sul, de frente para a praca |
| `spawn_doca` | 50, 0 | spawn | Desembarque na doca de dirigiveis |
| `mira` | -13.5, -12 | herbalista | Botica da Mira, balcao da frente |
| `jardineira` | -32.5, 31 | horticultora | Hortas junto ao Celeiro das Sementes |
| `guardia` | 33, -3.5 | guarda | Mural de pedidos do Posto da Guarda |
| `sineiro` | -15, 20.5 | sineiro | Porta da Casa do Sineiro |
| `ferreiro` | -35, -2.5 | ferreiro | Bigorna da Ferraria do Porto |
| `estalajadeira` | 13, -12.5 | estalajadeira | Mesa em frente a Estalagem da Lanterna |
| `arquimago` | 36, -33 | arquimago | Porta da Torre do Arquimago |
| `capitao` | 62, 1.5 | comerciante | Ponta da doca, ao lado do dirigivel |
| `mercador_praca` | 6.5, 5.5 | comerciante | Barracas da praca central |
| `morador_1` | 9, 22 | morador | Frente das casas do bairro sul |
| `morador_2` | -4.5, -33 | morador | Rua norte, perto da ponte |
| `crianca_praca` | -3, 3 | morador | Brincando perto do chafariz |
| `gato` | 2.5, -4 | animal | Gato da praca |
| `dragao` | 54.5, -2.6 | guardiao_rota | Entrada da doca de dirigiveis, lado da Rota do Ambar (cobra pedagio de quem embarca) |

**Vila dos Orcs** (`scenes/vila_orcs/vila_orcs.tscn`)

| id | x, z | papel | onde |
|---|---|---|---|
| `spawn_jogador` | 0, 38 | spawn | Portao sul da palicada (chegada pela trilha) |
| `spawn_portao_leste` | 38, 1 | spawn | Portao leste |
| `lider_orc` | 0, -10.5 | lider | Diante do Salao de Guerra |
| `xama_orc` | -4, 6 | xama | Caldeirao ao lado da fogueira do conselho |
| `ferreiro_orc` | -8, -6.5 | ferreiro | Bigorna e forja improvisada |
| `guerreiro_orc_1` | 11.5, -1 | guerreiro | Campo de treino |
| `guerreiro_orc_2` | 3, 30 | sentinela | Torre de vigia do portao sul |
| `cacadora_orc` | 18, 7 | cacadora | Entre as cabanas a leste |
| `anciao_orc` | 5, 3 | anciao | Junto a fogueira do conselho |
| `prisioneiro` | 6, 9.5 | prisioneiro | Jaula perto da fogueira (missao de resgate) |

**Cidade Fantasma** (`scenes/cidade_fantasma/cidade_fantasma.tscn`)

| id | x, z | papel | onde |
|---|---|---|---|
| `spawn_jogador` | 0, 26 | spawn | Entrada sul da antiga capital |
| `condessa` | -24, -8 | condessa | Escadaria da Mansao da Condessa (mercado noturno de reliquias) |
| `espectro_sineiro` | 0, -22 | espectro | Portal da Capela do Relogio Partido |
| `eco_arquimago` | 0, -40 | eco | Altar da capela (versao alternativa do Arquimago) |
| `mercador_reliquias` | -6, 11 | comerciante | Barraca abandonada na praca |
| `coveiro` | 22, -27 | coveiro | Portao do cemiterio |
| `lobisomem` | -19, 30 | eremita | Margem do rio, a montante da ponte |
| `vampiro_menor_1` | 14, -7.5 | inimigo | Diante das ruinas a leste (patrulha noturna) |
| `espectro_1` | -16, -8.5 | inimigo | Porta da ruina queimada a oeste |

As coordenadas são (x, z) em metros. O Y é calculado a partir da altura do terreno (na doca, é a altura do deque). Com a navegação assada, os 29 NPCs originais dos três mapas são alcançáveis a partir do `spawn_jogador` (testado com `NavigationServer3D.map_get_path`). O `dragao` foi acrescentado depois, no deque da doca, ao lado do `spawn_doca`.

## Conversar com os moradores

Os três mapas já vêm com o sistema de conversas (`README_DIALOGOS.md`) ligado:

1. Abra `scenes/vila_grande/vila_grande.tscn`, `scenes/vila_orcs/vila_orcs.tscn` ou `scenes/cidade_fantasma/cidade_fantasma.tscn` e aperte **F6**.
2. Ande até um morador (WASD). Quando estiver perto, aparece **"E - Conversar"** com o nome dele.
3. Aperte **E**. A cápsula da jogadora fica parada enquanto a caixa está aberta.
4. Na caixa: **E / Espaço / Enter / clique** continua, **1–4** ou setas escolhem, **Esc** pula o texto.

Como funciona: cada cena tem um nó `Dialogos` (`scripts/dialogos/interacao_npcs.gd`). No fim do `_ready`, o `mapa_cc0.gd` liga esse nó à jogadora e chama `InteracaoNpcs.spawn_em_marcadores(Marcadores)`, que cria um `NPC_<id>` em cada `Marker3D` cujo nome está no registro (`scripts/dialogos/npcs_registro.gd`). Os `spawn_*` são ignorados. Enquanto a conversa está aberta, `demo_mode` fica `true` no mapa e o movimento para. `$VilaGrande.npc("mira")` devolve o morador criado.

| Mapa | Moradores com história | Moradores de fundo (1–2 falas) |
|---|---|---|
| Porto Velho | mira, jardineira, guardia, sineiro, ferreiro, estalajadeira, arquimago, capitao, dragao | mercador_praca, morador_1, morador_2, crianca_praca, gato |
| Vila dos Orcs | lider_orc | xama_orc, ferreiro_orc, guerreiro_orc_1, guerreiro_orc_2, cacadora_orc, anciao_orc, prisioneiro |
| Cidade Fantasma | condessa, lobisomem | espectro_sineiro, eco_arquimago, mercador_reliquias, coveiro, vampiro_menor_1, espectro_1 |

Para pôr outro morador: crie o `Marker3D` (ou acrescente em `tools/vila_grande_layouts.py` e regere), crie `dialogos/<id>.dialogue` e acrescente o id em `NPCS` ou `GENERICOS` no registro.

Testes (headless): `godot --headless --path . -s res://tests/mapas_dialogos_testes.gd` → `PASS: 314 verificacoes, 0 falhas`.
Capturas com a caixa aberta: `godot --path . -s res://tests/mapas_dialogos_capturas.gd -- /pasta/saida`.

## Navegação e colisões

- O terreno, as casas, as rochas, os troncos, os muros e as paliçadas têm colisão estática.
- As estradas são planas, sem obstáculos, e têm pelo menos 3 m de largura.
- O terreno fica no grupo `navegavel`.
- Chame `assar_navegacao()` na raiz do mapa para criar e assar um `NavigationRegion3D` a partir dos colisores estáticos. Ele é opcional e não roda por padrão.

## Observações

- Os NPCs do jogo são sprites em pixel-art: nenhum sprite foi trocado.
- Os modelos Kenney (chafariz, barracas, moinhos) são mais low-poly que os da Quaternius. Eles foram recoloridos para a paleta do jogo, mas dá para trocar.
- Rio, cachoeira e borda da ilha são aproximações procedurais.
