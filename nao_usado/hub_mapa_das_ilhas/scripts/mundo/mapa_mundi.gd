extends Control
## Mapa das Ilhas (PROPOSTA): tela de viagem com as ilhas flutuantes de data/areas.json.
## Cada ilha mostra a ilustração da área (art/ui/telas/<id>.png) no topo, rocha pendurada embaixo,
## rotas de dirigível entre as ilhas, masmorras ligadas às cidades, estado bloqueada/liberada e o
## painel com nome, descrição e "Viajar". Usado de dois jeitos:
##   - cena própria (scenes/ui/mapa_mundi.tscn, modo "tela"): ponto de partida / hub de viagem;
##   - por cima do jogo (modo "sobreposicao"): tecla M ou ponto de viagem nas cidades (viajante.gd).
## Teclas: ←/→/↑/↓ ou A/D escolhem, Enter/Espaço viajam, M/Esc fecham, U libera tudo (dev).
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Viagem = preload("res://scripts/mundo/viagem.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"
const BASE := Vector2(1600, 900)
const COR_OURO := Color("f2c76e")
const COR_PERGAMINHO := Color("f3e3c3")
const TIPOS := {"cidade": "Cidade", "fazenda": "Fazenda", "arena": "Arena", "masmorra": "Masmorra"}
const ACENTO := {
	"porto_velho": "ffcf7a", "fazenda_do_alto": "b6e07a", "vila_da_ilha": "ffd99a", "arena_das_cinzas": "ff9a7a",
	"vila_orcs": "ff8a4a", "cidade_fantasma": "a8dcff", "estacao_depois_de_ontem": "7af4ff",
	"minas_da_cinza": "ff9a4a", "criptas_de_cinzalta": "9fffe0", "fenda_cronal": "ff7af0",
}

signal fechar_pedido
signal selecionou(id: String)
signal partiu(id: String, ponto: String)

@export var modo := "tela"          # "tela" | "sobreposicao"
var area_atual := ""
var selecionada := ""
var ilhas: Dictionary = {}           # id -> Ilha
var ordem: Array = []
var mundo: Control
var rotas: Control
var painel: PanelContainer
var p_arte: TextureRect
var p_nome: Label
var p_tipo: Label
var p_desc: Label
var p_estado: Label
var p_extra: Label
var b_viajar: Button
var b_fechar: Button
var aviso: Label
var viajando := false
var fonte: Font
var _t := 0.0
var _tw_aviso: Tween

func _ready() -> void:
	fonte = load(FONTE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Viagem.garantir_viajante(get_tree())
	if modo == "tela" and area_atual == "":
		area_atual = Viagem.area_atual(get_tree())
	_montar()
	var ini := area_atual if ilhas.has(area_atual) else String(Registro.carregar().get("hub", ordem[0] if ordem.size() else ""))
	selecionar(ini)
	if modo == "sobreposicao":
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
	if OS.get_environment("MAPA_CAPTURA") != "" and modo == "tela":
		_capturas(OS.get_environment("MAPA_CAPTURA"))

# ------------------------------------------------------------------ montagem
func _montar() -> void:
	mundo = Control.new()
	mundo.name = "Mundo"
	mundo.size = BASE
	mundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mundo)
	var ceu := ColorRect.new()
	ceu.name = "Ceu"
	ceu.size = BASE + Vector2(400, 300)
	ceu.position = Vector2(-200, -150)
	ceu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/mapa_ceu.gdshader")
	ceu.material = sm
	mundo.add_child(ceu)
	_cinza_caindo()
	rotas = Rotas.new()
	rotas.name = "Rotas"
	rotas.mapa = self
	rotas.size = BASE
	rotas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mundo.add_child(rotas)
	for a in Viagem.areas_do_mapa():
		var id := String(a.id)
		var il := Ilha.new()
		il.mapa = self
		il.configurar(a, Color(ACENTO.get(id, "f2c76e")))
		il.name = "Ilha_" + id
		mundo.add_child(il)
		ilhas[id] = il
		ordem.append(id)
	rotas.montar()
	var nf := Nuvens.new()
	nf.name = "NuvensFrente"
	nf.size = BASE
	nf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mundo.add_child(nf)
	_titulo()
	_painel()
	_rodape()

func _cinza_caindo() -> void:
	var p := CPUParticles2D.new()
	p.name = "Cinza"
	p.position = Vector2(BASE.x * 0.5, -20)
	p.amount = 90
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(BASE.x * 0.6, 10)
	p.direction = Vector2(0.25, 1)
	p.spread = 12
	p.gravity = Vector2(4, 9)
	p.initial_velocity_min = 14
	p.initial_velocity_max = 34
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.86, 0.7, 0.0))
	g.add_point(0.15, Color(1.0, 0.86, 0.7, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.7, 0.6, 0.0))
	p.color_ramp = g
	mundo.add_child(p)

