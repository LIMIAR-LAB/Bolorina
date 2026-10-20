extends Node3D
## Entrada visível de masmorra numa cidade (PROPOSTA). Nó filho da raiz do mapa
## (scripts/vila_grande/mapa_cc0.gd ou ilha_futurista.gd). Lê posição/rótulo/destino de
## data/areas.json (scripts/mundo/registro_areas.gd), monta o visual pelo tipo
## (elevador | caverna | portao | fenda), mostra o rótulo e "[E] Entrar" perto da jogadora,
## abre um menu (tema, profundidade alcançada, Entrar / Cancelar) e carrega a masmorra.
## Na volta (Registro.chegada_pendente para esta entrada) põe a jogadora na frente da entrada.
## Capturas: DUNGEON_CAPTURA=/pasta (prompt + menu) e sai.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")

signal menu_aberto
signal entrando(masmorra: String, ponto: String)

@export var area_id := ""
@export var entrada_id := ""
@export var raio_interacao := 3.2

var mapa: Node3D
var dados: Dictionary = {}
var destino: Dictionary = {}
var tema_dados: Dictionary = {}
var prompt: Label3D
var rotulo: Label3D
var menu: CanvasLayer
var botao_entrar: Button
var perto := false
var pronto := false
var _mats := {}
var _giram: Array = []
var _t := 0.0
var luz_principal: OmniLight3D

func _ready() -> void:
	add_to_group("entrada_masmorra")
	call_deferred("_montar")

func _montar() -> void:
	mapa = get_parent()
	dados = Registro.entrada_de_masmorra(area_id, entrada_id)
	if dados.is_empty():
		push_warning("entrada_masmorra: %s/%s não está em data/areas.json" % [area_id, entrada_id])
		return
	destino = Registro.area(String(dados.area))
	tema_dados = Sessao.dados_tema(String(destino.get("tema", dados.area)))
	var p: Array = dados.pos
	var y: float = mapa._y(float(p[0]), float(p[1])) if mapa.has_method("_y") else 0.0
	position = Vector3(float(p[0]), y, float(p[1]))
	rotation.y = deg_to_rad(float(dados.get("ang", 0.0)))
	name = "Entrada_" + entrada_id
	match String(dados.get("tipo", "")):
		"elevador": _elevador()
		"caverna": _caverna()
		"portao": _portao()
		_: _fenda()
	rotulo = _label(String(dados.get("rotulo", Registro.nome(String(dados.area)))), Vector3(0, 6.4, 0), Color("ffe6b0"), 0.014)
	prompt = _label("[E] Entrar", Vector3(0, 4.3, 0), Color("fff6c8"), 0.011)
	prompt.visible = false
	pronto = true
	_chegada()
	if OS.get_environment("DUNGEON_CAPTURA") != "":
		_capturas(OS.get_environment("DUNGEON_CAPTURA"))

## ponto na frente da entrada (para onde a jogadora volta), em coordenadas do mapa
func ponto_de_volta() -> Vector3:
	var pv := Registro.ponto(area_id, entrada_id)
	var p: Array = pv.get("pos", dados.pos)
	var y: float = mapa._y(float(p[0]), float(p[1])) if mapa.has_method("_y") else 0.0
	return Vector3(float(p[0]), y, float(p[1]))

func _chegada() -> void:
	var c: Dictionary = Registro.chegada_pendente
	if String(c.get("area", "")) == area_id and String(c.get("ponto", "")) == entrada_id:
		Registro.consumir_chegada(area_id)
		if mapa.get("jogador"):
			mapa.jogador.position = ponto_de_volta() + Vector3(0, 0.3, 0)
			mapa.jogador.velocity = Vector3.ZERO

# ------------------------------------------------------------------ visual
func _mat(nome: String, cor: Color, emissao := 0.0, metal := 0.0, alfa := 1.0) -> StandardMaterial3D:
	if _mats.has(nome):
		return _mats[nome]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	m.roughness = 0.8 if metal == 0.0 else 0.35
	m.metallic = metal
	if alfa < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	_mats[nome] = m
	return m

