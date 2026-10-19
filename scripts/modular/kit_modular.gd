extends RefCounted
## Kit modular da vila V7 (fidelidade). Grade de 1 m (GRID); origem de cada peca = centro
## da celula/pegada no chao (y local 0); rotacao em passos de 90 graus (rot*90 em Y).
## Cada peca recebe metadados: modulo, pegada (celulas), categoria, recurso (colheita).
## Catalogo completo: docs/modulos.md
const GRID := 1.0
const ChoppableTree = preload("res://scripts/choppable_tree.gd")
const CATALOGO := {
	"casa": {"pegada": Vector2i(6,5), "categoria": "construcao"},
	"poco": {"pegada": Vector2i(2,2), "categoria": "construcao"},
	"ponte": {"pegada": Vector2i(3,7), "categoria": "construcao"},
	"cerca": {"pegada": Vector2i(1,1), "categoria": "cerca"},
	"poste_lampiao": {"pegada": Vector2i(1,1), "categoria": "luz"},
	"pilar_braseiro": {"pegada": Vector2i(1,1), "categoria": "luz"},
	"estandarte": {"pegada": Vector2i(1,1), "categoria": "decoracao"},
	"carroca_abobora": {"pegada": Vector2i(3,2), "categoria": "decoracao"},
	"menir_runa": {"pegada": Vector2i(2,2), "categoria": "marco"},
	"pilar_pedra": {"pegada": Vector2i(1,1), "categoria": "marco"},
	"ruina_arco": {"pegada": Vector2i(6,2), "categoria": "ruina"},
	"ruina_pilar": {"pegada": Vector2i(1,1), "categoria": "ruina"},
	"canteiro": {"pegada": Vector2i(1,1), "categoria": "cultivo"},
	"arvore_outono": {"pegada": Vector2i(2,2), "categoria": "recurso", "recurso": {"tipo": "madeira", "quantidade": 3, "golpes": 3}},
	"arvore_escura": {"pegada": Vector2i(2,2), "categoria": "recurso", "recurso": {"tipo": "madeira", "quantidade": 4, "golpes": 4}},
	"arvore_seca": {"pegada": Vector2i(1,1), "categoria": "recurso", "recurso": {"tipo": "galhos", "quantidade": 2, "golpes": 1}},
	"rocha": {"pegada": Vector2i(1,1), "categoria": "recurso", "recurso": {"tipo": "pedra", "quantidade": 2, "golpes": 2}},
	"arbusto_flor": {"pegada": Vector2i(1,1), "categoria": "recurso", "recurso": {"tipo": "fibra", "quantidade": 1, "golpes": 1}},
	"arbusto_escuro": {"pegada": Vector2i(2,2), "categoria": "decoracao"},
	"barril": {"pegada": Vector2i(1,1), "categoria": "decoracao"},
	"caixote": {"pegada": Vector2i(1,1), "categoria": "decoracao"},
	"corvo": {"pegada": Vector2i(1,1), "categoria": "ambiente"},
	"banco": {"pegada": Vector2i(2,1), "categoria": "mobilia"},
	"mesa": {"pegada": Vector2i(2,2), "categoria": "mobilia"},
	"cogumelos": {"pegada": Vector2i(1,1), "categoria": "recurso", "recurso": {"tipo": "cogumelo", "quantidade": 2, "golpes": 0}},
	"deck": {"pegada": Vector2i(3,3), "categoria": "construcao"},
}
var art
var mats := {}
var folhagem: ShaderMaterial
var rng := RandomNumberGenerator.new()
var luzes_fogo: Array[OmniLight3D] = []
var fogos: Array[Node3D] = []
var fumacas: Array[CPUParticles3D] = []
var sombras: Array[MeshInstance3D] = []
var _bola: SphereMesh

