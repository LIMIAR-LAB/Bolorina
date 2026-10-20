# Ilha das Cinzas — 3 areas conectadas

Entrada: `jogo_ilha.tscn` (atalho `Jogar-ilha.ps1`). Comeca na **fazenda**.

| Area | Cena | Observacao |
|------|------|------------|
| Fazenda | `scripts/ilha/fazenda.tscn` | Standard Farm: casa, campo, lago, galinheiro |
| Vila | `scripts/ilha/vila_jogo.tscn` | V7 modular + cercas novas + andaveis |
| Combate | `combat_arena.tscn` | Mesmo Vale (paleta V6 nos golpes) |

## Controles (fazenda)
- **1–9, 0 / roda**: ferramenta (enxada, picareta, machado, foice, regador, sementes, mao; **0 = vara de pesca**)
- **LMB / J**: usa no cursor (celula a frente ou sob o mouse)
- **E**: entrar na casa / caixa de envio / **galinheiro**: ovos (coletar), cocho (ração), galinha (carinho)
- **Energia**: barra no canto (100). Enxada 4, picareta/machado 5, foice/regador 2, vara 6. Sem energia não usa; dormir restaura
- **Pesca**: vara (0) virada para o lago → boia → espere o **!** e use de novo (janela 0,9 s). Carpa 30, tilápia 50, truta dourada 140
- **Galinhas**: ração no cocho (1 por galinha/dia) → ovos no dia seguinte (mais afeto = mais chance); carinho 1×/dia (afeto 0–10). Ovo 25
- **M**: mapa (`docs/MAPA_MUNDI.md`)
- **F9 / N**: dormir (avanca o dia; terra regada cresce)
- **F5**: salvar em `user://ilha_fazenda_v1.json` (nunca toca `island_v1.json`)
- **F7 / F10 / F11 / F12**: debug — masmorra / vila / arena / fazenda

## Vila
- **E** perto de um morador: conversa (+1 amizade/dia). Sr. Armando (loja de sementes e ração, compra colheita/ovos/peixes), Dona Lurdes, Tobias (guia: ruínas). Ver `docs/VILA_MAIOR.md`.
- Portão entre os pilares das ruínas (norte) → **masmorra** procedural (`docs/DUNGEONS.md`).

## Culturas
Nabo 3 dias, couve 5, abobora 7 (so cresce se regada naquele dia). Estagios 0–3.

## Vale no combate
Folhas de ataque em `art/characters/vale_combate_v6pal/` (remap CIELAB da arte Gamelab
para a paleta V6). Idle/corrida ja usavam PNGs V6. Ver README na pasta e `tools/vale_paleta_v6.py`.

## Correções 19/10 (abismo, armadura, ícones)
- **Abismo da vila**: `scripts/modular/abismo_barreiras.gd`. Células andáveis sem chão completo (borda da grade e beira de penhasco > 1,5 m) saem da lista andável; nelas entra uma borda natural (rochas, arbustos escuros/floridos, árvores de outono/escuras; pilares de ruína emoldurando a trilha das ruínas), com 143 peças. Atrás disso há paredes finas invisíveis como reserva (`ABISMO_VER=1` mostra em vermelho). Se cair mesmo assim (y < seguro − 2 m por 0,8 s), a Vale volta ao último ponto seguro. Para desligar: `abismo_v1: true` no config extra. Teste: `tests/vila_abismo.gd` (`ABISMO_MODO`, `ABISMO_CAP=1`).
- **Armadura nos golpes**: transformada, a Vale usa `x_<golpe>_<dir>` de `art/characters/vale_combate_armadura/` (combo, dash, especial, dano), recolorida com a paleta do corpo v99 por `tools/vale_armadura.py`; asas e aura continuam. Para desligar: `jogador_combate.armadura_golpes = false`. Teste: `tests/combate_armadura_ataque.gd` (`CMB_CAP=1`).
- **Ícones da barra**: pixel-art 16×16 (`art/ui/icones_fazenda/`, gerados por `tools/icones_fazenda.py`), desenhados 3× sem filtro; se faltar o PNG, volta o desenho vetorial. Teste: `tests/inventario_icones.gd`.

## Escopo 19/10 tarde (fazenda, vila, mapa, masmorra)
- Combate: N/S de tela não tem folha própria (arte em 6 direções). No combo, golpes para N/S alternam as
  diagonais (1º lado atual, 2º lado oposto, 3º lado atual) — o corte varre e lê como frontal. Desligar:
  `jogador_combate.n_s_alterna = false`. Teste: `tests/combate_norte_sul.gd`. Sem arte nova (nada pago).
- Árvores dos detritos 143, 144 e 145 que tapavam a vista do canteiro foram movidas para (5,−12), (13,2) e (−10,−9).
- Testes: `tests/fazenda_extras.gd` (`FAZ_CAP=1`), `tests/vila_npcs_testes.gd` (`NPC_CAP=1`), `tests/masmorra_testes.gd` (`MAS_CAP=1`).

## Horizonte vivo (Vila e Fazenda)
Fundo do Environment em modo **canvas** (`scripts/ilha/horizonte_vivo.gd`); luz, sombras e ambiente da cena não mudam.
- **Mesmo lugar, clima por dia**: `CLIMAS[(dia − 1) % 5]` = ensolarado → nublado → chuva leve → pôr do sol → aurora
  (estável no mesmo dia; muda ao dormir com F9). À noite (relógio, tecla L) o céu escurece e aparecem estrelas.
- **Camadas**: céu procedural (nuvens que derivam, sol, chuva, estrelas) · `horizonte_base.png` (ilhas distantes + mar de nuvens, só tingido)
  · 3 **ilhas flutuantes** separadas que derivam devagar e têm parallax (posição/velocidade sorteadas pelo dia).
- **Aurora 3D**: 3 cortinas aditivas (shader) presas à câmera, no alto da tela, **por cima da cena**. Automática no dia "aurora"
  (mais forte à noite); **U** alterna automática → ligada → desligada.
- **Névoa do abismo** (4 planos de `vila_modular`): com o horizonte ligado fica a 5 % do alfa e tingida pelo clima — era ela o "véu lavado".
- **Curva da cena**: exposição + filmic + ajustes + LUT deixam tudo acima de ~55 % cinza rosa-claro; o céu aplica a inversa medida
  (`art/environment/curva_inversa.png`, refazer com `tests/horizonte_calibrar.gd` se mudar a grade).
- **Teclas/flags**: **K** liga/desliga (volta ao céu e à névoa originais) · **Shift+K** próximo clima (teste) · **U** aurora ·
  env `HORIZONTE=0` desliga · `HORIZONTE_CLIMA=nublado` força · `AURORA=1/0` · `HORIZONTE_COMPENSAR=0` sem curva inversa.
- Teste: `tests/horizonte_testes.gd` (`HZ_CAP=1` → `docs/horizonte-*.png`, `docs/aurora-efeito-*.png`).
- Exportação: `art/environment/` tem `.gdignore` (carregada em tempo de execução) — copiar solta ao lado do exe.
- Limite conhecido: ainda há blocos retangulares fracos no céu em alguns tons (não vêm do glow, do DOF nem da névoa; suspeitos: SSIL/SSR); não mexi.
