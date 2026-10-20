# Ilha da Maré do Tempo

Uma ilha flutuante a nordeste da Ilha das Cinzas, onde **o mar fica em cima**. Uma lâmina de água suspensa cobre o
céu da ilha e sobe e desce como maré. Só que a maré não traz água: traz **tempo**. Quando ela baixa, deixa na praia
coisas de outras eras (um navio viking, uma geladeira de 1987, um robô que pede desculpas). Quando sobe, os peixes
nadam no ar e a vila inteira pesca de vara apontada para cima.

Tom: o mesmo da Ilha das Cinzas (comércio entre ilhas, lendas, viagem no tempo, humor absurdo de multiverso), mais
salgado e mais barulhento. É a ilha dos pescadores, sucateiros e colecionadores.

## Lugares
| Lugar | O que tem |
|---|---|
| **Vila Contracorrente** (centro) | Casas com telhado de casco de barco virado; a praça tem um relógio de sol que marca a maré, não a hora |
| **Cais do Céu** (norte) | Píer que sobe em espiral até a água suspensa; doca do dirigível da Capitã Marina |
| **Praia dos Naufrágios** (leste) | Areia cinza com destroços de várias eras; aparece inteira só na maré baixa |
| **Farol Invertido** (sul) | Farol pendurado de cabeça para baixo na água de cima; a luz aponta para o chão |
| **Recife de Engrenagens** (oeste) | Rochas cheias de engrenagens fossilizadas; minério de **bronze das marés** |
| **Gruta da Ampulheta** (subterrâneo) | Mini-dungeon onde a areia cai para cima; guarda o Relojoeiro |

## Moradores (8, com função de jogo)
| id | Nome | Papel | Função |
|---|---|---|---|
| `dona_nereida` | Dona Nereida | chefe da vila, pescadora de céu | missões da maré, iscas aéreas |
| `zezinho_sucata` | Zezinho Sucata | sucateiro | compra e vende achados da maré baixa |
| `professora_eon` | Professora Éon | arqueóloga do tempo | identifica relíquias (troca "objeto estranho" por relíquia nomeada) |
| `marujo_bento2` | Bento-de-Outra-Linha | marinheiro de outro universo | é o Bento da Ilha das Cinzas, mas de 1700; boatos e lore |
| `relojoeiro` | O Relojoeiro | guardião da Gruta da Ampulheta | conserta a bússola temporal; chefe opcional |
| `lumi` | Lumi | faroleira | acende o Farol Invertido nos eventos; vende óleo de farol |
| `tatu_dourado` | Tatu Dourado | mercador ambulante de outra era | aparece só na Feira das Eras |
| `polvo_contador` | Contador | polvo contabilista | banco da ilha; aceita moedas de qualquer século |

## Ciclo da maré (base dos eventos)
A maré tem 4 fases por dia de jogo (6 h cada): **baixa → enchente → alta → vazante**.
- **Maré baixa**: a Praia dos Naufrágios abre; nós de coleta de "achados" aparecem na areia.
- **Maré alta**: dá para pescar no ar (peixes voadores) no Cais do Céu.
- **Enchente/vazante**: mudam os preços do Zezinho (achado vale mais quando a maré está voltando).

## Eventos
| Evento | Quando | O que acontece | Recompensa |
|---|---|---|---|
| **Maré dos Achados** | toda maré baixa | 6 nós de coleta na praia: sucata, objeto estranho, relíquia rara (5%) | itens para vender ou identificar |
| **Pesca no Céu** | toda maré alta | peixes voadores (sardinha-nuvem, linguado-pipa, enguia-raio) no Cais do Céu | peixes novos, receita de sopa |
| **Feira das Eras** | 1 dia a cada 7 | o Tatu Dourado e 3 barracas de outras épocas vendem itens raros, só por um dia | relíquias, sementes de outra era |
| **Eclipse da Ampulheta** | aleatório (1 em 10 dias) | o tempo para por 2 min: NPCs congelam no meio da frase; a Vale anda e resolve um pequeno quebra-cabeça de relógios na praça | Areia parada (material da forja) |
| **Chuva de Engrenagens** | depois de tempestade | engrenagens caem do mar de cima; o Recife fica com o dobro de minério por um dia | bronze das marés extra |
| **Visita do Eu do Futuro** | 1 vez, depois do dia 15 | uma Vale mais velha pede para a Vale de hoje NÃO comprar uma coisa na feira; a missão é descobrir o quê (spoiler: é um patinho de borracha que vira chefe) | Capa do Futuro (cosmético) |
| **Tempestade de Vidro** | evento de combate | a água de cima racha; elementais de vidro descem; a vila pede ajuda | lingotes de vidro-do-tempo, amizade |
| **Festival do Farol Invertido** | fim de estação | a Lumi acende o farol; a luz para cima mostra o mapa do tesouro da estação | baú do festival, retrato especial |

## Economia e forja
- Metal novo: **bronze das marés** (nível 4, minério `minerio_bronze_mare` no Recife de Engrenagens).
- Material especial: **areia parada** (do Eclipse) e **vidro-do-tempo** (da Tempestade): base da liga temporal da
  Ilha Futurista.
- Itens novos: `achado_estranho`, `sucata`, `sardinha_nuvem`, `linguado_pipa`, `enguia_raio`, `oleo_farol`,
  `areia_parada`, `vidro_tempo`, `minerio_bronze_mare`, `lingote_bronze_mare`, `tabua_das_mares` (libera a viagem).

## Como se chega
O Tobias (cartógrafo de Porto Velho) vende a **Tábua das Marés**; com ela, a Capitã Marina leva a Vale de dirigível.
No registro de áreas: `ilha_mare` → `scenes/ilha_mare_do_tempo.tscn` (quando a cena existir), `requer: tabua_das_mares`.

## Dados já criados no projeto
- `data/areas.json` → área `ilha_mare` ("em breve" até a cena chegar).
- `data/npcs/ilha_mare.json` → os 8 moradores com falas e funções.
- `data/eventos/ilha_mare.json` → ciclo da maré e os 8 eventos (gatilho, duração, efeitos), para o código de eventos.
- `data/minerios.json` → nós de bronze das marés na área.
