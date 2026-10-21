extends RefCounted
## Bolorina 21/10/2026 — visual da tela inicial (so aparencia; a logica continua em menu_inicial.gd).
## Fundo vivo 3D (Mirante da Cascata em modo vitrine, por do sol, cachoeira e luz), veu de leitura,
## cinzas subindo, logotipo e botoes com moldura Kenney Fantasy UI Borders (CC0) e animacao de foco.
const PASTA := "res://art/ui/titulo/"
const OURO := Color("f0c77e")
const OURO_FORTE := Color("ffd98f")
const TINTA := Color("1a1018")

static func _tex(nome: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(PASTA + nome))
	return ImageTexture.create_from_image(img) if img else null

static func fundo(pai: Control) -> SubViewport:
	var box := SubViewportContainer.new()
	box.name = "FundoVivo"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.size = Vector2i(1600, 900)
	box.add_child(vp)
	var cena = load("res://scenes/mirante_cascata/mirante_cascata.tscn").instantiate()
	cena.vitrine = true
	vp.add_child(cena)
	# veu: escurece a esquerda (menu) e as bordas, sem apagar o por do sol
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	g.colors = PackedColorArray([Color(0.05, 0.03, 0.06, 0.86), Color(0.05, 0.03, 0.06, 0.35), Color(0.05, 0.03, 0.06, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	var veu := TextureRect.new()
	veu.texture = gt
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.stretch_mode = TextureRect.STRETCH_SCALE
	veu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(veu)
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.55, 1.0])
	vg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.03, 0.01, 0.04, 0.75)])
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.1, 1.0)
	vt.width = 256
	vt.height = 256
	var vinheta := TextureRect.new()
	vinheta.texture = vt
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(vinheta)
	cinzas(pai)
	return vp

## cinzas/brasas subindo pela tela (o nome do jogo)
static func cinzas(pai: Control) -> void:
	var p := CPUParticles2D.new()
	p.name = "Cinzas"
	p.amount = 70
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(800, 940)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 10)
	p.direction = Vector2(0.25, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.68, 0.36, 0.85)
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	rampa.colors = PackedColorArray([Color(1, 0.8, 0.5, 0), Color(1, 0.75, 0.4, 0.9), Color(1, 0.45, 0.25, 0.6), Color(0.5, 0.4, 0.4, 0)])
	p.color_ramp = rampa
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	pai.add_child(p)

static func logo(pai: Control, pos: Vector2, fonte: Font) -> Control:
	var c := Control.new()
	c.name = "Logo"
	c.position = pos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(c)
	var sub := Label.new()
	sub.text = "C R Ô N I C A S   D O   P O E N T E"
	sub.position = Vector2(6, 0)
	sub.add_theme_font_override("font", fonte)
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color("e9b98a"))
	c.add_child(sub)
	var t := Label.new()
	t.text = "Ilha das Cinzas"
	t.position = Vector2(0, 22)
	t.add_theme_font_override("font", fonte)
	t.add_theme_font_size_override("font_size", 96)
	t.add_theme_color_override("font_color", OURO_FORTE)
	t.add_theme_color_override("font_outline_color", TINTA)
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_shadow_color", Color(0.9, 0.35, 0.1, 0.55))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 6)
	t.add_theme_constant_override("shadow_outline_size", 22)
	c.add_child(t)
	var div := TextureRect.new()
	div.texture = _tex("divisor.png")
	div.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	div.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	div.stretch_mode = TextureRect.STRETCH_SCALE
	div.position = Vector2(4, 150)
	div.size = Vector2(560, 34)
	div.modulate = OURO
	c.add_child(div)
	var frase := Label.new()
	frase.text = "Cultive um lar. Explore o que restou."
	frase.position = Vector2(8, 190)
	frase.add_theme_font_override("font", fonte)
	frase.add_theme_font_size_override("font_size", 24)
	frase.add_theme_color_override("font_color", Color("f4e5c8"))
	frase.add_theme_color_override("font_outline_color", TINTA)
	frase.add_theme_constant_override("outline_size", 6)
	c.add_child(frase)
	# respira devagar
	var tw := t.create_tween().set_loops()
	tw.tween_property(t, "modulate", Color(1.08, 1.0, 0.92), 2.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "modulate", Color(1, 1, 1), 2.4).set_trans(Tween.TRANS_SINE)
	return c

static func moldura(nome: String, cor: Color, fundo_cor: Color, margem := 18) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _tex(nome)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_texture_margin(lado, 16)
		s.set_content_margin(lado, margem)
	s.modulate_color = cor
	s.draw_center = true
	return s

static func painel(pai: Control, pos: Vector2, tam: Vector2) -> Panel:
	var fundo_p := Panel.new()
	fundo_p.position = pos
	fundo_p.size = tam
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.07, 0.58)
	sb.set_corner_radius_all(6)
	fundo_p.add_theme_stylebox_override("panel", sb)
	pai.add_child(fundo_p)
	var borda := Panel.new()
	borda.set_anchors_preset(Control.PRESET_FULL_RECT)
	var st := moldura("moldura_menu.png", OURO, Color(0, 0, 0, 0))
	st.draw_center = false
	borda.add_theme_stylebox_override("panel", st)
	borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	borda.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fundo_p.add_child(borda)
	return fundo_p

## estilo do botao do menu inicial: texto grande, sem caixa; em foco/hover ganha moldura dourada,
## desliza para a direita e mostra o losango
static func estilizar(b: Button, fonte: Font, destaque := false) -> void:
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color(0, 0, 0, 0)
	vazio.content_margin_left = 34
	var foco := StyleBoxFlat.new()
	foco.bg_color = Color(0.95, 0.62, 0.28, 0.20)
	foco.border_color = Color(1.0, 0.82, 0.5, 0.95)
	foco.border_width_left = 4
	foco.set_corner_radius_all(4)
	foco.content_margin_left = 34
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, vazio)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, foco)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", fonte)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", OURO_FORTE if destaque else Color("f4e5c8"))
	for st in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, Color("fff1cf"))
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.68, 0.62, 0.45))
	b.add_theme_color_override("font_outline_color", TINTA)
	b.add_theme_constant_override("outline_size", 6)
	var x0 := b.position.x
	var animar := func(dentro: bool) -> void:
		if not is_instance_valid(b):
			return
		var tw := b.create_tween()
		tw.tween_property(b, "position:x", x0 + (14.0 if dentro else 0.0), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	b.focus_entered.connect(animar.bind(true))
	b.focus_exited.connect(animar.bind(false))
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
