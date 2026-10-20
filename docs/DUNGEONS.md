# Masmorras procedurais (protótipo)

Entrada: portão entre os pilares das **Ruínas do Norte** da vila (gatilho em (−6, −20)) ou **F7**.
Cena: `dungeon_teste.tscn` → `scripts/masmorra/masmorra_teste.gd`. Gerador puro:
`scripts/masmorra/masmorra_gerador.gd` (sem nós, testável).

## Semente
`semente` = env `MASMORRA_SEMENTE` ou `estado.dia * 13 + 5` (muda a cada dia de jogo).
`Gerador.gerar(semente, andar)` usa `RandomNumberGenerator.seed = semente*7919 + andar*104729`:
mesma semente + andar ⇒ mesma masmorra. Em jogo, **R** gera outra semente (teste).

## Layout (grafo de salas)
1. Grade lógica de células `Vector2i`; começa em (0,0) = sala **inicio**.
2. Passeio aleatório com ramificação: a cada passo anda 1 célula (30% das vezes recomeça de uma
   sala existente qualquer); célula nova vira sala **combate** + aresta. Meta: `min(6 + andar*2, 14)` salas.
3. Laços ocasionais: ao pisar numa sala já existente sem aresta, 15% de chance de criar a aresta.
4. **saida** = sala mais distante do início por BFS (escada para o andar seguinte).
5. **tesouro** = uma folha (grau 1) que não seja início/saída.
6. **descanso** a partir do andar 2: uma sala combate a meio caminho (BFS) da saída; sem inimigos, 1 prop.
7. `conexo(m)` verifica por BFS que todas as salas são alcançáveis.

Dados: `{salas{celula: {celula, tipo, inimigos, props, portas}}, arestas, inicio, saida, semente, andar}`.

## Construção 3D
- Sala 14×10 m em passo 18×14 m; paredes com vão na porta de cada aresta; corredores ligam vãos.
- Piso colorido por tipo (inicio / combate / tesouro / descanso / saída).
- **Orcs**: `1 + andar + rand(0..2)` por sala combate e na saída; sprite `art/combate/orc/orc_idle.png` animado.
  *Ainda sem IA/combate* — próximo passo: reaproveitar `inimigo` + `jogador_combate` da arena.
- **Quebráveis**: 3–6 props por sala (caixote / urna / rocha) de `art/combate/props`. *Ainda não quebram.*

## Andares e volta
- Pisar na **escada** (sala saída) ⇒ `andar + 1`, nova masmorra maior.
- **Portal azul** na sala inicial ou **Esc** ⇒ `gerenciador.ir("vila", "da_masmorra")`
  (volta ao portão das ruínas, em (−6, −17,4), fora do gatilho).

## Testes
`tests/masmorra_testes.gd`: 160 masmorras (40 sementes × 4 andares) conexas, saída ≠ início,
tesouro, andares maiores, determinismo; cena monta salas/orcs/escada/portal; escada desce.
`MAS_CAP=1` → `docs/masmorra-teste.png`.

## Próximos passos
Combate com orcs reais, quebráveis com drop (minério para a ferreira Helena), chave/porta trancada,
salas pré-desenhadas misturadas ao gerador, minimapa.