func _caixa(tam: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, colisao := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	if colisao:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = tam
		cs.shape = s
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		add_child(sb)
	return mi

func _modelo(caminho: String, pos: Vector3, rot_y := 0.0, escala := 1.0) -> Node3D:
	var p := "res://art/models/" + caminho
	var n: Node3D = (load(p) as PackedScene).instantiate() if ResourceLoader.exists(p) else Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * escala
	add_child(n)
	return n

func _luz(pos: Vector3, cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.position = pos
	add_child(l)
	return l

func _label(texto: String, pos: Vector3, cor: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 64
	l.pixel_size = px
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = cor
	l.outline_modulate = Color("1a110b")
	l.position = pos
	l.render_priority = 5
	add_child(l)
	return l

func _particulas(cor: Color, qtd: int, caixa: Vector3, pos: Vector3, subida: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = qtd
	p.lifetime = 2.5
	p.preprocess = 2.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caixa
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = subida * 0.3
	pm.initial_velocity_max = subida
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = cor
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.draw_pass_1 = q
	p.position = pos
	add_child(p)

func _elevador() -> void:
	# torre de madeira do Elevador do Tião (desce para as Minas da Cinza)
	var mad := _mat("madeira", Color("7a5232"))
	var ferro := _mat("ferro", Color("5c5a60"), 0.0, 0.7)
	_caixa(Vector3(3.0, 0.2, 3.0), Vector3(0, 0.1, 0), mad, Vector3.ZERO, false)
	for sx in [-1.4, 1.4]:
		for sz in [-1.4, 1.4]:
			_caixa(Vector3(0.25, 7.0, 0.25), Vector3(sx, 3.5, sz), mad, Vector3.ZERO, true)
	for yy in [2.8, 6.8]:
		_caixa(Vector3(3.2, 0.24, 0.24), Vector3(0, yy, -1.4), mad)
		_caixa(Vector3(3.2, 0.24, 0.24), Vector3(0, yy, 1.4), mad)
		_caixa(Vector3(0.24, 0.24, 3.2), Vector3(-1.4, yy, 0), mad)
	_caixa(Vector3(3.6, 0.3, 3.6), Vector3(0, 7.1, 0), _mat("telhado", Color("3d4656")))
	var roda := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.7
	c.bottom_radius = 0.7
	c.height = 0.16
	roda.mesh = c
	roda.material_override = ferro
	roda.position = Vector3(0, 6.3, 0)
	roda.rotation = Vector3(0, 0, PI / 2)
	add_child(roda)
	_giram.append([roda, Vector3(1, 0, 0), 0.8])
	for sx in [-0.5, 0.5]:
		_caixa(Vector3(0.04, 6.0, 0.04), Vector3(sx, 3.3, 0), _mat("corda", Color("a88a5a")))
	# grade de proteção e a gaiola
	_caixa(Vector3(2.8, 0.08, 0.06), Vector3(0, 1.0, -1.35), ferro)
	_caixa(Vector3(0.06, 0.08, 2.8), Vector3(-1.35, 1.0, 0), ferro)
	_caixa(Vector3(2.4, 1.4, 0.05), Vector3(0, 1.2, -1.2), _mat("gaiola", Color("2a2622"), 0.0, 0.5, 0.55))
	# poço escuro
	_caixa(Vector3(2.4, 0.04, 2.4), Vector3(0, 0.22, 0), _mat("poco", Color("0a0806")))
	var lamp := _caixa(Vector3(0.28, 0.36, 0.28), Vector3(1.4, 2.4, 1.4), _mat("vidro", Color("ffb35a"), 3.0))
	lamp.name = "Lampiao"
	luz_principal = _luz(Vector3(1.2, 2.6, 1.2), Color("ffc27a"), 2.4, 9.0)
	_modelo("kaykit_dungeon/crates_stacked.gltf", Vector3(2.6, 0, -1.6), 0.4, 0.55)
	_modelo("kaykit_dungeon/barrel_large.gltf", Vector3(-2.4, 0, 1.8), 0.0, 0.5)
	_modelo("kenney_train_kit/train-carriage-coal.glb", Vector3(2.6, 0, 1.8), PI / 2, 0.55)

func _caverna() -> void:
	# boca de mina numa encosta: rochas grandes formando um arco + escoras + trilho
	var rocha := _mat("rocha", Color("5a4c44"))
	var escuro := _mat("boca", Color("050403"))
	var b1 := _modelo("boulder_01/boulder_01_1k.gltf", Vector3(-2.6, 0, -0.8), 0.6, 2.4)
	var b2 := _modelo("boulder_01/boulder_01_1k.gltf", Vector3(2.6, 0, -0.8), 2.4, 2.2)
	var b3 := _modelo("boulder_01/boulder_01_1k.gltf", Vector3(0.0, 2.9, -1.4), 1.2, 2.6)
	for b in [b1, b2, b3]:
		b.name = "RochaDoArco"
	_caixa(Vector3(1.6, 3.4, 2.4), Vector3(-2.6, 1.7, -1.2), rocha, Vector3.ZERO, true)
	_caixa(Vector3(1.6, 3.4, 2.4), Vector3(2.6, 1.7, -1.2), rocha, Vector3.ZERO, true)
	_caixa(Vector3(3.6, 3.0, 0.1), Vector3(0, 1.5, -1.9), escuro)
	var mad := _mat("madeira", Color("6a4428"))
	for sx in [-1.6, 1.6]:
		_caixa(Vector3(0.28, 3.2, 0.28), Vector3(sx, 1.6, -0.4), mad)
	_caixa(Vector3(3.8, 0.3, 0.3), Vector3(0, 3.25, -0.4), mad)
	for k in 4:
		_modelo("kenney_train_kit/track-single.glb", Vector3(0, 0.02, 0.6 - k * 1.0), 0.0, 1.0)
	_modelo("kenney_train_kit/train-carriage-dirt.glb", Vector3(0, 0.05, 1.8), 0.0, 0.55)
	# tochas de brasa (o clã Brasa-Velha marca a entrada)
	for sx in [-2.1, 2.1]:
		_modelo("kaykit_dungeon/torch_mounted.gltf", Vector3(sx, 1.6, 0.2), 0.0, 0.9)
		_caixa(Vector3(0.18, 0.24, 0.18), Vector3(sx, 2.25, 0.4), _mat("brasa", Color("ff7a2a"), 4.0))
	luz_principal = _luz(Vector3(0, 2.2, 0.6), Color("ff8a3a"), 3.0, 9.0)
	_luz(Vector3(0, 1.0, -1.4), Color("ff5a1a"), 1.6, 4.0)
	_particulas(Color(1.0, 0.55, 0.2, 0.9), 30, Vector3(1.2, 0.3, 0.4), Vector3(0, 0.6, -1.2), 0.6)

func _portao() -> void:
	# portão de ferro da cripta, entre pilares, com degraus que descem e velas frias
	var pedra := _mat("pedra", Color("6a6c78"))
	_modelo("kenney_mini_dungeon/gate.glb", Vector3(0, 0, -0.4), 0.0, 2.6)
	for sx in [-2.0, 2.0]:
		_modelo("kaykit_dungeon/pillar.gltf", Vector3(sx, 0, -0.4), 0.0, 0.6)
		_caixa(Vector3(0.9, 0.5, 0.9), Vector3(sx, 0.25, -0.4), pedra, Vector3.ZERO, true)
	_caixa(Vector3(5.0, 0.5, 0.9), Vector3(0, 4.1, -0.4), pedra)
	_caixa(Vector3(5.6, 0.25, 1.1), Vector3(0, 4.45, -0.4), pedra)
	_caixa(Vector3(3.0, 0.06, 1.6), Vector3(0, 0.03, -1.6), _mat("escada", Color("1a1a22")))
	for k in 3:
		_caixa(Vector3(3.0, 0.12, 0.4), Vector3(0, -0.1 - k * 0.18, -1.0 - k * 0.4), pedra)
	_modelo("kaykit_dungeon/candle_triple.gltf", Vector3(-1.4, 0, 0.6), 0.0, 0.7)
	_modelo("kaykit_dungeon/candle_triple.gltf", Vector3(1.5, 0, 0.5), 1.0, 0.7)
	_modelo("kaykit_dungeon/rubble_half.gltf", Vector3(2.8, 0, 0.6), 0.5, 0.45)
	luz_principal = _luz(Vector3(0, 2.2, 1.2), Color("8ab8ff"), 3.4, 10.0)
	_luz(Vector3(0, 1.0, -1.6), Color("5ae0d0"), 1.6, 4.0)
	_particulas(Color(0.55, 0.95, 1.0, 0.7), 24, Vector3(1.4, 0.4, 0.4), Vector3(0, 0.5, -1.0), 0.4)

func _fenda() -> void:
	# fenda temporal: rachadura vertical brilhante com cacos flutuando e engrenagens girando
	var ciano := _mat("ciano", Color("5af0ff"), 3.0, 0.0, 0.8)
	var rosa := _mat("rosa", Color("ff5af0"), 2.6, 0.0, 0.75)
	var ouro := _mat("ouro", Color("d8b060"), 0.5, 0.85)
	var nucleo := _caixa(Vector3(0.5, 3.6, 0.12), Vector3(0, 2.0, 0), ciano, Vector3(0, 0, 0.08))
	_giram.append([nucleo, Vector3.ZERO, 0.0, "pulsa"])
	for k in 9:
		var h := 0.5 + k * 0.42
		var lado := -1.0 if k % 2 == 0 else 1.0
		var caco := _caixa(Vector3(0.35 + (k % 3) * 0.12, 0.22, 0.06), Vector3(lado * (0.3 + (k % 4) * 0.12), h, 0.05), rosa if k % 3 == 0 else ciano, Vector3(0, 0, lado * (0.4 + k * 0.1)))
		_giram.append([caco, Vector3.ZERO, 0.0, "flutua", caco.position, k * 0.7])
	for r in [1.6, 2.3]:
		var piv := Node3D.new()
		piv.position = Vector3(0, 2.0, 0)
		add_child(piv)
		var t := TorusMesh.new()
		t.inner_radius = r
		t.outer_radius = r + 0.12
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.material_override = ouro
		mi.rotation = Vector3(PI / 2, 0, 0)
		piv.add_child(mi)
		for d in 12:
			var ang := d * TAU / 12.0
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.25, 0.08)
			b.mesh = bm
			b.material_override = ouro
			b.position = Vector3(sin(ang), cos(ang), 0) * (r + 0.15)
			b.rotation.z = -ang
			piv.add_child(b)
		_giram.append([piv, Vector3(0, 0, 1), 0.35 if r < 2 else -0.22])
	# base: chão rachado e cristais
	_caixa(Vector3(3.4, 0.08, 1.6), Vector3(0, 0.04, 0), _mat("chao", Color("1a1428"), 0.6))
	_modelo("kenney_space_kit/rock_crystals.glb", Vector3(-2.2, 0, 0.4), 0.3, 1.6)
	_modelo("kenney_space_kit/rock_crystals.glb", Vector3(2.0, 0, -0.3), 2.0, 1.3)
	_modelo("kenney_space_station/structure-barrier.glb", Vector3(-2.6, 0, 1.6), 0.4, 1.2)
	_modelo("kenney_space_station/structure-barrier.glb", Vector3(2.6, 0, 1.6), -0.4, 1.2)
	luz_principal = _luz(Vector3(0, 2.2, 0.8), Color("5af0ff"), 3.2, 10.0)
	_luz(Vector3(0, 1.0, -0.6), Color("ff5af0"), 2.0, 6.0)
	_particulas(Color(0.4, 0.95, 1.0, 0.9), 60, Vector3(0.5, 1.6, 0.2), Vector3(0, 2.0, 0), 0.5)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(1.2, 3.0, 0.6)
	cs.shape = s
	cs.position.y = 1.5
	sb.add_child(cs)
	add_child(sb)

func _process(delta: float) -> void:
	_t += delta
	for gi in _giram:
		var n: Node3D = gi[0]
		if gi.size() <= 3:
			n.rotate_object_local(gi[1], float(gi[2]) * delta)
		elif gi[3] == "pulsa":
			n.scale = Vector3(1.0 + 0.15 * sin(_t * 5.0), 1.0, 1.0)
		elif gi[3] == "flutua":
			n.position = gi[4] + Vector3(0, 0.08 * sin(_t * 1.7 + float(gi[5])), 0)
	if luz_principal:
		luz_principal.light_energy = luz_principal.light_energy * 0.9 + (2.6 + 0.4 * sin(_t * 7.0)) * 0.1

# ------------------------------------------------------------------ interação
func _physics_process(_delta: float) -> void:
	if not pronto or mapa == null or mapa.get("jogador") == null:
		return
	var j: Node3D = mapa.jogador
	var d := Vector2(j.global_position.x - global_position.x, j.global_position.z - global_position.z).length()
	perto = d < raio_interacao
	prompt.visible = perto and menu == null
	if prompt.visible:
		prompt.text = "[E] Entrar · %s" % Registro.nome(String(dados.area))

func _unhandled_input(event: InputEvent) -> void:
	if not pronto:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if menu:
			if event.physical_keycode == KEY_ESCAPE:
				fechar_menu()
				get_viewport().set_input_as_handled()
			elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
				entrar()
				get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_E and perto and not bool(mapa.get("demo_mode")):
			abrir_menu()
			get_viewport().set_input_as_handled()

func tema_id() -> String:
	return String(destino.get("tema", dados.get("area", "")))

func andar_de_entrada() -> int:
	return int(Registro.ponto(String(dados.area), String(dados.ponto)).get("andar", 1))

func abrir_menu() -> void:
	if menu:
		return
	mapa.demo_mode = true
	menu = CanvasLayer.new()
	menu.layer = 20
	menu.name = "MenuEntrada"
	add_child(menu)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.45)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(fundo)
	var painel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.07, 0.94)
	var cor := Color(String(tema_dados.get("paleta", {}).get("leitura", "ffd27a")))
	sb.border_color = cor
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	painel.add_theme_stylebox_override("panel", sb)
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(620, 0)
	painel.position = Vector2(-310, -190)
	menu.add_child(painel)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	painel.add_child(caixa)
	var t := Label.new()
	t.text = Registro.nome(String(dados.area))
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", cor)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(t)
	var sub := Label.new()
	sub.text = String(tema_dados.get("subtitulo", ""))
	sub.add_theme_font_size_override("font_size", 18)
	sub.modulate = Color(1, 1, 1, 0.8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(sub)
	var tema := tema_id()
	var prof := Sessao.profundidade_de(tema)
	var lista: Array = Sessao.andares(tema)
	var chefe := Sessao.dados_inimigo(String(tema_dados.get("chefe", "")))
	var linhas := [
		"Tema: %s" % String(tema_dados.get("inimigo_tema", "")),
		"Entrada: andar %d%s" % [andar_de_entrada(), "  (Túneis de Brasa)" if String(dados.ponto) == "tuneis_de_brasa" else ""],
		"Profundidade alcançada: %s" % ("nenhuma ainda" if prof <= 0 else "andar %d de %d" % [prof, int(lista.back()) if lista.size() > 0 else 0]),
		"Chefe do último andar: %s%s" % [String(chefe.get("nome", "?")), "  ✔ derrotado" if Sessao.chefes_derrotados.has(tema) else ""],
	]
	for l in linhas:
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_size_override("font_size", 20)
		caixa.add_child(lb)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 24)
	caixa.add_child(botoes)
	botao_entrar = Button.new()
	botao_entrar.text = "  Entrar  "
	botao_entrar.add_theme_font_size_override("font_size", 24)
	botao_entrar.pressed.connect(entrar)
	botoes.add_child(botao_entrar)
	var cancelar := Button.new()
	cancelar.text = "  Cancelar  "
	cancelar.add_theme_font_size_override("font_size", 24)
	cancelar.pressed.connect(fechar_menu)
	botoes.add_child(cancelar)
	var dica := Label.new()
	dica.text = "Enter entra · Esc cancela"
	dica.modulate = Color(1, 1, 1, 0.55)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(dica)
	botao_entrar.call_deferred("grab_focus")
	menu_aberto.emit()

func fechar_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null
	mapa.demo_mode = false

func entrar(semente := -1) -> int:
	var tema := tema_id()
	Sessao.iniciar(tema, area_id, entrada_id, andar_de_entrada(), semente)
	entrando.emit(String(dados.area), String(dados.ponto))
	return Registro.viajar(get_tree(), String(dados.area), String(dados.ponto))

# ------------------------------------------------------------------ capturas
func _capturas(pasta: String) -> void:
	get_window().size = Vector2i(1600, 900)
	mapa.jogador.position = ponto_de_volta() + Vector3(0, 0.3, 0)
	for i in 40:
		await get_tree().physics_frame
	var base := pasta.path_join("%s_entrada_%s" % [area_id, entrada_id])
	get_viewport().get_texture().get_image().save_png(base + "_prompt.png")
	print("[entrada_masmorra] captura: ", base + "_prompt.png")
	abrir_menu()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(base + "_menu.png")
	print("[entrada_masmorra] captura: ", base + "_menu.png")
	fechar_menu()
	# vista de cima mais aberta para conferir a posição
	if mapa.get("zoom") != null:
		mapa.zoom = 2.2
	for i in 8:
		await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png(base + "_local.png")
	print("[entrada_masmorra] captura: ", base + "_local.png")
	get_tree().quit()
