# Estudo: mundo aberto na Ilha das Cinzas

19/10/2026 · **somente estudo**. Nada foi implementado nem alterado no código.
Base: Godot 4.7.2, Forward+, 1600×900, câmera ortográfica fixa (yaw 50°, pitch 28°, `size` 20), cenário 3D modular em grade de 1 m e personagens em sprite pixel art de 8 direções.

## 1. Como o jogo está hoje

| Item | Situação atual |
|---|---|
| Áreas | Fazenda (104 × 92 m), Vila V7 (77 × 73 m), Arena dos Orcs e Masmorra procedural, cada uma uma **cena separada** |
| Troca de área | `jogo_ilha.gd → ir(area, spawn)`: fade de saída, `queue_free` da área atual, `load()` **síncrono** da próxima e fade de entrada |
| Terreno | Grade de 1 m a partir de JSON (`vila_layout.json`, `fazenda_layout.json`) + kit modular (`kit_modular.gd`), com penhascos e degraus |
| Navegação | Lista de células andáveis (sem NavigationMesh) + `abismo_barreiras.gd` |
| Céu e distância | `horizonte_vivo.gd` (céu em canvas, ilhas que derivam, aurora 3D) faz o "longe" sem geometria real |
| Save | `user://ilha_fazenda_v1.json` (dia, canteiro, animais, amizade, área atual) |
| Instâncias | MultiMesh só em folhas/árvores e decoração. Peças do kit e cercas são, na maioria, nós individuais |

**Desempenho medido (arquivos já existentes, gerados no notebook pelos testes em 19/10):**

| Cena | GPU ms | CPU render ms | Process ms | Draw calls | Fonte |
|---|---|---|---|---|---|
| Vila V7 (efeitos ligados) | 4,89 | 1,41 | 11,42 | 2.293 | `docs/fid-perf-fase5.0.json` (`tests/fidelity_perf.gd`) |
| Vila V7 (efeitos desligados) | 4,22 | 1,35 | 9,06 | 2.210 | idem |
| Arena (luta, piloto automático) | 15,25 | 1,03 | 18,84 | 407 | `docs/combate-perf.json` |
| Arena (início de sala, pior quadro) | 16,08 (pior quadro 17,6) | 1,22 | 34,93 | 444 | idem |

Não rodei o teste de novo agora: o `tests/fidelity_perf.gd` grava em `docs/fid-perf-*.json`, o que fugiria da regra de escrever só estes dois documentos. GPUs do notebook "alien": **NVIDIA GeForce RTX 4050 Laptop** + Intel Graphics integrada.

**Hipóteses:**
- A Vila tem folga grande (cerca de 5 ms de GPU para 16,6 ms a 60 FPS). O gargalo provável é a **quantidade de draw calls** (mais de 2.200 numa área de 77 × 73 m) e o tempo de `process`.
- A Arena já fica perto do limite de 60 FPS por causa dos efeitos de combate. Ela deve continuar como cena separada em qualquer opção.
- Se duas ou três áreas desse tamanho forem carregadas ao mesmo tempo sem juntar malhas, os draw calls passam de 5.000 a 7.000, e é aí que um notebook sofre.
- Os números acima supõem que o Godot rodou na RTX 4050. Se rodar na Intel integrada (modo econômico do Windows/bateria), espere 2 a 4 vezes mais tempo de GPU. Confirmar no spike qual GPU o Godot usa.

## 2. O que a câmera fixa iso/ortográfica muda

- A câmera ortográfica com `size` 20 mostra cerca de 20 m na vertical × 36 m na horizontal. O **recorte da câmera já descarta quase tudo**, e o raio de streaming necessário é pequeno (2 a 3 chunks de 32 m em volta do jogador).
- Não existe "vista ao longe" de verdade, como num jogo em perspectiva. O grande atrativo do mundo aberto em 3D (ver a montanha e ir até ela) não aparece. O horizonte vivo já cumpre esse papel de forma barata.
- Num mapa ortográfico, a distância até a câmera é quase constante (cerca de 90 m). **LOD por distância e `visibility_range` funcionam pouco**: tudo que está na tela está "à mesma distância". O que funciona é carregar e descarregar pela **posição do jogador**.
- Os sprites de 8 direções não dependem do tamanho do mundo. Funcionam igual em área separada ou contínua.
- Referências:
  - **Link's Awakening**: mundo contínuo em telas/blocos, com interiores separados.
  - **Eastward**: áreas grandes ligadas por transições.
  - **Sea of Stars**: áreas separadas + **mapa-múndi** com mini-sprite, barco e voo.

  Os três parecem "mundo grande" sem streaming contínuo pesado. Um 3D contínuo estilo Zelda BotW pede câmera em perspectiva, que não é o caso aqui.

