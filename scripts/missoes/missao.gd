extends RefCounted
## Uma missão carregada de JSON (data/missoes/*.json) e o seu andamento (PROPOSTA).
## A lógica de transição fica em gerenciador_missoes.gd; aqui ficam os dados e o estado serializável.

var dados: Dictionary = {}
var id := ""
var situacao := "inativa"            # inativa | ativa | concluida
var indice := -1                     # etapa atual
var contadores: Dictionary = {}      # "<etapa_id>/c0" -> int ; "<etapa_id>/p0" (pular_quando) ; "opc:<id>/c0"
var opcionais: Dictionary = {}       # id -> inativo | ativo | concluido | expirado
var etapas_concluidas: Array = []
var etapas_puladas: Array = []
var escolhas: Dictionary = {}        # etapa_id -> marca escolhida

func _init(d: Dictionary = {}) -> void:
	dados = d
	id = String(d.get("id", ""))
	for o in d.get("opcionais", []):
		opcionais[String(o.id)] = "inativo"

static func de_arquivo(caminho: String):
	var txt := FileAccess.get_file_as_string(caminho)
	var d = JSON.parse_string(txt)
	if not d is Dictionary:
		push_error("missao invalida: " + caminho)
		return null
	return load("res://scripts/missoes/missao.gd").new(d)

func ativa() -> bool:
	return situacao == "ativa"

func concluida() -> bool:
	return situacao == "concluida"

func etapas() -> Array:
	return dados.get("etapas", [])

func etapa_atual() -> Dictionary:
	if ativa() and indice >= 0 and indice < etapas().size():
		return etapas()[indice]
	return {}

func etapa(etapa_id: String) -> Dictionary:
	for e in etapas():
		if String(e.id) == etapa_id:
			return e
	return {}

func indice_de(etapa_id: String) -> int:
	var es := etapas()
	for i in es.size():
		if String(es[i].id) == etapa_id:
			return i
	return -1

func opcional(opc_id: String) -> Dictionary:
	for o in dados.get("opcionais", []):
		if String(o.id) == opc_id:
			return o
	return {}

func opcionais_ativos() -> Array:
	var r: Array = []
	for o in dados.get("opcionais", []):
		if String(opcionais.get(String(o.id), "")) == "ativo":
			r.append(o)
	return r

func item_e_de_missao(item_id: String) -> bool:
	var it: Dictionary = dados.get("itens", {}).get(item_id, {})
	return String(it.get("tipo", "")) in ["missao", "documento"]

## Texto do objetivo na tela, com contador quando a etapa tem "progresso_tela".
func texto_objetivo() -> String:
	var e := etapa_atual()
	if e.is_empty():
		return ""
	var t := String(e.get("objetivo", ""))
	var p := progresso(e)
	return t if p == "" else t + "  " + p

func progresso(e: Dictionary) -> String:
	var pt: Dictionary = e.get("progresso_tela", {})
	if pt.is_empty():
		return ""
	var conds: Array = e.get("condicoes", [])
	for i in conds.size():
		var c: Dictionary = conds[i]
		if String(c.get("tipo", "")) == "evento" and String(c.get("evento", "")) == String(pt.get("evento", "")) and String(c.get("alvo", "*")) == String(pt.get("alvo", "*")):
			var total := int(c.get("quantidade", 1))
			var n := mini(int(contadores.get(String(e.id) + "/c" + str(i), 0)), total)
			return String(pt.get("texto", "{n}/{total}")).format({"n": n, "total": total})
	return ""

func serializar() -> Dictionary:
	return {"id": id, "situacao": situacao, "indice": indice, "contadores": contadores.duplicate(),
		"opcionais": opcionais.duplicate(), "etapas_concluidas": etapas_concluidas.duplicate(),
		"etapas_puladas": etapas_puladas.duplicate(), "escolhas": escolhas.duplicate()}

func desserializar(d: Dictionary) -> void:
	situacao = String(d.get("situacao", "inativa"))
	indice = int(d.get("indice", -1))
	contadores = d.get("contadores", {})
	for k in d.get("opcionais", {}):
		opcionais[k] = d.opcionais[k]
	etapas_concluidas = d.get("etapas_concluidas", [])
	etapas_puladas = d.get("etapas_puladas", [])
	escolhas = d.get("escolhas", {})
