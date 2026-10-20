extends RefCounted
## Catalogo de itens (data/itens.json) + equipamentos (scripts/ilha/equipamento.gd, categoria "equip").
## Icone: art/ui/icones/<id>.png (arte da Bolorina) -> icones antigos (equipamento/fazenda) -> quadrado da cor da categoria.
const ARQUIVO := "res://data/itens.json"
const Equip = preload("res://scripts/ilha/equipamento.gd")
## integracao 20/10: 16x16 em art/ui/icones (catalogo); os 32x32 da forja da Bolorina ficam em art/ui/icones_forja
const PASTAS_ICONE := ["res://art/ui/icones/", "res://art/ui/icones_equip/", "res://art/ui/icones_fazenda/", "res://art/ui/icones_forja/"]
const COR_CAT := {"semente": Color("7fb04a"), "colheita": Color("e39a2e"), "peixe": Color("5fa8d8"), "material": Color("a08060"),
	"pesca": Color("4a7ab0"), "pocao": Color("c060c0"), "comida": Color("e0b060"), "minerio": Color("8a7a70"), "lingote": Color("c8b8a0"),
	"ferramenta": Color("707070"), "mapa": Color("e8d8a0"), "roupa": Color("d06070"), "reliquia": Color("b0f0ff"), "pet": Color("f0a060"),
	"missao": Color("f0f0f0"), "equip": Color("9aa8c0")}
static var _cat := {}
static var _icones := {}

static func catalogo() -> Dictionary:
	if _cat.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
		_cat = d.itens if d is Dictionary and d.has("itens") else {}
	return _cat

static func existe(id: String) -> bool:
	return catalogo().has(id) or Equip.ITENS.has(id) or forja_info().has(id)

static func info(id: String) -> Dictionary:
	if catalogo().has(id):
		return catalogo()[id]
	if Equip.ITENS.has(id):
		var e: Dictionary = Equip.ITENS[id]
		return {"nome": e.nome, "cat": "equip", "preco": int(e.get("preco", 50 + 40 * int(e.get("defesa", 0)) + 40 * int(e.get("ataque", 0)))), "desc": e.get("desc", "")}
	if forja_info().has(id):
		return forja_info()[id]
	return {"nome": id.capitalize(), "cat": "material", "preco": 1, "desc": ""}

## integracao 20/10: nomes/precos dos materiais e pecas da forja da Bolorina (data/forja) que nao estao no catalogo
static var _forja := {}
static func forja_info() -> Dictionary:
	if _forja.is_empty():
		var cats := {"minerio": "minerio", "lingote": "lingote", "liga": "lingote", "arma": "equip", "armadura": "equip", "ferramenta": "ferramenta", "acessorio": "equip"}
		for arq in ["res://data/forja/materiais.json", "res://data/forja/itens.json"]:
			var d = JSON.parse_string(FileAccess.get_file_as_string(arq))
			if not d is Dictionary:
				continue
			for k in ["materiais", "itens"]:
				for it in d.get(k, []):
					_forja[String(it.id)] = {"nome": String(it.get("nome", it.id)), "cat": String(cats.get(String(it.get("tipo", "")), "material")),
						"preco": int(it.get("valor_ouro", 1)), "desc": String(it.get("especial", it.get("nota", "")))}
	return _forja

static func nome(id: String) -> String:
	return String(info(id).nome)

static func cat(id: String) -> String:
	return String(info(id).cat)

static func preco(id: String) -> int:
	return int(info(id).preco)

static func eh_equip(id: String) -> bool:
	return Equip.ITENS.has(id)

## textura do icone (com fallback); nunca null
static func icone(id: String) -> Texture2D:
	if _icones.has(id):
		return _icones[id]
	var tex: Texture2D = null
	for p in PASTAS_ICONE:
		var g := ProjectSettings.globalize_path(p + id + ".png")
		if FileAccess.file_exists(g):
			var img := Image.load_from_file(g)
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				break
	if tex == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var c: Color = COR_CAT.get(cat(id), Color.WHITE)
		img.fill(Color(0.13, 0.09, 0.08))
		img.fill_rect(Rect2i(1, 1, 14, 14), c)
		img.fill_rect(Rect2i(3, 3, 4, 4), c.lightened(0.4))
		tex = ImageTexture.create_from_image(img)
	_icones[id] = tex
	return tex

## quantidade que a Vale tem (equipamento: 1 se possui)
static func qtd(estado, id: String) -> int:
	if eh_equip(id):
		return 1 if estado.equipamento.possui.has(id) else 0
	return estado.qtd(id)

## da o item para a Vale (equipamento vai para a mochila de roupas)
static func dar(estado, id: String, n := 1) -> void:
	if eh_equip(id):
		Equip.ganhar(estado.equipamento, id)
	else:
		estado.somar(id, n)

static func tirar(estado, id: String, n := 1) -> bool:
	if qtd(estado, id) < n:
		return false
	if eh_equip(id):
		if Equip.esta_equipado(estado.equipamento, id):
			Equip.desequipar(estado.equipamento, String(Equip.ITENS[id].slot))
		estado.equipamento.possui.erase(id)
	else:
		estado.somar(id, -n)
	return true
