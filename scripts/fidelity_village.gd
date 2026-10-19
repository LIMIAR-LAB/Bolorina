extends "res://scripts/reference_village.gd"
## Cena de FIDELIDADE (fase 1): o vilarejo V6 herdado sem alterar a cena original,
## com camera travada no enquadramento da imagem-alvo do usuario
## (docs/referencia-usuario.png) e sobreposicao semitransparente da referencia.
## O: liga/desliga a sobreposicao | - / =: opacidade | P: piscar referencia x jogo
## Tab: camera SEGUINDO a Vale (padrao; roda do mouse = zoom) <-> TRAVADA no enquadramento
## da referencia (usada pelas capturas/pontuacao: tests/fidelity_capture.gd, FID_CAMERA=travada).
## Camera: docs/fidelidade-camera.json (escala e deslocamento calculados por
## tools/fidelidade_ajuste.py a partir de pontos de referencia).
const CONFIG := "res://docs/fidelidade-camera.json"
const CERCAS := "res://scripts/modular/vila_cercas.json"
const LAYOUT := "res://scripts/modular/vila_layout.json"
const VilaModular = preload("res://scripts/modular/vila_modular.gd")
const Efeitos = preload("res://scripts/modular/efeitos_fidelidade.gd")
const ValeFidelidade = preload("res://scripts/modular/vale_fidelidade.gd")
const Interiores = preload("res://scripts/modular/interiores.gd")
const Barreiras = preload("res://scripts/modular/abismo_barreiras.gd")
const VALE_MANIFEST := "res://art/characters/original_vale_v6/manifest.json"
const ZONA_MORTA := 1.25
## modo "v7": vila modular nova (fases 2-5, scripts/modular/); modo "v6": vila V6 herdada (fase 1).
var vila
var efeitos
var efeitos_label: Label
## interiores das casas (E na porta): scripts/modular/interiores.gd
var interiores
const REFERENCE := "res://docs/referencia-usuario.png"
var fidelity_camera: Camera3D
var base_transform: Transform3D
var base_size := 0.0
var config := {"hora": 18.6, "escala": 1.0, "desloc_px": [0.0, 0.0], "modo": "v6", "fase": 5}
var overlay_layer: CanvasLayer
var overlay: TextureRect
var overlay_label: Label
var overlay_opacity := 0.5
var blink := false
var blink_time := 0.0
## false = camera segue a Vale (padrao); true = enquadramento fixo da referencia.
var camera_travada := false
var cam_seguir := Vector3.ZERO
var cam_desloc := Vector3.ZERO
var altura0 := 0.0
## protecao contra quedas (abismo_barreiras.gd) + reaparecer no ultimo ponto seguro
var barreiras
var ultimo_seguro := Vector3.INF
var t_queda := 0.0
var quedas := 0

func _actor(character: String) -> AnimatedSprite3D:
	# Protagonista: Vale V6 coerente (mesmo corpo em todas as animacoes, altura constante).
	if character == "original_apprentice" and FileAccess.file_exists(VALE_MANIFEST):
		var vale = ValeFidelidade.new()
		vale.preparar(1.48)
		return vale
	return super._actor(character)

func _load() -> void:
	super._load()
	if FileAccess.file_exists(CONFIG):
		var data = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if data is Dictionary:
			config.merge(data, true)
	# ajustes temporarios sem editar o JSON (usado para calibrar o crepusculo): FID_CONFIG_EXTRA='{"crep_sol":2.0}'
	var extra = JSON.parse_string(OS.get_environment("FID_CONFIG_EXTRA")) if OS.get_environment("FID_CONFIG_EXTRA") != "" else null
	if extra is Dictionary:
		config.merge(extra, true)

func modular() -> bool:
	return String(config.modo) == "v7"

