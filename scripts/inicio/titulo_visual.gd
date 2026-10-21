extends RefCounted
## Bolorina 21/10/2026 — visual da tela inicial (so aparencia; a logica continua em menu_inicial.gd).
## 21/10 (3a passada): o fundo agora e a arte conceitual do Thiago (art/ui/titulo/fundo_titulo.png, UI pintada
## removida), com Ken Burns lento, brilho nas cachoeiras, sol pulsando, cinzas e brasas. O fundo 3D do Mirante
## fica so como reserva se a imagem nao carregar. Botoes em placas separadas com icone, como na referencia.
const PASTA := "res://art/ui/titulo/"
const OURO := Color("f0c77e")
const OURO_FORTE := Color("ffd98f")
const TINTA := Color("1a1018")

static func _tex(nome: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(PASTA + nome))
	return ImageTexture.create_from_image(img) if img else null

static func fundo_3d(pai: Control) -> SubViewport:
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

const FUNDO := "res://art/ui/titulo/fundo_titulo.png"
## retangulos das cachoeiras na imagem (UV) e posicao do sol
const QUEDAS := [Vector4(0.632, 0.52, 0.698, 0.865), Vector4(0.390, 0.42, 0.410, 0.66), Vector4(0.482, 0.17, 0.502, 0.36), Vector4(0.874, 0.61, 0.902, 0.82), Vector4(0.890, 0.13, 0.908, 0.22), Vector4(0.586, 0.80, 0.598, 0.90)]

static func _textura_fundo() -> Texture2D:
	if ResourceLoader.exists(FUNDO):
		var t = load(FUNDO)
		if t is Texture2D:
			return t
	var img := Image.load_from_file(ProjectSettings.globalize_path(FUNDO))
	return ImageTexture.create_from_image(img) if img and not img.is_empty() else null

## fundo pintado com vida; se a imagem falhar, cai no fundo 3D antigo
static func fundo(pai: Control) -> Control:
	var tex := _textura_fundo()
	if tex == null:
		push_warning("tela inicial: fundo_titulo.png nao carregou, usando o fundo 3D")
		var vp := fundo_3d(pai)
		return vp.get_parent() as Control
	var box := Control.new()
	box.name = "FundoVivo"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(box)
	var pintura := TextureRect.new()
	pintura.name = "Pintura"
	pintura.texture = tex
	pintura.set_anchors_preset(Control.PRESET_FULL_RECT)
	pintura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pintura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pintura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pintura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/titulo/fundo_titulo.gdshader")
	var q := PackedVector4Array()
	for r in QUEDAS: q.append(r)
	mat.set_shader_parameter("quedas", q)
	mat.set_shader_parameter("n_quedas", QUEDAS.size())
	pintura.material = mat
	box.add_child(pintura)
	# Ken Burns lento: sempre com zoom > 1, entao a imagem continua cobrindo a tela
	var arrumar := func() -> void:
		pintura.pivot_offset = pintura.size * 0.5
	pintura.resized.connect(arrumar)
	arrumar.call_deferred()
	pintura.scale = Vector2.ONE * 1.045
	var tw := pintura.create_tween().set_loops()
	tw.tween_property(pintura, "scale", Vector2.ONE * 1.095, 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(pintura, "position", Vector2(-18, -8), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pintura, "scale", Vector2.ONE * 1.045, 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(pintura, "position", Vector2(10, 4), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# veu escuro a esquerda (leitura do menu e esconde a area repintada) + vinheta
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.30, 0.52, 1.0])
	g.colors = PackedColorArray([Color(0.06, 0.03, 0.06, 0.78), Color(0.06, 0.03, 0.06, 0.55), Color(0.06, 0.03, 0.06, 0.12), Color(0.06, 0.03, 0.06, 0.0)])
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
	box.add_child(veu)
	var vg := Gradient.new()
	vg.offsets = PackedFloat32Array([0.6, 1.0])
	vg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.03, 0.01, 0.04, 0.55)])
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
	box.add_child(vinheta)
	cinza_caindo(box)
	cinzas(box)
	return box

## flocos de cinza caindo devagar, de lado (alem das brasas que sobem)
static func cinza_caindo(pai: Control) -> void:
	var p := CPUParticles2D.new()
	p.name = "CinzaCaindo"
	p.amount = 55
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.position = Vector2(700, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1000, 10)
	p.direction = Vector2(0.45, 1)
	p.spread = 20.0
	p.gravity = Vector2(4, 8)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 45.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 3.0
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	rampa.colors = PackedColorArray([Color(0.85, 0.8, 0.8, 0), Color(0.85, 0.8, 0.82, 0.55), Color(0.7, 0.66, 0.7, 0.4), Color(0.6, 0.6, 0.6, 0)])
	p.color_ramp = rampa
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	pai.add_child(p)

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

# ---------------------------------------------------------------- 3a passada: layout da referencia do Thiago
const ICONES := "res://art/ui/titulo/icones/"

static func _icone(nome: String) -> Texture2D:
	var cam := ICONES + nome + ".png"
	if ResourceLoader.exists(cam):
		return load(cam)
	var img := Image.load_from_file(ProjectSettings.globalize_path(cam))
	return ImageTexture.create_from_image(img) if img else null