func _rotulo(txt: String, tam: int, cor: Color, f: Font = null, contorno := 0) -> Label:
	var l := Label.new()
	l.text = txt
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	if contorno > 0:
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.04, 0.95))
		l.add_theme_constant_override("outline_size", contorno)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _titulo() -> void:
	var t := _rotulo("Arquipélago das Cinzas", 46, Color("ffe4ae"), fonte, 10)
	t.position = Vector2(40, 22)
	mundo.add_child(t)
	var s := _rotulo("Mapa das Ilhas · rotas de dirigível do Capitão Bartolomeu" if modo == "sobreposicao" else "Para onde a Vale vai hoje?", 19, Color("eedcc4"), null, 6)
	s.position = Vector2(44, 80)
	mundo.add_child(s)

func _estilo(bg: Color, borda: Color, raio := 12, larg := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = borda
	sb.set_border_width_all(larg)
	sb.set_corner_radius_all(raio)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	return sb

func _painel() -> void:
	painel = PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.07, 0.045, 0.07, 0.9), Color(0.95, 0.76, 0.42, 0.85), 16, 2))
	painel.position = Vector2(1168, 28)
	painel.size = Vector2(404, 844)
	painel.custom_minimum_size = Vector2(404, 844)
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	painel.add_child(v)
	var cab := _rotulo("DESTINO", 15, Color(0.95, 0.78, 0.5, 0.8), fonte)
	v.add_child(cab)
	var moldura := PanelContainer.new()
	var ms := _estilo(Color(0, 0, 0, 0.6), Color(0.95, 0.76, 0.42, 0.6), 8, 2)
	ms.set_content_margin_all(3)
	ms.shadow_size = 0
	moldura.add_theme_stylebox_override("panel", ms)
	v.add_child(moldura)
	p_arte = TextureRect.new()
	p_arte.custom_minimum_size = Vector2(370, 208)
	p_arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	moldura.add_child(p_arte)
	p_nome = _rotulo("", 34, Color("ffe2a6"), fonte, 6)
	p_nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_nome.custom_minimum_size.x = 370
	v.add_child(p_nome)
	p_tipo = _rotulo("", 16, Color(0.86, 0.78, 0.7))
	v.add_child(p_tipo)
	p_desc = _rotulo("", 17, COR_PERGAMINHO)
	p_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_desc.custom_minimum_size = Vector2(370, 96)
	v.add_child(p_desc)
	var sep := HSeparator.new()
	var ss := StyleBoxLine.new()
	ss.color = Color(0.95, 0.76, 0.42, 0.35)
	ss.thickness = 1
	sep.add_theme_stylebox_override("separator", ss)
	v.add_child(sep)
	p_estado = _rotulo("", 19, Color.WHITE, fonte)
	p_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_estado.custom_minimum_size.x = 370
	v.add_child(p_estado)
	p_extra = _rotulo("", 15, Color(0.85, 0.8, 0.75))
	p_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_extra.custom_minimum_size.x = 370
	v.add_child(p_extra)
	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(esp)
	b_viajar = _botao("✈  Viajar", true)
	b_viajar.pressed.connect(viajar_selecionada)
	v.add_child(b_viajar)
	b_fechar = _botao("Fechar  [M]" if modo == "sobreposicao" else "Sair do jogo", false)
	b_fechar.pressed.connect(_fechar)
	v.add_child(b_fechar)
	aviso = _rotulo("", 16, Color("ffb39a"), null, 5)
	aviso.position = Vector2(40, 836)
	aviso.modulate.a = 0.0
	add_child(aviso)

func _botao(txt: String, principal: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(370, 58 if principal else 42)
	b.add_theme_font_override("font", fonte)
	b.add_theme_font_size_override("font_size", 26 if principal else 18)
	var base := Color(0.72, 0.46, 0.18, 0.95) if principal else Color(0.2, 0.14, 0.16, 0.9)
	var n := _estilo(base, Color(1.0, 0.85, 0.5, 0.9) if principal else Color(0.7, 0.55, 0.4, 0.6), 10, 2)
	n.shadow_size = 4
	var h := _estilo(base.lightened(0.18), Color(1, 0.93, 0.7), 10, 2)
	h.shadow_size = 6
	var d := _estilo(Color(0.22, 0.2, 0.22, 0.85), Color(0.45, 0.42, 0.45, 0.6), 10, 2)
	d.shadow_size = 0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_color_override("font_color", Color("fff3d6") if principal else Color("e8d8c4"))
	b.add_theme_color_override("font_disabled_color", Color(0.65, 0.62, 0.62))
	b.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.04))
	b.add_theme_constant_override("outline_size", 4 if principal else 0)
	return b

