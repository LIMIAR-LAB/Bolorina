extends RefCounted
## Modelo da interface da forja (PROPOSTA). Sem nós: dá para testar headless.
## Junta scripts/forja/forja.gd (receitas, itens, materiais) com scripts/missoes/gerenciador_missoes.gd
## (mochila, reservas e a missão "Atrasada desde amanhã").
##
## Regra de ouro: só gasta via gerenciador.pode_gastar()/gastar_excedente(). O cobre reservado para a
## missão e os itens de missão nunca entram num custo da forja.
##
## Uso:
##   var m = ForjaModelo.new(gerenciador)                # ou ForjaModelo.new(gerenciador, forja, niveis)
##   m.lista("pode")                                     # filtros: "pode" | "falta" | "travado" | "tudo"
##   m.detalhe(receita_id)                               # materiais, de onde vem o que falta, comparação
##   m.forjar(receita_id) / m.equipar(item_id)
##   m.eco_opcoes() / m.escolher_eco("eco_rapido")
signal mudou
signal item_forjado(receita_id: String, item_id: String)
signal item_equipado(slot: String, item_id: String)
signal eco_escolhido(variacao_id: String, pago: bool)
signal reforco_feito(item_id: String)

const Forja = preload("res://scripts/forja/forja.gd")
const DADOS_UI := "res://data/forja/forja_ui.json"
const PASTA_ICONES := "res://art/ui/icones_forja/"
const FILTROS := ["pode", "falta", "travado", "tudo"]
const NOMES_FILTRO := {"pode": "Dá para forjar", "falta": "Falta material", "travado": "Travado", "tudo": "Tudo"}
const STATS := [["ataque", "Ataque"], ["defesa", "Defesa"], ["velocidade", "Velocidade"], ["multiplicador_dano", "Dano ×"], ["nivel_mineracao", "Mineração"]]
const METAIS := ["cobre", "ferro", "aco", "brasa", "prata", "celeste", "cronostio", "adamantium", "paradoxal", "porto"]

var forja                       # scripts/forja/forja.gd
var g                           # gerenciador_missoes.gd
var ui: Dictionary = {}
var forja_id := "ferraria_porto"
var niveis: Dictionary = {}
var equipado: Dictionary = {}   # slot -> item_id
var mochila_equip: Array = []   # instâncias forjadas ainda não equipadas {"id","reforja","encanto"}
var variacoes_compradas: Array = []
var _icones: Dictionary = {}

func _init(gerenciador, forja_existente = null, niveis_forja: Dictionary = {}) -> void:
	g = gerenciador
	forja = forja_existente if forja_existente != null else Forja.new()
	var f := FileAccess.get_file_as_string(DADOS_UI)
	var d = JSON.parse_string(f) if f != "" else null
	ui = d if d is Dictionary else {}
	forja_id = String(ui.get("forja_padrao", "ferraria_porto"))
	niveis = niveis_forja.duplicate() if not niveis_forja.is_empty() else Dictionary(ui.get("niveis_iniciais", {forja_id: 1})).duplicate()
	for it in ui.get("itens_extra", []):
		if not forja.itens.has(String(it.id)):
			forja.itens[String(it.id)] = it
	for mt in ui.get("materiais_extra", []):
		if not forja.materiais.has(String(mt.id)):
			forja.materiais[String(mt.id)] = mt
	equipado["arma"] = String(g.arma_atual) if g != null else "facao_fazenda"
	if g != null and String(g.variacao_eco) != "":
		variacoes_compradas.append(String(g.variacao_eco))
	if g != null and g.has_signal("arma_trocada"):
		g.arma_trocada.connect(func(_de, para): equipado["arma"] = String(para); mudou.emit())

# ------------------------------------------------------------------ mochila (via gerenciador)
func tem(id: String) -> int:
	return int(g.materiais.get(id, 0))

func livre(id: String) -> int:
	return g.excedente(id)

func reservado(id: String) -> int:
	return g.reservado(id)

func ouro() -> int:
	return tem("ouro")

static func custo_de(r: Dictionary) -> Dictionary:
	var c: Dictionary = {}
	for k in r.get("materiais", {}):
		c[String(k)] = int(r.materiais[k])
	if int(r.get("ouro", 0)) > 0:
		c["ouro"] = int(r.ouro)
	return c

