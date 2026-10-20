extends CanvasLayer
## Caixa de dialogo pixel art da Ilha das Cinzas, sobre o Dialogue Manager (Nathan Hoad, MIT).
## Painel com nome + titulo do morador, retrato, texto com efeito maquina de escrever,
## escolhas e avanco com E / Espaco / Enter / clique. Esc ou clique durante a digitacao pula o texto.
## Uso:  var caixa = preload("res://scenes/ui/caixa_dialogo.tscn").instantiate()
##       add_child(caixa); caixa.iniciar(load("res://dialogos/mira.dialogue"), "mira")
##       await caixa.encerrado

signal encerrado(npc_id: String)
signal linha_mostrada(personagem: String, texto: String)

const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"

const COR_FUNDO := Color("1b1410")
const COR_BORDA := Color("c9a25a")
const COR_BORDA_ESCURA := Color("5a3d22")
const COR_TEXTO := Color("f1e2bd")
const COR_NOME := Color("ffd27a")
const COR_TITULO := Color("b8a07a")

@export var segundos_por_letra := 0.022
## Em testes, avanca sozinho (sem esperar tecla).
var automatico := false
var escolha_automatica: Callable

var recurso: Resource
var npc_id := ""
var linha = null
var estados: Array = []
var esperando := false
var ativo := false
var _bloqueio := 0.0

var painel: PanelContainer
var retrato: TextureRect
var moldura_retrato: PanelContainer
var nome: Label
var titulo: Label
var texto: DialogueLabel
var escolhas: Container ## DialogueResponsesMenu (script do addon) num VBoxContainer
var seta: Label
var _t := 0.0
var _fonte: Font

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	painel.hide()

func iniciar(dialogo: Resource, id: String = "", cue: String = "start", extras: Array = []) -> void:
	recurso = dialogo
	npc_id = id
	estados = [Estado.global()] + extras
	ativo = true
	_bloqueio = 0.18
	linha = await recurso.get_next_dialogue_line(cue, estados)
	_aplicar()

func proxima(next_id: String) -> void:
	linha = await recurso.get_next_dialogue_line(next_id, estados)
	_aplicar()

func _aplicar() -> void:
	if linha == null:
		_fechar()
		return
	esperando = false
	var quem := String(linha.character)
	var id_falante := _id_do_falante(quem)
	nome.text = quem if quem != "" else " "
	titulo.text = String(Registro.dados(id_falante).get("titulo", "")) if id_falante != "" else ("Recém-chegada a Porto Velho" if quem == "Vale" else "")
	retrato.texture = Registro.retrato_vale() if quem == "Vale" else Registro.retrato(id_falante if id_falante != "" else npc_id)
	moldura_retrato.visible = quem != ""
	escolhas.hide()
	escolhas.responses = linha.responses
	seta.hide()
	painel.show()
	texto.dialogue_line = linha
	linha_mostrada.emit(quem, String(linha.text))
	if String(linha.text) != "":
		if automatico:
			texto.type_out()
			texto.skip_typing()
		else:
			texto.type_out()
			await texto.finished_typing
	if linha == null:
		return
	if linha.responses.size() > 0:
		escolhas.show()
		if automatico:
			var i := 0
			if escolha_automatica.is_valid():
				i = int(escolha_automatica.call(linha.responses))
			call_deferred("proxima", linha.responses[i].next_id)
	else:
		esperando = true
		if automatico:
			call_deferred("proxima", linha.next_id)

func _id_do_falante(quem: String) -> String:
	var id := Registro.id_por_nome(quem)
	if id == "" and npc_id != "" and quem != "Vale":
		id = npc_id
	return id

func _fechar() -> void:
	ativo = false
	painel.hide()
	encerrado.emit(npc_id)

