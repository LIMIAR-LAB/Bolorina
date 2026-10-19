# Validação da V3 — 18/10/2026

Godot 4.7.2 stable oficial, Windows, Forward+ / Vulkan, NVIDIA RTX 4050 Laptop. O Chrono Memories original não foi alterado.

## Sistemas

**513/513 verificações passaram**, saída 0. Incluem 100 seeds determinísticas e conectadas, âncoras, chão, plantio, colheita, recrutamento, save, dano, esquiva e entrada/saída da bancada de combate. O teste preservou os bytes do save anterior.

## Movimento e cena

**35/35 verificações passaram**, saída 0. Incluem os quadros nas oito direções, ausência de espelhamento, seleção de animação, origem dos personagens, câmera ortográfica com orientação constante, addons, normais do terreno, subida real da rampa e travessia da ponte em ambos os sentidos. O gesto de cultivo original e a troca dos feixes de luz também foram verificados.

Na rampa, a diferença máxima amostrada entre apoio do personagem e altura analítica do terreno foi 0,213 m; o personagem alcançou o patamar superior. A ponte foi testada com a mesma entrada e física do jogo. Uma borda de colisão que travava a passagem foi substituída por uma superfície contínua antes da rodada final.

## Revisão visual

Capturas em GPU: prototipo.png, panorama.png e crepusculo.png. Vídeo movimentacao-autoral.mp4: 775 quadros, 1600×900, 30 fps, aproximadamente 25,8 s, gravado na engine com a física ativa. Demonstra direções, corrida, gesto de cultivo e travessia. O roteiro não grava progresso de cultivo do usuário.

Foram corrigidos partículas grandes, névoa excessiva, brilho estourado na água e rotações da NPC com cenário acidental. Os sprites ativos são originais. Texturas de cenário têm mipmaps; normais e materiais foram inspecionados nas capturas.

Amostra curta final de 120 quadros: cerca de 68 FPS médios na GPU local. Não é benchmark sustentado nem garantia de desempenho mínimo. O encerramento das capturas apresentou aviso de sete recursos Texture não liberados; não houve erro de script na execução final.

## Limites

Não houve playtest humano contínuo. Permanecem sem validação: hardware mínimo, gamepad, várias resoluções, milhares de seeds, construção dinâmica, navegação completa de NPCs, combate Chrono adaptado e produção artística final. O vídeo e os testes não substituem a avaliação do usuário sobre sensação do movimento e identidade visual.

BMAD instalado: core 6.12.4 e Game Dev Studio 0.7.2. O brief e a proposta anteriores permanecem no projeto; o plano visual atualizado está em VISUAL_V3.md. Esta rodada priorizou o laboratório de arte e movimento.
