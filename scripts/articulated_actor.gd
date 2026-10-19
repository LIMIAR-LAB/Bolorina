extends Node3D
## EXPERIMENTO: personagem original montado com pecas de pixel art presas aos
## ossos de um Skeleton3D (um BoneAttachment3D por osso). As pecas sao quads
## voltados para a camera, orientados pelo script: membros giram no plano da
## tela seguindo o osso; cabeca, tronco, maos e botas usam vistas desenhadas.
## Profundidade: todas as pecas ficam no plano do personagem (como o sprite
## completo) com camadas calculadas pelo lado do corpo voltado para a camera.
## Pode seguir o estado logico de um ActorVisual (source) ou funcionar sozinho.

const DIRECTIONS := ["east","south-east","south","south-west","west","north-west","north","north-east"]
const ART := "res://art/characters/experimental_articulated/"
const WORLD_HEIGHT := 1.28
# O ActorVisual normaliza a altura desenhada (44 px) para 1,28 m; mesma escala aqui.
const DRAWN_HEIGHT := 44.0
const PX := WORLD_HEIGHT/DRAWN_HEIGHT
const CAMERA_YAW := PI/4.0
const SNAP_TO_TEXELS := true
const SHORT_RATIO := 0.72
const VIEW_TEXTURE := {"east":["east",false],"south-east":["south-east",false],"south":["south",false],"south-west":["south-east",true],"west":["east",true],"north-west":["north-east",true],"north":["north",false],"north-east":["north-east",false]}
const BOOT_VIEW := {"south":"front","north":"back","east":"side","south-east":"side","north-east":"side","west":"side","south-west":"side","north-west":"side"}
const HIP := 7.5
const THIGH := 3.75
const SHIN := 3.75
# osso, pai, posicao de repouso em texels (quadro de 48 px do original_apprentice)
const BONES := [
	["root","",Vector3.ZERO],
	["hips","root",Vector3(0,7.5,0)],
	["torso","hips",Vector3.ZERO],
	["head","torso",Vector3(0,12.5,0)],
	["upper_arm_r","torso",Vector3(7.5,11.0,0)],
	["lower_arm_r","upper_arm_r",Vector3(0,-4.5,0)],
	["hand_r","lower_arm_r",Vector3(0,-3.5,0)],
	["tool_r","hand_r",Vector3(0,-2.0,0)],
	["upper_arm_l","torso",Vector3(-7.5,11.0,0)],
	["lower_arm_l","upper_arm_l",Vector3(0,-4.5,0)],
	["hand_l","lower_arm_l",Vector3(0,-3.5,0)],
	["thigh_r","hips",Vector3(4.5,0,0)],
	["shin_r","thigh_r",Vector3(0,-3.75,0)],
	["foot_r","shin_r",Vector3(0,-3.75,0)],
	["thigh_l","hips",Vector3(-4.5,0,0)],
	["shin_l","thigh_l",Vector3(0,-3.75,0)],
	["foot_l","shin_l",Vector3(0,-3.75,0)],
]
const ANIMATED := ["torso","head","upper_arm_r","lower_arm_r","hand_r","upper_arm_l","lower_arm_l","hand_l","thigh_r","shin_r","thigh_l","shin_l"]
const ANIMATIONS := {"idle":[1.6,16,true],"walk":[0.5,16,true],"run":[0.4,16,true],"tend":[0.8,16,false],"water":[1.0,20,false],"chop":[0.62,20,false]}

var role := "experimental_articulated"
var art_folder := ART
var source = null
var body: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var attachments := {}
var bone_index := {}
var parts: Array = []
var textures := {}
var shadow: MeshInstance3D
var facing_direction := "south"
var action_timer := 0.0
var current_action := ""
var last_source_animation := ""
var applied_modulate := Color.WHITE
var applied_shaded := false
var update_count := 0
var update_usec := 0
var layers := 1:
	set(value):
		layers = value
		for part in parts:
			part.sprite.layers = value

