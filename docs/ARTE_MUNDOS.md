# Arte dos mundos — Bolorina (21/10/2026)

- **Música:** o autoload `Musica` (`scripts/audio/musica.gd`) escolhe a faixa pela cena: tela inicial → título; área do jogo → `data/musica.json` (por id da área, depois pela categoria, senão exploração); arena e masmorras → batalha. Troca com crossfade de 2 s. Usa o barramento "Musica", que manda para o Master, então segue o volume geral das Configurações. Na pausa o volume cai 6 dB. Outras cenas podem forçar uma faixa com `Musica.forcar("batalha")` e devolver o controle com `Musica.liberar()`. Para tirar o som em testes e capturas, use `ILHA_SEM_MUSICA=1`.
- **Mirante da Cascata:** área `mirante_cascata`, na primeira ilha, aberta pelo mapa-múndi. A cena fica em `scenes/mirante_cascata/` e o script em `scripts/mundo/mirante_cascata.gd`. Pisar no altar dourado ativa a câmera cinematográfica.
- **Tela inicial:** o fundo vivo, o logo e os botões vêm de `scripts/inicio/titulo_visual.gd`. O `menu_inicial.gd` só chama esse script; a lógica não mudou.
- **Props:** estão nos layouts `scripts/vila_grande/*_layout.json`, com `"origem": "bolorina_arte_mundos_2026-10-21"` (dá para tirar com um filtro).
- **Testes:** `tests/arte_mundos_testes.gd` (24 verificações). Capturas: `tests/arte_mundos_captura.gd`.


## 2ª passada (21/10/2026)
- **Mirante (vista isométrica):** chão com shader próprio (`shaders/mirante/chao.gdshader`: grama, flores e trilha), trilha de pedras até o altar, árvores variadas (Quaternius), grama, flores e arbustos, rochas quebrando os blocos do penhasco, lago com ondas e mini-cascata, luz de contorno. Sol e neblina mudam conforme a câmera: na ortográfica as sombras ficam mais curtas e suaves; na perspectiva fica o pôr do sol forte.
- **Fundo da tela inicial:** câmera reenquadrada para a cascata principal e o sol aparecerem juntos. Os picos laranja foram removidos.
- **Autoload `DecoracaoMundos`** (`scripts/mundo/decoracao_mundos.gd` + `data/decoracao_mundos.json`): decora por dados, sem editar cenas nem sistemas de outros agentes.
  - Portais animados (sprite billboard, luz e partículas) em toda `pedra_viagem` e todo `ponto_viagem`.
  - Cristais, pilhas de minério e lanternas nas masmorras, por tema (`minas_da_cinza`). Usa RNG próprio e não altera o gerador.
  - Neon, hologramas e faíscas na Estação Depois-de-Ontem.
  - Props, brasas, fumaça e luz tremulante em volta da Ferraria do Porto. O código da forja não foi tocado.
  - Para desligar: `ILHA_SEM_DECORACAO=1`.
- Monstros pixel nas masmorras: **não feito**. Não havia ponto seguro e só por dados sem mexer no combate.

## 3ª passada: tela inicial no estilo da referência do Thiago
- **Fundo:** a própria arte do Thiago em resolução cheia (1672x941), com a interface pintada removida. Preenche a tela em qualquer proporção (cover).
- **Animação do fundo:** Ken Burns lento (zoom entre 1,045 e 1,095 e deslocamento, ciclo de 36 s), brilho correndo nas 6 cachoeiras, sol pulsando, cinzas caindo e brasas subindo.
- **Reserva:** o fundo 3D do Mirante (`TituloVisual.fundo_3d`) só entra se a imagem não carregar.
- **Menu:** quatro placas separadas, cada uma com moldura dupla e ícone. No foco: borda dourada, brilho, chevron e leve deslize. Carregar jogo fica apagado sem save. A navegação por teclado e controle continua igual.

## 4ª passada: masmorra dos orcs (Minas da Cinza) consistente com a arena
- **Orcs:** os orcs da masmorra (grunt, besteiro, xamã, bruto e o chefe Brasa-Viva) usam o MESMO sprite pixel do orc da arena (`art/combate/orc`, filtro nearest, sem sombreamento). Tudo vem de dados: `"visual": "sprite_orc"` e `"tinta_sprite"` em `data/dungeon/temas.json`. O porte define o tamanho. O modelo 3D Quaternius só entra nos tipos sem sprite próprio.
- **Câmera:** a da masmorra agora é igual à da arena (yaw 45°, pitch 40°, tamanho ortográfico 15,5), então Vale e os orcs têm o mesmo tamanho na tela.
- **Decoração:** acampamento de guerra decorado por dados (`DecoracaoMundos`, `"acampamento_orc": true`), com RNG próprio e sem colisão. Fica fora das células ocupadas, então o gerador e os testes de layout não mudam.
  - Acampamento: tendas, fogueira, paliçadas, estandarte, armas e lenha.
  - Jaulas: gaiolas, ossadas, totem e paliçada.
  - Sala de guerra: mesa, estandartes, suportes de armas, escudo, totem, fogueira e tochas.
  - Covil do chefe: fogueiras grandes, 3 totens, estandartes e ossadas.
  - No andar todo: rochas escuras nas beiradas, manchas de lama, brasas e fumaça baixa.
- **Outros temas** (criptas e fenda): ganharam a mesma câmera da arena. Os inimigos continuam em 3D, porque não existe sprite pixel equivalente no projeto.
