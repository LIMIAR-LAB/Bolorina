# Créditos — Minas da Cinza (dungeon sob Porto Velho)

> **PROPOSTA.** Todos os assets novos são **CC0 1.0 (domínio público)**, baixados de graça em 20/10/2026 (nenhum crédito pago — sem Meshy, PixelLab ou Gamelab).
> Curadoria: `tools/minas_da_cinza_curar_assets.py` (re-executável; espera os zips extraídos em `MINAS_DL`). Só as peças usadas foram copiadas; as licenças originais vão junto em cada pasta.

| Pasta no projeto | Pack | Autor | Licença | Fonte | Usado para |
|---|---|---|---|---|---|
| `art/models/kaykit_dungeon/` (37 .gltf + atlas 512 px) | KayKit Dungeon Pack 1.1 — FREE (a página "KayKit Dungeon Remastered" leva a este pack) | Kay Lousberg (www.kaylousberg.com) | CC0 1.0 | https://kaylousberg.itch.io/kaykit-dungeon-pack | tochas de parede, escada de madeira dos poços, barris, caixas, baú, velas, pilares, entulho |
| `art/models/kenney_mini_dungeon/` (8 .glb) | Mini Dungeon 2.0 | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/mini-dungeon | esteios de madeira, portão da Porta Selada, pedras |
| `art/models/kenney_train_kit/` (6 .glb) | Train Kit 1.1 | Kenney | CC0 1.0 | https://kenney.nl/assets/train-kit | vagonetas (carvão/terra) e a Dona Vagoneta |
| `art/models/kenney_survival_kit/` (11 .glb) | Survival Kit 2.0 | Kenney | CC0 1.0 | https://kenney.nl/assets/survival-kit | rochas dos veios, picareta, pá, balde, placa, caixas |
| `art/materials/minas_da_cinza/rock_wall_10_*` | Rock Wall 10 (diff + normal GL) | Amal Kumar / Poly Haven | CC0 1.0 | https://polyhaven.com/a/rock_wall_10 | paredes de rocha (triplanar) |
| `art/materials/minas_da_cinza/rocky_trail_*` | Rocky Trail (diff + normal GL) | Amal Kumar / Poly Haven | CC0 1.0 | https://polyhaven.com/a/rocky_trail | chão das galerias (triplanar) |

## O que a curadoria mudou
- **KayKit:** atlas `dungeon_texture.png` reduzido para 512 px (cores chapadas, sem perda visível).
- **Poly Haven:** cor em 1024 px, normal em 512 px; tingidos na cena (quente nos andares de cobre, frio nos de ferro).
- Rocha, chão, trilhos, elevador, escada de mão, lanternas, cristais de brasa, lava e neblina são **procedurais** (código em `scripts/minas_da_cinza/minas_da_cinza.gd`), não precisam de crédito.
- Kenney Train Kit: as vagonetas são carruagens de carga do pack em escala 0,5.