func setup(source_actor = null) -> void:
	source = source_actor
	_load_textures()
	body = Node3D.new()
	body.name = "Corpo"
	add_child(body)
	skeleton = Skeleton3D.new()
	skeleton.name = "Esqueleto"
	body.add_child(skeleton)
	for entry in BONES:
		skeleton.add_bone(entry[0])
	for i in BONES.size():
		var entry: Array = BONES[i]
		if entry[1] != "":
			skeleton.set_bone_parent(i, skeleton.find_bone(entry[1]))
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, entry[2]*PX))
	skeleton.reset_bone_poses()
	for entry in BONES:
		var attachment := BoneAttachment3D.new()
		attachment.name = "Osso_" + entry[0]
		skeleton.add_child(attachment)
		attachment.bone_name = entry[0]
		attachments[entry[0]] = attachment
		bone_index[entry[0]] = skeleton.find_bone(entry[0])
	for spec in _part_specs():
		_make_part(spec)
	animator = AnimationPlayer.new()
	animator.name = "Animacoes"
	add_child(animator)
	var library := AnimationLibrary.new()
	for name in ANIMATIONS:
		var info: Array = ANIMATIONS[name]
		library.add_animation(name, _make_animation(name, info[0], info[1], info[2]))
	animator.add_animation_library("", library)
	_make_shadow()
	if source != null:
		layers = source.layers
	_apply_modulate(Color.WHITE)
	_apply_shaded(false)
	skeleton.skeleton_updated.connect(_update_parts)
	_set_facing(facing_direction)
	animator.play("idle")

func set_art_folder(folder: String) -> void:
	# Troca o conjunto de texturas das pecas (ex.: variante de teste Adamantium 99).
	if folder == art_folder:
		return
	art_folder = folder
	_load_textures()
	for part in parts:
		part.key = ""
	_update_parts()

func _load_textures() -> void:
	var names := ["upper_arm","upper_arm_short","lower_arm","lower_arm_short","hand","hand_grip","cap","thigh","thigh_short","shin","boot_front","boot_side","boot_back","axe","can"]
	for view in ["south","south-east","east","north-east","north"]:
		names.append("head_"+view)
		names.append("torso_"+view)
	for name in names:
		var path: String = art_folder + name + ".png"
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path)
		else:
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			texture = ImageTexture.create_from_image(image)
		textures[name] = texture

func _part_specs() -> Array:
	var specs := [
		{"name":"torso","bone":"torso","tex":"torso","mode":"view","anchor":Vector2(9,13),"layer":0.0,"group":[]},
		{"name":"head","bone":"head","tex":"head","mode":"view","anchor":Vector2(15,24),"layer":0.09,"group":[]},
	]
	for side in ["r","l"]:
		var arm := ["upper_arm_"+side,"hand_"+side]
		var leg := ["thigh_"+side,"foot_"+side]
		specs.append({"name":"upper_arm_"+side,"bone":"upper_arm_"+side,"to":"lower_arm_"+side,"tex":"upper_arm","mode":"limb","anchor":Vector2(3.5,1),"layer":0.020,"group":arm})
		specs.append({"name":"lower_arm_"+side,"bone":"lower_arm_"+side,"to":"hand_"+side,"tex":"lower_arm","mode":"limb","anchor":Vector2(3.5,0.5),"layer":0.022,"group":arm})
		specs.append({"name":"cap_"+side,"bone":"upper_arm_"+side,"tex":"cap","mode":"cap","anchor":Vector2(3.5,2.5),"layer":0.028,"group":arm})
		specs.append({"name":"hand_"+side,"bone":"hand_"+side,"tex":"hand","mode":"hand","anchor":Vector2(3,3),"layer":0.026,"group":arm,"grip":side=="r"})
		specs.append({"name":"thigh_"+side,"bone":"thigh_"+side,"to":"shin_"+side,"tex":"thigh","mode":"limb","anchor":Vector2(3.5,0.5),"layer":-0.014,"group":leg})
		specs.append({"name":"shin_"+side,"bone":"shin_"+side,"to":"foot_"+side,"tex":"shin","mode":"limb","anchor":Vector2(3.5,0.5),"layer":-0.012,"group":leg})
		specs.append({"name":"boot_"+side,"bone":"foot_"+side,"tex":"boot","mode":"boot","anchor":Vector2(4,6),"layer":-0.010,"group":leg})
	specs.append({"name":"axe","bone":"hand_r","tex":"axe","mode":"axe","anchor":Vector2(5.5,2),"layer":0.024,"group":["upper_arm_r","hand_r"]})
	specs.append({"name":"can","bone":"hand_r","tex":"can","mode":"can","anchor":Vector2(6,1.5),"layer":0.024,"group":["upper_arm_r","hand_r"]})
	return specs

