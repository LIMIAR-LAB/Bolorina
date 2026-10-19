extends Node3D
## Detritos do campo (estilo Standard Farm): pedra (picareta), galho/toco/arvore (machado), mato (foice).
## Arvores reusam o ChoppableTree da V6 (3 golpes, toras no chao); depois o toco sai com mais um golpe.
const ChoppableTree = preload("res://scripts/choppable_tree.gd")
const REGRAS := {
	"pedra": {"ferramenta": "picareta", "golpes": 1, "item": "pedra", "qtd": 1},
	"galho": {"ferramenta": "machado", "golpes": 1, "item": "madeira", "qtd": 1},
	"toco": {"ferramenta": "machado", "golpes": 3, "item": "madeira", "qtd": 3},
	"mato": {"ferramenta": "foice", "golpes": 1, "item": "fibra", "qtd": 1},
	"arvore": {"ferramenta": "machado", "golpes": 3, "item": "madeira", "qtd": 3},
}
var g
var mapa := {}  # Vector2i -> {tipo, hp, no}
var mato_mesh: ArrayMesh
var mato_mesh2: ArrayMesh
var mat_galho: StandardMaterial3D
var mat_toco: StandardMaterial3D
var mat_toco_topo: StandardMaterial3D
var rng := RandomNumberGenerator.new()

func montar(game) -> void:
	g = game
	name = "Detritos"
	rng.seed = 5511
	var kit = g.vila.kit
	mato_mesh = kit.foliage_mesh(16, Vector3(0.42, 0.55, 0.42), Color("3f5f22"), Color("9aa83e"), Color(), 0.0, 311)
	mato_mesh2 = kit.foliage_mesh(14, Vector3(0.38, 0.45, 0.38), Color("4d6a26"), Color("b8a845"), Color("e9d9a0"), 0.25, 312)
	mat_galho = StandardMaterial3D.new()
	mat_galho.albedo_color = Color("6b4528")
	mat_galho.roughness = 1.0
	mat_toco = StandardMaterial3D.new()
	mat_toco.albedo_color = Color("6e4a2c")
	mat_toco.roughness = 1.0
	mat_toco_topo = StandardMaterial3D.new()
	mat_toco_topo.albedo_color = Color("c49a62")
	for d in g.vila.data.fazenda.detritos:
		var c := Vector2i(int(d.celula[0]), int(d.celula[1]))
		var k: String = g.estado.chave(c)
		if g.estado.removidos.has(k):
			continue
		var tipo := String(d.tipo)
		var info = {"tipo": tipo, "hp": int(REGRAS[tipo].golpes), "no": null}
		if tipo == "arvore":
			var st: Dictionary = g.estado.arvores.get(k, {})
			if bool(st.get("removida", false)):
				continue
			var tr: Node3D = ChoppableTree.new()
			g.ground.add_child(tr)
			tr.setup(g.art_world, _pos(c), bool(st.get("derrubada", false)), int(st.get("toras", 0)))
			if bool(st.get("derrubada", false)):
				tr.fall_pivot.visible = false
				tr.stump.visible = true
				tr.trunk_body.process_mode = Node.PROCESS_MODE_DISABLED
			tr.canopy_material.shader = load("res://shaders/reference_leaves.gdshader")
			tr.rotation.y = rng.randf() * TAU
			info.no = tr
		else:
			info.no = _criar(tipo, c)
		mapa[c] = info

func _pos(c: Vector2i) -> Vector3:
	return Vector3(c.x, g.vila.altura(float(c.x), float(c.y)), c.y)

func _criar(tipo: String, c: Vector2i) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "%s_%d_%d" % [tipo, c.x, c.y]
	n.position = _pos(c)
	n.rotation.y = rng.randf() * TAU
	n.set_meta("detrito", tipo)
	add_child(n)
	var kit = g.vila.kit
	match tipo:
		"pedra":
			for i in rng.randi_range(2, 3):
				var r: MeshInstance3D = kit.ball(n, Vector3(rng.randf_range(-0.18, 0.18), 0.1, rng.randf_range(-0.18, 0.18)), Vector3(rng.randf_range(0.3, 0.5), rng.randf_range(0.22, 0.36), rng.randf_range(0.3, 0.45)), kit.mats.lichen_rock)
				r.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, 0)
			_corpo(n, 0.32, 0.4)
		"galho":
			for i in 2:
				var a := Vector3(rng.randf_range(-0.4, -0.2), 0.05, rng.randf_range(-0.2, 0.2))
				var b := Vector3(rng.randf_range(0.2, 0.42), 0.06, rng.randf_range(-0.2, 0.2))
				_graveto(n, a, b, 0.06)
				_graveto(n, a.lerp(b, 0.5), a.lerp(b, 0.5) + Vector3(0.1, 0.03, 0.22), 0.035)
		"mato":
			kit.foliage_instance(n, mato_mesh if rng.randf() < 0.6 else mato_mesh2)
		"toco":
			var m: MeshInstance3D = MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.3
			cy.bottom_radius = 0.38
			cy.height = 0.42
			cy.radial_segments = 9
			m.mesh = cy
			m.material_override = mat_toco
			m.position.y = 0.2
			n.add_child(m)
			var topo := MeshInstance3D.new()
			var tc := CylinderMesh.new()
			tc.top_radius = 0.27
			tc.bottom_radius = 0.27
			tc.height = 0.02
			tc.radial_segments = 9
			topo.mesh = tc
			topo.material_override = mat_toco_topo
			topo.position.y = 0.42
			n.add_child(topo)
			for i in 3:
				var a := TAU * i / 3.0 + 0.4
				_graveto(n, Vector3(cos(a) * 0.25, 0.08, sin(a) * 0.25), Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55), 0.09)
			_corpo(n, 0.36, 0.5)
	return n

