extends SceneTree
## Clipe curto da transformacao de teste (G). Gravar com:
##   Godot --path . --write-movie <arquivo.avi> --fixed-fps 30 --script tests/transformation_movie.gd
var game
var phase := 0
var elapsed := 0.0
var caption: Label
# acao, parametro, duracao, legenda
var phases := [
	["wait",0,1.2,"Forma normal (sprite completo V4)"],
	["key",KEY_G,1.6,"G - transformar: armadura de adamantium nivel 99 + aura + asas (TESTE)"],
	["walk_dir",Vector2(0,1),1.4,"Caminhada: corpo PixelLab, asas articuladas no osso das costas"],
	["walk_dir",Vector2(1,0),1.2,"Leste"],
	["walk_dir",Vector2(0,-1),1.4,"De costas: asas na frente do corpo"],
	["run_dir",Vector2(-1,0),1.2,"Corrida (Shift): asas batem mais rapido"],
	["spin",0,3.2,"Oito direcoes"],
	["mode",true,0.2,"T - modo articulado (pecas recoloridas por codigo)"],
	["walk_dir",Vector2(1,1).normalized(),1.6,"Articulado transformado"],
	["spot","lanterna",0.4,"Noite junto a lanterna"],
	["mode",false,0.2,"Sprite transformado a noite"],
	["walk_dir",Vector2(0,1),1.4,"Aura aditiva sem luz propria"],
	["key",KEY_G,1.6,"G - volta a forma normal"],
	["wait",0,0.8,"Fim do teste"]]

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	game = load("res://articulated_comparison.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	game.ui_layer.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 30
	game.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(28,22)
	caption.add_theme_font_size_override("font_size",20)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(caption)

func _physics_process(delta: float) -> bool:
	if game == null or game.rig == null:
		return false
	if phase == 0 and elapsed == 0.0:
		game.zoom_target = 0.42
		game.zoom_current = 0.42
		game.camera.size = 21.5*0.42
	if phase >= phases.size():
		game.queue_free()
		quit()
		return true
	var current: Array = phases[phase]
	caption.text = current[3]
	game.demo_input = Vector2.ZERO
	game.demo_running = current[0] == "run_dir"
	if current[0] in ["walk_dir","run_dir"]:
		game.demo_input = current[1]
	elif current[0] == "spin":
		var index := int(elapsed/0.4)
		if index < 8:
			game.full_sprite.set_direction(Vector2(cos(index*PI/4.0),sin(index*PI/4.0)))
	elif elapsed == 0:
		match current[0]:
			"mode":
				game.set_articulated(current[1])
			"key":
				var event := InputEventKey.new()
				event.pressed = true
				event.physical_keycode = current[1]
				game._unhandled_key_input(event)
			"spot":
				game.go_to_spot(current[1])
	elapsed += delta
	if elapsed >= current[2]:
		elapsed = 0
		phase += 1
	return false