func _make_part(spec: Dictionary) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Pixel_" + spec.name
	sprite.pixel_size = PX
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sprite.top_level = true
	attachments[spec.bone].add_child(sprite)
	var part: Dictionary = spec.duplicate()
	part.sprite = sprite
	part.key = ""
	part.flip = false
	parts.append(part)

func _make_shadow() -> void:
	shadow = MeshInstance3D.new()
	shadow.name = "SombraDeContato"
	var quad := QuadMesh.new()
	quad.size = Vector2(WORLD_HEIGHT*0.55, WORLD_HEIGHT*0.32)
	shadow.mesh = quad
	shadow.rotation.x = -PI/2
	shadow.position.y = 0.035
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/contact_shadow.gdshader")
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

# ------------------------------------------------------------- animacao
func _pose(kind: String, t: float) -> Dictionary:
	var r := {}
	for bone in ANIMATED:
		r[bone] = Vector3.ZERO
	var w := TAU*t
	var s := sin(w)
	var c := cos(w)
	match kind:
		"idle":
			r.torso = Vector3(-0.02+0.02*s,0,0)
			r.upper_arm_r = Vector3(0.05*s,0,0.06)
			r.upper_arm_l = Vector3(-0.05*s,0,-0.06)
			r.lower_arm_r = Vector3(0.12,0,0)
			r.lower_arm_l = Vector3(0.12,0,0)
		"walk","run":
			var run := kind == "run"
			var amp := 0.9 if run else 0.7
			var knee := 1.35 if run else 0.9
			var arm := 0.85 if run else 0.5
			var elbow := 1.1 if run else 0.25
			r.thigh_r = Vector3(amp*s,0,0)
			r.thigh_l = Vector3(-amp*s,0,0)
			r.shin_r = Vector3(-knee*maxf(0.0,c),0,0)
			r.shin_l = Vector3(-knee*maxf(0.0,-c),0,0)
			r.upper_arm_r = Vector3(-arm*s,0,0.07)
			r.upper_arm_l = Vector3(arm*s,0,-0.07)
			r.lower_arm_r = Vector3(elbow+0.15*maxf(0.0,-s),0,0)
			r.lower_arm_l = Vector3(elbow+0.15*maxf(0.0,s),0,0)
			r.torso = Vector3(-0.16 if run else -0.05,0.08*s,0)
		"tend":
			var e := sin(PI*t)
			r.thigh_r = Vector3(0.95*e,0,0)
			r.thigh_l = Vector3(0.95*e,0,0)
			r.shin_r = Vector3(-1.5*e,0,0)
			r.shin_l = Vector3(-1.5*e,0,0)
			r.torso = Vector3(-0.42*e,0,0)
			r.upper_arm_r = Vector3(1.0*e,0,0.05)
			r.upper_arm_l = Vector3(0.9*e,0,-0.05)
			r.lower_arm_r = Vector3(0.35*e,0,0)
			r.lower_arm_l = Vector3(0.35*e,0,0)
		"water":
			var raise := smoothstep(0.0,0.25,t)*(1.0-smoothstep(0.8,1.0,t))
			var pour := smoothstep(0.3,0.45,t)*(1.0-smoothstep(0.65,0.8,t))
			r.upper_arm_r = Vector3(1.05*raise,0,0.12*raise)
			r.lower_arm_r = Vector3(0.25*raise,0,0)
			r.hand_r = Vector3(-1.25*raise+0.65*pour,0,0)
			r.upper_arm_l = Vector3(0.25*raise,0,-0.1)
			r.lower_arm_l = Vector3(0.3*raise,0,0)
			r.torso = Vector3(-0.12*raise-0.06*pour,0,0)
			r.thigh_r = Vector3(0.18*raise,0,0)
			r.thigh_l = Vector3(-0.12*raise,0,0)
		"chop":
			var lift := smoothstep(0.0,0.38,t)
			var strike := smoothstep(0.38,0.52,t)
			var back := smoothstep(0.62,1.0,t)
			var a := lerpf(lerpf(0.0,2.75,lift),0.55,strike)
			a = lerpf(a,0.0,back)
			var hold := 1.0-back
			r.upper_arm_r = Vector3(a,0,-0.3*hold)
			r.upper_arm_l = Vector3(a*0.92,0,0.3*hold)
			r.lower_arm_r = Vector3(0.25*(1.0-0.6*strike),0,0)
			r.lower_arm_l = Vector3(0.25*(1.0-0.6*strike),0,0)
			r.torso = Vector3(lerpf(lerpf(0.0,0.12,lift),-0.3,strike)*hold,0,0)
			r.thigh_r = Vector3(0.3*hold,0,0)
			r.thigh_l = Vector3(-0.22*hold,0,0)
			r.shin_l = Vector3(-0.15*hold,0,0)
	return r

