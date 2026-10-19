# Arte do protótipo de combate (art/combate/)

Assets do próprio Thiago no Gamelab Studio (conta tsmartinelli88, projeto 30457 "MCP Creations"). Foram baixados antes, só por leitura, para `/workspace/ilha/gamelab/` na box (catálogo em `catalogo.md`). Todo o processamento foi local: **nenhuma geração nova e nenhum crédito gasto**.

| Arquivo | Fonte (id Gamelab) | Processamento |
|---|---|---|
| `orc/orc_run.png` | 67660 Orc motion v3 run (vídeo 960², 12 qps) | quadros 9–19 (um ciclo) |
| `orc/orc_idle.png`, `orc_windup.png`, `orc_strike.png`, `orc_recover.png` | 67661 Orc motion v3 axe_combo | ocioso 0–3; preparo (machado acima da cabeça) 22–30; golpe 31–34; recuperação 35–44 |
| `orc/orc_hurt.png`, `orc_death.png` | 67663 Orc motion v3 hurt_death | dano 1–8; morte 16–34 |
| `props/prop_caixote_*.png` | 65740 room2_crate (inteiro + quebrado) | chroma magenta, metade esquerda/direita, vizinho mais próximo (escala 26/351) |
| `props/prop_urna_*.png` | 65741 room2_pottery | idem (largura 20 px) |
| `props/prop_rocha_inteiro.png` | 65742 room2_rock | idem (largura 40 px); não quebra, serve de cobertura |
| `vfx/fx_corte_crescente.png` | 64195 Andarilho chibi base, quadro 12 da folha | máscara de vermelho/branco, maior componente conectado, 128 px |

Orc: o fundo branco foi removido por preenchimento a partir das bordas (`ferramentas/orc_recorte.py`), com recorte da área útil 640² sem as tarjas pretas. Depois veio a redução para 0,11× com alpha pré-multiplicado, alpha binário, paleta de 48 cores comum a todas as animações e contorno escuro de 1 px (`ferramentas/orc_reduzir.py`). Célula de 72×72 px, pés em (36, 67), olhando para leste (espelhado para oeste no jogo). Os scripts rodam na box (Python + Pillow + SciPy) e esperam os vídeos em `/workspace/ilha/gamelab/30457/`.

O 64205 (aura do Tobin) não foi usado: o anel fica atrás de um relógio/ampulheta grudado no personagem. A aura do especial já vem na própria animação do Vale, e o anel de impacto no chão é procedural (shader).