func setup(world) -> void:
	art = world
	rng.seed = 7707
	mats = art.materials
	folhagem = ShaderMaterial.new()
	folhagem.shader = load("res://shaders/fid_folhagem.gdshader")
	_bola = SphereMesh.new()
	_bola.radial_segments = 8
	_bola.rings = 5
	for entry in [["abobora","d0701f"],["abobora_escura","9a4a14"],["couve","5d8a3a"],["vermelho","6b1414"],["madeira_escura","3a2a1c"],["corvo","121216"],["dourado","c99a3f"],["palha","b8954e"]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(entry[1])
		m.roughness = 0.85
		mats["kit_"+entry[0]] = m

static func info(id: String) -> Dictionary:
	return CATALOGO.get(id, {"pegada": Vector2i(1,1), "categoria": "outro"})

func make(id: String, data: Dictionary = {}) -> Node3D:
	var node := Node3D.new()
	node.name = id
	var catalog := info(id)
	node.set_meta("modulo", id)
	node.set_meta("pegada", catalog.pegada)
	node.set_meta("categoria", catalog.categoria)
	if catalog.has("recurso"):
		node.set_meta("recurso", catalog.recurso)
	if has_method("_p_"+id):
		call("_p_"+id, node, data)
	else:
		push_warning("Modulo desconhecido: "+id)
	return node

# ---------------------------------------------------------------- primitivas
func box(parent: Node3D, pos: Vector3, size: Vector3, mat: String, solid := false) -> MeshInstance3D:
	return art.box(pos, size, mat, solid, parent)

func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: String) -> void:
	art._beam(a, b, width, mat, parent)

func ball(parent: Node3D, pos: Vector3, scale: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _bola
	m.material_override = mat
	m.position = pos
	m.scale = scale
	parent.add_child(m)
	return m

func solid_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	body.position = pos + Vector3(0, height*0.5, 0)
	body.add_child(col)
	parent.add_child(body)

func blob_shadow(parent: Node3D, radius: float, strength := 0.4) -> void:
	# Sombra de contato em blob (efeito alternavel pela cena).
	var q := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius*2, radius*2)
	q.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/contact_shadow.gdshader")
	q.material_override = mat
	q.position.y = 0.03
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.transparency = 1.0 - strength/0.35 if strength < 0.35 else 0.0
	parent.add_child(q)
	sombras.append(q)

func foliage_mesh(count: int, radius: Vector3, base: Color, alt: Color, flower: Color = Color(0,0,0,0), flower_ratio := 0.0, seed_value := 1) -> ArrayMesh:
	# Moita de "cartoes" de folha (triangulos) com cor por vertice; balanca com o vento.
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var p := Vector3(r.randf_range(-1,1), r.randf_range(0,1), r.randf_range(-1,1))
		if Vector2(p.x,p.z).length() > 1.0:
			var v := Vector2(p.x,p.z).normalized()*r.randf_range(0.5,1.0)
			p = Vector3(v.x, p.y, v.y)
		p.y = p.y*(1.0-0.5*Vector2(p.x,p.z).length())
		p *= radius
		var col := base.lerp(alt, r.randf())
		if flower_ratio > 0.0 and r.randf() < flower_ratio:
			col = flower.lerp(Color.WHITE, r.randf()*0.15)
		col = col.darkened(0.35*(1.0-p.y/maxf(radius.y,0.01)))
		var a := r.randf()*TAU
		var s := r.randf_range(0.12,0.24)*maxf(radius.x,0.6)/1.2
		var d1 := Vector3(cos(a),0.35,sin(a))*s
		var d2 := Vector3(-sin(a),0.9,cos(a))*s*0.8
		for q in [p-d1, p+d1, p+d2]:
			st.set_color(col)
			st.add_vertex(q)
	st.generate_normals()
	return st.commit()