# ------------------------------------------------------------------ lista e filtros
func receitas_visiveis() -> Array:
	var out: Array = []
	for id in forja.receitas:
		var r: Dictionary = forja.receitas[id]
		if String(r.forja) == forja_id:
			out.append(String(id))
	out.sort_custom(func(a, b): return _ordem(a) < _ordem(b))
	return out

func _ordem(id: String) -> String:
	var r: Dictionary = forja.receitas[id]
	var tipo := "0" if String(r.get("etapa", "")) == "fundicao" else _grupo_ordem(String(r.resultado))
	return "%s|%02d|%s" % [tipo, int(r.nivel_forja), id]

func _grupo_ordem(item_id: String) -> String:
	match String(forja.itens.get(item_id, {}).get("tipo", "")):
		"arma": return "1"
		"armadura": return "2"
		"acessorio": return "3"
		"ferramenta": return "4"
	return "5"

func grupo(receita_id: String) -> String:
	var r: Dictionary = forja.receitas.get(receita_id, {})
	if String(r.get("etapa", "")) == "fundicao":
		return "Fundição"
	match String(forja.itens.get(String(r.get("resultado", "")), {}).get("tipo", "")):
		"arma": return "Armas"
		"armadura": return "Armaduras"
		"acessorio": return "Acessórios"
		"ferramenta": return "Ferramentas"
	return "Outros"

## "pode" | "falta" | "travado"
func situacao(receita_id: String) -> String:
	var r: Dictionary = forja.receitas.get(receita_id, {})
	if r.is_empty():
		return "travado"
	if int(niveis.get(String(r.forja), 0)) < int(r.nivel_forja):
		return "travado"
	return "pode" if g.pode_gastar(custo_de(r)) else "falta"

func lista(filtro := "tudo") -> Array:
	var out: Array = []
	for id in receitas_visiveis():
		if filtro == "tudo" or situacao(id) == filtro:
			out.append(id)
	return out

func contagem() -> Dictionary:
	var c := {"pode": 0, "falta": 0, "travado": 0, "tudo": 0}
	for id in receitas_visiveis():
		c[situacao(id)] += 1
		c.tudo += 1
	return c

# ------------------------------------------------------------------ detalhe
func detalhe(receita_id: String) -> Dictionary:
	var r: Dictionary = forja.receitas.get(receita_id, {})
	if r.is_empty():
		return {}
	var res_id := String(r.resultado)
	var it: Dictionary = forja.itens.get(res_id, forja.materiais.get(res_id, {}))
	var mats: Array = []
	var custo := custo_de(r)
	for k in custo:
		var precisa := int(custo[k])
		var lv := livre(k)
		var linha := {"id": k, "nome": nome(k), "precisa": precisa, "tem": tem(k), "livre": lv,
			"reservado": reservado(k), "ok": lv >= precisa, "falta": maxi(0, precisa - lv), "origem": ""}
		if not linha.ok:
			linha.origem = origem(k)
			if tem(k) >= precisa and lv < precisa:
				linha.origem = "%d reservado(s) para a missão. %s" % [reservado(k), linha.origem]
		mats.append(linha)
	var sit := situacao(receita_id)
	var motivo := ""
	if sit == "travado":
		motivo = motivo_travado(r)
	elif sit == "falta":
		motivo = "Falta material (o reservado para a missão não conta)."
	return {"id": receita_id, "resultado": res_id, "nome": nome(res_id), "quantidade": int(r.get("quantidade", 1)),
		"descricao": descricao(res_id), "tipo": String(it.get("tipo", "")), "grupo": grupo(receita_id),
		"situacao": sit, "motivo": motivo, "materiais": mats, "slot": slot_de(res_id),
		"comparacao": comparar(res_id), "equipavel": equipavel(res_id), "testavel": testavel(res_id)}

func motivo_travado(r: Dictionary) -> String:
	var f: Dictionary = forja.forjas.get(String(r.forja), {})
	var nv := int(r.nivel_forja)
	var nome_nivel := ""
	for n in f.get("niveis", []):
		if int(n.nivel) == nv:
			nome_nivel = String(n.nome)
	return "%s precisa do nível %d%s." % [String(f.get("nome", r.forja)), nv, (" (" + nome_nivel + ")") if nome_nivel != "" else ""]

func descricao(id: String) -> String:
	var it: Dictionary = forja.itens.get(id, {})
	for k in ["especial", "efeito", "descricao"]:
		if String(it.get(k, "")) != "":
			return String(it[k])
	var m: Dictionary = forja.materiais.get(id, {})
	return String(m.get("nota", ""))

