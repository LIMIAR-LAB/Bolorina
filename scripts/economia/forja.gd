extends RefCounted
## Forja (ferreira de Porto Velho): fundicao (minerio + carvao -> lingote) e forja (lingotes + ouro -> peca).
## Receitas em data/forja/receitas.json (formato: id, nome, nivel, materiais[{id,qtd}], ouro, nivel_forja, stats, resultado).
## Nivel da forja (estado.extras.nivel_forja, comeca 1) sobe ao forjar: 3 pecas do nivel atual -> +1 (max 3 no provisorio).
const Itens = preload("res://scripts/economia/itens.gd")
## Integracao 20/10: os dados agora sao os da Bolorina (data/forja: 9 metais, 87 itens, fundicao + receitas, 3 forjas).
## Os provisorios do Claude ficaram em data/forja/provisorio_claude/. Este arquivo converte o formato da Bolorina
## (materiais {id: qtd}, fundicao/receitas separadas, tier) para o formato que a economia usa
## (materiais [{id, qtd}], tipo fundir/forjar, nivel, stats, resultado) e liga as pecas de cobre, ferro e prata aos
## conjuntos com cor do equipamento (elmo_X -> capacete_X, peitoral_X -> peito_X; luvas, botas, escudo e espada iguais).
const RECEITAS := "res://data/forja/receitas.json"
const MATERIAIS := "res://data/forja/materiais.json"
const ITENS_FORJA := "res://data/forja/itens.json"
const METAIS_COM_COR := ["cobre", "ferro", "prata"]
static var _rec := []
static var _mat := []
static var _itens := {}

## id da peca da Bolorina -> id da peca do equipamento (conjuntos com cor do Claude)
static func alias_peca(id: String) -> String:
	for m in METAIS_COM_COR:
		if id == "elmo_" + m:
			return "capacete_" + m
		if id == "peitoral_" + m:
			return "peito_" + m
	return id

static func itens_forja() -> Dictionary:
	if _itens.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(ITENS_FORJA))
		if d is Dictionary:
			for it in d.get("itens", []):
				_itens[String(it.id)] = it
	return _itens

static func _converter(r: Dictionary, tipo: String) -> Dictionary:
	var mats: Array = []
	var m = r.get("materiais", {})
	if m is Dictionary:
		for k in m:
			mats.append({"id": String(k), "qtd": int(m[k])})
	elif m is Array:
		mats = m
	var res_orig := String(r.resultado)
	var res := alias_peca(res_orig)
	var it: Dictionary = itens_forja().get(res_orig, {})
	var stats := {}
	for k in ["ataque", "defesa"]:
		if it.has(k):
			stats[k] = int(it[k])
	var rid := String(r.id)
	if res != res_orig:
		rid = rid.replace(res_orig, res)
	var nm := String(it.get("nome", Itens.nome(res)))
	return {"id": rid, "id_bolorina": String(r.id), "nome": nm, "tipo": tipo, "nivel": int(it.get("tier", r.get("nivel_forja", 1))),
		"materiais": mats, "ouro": int(r.get("ouro", 0)), "nivel_forja": int(r.get("nivel_forja", 1)), "stats": stats,
		"resultado": res, "quantidade": int(r.get("quantidade", 1)), "forja": String(r.get("forja", "ferraria_porto")),
		"ferreiro": String(r.get("ferreiro", ""))}

static func receitas() -> Array:
	if _rec.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(RECEITAS))
		if d is Dictionary:
			for r in d.get("fundicao", []):
				_rec.append(_converter(r, "fundir"))
			for r in d.get("receitas", []):
				_rec.append(_converter(r, "forjar"))
	return _rec

## metais no formato da economia: {id, nome, nivel, minerio, lingote}
static func materiais() -> Array:
	if _mat.is_empty():
		var tiers := {}
		var d = JSON.parse_string(FileAccess.get_file_as_string(MATERIAIS))
		if d is Dictionary:
			for m in d.get("materiais", []):
				tiers[String(m.id)] = m
		for r in receitas():
			if String(r.tipo) != "fundir":
				continue
			var lingote := String(r.resultado)
			var minerio := ""
			for m in r.materiais:
				if String(m.id).begins_with("minerio_") or String(m.id).ends_with("_bruto") or String(m.id).begins_with("lingote_"):
					minerio = String(m.id)
					break
			var info: Dictionary = tiers.get(lingote, {})
			_mat.append({"id": lingote.trim_prefix("lingote_"), "nome": String(info.get("nome", lingote)), "nivel": int(info.get("tier", 1)),
				"minerio": minerio, "lingote": lingote})
	return _mat

static func recarregar() -> void:
	_rec = []
	_mat = []
	_itens = {}

static func receita(id: String) -> Dictionary:
	for r in receitas():
		if String(r.id) == id:
			return r
	return {}

## receitas de um tipo; forja_id ("ferraria_porto", "forja_cla", "forja_quantica") filtra pela forja do balcao
static func de_tipo(tipo: String, forja_id := "") -> Array:
	var out: Array = []
	for r in receitas():
		if String(r.tipo) == tipo and (forja_id == "" or String(r.get("forja", "")) == forja_id):
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
	Itens.dar(estado, String(r.resultado), int(r.get("quantidade", 1)))
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
