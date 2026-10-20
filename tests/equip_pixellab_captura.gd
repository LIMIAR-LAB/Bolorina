extends SceneTree
## Conferencia visual das pecas do PixelLab no jogo (com janela; usa save de teste, nao toca o save real).
## Vila: abre a tela de equipamento (I), veste cada peca pela tela e fotografa a Vale no mundo nas 8 direcoes
## (parada) + correndo. Depois fazenda e combate com armadura + elmo.
## Saida: work/equip_logs/pixellab/cap/*.png e a folha docs/equip-pixellab-jogo.png
const Equip = preload("res://scripts/ilha/equipamento.gd")
const SAVE := "user://ilha_equip_captura.json"
const DIRS := ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
const PECAS := ["capuz_couro", "elmo_ferro", "elmo_adamantium", "couro_cacador", "malha_guarda"]
const LADO := 120
var jogo
var folha: Image
var pasta := ""

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func tecla(k: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	await fr(2)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)
	await fr(1)

func tela_img() -> Image:
	await fr(4)
	return root.get_viewport().get_texture().get_image()

## recorte em volta da Vale (projecao da camera)
func recorte(a, img: Image) -> Image:
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var p := cam.unproject_position(a.player.global_position + Vector3(0, 0.9, 0))
	var r := Rect2i(int(p.x) - LADO / 2, int(p.y) - LADO / 2, LADO, LADO)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)

func colar(img: Image, col: int, lin: int) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var r := Rect2i(Vector2i.ZERO, img.get_size())
	folha.blit_rect(img, r, Vector2i(col * LADO, lin * LADO))

func preparar(a) -> void:
	a.player.velocity = Vector3.ZERO
	a.camera_travada = true
	a.vila.cam_alvo = Vector3(a.player.position.x, 0, a.player.position.z)
	a.vila.cam_size = 11.0
	a.apply_camera()

func _run() -> void:
	create_timer(400.0).timeout.connect(func():
		print("FAIL tempo esgotado")
		paused = false
		quit(2))
	pasta = ProjectSettings.globalize_path("res://work/equip_logs/pixellab/cap/")
	DirAccess.make_dir_recursive_absolute(pasta)
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "vila")
	OS.set_environment("ILHA_SPAWN", "da_fazenda")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 240:
		await process_frame
		if jogo.atual and jogo.nome == "vila" and not jogo.ocupado:
			break
	await create_timer(0.8).timeout
	var v = jogo.atual
	v.nascer("padrao")
	await fr(3)
	preparar(v)
	# linhas: sem peca + 5 pecas + 2 combinacoes; colunas: 8 direcoes paradas + 2 de corrida
	var linhas := [[], ["capuz_couro"], ["elmo_ferro"], ["elmo_adamantium"], ["couro_cacador"], ["malha_guarda"],
		["couro_cacador", "capuz_couro"], ["malha_guarda", "elmo_adamantium"]]
	folha = Image.create(LADO * 10, LADO * linhas.size(), false, Image.FORMAT_RGBA8)
	folha.fill(Color(0.1, 0.1, 0.1))
	for li in linhas.size():
		# veste pela tela de equipamento (I, escolhe, Enter, I)
		await tecla(KEY_I)
		var tela = jogo.equip_tela
		for s in Equip.SLOTS:
			tela.tirar_slot(s)
		for id in linhas[li]:
			tela.sel = tela.possui_lista().find(id)
			await tecla(KEY_ENTER)
		if li > 0:
			var it: Image = await tela_img()
			it.save_png(pasta + "tela_%s.png" % "+".join(linhas[li]))
		await tecla(KEY_I)
		var cam_ok := []
		for id in linhas[li]:
			cam_ok.append(Equip.esta_equipado(jogo.estado.equipamento, id))
		print("INFO linha %d %s vestido=%s camadas=%s" % [li, str(linhas[li]), str(cam_ok), str(Equip.camadas(jogo.estado.equipamento))])
		preparar(v)
		for di in DIRS.size():
			v.sprite.facing_direction = DIRS[di]
			v.sprite.play(v.sprite.animation_for("idle"))
			var img: Image = await tela_img()
			colar(recorte(v, img), di, li)
		for k in 2:
			v.sprite.facing_direction = ["south-east", "north-west"][k]
			v.sprite.play(v.sprite.animation_for("run"))
			v.sprite.frame = 3
			v.sprite.pause()
			var img2: Image = await tela_img()
			colar(recorte(v, img2), 8 + k, li)
	folha.save_png(ProjectSettings.globalize_path("res://docs/equip-pixellab-jogo.png"))
	print("INFO folha docs/equip-pixellab-jogo.png")
	# fazenda com couraca + capuz
	await tecla(KEY_I)
	for id in ["couro_cacador", "capuz_couro"]:
		jogo.equip_tela.sel = jogo.equip_tela.possui_lista().find(id)
		await tecla(KEY_ENTER)
	await tecla(KEY_I)
	jogo.ir("fazenda", "da_vila")
	for i in 300:
		await process_frame
		if jogo.nome == "fazenda" and not jogo.ocupado:
			break
	await create_timer(0.6).timeout
	var fz = jogo.atual
	fz.nascer("inicio")
	await fr(3)
	preparar(fz)
	for d in ["south-west", "north-east"]:
		fz.sprite.facing_direction = d
		fz.sprite.play(fz.sprite.animation_for("idle"))
		(await tela_img()).save_png(pasta + "fazenda_%s.png" % d)
	# combate com malha + elmo de ferro: um quadro de cada golpe
	Equip.equipar(jogo.estado.equipamento, "malha_guarda")
	Equip.equipar(jogo.estado.equipamento, "elmo_ferro")
	jogo.ir("arena", "da_vila")
	for i in 400:
		await process_frame
		if jogo.nome == "arena" and not jogo.ocupado:
			break
	await create_timer(0.6).timeout
	var j = jogo.atual.jogador
	for anim in ["c_slash_combo_east", "c_dash_north-east", "c_hit_south-west", "c_special_west", "idle_south", "run_north-west"]:
		if j.sprite.sprite_frames.has_animation(anim):
			j.sprite.play(anim)
			j.sprite.frame = mini(12, j.sprite.sprite_frames.get_frame_count(anim) - 1)
			j.sprite.pause()
			(await tela_img()).save_png(pasta + "combate_%s.png" % anim)
	print("INFO capturas em work/equip_logs/pixellab/cap/")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	paused = false
	quit(0)
