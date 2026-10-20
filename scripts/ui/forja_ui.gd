extends Control
## Interface da forja (PROPOSTA). Cena: res://scenes/ui/forja_ui.tscn. Independente: rodando a cena sozinha
## (F6) ela monta uma mochila de demonstração. No jogo, chame abrir(gerenciador_missoes).
##
## Responde as perguntas do plano:
##   o que dá para forjar agora?        filtros "Dá para forjar" / "Falta material" / "Travado" / "Tudo"
##   vale a pena?                         comparação com o equipado (verde melhorou, vermelho piorou)
##   de onde vem o que falta?             área e andar de cada material que falta (ou a fundição dele)
##   e agora?                             Forjar, Equipar, Testar na Arena (sinal testar_na_arena)
## Também mostra a Têmpera em cinza (reforço da missão) e a escolha Eco rápido / Eco pesado.
##
## Teclado: setas, Enter (ações / confirmar), Q/E filtro, X equipar, T testar, Esc fechar.
## Controle: direcional/analógico, A confirmar, LB/RB filtro, X equipar, Y testar, B fechar.
signal fechada
signal testar_na_arena(item_id: String, variacao_eco: String)
signal forjado(receita_id: String, item_id: String)
signal equipado(slot: String, item_id: String)
signal eco_escolhido(variacao_id: String)

const Modelo = preload("res://scripts/ui/forja_modelo.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"
const COR_FUNDO := Color("1b1410")
const COR_BORDA := Color("c9a25a")
const COR_BORDA_ESCURA := Color("5a3d22")
const COR_TEXTO := Color("f1e2bd")
const COR_NOME := Color("ffd27a")
const COR_TITULO := Color("b8a07a")
const COR_BOM := Color("7fe07a")
const COR_RUIM := Color("ff6b5a")
const COR_FALTA := Color("ffae5a")
const COR_TRAVADO := Color("8a7d6a")
const ESPECIAL_REFORCO := "@reforco"
const ESPECIAL_ECO := "@eco"

@export var demo_se_sozinha := true

var modelo
var filtro := "pode"
var selecionado := ""
var _fonte: Font
var _gerenciador_proprio = null

var lista_box: VBoxContainer
var lista_scroll: ScrollContainer
var botoes_filtro: Dictionary = {}
var lbl_ouro: Label
var lbl_subtitulo: Label
var detalhe_box: VBoxContainer
var btn_forjar: Button
var btn_equipar: Button
var btn_testar: Button
var lbl_aviso: Label
var botoes_lista: Array = []
var botoes_eco: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fonte = load(FONTE) if ResourceLoader.exists(FONTE) else ThemeDB.fallback_font
	theme = _tema()
	_montar()
	if modelo == null and demo_se_sozinha and get_parent() == get_tree().root:
		abrir(_gerenciador_demo())

## Abre a forja ligada ao gerenciador de missões do jogo.
func abrir(gerenciador, forja = null, niveis: Dictionary = {}) -> void:
	modelo = Modelo.new(gerenciador, forja, niveis)
	modelo.mudou.connect(_atualizar_tudo)
	modelo.item_forjado.connect(func(r, i): forjado.emit(r, i))
	modelo.item_equipado.connect(func(s, i): equipado.emit(s, i))
	modelo.eco_escolhido.connect(func(v, _p): eco_escolhido.emit(v))
	visible = true
	if modelo.reforco_disponivel() or modelo.modo_eco() == "missao":
		filtro = "pode"
	elif modelo.lista("pode").is_empty():
		filtro = "tudo"
	selecionado = ""
	_avisar("")
	_atualizar_tudo()
	_focar_lista()

func fechar() -> void:
	visible = false
	fechada.emit()

# ------------------------------------------------------------------ montagem
func _estilo(fundo: Color, borda: Color, largura := 4, margem := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margem)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 6
	s.shadow_offset = Vector2(4, 4)
	return s

func _tema() -> Theme:
	var t := Theme.new()
	t.default_font = _fonte
	t.default_font_size = 24
	var b_normal := _estilo(Color("2a1f17"), COR_BORDA_ESCURA, 3, 8)
	var b_foco := _estilo(Color("4a3220"), COR_BORDA, 3, 8)
	var b_off := _estilo(Color("1f1915"), Color("3a2c22"), 3, 8)
	for s in [b_normal, b_foco, b_off]:
		s.shadow_size = 0
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_foco)
	t.set_stylebox("pressed", "Button", b_foco)
	t.set_stylebox("focus", "Button", b_foco)
	t.set_stylebox("disabled", "Button", b_off)
	t.set_stylebox("hover_pressed", "Button", b_foco)
	t.set_color("font_color", "Button", COR_TEXTO)
	t.set_color("font_hover_color", "Button", COR_NOME)
	t.set_color("font_focus_color", "Button", COR_NOME)
	t.set_color("font_pressed_color", "Button", COR_NOME)
	t.set_color("font_hover_pressed_color", "Button", COR_NOME)
	t.set_color("font_disabled_color", "Button", Color("6d6050"))
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Label", COR_TEXTO)
	t.set_font_size("font_size", "Label", 22)
	return t

