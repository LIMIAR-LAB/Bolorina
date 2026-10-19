extends Node3D
## Laboratorio visual: mundo 3D modular e personagens originais em oito direcoes.
const Layout = preload("res://scripts/world_layout.gd")
const VisualWorld = preload("res://scripts/visual_world.gd")
const ActorVisual = preload("res://scripts/actor_visual.gd")
const Atmosphere = preload("res://scripts/visual_atmosphere.gd")
const FarmPlots = preload("res://scripts/farm_plots.gd")
const ChoppableTree = preload("res://scripts/choppable_tree.gd")
var tools_visual
var farm
var cut_tree
var farm_save: Array=[]
var tree_felled:=false
var tree_logs:=0
var wood:=0
var follow_trail: Array[Vector3]=[]
var atmosphere
var demo_input := Vector2.ZERO
var demo_running := false
var demo_mode := false
var suppress_saves:=false
const CAMERA_YAW := PI/4.0
const CAMERA_OFFSET := Vector3(24,24,24)
var art_world
var phantom
var camera_yaw := 0.0
var zoom_target := 1.0
var zoom_current := 1.0
var overview := false
var ui_layer: CanvasLayer
var camera_anchor: Node3D
const SPEED := 2.8
const RUN_MULT := 1.8
const DODGE_SPEED := 10.0
const DODGE_DURATION := 0.22
const DODGE_COST := 25.0
const ATTACK_DAMAGE := 18.0
const ATTACK_RANGE := 1.9
const ATTACK_COOLDOWN := 0.42
const ENEMY_DAMAGE := 12.0
const SAVE_FILE := "user://island_v1.json"
var world_seed := 41826
var ground: Node3D
var cells: Array[Vector2i] = []
var player: CharacterBody3D
var sprite: AnimatedSprite3D
var ally: AnimatedSprite3D
var camera: Camera3D
var npc: AnimatedSprite3D
var enemy: AnimatedSprite3D
var crop: MeshInstance3D
var hud: Label
var message: Label
var health := 100.0
var stamina := 100.0
var enemy_health := 90.0
var attack_timer := 0.0
var dodge_timer := 0.0
var enemy_timer := 1.5
var crop_stage := 0
var harvests := 0
var day := 1
var recruited := false
var arena := false
var yaw := 0.0
var facing := Vector3.FORWARD
var dodge_direction := Vector3.FORWARD
var home_position := Vector3.ZERO
var clock_time := 0.0

