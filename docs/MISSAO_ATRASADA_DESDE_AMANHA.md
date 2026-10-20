# Missão "Atrasada desde amanhã" e tutorial: roteiro e integração

> **PROPOSTA, não é canon.** A missão segue o plano aprovado pelo Thiago. Vale explora o mundo onde o tempo quebrou e traz de volta coisas que mudam Porto Velho. A forja muda o jeito de lutar, as descobertas mudam a cidade e os moradores dão motivos pessoais.

Duração estimada: **30 a 45 min**.

Arquivos:
- dados: `data/missoes/atrasada_desde_amanha.json`
- falas: `dialogos/missao_atrasada/*.dialogue`
- máquina de estados: `scripts/missoes/missao.gd`, `scripts/missoes/gerenciador_missoes.gd`, `scripts/missoes/condicoes.gd` e `scripts/missoes/seletor_dialogos.gd`
- testes: `tests/missao_testes.gd`

## A ideia em uma frase

O Gaspar recebe uma multa por atrasar uma peça que ele ainda não fez. O defeito descrito no papel começa a acontecer de verdade no guindaste da doca. A Vale desce às Minas da Cinza, aprende o **eco temporal**, recupera a peça (feita pelo próprio Gaspar, amanhã) e volta para uma cidade que reage.

## Etapas

| # | id | Objetivo na tela | Termina quando |
|---|---|---|---|
| 1 | `conta_impossivel` | Fale com Gaspar Bigorna na Ferraria do Porto. | `atrasada_conta_lida` (Gaspar, cue `conta_impossivel`). Cena: Brida entrega o envelope. Recebe **Conta Impossível** (item de missão). |
| 2 | `ver_guindaste` | Vá até o guindaste da doca e confira o defeito descrito na conta. | `atrasada_defeito_visto` (interação `guindaste_doca`, cue do Capitão). Mundo: `guindaste_rachado`. |
| 3 | `reforco_arma` | Volte à Ferraria e faça o primeiro reforço do Facão da Fazenda na bigorna. | `atrasada_gaspar_explicou_minas` + evento `forja_reforco_feito(facao_fazenda)`. Troca a arma por `facao_fazenda_eco`, marca `eco_desbloqueado` e libera o eco base. |
| 4 | `provisao_fazenda` *(opcional)* | (Opcional) Passe na fazenda e escolha uma provisão. | Nabo assado, óleo de lampião ou chá de raiz-de-brasa (`cesto_provisoes`). **É pulada** quando a Vale chega à mina, e esse mesmo evento conta para a etapa seguinte. |
| 5 | `minas_entrada` | Desça pelo Elevador do Tião e vença os Lodos Casca-Grossa usando o eco. | `chegou_area(minas_andar_1)`, 1× `eco_acertou(lodo_casca_grossa)` e 3× `inimigo_derrotado(lodo_casca_grossa)`. O lodo endurece 0,25 s depois de apanhar e amolece 0,45 s depois, que é exatamente quando o eco base (0,6 s) acerta. Dá 5 Minérios de Cobre e 1 Carvão. |
| 6 | `bifurcacao` | No andar 2, siga o trilho ou arrisque a Galeria Desabada. | `chegou_area(minas_andar_4)`. A escolha fica em `atrasada_caminho_seguro` ou `atrasada_caminho_arriscado`, pela placa ou pela Dona Vagoneta. |
| 7 | `bate_estaca` | O Bate-Estaca repete os mesmos 3 segundos. Use o eco para acertar as 3 travas. | 3× `trava_acertada_eco(bate_estaca)` e `item_coletado(catraca_mestra)`. A trava só quebra com o eco: o golpe direto é empurrado de volta, porque "o mecanismo lembra". Dá 3 Lascas de Eco. Toca a fala do Zeca, `sexta_feira`. |
| 8 | `voltar_ao_porto` | Volte a Porto Velho com a Catraca-Mestra. | `chegou_area(porto_velho)` e marca `primeira_expedicao_voltou`. |
| 9 | `entregar_peca` | Entregue a Catraca-Mestra ao Gaspar. | Item de missão `catraca_mestra` + `atrasada_peca_entregue`. Consome a catraca e os **3 Minérios de Cobre reservados**. |
| 10 | `escolher_eco` | Use o excedente na forja: escolha Eco rápido ou Eco pesado. | `atrasada_eco_rapido` ou `atrasada_eco_pesado`. Custa 3 Lascas de Eco e 2 Minérios de Cobre **do excedente**. Sem material, o Gaspar faz fiado (`atrasada_eco_fiado`), então a missão nunca trava. |
| 11 | `testar_arena` | Teste o eco novo na Arena das Cinzas: acerte 3 inimigos com o eco. | `chegou_area(arena_das_cinzas)` + 3× `eco_acertou`. O tutorial do mapa e do teleporte entra aqui. |
| 12 | `religar_guindaste` | Volte à doca: o Capitão Nuvem vai religar o guindaste. | `atrasada_guindaste_ligado`. Mundo: `guindaste_funcionando`, `carga_movida`, `passagem_armazem_aberta` e `encomenda_estacao_apareceu`. Recebe a caixa do vidro e a **Encomenda para a Estação Depois-de-Ontem**. |
| 13 | `entregar_vidro` | Leve a caixa frágil para Dona Rosalva. | `atrasada_vidro_entregue`. Mundo: `lanterna_vidro_novo`. |
| 14 | `arquivar_conta` | Conte ao Gaspar como ficou o guindaste. | `atrasada_conta_arquivada`. Mundo: `conta_emoldurada`. Marca `gancho_estacao_depois_de_ontem`. |