func _process(delta: float) -> void:
	_t += delta
	_bloqueio = maxf(0.0, _bloqueio - delta)
	if seta and linha != null and painel.visible:
		seta.visible = esperando and not texto.is_typing
		seta.offset_top = -82 + (3.0 if fmod(_t, 0.8) > 0.4 else 0.0)
		seta.offset_bottom = seta.offset_top + 30

func _avancar_tecla(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	return false

func _input(event: InputEvent) -> void:
	if not ativo or linha == null:
		return
	var clique: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var tecla := _avancar_tecla(event)
	var pular: bool = event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE
	if event is InputEventKey or clique:
		# enquanto a caixa esta aberta, nenhuma tecla vaza para o jogo
		get_viewport().set_input_as_handled()
	if _bloqueio > 0.0:
		return
	if texto.is_typing:
		if clique or tecla or pular:
			texto.skip_typing()
		return
	if linha.responses.size() > 0 and escolhas.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var k: int = event.physical_keycode
			if k >= KEY_1 and k <= KEY_9:
				_escolher_indice(k - KEY_1)
			elif k == KEY_UP or k == KEY_W:
				_mover_foco(-1)
			elif k == KEY_DOWN or k == KEY_S:
				_mover_foco(1)
			elif tecla:
				var foco := get_viewport().gui_get_focus_owner()
				var itens: Array = escolhas.get_menu_items()
				_escolher_indice(maxi(0, itens.find(foco)))
		elif clique:
			# o proprio botao recebe o clique; deixa a GUI tratar
			for item in escolhas.get_menu_items():
				if (item as Control).get_global_rect().has_point(event.position):
					_escolher_indice(escolhas.get_menu_items().find(item))
		return
	if esperando and (tecla or clique):
		esperando = false
		proxima(linha.next_id)

func _mover_foco(d: int) -> void:
	var itens: Array = escolhas.get_menu_items()
	if itens.is_empty():
		return
	var i: int = itens.find(get_viewport().gui_get_focus_owner())
	i = clampi(i + d, 0, itens.size() - 1)
	(itens[i] as Control).grab_focus()

func _escolher_indice(i: int) -> void:
	var itens: Array = escolhas.get_menu_items()
	if i < 0 or i >= itens.size():
		return
	var item: Control = itens[i]
	var resp = item.get_meta("response")
	if resp == null or not resp.is_allowed:
		return
	escolhas.hide()
	proxima(resp.next_id)

func _on_escolha(resp) -> void:
	escolhas.hide()
	proxima(resp.next_id)

# ------------------------------------------------------------------ visual
func _estilo(fundo: Color, borda: Color, largura := 4, margem := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.set_content_margin_all(margem)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 0
	s.shadow_offset = Vector2(6, 6)
	return s

func _montar() -> void:
	_fonte = Registro.fonte()
	var tema := Theme.new()
	tema.default_font = _fonte
	tema.default_font_size = 28
	var b_normal := _estilo(Color("2a1f17"), COR_BORDA_ESCURA, 3, 10)
	var b_foco := _estilo(Color("4a3220"), COR_BORDA, 3, 10)
	var b_off := _estilo(Color("1f1915"), Color("3a2c22"), 3, 10)
	tema.set_stylebox("normal", "Button", b_normal)
	tema.set_stylebox("hover", "Button", b_foco)
	tema.set_stylebox("focus", "Button", b_foco)
	tema.set_stylebox("pressed", "Button", b_foco)
	tema.set_stylebox("disabled", "Button", b_off)
	tema.set_color("font_color", "Button", COR_TEXTO)
	tema.set_color("font_hover_color", "Button", COR_NOME)
	tema.set_color("font_focus_color", "Button", COR_NOME)
	tema.set_color("font_disabled_color", "Button", Color("6d6050"))
	tema.set_font_size("font_size", "Button", 25)
	tema.set_constant("h_separation", "Button", 8)

	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = tema
	add_child(raiz)

	painel = PanelContainer.new()
	painel.name = "Painel"
	var estilo := _estilo(COR_FUNDO.lerp(Color.BLACK, 0.1), COR_BORDA, 5, 18)
	estilo.bg_color.a = 1.0
	estilo.shadow_size = 1
	painel.add_theme_stylebox_override("panel", estilo)
	painel.anchor_left = 0.0
	painel.anchor_right = 1.0
	painel.anchor_top = 1.0
	painel.anchor_bottom = 1.0
	painel.offset_left = 90
	painel.offset_right = -90
	painel.offset_top = -268
	painel.offset_bottom = -34
	painel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(painel)

	var linha_h := HBoxContainer.new()
	linha_h.add_theme_constant_override("separation", 22)
	painel.add_child(linha_h)

	moldura_retrato = PanelContainer.new()
	moldura_retrato.add_theme_stylebox_override("panel", _estilo(Color("3b2a1d"), COR_BORDA_ESCURA, 4, 6))
	moldura_retrato.custom_minimum_size = Vector2(176, 176)
	moldura_retrato.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	linha_h.add_child(moldura_retrato)
	retrato = TextureRect.new()
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.custom_minimum_size = Vector2(160, 160)
	moldura_retrato.add_child(retrato)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	linha_h.add_child(col)

	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 16)
	col.add_child(cab)
	nome = Label.new()
	nome.add_theme_font_size_override("font_size", 32)
	nome.add_theme_color_override("font_color", COR_NOME)
	nome.add_theme_color_override("font_outline_color", Color("2b1a0c"))
	nome.add_theme_constant_override("outline_size", 6)
	cab.add_child(nome)
	titulo = Label.new()
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", COR_TITULO)
	titulo.size_flags_vertical = Control.SIZE_SHRINK_END
	cab.add_child(titulo)

	var sep := ColorRect.new()
	sep.color = COR_BORDA_ESCURA
	sep.custom_minimum_size = Vector2(0, 3)
	col.add_child(sep)

	texto = DialogueLabel.new()
	texto.name = "Texto"
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(0, 96)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.seconds_per_step = segundos_por_letra
	texto.skip_action = &""
	texto.add_theme_font_override("normal_font", _fonte)
	texto.add_theme_font_size_override("normal_font_size", 28)
	texto.add_theme_color_override("default_color", COR_TEXTO)
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(texto)

	# DialogueResponsesMenu estende Container: num VBoxContainer as escolhas ficam uma por linha
	var vb := VBoxContainer.new()
	vb.set_script(load("res://addons/dialogue_manager/nodes/responses_menu/dialogue_responses_menu.gd"))
	escolhas = vb
	escolhas.name = "Escolhas"
	escolhas.add_theme_constant_override("separation", 6)
	escolhas.next_action = &"ui_accept"
	col.add_child(escolhas)
	escolhas.response_selected.connect(_on_escolha)

	seta = Label.new()
	seta.text = "▼"
	seta.add_theme_color_override("font_color", COR_BORDA)
	seta.add_theme_font_size_override("font_size", 24)
	seta.anchor_left = 1.0
	seta.anchor_right = 1.0
	seta.anchor_top = 1.0
	seta.anchor_bottom = 1.0
	seta.offset_left = -136
	seta.offset_right = -106
	seta.offset_top = -82
	seta.offset_bottom = -52
	seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(seta)

	var dica := Label.new()
	dica.text = "E / Espaço: continuar   1-4: escolher   Esc: pular texto"
	dica.add_theme_font_size_override("font_size", 16)
	dica.add_theme_color_override("font_color", Color(0.75, 0.66, 0.5, 0.8))
	dica.anchor_left = 1.0
	dica.anchor_right = 1.0
	dica.anchor_top = 1.0
	dica.anchor_bottom = 1.0
	dica.offset_left = -520
	dica.offset_right = -96
	dica.offset_top = -30
	dica.offset_bottom = -8
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	raiz.add_child(dica)
	painel.visibility_changed.connect(func(): dica.visible = painel.visible)
	dica.visible = false
