extends RefCounted
## Modulos 3D autorais: detalhes construidos no mundo, nao uma imagem de fundo.
var art
var root: Node3D
var random := RandomNumberGenerator.new()
var materials := {}
var batches := {}
var transforms := {}

func build(world, target: Node3D) -> void:
	art = world
	root = target
	random.seed = 64029
	for entry in [["slate",Color("354758")],["stone",Color("7b8276")],["moss",Color("617332")],["leaf",Color("73833e")],["pumpkin",Color("cb681b")],["terracotta",Color("87522e")],["red",Color("8f3428")]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = entry[1]
		material.roughness = 0.9
		materials[entry[0]] = material
	for node in root.get_children():
		if node is Node3D and (node.name.begins_with("CasaModular") or Vector2(node.position.x,node.position.z).distance_to(Vector2(4,-10))<0.01):
			_house_details(node)
	_banks()
	_garden()
	_ruin_garden()
	_arch(Vector3(12,art.height_at(12,-15),-15))
	_arch(Vector3(-9,art.height_at(-9,-16),-16))
	_grass_islands()
	_flush()

func _instance(label: String, mesh: Mesh, transform: Transform3D, material: Material) -> void:
	if not batches.has(label):
		batches[label] = [mesh,material]
		transforms[label] = []
	transforms[label].append(transform)

func _cube(label: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_instance(label,mesh,Transform3D(Basis.from_euler(rotation).scaled(size),position),material)

func _ball(label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 9
	mesh.rings = 5
	_instance(label,mesh,Transform3D(Basis.IDENTITY.scaled(size),position),material)

func _flush() -> void:
	for label in batches:
		var batch := MultiMeshInstance3D.new()
		batch.name = "Detalhe_"+label
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = batches[label][0]
		batch.multimesh.instance_count = transforms[label].size()
		for i in transforms[label].size():
			batch.multimesh.set_instance_transform(i,transforms[label][i])
		batch.material_override = batches[label][1]
		root.add_child(batch)

func _house_details(house: Node3D) -> void:
	# Tiras sobrepostas em duas aguas; pequenas variacoes evitam repeticao plana.
	for side in [-1,1]:
		for row in range(7):
			for col in range(15):
				var z: float = side*(0.15+row*0.335)
				var point := Vector3(-2.72+col*0.375+(row%2)*0.10,4.31-absf(z)*0.532,z)
				var position := house.to_global(point)
				var tint := col%3
				var label := "telhas_"+str(tint)
				var tile_mat: StandardMaterial3D = materials.slate.duplicate()
				tile_mat.albedo_color = Color("354758").lightened(tint*0.065)
				_cube(label,position,Vector3(0.355,0.10,0.43)*house.scale.x,tile_mat,Vector3(side*0.489,random.randf_range(-0.025,0.025),0))
	# Base de pedra individual e molduras da entrada.
	for side in [-1,1]:
		for row in range(3):
			for col in range(11):
				var point := Vector3(-2.42+col*0.48+(row%2)*0.1,0.3+row*0.23,side*1.96)
				_cube("pedras_casa",house.to_global(point),Vector3(0.45,0.20,0.12)*house.scale.x,materials.stone)
	for x in [-0.57,0.57]:
		_cube("moldura",house.to_global(Vector3(x,1.34,2.08)),Vector3(0.14,2.2,0.22)*house.scale.x,art.materials.wood)
	# Floreiras, vasos e caixas afastados do corredor da porta.
	for x in [-1.65,1.65]:
		var point := house.to_global(Vector3(x,0.35,2.5))
		_cube("floreiras",point,Vector3(0.95,0.35,0.45)*house.scale.x,art.materials.brown_planks_03)
		for i in range(8):
			_ball("arbustos",point+Vector3(random.randf_range(-0.4,0.4),0.30,random.randf_range(-0.17,0.17)),Vector3.ONE*0.29,materials.leaf)
			_ball("flores_vaso",point+Vector3(random.randf_range(-0.4,0.4),0.45,random.randf_range(-0.17,0.17)),Vector3.ONE*0.12,materials.red if i%2==0 else art.materials.flower)
		_pot(house.to_global(Vector3(x*1.65,0,2.1)))
	for i in range(7):
		var point := house.to_global(Vector3(2.58,0.5+i*0.45,1.3-sin(i)*0.4))
		for j in range(7):
			_ball("hera",point+Vector3(random.randf_range(-0.03,0.06),random.randf_range(-0.18,0.18),random.randf_range(-0.35,0.35)),Vector3(0.10,0.19,0.25),materials.moss)
	for i in range(52):
		var z := random.randf_range(-1.9,1.9)
		var point := house.to_global(Vector3(2.7-random.randf()*0.9,4.42-absf(z)*0.532,z))
		_ball("hera_telhado",point,Vector3(0.26,0.10,0.21),materials.moss)
	_crate(house.to_global(Vector3(2.8,0,2.55)),0.65)
	_crate(house.to_global(Vector3(-2.55,0,2.75)),0.55)
	# Pontos quentes iluminam madeira e personagens diante das casas.
	for x in [-1.55,1.55]:
		var light := OmniLight3D.new()
		light.position = house.to_global(Vector3(x,1.9,2.5))
		light.light_color = Color("ffad42")
		light.omni_range = 3.2
		light.light_energy = 1.4
		light.add_to_group("facade_lights")
		root.add_child(light)

func _pot(point: Vector3) -> void:
	_ball("vasos",point+Vector3(0,0.25,0),Vector3(0.43,0.5,0.43),materials.terracotta)
	_ball("boca_vaso",point+Vector3(0,0.49,0),Vector3(0.22,0.035,0.22),art.materials.soil)

func _crate(point: Vector3, size: float) -> void:
	_cube("caixas",point+Vector3(0,size/2,0),Vector3.ONE*size,art.materials.brown_planks_03)
	for x in [-1,1]:
		for z in [-1,1]:
			_cube("quinas_caixas",point+Vector3(x*size/2,size/2,z*size/2),Vector3(0.07,size+0.04,0.07),art.materials.wood)
	for y in [0.06,size-0.06]:
		for z in [-1,1]:
			_cube("ripas_caixas",point+Vector3(0,y,z*size/2),Vector3(size+0.07,0.08,0.08),art.materials.wood)

func _banks() -> void:
	var cells = art.Layout.generate(41826)
	for side in [-1,1]:
		for i in range(80):
			var x := -23+i*0.58
			if absf(x)<1.4 or not cells.has(Vector2i(roundi(x),roundi(7.5+side*2))):
				continue
			var z: float = 7.5+side*(1.6+random.randf_range(-0.16,0.2))
			var y: float = art.height_at(x,z)
			_cube("margem_rocha",Vector3(x,y-0.22,z),Vector3(random.randf_range(0.45,0.85),random.randf_range(0.65,0.95),0.62),materials.stone,Vector3(random.randf_range(-0.14,0.14),random.randf_range(-0.3,0.3),random.randf_range(-0.1,0.1)))
			if i%3==0:
				_ball("musgo_margem",Vector3(x,y+0.22,z),Vector3(0.5,0.14,0.35),materials.moss)
			if i%2==0:
				for reed in range(5):
					var p := Vector3(x+random.randf_range(-0.22,0.22),-0.32,7.5+side*1.32)
					_cube("juncos",p+Vector3(0,0.25,0),Vector3(0.035,random.randf_range(0.3,0.8),0.035),materials.leaf,Vector3(0,0,random.randf_range(-0.16,0.16)))
	for i in range(30):
		var x := random.randf_range(-18,18)
		if absf(x)<1.5:
			continue
		var point := Vector3(x,-0.35,7.5+random.randf_range(-1.1,1.1))
		_ball("nenufares",point,Vector3(0.23,0.025,0.19),materials.moss)
		if i%5==0:
			_ball("flor_agua",point+Vector3(0,0.06,0),Vector3(0.09,0.10,0.09),art.materials.flower)

func _garden() -> void:
	for p in [Vector3(-9.4,0,0.1),Vector3(-9.3,0,2.4),Vector3(-6.5,0,3.6),Vector3(-4.2,0,3.6)]:
		_pumpkin(p)
	var scarecrow := Vector3(-9.2,0,3.5)
	_cube("espantalho",scarecrow+Vector3(0,0.75,0),Vector3(0.07,1.5,0.07),art.materials.wood)
	_cube("bracos_espantalho",scarecrow+Vector3(0,1.18,0),Vector3(0.85,0.075,0.07),art.materials.wood)
	_cube("camisa_espantalho",scarecrow+Vector3(0,1.02,0),Vector3(0.39,0.42,0.18),materials.red)
	_ball("cabeca_espantalho",scarecrow+Vector3(0,1.48,0),Vector3(0.27,0.30,0.25),materials.terracotta)
	_cube("chapeu_espantalho",scarecrow+Vector3(0,1.62,0),Vector3(0.41,0.06,0.35),art.materials.wood)
	for i in range(6):
		_pumpkin(Vector3(-10.3+i*0.23,0.84,5.0+random.randf_range(-0.2,0.2)))

func _pumpkin(point: Vector3) -> void:
	var size := random.randf_range(0.30,0.48)
	for rib in range(7):
		var angle := rib*TAU/7
		_ball("aboboras",point+Vector3(cos(angle)*size*0.23,size*0.4,sin(angle)*size*0.23),Vector3(size*0.55,size*0.8,size*0.55),materials.pumpkin)
	_cube("talo_abobora",point+Vector3(0,size*0.9,0),Vector3(0.055,0.16,0.055),art.materials.wood,Vector3(0,0,0.15))

func _ruin_garden() -> void:
	for x in [-12.0,-5.0,5.0,12.0]:
		var z := -14.0
		var y: float = art.height_at(x,z)
		for row in range(7):
			for col in range(2):
				_cube("ruinas_blocos",Vector3(x+col*0.46,y+row*0.38,z),Vector3(0.43,0.35,0.68),materials.stone)
		_cube("ruinas_capitel",Vector3(x+0.23,y+2.5,z),Vector3(1.25,0.18,1.05),materials.stone)
		for i in range(12):
			_ball("musgo_ruina",Vector3(x+random.randf_range(-0.2,0.65),y+random.randf_range(1.5,2.7),z+0.38),Vector3(0.25,0.18,0.10),materials.moss)
	# Detalhe de pedras nas laterais da escadaria sem criar degraus na colisao.
	for step in range(12):
		var z := -5.3-step*0.43
		for x in [-1.65,1.65]:
			_cube("borda_escada",Vector3(x,art.height_at(x,z)+0.10,z),Vector3(0.22,0.20,0.4),materials.stone)

func _grass_islands() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(7):
		var angle := blade*2.4
		var foot := Vector3(cos(angle)*0.11,0,sin(angle)*0.11)
		var side := Vector3(cos(angle+1.57),0,sin(angle+1.57))*0.035
		var tip := foot+Vector3(cos(angle)*0.1,0.24+(blade%3)*0.09,sin(angle)*0.1)
		for i in range(3):
			surface.set_color(Color("536b2c") if i<2 else Color("8d9942"))
			surface.add_vertex([foot-side,foot+side,tip][i])
	surface.generate_normals()
	var mesh := surface.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/reference_flowers.gdshader")
	var cells = art.Layout.generate(41826)
	for i in range(18000):
		var x := random.randf_range(-23,23)
		var z := random.randf_range(-22,21)
		if not cells.has(Vector2i(roundi(x),roundi(z))) or art._clear_zone(x,z):
			continue
		# Bordas densas e clareiras: variacao espacial em vez de ruido uniforme.
		var cluster := sin(x*0.72)*cos(z*0.59)
		if cluster< -0.35 and i%4!=0:
			continue
		var basis := Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*random.randf_range(0.7,1.4))
		_instance("capim_fino",mesh,Transform3D(basis,Vector3(x,art.height_at(x,z),z)),material)

func _arch(origin: Vector3) -> void:
	for side in [-1,1]:
		for row in range(7):
			_cube("arco_pilares",origin+Vector3(side*1.35,0.22+row*0.43,0),Vector3(0.68,0.4,0.7),materials.stone)
	for i in range(9):
		# Arco realmente aberto: blocos de cantaria em volta de um vao.
		var angle := i*PI/8
		var p := origin+Vector3(cos(angle)*1.35,2.95+sin(angle)*1.35,0)
		_cube("arco_aduelas",p,Vector3(0.57,0.64,0.76),materials.stone,Vector3(0,0,angle-PI/2))
	for i in range(25):
		var p := origin+Vector3(random.randf_range(-1.7,1.7),random.randf_range(2.8,4.4),0.39)
		_ball("hera_arco",p,Vector3(0.25,0.16,0.08),materials.moss)
	_crow(origin+Vector3(1.35,3.25,0))

func _crow(point: Vector3) -> void:
	_ball("corvos_corpo",point+Vector3(0,0.14,0),Vector3(0.22,0.30,0.30),art.materials.iron)
	_ball("corvos_cabeca",point+Vector3(0.04,0.32,0.10),Vector3(0.19,0.19,0.19),art.materials.iron)
	_cube("corvos_bico",point+Vector3(0.04,0.31,0.22),Vector3(0.09,0.06,0.14),art.materials.iron)
	_cube("corvos_cauda",point+Vector3(0,0.10,-0.20),Vector3(0.14,0.06,0.27),art.materials.iron,Vector3(-0.35,0,0))
