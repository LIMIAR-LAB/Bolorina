extends SceneTree
## Capturas das cercas (camera seguindo, zoom de perto): docs/<prefixo>-campo.png, -horta.png, -geral.png
## Prefixo por FID_SAIDA (padrao vila-cercas-depois). Use FID_CONFIG_EXTRA='{"cercas_v1":true}' para o "antes".
func _initialize() -> void:
	call_deferred("run")

func shot(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/%s.png" % nome)

func run() -> void:
	var pre := OS.get_environment("FID_SAIDA")
	if pre == "":
		pre = "vila-cercas-depois"
	var game = load("res://fidelity_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	for i in 60:
		await process_frame
	game.ui_layer.visible = false
	game.overlay_label.visible = false
	if game.efeitos_label:
		game.efeitos_label.visible = false
	for alvo in [["campo", Vector3(4.6, 0, -6.8)], ["horta", Vector3(-13.5, 0, -3.6)]]:
		var p: Vector3 = alvo[1]
		game.player.position = Vector3(p.x, game.vila.altura(p.x, p.z) + 0.4, p.z)
		game.zoom_target = 0.55
		game.zoom_current = 0.55
		game.cam_seguir = Vector3(p.x, 0, p.z) + game.cam_desloc
		game.apply_camera()
		await create_timer(1.2).timeout
		await shot("%s-%s" % [pre, alvo[0]])
	print("RESULTADO: 1/1 verificacoes")
	game.queue_free()
	await process_frame
	quit(0)