func _hip_height(pose: Dictionary) -> float:
	# Mantem o pe mais baixo exatamente no chao (pelve desce quando as pernas abrem).
	var lowest := INF
	for side in ["r","l"]:
		var a: float = pose["thigh_"+side].x
		var b: float = pose["shin_"+side].x
		lowest = minf(lowest, HIP-THIGH*cos(a)-SHIN*cos(a+b))
	return HIP-lowest

func _make_animation(kind: String, length: float, samples: int, loop: bool) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for bone in ANIMATED:
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Corpo/Esqueleto:"+bone))
		tracks[bone] = track
	var hips := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hips, NodePath("Corpo/Esqueleto:hips"))
	var count := samples if loop else samples+1
	for i in count:
		var t := float(i)/samples
		var pose := _pose(kind,t)
		for bone in ANIMATED:
			animation.rotation_track_insert_key(tracks[bone], t*length, Quaternion.from_euler(pose[bone]))
		animation.position_track_insert_key(hips, t*length, Vector3(0,_hip_height(pose)*PX,0))
	return animation

# ------------------------------------------------------------- interface do ator
func set_direction(screen_direction: Vector2) -> void:
	if screen_direction.length_squared() < 0.01:
		return
	var index := posmod(roundi(atan2(screen_direction.y,screen_direction.x)*4.0/PI),8)
	_set_facing(DIRECTIONS[index])

func set_motion(moving: bool, running: bool, _dodging: bool = false, _attacking: bool = false) -> void:
	if current_action != "":
		return
	_play_motion(("run" if running else "walk") if moving else "idle")

func play_action(action: String) -> void:
	if action == "tend":
		_start_action("tend")

func use_tool(kind: String, direction: Vector3) -> void:
	var local := direction.rotated(Vector3.UP,-CAMERA_YAW)
	var screen := Vector2(local.x,local.z)
	if source != null:
		source.set_direction(screen)
		_set_facing(source.facing_direction)
	else:
		set_direction(screen)
	_start_action("chop" if kind == "axe" else "water")
	if source != null:
		# Mesma regra do cultivo: o personagem para enquanto a ferramenta age.
		source.action_timer = maxf(source.action_timer, action_timer)

func sync_now() -> void:
	if source == null:
		return
	_set_facing(source.facing_direction)
	last_source_animation = ""
	_follow_source()
	_update_parts()

func world_direction(name: String) -> Vector3:
	var index := DIRECTIONS.find(name)
	return Vector3(cos(index*PI/4.0),0,sin(index*PI/4.0)).rotated(Vector3.UP,CAMERA_YAW)

func bone_position(bone: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bone_index[bone]).origin

func bone_position_interpolated(bone: String) -> Vector3:
	# Pose atual do osso (a mesma que o BoneAttachment3D recebe), com interpolacao fisica.
	return skeleton.get_global_transform_interpolated()*skeleton.get_bone_global_pose(bone_index[bone]).origin

func get_part(part_name: String) -> Dictionary:
	for entry in parts:
		if entry.name == part_name:
			return entry
	return {}

func _set_facing(name: String) -> void:
	facing_direction = name
	var direction := world_direction(name)
	body.rotation.y = atan2(-direction.x,-direction.z)

func _play_motion(kind: String) -> void:
	if animator.current_animation != kind:
		animator.play(kind, 0.12)

func _start_action(name: String) -> void:
	current_action = name
	animator.play(name, 0.06)
	animator.seek(0.0, true)
	action_timer = animator.current_animation_length

func _apply_modulate(color: Color) -> void:
	applied_modulate = color
	for part in parts:
		part.sprite.modulate = color

func _apply_shaded(value: bool) -> void:
	applied_shaded = value
	for part in parts:
		part.sprite.shaded = value

func _follow_source() -> void:
	if source.modulate != applied_modulate:
		_apply_modulate(source.modulate)
	if source.shaded != applied_shaded:
		_apply_shaded(source.shaded)
	if source.facing_direction != facing_direction and current_action == "":
		_set_facing(source.facing_direction)
	var animation_name := str(source.animation)
	var kind := animation_name.get_slice("_",0)
	if animation_name != last_source_animation:
		last_source_animation = animation_name
		if kind == "tend" and current_action == "":
			_start_action("tend")
	if current_action == "" and kind != "tend":
		_play_motion(kind)

