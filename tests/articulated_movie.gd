extends SceneTree
## Video curto da comparacao. Gravar com:
##   Godot --path . --write-movie <arquivo.avi> --fixed-fps 30 --script tests/articulated_movie.gd
## Fisica e animacoes reais; teleportes e mudancas de hora sao indicados na legenda.
var game
var phase := 0
var elapsed := 0.0
var caption: Label
var spin := 0
# acao, alvo/parametro, duracao maxima, legenda
var phases := [
	["mode",false,1.6,"Comparacao: sprite completo atual (V4) x articulado experimental | mesma fisica, camera e luz"],
	["walk",Vector3(-3.9,0,1.5),5.0,"Sprite completo: caminhada ate a horta"],
	["key",KEY_E,0.9,"E - colher (farm.interact real)"],
	["key",KEY_E,0.9,"E - plantar"],
	["key",KEY_R,1.3,"R - regar"],
	["mode",true,1.0,"T - alterna para o ARTICULADO no mesmo lugar"],
	["reset_plot",5,0.3,"Canteiro devolvido a muda seca para repetir a acao"],
	["key",KEY_R,1.4,"Articulado: R - regar (regador preso a mao)"],
	["run",Vector3(0,0,2),4.0,"Articulado: corrida (Shift)"],
	["walk",Vector3(2.2,0,-0.2),4.0,"Articulado: caminhada"],
	["spin",true,3.4,"Articulado: oito direcoes"],
	["mode",false,0.4,"T - sprite completo"],
	["spin",false,3.4,"Sprite completo: oito direcoes"],
	["tree",0,0.8,"Teleporte de demonstracao ate a arvore de recurso"],
	["key",KEY_F,1.0,"Sprite completo: F - machado (cut_tree.hit real)"],
	["mode",true,0.6,"T - articulado"],
	["key",KEY_F,1.1,"Articulado: F - golpe com o machado na mao"],
	["key",KEY_F,2.2,"Articulado: terceiro golpe derruba a arvore"],
	["spot","sombra",0.4,"Teleporte para a sombra"],
	["walk_dir",Vector2(1,0),1.6,"Articulado na sombra"],
	["mode",false,0.2,"T - sprite completo"],
	["walk_dir",Vector2(-1,0),1.6,"Sprite completo na sombra"],
	["spot","lanterna",0.6,"Noite (hora ajustada) junto a uma lanterna"],
	["walk_dir",Vector2(0,1),1.6,"Sprite completo sob a lanterna"],
	["mode",true,0.2,"T - articulado"],
	["walk_dir",Vector2(0,-1),1.6,"Articulado sob a lanterna"],
	["wait",0,1.5,"Fim: avaliacao em docs/COMPARACAO_ARTICULADO.md"]]

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
	if phase >= phases.size():
		game.queue_free()
		quit()
		return true
	var current: Array = phases[phase]
	caption.text = current[3]
	game.demo_input = Vector2.ZERO
	game.demo_running = current[0] == "run"
	if current[0] in ["walk","run"]:
		var difference: Vector3 = current[1]-game.player.position
		difference.y = 0
		if difference.length() < 0.18:
			elapsed = 0
			phase += 1
			return false
		var direction := difference.normalized().rotated(Vector3.UP,-PI/4)
		game.demo_input = Vector2(direction.x,direction.z)
	elif current[0] == "walk_dir":
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
				if current[1] == KEY_F:
					game.cut_tree.cooldown = 0
				var event := InputEventKey.new()
				event.pressed = true
				event.physical_keycode = current[1]
				game._unhandled_key_input(event)
			"reset_plot":
				game.farm.plots[current[1]].stage = 1
				game.farm.plots[current[1]].watered = false
				game.farm.refresh()
			"tree":
				var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
				var target: Vector3 = game.cut_tree.global_position+Vector3(0.88,0,0)
				var hit = game._floor_at(space,target.x,target.z)
				game.teleport(hit if hit != null else target)
			"spot":
				game.go_to_spot(current[1])
	elapsed += delta
	if elapsed >= current[2]:
		if current[0] in ["walk","run"]:
			push_error("Percurso bloqueado: "+str(current[1])+" de "+str(game.player.position))
		elapsed = 0
		phase += 1
	return false