extends SceneTree
## Mecanicas preservadas na vila V7 (cena de fidelidade): plantar/regar, cortar arvore, catalogo modular, teclas de efeitos,
## Vale V6 com altura constante (8 direcoes x idle/walk/run/acao, medida nos PNGs) e camera seguir/travada (Tab).
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

var _alt_cache := {}
## Altura real (px) do conteudo opaco e base (pe) de um quadro, lida do PNG (funciona em --headless).
func conteudo(tex: Texture2D) -> Vector2i:
	var path := tex.resource_path
	if _alt_cache.has(path):
		return _alt_cache[path]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var topo := -1
	var base := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 16.0/255.0:
				if topo < 0:
					topo = y
				base = y + 1
				break
	_alt_cache[path] = Vector2i(base - topo, base)
	return _alt_cache[path]

func vale_checks(game) -> void:
	var s = game.sprite
	var cam: Camera3D = game.fidelity_camera
	var tela_h: float = game.get_viewport().get_visible_rect().size.y
	check(s.role == "vale_unica" and s.get_script().resource_path.ends_with("vale_fidelidade.gd"), "Protagonista e a Vale unica (%s, %s)" % [s.role, s.get_script().resource_path.get_file()])
	var mesmo_corpo := true
	for d in s.DIRECTIONS:
		for i in s.sprite_frames.get_frame_count("walk_"+d):
			if s.sprite_frames.get_frame_texture("walk_"+d, i) != s.sprite_frames.get_frame_texture("run_"+d, i % s.sprite_frames.get_frame_count("run_"+d)):
				mesmo_corpo = false
	check(mesmo_corpo, "Andar usa o corpo V6 de run (nao o walk/ magro antigo) nas 8 direcoes")
	# altura em pe por animacao = maior altura opaca dos quadros x pixel_size daquela animacao
	var alturas := {}
	var pes_ok := true
	var pior_pe := 0
	for fam in ["idle", "walk", "run", "tend"]:
		for d in s.DIRECTIONS:
			var anim: String = fam + "_" + d
			var hmax := 0
			var info: Dictionary = s.manifest.anims[anim]
			for i in s.sprite_frames.get_frame_count(anim):
				var c := conteudo(s.sprite_frames.get_frame_texture(anim, i))
				hmax = maxi(hmax, c.x)
				var pe := float(info.feet[mini(i, info.feet.size()-1)])
				pior_pe = maxi(pior_pe, absi(c.y - int(pe)))
				if absi(c.y - int(pe)) > 1:
					pes_ok = false
			s.play(anim)
			s._ground_frame()
			alturas[anim] = hmax * s.pixel_size
	var em_pe := []
	for k in alturas:
		if not String(k).begins_with("tend_"):
			em_pe.append(alturas[k])
	var acoes := []
	for k in alturas:
		if String(k).begins_with("tend_"):
			acoes.append(alturas[k])
	var ref: float = s.manifest.world_height
	var px := func(h: float) -> float: return h / cam.size * tela_h
	print("INFO Vale altura em pe (m): idle/walk/run min %.3f max %.3f | acao tend min %.3f max %.3f | tela %.1f-%.1f px (camera %.1f, janela %d px)" % [em_pe.min(), em_pe.max(), acoes.min(), acoes.max(), px.call(em_pe.min()), px.call(em_pe.max()), cam.size, int(tela_h)])
	for fam in ["idle", "walk", "run", "tend"]:
		var linha: String = "INFO " + fam + ":"
		for d in s.DIRECTIONS:
			linha += " %s=%.2fm/%.0fpx" % [d, alturas[fam+"_"+d], px.call(alturas[fam+"_"+d])]
		print(linha)
	check(em_pe.min() >= ref*0.95 and em_pe.max() <= ref*1.05, "Altura constante idle/walk/run x 8 direcoes: %.3f-%.3f m (alvo %.2f +-5%%)" % [em_pe.min(), em_pe.max(), ref])
	check(acoes.min() >= ref*0.88 and acoes.max() <= ref*1.05, "Acao (regar/machado = tend) sem salto de escala: %.3f-%.3f m (pose abaixada ate -12%%)" % [acoes.min(), acoes.max()])
	check(pes_ok, "Pe plantado no pivo em todos os quadros (desvio max %d px)" % pior_pe)
	# em jogo: andar, correr e agir sem mudar a escala do corpo
	var pxs := {}
	game.demo_input = Vector2(1, 0.3)
	for running in [false, true]:
		game.demo_running = running
		for i in 20:
			await process_frame
			pxs[String(s.animation).get_slice("_",0)] = s.pixel_size * s.altura_ref(String(s.animation))
	game.demo_input = Vector2.ZERO
	game.demo_running = false
	for i in 10:
		await process_frame
	pxs["idle"] = s.pixel_size * s.altura_ref(String(s.animation))
	s.play_action("tend")
	pxs["tend"] = s.pixel_size * s.altura_ref(String(s.animation))
	var vals := pxs.values()
	check(pxs.size() >= 3 and vals.max() - vals.min() < 0.001, "Em jogo idle/walk/run/acao com a mesma escala do corpo %s" % str(pxs))
	# escala x casas/portas: porta do kit = 2,1 m de vao (visual_world._house)
	var casas: Array = game.find_children("CasaModular*", "", true, false)
	var esc: float = casas[0].global_basis.get_scale().y if casas.size() > 0 else 1.0
	var porta := 2.1 * esc
	print("INFO casas %d escala %.2f porta %.2f m (%.0f px) Vale %.2f m (%.0f px)" % [casas.size(), esc, porta, px.call(porta), ref, px.call(ref)])
	check(casas.size() > 0 and ref/porta > 0.6 and ref/porta < 0.85, "Vale/porta = %.2f (proporcao plausivel para chibi, 0,6-0,85)" % (ref/porta))

