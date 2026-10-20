extends Node
## Gerente de conversas de um mapa. Um por cena.
## - escolhe o morador mais proximo dentro da Area3D e mostra "E - Conversar";
## - E inicia a conversa na caixa de dialogo (scenes/ui/caixa_dialogo.tscn);
## - enquanto conversa, trava a jogadora (game.demo_mode como em interiores.gd, ou a flag 'conversando').
##
## Mapas que ja usam E (portas em scripts/modular/interiores.gd) devem desligar tratar_tecla_e e
## encadear, igual as portas:   if k == KEY_E and dialogos and dialogos.tecla_e(): return
##
## Helper de spawn: InteracaoNpcs.spawn_em_marcadores(raiz) cria um morador em cada Marker3D cujo
## nome seja um id do registro ("mira", "NPC_mira" ou "npc_mira").

signal conversa_iniciada(npc_id: String)
signal conversa_encerrada(npc_id: String)

const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const NpcConversavel = preload("res://scripts/dialogos/npc_conversavel.gd")
const CenaCaixa = preload("res://scenes/ui/caixa_dialogo.tscn")

## Trata a tecla E sozinho (_unhandled_key_input). Desligue se o mapa ja encadeia tecla_e().
@export var tratar_tecla_e := true
## No do jogo que tenha 'demo_mode'/'demo_input' (fidelity_village e filhos) para travar a jogadora.
var game: Node = null
## No da jogadora (Node3D). Usado para virar o morador e como reserva de distancia.
var jogador: Node3D = null

var caixa: CanvasLayer
var conversando := false
var atual = null
var _perto: Array = []
var _modo_demo_antes := false

func _ready() -> void:
	caixa = CenaCaixa.instantiate()
	add_child(caixa)
	caixa.encerrado.connect(_ao_encerrar)
	get_tree().node_added.connect(_no_adicionado)
	for n in get_tree().get_nodes_in_group("npc_conversavel"):
		registrar(n)

func _no_adicionado(n: Node) -> void:
	if n.get_script() == NpcConversavel:
		registrar.call_deferred(n)

func registrar(npc) -> void:
	if not is_instance_valid(npc) or npc.jogador_entrou.is_connected(_entrou):
		return
	npc.jogador_entrou.connect(_entrou)
	npc.jogador_saiu.connect(_saiu)
	if npc.jogador_perto:
		_entrou(npc)

func _entrou(npc) -> void:
	if not npc in _perto:
		_perto.append(npc)

func _saiu(npc) -> void:
	_perto.erase(npc)

func mais_proximo():
	var melhor = null
	var d := INF
	var ref := jogador.global_position if is_instance_valid(jogador) else Vector3.ZERO
	for n in _perto:
		if not is_instance_valid(n):
			continue
		var dd: float = n.global_position.distance_to(ref) if is_instance_valid(jogador) else 0.0
		if dd < d:
			d = dd
			melhor = n
	return melhor

func _process(_delta: float) -> void:
	_perto = _perto.filter(func(n): return is_instance_valid(n))
	var alvo = null if conversando else mais_proximo()
	for n in get_tree().get_nodes_in_group("npc_conversavel"):
		n.mostrar_aviso(n == alvo)

## Mesmo contrato de interiores.tecla_e(): true se a tecla E foi consumida.
func tecla_e() -> bool:
	if conversando:
		return true
	var npc = mais_proximo()
	if npc == null:
		return false
	conversar(npc)
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if not tratar_tecla_e:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if tecla_e():
			get_viewport().set_input_as_handled()

func conversar(npc, cue := "") -> bool:
	var recurso: Resource = npc.carregar_dialogo()
	if recurso == null:
		push_warning("Dialogo nao encontrado para '%s': %s" % [npc.npc_id, npc.caminho_dialogo()])
		return false
	conversando = true
	atual = npc
	npc.conversando = true
	if is_instance_valid(jogador):
		npc.olhar_para(jogador.global_position)
	_travar(true)
	conversa_iniciada.emit(String(npc.npc_id))
	caixa.iniciar(recurso, String(npc.npc_id), cue if cue != "" else String(npc.cue_inicial))
	return true

## Inicia pelo id (sem precisar estar perto). Util para cutscenes e testes.
func conversar_com(id: String, cue := "") -> bool:
	for n in get_tree().get_nodes_in_group("npc_conversavel"):
		if String(n.npc_id) == id:
			return conversar(n, cue)
	return false

func _ao_encerrar(id: String) -> void:
	if atual and is_instance_valid(atual):
		atual.conversando = false
	atual = null
	_travar(false)
	# solta no proximo quadro para o mesmo E nao reabrir a conversa
	await get_tree().process_frame
	conversando = false
	conversa_encerrada.emit(id)

func _travar(sim: bool) -> void:
	if game == null or not ("demo_mode" in game):
		return
	if sim:
		_modo_demo_antes = game.demo_mode
		game.demo_mode = true
		if "demo_input" in game:
			game.demo_input = Vector2.ZERO
		if "player" in game and game.player is CharacterBody3D:
			game.player.velocity = Vector3.ZERO
	else:
		game.demo_mode = _modo_demo_antes

# ------------------------------------------------------------------ spawn
static func id_do_marcador(nome_no: String) -> String:
	var n := nome_no.to_lower()
	for prefixo in ["npc_", "npc-", "npc"]:
		if n.begins_with(prefixo) and Registro.existe(n.substr(prefixo.length())):
			return n.substr(prefixo.length())
	return n if Registro.existe(n) else ""

## Cria um morador em cada Marker3D cujo nome seja um id do registro. Retorna os moradores criados.
## pai: onde pendurar (padrao: o pai do marcador, herdando a posicao global do marcador).
static func spawn_em_marcadores(raiz: Node, pai: Node3D = null) -> Array:
	var criados: Array = []
	for m in raiz.find_children("*", "Marker3D", true, false):
		var id := id_do_marcador(String(m.name))
		if id == "":
			continue
		var destino: Node3D = pai if pai else m.get_parent()
		var npc := criar_npc(id, destino, (m as Marker3D).global_transform)
		criados.append(npc)
	return criados

static func criar_npc(id: String, pai: Node3D, onde: Transform3D = Transform3D.IDENTITY) -> Node3D:
	var npc: Node3D = NpcConversavel.new()
	npc.npc_id = id
	npc.name = "NPC_" + id
	pai.add_child(npc)
	npc.global_transform = onde
	return npc
