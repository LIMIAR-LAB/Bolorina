extends "res://scripts/island.gd"
## Laboratorio independente: composicao fixa, sem ler nem alterar o progresso.
var lit_sprites := true
var border_vegetation: Node3D
var foliage_dense := true
var dressing
var river_material: ShaderMaterial
var village_cat: AnimatedSprite3D
var village_resident: AnimatedSprite3D

func _load() -> void:
	world_seed = 41826
	suppress_saves = true

func _save() -> void:
	pass

func _actor(character: String) -> AnimatedSprite3D:
	var selected := character
	if character=="original_apprentice" and FileAccess.file_exists("res://art/characters/original_vale_v6/manifest.json"):
		selected = "original_vale_v6"
	elif character=="original_gardener":
		selected = "original_mira_v6"
	var actor := super._actor(selected)
	actor.manifest.world_height = 1.48
	var common_height := 36.0
	for info in actor.manifest.anims.values():
		common_height = maxf(common_height,float(info.bounds[3]-info.bounds[1]))
	actor.manifest.min_normalization_height = common_height
	actor._ground_frame()
	return actor

func _ready() -> void:
	super._ready()
	DisplayServer.window_set_title("Ilha das Cinzas | Vilarejo de referencia")
	zoom_target = 0.94
	var lens := CameraAttributesPractical.new()
	lens.dof_blur_near_enabled = true
	lens.dof_blur_near_distance = 25.0
	lens.dof_blur_near_transition = 10.0
	lens.dof_blur_far_enabled = true
	lens.dof_blur_far_distance = 78.0
	lens.dof_blur_far_transition = 30.0
	lens.dof_blur_amount = 0.055
	camera.attributes = lens
	for actor in [sprite,npc,enemy]:
		actor.layers = 1 << 19
		# Luz de preenchimento exclusiva dos atores, alem das luzes do mundo.
		# Mantem o material nativo e suas texturas animadas sem emissao artificial.
		var fill := OmniLight3D.new()
		fill.name = "PreenchimentoDoSprite"
		fill.light_cull_mask = 1 << 19
		fill.light_color = Color("b5c6da")
		fill.light_energy = 1.45
		fill.omni_range = 5.5
		fill.position = Vector3(1.5,2.5,2)
		actor.add_child(fill)
	_set_sprite_lighting()
	village_cat = ActorVisual.new()
	village_cat.setup("original_cat_v6")
	village_cat.manifest.world_height = 0.64
	village_cat.manifest.min_normalization_height = 25
	village_cat._ground_frame()
	village_cat.shaded = true
	village_cat.position = Vector3(1.1,0,1.2)
	ground.add_child(village_cat)
	# Morador cenografico distinto; a companhia continua sendo apenas Mira.
	village_resident = ActorVisual.new()
	village_resident.setup("original_apprentice")
	village_resident.manifest.world_height = 1.4
	village_resident.facing_direction = "south-west"
	village_resident.play(village_resident.animation_for("idle"))
	village_resident._ground_frame()
	village_resident.shaded = true
	village_resident.position = Vector3(2.3,VisualWorld.height_at(2.3,-1.4),-1.4)
	ground.add_child(village_resident)
	atmosphere.set_hour(16.0)
	atmosphere.settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	atmosphere.settings.adjustment_saturation = 1.13
	atmosphere.settings.adjustment_contrast = 1.09
	atmosphere.settings.ssao_intensity = 1.2
	atmosphere.settings.glow_intensity = 0.62
	atmosphere.settings.volumetric_fog_density = 0.00045
	for shaft in atmosphere.shafts:
		shaft.hide()
	for node in get_children():
		if node is FogVolume:
			node.material.density = 0.0007
	for i in farm.plots.size():
		farm.plots[i].stage = 0 if i==8 else 2
	_detail_crops()
	farm.refresh()
	call_deferred("_reference_title")
	message.text = "Cena de referencia | F6: comparar luz nos sprites | F7: vegetacao | L: anoitecer | H: interface"

func _reference_title() -> void:
	DisplayServer.window_set_title("Ilha das Cinzas | Vilarejo V6")

