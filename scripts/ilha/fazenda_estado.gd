extends RefCounted
## Estado do jogo conectado (fazenda/inventario/dia). Save NOVO e separado:
## user://ilha_fazenda_v1.json (nunca toca user://island_v1.json).
## ILHA_SAVE=<caminho> troca o arquivo (testes); ILHA_SEM_SAVE=1 nao grava nada.
const ARQUIVO := "user://ilha_fazenda_v1.json"
const VERSAO := 1
## dias regados ate a colheita (estagios 0..3)
const CULTURAS := {
	"nabo": {"nome": "Nabo", "dias": 3, "preco": 35},
	"couve": {"nome": "Couve", "dias": 5, "preco": 60},
	"abobora": {"nome": "Abobora", "dias": 7, "preco": 120},
}
const REGADOR_MAX := 40
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
		"semente_nabo": 15, "semente_couve": 5, "semente_abobora": 3}
	solo = {}
	removidos = {}
	arvores = {}
	slot = 0
	novo = true

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
	ouro += ganho
	return ganho

# ---------------------------------------------------------------- arquivo
func dados() -> Dictionary:
	return {"versao": VERSAO, "dia": dia, "ouro": ouro, "regador": regador, "itens": itens, "solo": solo,
		"removidos": removidos.keys(), "arvores": arvores, "slot": slot}

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
	novo = false
	return true
