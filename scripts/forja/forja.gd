extends RefCounted
## Sistema de forja AUTÔNOMO (PROPOSTA, não é canon). Não está ligado a nenhuma cena.
## Lê data/forja/{materiais,itens,receitas}.json e faz: conferir inventário, fundir minério em
## lingote, forjar item, reforjar (+1..+3), encantar com essências e calcular bônus de conjunto.
##
## Uso:
##   var Forja = preload("res://scripts/forja/forja.gd")
##   var f = Forja.new()                      # carrega os JSON
##   var inv := {"ouro": 500, "itens": {"minerio_cobre": 6, "carvao": 2}}
##   var niveis := {"ferraria_porto": 1}      # nível de cada forja já construída
##   f.pode_fazer("fundir_cobre", inv, niveis) -> {"ok": true, "faltando": {}, "motivo": ""}
##   f.fazer("fundir_cobre", inv, niveis)      -> {"ok": true, "resultado": "lingote_cobre", ...}
## O inventário é um Dictionary simples: {"ouro": int, "itens": {id: qtd}}. Equipamento forjado vira
## uma "instância" {"id", "reforja", "encanto"} guardada em inv["equipamento"] (Array).

const PASTA := "res://data/forja/"

var materiais: Dictionary = {}   # id -> dados
var itens: Dictionary = {}       # id -> dados
var receitas: Dictionary = {}    # id -> receita (forja + fundição)
var conjuntos: Dictionary = {}
var forjas: Dictionary = {}
var locais: Dictionary = {}
var nos_de_minerio: Dictionary = {}
var reforja: Dictionary = {}
var encantamento: Dictionary = {}
var mvp: Dictionary = {}
var formula: Dictionary = {}
var erros: Array = []

func _init(pasta := PASTA) -> void:
	carregar(pasta)