func _detail_crops() -> void:
	for index in farm.plots.size():
		var plant: Node3D = farm.plots[index].plant
		for node in plant.get_children():
			node.hide()
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for dx in [-0.22,0.22]:
			for dz in [-0.22,0.22]:
				for leaf in range(9):
					var angle := leaf*TAU/9
					var forward := Vector3(cos(angle),0,sin(angle))
					var side := Vector3(-sin(angle),0,cos(angle))
					var center := Vector3(dx,0,dz)
					var radius := 0.15 if index%3==0 else 0.24
					var height := 0.42 if index%3==0 else 0.21
					var points := [center+Vector3(0,0.05,0),center+forward*radius*0.65-side*0.09+Vector3(0,height*0.55,0),center+forward*radius+Vector3(0,height,0),center+forward*radius*0.65+side*0.09+Vector3(0,height*0.55,0)]
					for vertex in [0,1,2,0,2,3]:
						surface.set_color(Color("537329").lerp(Color("8b9e40"),float(leaf%4)/4))
						surface.add_vertex(points[vertex])
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.9
		mesh.material_override = material
		plant.add_child(mesh)

func _build_world() -> void:
	super._build_world()
	# Materiais compartilhados: mesma paleta em todos os modulos desta cena.
	art_world.materials.grey_roof_tiles.albedo_color = Color("526578")
	art_world.materials.brown_planks_03.albedo_color = Color("a18a6b")
	art_world.materials.plastered_stone_wall.albedo_color = Color("d5c4a2")
	for material in art_world.materials.values():
		if material is StandardMaterial3D and material.normal_enabled:
			material.normal_scale = 0.35
	# Evita o tapete uniforme de samambaias: ficam ilhas de detalhe.
	var fern_index := 0
	for node in ground.get_children():
		# O poco ocupa a frente da praca, alinhado ao eixo do protagonista.
		if node is MeshInstance3D and absf(node.position.x-3.8)<1.0 and absf(node.position.z-0.8)<0.85 and node.position.y<3.0:
			node.position += Vector3(-0.9,0,4.1)
		if node is MeshInstance3D and node.mesh is BoxMesh and node.mesh.size.is_equal_approx(Vector3(5.2,0.05,4.1)):
			var plot_material: StandardMaterial3D = art_world.materials.soil.duplicate()
			plot_material.albedo_color = Color("98774d")
			node.material_override = plot_material
		if node is MeshInstance3D and node.mesh is PlaneMesh and absf(node.position.y+0.48)<0.01:
			river_material = ShaderMaterial.new()
			river_material.shader = load("res://shaders/reference_water.gdshader")
			node.material_override = river_material
		if node.name == "VegetacaoSimpleGrass":
			node.scale_h = 0.3
			node.scale_w = 0.5
			node.multimesh.visible_instance_count = int(node.multimesh.instance_count*0.65)
		if node is Node3D and "fern_02" in node.scene_file_path:
			node.visible = fern_index % 4 == 0
			fern_index += 1
	border_vegetation = Node3D.new()
	border_vegetation.name = "BordasFloridas"
	ground.add_child(border_vegetation)
	_make_border_plants()
	_make_autumn_trees()
	_make_banners()
	dressing = preload("res://scripts/reference_dressing.gd").new()
	dressing.build(art_world,ground)
	art_world.materials.crop.albedo_color = Color("6c8736")
	cut_tree.canopy_material.shader = load("res://shaders/reference_leaves.gdshader")
	var well_body := StaticBody3D.new()
	well_body.name = "ColisaoDoPoco"
	well_body.position = Vector3(2.9,0.6,4.9)
	var well_collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.78
	cylinder.height = 1.2
	well_collision.shape = cylinder
	well_body.add_child(well_collision)
	ground.add_child(well_body)

func _set_sprite_lighting() -> void:
	for actor in [sprite, npc, enemy, village_cat, village_resident]:
		if actor==null:
			continue
		actor.shaded = lit_sprites
		actor.double_sided = true
		actor.modulate = Color.WHITE
		# Sombra de contato permanece estavel quando o billboard muda de direcao.
		actor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if lit_sprites:
		# A cor noturna vem das luzes reais, sem uma segunda tinta azul artificial.
		sprite.modulate = Color.WHITE
		npc.modulate = Color.WHITE
		village_cat.modulate = Color.WHITE
		village_resident.modulate = Color.WHITE

func _process(delta: float) -> void:
	super._process(delta)
	var night := smoothstep(17.8,19.8,atmosphere.hour)
	# Contraste de luz localizada sem a nevoa amarela cobrindo toda a vila.
	atmosphere.settings.ambient_light_energy = lerpf(0.72,0.34,night)
	atmosphere.settings.ambient_light_color = Color("91afc3").lerp(Color("6686b6"),night)
	art_world.materials.glow.emission = Color("ff9f32")
	art_world.materials.glow.emission_energy_multiplier = lerpf(2.8,3.2,night)
	for shaft in atmosphere.shafts:
		shaft.hide()
	for light in get_tree().get_nodes_in_group("facade_lights"):
		light.light_energy = lerpf(1.4,2.1,night)
	if river_material:
		river_material.set_shader_parameter("daylight",1.0-night)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F6:
				lit_sprites = not lit_sprites
				_set_sprite_lighting()
				message.text = "Sprites: luz 3D real" if lit_sprites else "Sprites: cor propria (comparacao)"
				return
			KEY_F7:
				foliage_dense = not foliage_dense
				border_vegetation.visible = foliage_dense
				return
			KEY_F8:
				message.text = "Esta cena mantem a mesma ilha para comparar qualidade visual."
				return
			KEY_F5:
				message.text = "Laboratorio visual: o progresso da aventura fica preservado."
				return
	super._unhandled_key_input(event)

