# Masmorras procedurais — Minas da Cinza · Criptas de Cinzalta · Fenda Cronal

Loop jogável: cidade → entrada (rótulo + [E] → menu Entrar/Cancelar) → andares procedurais com inimigos,
minério, baús e escada → covil do chefe no andar final → saída de volta à cidade de origem em qualquer andar.

## Temas

| tema | cena | andares | chefe | minério do tema | origem (cidade/entrada) |
|---|---|---|---|---|---|
| Minas da Cinza (orcs) | scenes/dungeon/minas_da_cinza.tscn | 1–12 + 20 (chefe) | Chefe Orc Brasa-Viva | cobre/carvão (1–5), ferro (6–12), ferro-brasa (8+), adamantium (20) | Porto Velho / Elevador do Tião → andar 1; Vila dos Orcs / Boca do Veio das Cinzas → andar 8 (Túneis de Brasa) |
| Criptas de Cinzalta (mortos-vivos) | scenes/dungeon/criptas_de_cinzalta.tscn | 1–5 + 6 (chefe) | O Sineiro Afogado | prata tumular | Cidade Fantasma / Portão da Cripta |
| Fenda Cronal (anomalias do tempo) | scenes/dungeon/fenda_cronal.tscn | 1–5 + 6 (chefe) | O Paradoxo | cronóstio, chip de anomalia, cristal celeste (4+), adamantium (6) | Estação Depois de Ontem / Fenda Temporal |

Estilos do gerador (`scripts/dungeon/gerador_masmorra.gd`, estende `gerador_minas`): minas `galerias`/`cavernas`/`coracao`;
criptas `criptas` (salas + corredores de lápides) e `nave` (chefe); fenda `fenda` (ilhas no vazio ligadas por pontes) e `anel` (chefe).
Toda configuração (grade, densidade, tabelas de minério, inimigos por profundidade, baús, loot) está em `data/dungeon/temas.json`.

Semente: aleatória a cada run (`Sessao.nova_run()`); fixa com `Sessao.semente_fixa = N` ou env `DUNGEON_SEMENTE=N`.
Mesma semente + andar = mesmo mapa (testado).

## Inimigos (modelo, licença, stats base; multiplicadores por profundidade em temas.json)

### Minas da Cinza (minas_da_cinza) — andares 1–20, chefe no 20

| id | nome | modelo | licença | HP | dano | vel. | ataque |
|---|---|---|---|---|---|---|---|
| orc_grunt | Orc Brasa-Velha (grunt) | dungeon_quaternius/orc.glb | Quaternius (poly.pizza) - CC0 1.0 (Ultimate Monsters: Orc) | 60 | 12 | 3.1 | corpo |
| orc_arqueiro | Orc Besteiro | dungeon_quaternius/orc.glb | Quaternius (poly.pizza) - CC0 1.0 + besta KayKit Skeletons (CC0) | 40 | 10 | 2.8 | distancia |
| orc_xama | Orc Xamã da Brasa | dungeon_quaternius/orc.glb | Quaternius (poly.pizza) - CC0 1.0 + cajado KayKit Skeletons (CC0) | 50 | 16 | 2.6 | distancia |
| orc_bruto | Orc Bruto | dungeon_quaternius/orc.glb | Quaternius (poly.pizza) - CC0 1.0 | 130 | 22 | 2.4 | corpo |
| chefe_orc_brasa_viva | Chefe Orc Brasa-Viva | dungeon_quaternius/orc.glb | Quaternius (poly.pizza) - CC0 1.0 | 560 | 26 | 2.7 | corpo / chefe_orc |

### Criptas de Cinzalta (criptas_de_cinzalta) — andares 1–6, chefe no 6

