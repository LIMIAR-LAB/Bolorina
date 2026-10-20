extends Node3D
## Prototipo jogavel de masmorra procedural (placeholder): monta o andar do gerador em blocos,
## Vale anda (WASD), orcs/props sao marcadores (sem combate ainda), escada = proximo andar,
## portal na sala inicial = volta para a vila (entrada das ruinas). R = nova semente. Esc/F12 sai.
const Gerador = preload("res://scripts/masmorra/masmorra_gerador.gd")
const ValeFidelidade = preload("res://scripts/modular/vale_fidelidade.gd")
const SALA := Vector2(14.0, 10.0)
const PASSO := Vector2(18.0, 14.0)
const CAMERA_YAW := PI / 4.0
var gerenciador
var estado
var semente := 1
var andar := 1
var mapa: Dictionary
var raiz: Node3D
var player: CharacterBody3D
var sprite
var camera: Camera3D
var label: Label
var escada := Vector3.ZERO
var portal := Vector3.ZERO
var t := 0.0
var orcs: Array = []
var mats := {}

func _ready() -> void:
	if OS.get_environment("MASMORRA_SEMENTE") != "":
		semente = int(OS.get_environment("MASMORRA_SEMENTE"))
	elif estado != null:
		semente = int(estado.dia) * 13 + 5
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, 35, 0)
	luz.light_energy = 1.1
	luz.shadow_enabled = true
	add_child(luz)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("120d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a5a7a")
	env.ambient_light_energy = 0.7
	amb.environment = env
	add_child(amb)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.0
	add_child(camera)
	camera.make_current()
	player = CharacterBody3D.new()
	player.name = "Vale"
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	col.shape = cap
	col.position.y = 0.6
	player.add_child(col)
	add_child(player)
	sprite = ValeFidelidade.new()
	sprite.preparar(1.48)
	player.add_child(sprite)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(20, 16)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(label)
	for nome in ["chao", "chao_inicio", "chao_saida", "chao_tesouro", "chao_descanso", "parede", "porta"]:
		var m := StandardMaterial3D.new()
		m.albedo_color = {"chao": Color("4b4250"), "chao_inicio": Color("4f5a4a"), "chao_saida": Color("5a3f3a"), "chao_tesouro": Color("6a5a32"), "chao_descanso": Color("3e5262"), "parede": Color("2c2430"), "porta": Color("6e5a44")}[nome]
		m.roughness = 1.0
		mats[nome] = m
	montar()

func montar() -> void:
	if raiz:
		raiz.queue_free()
	orcs.clear()
	raiz = Node3D.new()
	raiz.name = "Andar"
	add_child(raiz)
	mapa = Gerador.gerar(semente, andar)
	for c in mapa.salas:
		_sala(mapa.salas[c])
	for e in mapa.arestas:
		_corredor(e[0], e[1])
	player.position = _centro(mapa.inicio) + Vector3(0, 0.1, 1.5)
	player.velocity = Vector3.ZERO
	_atualizar_texto()

func _centro(c: Vector2i) -> Vector3:
	return Vector3(c.x * PASSO.x, 0, c.y * PASSO.y)

