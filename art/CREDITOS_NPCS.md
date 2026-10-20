# Créditos — rostos e corpos dos moradores

> Nada aqui usou crédito pago (sem PixelLab, Meshy ou Gamelab). Nenhum modelo novo foi baixado para a entrega.

## Retratos — `art/ui/retratos/<id>.png` (41 arquivos)

| O quê | Origem | Licença / uso |
|---|---|---|
| 41 retratos 128×128 (grade de 64 px ampliada 2× com nearest, 32 cores) | Gerados pelo Grok Bot (GenerateImage), tendo como referência de estilo o sprite `original_mira_v6/rotations/south.png` do próprio jogo. Pós-processo: corte de 4%, nearest até 64 px, paleta de 32 cores sem dithering, ×2 | Arte original feita para o Ilha das Cinzas; não usa assets de terceiros |
| `lobisomem.png` refeito: eremita lobisomem mais assustador | idem | idem |

Na caixa de diálogo, `Registro.retrato(id)` lê o PNG, volta para a grade de 64 px e centraliza num quadro de 82 px preenchido com a cor do fundo do retrato. O slot tem 164 px, então a escala fica em exatamente 2×.

## Sprites de mundo — `art/npcs/<id>/` (35 moradores)

| O quê | Origem | Licença / uso |
|---|---|---|
| `frente_0/1.png` (+ `costas_0/1.png` dos 9 principais sem sprite) e `npc.json` | Folhas geradas pelo Grok Bot (GenerateImage) com fundo chroma (verde #00FF00; magenta para os orcs). As referências foram o sprite da Mira e o retrato do próprio morador. Pós-processo (`proc_sprites.py`, guardado no zip de fontes): recorte do chroma, despill, redução por área até a altura do personagem (densidade da Vale: 1,72 m / 48 px), paleta de 22 cores, alfa binário, contorno escuro de 1 px. O segundo quadro do idle desce o tronco 1 px (os fantasmas sobem 1 px) | Arte original para o jogo |

## Modelos 3D (já estavam no projeto, só passaram a ser o "visual" do registro)

| Morador | Modelo | Autor | Licença |
|---|---|---|---|
| `robo_lobisomem` (L-0B0) | `art/models/quaternius_scifi_essentials/Enemy_QuadShell.gltf` | Quaternius | CC0 1.0 |
| `drone_zelador` (Z-12) | `art/models/quaternius_scifi_essentials/Enemy_EyeDrone.gltf` | Quaternius | CC0 1.0 |
| `vagoneta_falante` | `art/models/kenney_train_kit/train-carriage-coal.glb` | Kenney | CC0 1.0 |

## Avaliados e descartados

- **Orcs 3D CC0:** testei o "Orc" (poly.pizza/m/5vO2YJsPEf) e o "Orc Enemy" (poly.pizza/m/Q3z8ZX4kUy), ambos da Quaternius (CC0 1.0, com Idle/Wave). São goblins caricatos de língua para fora: não combinam com os retratos (Grusha é uma chefe altiva) nem com o resto da vila em pixel. Por isso os orcs viraram sprites pixel. Nada disso entrou no projeto.
- **Dragão 3D CC0** (Quaternius Ultimate Monsters): descartado para o dragão ficar no mesmo estilo pixel dos outros. Ambarion é um sprite de 96 px (cerca de 3,4 m), com frente e costas.
- **`art/characters/original_cat_v6`** (gato PixelLab que já existia): não usei, porque o retrato do Gato da Praça é um gato gordo e cinza de coroa. Fiz um sprite novo que combina com o retrato.
