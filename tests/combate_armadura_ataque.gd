extends SceneTree
## Transformado (adamantium): combo/dash/especial/dano usam quadros COM armadura (x_*),
## asas visiveis; destransformado volta aos golpes normais (c_*). CMB_CAP=1 grava docs/combate-armadura-ataque.png
var checks := 0
var failures := 0
var a
var j

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func fis(n: int) -> void:
	for i in n:
		await physics_frame

func esperar(s: float) -> void:
	var alvo: float = j.relogio + s
	var guarda := 0
	while j.relogio < alvo - 0.0001 and guarda < 3000:
		await physics_frame
		guarda += 1

func anim() -> String:
	return String(j.sprite.animation)

func run() -> void:
	a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	await fis(5)
	j = a.jogador
	a.hitstop_ativo = false
	for e in a.inimigos.duplicate():
		if is_instance_valid(e):
			a._inimigo_removido(e)
			e.queue_free()
	await fis(2)
	j.reiniciar(Vector3.ZERO)
	check(j.sprite.sprite_frames.has_animation("x_slash_combo_south-east"), "Quadros com armadura carregados (x_*)")
	j.pedir_ataque(Vector3(1, 0, 0))
	await esperar(0.08)
	check(anim().begins_with("c_slash_combo"), "Sem transformar: combo normal (%s)" % anim())
	await esperar(0.8)
	j.energia = j.energia_max
	j.pedir_transformar()
	await esperar(j.transformar_duracao + 0.1)
	check(j.transformado, "Transformado")
	var e = a.gerar_inimigo(Vector3(1.6, 0, 0))
	e.alvo = null
	var vistos := {}
	for golpe in 3:
		j.pedir_ataque(Vector3(1, 0, 0))
		for k in 12:
			await physics_frame
			if j.estado == "ataque":
				vistos[anim()] = j.adamantium.asas.values()[0].visible
	var ok_combo := not vistos.is_empty()
	var asas_ok := true
	for n in vistos:
		ok_combo = ok_combo and String(n).begins_with("x_slash_combo")
		asas_ok = asas_ok and bool(vistos[n])
	check(ok_combo, "Combo transformado com armadura %s" % str(vistos.keys()))
	check(asas_ok, "Asas visiveis durante o combo")
	if OS.get_environment("CMB_CAP") == "1":
		if is_instance_valid(e):
			a._inimigo_removido(e)
			e.queue_free()
		await esperar(0.7)
		j.pedir_ataque(Vector3(1, 0, 0))
		await fis(5)
		await process_frame
		var img: Image = a.get_viewport().get_texture().get_image()
		var cam: Camera3D = a.get_viewport().get_camera_3d()
		var sp: Vector2 = cam.unproject_position(j.global_position + Vector3(0, 0.8, 0)) if cam else img.get_size() * 0.5
		var lado := 260
		var r := Rect2i(Vector2i(sp) - Vector2i(lado / 2, lado / 2), Vector2i(lado, lado)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var rec := img.get_region(r)
		rec.resize(r.size.x * 3, r.size.y * 3, Image.INTERPOLATE_NEAREST)
		rec.save_png(ProjectSettings.globalize_path("res://docs/combate-armadura-ataque.png"))
		img.save_png(ProjectSettings.globalize_path("res://docs/combate-armadura-ataque-tela.png"))
		print("INFO captura docs/combate-armadura-ataque.png anim=", anim())
	await esperar(0.7)
	j.pedir_dash()
	var dash_ok := false
	for k in 10:
		await physics_frame
		if j.estado == "dash":
			dash_ok = anim().begins_with("x_dash")
			break
	check(dash_ok, "Dash transformado com armadura (%s)" % anim())
	await esperar(0.6)
	# especial e dano: forca o estado e confere a animacao escolhida
	for par in [["especial", "x_special"], ["ferido", "x_hit"]]:
		j.estado = par[0]
		j.t_estado = 0.05
		j._animar()
		check(anim().begins_with(par[1]), "%s transformado com armadura (%s)" % [par[0], anim()])
	j.estado = "livre"
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