**Recompensas finais:**
- 120 de ouro e 2 Lingotes de Cobre.
- Confiança: ferreiro +2, capitão +2, Tião +1, Rosalva +1.
- Desbloqueia `forja_variacoes_eco` e `rota_estacao_depois_de_ontem`.
- Marca `missao_atrasada_concluida`.

### Objetivos opcionais
- **Ferrugem fresca** (`pista_da_mira`, da etapa 2 à 14): a Mira cheira a conta e pede uma amostra. A Vale raspa a ferrugem do guindaste (`atrasada_amostra_raspada`), e a Mira reconhece a investigação (`atrasada_pista_confirmada`) e dá 1 Essência de Raiz-de-Brasa. Só aparece se a Vale já conhecia a Mira.
- **Material extra** (`galeria_desabada`, etapas 6 e 7): 6 morcegos e o baú `bau_galeria_desabada` dão +4 de cobre, +3 lascas e +2 de carvão.
- **Recado de uma quinta-feira** (`recado_do_zeca`, persistente): o recado do Zeca chega ao Tião (`tiao_recebeu_recado`). Mundo: `lamparina_andar_4`.

### Itens obrigatórios separados do excedente
- **Itens de missão:** `conta_impossivel`, `amostra_ferrugem`, `catraca_mestra`, `caixa_vidro_lanterna` e `encomenda_estacao` (tipo `missao` ou `documento`) ficam em `itens_missao` e **nunca** entram em `pode_gastar()` nem em `gastar_excedente()`.
- **Reserva:** enquanto a missão está ativa, **3 Minérios de Cobre ficam reservados** para o acabamento da catraca. Com 5 cobres, por exemplo, 3 ficam reservados e 2 viram excedente. A forja e as lojas só enxergam o excedente.
- O caminho seguro garante o material exato para o eco (2 cobres e 3 lascas). O caminho arriscado deixa sobra.

## O eco temporal

O golpe pesado, que é o 3º do combo, deixa um **eco**. No mesmo lugar, um instante depois, ele repete o golpe. Com isso a Vale pode bater e sair: o eco termina o serviço.

| Variação | Atraso | Dano | Raio | Extra |
|---|---|---|---|---|
| Eco (base, primeiro reforço) | 0,6 s | 60% | 1,6 m | — |
| **Eco rápido** | 0,35 s | 45% | 1,6 m | acerto do eco tira 0,1 s da recarga do dash |
| **Eco pesado** | 0,9 s | 100% | 2,2 m | quebra postura (conta como golpe pesado) |