| id | nome | modelo | licença | HP | dano | vel. | ataque |
|---|---|---|---|---|---|---|---|
| zumbi | Zumbi de Cinzalta | dungeon_quaternius/zombie.glb | Quaternius (poly.pizza) - CC0 1.0 (Zombie) | 70 | 12 | 1.9 | corpo |
| esqueleto_lacaio | Esqueleto Lacaio | kaykit_skeletons/Skeleton_Minion.glb | KayKit Character Pack: Skeletons (Kay Lousberg) - CC0 1.0 | 38 | 10 | 3.0 | corpo |
| esqueleto_guerreiro | Esqueleto Guerreiro | kaykit_skeletons/Skeleton_Warrior.glb | KayKit Character Pack: Skeletons (Kay Lousberg) - CC0 1.0 | 55 | 14 | 3.0 | corpo |
| fantasma | Fantasma Afogado | dungeon_quaternius/ghost.glb | Quaternius (poly.pizza) - CC0 1.0 (Ultimate Monsters: Ghost) | 32 | 10 | 3.4 | corpo / fantasma |
| esqueleto_besteiro | Esqueleto Besteiro | kaykit_skeletons/Skeleton_Rogue.glb | KayKit Character Pack: Skeletons (Kay Lousberg) - CC0 1.0 | 35 | 10 | 2.9 | distancia |
| zumbi_gordo | Zumbi Inchado | dungeon_quaternius/zombie_chubby.glb | Quaternius (poly.pizza) - CC0 1.0 (Zombie Chubby) | 120 | 18 | 1.6 | area |
| caveira_espectral | Caveira Espectral | dungeon_quaternius/ghost_skull.glb | Quaternius (poly.pizza) - CC0 1.0 (Ultimate Monsters: Ghost Skull) | 26 | 8 | 3.8 | corpo / fantasma |
| esqueleto_mago | Esqueleto Mago | kaykit_skeletons/Skeleton_Mage.glb | KayKit Character Pack: Skeletons (Kay Lousberg) - CC0 1.0 | 45 | 15 | 2.6 | distancia |
| sineiro_afogado | O Sineiro Afogado | dungeon_quaternius/ghost.glb | Quaternius (poly.pizza) - CC0 1.0 (Ghost, escala de chefe) | 500 | 24 | 2.6 | corpo / chefe_sineiro |

### Fenda Cronal (fenda_cronal) — andares 1–6, chefe no 6

| id | nome | modelo | licença | HP | dano | vel. | ataque |
|---|---|---|---|---|---|---|---|
| sentinela_cronal | Sentinela Cronal | dungeon_quaternius/robot_enemy.glb | Quaternius (poly.pizza) - CC0 1.0 (Robot Enemy) | 60 | 13 | 3.0 | corpo |
| olho_relogio | Olho-Relógio | quaternius_scifi_essentials/Enemy_EyeDrone.gltf | Quaternius Sci-Fi Essentials Kit - CC0 1.0 (Enemy EyeDrone) + mostrador procedural | 22 | 8 | 2.8 | distancia / olho |
| drone_cronal | Drone Cronal | dungeon_quaternius/robot_flying.glb | Quaternius (poly.pizza) - CC0 1.0 (Robot Enemy Flying) | 30 | 9 | 3.3 | distancia / flutua |
| duplicata | Duplicata | dungeon_quaternius/robot_humanoide.glb | Quaternius (poly.pizza) - CC0 1.0 (Animated Robot) | 55 | 14 | 3.4 | corpo / duplicata |
| colosso_cronal | Colosso Cronal | dungeon_quaternius/robot_legs_gun.glb | Quaternius (poly.pizza) - CC0 1.0 (Robot Enemy Legs Gun) | 140 | 24 | 2.3 | area |
| o_paradoxo | O Paradoxo | (eco da Vale: sprites do jogador_combate) | eco da própria Vale (sprites do jogador_combate.gd, tingidos) | 520 | 22 | 3.4 | corpo / chefe_paradoxo |


Comportamentos: perseguir (navmesh) → telegraph vermelho → golpe/projétil/área; `fantasma` fica translúcido, atravessa e pisca (blink);
`duplicata` rebobina posição (rewind) e teleporta atrás do jogador; `olho_relogio` tem mostrador de relógio e projétil que causa lentidão;
`drone_cronal` flutua. Barra de HP em billboard. Todos estendem `scripts/combate/inimigo_orc.gd` (sem editá-lo) via
`scripts/dungeon/inimigos/inimigo_masmorra.gd`.

## Chefes (`scripts/dungeon/inimigos/chefe_masmorra.gd`)
- Ataque em área a cada 3º ataque (anel telegrafado); fase 2 em 50% de HP: mais rápido + invoca lacaios do tema.
- Chefe Orc Brasa-Viva (orc em escala, luz de brasa), O Sineiro Afogado (fantasma em escala com sino), O Paradoxo (marionete do
  `jogador_combate` — o eco da própria Vale, com glitch/tinta).
- Ao morrer: barra some, baú do chefe + portal de volta aparecem, loot de forja.

## Combate e loot
- Jogador real `scripts/combate/jogador_combate.gd` (instanciado, não editado). Ponte `scripts/dungeon/combate_masmorra.gd`
  espelha `arena_combate._golpe_jogador` / `_inimigo_ataca` (+ raycast de parede), projéteis, lentidão, invocação.
- Loot: tabela por inimigo → pickups com ímã → inventário da sessão no formato da forja `{"itens": {id: qtd}}`
  (`Sessao.inventario`). Baús (`abrir_bau`) dão materiais de `data/forja/materiais.json`. Minério com picareta mínima.
