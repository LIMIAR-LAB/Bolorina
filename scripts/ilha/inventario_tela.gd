extends CanvasLayer
## Inventario da Vale (I / B / Select do controle): abas por categoria + aba Equipamento (a tela do Codex,
## embutida por scripts/ilha/equipamento_aba.gd) + aba Fabricar (bau de madeira). Tambem e a tela do BAU
## (E perto de um bau): grade de 36 espacos em cima, mochila embaixo.
## Pausa o jogo enquanto aberta (PROCESS_MODE_ALWAYS). Fonte unica: o save (scripts/ilha/inventario.gd).
## Teclado: setas/WASD escolhem | Tab/Shift+Tab ou PgDn/PgUp trocam de aba (no bau: troca bau <-> mochila) |
## Enter/F/Espaco: acao (no bau: move 1; Shift: a pilha toda) | R: ordenar | G (bau): guardar iguais |
## C (Fabricar): fabricar | I/B/Esc: fechar.  Mouse: clique escolhe; no bau clique move 1, Shift+clique a pilha,
## botao direito a metade. Controle: direcional, A acao, X pilha, Y ordenar, LB/RB abas, B/Select fecha.
const UI = preload("res://scripts/ui/tema_vilarejo.gd")
const Inv = preload("res://scripts/ilha/inventario.gd")
const EquipAba = preload("res://scripts/ilha/equipamento_aba.gd")
const COLS := 10
const COLS_BAU := 9
const CEL := 76
const GAP := 8
const BEGE := Color("f1e2bd")
const ESCURO := Color("3a2412")
const MUITO := 1 << 30
var g        # gerenciador (jogo_ilha.gd) ou qualquer no com .estado
var estado
var aberto := false
var modo := "inventario"   # ou "bau"
## ultima aba usada; a 1a abertura com I cai em Equipamento (I sempre abriu o equipamento)
var aba := "equipamento"
var ordem := "categoria"
var sel := 0
var itens_vis: Array = []
var equip  # equipamento_aba.gd
var raiz: Control
var titulo: Label
var ouro_label: Label
var botoes_aba := {}
var conteudo_itens: Control
var rolagem: ScrollContainer
var grade: GridContainer
var celulas: Array = []
var vazio_label: Label
var conteudo_fab: Control
var fab_linhas: Array = []
var fab_botao_colocar: Button
var conteudo_equip: Control
var info: Panel
var info_icone: TextureRect
var info_nome: Label
var info_cat: Label
var info_qtd: Label
var info_desc: Label
var info_acao: Label
var botao_ordem: Button
var botao_acao: Button
var resumo: Label
var dica: Label
var msg: Label
# ---- bau
var raiz_bau: Control
var bau: Dictionary = {}
var bau_mundo  # baus_mundo.gd
var painel := 1   # 0 = bau, 1 = mochila
var sel_bau := 0
var sel_moc := 0
var moc_vis: Array = []
var bau_titulo: Label
var bau_cels: Array = []
var moc_rolagem: ScrollContainer
var moc_grade: GridContainer
var moc_cels: Array = []
var b_info_icone: TextureRect
var b_info_nome: Label
var b_info_qtd: Label
var b_info_desc: Label
var b_recolher: Button
var b_msg: Label
var selo: Panel

func montar(gerenciador, est = null) -> void:
	g = gerenciador
	estado = est if est != null else g.estado
	layer = 72
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TelaInventario"
	_selo()
	_construir()
	_construir_bau()
	raiz.visible = false
	raiz_bau.visible = false
	# a tela de equipamento do Codex, embutida na aba (mesma API: jogo_ilha.equip_tela = equip)
	equip = EquipAba.new()
	equip.inventario = self
	add_child(equip)
	equip.montar(g, estado)
	equip.embutir(conteudo_equip)

# ---------------------------------------------------------------- estilo
func _estilo(bg: Color, borda: Color, w: int, r := 4) -> StyleBox:
	if bg.r > 0.45:
		return UI.caixa("slot_selecionado" if borda.r > 0.9 else "slot", 6)
	return UI.caixa("moldura" if w >= 4 else "painel", 12)

func _rotulo(pai: Control, pos: Vector2, tam: int, cor := BEGE, texto := "") -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_override("font", UI.fonte())
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l

func _botao(pai: Control, pos: Vector2, tam: Vector2, texto: String, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = tam
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.theme = UI.tema()
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", UI.caixa("botao_ativo", 8))
	b.add_theme_color_override("font_color", ESCURO)
	b.pressed.connect(cb)
	pai.add_child(b)
	return b

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

func _titulo_fonte(l: Label) -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia"])
	l.add_theme_font_override("font", f)

## selo fixo no HUD (no lugar do "I Equipamento")
func _selo() -> void:
	selo = Panel.new()
	selo.name = "SeloInventario"
	selo.position = Vector2(1600 - 254, 900 - 63 - 40)
	selo.size = Vector2(240, 32)
	selo.add_theme_stylebox_override("panel", _estilo(Color(0.16, 0.1, 0.06, 0.85), Color("6b4a2a"), 2))
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selo)
	var x := 6
	for par in [["I", "Inventário"], ["B", "Mochila"]]:
		var k := Panel.new()
		k.position = Vector2(x, 5)
		k.size = Vector2(22, 22)
		k.add_theme_stylebox_override("panel", _estilo(Color("e8cf98"), Color("fff1b8"), 2, 3))
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selo.add_child(k)
		var kl := _rotulo(k, Vector2.ZERO, 14, ESCURO, String(par[0]))
		kl.size = Vector2(22, 22)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kl.add_theme_constant_override("shadow_offset_x", 0)
		kl.add_theme_constant_override("shadow_offset_y", 0)
		_rotulo(selo, Vector2(x + 28, 6), 14, BEGE, String(par[1]))
		x += 120

