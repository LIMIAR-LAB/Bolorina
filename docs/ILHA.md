# Ilha das Cinzas — 3 areas conectadas

Entrada: `jogo_ilha.tscn` (atalho `Jogar-ilha.ps1`). Comeca na **fazenda**.

| Area | Cena | Observacao |
|------|------|------------|
| Fazenda | `scripts/ilha/fazenda.tscn` | Standard Farm: casa, campo, lago, galinheiro |
| Vila | `scripts/ilha/vila_jogo.tscn` | V7 modular + cercas novas + andaveis |
| Combate | `combat_arena.tscn` | Mesmo Vale (paleta V6 nos golpes) |

## Controles (fazenda)
- **1–9 / roda**: ferramenta (enxada, picareta, machado, foice, regador, sementes, mao)
- **LMB / J**: usa no cursor (celula a frente ou sob o mouse)
- **E**: entrar na casa / caixa de envio
- **F9 / N**: dormir (avanca o dia; terra regada cresce)
- **F5**: salvar em `user://ilha_fazenda_v1.json` (nunca toca `island_v1.json`)
- **F10 / F11 / F12**: debug — vila / arena / fazenda

## Culturas
Nabo 3 dias, couve 5, abobora 7 (so cresce se regada naquele dia). Estagios 0–3.

## Vale no combate
Folhas de ataque em `art/characters/vale_combate_v6pal/` (remap CIELAB da arte Gamelab
para a paleta V6). Idle/corrida ja usavam PNGs V6. Ver README na pasta e `tools/vale_paleta_v6.py`.

## Correções 19/10 (abismo, armadura, ícones)
- **Abismo da vila**: `scripts/modular/abismo_barreiras.gd`. Células andáveis sem chão completo (borda da grade e beira de penhasco > 1,5 m) saem da lista andável; nelas entra uma borda natural (rochas, arbustos escuros/floridos, árvores de outono/escuras; pilares de ruína emoldurando a trilha das ruínas), com 143 peças. Atrás disso há paredes finas invisíveis como reserva (`ABISMO_VER=1` mostra em vermelho). Se cair mesmo assim (y < seguro − 2 m por 0,8 s), a Vale volta ao último ponto seguro. Para desligar: `abismo_v1: true` no config extra. Teste: `tests/vila_abismo.gd` (`ABISMO_MODO`, `ABISMO_CAP=1`).
- **Armadura nos golpes**: transformada, a Vale usa `x_<golpe>_<dir>` de `art/characters/vale_combate_armadura/` (combo, dash, especial, dano), recolorida com a paleta do corpo v99 por `tools/vale_armadura.py`; asas e aura continuam. Para desligar: `jogador_combate.armadura_golpes = false`. Teste: `tests/combate_armadura_ataque.gd` (`CMB_CAP=1`).
- **Ícones da barra**: pixel-art 16×16 (`art/ui/icones_fazenda/`, gerados por `tools/icones_fazenda.py`), desenhados 3× sem filtro; se faltar o PNG, volta o desenho vetorial. Teste: `tests/inventario_icones.gd`.
