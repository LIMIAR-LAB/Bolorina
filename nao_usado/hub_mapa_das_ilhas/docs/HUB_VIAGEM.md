# Hub de viagem: Mapa das Ilhas (Bolorina)

PROPOSTA, construída só no box em `/workspace/bolorina_integrado`. Nada foi commitado. `main.tscn`, `reference_village`, os saves, o CronosMemories e o `project.godot` não foram alterados (sem autoload novo e sem plugin novo).

## Mapa-múndi "real"
Procurei o mapa-múndi bonito que o Thiago já tinha visto e **não achei em lugar nenhum do box**: nada em cenas, pastas antigas, docs nem capturas, e nada no GitHub LIMIAR-LAB/Bolorina, que só tem um commit inicial sem mapa. Ele provavelmente está no PC do Thiago. Por isso o mapa novo foi feito do zero em `scenes/ui/mapa_mundi.tscn`. Se o antigo aparecer no PC, fica ao lado deste; os dois leem `data/areas.json`.

## Áreas (data/areas.json v2, `hub: porto_velho`)
| id | cena | chegada pelo mapa | saída |
|---|---|---|---|
| porto_velho | scenes/vila_grande/vila_grande.tscn | doca do dirigível (44.2, 0) | doca / M |
| fazenda_do_alto | scenes/mundo/ilha_viagem.tscn (area_interna fazenda) | totem da fazenda | totem / M / caminho leste → vilarejo |
| vila_da_ilha | ilha_viagem (vila) | totem da praça | totem / M / caminhos → fazenda e arena |
| arena_das_cinzas | ilha_viagem (arena) | totem da arena | totem / M / volta à vila |
| vila_orcs | scenes/vila_orcs/vila_orcs.tscn | totem (1.32, 36.24) | totem / M / boca do veio → Minas |
| cidade_fantasma | scenes/cidade_fantasma/cidade_fantasma.tscn | Lanterna dos Caminhos (-0.68, 21.74) | lanterna / M / portão → Criptas |
| estacao_depois_de_ontem | scenes/ilha_futurista/ilha_futurista.tscn | plataforma do dirigível (38.2, -1) | plataforma / M / fenda → Fenda Cronal |
| minas_da_cinza | scenes/dungeon/minas_da_cinza.tscn | andar 1 | saída para a origem (elevador) / M |
| criptas_de_cinzalta | scenes/dungeon/criptas_de_cinzalta.tscn | andar 1 | saída para a origem / M |
| fenda_cronal | scenes/dungeon/fenda_cronal.tscn | andar 1 | saída para a origem / M |

**Cinzalta** é a Cidade Fantasma (a antiga capital), como dizem os docs. A ilha (fazenda, vila e arena) usa `ilha_viagem.tscn`, que estende `jogo_ilha.gd` sem editá-lo e escolhe a sub-área pela chegada pendente do registro.

Campos novos por área:
- `chegada_mapa`: o ponto usado quando se viaja pelo mapa.
- `ponto_de_viagem {tipo dirigivel|totem, pos, ang, rotulo}`
- `mapa {pos, raio, rotas, ligada_a, desbloqueio, hub, cachoeiras}`

`fora_do_mapa` lista, com o motivo, toda cena .tscn de mapa que ficou de fora.

Desbloqueio padrão:
- Liberadas desde o início: Porto Velho, Fazenda, Vilarejo e Arena.
- Visitar Porto Velho libera Orcs, Cidade Fantasma, Estação e Minas.
- Visitar a Cidade Fantasma libera as Criptas.
- Visitar a Estação libera a Fenda Cronal.

## Mapa das Ilhas (scenes/ui/mapa_mundi.tscn + scripts/mundo/mapa_mundi.gd)
- **Ilhas:** cada uma é flutuante, com a ilustração de `art/ui/telas/<id>.png`, rocha por baixo, cachoeiras, placa com o nome, cadeado quando bloqueada e o pino "Você está aqui".
- **Rotas:** as rotas de dirigível são tracejadas e as passagens para masmorras são pontilhadas; há dirigíveis passando ao fundo e animação de voo ao viajar.
- **Painel:** mostra arte, nome, tipo·região, descrição, estado (liberada, bloqueada com o requisito, ou "você está aqui"), rotas e entradas (ou andares e profundidade, no caso de masmorra) e os botões "✈ Viajar" / "Descer ↓".
- **Controles:**
  - M abre e fecha o mapa em qualquer área; ele aparece por cima do jogo e pausa a cena.
  - ←→/WASD/Tab escolhem a ilha; Enter/Espaço ou clique duplo viajam; Esc fecha.
  - U libera tudo (dev).
- **Ponto físico:** cada cidade tem um ponto de viagem (doca de dirigível ou totem) com "[E] Viajar" que abre o mapa. As 3 áreas da ilha ganham um totem por código, em `ilha_viagem.gd`.
- **Arte:** `tools/hub_telas.py` gera as ilustrações da fazenda, do vilarejo e da arena e refaz as das cidades a partir das previews limpas. As artes antigas estão no backup.

