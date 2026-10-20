extends RefCounted
## Estado do jogo conectado (fazenda/inventario/dia). Save NOVO e separado:
## user://ilha_fazenda_v1.json (nunca toca user://island_v1.json).
## ILHA_SAVE=<caminho> troca o arquivo (testes); ILHA_SEM_SAVE=1 nao grava nada.
const ARQUIVO := "user://ilha_fazenda_v1.json"
## pecas e o que a Vale veste (scripts/ilha/equipamento.gd); chave nova "equipamento" no mesmo save
const Equip = preload("res://scripts/ilha/equipamento.gd")
const VERSAO := 1
## dias regados ate a colheita (estagios 0..3)
const CULTURAS := {
	"nabo": {"nome": "Nabo", "dias": 3, "preco": 35},
	"couve": {"nome": "Couve", "dias": 5, "preco": 60},
	"abobora": {"nome": "Abobora", "dias": 7, "preco": 120},
}
const REGADOR_MAX := 40
## energia (estilo Stardew): ferramentas gastam, dormir (F9) restaura
const ENERGIA_MAX := 100
const CUSTO := {"enxada": 4, "picareta": 5, "machado": 5, "foice": 2, "regador": 2, "vara": 6}
## peixes do lago: chance relativa, preco
const PEIXES := {
	"peixe_carpa": {"nome": "Carpa", "chance": 55, "preco": 30},
	"peixe_tilapia": {"nome": "Tilapia", "chance": 32, "preco": 50},
	"peixe_dourado": {"nome": "Truta dourada", "chance": 13, "preco": 140},
}
## precos de venda (caixa de envio / loja)
const PRECO_OVO := 25
## loja da vila: item -> [quantidade, preco]
const LOJA := {
	"semente_nabo": [1, 20], "semente_couve": [1, 40], "semente_abobora": [1, 80], "racao": [5, 30],
}
const GALINHAS := ["Pipoca", "Canjica", "Paçoca", "Cocada", "Quindim"]
var arquivo := ARQUIVO
var gravar := true
var dia := 1
var ouro := 0
var regador: int = REGADOR_MAX
var itens := {}
## "x,z" -> {"molhada": bool, "cultura": "", "dias": 0, "estagio": 0}
var solo := {}
## "x,z" de detritos ja removidos
var removidos := {}
## "x,z" -> {"derrubada": bool, "toras": int, "removida": bool}
var arvores := {}
var slot := 0
var area: String = "fazenda"
var novo := true
var energia: int = ENERGIA_MAX
## galinhas: alimentado_dia = ultimo dia com racao no cocho; afeto 0-10 por galinha;
## carinho_dia = dia do ultimo carinho; ovos = ovos esperando no galinheiro
var animais := {}
## amizade com moradores (pontos; 10 = 1 coracao) e dia da ultima conversa
var amizade := {}
var conversou := {}
## {"possui": [ids], "equipado": {slot: id}}
var equipamento := {}
## economia (scripts/economia/): estoque das lojas por dia e estado geral (cofre, encantos, missoes, codex...)
var lojas := {}
var extras := {}

func _init() -> void:
	if OS.get_environment("ILHA_SAVE") != "":
		arquivo = OS.get_environment("ILHA_SAVE")
	gravar = OS.get_environment("ILHA_SEM_SAVE") != "1"
	reiniciar()

func reiniciar() -> void:
	dia = 1
	ouro = 0
	regador = REGADOR_MAX
	itens = {"madeira": 0, "pedra": 0, "fibra": 0, "nabo": 0, "couve": 0, "abobora": 0,
		"semente_nabo": 15, "semente_couve": 5, "semente_abobora": 3, "racao": 10, "ovo": 0,
		"peixe_carpa": 0, "peixe_tilapia": 0, "peixe_dourado": 0}
	energia = ENERGIA_MAX
	animais = _animais_novos()
	amizade = {}
	conversou = {}
	equipamento = Equip.novo()
	lojas = {}
	extras = {}
	solo = {}
	removidos = {}
	arvores = {}
	slot = 0
	novo = true

