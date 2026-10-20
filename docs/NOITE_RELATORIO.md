# Relatório da madrugada (20/10/2026) — branch `noite-2026-10-20`

Trabalho local, sem push, sem merge, sem créditos pagos. Backups em `work/backups/noite/`.
Testes headless: `work/noite_logs/suites.ps1 -Etapa <nome>` (logs em `work/noite_logs/<etapa>/`).

## Antes da noite (referência)
Estado commitado como "Estado antes da noite" (`ce2bbd3`), já com a Vale única e as peças do PixelLab.
Equipamento 79/79 · combate 53/54 (falha antiga do `.import` do vale_combate_gamelab) · fazenda_terra 19/20 (falha antiga:
terra arada sem mato) · demais suítes 100%.

## Etapa 0 — entregas da Bolorina
**Pulada.** Os zips `ilha_entrega_1..4` não estão na máquina (procurei no projeto, Documentos, Downloads, Desktop e D:).
Não existem `scenes/`, `dialogos/` nem o addon Dialogue Manager. O registro de áreas já aponta para as cenas que eles
trazem (`scenes/vila_grande.tscn`, `scenes/vila_orcs.tscn`, `scenes/cidade_fantasma.tscn`): quando chegarem, aparecem
no mapa e no teleporte sem mexer em código.

## Etapa 1 — mapa-múndi + teleporte
- **Mapa "bonito"**: não achei nenhuma versão pintada anterior (git tem só o commit inicial; procurei em `art/ui`,
  `docs`, `work/`, release e zips). O jogo previa `art/ui/mapa_mundi_arte.png` (arte do usuário) que nunca existiu.
  Fiz um mapa pintado novo por código, `tools/mapa_mundi_pintado.py` → `art/ui/mapa_mundi_pintado.png` (1200×800):
  relevo sombreado, serra com neve, floresta, rio, névoa da Cidade Fantasma, ilhota dos orcs, ilha flutuante, trilhas
  e selos por área. O esquemático (`mapa_esquematico.png`) continua intacto e é o reserva. Ordem: arte do usuário >
  pintado > esquemático.
- **Registro único**: `data/areas.json` + `scripts/mundo/registro_areas.gd` (id, nome, cena, chegada, posição no
  mapa, bioma, descrição). Áreas: fazenda, vila, arena, masmorra, Porto Velho, Vila dos Orcs, Cidade Fantasma, Minas da
  Cinza, Ilha Futurista. Área sem cena = "em breve" (desligada no mapa).
- **Teleporte**: M abre o mapa; ◀ ▶/Tab escolhe, Enter ou clique viaja (`jogo_ilha.gd → viajar(id)`). Área nova do
  registro carrega por uma rota genérica (instancia a cena, passa `estado`/`gerenciador`, chama `nascer(chegada)`).
- **Chegada e volta**: cada área ganha uma **pedra de viagem** (cristal azul) no ponto de chegada
  (`scripts/mundo/pedra_viagem.gd`); perto dela, **T** abre o mapa no modo viagem.
- **Teste**: `tests/mundo_areas_testes.gd` 19/19 (registro, mapa com todas as áreas, em breve recusado, entra e sai de
  fazenda → vila → arena → masmorra → fazenda, pedra em cada uma, T abre o modo viagem, save real intacto).
- Suítes depois da etapa: iguais às de antes (equipamento 79/79, combate 53/54, fazenda_terra 19/20, resto 100%).
- Depois: mapas da cartógrafa liberam a viagem para Minas, Cidade Fantasma, Vila dos Orcs e Ilha Futurista (`"requer"` no registro).

## Etapa 2 — Vale nos mapas novos (preparada; os mapas não chegaram)
- `scripts/mundo/area_mapa_novo.gd`: carrega o mapa, troca a cápsula `SubstituirPeloSpriteDaVale` pela **Vale única**
  (sem espada), com o mesmo controle (WASD, Shift corre) e a câmera isométrica ortográfica do jogo (yaw 50°,
  pitch 28°). Colisão: `CharacterBody3D` contra os corpos do mapa. **E** conversa com os NPCs do roster da área
  (marcadores `npc_<id>`); minério pelos marcadores `minerio_<metal>`. Se o addon Dialogue Manager estiver ativo e
  existir `dialogos/<id>.dialogue`, a conversa usa o balão dele.
- No registro, Porto Velho, Vila dos Orcs, Cidade Fantasma, Minas da Cinza e Ilha Futurista já apontam para o
  adaptador. Quando `scenes/vila_grande.tscn` chegar, Porto Velho troca sozinho do provisório para o mapa novo.
- Teste com um mapa de mentira no mesmo formato (`tests/fixtures/mapa_novo_teste.tscn`): `tests/mapa_novo_testes.gd`
  15/15 (cápsula trocada, Vale nasce no lugar, anda, bate na parede e escorrega, fica no chão, E conversa, NPC no
  marcador, minério no marcador, entra e sai pelo mapa-múndi).