static func _ler(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return d if d is Dictionary else {}

func carregar(pasta := PASTA) -> bool:
	erros.clear()
	var dm := _ler(pasta + "materiais.json")
	var di := _ler(pasta + "itens.json")
	var dr := _ler(pasta + "receitas.json")
	if dm.is_empty() or di.is_empty() or dr.is_empty():
		erros.append("JSON da forja ausente ou inválido em " + pasta)
		return false
	for m in dm.get("materiais", []):
		materiais[String(m.id)] = m
	locais = dm.get("locais", {})
	nos_de_minerio = dm.get("nos_de_minerio", {})
	for i in di.get("itens", []):
		itens[String(i.id)] = i
	conjuntos = di.get("conjuntos", {})
	formula = di.get("formula", {})
	forjas = dr.get("forjas", {})
	for r in dr.get("fundicao", []) + dr.get("receitas", []):
		receitas[String(r.id)] = r
	reforja = dr.get("reforja", {})
	encantamento = dr.get("encantamento", {})
	mvp = dr.get("mvp", {})
	return true

# ------------------------------------------------------------------ consultas
func nome(id: String) -> String:
	if itens.has(id): return String(itens[id].nome)
	if materiais.has(id): return String(materiais[id].nome)
	return id

func existe(id: String) -> bool:
	return itens.has(id) or materiais.has(id)

func receitas_da_forja(forja_id: String, nivel: int) -> Array:
	var out: Array = []
	for id in receitas:
		var r: Dictionary = receitas[id]
		if String(r.forja) == forja_id and int(r.nivel_forja) <= nivel:
			out.append(id)
	return out

func receita_de(item_id: String) -> Dictionary:
	for id in receitas:
		if String(receitas[id].resultado) == item_id:
			return receitas[id]
	return {}

static func qtd(inv: Dictionary, id: String) -> int:
	return int(inv.get("itens", {}).get(id, 0))

static func _somar(inv: Dictionary, id: String, n: int) -> void:
	if not inv.has("itens"):
		inv["itens"] = {}
	var v := int(inv.itens.get(id, 0)) + n
	if v <= 0:
		inv.itens.erase(id)
	else:
		inv.itens[id] = v

# ------------------------------------------------------------------ forjar / fundir
## Confere tudo sem mexer no inventário.
func pode_fazer(receita_id: String, inv: Dictionary, niveis_forja: Dictionary, vezes := 1) -> Dictionary:
	var res := {"ok": false, "faltando": {}, "motivo": ""}
	if not receitas.has(receita_id):
		res.motivo = "receita desconhecida: " + receita_id
		return res
	var r: Dictionary = receitas[receita_id]
	var f := String(r.forja)
	var nivel := int(niveis_forja.get(f, 0))
	if nivel < int(r.nivel_forja):
		res.motivo = "%s precisa estar no nível %d (está no %d)" % [String(forjas.get(f, {}).get("nome", f)), int(r.nivel_forja), nivel]
		return res
	for m in r.materiais:
		var precisa := int(r.materiais[m]) * vezes
		var tem := qtd(inv, m)
		if tem < precisa:
			res.faltando[m] = precisa - tem
	var ouro := int(r.get("ouro", 0)) * vezes
	if int(inv.get("ouro", 0)) < ouro:
		res.faltando["ouro"] = ouro - int(inv.get("ouro", 0))
	if not res.faltando.is_empty():
		res.motivo = "faltam materiais"
		return res
	res.ok = true
	return res

## Consome materiais e ouro e entrega o resultado. Equipamento vira instância em inv.equipamento.
func fazer(receita_id: String, inv: Dictionary, niveis_forja: Dictionary, vezes := 1) -> Dictionary:
	var chk := pode_fazer(receita_id, inv, niveis_forja, vezes)
	if not chk.ok:
		return chk
	var r: Dictionary = receitas[receita_id]
	for m in r.materiais:
		_somar(inv, m, -int(r.materiais[m]) * vezes)
	inv["ouro"] = int(inv.get("ouro", 0)) - int(r.get("ouro", 0)) * vezes
	var res_id := String(r.resultado)
	var n := int(r.get("quantidade", 1)) * vezes
	var instancias: Array = []
	if itens.has(res_id) and String(itens[res_id].tipo) in ["arma", "armadura", "acessorio", "ferramenta"]:
		if not inv.has("equipamento"):
			inv["equipamento"] = []
		for i in n:
			var inst := {"id": res_id, "reforja": 0, "encanto": ""}
			inv.equipamento.append(inst)
			instancias.append(inst)
	else:
		_somar(inv, res_id, n)
	return {"ok": true, "resultado": res_id, "quantidade": n, "instancias": instancias, "faltando": {}, "motivo": ""}

# ------------------------------------------------------------------ reforja / encanto
func custo_reforja(inst: Dictionary) -> Dictionary:
	var prox := int(inst.get("reforja", 0)) + 1
	var niveis: Array = reforja.get("niveis", [])
	if prox > niveis.size():
		return {}
	var nv: Dictionary = niveis[prox - 1]
	var rec := receita_de(String(inst.id))
	if rec.is_empty():
		return {}
	var lingote := ""
	for m in rec.materiais:
		if String(materiais.get(m, {}).get("tipo", "")) in ["lingote", "liga"]:
			lingote = m
			break
	var mats := {}
	if lingote != "":
		mats[lingote] = int(nv.lingotes_do_tier)
	for k in nv.get("extra", {}):
		mats[k] = int(nv.extra[k])
	return {"nivel": prox, "materiais": mats, "ouro": int(ceil(int(rec.get("ouro", 0)) * float(nv.ouro_fracao))),
		"forja": String(rec.forja), "nivel_forja": int(rec.nivel_forja)}

func reforjar(inst: Dictionary, inv: Dictionary, niveis_forja: Dictionary) -> Dictionary:
	var c := custo_reforja(inst)
	if c.is_empty():
		return {"ok": false, "motivo": "já está no máximo (+3) ou não pode ser reforjado"}
	var item: Dictionary = itens.get(String(inst.id), {})
	var nivel_req := int(c.nivel_forja)
	if c.nivel == 3 and String(c.forja) == "forja_cla":
		nivel_req = 2
	if int(niveis_forja.get(c.forja, 0)) < nivel_req:
		return {"ok": false, "motivo": "forja de nível insuficiente para +%d" % c.nivel}
	for m in c.materiais:
		if qtd(inv, m) < int(c.materiais[m]):
			return {"ok": false, "motivo": "faltam materiais", "faltando": {m: int(c.materiais[m]) - qtd(inv, m)}}
	if int(inv.get("ouro", 0)) < int(c.ouro):
		return {"ok": false, "motivo": "falta ouro"}
	for m in c.materiais:
		_somar(inv, m, -int(c.materiais[m]))
	inv["ouro"] = int(inv.ouro) - int(c.ouro)
	inst["reforja"] = int(c.nivel)
	return {"ok": true, "nivel": inst.reforja, "item": String(item.get("nome", inst.id))}

func encantar(inst: Dictionary, essencia: String, inv: Dictionary) -> Dictionary:
	if not essencia in encantamento.get("essencias", []):
		return {"ok": false, "motivo": "não é uma essência"}
	if qtd(inv, essencia) < 1:
		return {"ok": false, "motivo": "sem essência"}
	var tier := int(itens.get(String(inst.id), {}).get("tier", 1))
	var ouro := int(encantamento.get("ouro_por_tier", 40)) * tier
	if int(inv.get("ouro", 0)) < ouro:
		return {"ok": false, "motivo": "falta ouro"}
	_somar(inv, essencia, -1)
	inv["ouro"] = int(inv.ouro) - ouro
	var anterior := String(inst.get("encanto", ""))
	inst["encanto"] = essencia
	return {"ok": true, "substituiu": anterior}

# ------------------------------------------------------------------ atributos
## Ataque/defesa da instância com a reforja aplicada.
func atributos(inst: Dictionary) -> Dictionary:
	var it: Dictionary = itens.get(String(inst.id), {})
	var bonus := 0.0
	var r := int(inst.get("reforja", 0))
	if r > 0:
		bonus = float(reforja.niveis[r - 1].bonus_atributo)
	var out := {"ataque": 0, "defesa": 0, "encanto": String(inst.get("encanto", ""))}
	if it.has("ataque"):
		out.ataque = int(round(float(it.ataque) * (1.0 + bonus)))
		out["multiplicador_dano"] = 1.0 + out.ataque / 25.0
	if it.has("defesa"):
		out.defesa = int(round(float(it.defesa) * (1.0 + bonus)))
	return out

## Bônus de conjunto: lista de instâncias equipadas -> {conjunto_id: {"pecas": n, "bonus": [..]}}
func bonus_conjunto(equipadas: Array) -> Dictionary:
	var conta := {}
	for inst in equipadas:
		var c := String(itens.get(String(inst.id), {}).get("conjunto", ""))
		if c != "":
			conta[c] = int(conta.get(c, 0)) + 1
	var out := {}
	for c in conta:
		var b: Array = []
		if conta[c] >= 3: b.append(String(conjuntos[c].bonus_3_pecas))
		if conta[c] >= 5: b.append(String(conjuntos[c].bonus_5_pecas))
		out[c] = {"pecas": conta[c], "bonus": b}
	return out

## Dano que a Vale recebe com a defesa total equipada (fórmula da proposta).
static func dano_recebido(dano: int, defesa_total: int) -> int:
	return maxi(1, int(round(dano * 100.0 / (100.0 + defesa_total))))

## Picareta pode minerar o material?
func pode_minerar(material_id: String, picareta_id: String) -> bool:
	var precisa := int(materiais.get(material_id, {}).get("picareta_minima", 0))
	var nivel := int(itens.get(picareta_id, {}).get("nivel_mineracao", 0)) if picareta_id != "" else 0
	return nivel >= precisa

## Confere a consistência dos dados (usado nos testes). Retorna lista de problemas.
func validar() -> Array:
	var p: Array = []
	for id in receitas:
		var r: Dictionary = receitas[id]
		if not existe(String(r.resultado)): p.append("%s: resultado desconhecido %s" % [id, r.resultado])
		if not forjas.has(String(r.forja)): p.append("%s: forja desconhecida %s" % [id, r.forja])
		for m in r.materiais:
			if not materiais.has(m): p.append("%s: material desconhecido %s" % [id, m])
	for id in itens:
		if receita_de(id).is_empty(): p.append("item sem receita: " + id)
	for id in materiais:
		var m: Dictionary = materiais[id]
		if String(m.tipo) in ["lingote", "liga"] and receita_de(id).is_empty():
			p.append("lingote sem fundição: " + id)
		for l in m.get("onde", []):
			if not locais.has(l): p.append("%s: local desconhecido %s" % [id, l])
	for zona in nos_de_minerio:
		for n in nos_de_minerio[zona]:
			if not materiais.has(String(n.material)): p.append("nó %s: material desconhecido" % n.id)
	return p
