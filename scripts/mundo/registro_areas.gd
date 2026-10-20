extends RefCounted
## Registro unico das areas do jogo (data/areas.json). Mapa-mundi, teleporte e jogo_ilha.gd leem daqui.
## Area nova: uma entrada no JSON (id, nome, cena, chegada, mapa, raio...). Se a cena ainda nao existe,
## a area aparece no mapa como "em breve" e o teleporte fica desligado.
const ARQUIVO := "res://data/areas.json"
static var _dados := {}

static func dados() -> Dictionary:
	if _dados.is_empty():
		var txt := FileAccess.get_file_as_string(ARQUIVO)
		var d = JSON.parse_string(txt) if txt != "" else null
		_dados = d if d is Dictionary else {"areas": []}
	return _dados

static func recarregar() -> void:
	_dados = {}

## lista de areas na ordem do JSON
static func lista() -> Array:
	return dados().get("areas", [])

static func ids() -> Array:
	var out: Array = []
	for a in lista():
		out.append(String(a.id))
	return out

static func info(id: String) -> Dictionary:
	for a in lista():
		if String(a.id) == id:
			return a
	return {}

static func existe(id: String) -> bool:
	return not info(id).is_empty()

## a cena da area existe no projeto (pode teleportar)?
static func disponivel(id: String) -> bool:
	return cena(id) != ""

## cena que o jogo carrega: a oficial (ex. mapa da Bolorina) ou, se ainda nao existe, a "cena_provisoria"
static func cena(id: String) -> String:
	var a := info(id)
	for k in ["cena", "cena_provisoria"]:
		if a.get(k) != null and ResourceLoader.exists(String(a.get(k))):
			return String(a.get(k))
	return ""

static func nome(id: String) -> String:
	return String(info(id).get("nome", id.capitalize()))

static func chegada(id: String) -> String:
	return String(info(id).get("chegada", "inicio"))

static func disponiveis() -> Array:
	var out: Array = []
	for a in lista():
		if disponivel(String(a.id)):
			out.append(String(a.id))
	return out
