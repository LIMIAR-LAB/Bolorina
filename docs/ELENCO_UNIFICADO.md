# Elenco unificado de Porto Velho

Integração de 20/10/2026. Porto Velho é o mapa real da Bolorina (`scenes/vila_grande/vila_grande.tscn`). O elenco é o da Bolorina; as 20 lojas e serviços que o Claude criou para a cena provisória foram entregues ao morador da Bolorina que mais combina com cada uma. Quando nenhum morador servia, o NPC do Claude ficou como morador novo, marcado PROPOSTA.

Dados: `data/npcs/porto_velho.json` (gerado por `tools/integracao_elenco.py`). O roster original do Claude continua em `data/npcs/porto_velho_provisorio.json`, usado pela cena `scenes/mundo/porto_velho_provisorio.tscn` (área oculta `teste_mapa_novo`).

## Como funciona no jogo

- Morador da Bolorina com loja: E abre a conversa dele no Dialogue Manager (rosto, falas e lore da Bolorina). Quando a conversa termina, abre o balcão da loja do Claude (comprar, vender, fundir, forjar ou serviços).
- Morador novo do Claude: usa o corpo e as falas do Claude, desenhado pelo `NpcsArea` no chão livre mais próximo da posição indicada. E mostra as falas e depois o balcão, como na cena provisória.
- Seu Tião Lamparina não tem marcador no mapa de Porto Velho (ele mora nas Minas). Foi criado com `InteracaoNpcs.criar_npc` perto do elevador das minas.

## Papéis do Claude entregues ao elenco da Bolorina

| Papel do Claude (NPC provisório) | Loja | Morador da Bolorina | id no mapa |
|---|---|---|---|
| Helena (ferreira) | `forja` | Gaspar Bigorna (ferreiro · Ferraria do Porto) | `ferreiro` |
| Mira (herbalista) | `ervas` | Mira (herbalista · Botica da Mira) | `mira` |
| Caio (estalajadeiro) | `estalagem` | Dona Rosalva (estalajadeira · Estalagem da Lanterna) | `estalajadeira` |
| Bruna (guardiã da vila) | `guarda` | Brida Ferrolho (guardiã · Posto da Guarda) | `guardia` |
| Capitã Marina (capitã do dirigível) | `doca` | Capitão Bartolomeu Nuvem (capitão do dirigível Andorinha) | `capitao` |
| Arquimago Ozório (arquimago) | `torre_ozorio` | Ozório Pêndulo (arquimago · Torre Torta) | `arquimago` |
| Bartolomeu (sineiro) | `sino` | Mestre Anselmo (sineiro · Torre do Sino) | `sineiro` |
| Rosa (jardineira) | `viveiro` | Dona Iolanda (horticultora · Celeiro das Sementes) | `jardineira` |
| Sr. Armando (mercador da praça) | `mercado` | Mercador da Praça (mercador · barracas da praça) | `mercador_praca` |
| Seu Gaspar (minerador aposentado) | `mina_velha` | Seu Tião Lamparina (mineiro aposentado · Elevador do Tião) | `minerador_aposentado` |
| Nina (criança mensageira) | `mensageria` | Pipo (mensageiro da praça) | `crianca_praca` |

## Moradores novos (NPCs do Claude sem equivalente)

| NPC do Claude | Papel | Loja | Posição (x, z) | Nota |
|---|---|---|---|---|
| Otávio | carpinteiro | `carpintaria` | [-6, 12.5] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Dona Lurdes | pescadora | `pescaria` | [26, 10] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Cinira | banqueira de cinzas | `banco` | [22, 9] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Tobias | cartógrafo | `cartografia` | [26, 2] | Mesmo nome do Tobias do Ermo (lobisomem) do elenco da Bolorina e do Tobias guia de trilhas da Vila original. PROPOSTA: decidir se são a mesma pessoa. |
| Severino | alfaiate | `alfaiataria` | [-8, 25] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Frei Zé | bibliotecário | `biblioteca` | [-24, 8] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Madame Tempora | comerciante de relíquias do tempo | `reliquias` | [24, -24] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Kiko | domador | `domador` | [-26, 24] | PROPOSTA: morador novo, sem lore da Bolorina. |
| Fagulha | dragão da doca | `dragao` | [52, 5] | PROPOSTA: filhote do Ambarion (dragão guardião da Rota do Âmbar, que fica na entrada da doca). |

## Quem ficou só na Vila original

Helena (ferreira), Caio, Armando, Nina e Marina são moradores originais da Vila do Thiago (`scripts/ilha/moradores.json`, intocado). Na cena provisória o Claude os tinha levado para Porto Velho; no mapa real os papéis deles foram para Gaspar Bigorna, Dona Rosalva, o Mercador da Praça, Pipo e o Capitão Nuvem. Eles continuam na Vila.

## Lore (conflitos resolvidos a favor da Bolorina)

- A forja de Porto Velho é a Ferraria do Porto, de Gaspar Bigorna. Os textos que falavam da Helena em Porto Velho (`servicos.gd`, `equipamento.gd`, `data/itens.json`, `data/lojas/forja.json`) agora falam do Gaspar.
- A entrega de cartas do Claude (Nina para a Capitã Marina) virou Pipo para o Capitão Nuvem (`Servicos.ao_falar(e, "capitao")`).
- O Gaspar do Claude (minerador da mina velha) virou o Seu Tião Lamparina, para não colidir com o Gaspar Bigorna.
- PROPOSTA: as falas de balcão escritas para Gaspar, Rosalva, Brida, Capitão Nuvem, Mercador da Praça, Seu Tião e Pipo são novas (as falas longas de cada um continuam nos `.dialogue` da Bolorina).
- PROPOSTA: o cartógrafo Tobias tem o mesmo nome do Tobias do Ermo (lobisomem) e do Tobias guia da Vila. Falta decidir se são a mesma pessoa ou trocar o nome.
- PROPOSTA: Fagulha é filhote do Ambarion.

## Arte que falta

Retratos de `lurdes`, `otavio`, `cinira`, `tobias`, `severino`, `frei_ze`, `tempora`, `kiko` e `fagulha` em `art/ui/retratos/`. Sem eles o balcão usa o quadro de frente do próprio sprite, ampliado. O Fagulha ainda usa um ator provisório, sem sprite de dragão filhote.
