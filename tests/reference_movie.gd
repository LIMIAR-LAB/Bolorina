extends SceneTree
var game
var elapsed := 0.0
var sunset_started := false
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	game = load("res://reference_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	game.ui_layer.visible = false
func _physics_process(delta: float) -> bool:
	if game == null:
		return false
	elapsed += delta
	game.demo_input = Vector2.ZERO
	# Mesmo caminho nos dois sentidos, com fisica e animacoes do jogo.
	if elapsed>1.5 and elapsed<3.0:
		game.demo_input = Vector2(-1,0)
	elif elapsed>3.5 and elapsed<5.0:
		game.demo_input = Vector2(1,0)
	elif elapsed>5.5 and elapsed<7:
		game.demo_input = Vector2(0,1)
	elif elapsed>7.5 and elapsed<9:
		game.demo_input = Vector2(0,-1)
	if elapsed>9.5 and not sunset_started:
		sunset_started = true
		game.atmosphere.toggle()
		# Apenas a gravacao comprime os 35 segundos de transicao em 10 segundos.
		game.atmosphere.transition_duration = 10
	if elapsed>21:
		game.queue_free()
		quit()
	return false
