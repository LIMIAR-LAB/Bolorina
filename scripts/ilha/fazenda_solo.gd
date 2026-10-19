extends Node3D
## Solo arado + culturas (estagios 0-3 por dia regado). Terra molhada fica mais escura.
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
var g
var nos := {}      # Vector2i -> MeshInstance3D (terra)
var plantas := {}  # Vector2i -> Node3D
var mat_seca: StandardMaterial3D
var mat_molhada: StandardMaterial3D
var mat_sulco: StandardMaterial3D
var mat_nabo: StandardMaterial3D
var mat_nabo_topo: StandardMaterial3D
var rng := RandomNumberGenerator.new()

func montar(game) -> void:
	g = game
	name = "Solo"
	mat_seca = StandardMaterial3D.new()
	mat_seca.albedo_color = Color("7a5a3c")
	mat_seca.roughness = 1.0
	mat_molhada = StandardMaterial3D.new()
	mat_molhada.albedo_color = Color("3e2c1e")
	mat_molhada.roughness = 0.7
	mat_molhada.metallic_specular = 0.25
	mat_sulco = StandardMaterial3D.new()
	mat_sulco.albedo_color = Color(0, 0, 0, 0.22)
	mat_sulco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_nabo = StandardMaterial3D.new()
	mat_nabo.albedo_color = Color("efe6f0")
	mat_nabo_topo = StandardMaterial3D.new()
	mat_nabo_topo.albedo_color = Color("9a4f9e")
	# canteiro inicial (ja arado) na primeira vez
	if g.estado.solo.is_empty():
		for c in g.vila.data.fazenda.canteiro_inicial:
			g.estado.arar(Vector2i(int(c[0]), int(c[1])))
	aplicar()

func tem(c: Vector2i) -> bool:
	return g.estado.solo.has(Estado.chave(c))

func dados(c: Vector2i):
	return g.estado.solo.get(Estado.chave(c))

func vazio(c: Vector2i) -> bool:
	var s = dados(c)
	return s != null and String(s.cultura) == ""

func maduro(c: Vector2i) -> bool:
	var s = dados(c)
	return s != null and String(s.cultura) != "" and int(s.estagio) >= 3

func arar(c: Vector2i) -> void:
	g.estado.arar(c)
	_atualizar(c)

func molhar(c: Vector2i) -> String:
	if g.estado.regador <= 0:
		return "Regador vazio. Encha no lago ou no poco."
	var s = dados(c)
	if bool(s.molhada):
		return "Ja esta molhada."
	g.estado.molhar(c)
	_atualizar(c)
	_gotas(c)
	return "Terra regada (regador %d)." % g.estado.regador

func plantar(c: Vector2i, cultura: String) -> String:
	if not tem(c):
		return "Are a terra com a enxada antes de plantar."
	if not vazio(c):
		return "Ja tem algo plantado aqui."
	if g.estado.qtd("semente_" + cultura) <= 0:
		return "Sem sementes de %s." % cultura
	g.estado.plantar(c, cultura)
	_atualizar(c)
	return "%s plantado. Regue todo dia (%d dias regados ate colher)." % [String(Estado.CULTURAS[cultura].nome), int(Estado.CULTURAS[cultura].dias)]

func colher(c: Vector2i) -> String:
	var cult: String = g.estado.colher(c)
	if cult == "":
		return "Ainda nao esta maduro."
	_atualizar(c)
	return "Colheu 1 %s! (total %d)" % [String(Estado.CULTURAS[cult].nome).to_lower(), g.estado.qtd(cult)]

func aplicar() -> void:
	for k in g.estado.solo:
		_atualizar(Estado.celula(k))
	for c in nos.keys():
		if not tem(c):
			nos[c].queue_free()
			nos.erase(c)

func cada_quadro() -> void:
	pass