- **Falta quando os zips chegarem**: ativar autoload + plugin do Dialogue Manager no `project.godot`, rodar
  `tests/dialogos_testes.gd` e `tests/mapas_dialogos_testes.gd`, e rodar `mapa_novo_testes` apontando para os mapas reais.

## Etapa 3 — Porto Velho com 20 NPCs que funcionam
- Como o mapa da Bolorina não chegou, fiz um **Porto Velho provisório** (`scenes/porto_velho_provisorio.tscn`): o
  cenário da vila com os **20 moradores de Porto Velho** (a vila original e seus testes ficam iguais).
- `data/npcs/porto_velho.json`: 20 NPCs, cada um com papel, loja/serviço, falas no tom da lore, cor, retrato e
  diálogo previstos: Helena (ferreira, forja), Mira (herbalista), Caio (estalagem), Bruna (guardiã, missões),
  Capitã Marina (dirigível, viagem), Arquimago Ozório (encantos), Bartolomeu (sineiro, pula o dia), Rosa
  (jardineira, mudas), Sr. Armando (mercado da praça), Otávio (carpinteiro, melhorias), Dona Lurdes (iscas), Cinira
  (banco, cofre com 1% ao dia), Tobias (cartógrafo, mapas que liberam viagem), Severino (alfaiate), Seu Gaspar
  (minerador aposentado), Nina (entregas), Frei Zé (códex), Madame Tempora (relíquias do tempo), Kiko (pets) e
  Fagulha (dragão da doca, presente diário).
- Sistema genérico: `scripts/economia/loja.gd` (comprar, vender, estoque diário, preço de venda por loja),
  `servicos.gd` (descanso, boatos, missões, viagem, encantar, cofre, entregas, códex, pet, dragão...),
  `npcs_area.gd` (conversa + balcão com abas Comprar/Vender/Serviços/Fundir/Forjar), `itens.gd` (catálogo
  `data/itens.json`, 61 itens, ícone `art/ui/icones/<id>.png` com fallback). Lojas: `data/lojas/*.json` (20).
- Save: chaves novas `lojas` e `extras` (saves antigos carregam vazios); o inventário e o equipamento são os de
  sempre. Teste: `tests/economia_testes.gd` 49/49.

## Etapa 4 — Forja e equipamentos
- `scripts/economia/forja.gd` + `data/forja/{materiais,itens,receitas}.json` **provisórios** (mesmo formato pedido:
  id, nome, nível, materiais[{id,qtd}], ouro, nivel_forja, stats): cobre, ferro e prata de túmulo. Fundir: 3 minérios
  + 1 carvão = 1 lingote. Forjar: lingotes + ouro = peça. A forja sobe de nível a cada 3 peças.
- **3 conjuntos** completos (capacete, peitoral, luvas, botas, escudo, espada) de cobre, ferro e prata, só com cor:
  `tools/vale_conjuntos.py` recolore as máscaras da Vale (peito, botas, mãos) e o elmo de ferro do PixelLab. Slots
  novos no equipamento: **mãos, pés, escudo, arma** (tela com 8 slots). Escudo e espada não aparecem fora do
  combate (Vale sem arma na cidade). Ícones novos em `art/ui/icones_equip/`.
- Minério: `scripts/economia/minerios_area.gd`: nós em cada área (`data/minerios.json` ou marcadores `minerio_*`),
  E minera (prata pede picareta de ferro), o nó volta no dia seguinte.
- O capacete da forja se chama `capacete_<metal>` porque `elmo_ferro` já era a peça do PixelLab.

## Etapa 5 — Fazenda maior
- Variante nova `scripts/ilha/fazenda_grande.tscn` (a fazenda original não mudou): `tools/fazenda_grande.py` parte do
  layout atual e amplia a área andável de 2.793 m² para 5.427 m² (+94%), 60 células de canteiro já aradas (eram 12),
  pomar com 16 árvores a oeste, celeiro, pasto cercado ao sul e caminho no sudeste até o portão de **Porto Velho**.
- No registro como "Fazenda grande" (aparece no mapa). Teste: `tests/fazenda_grande_testes.gd` 11/11.

## Commits locais (branch `noite-2026-10-20`, nada enviado)
- (o commit deste relatório vem por último)
- `102c6ce` Etapa 2 (preparada): adaptador dos mapas novos com a Vale unica, controle e camera do jogo
- `cf1f54f` Etapa 5: fazenda grande (variante) com pomar, celeiro, pasto e caminho ate Porto Velho
- `30099e1` Etapas 3 e 4: economia (lojas, servicos, forja, minerio), Porto Velho provisorio com 20 NPCs e 3 conjuntos
- `713a713` Etapa 1: mapa-mundi pintado, registro de areas e pedras de viagem
- `ce2bbd3` Estado antes da noite: trabalho sem commit ate 20/10 (equipamento PixelLab, Vale unica, fazenda, vila)

