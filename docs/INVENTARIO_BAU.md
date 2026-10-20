# Inventário da Vale e baú de madeira

Branch `bolorina/inventario-bau`, criada a partir de `integracao-2026-10-20` (a29dc92). Feita pela Bolorina em 20/10/2026.

## Como jogar

| Tecla | O que faz |
|---|---|
| **I** | Abre o inventário na última aba usada. Na primeira vez da sessão, abre em Equipamento, como a tecla I sempre fez. |
| **B** | Abre a mochila na aba Tudo. Na arena o B continua sendo "voltar". |
| **Select/Back** do controle | Abre a mochila. |
| Tab / Shift+Tab, PgDn / PgUp, LB / RB | Troca de aba. |
| Setas, WASD, direcional | Escolhem o item. Passar o mouse por cima também escolhe e mostra a dica (nome, descrição, quantidade e valor). |
| Enter, F, Espaço, botão A | Ação: colocar o baú, ir para Equipamento ou ir para Fabricar. |
| R, botão Y | Ordena por categoria, nome, quantidade ou valor. |
| C | Fabrica, na aba Fabricar. |
| I, B, Esc, botão B | Fecham. O jogo fica pausado enquanto o inventário está aberto. |

**Abas:** Tudo · Sementes · Colheitas · Materiais · Minérios · Pesca · Consumo · Missão · Ferramentas · **Equipamento** · **Fabricar**.

- **Equipamento** é a tela de equipar do Codex (`equipamento_tela.gd`), instanciada dentro da aba por um adaptador. Lá dentro continuam valendo as teclas dela: setas, Enter/F, X, Q/E e Espaço.
- **Ferramentas** traz as ferramentas fixas da barra, as ferramentas da forja (ex.: picareta de cobre) e as peças forjadas que ainda são só contagem.
- Durante uma incursão, o saque da masmorra aparece com a marca "(masmorra)". Não dá para mexer nele até voltar à superfície.

### Baú

1. **Madeira.** O machado já soltava madeira, e isso não mudou: galho +1, toco +3 e árvore 3 toras + 1 do toco.
2. **Fabricar.** Na aba Fabricar, escolha Baú de madeira e aperte C (ou Enter, ou o botão). O custo é **25 de madeira** (veja o balanço abaixo). O baú vai para a mochila como item.
3. **Colocar.** Use "Colocar baú", ou Enter com o baú escolhido na mochila. O inventário fecha e aparece um baú-fantasma na célula à frente da Vale (ou sob o mouse, igual ao cursor das ferramentas).
   - Verde quer dizer que dá para colocar ali.
   - Clique, E, J, Enter ou o botão A colocam. Esc, o botão direito ou o botão B cancelam.
   - Não dá para colocar em água, detrito, terra arada, cima da Vale, outro baú ou construção.
   - Funciona na fazenda, na fazenda grande e **dentro da casa da Vale**.
4. **Abrir.** Aperte E perto do baú. Em cima fica a grade de 36 espaços (pilhas de até 999) e embaixo a mochila.
   - Clique: move 1.
   - **Shift+clique: move a pilha toda.**
   - Botão direito: move metade.
   - Teclado: Enter move 1 e Shift+Enter move a pilha. Tab troca entre o baú e a mochila.
   - R ordena o baú e G guarda o que já existe nele ("guardar iguais").
5. **Recolher.** Abra o baú vazio e use "Recolher baú". Ele volta para a mochila. Com itens dentro, o botão fica desabilitado.
6. **Baú da casa.** O baú que já enfeitava a Casa da Vale agora guarda coisas: entre em casa e aperte E perto dele. Ele não pode ser recolhido.

Pode haver vários baús. Cada um tem a sua própria grade.

## Balanço do custo (25 em vez de 50)

A fazenda tem cerca de 85 de madeira no total: 30 galhos × 1, 9 tocos × 3 e 7 árvores × 4. As árvores **não voltam a crescer**, e a forja também usa madeira (receitas de 1 a 30). Com 50 por baú, só daria para fazer um único baú, e a forja ficaria sem madeira. Com 25, dá para 2 ou 3 baús e ainda sobra madeira para a forja. O valor fica em `data/fabricar.json`. Se as árvores passarem a crescer de novo, dá para subir para 50.

## Save

O save continua em `user://ilha_fazenda_v1.json`, na versão 1. Ele ganha:

