extends RefCounted
## Inventario central da Vale (fonte unica de verdade = o save, scripts/ilha/fazenda_estado.gd).
## Nao guarda estado proprio: le e escreve estado.itens (contagens), estado.equipamento (pecas, so leitura aqui),
## estado.baus (bau = grade de SLOTS_BAU espacos) e, durante uma incursao, o saque da masmorra (so leitura).
## Catalogo/nomes/precos/icones: scripts/economia/itens.gd (data/itens.json + forja) e, para os itens fabricados
## aqui (o bau), EXTRA abaixo. Receitas: data/fabricar.json.
const Itens = preload("res://scripts/economia/itens.gd")
const Equip = preload("res://scripts/ilha/equipamento.gd")
const RECEITAS_ARQ := "res://data/fabricar.json"
const PASTA_ICONES := "res://art/ui/icones_fabricar/"
const SLOTS_BAU := 36
const PILHA_MAX := 999
const ID_CASA := "casa_vale"
## areas onde a Vale pode colocar baus (a casa dela fica na fazenda: baus dentro dela tambem valem)
const AREAS_BAU := ["fazenda", "fazenda_grande"]
const EXTRA := {
	"bau": {"nome": "Baú de madeira", "cat": "movel", "preco": 125,
		"desc": "36 espaços. Na aba Fabricar ou aqui: Enter coloca o baú na frente da Vale (na fazenda ou em casa)."},
}
## ferramentas da barra (sempre com a Vale; nao vao para o bau)
const FERRAMENTAS_FIXAS := [
	["enxada", "Enxada", "Ara a terra para plantar."],
	["picareta", "Picareta", "Quebra pedras e minérios."],
	["machado", "Machado", "Corta galhos, tocos e árvores (a árvore solta toras: madeira)."],
	["foice", "Foice", "Corta o mato (fibra) e colhe."],
	["regador", "Regador", "Rega a terra arada. Encha no lago ou no poço."],
	["vara", "Vara de pesca", "Pesca no lago."],
]
const ABAS := [
	{"id": "tudo", "nome": "Tudo"},
	{"id": "sementes", "nome": "Sementes", "cats": ["semente"]},
	{"id": "colheitas", "nome": "Colheitas", "cats": ["colheita"]},
	{"id": "materiais", "nome": "Materiais", "cats": ["material", "movel"]},
	{"id": "minerios", "nome": "Minérios", "cats": ["minerio", "lingote"]},
	{"id": "pesca", "nome": "Pesca", "cats": ["peixe", "pesca"]},
	{"id": "consumo", "nome": "Consumo", "cats": ["pocao", "comida", "pet"]},
	{"id": "missao", "nome": "Missão", "cats": ["missao", "mapa", "reliquia", "roupa"]},
	{"id": "ferramentas", "nome": "Ferramentas", "cats": ["ferramenta", "forjado", "barra"]},
	{"id": "equipamento", "nome": "Equipamento", "especial": true},
	{"id": "fabricar", "nome": "Fabricar", "especial": true},
]
const ORDENS := ["categoria", "nome", "quantidade", "valor"]
const NOME_ORDEM := {"categoria": "Categoria", "nome": "Nome", "quantidade": "Quantidade", "valor": "Valor"}
const NOME_CAT := {"semente": "Semente", "colheita": "Colheita", "peixe": "Peixe", "material": "Material", "movel": "Móvel",
	"pesca": "Pesca", "pocao": "Poção", "comida": "Comida", "minerio": "Minério", "lingote": "Lingote", "ferramenta": "Ferramenta",
	"forjado": "Peça forjada", "barra": "Ferramenta da barra", "mapa": "Mapa", "roupa": "Roupa", "reliquia": "Relíquia", "pet": "Pet",
	"missao": "Item de missão", "equip": "Equipamento"}
static var _receitas := {}

# ---------------------------------------------------------------- catalogo
static func info(id: String) -> Dictionary:
	if EXTRA.has(id):
		return EXTRA[id]
	return Itens.info(id)

static func nome(id: String) -> String:
	return String(info(id).get("nome", id))

static func preco(id: String) -> int:
	return int(info(id).get("preco", 0))

static func desc(id: String) -> String:
	return String(info(id).get("desc", ""))