func foliage_instance(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, height := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat: ShaderMaterial = folhagem
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

# ---------------------------------------------------------------- pecas
func _p_casa(n: Node3D, d: Dictionary) -> void:
	var old_parent = art.parent
	art.parent = n
	art._house(Vector3.ZERO, false, 1.0)
	art.parent = old_parent
	# estandarte vermelho na fachada e trepadeiras/vasos
	var banner := _banner_mesh(Vector2(0.8,1.6))
	banner.position = Vector3(0.95,1.75,2.09)
	n.add_child(banner)
	foliage_instance(n, foliage_mesh(70, Vector3(0.5,1.6,0.25), Color("2f4a22"), Color("6b7f2c"), Color("b8402a"), 0.12, 11), Vector3(-2.55,0.2,2.0))
	foliage_instance(n, foliage_mesh(60, Vector3(0.45,1.4,0.25), Color("2f4a22"), Color("587a2a"), Color("e8d9a0"), 0.1, 12), Vector3(2.55,0.2,1.9))
	for x in [-2.2, 2.0]:
		box(n, Vector3(x,0.25,2.35), Vector3(0.38,0.4,0.38), "brown_planks_03")
		foliage_instance(n, foliage_mesh(26, Vector3(0.3,0.45,0.3), Color("3d5c26"), Color("7a8f35"), Color("c2452c"), 0.25, 13+int(x*10)), Vector3(x,0.45,2.35))
	var smoke := CPUParticles3D.new()
	smoke.name = "FumacaChamine"
	smoke.position = Vector3(1.5,5.5,-0.6)
	smoke.amount = 26
	smoke.lifetime = 4.5
	smoke.direction = Vector3(0.3,1,0)
	smoke.spread = 12
	smoke.initial_velocity_min = 0.35
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3(0.12,0.05,0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0,0.4))
	curve.add_point(Vector2(1,2.2))
	smoke.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6,0.6)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _soft_dot()
	quad.material = sm
	smoke.mesh = quad
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75,0.72,0.68,0.0))
	grad.add_point(0.15, Color(0.72,0.70,0.66,0.45))
	grad.set_color(grad.get_point_count()-1, Color(0.6,0.62,0.66,0.0))
	smoke.color_ramp = grad
	n.add_child(smoke)
	fumacas.append(smoke)

func _p_poco(n: Node3D, _d: Dictionary) -> void:
	for i in 14:
		var a := i*TAU/14
		var s := box(n, Vector3(cos(a)*0.72,0.42,sin(a)*0.72), Vector3(0.38,0.84,0.3), "castle_brick_01")
		s.rotation.y = -a
	box(n, Vector3(0,0.86,0), Vector3(1.2,0.06,1.2), "wood")
	for x in [-0.85,0.85]:
		box(n, Vector3(x,1.25,0), Vector3(0.14,2.5,0.14), "wood")
	beam(n, Vector3(-0.85,1.75,0), Vector3(0.85,1.75,0), 0.09, "wood")
	box(n, Vector3(0.1,1.35,0), Vector3(0.24,0.26,0.24), "brown_planks_03")
	for side in [-1,1]:
		var roof := box(n, Vector3(0,2.5,side*0.42), Vector3(2.25,0.1,1.1), "grey_roof_tiles")
		roof.rotation.x = side*0.5
	solid_cylinder(n, Vector3.ZERO, 0.85, 1.2)
	blob_shadow(n, 1.3)

func _p_ponte(n: Node3D, _d: Dictionary) -> void:
	# Ponte em arco ao longo de z local; extremos apoiados no chao (y 0).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L := 7.0
	for i in 24:
		var z0 := -L/2 + i*L/24
		var z1 := z0 + L/24
		var h0 := sin((z0/L+0.5)*PI)*0.35+0.12
		var h1 := sin((z1/L+0.5)*PI)*0.35+0.12
		var pts := [Vector3(-1.1,h0,z0),Vector3(1.1,h0,z0),Vector3(-1.1,h1,z1),Vector3(1.1,h1,z1)]
		for k in [0,1,2,1,3,2]:
			st.add_vertex(pts[k])
	st.generate_normals()
	var deck := MeshInstance3D.new()
	deck.mesh = st.commit()
	deck.material_override = mats.wood
	n.add_child(deck)
	deck.create_trimesh_collision()
	for i in 26:
		var z := -L/2 + 0.15 + i*(L-0.3)/25
		var h := sin((z/L+0.5)*PI)*0.35+0.12
		var plank := box(n, Vector3(rng.randf_range(-0.04,0.04),h+0.03,z), Vector3(2.3,0.08,0.24), "brown_planks_03")
		plank.rotation.y = rng.randf_range(-0.03,0.03)
	for x in [-1.15,1.15]:
		for z in [-3.2,-1.6,0.0,1.6,3.2]:
			var h := sin((z/L+0.5)*PI)*0.35+0.12
			box(n, Vector3(x,h+0.5,z), Vector3(0.16,1.05,0.16), "wood")
			box(n, Vector3(x,h-0.6,z), Vector3(0.22,1.4,0.22), "wood")
		for z in range(4):
			var za := -3.2 + z*1.6
			var zb := za + 1.6
			for y in [0.5,0.95]:
				beam(n, Vector3(x,sin((za/L+0.5)*PI)*0.35+0.12+y,za), Vector3(x,sin((zb/L+0.5)*PI)*0.35+0.12+y,zb), 0.09, "brown_planks_03")