func _rodape() -> void:
	var r := _rotulo("←/→ escolher ilha · Enter viajar · clique duplo viaja · %s · U liberar tudo (dev)" % ("M/Esc fechar" if modo == "sobreposicao" else "Esc sair"), 14, Color(0.95, 0.88, 0.8, 0.75), null, 4)
	r.position = Vector2(44, 874)
	add_child(r)
	# legenda
	var leg := _rotulo("━ ━  rota de dirigível      ┅┅  passagem para masmorra      🔒  bloqueada", 14, Color(0.95, 0.88, 0.8, 0.65), null, 4)
	leg.position = Vector2(44, 110)
	mundo.add_child(leg)

# ------------------------------------------------------------------ seleção / painel
func selecionar(id: String) -> void:
	if not ilhas.has(id):
		return
	selecionada = id
	for k in ilhas:
		ilhas[k].selecionada = (k == id)
	var a := Registro.area(id)
	var arte := String(a.get("arte", ""))
	p_arte.texture = load(arte) if ResourceLoader.exists(arte) else null
	p_nome.text = String(a.get("nome", id))
	p_tipo.text = "%s · %s" % [TIPOS.get(String(a.get("tipo", "")), "Área"), String(a.get("regiao", ""))]
	p_desc.text = String(a.get("descricao", ""))
	var livre := Viagem.desbloqueada(id)
	if id == area_atual:
		p_estado.text = "◉ Você está aqui"
		p_estado.add_theme_color_override("font_color", Color("ffd27a"))
	elif livre:
		p_estado.text = "✔ Liberada" + ("  ·  já visitada" if Viagem.visitadas.has(id) else "")
		p_estado.add_theme_color_override("font_color", Color("a8f0a0"))
	else:
		p_estado.text = "🔒 Bloqueada · " + Viagem.requisito(id)
		p_estado.add_theme_color_override("font_color", Color("ff9f8a"))
	p_extra.text = _extra(a)
	b_viajar.disabled = not livre or id == area_atual or viajando
	b_viajar.text = "✈  Viajar" if String(a.get("tipo", "")) != "masmorra" else "Descer  ↓"
	if id == area_atual:
		b_viajar.text = "Você já está aqui"
	selecionou.emit(id)

func _extra(a: Dictionary) -> String:
	var linhas: Array = []
	var id := String(a.id)
	if String(a.get("tipo", "")) == "masmorra":
		var tema := String(a.get("tema", id))
		var lista: Array = Sessao.andares(tema)
		linhas.append("Andares: %d–%d · chefe no %d" % [int(lista[0]), int(lista[lista.size() - 2]) if lista.size() > 1 else int(lista[0]), int(lista.back())])
		var prof := Sessao.profundidade_de(tema)
		linhas.append("Mais fundo alcançado: " + ("andar %d" % prof if prof > 0 else "nunca desceu"))
		var ori := Registro.origem_de(id)
		if not ori.is_empty():
			linhas.append("Volta para: " + Registro.nome(String(ori.area)))
	else:
		var viz: Array = []
		for r in rotas.ligacoes:
			if r.a == id: viz.append(Registro.nome(r.b))
			elif r.b == id: viz.append(Registro.nome(r.a))
		if viz.size():
			linhas.append("Rotas: " + ", ".join(viz))
		var ms: Array = []
		for e in a.get("entradas_de_masmorra", []):
			ms.append(Registro.nome(String(e.area)))
		if ms.size():
			linhas.append("Entradas: " + ", ".join(ms))
	return "\n".join(linhas)

func proxima(passo: int) -> void:
	var i := ordem.find(selecionada)
	selecionar(String(ordem[(i + passo + ordem.size()) % ordem.size()]))

