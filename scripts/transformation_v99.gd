extends Node3D
## TESTE: forma "Armadura de adamantium nivel 99" com aura e asas.
## Hibrido: corpo em sprite completo PixelLab (8 direcoes, caminhada) no modo
## sprite, ou pecas recoloridas no modo articulado; asas sao duas pecas de pixel
## art presas a ossos de um Skeleton3D proprio (costas -> asa_esquerda/asa_direita)
## que seguem as costas do personagem. Aura: particulas e anel aditivos sem luz
## (nao iluminam o cenario nem os sprites). G alterna. Nada e salvo.
const ART := "res://art/characters/experimental_adamantium_v99/"
const PARTS_ART := "res://art/characters/experimental_articulated/adamantium/"
const PX := 1.28/44.0
const WING_SCALE := 0.58
const BACK_HEIGHT_PX := 25.0      # altura da raiz das asas no sprite completo (alto das costas)
const SHOULDER_DROP_PX := -8.5    # no articulado: raiz na mesma altura de tela do sprite (~25 px)
const WING_DEPTH := 0.13          # atras/frente do plano do corpo (alem das camadas dos bracos, +-0,12)
const SPREAD := 0.70
const FRONT_VIEWS := ["north","north-east","north-west"]
const SIDE_VIEWS := ["east","west"]

var game
var active := false
var armor_frames: SpriteFrames
var armor_manifest: Dictionary
var normal_frames: SpriteFrames
var normal_manifest: Dictionary
var skeleton: Skeleton3D
var attachments := {}
var wings := {}
var wing_info := {}
var aura: CPUParticles3D
var ring: MeshInstance3D
var flap_time := 0.0
var flap_angle := 0.0
var wings_in_front := false
var anchor := Vector3.ZERO
var update_count := 0
var opaque := {}   # pixels opacos de cada asa (para medir o ponto mais baixo real)

func setup(owner_game) -> void:
	game = owner_game
	name = "TransformacaoAdamantium99"
	armor_manifest = JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json"))
	armor_frames = SpriteFrames.new()
	armor_frames.remove_animation("default")
	for anim: String in armor_manifest.anims:
		armor_frames.add_animation(anim)
		armor_frames.set_animation_speed(anim,float(armor_manifest.anims[anim].fps))
		armor_frames.set_animation_loop(anim,true)
		for file: String in armor_manifest.anims[anim].files:
			armor_frames.add_frame(anim,load(ART+file))
	wing_info = armor_manifest.wings
	skeleton = Skeleton3D.new()
	skeleton.name = "EsqueletoAsas"
	skeleton.top_level = true
	skeleton.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(skeleton)
	skeleton.add_bone("costas")
	for side in ["asa_esquerda","asa_direita"]:
		var bone := skeleton.add_bone(side)
		skeleton.set_bone_parent(bone,0)
		skeleton.set_bone_rest(bone,Transform3D(Basis.IDENTITY,Vector3((-1.0 if side=="asa_esquerda" else 1.0)*1.5*PX,0,0)))
	skeleton.reset_bone_poses()
	for side in ["asa_esquerda","asa_direita"]:
		var attachment := BoneAttachment3D.new()
		attachment.name = "Osso_"+side
		skeleton.add_child(attachment)
		attachment.bone_name = side
		attachments[side] = attachment
		var sprite := Sprite3D.new()
		sprite.name = "Pixel_"+side
		sprite.texture = load(ART+str(wing_info[side].file))
		sprite.pixel_size = PX*WING_SCALE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.3
		sprite.double_sided = true
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sprite.top_level = true
		sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		var size: Array = wing_info[side].size
		var root: Array = wing_info[side].root
		# offset em pixels a partir do centro da textura; raiz da asa vira a origem
		sprite.offset = Vector2(float(size[0])/2.0-float(root[0])-0.5, float(root[1])+0.5-float(size[1])/2.0)
		attachment.add_child(sprite)
		wings[side] = sprite
		var image: Image = sprite.texture.get_image()
		var points := PackedVector2Array()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a > 0.3:
					points.append(Vector2(x+0.5-image.get_width()/2.0, image.get_height()/2.0-(y+0.5)))
		opaque[side] = points
	_make_aura()
	_apply_visibility()