func _animais_novos() -> Dictionary:
	var af := []
	var cd := []
	for i in GALINHAS.size():
		af.append(0)
		cd.append(0)
	return {"alimentado_dia": 0, "afeto": af, "carinho_dia": cd, "ovos": 0}

# ---------------------------------------------------------------- energia
func pode_gastar(acao: String) -> bool:
	return energia >= int(CUSTO.get(acao, 0))

func gastar(acao: String) -> bool:
	var c: int = int(CUSTO.get(acao, 0))
	if energia < c:
		return false
	energia -= c
	return true

# ---------------------------------------------------------------- galinhas
func alimentar() -> int:
	## enche o cocho para hoje: 1 racao por galinha. Devolve quantas comeram (0 = sem racao ou ja alimentadas)
	if int(animais.alimentado_dia) == dia:
		return -1
	var n: int = mini(qtd("racao"), GALINHAS.size())
	if n <= 0:
		return 0
	somar("racao", -n)
	animais.alimentado_dia = dia
	animais["comeram"] = n
	return n

func carinho(i: int) -> int:
	## devolve o afeto novo, ou -1 se ja recebeu carinho hoje
	if int(animais.carinho_dia[i]) == dia:
		return -1
	animais.carinho_dia[i] = dia
	animais.afeto[i] = mini(10, int(animais.afeto[i]) + 1)
	return int(animais.afeto[i])

func coletar_ovos() -> int:
	var n: int = int(animais.ovos)
	animais.ovos = 0
	somar("ovo", n)
	return n

func _botar_ovos() -> void:
	## ao virar o dia: galinhas alimentadas ontem botam; afeto aumenta a chance (60% + 4%/coracao)
	if int(animais.alimentado_dia) != dia:
		return
	var r := RandomNumberGenerator.new()
	r.seed = 4242 + dia * 31
	var comeram: int = int(animais.get("comeram", GALINHAS.size()))
	for i in comeram:
		if r.randf() < 0.6 + 0.04 * float(animais.afeto[i]):
			animais.ovos = int(animais.ovos) + 1
	animais.ovos = mini(int(animais.ovos), 20)

static func chave(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

static func celula(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))

func qtd(item: String) -> int:
	return int(itens.get(item, 0))

func somar(item: String, n: int) -> void:
	itens[item] = maxi(0, qtd(item) + n)

# ---------------------------------------------------------------- solo
func arar(c: Vector2i) -> void:
	solo[chave(c)] = {"molhada": false, "cultura": "", "dias": 0, "estagio": 0}

func plantar(c: Vector2i, cultura: String) -> bool:
	var s = solo.get(chave(c))
	if s == null or String(s.cultura) != "" or qtd("semente_" + cultura) <= 0:
		return false
	somar("semente_" + cultura, -1)
	s.cultura = cultura
	s.dias = 0
	s.estagio = 0
	return true

func molhar(c: Vector2i) -> bool:
	var s = solo.get(chave(c))
	if s == null or regador <= 0:
		return false
	regador -= 1
	s.molhada = true
	return true

func colher(c: Vector2i) -> String:
	var s = solo.get(chave(c))
	if s == null or String(s.cultura) == "" or int(s.estagio) < 3:
		return ""
	var cult: String = String(s.cultura)
	somar(cult, 1)
	s.cultura = ""
	s.dias = 0
	s.estagio = 0
	return cult

static func estagio_de(cultura: String, dias: int) -> int:
	var total: int = int(CULTURAS[cultura].dias)
	if dias >= total:
		return 3
	return mini(2, int(ceil(dias * 3.0 / total)))