**Conclusão:** um jogo com esta câmera ganha pouco com o mundo contínuo **dentro** da ilha. Ganha muito mais com **conexões claras, transições rápidas e um mapa coerente**. O mundo aberto faz mais sentido **no céu**, onde a sensação de viagem é o objetivo.

## 3. Técnicas no Godot 4.7

| Técnica | Como usar aqui | Observação |
|---|---|---|
| **Chunks** | Dividir a ilha em blocos de 32 × 32 m (`chunk_x_z.tscn` ou JSON da grade + decoração). Manter carregados o chunk do jogador e os vizinhos | A grade de 1 m em JSON facilita fatiar. Precisa de uma ferramenta que corte o layout atual em chunks |
| **Carregamento em segundo plano** | `ResourceLoader.load_threaded_request(path)` → acompanhar com `load_threaded_get_status(path)` → pegar com `load_threaded_get(path)` | O `instantiate()` e o `add_child()` continuam na thread principal. Dividir a montagem em vários quadros (por exemplo, 200 peças por quadro) para evitar travadas. **Isso também serve para a opção A**: pré-carregar a próxima área quando o jogador chega perto da saída |
| **Origem flutuante** | Ao passar de cerca de 2 a 4 km do (0,0,0), deslocar tudo de volta para perto da origem | Ilhas de 100 m não precisam disso. Um arquipélago de vários km precisa (ou use **origem por ilha**: cada ilha é uma cena com origem própria e a viagem acontece numa "camada de céu"). A compilação `precision=double` do Godot exige compilar o motor, o que não vale a pena aqui |
| **LOD / visibility range** | Malhas de importação com LOD automático. `visibility_range_begin/end` com fade para as ilhas distantes no modo voo | Útil no **modo voo** (câmera afastada). Pouco útil a pé (ver a seção 2) |
| **HLOD por chunk** | Na exportação do chunk, juntar as peças estáticas em poucas malhas (por material) | Maior ganho possível, porque ataca os 2.200 draw calls |
| **MultiMesh** | Grama, seixos, folhas, postes de cerca e pedras da borda do abismo: um MultiMesh por tipo e por chunk | Já é usado em árvores e decoração. Estender para as peças do kit repetidas |
| **Oclusão** | `OccluderInstance3D` + `rendering/occlusion_culling/use_occlusion_culling` | Pouco valor com a câmera alta (quase nada tampa o resto). Não é prioridade |
| **Terreno** | Opção 1: **Terrain3D 1.0.2** (GDExtension, suporta Godot 4.4 a 4.7, clipmap, pintura e buracos, até 65 km). Opção 2: **grade modular de 1 m** (atual) | Terrain3D dá encostas suaves e áreas enormes, mas não combina com o visual de terraços, penhascos de bloco e caminhos de pedra da V7. Manter a grade e só fatiar. Terrain3D só faria sentido em ilhas "selvagens" grandes do arquipélago |
| **Navegação** | Hoje: células andáveis. Com chunks: um conjunto de células por chunk + `AStarGrid2D` por região. Se for NavigationMesh: um `NavigationRegion3D` pré-gerado por chunk, ligado pela margem de borda do `NavigationServer3D` | NPCs fora dos chunks carregados seguem a `agenda` de forma abstrata (posição por horário) e só ganham corpo quando o chunk carrega |
| **Save do mundo** | Base determinística (layout + semente) + **deltas por chunk**: `{chunk_id: {arvores_cortadas, pedras_quebradas, baus, portoes}}`, com versão do formato | Expande o `ilha_fazenda_v1.json` atual sem quebrar. Gravar o delta ao descarregar o chunk e no F5 |

## 4. Travessia entre ilhas

