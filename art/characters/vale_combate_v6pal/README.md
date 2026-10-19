# Vale V6 — quadros de combate com a paleta da vila (19/10/2026)

Copia derivada de `../vale_combate_gamelab/` (que NAO foi alterada). Mesma estrutura de folhas
(`<mov>/<mov>_<direcao>_sheet.png`, celula 112x112, 8 colunas, 49 quadros), mesmas ancoras
(`art/combate/vale_combate_dados.json`).

Por que: a Vale do combate (golpes Gamelab) parecia um pouco "outra" frente a Vale V6 da vila:
paleta mais escura/fria e ~270 cores contra 44 da V6. Idle/andar/correr do combate ja usam os
proprios PNGs V6 (`original_vale_v6`), iguais aos da vila.

Como (local, sem custo, `tools/vale_paleta_v6.py`):
1. paleta V6 = cores opacas de `rotations/` + `run/` (82 cores com >=3 px);
2. pixels do "corpo" = cor a menos de dE 20 (CIELAB) de alguma cor V6; efeitos (rastro branco,
   fogo, poeira distante da paleta) ficam como estavam;
3. transferencia global de media/desvio Lab do corpo Gamelab -> V6 e depois cor V6 mais proxima.

Resultado (corpo, golpes+impacto): cores 270 -> 42 (V6: 44); Lab medio L/a/b 29,6/9,3/12,3 -> 27,6/10,8/14,4
(V6: 28,4/12,9/17,9). Escala ja casada antes (golpe/idle 1,023; tests/combate_testes.gd).
Desligar: `paleta_v6 = false` em jogador_combate.gd (volta para vale_combate_gamelab).
