# Integração de 20/10/2026: noite do Claude + pacotes da Bolorina

Branch `integracao-2026-10-20`, criada a partir de `noite-2026-10-20` (dbe82fe). Tudo foi feito no box. Depois a branch foi enviada ao GitHub (só ela, sem `--force`) e virou o PR #2 para a `main`, sem merge. Não foram tocados `main.tscn`, `reference_village`, o save real, os arquivos-fonte originais nem o CronosMemories. Os testes usam saves próprios de teste.

## Commits

| Commit | O que entrou |
|---|---|
| c041a6b | Integracao 1: pacotes da Bolorina (mapas, diálogos, rostos, missão, tutorial, dungeon, forja UI, eco, arte da noite). Os 61 ícones de itens (16 px) vão para `art/ui/icones/`. Os 18 ícones de equipamento vão para `art/ui/icones_equip/`. Os ícones de 32 px da forja foram movidos para `art/ui/icones_forja/`, e a `forja_ui` aponta para lá. |
| 5a4269a | Integracao 2: `project.godot` do Claude com só duas linhas novas, o autoload `DialogueManager` e o plugin `dialogue_manager`. |
| 95ba50e | Integracao 3: `.import` e `.uid` gerados pelo Godot 4.7.2. |
| ca7fd25 | Integracao 4: registro único de áreas (`data/areas.json` v3 e um único `registro_areas.gd`) com as 12 áreas, todas na primeira ilha. O mapa pintado foi refeito com as 12 áreas. Entradas e saídas de masmorra e os pontos de viagem passam pela API do `jogo_ilha`. O adaptador adota a jogadora dos mapas. O hub das ilhas foi guardado em `nao_usado/hub_mapa_das_ilhas/`. |
| 27291c7 | Integracao 5: a forja usa os dados da Bolorina (9 metais, 87 itens, 3 forjas) sobre a economia do Claude. `forja.gd` ganhou uma camada que normaliza o formato. Os dados provisórios do Claude ficam em `data/forja/provisorio_claude/`. |
| c2e85a9 | Integracao 6a: Porto Velho real com o elenco da Bolorina e os 20 papéis do Claude. O `NpcsArea` ganhou o modo `moradores_do_mapa`. |
| 82e8e88 | Integracao 6b: `docs/ELENCO_UNIFICADO.md`. |
| d177ea7 | Integracao 7: `tests/mapa_novo_reais_testes.gd`, o adaptador da Vale nos 4 mapas reais. |
| 3cf0470 | Integracao 8: ligações de baixo risco (missão e tutorial por grupo, `dialogo_para`, cores dos pontos de viagem) e o script de capturas. |
| 0c19aef | Integracao 9: capturas `docs/integracao-2026-10-20-*.png`. |
| a29dc92 | Integracao 10: este relatório. |
| (merge) | Integracao 11: merge do d0914dd do Claude (Ilha da Maré do Tempo), ver a seção abaixo. |

## Decisões aplicadas

1. **Mapa-múndi.** O mapa é o pintado do Claude (`art/ui/mapa_mundi_pintado.png`; M abre o mapa, T perto da pedra viaja). As 12 áreas estão na primeira ilha: Fazenda, Fazenda grande, Vila (praça), Arena das Cinzas, Masmorra (protótipo), Porto Velho, Vila dos Orcs, Cidade Fantasma, Estação Depois-de-Ontem, Minas da Cinza, Criptas de Cinzalta e Fenda Cronal. Há uma área oculta de teste, `teste_mapa_novo`.
   - Cada área tem `pontos_de_entrada`, `entradas_de_masmorra` e `ponto_de_viagem`.
   - Regras de liberação:
     - `requer` pede os mapas do cartógrafo e a bússola temporal;
     - `requer_visita`: as Criptas pedem a Cidade Fantasma, e a Fenda pede a Estação.
   - `id_antigo` guarda os ids antigos para quem ainda os usa.
   - O hub da Bolorina não é o mapa principal. Fica em `nao_usado/`, com `.gdignore` e um LEIA-ME.
2. **Forja.**
   - Os dados da Bolorina substituíram os provisórios. Ficaram do Claude: loja, serviços, balcão, fundir e forjar, minérios por área e os 3 conjuntos de cor.
   - O formato da Bolorina (materiais como dicionário, fundição separada) é convertido em `scripts/economia/forja.gd`.
   - Os 18 equipáveis do Claude correspondem às peças de cobre, ferro e prata da Bolorina (elmo vira capacete, peitoral vira peito).
   - A `forja_ui` não está ligada ao jogo (ver pendências).
