extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(60):
		await process_frame
	var started := Time.get_ticks_usec()
	for i in range(120):
		await process_frame
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	print("Amostra curta 120 quadros: ",120.0/elapsed," FPS medios; nao e benchmark sustentado")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/prototipo.png")
	game.overview = true
	for i in range(120):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/panorama.png")
	game.overview = false
	game.atmosphere.transition_active=false
	game.atmosphere.set_hour(20.2)
	for i in range(120):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/crepusculo.png")
	game.queue_free()
	await process_frame
	quit()
