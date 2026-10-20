# Minas da Cinza — dungeon sob Porto Velho (PROPOSTA)

A mina antiga embaixo de Porto Velho, de acordo com `docs/FORJA_E_ITENS.md`: a entrada fica na cisterna atrás da Ferraria do Porto (o Elevador do Tião). **Andares 1–5 têm cobre, os andares 6–12 têm ferro** e há carvão em todos. No andar 20 fica um teaser do **Coração Soterrado** (adamantium, abismo de brasa e a Porta Selada, que só abre com a Bigorna Cronal).

## Abrir
- Andares representativos: `scenes/minas_da_cinza/minas_da_cinza_andar_01.tscn` (entrada + elevador), `_04` (galerias de cobre), `_09` (cavernas de ferro), `_20` (Coração Soterrado).
- Cena genérica: `scenes/minas_da_cinza/minas_da_cinza.tscn`, com a propriedade `andar` (1–12 ou 20) ou a variável `MINAS_ANDAR=7`.
- **Não está ligada ao `main.tscn`.** Abra direto (F6). WASD move a jogadora provisória, **E** usa escada ou elevador (troca de andar na própria cena), Tab mostra a visão geral e a roda do mouse dá zoom.
- `VG_CAPTURA=/pasta` gera as capturas do andar e sai. `MINAS_SEM_NAV=1` pula o bake de navegação.

## Como os andares são feitos
`scripts/minas_da_cinza/gerador_minas.gd` usa uma semente fixa por andar (`1500 + andar*7919`). O mesmo andar sai sempre igual.
- **galerias** (1–5): salas escavadas ligadas por túneis, com bordas rachadas.
- **cavernas** (6–12): autômato celular. Só a maior região conectada fica, ligada à galeria de entrada.
- **coração** (20): salão redondo com um abismo de brasa no meio.

A rocha fica "em corte" para a câmera isométrica: o que tapa o chão visto de (+x,+z) é baixo (0,8 m) e o resto é alto (3,4 m). O trilho da vagoneta segue o caminho mais curto da entrada até o poço da escada.

## Marcadores
| Grupo / nome | O que é |
|---|---|
| `spawn_jogador` | chegada no andar |
| `saida_porto_velho` (andar 1) · `escada_subir` | saída para cima (`destino` / `destino_andar`) |
| `escada_descer` (1–12) · `porta_selada` (20) | poço com escada para o andar seguinte (12 → 20) / teaser da Bigorna Cronal |
| grupo `minerio_no`, nome `minerio_<material>_<nn>` (ex.: `minerio_cobre_03`, `minerio_carvao_01`) | nó de minério. Metas: `material` (id de `data/forja/materiais.json`), `nome`, `tier`, `picareta_minima`, `quantidade`, `renasce_dias`, `andar`, `esgotado` |
| grupo `inimigo_spawn`, nome `inimigo_<tipo>_<nn>` | só marcadores. `orc` aponta para `scripts/combate/inimigo_orc.gd` (o inimigo existente, sem mudar o combate); `morcego` e `lodo_de_cinza` são provisórios (`provisorio = true`) |
| ids do registro MINAS | moradores, criados por `InteracaoNpcs.spawn_em_marcadores` |

**Gancho de dados:** os minérios de cada andar saem de `materiais.json`, filtrando por `onde` (`minas_da_cinza` / `coracao_soterrado`) e pela faixa `andares`. A cena expõe:
- `nos_de_minerio()`
- `minerar(no_id, picareta_id, inventario)`, que usa `Forja.pode_minerar` e soma em `inventario.itens`
- o sinal `minerio_minerado(no_id, material, quantidade)`

## Moradores (4)
| id | Nome | Andar | Diálogo |
|---|---|---|---|
| minerador_aposentado | Seu Tião Lamparina (mineiro aposentado do elevador) | 1 | `dialogos/minerador_aposentado.dialogue` |
| vagoneta_falante | Dona Vagoneta (vagoneta falante, modelo Kenney) | 1 e 9 | `dialogos/vagoneta_falante.dialogue` |
| fantasma_mineiro | Zeca Sem-Volta (fantasma translúcido, perdido desde a Queda) | 4 e 20 | `dialogos/fantasma_mineiro.dialogue` |
| mercador_minerio | Quinquilho do Talvez (negociante meio goblin, "pula" no tempo) | 9 | `dialogos/mercador_minerio.dialogue` |

Os dados ficam em `scripts/minas_da_cinza/npcs_minas.gd`. O registro `scripts/dialogos/npcs_registro.gd` ganhou o bloco `MINAS` (preload); `ids()` continua com os 12 originais.

## Testes (headless)
```
godot --headless --path . -s res://tests/minas_da_cinza_testes.gd
```
O teste verifica:
- o gerador: é determinístico e os andares 1–12 e 20 saem conectados;
- cada andar carrega, com navegação, saídas, tochas, cristais e trilho;
- os nós de minério batem com `materiais.json`;
- os marcadores de inimigos;
- os moradores e a primeira conversa de cada um;
- o alcance a pé da entrada até a escada, os nós de minério e os moradores;
- o gancho `minerar()`.

## Regenerar os assets
```
MINAS_DL=<zips extraídos> MINAS_REPO=. python3 tools/minas_da_cinza_curar_assets.py
```
Créditos: `art/CREDITOS_MINAS_DA_CINZA.md`.