func _p_cerca(n: Node3D, d: Dictionary) -> void:
	# Segmento de 1 m: poste na origem + 2 travessas ate a proxima celula (direcao +x local).
	box(n, Vector3(0,0.5,0), Vector3(0.14,1.0,0.14), "wood")
	box(n, Vector3(0,1.02,0), Vector3(0.18,0.06,0.18), "wood")
	for y in [0.38,0.78]:
		var rail := box(n, Vector3(0.5,y,0), Vector3(1.0,0.09,0.07), "brown_planks_03")
		rail.rotation.z = rng.randf_range(-0.03,0.03)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0,1.0,0.15)
	col.shape = shape
	body.position = Vector3(0.5,0.5,0)
	body.add_child(col)
	n.add_child(body)

func _lantern_light(n: Node3D, pos: Vector3, energy := 1.6, rang := 5.5) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color("ffae5a")
	l.light_energy = energy
	l.omni_range = rang
	l.omni_attenuation = 1.4
	l.set_meta("base", energy)
	l.add_to_group("fid_fogo")
	n.add_child(l)
	luzes_fogo.append(l)

func _p_poste_lampiao(n: Node3D, _d: Dictionary) -> void:
	box(n, Vector3(0,1.3,0), Vector3(0.16,2.6,0.16), "wood")
	box(n, Vector3(0,0.12,0), Vector3(0.34,0.24,0.34), "castle_brick_01")
	beam(n, Vector3(0,2.45,0), Vector3(0.55,2.45,0), 0.08, "wood")
	box(n, Vector3(0.55,2.12,0), Vector3(0.24,0.34,0.24), "glow")
	box(n, Vector3(0.55,2.33,0), Vector3(0.32,0.07,0.32), "iron")
	box(n, Vector3(0.55,1.93,0), Vector3(0.28,0.05,0.28), "iron")
	_lantern_light(n, Vector3(0.55,2.0,0.25))
	blob_shadow(n, 0.45)

func _fire(n: Node3D, pos: Vector3, scale := 1.0) -> void:
	var fire := CPUParticles3D.new()
	fire.name = "Fogo"
	fire.position = pos
	fire.amount = 24
	fire.lifetime = 0.55
	fire.direction = Vector3.UP
	fire.spread = 18
	fire.initial_velocity_min = 0.6*scale
	fire.initial_velocity_max = 1.1*scale
	fire.gravity = Vector3(0,1.2,0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.12*scale
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0,1))
	curve.add_point(Vector2(1,0.1))
	fire.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28,0.36)*scale
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot()
	quad.material = m
	fire.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(1.0,0.85,0.4,1.0)*Color(2.2,2.0,1.6,1))
	g.set_color(1, Color(0.9,0.25,0.05,0.0))
	fire.color_ramp = g
	n.add_child(fire)
	# faiscas laranja rapidas, vida curta
	var sparks := CPUParticles3D.new()
	sparks.name = "Faiscas"
	sparks.position = pos
	sparks.amount = 14
	sparks.lifetime = 1.1
	sparks.direction = Vector3.UP
	sparks.spread = 30
	sparks.initial_velocity_min = 1.2*scale
	sparks.initial_velocity_max = 2.4*scale
	sparks.gravity = Vector3(0.2,0.3,0)
	var sq := QuadMesh.new()
	sq.size = Vector2(0.05,0.05)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.vertex_color_use_as_albedo = true
	sq.material = smat
	sparks.mesh = sq
	var sg := Gradient.new()
	sg.set_color(0, Color(3.0,1.6,0.5,1))
	sg.set_color(1, Color(1.2,0.3,0.05,1))
	sparks.color_ramp = sg
	n.add_child(sparks)
	fogos.append(fire)
	fogos.append(sparks)
	_lantern_light(n, pos+Vector3(0,0.4,0), 2.4*scale, 7.0)