- **Planador (asas do adamantium)**: liga com o lore (ver `LORE.md`). Com a câmera a pé, planar de uma borda para uma ilha próxima (menos de 60 m) dá para fazer sem trocar de modo.
- **Dirigível**: um **modo voo**. A câmera ortográfica se afasta (`size` 20 → 60–80), as ilhas aparecem como versões leves e o mar de nuvens vira um plano com shader. Ao pousar, carrega a ilha completa em segundo plano. É o padrão Sea of Stars/Final Fantasy, barato e muito legível.
- **Pontes de luz**: caminhos 3D temporários (noites de aurora) entre ilhas pequenas. Precisam das duas pontas carregadas ao mesmo tempo, o que pede um streaming simples.
- **Barco da Marina / portais**: são transições clássicas. Encaixam na opção A.

## 5. Três opções

### A) Áreas separadas com transições (hoje, melhorado)
- **Prós:** risco baixo; aproveita tudo o que existe (Vila V7, Fazenda, Arena e Masmorra com efeitos próprios); cada área pode ter luz e efeitos ajustados; o save não muda.
- **Contras:** o mundo parece "picado". Os problemas que o usuário viu (caminhos pouco claros e entradas que às vezes não trocam de tela) são de **gatilho e sinalização**, não da arquitetura, mas aparecem mais nesta opção.
- **Esforço:** **1–2 semanas**.
  - Fase 1 (3–4 dias): gatilhos de saída maiores e confiáveis, trilhas e placas visíveis, mapa-múndi correto.
  - Fase 2 (2–3 dias): pré-carregamento em segundo plano da área vizinha, para a transição ficar abaixo de 0,3 s.
  - Fase 3 (2 dias): spawn coerente com a direção de saída.
- **Riscos:** baixos. O único é o mundo continuar parecendo pequeno.
- **Prototipar primeiro:** saída Vila → Fazenda com `load_threaded_request` quando o jogador entra no raio de 10 m da saída, medindo o tempo do fade.

### B) Ilha principal contínua com streaming de chunks
- **Prós:** sem telas de carregamento na ilha; dá para andar livre da fazenda às ruínas; NPCs se movem entre distritos; o mapa vira o mundo real.
- **Contras:** custo alto para pouco ganho visível com câmera ortográfica fixa. Fazenda e Vila hoje têm **ambiente, luz e efeitos diferentes** e precisariam de um ambiente único com zonas de mistura. O abismo, as barreiras e a névoa precisam ser reorganizados para uma ilha só. Interiores e Arena continuam separados.
- **Esforço:** **10–14 semanas**.
  - Fase 1 (2 sem.): formato de chunk + ferramenta que fatia as grades atuais.
  - Fase 2 (2 sem.): juntar Fazenda + Vila + Ruínas num sistema de coordenadas e costurar as bordas.
  - Fase 3 (2–3 sem.): streaming em segundo plano + montagem dividida em quadros + HLOD/MultiMesh por chunk.
  - Fase 4 (2 sem.): navegação/NPCs entre chunks + agenda abstrata.
  - Fase 5 (1 sem.): save por deltas.
  - Fase 6 (1–2 sem.): luz, efeitos e horizonte contínuos + abismo.
  - Fase 7 (1 sem.): QA de desempenho no notebook.
- **Riscos:** travadas ao instanciar; draw calls somados de várias áreas; regressão visual na Vila V7 (cena de fidelidade); bugs de borda de chunk (colisão e navegação); retrabalho de todas as cenas existentes.
- **Prototipar primeiro:** fatiar só a Vila em 4 chunks e andar de ponta a ponta medindo o pior quadro e os draw calls com e sem HLOD.

### C) Hubs separados + arquipélago aberto no céu depois de sair da ilha
- **Prós:** combina com o lore (Corrente Alta, dirigível, planador, pontes de luz). Mantém a Ilha das Cinzas como está, com qualidade alta e transições. O "aberto" vem onde a câmera afastada brilha: o céu com ilhas pequenas, que viram chunks naturais (cada ilha = uma cena). A origem por ilha resolve as distâncias grandes. Reaproveita o horizonte vivo (céu, ilhas flutuantes, aurora).
- **Contras:** exige um novo modo de controle e câmera (voo) e conteúdo para várias ilhas (o maior custo é arte). Os sistemas de save e de mundo precisam saber de várias ilhas.
- **Esforço:** **10–16 semanas** para o modo voo + 3 ilhas pequenas.
  - Fase 0 (1–2 sem.): opção A completa (base).
  - Fase 1 (2 sem.): modo voo (dirigível) + câmera afastada + mar de nuvens + versões leves das ilhas.
  - Fase 2 (2–3 sem.): pouso/decolagem com carregamento em segundo plano + origem por ilha + save por ilha.
  - Fase 3 (3–6 sem.): 3 ilhas pequenas com o kit modular (Ilha do Sino, Jardins Suspensos, ilhotas dos Ventos).
  - Fase 4 (1–2 sem.): planador e pontes de luz entre ilhas vizinhas + eventos (aurora).
  - Fase 5 (1 sem.): QA de desempenho.
