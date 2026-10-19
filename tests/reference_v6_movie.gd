extends SceneTree
var game
var phase := 0
var elapsed := 0.0
var caption: Label
var phases := [
	["wait",Vector3.ZERO,1.5,"Vilarejo V6 - personagens originais e luz 3D"],
	["walk",Vector3(-3.9,0,1.5),5.0,"Caminhada ate a horta"],
	["harvest",Vector3.ZERO,1.0,"E - colher"],
	["plant",Vector3.ZERO,1.0,"E - plantar"],
	["water",Vector3.ZERO,1.3,"R - regar"],
	["run",Vector3(0,0,2),4.0,"Corrida com animacao propria e camera fixa"],
	["walk",Vector3(2.2,0,-0.2),4.0,"Praca, moradores e fachadas iluminadas"],
	["walk",Vector3(0,0,2),4.0,"Retorno pelo caminho de pedra"],
	["sunset",Vector3.ZERO,11.0,"Transicao solar acelerada para esta demonstracao"],
	["wait",Vector3.ZERO,1.5,"Lanternas, agua e vegetacao ao anoitecer"]]
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	game = load("res://reference_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	game.ui_layer.visible = false
	var layer := CanvasLayer.new()
	game.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(28,25)
	caption.add_theme_font_size_override("font_size",19)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(caption)
func _physics_process(delta: float) -> bool:
	if game==null:
		return false
	if phase>=phases.size():
		game.queue_free()
		quit()
		return true
	var current: Array = phases[phase]
	caption.text = current[3]
	game.demo_input = Vector2.ZERO
	game.demo_running = current[0]=="run"
	if current[0] in ["walk","run"]:
		var difference: Vector3 = current[1]-game.player.position
		difference.y = 0
		if difference.length()<0.18:
			elapsed = 0
			phase += 1
			return false
		var direction := difference.normalized().rotated(Vector3.UP,-PI/4)
		game.demo_input = Vector2(direction.x,direction.z)
	elif elapsed==0:
		match current[0]:
			"harvest","plant":game._farm_action(false)
			"water":game._farm_action(true)
			"sunset":
				game.atmosphere.toggle()
				game.atmosphere.transition_duration = 10
	elapsed += delta
	if elapsed>=current[2]:
		if current[0] in ["walk","run"]:
			push_error("Percurso V6 bloqueado: "+str(current[1])+" de "+str(game.player.position))
			quit(1)
		elapsed = 0
		phase += 1
	return false