# ---------------------------------------------------------------- construcao (inventario)
func _moldura(pai: Control, titulo_txt: String) -> Label:
	pai.theme = UI.tema()
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.aplicar_fundo(fundo)
	pai.add_child(fundo)
	var pn := Panel.new()
	pn.position = Vector2(86, 110)
	pn.size = Vector2(1428, 700)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.add_theme_stylebox_override("panel", UI.caixa("moldura"))
	pai.add_child(pn)
	var rodape := Panel.new()
	rodape.position=Vector2(108,820)
	rodape.size=Vector2(1384,68)
	rodape.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rodape.add_theme_stylebox_override("panel",UI.caixa("painel",10))
	pai.add_child(rodape)
	var banner := UI.cabecalho(pai, titulo_txt, Vector2(104, 62), Vector2(544, 76), UI.textura("mochila.svg"))
	return banner.get_child(banner.get_child_count()-1) as Label

func _construir() -> void:
	raiz = Control.new()
	raiz.name = "Inventario"
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz)
	titulo = _moldura(raiz, "INVENTÁRIO DA VALE")
	var bolsa := Panel.new()
	bolsa.name="PlacaOuro"
	bolsa.position=Vector2(1250,70)
	bolsa.size=Vector2(236,62)
	bolsa.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bolsa.add_theme_stylebox_override("panel",UI.caixa("madeira",10))
	raiz.add_child(bolsa)
	ouro_label = _rotulo(raiz, Vector2(1084, 82), 20, Color("ffd76a"))
	ouro_label.size = Vector2(390, 34)
	ouro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var x := 120.0
	for a in Inv.ABAS:
		var id := String(a.id)
		var b := Button.new()
		b.name = "Aba_" + id
		b.text = String(a.nome)
		b.position = Vector2(x, 146)
		b.size = Vector2(118, 42)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(ir_aba.bind(id))
		raiz.add_child(b)
		botoes_aba[id] = b
		x += 123.0
	# ---- itens
	conteudo_itens = Control.new()
	conteudo_itens.set_anchors_preset(Control.PRESET_FULL_RECT)
	conteudo_itens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(conteudo_itens)
	var fg := Panel.new()
	fg.position = Vector2(108, 200)
	fg.size = Vector2(878, 586)
	fg.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo_itens.add_child(fg)
	rolagem = ScrollContainer.new()
	rolagem.position = Vector2(126, 220)
	rolagem.size = Vector2(850, 550)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conteudo_itens.add_child(rolagem)
	grade = GridContainer.new()
	grade.columns = COLS
	grade.add_theme_constant_override("h_separation", GAP)
	grade.add_theme_constant_override("v_separation", GAP)
	rolagem.add_child(grade)
	vazio_label = _rotulo(conteudo_itens, Vector2(140, 238), 16, Color("cbb48a"), "")
	# ---- fabricar
	conteudo_fab = Control.new()
	conteudo_fab.set_anchors_preset(Control.PRESET_FULL_RECT)
	conteudo_fab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(conteudo_fab)
	var ff := Panel.new()
	ff.position = Vector2(108, 200)
	ff.size = Vector2(878, 586)
	ff.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	ff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo_fab.add_child(ff)
	_rotulo(conteudo_fab, Vector2(132, 220), 15, Color("cbb48a"), "RECEITAS")
	var y := 260.0
	for rid in Inv.receitas():
		var r: Dictionary = Inv.receitas()[rid]
		var p := Panel.new()
		p.position = Vector2(128, y)
		p.size = Vector2(832, 104)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_entered.connect(_sobre_fab.bind(String(rid)))
		conteudo_fab.add_child(p)
		var ic := _icone_rect(p, Vector2(12, 12), 72)
		ic.texture = Inv.icone(String(r.resultado))
		var nm := _rotulo(p, Vector2(98, 10), 20, Color("f6e7c1"), String(r.nome))
		var ing := _rotulo(p, Vector2(98, 42), 15, BEGE, "")
		ing.size = Vector2(440, 22)
		var st := _rotulo(p, Vector2(98, 66), 13, Color("cbb48a"), "")
		var bf := _botao(p, Vector2(674, 26), Vector2(130, 44), "Fabricar", fabricar.bind(rid))
		fab_linhas.append({"rid": rid, "painel": p, "ing": ing, "status": st, "botao": bf, "nome": nm})
		y += 108.0
	fab_botao_colocar = _botao(conteudo_fab, Vector2(132, y + 8), Vector2(300, 46), "Colocar baú", colocar_bau)
	_rotulo(conteudo_fab, Vector2(132, y + 76), 13, Color("9c8662"),
		"A madeira vem do machado: galhos (+1), tocos (+3) e árvores (3 toras + o toco). O baú só pode ser\ncolocado na fazenda (inclusive dentro de casa). Para recolher, abra o baú vazio e use \"Recolher baú\".")
	# ---- equipamento (a tela do Codex entra aqui em montar())
	conteudo_equip = Control.new()
	conteudo_equip.name = "AbaEquipamento"
	conteudo_equip.set_anchors_preset(Control.PRESET_FULL_RECT)
	conteudo_equip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(conteudo_equip)
	# ---- informacoes (itens e fabricar)
	info = Panel.new()
	info.position = Vector2(1002, 200)
	info.size = Vector2(490, 418)
	info.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(info)
	var moldura_ic := Panel.new()
	moldura_ic.position = Vector2(16, 16)
	moldura_ic.size = Vector2(104, 104)
	moldura_ic.add_theme_stylebox_override("panel", _estilo(Color("c9a46a"), Color("7a5230"), 3))
	moldura_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(moldura_ic)
	info_icone = _icone_rect(moldura_ic, Vector2(4, 4), 96)
	info_nome = _rotulo(info, Vector2(134, 18), 26, Color("f6e7c1"))
	info_nome.size = Vector2(336, 58)
	info_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_cat = _rotulo(info, Vector2(134, 86), 16, Color("cbb48a"))
	info_qtd = _rotulo(info, Vector2(24, 144), 19, BEGE)
	info_qtd.size = Vector2(444, 58)
	info_desc = _rotulo(info, Vector2(24, 218), 18, BEGE)
	info_desc.size = Vector2(440, 130)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_acao = _rotulo(info, Vector2(24, 366), 17, Color("8fd86a"))
	info_acao.size = Vector2(440, 42)
	info_acao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao_ordem = _botao(raiz, Vector2(1002, 634), Vector2(238, 48), "", ciclar_ordem)
	botao_acao = _botao(raiz, Vector2(1254, 634), Vector2(238, 48), "", acao)
	resumo = _rotulo(raiz, Vector2(1008, 704), 16, Color("cbb48a"))
	resumo.size = Vector2(466, 90)
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg = _rotulo(raiz, Vector2(120, 792), 16, Color("ffe08a"))
	msg.size = Vector2(1190, 26)
	dica = _rotulo(raiz, Vector2(130, 834), 14, Color("cbb48a"))
	dica.size = Vector2(1360, 60)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _sobre_fab(rid: String) -> void:
	sel = _idx_fab(rid)
	_atualizar_fab()