func _p_pilar_braseiro(n: Node3D, _d: Dictionary) -> void:
	box(n, Vector3(0,1.0,0), Vector3(0.95,2.0,0.95), "castle_brick_01")
	box(n, Vector3(0,2.08,0), Vector3(1.15,0.16,1.15), "castle_brick_01")
	var bowl := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.42
	c.bottom_radius = 0.22
	c.height = 0.3
	bowl.mesh = c
	bowl.material_override = mats.iron
	bowl.position = Vector3(0,2.3,0)
	n.add_child(bowl)
	box(n, Vector3(0,2.4,0), Vector3(0.45,0.12,0.45), "glow")
	_fire(n, Vector3(0,2.5,0), 1.3)

func _p_pilar_pedra(n: Node3D, _d: Dictionary) -> void:
	var h := 0.0
	for i in 5:
		var s := 1.1 - i*0.07
		var hh := rng.randf_range(0.8,1.2)
		var b := box(n, Vector3(rng.randf_range(-0.05,0.05),h+hh*0.5,0), Vector3(s,hh,s*0.9), "castle_brick_01")
		b.rotation.y = rng.randf_range(-0.1,0.1)
		h += hh
	box(n, Vector3(0,h+0.1,0), Vector3(1.0,0.2,0.9), "lichen_rock")
	foliage_instance(n, foliage_mesh(40, Vector3(0.7,0.6,0.7), Color("2e4a20"), Color("75892d"), Color("e3dba5"), 0.15, 21), Vector3(0,0,0))

func _banner_mesh(size: Vector2) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var flag := PlaneMesh.new()
	flag.size = size
	flag.subdivide_width = 4
	flag.subdivide_depth = 8
	mesh.mesh = flag
	mesh.rotation.x = PI/2
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/fid_estandarte.gdshader")
	mesh.material_override = material
	return mesh

func _p_estandarte(n: Node3D, _d: Dictionary) -> void:
	box(n, Vector3(0,1.6,0), Vector3(0.14,3.2,0.14), "wood")
	beam(n, Vector3(-0.1,3.0,0), Vector3(0.9,3.0,0), 0.08, "wood")
	var b := _banner_mesh(Vector2(0.72,1.5))
	b.position = Vector3(0.5,2.2,0.03)
	n.add_child(b)
	box(n, Vector3(0.5,3.05,0), Vector3(0.18,0.2,0.18), "glow")
	_lantern_light(n, Vector3(0.5,2.9,0.3), 1.1, 4.0)

func _pumpkin(n: Node3D, pos: Vector3, s: float) -> void:
	for k in 5:
		var a := k*TAU/5
		ball(n, pos+Vector3(cos(a),0,sin(a))*0.07*s, Vector3(0.2,0.24,0.2)*s, mats.kit_abobora if k%2 else mats.kit_abobora_escura)
	box(n, pos+Vector3(0,0.13*s,0), Vector3(0.04,0.1,0.04)*s, "wood")

func _p_carroca_abobora(n: Node3D, _d: Dictionary) -> void:
	var c := Vector3(0,0.55,0)
	box(n, c, Vector3(2.0,0.12,1.1), "brown_planks_03")
	for z in [-0.55,0.55]:
		box(n, c+Vector3(0,0.25,z), Vector3(2.0,0.42,0.08), "brown_planks_03")
		var wheel := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 0.45
		disk.bottom_radius = 0.45
		disk.height = 0.1
		disk.radial_segments = 14
		wheel.mesh = disk
		wheel.material_override = mats.wood
		wheel.rotation.x = PI/2
		wheel.position = Vector3(-0.2,0.45,z*1.18)
		n.add_child(wheel)
		beam(n, c+Vector3(0.9,0,z*0.5), c+Vector3(2.0,-0.45,z*0.5), 0.08, "wood")
	for i in 7:
		_pumpkin(n, c+Vector3(rng.randf_range(-0.75,0.75),0.2,rng.randf_range(-0.35,0.35)), rng.randf_range(1.1,1.5))
	for i in 3:
		ball(n, c+Vector3(rng.randf_range(-0.7,0.7),0.25,rng.randf_range(-0.3,0.3)), Vector3(0.22,0.18,0.22), mats.kit_couve)
	solid_cylinder(n, Vector3.ZERO, 0.9, 1.0)
	blob_shadow(n, 1.4)