func _graveto(n: Node3D, a: Vector3, b: Vector3, w: float) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(w, w, a.distance_to(b))
	m.mesh = bx
	m.material_override = mat_galho
	m.position = (a + b) * 0.5
	m.look_at_from_position(m.position, b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	n.add_child(m)

func _corpo(n: Node3D, r: float, h: float) -> void:
	var body := StaticBody3D.new()
	body.set_meta("detrito", true)
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position.y = h * 0.5
	body.add_child(cs)
	n.add_child(body)

func em(c: Vector2i) -> bool:
	return mapa.has(c)

func tipo(c: Vector2i) -> String:
	return String(mapa[c].tipo) if mapa.has(c) else ""

func golpe(c: Vector2i, ferramenta: String) -> String:
	if not mapa.has(c):
		return "Nada aqui para a %s." % ferramenta
	var d: Dictionary = mapa[c]
	var r: Dictionary = REGRAS[d.tipo]
	if String(r.ferramenta) != ferramenta:
		return "Isso pede a %s." % String(r.ferramenta)
	var k: String = g.estado.chave(c)
	if d.tipo == "arvore":
		var tr = d.no
		if not tr.felled:
			tr.cooldown = 0.0
			var txt: String = tr.hit(Vector3(c.x, tr.global_position.y, c.y))
			g.estado.arvores[k] = {"derrubada": tr.felled, "toras": tr.logs, "removida": false}
			if tr.felled:
				# recolhe as toras ao terminar a queda
				get_tree().create_timer(1.6).timeout.connect(func(): _recolher_toras(c))
			return txt.replace("F usa o machado", "use o machado").replace("E recolhe", "as toras vao para a mochila;")
		var n: int = tr.collect(Vector3(c.x, tr.global_position.y, c.y))
		if n > 0:
			g.estado.somar("madeira", n)
			g.estado.arvores[k] = {"derrubada": true, "toras": 0, "removida": false}
			return "+%d madeira (toras)." % n
		# arranca o toco
		g.estado.somar("madeira", 1)
		g.estado.arvores[k] = {"derrubada": true, "toras": 0, "removida": true}
		_sumir(tr)
		mapa.erase(c)
		_popup(c, "+1 madeira")
		return "Toco arrancado. +1 madeira."
	d.hp = int(d.hp) - 1
	_lascas(c, d.tipo)
	if d.hp > 0:
		var tw := create_tween()
		tw.tween_property(d.no, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
		tw.tween_property(d.no, "scale", Vector3.ONE, 0.12)
		return "%s: faltam %d golpe(s)." % [String(d.tipo).capitalize(), d.hp]
	g.estado.somar(String(r.item), int(r.qtd))
	g.estado.removidos[k] = true
	_sumir(d.no)
	mapa.erase(c)
	_popup(c, "+%d %s" % [int(r.qtd), String(r.item)])
	return "+%d %s (total %d)." % [int(r.qtd), String(r.item), g.estado.qtd(String(r.item))]

func _recolher_toras(c: Vector2i) -> void:
	if not mapa.has(c):
		return
	var tr = mapa[c].no
	var n: int = tr.collect(Vector3(c.x, tr.global_position.y, c.y))
	if n > 0:
		g.estado.somar("madeira", n)
		g.estado.arvores[g.estado.chave(c)] = {"derrubada": true, "toras": 0, "removida": false}
		g.estado.salvar()
		_popup(c, "+%d madeira" % n)
		g.ui.atualizar()

func _sumir(n: Node3D) -> void:
	for b in n.find_children("*", "StaticBody3D", true, false):
		b.process_mode = Node.PROCESS_MODE_DISABLED
		for cs in b.get_children():
			if cs is CollisionShape3D:
				cs.disabled = true
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(0.05, 0.05, 0.05), 0.18)
	tw.tween_callback(n.queue_free)

func _lascas(c: Vector2i, tipo: String) -> void:
	var cor := Color("9a9a90") if tipo == "pedra" else (Color("7fae46") if tipo == "mato" else Color("a3794a"))
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.06, 0.06, 0.06)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = cor
	m.material = mt
	p.mesh = m
	p.position = _pos(c) + Vector3(0, 0.25, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func _popup(c: Vector2i, txt: String) -> void:
	var l: Label3D = Label3D.new()
	l.text = txt
	l.font_size = 40
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color("fff1b8")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.position = _pos(c) + Vector3(0, 1.0, 0)
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