## categoria de exibicao (o catalogo chama de "equip" tambem as pecas da forja que ainda sao contagem)
static func categoria(id: String) -> String:
	if EXTRA.has(id):
		return String(EXTRA[id].cat)
	for f in FERRAMENTAS_FIXAS:
		if f[0] == id:
			return "barra"
	if Itens.eh_equip(id):
		return "equip"
	var c := Itens.cat(id)
	return "forjado" if c == "equip" else c

static func aba_de(id: String) -> String:
	var c := categoria(id)
	if c == "equip":
		return "equipamento"
	for a in ABAS:
		if (a.get("cats", []) as Array).has(c):
			return String(a.id)
	return "materiais"

static func icone(id: String) -> Texture2D:
	var cam := ProjectSettings.globalize_path(PASTA_ICONES + id + ".png")
	if FileAccess.file_exists(cam) and not Itens._icones.has(id):
		var img := Image.load_from_file(cam)
		if img and not img.is_empty():
			Itens._icones[id] = ImageTexture.create_from_image(img)
	return Itens.icone(id)

## pode ir para o bau? (equipamento fica na aba Equipamento: Equip.normalizar recria as pecas iniciais
## ao carregar, entao guardar pecas num bau duplicaria itens; ferramentas da barra sao fixas)
static func movivel(id: String) -> bool:
	var c := categoria(id)
	return c != "equip" and c != "barra" and id != ""

# ---------------------------------------------------------------- lista agregada
static func entrada(id: String, q: int, fonte := "mochila", mov := true, extra_nome := "") -> Dictionary:
	return {"id": id, "q": q, "nome": nome(id) + extra_nome, "cat": categoria(id), "preco": preco(id), "desc": desc(id),
		"movivel": mov and movivel(id), "fonte": fonte, "aba": aba_de(id)}

## tudo o que a Vale tem, de todas as fontes (sem copiar estado)
static func tudo(estado) -> Array:
	var out: Array = []
	for k in estado.itens:
		var q := int(estado.itens[k])
		if q > 0:
			out.append(entrada(String(k), q))
	for f in FERRAMENTAS_FIXAS:
		var e := entrada(String(f[0]), 1, "barra", false)
		e.nome = String(f[1])
		e.desc = String(f[2]) + ("  Água: %d/%d." % [int(estado.regador), int(estado.REGADOR_MAX)] if f[0] == "regador" else "")
		out.append(e)
	var eq = estado.equipamento
	if eq is Dictionary and eq.get("possui", null) is Array:
		for id in eq.possui:
			if Equip.ITENS.has(String(id)):
				var e2 := entrada(String(id), 1, "equipamento", false, "  (vestido)" if Equip.esta_equipado(eq, String(id)) else "")
				out.append(e2)
	# saque da incursao atual (vai para a mochila ao voltar a superficie: jogo_ilha._trazer_saque_da_masmorra)
	var Sessao = load("res://scripts/dungeon/sessao_masmorra.gd")
	if Sessao and bool(Sessao.ativa):
		var it: Dictionary = Sessao.inventario.get("itens", {})
		for k in it:
			if int(it[k]) > 0 and String(k) != "ouro":
				out.append(entrada(String(k), int(it[k]), "masmorra", false, "  (masmorra)"))
	return out

static func lista(estado, aba := "tudo", ordem := "categoria") -> Array:
	var out: Array = []
	for e in tudo(estado):
		if aba == "tudo" or String(e.aba) == aba:
			out.append(e)
	return ordenar(out, ordem)

static func _peso_cat(c: String) -> int:
	var i := 0
	for a in ABAS:
		var cats: Array = a.get("cats", [])
		if cats.has(c):
			return i * 10 + cats.find(c)
		i += 1
	return 900 if c == "equip" else 800

static func ordenar(l: Array, ordem := "categoria") -> Array:
	var r := l.duplicate()
	match ordem:
		"nome":
			r.sort_custom(func(a, b): return String(a.nome).naturalnocasecmp_to(String(b.nome)) < 0)
		"quantidade":
			r.sort_custom(func(a, b): return int(a.q) > int(b.q) if int(a.q) != int(b.q) else String(a.nome).naturalnocasecmp_to(String(b.nome)) < 0)
		"valor":
			r.sort_custom(func(a, b): return int(a.preco) * int(a.q) > int(b.preco) * int(b.q) if int(a.preco) * int(a.q) != int(b.preco) * int(b.q) else String(a.nome).naturalnocasecmp_to(String(b.nome)) < 0)
		_:
			r.sort_custom(func(a, b):
				var pa := _peso_cat(String(a.cat))
				var pb := _peso_cat(String(b.cat))
				return pa < pb if pa != pb else String(a.nome).naturalnocasecmp_to(String(b.nome)) < 0)
	return r

