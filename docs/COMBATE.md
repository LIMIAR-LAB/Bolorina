# Protótipo de combate (estilo Hades 2) — `combat_arena.tscn`

Cena **separada** e isolada: não herda nem altera `main.tscn` / `reference_village.tscn` / a vila V6, e **não lê nem grava o save** (`user://island_v1.json`). Abrir: `Jogar-combate.ps1`, ou `godot --path . res://combat_arena.tscn`.

## Controles
| Ação | Teclado/mouse | Controle |
|---|---|---|
| Mover (8 direções, relativo à câmera) | WASD / setas | analógico esquerdo |
| Atacar (combo de 3, mira no cursor) | LMB / J | X |
| Dash (i-frames, cancela ataques) | Espaço / Shift | A / RB |
| Especial (anel de fogo em área, recarga de 4 s) | RMB / K | Y |
| Forma Adamantium (barra cheia) | G | LB / D-pad ↑ |
| **Raio de Adamantium** (transformado; segurar = carregar, soltar = disparar) | segurar Q ou RMB / K | segurar RT |
| Reiniciar sala | R | — |
| Piloto automático / desempenho / caixas de golpe | F2 / F3 / F4 | — |

## Sensação (valores em `scripts/combate/jogador_combate.gd`)
- **Combo:** 3 golpes (10/12/24 de dano). Impacto em 0,07/0,08/0,13 s dentro de cada golpe. O próximo golpe guardado no buffer começa no ponto de cancelamento (0,15/0,17 s). A janela para continuar o combo é de 0,30 s depois do fim de um golpe. O 3º golpe é pesado: empurrão maior e quebra a postura do inimigo.
- **Dash:** 0,19 s, ~4,4 m, i-frames durante o dash + 0,05 s, recarga de 0,32 s. Atravessa inimigos e cancela qualquer ataque. Um ataque até 0,2 s depois do dash vira **golpe de investida** (18 de dano).
- **Especial:** área com raio de 3,4 m, 30 de dano, empurrão forte, recarga de 4 s.
- **Retorno visual:** hitstop (time_scale 0,05 por 50–90 ms), tremor de tela, números de dano, flash branco no inimigo, faíscas, onda de corte (VFX Gamelab 64195), anel de fogo procedural, rastro fantasma do dash e vinheta vermelha ao levar dano.
- **Inimigo Orc** (sprites Gamelab 67660/67661/67663): persegue e, a ~2,2 m, entra em **preparo** de 0,8 s (anel vermelho no chão enchendo + brilho vermelho). Depois vem o **golpe** em área à frente (14 de dano) e a **recuperação** de 0,8 s, que é a janela de punição. A postura no preparo só quebra com golpe pesado ou 22 de dano acumulado. O Orc **bruto** tem 110 de vida, causa 20 de dano e é maior.
- **Sala:** onda 1 com 2 orcs e onda 2 com 3 (inclui um bruto). Depois aparecem **SALA LIMPA**, a bênção (+20% de dano), a porta que se abre e a próxima sala (placeholder: reinicia com +1 orc por onda).
- **Quebráveis** (sprites Gamelab 65740/65741/65742): caixote e urna quebram com um golpe; a urna deixa um orbe de cura de +10. A rocha é cobertura indestrutível.

## Forma Adamantium e Raio de Adamantium (19/10, 07h)
- **Barra ADAMANTIUM** (HUD, abaixo de ESPECIAL): começa cheia. Cada acerto rende +7 (golpe pesado rende +14). Com a barra cheia aparece "G: TRANSFORMAR". Transformado, a barra vira o tempo restante: **20 s**. Ao acabar, ela zera e volta a encher com acertos.
- **Transformação em batalha** (G/LB): leva 0,5 s, com i-frames durante ela e mais 0,3 s. Tem câmera lenta (time_scale 0,3 por 0,45 s reais), clarão de tela, explosão de partículas ciano, anel de aura expandindo, luz e uma onda de choque (raio de 2,8 m, 8 de dano, empurrão forte). Pode ser usada parado, no meio do combo ou ao levar dano (como fuga).
- **Visual da forma:** sprites PixelLab da armadura (`experimental_adamantium_v99`: idle e caminhada em 8 direções), asas de pixel art batendo atrás do corpo (ou na frente, quando ele está de costas), aura aditiva (partículas + anel). Os golpes Gamelab não têm versão blindada, então recebem um tom de adamantium mais a aura. A escala da armadura é normalizada para a mesma altura do Vale (idle 44 px / caminhada 41 px → 1,61 m).
- **Raio de Adamantium** (implementação original):
  - *Carga:* segurar Q, RMB ou RT. O orbe de energia cresce entre as mãos, partículas convergem, uma luz aumenta, a tela treme cada vez mais e o controle vibra. A carga fica cheia em 1 s. Carregando, a movimentação cai para 40%. Dash cancela a carga.
  - *Disparo:* ao soltar (mínimo de 0,25 s de carga; dispara sozinho depois de 3 s), sai um feixe de até 15 m que para na parede da arena. Tem 3 camadas aditivas: núcleo HDR branco-ciano (bloom pelo glow), camada ciano e halo azul. Há clarões na boca e na ponta e faíscas ao longo do feixe.
  - *Duração e dano:* dura 1,0 s (carga mínima) a 1,45 s (carga cheia), com **ticks a cada 0,1 s** de 5 a 11 de dano. Atravessa todos os inimigos no feixe, empurra ao longo dele, atordoa e quebra caixotes e urnas.
  - *Durante o disparo:* tremor constante, movimentação a 22% e superarmadura (o dano não interrompe). O feixe gira seguindo a mira, a no máximo 75°/s.
  - *Recarga:* **7 s**, mostrada na barra RAIO.