func _build_world() -> void:
	if not modular():
		super._build_world()
		return
	# Vila V7: nada da V6 e construido; materiais compartilhados vem do VisualWorld.
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
	vila = VilaModular.new()
	vila.densidade_extra = bool(config.get("densidade_extra", true))
	# cercas modulares novas (19/10); "cercas_v1": true volta as pecas antigas
	if not bool(config.get("cercas_v1", false)) and FileAccess.file_exists(cercas_arquivo()):
		vila.cercas_dados = JSON.parse_string(FileAccess.get_file_as_string(cercas_arquivo()))
	vila.build(art_world, ground, layout_arquivo(), int(config.fase))
	farm = FarmPlots.new()
	ground.add_child(farm)
	farm.setup(art_world)
	cut_tree = ChoppableTree.new()
	ground.add_child(cut_tree)
	var tree_spot: Vector3 = vila.tela_para_mundo(470, 330, 0.0)
	cut_tree.setup(art_world, Vector3(roundf(tree_spot.x), 0, roundf(tree_spot.z)), false, 0)
	cut_tree.canopy_material.shader = load("res://shaders/reference_leaves.gdshader")
	npc = _actor("original_gardener")
	ground.add_child(npc)
	enemy = _actor("original_gardener")
	ground.add_child(enemy)
	enemy.visible = false
	ally = npc
	follow_trail.clear()
	border_vegetation = Node3D.new()
	ground.add_child(border_vegetation)

func layout_arquivo() -> String:
	return LAYOUT

func cercas_arquivo() -> String:
	return CERCAS

## grade andavel V7 (island.gd usa 'cells'; a grade V6 nao corresponde ao terreno modular)
func _definir_andaveis() -> void:
	var d: Dictionary = vila.andaveis()
	if not bool(config.get("abismo_v1", false)):
		barreiras = Barreiras.new()
		d = barreiras.filtrar(vila, d)
		barreiras.construir(vila, ground, d, OS.get_environment("ABISMO_VER") == "1")
		barreiras.decorar(vila, ground, d)
	cells.clear()
	for c in d:
		cells.append(c)

func andavel(p: Vector3) -> bool:
	return cells.has(Vector2i(roundi(p.x), roundi(p.z)))

func _physics_process(delta: float) -> void:
	var p0: Vector3 = player.position
	super._physics_process(delta)
	if modular() and not arena and not bool(config.get("andaveis_v6", false)):
		# island.gd reverte o passo pela regra fixa do rio V6 (|z-7,5|<1,65 e |x|>1,05), que nao vale no
		# terreno V7: refaz o passo quando a celula V7 de destino e andavel.
		var v := Vector3(player.velocity.x, 0, player.velocity.z)
		if v.length() > 0.05 and player.position.distance_to(p0) < 0.0001 and andavel(p0 + v*delta):
			player.move_and_slide()
			if not andavel(player.position):
				player.position = p0
	if modular() and not arena and not bool(config.get("abismo_v1", false)):
		_vigiar_queda(delta)

## reaparece no ultimo ponto seguro se cair (> 2 m abaixo dele por 0,8 s) em vez de cair para sempre
func _vigiar_queda(delta: float) -> void:
	if interiores and (interiores.ativo >= 0 or interiores.ocupado):
		t_queda = 0.0
		return
	if player.is_on_floor() and andavel(player.position) and absf(player.position.y - vila.altura(player.position.x, player.position.z)) < 0.6:
		ultimo_seguro = player.position
		t_queda = 0.0
		return
	if ultimo_seguro == Vector3.INF:
		return
	if player.position.y < ultimo_seguro.y - 2.0:
		t_queda += delta
		if t_queda > 0.8:
			quedas += 1
			player.position = ultimo_seguro + Vector3(0, 0.3, 0)
			player.velocity = Vector3.ZERO
			t_queda = 0.0
			message.text = "Ufa! A Vale voltou para terra firme."
	else:
		t_queda = 0.0

func _actor_pos(key: String) -> Vector3:
	var a: Array = vila.data.atores[key]
	return Vector3(float(a[0]), vila.altura(float(a[0]), float(a[1])), float(a[1]))