func _ready() -> void:
	ground = Node3D.new()
	add_child(ground)
	_load()
	recruited=false # Companhia precisa de pedido explicito nesta sessao.
	_build_world()
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.4, 2)
	add_child(player)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.0
	collision.shape = shape
	collision.position.y = 0.5
	player.add_child(collision)
	sprite = _actor("original_apprentice")
	player.add_child(sprite)
	sprite.position = Vector3.ZERO
	tools_visual=preload("res://scripts/tool_visual.gd").new()
	player.add_child(tools_visual)
	tools_visual.setup()
	player.floor_snap_length = 0.6
	player.floor_max_angle = deg_to_rad(48)
	player.floor_constant_speed = true
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21.5
	camera.far = 500
	camera.near = 0.15
	add_child(camera)
	_setup_camera()
	atmosphere = Atmosphere.new()
	atmosphere.install(self)
	_setup_ui()
	_update_camera(1.0)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title := Label.new()
	title.position = Vector2(30,22)
	title.text = "ILHA DAS CINZAS"
	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia"])
	title.add_theme_font_override("font",title_font)
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("e6d4a6"))
	title.add_theme_color_override("font_shadow_color",Color(0,0,0,0.85))
	title.add_theme_constant_override("shadow_offset_x",2)
	title.add_theme_constant_override("shadow_offset_y",2)
	ui_layer.add_child(title)
	hud = Label.new()
	hud.position = Vector2(32,55)
	hud.add_theme_font_size_override("font_size",14)
	hud.add_theme_color_override("font_shadow_color",Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x",1)
	hud.add_theme_constant_override("shadow_offset_y",1)
	ui_layer.add_child(hud)
	var bottom := ColorRect.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -63
	bottom.color = Color(0.035,0.043,0.047,0.84)
	ui_layer.add_child(bottom)
	var controls := Label.new()
	controls.position = Vector2(25,13)
	controls.text = "WASD andar | Shift correr | E interagir | R regar | F cortar | C companhia | L por do sol | H interface"
	controls.add_theme_font_size_override("font_size",14)
	bottom.add_child(controls)
	message = Label.new()
	message.position = Vector2(25,36)
	message.add_theme_font_size_override("font_size",13)
	message.add_theme_color_override("font_color",Color("ccbf9f"))
	message.text = "Horta a esquerda: E planta, R rega. Arvore junto da cerca: 3 golpes com F; E recolhe madeira."
	bottom.add_child(message)

func _setup_camera() -> void:
	camera_anchor = Node3D.new()
	camera_anchor.name = "EnquadramentoFixo"
	camera_anchor.position = player.position + Vector3(-2.2,0,-2.2)
	add_child(camera_anchor)
	var host = load("res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd").new()
	camera.add_child(host)
	phantom = load("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd").new()
	phantom.name = "CameraIsometrica"
	phantom.follow_mode = 2
	phantom.follow_target = camera_anchor
	phantom.follow_offset = CAMERA_OFFSET
	phantom.follow_damping = true
	phantom.follow_damping_value = Vector3(0.35,0.65,0.35)
	phantom.priority = 10
	phantom.position = camera_anchor.position + CAMERA_OFFSET
	phantom.quaternion = Basis.looking_at(-CAMERA_OFFSET).get_rotation_quaternion()
	add_child(phantom)

func _actor(character: String) -> AnimatedSprite3D:
	var actor := ActorVisual.new()
	actor.setup(character)
	return actor

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

func _build_world() -> void:
	for child in ground.get_children():
		ground.remove_child(child)
		child.queue_free()
	cells = Layout.generate(world_seed)
	art_world = VisualWorld.new()
	art_world.build(ground, world_seed)
	farm=FarmPlots.new()
	ground.add_child(farm)
	farm.setup(art_world)
	farm.restore(farm_save)
	if farm_save.is_empty() and crop_stage>0:
		farm.plots[0].stage=crop_stage
		farm.refresh()
	cut_tree=ChoppableTree.new()
	ground.add_child(cut_tree)
	cut_tree.setup(art_world,Vector3(-11,VisualWorld.height_at(-11,1),1),tree_felled,tree_logs)

	npc = _actor("original_gardener")
	ground.add_child(npc)
	npc.position = Vector3(-6,0,-2)
	enemy = _actor("original_gardener")
	ground.add_child(enemy)
	enemy.position = Vector3(12,VisualWorld.height_at(12,12),12)
	enemy.modulate = Color("aa8d83")
	enemy.visible = false
	ally=npc
	follow_trail.clear()


func _process(delta: float) -> void:
	_update_camera(delta)
	atmosphere.advance(delta)
	farm.highlight(player.position)

func _physics_process(delta: float) -> void:
	clock_time += delta
	attack_timer = maxf(0, attack_timer - delta)
	dodge_timer = maxf(0, dodge_timer - delta)
	stamina = minf(100, stamina + delta * 18)
	var input := demo_input if demo_mode else Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	if sprite.action_timer > 0:
		input = Vector2.ZERO
	var running := demo_running if demo_mode else Input.is_physical_key_pressed(KEY_SHIFT)
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, CAMERA_YAW)
	if arena:
		direction = Vector3(input.x, 0, 0)
	if direction.length() > 0.1:
		facing = direction
	var speed := SPEED * (RUN_MULT if running else 1.0)
	if dodge_timer > 0:
		direction = dodge_direction
		speed = DODGE_SPEED
	var vertical_speed := player.velocity.y
	var horizontal := Vector3(player.velocity.x,0,player.velocity.z).move_toward(direction*speed,32*delta)
	player.velocity = horizontal
	player.velocity.y = 0 if player.is_on_floor() else vertical_speed - 18 * delta
	var previous := player.position
	player.move_and_slide()
	var cell := Vector2i(roundi(player.position.x), roundi(player.position.z))
	if not cells.has(cell) or (absf(player.position.z-7.5)<1.65 and absf(player.position.x)>1.05):
		player.position = previous
	if arena:
		player.position.z = 4
		player.position.x = clampf(player.position.x, -5.0, 7.0)
	sprite.set_direction(input if dodge_timer <= 0 else Vector2(dodge_direction.rotated(Vector3.UP,-CAMERA_YAW).x,dodge_direction.rotated(Vector3.UP,-CAMERA_YAW).z))
	sprite.modulate = Color("f4dcb5") if dodge_timer > 0 else Color.WHITE.lerp(Color("a1b2d9"),smoothstep(17.8,19.8,atmosphere.hour))
	sprite.set_motion(horizontal.length() > 0.1, running, dodge_timer > 0, attack_timer > 0.1)
	if arena and enemy_health > 0 and enemy.position.distance_to(player.position) < 7:
		var target := Vector3(player.position.x, player.position.y, player.position.z)
		if enemy.position.distance_to(target) > 1.1:
			enemy.position = enemy.position.move_toward(target, delta * 1.1)
		enemy_timer -= delta
		if enemy_timer <= 0:
			enemy_timer = 1.6
			if enemy.position.distance_to(target) < 1.6 and dodge_timer <= 0:
				health = maxf(0, health - ENEMY_DAMAGE)
				message.text = "Voce foi atingido. Espaco esquiva; J ataca."
	if recruited:
		_update_companion(delta)
	else:
		ally.set_motion(false,false,false,false)

	if health <= 0:
		health = 100
		arena = false
		player.position = Vector3(0, 0.4, 2)
		message.text = "Resgatado pela vila. Prototipo sem penalidade por derrota."
	hud.text = "PORTO VELHO / %02d:%02d | Dia %d | Colheitas %d | Madeira %d" % [int(atmosphere.hour),int(fmod(atmosphere.hour,1)*60),day,harvests,wood]