func _make_border_plants() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 5401
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Touceira com folhas cruzadas e flores: um unico mesh por lote de instancias.
	for blade in range(5):
		var angle := blade * TAU / 5
		var side := Vector3(cos(angle),0,sin(angle)) * 0.055
		var tip := Vector3(cos(angle)*0.12,0.32+blade*0.025,sin(angle)*0.12)
		for point in [-side,side,tip]:
			surface.set_color(Color("697b35"))
			surface.add_vertex(point)
	for petal in range(5):
		var angle := petal * TAU / 5
		var center := Vector3(0,0.4,0)
		var outside := Vector3(cos(angle)*0.08,0.41,sin(angle)*0.08)
		var across := Vector3(-sin(angle),0,cos(angle))*0.035
		for point in [center,outside+across,outside-across]:
			surface.set_color(Color("eee4bd"))
			surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/reference_flowers.gdshader")
	var transforms: Array[Transform3D] = []
	for i in range(5200):
		var x := random.randf_range(-15,16)
		var z := random.randf_range(-15,12)
		# Fileiras irregulares nas margens das ruas; corredores continuam vazios.
		var edge := (absf(x)>2.15 and absf(x)<3.15) or (absf(z+1)>1.65 and absf(z+1)<2.35) or (absf(z-7.5)>2.05 and absf(z-7.5)<2.7)
		if not edge or not cells.has(Vector2i(roundi(x),roundi(z))):
			continue
		if Rect2(-11,-8,7,13).has_point(Vector2(x,z)) or Rect2(1,-13,8,8).has_point(Vector2(x,z)) or Rect2(7,-8,8,7).has_point(Vector2(x,z)):
			continue
		var basis := Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*random.randf_range(0.65,1.35))
		transforms.append(Transform3D(basis,Vector3(x,VisualWorld.height_at(x,z),z)))
	var batch := MultiMeshInstance3D.new()
	batch.name = "FloresInstanciadas"
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = transforms.size()
	for i in transforms.size():
		batch.multimesh.set_instance_transform(i,transforms[i])
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	border_vegetation.add_child(batch)

func _make_autumn_trees() -> void:
	for entry in [Vector3(-12,0,-7),Vector3(13,0,-11),Vector3(-14,0,5),Vector3(17,0,5),Vector3(-14,0,-15)]:
		var factory = ChoppableTree.new()
		factory.art = art_world
		var tree: Node3D = factory._make_tree()
		tree.name = "ArvoreOutonal"
		tree.position = Vector3(entry.x,VisualWorld.height_at(entry.x,entry.z),entry.z)
		ground.add_child(tree)
		var leaves: MultiMeshInstance3D = tree.get_node("FolhasLargasAoSol")
		var leaf_mat := ShaderMaterial.new()
		leaf_mat.shader = load("res://shaders/reference_leaves.gdshader")
		leaves.material_override = leaf_mat
		for i in leaves.multimesh.instance_count:
			var transform := leaves.multimesh.get_instance_transform(i)
			transform.basis = transform.basis.scaled(Vector3.ONE*0.62)
			leaves.multimesh.set_instance_transform(i,transform)
			var tint := Color("546c32") if i%3==0 else Color("96712e")
			if i%7==0:
				tint = Color("9c3a23")
			leaves.multimesh.set_instance_color(i,tint)
		factory.free()

func _make_banners() -> void:
	for origin in [Vector3(-5.8,0,-2.98),Vector3(5.7,0,-8.27)]:
		origin.y = VisualWorld.height_at(origin.x,origin.z)
		var mesh := MeshInstance3D.new()
		var flag := PlaneMesh.new()
		flag.size = Vector2(0.65,1.35)
		flag.subdivide_width = 4
		flag.subdivide_depth = 8
		mesh.mesh = flag
		mesh.rotation.x = PI/2
		mesh.position = origin+Vector3(0,2.05,0)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/reference_banner.gdshader")
		mesh.material_override = material
		ground.add_child(mesh)
