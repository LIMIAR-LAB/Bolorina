# Estação Depois-de-Ontem — ilha futurista (PROPOSTA)

Uma estação de pesquisa e comércio de tempo dos **Arquimagos do Relógio**, de uns 300 anos no futuro, que **caiu no presente** quando o Ozório quebrou o Coração do Tempo. As linhas do tempo se chocam: holograma de relógio que conta para trás, uma zona de anomalia "glitchada" com pedaços medievais (muro, carroça, árvore, totem orc) e detritos flutuando, e um metal do tempo, o **cronóstio** (tier 7 da forja).

## Abrir
- Cena: `res://scenes/ilha_futurista/ilha_futurista.tscn` (raiz `IlhaFuturista`, script `scripts/ilha_futurista/ilha_futurista.gd`, que estende `mapa_cc0.gd`).
- **Não está ligada ao `main.tscn`.** Abra direto no editor (F6) ou: `godot --path . scenes/ilha_futurista/ilha_futurista.tscn`.
- `FUT_SEM_NAV=1` pula o bake de navegação; `VG_CAPTURA=/pasta` gera as capturas e sai.

## Zonas
Doca de pouso (leste; ligada à Rota do Âmbar, dirigível) · Praça dos Segundos (comerciantes de tempo, relógio holográfico) · Forja Quântica (fabricadora, hangar ao norte) · Veio da Fenda (mina com crateras e nós de minério, oeste) · Laboratório de Anomalias + zona de anomalia (nordeste) · pods de moradia (sul) · robôs/drones, postes de energia com cabos, faixas de neon, holograma de lua, canal de refrigerante ciano com cachoeira.

## NPCs (7, marcadores + `Interacao.spawn_em_marcadores`)
| id | Nome | Onde | Diálogo |
|---|---|---|---|
| fabricadora | Mestra Ione Têmpera (tataraneta do Gaspar, do futuro) | Forja Quântica | `dialogos/fabricadora.dialogue` |
| mercador_temporal | Zé Antes-Depois | Praça dos Segundos | `dialogos/mercador_temporal.dialogue` |
| robo_lobisomem | L-0B0 (modelo QuadShell) | pods | `dialogos/robo_lobisomem.dialogue` |
| cientista_mira | Dra. Mira de Depois | Laboratório | `dialogos/cientista_mira.dialogue` |
| drone_zelador | Z-12 (modelo EyeDrone, flutua) | praça/forja | `dialogos/drone_zelador.dialogue` |
| fiscal_linhas | Agente Vera Bis | doca | `dialogos/fiscal_linhas.dialogue` |
| minerador_fenda | Bento Picareta-Quântica | Veio da Fenda | `dialogos/minerador_fenda.dialogue` |

Os dados ficam em `scripts/ilha_futurista/npcs_futuristas.gd`; o registro `scripts/dialogos/npcs_registro.gd` ganhou o bloco `FUTURISTAS` (preload) — `ids()` continua com os 12 originais.

## Nós de minério
`Marker3D` no grupo `veio_minerio`, com metas `material`, `nome`, `tier`, `picareta_minima`, `quantidade`, `renasce_dias` (vindos de `data/forja/materiais.json` → `nos_de_minerio.veio_da_fenda`). Mostram cristais emissivos + rótulo. **Ainda não há sistema de mineração** — só os marcadores, prontos para ligar com `Forja.pode_minerar()`.

## Regenerar
```
python3 tools/forja_gerar_dados.py          # data/forja/*.json
python3 tools/forja_gerar_doc.py            # docs/FORJA_E_ITENS.md
python3 tools/ilha_futurista_layout.py      # scripts/ilha_futurista/ilha_futurista_layout.json
FUT_DL=<zips extraídos> FUT_REPO=. python3 tools/ilha_futurista_curar_assets.py   # modelos curados
```

## Testes (headless)
```
godot --headless --path . -s res://tests/ilha_futurista_testes.gd   # cena, navegação, NPCs, diálogos, nós de minério
godot --headless --path . -s res://tests/forja_testes.gd            # dados e mecânicas da forja
```
Créditos dos modelos: `art/CREDITOS_ILHA_FUTURISTA.md`.
