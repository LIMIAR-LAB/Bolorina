extends AnimatedSprite3D
## Personagens originais, oito direcoes; pixels preservados sem retoque.
const DIRECTIONS := ["east","south-east","south","south-west","west","north-west","north","north-east"]
var role := "original_guardian"
var facing_direction := "south"
var manifest: Dictionary
var shadow: MeshInstance3D
var action_timer := 0.0

func setup(character: String) -> void:
	role = character
	var folder := "res://art/characters/" + character + "/"
	if not FileAccess.file_exists(folder+"manifest.json"):
		folder = "res://art/characters/original_guardian/"
	manifest = JSON.parse_string(FileAccess.get_file_as_string(folder+"manifest.json"))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in manifest.anims:
		frames.add_animation(anim)
		frames.set_animation_speed(anim,float(manifest.anims[anim].fps))
		frames.set_animation_loop(anim,not anim.begins_with("tend_"))
		for file: String in manifest.anims[anim].files:
			frames.add_frame(anim,load(folder+file))
	sprite_frames = frames
	pixel_size = 1.72/60.0
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.3
	shaded = false
	no_depth_test = false
	frame_changed.connect(_ground_frame)
	play(animation_for("idle"))
	_ground_frame()
	shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(float(manifest.get("world_height",1.72))*0.55,float(manifest.get("world_height",1.72))*0.32)
	shadow.mesh = quad
	shadow.rotation.x = -PI/2
	shadow.position.y = 0.035
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/contact_shadow.gdshader")
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func set_direction(screen_direction: Vector2) -> void:
	if screen_direction.length_squared() < 0.01:
		return
	var index := posmod(roundi(atan2(screen_direction.y,screen_direction.x)*4.0/PI),8)
	facing_direction = DIRECTIONS[index]
	flip_h = false

func animation_for(motion: String) -> String:
	var name := motion+"_"+facing_direction
	if sprite_frames.has_animation(name):
		return name
	if motion != "idle":
		name = "walk_"+facing_direction
		if sprite_frames.has_animation(name):
			return name
	return "idle_"+facing_direction

func set_motion(moving: bool, running: bool, _dodging: bool, _attacking: bool) -> void:
	if action_timer > 0:
		return
	var wanted := animation_for("run" if running else "walk") if moving else animation_for("idle")
	if animation != wanted:
		var phase := (float(frame)+frame_progress)/maxi(1,sprite_frames.get_frame_count(animation))
		var preserve := (str(animation).begins_with("walk_") and wanted.begins_with("walk_")) or (str(animation).begins_with("run_") and wanted.begins_with("run_"))
		play(wanted)
		if preserve:
			var next := phase*sprite_frames.get_frame_count(wanted)
			set_frame_and_progress(int(next),fmod(next,1.0))
		_ground_frame()

func _ground_frame() -> void:
	if manifest.is_empty() or not manifest.anims.has(str(animation)):
		return
	var info: Dictionary = manifest.anims[str(animation)]
	var canvas: Array = info.size
	var bounds: Array = info.bounds
	var feet: Array = info.feet
	var foot := float(feet[mini(frame,feet.size()-1)])
	# Pivo por quadro ancora o pe plantado; deslocamento vem da fisica.
	offset = Vector2(0,foot-float(canvas[1])/2.0)
	pixel_size = float(manifest.get("world_height",1.72))/maxf(float(manifest.get("min_normalization_height",48.0)),float(bounds[3]-bounds[1]))

func play_action(action: String) -> void:
	var wanted := action+"_"+facing_direction
	if not sprite_frames.has_animation(wanted):
		return
	play(wanted)
	action_timer = float(sprite_frames.get_frame_count(wanted))/sprite_frames.get_animation_speed(wanted)
	_ground_frame()

func _process(delta: float) -> void:
	action_timer = maxf(0,action_timer-delta)
