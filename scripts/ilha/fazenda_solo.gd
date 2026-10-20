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
			_limpar_chao(c, false)

## decoracao do chao (MultiMesh "Lote_*" da vila) por celula; terra arada esconde a dela
var _indice_chao := {}
var _indexado := false
var limpas := {}
func _indexar_chao() -> void:
	_indexado = true
	var raiz_cena: Node = g as Node
	if raiz_cena == null:
		return
	for n in raiz_cena.find_children("Lote_*", "MultiMeshInstance3D", true, false):
		var mi: MultiMeshInstance3D = n
		if mi.multimesh == null or mi.name == "Lote_laje":
			continue
		var mm: MultiMesh = mi.multimesh
		for i in mm.instance_count:
			var t: Transform3D = mm.get_instance_transform(i)
			var gp: Vector3 = mi.global_transform * t.origin
			var c := Vector2i(roundi(gp.x), roundi(gp.z))
			if not _indice_chao.has(c):
				_indice_chao[c] = []
			_indice_chao[c].append([mm, i, t])

func _limpar_chao(c: Vector2i, limpar: bool) -> void:
	if not _indexado:
		_indexar_chao()
	if limpas.has(c) == limpar:
		return
	if limpar:
		limpas[c] = true
	else:
		limpas.erase(c)
	for e in _indice_chao.get(c, []):
		var t: Transform3D = e[2]
		var mm: MultiMesh = e[0]
		mm.set_instance_transform(int(e[1]), Transform3D(Basis().scaled(Vector3.ONE * 0.0001), t.origin) if limpar else t)

## refaz toda a terra (usado em testes/capturas ao trocar SOLO_V1)
func recriar() -> void:
	for c in nos.keys():
		nos[c].queue_free()
	nos.clear()
	for c in plantas.keys():
		plantas[c].queue_free()
	plantas.clear()
	_mats_solo.clear()
	for c in limpas.keys():
		_limpar_chao(c, false)
	aplicar()

func cada_quadro() -> void:
	pass

## estado visual do solo: "arada" (vazia), "semeada" (estagio 0), "plantada" (crescendo/pronta)
func estado_visual(c: Vector2i) -> String:
	var s = dados(c)
	if s == null:
		return ""
	if String(s.cultura) == "":
		return "arada"
	return "semeada" if int(s.estagio) == 0 else "plantada"

const PASTA_SOLO := "res://art/fazenda/solo/"
var _mats_solo := {}
var _mat_lado: StandardMaterial3D
## material pixel-art (tools/solo_fazenda.py); null se o PNG faltar (cai no visual antigo)
func _mat_solo(nome: String) -> StandardMaterial3D:
	if _mats_solo.has(nome):
		return _mats_solo[nome]
	if OS.get_environment("SOLO_V1") == "1":
		return null
	var mt: StandardMaterial3D = null
	var cam := ProjectSettings.globalize_path(PASTA_SOLO + nome + ".png")
	if FileAccess.file_exists(cam):
		var img := Image.load_from_file(cam)
		if img != null and not img.is_empty():
			mt = StandardMaterial3D.new()
			mt.albedo_texture = ImageTexture.create_from_image(img)
			mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mt.roughness = 0.75 if nome.ends_with("_molhada") else 1.0
			if nome.ends_with("_molhada"):
				mt.metallic_specular = 0.3
	_mats_solo[nome] = mt
	return mt

func _atualizar(c: Vector2i) -> void:
	var s = dados(c)
	if s == null:
		return
	var h: float = g.vila.altura(float(c.x), float(c.y))
	var ev := estado_visual(c)
	var nome_tex := ev + ("_molhada" if bool(s.molhada) else "")
	var mt := _mat_solo(nome_tex)
	if not nos.has(c):
		var m: MeshInstance3D = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.98, 0.05, 0.98)
		m.mesh = b
		m.position = Vector3(c.x, h + 0.012, c.y)
		m.name = "Terra_%d_%d" % [c.x, c.y]
		add_child(m)
		if mt != null:
			var topo := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.0, 1.0)
			topo.mesh = pm
			topo.name = "Topo"
			topo.position = Vector3(0, 0.026, 0)
			m.add_child(topo)
		else:
			for i in 3:
				var sl := MeshInstance3D.new()
				var sb := BoxMesh.new()
				sb.size = Vector3(0.86, 0.012, 0.07)
				sl.mesh = sb
				sl.material_override = mat_sulco
				sl.position = Vector3(0, 0.031, -0.28 + i * 0.28)
				m.add_child(sl)
		nos[c] = m
	var topo_n: MeshInstance3D = nos[c].get_node_or_null("Topo")
	if topo_n != null and mt != null:
		topo_n.material_override = mt
		if _mat_lado == null:
			_mat_lado = StandardMaterial3D.new()
			_mat_lado.albedo_color = Color("4a3220")
			_mat_lado.roughness = 1.0
		nos[c].material_override = _mat_lado
	else:
		nos[c].material_override = mat_molhada if bool(s.molhada) else mat_seca
	if mt != null:
		_limpar_chao(c, true)
	nos[c].set_meta("molhada", bool(s.molhada))
	nos[c].set_meta("estado_solo", ev)
	nos[c].set_meta("textura_solo", nome_tex if mt != null else "")
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
		if _mat_solo("semeada") != null:
			return n
		for i in 3:
			kit.ball(n, Vector3(rng.randf_range(-0.15, 0.15), 0.02, rng.randf_range(-0.15, 0.15)), Vector3(0.06, 0.04, 0.06), mat_seca if false else _mat_semente())
		return n
	if estagio in [1, 2] and _mat_solo("plantada") != null:
		_broto(n, estagio, cultura)
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

var _mat_broto: StandardMaterial3D
var _mat_broto_claro: StandardMaterial3D
func _broto(n: Node3D, estagio: int, cultura: String) -> void:
	if _mat_broto == null:
		_mat_broto = StandardMaterial3D.new()
		_mat_broto.albedo_color = Color("4f9a2e")
		_mat_broto.roughness = 0.8
		_mat_broto_claro = StandardMaterial3D.new()
		_mat_broto_claro.albedo_color = Color("8fd04a")
		_mat_broto_claro.roughness = 0.8
	var b := Node3D.new()
	b.name = "Broto"
	n.add_child(b)
	var alt := 0.16 if estagio == 1 else 0.28
	var haste := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.012
	hm.bottom_radius = 0.018
	hm.height = alt
	hm.radial_segments = 5
	hm.rings = 1
	haste.mesh = hm
	haste.material_override = _mat_broto
	haste.position = Vector3(0, alt * 0.5, 0)
	b.add_child(haste)
	var folhas := 2 if estagio == 1 else 4
	var tam := 0.12 if estagio == 1 else 0.17
	if cultura == "abobora":
		tam *= 1.25
	for i in folhas:
		var a := TAU * float(i) / float(folhas) + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		g.vila.kit.ball(b, d * tam * 0.75 + Vector3(0, alt * (0.95 if i % 2 == 0 else 0.7), 0), Vector3(tam * 1.4, tam * 0.35, tam * 0.8), _mat_broto_claro if i % 2 == 0 else _mat_broto)

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