func _p_menir_runa(n: Node3D, _d: Dictionary) -> void:
	box(n, Vector3(0,0.15,0), Vector3(1.5,0.3,1.3), "castle_brick_01")
	box(n, Vector3(0,1.15,0), Vector3(0.95,1.9,0.7), "lichen_rock")
	box(n, Vector3(0,2.15,0), Vector3(1.05,0.18,0.8), "castle_brick_01")
	var rune := TorusMesh.new()
	rune.inner_radius = 0.26
	rune.outer_radius = 0.33
	rune.rings = 24
	rune.ring_segments = 6
	var symbol := MeshInstance3D.new()
	symbol.mesh = rune
	var gm: StandardMaterial3D = mats.kit_dourado.duplicate()
	gm.emission_enabled = true
	gm.emission = Color("d79a3a")
	gm.emission_energy_multiplier = 0.6
	symbol.material_override = gm
	symbol.rotation.x = PI/2
	symbol.position = Vector3(0,1.35,0.37)
	n.add_child(symbol)
	solid_cylinder(n, Vector3.ZERO, 0.6, 2.2)
	blob_shadow(n, 1.0)

func _p_ruina_arco(n: Node3D, d: Dictionary) -> void:
	# Arco em ruina sobre pilar de rocha que sobe do fundo do abismo.
	var depth := float(d.get("fundo", 30.0))
	# pilar de rocha afunilado (3 blocos) sob o arco
	var y0 := -0.2
	for seg in [[5.4,2.6,0.22],[4.2,2.1,0.3],[3.0,1.6,0.48]]:
		var hh: float = depth*float(seg[2])
		var blk := box(n, Vector3(rng.randf_range(-0.3,0.3), y0-hh*0.5, 0), Vector3(float(seg[0]), hh, float(seg[1])), "lichen_rock")
		blk.rotation.y = rng.randf_range(-0.15,0.15)
		y0 -= hh
	for x in [-2.3,2.3]:
		box(n, Vector3(x,2.4,0), Vector3(1.2,4.8,1.4), "castle_brick_01")
	for i in 9:
		var a := PI*float(i)/8
		if i == 6 or i == 7:
			continue
		var b := box(n, Vector3(cos(a)*2.3,4.4+sin(a)*2.3,0), Vector3(0.95,0.8,1.4), "castle_brick_01")
		b.rotation.z = a-PI/2
	for i in 6:
		box(n, Vector3(rng.randf_range(-3,3),0.2,rng.randf_range(-1.2,1.2)), Vector3(0.7,0.4,0.6), "castle_brick_01")
	foliage_instance(n, foliage_mesh(120, Vector3(3.0,0.9,1.4), Color("2b4220"), Color("64792a"), Color("a33a22"), 0.08, 31), Vector3(0,0,0.4))
	foliage_instance(n, foliage_mesh(40, Vector3(0.7,1.8,0.5), Color("2b4220"), Color("5f7a2a"), Color(), 0.0, 32), Vector3(-2.3,3.0,0.7))
	_crow(n, Vector3(2.3,4.85,0))

func _p_ruina_pilar(n: Node3D, _d: Dictionary) -> void:
	var h := 0.0
	for i in 3:
		var hh := rng.randf_range(0.7,1.0)
		box(n, Vector3(0,h+hh*0.5,0), Vector3(0.9,hh,0.9), "castle_brick_01")
		h += hh
	_crow(n, Vector3(0,h,0))
	foliage_instance(n, foliage_mesh(30, Vector3(0.6,0.7,0.6), Color("2e4a20"), Color("71862c"), Color(), 0.0, 41), Vector3.ZERO)

func _crow(n: Node3D, pos: Vector3) -> void:
	var c := Node3D.new()
	c.name = "Corvo"
	c.position = pos
	c.rotation.y = rng.randf()*TAU
	c.set_meta("modulo","corvo")
	n.add_child(c)
	ball(c, Vector3(0,0.2,0), Vector3(0.22,0.2,0.36), mats.kit_corvo)
	ball(c, Vector3(0,0.36,0.17), Vector3(0.14,0.14,0.14), mats.kit_corvo)
	box(c, Vector3(0,0.35,0.28), Vector3(0.04,0.04,0.1), "iron")
	var tail := box(c, Vector3(0,0.2,-0.22), Vector3(0.12,0.03,0.2), "kit_corvo")
	tail.rotation.x = 0.4