- Testes: `tests/combate_adamantium_testes.gd` **36/36** (barra, transformação com i-frames e câmera lenta, sprites/asas/aura, escala, carga com orbe/tremor/lentidão, feixe que atravessa 3 inimigos com ticks, inimigo fora da linha intacto, empurrão, quebra de prop, duração, recarga, giro com a mira, parede, superarmadura, fim da forma, legenda, save). Captura: `tests/combate_raio_captura.gd` → `docs/combate-raio.png` e `docs/combate-forma.png`. O piloto automático (F2) também transforma e usa o raio.

## Animações do Vale
As folhas de `art/characters/vale_combate_gamelab/` são lidas em tempo de execução (`Image.load_from_file`), sem criar `.import` na pasta. Os quadros ativos por direção foram medidos nas folhas (`art/combate/vale_combate_dados.json`, gerado por `art/combate/ferramentas/combate_medir.py`). O dash compensa o deslocamento embutido no sprite. Norte e sul usam a diagonal mais próxima conforme o lado. Andar e ficar parado usam os sprites originais do Vale V6 em 8 direções.

**Escala (corrigida em 19/10, 07h):** os quadros Gamelab (célula de 112 px) mostram o corpo em pé com 44–46 px, a mesma densidade do `run/` do V6 (44–45 px). O `idle` (`rotations/`) desenha o mesmo corpo com 48 px. Antes, o idle usava o mesmo `pixel_size` da corrida e os golpes eram reduzidos por 42/45, por isso o Vale "encolhia" ao atacar: idle 1,72 m → golpe 1,47 m (−14%). Agora `PX_IDLE = H/48`, `PX_BASE = PX_COMBATE = H/45` com H = 1,61 m. Idle → golpe tem diferença máxima de 2,3%. Corrida → golpe chega a 6,8%, que é o pulo da passada. As duas medidas são feitas por pixels nos PNGs pelo teste.

## Testes
`tests/combate_testes.gd`: **54/54** em 19/10/2026 07h (52 + 2 de escala). `tests/combate_adamantium_testes.gd`: **36/36**. Cobre movimento em 8 direções, tempos do combo com buffer e janela, dash (i-frames, distância, recarga, cancelamento, investida), dano, empurrão, flash, números, hitstop/tremor, telegrafo e golpe do orc, postura, morte, especial (área + recarga), quebráveis + cura, sala → recompensa → porta, derrota/reinício, save intocado, cenas originais inalteradas (sha256) e pasta Gamelab sem `.import`, além da escala idle/corrida/golpe medida nos PNGs.

## Desempenho (`tests/combate_perf_sondagem.gd`, 1600x900, vsync ligado)
| Configuração | GPU ms | draw calls |
|---|---|---|
| base | 8,4 | 354 |
| sem sombra | 7,8 | 142 |
| sem glow | 6,6 | 354 |
| sem neblina (fog) | 7,5 | 354 |
| sem MSAA 2x | 8,0 | 354 |
| sem as 8 luzes de fogo | 8,0 | 354 |

Roda a 58–60 fps (limite do vsync). Nenhum recurso isolado passa de ~1,7 ms de GPU, então nada foi cortado. A medida tem ruído de cerca de ±1 ms entre execuções: "sem planos de névoa" e "sem ajuste de cor" saíram mais lentos que a base, o que é ruído e não custo. Clipe de demonstração: `--write-movie` com `tests/combate_filme.gd` (piloto automático).