func _update_camera(delta: float) -> void:
	if phantom == null:
		return
	var desired := player.position + Vector3(-2.2,0,-2.2)
	var displacement := desired-camera_anchor.position
	# Zona morta: os primeiros passos acontecem dentro do enquadramento.
	var horizontal := Vector2(displacement.x,displacement.z)
	if horizontal.length()>1.25:
		var travel := horizontal.normalized()*(horizontal.length()-1.25)
		camera_anchor.position.x += travel.x*(1-exp(-4*delta))
		camera_anchor.position.z += travel.y*(1-exp(-4*delta))
	camera_anchor.position.y = lerpf(camera_anchor.position.y,desired.y,1-exp(-2*delta))
	zoom_current = lerpf(zoom_current,zoom_target,1-exp(-4*delta))
	camera.size = lerpf(camera.size,34.0 if overview else 21.5*zoom_current,1-exp(-4*delta))
	# Orientacao constante: nenhuma orbita ou reorientacao ao caminhar.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target-0.08,0.65,1.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target+0.08,0.65,1.5)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_H:
			ui_layer.visible = not ui_layer.visible
		KEY_V:
			overview = not overview
		KEY_SPACE:
			if dodge_timer <= 0 and stamina >= DODGE_COST:
				stamina -= DODGE_COST
				dodge_timer = DODGE_DURATION
				dodge_direction = facing
		KEY_J:
			if attack_timer <= 0 and dodge_timer <= 0:
				attack_timer = ATTACK_COOLDOWN
				var toward := enemy.position - player.position
				toward.y = 0
				if toward.length() < ATTACK_RANGE and facing.dot(toward.normalized()) > -0.1:
					_damage_enemy(ATTACK_DAMAGE)
		KEY_E:
			_interact()
		KEY_R:
			_farm_action(true)
		KEY_F:
			var was_felled: bool=cut_tree.felled
			var feedback: String=cut_tree.hit(player.position)
			if not feedback.is_empty():
				if player.position.distance_to(cut_tree.global_position)<=2.0 and not was_felled:
					tools_visual.use_tool("axe",cut_tree.global_position-player.position)
				message.text=feedback
				tree_felled=cut_tree.felled
				tree_logs=cut_tree.logs
				_save()
		KEY_C:
			_toggle_companion()
		KEY_N:
			day += 1
			farm.next_day()
			crop_stage=int(farm.plots[0].stage)
			_save()
			atmosphere.transition_active=false
			atmosphere.set_hour(16.0)
			message.text="Novo dia. Apenas as mudas regadas cresceram."
		KEY_B:
			if arena:
				arena = false
				player.position = home_position
			elif player.position.distance_to(Vector3(0, 0, 7)) < 3:
				home_position = player.position
				arena = true
				player.position = Vector3(-3, 0.4, 4)
				enemy.position = Vector3(3, 0, 4)
				enemy_health = 90
				enemy.visible = true
				message.text = "Arena lateral experimental. B retorna. Combate Chrono ainda nao portado."
		KEY_L:
			message.text = atmosphere.toggle()
		KEY_F5:
			_save()
			message.text = "Progresso salvo em arquivo exclusivo deste prototipo."
		KEY_F8:
			if not arena:
				world_seed += 1
				_build_world()
				player.position = Vector3(0, 0.4, 2)
				enemy_health = 90
				_save()

