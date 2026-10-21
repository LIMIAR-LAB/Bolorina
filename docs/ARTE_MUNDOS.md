# Arte dos mundos — Bolorina (21/10/2026)

- **Música:** o autoload `Musica` (`scripts/audio/musica.gd`) escolhe a faixa pela cena: tela inicial → título; área do jogo → `data/musica.json` (por id da área, depois pela categoria, senão exploração); arena e masmorras → batalha. Troca com crossfade de 2 s. Usa o barramento "Musica", que manda para o Master, então segue o volume geral das Configurações. Na pausa o volume cai 6 dB. Outras cenas podem forçar uma faixa com `Musica.forcar("batalha")` e devolver o controle com `Musica.liberar()`. Para tirar o som em testes e capturas, use `ILHA_SEM_MUSICA=1`.
- **Mirante da Cascata:** área `mirante_cascata`, na primeira ilha, aberta pelo mapa-múndi. A cena fica em `scenes/mirante_cascata/` e o script em `scripts/mundo/mirante_cascata.gd`. Pisar no altar dourado ativa a câmera cinematográfica.
- **Tela inicial:** o fundo vivo, o logo e os botões vêm de `scripts/inicio/titulo_visual.gd`. O `menu_inicial.gd` só chama esse script; a lógica não mudou.
- **Props:** estão nos layouts `scripts/vila_grande/*_layout.json`, com `"origem": "bolorina_arte_mundos_2026-10-21"` (dá para tirar com um filtro).
- **Testes:** `tests/arte_mundos_testes.gd` (24 verificações). Capturas: `tests/arte_mundos_captura.gd`.
