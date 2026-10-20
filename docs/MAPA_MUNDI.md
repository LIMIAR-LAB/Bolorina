# Mapa-múndi — Ilha das Cinzas

Mapa no jogo: **M** (abre/fecha; Esc também fecha). Usa `art/ui/mapa_mundi_arte.png` se existir
(arte pintada pelo usuário, futura); senão o esquemático `art/ui/mapa_esquematico.png`
(gerado por `python tools/mapa_esquematico.py .`, 1200×800, pergaminho). O mesmo script grava
`art/ui/mapa_mundi.json` (centro/raio de cada área no mapa + limites do mundo de cada cena).
O marcador **"◆ Você está aqui — <área>"** pisca na **posição real do jogador** dentro da área
(`scripts/ilha/mapa_mundi.gd`; norte = −z = cima; fallback `jogo_ilha.gd → MAPA_POS`).

Atualizado em 19/10/2026 a partir do código (saídas reais em `scripts/ilha/caminhos_ilha.gd`,
grade andável medida com `tests/caminhos_sonda.gd`).

## Regiões

| Região | Estado | Cena / origem | Liga com (saídas reais) |
|---|---|---|---|
| **Fazenda** (sudoeste) | jogável | `scripts/ilha/fazenda.tscn` | **Saída leste** (fim do corredor entre barrancos, portão x 43–46, z −13,5…−8,5) → Vila (chega na entrada **sul**, `da_fazenda` (0, 16)) |
| **Vila** (centro) | jogável | `scripts/ilha/vila_jogo.tscn` (V7 modular) | **Sul** (faixa x −12…12, z ≥ 19,5) → Fazenda (`da_vila` (41,5, −10,5)); **Leste** (x ≥ 21,5, z −12…4) → Arena; **Portão das ruínas** (norte, x −8…−4, z ≤ −19) → Masmorra |
| **Ruínas do Norte** | jogável (borda da vila, mesma cena) | pilares + trilha de pedra em `vila_jogo` | Portão → Masmorra; volta em `da_masmorra` (−6, −17,4) |
| **Arena dos Orcs** (leste) | jogável | `combat_arena.tscn` + `scripts/ilha/arena_saida.gd` | **Portão oeste** (faixa de grama, x ≤ −9,3, z 0,5…6,5; só com a sala limpa) ou **B/Esc** → Vila (`da_arena` (18, −4)). A porta do fundo = próxima sala |
| **Masmorra** | protótipo | `dungeon_teste.tscn` | Portal azul (raio 1,5 m) ou Esc → Vila; escada → próximo andar. Ver `DUNGEONS.md` |
| **Floresta / Cabana do Bento** | em breve | — | Placa "em breve" no oeste da fazenda (trilha oeste do lago) |
| **Ermida da Iara** (penhasco nordeste) | em breve | — | Escadaria atrás das ruínas |
| **Lago Grande / Seu Joaquim** | em breve | — | Rio ao sul da vila, ponte |
| **Vila Grande** (lojas/porto) | em breve | plano em `VILA_MAIOR.md` | Leste/sul da praça |
| **Ilhas flutuantes** | futuro | — | (fora da ilha) |

## Esquema de conexões (como o código liga hoje)

```
                     [Masmorra (protótipo)]
                              |  portão (z ≤ −19)  /  portal azul volta
 [Ermida · em breve] - - [Ruínas do Norte]  (borda norte da vila, mesma cena)
                              |
                           [Vila] ——— leste ——— [Arena dos Orcs]  (portão oeste / B)
                           /  |  \ - - [Vila Grande · em breve]
             entrada sul  /   |   - - [Lago Grande · em breve]
                         /
 [Floresta · em breve] - - [Fazenda]  (saída leste → entrada sul da vila)
```

Na fazenda a saída é a **leste**, e ela chega na **entrada sul** da vila: no mapa a trilha sai do
lado direito da fazenda e sobe até a ponta de baixo da vila.

## Saídas (como funcionam)
`scripts/ilha/saidas_area.gd`: cada saída é um **portão largo** (retângulo que cobre a trilha e o
terreno andável em volta), com Area3D + checagem a cada quadro de física (ponto e varredura do passo,
para corrida e esquiva), **rearme** (só dispara de novo depois de sair de todos os portões) e
bloqueio (dentro de casa na fazenda; combate na arena). Visual: arco de madeira, brilho com setas no
chão, rótulo "→ Destino" e dica no HUD ("↙ Fazenda (siga a trilha)") quando o jogador chega a 8 m.

## Debug
F12 fazenda · F10 vila · F11 arena · F7 masmorra · M mapa.

## Notas
- As distâncias do esquemático são ilustrativas: cada área é uma cena separada, trocada com fade
  por `jogo_ilha.gd → ir(area, spawn)`.
- Regiões "em breve" ainda não têm cena; os personagens remotos estão em `scripts/ilha/moradores.json → remotos`.
- Na exportação, `art/ui/` vai solta ao lado do exe (lida por `Image.load_from_file` / `FileAccess`).
- Testes: `tests/transicoes_testes.gd` (cada saída, vários ângulos, andando e correndo).
