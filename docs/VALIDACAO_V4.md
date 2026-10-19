# Verificação da V4 — 18/10/2026

Godot 4.7.2, Forward+ / Vulkan, Windows, RTX 4050 Laptop. O projeto Chrono Memories original permanece intocado.

## Resultados

- 513/513 verificações de sistemas: 100 seeds, costa conectada, plantio/colheita, recrutamento explícito, save e bancada de combate.
- 35/35 verificações de cena e movimento: animações direcionais, orientação fixa da câmera, rampas, ponte nos dois sentidos, gesto de cultivo e iluminação.
- 25/25 verificações novas: conversa sem acompanhar, uma única NPC, parada sem oscilação, deslocamento sem teleporte, shader de folhas, nove células, corredores, rega individual, crescimento condicionado à água, colheita, movimento solar, noite, três golpes na árvore, madeira sem duplicação e persistência.

Total: 573 verificações passaram. A subida da rampa teve erro máximo amostrado de apoio de 0,213 m. O percurso da demonstração pela horta e pelo portão foi simulado com a física do jogo sem erro de rota.

## Revisão visual

Protagonista em 48×48: 176 quadros originais, oito direções de caminhada, corrida, cultivo e poses de repouso. Jardineira em 48×48: 72 quadros, oito direções de caminhada e poses de repouso. Os PNGs originais foram preservados; escala e ancoragem foram configuradas na engine.

A árvore de recurso tem galhos, folhas largas instanciadas, vento, transmissão de luz e redução parcial da oclusão da copa quando o jogador chega perto. As árvores cenográficas mantêm o modelo CC0 com shader de folhas e recorte de alfa para sombras.

A transição solar dura 35 segundos como demonstração: a direção e a cor da luz mudam, as sombras se deslocam, os feixes solares desaparecem e lua/lanternas assumem a iluminação. O calendário completo ainda não está integrado.

Os roteiros de gravação usam suppress_saves e não escrevem progresso. Os testes que verificam persistência restauram os bytes do save anterior ao finalizar.

## Limites

O acompanhamento segue a trilha real deixada pelo jogador; ainda não há navegação completa para mudanças dinâmicas em todo o mapa. A horta não possui inventário de sementes ou reserva de água. A construção ainda usa um lote reservado, sem editor de posicionamento. Os modelos arquitetônicos e a consistência artística das animações continuam em refinamento.

Capturas na GPU mostram o resultado atual; não equivalem a um playtest humano de ergonomia. Não houve benchmark sustentado nem teste de hardware mínimo. O encerramento das capturas pode registrar o aviso já observado de sete recursos Texture não liberados; não houve erro de script nas rodadas finais.