func _idx_fab(rid: String) -> int:
	for i in fab_linhas.size():
		if fab_linhas[i].rid == rid:
			return i
	return 0

# ---------------------------------------------------------------- construcao (bau)
func _construir_bau() -> void:
	raiz_bau = Control.new()
	raiz_bau.name = "Bau"
	raiz_bau.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz_bau.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(raiz_bau)
	bau_titulo = _moldura(raiz_bau, "BAÚ")
	var fb := Panel.new()
	fb.position = Vector2(108, 142)
	fb.size = Vector2(804, 354)
	fb.add_theme_stylebox_override("panel", _estilo(Color("3a2616"), Color("a0763c"), 3, 4))
	fb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz_bau.add_child(fb)
	for i in Inv.SLOTS_BAU:
		var c := _celula(raiz_bau, Vector2(130 + (i % COLS_BAU) * (CEL + GAP), 154 + (i / COLS_BAU) * (CEL + GAP)))
		c.gui_input.connect(_clique_bau.bind(0, i))
		c.mouse_entered.connect(_sobre_bau.bind(0, i))
		bau_cels.append(c)
	_rotulo(raiz_bau, Vector2(126, 504), 15, Color("cbb48a"), "MOCHILA DA VALE  (clique: 1 · Shift+clique: a pilha · botão direito: metade)")
	var fm := Panel.new()
	fm.position = Vector2(108, 538)
	fm.size = Vector2(878, 250)
	fm.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	fm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz_bau.add_child(fm)
	moc_rolagem = ScrollContainer.new()
	moc_rolagem.position = Vector2(126, 550)
	moc_rolagem.size = Vector2(850, 224)
	moc_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	raiz_bau.add_child(moc_rolagem)
	moc_grade = GridContainer.new()
	moc_grade.columns = COLS
	moc_grade.add_theme_constant_override("h_separation", GAP)
	moc_grade.add_theme_constant_override("v_separation", GAP)
	moc_rolagem.add_child(moc_grade)
	var bi := Panel.new()
	bi.position = Vector2(1002, 142)
	bi.size = Vector2(490, 396)
	bi.add_theme_stylebox_override("panel", _estilo(Color("2b1c12"), Color("7a5230"), 3, 4))
	bi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz_bau.add_child(bi)
	var mi := Panel.new()
	mi.position = Vector2(16, 16)
	mi.size = Vector2(104, 104)
	mi.add_theme_stylebox_override("panel", _estilo(Color("c9a46a"), Color("7a5230"), 3))
	mi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bi.add_child(mi)
	b_info_icone = _icone_rect(mi, Vector2(4, 4), 96)
	b_info_nome = _rotulo(bi, Vector2(134, 18), 21, Color("f6e7c1"))
	b_info_nome.size = Vector2(296, 56)
	b_info_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_info_qtd = _rotulo(bi, Vector2(16, 134), 16, BEGE)
	b_info_qtd.size = Vector2(410, 74)
	b_info_desc = _rotulo(bi, Vector2(16, 214), 15, BEGE)
	b_info_desc.size = Vector2(408, 150)
	b_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_botao(raiz_bau, Vector2(1002, 558), Vector2(238, 48), "Ordenar baú (R)", ordenar_bau)
	_botao(raiz_bau, Vector2(1254, 558), Vector2(238, 48), "Guardar iguais (G)", guardar_iguais)
	b_recolher = _botao(raiz_bau, Vector2(1002, 620), Vector2(238, 48), "Recolher baú", recolher_bau)
	_botao(raiz_bau, Vector2(1254, 620), Vector2(238, 48), "Fechar (Esc)", fechar)
	b_msg = _rotulo(raiz_bau, Vector2(1010, 690), 16, Color("ffe08a"))
	b_msg.size = Vector2(440, 90)
	b_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bd := _rotulo(raiz_bau, Vector2(130, 834), 14, Color("cbb48a"),
		"Setas/WASD: escolher  ·  Tab: baú ↔ mochila  ·  Enter/F/Espaço: mover 1  ·  Shift+Enter: mover a pilha  ·  R: ordenar  ·  G: guardar iguais  ·  E/Esc/I: fechar\nControle: direcional, A move 1, X a pilha, Y ordena, LB/RB troca baú ↔ mochila, B fecha.")
	bd.size = Vector2(1360, 60)

