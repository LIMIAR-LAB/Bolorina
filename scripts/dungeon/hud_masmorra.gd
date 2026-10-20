extends CanvasLayer
## HUD da masmorra (PROPOSTA): título do andar, vida/energia da jogadora, barra do chefe,
## aviso de interação [E], lista de loot recente e faixa central (banner).
var titulo: Label
var subtitulo: Label
var vida_fundo: ColorRect
var vida: ColorRect
var vida_txt: Label
var energia: ColorRect
var chefe_caixa: Control
var chefe_nome: Label
var chefe_barra: ColorRect
var prompt: Label
var feed: VBoxContainer
var banner: Label
var contagem: Label
var _t_banner := 0.0
var cor_tema := Color("ffd27a")

func _ready() -> void:
	layer = 5
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	titulo = _label(raiz, 30, Vector2(28, 18))
	subtitulo = _label(raiz, 18, Vector2(30, 58))
	subtitulo.modulate = Color(1, 1, 1, 0.8)
	contagem = _label(raiz, 17, Vector2(30, 84))
	contagem.modulate = Color(1, 1, 1, 0.75)
	# vida
	vida_fundo = ColorRect.new()
	vida_fundo.color = Color(0.05, 0.03, 0.04, 0.85)
	vida_fundo.position = Vector2(28, 118)
	vida_fundo.size = Vector2(304, 22)
	raiz.add_child(vida_fundo)
	vida = ColorRect.new()
	vida.color = Color("e04a3a")
	vida.position = Vector2(2, 2)
	vida.size = Vector2(300, 18)
	vida_fundo.add_child(vida)
	vida_txt = _label(vida_fundo, 15, Vector2(8, 0))
	energia = ColorRect.new()
	energia.color = Color("6ad8ff")
	energia.position = Vector2(28, 144)
	energia.size = Vector2(300, 6)
	raiz.add_child(energia)
	# chefe
	chefe_caixa = Control.new()
	chefe_caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	chefe_caixa.position = Vector2(-360, 22)
	chefe_caixa.size = Vector2(720, 60)
	chefe_caixa.visible = false
	raiz.add_child(chefe_caixa)
	chefe_nome = _label(chefe_caixa, 24, Vector2(0, 0))
	chefe_nome.size = Vector2(720, 30)
	chefe_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cf := ColorRect.new()
	cf.color = Color(0.05, 0.03, 0.04, 0.9)
	cf.position = Vector2(0, 34)
	cf.size = Vector2(720, 18)
	chefe_caixa.add_child(cf)
	chefe_barra = ColorRect.new()
	chefe_barra.color = Color("ff8a2a")
	chefe_barra.position = Vector2(2, 2)
	chefe_barra.size = Vector2(716, 14)
	cf.add_child(chefe_barra)
	# prompt
	prompt = _label(raiz, 24, Vector2.ZERO)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-500, -96)
	prompt.size = Vector2(1000, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.visible = false
	# feed de loot
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed.position = Vector2(-380, 24)
	feed.size = Vector2(350, 300)
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	raiz.add_child(feed)
	# banner
	banner = _label(raiz, 44, Vector2.ZERO)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-700, -160)
	banner.size = Vector2(1400, 120)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.visible = false
	# ajuda
	var ajuda := _label(raiz, 14, Vector2.ZERO)
	ajuda.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ajuda.position = Vector2(28, -34)
	ajuda.text = "WASD mover · J/clique atacar · K/botão direito especial · Espaço esquiva · G Adamantium · E interagir · Tab mapa"
	ajuda.modulate = Color(1, 1, 1, 0.55)

func _label(pai: Control, tam: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.03))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l

func definir_titulo(t: String, s: String, cor: Color) -> void:
	cor_tema = cor
	titulo.text = t
	titulo.modulate = cor
	subtitulo.text = s

func atualizar(j, chefe, info: String) -> void:
	if j:
		var f := clampf(float(j.hp) / maxf(j.hp_max, 1), 0, 1)
		vida.size.x = 300.0 * f
		vida_txt.text = "Vale  %d / %d" % [j.hp, j.hp_max]
		energia.size.x = 300.0 * clampf(j.energia / maxf(j.energia_max, 1.0), 0, 1)
		energia.color = Color("aef4ff") if j.transformado else (Color("6ad8ff") if j.energia >= j.energia_max - 0.01 else Color("3a7898"))
	contagem.text = info
	chefe_caixa.visible = chefe != null and is_instance_valid(chefe) and chefe.acordado and chefe.vivo
	if chefe_caixa.visible:
		chefe_nome.text = String(chefe.def.get("nome", "Chefe")) + ("  · fase 2" if chefe.fase >= 2 else "")
		chefe_barra.size.x = 716.0 * clampf(float(chefe.hp) / maxf(chefe.hp_max, 1), 0, 1)

func mostrar_prompt(texto: String) -> void:
	prompt.visible = texto != ""
	prompt.text = texto

func loot(texto: String, cor: Color) -> void:
	var l := _label(feed, 18, Vector2.ZERO)
	l.text = texto
	l.modulate = cor
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	while feed.get_child_count() > 7:
		feed.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)

func mostrar_banner(texto: String, duracao := 2.5, cor := Color.WHITE) -> void:
	banner.text = texto
	banner.modulate = cor
	banner.visible = true
	_t_banner = duracao

func _process(delta: float) -> void:
	if _t_banner > 0.0:
		_t_banner -= delta
		if _t_banner <= 0.0:
			banner.visible = false