- **Riscos:** custo de conteúdo; enjoo ou tédio no voo se o céu ficar vazio (pede eventos, ninhos e destroços); escopo crescer demais. O risco técnico é médio, porque as ilhas pequenas cabem no orçamento atual (menos de 2.000 draw calls por ilha).
- **Prototipar primeiro:** o modo voo com uma ilha real (Vila) + 2 ilhas de teste, pousando com carregamento em segundo plano.

### Comparação rápida

| | A (agora) | B (ilha contínua) | C (hubs + céu aberto) |
|---|---|---|---|
| Esforço | 1–2 sem. | 10–14 sem. | 10–16 sem. (inclui A) |
| Risco técnico | baixo | alto | médio |
| Ganho percebido com câmera ortográfica | médio (conserta a navegação) | baixo/médio | alto (viagem, descoberta) |
| Combina com o lore | sim | neutro | muito |
| Reaproveita o que existe | 100 % | precisa refazer as costuras | 100 % + ilhas novas |

## 6. Recomendação

1. **Agora: opção A.** Corrigir os gatilhos de entrada, deixar as trilhas e placas claras, corrigir o mapa-múndi e pré-carregar a área vizinha em segundo plano. Isso resolve as reclamações atuais em 1–2 semanas, sem risco.
2. **Depois de sair da ilha: opção C.** O mundo aberto vira o **arquipélago do céu**, com dirigível, planador e pontes de luz, onde a câmera afastada e o horizonte vivo rendem mais. Cada ilha é uma cena carregada em segundo plano, com origem própria.
3. **Não fazer a opção B** enquanto um teste com jogadores não mostrar que as transições dentro da ilha incomodam. Com câmera ortográfica fixa, o custo de 10+ semanas não se paga.
4. Ao mexer em cenas a partir de agora, preparar o terreno: dados de layout fatiáveis por chunk, malhas estáticas juntadas por área e save com deltas versionados. Assim B ou C ficam mais baratos depois.

## 7. Plano de protótipo (spike de 1–2 dias, não construído)

**Objetivo:** responder com números se (1) o carregamento em segundo plano elimina a espera das transições e (2) um modo voo com câmera afastada fica bom e leve no notebook.

**Dia 1: streaming e transição (serve para A e C)**
- Cena de teste isolada (`tests/spike_streaming.gd`), sem tocar nas cenas existentes.
- Com a Vila carregada, pedir `load_threaded_request("res://scripts/ilha/fazenda.tscn")` e medir o tempo até `THREAD_LOAD_LOADED`, o tempo de `instantiate()` + `add_child()` e o pior quadro durante o processo.
- Repetir montando em partes (N nós por quadro) e comparar.
- Medir os draw calls da Vila com as peças estáticas juntadas (cópia em memória, sem salvar).
- **Critério:** transição de área abaixo de 300 ms, nenhum quadro acima de 33 ms durante o pré-carregamento e redução de pelo menos 40 % nos draw calls com a junção de malhas.

**Dia 2: modo voo (C)**
- Cena de teste com mar de nuvens (plano + shader), 3 ilhas leves (silhuetas do `horizonte_base.png` em Sprite3D ou malhas simples) e um dirigível placeholder (caixa + sprite).
- Câmera ortográfica com yaw e pitch atuais e `size` 70. Ao chegar perto de uma ilha, aproximar a câmera para `size` 20 e carregar a cena da ilha em segundo plano.
- Medir FPS, pior quadro e memória no notebook (F3 / `Performance`) e gravar um vídeo curto para o usuário avaliar a sensação.
- **Critério:** 60 FPS estáveis em voo, pouso sem travada visível, leitura clara de para onde ir.

**Saídas do spike:** um JSON de medidas e um vídeo de 30 s. A decisão (A agora, C depois) é revista com esses números. Sem arte paga: tudo com placeholders e assets existentes.
