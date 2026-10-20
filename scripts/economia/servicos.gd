extends RefCounted
## Servicos dos NPCs (data/lojas/<id>.json -> "servicos"). Cada um devolve a mensagem para o jogador.
## Estado geral em estado.extras (cofre, missao, entrega, codex, pet, casa...). Forja e fundicao ficam em forja.gd.
const Itens = preload("res://scripts/economia/itens.gd")
const Loja = preload("res://scripts/economia/loja.gd")
const Equip = preload("res://scripts/ilha/equipamento.gd")

const BOATOS := [
	"Dizem que o sino da torre tocou ontem às 16:30 de amanhã.",
	"Um orc de gravata pediu desconto na forja. Conseguiu, era diplomata.",
	"A ilha futurista está ancorada a leste. Ou estará, conforme o humor do tempo.",
	"Na Cidade Fantasma, os túmulos guardam prata. E opiniões.",
	"O dragão da doca prefere truta dourada. Quem der uma ganha uma escama, às vezes.",
	"Nas Minas da Cinza tem um minerador que é você, de outro universo. Ele cobra caro.",
	"O Arquimago Ozório tentou encantar o próprio chapéu. O chapéu ganhou.",
]
const DICAS_MINA := [
	"Cobre sai na pedreira e nas minas rasas. Ferro, mais fundo. Prata de túmulo, só na Cidade Fantasma.",
	"Leve carvão: sem carvão o Gaspar Bigorna não funde nada.",
	"Três minérios e um carvão fazem um lingote. Matemática de mineiro.",
	"Picareta de ferro quebra minério de prata. A comum só arranha.",
]
const CODEX := [
	"Página 1 — A Ilha das Cinzas flutua sobre um mar de nuvens. Vive de comércio entre ilhas e de teimosia.",
	"Página 2 — Porto Velho nasceu de uma doca de dirigíveis. O primeiro capitão chegou antes de partir.",
	"Página 3 — O vulcão adormecido cobre tudo de cinza fértil. Por isso a fazenda dá abóbora do tamanho de um orc.",
	"Página 4 — Os orcs da ilhota leste são comerciantes honestos. A gravata é para negociar.",
	"Página 5 — A Cidade Fantasma ficou presa às 16:30 de um dia que ninguém lembra.",
	"Página 6 — A Ilha Futurista é a mesma ilha, mil anos depois. Ou antes. O códex discorda de si mesmo.",
	"Página 7 — A forma Adamantium foi forjada com metal que ainda vai ser descoberto.",
]
const MISSOES := [
	{"id": "cobre", "texto": "Traga 3 minérios de cobre para os portões.", "item": "minerio_cobre", "qtd": 3, "ouro": 90},
	{"id": "peixe", "texto": "Traga 2 carpas para a cantina da guarda.", "item": "peixe_carpa", "qtd": 2, "ouro": 70},
	{"id": "nabo", "texto": "Traga 5 nabos para a ração dos guardas.", "item": "nabo", "qtd": 5, "ouro": 120},
	{"id": "ferro", "texto": "Traga 2 lingotes de ferro para as grades.", "item": "lingote_ferro", "qtd": 2, "ouro": 220},
]

static func _cofre(estado) -> int:
	var c: int = int(estado.extras.get("cofre", 0))
	var d0: int = int(estado.extras.get("cofre_dia", estado.dia))
	if c > 0 and estado.dia > d0:
		for i in estado.dia - d0:
			c += int(c * 0.01)
	estado.extras["cofre"] = c
	estado.extras["cofre_dia"] = int(estado.dia)
	return c

static func _pagar(estado, preco: int) -> String:
	if estado.ouro < preco:
		return "Ouro insuficiente (%d/%d)." % [estado.ouro, preco]
	estado.ouro -= preco
	return ""

static func info(loja: String, sid: String) -> Dictionary:
	for s in Loja.dados(loja).get("servicos", []):
		if String(s.id) == sid:
			return s
	return {}