func _celula(pai: Control, pos = null) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(CEL, CEL)
	p.size = Vector2(CEL, CEL)
	if pos != null:
		p.position = pos
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	pai.add_child(p)
	var ic := _icone_rect(p, Vector2(8, 6), 60)
	ic.name = "Icone"
	var q := _rotulo(p, Vector2(4, 51), 20, Color.WHITE)
	q.name = "Qtd"
	q.add_theme_font_override("font",UI.fonte(true))
	q.add_theme_color_override("font_outline_color",Color("211a17"))
	q.add_theme_constant_override("outline_size",3)
	q.size = Vector2(66, 24)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return p

func _pintar(c: Panel, id: String, q: int, escolhida: bool, apagada := false, mostrar_q := true) -> void:
	(c.get_node("Icone") as TextureRect).texture = Inv.icone(id) if id != "" else null
	(c.get_node("Icone") as TextureRect).modulate = Color(1, 1, 1, 0.45) if apagada else Color.WHITE
	(c.get_node("Qtd") as Label).text = str(q) if id != "" and (q > 1 or (mostrar_q and q > 0)) else ""
	var bg := Color("e8cf98") if escolhida else (Color("8f7350") if apagada else Color("c9a46a"))
	if id == "" and not escolhida:
		bg = Color("6b5238")
	c.add_theme_stylebox_override("panel", UI.caixa("slot_selecionado" if escolhida else ("vazio" if id == "" else "slot"), 4))
	c.tooltip_text = "%s ×%d\n%s\nValor: %d ouro" % [Inv.nome(id), q, Inv.desc(id), Inv.preco(id)] if id != "" else ""

# ---------------------------------------------------------------- abrir / fechar
func abrir(aba_ini := "") -> void:
	if aberto:
		return
	if aba_ini != "":
		aba = aba_ini
	aberto = true
	modo = "inventario"
	raiz.visible = true
	raiz_bau.visible = false
	msg.text = ""
	get_tree().paused = true
	_mostrar_aba(true)

func fechar() -> void:
	if not aberto:
		return
	aberto = false
	if equip and equip.aberta:
		equip.fechar()
	raiz.visible = false
	raiz_bau.visible = false
	if modo == "bau" and bau_mundo and is_instance_valid(bau_mundo) and bau_mundo.has_method("fechou"):
		bau_mundo.fechou(bau)
	modo = "inventario"
	if estado.has_method("salvar"):
		estado.salvar()
	get_tree().paused = false
	_hud()

func alternar(aba_ini := "") -> void:
	if aberto:
		fechar()
	else:
		abrir(aba_ini)

func _hud() -> void:
	var a = g.get("atual") if g else null
	if a and a.get("ui") != null and a.ui.has_method("atualizar"):
		a.ui.atualizar()

func ir_aba(id: String) -> void:
	if not aberto or modo != "inventario":
		return
	if id == aba:
		return
	aba = id
	sel = 0
	_mostrar_aba(false)

func _mostrar_aba(_inicio: bool) -> void:
	for id in botoes_aba:
		var b: Button = botoes_aba[id]
		var ativa: bool = id == aba
		b.add_theme_stylebox_override("normal", UI.caixa("botao_ativo" if ativa else "botao", 8))
		b.add_theme_stylebox_override("hover", _estilo(Color("f2dcaa"), Color("fff1b8"), 2, 4))
		b.add_theme_color_override("font_color", ESCURO if ativa else BEGE)
		b.add_theme_color_override("font_hover_color", ESCURO)
	var eh_equip := aba == "equipamento"
	var eh_fab := aba == "fabricar"
	conteudo_equip.visible = eh_equip
	conteudo_itens.visible = not eh_equip and not eh_fab
	conteudo_fab.visible = eh_fab
	info.visible = not eh_equip
	botao_ordem.visible = not eh_equip and not eh_fab
	botao_acao.visible = not eh_equip
	resumo.visible = not eh_equip
	titulo.visible = true
	titulo.text="INVENTÁRIO · "+String(estado.extras.get("aparencia",{}).get("nome","Vale")).to_upper()
	ouro_label.visible = aba != "equipamento"
	raiz.get_node("PlacaOuro").visible = aba != "equipamento"
	ouro_label.text = "Ouro  %d" % int(estado.ouro)
	if eh_equip:
		if not equip.aberta:
			equip.abrir()
		dica.text = "WASD: escolher · Enter/F: equipar · X: retirar · Q/E: girar · Espaço: animar · Tab: trocar de aba · Esc: fechar"
		msg.position.y = 790
		return
	if equip.aberta:
		equip.fechar()
	dica.text = "Setas/WASD: escolher  ·  Tab/Shift+Tab ou PgDn/PgUp: aba  ·  Enter/F: ação  ·  R: ordenar  ·  %sI/B/Esc: fechar\nControle: direcional, A ação, Y ordena, LB/RB abas, B ou Select fecha.  Mouse: passe por cima para ver; clique para escolher." % ("C: fabricar  ·  " if eh_fab else "")
	if eh_fab:
		_atualizar_fab()
	else:
		_atualizar_itens(true)