3. **Porto Velho.** É o mapa real `scenes/vila_grande`. A cena provisória continua em `scenes/mundo/porto_velho_provisorio.tscn`, com o roster original em `data/npcs/porto_velho_provisorio.json`. O elenco é o da Bolorina e o mapeamento está em `docs/ELENCO_UNIFICADO.md`.
4. **Vale.**
   - O `area_mapa_novo` roda em todos os mapas da Bolorina, no modo de adoção: usa o corpo `jogador` do mapa, troca a cápsula pela Vale e desliga o controle do mapa.
   - A Vale nasce no ponto do registro e volta ao último lugar seguro se cair.
   - Fica travada durante a conversa, o balcão e o menu de masmorra.
5. **Dialogue Manager.** Ligado só com as duas linhas no `project.godot` do Claude.
6. **Masmorras.**
   - Elevador, caverna, portão e fenda chamam `Registro.viajar`, que usa `jogo_ilha.ir()`.
   - Descer de andar usa `recarregar()`.
   - Ao sair, o saque da sessão vai para a mochila do save, e a Vale volta ao ponto de entrada (por exemplo `elevador_minas`).

## Elenco (resumo)

| Papel do Claude | Morador da Bolorina |
|---|---|
| Helena (forja) | Gaspar Bigorna, Ferraria do Porto |
| Mira (ervas) | Mira |
| Caio (estalagem) | Dona Rosalva |
| Bruna (guarda) | Brida Ferrolho |
| Marina (doca) | Capitão Bartolomeu Nuvem |
| Ozório (torre) | Ozório Pêndulo |
| Bartolomeu (sino) | Mestre Anselmo |
| Rosa (viveiro) | Dona Iolanda |
| Armando (mercado) | Mercador da Praça |
| Gaspar (mina velha) | Seu Tião Lamparina (criado perto do elevador) |
| Nina (mensageria) | Pipo |

Nove NPCs do Claude ficaram como moradores novos, marcados PROPOSTA: Lurdes, Otávio, Cinira, Tobias (cartógrafo; o nome colide com Tobias do Ermo), Severino, Frei Zé, Têmpora, Kiko e Fagulha (proposta: filhote do Ambarion).

Helena, Caio, Armando, Nina e Marina continuam na Vila original (`scripts/ilha/moradores.json`, intocado).

No jogo, o E num morador da Bolorina abre o diálogo dele, com o rosto. No fim da conversa abre o balcão da loja. A entrega de cartas agora é de Pipo para o Capitão Nuvem.

## Integracao 11: Ilha da Maré do Tempo (d0914dd do Claude)

O Claude fez o commit `d0914dd` às 12:13 (horário de Brasília), na `noite-2026-10-20`, depois do `dbe82fe`. Ele foi trazido por merge e agora o PR #2 contém tudo o que está no PR #1. Os arquivos do nosso lado e do lado do Claude foram guardados antes da resolução, no box em `/workspace/merge/backup_mare_1546/`.

Conflitos e como foram resolvidos:
- **`data/areas.json`** (entrou sem conflito de texto, mas foi ajustado). Agora são 13 áreas visíveis: as 12 da primeira ilha e a `ilha_mare`. A `ilha_mare` é a **segunda ilha flutuante** (`"ilha": "ilha_mare_do_tempo"`), e não faz parte da primeira. Ela fica no canto nordeste do mapa pintado, onde o Claude desenhou uma ilha separada. Recebeu `categoria: ilha_nova`, `estado: em_breve`, `chegada: viagem` e um ponto de entrada `viagem` marcado como PROPOSTA. Os campos do Claude foram mantidos (`cena: res://scenes/ilha_mare_do_tempo.tscn`, `bioma: mare`, `requer: tabua_das_mares`, `adaptador`). A nota do registro agora diz que tudo o que existia até 20/10 fica na primeira ilha e que a Maré é a segunda.
- **`scripts/mundo/registro_areas.gd`.** O `validar()` aceita uma área com `"estado": "em_breve"` sem cena, como o próprio registro já dizia ("área sem cena = em breve"). Não houve outra mudança.
- **`data/minerios.json`.** Ficaram os ids unificados (`minas_da_cinza`, `estacao_depois_de_ontem`, `prata_tumular`) e entrou a `ilha_mare` do Claude (bronze das marés ×3 e ferro). O `minerio_bronze_mare` existe como item, mas ainda não é um metal da forja da Bolorina (`data/forja/materiais.json`).
- **`data/itens.json`.** Ficou a "Carta para entregar" unificada (Pipo para o Capitão Nuvem) e entraram os 13 itens novos do Claude.
- **`art/ui/mapa_mundi_pintado.json` e `.png`.** Foram refeitos com `tools/mapa_mundi_pintado.py`, que junta as mudanças dos dois lados (ilha da Maré e ícone `mare` do Claude, ids unificados e trilhas das masmorras). Só o nordeste muda, e a Maré aparece "em breve". A rosa dos ventos foi para o sudoeste, porque cobria a ilha nova.
- **Elenco (Tobias e Capitã Marina).** Ver `docs/ELENCO_UNIFICADO.md`, seção "Ilha da Maré do Tempo". A Tábua das Marés é vendida na `cartografia` do Tobias, e quem pilota o dirigível é o Capitão Nuvem, no lugar da Capitã Marina. O nome do Tobias continua PROPOSTA.
- **Sem mudança:** `data/npcs/ilha_mare.json` (8 moradores), `data/eventos/ilha_mare.json`, as 8 lojas `mare_*`, a Tábua na `cartografia` e o `docs/PROMPT_ILHA_MARE.md`.