func _damage_enemy(amount: float) -> void:
	enemy_health = maxf(0, enemy_health - amount)
	enemy.visible = enemy_health > 0
	message.text = "Sentinela: %d de vida" % enemy_health
	if enemy_health <= 0:
		message.text = "Sentinela vencida. B retorna da arena."

func _interact() -> void:
	var collected: int=cut_tree.collect(player.position)
	if collected>0:
		wood+=collected
		tree_logs=cut_tree.logs
		message.text="Madeira recolhida: %d. Total: %d."%[collected,wood]
		_save()
	elif player.position.distance_to(npc.position)<1.8:
		message.text="Jardineira: 'Cada muda precisa de espaco e agua. C pede companhia; E apenas conversa.'"
	else:
		_farm_action(false)

func _farm_action(water: bool) -> void:
	var result: Dictionary=farm.interact(player.position,water)
	message.text=result.message
	harvests+=int(result.harvest)
	if result.acted:
		var target: int=farm.nearest(player.position)
		var direction: Vector3=(farm.plots[target].position-player.position).rotated(Vector3.UP,-CAMERA_YAW)
		sprite.set_direction(Vector2(direction.x,direction.z))
		sprite.play_action("tend")
		if water:
			tools_visual.use_tool("water",farm.plots[target].position-player.position)
	crop_stage=int(farm.plots[0].stage)
	_save()

func _toggle_companion() -> void:
	if not recruited and player.position.distance_to(npc.position)>2.2:
		message.text="Aproxime-se da jardineira e pressione C para pedir companhia."
		return
	recruited=not recruited
	follow_trail.clear()
	if recruited:
		follow_trail.append(player.position)
	message.text="Jardineira: 'Vou seguir seus passos.' C dispensa." if recruited else "Jardineira: 'Vou esperar aqui.'"
	_save()

func _update_companion(delta: float) -> void:
	if follow_trail.is_empty() or follow_trail.back().distance_to(player.position)>0.35:
		follow_trail.append(player.position)
	while follow_trail.size()>300:
		follow_trail.pop_front()
	var moving:=false
	var before: Vector3=ally.position
	if ally.position.distance_to(player.position)>1.8 and not follow_trail.is_empty():
		var target: Vector3=follow_trail.front()
		if ally.position.distance_to(target)<0.16:
			follow_trail.pop_front()
		else:
			ally.position=ally.position.move_toward(target,delta*3.6)
			moving=true
	if moving:
		var direction: Vector3=(ally.position-before).rotated(Vector3.UP,-CAMERA_YAW)
		ally.set_direction(Vector2(direction.x,direction.z))
	ally.set_motion(moving,false,false,false)

func _update_crop() -> void:
	# Compatibilidade com chamadas antigas da bancada de sistemas.
	if farm!=null:
		farm.refresh()

func _save() -> void:
	if suppress_saves:
		return
	farm_save=farm.serialize()
	tree_felled=cut_tree.felled
	tree_logs=cut_tree.logs
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 1, "seed": world_seed, "day": day, "crop": crop_stage, "harvests": harvests, "recruited": recruited,"plots":farm.serialize(),"tree_felled":cut_tree.felled,"tree_logs":cut_tree.logs,"wood":wood}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
	if not data is Dictionary or data.get("version", 0) != 1:
		return
	world_seed = int(data.get("seed", 41826))
	day = maxi(1, int(data.get("day", 1)))
	crop_stage = clampi(int(data.get("crop", 0)), 0, 2)
	harvests = maxi(0, int(data.get("harvests", 0)))
	recruited = bool(data.get("recruited", false))
	farm_save=data.get("plots",[]) if data.get("plots",[]) is Array else []
	tree_felled=bool(data.get("tree_felled",false))
	tree_logs=clampi(int(data.get("tree_logs",0)),0,3)
	wood=maxi(0,int(data.get("wood",0)))

