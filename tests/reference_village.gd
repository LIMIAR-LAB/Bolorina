extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("verify")
func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ", description)
	failed = failed or not ok
func verify() -> void:
	var game = load("res://reference_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	game.ui_layer.visible = false
	for i in range(90):
		await process_frame
	check(game.sprite.shaded and game.npc.shaded,"Personagens recebem luz 3D")
	check(game.sprite.role=="original_vale_v6" and game.npc.role=="original_mira_v6","Novos personagens originais ativos")
	for direction in game.sprite.DIRECTIONS:
		check(game.sprite.sprite_frames.has_animation("walk_"+direction) and game.sprite.sprite_frames.get_frame_count("walk_"+direction)==8,"Protagonista caminha em "+direction)
		check(game.npc.sprite_frames.has_animation("walk_"+direction) and game.npc.sprite_frames.get_frame_count("walk_"+direction)==8,"NPC caminha em "+direction)
		check(game.sprite.sprite_frames.has_animation("run_"+direction) and game.sprite.sprite_frames.get_frame_count("run_"+direction)==8,"Corrida em "+direction)
		check(game.sprite.sprite_frames.has_animation("tend_"+direction),"Acao da horta em "+direction)
	check(game.village_cat.sprite_frames.get_frame_count("idle_south")==8,"Gato com oito quadros de repouso")
	check(game.ground.get_node("Detalhe_telhas_0").multimesh.instance_count>=140,"Telhas de ambas as casas instanciadas")
	check(game.ground.get_node("Detalhe_capim_fino").multimesh.instance_count>1000,"Capim fino em grupos")
	check(game.river_material!=null,"Agua com reflexos animados")
	check(game.sprite.material_override==null,"Material nativo preserva as texturas animadas")
	check(game.suppress_saves and game.world_seed==41826,"Cena deterministica sem progresso salvo")
	check(game.border_vegetation.get_child(0).multimesh.instance_count>100,"Flores instanciadas nas bordas")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/vilarejo-referencia-dia.png")
	var before: Vector3 = game.player.position
	var orientation: Quaternion = game.camera.quaternion
	game.demo_input = Vector2(0,-1)
	for i in range(90):
		await physics_frame
	game.demo_input = Vector2.ZERO
	check(game.player.position.distance_to(before)>1.5,"Movimento real por CharacterBody3D")
	check(absf(orientation.dot(game.camera.quaternion))>0.9999,"Orientacao isometrica permanece fixa")
	game.atmosphere.set_hour(20.2)
	for i in range(60):
		await process_frame
	check(game.sprite.modulate.is_equal_approx(Color.WHITE),"Sem duplicar tinta azul sobre iluminacao real")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/vilarejo-referencia-noite.png")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_F6
	game._unhandled_key_input(event)
	check(not game.sprite.shaded,"Comparacao ao vivo sem luz")
	game._unhandled_key_input(event)
	check(game.sprite.shaded,"Retorno a iluminacao 3D")
	check(game.sprite.get_node("PreenchimentoDoSprite").light_cull_mask==game.sprite.layers,"Preenchimento limitado aos atores")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
