extends RefCounted
## Cena autoral modular. Terreno e props 3D; personagens em quadros 2D reais.
const Layout = preload("res://scripts/world_layout.gd")
var parent: Node3D
var rng := RandomNumberGenerator.new()
var materials := {}
var body_mesh: SphereMesh
var ground_mesh: MeshInstance3D
var model_cache := {}
var leaf_materials := {}

static func height_at(x: float, z: float) -> float:
	var terrain := _base_height(x,z)
	# Lotes planos sobre o relevo: fundacoes nao ficam suspensas nas rampas.
	for anchor in [Vector2(-8,-5),Vector2(4,-10),Vector2(11,-5)]:
		var distance := maxf(absf(x-anchor.x)-2.8,absf(z-anchor.y)-2.3)
		if distance < 1.0:
			terrain = lerpf(_base_height(anchor.x,anchor.y),terrain,smoothstep(0.0,1.0,distance))
	return terrain

static func _base_height(x: float, z: float) -> float:
	var north := smoothstep(5.0, 11.0, -z) * 2.5 + smoothstep(13.0, 18.0, -z) * 2.2
	var south := smoothstep(8.0, 17.0, z) * -2.4
	var east := smoothstep(11.0, 18.0, x) * 1.4
	return lerpf(north+south+east,-1.25,1.0-smoothstep(0.9,2.0,absf(z-7.5)))

func build(root: Node3D, world_seed: int) -> void:
	parent = root
	rng.seed = world_seed
	_make_materials()
	var layout_cells := Layout.generate(world_seed)
	_terrain(world_seed)
	_water(layout_cells)
	_house(Vector3(-8, height_at(-8,-5), -5), false)
	_house(Vector3(4, height_at(4,-10), -10), false, 0.85)
	_building_plot(Vector3(11,height_at(11,-5),-5))
	# Os canteiros interativos sao construidos por FarmPlots.
	_fence(Vector3(-9, 0, 4.5), Vector3(-2, 0, 4.5))
	_fence(Vector3(-10,0,-0.5),Vector3(-10,0,0.8))
	_fence(Vector3(-10,0,2.2),Vector3(-10,0,4.5))
	_fence(Vector3(3, 0, 3.7), Vector3(10, 0, 3.7))
	_well(Vector3(3.8, 0, 0.8))
	_bridge(Vector3(0, 0.0, 7.5))
	_ruin(Vector3(-6, height_at(-6,-13), -13), 0.85)
	for pos in [Vector3(-14,0,-4),Vector3(-16,0,5),Vector3(17,0,-9),Vector3(16,0,-15)]:
		pos.y = height_at(pos.x,pos.z)
		_model("island_tree_02",pos,6.0)
	# Marcos distantes sao meshes 3D fixos, nao uma imagem de fundo.
	for index in range(5):
		var x := -85.0 + index * 38.0
		var z := -110.0 - rng.randf_range(0, 35)
		var island := Vector3(x, -10, z)
		_distant_island(island)
		_tower(island + Vector3(0, 11, 0), rng.randf_range(1.1,1.6))
		if index % 2 == 0:
			_ruin(island + Vector3(10, 8, 1), 1.5)
	for i in range(180):
		var x := rng.randf_range(-23,23)
		var z := rng.randf_range(-22,23)
		if not layout_cells.has(Vector2i(roundi(x), roundi(z))):
			continue
		if _clear_zone(x,z):
			continue
		var pos := Vector3(x, height_at(x,z), z)
		if i % 7 == 0 and (x < -13 or (x > 16 and z < -4)):
			_model("island_tree_02", pos, rng.randf_range(5.5,7.5))
		else:
			_rock(pos, Vector3.ONE * rng.randf_range(0.35,1.25))
	# Samambaias reais nas bordas, sem invadir os lotes e caminhos.
	for i in range(90):
		var x := rng.randf_range(-21,21)
		var z := rng.randf_range(-20,20)
		if not _clear_zone(x,z):
			_model("fern_02",Vector3(x,height_at(x,z),z),rng.randf_range(0.3,0.65))
	_grass(world_seed)
	_details()
	_flowers(layout_cells)
	_landmarks()
	_cliff_details(layout_cells)

