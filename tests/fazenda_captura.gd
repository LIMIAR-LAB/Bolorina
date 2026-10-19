extends SceneTree
## Capturas da fazenda: vista geral, campo/detritos, galinheiro, casa, hotbar.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_captura.json")
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	if FileAccess.file_exists("user://ilha_captura.json"):
		DirAccess.remove_absolute("user://ilha_captura.json")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 150:
		await process_frame
		if jogo.atual and jogo.atual.get("ui"):
			break
	var f = jogo.atual
	if f == null:
		push_error("fazenda nao carregou"); quit(1); return
	await create_timer(1.2).timeout
	await _shot(f, "fazenda-geral", Vector3(-7, 0, -12), 20.0)
	await create_timer(0.4).timeout
	await _shot(f, "fazenda-campo", Vector3(4, 0, 0), 16.0)
	await create_timer(0.4).timeout
	await _shot(f, "fazenda-galinheiro", Vector3(15, 0, -17), 14.0)
	await create_timer(0.4).timeout
	await _shot(f, "fazenda-lago", Vector3(-18, 0, 12), 15.0)
	await create_timer(0.4).timeout
	await _shot(f, "fazenda-casa", Vector3(-6, 0, -15), 12.0)
	# planta e rega para foto
	var c := Vector2i(-3, -7)
	if not f.solo.tem(c):
		f.solo.arar(c)
	f.solo.plantar(c, "nabo")
	f.solo.molhar(c)
	f.player.position = Vector3(-4, f.vila.altura(-4, -7) + 0.4, -7)
	f.cam_seguir = Vector3(f.player.position.x, 0, f.player.position.z) + f.cam_desloc
	f.apply_camera()
	await create_timer(0.5).timeout
	await _shot(f, "fazenda-plantio", Vector3(-3, 0, -7), 10.0)
	print("capturas ok")
	quit(0)

func _shot(f, nome: String, alvo: Vector3, tam: float) -> void:
	# caller must await this
	f.camera_travada = true
	f.vila.cam_alvo = Vector3(alvo.x, 0, alvo.z)
	f.vila.cam_size = tam
	f.apply_camera()
	await process_frame
	await process_frame
	var img: Image = f.get_viewport().get_texture().get_image()
	var path := "res://docs/%s.png" % nome
	img.save_png(ProjectSettings.globalize_path(path))
	print("salvou ", path)