Teste novo em `mundo_areas`: confere que a `ilha_mare` está no registro como segunda ilha e pede a Tábua, que todas as outras áreas continuam na primeira ilha, que o botão aparece no mapa (desligado enquanto não houver cena) e que a viagem é recusada sem travar o jogo. A ida e volta de verdade só vai dar para testar quando a cena existir.

Resultados dos testes depois do merge: as mesmas suítes da tabela abaixo foram rodadas de novo, e todas passam com os mesmos números. `mundo_areas` subiu de 37/37 para 42/42 com as 5 checagens novas da Maré. As exceções continuam as conhecidas: combate 53/54 e fazenda_terra 19/20. O eco passa 68/68 com `--fixed-fps 60`. O `vila_travamento` deu 13/14 na primeira rodada (a sonda ficou presa em 37 células com a máquina carregada) e 14/14 quando rodou de novo sozinho. Nenhum arquivo da vila mudou neste merge.

## Testes

Todos rodaram headless, um processo Godot por vez com `flock /workspace/.godot.lock`, e todos usam save de teste.

| Suíte | Resultado |
|---|---|
| equipamento | 97/97 |
| combate | 53/54 (conhecido: `.import` de `vale_combate_gamelab`) |
| combate_adamantium | 36/36 |
| combate_armadura_ataque | 8/8 |
| combate_norte_sul | 7/7 |
| combate_vale_consistencia | 4/4 |
| fazenda_extras | 27/27 |
| fazenda_terra | 19/20 (conhecido) |
| fazenda_testes | 27/27 |
| fidelity_mechanics | 23/23 |
| horizonte | 18/18 |
| ilha_areas | 6/6 |
| masmorra | 10/10 |
| vila_abismo | 5/5 |
| vila_npcs | 17/17 |
| vila_oclusao | 19/19 |
| vila_travamento | 14/14 |
| mundo_areas (12 áreas + ilha_mare em breve, ida e volta) | 42/42 (37/37 antes da Maré) |
| economia | 50/50 |
| fazenda_grande | 11/11 |
| mapa_novo (fixture do Claude) | 15/15 |
| mapa_novo_reais (novo: 4 mapas reais, elenco, elevador) | 53/53 |
| transicoes | 98/98 |
| dialogos | 126/126 |
| mapas_dialogos | 314/314 |
| minas_da_cinza | 154/154 |
| ilha_futurista | 102/102 |
| forja | 52/52 |
| rostos | 579/579 |
| missao | 266/266 |
| forja_ui | 85/85 |
| eco | 68/68 com `--fixed-fps 60`, como manda o doc. Sem essa opção dá 66/68: duas checagens de tempo real ("guarda volta depois de 3 s" e "boneco levanta") falham com a máquina carregada. |
| dungeon | 293/293 |

O teste do hub foi arquivado junto com o hub e não é mais relevante.

Testes ajustados na integração:
- `mundo_areas`: ids novos, e confere a recusa da viagem sem o mapa e as Criptas fechadas.
- `economia`: madeira e couro nas receitas da Bolorina, Gaspar e Capitão Nuvem no Porto Velho real.
- `forja_ui`: pasta `icones_forja`.

## Capturas

Arquivos `docs/integracao-2026-10-20-*.png`:

