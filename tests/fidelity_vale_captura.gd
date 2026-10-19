extends SceneTree
## Captura da Vale V6 corrigida na vila (camera seguindo, zoom aproximado): docs/fid-vale-corrigido.png
var falhas := 0
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://fidelity_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	for i in 60:
		await process_frame
	game.ui_layer.visible = false
	game.overlay_label.visible = false
	if game.efeitos_label:
		game.efeitos_label.visible = false
	game.zoom_target = 0.62
	game.demo_input = Vector2(0.6, 0.4).normalized()
	await create_timer(1.2).timeout
	game.demo_input = Vector2.ZERO
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/fid-vale-corrigido.png")
	var ok: bool = not game.camera_travada and game.suppress_saves
	print("PASS captura Vale (camera seguindo, zoom %.2f)" % game.zoom_current if ok else "FAIL captura Vale")
	print("RESULTADO: %d/1 verificacoes" % (1 if ok else 0))
	game.queue_free()
	await process_frame
	quit(0 if ok else 1)