func _label(texto: String, tam := 22, cor := COR_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.02, 0.02, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)
	var painel := PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel", _estilo(COR_FUNDO, COR_BORDA, 4, 18))
	painel.set_anchors_preset(Control.PRESET_FULL_RECT)
	painel.offset_left = 56; painel.offset_top = 36; painel.offset_right = -56; painel.offset_bottom = -36
	add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	painel.add_child(v)
	# cabeçalho
	var cab := HBoxContainer.new()
	v.add_child(cab)
	var tit := VBoxContainer.new()
	tit.add_theme_constant_override("separation", 0)
	cab.add_child(tit)
	var l_tit := _label("Ferraria do Porto", 36, COR_NOME)
	l_tit.add_theme_color_override("font_outline_color", Color("2b1a0c"))
	l_tit.add_theme_constant_override("outline_size", 6)
	tit.add_child(l_tit)
	lbl_subtitulo = _label("", 18, COR_TITULO)
	tit.add_child(lbl_subtitulo)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(esp)
	lbl_ouro = _label("", 26, COR_NOME)
	lbl_ouro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cab.add_child(lbl_ouro)
	# filtros
	var fil := HBoxContainer.new()
	fil.add_theme_constant_override("separation", 8)
	v.add_child(fil)
	for f in Modelo.FILTROS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_mudar_filtro.bind(f))
		fil.add_child(b)
		botoes_filtro[f] = b
	fil.add_child(_label("   Q / E  ·  LB / RB", 16, COR_TITULO))
	# corpo
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 14)
	v.add_child(corpo)
	var pl := PanelContainer.new()
	pl.custom_minimum_size = Vector2(520, 0)
	pl.add_theme_stylebox_override("panel", _estilo(Color("140f0c"), COR_BORDA_ESCURA, 3, 8))
	corpo.add_child(pl)
	lista_scroll = ScrollContainer.new()
	lista_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lista_scroll.follow_focus = true
	pl.add_child(lista_scroll)
	lista_box = VBoxContainer.new()
	lista_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_box.add_theme_constant_override("separation", 4)
	lista_scroll.add_child(lista_box)
	var pd := PanelContainer.new()
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pd.add_theme_stylebox_override("panel", _estilo(Color("211913"), COR_BORDA_ESCURA, 3, 16))
	corpo.add_child(pd)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	pd.add_child(dv)
	var ds := ScrollContainer.new()
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dv.add_child(ds)
	detalhe_box = VBoxContainer.new()
	detalhe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalhe_box.add_theme_constant_override("separation", 8)
	ds.add_child(detalhe_box)
	lbl_aviso = _label("", 20, COR_NOME)
	lbl_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_aviso.visible = false
	dv.add_child(lbl_aviso)
	var acoes := HBoxContainer.new()
	acoes.add_theme_constant_override("separation", 10)
	dv.add_child(acoes)
	btn_forjar = Button.new(); btn_forjar.name = "Forjar"; btn_forjar.text = "Forjar"
	btn_equipar = Button.new(); btn_equipar.name = "Equipar"; btn_equipar.text = "Equipar  [X]"
	btn_testar = Button.new(); btn_testar.name = "Testar"; btn_testar.text = "Testar na Arena  [T / Y]"
	for b in [btn_forjar, btn_equipar, btn_testar]:
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		acoes.add_child(b)
	btn_forjar.pressed.connect(_acao_forjar)
	btn_equipar.pressed.connect(_acao_equipar)
	btn_testar.pressed.connect(_acao_testar)
	btn_forjar.focus_neighbor_left = btn_forjar.get_path_to(btn_testar)
	btn_testar.focus_neighbor_right = btn_testar.get_path_to(btn_forjar)
	# rodapé
	var rod := _label("Setas: escolher, ir às ações e voltar   Enter/A confirmar   X equipar   T/Y testar   Q/E·LB/RB filtro   Esc/B sair", 16, COR_TITULO)
	rod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rod)

