# Adendo do brief

A análise visual, fontes do projeto existente, comparação de engines, direção de arte e plano técnico estão em `docs/PROPOSTA.md` na raiz deste projeto. O laboratório serve para reduzir risco técnico; não aprova automaticamente o sistema de combate híbrido nem estabelece ligação canônica com Chrono Memories.

## Detalhes preservados do pedido

- Visual que lembra personagens dos primeiros Pokémon, com cenário de profundidade e acabamento modernos.
- Dark fantasy inspirada em Elden Ring como direção a explorar.
- Moradores com personalidade e possibilidade de participar de batalhas em momentos específicos.
- Manter inicialmente ambas as propostas de luta, avaliando a referência e o combate principal existente.
- Começar pequeno, com ilha e geração procedural; estudar também personagens gerados.

## Alternativas

Um único combate livre no mundo reduziria a troca de contexto, mas exigiria refazer posicionamento, hitboxes e a física aérea lateral. Um único combate lateral facilita reaproveitamento e perde parte da exploração combativa do vídeo. Testar ambos antes da decisão evita tratar preferência de implementação como preferência do jogador.

O laboratório atual troca restrição de movimento e câmera no mesmo cenário. Não instancia a arena de Chrono, ainda não adapta os combos do original, não usa seus recursos de dano e não salva estado de luta. É uma bancada para circulação/câmera/sistemas básicos, conforme o limite explicitado no brief.
