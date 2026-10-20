# Fontes dos assets da cena visual

## Plugins

- Phantom Camera, Ramokz e colaboradores, MIT. Licenca incluida em addons/phantom_camera/LICENSE.
- Simple Grass Textured, IcterusGames, MIT. Licenca incluida em addons/simplegrasstextured/LICENSE.
- Textura grassbushcc008.png distribuida com Simple Grass: FabinhoSC, CC0, https://opengameart.org/content/stylized-grass-and-bush-textures-0

## Poly Haven â€” CC0

Licenca dos assets: https://polyhaven.com/license

- https://polyhaven.com/a/castle_brick_01
- https://polyhaven.com/a/grey_roof_tiles
- https://polyhaven.com/a/brown_planks_03
- https://polyhaven.com/a/grass_path_3
- https://polyhaven.com/a/aerial_grass_rock
- https://polyhaven.com/a/lichen_rock
- https://polyhaven.com/a/island_tree_02
- https://polyhaven.com/a/fern_02
- https://polyhaven.com/a/dead_tree_trunk_02 (baixado, sem instancia ativa na composicao final)
- https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky

Materiais e modelos baixados nas variantes 1k para esta prova local. Edificios, terreno, cercas, poco, ponte, ilhas e ruinas sao geometria montada por codigo neste projeto.

island_tree_02_optimized.glb e uma copia simplificada no Blender 5.2.2 LTS, com 10% das faces do original. Fonte glTF preservada no mesmo diretorio.

## Personagens originais ativos — V3

Guardião da Horta e Zeladora do Viveiro foram gerados para Ilha das Cinzas com PixelLab, em 18/10/2026. Metadados completos em art/characters/original_guardian/source-metadata.json e original_villager/source-metadata.json. PNGs preservados sem retoque; montagem, pivô e escala configurados no Godot. O uso segue os termos do serviço: https://pixellab.ai/termsofservice

As cópias de sprites locais de Chrono usadas na V2 foram retiradas da pasta ativa e arquivadas em work/backups/v2/characters, com .gdignore. Os arquivos originais de D:/Projetos/CronosMemories permanecem intocados. Não há sprites de outros jogos ativos na V3.

## Texturas acrescentadas na V3 — Poly Haven, CC0

- https://polyhaven.com/a/leafy_grass
- https://polyhaven.com/a/forest_ground_04 (preservada para variações futuras)
- https://polyhaven.com/a/mossy_cobblestone
- https://polyhaven.com/a/plastered_stone_wall (normal utilizado; reboco com cor própria para legibilidade)

O céu ativo é procedural; o HDRI anterior está preservado para comparação. Flores, mudas, carrinho, pedra votiva, feixes e água foram construídos por código no projeto.

## Personagens e árvore da V4

Aprendiz do Vale (original_apprentice) e Jardineira do Vale (original_gardener): novas gerações originais PixelLab em 48×48, proporções compactas. Metadados e PNGs preservados nas respectivas pastas. O protagonista anterior e a NPC anterior ficam preservados para comparação, sem instâncias ativas na V4.

A árvore de recurso é geometria autoral: tronco e galhos em malha, 850 folhas instanciadas com cores e shader de transmissão, vento e oclusão parcial da copa. As árvores cenográficas de Poly Haven continuam no cenário com shader próprio para suas folhas. Machado, regador e respingos são geometria e animação por código.

As imagens referencia-layout-v4.png e referencia-personagem-v4.png foram fornecidas pelo usuário e são documentos de referência, fora da importação do jogo (docs/.gdignore). Não foram usadas como sprites ou cenários jogáveis.

## Vilarejo de referência — V6

Vale (`original_vale_v6`), Mira (`original_mira_v6`) e gato (`original_cat_v6`) são gerações originais PixelLab para este projeto, em 18/10/2026. PNGs e metadados preservados sem retoque nas respectivas pastas. Prompts e IDs em `docs/PROMPTS_PERSONAGENS_V6.txt` e `docs/ARTE_V6.txt`. Uso sujeito aos termos do serviço já indicados acima. O morador da praça reutiliza `original_apprentice`, original da V4.

