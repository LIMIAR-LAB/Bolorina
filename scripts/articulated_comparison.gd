extends "res://scripts/reference_village.gd"
## Laboratorio de comparacao: sprite completo atual (original_apprentice, V4)
## x personagem experimental articulado (scripts/articulated_actor.gd).
## Mesma CharacterBody3D, velocidade, camera, luz de preenchimento e material.
## Herda o vilarejo V6 sem ler nem gravar o save. T alterna o modo.
const ArticulatedActor = preload("res://scripts/articulated_actor.gd")
const TransformationV99 = preload("res://scripts/transformation_v99.gd")
var transformation
var full_sprite: AnimatedSprite3D
var full_tools
var rig
var articulated := false
var mode_layer: CanvasLayer
var mode_panel: ColorRect
var mode_label: Label
var fill_light: OmniLight3D
var spots := {}

func _actor(character: String) -> AnimatedSprite3D:
	if character == "original_apprentice" and full_sprite == null:
		# Protagonista atual do jogo principal, com escala e pixel do manifesto V4.
		var actor := ActorVisual.new()
		actor.setup("original_apprentice")
		full_sprite = actor
		return actor
	return super._actor(character)

func _ready() -> void:
	super._ready()
	full_tools = tools_visual
	# Morador cenografico usa o mesmo sprite V4: oculto para nao confundir a comparacao.
	village_resident.visible = false
	# A luz de preenchimento dos atores passa do sprite para o corpo fisico,
	# assim os dois modos recebem exatamente a mesma luz.
	fill_light = full_sprite.get_node("PreenchimentoDoSprite")
	fill_light.reparent(player)
	rig = ArticulatedActor.new()
	rig.name = "PersonagemArticulado"
	player.add_child(rig)
	rig.setup(full_sprite)
	transformation = TransformationV99.new()
	player.add_child(transformation)
	transformation.setup(self)
	_setup_mode_label()
	set_articulated(false)
	message.text = "T: sprite completo / articulado | G: transformar (Adamantium 99, teste) | 1 sol | 2 sombra | 3 lanterna | F6 luz | L anoitecer | H interface"

func _reference_title() -> void:
	DisplayServer.window_set_title("Ilha das Cinzas | Comparacao sprite completo x articulado")

func _setup_mode_label() -> void:
	mode_layer = CanvasLayer.new()
	mode_layer.layer = 20
	mode_layer.name = "IdentificacaoDoModo"
	add_child(mode_layer)
	mode_panel = ColorRect.new()
	mode_panel.position = Vector2(1040,18)
	mode_panel.size = Vector2(540,62)
	mode_panel.color = Color(0.03,0.035,0.04,0.82)
	mode_layer.add_child(mode_panel)
	mode_label = Label.new()
	mode_label.position = Vector2(14,6)
	mode_label.add_theme_font_size_override("font_size",19)
	mode_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	mode_label.add_theme_constant_override("shadow_offset_x",1)
	mode_label.add_theme_constant_override("shadow_offset_y",1)
	mode_panel.add_child(mode_label)

func _update_mode_label() -> void:
	if mode_label == null:
		return
	if articulated:
		mode_label.text = "MODO ATIVO: ARTICULADO (EXPERIMENTAL)\nSkeleton3D, %d ossos, %d pecas de pixel art | T alterna" % [rig.skeleton.get_bone_count(), rig.parts.size()]
		mode_label.add_theme_color_override("font_color",Color("8fe3e8"))
		mode_panel.color = Color(0.02,0.08,0.10,0.86)
	else:
		mode_label.text = "MODO ATIVO: SPRITE COMPLETO (ATUAL)\noriginal_apprentice V4, quadros desenhados | T alterna"
		mode_label.add_theme_color_override("font_color",Color("f1d48a"))
		mode_panel.color = Color(0.09,0.06,0.02,0.86)
	var transformed: bool = transformation != null and transformation.active
	mode_panel.size = Vector2(540,90 if transformed else 62)
	mode_panel.position.x = maxf(18.0, get_viewport().get_visible_rect().size.x-mode_panel.size.x-18.0)
	if transformed:
		mode_label.text += "\nFORMA TESTE: ADAMANTIUM NV 99 + AURA + ASAS | G"

func set_articulated(on: bool) -> void:
	articulated = on
	full_sprite.visible = not on
	rig.visible = on
	rig.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	full_tools.visible = not on
	tools_visual = rig if on else full_tools
	if on:
		rig.sync_now()
	if transformation != null:
		transformation.update_now()
	_update_mode_label()

func toggle_transformation() -> void:
	transformation.set_active(not transformation.active)
	message.text = "Forma Adamantium nivel 99 ativa (teste)." if transformation.active else "Forma normal."
	_update_mode_label()

