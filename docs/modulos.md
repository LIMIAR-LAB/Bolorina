# Catálogo de módulos — Vila V7 (fidelity_village.tscn)

Peças modulares criadas para o modo `"v7"` da cena de fidelidade. Foram pensadas para, no futuro, o jogador colocar peças e coletar recursos no estilo Stardew. Por enquanto só a cena `fidelity_village.tscn` usa essas peças; a vila V6 original (`main.tscn` / `reference_village.tscn`) não foi alterada.

## Regras de grade
- **Grade:** 1 m (`KitModular.GRID = 1.0`). A origem de cada peça fica no **centro da célula**, e a posição é arredondada para o metro inteiro.
- **Rotação:** apenas em passos de 90° (campo `rot` = 0/1/2/3).
- **Pegada:** `Vector2i(largura_x, profundidade_z)` em células. Peças com pegada par ficam centradas no canto entre células.
- **Altura:** a peça é apoiada no terreno com `VilaModular.altura(x,z)`.
- **Metadados em cada nó:** `modulo` (id), `pegada`, `categoria`, `recurso` (só nas peças coletáveis: `tipo`, `quantidade`, `golpes`). Canteiros também têm `cultura` e `estagio`.
- **Fábrica:** `KitModular.make(id, dados) -> Node3D`. Ela chama `_p_<id>`; um id desconhecido gera um aviso e um nó vazio.

## Peças
| id | pegada | categoria | recurso | observações |
|---|---|---|---|---|
| casa | 6×5 | construcao | — | casa enxaimel com estandarte de árvore, trepadeiras, vasos e chaminé com fumaça |
| poco | 2×2 | construcao | — | poço de pedra com telhadinho |
| ponte | 3×7 | construcao | — | ponte arqueada com colisão trimesh |
| deck | 3×3 | construcao | — | plataforma de tábuas (fase 5) |
| cerca | 1×1 | cerca | — | segmento de 1 m com colisão |
| poste_lampiao | 1×1 | luz | — | OmniLight no grupo `fid_fogo` (cintila) |
| pilar_braseiro | 1×1 | luz | — | fogo, faíscas (CPUParticles) e luz |
| estandarte | 1×1 | decoracao | — | shader `fid_estandarte` (emblema de árvore) |
| carroca_abobora | 3×2 | decoracao | — | carroça com abóboras |
| barril | 1×1 | decoracao | — | fase 5 |
| caixote | 1×1 | decoracao | — | fase 5 |
| arbusto_escuro | 2×2 | decoracao | — | moldura das bordas |
| banco | 2×1 | mobilia | — | fase 5 |
| mesa | 2×2 | mobilia | — | fase 5 |
| corvo | 1×1 | ambiente | — | pousado sobre cercas e telhados |
| menir_runa | 2×2 | marco | — | menir com runa |
| pilar_pedra | 1×1 | marco | — | |
| ruina_arco | 6×2 | ruina | — | 2 pilares afunilados com 3 blocos; o parâmetro `fundo` (padrão 30) os desce até o abismo |
| ruina_pilar | 1×1 | ruina | — | |
| canteiro | 1×1 | cultivo | — | `cultura`: `abobora` (estágios 0–3) ou `couve` |
| arvore_outono | 2×2 | recurso | madeira ×3, 3 golpes | criada pela fábrica do ChoppableTree |
| arvore_escura | 2×2 | recurso | madeira ×4, 4 golpes | |
| arvore_seca | 1×1 | recurso | galhos ×2, 1 golpe | |
| rocha | 1×1 | recurso | pedra ×2, 2 golpes | |
| arbusto_flor | 1×1 | recurso | fibra ×1, 1 golpe | |
| cogumelos | 1×1 | recurso | cogumelo ×2, 0 golpes (coleta direta) | fase 5 |

Contagem atual no layout (136 peças): cerca 61, canteiro 12, rocha 9, poste_lampiao 7, barril 7, arbusto_flor 5, arbusto_escuro 4, ruina_arco 3, arvore_escura 3, cogumelos 3, casa 2, estandarte 2, pilar_pedra 2, ruina_pilar 2, arvore_outono 2, arvore_seca 2, banco 2, e 1 de cada: poco, menir_runa, carroca_abobora, ponte, pilar_braseiro, caixote, mesa, deck.

**Atenção:** os metadados de recurso já estão nas peças, mas só a árvore cortável principal (`cut_tree`) tem a mecânica de golpes ligada. As demais peças marcadas como recurso ainda não são coletáveis no jogo; os metadados preparam essa etapa.

## Abóbora — estágios do canteiro
0 = terra lavrada vazia · 1 = broto · 2 = planta com folhas · 3 = abóbora madura.

## Tipos de piso (terreno)
Gerado por `tools/fidelidade_layout.py`. Os pesos vão nas cores dos vértices, e o shader `fid_terreno` mistura as texturas:
- `g` grama · `c` caminho de terra batida · `t` terra lavrada (sulcos) · `h` horta · `b` borda do platô / encosta rochosa · `r` rio.
- Canais de COLOR: r = caminho, g = terra, b = rocha, a = sulcos. Encostas íngremes viram rocha automaticamente.

## Fase por peça
`VilaModular.FASE_PECA`: barril, caixote, banco, mesa, cogumelos e deck são da fase 5; ruínas, árvores e rochas da fase 3; o restante da fase 2. O campo `fase` do config (`docs/fidelidade-camera.json`) liga as fases de forma cumulativa.

## Como adicionar uma peça
1. Adicione o id em `CATALOGO` (`scripts/modular/kit_modular.gd`) com a pegada e a categoria (e `recurso`, se for coletável).
2. Implemente `func _p_<id>(node: Node3D, data: Dictionary)` usando `mats` / `folhagem` / `foliage_mesh`.
3. (Opcional) defina a fase em `FASE_PECA` (`vila_modular.gd`).
4. Coloque a peça em `tools/fidelidade_layout.py`: as posições são escritas em pixels da referência e convertidas para o mundo por `fidelidade_mapa.py`, com DELTA (-4.67, 0, -7.0).
5. Rode `python tools/fidelidade_layout.py` (use `--preview` para ver a sobreposição) para regenerar `scripts/modular/vila_layout.json`.
6. Valide com `tests/fidelity_mechanics.gd`: ele confere o encaixe na grade e os metadados.