## quantidade total de um item: mochila + todos os baus (testes: "nenhum item some")
static func total(estado, id: String) -> int:
	var n := int(estado.qtd(id))
	for b in estado.baus:
		n += qtd_bau(b, id)
	return n

# ---------------------------------------------------------------- baus (dados)
static func slots_vazios() -> Array:
	var s: Array = []
	for i in SLOTS_BAU:
		s.append({})
	return s

static func novo_bau(id: String, area: String, pos: Vector3, rot := 0.0, fixo := false) -> Dictionary:
	return {"id": id, "area": area, "pos": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)],
		"rot": snappedf(rot, 0.001), "fixo": fixo, "slots": slots_vazios()}

## save -> lista valida (save antigo sem "baus": lista vazia; entradas quebradas sao ignoradas, itens nunca somem)
static func normalizar_baus(d) -> Array:
	var out: Array = []
	if not d is Array:
		return out
	var ids := {}
	for b in d:
		if not b is Dictionary or String(b.get("id", "")) == "" or ids.has(String(b.id)):
			continue
		var p = b.get("pos", [0, 0, 0])
		if not p is Array or p.size() < 3:
			p = [0, 0, 0]
		var nb := novo_bau(String(b.id), String(b.get("area", "fazenda")), Vector3(float(p[0]), float(p[1]), float(p[2])),
			float(b.get("rot", 0.0)), bool(b.get("fixo", false)))
		var sl = b.get("slots", [])
		var sobra: Array = []
		if sl is Array:
			for i in sl.size():
				var s = sl[i]
				if s is Dictionary and String(s.get("id", "")) != "" and int(s.get("q", 0)) > 0:
					var item := {"id": String(s.id), "q": mini(int(s.q), PILHA_MAX)}
					if i < SLOTS_BAU:
						nb.slots[i] = item
					else:
						sobra.append(item)
		for item in sobra:
			_somar_bau(nb, String(item.id), int(item.q))
		ids[nb.id] = true
		out.append(nb)
	return out

static func achar(estado, id: String) -> Dictionary:
	for b in estado.baus:
		if String(b.id) == id:
			return b
	return {}

## o bau que ja existia (decoracao) na Casa da Vale vira um bau de verdade (fixo: nao se recolhe)
static func bau_casa(estado) -> Dictionary:
	var b := achar(estado, ID_CASA)
	if b.is_empty():
		b = novo_bau(ID_CASA, "casa", Vector3.ZERO, 0.0, true)
		estado.baus.append(b)
	return b

static func nome_bau(b: Dictionary) -> String:
	if String(b.get("id", "")) == ID_CASA:
		return "Baú da casa"
	return "Baú de madeira nº %s" % String(b.id).trim_prefix("bau_")

static func qtd_bau(b: Dictionary, id: String) -> int:
	var n := 0
	for s in b.slots:
		if s is Dictionary and String(s.get("id", "")) == id:
			n += int(s.q)
	return n

static func vazio(b: Dictionary) -> bool:
	for s in b.slots:
		if s is Dictionary and not s.is_empty():
			return false
	return true

static func livres(b: Dictionary) -> int:
	var n := 0
	for s in b.slots:
		if not (s is Dictionary) or s.is_empty():
			n += 1
	return n

## quantos de "id" ainda cabem no bau
static func cabe(b: Dictionary, id: String) -> int:
	var n := 0
	for s in b.slots:
		if not (s is Dictionary) or s.is_empty():
			n += PILHA_MAX
		elif String(s.id) == id:
			n += PILHA_MAX - int(s.q)
	return n

static func _somar_bau(b: Dictionary, id: String, n: int) -> int:
	var resto := n
	for s in b.slots:
		if resto <= 0:
			break
		if s is Dictionary and not s.is_empty() and String(s.id) == id and int(s.q) < PILHA_MAX:
			var k := mini(resto, PILHA_MAX - int(s.q))
			s.q = int(s.q) + k
			resto -= k
	for i in b.slots.size():
		if resto <= 0:
			break
		var s = b.slots[i]
		if not (s is Dictionary) or s.is_empty():
			var k := mini(resto, PILHA_MAX)
			b.slots[i] = {"id": id, "q": k}
			resto -= k
	return n - resto

