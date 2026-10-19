extends SceneTree
var game
var elapsed:=0.0
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo_mode=true
	game.suppress_saves=true
	game.recruited=false
	game.player.position=Vector3(-6.9,0.1,2.7)
	game.zoom_target=0.67
	game.ui_layer.visible=false
	game.atmosphere.set_hour(16)
func _process(delta: float) -> bool:
	if game==null:
		return false
	elapsed+=delta
	if elapsed>=2.0 and elapsed<2.0+delta:
		game.atmosphere.toggle()
	if elapsed>=39:
		game.queue_free()
		quit()
		return true
	return false