Os dados estão em `variacoes_eco` no JSON. O gerenciador emite `variacao_eco_alterada(id, dados)`, e o combate só precisa ler esses números.

## Ganchos para o Claude ligar

O `GerenciadorMissoes` é um `Node` independente. Pode virar autoload, ou ficar como filho do jogo:

```gdscript
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")
const Tutorial = preload("res://scripts/tutorial/tutorial.gd")
var missoes = Gerenciador.new()          # usa EstadoDialogos.global()
var tutorial = Tutorial.new()
func _ready():
	add_child(missoes); add_child(tutorial)
	missoes.tutorial = tutorial
	tutorial.notificar("jogo_iniciado")
```

**Eventos que o jogo manda** (`missoes.notificar(evento, alvo, qtd)` e `tutorial.notificar(...)`; pode mandar para os dois):

| Evento | Alvo | Quem manda |
|---|---|---|
| `chegou_area` | `porto_velho`, `fazenda`, `minas_andar_1`..`_4`, `arena_das_cinzas` | troca de cena ou mapa-múndi (`missoes.chegou_area(x)`) |
| `perto_de` | `crianca_praca`, `elevador_tiao` | Area3D |
| `golpe_acertou` / `golpe_pesado` / `esquivou` | `sir_palha` ou id do inimigo | combate |
| `eco_acertou` | id do inimigo (`lodo_casca_grossa`, `poste_treino`...) | combate, no acerto do eco |
| `inimigo_derrotado` | `lodo_casca_grossa`, `morcego` | combate |
| `trava_acertada_eco` | `bate_estaca` | mecanismo do andar 4 |
| `bau_aberto` | `bau_galeria_desabada` | baú |
| `forja_aberta` / `forja_reforco_feito` / `forja_item_feito` | id da arma | interface da forja |
| `jogo_salvo`, `mapa_aberto`, `mapa_liberado`, `teleportou` | — | save e mapa-múndi |
| `item_coletado` | id | use `missoes.coletar_item(id, n)`, que soma e notifica |

**Funções:**
- `dialogo_para(npc_id) -> {arquivo, cue, origem}`. Vazio quer dizer que vale o padrão. Isso precisa entrar em `interacao_npcs.conversar()`, que hoje não editei: `var d = missoes.dialogo_para(id); if d: caixa.iniciar(load(d.arquivo), id, d.cue)`.
- `interacao(alvo_id) -> {arquivo, cue, npc}` para objetos: `guindaste_doca`, `cesto_provisoes` e `placa_bifurcacao`.
- `adicionar_item(id, n)` para minério minerado, loja e similares. Antes de a forja gastar, chame `pode_gastar(custo)` e `gastar_excedente(custo)`. `itens_reservados()` informa à interface o que mostrar como travado.
- `cenas_disponiveis(periodo)` devolve as cenas de ambiente. Depois de tocar uma, chame `cena_vista(id)`. Defina `missoes.periodo = "manha" | "tarde" | "noite"` pelo relógio do jogo.
- `objetivo_atual()` dá o texto do HUD. `salvar()` e `carregar()` usam `user://missoes_estado_v1.json`, um arquivo próprio que não toca no save da fazenda.

**Sinais que o jogo escuta:**
- `etapa_iniciada(missao, etapa, objetivo, dica)` e `objetivo_atualizado(missao, texto)` → HUD
- `mudanca_mundo(id, dados)` → animar o guindaste, mover caixas, remover a colisão do beco, mostrar a encomenda, a moldura e a lamparina (alvos sugeridos em `mudancas_mundo`)
- `arma_trocada(de, para)` e `variacao_eco_alterada(id, dados)` → combate
- `provisao_escolhida(id, dados)` → buff na mina
- `dialogo_pedido(npc, arquivo, cue)` → abrir a caixa (falas depois de etapas, como `reforco_pronto`, `sexta_feira` e `fim_teste`)
- `cena_ambiente_pedida(id)`, `missao_iniciada`, `missao_concluida(id, recompensas)`, `opcional_iniciado`, `opcional_concluido`, `desbloqueado(o_que)`, `item_missao_alterado` e `material_alterado`

