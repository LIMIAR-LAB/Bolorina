extends SceneTree
## Captura alinhada da cena de fidelidade (com janela 1600x900):
##   Godot --path . --resolution 1600x900 --script tests/fidelity_capture.gd
## Salva docs/fidelidade-v6-alinhado.png e docs/fidelidade-sobreposicao-50.png.
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var save_path := "user://island_v1.json"
	var existed := FileAccess.file_exists(save_path)
	var game = load("res://fidelity_village.tscn").instantiate()
	game.camera_travada = true  # pontuacao/captura sempre no enquadramento da referencia
	root.add_child(game)
	game.demo_mode = true
	await frames(90)
	game.ui_layer.visible = false
	game.overlay_label.visible = false
	if game.efeitos_label:
		game.efeitos_label.visible = false
	await frames(30)
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	check(cam == game.fidelity_camera, "Camera de fidelidade ativa")
	var before := cam.global_transform
	game.demo_input = Vector2(1,0)
	await frames(40)
	game.demo_input = Vector2.ZERO
	check(cam.global_transform.is_equal_approx(before), "Camera travada mesmo com o personagem andando")
	await frames(20)
	var img: Image = await shot()
	check(img.get_size() == Vector2i(1600,900), "Captura em 1600x900 (%s)" % str(img.get_size()))
	var nome := OS.get_environment("FID_SAIDA")
	if nome == "":
		nome = "fidelidade-v6-alinhado"
	img.save_png("res://docs/%s.png" % nome)
	game.set_overlay(true)
	game.set_opacity(0.5)
	await frames(4)
	(await shot()).save_png("res://docs/%s.png" % ("fidelidade-sobreposicao-50" if nome == "fidelidade-v6-alinhado" else nome+"-sobreposicao-50"))
	var a: float = game.overlay_opacity
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_MINUS
	game._unhandled_key_input(event)
	check(absf(game.overlay_opacity-(a-0.1)) < 0.001, "Tecla - reduz a opacidade")
	event.physical_keycode = KEY_O
	game._unhandled_key_input(event)
	check(not game.overlay.visible, "O oculta a sobreposicao")
	check(game.suppress_saves and FileAccess.file_exists(save_path) == existed, "Sem gravar save")
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)