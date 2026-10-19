# Fidelidade visual - Fase 1 (medicao base)

Data: 2026-10-19. Fase 1 apenas mede e prepara; nenhuma mudanca visual na vila foi feita.

## 1. Alvo canonico
- `docs/referencia-usuario.png` (1600x900), copiada da imagem enviada pelo usuario.
- Verificacao: e **byte a byte identica** a `docs/alvo-vilarejo.png` (mesmo SHA-256 163c2d329f2f..., diferenca media de pixels 0). O alvo antigo ja era a imagem do usuario.
- Notas de estilo: `docs/estilo-video-referencia.md`.

## 2. Cena de fidelidade (separada)
- `fidelity_village.tscn` + `scripts/fidelity_village.gd` (herda `reference_village.gd`; `reference_village.tscn` e `main.tscn` nao foram alterados).
- Camera propria travada no enquadramento da referencia (config em `docs/fidelidade-camera.json`: hora, escala, deslocamento).
- Sobreposicao semitransparente da referencia: **O** liga/desliga, **- / +** opacidade +-10%, **P** pisca. Nao grava save.
- Teste: `tests/fidelity_capture.gd` -> 6/6 (camera ativa, travada com o personagem andando, 1600x900, opacidade, O oculta, sem save).

## 3. Ajuste de camera
- 7 marcos escolhidos a mao (poco, menir, lampiao, campo, janelas) -> ajuste de similaridade (escala+translacao).
- Resultado: escala 0,8864 (zoom out ~11%), deslocamento (37,5; -25,9) px.
- **Residuo medio 53 px, max 67 px**: o enquadramento nao resolve; os objetos do lado direito (menir, poste da praca, casa direita, campo) estao 55-120 px fora do lugar em relacao a casa esquerda/poco. E um problema de **layout**, nao de camera.
- Hora calibrada por varredura (15,0 a 19,2): L* medio da referencia = 30,6; hora 16,5 escolhida (16,3 -> 32,5; 16,8 -> 28,1). Em 18,6 (antiga) cor/luz media era 0,375 vs 0,61 em 16,8. Mesmo na melhor hora a captura fica com a* negativo (verde) e a referencia a* +4 (quente): falta dominante laranja.

## 4. Metodo de pontuacao (`tools/fidelidade_pontuacao.py`)
| Componente | Peso | Como |
|---|---|---|
| Composicao | 40% | checklist de 60 elementos (`docs/fidelidade-checklist.json`), presente=1 / parcial=0,5 / ausente=0, pesos 1-3 |
| Cor/luz | 30% | grade 8x6 em 800x450: 50% delta-E CIE76 da media Lab (0 em dE>=40) + 50% intersecao de histograma L* (16 bins) |
| Detalhe | 20% | densidade de bordas Sobel (limiar 0,10) por regiao, razao min/max |
| Avaliacao do usuario | 10% | pendente |

## 5. Pontuacao inicial (V6 alinhada, hora 16,5)
| Componente | Nota |
|---|---|
| Composicao (40%) | 46,1 / 100 (14 presentes, 24 parciais, 22 ausentes) |
| Cor/luz (30%) | 61,2 / 100 |
| Detalhe (20%) | 64,3 / 100 |
| **Total sem avaliacao** (renormalizado em 90%) | **55,2** |
| **Total com avaliacao neutra 0,5** | **54,6** |

Arquivos: `docs/fidelidade-pontuacao.json`, `docs/fidelidade-mapa-calor.png`, `docs/fidelidade-lado-a-lado.png`, `docs/fidelidade-v6-alinhado.png`, `docs/fidelidade-sobreposicao-50.png`.

## 6. Maiores lacunas (ganho esperado em pontos do total)
Checklist (cada item ausente de peso 3 vale ~1,0 pt; peso 2 ~0,7; parcial peso 3 ~0,5):
1. Praca central pavimentada entre as casas (1,04)
2. Ruinas com arcos de pedra a direita (1,04)
3. Penhascos com neblina ao fundo (1,04)
4. Densidade alta de props pequenos (1,04)
5. Moldura escura de folhagem/rocha nas bordas, estandartes vermelhos, aboboras, cachoeira, floresta na borda superior, neblina, textura de chao, remover encosta visivel (0,7 cada)
6. Parciais peso 3: vila preenchendo a tela, casa direita no lugar, rio contornando a vila, caminhos de pedra largos, luz de crepusculo laranja, pixel art no terreno (0,52 cada)

Regioes (mapa de calor; linha,coluna de 0): base esquerda (5,0) 0,8; centro-direita (3,5)/(3,6) - menir/praca deslocados - 0,7 cada; cantos superiores (0,0),(0,7),(1,7) - ceu cinza vazio vs cachoeira/ruinas - 0,6-0,7; (2,4) praca 0,6.

Layout: residuo de 53 px dos marcos -> reposicionar o lado direito afeta checklist e varias regioes ao mesmo tempo.

## 7. Plano das proximas fases (nao iniciadas)
- **Fase 2 - layout e enquadramento** (maior ganho estimado, ~6-9 pts): numa copia da vila (cena de fidelidade), mover casa direita, praca/poste, menir e campo para os marcos da referencia; rio em curva contornando a vila com ponte central; cobrir encosta e ceu vazio com plato que preencha a tela; meta residuo < 15 px.
- **Fase 3 - fundo e bordas** (~5-7 pts): penhascos com neblina, ruinas com arcos a direita, cachoeira superior esquerda, floresta densa e vinheta de folhagem escura.
- **Fase 4 - luz e paleta** (~3-5 pts): grade de cor quente de crepusculo (a*>0), sombras frias, halos de lanterna, neblina volumetrica/fog de altura, fumaca de chamine.
- **Fase 5 - densidade de props e textura** (~5-8 pts): pavimento de pedra largo, aboboras, carroca, barris, estandartes com arvore, corvos, gato, flores vermelhas, textura pixelada no chao (seguindo `estilo-video-referencia.md`).
- **Fase 6 - avaliacao do usuario** e iteracao guiada pelo mapa de calor.
Estimativas sao hipoteses, nao medidas. Chegar a 95% exige quase todos os itens presentes e cor/detalhe > 90 por regiao; com arte 3D + sprites pode haver teto abaixo disso.

## 8. Limitacoes
- Marcos de camera e checklist avaliados manualmente pelo agente (subjetivo); o checklist deve ser revisado pelo usuario.
- Metricas de cor/detalhe sao globais por regiao, nao reconhecem objetos; podem premiar ruido.
- A nota nao e porcentagem de "fidelidade percebida"; serve para comparar versoes com o mesmo metodo.