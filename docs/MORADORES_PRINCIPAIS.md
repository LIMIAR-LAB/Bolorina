# Moradores principais de Porto Velho

> **PROPOSTA, não é canon.** Os nomes, a filha da Rosalva (Lia), o Zeca como parceiro do Tião, a Repartição de Prazos, o Contrato de Penumbra e os dois Jucas são sugestões. Canon do repositório: Porto Velho, a Mira, o ferreiro, os orcs, a Arena das Cinzas e Cinzalta.

Seis moradores com desejo, contradição, rotina, relação, situação e mudança. Os dados estão em `data/missoes/moradores_principais.json`. As falas de rotina e de memória ficam em `dialogos/reacoes/<id>.dialogue`, e as da missão em `dialogos/missao_atrasada/`. Quem escolhe a conversa certa é o `scripts/missoes/seletor_dialogos.gd`, pelo `GerenciadorMissoes.dialogo_para(id)`.

**Três deles estão na missão principal** "Atrasada desde amanhã": Gaspar, o Capitão Nuvem e o Seu Tião. A Mira participa de um objetivo opcional, a Rosalva do fechamento e a Brida da abertura.

## Resumo

| Morador | Quer | Contradição | Depois da missão |
|---|---|---|---|
| **Gaspar Bigorna**, ferreiro | Nunca atrasar. Estar à altura do avô, que forjava para os Arquimagos. | Tem pavor de metal que "sussurra horários", mas vive para o relógio. Os juros da multa o ofendem mais do que o tempo quebrado. | Emoldura a conta ("Arquivo, amanhã"), abre um caderno de encomendas futuras e libera as variações do eco. Se o recado do Zeca chegar, perdoa a primeira dívida em 31 anos. |
| **Mira**, herbalista | Provar que a cinza é remédio, e entender o que ela é. | É a pessoa mais curiosa do porto e nunca sai de Porto Velho. Manda os outros buscarem amostras. | Descobre que a cinza também é tempo que ainda vai acontecer. Começa um "mapa do tempo" e pede amostras de cada ilha. |
| **Dona Rosalva**, estalajadeira | Que todo mundo que sai volte, inclusive a filha Lia, navegadora desde a semana da Queda. | Diz que "não espera nada de ninguém" e passa a vida esperando, com uma lanterna que nunca apaga e um prato a mais na mesa. | Lanterna com vidro novo e luz mais clara. Regra nova: "quem volta de mina come primeiro, de graça". A mesa reservada ganha um bilhete também para a Vale. |
| **Capitão Bartolomeu Nuvem** | Reabrir a rota e ficar rico, "nessa ordem, se possível". | Se gaba de não ter medo de nada e não sai da doca há meses. O guindaste quebrado é a desculpa para não encarar o pedágio do dragão. | Descarrega a Andorinha, troca o "talvez" do mapa por "Estação Depois-de-Ontem" e marca a viagem. |
| **Brida Ferrolho**, guardiã | Ordem. No fundo, ser querida e contar uma piada que funcione. | Aplica regras que ela mesma acha absurdas, porque "desde a Queda, normal é o que tem carimbo". | Cria o carimbo "RECEBIDO ANTES DE ENVIADO", atualiza o formulário 7-B, resolve o caso dos ratos do armazém e conta a primeira piada boa. |
| **Seu Tião Lamparina**, mineiro do elevador | Que ninguém mais se perca na mina como o Zeca. | Faz piada com a mina o dia inteiro e há 32 anos não passa do andar 3. | Volta a descer, pendura uma lamparina no andar 4 e pinta "Elevador Tião e Zeca". |

## Fichas

### Gaspar Bigorna (ferreiro, `ferreiro`)
- **Relação:** é amigo e rival do Seu Tião há vinte anos. Toda noite os dois discutem se o rangido do elevador vem da polia, que é dele, ou do cabo, que é do Tião. O Zeca morreu devendo três lingotes para ele.
- **Situação que a Vale muda:** a Conta Impossível. A Vale traz da mina a catraca que ele mesmo vai fazer amanhã.
- **Rotina:**
  - **manhã:** acende a forja, que pega no terceiro sopro, e não atende antes do café.
  - **tarde:** martela e atende.
  - **noite:** fica na porta polindo o martelo do avô e discutindo com o Tião.
  - **depois da missão:** a conta fica emoldurada na parede.
- **Memória da cidade:** comenta a dívida do Zeca, a conta emoldurada e o eco que "não pode começar a repetir conversa".

### Mira (`mira`)
- **Relação:** recebe ervas da Dona Iolanda pelo Pipo, e as duas brigam por bilhete sobre o alecrim (cena "Alecrim ofendido").
- **Situação:** a tinta da conta tem cinza de amanhã, com cheiro de chuva que ainda não caiu. Ela pede à Vale uma amostra da ferrugem do guindaste. É o objetivo opcional "Ferrugem fresca".
- **Rotina:**
  - **manhã:** peneira cinza para os canteiros.
  - **tarde:** fica no balcão misturando essências.
  - **noite:** deixa a janela entreaberta e anota o que o vento conta.
  - **depois da missão:** guarda o frasco "Amanhã, nº 1".
- **Memória da cidade:** percebe o facão "cheirando a cinza fresca", o pó do andar 4 no ombro da Vale e, depois, **reconhece que a Vale investigou a pista dela**, no cue `pista_reconhecida`.

