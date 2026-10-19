extends "res://scripts/fidelity_village.gd"
## Fazenda (inspirada na Standard Farm). Layout proprio; fundo_vila=false.

const LAYOUT_FAZENDA := "res://scripts/ilha/fazenda_layout.json"
const CERCAS_FAZENDA := "res://scripts/ilha/fazenda_cercas.json"
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const Placa = preload("res://scripts/ilha/placa.gd")
const FazendaUI = preload("res://scripts/ilha/fazenda_ui.gd")
const Detritos = preload("res://scripts/ilha/fazenda_detritos.gd")
const Solo = preload("res://scripts/ilha/fazenda_solo.gd")
const Galinheiro = preload("res://scripts/ilha/fazenda_galinheiro.gd")

## definido pelo gerenciador (jogo_ilha.gd) antes de entrar na arvore
var estado
var gerenciador
var jogo := true

var ui
var detritos
var solo
var galinheiro
var saidas: Array = []
var _fade: ColorRect

func layout_arquivo() -> String:
	return LAYOUT_FAZENDA

func cercas_arquivo() -> String:
	return CERCAS_FAZENDA

func _load() -> void:
	super._load()
	config["modo"] = "v7"
	config["fase"] = 5
	config["densidade_extra"] = false

func _build_world() -> void:
	vila = VilaModular.new()
	vila.fundo_vila = false
	cells = Layout.generate(world_seed)
	art_world = VisualWorld.new()
	art_world.parent = ground
	art_world.rng.seed = world_seed
	art_world._make_materials()
	art_world.materials.grey_roof_tiles.albedo_color = Color("3d4656")
	art_world.materials.brown_planks_03.albedo_color = Color("9a7650")
	art_world.materials.plastered_stone_wall.albedo_color = Color("d9bf93")
	art_world.materials.castle_brick_01.albedo_color = Color("8d8a80")
	art_world.materials.glow.emission = Color("ff9f32")
	if FileAccess.file_exists(cercas_arquivo()):
		vila.cercas_dados = JSON.parse_string(FileAccess.get_file_as_string(cercas_arquivo()))
	vila.build(art_world, ground, layout_arquivo(), int(config.fase))
	farm = FarmPlots.new()
	ground.add_child(farm)
	farm.setup(art_world)
	farm.visible = false
	cut_tree = ChoppableTree.new()
	ground.add_child(cut_tree)
	cut_tree.setup(art_world, Vector3(-200, 0, -200), false, 0)
	npc = _actor("original_gardener")
	ground.add_child(npc)
	npc.visible = false
	enemy = _actor("original_gardener")
	ground.add_child(enemy)
	enemy.visible = false
	ally = npc
	follow_trail.clear()
	border_vegetation = Node3D.new()
	ground.add_child(border_vegetation)

func _ready() -> void:
	super._ready()
	if estado == null:
		estado = Estado.new()
		estado.carregar()
	overlay.visible = false
	efeitos_label.visible = false
	overlay_label.visible = false
	_extras()
	ui = FazendaUI.new()
	add_child(ui)
	ui.montar(self)
	detritos = Detritos.new()
	add_child(detritos)
	detritos.montar(self)
	solo = Solo.new()
	add_child(solo)
	solo.montar(self)
	galinheiro = Galinheiro.new()
	add_child(galinheiro)
	galinheiro.montar(self)
	_saidas()
	message.text = "Fazenda | 1-9 ou roda: ferramenta | LMB/J: usar | E: casa/caixa | F9: dormir | F5: salvar"
	hud.text = ui.linha_hud()

