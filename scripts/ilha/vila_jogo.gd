extends "res://scripts/fidelity_village.gd"
## Vila conectada ao restante do jogo: saidas para Fazenda (sul) e Arena (leste),
## placas, fade via gerenciador. Overlay de referencia desligado.
const Placa = preload("res://scripts/ilha/placa.gd")
const Npcs = preload("res://scripts/ilha/vila_npcs.gd")
const Horizonte = preload("res://scripts/ilha/horizonte_vivo.gd")
const Caminhos = preload("res://scripts/ilha/caminhos_ilha.gd")  # portoes largos + trilhas
var horizonte
const Oclusao = preload("res://scripts/ilha/oclusao_casas.gd")
var oclusao
var npcs
var estado
var gerenciador
var jogo := true
var saidas: Array = []
var saidas_novas  # saidas_area.gd (portoes largos); quando existe, o laco antigo de raio fica desligado
## spawns: da_fazenda (leste do caminho sul), da_arena (oeste da saida leste), padrao
const SPAWNS := {
	"padrao": Vector2(-4.67, -5.0),
	"da_fazenda": Vector2(0.0, 16.0),
	"da_arena": Vector2(18.0, -4.0),
	"da_masmorra": Vector2(-6.0, -17.4),
}
const SAIDAS := [
	{"pos": Vector2(0.0, 20.0), "raio": 2.0, "area": "fazenda", "spawn": "da_vila", "placa": Vector2(2.6, 18.2), "texto": "Fazenda  >"},
	{"pos": Vector2(22.0, -4.0), "raio": 2.0, "area": "arena", "spawn": "da_vila", "placa": Vector2(20.0, -7.4), "texto": "Arena  >"},
	{"pos": Vector2(-6.0, -20.0), "raio": 0.9, "area": "masmorra", "spawn": "inicio", "placa": Vector2(-4.6, -18.6), "texto": "Masmorra ^"},
]

func _ready() -> void:
	super._ready()
	overlay.visible = false
	overlay_label.visible = false
	if efeitos_label:
		efeitos_label.visible = false
	_montar_saidas()
	saidas_novas = Caminhos.vila(self)
	if estado == null:
		estado = load("res://scripts/ilha/fazenda_estado.gd").new()
		estado.carregar()
	npcs = Npcs.new()
	add_child(npcs)
	npcs.montar(self)
	# horizonte vivo: ceu por clima do dia + ilhas que derivam + aurora 3D (K / Shift+K / U; HORIZONTE=0 desliga)
	horizonte = Horizonte.new()
	add_child(horizonte)
	horizonte.montar(self)
	# telhados das casas desbotam quando a Vale esta sob/atras delas (OCLUSAO=0 desliga)
	oclusao = Oclusao.new()
	add_child(oclusao)
	oclusao.montar(self)
	message.text = "Vila | E: conversar/casas | loja do Sr. Armando | norte: ruinas | sul: fazenda | leste: arena | M: mapa"
	if OS.get_environment("ILHA_SPAWN") != "" and has_method("nascer"):
		pass

func _montar_saidas() -> void:
	for s in SAIDAS:
		var pl: Vector2 = s.placa
		Placa.criar(art_world, ground, Vector3(pl.x, vila.altura(pl.x, pl.y), pl.y), String(s.texto))
		var pos: Vector2 = s.pos
		saidas.append({"pos": Vector3(pos.x, vila.altura(pos.x, pos.y) + 0.4, pos.y), "raio": float(s.raio), "area": String(s.area), "spawn": String(s.spawn)})
	# caminho sul e leste (marca visual no chao)
	for z in range(14, 22):
		for x in [-1, 0, 1]:
			if vila.tipo(x, z) == "g" and vila.altura(float(x), float(z)) > -0.3:
				pass
	for x in range(16, 24):
		pass

func nascer(spawn: String) -> void:
	var sp: Vector2 = SPAWNS.get(spawn, SPAWNS.padrao)
	player.position = Vector3(sp.x, vila.altura(sp.x, sp.y) + 0.4, sp.y)
	cam_seguir = Vector3(player.position.x, player.position.y - altura0, player.position.z) + cam_desloc
	apply_camera()

func _process(delta: float) -> void:
	super._process(delta)
	if npcs:
		npcs.cada_quadro(delta)
	if gerenciador == null or gerenciador.ocupado or saidas_novas:
		return
	for s in saidas:
		var p: Vector3 = s.pos
		if Vector2(player.position.x - p.x, player.position.z - p.z).length() < float(s.raio):
			gerenciador.ir(String(s.area), String(s.spawn))
			return

func _unhandled_key_input(event: InputEvent) -> void:
	# no modo jogo, 1-9 nao mexem nos efeitos (ficam na fazenda)
	if npcs and npcs.entrada(event):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			return
		if event.physical_keycode == KEY_O or event.physical_keycode == KEY_P:
			return
	super._unhandled_key_input(event)