func _ready() -> void:
	super._ready()
	if modular() and not bool(config.get("andaveis_v6", false)):
		_definir_andaveis()
	atmosphere.transition_active = false
	atmosphere.set_hour(float(config.hora))
	# Enquadramento base: o mesmo da cena V6 na posicao inicial do protagonista.
	if modular():
		player.position = _actor_pos("jogador") + Vector3(0,0.4,0)
		npc.position = _actor_pos("mira")
		village_cat.position = _actor_pos("gato")
		village_resident.position = _actor_pos("morador")
		camera_anchor.position = player.position + Vector3(-2.2,0,-2.2)
		# Seguir comeca exatamente no enquadramento da referencia e mantem o mesmo deslocamento.
		altura0 = vila.altura(player.position.x, player.position.z)
		cam_desloc = Vector3(vila.cam_alvo.x-player.position.x, 0, vila.cam_alvo.z-player.position.z)
		cam_seguir = vila.cam_alvo
	if OS.get_environment("FID_CAMERA") == "travada":
		camera_travada = true
	zoom_current = zoom_target
	base_size = 21.5*0.94
	var anchor_point: Vector3 = player.position + Vector3(-2.2,0,-2.2)
	base_transform = Transform3D(Basis.IDENTITY, anchor_point+CAMERA_OFFSET).looking_at(anchor_point, Vector3.UP)
	fidelity_camera = Camera3D.new()
	fidelity_camera.name = "CameraFidelidade"
	fidelity_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	fidelity_camera.near = camera.near
	fidelity_camera.far = camera.far
	fidelity_camera.attributes = camera.attributes
	fidelity_camera.cull_mask = camera.cull_mask
	add_child(fidelity_camera)
	apply_camera()
	fidelity_camera.make_current()
	_setup_overlay()
	if modular():
		efeitos = Efeitos.new()
		add_child(efeitos)
		efeitos.setup(self, vila, int(config.fase))
		efeitos_label = Label.new()
		efeitos_label.position = Vector2(24,834)
		efeitos_label.add_theme_font_size_override("font_size",13)
		efeitos_label.add_theme_color_override("font_shadow_color",Color.BLACK)
		efeitos_label.add_theme_constant_override("shadow_offset_x",1)
		efeitos_label.add_theme_constant_override("shadow_offset_y",1)
		overlay_layer.add_child(efeitos_label)
		efeitos_label.text = "EFEITOS: " + efeitos.texto()
		interiores = Interiores.new()
		add_child(interiores)
		interiores.setup(self)
	message.text = "FIDELIDADE: Tab camera seguir/travada | E na porta: entrar na casa | roda zoom | O sobreposicao | -/= opacidade | P piscar"

func _reference_title() -> void:
	DisplayServer.window_set_title("Ilha das Cinzas | Fidelidade x referencia do usuario")

func apply_camera() -> void:
	if modular():
		var b: Vector3 = vila.basis_cam()[2]
		if interiores and interiores.ativo >= 0:
			var c: Vector3 = interiores.centro()
			fidelity_camera.size = interiores.TAM_CAMERA*zoom_current/0.94
			fidelity_camera.global_transform = Transform3D(Basis.IDENTITY, c + b*90.0).looking_at(c, Vector3.UP)
			fidelity_camera.far = 400
			return
		var alvo: Vector3 = vila.cam_alvo if camera_travada else cam_seguir
		fidelity_camera.size = vila.cam_size if camera_travada else vila.cam_size*zoom_current/0.94
		fidelity_camera.global_transform = Transform3D(Basis.IDENTITY, alvo + b*90.0).looking_at(alvo, Vector3.UP)
		fidelity_camera.far = 400
		return
	var scale: float = float(config.escala)
	var shift: Array = config.desloc_px
	var k := base_size/900.0
	var b := base_transform.basis.orthonormalized()
	fidelity_camera.size = base_size/scale
	fidelity_camera.global_transform = Transform3D(b, base_transform.origin + b.x*float(shift[0])*k - b.y*float(shift[1])*k)