func _extras() -> void:
	var f: Dictionary = vila.data.fazenda
	# caixa de envio (placeholder)
	var c: Array = f.caixa_envio
	var cx := Vector3(float(c[0]), vila.altura(float(c[0]), float(c[1])), float(c[1]))
	var caixa: Node3D = Node3D.new()
	caixa.name = "CaixaEnvio"
	caixa.position = cx
	caixa.set_meta("caixa", true)
	ground.add_child(caixa)
	art_world.box(Vector3(0, 0.35, 0), Vector3(1.3, 0.7, 1.0), "brown_planks_03", true, caixa)
	art_world.box(Vector3(0, 0.85, -0.15), Vector3(1.4, 0.35, 0.45), "grey_roof_tiles", false, caixa)
	var l: Label3D = Label3D.new()
	l.text = "ENVIO"
	l.font_size = 42
	l.pixel_size = 0.005
	l.position = Vector3(0, 1.25, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("f1e2bd")
	l.shaded = false
	caixa.add_child(l)
	# celeiro/galinheiro placeholder (dentro do cercado)
	var g: Array = f.galinheiro.celeiro
	var gp := Vector3(float(g[0]), vila.altura(float(g[0]), float(g[1])), float(g[1]))
	var celeiro: Node3D = Node3D.new()
	celeiro.name = "Celeiro"
	celeiro.position = gp
	ground.add_child(celeiro)
	art_world.box(Vector3(0, 1.1, 0), Vector3(3.6, 2.2, 2.6), "brown_planks_03", true, celeiro)
	art_world.box(Vector3(0, 2.45, 0), Vector3(4.0, 0.5, 3.0), "grey_roof_tiles", false, celeiro)
	art_world.box(Vector3(0, 0.5, 1.35), Vector3(1.1, 1.0, 0.1), "plastered_stone_wall", false, celeiro)
	var pl: Label3D = Label3D.new()
	pl.text = "GALINHEIRO"
	pl.font_size = 40
	pl.pixel_size = 0.0055
	pl.position = Vector3(0, 3.0, 0)
	pl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pl.modulate = Color("f1e2bd")
	pl.shaded = false
	celeiro.add_child(pl)

func _saidas() -> void:
	for s in vila.data.fazenda.saidas:
		var p: Array = s.pos
		var pos := Vector3(float(p[0]), vila.altura(float(p[0]), float(p[1])) + 0.4, float(p[1]))
		var pl: Array = s.placa
		Placa.criar(art_world, ground, Vector3(float(pl[0]), vila.altura(float(pl[0]), float(pl[1])), float(pl[1])), String(s.texto))
		saidas.append({"pos": pos, "raio": float(s.raio), "area": String(s.area), "spawn": String(s.spawn)})

func _process(delta: float) -> void:
	super._process(delta)
	if ui:
		ui.cada_quadro(delta)
	if solo:
		solo.cada_quadro()
	if galinheiro:
		galinheiro.cada_quadro(delta)
	if gerenciador and not gerenciador.ocupado and (interiores == null or interiores.ativo < 0):
		for s in saidas:
			var p: Vector3 = s.pos
			if Vector2(player.position.x - p.x, player.position.z - p.z).length() < float(s.raio):
				gerenciador.ir(String(s.area), String(s.spawn))
				return

func _unhandled_input(event: InputEvent) -> void:
	if ui and ui.entrada(event):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var k: int = event.physical_keycode
	# 1-9 / O / P / -/= ficam com a barra de ferramentas (nao efeitos de fidelidade)
	if k == KEY_TAB or k == KEY_O or k == KEY_P or k == KEY_MINUS or k == KEY_EQUAL or k == KEY_KP_SUBTRACT or k == KEY_KP_ADD:
		return
	if k >= KEY_1 and k <= KEY_9:
		return
	if k == KEY_E and interiores and interiores.tecla_e():
		return
	if k == KEY_E:
		_caixa()
		return
	if k == KEY_F9 or k == KEY_N:
		_dormir()
		return
	if k == KEY_F5:
		if estado.salvar():
			message.text = "Fazenda salva em arquivo novo (ilha_fazenda_v1.json)."
		return
	if k == KEY_J and ui:
		ui.usar()
		return
	if k == KEY_H:
		ui_layer.visible = not ui_layer.visible
		return

func _caixa() -> void:
	var f: Array = vila.data.fazenda.caixa_envio
	var p := Vector3(float(f[0]), 0, float(f[1]))
	if Vector2(player.position.x - p.x, player.position.z - p.z).length() > 2.2:
		message.text = "Caixa de envio: aproxime-se para vender a colheita."
		return
	var g: int = estado.vender_colheita()
	estado.salvar()
	message.text = ("Enviado! +%d ouro (total %d)." % [g, estado.ouro]) if g > 0 else "Nada para enviar. Colha nabo, couve ou abobora."
	hud.text = ui.linha_hud()

func _dormir() -> void:
	# F9 avanca o dia (debug e cama). Dentro da casa, perto da cama, mensagem especifica.
	var na_cama := false
	if interiores and interiores.ativo >= 0:
		for m in interiores.moveis(interiores.ativo):
			if String(m.get_meta("modulo", "")) == "cama" and Vector2(player.position.x - m.global_position.x, player.position.z - m.global_position.z).length() < 1.6:
				na_cama = true
	estado.novo_dia()
	estado.salvar()
	solo.aplicar()
	ui.atualizar()
	message.text = ("Voce dormiu. " if na_cama else "") + "Dia %d. A terra regada cresceu; tudo secou." % estado.dia
	hud.text = ui.linha_hud()

## chamado pelo gerenciador ao voltar para a fazenda
func nascer(spawn: String) -> void:
	var sp = vila.data.fazenda.spawns.get(spawn, vila.data.fazenda.spawns.inicio)
	var p := Vector3(float(sp[0]), vila.altura(float(sp[0]), float(sp[1])) + 0.4, float(sp[1]))
	player.position = p
	cam_seguir = Vector3(p.x, p.y - altura0, p.z) + cam_desloc
	apply_camera()
