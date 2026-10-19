# Vale V6 — animações de combate (Gamelab, teste)

Gerado em 19/10/2026 com Gamelabs Studio (MCP), projeto Gamelab 32737 "Ilha das Cinzas - Vale combate".
Referência: rotações PixelLab de `original_vale_v6` (sul-leste, leste, nordeste), copiadas sem alteração.
Nenhum arquivo existente do projeto foi modificado. Nada aqui está ligado a cenas ainda.

## Conteúdo
- 4 movimentos × 6 direções = 24 animações, 49 quadros cada a 12 qps (≈4 s, em loop: começa e termina na pose de guarda).
  - `slash_combo/` combo de 3 golpes de espada com rastro branco
  - `dash/` esquiva rápida com poeira (o personagem SE DESLOCA dentro da célula; mover o corpo no jogo e/ou usar só o trecho do avanço)
  - `hit/` golpe recebido, 2 vezes por ciclo
  - `special/` carga com aura + giro com anel de fogo
- Direções geradas: south-east, east, north-east. Espelhadas por código (espada troca de mão): south-west, west, north-west. Faltam north e south (usar a diagonal mais próxima).
- `<mov>/<direção>/NNN.png` quadros soltos; `<mov>/<mov>_<direção>_sheet.png` atlas 8 colunas.
- Célula 112×112 px. O Vale na pose de guarda tem ~44–46 px de altura (escala dos sprites de 48 px). Âncora dos pés por animação em `manifest.json` (`anchor_feet_px`).
- `contato_*.png` e `vitrine_combate_vale.png`: pranchas para revisão.
- `fonte/` (com `.gdignore`): imagens base em fundo magenta, vídeos MP4 originais 960×960 e `gamelab_jobs.json` (ids, prompts, créditos). `hit_ne_v1_rejeitado.mp4` foi descartado (o personagem se vira para a câmera).

## Processamento (local, sem custo)
Quadros extraídos do MP4 a 12 qps com ffmpeg; magenta e sombra arroxeada removidos por chroma; despill no brilho; filtro de mediana; redução por vizinho mais próximo para escala 0,1103; paleta compartilhada de 48 cores por animação. Script: `/workspace/ilha/gamelab-vale/tools/process.py` (box do agente).

## Limitações conhecidas
- Pequena oscilação de cor/contorno entre quadros (vem do vídeo); a aura do especial ficou salmão em vez de laranja puro por causa do fundo magenta.
- Os ciclos têm "tempo morto" em guarda no início/fim: para o jogo, cortar só o trecho ativo (ex.: combo ≈ quadros 8–40).
- Arte gerada por IA a partir de sprite original do projeto; uso comercial permitido pelos termos do Gamelabs Studio (sem atribuição obrigatória).
