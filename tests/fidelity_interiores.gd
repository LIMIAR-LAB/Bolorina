extends SceneTree
## Interiores da vila de fidelidade: entrar/sair com E na porta (fade), sala mobiliada + template,
## grade sem sobreposicao, luzes quentes/frias, colisao, camera e save intocado.
##   Godot --path . --resolution 1600x900 --script tests/fidelity_interiores.gd
## Salva docs/fid-interior-casa.png e docs/fid-interior-modelo.png.
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

func espera(s: float) -> void:
	await create_timer(s).timeout

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func tecla_e(game) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_E
	game._unhandled_key_input(ev)

func local(sala: Node3D, p: Vector3) -> Vector3:
	return sala.to_local(p)

func run() -> void:
	var save_path := "user://island_v1.json"
	var existed := FileAccess.file_exists(save_path)
	var md5 := FileAccess.get_md5(save_path) if existed else ""
	var game = load("res://fidelity_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	await frames(90)
	game.ui_layer.visible = false
	game.overlay_label.visible = false
	if game.efeitos_label:
		game.efeitos_label.visible = false
	var it = game.interiores
	check(it != null and it.casas.size() >= 1 and it.salas.size() == it.casas.size(), "Um interior por casa (%d casas)" % (it.casas.size() if it else 0))
	check(it.conflitos.is_empty(), "Moveis na grade de 1 m sem sobreposicao nem fora da sala %s" % str(it.conflitos))
	var ids := {}
	for n in it.moveis(0):
		ids[String(n.get_meta("modulo"))] = true
	var pedidos := ["cama", "mesa", "cadeira", "estante", "lareira", "tapete", "bau", "caixote", "planta", "janela"]
	var faltam: Array = pedidos.filter(func(x): return not ids.has(x))
	check(faltam.is_empty(), "Casa mobiliada tem %s (faltam %s)" % [", ".join(pedidos), str(faltam)])
	var quentes := 0
	var frias := 0
	for l in it.luzes:
		if it.salas[0].is_ancestor_of(l):
			if String(l.get_meta("tipo", "")) == "quente":
				quentes += 1
			elif String(l.get_meta("tipo", "")) == "fria":
				frias += 1
	check(quentes >= 3 and frias >= 1, "Luzes da sala: %d quentes (lareira/lampioes) + %d frias (janelas)" % [quentes, frias])
	if it.salas.size() > 1:
		check(it.plantas[1] == it.MODELO and it.moveis(1).size() >= 6, "Outras casas usam o template MODELO (%d moveis)" % it.moveis(1).size())
	# entrar
	game.player.position = it.saida_fora(0)
	await frames(5)
	check(it.casa_proxima() == 0, "Na porta da casa: E disponivel")
	tecla_e(game)
	check(it.ocupado, "E inicia a transicao")
	await espera(it.FADE*0.9)
	check(it.fade_rect.color.a > 0.6, "Fade escurece (alfa %.2f)" % it.fade_rect.color.a)
	await espera(1.0)
	var sala: Node3D = it.salas[0]
	var lp := local(sala, game.player.position)
	check(it.ativo == 0 and not it.ocupado and it.fade_rect.color.a < 0.02, "Dentro da casa apos o fade (ativo %d, alfa %.2f)" % [it.ativo, it.fade_rect.color.a])
	check(absf(lp.x) < 4.0 and absf(lp.z) < 3.0, "Vale dentro da sala (local %s)" % str(lp))
	var sol_apagado := true
	for l in game.find_children("*", "DirectionalLight3D", true, false):
		sol_apagado = sol_apagado and not l.visible
	check(sol_apagado, "Sol do crepusculo desligado dentro; so luzes da sala")
	var cam: Camera3D = game.fidelity_camera
	var alvo: Vector3 = cam.global_position - game.vila.basis_cam()[2]*90.0
	check(alvo.distance_to(it.centro()) < 0.05 and absf(cam.size - it.TAM_CAMERA*game.zoom_current/0.94) < 0.05, "Camera enquadra a sala (size %.1f)" % cam.size)
	await espera(0.6)
	await shot("res://docs/fid-interior-casa.png")
	# andar e colisao
	var antes: Vector3 = game.player.position
	game.demo_input = Vector2(0, -1)
	await espera(1.6)
	game.demo_input = Vector2(1, 0)
	await espera(2.5)
	game.demo_input = Vector2.ZERO
	await frames(5)
	lp = local(sala, game.player.position)
	check(game.player.position.distance_to(antes) > 0.8 and absf(lp.x) < 4.0 and absf(lp.z) < 3.0 and lp.y > -0.3, "Anda dentro e paredes/moveis seguram (deslocou %.2f m, local %s)" % [game.player.position.distance_to(antes), str(lp)])
	tecla_e(game)
	await frames(3)
	check(it.ativo == 0 and not it.ocupado, "E longe do capacho nao sai")
	# sair
	game.player.position = it.capacho(0) + Vector3(0, 0.4, 0)
	await frames(3)
	tecla_e(game)
	await espera(it.FADE*2 + 0.6)
	check(it.ativo == -1 and game.player.position.distance_to(it.saida_fora(0)) < 0.6, "E no capacho volta para a porta da casa (dist %.2f)" % game.player.position.distance_to(it.saida_fora(0)))
	var sol_ok := false
	for l in game.find_children("*", "DirectionalLight3D", true, false):
		sol_ok = sol_ok or l.visible
	alvo = cam.global_position - game.vila.basis_cam()[2]*90.0
	check(sol_ok and not it.salas[0].visible and Vector2(alvo.x - game.player.position.x, alvo.z - game.player.position.z).distance_to(Vector2(game.cam_desloc.x, game.cam_desloc.z)) < 1.5, "Fora: sol de volta, sala oculta, camera segue a Vale")
	# template
	if it.salas.size() > 1:
		game.player.position = it.saida_fora(1)
		await frames(5)
		tecla_e(game)
		await espera(it.FADE*2 + 0.8)
		check(it.ativo == 1, "Casa do template tambem abre")
		await shot("res://docs/fid-interior-modelo.png")
		game.player.position = it.capacho(1) + Vector3(0, 0.4, 0)
		await frames(3)
		tecla_e(game)
		await espera(it.FADE*2 + 0.4)
		check(it.ativo == -1, "Sai do template")
	check(game.suppress_saves and FileAccess.file_exists(save_path) == existed and (not existed or FileAccess.get_md5(save_path) == md5), "Save do jogador intocado (%s)" % ("md5 igual" if existed else "inexistente"))
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
