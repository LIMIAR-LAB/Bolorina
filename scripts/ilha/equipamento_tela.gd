extends CanvasLayer
## Tela de equipamento (I): previa grande da Vale ao vivo, slots, mochila de pecas, defesa.
## Pausa o jogo enquanto aberta (get_tree().paused); esta camada roda em PROCESS_MODE_ALWAYS.
## Teclado: setas/WASD escolhem | Enter/F veste ou tira | X tira a peca do slot | Q/E giram a previa |
## Espaco anda/para | I/Esc fecha. Mouse: clique na peca veste/tira, clique no slot tira.
const Equip = preload("res://scripts/ilha/equipamento.gd")
const Visual = preload("res://scripts/ilha/equipamento_visual.gd")
const PASTA_ICONES := "res://art/ui/icones_equip/"
const DIRS := ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"]
const NOME_DIR := {"south": "sul", "south-west": "sudoeste", "west": "oeste", "north-west": "noroeste", "north": "norte", "north-east": "nordeste", "east": "leste", "south-east": "sudeste"}
const COLS := 8
const CAIXA := 52
const BEGE := Color("f1e2bd")
var g          # gerenciador (jogo_ilha.gd) ou qualquer no com .estado e vestir_atual()
var estado
var aberta := false
var mudou := false
var sel := 0
var dir_i := 0
var andando := true
var quadros: Array[Texture2D] = []
var q_i := 0
var t_ms := 0
var raiz: Control
var previa: TextureRect
var previa_dir: Label
var defesa_label: Label
var slot_caixas := {}
var slot_icones := {}
var slot_nomes := {}
var grade: Array[Panel] = []
var grade_icones: Array = []
var grade_marcas: Array = []
var info_nome: Label
var info_slot: Label
var info_desc: Label
var dica: Label
var selo: Label
static var _icones := {}

func montar(gerenciador, est = null) -> void:
	g = gerenciador
	estado = est if est != null else g.estado
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TelaEquipamento"
	_selo()
	_construir()
	raiz.visible = false