**Tutorial (`scripts/tutorial/tutorial.gd`):**
- sinais `passo_iniciado(id, dica)`, `dica_alterada(texto)`, `passo_concluido`, `passo_pulado`, `dialogo_pedido(npc, arquivo, cue)` e `tutorial_concluido(pulado)`
- funções `iniciar()`, `notificar()`, `pular_passo()`, `pular_tudo()`, `dica_atual()` e `dialogo_para(npc)`

**O que ainda falta no jogo** (não fiz porque esses arquivos estão com outros):
- o combate emitir `eco_acertou` e desenhar o eco
- o Lodo Casca-Grossa (vida 40, casca 0,45 s)
- o Bate-Estaca no andar 4 (ciclo de 3 s, fases em `mecanismo`)
- o boneco Sir Palha na praça
- o cesto da fazenda
- a placa do andar 2
- a interface da forja chamar `pode_gastar`
- as mudanças de mundo nas cenas
- o elevador só descer depois de `eco_desbloqueado` (o evento de chegada só conta com a etapa certa ativa)

## Tutorial (`data/tutorial/tutorial.json`, `dialogos/tutorial/*.dialogue`)

Curto, ensinado fazendo, e dá para pular de três jeitos: pela opção "Já conheço Porto Velho" no primeiro diálogo, com `pular_passo()` ou com `pular_tudo()`.

| Passo | Gatilho | Dica na tela | Conclusão |
|---|---|---|---|
| abertura | `jogo_iniciado` | — (cena: a Andorinha chega; o Pipo pintou "BEM-VIMDA VALE" e o gato dorme no "VIMDA") | `tut_abertura_vista` |
| mover | imediato | WASD ou setas para andar. Vá até a faixa na praça. | `perto_de(crianca_praca)` |
| conversar | imediato | Aperte E perto do Pipo. | `tut_conversou` |
| atacar | imediato | J ou clique esquerdo no Sir Palha; o 3º golpe é pesado. | 3 acertos + 1 golpe pesado |
| esquivar | imediato | Quando o Sir Palha girar, Espaço ou Shift. | `esquivou(sir_palha)` → `tutorial_basico_concluido` (a missão começa) |
| forja | o Gaspar explica ou `forja_aberta` | Receita à esquerda, comparação à direita (verde = melhor), confirmar. | `forja_reforco_feito` ou `forja_item_feito` |
| eco | `eco_desbloqueado` | Golpe pesado deixa um eco. Bata e saia. | 1× `eco_acertou` (o poste da Ferraria serve) |
| salvar | perto do elevador ou na mina | F5 salva; dormir na Estalagem também. | `jogo_salvo` |
| mapa | escolheu o eco ou `mapa_liberado` | M abre o mapa; escolha a Arena das Cinzas. | `mapa_aberto` + `teleportou` |

As teclas M (mapa) e F5 (salvar) são sugestões: troque o texto da dica se o jogo usar outras.

## Testes

`godot --headless --path . -s res://tests/missao_testes.gd`

O teste cobre:
- todo `.dialogue` novo compila, está importado e só usa falantes do registro
- as 80 referências `{arquivo, cue}` dos JSON existem
- 200 ramos são percorridos até o fim
- as 45 marcas citadas são todas marcadas em algum lugar
- a missão roda inteira em 3 caminhos (seguro com eco rápido e tutorial completo; arriscado com eco pesado, pista da Mira e provisão; fiado), usando as conversas de verdade
- a separação entre itens obrigatórios, reservas e excedente
- o tutorial completo, pulado inteiro, pulado por passo e pulado pela escolha no diálogo
- seletor, memória da cidade, cenas, save e load

Os testes antigos continuam passando: `dialogos_testes` (126), `mapas_dialogos_testes` (314) e `minas_da_cinza_testes` (154).