| Arquivo | O que mostra |
|---|---|
| `mapa` | Mapa pintado com as 12 áreas |
| `porto-velho` | Praça real com a Vale e os moradores |
| `conversa-mira` | Diálogo com o rosto da Mira |
| `conversa-gaspar` | Diálogo com o Gaspar Bigorna |
| `forja-balcao` | Balcão da Ferraria do Porto, aba forjar |
| `cartografo` | Morador novo do Claude |
| `forja-ui` | Interface da forja da Bolorina com os ícones de 32 px |

## O que ainda não está ligado

- **`forja_ui`.** Não está no jogo, porque depende do inventário próprio do `GerenciadorMissoes`, e o jogo usa o `estado` do save. A forja jogável é o balcão do Claude. Para ligar, é preciso uma ponte entre o inventário do save e o do `GerenciadorMissoes` (ver `docs/FORJA_UI_E_ECO.md`).
- **Missão "Atrasada desde amanhã" e tutorial.** O `GerenciadorMissoes` e o `Tutorial` não são criados pelo `jogo_ilha`. Os ganchos estão prontos: os dois entram nos grupos `gerenciador_missoes` e `tutorial`. Quando estiverem na árvore, a troca de área já manda `chegou_area` (com o id novo e o antigo), e `interacao_npcs.conversar()` já pergunta `dialogo_para`. Ainda faltam os eventos que dependem do combate e de objetos:
  - `eco_acertou`;
  - o Lodo Casca-Grossa;
  - o Bate-Estaca do andar 4;
  - o boneco Sir Palha;
  - o cesto da fazenda;
  - a placa do andar 2;
  - `pode_gastar` na forja;
  - `minas_andar_N`;
  - HUD do objetivo.
- **Eco Temporal.** Só existe a arena de protótipo (`scenes/prototipos/eco/arena_eco.tscn`). Não está no combate do jogo.
- **Equipamento.** Só as 18 peças de cobre, ferro e prata são equipáveis (`equipamento.gd`). As outras 69 peças forjadas vão para a mochila como itens, sem atributos de equipamento.
- **Forjas.** Só a Ferraria do Porto tem balcão. A Forja do Clã Brasa-Velha (`ferreiro_orc`, Vila dos Orcs) e a Forja Quântica (`fabricadora`, Estação) têm receitas nos dados, mas não têm loja no jogo.
- **Masmorras.** O estado da sessão (profundidade, chefes derrotados) é estático no `Sessao` e não vai para o save.
- **Ilha da Maré do Tempo.** Os dados, os 8 moradores, as lojas e os eventos estão prontos, mas a cena `scenes/ilha_mare_do_tempo.tscn` ainda não existe (o prompt para montar a vila está em `docs/PROMPT_ILHA_MARE.md`). Também faltam o ponto de viagem real e o bronze das marés como metal da forja.
- **Lore marcada PROPOSTA.** As falas novas de balcão, o nome repetido do Tobias e o Fagulha como filhote do Ambarion.

## Arte que falta

Esta é a lista do Claude em `docs/NOITE_RELATORIO.md`, sem o que os pacotes da Bolorina já cobrem.

| Pedido do Claude | Situação |
|---|---|
| 61 ícones de itens (`art/ui/icones/`) | Coberto (`icones_itens.zip`) |
| Ícones dos conjuntos (`art/ui/icones_equip/`) | Coberto (18) |
| 20 retratos de Porto Velho | 11 cobertos pelos rostos da Bolorina (ferreiro, mira, estalajadeira, guardia, capitao, arquimago, sineiro, jardineira, mercador_praca, minerador_aposentado, crianca_praca). **Faltam 9:** lurdes, otavio, cinira, tobias, severino, frei_ze, tempora, kiko e fagulha, em `art/ui/retratos/<id>.png`. Os rostos da Bolorina seguem a grade de 64 px ampliada 2x, não os 128 px que o Claude pediu. Sem retrato, o balcão usa o quadro de frente do sprite. |
| Sprite do dragão Fagulha (8 direções, 48x48) | **Falta.** Ainda é o ator provisório tingido. |
| Mapa-múndi pintado à mão (`art/ui/mapa_mundi_arte.png`) | **Falta** (opcional). Hoje usa o mapa gerado por `tools/mapa_mundi_pintado.py`, refeito com as 12 áreas. |
| Retratos de Helena, Caio, Armando, Nina e Marina | Não são mais necessários em Porto Velho. Ficam como opcionais para a Vila original. |