# ---------------------------------------------------------------- interface
func _estilo(bg: Color, borda: Color, w: int, raio := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borda
	s.set_border_width_all(w)
	s.set_corner_radius_all(raio)
	return s

func _rotulo(pai: Control, pos: Vector2, tam: int, cor := BEGE, texto := "") -> Label:
	var l := Label.new()
	l.position = pos
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l

static func icone(id: String) -> Texture2D:
	if _icones.has(id):
		return _icones[id]
	var tex: Texture2D = null
	var cam := ProjectSettings.globalize_path(PASTA_ICONES + id + ".png")
	if FileAccess.file_exists(cam):
		var img := Image.load_from_file(cam)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_icones[id] = tex
	return tex

func _icone_rect(pai: Control, pos: Vector2, lado: float) -> TextureRect:
	var r := TextureRect.new()
	r.position = pos
	r.size = Vector2(lado, lado)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r

## dica fixa no HUD (canto inferior direito, acima da barra de mensagens)
func _selo() -> void:
	var p := Panel.new()
	p.name = "SeloEquipamento"
	p.position = Vector2(1600 - 214, 900 - 63 - 40)
	p.size = Vector2(200, 32)
	p.add_theme_stylebox_override("panel", _estilo(Color(0.16, 0.1, 0.06, 0.85), Color("6b4a2a"), 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var k := Panel.new()
	k.position = Vector2(6, 5)
	k.size = Vector2(22, 22)
	k.add_theme_stylebox_override("panel", _estilo(Color("e8cf98"), Color("fff1b8"), 2, 3))
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(k)
	var kl := _rotulo(k, Vector2(0, 0), 14, Color("3a2412"), "I")
	kl.size = Vector2(22, 22)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kl.add_theme_constant_override("shadow_offset_x", 0)
	kl.add_theme_constant_override("shadow_offset_y", 0)
	selo = _rotulo(p, Vector2(36, 6), 14, BEGE, "Equipamento")

func _construir() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.015, 0.03, 0.62)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(fundo)
	var pn := Panel.new()
	pn.position = Vector2(190, 92)
	pn.size = Vector2(1220, 690)
	pn.add_theme_stylebox_override("panel", _estilo(Color(0.16, 0.1, 0.06, 0.96), Color("6b4a2a"), 4, 6))
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(pn)
	var faixa := Panel.new()
	faixa.position = Vector2(8, 8)
	faixa.size = Vector2(1204, 50)
	faixa.add_theme_stylebox_override("panel", _estilo(Color(0.24, 0.15, 0.08, 1.0), Color("8a6238"), 2, 4))
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_child(faixa)
	var titulo := _rotulo(pn, Vector2(26, 13), 28, Color("e6d4a6"), "EQUIPAMENTO")
	var fonte := SystemFont.new()
	fonte.font_names = PackedStringArray(["Georgia"])
	titulo.add_theme_font_override("font", fonte)
	defesa_label = _rotulo(pn, Vector2(860, 18), 20, Color("f6e7c1"))
	defesa_label.size = Vector2(330, 30)
	defesa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# ---- previa
	var pv := Panel.new()
	pv.position = Vector2(24, 74)
	pv.size = Vector2(336, 470)
	pv.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_child(pv)
	var chao := Previa.new()
	chao.position = Vector2(8, 8)
	chao.size = Vector2(320, 400)
	chao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(chao)
	previa = TextureRect.new()
	previa.position = Vector2(16, 60)
	previa.size = Vector2(304, 304)
	previa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	previa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(previa)
	_rotulo(pv, Vector2(16, 14), 15, Color("cbb48a"), "VALE")
	previa_dir = _rotulo(pv, Vector2(12, 416), 14, BEGE)
	previa_dir.size = Vector2(312, 44)
	previa_dir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for lado in [-1, 1]:
		var b := Button.new()
		b.text = "◀" if lado < 0 else "▶"
		b.position = Vector2(14 if lado < 0 else 280, 196)
		b.size = Vector2(42, 42)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _estilo(Color("c9a46a"), Color("7a5230"), 2))
		b.add_theme_stylebox_override("hover", _estilo(Color("e8cf98"), Color("fff1b8"), 2))
		b.add_theme_stylebox_override("pressed", _estilo(Color("e8cf98"), Color("fff1b8"), 3))
		b.add_theme_color_override("font_color", Color("3a2412"))
		b.add_theme_color_override("font_hover_color", Color("3a2412"))
		b.pressed.connect(girar.bind(lado))
		pv.add_child(b)
	# ---- slots
	_rotulo(pn, Vector2(384, 74), 15, Color("cbb48a"), "VESTINDO")
	for i in Equip.SLOTS.size():
		var s: String = Equip.SLOTS[i]
		# 8 slots: 2 colunas x 4 linhas (conjuntos da forja: maos, pes, escudo, arma)
		var y := 100 + (i % 4) * 110
		var x0 := 384 + (i / 4) * 168
		var cx := Panel.new()
		cx.position = Vector2(x0, y)
		cx.size = Vector2(64, 64)
		cx.mouse_filter = Control.MOUSE_FILTER_STOP
		cx.gui_input.connect(_clique_slot.bind(s))
		cx.tooltip_text = "Clique: tirar"
		pn.add_child(cx)
		slot_caixas[s] = cx
		slot_icones[s] = _icone_rect(cx, Vector2(6, 6), 52)
		_rotulo(pn, Vector2(x0, y + 66), 12, Color("cbb48a"), String(Equip.NOME_SLOT[s]).to_upper())
		var nm := _rotulo(pn, Vector2(x0 + 70, y + 2), 13, BEGE)
		nm.size = Vector2(94, 64)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_nomes[s] = nm
	# ---- mochila
	_rotulo(pn, Vector2(724, 74), 15, Color("cbb48a"), "MOCHILA DE ROUPAS")
	var itens := _lista()
	for i in itens.size():
		var p := Panel.new()
		p.position = Vector2(724 + (i % COLS) * (CAIXA + 8), 100 + (i / COLS) * (CAIXA + 8))
		p.size = Vector2(CAIXA, CAIXA)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(_clique_item.bind(i))
		p.mouse_entered.connect(_sobre.bind(i))
		pn.add_child(p)
		grade.append(p)
		grade_icones.append(_icone_rect(p, Vector2(6, 6), 40))
		var m := Panel.new()
		m.position = Vector2(CAIXA - 20, 3)
		m.size = Vector2(17, 17)
		m.add_theme_stylebox_override("panel", _estilo(Color("5fbf4a"), Color("1f3a14"), 2, 8))
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ml := _rotulo(m, Vector2(0, -2), 12, Color.WHITE, "E")
		ml.size = Vector2(17, 17)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(m)
		grade_marcas.append(m)
	# ---- informacoes
	var inf := Panel.new()
	inf.position = Vector2(724, 340)
	inf.size = Vector2(470, 204)
	inf.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	inf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_child(inf)
	info_nome = _rotulo(inf, Vector2(16, 12), 20, Color("f6e7c1"))
	info_slot = _rotulo(inf, Vector2(16, 44), 14, Color("cbb48a"))
	info_slot.size = Vector2(440, 22)
	info_desc = _rotulo(inf, Vector2(16, 76), 15, BEGE)
	info_desc.size = Vector2(440, 120)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica = _rotulo(pn, Vector2(24, 566), 14, Color("cbb48a"),
		"Setas/WASD: escolher   ·   Enter/F ou clique: vestir/tirar   ·   X: tirar do slot   ·   Q/E ou ◀ ▶: girar   ·   Espaço: andar/parar   ·   I/Esc: fechar")
	var nota := _rotulo(pn, Vector2(24, 600), 13, Color("9c8662"),
		"A roupa aparece na fazenda, na vila, na masmorra e no combate. Na forma Adamantium (G) a armadura da transformação cobre tudo; ao sair, volta o que está vestido.\nCapuz, elmos, couraça e cota de malha: arte do PixelLab.")
	nota.size = Vector2(1170, 60)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _lista() -> Array:
	var out: Array = []
	for s in Equip.SLOTS:
		for id in Equip.INICIAIS + Equip.ITENS.keys():
			if String(Equip.ITENS[id].slot) == s and not out.has(id):
				out.append(id)
	return out

## pecas que a Vale tem, na ordem do catalogo
func possui_lista() -> Array:
	var out: Array = []
	for id in _lista():
		if estado.equipamento.possui.has(id):
			out.append(id)
	return out

# ---------------------------------------------------------------- abrir / fechar
func abrir() -> void:
	if aberta:
		return
	aberta = true
	mudou = false
	raiz.visible = true
	get_tree().paused = true
	sel = clampi(sel, 0, maxi(0, possui_lista().size() - 1))
	t_ms = Time.get_ticks_msec()
	atualizar()

func fechar() -> void:
	if not aberta:
		return
	aberta = false
	raiz.visible = false
	get_tree().paused = false
	if mudou and estado.has_method("salvar"):
		estado.salvar()

func alternar() -> void:
	if aberta:
		fechar()
	else:
		abrir()

# ---------------------------------------------------------------- acoes
func vestir_sel() -> bool:
	var lista := possui_lista()
	if sel < 0 or sel >= lista.size():
		return false
	var ok := Equip.alternar(estado.equipamento, String(lista[sel]))
	if ok:
		_aplicar()
	return ok

func tirar_slot(slot: String) -> bool:
	var ok := Equip.desequipar(estado.equipamento, slot)
	if ok:
		_aplicar()
	return ok

func _aplicar() -> void:
	mudou = true
	if estado.has_method("salvar"):
		estado.salvar()
	if g and g.has_method("vestir_atual"):
		g.vestir_atual()
	atualizar()

func girar(lado: int) -> void:
	dir_i = posmod(dir_i + lado, DIRS.size())
	_carregar_previa()

func _clique_item(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		sel = i
		vestir_sel()

func _clique_slot(ev: InputEvent, slot: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tirar_slot(slot)

func _sobre(i: int) -> void:
	if sel != i:
		sel = i
		atualizar()

func _input(event: InputEvent) -> void:
	if not aberta:
		return
	if event is InputEventKey and event.pressed:
		var k: int = event.physical_keycode
		var eco: bool = event.echo
		var n := possui_lista().size()
		match k:
			KEY_I, KEY_ESCAPE:
				if not eco:
					fechar()
			KEY_LEFT, KEY_A:
				sel = posmod(sel - 1, maxi(1, n))
				atualizar()
			KEY_RIGHT, KEY_D:
				sel = posmod(sel + 1, maxi(1, n))
				atualizar()
			KEY_UP, KEY_W:
				sel = sel - COLS if sel - COLS >= 0 else sel
				atualizar()
			KEY_DOWN, KEY_S:
				sel = sel + COLS if sel + COLS < n else sel
				atualizar()
			KEY_ENTER, KEY_KP_ENTER, KEY_F:
				if not eco:
					vestir_sel()
			KEY_X, KEY_BACKSPACE:
				if not eco:
					var lista := possui_lista()
					if sel < lista.size():
						tirar_slot(String(Equip.ITENS[lista[sel]].slot))
			KEY_Q:
				girar(-1)
			KEY_E:
				girar(1)
			KEY_SPACE:
				if not eco:
					andando = not andando
					_carregar_previa()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- estado visual
func _carregar_previa() -> void:
	var cam: Array = Equip.camadas(estado.equipamento)
	var d: String = DIRS[dir_i]
	quadros = Visual.quadros_previa(cam, ("run_" if andando else "idle_") + d)
	q_i = q_i % maxi(1, quadros.size())
	previa.texture = quadros[q_i] if not quadros.is_empty() else null
	previa_dir.text = "Olhando para o %s · %s\nQ/E girar · Espaço %s" % [NOME_DIR[d], "andando" if andando else "parada", "parar" if andando else "andar"]

func atualizar() -> void:
	var eq: Dictionary = estado.equipamento
	var lista := possui_lista()
	sel = clampi(sel, 0, maxi(0, lista.size() - 1))
	defesa_label.text = "DEFESA TOTAL  %d" % Equip.defesa(eq)
	for s in Equip.SLOTS:
		var id := Equip.equipado(eq, s)
		slot_icones[s].texture = icone(id) if id != "" else null
		slot_nomes[s].text = (String(Equip.ITENS[id].nome) + ("\nDEF +%d" % int(Equip.ITENS[id].defesa) if int(Equip.ITENS[id].defesa) > 0 else "")) if id != "" else "— vazio —"
		var destaque: bool = lista.size() > 0 and sel < lista.size() and String(Equip.ITENS[lista[sel]].slot) == s
		slot_caixas[s].add_theme_stylebox_override("panel", _estilo(Color("e8cf98") if destaque else Color("c9a46a"), Color("fff1b8") if destaque else Color("7a5230"), 4 if destaque else 2))
	for i in grade.size():
		var tem := i < lista.size()
		grade[i].visible = tem
		if not tem:
			continue
		var id: String = lista[i]
		grade_icones[i].texture = icone(id)
		var vest := Equip.esta_equipado(eq, id)
		grade_marcas[i].visible = vest
		var e_sel := i == sel
		grade[i].add_theme_stylebox_override("panel", _estilo(Color("e8cf98") if e_sel else (Color("d8b77c") if vest else Color("c9a46a")), Color("fff1b8") if e_sel else (Color("5fbf4a") if vest else Color("7a5230")), 4 if e_sel else (3 if vest else 2)))
		grade[i].tooltip_text = String(Equip.ITENS[id].nome)
	if sel < lista.size():
		var id: String = lista[sel]
		var it: Dictionary = Equip.ITENS[id]
		var vest := Equip.esta_equipado(eq, id)
		var d0 := Equip.defesa(eq)
		var d1 := Equip.defesa_com(eq, id)
		var dif := d1 - d0
		info_nome.text = String(it.nome) + ("   (vestido)" if vest else "")
		info_slot.text = "%s  ·  Defesa +%d  ·  %s %s" % [String(Equip.NOME_SLOT[it.slot]), int(it.defesa), "Tirar:" if vest else "Vestir:", ("defesa %d → %d" % [d0, d1]) if dif != 0 else "defesa igual"]
		info_slot.add_theme_color_override("font_color", Color("8fd86a") if dif > 0 else (Color("e58a6a") if dif < 0 else Color("cbb48a")))
		info_desc.text = String(it.desc)
	_carregar_previa()

func _process(_delta: float) -> void:
	if not aberta or quadros.is_empty():
		return
	var agora := Time.get_ticks_msec()
	var passo := 111 if andando else 400
	if agora - t_ms >= passo:
		t_ms = agora
		q_i = (q_i + 1) % quadros.size()
		previa.texture = quadros[q_i]

## fundo da previa: grama e sombra de contato (desenho por codigo, pixelado)
class Previa extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("3c5a3a"))
		for i in 40:
			var x := float((i * 73) % int(size.x))
			var y := 250.0 + float((i * 37) % 140)
			draw_rect(Rect2(x, y, 4, 4), Color("4f7448"))
		draw_rect(Rect2(0, 0, size.x, 230), Color("2f4a5c"))
		draw_rect(Rect2(0, 226, size.x, 6), Color("2a4026"))
		var c := Vector2(size.x * 0.5, 342)
		for k in 3:
			var w := 120.0 - k * 26.0
			draw_rect(Rect2(c.x - w * 0.5, c.y - 8 + k * 4, w, 12 - k * 4), Color(0, 0, 0, 0.18))
