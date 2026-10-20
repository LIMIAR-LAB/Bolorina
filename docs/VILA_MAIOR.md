# Vila maior — plano (parcial no código)

Estado atual: a vila jogável continua sendo a cena de fidelidade V7 (`scripts/ilha/vila_jogo.tscn`,
**não alterada** na geometria). Por cima dela, `scripts/ilha/vila_npcs.gd` coloca os moradores
**ativos** de `scripts/ilha/moradores.json`. Os demais estão só em dados, prontos para a expansão.
Remover: tirar `npcs` de `vila_jogo.gd` (3 linhas) — a cena volta ao que era.

## Distritos
| Distrito | Hoje | Plano |
|---|---|---|
| **Praça** (centro, poço) | existe | taverna da Brasa, quadro de pedidos, festas |
| **Lojas** (leste da praça) | banca do Sr. Armando | armazém, forja da Helena, mercado |
| **Residencial** (oeste) | 2 casas com interior | Casa do Poço, Oficina do Otávio, escola |
| **Borda das ruínas** (norte) | pilares + portão da masmorra | Templo das Cinzas (Frei Zé), Cabana do Guia |
| **Porto / rio** (sul) | — | cais da Marina, ponte para o Lago Grande |

## Moradores (10)
Horários em 24 h (relógio do jogo ainda não existe; hoje todos ficam parados na posição `pos`).

| Nome | Papel | Distrito | Casa | Agenda | Estado |
|---|---|---|---|---|---|
| Sr. Armando | lojista de sementes | lojas | Armazem Armando | 08h armazem → 18h taverna → 21h casa | **ativo** |
| Dona Lurdes | moradora, ex-pescadora | residencial | Casa do Poco | 07h poco → 12h praca → 19h casa | **ativo** |
| Tobias | guia das trilhas | borda das ruinas | Cabana do Guia | 06h trilha das ruinas → 17h praca → 22h casa | **ativo** |
| Mira | jardineira (ja na vila) | praca | Casa da Horta | 07h canteiros → 13h praca → 20h casa | dados |
| Caio | taverneiro | praca | Taverna da Brasa | 10h taverna → 02h casa | dados |
| Helena | ferreira | lojas | Forja | 08h forja → 19h taverna → 22h casa | dados |
| Nina | crianca curiosa | residencial | Casa do Poco | 09h escola → 14h rio → 19h casa | dados |
| Frei Ze | guardiao do templo | templo / borda das ruinas | Templo das Cinzas | 06h templo → 18h praca → 21h templo | dados |
| Marina | barqueira do porto | porto / rio | Casa do Cais | 05h cais → 15h mercado → 20h casa | dados |
| Otavio | carpinteiro | residencial | Oficina | 08h oficina → 18h taverna → 22h casa | dados |

Casas: enquanto não houver casas novas, as duas casas com interior da vila servem de stub
(qual casa vira de quem ainda está a definir); os nomes de `casa` são só dados.

## Personagens remotos (3)
| Nome | Papel | Lugar | Caminho (stub) |
|---|---|---|---|
| Bento | lenhador | Cabana da Floresta (floresta a oeste da fazenda) | trilha da fazenda (oeste do lago) |
| Iara | eremita | Ermida do Penhasco (penhascos a nordeste das ruinas) | escadaria das ruinas |
| Seu Joaquim | pescador aposentado | Casa do Lago (lago grande ao sul da vila) | rio, passando a ponte |

Os caminhos aparecem no mapa (M) como trilhas tracejadas; ainda não há cenas.

## Amizade (corações) — stub
- `estado.amizade[id]` (pontos, salvo em `user://ilha_fazenda_v1.json`); `estado.conversou[id]` = último dia.
- Conversar (E) dá **+1 por dia** por morador. 10 pontos = 1 coração; máx. 10 corações.
- O painel de diálogo mostra `♡ (n/10)` ou os corações cheios (`vila_npcs.gd → coracoes`).
- Planejado: presentes (+3 gosta / −1 não gosta), eventos de coração 2/4/6, desconto na loja.

## Loja (Sr. Armando)
E duas vezes abre a loja: **1** nabo (20) · **2** couve (40) · **3** abóbora (80) · **4** ração ×5 (30) ·
**5** vende colheita, ovos e peixes · **E/Esc** sai. Ouro é o mesmo da caixa de envio da fazenda.

## Próximos passos (código)
1. Relógio do dia (06h–02h) e mover NPCs pela `agenda` (pontos nomeados por distrito).
2. `vila_grande.tscn`: ampliar a grade V7 com os distritos Lojas/Porto (cena nova; a de fidelidade fica intacta).
3. Ativar os 7 moradores restantes, com falas por coração.
