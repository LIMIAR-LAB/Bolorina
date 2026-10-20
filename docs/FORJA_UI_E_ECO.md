# Forja UI + Protótipo do Eco Temporal

> **PROPOSTA** — textos, itens extras (facao_fazenda, facao_fazenda_eco, lasca_de_eco) e a "Têmpera em cinza" são proposta, não canon.

## Forja UI
- Cena: `scenes/ui/forja_ui.tscn` (Control, rodar sozinha abre uma demo).
- Scripts: `scripts/ui/forja_ui.gd` (visual/entrada), `scripts/ui/forja_modelo.gd` (lógica testável).
- Dados: `data/forja/*.json` via `scripts/forja/forja.gd`; extras em `data/forja/forja_ui.json`. Ícones: `art/ui/icones_forja/` (32x32; os 16x16 do catálogo ficam em `art/ui/icones/`).
- Filtros: Dá para forjar / Falta material / Travado / Tudo. Comparação com o equipado (verde melhor, vermelho pior). Origem de cada material faltante (área + andares, ou "Fundir aqui").
- Gasto só via `gerenciador.pode_gastar()` / `gastar_excedente()` — a reserva de 3 minério de cobre da missão nunca é usada.
- Missão: entrada "Têmpera em cinza" na etapa `reforco_arma` (emite `forja_reforco_feito`), cartões Eco rápido / Eco pesado na etapa `escolher_eco` (marca `atrasada_eco_rapido|pesado`; fiado se faltar excedente).

### Integração
```gdscript
var ui = preload("res://scenes/ui/forja_ui.tscn").instantiate()
add_child(ui)
ui.abrir(GerenciadorMissoes)   # (gerenciador, forja=null, niveis={})
ui.testar_na_arena.connect(func(item_id, variacao): get_tree().change_scene_to_file("res://scenes/prototipos/eco/arena_eco.tscn"))
ui.fechada.connect(...)        # também: forjado, equipado, eco_escolhido
```
Controles: setas/D-pad navegam, Enter/A confirma, Q/E ou LB/RB trocam filtro, X equipa, T/Y testa na arena, Esc/B volta/fecha.

## Eco Temporal (protótipo)
- Cena: `scenes/prototipos/eco/arena_eco.tscn`. Scripts em `scripts/prototipos/eco/` (eco_temporal, alvo_treino, bate_estaca, arena_eco).
- Golpe pesado (3º do combo, ou H/LB) deixa um fantasma que repete o golpe no mesmo lugar.

| Variação | Atraso | Dano | Raio | Extra |
|---|---|---|---|---|
| eco_base | 0.6 s | 60% | 1.6 m | — |
| eco_rapido | 0.35 s | 45% | — | dash −0.1 s |
| eco_pesado | 0.9 s | 100% | 2.2 m | quebra postura |

- Teclas 1/2/3 (ou D-pad ←/↑/→) trocam variação; R reinicia; Esc sai.
- Bate-Estaca: 3 travas que só abrem com golpe de eco → Catraca-Mestra.
- Integração: `arena.gerenciador = GerenciadorMissoes` antes de entrar na árvore; a arena chama `notificar("eco_acertou", id)`, `notificar("trava_acertada_eco", "bate_estaca")`, `coletar_item("catraca_mestra")`. Sinais: eco_marcado, eco_disparou, eco_acertou, trava_aberta, bate_estaca_aberto, variacao_mudou. Reaproveita `jogador_combate.gd` (sinal `golpe`) sem alteração.

## Testes
`godot --headless --fixed-fps 60 -s res://tests/forja_ui_testes.gd` (85) e `-s res://tests/eco_testes.gd` (68).
Capturas: `tests/forja_ui_captura.gd` (FORJA_CAPTURA=dir) · Vídeo: `tests/eco_filme.gd` com `--write-movie`.
