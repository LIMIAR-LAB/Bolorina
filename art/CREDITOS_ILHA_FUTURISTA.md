# Créditos — Estação Depois-de-Ontem (ilha futurista)

> **PROPOSTA.** Todos os modelos novos são **CC0 1.0 (domínio público)**, baixados de graça em 19/10/2026 (nenhum crédito pago — sem Meshy, PixelLab ou Gamelab).
> Curadoria/recoloração: `tools/ilha_futurista_curar_assets.py` (re-executável; espera os zips extraídos em `FUT_DL`).

| Pasta no projeto | Pack | Autor | Licença | Fonte | Tamanho |
|---|---|---|---|---|---|
| `art/models/kenney_space_kit/` (70 modelos .glb) | Space Kit 2.0 | Kenney (www.kenney.nl) | CC0 1.0 | https://kenney.nl/assets/space-kit | 1,6 MB |
| `art/models/kenney_space_station/` (13 .glb + colormap) | Space Station Kit 1.0 | Kenney | CC0 1.0 | https://kenney.nl/assets/space-station-kit | 0,3 MB |
| `art/models/kenney_modular_space/` (portões-laser, cabos) | Modular Space Kit 1.0 | Kenney | CC0 1.0 | https://kenney.nl/assets/modular-space-kit | 0,3 MB |
| `art/models/quaternius_scifi_modular/` (36 .gltf) | Modular SciFi MegaKit [Standard] | Quaternius | CC0 1.0 | https://quaternius.itch.io/modular-sci-fi-megakit · https://quaternius.com | 2,5 MB |
| `art/models/quaternius_scifi_essentials/` (10 .gltf: EyeDrone, QuadShell, Trilobite, Locker, Crate_Large, Crate_Tarp_Large, SatelliteDish, Shelves_WideTall, Desk_L, Barrel2_Closed) | Sci-Fi Essentials Kit [Standard] | Quaternius | CC0 1.0 | https://quaternius.itch.io/sci-fi-essentials-kit | 3,7 MB |

Os arquivos de licença originais vão junto em cada pasta (`License.txt` / `License_Standard.txt`).

**Reaproveitados de entregas anteriores** (já creditados em `art/CREDITOS_VILA_GRANDE.md`): `quaternius_natureza` (cogumelos, plantas, árvores retorcidas tingidas de violeta `a890ff`), `quaternius_props` e `quaternius_vila_medieval` (muro, carroça — usados "fora do tempo" na zona de anomalia).

## O que a curadoria mudou
- **Kenney:** materiais recoloridos para a paleta da estação (metal `b4bed0`, metal escuro `5c667c`, escuro `20263a`); o vermelho virou **neon ciano emissivo**; cristais viram material "cristal"; rochas em tons frios. Recentragem: translação dos nós-raiz deslocada em (-2, 0, -1,5).
- **Quaternius:** texturas com deslocamento de matiz (neon ciano `19e6ff` / magenta `ff3df0`), redimensionadas para 1024 (cor) / 512 (normal); mapas ORM descartados para caber no orçamento.
- **Céu:** procedural (anel no céu + planeta), sem HDRI.
- Texturas de metal da Poly Haven (metal_plate, metal_plate_02, corrugated_iron, CC0) chegaram a ser baixadas e testadas, mas **não ficaram na cena** e não vão na entrega.