## novo dia: so cresce o que foi regado; toda terra seca de novo
func novo_dia() -> void:
	_botar_ovos()
	energia = ENERGIA_MAX
	dia += 1
	for k in solo:
		var s: Dictionary = solo[k]
		if String(s.cultura) != "" and bool(s.molhada) and int(s.estagio) < 3:
			s.dias = int(s.dias) + 1
			s.estagio = estagio_de(String(s.cultura), int(s.dias))
		s.molhada = false

func vender_colheita() -> int:
	var ganho: int = 0
	for c in CULTURAS:
		ganho += qtd(c) * int(CULTURAS[c].preco)
		itens[c] = 0
	for p in PEIXES:
		ganho += qtd(p) * int(PEIXES[p].preco)
		itens[p] = 0
	ganho += qtd("ovo") * PRECO_OVO
	itens["ovo"] = 0
	ouro += ganho
	return ganho

func comprar(item: String) -> String:
	if not LOJA.has(item):
		return "Item fora de estoque."
	var q: int = int(LOJA[item][0])
	var preco: int = int(LOJA[item][1])
	if ouro < preco:
		return "Ouro insuficiente (%d/%d)." % [ouro, preco]
	ouro -= preco
	somar(item, q)
	return ""

# ---------------------------------------------------------------- arquivo
func dados() -> Dictionary:
	return {"versao": VERSAO, "dia": dia, "ouro": ouro, "regador": regador, "itens": itens, "solo": solo,
		"removidos": removidos.keys(), "arvores": arvores, "slot": slot, "energia": energia, "animais": animais, "amizade": amizade, "conversou": conversou, "equipamento": equipamento, "lojas": lojas, "extras": extras}

func salvar() -> bool:
	if not gravar or arquivo == "user://island_v1.json":
		return false
	var f: FileAccess = FileAccess.open(arquivo, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(dados(), "\t"))
	f.close()
	novo = false
	return true

func carregar() -> bool:
	if not FileAccess.file_exists(arquivo):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
	if not d is Dictionary or int(d.get("versao", 0)) != VERSAO:
		return false
	dia = int(d.get("dia", 1))
	ouro = int(d.get("ouro", 0))
	regador = int(d.get("regador", REGADOR_MAX))
	var it = d.get("itens", {})
	if it is Dictionary:
		for k in it:
			itens[k] = int(it[k])
	solo = d.get("solo", {}) if d.get("solo", {}) is Dictionary else {}
	for k in solo:
		var s: Dictionary = solo[k]
		s.molhada = bool(s.get("molhada", false))
		s.cultura = String(s.get("cultura", ""))
		s.dias = int(s.get("dias", 0))
		s.estagio = int(s.get("estagio", 0))
	removidos = {}
	for k in d.get("removidos", []):
		removidos[String(k)] = true
	arvores = d.get("arvores", {}) if d.get("arvores", {}) is Dictionary else {}
	slot = int(d.get("slot", 0))
	energia = int(d.get("energia", ENERGIA_MAX))
	amizade = d.get("amizade", {}) if d.get("amizade", {}) is Dictionary else {}
	conversou = d.get("conversou", {}) if d.get("conversou", {}) is Dictionary else {}
	# saves antigos nao tem "equipamento": recebem o inicial
	equipamento = Equip.normalizar(d.get("equipamento", null))
	# saves antigos nao tem lojas/extras (economia): comecam vazios
	lojas = d.get("lojas", {}) if d.get("lojas", {}) is Dictionary else {}
	extras = d.get("extras", {}) if d.get("extras", {}) is Dictionary else {}
	var an = d.get("animais", {})
	animais = _animais_novos()
	if an is Dictionary:
		animais.alimentado_dia = int(an.get("alimentado_dia", 0))
		animais.ovos = int(an.get("ovos", 0))
		if an.has("comeram"):
			animais["comeram"] = int(an.comeram)
		for campo in ["afeto", "carinho_dia"]:
			var arr = an.get(campo, [])
			if arr is Array:
				for i in mini(arr.size(), GALINHAS.size()):
					animais[campo][i] = int(arr[i])
	novo = false
	return true