# ------------------------------------------------------------------ atualização
func _atualizar_tudo() -> void:
	if modelo == null:
		return
	var f: Dictionary = modelo.forja.forjas.get(modelo.forja_id, {})
	var nv := int(modelo.niveis.get(modelo.forja_id, 1))
	var nome_nv := ""
	for n in f.get("niveis", []):
		if int(n.nivel) == nv:
			nome_nv = String(n.nome)
	lbl_subtitulo.text = "%s  ·  %s (nível %d)  ·  arma: %s" % [String(f.get("ferreiro_nome", "")), nome_nv, nv, modelo.nome(String(modelo.equipado.get("arma", "")))]
	lbl_ouro.text = "Ouro  %d" % modelo.ouro()
	var c: Dictionary = modelo.contagem()
	for k in botoes_filtro:
		var b: Button = botoes_filtro[k]
		b.text = "%s (%d)" % [Modelo.NOMES_FILTRO[k], int(c[k])]
		b.set_pressed_no_signal(k == filtro)
	_montar_lista()
	_mostrar(selecionado)

func entradas() -> Array:
	var out: Array = []
	if modelo.reforco_disponivel():
		out.append(ESPECIAL_REFORCO)
	if modelo.modo_eco() != "":
		out.append(ESPECIAL_ECO)
	out.append_array(modelo.lista(filtro))
	return out

