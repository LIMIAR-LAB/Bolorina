extends SceneTree
var game
var step := 0
var elapsed := 0.0
var sequence: Array = []
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	game.recruited = false
	game.ally.visible = false
	game.zoom_target = 0.78
	game.ui_layer.visible = false
	sequence.append([Vector2.ZERO,1.5,false])
	# Cada par sai e retorna usando a mesma fisica dos controles WASD.
	for dir in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
		sequence.append([dir,0.6,false])
		sequence.append([Vector2.ZERO,0.22,false])
		sequence.append([-dir,0.6,false])
		sequence.append([Vector2.ZERO,0.22,false])
	sequence.append([Vector2.ZERO,1.0,false])
	for dir in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized()]:
		sequence.append([dir,0.42,true])
		sequence.append([Vector2.ZERO,0.22,false])
		sequence.append([-dir,0.42,true])
		sequence.append([Vector2.ZERO,0.22,false])
	sequence.append([Vector2.ZERO,1.0,false])
	sequence.append([Vector3(-3.1,0,1.2),5.0,false])
	sequence.append(["tend",1.2,false])
	sequence.append([Vector3(0,0,3.7),5.0,false])
	sequence.append([Vector3(0,0,12),6.0,false])
	sequence.append([Vector2.ZERO,0.8,false])
	sequence.append([Vector3(0,0,3.7),5.0,true])
	sequence.append([Vector2.ZERO,1.0,false])
func _physics_process(delta: float) -> bool:
	if game == null:
		return false
	if step >= sequence.size():
		quit()
		return true
	var entry = sequence[step][0]
	if entry is Vector3:
		var difference: Vector3 = entry-game.player.position
		difference.y = 0
		if difference.length()<0.18:
			game.demo_input = Vector2.ZERO
			elapsed = 0
			step += 1
			return false
		var local := difference.normalized().rotated(Vector3.UP,-PI/4)
		game.demo_input = Vector2(local.x,local.z)
	elif entry is String:
		game.demo_input = Vector2.ZERO
		if elapsed == 0:
			game.sprite.set_direction(Vector2(-1,0))
			game.sprite.play_action("tend")
	else:
		game.demo_input = entry
	game.demo_running = sequence[step][2]
	elapsed += delta
	if elapsed >= sequence[step][1]:
		elapsed = 0
		step += 1
	return false