func _p_canteiro(n: Node3D, d: Dictionary) -> void:
	box(n, Vector3(0,0.04,0), Vector3(0.92,0.1,0.92), "soil")
	var crop := String(d.get("cultura","abobora"))
	var stage := int(d.get("estagio",3))
	n.set_meta("cultura", crop)
	n.set_meta("estagio", stage)
	if crop == "abobora":
		# estagios: 0 semente, 1 broto, 2 rama com flor, 3 abobora madura
		if stage >= 1:
			foliage_instance(n, foliage_mesh(10+stage*14, Vector3(0.42,0.18+stage*0.07,0.42), Color("3d6526"), Color("7b9a36"), Color("e5b73b"), 0.08 if stage==2 else 0.0, 50+stage), Vector3(0,0.08,0))
		if stage >= 3:
			_pumpkin(n, Vector3(0.05,0.22,0.0), 1.6)
	else:
		for k in 3:
			ball(n, Vector3(0,0.15+k*0.05,0), Vector3(0.45-k*0.1,0.22,0.45-k*0.1), mats.kit_couve)
		foliage_instance(n, foliage_mesh(18, Vector3(0.4,0.25,0.4), Color("4f7a35"), Color("8fb050"), Color(), 0.0, 60), Vector3(0,0.06,0))

func _tree_from_factory(n: Node3D, scale: float, tints: Array, red_every: int, leaves := true) -> void:
	var factory = ChoppableTree.new()
	factory.art = art
	var tree: Node3D = factory._make_tree()
	tree.scale = Vector3.ONE*scale
	n.add_child(tree)
	var leaf_node: MultiMeshInstance3D = tree.get_node("FolhasLargasAoSol")
	if not leaves:
		leaf_node.queue_free()
	else:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/reference_leaves.gdshader")
		leaf_node.material_override = m
		for i in leaf_node.multimesh.instance_count:
			var t := leaf_node.multimesh.get_instance_transform(i)
			t.basis = t.basis.scaled(Vector3.ONE*0.75)
			leaf_node.multimesh.set_instance_transform(i,t)
			var tint: Color = tints[i%tints.size()]
			if red_every > 0 and i%red_every == 0:
				tint = Color("a2321c")
			leaf_node.multimesh.set_instance_color(i,tint)
	factory.free()
	blob_shadow(n, 1.6*scale)

func _p_arvore_outono(n: Node3D, _d: Dictionary) -> void:
	_tree_from_factory(n, 1.25, [Color("b0451f"),Color("8e2f19"),Color("c9762c"),Color("5a6a2a")], 0)

func _p_arvore_escura(n: Node3D, _d: Dictionary) -> void:
	_tree_from_factory(n, 1.45, [Color("23361b"),Color("34502a"),Color("455f2a"),Color("2b4220")], 7)

func _p_arvore_seca(n: Node3D, _d: Dictionary) -> void:
	_tree_from_factory(n, 0.95, [], 0, false)

func _p_arbusto_flor(n: Node3D, _d: Dictionary) -> void:
	var s := rng.randf_range(0.9,1.3)
	foliage_instance(n, foliage_mesh(140, Vector3(1.1,1.0,1.1)*s, Color("263b1b"), Color("4c6526"), Color("b3301c"), 0.35, rng.randi()))
	blob_shadow(n, 1.1*s)

func _p_arbusto_escuro(n: Node3D, _d: Dictionary) -> void:
	var s := rng.randf_range(1.2,1.7)
	foliage_instance(n, foliage_mesh(190, Vector3(1.4,1.3,1.4)*s, Color("1c2a16"), Color("3d5224"), Color("8a2e18"), 0.18, rng.randi()))

func _p_rocha(n: Node3D, _d: Dictionary) -> void:
	for i in rng.randi_range(1,3):
		var r := ball(n, Vector3(rng.randf_range(-0.25,0.25),0.15,rng.randf_range(-0.25,0.25)), Vector3(rng.randf_range(0.4,0.75),rng.randf_range(0.3,0.55),rng.randf_range(0.4,0.7)), mats.lichen_rock)
		r.rotation = Vector3(rng.randf()*0.4,rng.randf()*TAU,0)
	foliage_instance(n, foliage_mesh(18, Vector3(0.5,0.35,0.5), Color("3a5a24"), Color("8a9a3a"), Color("e9e2b0"), 0.2, rng.randi()))
	blob_shadow(n, 0.7)