Telhas, arcos, floreiras, caixas, vasos, trepadeiras, capim, legumes, abóboras, espantalho, margens, juncos, nenúfares e corvos cenográficos são geometria por código, com materiais e shaders do projeto. Os materiais e modelos externos anteriores mantêm suas atribuições acima. A imagem alvo fornecida pelo usuário permanece apenas como referência em `docs/`, sem uso como fundo da cena.

## Personagem articulado experimental (comparação, 19/10/2026)

As 25 peças em `art/characters/experimental_articulated/` (cabeça e tronco em 5 vistas, braços, antebraços, mãos, punho, manga, coxas, canelas, botas em 3 vistas, machado e regador) foram desenhadas por código neste projeto com `source/gerar_pecas.py` (Python 3.13 + Pillow 12.3). A paleta foi amostrada de `original_apprentice` (V4); nenhum sprite existente foi recortado ou retocado, e os PNGs PixelLab originais seguem intactos. Hashes sha256 e procedência em `manifest.json`. Nenhum serviço pago foi usado (sem PixelLab, sem Meshy AI). A técnica de peças em billboard presas a um esqueleto 3D é inspirada na descrição pública dos desenvolvedores de Alabaster Dawn; nenhuma arte desse jogo foi usada.

## Forma de teste "Armadura de adamantium nível 99" (19/10/2026)

Gerada com PixelLab pela API oficial, usando a assinatura do usuário (plano Tier 2: Pixel Artisan). A chave foi passada só por variável de ambiente do processo e não está gravada em nenhum arquivo. Pasta: `art/characters/experimental_adamantium_v99/`. Registro de cada geração (prompt, configurações, data, saldo antes e depois) em `source/pixellab/geracoes.json`; metadados do personagem em `source/pixellab/metadata.json` (character_id `39d5ea40-d5f8-405f-8ce4-2097c4db6634`).

| Etapa | Endpoint | Gerações |
|---|---|---|
| Armadura sobre o aprendiz V4 (vista sul, 48×48, seed 9901). Entrada: `original_apprentice/rotations/south.png`, não alterado | `/edit-image-pixen` | 1 |
| 8 rotações a partir da vista sul armada (seed 9902) | `/create-character-v3` (referência) | 1 |
| Caminhada nas 8 direções, 6 quadros (template `walking`, seed 9903) | `/characters/animations` (template) | 8 |
| Asas simétricas 64×64 com a paleta da armadura (seed 9904) | `/create-image-pixflux` | 1 |

Total: **11 gerações da assinatura** (saldo de 706,8 para 695,8 de 4800). Os créditos em dólar continuaram em US$ 0,00; nenhuma compra. Os PNGs da PixelLab foram copiados sem retoque. A divisão das asas em duas peças, o manifesto e a corrida (a mesma caminhada em 14 qps; não foi gerada uma corrida própria) são feitos por código em `source/montar.py`. As peças "adamantium" do personagem articulado (`experimental_articulated/adamantium/`) são uma recoloração por código das peças originais, sem IA. A aura (partículas e anel) é shader e partículas do Godot (`shaders/aura_ring.gdshader`). Meshy e GameLab não foram usados.

## Animações de combate do Vale V6 — Gamelabs Studio (19/10/2026)

Geradas com Gamelabs Studio (gamelabstudio.co) via MCP, usando os créditos da conta do usuário (limite autorizado: 60 créditos; usados: **55**). Nenhuma compra. Projeto Gamelab 32737 "Ilha das Cinzas - Vale combate". Referência: rotações PixelLab de `original_vale_v6` (south-east, east, north-east) ampliadas ×8 em fundo magenta; os PNGs originais não foram alterados. Pasta: `art/characters/vale_combate_gamelab/` (detalhes em `README.md`, `manifest.json` e `fonte/gamelab_jobs.json`).