func _setup_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 40
	overlay_layer.name = "SobreposicaoReferencia"
	add_child(overlay_layer)
	overlay = TextureRect.new()
	var image := Image.load_from_file(ProjectSettings.globalize_path(REFERENCE))
	overlay.texture = ImageTexture.create_from_image(image)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	overlay_layer.add_child(overlay)
	overlay_label = Label.new()
	overlay_label.position = Vector2(24,860)
	overlay_label.add_theme_font_size_override("font_size",18)
	overlay_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	overlay_label.add_theme_constant_override("shadow_offset_x",1)
	overlay_label.add_theme_constant_override("shadow_offset_y",1)
	overlay_layer.add_child(overlay_label)
	_refresh_overlay()

func set_camera_travada(on: bool) -> void:
	camera_travada = on
	if not on and modular():
		# volta a seguir a partir do enquadramento atual, sem salto
		cam_seguir = fidelity_camera.global_position - vila.basis_cam()[2]*90.0
	apply_camera()
	_refresh_overlay()

func _seguir_camera(delta: float) -> void:
	var desejado := Vector3(player.position.x, player.position.y-altura0, player.position.z) + cam_desloc
	var d := Vector2(desejado.x-cam_seguir.x, desejado.z-cam_seguir.z)
	if d.length() > ZONA_MORTA:
		var t := d.normalized()*(d.length()-ZONA_MORTA)*(1.0-exp(-4.0*delta))
		cam_seguir.x += t.x
		cam_seguir.z += t.y
	cam_seguir.y = lerpf(cam_seguir.y, clampf(desejado.y,-3.0,6.0), 1.0-exp(-2.0*delta))
	apply_camera()

## chamado pelos interiores ao entrar/sair: camera volta a seguir sem panoramica longa
func interior_mudou() -> void:
	if interiores.ativo < 0:
		cam_seguir = Vector3(player.position.x, player.position.y-altura0, player.position.z) + cam_desloc
	apply_camera()

func set_overlay(on: bool) -> void:
	overlay.visible = on
	_refresh_overlay()

func set_opacity(value: float) -> void:
	overlay_opacity = clampf(value,0.0,1.0)
	_refresh_overlay()

func _refresh_overlay() -> void:
	overlay.modulate.a = overlay_opacity
	overlay_label.text = ("REFERENCIA %d%%" % roundi(overlay_opacity*100.0) if overlay.visible else "REFERENCIA OCULTA") + ("  (piscando)" if blink else "") + "  | O / - / = / P  | Tab camera: " + ("TRAVADA (referencia)" if camera_travada else "SEGUINDO (roda: zoom)")

func _process(delta: float) -> void:
	super._process(delta)
	if efeitos:
		efeitos.cada_quadro(delta)
	if interiores:
		interiores.cada_quadro(delta, atmosphere.settings)
	if fidelity_camera and modular() and interiores and interiores.ativo >= 0:
		apply_camera()
	elif fidelity_camera and modular() and not camera_travada:
		_seguir_camera(delta)
	if blink:
		blink_time += delta
		overlay.modulate.a = 1.0 if fmod(blink_time,1.0) < 0.5 else 0.0

func _input(event: InputEvent) -> void:
	# Tab em _input: a interface nao consome a tecla para trocar foco.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		set_camera_travada(not camera_travada)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and interiores and interiores.tecla_e():
			return
		match event.physical_keycode:
			KEY_O:
				set_overlay(not overlay.visible)
				return
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_opacity(overlay_opacity-0.1)
				return
			KEY_EQUAL, KEY_KP_ADD:
				set_opacity(overlay_opacity+0.1)
				return
			_ when efeitos and efeitos.tecla(event.physical_keycode):
				efeitos_label.text = "EFEITOS: " + efeitos.texto()
				return
			KEY_P:
				blink = not blink
				overlay.visible = overlay.visible or blink
				_refresh_overlay()
				return
	super._unhandled_key_input(event)