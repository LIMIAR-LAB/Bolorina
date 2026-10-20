extends RefCounted
## Tema compartilhado para inventario, equipamento, baus, lojas, forja, mapa e dialogos.
const PASTA := "res://art/ui/vilarejo/"
const TEXTO := Color("f4e5c8")
const OURO := Color("edc17c")
const SUAVE := Color("cabbab")
const ESCURO := Color("292830")
static var _textures := {}
static var _tema: Theme
static var _fonte: SystemFont
static var _titulo: SystemFont

static func textura(nome: String) -> Texture2D:
	if _textures.has(nome): return _textures[nome]
	var file := ProjectSettings.globalize_path(PASTA+nome)
	var image := Image.new()
	var error: int
	if nome.ends_with(".svg"):
		error=image.load_svg_from_string(FileAccess.get_file_as_string(file))
	else:
		error=image.load(file)
	if error!=OK:
		push_error("Tema: textura ausente "+file)
		return null
	var tex := ImageTexture.create_from_image(image)
	_textures[nome]=tex
	return tex

static func fonte(titulo := false) -> Font:
	if titulo:
		if _titulo==null:
			_titulo=SystemFont.new()
			_titulo.font_names=PackedStringArray(["Georgia","Noto Serif"])
			_titulo.font_weight=700
		return _titulo
	if _fonte==null:
		_fonte=SystemFont.new()
		_fonte.font_names=PackedStringArray(["Georgia","Noto Serif"])
	return _fonte

static func caixa(nome := "painel", margem := 16) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture=textura(nome+".svg")
	var fatia := 14 if nome.begins_with("slot") or nome.begins_with("botao") or nome=="vazio" else (24 if nome=="moldura" else 24)
	for lado in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: box.set_texture_margin(lado,fatia)
	box.set_content_margin_all(margem)
	return box

static func tema() -> Theme:
	if _tema!=null:return _tema
	_tema=Theme.new()
	_tema.default_font=fonte()
	_tema.default_font_size=19
	for type in ["Button","OptionButton","TabBar"]:
		for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
			_tema.set_stylebox(state,type,caixa("botao_ativo" if state in ["hover","pressed","hover_pressed","focus"] else "botao",10))
		_tema.set_color("font_color",type,TEXTO)
		for state in ["hover","pressed","focus","hover_pressed"]:
			_tema.set_color("font_"+state+"_color",type,Color("302317"))
		_tema.set_font_size("font_size",type,19)
	_tema.set_color("font_color","Label",TEXTO)
	_tema.set_color("font_color","RichTextLabel",TEXTO)
	_tema.set_stylebox("panel","Panel",caixa())
	_tema.set_stylebox("panel","PanelContainer",caixa())
	_tema.set_stylebox("normal","LineEdit",caixa("vazio",12))
	_tema.set_color("font_color","LineEdit",TEXTO)
	return _tema

static func rotulo(pai: Node, texto: String, pos: Vector2, tamanho := 19, titulo := false) -> Label:
	var l := Label.new()
	l.text=texto;l.position=pos
	l.add_theme_font_override("font",fonte(titulo))
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",TEXTO)
	l.add_theme_color_override("font_shadow_color",Color("151317"))
	l.add_theme_constant_override("shadow_offset_y",2)
	pai.add_child(l)
	return l

static func cabecalho(pai: Node, texto: String, pos: Vector2, tam: Vector2, icone: Texture2D = null) -> Panel:
	var panel := Panel.new()
	panel.position=pos;panel.size=tam
	panel.add_theme_stylebox_override("panel",caixa("madeira"))
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pai.add_child(panel)
	var x := 24.0
	if icone:
		var image := TextureRect.new()
		image.position=Vector2(24,14);image.size=Vector2(48,48)
		image.texture=icone;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		panel.add_child(image);x=88
	var label:=rotulo(panel,texto,Vector2(x,(tam.y-38)/2),28,true)
	label.size=Vector2(tam.x-x-20,38)
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	return panel

static func aplicar_fundo(rect: ColorRect, blur := 1.8) -> void:
	var shader := Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear_mipmap; uniform float nivel = 3.0; void fragment(){ vec3 c=textureLod(tela, SCREEN_UV,nivel).rgb; COLOR=vec4(c*0.90,1.0); }"
	var material := ShaderMaterial.new()
	material.shader=shader;material.set_shader_parameter("nivel",blur)
	rect.material=material
	rect.color=Color.WHITE

static func rodape(pai: Node, pos: Vector2, acoes: Array, largura := 1380.0) -> Control:
	var bar := Panel.new();bar.position=pos;bar.size=Vector2(largura,52)
	bar.add_theme_stylebox_override("panel",caixa("painel",12));pai.add_child(bar)
	var row := HBoxContainer.new();row.position=Vector2(20,10)
	row.add_theme_constant_override("separation",24);bar.add_child(row)
	for action in acoes:
		var group:=HBoxContainer.new();group.add_theme_constant_override("separation",9);row.add_child(group)
		var key:=Label.new();key.text=action[0]
		key.add_theme_stylebox_override("normal",caixa("slot",6))
		key.add_theme_color_override("font_color",Color("33251a"))
		key.add_theme_font_size_override("font_size",16)
		group.add_child(key)
		var name:=Label.new();name.text=action[1];name.add_theme_font_size_override("font_size",17);group.add_child(name)
	return bar
