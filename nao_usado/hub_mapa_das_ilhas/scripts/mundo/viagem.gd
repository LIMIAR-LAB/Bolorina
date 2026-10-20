extends RefCounted
## Viagem entre áreas pelo mapa das ilhas (PROPOSTA). Estático, sem autoload (project.godot intocado).
##
##   const Viagem = preload("res://scripts/mundo/viagem.gd")
##   Viagem.ir(get_tree(), "cidade_fantasma")          # usa chegada_mapa do registro
##   Viagem.ir(get_tree(), "minas_da_cinza", "andar_1") # masmorra: abre a sessão com a origem certa
##   Viagem.desbloqueada("fenda_cronal") -> bool
##   Viagem.garantir_viajante(get_tree())              # instala a tecla M em qualquer cena
##
## Ganchos para o jogo principal (Claude):
##   Viagem.provedor_desbloqueio = func(id: String, regra) -> int   # 1 libera, 0 bloqueia, -1 usa a regra padrão
##   Viagem.ao_viajar = func(de: String, para: String, ponto: String) -> void   # salvar antes de trocar de cena
##   Viagem.visitadas / Viagem.marcar_visitada(id)   # ligar ao save quando existir
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const VIAJANTE := "res://scripts/mundo/viajante.gd"
const MAPA := "res://scenes/ui/mapa_mundi.tscn"

static var visitadas: Dictionary = {}
static var desbloquear_tudo := false
static var provedor_desbloqueio: Callable
static var ao_viajar: Callable
## última viagem (testes)
static var ultima: Dictionary = {}
## testes/capturas: pula a animação do dirigível
static var animacao_rapida := false
static var _viajante: Node

static func areas_do_mapa() -> Array:
	return Registro.areas().filter(func(a): return a.has("mapa") and not bool(a.mapa.get("oculta", false)))

static func marcar_visitada(id: String) -> void:
	if id != "":
		visitadas[id] = true

static func regra(id: String):
	return Registro.area(id).get("mapa", {}).get("desbloqueio", "inicial")

static func desbloqueada(id: String) -> bool:
	if desbloquear_tudo or visitadas.has(id):
		return true
	var r = regra(id)
	if provedor_desbloqueio.is_valid():
		var v: int = int(provedor_desbloqueio.call(id, r))
		if v >= 0:
			return v == 1
	if r is String:
		return String(r) == "inicial"
	if r is Dictionary:
		if r.has("visitar"):
			return visitadas.has(String(r.visitar))
		if r.has("profundidade"):
			var p: Dictionary = r.profundidade
			return Sessao.profundidade_de(String(p.tema)) >= int(p.andar)
	return false

## texto curto do requisito para o painel
static func requisito(id: String) -> String:
	var r = regra(id)
	if r is Dictionary:
		if r.has("visitar"):
			return "Visite %s primeiro" % Registro.nome(String(r.visitar))
		if r.has("profundidade"):
			return "Chegue ao andar %d de %s" % [int(r.profundidade.andar), Registro.nome(String(r.profundidade.tema))]
	return "Ainda não descoberta"

## área da cena atual (pelo arquivo da cena ou pelo gerenciador da ilha)
static func area_atual(tree: SceneTree) -> String:
	var c := tree.current_scene
	if c == null:
		return ""
	if c.has_method("area_registro"):
		return String(c.area_registro())
	for a in Registro.areas():
		if String(a.cena) == c.scene_file_path:
			return String(a.id)
	return ""

static func ponto_padrao(id: String) -> String:
	var a := Registro.area(id)
	var p := String(a.get("chegada_mapa", ""))
	if p == "" and a.get("pontos_de_entrada", []).size() > 0:
		p = String(a.pontos_de_entrada[0].id)
	return p

## Viaja para a área. Masmorras: abre a sessão (origem = cidade da entrada), começa no andar do ponto.
static func ir(tree: SceneTree, id: String, ponto_id := "") -> int:
	if not Registro.existe(id):
		push_error("viagem: área desconhecida %s" % id)
		return ERR_DOES_NOT_EXIST
	if ponto_id == "":
		ponto_id = ponto_padrao(id)
	var de := area_atual(tree)
	if ao_viajar.is_valid():
		ao_viajar.call(de, id, ponto_id)
	var a := Registro.area(id)
	if String(Registro.area(de).get("tipo", "")) == "masmorra" and de != id:
		Sessao.encerrar()   # saiu da masmorra pelo mapa: o que já foi coletado fica no inventário da sessão
	if String(a.get("tipo", "")) == "masmorra":
		var tema := String(a.get("tema", id))
		var ori := Registro.origem_de(id, ponto_id)
		if ori.is_empty():
			ori = Registro.origem_de(id)
		var andar := int(Registro.ponto(id, ponto_id).get("andar", 1))
		Sessao.iniciar(tema, String(ori.get("area", "")), String(ori.get("ponto", "")), andar)
	ultima = {"de": de, "para": id, "ponto": ponto_id, "msec": Time.get_ticks_msec()}
	garantir_viajante(tree)
	tree.paused = false
	return Registro.viajar(tree, id, ponto_id)

## Nó persistente na raiz (sobrevive à troca de cena): tecla M, overlay do mapa, chegada genérica.
static func garantir_viajante(tree: SceneTree) -> Node:
	if is_instance_valid(_viajante):
		return _viajante
	var n := tree.root.get_node_or_null("Viajante")
	if n == null:
		n = Node.new()
		n.name = "Viajante"
		n.set_script(load(VIAJANTE))
		tree.root.call_deferred("add_child", n)
	_viajante = n
	return n