func nome(id: String) -> String:
	if forja.itens.has(id): return String(forja.itens[id].get("nome", id))
	if forja.materiais.has(id): return String(forja.materiais[id].get("nome", id))
	return id

## De onde vem um material: área/andar, ou a fundição que o produz (e de onde vem o minério dela).
func origem(id: String, profundidade := 0) -> String:
	var m: Dictionary = forja.materiais.get(id, {})
	var partes: Array = []
	for l in m.get("onde", []):
		var loc: Dictionary = forja.locais.get(String(l), {})
		var txt := String(loc.get("nome", l))
		if m.has("andares") and String(l) == "minas_da_cinza":
			var a: Array = m.andares
			txt += (", andar %d" % int(a[0])) if int(a[0]) == int(a[1]) else (", andares %d–%d" % [int(a[0]), int(a[1])])
		partes.append(txt)
	var txt_onde := " / ".join(partes)
	if txt_onde == "" and profundidade < 2:
		var rec: Dictionary = forja.receita_de(id)
		if not rec.is_empty() and String(rec.get("etapa", "")) == "fundicao":
			var ins: Array = []
			for k in rec.materiais:
				ins.append("%d %s" % [int(rec.materiais[k]), nome(k)])
			var fonte := origem(String(rec.materiais.keys()[0]), profundidade + 1)
			txt_onde = "Fundir aqui: " + " + ".join(ins) + ((" (" + fonte + ")") if fonte != "" else "")
	var nota := String(m.get("nota", ""))
	if txt_onde == "":
		return nota if nota != "" else "Origem ainda não definida."
	if nota != "" and profundidade == 0 and partes.size() > 0:
		return txt_onde + ". " + nota
	return txt_onde

# ------------------------------------------------------------------ comparação e equipamento
func slot_de(item_id: String) -> String:
	var it: Dictionary = forja.itens.get(item_id, {})
	if it.is_empty():
		return ""
	var tipo := String(it.get("tipo", ""))
	if tipo == "arma":
		return "arma"
	if tipo == "acessorio":
		return "acessorio"
	var cat := String(it.get("categoria", ""))
	for s in ui.get("slots", {}):
		if cat in ui.slots[s]:
			return String(s)
	return cat

func equipavel(item_id: String) -> bool:
	return slot_de(item_id) != ""

func testavel(item_id: String) -> bool:
	return String(forja.itens.get(item_id, {}).get("tipo", "")) == "arma"

func _stats(item_id: String) -> Dictionary:
	var it: Dictionary = forja.itens.get(item_id, {})
	var s := {}
	for par in STATS:
		if it.has(par[0]):
			s[par[0]] = float(it[par[0]])
	var ef := String(it.get("efeito", ""))
	var rx := RegEx.create_from_string("\\+(\\d+) de defesa")
	var mt := rx.search(ef)
	if mt != null:
		s["defesa"] = float(mt.get_string(1)) + float(s.get("defesa", 0.0))
	return s

## Compara o item com o que está equipado no mesmo slot: [{stat, nome, atual, novo, delta, melhor}]
func comparar(item_id: String) -> Dictionary:
	var slot := slot_de(item_id)
	var atual_id := String(equipado.get(slot, ""))
	var novo := _stats(item_id)
	var atual := _stats(atual_id) if atual_id != "" else {}
	var linhas: Array = []
	for par in STATS:
		var k: String = par[0]
		if not novo.has(k) and not atual.has(k):
			continue
		var a := float(atual.get(k, 0.0))
		var n := float(novo.get(k, 0.0))
		linhas.append({"stat": k, "nome": par[1], "atual": a, "novo": n, "delta": n - a, "melhor": n > a, "pior": n < a})
	return {"slot": slot, "equipado": atual_id, "equipado_nome": nome(atual_id) if atual_id != "" else "nada", "linhas": linhas}

func equipar(item_id: String) -> bool:
	var slot := slot_de(item_id)
	if slot == "" or not possui(item_id):
		return false
	var antigo := String(equipado.get(slot, ""))
	for i in mochila_equip.size():
		if String(mochila_equip[i].id) == item_id:
			mochila_equip.remove_at(i)
			break
	if antigo != "" and antigo != item_id:
		mochila_equip.append({"id": antigo, "reforja": 0, "encanto": ""})
	equipado[slot] = item_id
	if slot == "arma" and g != null:
		g.arma_atual = item_id
	item_equipado.emit(slot, item_id)
	mudou.emit()
	return true

