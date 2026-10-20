# Hub "Mapa das Ilhas" da Bolorina (guardado, SEM USO)

Decisão do Thiago em 20/10/2026: o mapa-múndi oficial é o **mapa pintado do Claude** (`art/ui/mapa_mundi_pintado.png`,
tecla M e pedras de viagem com T, em `scripts/ilha/jogo_ilha.gd`). Tudo o que existe hoje fica na **primeira ilha
flutuante**, então o hub de várias ilhas flutuantes não é o mapa principal.

Este diretório guarda o hub como estava (cena, scripts, shaders, testes, ferramenta e documento), com caminhos
originais preservados embaixo desta pasta. O arquivo `nao_usado/.gdignore` faz o Godot ignorar tudo aqui, então nada
disto é importado nem carregado.

O que foi reaproveitado no jogo:
- `data/areas.json` unificado (formato do Claude + pontos de entrada, entradas de masmorra e regras da Bolorina);
- `scripts/mundo/ponto_viagem.gd` (doca/totem físico nas cidades), que agora abre o mapa pintado no modo viagem;
- as ilustrações `art/ui/telas/*.png` (campo `arte` de cada área).

Para reativar no futuro (por exemplo quando existir a segunda ilha): devolver os arquivos aos caminhos originais,
apagar o `.gdignore` e ajustar `viagem.gd` para o formato v3 do registro (`mapa` agora é `[x, y]` do mapa pintado).