Configuração: `image.generate` qualidade standard, pixel_art (32 cores), fundo magenta, vista 3/4 de cima, 512×512 (1 crédito cada); `video.generate` qualidade standard, 4 s, loop, 960×960 (4 créditos cada). Sem `spritesheet.generate`: quadros recortados, sem magenta e reduzidos (vizinho mais próximo, escala 0,1103, paleta de 48 cores) por código local. As direções south-west, west e north-west são espelhamentos por código.

| Item | Job id | Prompt (resumo) | Créditos |
|---|---|---|---|
| Base de combate south-east (asset 70326) | `52c45ab0-31f3-48f8-a947-7af3e3fdc3ef` | Pixel art game sprite of the same young chibi hero as the reference image (big head, messy brown hair, green shirt, open brown leather vest, dark grey trousers, brown boots, dark 1px outline, warm cel shading), now holding a short steel sword in his right hand in a ready combat stance, slightly crouched; full body, 3/4 top-down view, facing south-east; keep the exact same face, hair, outfit, colors and chibi proportions. | 1 |
| Base de combate east (asset 70327) | `bd34b1a6-4da1-4846-848d-f4152d27c32f` | Same as the south-east base, side profile facing east (references: Vale V6 east + south-east rotations). | 1 |
| Base de combate north-east (asset 70332) | `36ec1815-19ed-4865-9b01-d0038dfbf6f6` | Same as the south-east base, seen from behind at an angle, facing north-east (references: Vale V6 north-east + south-east rotations). | 1 |
| Vídeo slash_combo_se | `e3ce59d9-a6a8-49b0-ad8c-53e484523395` | Fast three-hit sword combo (horizontal slash, backhand slash, overhead downward chop with a short step), brief white arc trails, return to ready stance; stays in place facing south-east. | 4 |
| Vídeo dash_se | `a140176e-5053-4252-bbe4-54a406d36378` | Brief crouch, very fast evasive dash toward bottom-right with dust and white speed streaks, skid stop, spring back to ready stance and return to the start position. | 4 |
| Vídeo hit_se | `f88529e9-0746-497a-be61-2f514edae59a` | Hit by an unseen blow from the front: head snaps back, recoil with white impact flash, stagger one step, recover; hit a second time and recover again. | 4 |
| Vídeo special_se | `740f97f5-1c8c-458f-8bb6-342d921c9ccf` | Special: charge with orange ember aura and glowing orange blade, spin once releasing a full circular orange fire slash ring with ember sparks, strong low finish, return to ready stance. | 4 |
| Vídeo slash_combo_e | `852e8665-21f4-42d4-8871-dd86a1d0c6cb` | Same combo prompt, facing east. | 4 |
| Vídeo dash_e | `9020c8e0-501c-418e-9f3f-4cfc61f0e6a1` | Same dash prompt, dashing to the right, facing east. | 4 |
| Vídeo hit_e | `50219059-6664-4b75-ad1f-c5c059a25271` | Same hit-reaction prompt, facing east. | 4 |
| Vídeo special_e | `9f0115a6-7b63-42de-9497-9e3ca3dace25` | Same special prompt, facing east. | 4 |
| Vídeo slash_combo_ne | `d450dfaa-6d3f-4c57-9ad2-277e2907c555` | Same combo prompt, seen from behind, facing north-east. | 4 |
| Vídeo dash_ne | `0aca277e-95ca-4d7d-9e0d-561405f89834` | Same dash prompt, dashing toward top-right, facing north-east. | 4 |
| Vídeo hit_ne | `845b42fc-415a-4cfe-b5a5-f6268e5ef937` | Retry: seen from the back the entire time, never turns around; blow from the top-right, upper body jolts back toward the camera, small white spark on the far side, slides back one small step, steadies; twice. | 4 |
| Vídeo special_ne | `b52fce68-a506-49fa-8b26-45c998939c77` | Same special prompt, seen from behind, facing north-east. | 4 |
| Vídeo hit_ne (v1, rejeitado: vira para a câmera) | `96ef596f-b559-43b7-ab78-a32e17a103e1` | Same hit-reaction prompt, seen from behind, facing north-east. | 4 |