- a chave nova **`baus`**: `[{"id", "area", "pos": [x,y,z], "rot", "fixo", "slots": [36 × {} ou {"id","q"}]}]`;
- o item `"bau"` dentro de `itens` (os baús que estão na mochila).

**Save antigo** (sem `baus`) carrega normalmente, com a lista vazia. Se uma entrada estiver quebrada, ela é normalizada e os itens válidos são mantidos.

As **peças de roupa e armadura não vão para o baú**, porque `Equip.normalizar()` recria as peças iniciais ao carregar e guardá-las duplicaria itens. As ferramentas da barra também não vão.

## Arquivos

**Novos:**
- `scripts/ilha/inventario.gd`: o modelo, com a lista agregada, os baús, as receitas, a colocação e o recolhimento.
- `scripts/ilha/inventario_tela.gd`: a interface do inventário e do baú.
- `scripts/ilha/equipamento_aba.gd`: o adaptador da tela do Codex.
- `scripts/ilha/baus_mundo.gd`: os baús no mundo, a colocação e o E para abrir.
- `data/fabricar.json`: as receitas.
- `art/ui/icones_fabricar/bau.png`: o ícone 16×16, desenhado por código em `tools/icone_bau.py`. É arte original, sem geração paga.
- `tests/inventario_bau_testes.gd` e `tests/inventario_bau_captura.gd`.
- `docs/INVENTARIO_BAU.md` e `docs/inventario_bau/*.png`.

**Alterados (pequenos):**
- `scripts/ilha/fazenda_estado.gd`: a chave `baus` no save.
- `scripts/ilha/jogo_ilha.gd`: o inventário no lugar da criação direta da tela de equipamento (`equip_tela` continua existindo e aponta para a aba), as teclas I e B e o `_colocar_baus()` ao entrar numa área.

**Não foram tocados:** `equipamento.gd`, `equipamento_visual.gd`, `equipamento_tela.gd`, `art/characters/vale_trajes/`, a forja, a missão, o tutorial, o eco temporal, a base de personagem e o criador de aparência, `main.tscn`, `reference_village`, `project.godot` e os arquivos-fonte originais.

## Para o Codex (sem urgência: o adaptador já funciona)

O adaptador (`equipamento_aba.gd`) usa `extends "res://scripts/ilha/equipamento_tela.gd"` e mexe em quatro coisas. Se a tela mudar, convém rever estes pontos:

1. **`_selo()`**: o adaptador sobrescreve para não criar o selo "I Equipamento" no HUD, porque o inventário mostra o dele. *Sugestão:* uma opção `mostrar_selo := true`.
2. **`raiz`**: o adaptador move o nó para dentro da aba e esconde o primeiro filho (o `ColorRect` de fundo de tela cheia). Ele também põe `raiz.mouse_filter = IGNORE`, para não engolir os cliques nas abas. *Sugestão:* `montar(g, est, embutida := false)`, que construiria sem o fundo e com o painel num `Control` que o inventário possa reposicionar. Hoje o painel está em posição absoluta (190, 92) e tamanho 1220×690, e o inventário foi desenhado em volta disso.
3. **`fechar()`**: a tela despausa o jogo. O adaptador pausa de novo quando o inventário continua aberto, ao trocar de aba. *Sugestão:* deixar a pausa com quem abre (um sinal `fechou` ou um parâmetro `pausar := true`).
4. **`_input()`**: a tela fecha com I/Esc. O adaptador deixa I/B/Esc/Tab/PgUp/PgDn e o controle com o inventário. *Sugestão:* emitir `pedir_fechar` em vez de fechar sozinha, e aceitar controle. Hoje o inventário traduz o direcional e o A/Y para `sel`, `vestir_sel()` e `girar()`.

Outros pontos:

5. **Se `Equip.ITENS` ganhar as peças forjadas** (`data/forja/itens.json`), elas saem da aba Ferramentas e vão para Equipamento sozinhas, porque `Inv.categoria` usa `Itens.eh_equip`.
6. **Testes do Codex**: `equipamento_testes` (97/97) e `equip_pixellab_captura` continuam usando `jogo.equip_tela` e a tecla I. Os dois funcionam porque a primeira abertura cai em Equipamento.
7. **Baú de roupas (futuro)**: se as peças puderem ir para o baú, `Equip.normalizar()` precisaria parar de recriar as `PADRAO`/`NOVAS` que a Vale guardou. Por exemplo, o save poderia marcar `"guardadas": [ids]`.