## Testes — antes e depois
| Suíte | Antes | Depois |
|---|---|---|
| equipamento_testes | 79/79 | 97/97 (mais peças = mais verificações) |
| combate_testes | 53/54 | 53/54 (mesma falha antiga do .import) |
| combate_adamantium_testes | 36/36 | 36/36 |
| combate_armadura_ataque | 8/8 | 8/8 |
| combate_norte_sul | 7/7 | 7/7 |
| combate_vale_consistencia | 4/4 | 4/4 |
| fazenda_extras | 27/27 | 27/27 sozinho; 26/27 na rodada completa (espera do peixe com limite de quadros, aleatório) |
| fazenda_terra | 19/20 | 19/20 (falha antiga) |
| fazenda_testes | 27/27 | 27/27 |
| fidelity_mechanics | 23/23 | 23/23 |
| horizonte_testes | 18/18 | 18/18 |
| ilha_areas_testes | 6/6 | 6/6 |
| masmorra_testes | 10/10 | 10/10 |
| vila_abismo | 5/5 | 5/5 |
| vila_npcs_testes | 17/17 | 17/17 |
| vila_oclusao_testes | 19/19 | 19/19 |
| vila_travamento | 14/14 | 14/14 |
| mundo_areas_testes (novo) | — | 23/23 |
| economia_testes (novo) | — | 49/49 |
| fazenda_grande_testes (novo) | — | 11/11 |
| mapa_novo_testes (novo) | — | 15/15 |

## Pendências
- Zips da Bolorina (etapa 0): mapas, Dialogue Manager e testes de diálogo ainda não existem na máquina.
- O mapa-múndi "bonito" anterior não foi encontrado; fiz um novo pintado. Se o Thiago lembrar onde estava, troco.
- Ataque das espadas é somado (`Equipamento.ataque`), mas o combate ainda não usa esse número.
- Pets, montaria, melhorias da casa/celeiro e cosméticos ficam registrados no save, sem visual ainda.
- Forja com 3 metais provisórios; trocar pelos JSON da Bolorina (mesmo formato) e rodar `tools/vale_conjuntos.py`.
- Teste `fazenda_extras` ("peixe mordeu") falha às vezes e passa de novo sozinho (aleatório, já acontecia antes).
- `fazenda_terra` 19/20 e `combate_testes` 53/54 são falhas antigas.

## Arte para a Bolorina gerar
| O quê | Arquivo | Tamanho |
|---|---|---|
| Retrato de cada NPC de Porto Velho (20) | `art/ui/retratos/<id>.png` com id: helena, mira, caio, bruna, marina, ozorio, bartolomeu, rosa, armando, otavio, lurdes, cinira, tobias, severino, gaspar, nina, frei_ze, tempora, kiko, fagulha | 128×128 px, fundo transparente |
| Ícones de itens (61) | `art/ui/icones/<item>.png` — sementes: semente_nabo, semente_couve, semente_abobora, semente_girassol, racao, muda_macieira, muda_laranjeira; colheita: nabo, couve, abobora, ovo, maca, laranja; peixes: peixe_carpa, peixe_tilapia, peixe_dourado; materiais: madeira, pedra, fibra, tabuas, corda, tocha, sal; pesca: isca_minhoca, isca_brilhante, vara_reforcada; poções: pocao_vida, pocao_energia, cha_calmante, antidoto; comida: sopa_peixe, pao_cinzas, torta_abobora; minério: minerio_cobre, minerio_ferro, minerio_prata, carvao; lingotes: lingote_cobre, lingote_ferro, lingote_prata; ferramentas: picareta, picareta_ferro, lanterna_mina; mapas: mapa_minas, mapa_cidade_fantasma, mapa_vila_orcs, bussola_temporal; roupas: chapeu_palha, lenco_vermelho, capa_viagem, tinta_anil; relíquias: relogio_parado, moeda_futuro, fossil_dragao, ampulheta_rachada, escama_dragao, insignia_guarda; pets: racao_pet, coleira, apito_montaria; missão: carta_entrega | 16×16 px (mesmo estilo dos ícones da fazenda) |
| Ícones dos conjuntos (opcional, hoje feitos por código) | `art/ui/icones_equip/<capacete\|peito\|luvas\|botas\|escudo\|espada>_<cobre\|ferro\|prata>.png` | 16×16 px |
| Mapa-múndi pintado à mão (opcional; substitui o gerado) | `art/ui/mapa_mundi_arte.png`, com as áreas nas posições de `data/areas.json → mapa` | 1200×800 px |
| Sprite do dragão Fagulha (hoje é o gato tingido de vermelho) | `art/characters/fagulha/` no formato de `original_cat_v6` | 48×48 px por quadro, 8 direções |

## Capturas
`docs/noite-porto-velho.png`, `noite-mapa.png`, `noite-conversa.png`, `noite-forja.png`, `noite-conjunto-ferro.png`,
`noite-fazenda-grande.png` (geradas por `tests/noite_captura.gd`, com janela e save de teste).