func toggle_mode() -> void:
	set_articulated(not articulated)
	message.text = "Personagem articulado experimental ativo." if articulated else "Sprite completo atual ativo."

func snap_camera() -> void:
	camera_anchor.position = player.position + Vector3(-2.2,0,-2.2)
	phantom.global_position = camera_anchor.position + CAMERA_OFFSET
	if phantom.has_method("teleport_position"):
		phantom.teleport_position()
	camera.global_position = phantom.global_position

func teleport(target: Vector3) -> void:
	player.position = target + Vector3(0,0.05,0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	snap_camera()

func go_to_spot(spot: String) -> bool:
	if not spots.has(spot):
		message.text = "Ponto de luz ainda nao calculado."
		return false
	teleport(spots[spot])
	if spot == "lanterna" and atmosphere.hour < 19.0:
		atmosphere.transition_active = false
		atmosphere.set_hour(20.2)
	elif spot != "lanterna" and atmosphere.hour > 18.0:
		atmosphere.transition_active = false
		atmosphere.set_hour(16.0)
	message.text = "Ponto de comparacao: " + spot
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_T:
				toggle_mode()
				return
			KEY_G:
				toggle_transformation()
				return
			KEY_1:
				go_to_spot("sol")
				return
			KEY_2:
				go_to_spot("sombra")
				return
			KEY_3:
				go_to_spot("lanterna")
				return
	super._unhandled_key_input(event)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if spots.is_empty() and Engine.get_physics_frames() > 3:
		_find_spots()

# ------------------------------------------------------------- pontos de luz
func _floor_at(space: PhysicsDirectSpaceState3D, x: float, z: float):
	var query := PhysicsRayQueryParameters3D.create(Vector3(x,8,z),Vector3(x,-4,z))
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	return null if hit.is_empty() else hit.position

func _free_at(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	if not cells.has(Vector2i(roundi(point.x),roundi(point.z))):
		return false
	if absf(point.z-7.5)<1.65 and absf(point.x)>1.05:
		return false
	var shape := SphereShape3D.new()
	shape.radius = 0.32
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point+Vector3(0,0.75,0))
	query.exclude = [player.get_rid()]
	return space.intersect_shape(query,1).is_empty()

func _sun_state(space: PhysicsDirectSpaceState3D, point: Vector3, to_sun: Vector3) -> int:
	# 1 = sol, 0 = sombra de volume alto (casa/muro), -1 = ambiguo (cerca baixa).
	var origin := point+Vector3(0,0.7,0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin+to_sun*45.0)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return 1
	return 0 if hit.position.y > point.y+1.6 else -1

func _sunlit(space: PhysicsDirectSpaceState3D, point: Vector3, to_sun: Vector3) -> int:
	var state := _sun_state(space,point,to_sun)
	for offset in [Vector3(0.5,0,0),Vector3(-0.5,0,0),Vector3(0,0,0.5),Vector3(0,0,-0.5)]:
		if _sun_state(space,point+offset,to_sun) != state:
			return -1
	return state

func _find_spots() -> void:
	var space := get_world_3d().direct_space_state
	var saved_hour: float = atmosphere.hour
	atmosphere.set_hour(16.0)
	var to_sun: Vector3 = atmosphere.sun.global_basis.z
	atmosphere.set_hour(saved_hour)
	var start := Vector2(0,2)
	var best := {"sol":INF,"sombra":INF}
	for xi in range(-20,21):
		for zi in range(-16,21):
			var x := xi*0.5
			var z := zi*0.5
			var hit = _floor_at(space,x,z)
			if hit == null or not _free_at(space,hit):
				continue
			var distance := start.distance_to(Vector2(x,z))
			var state := _sunlit(space,hit,to_sun)
			if state < 0:
				continue
			var key := "sol" if state == 1 else "sombra"
			if distance < best[key]:
				best[key] = distance
				spots[key] = hit
	var lights: Array = get_tree().get_nodes_in_group("night_lights") + get_tree().get_nodes_in_group("facade_lights")
	var best_lantern := INF
	for light in lights:
		var lp: Vector3 = light.global_position
		for k in range(8):
			var angle := k*PI/4.0
			var x := lp.x+cos(angle)*1.1
			var z := lp.z+sin(angle)*1.1
			var hit = _floor_at(space,x,z)
			if hit == null or not _free_at(space,hit) or absf(hit.y-lp.y)>3.2:
				continue
			var score := Vector2(x,z).distance_to(start)+Vector2(hit.x,hit.z).distance_to(Vector2(lp.x,lp.z))*2.0
			if score < best_lantern:
				best_lantern = score
				spots["lanterna"] = hit