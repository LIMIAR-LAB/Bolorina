extends SceneTree
const Layout = preload("res://scripts/world_layout.gd")
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		push_error(description)
		quit(1)
		assert(condition, description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in range(100):
		var cells := Layout.generate(seed_value)
		check(cells == Layout.generate(seed_value), "Seed deterministica")
		var visited := {Vector2i.ZERO: true}
		var queue: Array[Vector2i] = [Vector2i.ZERO]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + offset
				if cells.has(next) and not visited.has(next):
					visited[next] = true
					queue.append(next)
		check(visited.size() == cells.size(), "Ilha totalmente conectada")
		for anchor in [Vector2i(-4, 1), Vector2i(3, 0), Vector2i(0, 7)]:
			check(visited.has(anchor), "Ancora alcancavel")
	check(Layout.generate(1) != Layout.generate(2), "Seeds diferentes mudam costa")
	# Isola o save de teste e restaura seus bytes mesmo quando ja existe progresso.
	var packed := load("res://main.tscn") as PackedScene
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	for i in range(30):
		await physics_frame
	check(game.player.position.y > -0.1, "Chao suporta personagem")
	game.player.position = game.farm.plots[0].position+Vector3(0.7,0,0)
	var save_path: String = game.SAVE_FILE
	var had_save := FileAccess.file_exists(save_path)
	var backup := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()
	game.farm.plots[0].stage=0
	game._interact()
	check(game.crop_stage == 1, "Plantio por proximidade")
	game.farm.plots[0].stage=2
	var before: int = game.harvests
	game._interact()
	check(game.harvests == before + 1 and game.crop_stage == 0, "Colheita")
	game.player.position = game.npc.position
	game.recruited = false
	game._toggle_companion()
	check(game.recruited and game.ally.visible, "Recrutamento")
	game._save()
	game.recruited = false
	game._load()
	check(game.recruited, "Save restaura recrutamento")
	game.enemy_health = 18
	game._damage_enemy(18)
	check(not game.enemy.visible and game.enemy_health == 0, "Derrota de inimigo")
	var input := InputEventKey.new()
	input.pressed = true
	input.physical_keycode = KEY_SPACE
	game.stamina = 100
	game._unhandled_key_input(input)
	check(is_equal_approx(game.stamina, 75) and game.dodge_timer > 0, "Esquiva consome folego")
	game._unhandled_key_input(input)
	check(is_equal_approx(game.stamina, 75), "Esquiva nao repete durante janela")
	game.dodge_timer = 0
	game.player.position = Vector3(0, 0, 7)
	input.physical_keycode = KEY_B
	game._unhandled_key_input(input)
	check(game.arena and game.enemy_health == 90, "Entra em arena com inimigo restaurado")
	game._unhandled_key_input(input)
	check(not game.arena and game.player.position == Vector3(0, 0, 7), "Retorna ao ponto de entrada")
	game.player.position = Vector3(0, 0, 0)
	game._unhandled_key_input(input)
	check(not game.arena, "Arena exige proximidade da ruina")
	game.farm.plots[0].stage=1
	game.farm.plots[0].watered=true
	input.physical_keycode = KEY_N
	game._unhandled_key_input(input)
	check(game.crop_stage == 2, "Amanhecer amadurece plantacao")
	if had_save:
		var restore := FileAccess.open(save_path, FileAccess.WRITE)
		restore.store_buffer(backup)
		restore.close()
	else:
		DirAccess.remove_absolute(save_path)
	print("PASS: ", checks, " verificacoes; 100 seeds; plantio/colheita/recrutamento/save/combate/chao")
	game.queue_free()
	await process_frame
	quit(0)