func _p_barril(n: Node3D, _d: Dictionary) -> void:
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.33
	cyl.height = 0.8
	cyl.radial_segments = 12
	barrel.mesh = cyl
	barrel.material_override = mats.brown_planks_03
	barrel.position.y = 0.4
	n.add_child(barrel)
	for y in [0.15,0.62]:
		var hoop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.3
		torus.outer_radius = 0.35
		torus.rings = 12
		torus.ring_segments = 5
		hoop.mesh = torus
		hoop.material_override = mats.iron
		hoop.position.y = y
		n.add_child(hoop)
	blob_shadow(n, 0.5)

func _p_caixote(n: Node3D, _d: Dictionary) -> void:
	var s := rng.randf_range(0.5,0.7)
	var b := box(n, Vector3(0,s*0.5,0), Vector3(s,s,s), "brown_planks_03")
	b.rotation.y = rng.randf_range(-0.3,0.3)
	var strap := box(n, Vector3(0,s+0.02,0), Vector3(s*1.02,0.05,0.08), "wood")
	strap.rotation.y = b.rotation.y
	if rng.randf() < 0.6:
		for k in 3:
			ball(n, Vector3(rng.randf_range(-0.15,0.15),s+0.12,rng.randf_range(-0.15,0.15)), Vector3(0.18,0.16,0.18), mats.kit_abobora if k%2 else mats.kit_couve)
	blob_shadow(n, 0.5)

func _p_banco(n: Node3D, _d: Dictionary) -> void:
	box(n, Vector3(0,0.45,0), Vector3(1.8,0.08,0.45), "brown_planks_03")
	box(n, Vector3(0,0.75,-0.2), Vector3(1.8,0.35,0.06), "brown_planks_03")
	for x in [-0.75,0.75]:
		box(n, Vector3(x,0.22,0), Vector3(0.1,0.45,0.4), "wood")
	blob_shadow(n, 0.9)

func _p_mesa(n: Node3D, _d: Dictionary) -> void:
	box(n, Vector3(0,0.72,0), Vector3(1.4,0.08,0.9), "brown_planks_03")
	for x in [-0.6,0.6]:
		for z in [-0.35,0.35]:
			box(n, Vector3(x,0.36,z), Vector3(0.09,0.72,0.09), "wood")
	_pumpkin(n, Vector3(0.3,0.86,0), 1.2)
	box(n, Vector3(-0.35,0.84,0.1), Vector3(0.22,0.16,0.22), "glow")
	_lantern_light(n, Vector3(-0.35,1.1,0.2), 0.8, 3.5)
	blob_shadow(n, 1.0)

func _p_cogumelos(n: Node3D, _d: Dictionary) -> void:
	var cap: StandardMaterial3D = mats.kit_vermelho.duplicate()
	cap.albedo_color = Color("b0442a")
	for i in 6:
		var p := Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3))
		var h := rng.randf_range(0.1,0.22)
		box(n, p+Vector3(0,h*0.5,0), Vector3(0.04,h,0.04), "kit_palha")
		ball(n, p+Vector3(0,h,0), Vector3(0.16,0.08,0.16)*rng.randf_range(0.8,1.4), cap)

func _p_deck(n: Node3D, _d: Dictionary) -> void:
	for i in 9:
		box(n, Vector3(-1.4+i*0.35,0.12,0), Vector3(0.32,0.08,2.8), "brown_planks_03")
	for x in [-1.4,1.4]:
		for z in [-1.3,1.3]:
			box(n, Vector3(x,-0.3,z), Vector3(0.18,1.0,0.18), "wood")
	_p_poste_lampiao(n, {})

var _dot: ImageTexture
func _soft_dot() -> Texture2D:
	if _dot:
		return _dot
	var img := Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x-15.5,y-15.5).length()/16.0
			img.set_pixel(x,y,Color(1,1,1,clampf(1.0-d,0,1)**2))
	_dot = ImageTexture.create_from_image(img)
	return _dot