Total: **55 créditos Gamelab** (3 imagens × 1 + 13 vídeos × 4). O saldo exato da conta não é exposto pelo MCP; o débito de cada job foi confirmado pelo campo `credits_debited` da resposta. Uso comercial permitido pelos termos do Gamelabs Studio, sem atribuição obrigatória. Meshy e outros serviços pagos não foram usados.


## Protótipo de combate (art/combate/) — 19/10/2026

Assets **já existentes** na conta Gamelab do Thiago (projeto 30457), baixados antes só por leitura e processados localmente: **0 créditos, nenhuma geração nova**. Detalhes e scripts em `art/combate/README.md`.

| Arquivo | Id Gamelab | Nome |
|---|---|---|
| `orc/orc_run.png` | 67660 | Orc motion v3 run |
| `orc/orc_idle/windup/strike/recover.png` | 67661 | Orc motion v3 axe_combo |
| `orc/orc_hurt.png`, `orc_death.png` | 67663 | Orc motion v3 hurt_death |
| `props/prop_caixote_*.png` | 65740 | Cronos room v2 room2_crate |
| `props/prop_urna_*.png` | 65741 | Cronos room v2 room2_pottery |
| `props/prop_rocha_inteiro.png` | 65742 | Cronos room v2 room2_rock |
| `vfx/fx_corte_crescente.png` | 64195 | Andarilho chibi base (quadro 12, só a onda de corte) |

As animações do Vale (`art/characters/vale_combate_gamelab/`) só são lidas, sem nenhuma alteração.

## Horizonte vivo (19/10) — `art/environment/`
- `horizonte_base.png` (ilhas distantes + mar de nuvens) e `ilha_flutuante_1..3.png`: **originais, gerados por código**
  (`tools/horizonte_camadas.py`, PIL), na paleta da Vila/Fazenda (grama, folhas de outono low-poly, rocha lilás). Sem geração paga.
- `curva_inversa.png`: medição da curva de cor da cena (`tests/horizonte_calibrar.gd`), não é arte.
- Céu, nuvens, chuva, estrelas e aurora 3D: shaders procedurais em `scripts/ilha/horizonte_vivo.gd` (originais).
- As placas "épicas" geradas para conceito (vale dourado, tempestade, alvorada, aurora) **não entraram no jogo**
  (paisagens de outro lugar; o usuário pediu o mesmo lugar com só o clima mudando).

## Equipamento da Vale (PixelLab, 19/10/2026)

Capuz de couro, elmo de ferro, elmo de adamantium, couraça do caçador e cota de malha do guarda: gerados com
PixelLab (`/edit-image-pixen`, assinatura do usuário) em cima das rotações de `original_vale_v6`. 26 gerações
(saldo antes: 695,8 da assinatura; US$ 0). Imagens originais e registro (prompt, seed, job) em `work/pixellab_equip/`.
As camadas do jogo (`art/characters/vale_trajes/camadas/`) são recorte, espelho e carimbo por código
(`tools/vale_pecas_pixellab.py`), com pequenas correções descritas em `docs/EQUIPAMENTO.md`.

## Vale única (Gamelab, 20/10/2026)

`art/characters/vale_unica/`: Vale sem espada parada, correndo e agindo, gerada com Gamelabs Studio (projeto 32737)
a partir das bases do combate (`vale_combate_gamelab/fonte`), com os créditos da conta do usuário (41 créditos,
autorizados). Quadros recortados por código (`tools/vale_unica_quadros.py`); jobs em `work/vale_unica/jobs.json`.
