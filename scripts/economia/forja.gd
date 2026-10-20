extends RefCounted
## Forja (ferreira de Porto Velho): fundicao (minerio + carvao -> lingote) e forja (lingotes + ouro -> peca).
## Receitas em data/forja/receitas.json (formato: id, nome, nivel, materiais[{id,qtd}], ouro, nivel_forja, stats, resultado).
## Nivel da forja (estado.extras.nivel_forja, comeca 1) sobe ao forjar: 3 pecas do nivel atual -> +1 (max 3 no provisorio).
const Itens = preload("res://scripts/economia/itens.gd")
const RECEITAS := "res://data/forja/receitas.json"
const MATERIAIS := "res://data/forja/materiais.json"
static var _rec := []
static var _mat := []

static func receitas() -> Array:
	if _rec.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(RECEITAS))
		_rec = d.receitas if d is Dictionary else []
	return _rec

static func materiais() -> Array:
	if _mat.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(MATERIAIS))
		_mat = d.materiais if d is Dictionary else []
	return _mat

static func receita(id: String) -> Dictionary:
	for r in receitas():
		if String(r.id) == id:
			return r
	return {}

static func de_tipo(tipo: String) -> Array:
	var out: Array = []
	for r in receitas():
		if String(r.tipo) == tipo:
			out.append(r)
	return out

static func nivel(estado) -> int:
	return int(estado.extras.get("nivel_forja", 1))

## motivo de nao poder fazer ("" = pode)
static func falta(estado, r: Dictionary) -> String:
	if r.is_empty():
		return "Receita desconhecida."
	if Itens.eh_equip(String(r.resultado)) and Itens.qtd(estado, String(r.resultado)) > 0:
		return "Você já tem %s." % Itens.nome(String(r.resultado))
	if int(r.nivel_forja) > nivel(estado):
		return "A forja precisa ser nível %d (agora %d)." % [int(r.nivel_forja), nivel(estado)]
	for m in r.materiais:
		var tem: int = Itens.qtd(estado, String(m.id))
		if tem < int(m.qtd):
			return "Falta %s (%d/%d)." % [Itens.nome(String(m.id)), tem, int(m.qtd)]
	if estado.ouro < int(r.ouro):
		return "Ouro insuficiente (%d/%d)." % [estado.ouro, int(r.ouro)]
	return ""

## executa a receita; devolve "" se deu certo
static func fazer(estado, id: String) -> String:
	var r := receita(id)
	var f := falta(estado, r)
	if f != "":
		return f
	for m in r.materiais:
		Itens.tirar(estado, String(m.id), int(m.qtd))
	estado.ouro -= int(r.ouro)
	Itens.dar(estado, String(r.resultado), 1)
	if String(r.tipo) == "forjar":
		var feitas: int = int(estado.extras.get("forjadas", 0)) + 1
		estado.extras["forjadas"] = feitas
		var max_nivel := 1
		for m in materiais():
			max_nivel = maxi(max_nivel, int(m.nivel))
		if feitas >= nivel(estado) * 3 and nivel(estado) < max_nivel:
			estado.extras["nivel_forja"] = nivel(estado) + 1
	return ""

static func resumo(estado, r: Dictionary) -> String:
	var mats: Array = []
	for m in r.materiais:
		mats.append("%d %s (tem %d)" % [int(m.qtd), Itens.nome(String(m.id)), Itens.qtd(estado, String(m.id))])
	var st := ""
	if r.stats is Dictionary and not r.stats.is_empty():
		var p: Array = []
		for k in r.stats:
			if int(r.stats[k]) != 0:
				p.append("%s +%d" % [String(k).to_upper().left(3), int(r.stats[k])])
		st = "  [" + ", ".join(p) + "]"
	return "%s ← %s + %d ouro%s" % [String(r.nome), ", ".join(mats), int(r.ouro), st]
