# Vale — golpes com armadura de adamantium

Usados quando a Vale está transformada (G): combo, dash, especial e dano.
Origem: `vale_combate_v6pal/` (mesmos quadros/âncoras).
Método (`tools/vale_armadura.py`): o corpo abaixo da cabeça (~42% superiores = cabeça) recebe a paleta
metálica do corpo da armadura `experimental_adamantium_v99/rotations` por quantil de luminância
(contorno escuro mantido, placas clareadas). Cabeça, espada e efeitos ficam como estão.
As asas e a aura (`forma_adamantium.gd`) continuam ligadas durante os ataques.
Desligar: `jogador_combate.armadura_golpes = false`.
Sem geração paga; nada foi gerado em serviço externo.