func _input(event: InputEvent) -> void:
	if viajando:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		var tratou := true
		match k:
			KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S, KEY_TAB: proxima(1)
			KEY_LEFT, KEY_A, KEY_UP, KEY_W: proxima(-1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: viajar_selecionada()
			KEY_M:
				if modo == "sobreposicao":
					_fechar()
				else:
					tratou = false
			KEY_ESCAPE: _fechar()
			KEY_U:
				Viagem.desbloquear_tudo = not Viagem.desbloquear_tudo
				_mostrar_aviso("Dev: todas as ilhas liberadas" if Viagem.desbloquear_tudo else "Dev: desbloqueio normal")
				_atualizar()
			_: tratou = false
		if tratou:
			get_viewport().set_input_as_handled()

func _atualizar() -> void:
	for k in ilhas:
		ilhas[k].atualizar_estado()
	rotas.queue_redraw()
	selecionar(selecionada)

func _fechar() -> void:
	if modo == "sobreposicao":
		fechar_pedido.emit()
	else:
		get_tree().quit()

func _mostrar_aviso(t: String) -> void:
	aviso.text = t
	if _tw_aviso:
		_tw_aviso.kill()
	_tw_aviso = create_tween()
	aviso.modulate.a = 1.0
	_tw_aviso.tween_interval(1.8)
	_tw_aviso.tween_property(aviso, "modulate:a", 0.0, 0.6)

# ------------------------------------------------------------------ viagem
func viajar_selecionada() -> void:
	viajar_para(selecionada)

func viajar_para(id: String, ponto := "") -> bool:
	if viajando or not ilhas.has(id):
		return false
	if id == area_atual:
		_mostrar_aviso("A Vale já está em %s." % Registro.nome(id))
		return false
	if not Viagem.desbloqueada(id):
		ilhas[id].tremer()
		_mostrar_aviso("%s está bloqueada: %s." % [Registro.nome(id), Viagem.requisito(id)])
		return false
	viajando = true
	selecionar(id)
	b_viajar.disabled = true
	var de: Vector2 = ilhas[area_atual].centro_global() if ilhas.has(area_atual) else Vector2(BASE.x * 0.38, BASE.y + 60)
	var para: Vector2 = ilhas[id].centro_global()
	var dur := 0.25 if Viagem.animacao_rapida else 1.5
	rotas.voo_t = 0.0
	rotas.voo = {"de": de, "para": para, "t": 0.0, "masmorra": String(Registro.area(id).get("tipo", "")) == "masmorra"}
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rotas, "voo_t", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mundo.pivot_offset = para
	tw.tween_property(mundo, "scale", Vector2.ONE * 1.45, dur * 0.9).set_delay(dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate", Color(0.05, 0.03, 0.06, 1.0), dur * 0.4).set_delay(dur * 0.85)
	await tw.finished
	partiu.emit(id, ponto)
	Viagem.garantir_viajante(get_tree()).partir(id, ponto)
	return true

func _process(delta: float) -> void:
	_t += delta

# ------------------------------------------------------------------ capturas (modo tela)
func _capturas(pasta: String) -> void:
	get_window().size = Vector2i(1600, 900)
	for i in 40:
		await get_tree().process_frame
	var lista := OS.get_environment("MAPA_CAPTURA_SEL").split(",", false)
	if lista.is_empty():
		lista = PackedStringArray(["porto_velho"])
	for sid in lista:
		var partes: PackedStringArray = String(sid).split(":")
		selecionar(partes[0])
		if partes.size() > 1:
			ilhas[partes[0]].hover = true
		for i in 25:
			await get_tree().process_frame
		var nome := "mapa_%s.png" % String(sid).replace(":", "_")
		get_viewport().get_texture().get_image().save_png(pasta.path_join(nome))
		print("[mapa_mundi] captura: ", pasta.path_join(nome))
	get_tree().quit()

# ================================================================== ilha flutuante
class Ilha extends Control:
	var mapa
	var id := ""
	var dados: Dictionary = {}
	var raio := 100.0
	var achat := 0.5
	var centro := Vector2.ZERO        # posição no mapa (1600x900)
	var acento := Color.WHITE
	var arte: Texture2D
	var masmorra := false
	var selecionada := false
	var hover := false
	var livre := true
	var atual := false
	var _fase := 0.0
	var _topo := PackedVector2Array()
	var _uv := PackedVector2Array()
	var _baixo := PackedVector2Array()
	var _cores_baixo := PackedColorArray()
	var _raizes: Array = []
	var _cristais: Array = []
	var _tremor := 0.0
	var _esc := 1.0
	var _mat: ShaderMaterial
	var _t := 0.0

	func configurar(a: Dictionary, cor: Color) -> void:
		dados = a
		id = String(a.id)
		var m: Dictionary = a.mapa
		centro = Vector2(float(m.pos[0]), float(m.pos[1]))
		raio = float(m.get("raio", 100))
		masmorra = String(a.get("tipo", "")) == "masmorra"
		achat = 0.46 if masmorra else 0.52
		acento = cor
		var c := String(a.get("arte", ""))
		arte = load(c) if ResourceLoader.exists(c) else null
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		_fase = rng.randf() * TAU
		# topo: elipse levemente irregular
		var n := 56
		for i in n:
			var ang := TAU * i / n
			var w := 1.0 + 0.035 * sin(ang * 3.0 + _fase) + 0.02 * sin(ang * 7.0 + _fase * 2.0)
			var p := Vector2(cos(ang) * raio * w, sin(ang) * raio * achat * w)
			_topo.append(p)
			# a imagem 16:9 cobre a elipse: x -> [0,1], y -> faixa central
			# usa só a parte de cima da ilustração (sem a faixa do título), cortada para o formato da elipse
			_uv.append(Vector2(0.5 + p.x / raio * 0.36 * (0.52 / achat) * 1.0, 0.38 + p.y / (raio * achat) * 0.355))
		# rocha pendurada: arco de baixo da elipse + ponta irregular
		var prof := raio * (1.1 if not masmorra else 1.3)
		var arco := PackedVector2Array()
		for i in range(0, n / 2 + 1):
			var ang := TAU * i / n
			arco.append(Vector2(cos(ang) * raio * 0.985, sin(ang) * raio * achat * 0.985 + raio * 0.1))
		# ponta: cada ponto do arco desce d(x) (mesmo x, então o polígono nunca se cruza)
		var c_topo := Color(0.42, 0.3, 0.24) if not masmorra else Color(0.24, 0.2, 0.26)
		var c0 := Color(0.3, 0.21, 0.18) if not masmorra else Color(0.16, 0.13, 0.2)
		for p in arco:
			_baixo.append(p)
			_cores_baixo.append(c_topo)
		for i in range(arco.size() - 2, 0, -1):
			var p := arco[i]
			var f := 1.0 - clampf(absf(p.x) / raio, 0.0, 1.0)
			var d := prof * pow(maxf(f, 0.0), 1.2) * (0.62 + 0.38 * rng.randf())
			if i % 3 == 0:
				d *= 1.18
			elif i % 3 == 1:
				d *= 0.8
			_baixo.append(p + Vector2(0, d + 3.0))
			_cores_baixo.append(c0.lerp(Color(0.08, 0.06, 0.08), clampf(d / prof, 0.0, 1.0)))
		# raízes e cristais
		for i in 7:
			var x := rng.randf_range(-raio * 0.7, raio * 0.7)
			var y0 := raio * achat * 0.5 + rng.randf_range(0, raio * 0.25)
			_raizes.append([Vector2(x, y0), rng.randf_range(raio * 0.25, raio * 0.6), rng.randf() * TAU])
		var nc := 9 if masmorra else 3
		for i in nc:
			var ang := rng.randf_range(0.15, PI - 0.15) if masmorra else rng.randf_range(0.5, PI - 0.5)
			_cristais.append([Vector2(cos(ang) * raio * 0.98, sin(ang) * raio * achat + raio * 0.12 + rng.randf_range(0, raio * 0.3)), rng.randf_range(10, 22) * (raio / 100.0), rng.randf_range(-0.5, 0.5)])
		var marg := Vector2(raio + 30, 0)
		size = Vector2((raio + 40) * 2, raio * achat + prof + raio * achat + 120)
		pivot_offset = Vector2(size.x * 0.5, raio * achat + 60)
		position = centro - pivot_offset
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): hover = true)
		mouse_exited.connect(func(): hover = false)
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/mapa_bloqueada.gdshader")
		material = _mat
		atualizar_estado()

	func atualizar_estado() -> void:
		livre = Viagem.desbloqueada(id) if mapa else true
		atual = mapa != null and mapa.area_atual == id
		_mat.set_shader_parameter("quantidade", 0.0 if livre else 0.6)

	func centro_global() -> Vector2:
		return position + pivot_offset

	func _has_point(p: Vector2) -> bool:
		var q := p - pivot_offset
		var e := Vector2(q.x / raio, q.y / (raio * achat))
		return e.length() < 1.05 or (absf(q.x) < raio * 0.6 and q.y > 0 and q.y < raio * achat + 50)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.double_click:
				mapa.viajar_para(id)
			else:
				mapa.selecionar(id)
			accept_event()

	func tremer() -> void:
		_tremor = 0.45

	func _process(delta: float) -> void:
		_t += delta
		var alvo := 1.07 if (selecionada or hover) else 1.0
		_esc = lerpf(_esc, alvo, 1.0 - exp(-delta * 10.0))
		_tremor = maxf(0.0, _tremor - delta)
		var dx := sin(_t * 60.0) * 7.0 * (_tremor / 0.45)
		position = centro - pivot_offset + Vector2(dx, sin(_t * 0.9 + _fase) * (4.0 if not masmorra else 6.0))
		scale = Vector2.ONE * _esc
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(pivot_offset, 0.0, Vector2.ONE)
		var pulso := 0.5 + 0.5 * sin(_t * 2.4)
		# sombra no mar de cinza
		var sombra := PackedVector2Array()
		for p in _topo:
			sombra.append(Vector2(p.x * 0.8, p.y * 0.35 + raio * 1.9))
		draw_colored_polygon(sombra, Color(0, 0, 0, 0.07))
		# brilho de seleção atrás
		if selecionada or hover:
			for i in 4:
				var g := PackedVector2Array()
				for p in _topo:
					g.append(p * (1.06 + i * 0.05))
				g.append(g[0])
				draw_polyline(g, Color(COR_OURO, (0.32 - i * 0.07) * (0.6 + 0.4 * pulso)), 6.0 + i * 3.0, true)
		# raízes
		for r in _raizes:
			var p0: Vector2 = r[0]
			var pts := PackedVector2Array()
			for s in 8:
				var tt := s / 7.0
				pts.append(p0 + Vector2(sin(tt * 4.0 + r[2] + _t * 0.6) * 4.0 * tt, tt * float(r[1])))
			draw_polyline(pts, Color(0.18, 0.24, 0.14, 0.85) if not masmorra else Color(acento, 0.35), 2.0, true)
		# rocha
		draw_polygon(_baixo, _cores_baixo)
		# estratos
		for s in 3:
			var y := raio * achat * 0.45 + s * raio * 0.16
			var w := raio * (0.92 - s * 0.2)
			draw_line(Vector2(-w, y), Vector2(w, y + 3), Color(0, 0, 0, 0.18), 2.0, true)
		# cristais (masmorra: muitos, brilhando)
		for c in _cristais:
			var b: Vector2 = c[0]
			var h: float = c[1]
			var tri := PackedVector2Array([b + Vector2(-h * 0.28, 0), b + Vector2(h * 0.28, 0), b + Vector2(float(c[2]) * h * 0.3, h * (1.4 if masmorra else 0.9))])
			draw_colored_polygon(tri, Color(acento, 0.85) if masmorra else Color(0.55, 0.5, 0.5))
			if masmorra:
				draw_circle(b + Vector2(0, h * 0.5), h * 0.9, Color(acento, 0.08 + 0.06 * pulso))
		# espessura do solo
		var solo := PackedVector2Array()
		for p in _topo:
			solo.append(p + Vector2(0, raio * 0.1))
		draw_colored_polygon(solo, Color(0.33, 0.24, 0.16) if not masmorra else Color(0.2, 0.16, 0.22))
		# topo com a ilustração
		if arte:
			var cores := PackedColorArray()
			cores.resize(_topo.size())
			cores.fill(Color(1.12, 1.1, 1.08))
			draw_polygon(_topo, cores, _uv, arte)
		else:
			draw_colored_polygon(_topo, Color(0.4, 0.5, 0.3))
		# borda: grama / portal
		var borda := _topo.duplicate()
		borda.append(_topo[0])
		if masmorra:
			draw_polyline(borda, Color(acento, 0.55 + 0.35 * pulso), 5.0, true)
			draw_polyline(borda, Color(1, 1, 1, 0.25), 1.5, true)
		else:
			draw_polyline(borda, Color(0.32, 0.46, 0.2), 6.0, true)
			draw_polyline(borda, Color(0.62, 0.78, 0.38, 0.8), 2.0, true)
		# masmorra: portal girando sobre a ilustração
		if masmorra:
			for k in 3:
				var rr := raio * (0.32 + k * 0.13)
				var giro := _t * (0.6 + k * 0.35) * (1.0 if k % 2 == 0 else -1.0)
				for sgm in 6:
					var a0 := giro + sgm * TAU / 6.0
					var arco_p := PackedVector2Array()
					for q in 7:
						var aa := a0 + q * 0.09
						arco_p.append(Vector2(cos(aa) * rr, sin(aa) * rr * achat))
					draw_polyline(arco_p, Color(acento, 0.35 + 0.25 * pulso), 2.5, true)
			var nucleo := PackedVector2Array()
			for q in 24:
				var aa := TAU * q / 24
				nucleo.append(Vector2(cos(aa) * raio * 0.2, sin(aa) * raio * 0.2 * achat))
			draw_colored_polygon(nucleo, Color(acento, 0.18 + 0.12 * pulso))
		# cachoeiras (ilhas com rio)
		for cx in dados.get("mapa", {}).get("cachoeiras", []):
			var x0 := float(cx) * raio
			var y0 := raio * achat * sqrt(maxf(0.0, 1.0 - pow(float(cx), 2.0))) + raio * 0.08
			var comp := raio * 0.75
			for fio in 3:
				var fx := x0 + (fio - 1) * 3.0
				var pts := PackedVector2Array()
				var cores_f := PackedColorArray()
				for q in 12:
					pts.append(Vector2(fx + sin(q * 0.6 + _t * 2.0 + fio) * 1.2, y0 + comp * q / 11.0))
					cores_f.append(Color(0.75, 0.9, 1.0, 0.75 * (1.0 - q / 11.0)))
				draw_polyline_colors(pts, cores_f, 2.4, true)
			for q in 4:
				var gy := fmod(_t * 60.0 + q * comp * 0.25, comp)
				draw_circle(Vector2(x0, y0 + gy), 1.6, Color(1, 1, 1, 0.7 * (1.0 - gy / comp)))
		# placa do nome
		var nome := String(dados.get("nome", id))
		var fs := 22 if not masmorra else 18
		var tam: Vector2 = mapa.fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var py := raio * achat + 14
		var rect := Rect2(Vector2(-tam.x * 0.5 - 14, py - 4), Vector2(tam.x + 28, fs + 14))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.06, 0.07, 0.86) if livre else Color(0.12, 0.12, 0.14, 0.8)
		sb.border_color = Color(COR_OURO, 0.95 if selecionada else 0.55) if livre else Color(0.5, 0.5, 0.55, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(9)
		draw_style_box(sb, rect)
		draw_string(mapa.fonte, Vector2(-tam.x * 0.5, py + fs), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe6b4") if livre else Color(0.75, 0.75, 0.78))
		# cadeado
		if not livre:
			var c0 := Vector2(0, -raio * achat * 0.15)
			draw_circle(c0, 26, Color(0.05, 0.04, 0.06, 0.75))
			draw_arc(c0 + Vector2(0, -6), 9, PI, TAU, 16, Color(0.9, 0.86, 0.8), 3.5, true)
			draw_rect(Rect2(c0 + Vector2(-12, -6), Vector2(24, 18)), Color(0.9, 0.86, 0.8))
			draw_circle(c0 + Vector2(0, 2), 3, Color(0.1, 0.08, 0.1))
		# "você está aqui"
		if atual:
			var b := sin(_t * 3.0) * 6.0
			var ponta := Vector2(0, -raio * achat * 0.35 + b)
			var gota := PackedVector2Array([ponta, ponta + Vector2(-13, -26), ponta + Vector2(0, -44), ponta + Vector2(13, -26)])
			draw_colored_polygon(gota, Color("ffcf6a"))
			draw_circle(ponta + Vector2(0, -28), 13, Color("ffcf6a"))
			draw_circle(ponta + Vector2(0, -28), 6, Color(0.35, 0.16, 0.08))
			var txt := "Você está aqui"
			var tt: Vector2 = mapa.fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			draw_string_outline(mapa.fonte, ponta + Vector2(-tt.x * 0.5, -52), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Color(0.08, 0.04, 0.03))
			draw_string(mapa.fonte, ponta + Vector2(-tt.x * 0.5, -52), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffe6b4"))

# ================================================================== rotas e dirigíveis
class Rotas extends Control:
	var mapa
	var ligacoes: Array = []     # {a, b, tipo: "dirigivel"|"masmorra", curva}
	var voo: Dictionary = {}
	var voo_t := 0.0
	var _t := 0.0
	var _ambiente: Array = []    # dirigíveis passeando nas rotas

	func montar() -> void:
		var vistos := {}
		for id in mapa.ilhas:
			var a: Dictionary = mapa.ilhas[id].dados
			for b in a.mapa.get("rotas", []):
				var k := ("%s|%s" % [id, b]) if String(id) < String(b) else ("%s|%s" % [b, id])
				if mapa.ilhas.has(b) and not vistos.has(k):
					vistos[k] = true
					ligacoes.append({"a": id, "b": String(b), "tipo": "dirigivel", "curva": 0.16 if ligacoes.size() % 2 == 0 else -0.14})
			for b in a.mapa.get("ligada_a", []):
				if mapa.ilhas.has(b):
					ligacoes.append({"a": String(b), "b": id, "tipo": "masmorra", "curva": 0.06})
		var i := 0
		for l in ligacoes:
			if l.tipo == "dirigivel" and i < 3:
				_ambiente.append({"l": l, "fase": i * 0.37, "vel": 0.035 + i * 0.008})
				i += 1

	func _ponto(l: Dictionary, t: float) -> Vector2:
		var a: Vector2 = mapa.ilhas[l.a].centro
		var b: Vector2 = mapa.ilhas[l.b].centro
		var meio := (a + b) * 0.5
		var n := (b - a).orthogonal().normalized() * (b - a).length() * float(l.curva)
		var c := meio + n - Vector2(0, (b - a).length() * 0.08)
		return a.lerp(c, t).lerp(c.lerp(b, t), t)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for l in ligacoes:
			var livre: bool = Viagem.desbloqueada(l.a) and Viagem.desbloqueada(l.b)
			var sel: bool = mapa.selecionada == l.a or mapa.selecionada == l.b
			var n := 60
			var pts: Array = []
			for i in n + 1:
				pts.append(_ponto(l, float(i) / n))
			if l.tipo == "dirigivel":
				var cor := Color(1.0, 0.9, 0.72, (0.8 if sel else 0.55) if livre else 0.2)
				var desl := fmod(_t * 0.9, 2.0)
				for i in n:
					if (int(i + desl * 2.0) / 2) % 2 == 0:
						draw_line(pts[i] + Vector2(0, 3), pts[i + 1] + Vector2(0, 3), Color(0, 0, 0, cor.a * 0.35), 4.0, true)
						draw_line(pts[i], pts[i + 1], cor, 3.0 if sel else 2.4, true)
			else:
				var ac := Color(ACENTO.get(l.b, "ffffff"))
				for i in range(0, n + 1, 3):
					var pulso := 0.5 + 0.5 * sin(_t * 3.0 - i * 0.25)
					draw_circle(pts[i], 3.2 if sel else 2.6, Color(ac, (0.45 + 0.45 * pulso) if livre else 0.18))
		# dirigíveis passeando
		for d in _ambiente:
			var l: Dictionary = d.l
			if not (Viagem.desbloqueada(l.a) and Viagem.desbloqueada(l.b)):
				continue
			var tt := fmod(_t * float(d.vel) + float(d.fase), 2.0)
			var t := tt if tt < 1.0 else 2.0 - tt
			var p := _ponto(l, t)
			var p2 := _ponto(l, clampf(t + (0.01 if tt < 1.0 else -0.01), 0.0, 1.0))
			_dirigivel(p + Vector2(0, -16), (p2 - p).x >= 0.0, 0.75)
		# voo da viagem
		if not voo.is_empty():
			var a: Vector2 = voo.de
			var b: Vector2 = voo.para
			var c := (a + b) * 0.5 + Vector2(0, -minf(220.0, a.distance_to(b) * 0.45))
			var t := voo_t
			var p := a.lerp(c, t).lerp(c.lerp(b, t), t)
			var rastro := PackedVector2Array()
			for i in 24:
				var s := t * i / 23.0
				rastro.append(a.lerp(c, s).lerp(c.lerp(b, s), s))
			if rastro.size() > 1:
				draw_polyline(rastro, Color(1, 0.9, 0.7, 0.5), 3.0, true)
			_dirigivel(p + Vector2(0, -20), b.x >= a.x, 1.6)

	func _dirigivel(p: Vector2, direita: bool, e: float) -> void:
		var s := 1.0 if direita else -1.0
		var balao := PackedVector2Array()
		for i in 24:
			var ang := TAU * i / 24
			balao.append(p + Vector2(cos(ang) * 22.0 * e, sin(ang) * 9.0 * e))
		draw_colored_polygon(balao, Color("8c2f3a"))
		draw_line(p + Vector2(-20 * e, 0), p + Vector2(20 * e, 0), Color("c9535f"), 2.0 * e, true)
		draw_arc(p, 9.0 * e, PI * 1.1, PI * 1.9, 8, Color(1, 0.8, 0.7, 0.5), 1.5 * e, true)
		var leme := PackedVector2Array([p + Vector2(-s * 20 * e, 0), p + Vector2(-s * 30 * e, -9 * e), p + Vector2(-s * 30 * e, 9 * e)])
		draw_colored_polygon(leme, Color("5e1e28"))
		draw_line(p + Vector2(-8 * e, 8 * e), p + Vector2(-5 * e, 14 * e), Color(0.2, 0.15, 0.1), 1.2 * e)
		draw_line(p + Vector2(8 * e, 8 * e), p + Vector2(5 * e, 14 * e), Color(0.2, 0.15, 0.1), 1.2 * e)
		draw_rect(Rect2(p + Vector2(-7 * e, 14 * e), Vector2(14 * e, 5 * e)), Color("6b4a2c"))
		draw_circle(p + Vector2(s * 4 * e, 16 * e), 1.5 * e, Color(1, 0.85, 0.5))

# ================================================================== nuvens na frente das ilhas de baixo
class Nuvens extends Control:
	var _t := 0.0
	var _puffs: Array = []
	var _tex: Texture2D

	func _ready() -> void:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_tex = gt
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 9:
			_puffs.append({"x": rng.randf_range(-100, 1250), "y": rng.randf_range(640, 900), "e": rng.randf_range(0.9, 1.8), "v": rng.randf_range(4, 10)})

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for p in _puffs:
			var x := fmod(float(p.x) + _t * float(p.v) + 260.0, 1560.0) - 260.0
			var y := float(p.y) + sin(_t * 0.3 + float(p.x)) * 4.0
			var e := float(p.e)
			for k in 4:
				var w := (190.0 - absf(k - 1.5) * 40.0) * e
				var c := Vector2(x + (k - 1.5) * 60.0 * e, y + (k % 2) * 10.0 * e)
				draw_texture_rect(_tex, Rect2(c - Vector2(w, w * 0.42), Vector2(w * 2.0, w * 0.84)), false, Color(1.0, 0.84, 0.74, 0.1))