func _atualizar(c: Vector2i) -> void:
	var s = dados(c)
	if s == null:
		return
	var h: float = g.vila.altura(float(c.x), float(c.y))
	if not nos.has(c):
		var m: MeshInstance3D = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.96, 0.06, 0.96)
		m.mesh = b
		m.position = Vector3(c.x, h + 0.015, c.y)
		m.name = "Terra_%d_%d" % [c.x, c.y]
		add_child(m)
		for i in 3:
			var sl := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.86, 0.012, 0.07)
			sl.mesh = sb
			sl.material_override = mat_sulco
			sl.position = Vector3(0, 0.031, -0.28 + i * 0.28)
			m.add_child(sl)
		nos[c] = m
	nos[c].material_override = mat_molhada if bool(s.molhada) else mat_seca
	nos[c].set_meta("molhada", bool(s.molhada))
	if plantas.has(c):
		plantas[c].queue_free()
		plantas.erase(c)
	if String(s.cultura) != "":
		plantas[c] = _planta(c, String(s.cultura), int(s.estagio), h)

func _planta(c: Vector2i, cultura: String, estagio: int, h: float) -> Node3D:
	var kit = g.vila.kit
	var n: Node3D = Node3D.new()
	n.name = "Planta_%s_%d" % [cultura, estagio]
	n.position = Vector3(c.x, h + 0.05, c.y)
	n.set_meta("cultura", cultura)
	n.set_meta("estagio", estagio)
	add_child(n)
	rng.seed = c.x * 7919 + c.y * 104729
	if estagio == 0:
		for i in 3:
			kit.ball(n, Vector3(rng.randf_range(-0.15, 0.15), 0.02, rng.randf_range(-0.15, 0.15)), Vector3(0.06, 0.04, 0.06), mat_seca if false else _mat_semente())
		return n
	match cultura:
		"nabo":
			var folha_c := Color("5d8a34")
			kit.foliage_instance(n, kit.foliage_mesh(4 + estagio * 5, Vector3(0.14 + estagio * 0.08, 0.12 + estagio * 0.09, 0.14 + estagio * 0.08), Color("3f6b24"), folha_c, Color(), 0.0, 900 + estagio), Vector3(0, 0.02, 0))
			if estagio >= 3:
				kit.ball(n, Vector3(0, 0.08, 0), Vector3(0.3, 0.26, 0.3), mat_nabo)
				kit.ball(n, Vector3(0, 0.16, 0), Vector3(0.22, 0.12, 0.22), mat_nabo_topo)
		"couve":
			if estagio < 3:
				kit.foliage_instance(n, kit.foliage_mesh(5 + estagio * 6, Vector3(0.16 + estagio * 0.09, 0.12 + estagio * 0.06, 0.16 + estagio * 0.09), Color("3f6b30"), Color("86ad4c"), Color(), 0.0, 910 + estagio), Vector3(0, 0.02, 0))
			else:
				for k in 3:
					kit.ball(n, Vector3(0, 0.12 + k * 0.05, 0), Vector3(0.48 - k * 0.1, 0.22, 0.48 - k * 0.1), kit.mats.kit_couve)
				kit.foliage_instance(n, kit.foliage_mesh(18, Vector3(0.42, 0.25, 0.42), Color("4f7a35"), Color("8fb050"), Color(), 0.0, 60), Vector3(0, 0.03, 0))
		"abobora":
			kit.foliage_instance(n, kit.foliage_mesh(8 + estagio * 12, Vector3(0.22 + estagio * 0.08, 0.14 + estagio * 0.06, 0.22 + estagio * 0.08), Color("3d6526"), Color("7b9a36"), Color("e5b73b"), 0.1 if estagio == 2 else 0.0, 920 + estagio), Vector3(0, 0.03, 0))
			if estagio >= 3:
				kit._pumpkin(n, Vector3(0.04, 0.17, 0.0), 1.45)
	return n

var _ms: StandardMaterial3D
func _mat_semente() -> StandardMaterial3D:
	if _ms == null:
		_ms = StandardMaterial3D.new()
		_ms.albedo_color = Color("d9c38a")
	return _ms

func _gotas(c: Vector2i) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.45
	p.explosiveness = 0.8
	p.direction = Vector3.DOWN
	p.spread = 25
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -9, 0)
	var m := SphereMesh.new()
	m.radius = 0.03
	m.height = 0.07
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("9cd0ea")
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mt
	p.mesh = m
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, 0.05, 0.35)
	p.position = Vector3(c.x, g.vila.altura(float(c.x), float(c.y)) + 0.7, c.y)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