func _make_aura() -> void:
	aura = CPUParticles3D.new()
	aura.name = "AuraParticulas"
	aura.amount = 56
	aura.lifetime = 1.3
	aura.local_coords = false
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	aura.emission_ring_axis = Vector3.UP
	aura.emission_ring_radius = 0.42
	aura.emission_ring_inner_radius = 0.28
	aura.emission_ring_height = 0.05
	aura.direction = Vector3.UP
	aura.spread = 12.0
	aura.gravity = Vector3(0,0.9,0)
	aura.initial_velocity_min = 0.25
	aura.initial_velocity_max = 0.6
	aura.scale_amount_min = 0.7
	aura.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0,Color(0.55,1.0,1.0,0.95))
	ramp.set_color(1,Color(0.2,0.55,1.0,0.0))
	aura.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(PX*2.0,PX*2.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = material
	aura.mesh = quad
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0,0.05,0)
	add_child(aura)
	ring = MeshInstance3D.new()
	ring.name = "AuraAnel"
	var plane := QuadMesh.new()
	plane.size = Vector2(1.3,1.3)
	ring.mesh = plane
	ring.rotation.x = -PI/2
	ring.position.y = 0.04
	var ring_material := ShaderMaterial.new()
	ring_material.shader = load("res://shaders/aura_ring.gdshader")
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func set_active(on: bool) -> void:
	if on == active:
		_apply_visibility()
		return
	active = on
	var sprite: AnimatedSprite3D = game.full_sprite
	var kind := str(sprite.animation).get_slice("_",0)
	var phase := (float(sprite.frame)+sprite.frame_progress)/maxi(1,sprite.sprite_frames.get_frame_count(sprite.animation))
	if on:
		normal_frames = sprite.sprite_frames
		normal_manifest = sprite.manifest
		sprite.sprite_frames = armor_frames
		sprite.manifest = armor_manifest
	else:
		sprite.sprite_frames = normal_frames
		sprite.manifest = normal_manifest
	sprite.action_timer = 0.0 if on else sprite.action_timer
	var wanted: String = sprite.animation_for(kind if kind in ["idle","walk","run"] else "idle")
	sprite.play(wanted)
	var next := phase*sprite.sprite_frames.get_frame_count(wanted)
	sprite.set_frame_and_progress(int(next),fmod(next,1.0))
	sprite._ground_frame()
	game.rig.set_art_folder(PARTS_ART if on else game.rig.ART)
	if on:
		aura.restart()
	_apply_visibility()
	update_now()

func _apply_visibility() -> void:
	visible = active
	aura.emitting = active
	skeleton.visible = active
	process_mode = Node.PROCESS_MODE_INHERIT

func _source_motion() -> String:
	return str(game.full_sprite.animation).get_slice("_",0)

func _process(delta: float) -> void:
	if not active:
		return
	var kind := _source_motion()
	var period := 0.62 if kind == "run" else (0.95 if kind == "walk" else 1.5)
	flap_time = fmod(flap_time+delta/period,1.0)
	update_now()

func back_anchor() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var cam := camera.global_basis.orthonormalized()
	if game.articulated:
		var rig = game.rig
		var mid: Vector3 = (rig.bone_position_interpolated("upper_arm_r")+rig.bone_position_interpolated("upper_arm_l"))*0.5
		var origin: Vector3 = rig.get_global_transform_interpolated().origin
		var flat := mid-(-cam.z)*((mid-origin).dot(-cam.z))
		return flat-cam.y*SHOULDER_DROP_PX*PX
	var feet: Vector3 = game.full_sprite.get_global_transform_interpolated().origin
	return feet+cam.y*BACK_HEIGHT_PX*PX

func update_now() -> void:
	if not active or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var cam := camera.global_basis.orthonormalized()
	var facing: String = game.full_sprite.facing_direction
	wings_in_front = facing in FRONT_VIEWS
	var side_view: bool = facing in SIDE_VIEWS
	anchor = back_anchor()
	var amplitude := 0.16 if _source_motion() == "run" else 0.12
	flap_angle = SPREAD+amplitude*sin(TAU*flap_time)
	skeleton.global_transform = Transform3D.IDENTITY
	skeleton.set_bone_pose_position(0,anchor)
	skeleton.set_bone_pose_rotation(1,Quaternion(Vector3(0,0,1),-flap_angle))
	skeleton.set_bone_pose_rotation(2,Quaternion(Vector3(0,0,1),flap_angle))
	# Atualiza esqueleto e BoneAttachment3D agora (sem esperar o proximo quadro).
	skeleton.force_update_all_bone_transforms()
	for side in attachments:
		attachments[side].on_skeleton_update()
	var source: AnimatedSprite3D = game.full_sprite
	var depth := WING_DEPTH if wings_in_front else -WING_DEPTH
	for side in wings:
		var sprite: Sprite3D = wings[side]
		sprite.layers = source.layers
		sprite.shaded = source.shaded
		sprite.modulate = source.modulate
		var root: Vector3 = attachments[side].global_position
		var angle: float = -flap_angle if side == "asa_esquerda" else flap_angle
		var width := 0.55 if side_view else 1.0
		var basis := cam*Basis(Vector3(0,0,1),angle)*Basis.from_scale(Vector3(width,1,1))
		sprite.global_transform = Transform3D(basis, root+cam.z*depth)
	update_count += 1

func wing_root(side: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(side)).origin

func wing_lowest_point(side: String) -> float:
	# ponto mais baixo (y mundial) dos quatro cantos do quad da asa
	# ponto mais baixo (y mundial) entre os pixels opacos da asa
	var sprite: Sprite3D = wings[side]
	var lowest := INF
	for point: Vector2 in opaque[side]:
		var local := Vector3((point.x+sprite.offset.x)*sprite.pixel_size,(point.y+sprite.offset.y)*sprite.pixel_size,0)
		lowest = minf(lowest,(sprite.global_transform*local).y)
	return lowest