func possui(item_id: String) -> bool:
	if item_id in equipado.values():
		return true
	for inst in mochila_equip:
		if String(inst.id) == item_id:
			return true
	return false

# ------------------------------------------------------------------ forjar
func forjar(receita_id: String) -> Dictionary:
	var r: Dictionary = forja.receitas.get(receita_id, {})
	if r.is_empty():
		return {"ok": false, "motivo": "receita desconhecida"}
	var sit := situacao(receita_id)
	if sit == "travado":
		return {"ok": false, "motivo": motivo_travado(r)}
	if not g.gastar_excedente(custo_de(r)):
		return {"ok": false, "motivo": "Falta material (o reservado para a missão não conta)."}
	var res_id := String(r.resultado)
	var n := int(r.get("quantidade", 1))
	if equipavel(res_id):
		for i in n:
			mochila_equip.append({"id": res_id, "reforja": 0, "encanto": ""})
	else:
		g.adicionar_item(res_id, n)
	g.notificar("item_forjado", res_id, n)
	item_forjado.emit(receita_id, res_id)
	mudou.emit()
	return {"ok": true, "resultado": res_id, "quantidade": n}

# ------------------------------------------------------------------ missão: reforço e eco
func _etapa_ativa(missao_id: String, etapa_id: String) -> bool:
	if g == null:
		return false
	var m = g.missao(missao_id)
	if m == null or not m.ativa():
		return false
	return String(m.etapa_atual().get("id", "")) == etapa_id

func reforco_disponivel() -> bool:
	var rf: Dictionary = ui.get("reforco_missao", {})
	return not rf.is_empty() and _etapa_ativa(String(rf.missao), String(rf.etapa)) and String(g.arma_atual) == String(rf.alvo)

func reforco_info() -> Dictionary:
	var rf: Dictionary = ui.get("reforco_missao", {})
	if rf.is_empty():
		return {}
	return {"nome": String(rf.nome), "texto": String(rf.texto), "de": String(rf.alvo), "para": String(rf.resultado),
		"comparacao": _comparar_ids(String(rf.alvo), String(rf.resultado))}

func _comparar_ids(a_id: String, b_id: String) -> Array:
	var a := _stats(a_id)
	var b := _stats(b_id)
	var linhas: Array = []
	for par in STATS:
		if a.has(par[0]) or b.has(par[0]):
			var va := float(a.get(par[0], 0.0))
			var vb := float(b.get(par[0], 0.0))
			linhas.append({"stat": par[0], "nome": par[1], "atual": va, "novo": vb, "delta": vb - va, "melhor": vb > va, "pior": vb < va})
	return linhas

## Faz o reforço da missão (grátis). O gerenciador troca a arma e libera o eco.
func fazer_reforco() -> bool:
	if not reforco_disponivel():
		return false
	var rf: Dictionary = ui.reforco_missao
	g.notificar(String(rf.evento), String(rf.alvo))
	reforco_feito.emit(String(rf.resultado))
	mudou.emit()
	return true

func _variacoes() -> Dictionary:
	var m = g.missao(String(ui.get("eco", {}).get("missao", ""))) if g != null else null
	return m.dados.get("variacoes_eco", {}) if m != null else {}

func _custo_eco(vid: String) -> Dictionary:
	var m = g.missao(String(ui.get("eco", {}).get("missao", "")))
	return m.dados.get("custos", {}).get(vid, {}) if m != null else {}

## "missao" (escolha da etapa), "livre" (depois da missão) ou "" (indisponível).
func modo_eco() -> String:
	var e: Dictionary = ui.get("eco", {})
	if e.is_empty() or g == null:
		return ""
	if _etapa_ativa(String(e.missao), String(e.etapa)):
		return "missao"
	if g.estado != null and g.estado.tem(String(e.get("desbloqueio_pos_missao", ""))):
		return "livre"
	return ""