# ---------------------------------------------------------------- aba de itens
func _atualizar_itens(reconstruir := false) -> void:
	itens_vis = Inv.lista(estado, aba, ordem)
	sel = clampi(sel, 0, maxi(0, itens_vis.size() - 1))
	if reconstruir or celulas.size() != maxi(60, itens_vis.size()):
		for c in celulas:
			c.queue_free()
		celulas.clear()
		for i in maxi(60, itens_vis.size()):
			var c := _celula(grade)
			c.add_theme_stylebox_override("panel", UI.caixa("vazio",4))
			c.gui_input.connect(_clique_item.bind(i))
			c.mouse_entered.connect(_sobre_item.bind(i))
			celulas.append(c)
	for i in itens_vis.size():
		var e: Dictionary = itens_vis[i]
		_pintar(celulas[i], String(e.id), int(e.q), i == sel, String(e.fonte) == "masmorra")
	vazio_label.text = "" if not itens_vis.is_empty() else "Nada nesta aba ainda."
	botao_ordem.text = "Ordenar: %s (R)" % Inv.NOME_ORDEM[ordem]
	var n := 0
	for e in itens_vis:
		n += int(e.q)
	resumo.text = "%d tipos · %d itens nesta aba.\nBaús: %d (mais o da casa). Itens nos baús ficam fora desta lista.\nPeças de roupa e armadura: aba Equipamento." % [itens_vis.size(), n, _baus_colocados()]
	_info_item()
	if sel < celulas.size():
		_garantir_visivel(rolagem, sel, COLS)

func _baus_colocados() -> int:
	var n := 0
	for b in estado.baus:
		if String(b.id) != Inv.ID_CASA:
			n += 1
	return n

func _garantir_visivel(sc: ScrollContainer, i: int, cols: int) -> void:
	var y := (i / cols) * (CEL + GAP)
	if y < sc.scroll_vertical:
		sc.scroll_vertical = y
	elif y + CEL > sc.scroll_vertical + int(sc.size.y):
		sc.scroll_vertical = y + CEL - int(sc.size.y)

func _info_item() -> void:
	if itens_vis.is_empty() or sel >= itens_vis.size():
		info_icone.texture = null
		info_nome.text = "—"
		info_cat.text = ""
		info_qtd.text = ""
		info_desc.text = "Junte coisas pela ilha: o machado tira madeira das árvores, a picareta tira pedra, a foice tira fibra."
		info_acao.text = ""
		botao_acao.text = "—"
		botao_acao.disabled = true
		return
	var e: Dictionary = itens_vis[sel]
	var id := String(e.id)
	info_icone.texture = Inv.icone(id)
	info_nome.text = String(e.nome)
	var origem := {"mochila": "na mochila", "barra": "fixa na barra de ferramentas", "equipamento": "roupa/armadura", "masmorra": "saque da masmorra (vai para a mochila ao voltar)"}
	info_cat.text = "%s · %s" % [String(Inv.NOME_CAT.get(String(e.cat), String(e.cat).capitalize())), String(origem.get(String(e.fonte), ""))]
	var p := int(e.preco)
	info_qtd.text = "Quantidade: %d\nValor: %d ouro cada%s" % [int(e.q), p, ("  ·  %d no total" % (p * int(e.q))) if int(e.q) > 1 else ""]
	info_desc.text = String(e.desc) if String(e.desc) != "" else "—"
	botao_acao.disabled = false
	if id == "bau" and String(e.fonte) == "mochila":
		botao_acao.text = "Colocar baú (Enter)"
		info_acao.text = "Enter: colocar o baú na frente da Vale."
	elif String(e.fonte) == "equipamento":
		botao_acao.text = "Ir para Equipamento"
		info_acao.text = "Enter: abrir a aba Equipamento."
	else:
		botao_acao.text = "Fabricar…" if aba == "materiais" else "—"
		botao_acao.disabled = aba != "materiais"
		info_acao.text = "Pode ir para um baú." if bool(e.movivel) else "Não vai para o baú."

