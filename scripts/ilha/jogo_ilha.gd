extends Node
## Gerenciador das 3 areas: Fazenda <-> Vila <-> Arena. Fade + spawns.
## Debug: F7 masmorra | F10 vila | F11 arena | F12 fazenda | M mapa | I equipamento. Save: user://ilha_fazenda_v1.json.
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
## equipamento (I): tela + paper-doll da Vale nas 4 areas (docs/EQUIPAMENTO.md)
const Equip = preload("res://scripts/ilha/equipamento.gd")
const EquipVisual = preload("res://scripts/ilha/equipamento_visual.gd")
const EquipTela = preload("res://scripts/ilha/equipamento_tela.gd")
var equip_tela
const FAZENDA := "res://scripts/ilha/fazenda.tscn"
const VILA := "res://scripts/ilha/vila_jogo.tscn"
const ARENA := "res://combat_arena.tscn"
const MASMORRA := "res://dungeon_teste.tscn"
## mapa: arte do usuario (se existir) ou esquematico gerado (tools/mapa_esquematico.py)
const MAPA_ARTE := "res://art/ui/mapa_mundi_arte.png"
const MAPA_ESQ := "res://art/ui/mapa_esquematico.png"
## posicao de cada area no mapa esquematico (1200x800)
const MAPA_POS := {"fazenda": Vector2(360, 610), "vila": Vector2(620, 440), "arena": Vector2(905, 430), "masmorra": Vector2(585, 98)}
const MapaMundi = preload("res://scripts/ilha/mapa_mundi.gd")  # posicao real do jogador no mapa (art/ui/mapa_mundi.json)
var mapa_camada: CanvasLayer
var mapa_img: TextureRect
var mapa_marca: Label
var mapa_t := 0.0
const FADE := 0.35
var estado
var atual: Node
var nome := ""
var ocupado := false
var fade: ColorRect

func _ready() -> void:
	estado = Estado.new()
	estado.carregar()
	var camada := CanvasLayer.new()
	camada.layer = 80
	add_child(camada)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.015, 0.03, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fade)
	_montar_mapa()
	equip_tela = EquipTela.new()
	add_child(equip_tela)
	equip_tela.montar(self)
	DisplayServer.window_set_title("Ilha das Cinzas | Fazenda, Vila e Combate")
	var area: String = OS.get_environment("ILHA_AREA")
	var spawn: String = OS.get_environment("ILHA_SPAWN")
	await _trocar(area if area != "" else "fazenda", spawn if spawn != "" else "inicio", false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or ocupado:
		return
	if event.physical_keycode == KEY_I and equip_tela and not (mapa_camada and mapa_camada.visible):
		equip_tela.abrir()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_M:
		alternar_mapa()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_ESCAPE and mapa_camada and mapa_camada.visible:
		alternar_mapa()
		get_viewport().set_input_as_handled()
		return
	match event.physical_keycode:
		KEY_F7:
			ir("masmorra", "inicio")
		KEY_F10:
			ir("vila", "da_fazenda" if nome == "fazenda" else "da_arena")
		KEY_F11:
			ir("arena", "da_vila")
		KEY_F12:
			ir("fazenda", "da_vila" if nome == "vila" else "inicio")

func ir(area: String, spawn: String) -> void:
	if ocupado or area == nome:
		return
	ocupado = true  # sincroniza antes do 1o await do _trocar
	_trocar(area, spawn, true)

func _trocar(area: String, spawn: String, com_fade: bool) -> void:
	ocupado = true
	estado.area = area
	estado.salvar()
	if com_fade:
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, FADE)
		await tw.finished
	if atual:
		atual.queue_free()
		atual = null
		await get_tree().process_frame
		await get_tree().process_frame
	Engine.time_scale = 1.0
	nome = area
	match area:
		"fazenda":
			atual = load(FAZENDA).instantiate()
			atual.estado = estado
			atual.gerenciador = self
			add_child(atual)
			await get_tree().process_frame
			if atual.has_method("nascer"):
				atual.nascer(spawn)
		"vila":
			atual = load(VILA).instantiate()
			atual.estado = estado
			atual.gerenciador = self
			add_child(atual)
			await get_tree().process_frame
			if atual.has_method("nascer"):
				atual.nascer(spawn)
		"arena":
			atual = load(ARENA).instantiate()
			add_child(atual)
			await get_tree().process_frame
			var s := Node.new()
			s.name = "SaidaIlha"
			s.set_script(load("res://scripts/ilha/arena_saida.gd"))
			atual.add_child(s)
			s.montar(self, atual)
		"masmorra":
			atual = load(MASMORRA).instantiate()
			atual.gerenciador = self
			atual.estado = estado
			add_child(atual)
		_:
			push_error("Area desconhecida: " + area)
	vestir_atual()
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, FADE * (1.5 if not com_fade else 1.0))
	await tw2.finished
	ocupado = false