### Dona Rosalva (`estalajadeira`)
- **Relação:** é amiga de infância da Brida, que toda noite conta treze lanternas acesas por causa dela e nunca a multa (cena "O Contrato de Penumbra").
- **Situação:** o vidro novo da lanterna está preso há três anos no porão da Andorinha.
- **Rotina:**
  - **manhã:** acende o fogão às cinco e faz o pão às seis.
  - **tarde:** briga com os fornecedores e com o capitão.
  - **noite:** limpa a lanterna, põe um prato a mais na mesa e jura que o uivo do quarto 3 é vento.
  - **depois da missão:** a lanterna fica mais clara e a mesa ganha um bilhete.
- **Memória da cidade:** recebe a volta da primeira expedição com o "prato de volta" e uma vela a mais, e implica com o facão que "corta duas vezes".

### Capitão Bartolomeu Nuvem (`capitao`)
- **Relação:** paga a Estalagem com objetos estranhos e guarda a caixa que a Rosalva espera. Deve uma pena ao Ambarion.
- **Situação:** o guindaste racha na frente dele, e com a catraca nova acaba a desculpa para não voar.
- **Rotina:**
  - **manhã:** inspeciona o balão e grita com as gaivotas.
  - **tarde:** discute com o guindaste e paga os dois Jucas.
  - **noite:** conta histórias na Estalagem para ganhar sobremesa.
  - **depois da missão:** carrega a Andorinha e negocia "o recibo do recibo" com o dragão.
- **Memória da cidade:** comenta o guindaste trabalhando, com os dois Jucas finalmente valendo o salário dobrado, e o facão que bate duas vezes.

### Brida Ferrolho (`guardia`)
- **Relação:** é amiga da Rosalva e audita o capitão.
- **Situação:** entrega a conta e precisa "processar" um documento que chegou antes de ser enviado. Cita o artigo 7-B.
- **Rotina:**
  - **manhã:** revisa o mural.
  - **tarde:** patrulha o cais e confere a folha de pagamento.
  - **noite:** fecha os portões e conta as lanternas.
  - **depois da missão:** usa o carimbo novo.
- **Memória da cidade:** comenta o facão ("formulário 12-R, piada"), a volta da Vale ("a forasteira que volta") e o beco aberto, onde estavam os ratos com o chapéu do capitão.

### Seu Tião Lamparina (`minerador_aposentado`)
- **Relação:** foi parceiro de veio do Zeca Sem-Volta. Subiu mais cedo na noite da Queda e se culpa desde então. Acha que o assobio lá de baixo é bronca.
- **Situação:** é o **momento sincero do fantasma**. No Bate-Estaca, o Zeca destrava do "três e quinze" para o "três e dezesseis" e pede que a Vale diga ao Tião que a culpa não foi dele, e que ainda deve uma marmita. A Vale leva o recado.
- **Rotina:**
  - **manhã:** engraxa o cabo do elevador.
  - **tarde:** opera o elevador no andar 1.
  - **noite:** fica na porta da Ferraria com o Gaspar.
  - **depois da missão:** o elevador ganha o nome pintado.
- **Memória da cidade:** comenta o facão ("no meu tempo, o eco do túnel só repetia palavrão") e, depois do recado, a lamparina no andar 4.

## Memória da cidade (marcas que o jogo já liga)

| O que aconteceu | Marca | Quem comenta |
|---|---|---|
| Arma nova (reforço com eco) | `eco_desbloqueado` | Mira, Rosalva, Capitão, Brida, Tião |
| Volta da primeira expedição | `primeira_expedicao_voltou` | Mira, Rosalva, Brida, Tião (na missão) |
| Lugar consertado em uso | `mundo_guindaste_funcionando`, `mundo_passagem_armazem_aberta` | Capitão, Brida, cenas da tarde |
| A Vale investigou a pista da Mira | `atrasada_amostra_raspada` → `atrasada_pista_confirmada` | Mira (`amostra` na hora, `pista_reconhecida` depois) |
| O recado do Zeca chegou | `tiao_recebeu_recado` | Tião, Gaspar, cena "Três lingotes riscados" |

Cada reação aparece **uma vez** (marca `reacao_<id>_<tema>`). Depois o morador volta à rotina do período, ou à rotina de depois da missão.

## Cenas de ambiente (`data/missoes/cenas_ambiente.json`)

São balões sobre as cabeças, que não travam a jogadora. Quando a Vale chega perto, algumas mudam de assunto, no cue `*_disfarce`.

| Cena | Período | Quem | Humor |
|---|---|---|---|
| O Contrato de Penumbra | noite | Brida e Rosalva na porta da Estalagem | contrato dos vampiros sobre a iluminação das ruas (máximo de 12 lanternas; a da Rosalva é a 13ª). Muda de assunto para o sal do caldo. |
| Folha de pagamento em dobro | tarde (antes do conserto) | Brida e Capitão no cais | os dois Jucas pagos duas vezes ("perdi essa causa duas vezes, uma pra cada"). Muda de assunto para freio de dirigível. |
| Alecrim ofendido | manhã | Pipo e Mira na porta da Botica | entrega da Dona Iolanda com bilhete exigindo desculpas ao alecrim |
| Problema de vento | noite | Seu Lauro e Rosalva | a porta do quarto 3, "PROBLEMA DE VENTO. NÃO ABRIR EM LUA CHEIA" (é o Tobias). Muda de assunto ao chegar perto. |
| O recibo do pedágio | tarde (depois da missão) | Capitão e Gaspar | o Ambarion cobra taxa pelo recibo do pedágio |
| Polia ou cabo / Três lingotes riscados | noite | Gaspar e Tião | discussão que muda de assunto; depois do recado vira a cena sincera da dívida perdoada |

Também há uma cena da missão: "O envelope de carimbo vermelho" (Brida entrega a conta ao Gaspar).