## Arquivos
Novos:
- `scripts/mundo/viagem.gd`, `viajante.gd`, `mapa_mundi.gd`, `ponto_viagem.gd`, `ilha_viagem.gd`
- `scenes/ui/mapa_mundi.tscn`, `scenes/mundo/ilha_viagem.tscn`
- `shaders/mapa_ceu.gdshader`, `shaders/mapa_bloqueada.gdshader`
- `art/ui/telas/{fazenda_do_alto,vila_da_ilha,arena_das_cinzas}.png`, mais as 4 de cidade refeitas
- `tools/hub_telas.py`, `tests/hub_testes.gd`, `tests/hub_captura.gd`

Alterados (com backup):
- `data/areas.json` (passou para a v2)
- As 4 cenas de cidade: entrou só um nó `PontoViagem` e o ext_resource dele.
- `scripts/dungeon/masmorra.gd`: uma linha no `_ready` que instala o viajante, para a tecla M funcionar na masmorra.

## Testes
`flock /workspace/.godot.lock godot --headless --path . -s res://tests/hub_testes.gd` deu **208 verificações e 0 falhas**. Dá para rodar só algumas seções com `HUB_TESTE_SO=registro,cenas,mapa,viagens`.

Para cada área, o teste parte da doca do hub, abre o mapa e clica em Viajar. Depois confere:
- a chegada no ponto do registro;
- que a jogadora está no chão (`is_on_floor` ou raycast no chão), sem queda, fora de colisor e no navmesh, com caminho até o spawn ou a escada;
- que existe saída (ponto de viagem, saída para a origem, saída a pé ou B/Esc);
- a volta ao hub e a chegada no ponto certo (distância de volta: 0.0 m).

O teste também cobre o registro, o carregamento das cenas, a montagem do mapa (ilhas, rotas, cadeados, painel) e a tecla M.

**Varredura de órfãs:** nenhuma cena de mapa ficou sem estar no mapa ou em `fora_do_mapa`. O que vale registrar:
- As 5 cenas estáticas antigas de `scenes/minas_da_cinza/` (minas_da_cinza + andares 01, 04, 09, 20) são becos sem saída: não têm volta para Porto Velho e foram substituídas pela masmorra procedural. Ficaram fora do mapa.
- `main.tscn`, `reference_village`, `fidelity_village`, `articulated_comparison` e `jogo_ilha.tscn` são laboratórios ou lançadores antigos.
- `combat_arena`, `fazenda.tscn` e `vila_jogo.tscn` só existem dentro da ilha.
- `forja_ui` e `prototipos/eco` são do outro executor e estão em andamento.

Regressões (uma por vez, 20/10 03:03 UTC-3): dungeon 293/0, ilha_areas 6/0, minas_da_cinza 154/0, ilha_futurista 102/0, forja 52/0, mapas_dialogos 314/0, dialogos 126/0, fazenda 27/0.

Capturas: `HUB_CAPTURA=/pasta godot --path . -s res://tests/hub_captura.gd`. Trecho de vídeo: `HUB_TOUR_SEG="porto_velho>vila_orcs" ... --write-movie x.avi --fixed-fps 30`.
Previews em `previews/`. O vídeo `previews/tour_viagem_1024x576.mp4` (~20 s) faz Porto Velho → Vila dos Orcs → Cidade Fantasma → Criptas de Cinzalta → Estação Depois-de-Ontem, gravado em 4 trechos e acelerado 1.35x. Algumas fotos de ponto de viagem (porto, orcs, estação, fazenda) são de antes de o prompt virar "[E] Viajar" e ainda mostram "[E] Mapa das Ilhas".

## Ganchos para o Claude ligar no jogo principal
1. **Entrada:** o jogo principal ainda não chama o hub, porque `main.tscn` não foi tocado. Para ligar, use `Viagem.garantir_viajante(get_tree())` uma vez (no boot ou no `_ready` de cada mapa) e `Viagem.ir(get_tree(), "porto_velho")`.
2. **Save:**
   - Guardar e carregar `Viagem.visitadas` (um Dictionary id→true).
   - `Viagem.ao_viajar = func(de, para, ponto): salvar()` roda antes de trocar de cena, para não perder inventário, missão e equipamento.
3. **Desbloqueio:** `Viagem.provedor_desbloqueio = func(id, regra) -> int` devolve 1 para liberar, 0 para bloquear e -1 para usar a regra do JSON. Serve, por exemplo, para a cartógrafa ou missões liberarem teleportes.
4. **Ilha:** para entrar na ilha pelo hub, use `ilha_viagem.tscn` no lugar de `jogo_ilha.tscn`; ela tem a mesma lógica e o save `ILHA_SAVE` de sempre.
5. **Vale:** os mapas CC0 ainda usam a cápsula `SubstituirPeloSpriteDaVale`. Ao trocar pela Vale, mantenha o nó jogador como CharacterBody3D, porque o viajante o posiciona pelo ponto do registro.
6. **Sinais do viajante** (nó `/root/Viajante`): `mapa_aberto`, `mapa_fechado` e `chegou(area, ponto)`. As masmorras usam `Sessao.iniciar`/`encerrar` automaticamente quando se viaja.
7. **Tecla M:** fica desligada quando a cena tem `demo_mode == true`. Se o jogo principal já usar M, troque em `viajante.gd` (`_unhandled_key_input`).