func eco_opcoes() -> Array:
	var vs := _variacoes()
	var base: Dictionary = vs.get("eco_base", {})
	var out: Array = []
	var modo := modo_eco()
	for vid in ["eco_rapido", "eco_pesado"]:
		var v: Dictionary = vs.get(vid, {})
		if v.is_empty():
			continue
		var custo := _custo_eco(vid)
		var comprada: bool = vid in variacoes_compradas
		var pode: bool = comprada or g.pode_gastar(custo)
		var fiado: bool = modo == "missao" and not pode
		var deltas: Array = []
		for par in [["atraso_s", "Atraso (s)", true], ["dano_relativo", "Dano do eco", false], ["raio_m", "Raio (m)", false]]:
			var a := float(base.get(par[0], 0.0))
			var b := float(v.get(par[0], 0.0))
			var menor_e_melhor: bool = par[2]
			deltas.append({"stat": par[0], "nome": par[1], "atual": a, "novo": b, "delta": b - a,
				"melhor": (b < a) if menor_e_melhor else (b > a), "pior": (b > a) if menor_e_melhor else (b < a)})
		out.append({"id": vid, "nome": String(v.get("nome", vid)), "descricao": String(v.get("descricao", "")),
			"extra": String(v.get("extra", "")), "custo": custo, "pode_pagar": pode, "fiado": fiado,
			"comprada": comprada, "atual": String(g.variacao_eco) == vid, "comparacao": deltas, "modo": modo})
	return out

func escolher_eco(vid: String) -> Dictionary:
	var modo := modo_eco()
	var e: Dictionary = ui.get("eco", {})
	if modo == "missao":
		var marca := String(e.marcas.get(vid, ""))
		if marca == "":
			return {"ok": false, "motivo": "variação desconhecida"}
		var antes := tem("lasca_de_eco")
		g.estado.marcar(marca)          # o gerenciador aplica a escolha da etapa (gasta o excedente ou anota fiado)
		var pago := tem("lasca_de_eco") < antes
		if not vid in variacoes_compradas:
			variacoes_compradas.append(vid)
		eco_escolhido.emit(vid, pago)
		mudou.emit()
		return {"ok": true, "pago": pago, "fiado": not pago}
	if modo == "livre":
		if not vid in variacoes_compradas:
			if not g.gastar_excedente(_custo_eco(vid)):
				return {"ok": false, "motivo": "Falta material para essa variação."}
			variacoes_compradas.append(vid)
		g.variacao_eco = vid
		g.estado.marcar("variacao_" + vid)
		g.variacao_eco_alterada.emit(vid, _variacoes().get(vid, {}))
		eco_escolhido.emit(vid, true)
		mudou.emit()
		return {"ok": true, "pago": true, "fiado": false}
	return {"ok": false, "motivo": "O eco ainda não está liberado na forja."}

# ------------------------------------------------------------------ ícones
## Caminho do ícone e a cor (tinta de metal quando o ícone usa a peça de cobre como base).
func icone_info(id: String) -> Dictionary:
	var direto := PASTA_ICONES + id + ".png"
	if FileAccess.file_exists(direto):
		return {"caminho": direto, "cor": Color.WHITE}
	var metal := ""
	for p in id.split("_"):
		if p in METAIS:
			metal = p
	var cor := Color(String(ui.get("cores_metal", {}).get(metal, "ffffff")))
	var cat := String(forja.itens.get(id, {}).get("categoria", ""))
	var tipo := String(forja.materiais.get(id, {}).get("tipo", forja.itens.get(id, {}).get("tipo", "")))
	var candidatos: Array = []
	if cat != "":
		candidatos.append(cat + "_cobre")
	if tipo in ["lingote", "liga"]:
		candidatos.append("lingote_cobre")
	elif tipo == "minerio":
		candidatos.append("minerio_cobre")
	match String(forja.itens.get(id, {}).get("tipo", "")):
		"arma": candidatos.append("espada_cobre")
		"acessorio": candidatos.append("lingote_cobre")
		"ferramenta": candidatos.append("picareta_cobre")
	candidatos.append("carvao")
	for c in candidatos:
		if FileAccess.file_exists(PASTA_ICONES + String(c) + ".png"):
			return {"caminho": PASTA_ICONES + String(c) + ".png", "cor": cor}
	return {"caminho": "", "cor": cor}

func icone(id: String) -> Texture2D:
	var info := icone_info(id)
	var c := String(info.caminho)
	if c == "":
		return null
	if _icones.has(c):
		return _icones[c]
	var img := Image.load_from_file(ProjectSettings.globalize_path(c))
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	_icones[c] = tex
	return tex

func nome_variacao(vid: String) -> String:
	return String(_variacoes().get(vid, {}).get("nome", vid))
