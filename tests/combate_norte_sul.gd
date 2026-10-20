extends SceneTree
## Vale: golpes para Norte/Sul de tela (sem folha propria) alternam as diagonais no combo
## (golpe 1 = lado atual, golpe 2 = oposto, golpe 3 = lado atual). Leste/Oeste e diagonais nao mudam.
var checks := 0
var failures := 0
var a
var j
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + text)
func _initialize() -> void:
	call_deferred("run")
func fis(n: int) -> void:
	for i in n:
		await physics_frame

func combo(dir: Vector3) -> Dictionary:
	var vistos := {}
	j.reiniciar(Vector3.ZERO)
	await fis(3)
	for golpe in 3:
		j.pedir_ataque(dir)
		for k in 12:
			await physics_frame
			if j.estado == "ataque":
				vistos[j.combo_i] = j.dir6()
	await fis(40)
	return vistos

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
	# logica pura
	j.estado = "ataque"
	j.dir8 = "north"
	j.lado = 1
	var r := []
	for i in 3:
		j.combo_i = i
		r.append(j.dir6())
	check(r == ["north-east", "north-west", "north-east"], "N: alterna NE/NW/NE %s" % str(r))
	j.dir8 = "south"
	j.lado = -1
	r = []
	for i in 3:
		j.combo_i = i
		r.append(j.dir6())
	check(r == ["south-west", "south-east", "south-west"], "S: alterna SW/SE/SW %s" % str(r))
	j.dir8 = "east"
	j.combo_i = 1
	check(j.dir6() == "east", "Leste nao muda")
	j.estado = "livre"
	j.dir8 = "north"
	j.lado = 1
	check(j.dir6() == "north-east", "Fora do ataque: diagonal pelo ultimo lado")
	await fis(2)
	# em jogo: combo para cima da tela
	var v: Dictionary = await combo(j.cam_cima)
	print("INFO combo norte: ", v)
	var lados := {}
	for k in v:
		lados[v[k]] = true
	check(v.size() >= 2 and lados.has("north-east") and lados.has("north-west"), "Combo para o Norte usa as duas diagonais")
	var anim_ok := true
	for d in ["north-east", "north-west", "south-east", "south-west"]:
		for i in 3:
			if not j.sprite.sprite_frames.has_animation("c_slash_combo_" + d) and not j.sprite.sprite_frames.has_animation("x_slash_combo_" + d):
				anim_ok = false
	check(anim_ok, "Quadros de combo existem nas 4 diagonais")
	v = await combo(-j.cam_cima)
	print("INFO combo sul: ", v)
	lados = {}
	for k in v:
		lados[v[k]] = true
	check(lados.has("south-east") and lados.has("south-west"), "Combo para o Sul usa as duas diagonais")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
