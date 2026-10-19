# Identidade visual V3 — Ilha das Cinzas

18/10/2026. Estudo jogável para validar a identidade antes de ampliar os sistemas.

## Direção

Uma comunidade cultiva terra fértil entre restos de uma civilização de pedra. O contraste principal é vida pequena e acolhedora contra ruínas grandes e antigas. O personagem é um guardião da horta: capuz de carvão, capa musgo, couro de trabalho e detalhes âmbar. Evitar armadura brilhante, espadas gigantes e reprodução de personagens de franquias.

Paleta: verde musgo e ardósia nas massas; reboco gasto e madeira escura na vila; ouro nos pontos de luz; sombras frias. A referência do vídeo orienta a luz de fim de tarde, os sprites em cenário 3D e a leitura da vegetação. O resultado atual continua sendo uma composição de protótipo, com arquitetura simples.

## Implementação nesta versão

- Câmera ortográfica em ângulo fixo, com zona de folga, acompanhamento e zoom amortecidos. Caminhar não gira o enquadramento.
- Protagonista original gerado para este projeto: 200 quadros, 32 animações, oito direções de repouso, caminhada, corrida e gesto de cultivo. As diagonais têm desenhos próprios; não dependem de espelhar o sprite.
- NPC jardineira original com caminhada em oito direções e 81 quadros no conjunto ativo. Cinco vistas de repouso usam quadros limpos da própria caminhada; as rotações geradas com cenário acidental foram excluídas do manifesto ativo.
- Pivô dos pés por quadro, sombra de contato e preservação da fase ao trocar direção durante o mesmo movimento. O deslocamento vem do CharacterBody3D, com aceleração e colisão reais.
- Sol quente, sombras, brilho moderado, névoa volumétrica, feixes estilizados com profundidade e poeira discreta. L alterna fim de tarde e crepúsculo; H oculta a interface.
- Reflexos por SSR e ReflectionProbe. Água com movimento de superfície, canal e quedas nas bordas. Brilho especular reduzido após revisão das capturas.
- Ponte com superfície de colisão contínua que acompanha as duas margens, permitindo ida e volta sem travar num degrau.
- Casas modulares com base de pedra, reboco, enxaimel, janelas laterais, alpendres e lanternas. Carrinho de colheita, pedra votiva, flores, mudas ao vento e rochas na costa.
- Novos materiais CC0 e mapas normais; mipmaps ativados nas texturas de cenário. Árvores otimizadas e vegetação instanciada mantidos.
- Sprites de Chrono foram retirados da pasta ativa de personagens e arquivados em work/backups/v2, fora da importação. Nenhum sprite de Severence foi instalado.

## Testar

WASD caminha; Shift corre; roda aproxima; V mostra panorama. E perto do canteiro planta/colhe com gesto do personagem; N avança o dia. E junto da jardineira recruta/dispensa. O gesto de cultivo dura aproximadamente 0,83 s e interrompe o deslocamento durante sua execução.

O vídeo movimentacao-autoral.mp4 foi gravado na engine, usando a mesma entrada e física do jogo. A sequência demonstra direções, caminhada, corrida, gesto e travessia. Não é uma animação conceitual do cenário.

## Roadmap visual priorizado

1. **Validar esta identidade:** escala do personagem, ângulo fixo, intensidade solar, leitura de sombra e vegetação. Escolher a preferência entre luz dourada e crepúsculo antes de produzir mais conteúdo.
2. **Construção dinâmica:** extrair casas em módulos/cenas, definir encaixes, fundações, ocupação de lotes e remoção de vegetação. Validar a mesma iluminação com edifícios colocados pelo jogador.
3. **Personagens e combate:** revisar manualmente silhueta e consistência dos quadros, criar ferramentas e ataques autorais, antecipação de golpes e reações. Portar o combate principal de Chrono somente depois de validar movimento e escala.
4. **Ilha com regiões:** substituir a distribuição uniforme por composição de biomas, caminhos, margens orgânicas e marcos. Preservar determinismo e conexão das áreas nas seeds.
5. **Acabamento:** modelos arquitetônicos mais trabalhados, oclusão de construções diante do jogador, navegação completa dos NPCs, interação com vegetação e perfis de qualidade para máquinas diferentes.

## Limites atuais

A colocação de edifícios pelo jogador não está implementada. O relevo e a costa são procedurais, mas a vila tem pontos de composição fixos. O acompanhante usa uma passagem pela ponte; ainda precisa de navegação completa entre obstáculos. O combate continua simplificado, sem animações finais de ataque ou esquiva. O HDRI anterior está preservado, mas o céu ativo agora é procedural. SSR depende do que está na tela, complementado pelo probe; não é ray tracing.

A produção dos sprites usou PixelLab. Arquivos de origem e metadados foram preservados; os PNGs foram copiados sem retoque de pixels. O enquadramento e a ancoragem são ajustes da engine. Ainda há variação de proporções entre alguns ciclos, que merece uma revisão artística posterior.