# ---------------------------------------------------------------- equipamento (I)
## aplica o que esta vestido na Vale da area atual (vila/fazenda/masmorra: sprite; arena: jogador)
func vestir_atual() -> void:
	if atual == null or estado == null:
		return
	var cam: Array = Equip.camadas(estado.equipamento)
	if nome == "arena":
		var j = atual.get("jogador")
		if j:
			EquipVisual.vestir_combate(j, cam)
			if "defesa_equip" in j:
				j.defesa_equip = Equip.defesa(estado.equipamento)
	else:
		var s = atual.get("sprite")
		if s is AnimatedSprite3D:
			EquipVisual.vestir_sprite(s, cam)

# ---------------------------------------------------------------- mapa (M)
func _montar_mapa() -> void:
	mapa_camada = CanvasLayer.new()
	mapa_camada.layer = 75
	mapa_camada.visible = false
	add_child(mapa_camada)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.6)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa_camada.add_child(fundo)
	mapa_img = TextureRect.new()
	mapa_img.position = Vector2(200, 50)
	mapa_img.size = Vector2(1200, 800)
	mapa_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mapa_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mapa_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa_camada.add_child(mapa_img)
	mapa_marca = Label.new()
	mapa_marca.text = "◆ Você está aqui"
	mapa_marca.add_theme_font_size_override("font_size", 20)
	mapa_marca.add_theme_color_override("font_color", Color("ff4f4f"))
	mapa_marca.add_theme_color_override("font_outline_color", Color.WHITE)
	mapa_marca.add_theme_constant_override("outline_size", 6)
	mapa_camada.add_child(mapa_marca)
	var dica := Label.new()
	dica.text = "M / Esc: fechar mapa"
	dica.position = Vector2(210, 855)
	dica.add_theme_font_size_override("font_size", 14)
	mapa_camada.add_child(dica)

func _textura_mapa() -> Texture2D:
	for cam in [MAPA_ARTE, MAPA_ESQ]:
		var g := ProjectSettings.globalize_path(cam)
		if FileAccess.file_exists(g):
			var img := Image.load_from_file(g)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null

func alternar_mapa() -> void:
	if mapa_camada == null:
		return
	if not mapa_camada.visible and mapa_img.texture == null:
		mapa_img.texture = _textura_mapa()
	mapa_camada.visible = not mapa_camada.visible
	_marcar_mapa()
	mapa_marca.visible = mapa_img.texture != null and not FileAccess.file_exists(ProjectSettings.globalize_path(MAPA_ARTE))

func _process(delta: float) -> void:
	if mapa_camada and mapa_camada.visible:
		mapa_t += delta
		mapa_marca.modulate.a = 0.55 + 0.45 * sin(mapa_t * 5.0)
		_marcar_mapa()

func _marcar_mapa() -> void:
	var p: Vector2 = MapaMundi.ponto(nome, atual, MAPA_POS.get(nome, Vector2(600, 400)))
	mapa_marca.text = "◆ Você está aqui — " + MapaMundi.nome(nome)
	mapa_marca.position = mapa_img.position + p - Vector2(10, 14)