func _bloco(pos: Vector3, tam: Vector3, mat: String, solido: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mats[mat]
	mi.position = pos
	raiz.add_child(mi)
	if solido:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = tam
		cs.shape = sh
		b.add_child(cs)
		b.position = pos
		raiz.add_child(b)

func _sala(s: Dictionary) -> void:
	var c0: Vector3 = _centro(s.celula)
	var tipo: String = s.tipo
	_bloco(c0 + Vector3(0, -0.25, 0), Vector3(SALA.x, 0.5, SALA.y), "chao_" + tipo if mats.has("chao_" + tipo) else "chao", true)
	# paredes com vao de porta (3 m) onde ha conexao
	var hx := SALA.x / 2.0
	var hz := SALA.y / 2.0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var porta: bool = s.portas.has(d)
		var comp := SALA.y if d.x != 0 else SALA.x
		var meio := c0 + Vector3(d.x * hx, 0.9, d.y * hz)
		if not porta:
			_bloco(meio, Vector3(0.5, 1.8, comp) if d.x != 0 else Vector3(comp, 1.8, 0.5), "parede", true)
		else:
			var seg := (comp - 3.0) / 2.0
			for sgn in [-1, 1]:
				var off: float = (seg / 2.0 + 1.5) * sgn
				var p := meio + (Vector3(0, 0, off) if d.x != 0 else Vector3(off, 0, 0))
				_bloco(p, Vector3(0.5, 1.8, seg) if d.x != 0 else Vector3(seg, 1.8, 0.5), "parede", true)
	var rot := Label3D.new()
	rot.text = {"inicio": "ENTRADA", "saida": "ESCADA ↓", "tesouro": "TESOURO", "descanso": "DESCANSO", "combate": ""}[tipo]
	rot.font_size = 48
	rot.pixel_size = 0.01
	rot.outline_size = 10
	rot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rot.position = c0 + Vector3(0, 2.6, -hz + 1.0)
	raiz.add_child(rot)
	for pr in s.props:
		var pp: Vector2 = pr.pos
		_prop(String(pr.tipo), c0 + Vector3(pp.x, 0, pp.y))
	var r := RandomNumberGenerator.new()
	r.seed = hash(s.celula) + semente
	for i in int(s.inimigos):
		_orc(c0 + Vector3(r.randf_range(-4.5, 4.5), 0, r.randf_range(-3.0, 3.0)))
	if tipo == "saida":
		escada = c0
		_bloco(c0 + Vector3(0, 0.05, 0), Vector3(2.0, 0.1, 2.0), "porta", false)
	if tipo == "inicio":
		portal = c0 + Vector3(0, 0, -hz + 1.6)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color("8fd0ff")
		pm.emission_enabled = true
		pm.emission = Color("4aa8ff")
		pm.emission_energy_multiplier = 1.5
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.8
		cyl.bottom_radius = 0.8
		cyl.height = 0.08
		mi.mesh = cyl
		mi.material_override = pm
		mi.position = portal + Vector3(0, 0.05, 0)
		raiz.add_child(mi)

func _corredor(a: Vector2i, b: Vector2i) -> void:
	var pa := _centro(a)
	var pb := _centro(b)
	var meio := (pa + pb) / 2.0
	var horizontal := a.y == b.y
	var comp := (PASSO.x - SALA.x) if horizontal else (PASSO.y - SALA.y)
	_bloco(meio + Vector3(0, -0.25, 0), Vector3(comp + 0.6, 0.5, 3.0) if horizontal else Vector3(3.0, 0.5, comp + 0.6), "porta", true)
	for sgn in [-1, 1]:
		_bloco(meio + (Vector3(0, 0.9, 1.75 * sgn) if horizontal else Vector3(1.75 * sgn, 0.9, 0)), Vector3(comp + 0.6, 1.8, 0.5) if horizontal else Vector3(0.5, 1.8, comp + 0.6), "parede", true)

func _prop(tipo: String, pos: Vector3) -> void:
	var arq: String = {"caixote": "prop_caixote_inteiro", "urna": "prop_urna_inteiro", "rocha": "prop_rocha_inteiro"}[tipo]
	var cam := "res://art/combate/props/%s.png" % arq
	var s := Sprite3D.new()
	if ResourceLoader.exists(cam):
		s.texture = load(cam)
	s.pixel_size = 0.03
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.offset = Vector2(0, 12)
	s.position = pos
	s.set_meta("prop", tipo)
	raiz.add_child(s)
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.7, 0.8, 0.7)
	cs.shape = sh
	cs.position.y = 0.4
	b.add_child(cs)
	b.position = pos
	raiz.add_child(b)

func _orc(pos: Vector3) -> void:
	var s := Sprite3D.new()
	var cam := "res://art/combate/orc/orc_idle.png"
	if ResourceLoader.exists(cam):
		var tex: Texture2D = load(cam)
		s.texture = tex
		s.hframes = maxi(1, int(tex.get_width() / 72))
		s.vframes = maxi(1, int(tex.get_height() / 72))
	s.pixel_size = 0.025
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.offset = Vector2(0, 31)
	s.position = pos
	s.set_meta("inimigo", "orc")
	raiz.add_child(s)
	orcs.append(s)

func _atualizar_texto() -> void:
	var n_ini := 0
	for c in mapa.salas:
		n_ini += int(mapa.salas[c].inimigos)
	label.text = "MASMORRA (protótipo) — Andar %d   semente %d\n%d salas · %d orcs (marcadores, sem combate ainda)\nWASD andar · escada ↓ = próximo andar · portal azul = voltar às ruínas · R nova semente · Esc sair" % [andar, semente, mapa.salas.size(), n_ini]

func _physics_process(delta: float) -> void:
	t += delta
	var inp := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	inp += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	inp = inp.limit_length(1.0)
	var mundo := Vector3(inp.x, 0, inp.y).rotated(Vector3.UP, CAMERA_YAW)
	var rapido := Input.is_physical_key_pressed(KEY_SHIFT)
	player.velocity = Vector3(mundo.x, 0, mundo.z) * (6.0 if rapido else 3.6) + Vector3(0, player.velocity.y - 20.0 * delta, 0)
	player.move_and_slide()
	if player.is_on_floor():
		player.velocity.y = 0
	if player.position.y < -6.0:
		player.position = _centro(mapa.inicio) + Vector3(0, 0.5, 1.5)
	sprite.set_direction(inp if inp.length() > 0.1 else Vector2.ZERO)
	sprite.set_motion(inp.length() > 0.1, rapido, false, false)
	camera.position = player.position + Vector3(20, 20, 20)
	camera.look_at(player.position, Vector3.UP)
	for o in orcs:
		if is_instance_valid(o):
			o.frame = int(t * 8.0) % maxi(1, o.hframes * o.vframes)
	var pp := Vector2(player.position.x, player.position.z)
	if pp.distance_to(Vector2(escada.x, escada.z)) < 1.1:
		descer()
	elif pp.distance_to(Vector2(portal.x, portal.z)) < 1.5 and gerenciador and not gerenciador.ocupado:
		gerenciador.ir("vila", "da_masmorra")

func descer() -> void:
	andar += 1
	montar()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_R:
		semente += 1
		andar = 1
		montar()
	elif event.physical_keycode == KEY_ESCAPE and gerenciador:
		gerenciador.ir("vila", "da_masmorra")
