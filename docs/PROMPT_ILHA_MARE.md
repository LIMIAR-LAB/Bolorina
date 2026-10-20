Você vai montar o mapa 3D da Vila Contracorrente, na Ilha da Maré do Tempo, para o jogo "Ilha das Cinzas" (Godot 4.7.2, 2.5D: cenário 3D, personagens em pixel art, câmera isométrica ortográfica fixa). O código do jogo já está pronto para receber o mapa: você só entrega a cena e os assets. Não escreva scripts de jogador, câmera ou NPC.

TEMA
O mar fica em cima: uma lâmina de água suspensa cobre o céu da ilha e sobe e desce como maré. A maré traz objetos de outras eras (navio viking, geladeira de 1987, robô que pede desculpas). Tom: comércio entre ilhas, lendas, viagem no tempo, humor absurdo de multiverso. Casas com telhado de casco de barco virado, cordas, redes, boias, engrenagens velhas, areia cinza.

LUGARES (de norte a sul; norte = -Z)
- Cais do Céu (norte): píer em espiral subindo até a água suspensa; doca do dirigível.
- Vila Contracorrente (centro): praça com relógio de sol que marca a maré; 6 a 8 casas; mercado.
- Praia dos Naufrágios (leste): areia com destroços de várias eras.
- Recife de Engrenagens (oeste): rochas com engrenagens fossilizadas (minério).
- Farol Invertido (sul): farol pendurado de cabeça para baixo na água de cima, luz apontando para o chão.
- Entrada da Gruta da Ampulheta (perto do farol): só a porta, a gruta é outra cena.

ENTREGA
1. scenes/ilha_mare_do_tempo.tscn (texto .tscn, Godot 4.7.2). É o caminho que o jogo já espera.
2. Assets em art/maps/ilha_mare/ (modelos .glb/.gltf, texturas). Só CC0 (Kenney, Quaternius, Poly Haven, KayKit). Escreva o crédito de cada pack em art/CREDITOS.md (seção "Ilha da Maré do Tempo").
3. (Opcional) dialogos/<id>.dialogue para os 8 moradores (Dialogue Manager 4.1.0), cada um com um título "~ start".
4. Um zip com essa mesma estrutura de pastas, para descompactar na raiz do projeto.

REGRAS DA CENA (o adaptador scripts/mundo/area_mapa_novo.gd depende disso)
- Raiz: Node3D chamado IlhaMareDoTempo. Escala 1 unidade = 1 metro; a Vale tem 1,72 m.
- Chão e paredes com colisão: StaticBody3D + CollisionShape3D (ou GridMap/CSG com colisão ligada). A Vale é um CharacterBody3D (cápsula de raio 0,3 m, altura 1,4 m) e anda pelo que tiver colisão. Rampas de até 35°; degraus de no máximo 0,3 m.
- Área andável de mais ou menos 80 x 80 m, com o chão da praça em y = 0. Bordas fechadas (penhasco, cerca ou água com colisão) para a Vale não cair da ilha.
- Não coloque: Camera3D, CharacterBody3D, scripts de jogador, AnimationPlayer de personagens, nem autoloads novos. Luzes, WorldEnvironment e partículas podem.
- Câmera do jogo: ortográfica, yaw 50°, pitch 28°, tamanho ~18 m, olhando do sudeste. Monte pensando nesse ângulo: ruas legíveis, nada alto ao sul dos caminhos que esconda a Vale, telhados que não cubram as portas.
- A lâmina de água de cima é só visual (sem colisão), a uns 18 m de altura.

MARCADORES (Node3D ou Marker3D, nomes exatos, no chão onde a coisa fica)
- SubstituirPeloSpriteDaVale: onde a Vale chega (perto do Cais do Céu). Pode ser uma cápsula, o jogo apaga e põe a Vale no lugar.
- npc_dona_nereida, npc_zezinho_sucata, npc_professora_eon, npc_marujo_bento2, npc_relojoeiro, npc_lumi, npc_tatu_dourado, npc_polvo_contador: um por morador, em frente da casa ou da banca de cada um (2 m livres em volta para a Vale chegar e apertar E).
- minerio_bronze_mare_1, minerio_bronze_mare_2, minerio_bronze_mare_3, minerio_ferro_1: no Recife de Engrenagens.
- achado_1 a achado_6: na Praia dos Naufrágios (coleta na maré baixa).
- banca_feira_1 a banca_feira_3: na praça (Feira das Eras).
- relogio_1 a relogio_4: em volta do relógio de sol da praça (quebra-cabeça do eclipse).
- spawn_vidro_1 a spawn_vidro_6: em volta da praça, a 8–12 m do centro (Tempestade de Vidro).
- bau_festival: ao pé do Farol Invertido.
- cais_do_ceu, recife_engrenagens, praia_naufragios, farol_invertido, gruta_ampulheta: um marcador no centro de cada lugar.

QUEM SÃO OS MORADORES (para a casa/banca combinar)
Dona Nereida (chefe, pescadora de céu), Zezinho Sucata (ferro-velho), Professora Éon (arqueóloga do tempo, gabinete com estantes), Bento-de-Outra-Linha (marinheiro de 1700, mesa de taverna), O Relojoeiro (oficina de relógios, perto da gruta), Lumi (faroleira, ao pé do farol), Tatu Dourado (mercador de outra era, banca colorida na praça), Contador (polvo contabilista, banco com balcão).
Os dados deles já existem em data/npcs/ilha_mare.json, as lojas em data/lojas/mare_*.json e os eventos em data/eventos/ilha_mare.json. Não mude esses arquivos.

COMO TESTAR ANTES DE ENTREGAR
- Abrir a cena no editor: sem erros de recurso faltando.
- Na raiz do projeto (PowerShell):
  $env:ILHA_AREA="ilha_mare"; & "<Godot 4.7.2>" --path . res://jogo_ilha.tscn
  A Vale deve aparecer no marcador de chegada, andar com WASD sem atravessar paredes, falar com cada morador com E e ver os minérios no recife. M abre o mapa-múndi.
- Conferir que todos os marcadores da lista existem com o nome exato.

NO FIM, RESPONDA COM
A lista de arquivos entregues, os packs CC0 usados (com link), o tamanho da área andável e qualquer marcador que você não conseguiu colocar.