## mochila -> bau. Devolve quantos foram (0 = nada; nunca perde item)
static func guardar(estado, b: Dictionary, id: String, n := 1) -> int:
	if b.is_empty() or not movivel(id):
		return 0
	var k := mini(mini(n, int(estado.qtd(id))), cabe(b, id))
	if k <= 0:
		return 0
	var foi := _somar_bau(b, id, k)
	estado.somar(id, -foi)
	return foi

## bau (espaco i) -> mochila
static func retirar(estado, b: Dictionary, i: int, n := 1) -> int:
	if b.is_empty() or i < 0 or i >= b.slots.size():
		return 0
	var s = b.slots[i]
	if not (s is Dictionary) or s.is_empty():
		return 0
	var k := mini(n, int(s.q))
	var id := String(s.id)
	s.q = int(s.q) - k
	if int(s.q) <= 0:
		b.slots[i] = {}
	estado.somar(id, k)
	return k

## guarda no bau tudo o que a Vale tem e que ja existe nele (estilo "empilhar iguais")
static func guardar_iguais(estado, b: Dictionary) -> int:
	var n := 0
	var ids := {}
	for s in b.slots:
		if s is Dictionary and not s.is_empty():
			ids[String(s.id)] = true
	for id in ids:
		n += guardar(estado, b, String(id), int(estado.qtd(String(id))))
	return n

## junta pilhas iguais e ordena (categoria, nome); nao muda o total de nada
static func ordenar_bau(b: Dictionary) -> void:
	var soma := {}
	for s in b.slots:
		if s is Dictionary and not s.is_empty():
			soma[String(s.id)] = int(soma.get(String(s.id), 0)) + int(s.q)
	var l: Array = []
	for id in soma:
		l.append(entrada(String(id), int(soma[id]), "bau"))
	l = ordenar(l, "categoria")
	b.slots = slots_vazios()
	for e in l:
		_somar_bau(b, String(e.id), int(e.q))

# ---------------------------------------------------------------- fabricar / colocar / recolher
static func receitas() -> Dictionary:
	if _receitas.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(RECEITAS_ARQ))
		_receitas = d.receitas if d is Dictionary and d.get("receitas", null) is Dictionary else {}
	return _receitas

## "" = pode; senao o motivo
static func pode_fabricar(estado, rid: String) -> String:
	var r: Dictionary = receitas().get(rid, {})
	if r.is_empty():
		return "Receita desconhecida."
	var falta: Array = []
	for ing in r.ingredientes:
		var tem := int(estado.qtd(String(ing)))
		var precisa := int(r.ingredientes[ing])
		if tem < precisa:
			falta.append("%s %d/%d" % [nome(String(ing)), tem, precisa])
	return "" if falta.is_empty() else "Falta: " + ", ".join(falta)

static func fabricar(estado, rid: String) -> String:
	var motivo := pode_fabricar(estado, rid)
	if motivo != "":
		return motivo
	var r: Dictionary = receitas()[rid]
	for ing in r.ingredientes:
		estado.somar(String(ing), -int(r.ingredientes[ing]))
	estado.somar(String(r.resultado), int(r.get("qtd", 1)))
	return "Fabricou: %s (agora %d)." % [nome(String(r.resultado)), int(estado.qtd(String(r.resultado)))]

static func proximo_id(estado) -> String:
	var n := 0
	for b in estado.baus:
		var s := String(b.id)
		if s.begins_with("bau_"):
			n = maxi(n, int(s.trim_prefix("bau_")))
	return "bau_%d" % (n + 1)

## gasta 1 "bau" da mochila e cria o bau no mundo; {} se nao tem bau para colocar
static func colocar(estado, area: String, pos: Vector3, rot := 0.0) -> Dictionary:
	if int(estado.qtd("bau")) <= 0:
		return {}
	estado.somar("bau", -1)
	var b := novo_bau(proximo_id(estado), area, pos, rot)
	estado.baus.append(b)
	return b

## "" = recolheu (volta 1 "bau" para a mochila); senao o motivo
static func recolher(estado, id: String) -> String:
	var b := achar(estado, id)
	if b.is_empty():
		return "Baú não encontrado."
	if bool(b.get("fixo", false)):
		return "O baú da casa fica onde está."
	if not vazio(b):
		return "Esvazie o baú antes de recolher."
	estado.baus.erase(b)
	estado.somar("bau", 1)
	return ""