func camera_checks(game) -> void:
	var cam: Camera3D = game.fidelity_camera
	check(not game.camera_travada, "Camera padrao: seguindo a Vale")
	game.player.position = game._actor_pos("jogador") + Vector3(0,0.4,0)
	await create_timer(1.5).timeout
	var tela0 := cam.unproject_position(game.player.global_position)
	var origem0 := cam.global_position
	game.player.position += Vector3(6, 0, 3)
	await create_timer(2.0).timeout
	var tela1 := cam.unproject_position(game.player.global_position)
	check(cam.global_position.distance_to(origem0) > 4.0 and tela1.distance_to(tela0) < 90.0, "Camera segue (moveu %.1f m; Vale %.0f px do ponto inicial na tela)" % [cam.global_position.distance_to(origem0), tela1.distance_to(tela0)])
	var t0 := cam.global_basis
	check(t0.is_equal_approx(cam.global_basis) and absf(cam.global_basis.z.angle_to(game.vila.basis_cam()[2])) < 0.001, "Seguir mantem o angulo iso fixo do V7")
	var size0 := cam.size
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game._unhandled_input(ev)
	game._unhandled_input(ev)
	await create_timer(1.0).timeout
	check(cam.size > size0 + 0.5, "Roda do mouse afasta o zoom (%.1f -> %.1f)" % [size0, cam.size])
	var tab := InputEventKey.new()
	tab.pressed = true
	tab.physical_keycode = KEY_TAB
	game._input(tab)
	var b: Vector3 = game.vila.basis_cam()[2]
	var travado := Transform3D(Basis.IDENTITY, game.vila.cam_alvo + b*90.0).looking_at(game.vila.cam_alvo, Vector3.UP)
	check(game.camera_travada and cam.global_transform.is_equal_approx(travado) and is_equal_approx(cam.size, game.vila.cam_size), "Tab trava no enquadramento exato da referencia (tamanho %.1f)" % cam.size)
	check(game.overlay_label.text.contains("Tab camera: TRAVADA"), "Legenda mostra o modo da camera")
	game._input(tab)
	await process_frame
	check(not game.camera_travada and game.overlay_label.text.contains("SEGUINDO"), "Tab volta a seguir")

func run() -> void:
	var game = load("res://fidelity_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	await frames(30)
	check(game.modular(), "Modo V7 modular ativo")
	var pecas: Array = game.vila.lista_pecas
	var n_cerca: int = game.vila.cercas.vaos.size() if game.vila.cercas != null else 0
	check(pecas.size() + n_cerca > 100, "Pecas modulares colocadas (%d pecas + %d vaos de cerca)" % [pecas.size(), n_cerca])
	var grid_ok := true
	for n in pecas:
		if n.get_meta("modulo","") != "cerca" and (absf(n.position.x-roundf(n.position.x))>0.001 or absf(n.position.z-roundf(n.position.z))>0.001):
			grid_ok = false
	check(grid_ok, "Todas as pecas encaixadas na grade de 1 m")
	var recursos := pecas.filter(func(n): return n.has_meta("recurso"))
	check(recursos.size() >= 10, "Recursos colhiveis marcados (%d)" % recursos.size())
	var plot: Dictionary = game.farm.plots[8]
	game.player.position = plot.position + Vector3(0,0.4,0)
	var before: int = plot.stage
	var r1: Dictionary = game.farm.interact(game.player.position, false)
	check(r1.acted and plot.stage != before, "Horta: E planta (estagio %d -> %d)" % [before, plot.stage])
	var r2: Dictionary = game.farm.interact(game.player.position, true)
	check(r2.acted and plot.watered, "Horta: R rega")
	game.player.position = game.cut_tree.global_position + Vector3(1.2,0.4,0)
	var hits := 0
	for i in 3:
		print("INFO golpe: ", game.cut_tree.hit(game.player.position), " jogador ", game.player.position, " arvore ", game.cut_tree.global_position)
		hits += 1
		await create_timer(0.6).timeout  # golpe tem recarga de 0,5 s
	check(game.cut_tree.felled, "Arvore cortavel cai com 3 golpes")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_2
	var antes: bool = game.efeitos.estados.orvalho
	game._unhandled_key_input(ev)
	check(game.efeitos.estados.orvalho != antes and game.efeitos.orvalho.visible == game.efeitos.estados.orvalho, "Tecla 2 alterna orvalho")
	game._unhandled_key_input(ev)
	ev.physical_keycode = KEY_O
	game._unhandled_key_input(ev)
	check(game.overlay.visible, "Tecla O continua mostrando a referencia")
	await vale_checks(game)
	await camera_checks(game)
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)