func _montar_lista() -> void:
	var tinha_foco := false
	var foco := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for b in botoes_lista:
		if b == foco:
			tinha_foco = true
	for ch in lista_box.get_children():
		lista_box.remove_child(ch)
		ch.queue_free()
	botoes_lista.clear()
	var ents := entradas()
	if not selecionado in ents:
		selecionado = ents[0] if ents.size() > 0 else ""
	var grupo_atual := ""
	for id in ents:
		var g_nome := "Missão" if String(id).begins_with("@") else String(modelo.grupo(id))
		if g_nome != grupo_atual:
			grupo_atual = g_nome
			var h := _label(g_nome.to_upper(), 16, COR_TITULO)
			lista_box.add_child(h)
		var b := Button.new()
		b.name = "Item_" + String(id).replace("@", "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 46)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 32)
		var sit := "pode"
		if id == ESPECIAL_REFORCO:
			b.text = "» Têmpera em cinza"
			b.icon = modelo.icone("espada_cobre")
		elif id == ESPECIAL_ECO:
			b.text = "» Eco: rápido ou pesado"
			b.icon = modelo.icone("cristal_celeste")
		else:
			var r: Dictionary = modelo.forja.receitas[id]
			var res := String(r.resultado)
			sit = String(modelo.situacao(id))
			var q := int(r.get("quantidade", 1))
			b.text = modelo.nome(res) + ((" ×%d" % q) if q > 1 else "") + "   " + {"pode": "", "falta": "· falta", "travado": "· travado"}[sit]
			b.icon = modelo.icone(res)
			var info: Dictionary = modelo.icone_info(res)
			b.add_theme_color_override("icon_normal_color", info.cor)
			b.add_theme_color_override("icon_focus_color", info.cor)
			b.add_theme_color_override("icon_hover_color", info.cor)
		if sit == "falta":
			b.add_theme_color_override("font_color", COR_FALTA)
		elif sit == "travado":
			b.add_theme_color_override("font_color", COR_TRAVADO)
		b.focus_entered.connect(_selecionar.bind(id))
		b.mouse_entered.connect(_selecionar.bind(id))
		b.pressed.connect(_ir_para_acoes)
		b.set_meta("entrada", id)
		lista_box.add_child(b)
		botoes_lista.append(b)
	for b in botoes_lista:
		b.focus_neighbor_right = b.get_path_to(btn_forjar)
	if botoes_lista.size() > 0:
		botoes_lista[0].focus_neighbor_top = botoes_lista[0].get_path_to(botoes_lista[botoes_lista.size() - 1])
		botoes_lista[botoes_lista.size() - 1].focus_neighbor_bottom = botoes_lista[botoes_lista.size() - 1].get_path_to(botoes_lista[0])
	if tinha_foco:
		_focar_lista()

func _botao_de(id: String) -> Button:
	for b in botoes_lista:
		if String(b.get_meta("entrada")) == id:
			return b
	return null

func _focar_lista() -> void:
	var b := _botao_de(selecionado)
	if b == null and botoes_lista.size() > 0:
		b = botoes_lista[0]
	if b != null and is_inside_tree():
		b.grab_focus()

func _selecionar(id: String) -> void:
	if id == selecionado:
		return
	selecionado = id
	_avisar("")
	_mostrar(id)

func _ir_para_acoes() -> void:
	if selecionado == ESPECIAL_ECO and botoes_eco.size() > 0:
		botoes_eco[0].grab_focus()
	elif not btn_forjar.disabled:
		btn_forjar.grab_focus()
	elif not btn_equipar.disabled:
		btn_equipar.grab_focus()
	elif not btn_testar.disabled:
		btn_testar.grab_focus()

# ------------------------------------------------------------------ detalhe
func _limpar_detalhe() -> void:
	for ch in detalhe_box.get_children():
		detalhe_box.remove_child(ch)
		ch.queue_free()
	botoes_eco.clear()

func _cabecalho_item(icone_id: String, titulo: String, sub: String, desc: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	detalhe_box.add_child(h)
	var moldura := PanelContainer.new()
	moldura.add_theme_stylebox_override("panel", _estilo(Color("3b2a1d"), COR_BORDA_ESCURA, 4, 6))
	h.add_child(moldura)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(96, 96)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = modelo.icone(icone_id)
	tr.modulate = modelo.icone_info(icone_id).cor
	moldura.add_child(tr)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(_label(titulo, 32, COR_NOME))
	if sub != "":
		tv.add_child(_label(sub, 18, COR_TITULO))
	if desc != "":
		var d := _label(desc, 20)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tv.add_child(d)

func _secao(t: String) -> void:
	var l := _label(t, 18, COR_TITULO)
	detalhe_box.add_child(l)
	var linha := ColorRect.new()
	linha.color = COR_BORDA_ESCURA
	linha.custom_minimum_size = Vector2(0, 2)
	detalhe_box.add_child(linha)

static func fmt(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.2f" % v).rstrip("0").replace(".", ",")

static func fmt_delta(d: float) -> String:
	if is_zero_approx(d):
		return "="
	return ("+" if d > 0 else "−") + fmt(absf(d))

func _linhas_comparacao(linhas: Array) -> void:
	var gr := GridContainer.new()
	gr.columns = 4
	gr.add_theme_constant_override("h_separation", 28)
	detalhe_box.add_child(gr)
	for ln in linhas:
		gr.add_child(_label(String(ln.nome), 22, COR_TITULO))
		gr.add_child(_label(fmt(float(ln.atual)), 22))
		gr.add_child(_label("»  " + fmt(float(ln.novo)), 22))
		var cor := COR_BOM if bool(ln.melhor) else (COR_RUIM if bool(ln.pior) else COR_TITULO)
		var d := _label(fmt_delta(float(ln.delta)), 22, cor)
		d.name = "Delta_" + String(ln.stat)
		gr.add_child(d)

func _mostrar(id: String) -> void:
	if modelo == null or detalhe_box == null:
		return
	_limpar_detalhe()
	btn_forjar.visible = true
	btn_equipar.visible = true
	btn_testar.visible = true
	if id == "":
		_cabecalho_item("carvao", "Nada aqui", "", "Troque o filtro (Q/E) para ver outras receitas.")
		btn_forjar.disabled = true; btn_equipar.disabled = true; btn_testar.disabled = true
		return
	if id == ESPECIAL_REFORCO:
		_mostrar_reforco()
		return
	if id == ESPECIAL_ECO:
		_mostrar_eco()
		return
	var d: Dictionary = modelo.detalhe(id)
	var sub := "%s  ·  %s" % [String(d.grupo).trim_suffix("s") if d.grupo != "Fundição" else "Fundição", {"pode": "dá para forjar agora", "falta": "falta material", "travado": "travado"}[d.situacao]]
	_cabecalho_item(String(d.resultado), String(d.nome) + ((" ×%d" % int(d.quantidade)) if int(d.quantidade) > 1 else ""), sub, String(d.descricao))
	if d.situacao == "travado":
		var lt := _label("Travado: " + String(d.motivo), 22, COR_TRAVADO)
		lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detalhe_box.add_child(lt)
	_secao("MATERIAIS  (livre / precisa)")
	for m in d.materiais:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		detalhe_box.add_child(h)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(32, 32)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = modelo.icone(String(m.id)) if String(m.id) != "ouro" else null
		tr.modulate = modelo.icone_info(String(m.id)).cor
		h.add_child(tr)
		var nl := _label(String(m.nome), 22)
		nl.custom_minimum_size = Vector2(250, 0)
		h.add_child(nl)
		var q := _label("%d / %d" % [int(m.livre), int(m.precisa)], 22, COR_BOM if m.ok else COR_RUIM)
		q.custom_minimum_size = Vector2(110, 0)
		h.add_child(q)
		if int(m.reservado) > 0:
			h.add_child(_label("(%d reservado)" % int(m.reservado), 18, COR_TITULO))
		if not m.ok:
			var o := _label("» " + String(m.origem), 18, COR_FALTA)
			o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			o.name = "Origem_" + String(m.id)
			detalhe_box.add_child(o)
	var cmp: Dictionary = d.comparacao
	if not cmp.linhas.is_empty():
		_secao("COMPARADO COM O EQUIPADO (%s)" % String(cmp.equipado_nome).to_upper())
		_linhas_comparacao(cmp.linhas)
	btn_forjar.text = "Forjar" if d.situacao == "pode" else ("Falta material" if d.situacao == "falta" else "Travado")
	btn_forjar.disabled = d.situacao != "pode"
	btn_equipar.disabled = not (bool(d.equipavel) and modelo.possui(String(d.resultado)) and modelo.equipado.get(String(d.slot), "") != String(d.resultado))
	btn_equipar.text = "Equipado" if modelo.equipado.get(String(d.slot), "") == String(d.resultado) else "Equipar  [X]"
	btn_testar.disabled = not bool(d.testavel)

func _mostrar_reforco() -> void:
	var info: Dictionary = modelo.reforco_info()
	_cabecalho_item("espada_cobre", "Têmpera em cinza", "Missão: Atrasada desde amanhã  ·  grátis", String(info.texto))
	var l := _label("O golpe pesado (3º do combo) passa a deixar um ECO: o tempo repete o golpe no mesmo lugar um instante depois.", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalhe_box.add_child(l)
	_secao("%s  »  %s" % [modelo.nome(String(info.de)).to_upper(), modelo.nome(String(info.para)).to_upper()])
	_linhas_comparacao(info.comparacao)
	btn_forjar.text = "Temperar"
	btn_forjar.disabled = false
	btn_equipar.text = "Equipar  [X]"
	btn_equipar.disabled = true
	btn_testar.disabled = true

func _mostrar_eco() -> void:
	var modo: String = modelo.modo_eco()
	_cabecalho_item("cristal_celeste", "Eco temporal", ("Escolha da missão" if modo == "missao" else "Variações liberadas") + "  ·  paga com o excedente (o cobre reservado não entra)", "")
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	detalhe_box.add_child(cards)
	var ops: Array = modelo.eco_opcoes()
	for op in ops:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _estilo(Color("2a1f17"), COR_BORDA if op.atual else COR_BORDA_ESCURA, 3, 12))
		cards.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		v.add_child(_label(String(op.nome) + ("  (atual)" if op.atual else ""), 26, COR_NOME))
		var ds := _label(String(op.descricao), 16)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ds)
		if String(op.extra) != "":
			var ex := _label("+ " + String(op.extra), 16, COR_BOM)
			ex.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(ex)
		v.add_child(_label("comparado ao eco base", 16, COR_TITULO))
		var gr := GridContainer.new()
		gr.columns = 3
		gr.add_theme_constant_override("h_separation", 18)
		v.add_child(gr)
		for ln in op.comparacao:
			gr.add_child(_label(String(ln.nome), 18, COR_TITULO))
			var val := fmt(float(ln.novo)) if ln.stat != "dano_relativo" else "%d%%" % roundi(float(ln.novo) * 100)
			gr.add_child(_label(val, 18))
			var dl := fmt_delta(float(ln.delta)) if ln.stat != "dano_relativo" else ("=" if is_zero_approx(float(ln.delta)) else ("%+d%%" % roundi(float(ln.delta) * 100)))
			gr.add_child(_label(dl, 18, COR_BOM if ln.melhor else (COR_RUIM if ln.pior else COR_TITULO)))
		var custo_txt: Array = []
		for k in op.custo:
			custo_txt.append("%d %s (livre %d)" % [int(op.custo[k]), modelo.nome(String(k)), modelo.livre(String(k))])
		var ct := _label(("Já é sua" if op.comprada else "Custo: " + ", ".join(custo_txt)), 16, COR_TEXTO if op.pode_pagar else COR_FALTA)
		ct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(ct)
		if op.fiado:
			var fl := _label("Sem excedente: o Gaspar anota no fiado. A missão não trava.", 16, COR_FALTA)
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(fl)
		var b := Button.new()
		b.name = "Escolher_" + String(op.id)
		b.text = "Usar" if op.comprada and modo == "livre" else ("Escolher (fiado)" if op.fiado else "Escolher")
		b.disabled = bool(op.atual) or (not op.pode_pagar and not op.fiado)
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(_acao_eco.bind(String(op.id)))
		v.add_child(b)
		botoes_eco.append(b)
	for i in botoes_eco.size():
		var b: Button = botoes_eco[i]
		var sel := _botao_de(ESPECIAL_ECO)
		if sel != null:
			b.focus_neighbor_left = b.get_path_to(botoes_eco[i - 1]) if i > 0 else b.get_path_to(sel)
		b.focus_neighbor_right = b.get_path_to(botoes_eco[i + 1]) if i + 1 < botoes_eco.size() else b.get_path_to(btn_testar)
	btn_forjar.visible = false
	btn_equipar.visible = false
	btn_testar.disabled = String(modelo.g.variacao_eco) == ""
	btn_testar.focus_neighbor_right = btn_testar.get_path_to(botoes_eco[0]) if botoes_eco.size() > 0 else NodePath("")

# ------------------------------------------------------------------ ações
func _acao_forjar() -> void:
	if selecionado == ESPECIAL_REFORCO:
		if modelo.fazer_reforco():
			_avisar("Facão temperado em cinza! O eco está liberado. Teste no poste de treino.")
			selecionado = ""
			_atualizar_tudo()
			_focar_lista()
		return
	var r: Dictionary = modelo.forjar(selecionado)
	if r.ok:
		_avisar("Forjado: %s%s" % [modelo.nome(String(r.resultado)), (" ×%d" % int(r.quantidade)) if int(r.quantidade) > 1 else ""])
	else:
		_avisar(String(r.motivo), true)
	if btn_forjar.disabled or not btn_forjar.visible:
		_focar_lista()

func _acao_equipar() -> void:
	if selecionado.begins_with("@") or selecionado == "":
		return
	var d: Dictionary = modelo.detalhe(selecionado)
	if modelo.equipar(String(d.resultado)):
		_avisar("Equipado: " + String(d.nome))
		_focar_lista()

func _acao_testar() -> void:
	var item := String(modelo.equipado.get("arma", ""))
	if selecionado != "" and not selecionado.begins_with("@"):
		var d: Dictionary = modelo.detalhe(selecionado)
		if bool(d.testavel):
			item = String(d.resultado)
	testar_na_arena.emit(item, String(modelo.g.variacao_eco))
	_avisar("Indo para a Arena das Cinzas...")

func _acao_eco(vid: String) -> void:
	var r: Dictionary = modelo.escolher_eco(vid)
	if r.ok:
		_avisar(("%s escolhido. " % modelo.nome_variacao(vid)) + ("Pago com o excedente." if r.pago else "Anotado no fiado do Gaspar."))
		_focar_lista()
	else:
		_avisar(String(r.motivo), true)

func _avisar(t: String, erro := false) -> void:
	lbl_aviso.text = t
	lbl_aviso.visible = t != ""
	lbl_aviso.add_theme_color_override("font_color", COR_RUIM if erro else COR_NOME)
	lbl_aviso.modulate.a = 1.0
	if is_inside_tree() and t != "":
		var tw := create_tween()
		tw.tween_interval(2.6)
		tw.tween_property(lbl_aviso, "modulate:a", 0.0, 0.6)

func _mudar_filtro(f: String) -> void:
	filtro = f
	selecionado = ""
	_atualizar_tudo()
	_focar_lista()

func ciclar_filtro(passo: int) -> void:
	var i := Modelo.FILTROS.find(filtro)
	_mudar_filtro(Modelo.FILTROS[posmod(i + passo, Modelo.FILTROS.size())])

# ------------------------------------------------------------------ entrada
func _unhandled_input(event: InputEvent) -> void:
	if not visible or modelo == null:
		return
	if processar_entrada(event):
		get_viewport().set_input_as_handled()

## Atalhos (também usado pelos testes). Setas e Enter ficam com a navegação de foco do Godot.
func processar_entrada(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q: ciclar_filtro(-1); return true
			KEY_E: ciclar_filtro(1); return true
			KEY_X: _acao_equipar(); return true
			KEY_T: _acao_testar(); return true
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER: ciclar_filtro(-1); return true
			JOY_BUTTON_RIGHT_SHOULDER: ciclar_filtro(1); return true
			JOY_BUTTON_X: _acao_equipar(); return true
			JOY_BUTTON_Y: _acao_testar(); return true
	if event.is_action_pressed("ui_cancel"):
		var foco := get_viewport().gui_get_focus_owner()
		if foco != null and not foco in botoes_lista:
			_focar_lista()      # B/Esc nas ações volta para a lista; na lista fecha
		else:
			fechar()
		return true
	return false

# ------------------------------------------------------------------ demonstração (cena sozinha)
func _gerenciador_demo():
	var est = Estado.new()
	var g = Gerenciador.new(est)
	_gerenciador_proprio = g
	add_child(g)
	est.marcar("tutorial_pulado")
	var demo := {"ouro": 180, "minerio_cobre": 8, "carvao": 3, "lingote_cobre": 4, "madeira": 6, "couro": 1, "lasca_de_eco": 3}
	for k in demo:
		g.adicionar_item(k, int(demo[k]))
	return g