func _clique_item(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		sel = i
		if ev.double_click:
			acao()
		else:
			_atualizar_itens()

func _sobre_item(i: int) -> void:
	if sel != i and i < itens_vis.size():
		sel = i
		_atualizar_itens()

func ciclar_ordem() -> void:
	ordem = Inv.ORDENS[(Inv.ORDENS.find(ordem) + 1) % Inv.ORDENS.size()]
	_atualizar_itens(true)

func acao() -> void:
	if aba == "fabricar":
		if sel < fab_linhas.size():
			fabricar(String(fab_linhas[sel].rid))
		else:
			colocar_bau()
		return
	if itens_vis.is_empty() or sel >= itens_vis.size():
		return
	var e: Dictionary = itens_vis[sel]
	if String(e.id) == "bau" and String(e.fonte) == "mochila":
		colocar_bau()
	elif String(e.fonte) == "equipamento":
		ir_aba("equipamento")
	elif aba == "materiais":
		ir_aba("fabricar")

# ---------------------------------------------------------------- fabricar
func _atualizar_fab() -> void:
	sel = clampi(sel, 0, fab_linhas.size())
	for i in fab_linhas.size():
		var L: Dictionary = fab_linhas[i]
		var r: Dictionary = Inv.receitas()[L.rid]
		var partes: Array = []
		for ing in r.ingredientes:
			partes.append("%s %d/%d" % [Inv.nome(String(ing)), int(estado.qtd(String(ing))), int(r.ingredientes[ing])])
		L.ing.text = "Pede: " + ", ".join(partes)
		var motivo := Inv.pode_fabricar(estado, String(L.rid))
		L.status.text = "Pronto para fabricar (C / Enter)." if motivo == "" else motivo
		L.status.add_theme_color_override("font_color", Color("8fd86a") if motivo == "" else Color("e58a6a"))
		L.botao.disabled = motivo != ""
		var esc: bool = i == sel
		L.painel.add_theme_stylebox_override("panel", _estilo(Color("4a3220") if esc else Color("3a2616"), Color("fff1b8") if esc else Color("7a5230"), 3 if esc else 2))
	var nb := int(estado.qtd("bau"))
	fab_botao_colocar.text = "Colocar baú (%d na mochila)" % nb
	fab_botao_colocar.disabled = nb <= 0
	fab_botao_colocar.add_theme_stylebox_override("normal", _estilo(Color("e8cf98") if sel == fab_linhas.size() else Color("c9a46a"), Color("fff1b8") if sel == fab_linhas.size() else Color("7a5230"), 3 if sel == fab_linhas.size() else 2))
	botao_acao.disabled = false
	if sel < fab_linhas.size():
		var rid := String(fab_linhas[sel].rid)
		var r2: Dictionary = Inv.receitas()[rid]
		var res := String(r2.resultado)
		info_icone.texture = Inv.icone(res)
		info_nome.text = String(r2.nome)
		info_cat.text = "Receita · %s" % String(Inv.NOME_CAT.get(Inv.categoria(res), ""))
		info_qtd.text = "Na mochila: %d\nValor: %d ouro" % [int(estado.qtd(res)), Inv.preco(res)]
		info_desc.text = String(r2.get("desc", ""))
		var m := Inv.pode_fabricar(estado, rid)
		info_acao.text = "Enter/C: fabricar." if m == "" else m
		info_acao.add_theme_color_override("font_color", Color("8fd86a") if m == "" else Color("e58a6a"))
		botao_acao.text = "Fabricar (C)"
		botao_acao.disabled = m != ""
	else:
		info_icone.texture = Inv.icone("bau")
		info_nome.text = "Colocar baú"
		info_cat.text = "Na fazenda ou dentro de casa"
		info_qtd.text = "Baús na mochila: %d" % nb
		info_desc.text = "O inventário fecha e aparece o baú-fantasma na frente da Vale. Verde: pode colocar. Clique, E, J ou Enter coloca; Esc ou botão direito cancela."
		info_acao.text = ""
		botao_acao.text = "Colocar baú"
		botao_acao.disabled = nb <= 0
	resumo.text = "Madeira na mochila: %d · Baús colocados: %d" % [int(estado.qtd("madeira")), _baus_colocados()]

func fabricar(rid: String) -> void:
	var antes := Inv.pode_fabricar(estado, rid)
	var r := Inv.fabricar(estado, rid)
	if antes == "" and estado.has_method("salvar"):
		estado.salvar()
	msg.text = r
	ouro_label.visible = aba != "equipamento"
	raiz.get_node("PlacaOuro").visible = aba != "equipamento"
	ouro_label.text = "Ouro  %d" % int(estado.ouro)
	if aba == "fabricar":
		_atualizar_fab()
	else:
		_atualizar_itens(true)

## fecha o inventario e entra no modo de colocar (scripts/ilha/baus_mundo.gd)
func colocar_bau() -> void:
	if int(estado.qtd("bau")) <= 0:
		msg.text = "Fabrique um baú primeiro (aba Fabricar)."
		return
	var bm = g.get("baus_mundo") if g else null
	if bm == null or not is_instance_valid(bm):
		msg.text = "Baús só podem ser colocados na fazenda (ou dentro da casa da Vale)."
		return
	fechar()
	bm.iniciar_colocacao()

# ---------------------------------------------------------------- bau
func abrir_bau(b: Dictionary, mundo = null) -> void:
	if aberto or b.is_empty():
		return
	bau = b
	bau_mundo = mundo
	aberto = true
	modo = "bau"
	raiz.visible = false
	raiz_bau.visible = true
	b_msg.text = ""
	painel = 1 if not _moc_lista().is_empty() else 0
	sel_bau = 0
	sel_moc = 0
	get_tree().paused = true
	_atualizar_bau(true)

func _moc_lista() -> Array:
	var out: Array = []
	for e in Inv.lista(estado, "tudo", "categoria"):
		if bool(e.movivel):
			out.append(e)
	return out

func _atualizar_bau(reconstruir := false) -> void:
	if bau.is_empty():
		return
	moc_vis = _moc_lista()
	sel_moc = clampi(sel_moc, 0, maxi(0, moc_vis.size() - 1))
	if painel == 1 and moc_vis.is_empty():
		painel = 0
	bau_titulo.text = "%s · %d/%d livres" % [Inv.nome_bau(bau).to_upper(), Inv.livres(bau), Inv.SLOTS_BAU]
	bau_titulo.add_theme_font_size_override("font_size",22)
	for i in bau_cels.size():
		var s = bau.slots[i]
		var tem: bool = s is Dictionary and not s.is_empty()
		_pintar(bau_cels[i], String(s.id) if tem else "", int(s.q) if tem else 0, painel == 0 and i == sel_bau)
	if reconstruir or moc_cels.size() != moc_vis.size():
		for c in moc_cels:
			c.queue_free()
		moc_cels.clear()
		for i in moc_vis.size():
			var c := _celula(moc_grade)
			c.gui_input.connect(_clique_bau.bind(1, i))
			c.mouse_entered.connect(_sobre_bau.bind(1, i))
			moc_cels.append(c)
	for i in moc_vis.size():
		_pintar(moc_cels[i], String(moc_vis[i].id), int(moc_vis[i].q), painel == 1 and i == sel_moc)
	if painel == 1 and sel_moc < moc_cels.size():
		_garantir_visivel(moc_rolagem, sel_moc, COLS)
	var fixo := bool(bau.get("fixo", false))
	b_recolher.disabled = fixo or not Inv.vazio(bau)
	b_recolher.tooltip_text = "O baú da casa fica onde está." if fixo else ("Esvazie o baú para recolher." if not Inv.vazio(bau) else "Volta 1 baú para a mochila.")
	_info_bau()

func _info_bau() -> void:
	var id := ""
	var q := 0
	var onde := ""
	if painel == 0:
		var s = bau.slots[sel_bau]
		if s is Dictionary and not s.is_empty():
			id = String(s.id)
			q = int(s.q)
		onde = "No baú (espaço %d)" % (sel_bau + 1)
	elif sel_moc < moc_vis.size():
		id = String(moc_vis[sel_moc].id)
		q = int(moc_vis[sel_moc].q)
		onde = "Na mochila"
	if id == "":
		b_info_icone.texture = null
		b_info_nome.text = "Espaço vazio" if painel == 0 else "Mochila vazia"
		b_info_qtd.text = onde
		b_info_desc.text = "Escolha um item da mochila e aperte Enter (ou clique) para guardar."
		return
	b_info_icone.texture = Inv.icone(id)
	b_info_nome.text = Inv.nome(id)
	b_info_qtd.text = "%s: %d\nValor: %d ouro cada\nNo baú: %d · Na mochila: %d" % [onde, q, Inv.preco(id), Inv.qtd_bau(bau, id), int(estado.qtd(id))]
	b_info_desc.text = Inv.desc(id) if Inv.desc(id) != "" else String(Inv.NOME_CAT.get(Inv.categoria(id), ""))

## n: 1, MUITO (pilha) ou -1 (metade)
func mover(de_painel: int, i: int, n := 1) -> int:
	if bau.is_empty():
		return 0
	var foi := 0
	if de_painel == 0:
		var s = bau.slots[i] if i < bau.slots.size() else {}
		if not (s is Dictionary) or s.is_empty():
			return 0
		var k: int = int(ceil(int(s.q) / 2.0)) if n < 0 else n
		var id := String(s.id)
		foi = Inv.retirar(estado, bau, i, k)
		b_msg.text = "Retirou %d %s." % [foi, Inv.nome(id)]
	else:
		if i >= moc_vis.size():
			return 0
		var id := String(moc_vis[i].id)
		var k2: int = int(ceil(int(estado.qtd(id)) / 2.0)) if n < 0 else n
		foi = Inv.guardar(estado, bau, id, k2)
		b_msg.text = ("Guardou %d %s." % [foi, Inv.nome(id)]) if foi > 0 else "Baú cheio: não cabe %s." % Inv.nome(id)
	if foi > 0 and estado.has_method("salvar"):
		estado.salvar()
	_atualizar_bau()
	return foi

func _clique_bau(ev: InputEvent, p: int, i: int) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	painel = p
	if p == 0:
		sel_bau = i
	else:
		sel_moc = i
	if ev.button_index == MOUSE_BUTTON_LEFT:
		mover(p, i, MUITO if ev.shift_pressed else 1)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		mover(p, i, -1)

func _sobre_bau(p: int, i: int) -> void:
	if p == 1 and i >= moc_vis.size():
		return
	painel = p
	if p == 0:
		sel_bau = i
	else:
		sel_moc = i
	_atualizar_bau()

func ordenar_bau() -> void:
	Inv.ordenar_bau(bau)
	b_msg.text = "Baú ordenado."
	if estado.has_method("salvar"):
		estado.salvar()
	_atualizar_bau()

func guardar_iguais() -> void:
	var n := Inv.guardar_iguais(estado, bau)
	b_msg.text = ("Guardou %d itens que já estavam no baú." % n) if n > 0 else "Nada igual para guardar."
	if n > 0 and estado.has_method("salvar"):
		estado.salvar()
	_atualizar_bau(true)

func recolher_bau() -> void:
	var id := String(bau.get("id", ""))
	var m := Inv.recolher(estado, id)
	if m != "":
		b_msg.text = m
		return
	if estado.has_method("salvar"):
		estado.salvar()
	var bm = bau_mundo
	bau = {}
	bau_mundo = null
	modo = "inventario"
	fechar()
	if bm and is_instance_valid(bm) and bm.has_method("removido"):
		bm.removido(id)

# ---------------------------------------------------------------- entrada
func _input(event: InputEvent) -> void:
	if not aberto:
		# Select/Back do controle abre a mochila (a tecla I/B fica no jogo_ilha.gd)
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK and not get_tree().paused and not (g and bool(g.get("ocupado"))):
			abrir("tudo")
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		if _tecla(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		_controle(event.button_index)
		get_viewport().set_input_as_handled()

func _tecla(ev: InputEventKey) -> bool:
	var k: int = ev.physical_keycode
	var eco: bool = ev.echo
	if k in [KEY_ESCAPE, KEY_I, KEY_B] or (modo == "bau" and k == KEY_E):
		if not eco:
			fechar()
		return true
	if modo == "bau":
		_tecla_bau(k, eco, ev.shift_pressed)
		return true
	match k:
		KEY_TAB:
			_trocar_aba(-1 if ev.shift_pressed else 1)
			return true
		KEY_PAGEDOWN:
			_trocar_aba(1)
			return true
		KEY_PAGEUP:
			_trocar_aba(-1)
			return true
	if aba == "equipamento":
		return false  # setas/Enter/Q/E/X/Espaco: a tela de equipamento cuida
	match k:
		KEY_LEFT, KEY_A:
			_mover_sel(-1, 0)
		KEY_RIGHT, KEY_D:
			_mover_sel(1, 0)
		KEY_UP, KEY_W:
			_mover_sel(0, -1)
		KEY_DOWN, KEY_S:
			_mover_sel(0, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_F, KEY_SPACE:
			if not eco:
				acao()
		KEY_C:
			if not eco and aba == "fabricar" and sel < fab_linhas.size():
				fabricar(String(fab_linhas[sel].rid))
		KEY_R:
			if not eco and aba != "fabricar":
				ciclar_ordem()
	return true

func _trocar_aba(d: int) -> void:
	var ids: Array = []
	for a in Inv.ABAS:
		ids.append(String(a.id))
	ir_aba(String(ids[posmod(ids.find(aba) + d, ids.size())]))

func _mover_sel(dx: int, dy: int) -> void:
	if aba == "fabricar":
		sel = clampi(sel + dx + dy, 0, fab_linhas.size())
		_atualizar_fab()
		return
	var n := itens_vis.size()
	if n == 0:
		return
	if dx != 0:
		sel = posmod(sel + dx, n)
	elif dy < 0 and sel - COLS >= 0:
		sel -= COLS
	elif dy > 0:
		sel = mini(sel + COLS, n - 1) if (sel / COLS) < ((n - 1) / COLS) else sel
	_atualizar_itens()

func _tecla_bau(k: int, eco: bool, shift: bool) -> void:
	match k:
		KEY_TAB:
			if not eco:
				painel = 1 - painel
				_atualizar_bau()
		KEY_LEFT, KEY_A:
			_mover_bau(-1, 0)
		KEY_RIGHT, KEY_D:
			_mover_bau(1, 0)
		KEY_UP, KEY_W:
			_mover_bau(0, -1)
		KEY_DOWN, KEY_S:
			_mover_bau(0, 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_F, KEY_SPACE:
			mover(painel, sel_bau if painel == 0 else sel_moc, MUITO if shift else 1)
		KEY_R:
			if not eco:
				ordenar_bau()
		KEY_G:
			if not eco:
				guardar_iguais()

func _mover_bau(dx: int, dy: int) -> void:
	if painel == 0:
		var x := sel_bau % COLS_BAU
		var y := sel_bau / COLS_BAU
		if dx != 0:
			sel_bau = y * COLS_BAU + posmod(x + dx, COLS_BAU)
		elif dy < 0 and y > 0:
			sel_bau -= COLS_BAU
		elif dy > 0:
			if y < Inv.SLOTS_BAU / COLS_BAU - 1:
				sel_bau += COLS_BAU
			elif not moc_vis.is_empty():
				painel = 1
				sel_moc = mini(x, moc_vis.size() - 1)
	else:
		var n := moc_vis.size()
		if n == 0:
			painel = 0
		elif dx != 0:
			sel_moc = posmod(sel_moc + dx, n)
		elif dy < 0:
			if sel_moc - COLS >= 0:
				sel_moc -= COLS
			else:
				painel = 0
				sel_bau = (Inv.SLOTS_BAU / COLS_BAU - 1) * COLS_BAU + mini(sel_moc, COLS_BAU - 1)
		elif dy > 0 and (sel_moc / COLS) < ((n - 1) / COLS):
			sel_moc = mini(sel_moc + COLS, n - 1)
	_atualizar_bau()

func _controle(b: int) -> void:
	match b:
		JOY_BUTTON_B, JOY_BUTTON_BACK:
			fechar()
			return
	if modo == "bau":
		match b:
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
				painel = 1 - painel
				_atualizar_bau()
			JOY_BUTTON_DPAD_LEFT: _mover_bau(-1, 0)
			JOY_BUTTON_DPAD_RIGHT: _mover_bau(1, 0)
			JOY_BUTTON_DPAD_UP: _mover_bau(0, -1)
			JOY_BUTTON_DPAD_DOWN: _mover_bau(0, 1)
			JOY_BUTTON_A: mover(painel, sel_bau if painel == 0 else sel_moc, 1)
			JOY_BUTTON_X: mover(painel, sel_bau if painel == 0 else sel_moc, MUITO)
			JOY_BUTTON_Y: ordenar_bau()
		return
	match b:
		JOY_BUTTON_LEFT_SHOULDER:
			_trocar_aba(-1)
			return
		JOY_BUTTON_RIGHT_SHOULDER:
			_trocar_aba(1)
			return
	if aba == "equipamento":
		# a tela do Codex so le teclado: o adaptador traduz o controle para a API publica dela
		var n: int = equip.possui_lista().size()
		match b:
			JOY_BUTTON_DPAD_LEFT: equip.sel = posmod(equip.sel - 1, maxi(1, n))
			JOY_BUTTON_DPAD_RIGHT: equip.sel = posmod(equip.sel + 1, maxi(1, n))
			JOY_BUTTON_DPAD_UP: equip.sel = equip.sel - equip.COLS if equip.sel - equip.COLS >= 0 else equip.sel
			JOY_BUTTON_DPAD_DOWN: equip.sel = equip.sel + equip.COLS if equip.sel + equip.COLS < n else equip.sel
			JOY_BUTTON_A: equip.vestir_sel()
			JOY_BUTTON_Y: equip.girar(1)
		equip.atualizar()
		return
	match b:
		JOY_BUTTON_DPAD_LEFT: _mover_sel(-1, 0)
		JOY_BUTTON_DPAD_RIGHT: _mover_sel(1, 0)
		JOY_BUTTON_DPAD_UP: _mover_sel(0, -1)
		JOY_BUTTON_DPAD_DOWN: _mover_sel(0, 1)
		JOY_BUTTON_A: acao()
		JOY_BUTTON_Y: ciclar_ordem()