func _process(delta: float) -> void:
	action_timer = maxf(0.0, action_timer-delta)
	if current_action != "" and action_timer <= 0.0:
		current_action = ""
		if source == null:
			_play_motion("idle")
	if source != null:
		_follow_source()
	# As pecas sao atualizadas uma vez por quadro em skeleton_updated (pose atual).

# ------------------------------------------------------------- pecas
func _set_texture(part: Dictionary, key: String, flip: bool) -> void:
	if part.key == key and part.flip == flip:
		return
	var texture: Texture2D = textures[key]
	var sprite: Sprite3D = part.sprite
	sprite.texture = texture
	sprite.flip_h = flip
	var w := float(texture.get_width())
	var h := float(texture.get_height())
	var anchor: Vector2 = part.anchor
	sprite.offset = Vector2((anchor.x-w/2.0) if flip else (w/2.0-anchor.x), anchor.y-h/2.0)
	part.key = key
	part.flip = flip

func _screen_angle(v: Vector3, right: Vector3, up: Vector3) -> float:
	var sx := v.dot(right)
	var sy := v.dot(up)
	if sx*sx+sy*sy < 1e-10:
		return 0.0
	return atan2(sx,-sy)

func _update_parts() -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var started := Time.get_ticks_usec()
	var cam := camera.global_basis.orthonormalized()
	var right := cam.x
	var up := cam.y
	var back := cam.z
	var forward := -back
	var forward_h := Vector3(forward.x,0,forward.z).normalized()
	# O sprite completo e um quad voltado para a camera; ossos verticais seriam
	# encurtados pela inclinacao da camera (cos 35 graus). Compensa no eixo Y do corpo.
	var stretch := 1.0/maxf(0.3,up.y)
	if not is_equal_approx(body.scale.y,stretch):
		body.scale = Vector3(1,stretch,1)
	var origin := get_global_transform_interpolated().origin
	var view: Array = VIEW_TEXTURE[facing_direction]
	var west: bool = view[1]
	var gripping := current_action == "water" or current_action == "chop"
	var pos := {}
	var skeleton_xform := skeleton.get_global_transform_interpolated()
	for bone in attachments:
		pos[bone] = skeleton_xform*skeleton.get_bone_global_pose(bone_index[bone]).origin
	for part in parts:
		var sprite: Sprite3D = part.sprite
		if part.mode == "axe":
			sprite.visible = current_action == "chop"
		elif part.mode == "can":
			sprite.visible = current_action == "water"
		if not sprite.visible:
			continue
		var p: Vector3 = pos[part.bone]
		var angle := 0.0
		match part.mode:
			"view":
				_set_texture(part, part.tex+"_"+view[0], west)
			"boot":
				_set_texture(part, "boot_"+BOOT_VIEW[facing_direction], west)
			"hand":
				_set_texture(part, "hand_grip" if part.get("grip",false) and gripping else "hand", west)
			"cap":
				_set_texture(part, "cap", false)
			"limb":
				var v: Vector3 = pos[part.to]-p
				angle = _screen_angle(v,right,up)
				var projected := Vector2(v.dot(right),v.dot(up)).length()
				var short_key: String = part.tex+"_short"
				var use_short := projected < SHORT_RATIO*v.length() and textures.has(short_key)
				_set_texture(part, short_key if use_short else part.tex, false)
			"axe":
				angle = _screen_angle(pos["tool_r"]-pos["hand_r"],right,up)
				_set_texture(part, "axe", not west)
			"can":
				angle = -_screen_angle(pos["tool_r"]-pos["hand_r"],right,up)
				_set_texture(part, "can", west)
		var group: Array = part.group
		var side_depth := 0.0
		for bone in group:
			side_depth += (pos[bone]-origin).dot(forward_h)
		if group.size() > 0:
			side_depth /= group.size()
		var toward: float = part.layer-side_depth*0.5
		var flat := p-forward*((p-origin).dot(forward))
		var final := flat-forward*toward
		if SNAP_TO_TEXELS:
			var rel := final-origin
			final = origin+right*snappedf(rel.dot(right),PX)+up*snappedf(rel.dot(up),PX)+back*rel.dot(back)
		sprite.global_transform = Transform3D(cam*Basis(Vector3(0,0,1),angle), final)
	update_count += 1
	update_usec += Time.get_ticks_usec()-started