extends RefCounted
## Loja/servico generico (data/lojas/<id>.json): comprar, vender, estoque diario e precos.
## Estoque: estado.lojas[<loja>] = {"dia": N, "estoque": {item: restante}} (reabastece todo dia).
## Venda: o NPC compra os itens das categorias "vende_categorias" por preco_base * taxa_venda.
const Itens = preload("res://scripts/economia/itens.gd")
const PASTA := "res://data/lojas/"
static var _lojas := {}

static func dados(id: String) -> Dictionary:
	if not _lojas.has(id):
		var txt := FileAccess.get_file_as_string(PASTA + id + ".json")
		var d = JSON.parse_string(txt) if txt != "" else null
		_lojas[id] = d if d is Dictionary else {}
	return _lojas[id]

static func existe(id: String) -> bool:
	return not dados(id).is_empty()

static func ids() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(PASTA):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	return out

static func _reabastecer(estado, id: String) -> Dictionary:
	var l: Dictionary = estado.lojas.get(id, {})
	if int(l.get("dia", -1)) != int(estado.dia):
		var est := {}
		for c in dados(id).get("compra", []):
			est[String(c.item)] = int(c.get("estoque", 99))
		l = {"dia": int(estado.dia), "estoque": est}
		estado.lojas[id] = l
	return l

static func estoque(estado, id: String, item: String) -> int:
	return int(_reabastecer(estado, id).estoque.get(item, 0))

static func oferta(id: String, item: String) -> Dictionary:
	for c in dados(id).get("compra", []):
		if String(c.item) == item:
			return c
	return {}

## compra n lotes (cada lote = "qtd" unidades). Devolve "" se deu certo, senao o motivo.
static func comprar(estado, id: String, item: String, n := 1) -> String:
	var o := oferta(id, item)
	if o.is_empty():
		return "Isso não está à venda aqui."
	if estoque(estado, id, item) < n:
		return "Acabou o estoque de %s por hoje." % Itens.nome(item)
	var total: int = int(o.preco) * n
	if estado.ouro < total:
		return "Ouro insuficiente (%d/%d)." % [estado.ouro, total]
	if Itens.eh_equip(item) and Itens.qtd(estado, item) > 0:
		return "Você já tem %s." % Itens.nome(item)
	estado.ouro -= total
	estado.lojas[id].estoque[item] = estoque(estado, id, item) - n
	Itens.dar(estado, item, int(o.get("qtd", 1)) * n)
	return ""

static func aceita(id: String, item: String) -> bool:
	return dados(id).get("vende_categorias", []).has(Itens.cat(item))

static func preco_venda(id: String, item: String) -> int:
	return maxi(1, int(round(Itens.preco(item) * float(dados(id).get("taxa_venda", 0.5)))))

## itens da Vale que esta loja compra (id -> quantidade)
static func vendaveis(estado, id: String) -> Array:
	var out: Array = []
	for item in estado.itens:
		if int(estado.itens[item]) > 0 and aceita(id, String(item)):
			out.append(String(item))
	out.sort()
	return out

static func vender(estado, id: String, item: String, n := 1) -> String:
	if not aceita(id, item):
		return "%s não compra %s." % [String(dados(id).get("nome", id)), Itens.nome(item)]
	if Itens.qtd(estado, item) < n:
		return "Você não tem %d %s." % [n, Itens.nome(item)]
	Itens.tirar(estado, item, n)
	estado.ouro += preco_venda(id, item) * n
	return ""

## vende todos os itens aceitos; devolve o ouro ganho
static func vender_tudo(estado, id: String) -> int:
	var ganho := 0
	for item in vendaveis(estado, id):
		var q: int = estado.qtd(item)
		ganho += preco_venda(id, item) * q
		estado.somar(item, -q)
	estado.ouro += ganho
	return ganho
