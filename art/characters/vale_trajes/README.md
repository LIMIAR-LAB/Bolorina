# Vale — camadas de equipamento (paper-doll)

Gerado por `tools/vale_trajes.py` (local, sem custo, sem serviço externo) a partir de
`original_vale_v6/` (vila/fazenda/masmorra) e `vale_combate_v6pal/` (golpes). Nada da arte base foi alterado.

- `indice.json`: ordem dos quadros da vila (`vila.quadros`, atlas 16 colunas × 48 px) e folhas de combate (`combate.folhas`).
- `camadas/<peça>/vila.png`: só os pixels que a peça troca, quadro a quadro.
- `camadas/<peça>/combate/<mov>_<dir>_sheet.png`: idem para as 24 folhas de golpes (112 px, 8 col, 49 quadros).
- Peças: `camisa_azul`, `camisa_vermelha`, `camisa_cinzas` (recolor da camisa), `calca_anil`, `calca_caqui` (recolor da calça),
  `adam_peito`, `adam_grevas` (paleta metálica da armadura v99, mesmo método de `tools/vale_armadura.py`),
  `capuz_couro`, `elmo_ferro`, `elmo_adamantium`, `couro_cacador`, `malha_guarda`: arte do **PixelLab**
  (`work/pixellab_equip/`) recortada e carimbada em cada quadro por `tools/vale_pecas_pixellab.py`;
  têm também `vila_apagar.png` e `combate_apagar/` (máscara: pixels da base que a peça tira).
- Usado por `scripts/ilha/equipamento_visual.gd`. Documentação: `docs/EQUIPAMENTO.md`.