## executa o servico sid da loja. g = gerenciador (jogo_ilha) ou null. Devolve a mensagem.
static func executar(estado, g, loja: String, sid: String) -> String:
	var s := info(loja, sid)
	if s.is_empty():
		return "Esse serviço não existe aqui."
	var preco: int = int(s.get("preco", 0))
	var ex: Dictionary = estado.extras
	match sid:
		"ler_folhas", "boato":
			var e := _pagar(estado, preco)
			if e != "":
				return e
			var n := _contar(ex, "boatos")
			return BOATOS[(int(estado.dia) * 7 + n) % BOATOS.size()]
		"descansar":
			var e := _pagar(estado, preco)
			if e != "":
				return e
			estado.energia = estado.ENERGIA_MAX
			return "Você dormiu na estalagem. Energia cheia (%d)." % estado.energia
		"missao":
			if ex.has("missao"):
				return "Missão em andamento: " + String(ex.missao.texto)
			var m: Dictionary = MISSOES[int(ex.get("missoes_feitas", 0)) % MISSOES.size()]
			ex["missao"] = m.duplicate()
			return "Nova missão: %s Recompensa: %d ouro." % [String(m.texto), int(m.ouro)]
		"entregar_missao":
			if not ex.has("missao"):
				return "Nenhuma missão ativa. Peça uma primeiro."
			var m: Dictionary = ex.missao
			if Itens.qtd(estado, String(m.item)) < int(m.qtd):
				return "Ainda falta: %d %s (tem %d)." % [int(m.qtd), Itens.nome(String(m.item)), Itens.qtd(estado, String(m.item))]
			Itens.tirar(estado, String(m.item), int(m.qtd))
			estado.ouro += int(m.ouro)
			Itens.dar(estado, "insignia_guarda", 1)
			ex.erase("missao")
			ex["missoes_feitas"] = int(ex.get("missoes_feitas", 0)) + 1
			return "Missão cumprida! +%d ouro e uma insígnia da guarda." % int(m.ouro)
		"viajar":
			var e := _pagar(estado, preco)
			if e != "":
				return e
			if g and g.has_method("abrir_viagem"):
				g.abrir_viagem()
			return "Todos a bordo! Escolha o destino no mapa."
		"encantar":
			var corpo: String = Equip.equipado(estado.equipamento, "corpo")
			if corpo == "" or corpo == String(Equip.PADRAO.corpo):
				return "Vista uma peça de corpo (armadura) para encantar."
			var enc: Dictionary = estado.equipamento.get("encantos", {})
			if int(enc.get(corpo, 0)) >= 1:
				return "%s já está encantada." % Itens.nome(corpo)
			var e := _pagar(estado, preco)
			if e != "":
				return e
			enc[corpo] = 1
			estado.equipamento["encantos"] = enc
			return "%s brilha: +1 de defesa." % Itens.nome(corpo)
		"hora":
			return "Dia %d. O sino diz que é sempre agora." % int(estado.dia)
		"pular_dia":
			var e := _pagar(estado, preco)
			if e != "":
				return e
			estado.novo_dia()
			return "DONG! Amanheceu. Dia %d." % int(estado.dia)
		"melhorar_casa", "melhorar_celeiro":
			var chave := "nivel_casa" if sid == "melhorar_casa" else "nivel_celeiro"
			if int(ex.get(chave, 1)) >= 3:
				return "Já está no nível máximo."
			var e := _pagar(estado, preco)
			if e != "":
				return e
			ex[chave] = int(ex.get(chave, 1)) + 1
			return "Obra pronta! %s agora é nível %d." % ["A casa" if chave == "nivel_casa" else "O celeiro", int(ex[chave])]
		"depositar":
			if estado.ouro < 100:
				return "Precisa de 100 ouro para depositar."
			estado.ouro -= 100
			ex["cofre"] = _cofre(estado) + 100
			return "Depositado. Cofre: %d ouro (rende 1%% ao dia)." % int(ex.cofre)
		"sacar":
			var c := _cofre(estado)
			if c <= 0:
				return "O cofre está vazio."
			estado.ouro += c
			ex["cofre"] = 0
			return "Sacou %d ouro." % c
		"dica_mina":
			return DICAS_MINA[(int(estado.dia) + _contar(ex, "dicas")) % DICAS_MINA.size()]
		"pegar_entrega":
			if ex.has("entrega"):
				return "Você já tem uma carta para %s." % String(ex.entrega.nome)
			ex["entrega"] = {"para": "capitao", "nome": "o Capitão Nuvem", "entregue": false}
			Itens.dar(estado, "carta_entrega", 1)
			return "Leve esta carta para o Capitão Nuvem, na doca do dirigível. Depois volte aqui!"
		"concluir_entrega":
			if not ex.has("entrega"):
				return "Sem entrega no momento."
			if not bool(ex.entrega.entregue):
				return "A carta ainda não chegou na %s." % String(ex.entrega.nome)
			ex.erase("entrega")
			estado.ouro += 60
			ex["entregas"] = int(ex.get("entregas", 0)) + 1
			return "Obrigada! Aqui seus 60 ouro."
		"ler_codex":
			var p: int = int(ex.get("codex", 0))
			ex["codex"] = mini(p + 1, CODEX.size())
			return CODEX[mini(p, CODEX.size() - 1)]
		"adotar_pet":
			if ex.has("pet"):
				return "Você já tem um pet: %s." % String(ex.pet)
			var e := _pagar(estado, preco)
			if e != "":
				return e
			ex["pet"] = "Bigode (gato da doca)"
			return "Bigode, o gato da doca, agora é seu!"
		"presente_dragao":
			if int(ex.get("dragao_dia", 0)) == int(estado.dia):
				return "Fagulha está dormindo de barriga cheia. Volte amanhã."
			var peixe := ""
			for p in ["peixe_dourado", "peixe_tilapia", "peixe_carpa"]:
				if estado.qtd(p) > 0:
					peixe = p
					break
			if peixe == "":
				return "Fagulha cheira suas mãos. Sem peixe, sem conversa."
			estado.somar(peixe, -1)
			ex["dragao_dia"] = int(estado.dia)
			if peixe == "peixe_dourado" or (int(estado.dia) + estado.ouro) % 3 == 0:
				Itens.dar(estado, "escama_dragao", 1)
				return "Fagulha engole o peixe e solta uma escama morna. Presente!"
			estado.ouro += 20
			return "Fagulha engole o peixe e cospe 20 moedas. Educado."
		"fundir", "forjar":
			return ""
	return "Ainda não sei fazer isso."

static func _contar(ex: Dictionary, chave: String) -> int:
	ex[chave] = int(ex.get(chave, 0)) + 1
	return int(ex[chave])

## a Vale chegou num NPC: entrega pendente para ele?
static func ao_falar(estado, npc_id: String) -> String:
	var ex: Dictionary = estado.extras
	if ex.has("entrega") and String(ex.entrega.para) == npc_id and not bool(ex.entrega.entregue):
		Itens.tirar(estado, "carta_entrega", 1)
		ex.entrega["entregue"] = true
		return "Você entregou a carta do Pipo."
	return ""