## linha dourada que some nas pontas
static func _linha(pai: Control, x0: float, x1: float, y: float, sumir_esq := true, sumir_dir := true) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	g.colors = PackedColorArray([Color(OURO, 0.0 if sumir_esq else 0.9), Color(OURO, 0.9), Color(OURO, 0.9), Color(OURO, 0.0 if sumir_dir else 0.9)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 1
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = Vector2(x0, y)
	r.size = Vector2(x1 - x0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)

static func _enfeite(pai: Control, nome: String, centro: Vector2, lado: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _icone(nome)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(lado, lado)
	r.position = centro - r.size * 0.5
	r.modulate = OURO
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r

## logo como na referencia: versalete + ornamento estrela, titulo grande, linha com folha, frase
static func logo_ref(pai: Control, pos: Vector2, fonte: Font) -> Control:
	var c := Control.new()
	c.name = "Logo"
	c.position = pos
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(c)
	var espacada := FontVariation.new()
	espacada.base_font = fonte
	espacada.spacing_glyph = 3
	var sub := Label.new()
	sub.text = "CRÔNICAS DO POENTE"
	sub.position = Vector2(10, 0)
	sub.add_theme_font_override("font", espacada)
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color("ecc996"))
	sub.add_theme_color_override("font_outline_color", TINTA)
	sub.add_theme_constant_override("outline_size", 4)
	c.add_child(sub)
	_linha(c, 4, 120, 37, true, false)
	_enfeite(c, "ornamento_estrela", Vector2(134, 38), 20)
	_linha(c, 148, 268, 37, false, true)
	var t := Label.new()
	t.name = "Titulo"
	t.text = "Ilha das Cinzas"
	t.position = Vector2(0, 40)
	t.add_theme_font_override("font", fonte)
	t.add_theme_font_size_override("font_size", 90)
	t.add_theme_color_override("font_color", OURO_FORTE)
	t.add_theme_color_override("font_outline_color", Color("2a160c"))
	t.add_theme_constant_override("outline_size", 7)
	t.add_theme_color_override("font_shadow_color", Color(0.95, 0.45, 0.12, 0.45))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_constant_override("shadow_outline_size", 24)
	c.add_child(t)
	_linha(c, 0, 262, 160, true, false)
	_enfeite(c, "ornamento_folha", Vector2(284, 158), 30)
	_linha(c, 306, 580, 160, false, true)
	var frase := Label.new()
	frase.text = "Cultive um lar. Explore o que restou."
	frase.position = Vector2(8, 178)
	frase.add_theme_font_override("font", fonte)
	frase.add_theme_font_size_override("font_size", 25)
	frase.add_theme_color_override("font_color", Color("f6ead2"))
	frase.add_theme_color_override("font_outline_color", TINTA)
	frase.add_theme_constant_override("outline_size", 6)
	c.add_child(frase)
	var tw := t.create_tween().set_loops()
	tw.tween_property(t, "modulate", Color(1.08, 1.0, 0.92), 2.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t, "modulate", Color(1, 1, 1), 2.6).set_trans(Tween.TRANS_SINE)
	return c

static func _caixa(fundo_cor: Color, borda: Color, largura: int, brilho := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo_cor
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(4)
	s.content_margin_left = 92
	s.content_margin_right = 50
	if brilho > 0.0:
		s.shadow_color = Color(1.0, 0.62, 0.25, brilho)
		s.shadow_size = 16
	return s

## botao em placa propria: moldura escura, filete interno, icone a esquerda, chevron no foco
static func placa(b: Button, fonte: Font, icone: String) -> void:
	var normal := _caixa(Color(0.10, 0.06, 0.07, 0.74), Color(0.80, 0.62, 0.40, 0.55), 1)
	var foco := _caixa(Color(0.30, 0.15, 0.08, 0.86), Color(1.0, 0.84, 0.52, 1.0), 2, 0.42)
	foco.bg_color = Color(0.32, 0.16, 0.08, 0.88)
	var desligado := _caixa(Color(0.08, 0.05, 0.06, 0.55), Color(0.70, 0.58, 0.45, 0.30), 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("disabled", desligado)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, foco)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", fonte)
	b.add_theme_font_size_override("font_size", 29)
	b.add_theme_color_override("font_color", Color("f2e4c8"))
	for st in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, Color("fff3d6"))
	b.add_theme_color_override("font_disabled_color", Color(0.80, 0.72, 0.64, 0.42))
	b.add_theme_color_override("font_outline_color", TINTA)
	b.add_theme_constant_override("outline_size", 5)
	# filete interno (moldura dupla da referencia)
	var filete := Panel.new()
	filete.name = "Filete"
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.border_color = Color(0.85, 0.66, 0.42, 0.30)
	fs.set_border_width_all(1)
	fs.set_corner_radius_all(3)
	filete.add_theme_stylebox_override("panel", fs)
	filete.set_anchors_preset(Control.PRESET_FULL_RECT)
	filete.offset_left = 5; filete.offset_top = 5; filete.offset_right = -5; filete.offset_bottom = -5
	filete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(filete)
	var ic := TextureRect.new()
	ic.name = "Icone"
	ic.texture = _icone(icone)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(36, 36)
	ic.position = Vector2(32, (b.size.y - 36) * 0.5)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color("e8d2ae") if not b.disabled else Color(0.8, 0.72, 0.64, 0.42)
	b.add_child(ic)
	var ch := TextureRect.new()
	ch.name = "Chevron"
	ch.texture = _icone("chevron")
	ch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ch.size = Vector2(26, 26)
	ch.position = Vector2(b.size.x - 46, (b.size.y - 26) * 0.5)
	ch.modulate = Color(OURO_FORTE, 0.0)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ch)
	var x0 := b.position.x
	var animar := func(dentro: bool) -> void:
		if not is_instance_valid(b):
			return
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "position:x", x0 + (8.0 if dentro else 0.0), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ch, "modulate:a", 1.0 if dentro else 0.0, 0.16)
		tw.tween_property(ic, "modulate", OURO_FORTE if dentro else Color("e8d2ae"), 0.16)
	b.focus_entered.connect(animar.bind(true))
	b.focus_exited.connect(animar.bind(false))
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