- Morte do jogador → banner "A Vale caiu..." e volta à cidade de origem; o loot ainda no chão se perde (o já coletado fica no inventário da sessão).

Controles: WASD mover · J/clique atacar · K/botão direito especial · Espaço esquiva · G Adamantium · E interagir (minério, baú, escada, saída) · Tab mapa.
Menu da entrada: E abre, Enter = Entrar, Esc = Cancelar.

## Registro de áreas
`data/areas.json` (versao 1) + `scripts/mundo/registro_areas.gd` (estático, sem autoload — project.godot intocado).

```
{ "versao":1, "areas":[ {
   "id":"porto_velho", "nome":"Porto Velho", "tipo":"cidade"|"masmorra", "tema":"<id em temas.json>" (masmorra),
   "regiao":"...", "cena":"res://...tscn", "arte":"res://art/ui/telas/<id>.png", "descricao":"...",
   "pontos_de_entrada":[ {"id":"chegada","pos":[x,z]} | {"id":"andar_1","andar":1} ],
   "entradas_de_masmorra":[ {"id":"elevador_minas","area":"minas_da_cinza","ponto":"andar_1",
                              "tipo":"elevador|caverna|portao|fenda","pos":[x,z],"ang":graus,"rotulo":"..."} ] } ] }
```
API: `Registro.area(id)`, `cena(id)`, `nome(id)`, `ponto(area, ponto)`, `entrada_de_masmorra(cidade, entrada)`, `origem_de(...)`,
`viajar(area, ponto, origem)`, `consumir_chegada()`, `chegada_pendente()`, `validar()` (lista de erros; testado = []).

Entradas nas cidades (nó `EntradaMasmorra` com `scripts/dungeon/entrada_masmorra.gd`, posição vinda do registro):

| cidade (cena) | entrada | pos [x,z] | destino |
|---|---|---|---|
| Porto Velho (scenes/vila_grande/vila_grande.tscn) | Elevador do Tião | [-31, -14.5] | Minas andar 1 |
| Vila dos Orcs (scenes/vila_orcs/vila_orcs.tscn) | Boca do Veio das Cinzas | [-26, 11] | Minas andar 8 (Túneis de Brasa) |
| Cidade Fantasma (scenes/cidade_fantasma/cidade_fantasma.tscn) | Portão da Cripta | [35, -31] | Criptas andar 1 |
| Estação Depois de Ontem (scenes/ilha_futurista/ilha_futurista.tscn) | Fenda Temporal | [-37, 6] | Fenda andar 1 |

Única mudança nessas 4 cenas: 1 ext_resource + 1 nó `EntradaMasmorra` (area_id/entrada_id). Menu mostra tema, profundidade
máxima já alcançada, Entrar/Cancelar. Saídas: cada andar tem `saida_origem` (elevador/escada da cripta/portal) que volta para o
ponto de retorno da entrada de origem; escada `escada_descer` desce um andar.

## Testes
`godot --headless --path . -s res://tests/dungeon_testes.gd` (env `DUNGEON_TESTE_SO=semente,andares,combate,chefe,registro,cidades` filtra).
Resultado: **293 verificações, 0 falhas** — semente fixa reproduzível, todos os 25 andares gerados com ida e volta alcançáveis
(navmesh), spawn de inimigos, kill roteirizado → loot no inventário (3 temas), os 3 chefes até fase 2 e morte → baú + portal,
registro válido, entrada de cada cidade → masmorra → volta (distância 0 m do ponto de retorno).
Regressão: minas_da_cinza_testes 154/0, ilha_futurista_testes 102/0, forja_testes 52/0, mapas_dialogos_testes 314/0, dialogos_testes 126/0.

## Variáveis de ambiente (dev)
`DUNGEON_TEMA`, `DUNGEON_ANDAR`, `DUNGEON_SEMENTE`, `DUNGEON_CAPTURA=<dir>` (gera previews e sai), `DUNGEON_CAPTURA_SO`, `DUNGEON_TESTE`.

## Para integrar (Claude)
- Nada em scripts/combate/* ou scripts/ilha/equipamento* foi editado. Inimigos estendem inimigo_orc (sinais `ataque`/`morto`,
  `receber_golpe`, `alvejavel`); se a arena mudar `_golpe_jogador`/`_inimigo_ataca`, atualizar `combate_masmorra.gd`.
- `Sessao.inventario` usa o formato da forja; ligar ao inventário global quando existir.
- main.tscn, saves, CronosMemories, project.godot e npcs_registro.gd não foram tocados.