func _distant_island(origin: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in range(18):
		var angle := i*TAU/18
		var radius := rng.randf_range(13,25)
		rim.append(Vector3(cos(angle)*radius,rng.randf_range(-1,4),sin(angle)*radius*0.7))
	for i in range(18):
		var a := rim[i]
		var b := rim[(i+1)%18]
		for p in [Vector3(0,11,0),b,a,a,b,Vector3(a.x*1.2,-5,a.z*1.2),b,Vector3(b.x*1.2,-5,b.z*1.2),Vector3(a.x*1.2,-5,a.z*1.2)]:
			surface.add_vertex(p)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = materials.lichen_rock
	mesh.position = origin
	parent.add_child(mesh)

func _details() -> void:
	# Muretas de contencao tornam os patamares legiveis; rampa central livre.
	for x in range(-13,14):
		if absi(x) < 3:
			continue
		var y := height_at(x,-10)
		box(Vector3(x,y-0.55,-10),Vector3(0.96,1.2,0.38),"castle_brick_01")
	for pos in [Vector3(-10,0,-2.5),Vector3(-5.3,0,-4.5),Vector3(7,0,-5.5)]:
		# Barril de madeira com aros de ferro.
		var barrel := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.3
		cylinder.bottom_radius = 0.34
		cylinder.height = 0.85
		cylinder.radial_segments = 12
		barrel.mesh = cylinder
		barrel.material_override = materials.brown_planks_03
		barrel.position = pos + Vector3(0,height_at(pos.x,pos.z)+0.43,0)
		parent.add_child(barrel)
		for y in [0.18,0.65]:
			var hoop := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.30
			torus.outer_radius = 0.35
			torus.rings = 12
			torus.ring_segments = 6
			hoop.mesh = torus
			hoop.material_override = materials.iron
			hoop.position = pos + Vector3(0,height_at(pos.x,pos.z)+y,0)
			parent.add_child(hoop)

func _model(asset: String, pos: Vector3, desired_height: float) -> Node3D:
	if not model_cache.has(asset):
		var path := "res://art/models/"+asset+"/"+asset+".gltf"
		if asset == "island_tree_02":
			path = "res://art/models/island_tree_02/island_tree_02_optimized.glb"
		model_cache[asset] = load(path)
	var node: Node3D = model_cache[asset].instantiate()
	parent.add_child(node)
	var bounds := AABB()
	var valid := false
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if asset == "island_tree_02":
			for surface_index in range(mesh.mesh.get_surface_count()):
				var original = mesh.get_active_material(surface_index)
				if original is StandardMaterial3D and "leaves" in original.resource_name.to_lower():
					var key: String = str(original.get_instance_id())
					if not leaf_materials.has(key):
						var leaf := ShaderMaterial.new()
						leaf.shader = load("res://shaders/leaves.gdshader")
						leaf.set_shader_parameter("leaf_albedo",original.albedo_texture)
						leaf.set_shader_parameter("leaf_normal",original.normal_texture)
						leaf_materials[key] = leaf
					mesh.set_surface_override_material(surface_index,leaf_materials[key])
		var local: AABB = (node.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds = bounds.merge(local) if valid else local
		valid = true
	var factor := desired_height / maxf(0.1,bounds.size.y)
	node.scale = Vector3.ONE*factor
	node.rotation.y = rng.randf()*TAU
	node.position = pos-Vector3(0,bounds.position.y*factor,0)
	return node

func _make_materials() -> void:
	for name in ["castle_brick_01", "grey_roof_tiles", "brown_planks_03", "grass_path_3", "aerial_grass_rock", "lichen_rock", "leafy_grass", "forest_ground_04", "mossy_cobblestone", "plastered_stone_wall"]:
		var mat := StandardMaterial3D.new()
		var folder: String = "res://art/materials/" + str(name) + "/"
		mat.albedo_texture = load(folder + "albedo.jpg")
		mat.roughness = 0.94
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.45
		if ResourceLoader.exists(folder + "normal.jpg"):
			mat.normal_enabled = true
			mat.normal_texture = load(folder + "normal.jpg")
			mat.normal_scale = 0.7
		materials[name] = mat
	materials.castle_brick_01.albedo_color = Color("929b95")
	materials.grey_roof_tiles.albedo_color = Color("657b8e")
	materials.plastered_stone_wall.albedo_texture = null
	materials.plastered_stone_wall.albedo_color = Color("b9ad8e")
	materials.brown_planks_03.albedo_color = Color("797062")
	materials.wood = _color(Color("493c2c"))
	materials.iron = _color(Color("33393b"))
	materials.leaf = _color(Color("36432b"))
	materials.soil = _color(Color("342b20"))
	materials.crop = _color(Color("667541"))
	materials.gold = _color(Color("c18b39"))
	materials.flower = _color(Color("d9d1aa"))
	var glow := _color(Color("f8b454"))
	glow.emission_enabled = true
	glow.emission = Color("ffae47")
	glow.emission_energy_multiplier = 1.4
	materials.glow = glow

func _color(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func box(pos: Vector3, size: Vector3, material: String, solid: bool = false, target: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = materials[material]
	mesh.position = pos
	(target if target else parent).add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var solid_shape := BoxShape3D.new()
		solid_shape.size = size
		collision.shape = solid_shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func _beam(start: Vector3, end: Vector3, width: float, material: String, target: Node3D = null) -> void:
	var length := start.distance_to(end)
	var mesh := box((start + end) / 2.0, Vector3(width, length, width), material, false, target)
	var axis := (end-start).normalized()
	mesh.quaternion = Quaternion(Vector3.UP, axis)

func _terrain(world_seed: int) -> void:
	var cells: Array[Vector2i] = Layout.generate(world_seed)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in cells:
		var points: Array[Vector3] = []
		for step in [Vector2.ZERO, Vector2(1,0), Vector2(0,1), Vector2(1,1)]:
			var x: float = cell.x + step.x - 0.5
			var z: float = cell.y + step.y - 0.5
			points.append(Vector3(x, height_at(x,z), z))
		for i in [0,1,2,1,3,2]:
			surface.set_uv(Vector2(points[i].x,points[i].z) * 0.25)
			surface.add_vertex(points[i])
		# Vertical coastline walls, integrated into the same mesh.
		for edge in [[Vector2i.LEFT,0,2],[Vector2i.RIGHT,3,1],[Vector2i.UP,1,0],[Vector2i.DOWN,2,3]]:
			if not cells.has(cell + edge[0]):
				var a: Vector3 = points[edge[1]]
				var b: Vector3 = points[edge[2]]
				for p in [a,b,Vector3(a.x,-7,a.z),b,Vector3(b.x,-7,b.z),Vector3(a.x,-7,a.z)]:
					surface.set_uv(Vector2(p.x,p.y) * 0.4)
					surface.add_vertex(p)
	surface.generate_normals()
	ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "TerrenoEmNiveis"
	ground_mesh.mesh = surface.commit()
	var shader := ShaderMaterial.new()
	shader.shader = load("res://shaders/ground.gdshader")
	shader.set_shader_parameter("grass_tex", materials.leafy_grass.albedo_texture)
	shader.set_shader_parameter("path_tex", materials.mossy_cobblestone.albedo_texture)
	shader.set_shader_parameter("rock_tex", materials.lichen_rock.albedo_texture)
	shader.set_shader_parameter("grass_normal",materials.leafy_grass.normal_texture)
	shader.set_shader_parameter("path_normal",materials.mossy_cobblestone.normal_texture)
	ground_mesh.material_override = shader
	parent.add_child(ground_mesh)
	ground_mesh.create_trimesh_collision()
	# Degraus decorativos margeiam a rampa; centro permanece continuo.
	for i in range(9):
		var z := -6.0 - float(i) * 0.85
		for x in [-1.8,1.8]:
			box(Vector3(x,height_at(x,z)+0.16,z), Vector3(0.6,0.3,0.65), "castle_brick_01")

func _water(cells: Array[Vector2i]) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(650,650)
	plane.subdivide_width = 60
	plane.subdivide_depth = 60
	water.mesh = plane
	water.position.y = -5.4
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	water.material_override = mat
	parent.add_child(water)
	var stream := MeshInstance3D.new()
	var river_plane := PlaneMesh.new()
	var left := 0.0
	var right := 0.0
	for cell in cells:
		if cell.y == 7 or cell.y == 8:
			left = minf(left,cell.x-0.5)
			right = maxf(right,cell.x+0.5)
	river_plane.size = Vector2(right-left,2.9)
	river_plane.subdivide_width = 90
	river_plane.subdivide_depth = 8
	stream.mesh = river_plane
	stream.position = Vector3((left+right)*0.5,-0.48,7.5)
	var river_material: ShaderMaterial = mat.duplicate()
	river_material.set_shader_parameter("stream_mode",true)
	stream.material_override = river_material
	parent.add_child(stream)
	for edge in [left,right]:
		var fall := MeshInstance3D.new()
		var curtain := PlaneMesh.new()
		curtain.size = Vector2(4.92,2.9)
		curtain.subdivide_width = 12
		curtain.subdivide_depth = 8
		fall.mesh = curtain
		fall.rotation.z = PI/2
		fall.position = Vector3(edge,-2.94,7.5)
		var foam := ShaderMaterial.new()
		foam.shader = load("res://shaders/waterfall.gdshader")
		fall.material_override = foam
		parent.add_child(fall)

func _house(pos: Vector3, unfinished: bool, factor: float = 1.0) -> void:
	var house := Node3D.new()
	house.name = "CasaModularEmObra" if unfinished else "CasaModular"
	house.position = pos
	house.scale = Vector3.ONE * factor
	parent.add_child(house)
	box(Vector3(0,0.22,0), Vector3(5.5,0.45,4.2), "castle_brick_01", true, house)
	if not unfinished:
		box(Vector3(0,1.7,0), Vector3(5,3,3.8), "plastered_stone_wall", true, house)
		box(Vector3(0,0.65,0),Vector3(5.08,0.8,3.88),"castle_brick_01",false,house)
	else:
		for x in [-2.3,0,2.3]:
			box(Vector3(x,1.5,0),Vector3(0.18,3,4),"wood",false,house)
		for z in [-1.9,1.9]:
			box(Vector3(0,0.85,z),Vector3(5,1.3,0.35),"castle_brick_01",true,house)
		for x in [-2.5,2.5]:
			for z in [-2.5,2.5]:
				_beam(Vector3(x,0,z),Vector3(x,3,z),0.13,"wood",house)
			_beam(Vector3(x,0,-2.5),Vector3(x,3,2.5),0.1,"wood",house)
		box(Vector3(0,1.6,2.6),Vector3(5.8,0.12,0.7),"brown_planks_03",false,house)
	for x in [-2.42,0,2.42]:
		box(Vector3(x,1.8,1.94),Vector3(0.16,3.15,0.16),"wood",false,house)
	box(Vector3(0,3.1,1.94),Vector3(5,0.18,0.18),"wood",false,house)
	if unfinished:
		for i in range(7):
			box(Vector3(3+rng.randf(),0.18,-1.5+i*0.35),Vector3(1,0.32,0.5),"castle_brick_01",false,house)
		return
	for x in [-1.3,1.3]:
		_beam(Vector3(x-0.8,0.95,1.96),Vector3(x+0.8,3.0,1.96),0.12,"wood",house)
	# Gable roof built from two tilted, textured reusable panels.
	for x in [-2.5,2.5]:
		var gable := SurfaceTool.new()
		gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point in [Vector3(x,3.1,-1.9),Vector3(x,4.25,0),Vector3(x,3.1,1.9)]:
			gable.add_vertex(point)
		gable.generate_normals()
		var face := MeshInstance3D.new()
		face.mesh = gable.commit()
		var mat: StandardMaterial3D = materials.castle_brick_01.duplicate()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		face.material_override = mat
		house.add_child(face)
	for side in [-1,1]:
		var roof := box(Vector3(0,3.65,side*1.08),Vector3(5.8,0.16,2.7),"grey_roof_tiles",false,house)
		roof.rotation.x = side * deg_to_rad(28)
		_beam(Vector3(-2.9,3.1,side*2.25),Vector3(2.9,3.1,side*2.25),0.16,"wood",house)
	_beam(Vector3(-2.9,4.3,0),Vector3(2.9,4.3,0),0.18,"wood",house)
	for x in [-2.6,2.6]:
		_beam(Vector3(x,3.05,-2.2),Vector3(x,4.3,0),0.18,"wood",house)
		_beam(Vector3(x,4.3,0),Vector3(x,3.05,2.2),0.18,"wood",house)
	box(Vector3(1.5,4.2,-0.6),Vector3(0.65,2,0.65),"castle_brick_01",false,house)
	box(Vector3(1.5,5.22,-0.6),Vector3(0.85,0.16,0.85),"castle_brick_01",false,house)
	box(Vector3(0,1.3,1.98),Vector3(0.95,2.1,0.12),"brown_planks_03",false,house)
	for x in [-1.55,1.55]:
		box(Vector3(x,1.9,1.97),Vector3(0.8,1.05,0.08),"wood",false,house)
		box(Vector3(x,1.9,2.025),Vector3(0.64,0.87,0.025),"glow",false,house)
		box(Vector3(x,1.9,2.05),Vector3(0.05,0.95,0.06),"wood",false,house)
		box(Vector3(x,1.9,2.05),Vector3(0.7,0.05,0.06),"wood",false,house)
	# Fachada lateral visivel na camera isometrica: enxaimel e venezianas.
	for x in [-2.54,2.54]:
		for z in [-1.8,0,1.8]:
			box(Vector3(x,1.85,z),Vector3(0.13,2.6,0.13),"wood",false,house)
		for y in [0.95,2.9]:
			box(Vector3(x,y,0),Vector3(0.13,0.16,3.8),"wood",false,house)
		for z in [-0.9,0.9]:
			box(Vector3(x*1.015,1.95,z),Vector3(0.1,0.75,0.58),"glow",false,house)
			box(Vector3(x*1.02,1.95,z),Vector3(0.14,0.8,0.055),"wood",false,house)
			box(Vector3(x*1.02,1.95,z),Vector3(0.14,0.055,0.62),"wood",false,house)
			_beam(Vector3(x,0.98,z-0.8),Vector3(x,2.85,z+0.8),0.11,"wood",house)
	_lantern(pos + Vector3(-0.8,2.3,2.5)*factor)
	# Alpendre modular: profundidade e abrigo, em vez de fachada plana.
	box(Vector3(0,0.24,2.65),Vector3(2.1,0.16,1.3),"brown_planks_03",false,house)
	for x in [-0.95,0.95]:
		_beam(Vector3(x,0.3,3.15),Vector3(x,2.5,3.15),0.13,"wood",house)
		_beam(Vector3(x,1.85,3.15),Vector3(x*0.5,2.5,3.15),0.09,"wood",house)
	for side in [-1,1]:
		var awning := box(Vector3(side*0.54,2.75,2.6),Vector3(1.4,0.1,1.8),"grey_roof_tiles",false,house)
		awning.rotation.z = -side*0.4
	for i in range(3):
		box(Vector3(-1.5,0.13+i*0.05,2.3+i*0.25),Vector3(1.3,0.15,0.4),"castle_brick_01",false,house)

func _lantern(pos: Vector3) -> void:
	box(pos,Vector3(0.19,0.32,0.19),"glow")
	box(pos+Vector3(0,0.2,0),Vector3(0.3,0.09,0.3),"iron")
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0,0,0.3)
	light.light_color = Color("ffbb68")
	light.light_energy = 1.5
	light.add_to_group("night_lights")
	light.omni_range = 5
	parent.add_child(light)

func _farm() -> void:
	var seedlings: Array[Vector3] = []
	for x in [-7.1,-4.1]:
		for z in [0.5,2.9]:
			box(Vector3(x,0.025,z),Vector3(2.5,0.06,1.9),"soil")
			for row in range(4):
				box(Vector3(x-0.9+row*0.6,0.07,z),Vector3(0.15,0.08,1.8),"grass_path_3")
				for col in range(3):
					var crop_pos := Vector3(x-0.9+row*0.6,0.18,z-0.6+col*0.6)
					seedlings.append(crop_pos)
	_seedlings(seedlings)
	# Aboboras como volumes 3D junto a casa.
	for i in range(6):
		var p := Vector3(-9+rng.randf()*1.6,0.2,2+rng.randf()*1.3)
		_rock(p,Vector3(0.28,0.25,0.28),"gold")
		box(p+Vector3(0,0.2,0),Vector3(0.05,0.2,0.05),"wood")

func _fence(start: Vector3, end: Vector3) -> void:
	var count := ceili(start.distance_to(end)/1.5)
	for i in range(count+1):
		var pos := start.lerp(end,float(i)/count)
		pos.y = height_at(pos.x,pos.z)
		box(pos+Vector3(0,0.55,0),Vector3(0.13,1.1,0.13),"wood")
		if i < count:
			var next := start.lerp(end,float(i+1)/count)
			next.y = height_at(next.x,next.z)
			for y in [0.4,0.85]:
				_beam(pos+Vector3(0,y,0),next+Vector3(0,y,0),0.1,"brown_planks_03")
	var barrier:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(0.14,1.1,start.distance_to(end))
	collision.shape=shape
	barrier.position=(start+end)/2+Vector3(0,height_at((start.x+end.x)/2,(start.z+end.z)/2)+0.55,0)
	var direction:=end-start
	direction.y=0
	barrier.quaternion=Basis.looking_at(direction).get_rotation_quaternion()
	barrier.add_child(collision)
	parent.add_child(barrier)

func _well(pos: Vector3) -> void:
	for i in range(12):
		var angle := i * TAU/12
		var stone := box(pos+Vector3(cos(angle)*0.65,0.45,sin(angle)*0.65),Vector3(0.36,0.8,0.3),"castle_brick_01")
		stone.rotation.y = -angle
	for x in [-0.8,0.8]:
		box(pos+Vector3(x,1.2,0),Vector3(0.13,2.4,0.13),"wood")
	for side in [-1,1]:
		var roof := box(pos+Vector3(0,2.4,side*0.4),Vector3(2.1,0.1,1.05),"grey_roof_tiles")
		roof.rotation.x = side*0.45

func _bridge_height(pos: Vector3, z: float) -> float:
	var t := clampf((z+2.55)/5.1,0,1)
	return lerpf(height_at(pos.x,pos.z-2.55),height_at(pos.x,pos.z+2.55),t)+sin(t*PI)*0.12

func _bridge(pos: Vector3) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(20):
		var z := -2.55+i*5.1/20
		var next_z := z+5.1/20
		var h := _bridge_height(pos,z)-0.015
		var next_h := _bridge_height(pos,next_z)-0.015
		var points := [Vector3(-1.12,h,z),Vector3(1.12,h,z),Vector3(-1.12,next_h,next_z),Vector3(1.12,next_h,next_z)]
		for index in [0,1,2,1,3,2]:
			surface.add_vertex(pos+points[index])
	surface.generate_normals()
	var deck := MeshInstance3D.new()
	deck.name = "TabuleiroContinuoDaPonte"
	deck.mesh = surface.commit()
	deck.material_override = materials.wood
	parent.add_child(deck)
	deck.create_trimesh_collision()
	for i in range(19):
		var z := i*0.27-2.4
		box(pos+Vector3(0,_bridge_height(pos,z)-0.06,z),Vector3(2.3,0.12,0.25),"brown_planks_03")
	for x in [-1.2,1.2]:
		for z in [-2.3,0,2.3]:
			box(pos+Vector3(x,_bridge_height(pos,z)+0.5,z),Vector3(0.16,1.15,0.16),"wood")
		for y in [0.45,0.95]:
			for ends in [[-2.4,0],[0,2.4]]:
				_beam(pos+Vector3(x,_bridge_height(pos,ends[0])+y,ends[0]),pos+Vector3(x,_bridge_height(pos,ends[1])+y,ends[1]),0.1,"brown_planks_03")
		for z in [-2,2]:
			box(pos+Vector3(x,-0.8,z),Vector3(0.25,2,0.25),"wood")

func _rock(pos: Vector3, size: Vector3, material: String = "lichen_rock") -> void:
	var mesh := MeshInstance3D.new()
	if body_mesh == null:
		body_mesh = SphereMesh.new()
		body_mesh.radial_segments = 9
		body_mesh.rings = 5
	mesh.mesh = body_mesh
	mesh.material_override = materials[material]
	mesh.position = pos
	mesh.scale = size
	mesh.rotation = Vector3(rng.randf(),rng.randf()*TAU,rng.randf()*0.5)
	parent.add_child(mesh)

func _tree(pos: Vector3, factor: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE*factor
	parent.add_child(tree)
	_beam(Vector3.ZERO,Vector3(0.2,4,0),0.32,"brown_planks_03",tree)
	for i in range(7):
		var angle := i*2.4
		var end := Vector3(cos(angle)*1.5,2.8+float(i)*0.25,sin(angle)*1.4)
		_beam(Vector3(0,1.7,0),end,0.14,"wood",tree)
		# Plusieurs irregular, low-poly crowns; silhouettes remain volumetric.
		for j in range(3):
			var leaves := MeshInstance3D.new()
			leaves.mesh = body_mesh
			leaves.material_override = materials.leaf
			leaves.position = end+Vector3(rng.randf_range(-0.5,0.5),rng.randf()*0.4,rng.randf_range(-0.4,0.4))
			leaves.scale = Vector3(1.2,0.75,1.1)
			tree.add_child(leaves)

func _ruin(pos: Vector3, factor: float) -> void:
	var ruin := Node3D.new()
	ruin.position = pos
	ruin.scale = Vector3.ONE*factor
	parent.add_child(ruin)
	for x in [-2.4,2.4]:
		box(Vector3(x,2.8,0),Vector3(1.1,5.6,1.5),"castle_brick_01",true,ruin)
		box(Vector3(x,0.35,0),Vector3(1.5,0.7,1.9),"castle_brick_01",false,ruin)
	for i in range(9):
		var angle := PI*float(i)/8
		var p := Vector3(cos(angle)*2.4,5.0+sin(angle)*2.4,0)
		var brick := box(p,Vector3(0.95,0.8,1.5),"castle_brick_01",false,ruin)
		brick.rotation.z = angle-PI/2
	for i in range(8):
		box(Vector3(rng.randf_range(-4,4),0.2,rng.randf_range(-2,2)),Vector3(0.8,0.5,0.6),"castle_brick_01",false,ruin)

func _tower(pos: Vector3, factor: float) -> void:
	var tower := Node3D.new()
	tower.position = pos
	tower.scale = Vector3.ONE*factor
	parent.add_child(tower)
	box(Vector3(0,5,0),Vector3(4.5,10,4.5),"castle_brick_01",false,tower)
	for x in [-2.0,0,2.0]:
		for z in [-2.0,2.0]:
			box(Vector3(x,10.5,z),Vector3(1.1,rng.randf_range(1.2,2.4),1),"castle_brick_01",false,tower)
	for y in [3.0,6.5,9.0]:
		box(Vector3(0,y,2.26),Vector3(0.5,1.6,0.03),"iron",false,tower)

func _clear_zone(x: float, z: float) -> bool:
	if absf(x) < 2.0 or absf(z+1) < 1.4 or absf(z-7.5) < 2.0:
		return true
	for area in [Rect2(-11,-8,7,13),Rect2(1,-13,8,16),Rect2(7,-8,8,7),Rect2(-10,-20,7,8)]:
		if area.has_point(Vector2(x,z)):
			return true
	return false

func _grass(world_seed: int) -> void:
	var grass_script = load("res://addons/simplegrasstextured/grass.gd")
	var grass = grass_script.new()
	grass.name = "VegetacaoSimpleGrass"
	grass.interactive = false
	grass.albedo = Color("6f9554")
	grass.grass_strength = 0.72
	grass.scale_h = 0.55
	grass.scale_w = 0.8
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(grass)
	var transforms: Array[Transform3D] = []
	var cells := Layout.generate(world_seed)
	for i in range(18000):
		var x := rng.randf_range(-23,23)
		var z := rng.randf_range(-23,23)
		if not cells.has(Vector2i(roundi(x),roundi(z))) or _clear_zone(x,z):
			continue
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.4,1.0))
		transforms.append(Transform3D(basis,Vector3(x,height_at(x,z)-0.02,z)))
	grass.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		grass.multimesh.set_instance_transform(i,transforms[i])

func _flowers(cells: Array[Vector2i]) -> void:
	var petals := SphereMesh.new()
	petals.radial_segments = 5
	petals.rings = 3
	petals.radius = 0.075
	petals.height = 0.08
	for tint in [Color("e9dca8"),Color("adb3cf"),Color("d7ac59")]:
		var batch := MultiMeshInstance3D.new()
		batch.material_override = _color(tint)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = petals
		var points: Array[Transform3D] = []
		for patch in range(35):
			var center := Vector2(rng.randf_range(-20,20),rng.randf_range(-19,18))
			if _clear_zone(center.x,center.y) or not cells.has(Vector2i(center.round())):
				continue
			for i in range(22):
				var p := center+Vector2(rng.randfn(0,0.65),rng.randfn(0,0.65))
				if not _clear_zone(p.x,p.y):
					points.append(Transform3D(Basis.IDENTITY,Vector3(p.x,height_at(p.x,p.y)+rng.randf_range(0.14,0.32),p.y)))
		multi.instance_count = points.size()
		for i in range(points.size()):
			multi.set_instance_transform(i,points[i])
		batch.multimesh = multi
		parent.add_child(batch)


func _landmarks() -> void:
	# Pedra votiva autoral: agricultura resiste sob as ruinas.
	var origin := Vector3(8,height_at(8,-2),-2)
	box(origin+Vector3(0,0.2,0),Vector3(1.7,0.4,1.5),"castle_brick_01")
	box(origin+Vector3(0,1.3,0),Vector3(0.8,2.0,0.65),"lichen_rock")
	box(origin+Vector3(0,2.45,0),Vector3(1.1,0.3,0.95),"castle_brick_01")
	var rune := TorusMesh.new()
	rune.inner_radius = 0.27
	rune.outer_radius = 0.34
	rune.rings = 20
	rune.ring_segments = 6
	var symbol := MeshInstance3D.new()
	symbol.mesh = rune
	symbol.material_override = materials.gold
	symbol.rotation.x = PI/2
	symbol.position = origin+Vector3(0,1.7,0.36)
	parent.add_child(symbol)
	for p in [Vector2(-2,5),Vector2(2,10),Vector2(2,-5),Vector2(-3,-13)]:
		var foot := Vector3(p.x,height_at(p.x,p.y),p.y)
		box(foot+Vector3(0,1.35,0),Vector3(0.13,2.7,0.13),"wood")
		_beam(foot+Vector3(0,2.65,0),foot+Vector3(0.5,2.65,0),0.09,"iron")
		_lantern(foot+Vector3(0.5,2.35,0))
	# Carrinho de colheita reutilizavel feito de modulos.
	var cart := Vector3(-10,0.5,5)
	box(cart,Vector3(1.6,0.12,0.95),"brown_planks_03")
	for z in [-0.5,0.5]:
		box(cart+Vector3(0,0.27,z),Vector3(1.65,0.5,0.1),"brown_planks_03")
		var wheel := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		disk.top_radius = 0.42
		disk.bottom_radius = 0.42
		disk.height = 0.1
		disk.radial_segments = 12
		wheel.mesh = disk
		wheel.material_override = materials.wood
		wheel.rotation.x = PI/2
		wheel.position = cart+Vector3(0,-0.2,z*1.25)
		parent.add_child(wheel)
		_beam(cart+Vector3(0.7,0,z*0.6),cart+Vector3(2.5,-0.3,z*0.6),0.09,"wood")
	for i in range(9):
		_rock(cart+Vector3(rng.randf_range(-0.6,0.6),0.18,rng.randf_range(-0.3,0.3)),Vector3.ONE*0.22,"gold")


func _cliff_details(cells: Array[Vector2i]) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	var batch := MultiMeshInstance3D.new()
	batch.material_override = materials.lichen_rock
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	var transforms: Array[Transform3D] = []
	for cell in cells:
		var boundary := false
		for edge in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not cells.has(cell+edge):
				boundary = true
		if boundary and absf(cell.y-7.5)>2.0:
			var top := height_at(cell.x,cell.y)
			var height := top+6
			var scale := Vector3(rng.randf_range(1.2,2.2),height*0.9,rng.randf_range(1.3,2.4))
			var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(scale)
			transforms.append(Transform3D(basis,Vector3(cell.x,top-height*0.5,cell.y)))
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i,transforms[i])
	batch.multimesh = multi
	parent.add_child(batch)



func _seedlings(points: Array[Vector3]) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(7):
		var angle := i*TAU/7
		var outward := Vector3(cos(angle),0,sin(angle))
		var side := outward.cross(Vector3.UP)*0.07
		var tip := outward*0.28+Vector3(0,0.32+(i%3)*0.03,0)
		var middle := outward*0.1+Vector3(0,0.28,0)
		for p in [Vector3.ZERO,middle-side,middle+side,middle-side,tip,middle+side]:
			surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	var batch := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = points.size()
	for i in range(points.size()):
		multimesh.set_instance_transform(i,Transform3D(Basis(Vector3.UP,i*2.4),points[i]))
	batch.multimesh = multimesh
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/seedling.gdshader")
	batch.material_override = material
	parent.add_child(batch)

func _building_plot(pos: Vector3) -> void:
	box(pos+Vector3(0,0.025,0),Vector3(5.2,0.05,4.1),"grass_path_3")
	for x in [-2.65,2.65]:
		for z in [-2.1,0,2.1]:
			box(pos+Vector3(x,0.5,z),Vector3(0.12,1,0.12),"wood")
		for y in [0.35,0.75]:
			_beam(pos+Vector3(x,y,-2.1),pos+Vector3(x,y,2.1),0.07,"wood")
	for z in [-2.1,2.1]:
		for ends in [[-2.65,-0.65],[0.65,2.65]]:
			_beam(pos+Vector3(ends[0],0.65,z),pos+Vector3(ends[1],0.65,z),0.07,"wood")
	# Entrada central de 1,3 m: o lote e exploravel a pe.
	box(pos+Vector3(-1.8,0.35,2.6),Vector3(0.7,0.55,0.12),"brown_planks_03")
	box(pos+Vector3(-1.8,0.2,2.6),Vector3(0.1,1.0,0.1),"wood")
