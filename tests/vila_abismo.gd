extends SceneTree
## Quedas no abismo / bordas do terreno (vila V7). ABISMO_MODO=antes liga "abismo_v1" (sem protecao).
## 1) piso sob centro e bordas (0,4 m) de toda celula andavel; 2) Vale empurrada contra cada borda de queda
## (amostra) e contra o abismo das ruinas; 3) reaparecer apos queda forcada; 4) save intacto.
## ABISMO_CAP=1 grava docs/vila-abismo-<modo>.png (borda das ruinas).
var checks := 0
var failures := 0
var game
var space: PhysicsDirectSpaceState3D
var modo := "depois"

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func piso(x: float, z: float, h: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 1.5, z), Vector3(x, h - 1.0, z))
	q.exclude = [game.player.get_rid()]
	var r := space.intersect_ray(q)
	# objeto solido acima do chao (fonte, poco) tambem conta: o que importa e nao haver buraco
	return not r.is_empty() and float(r.position.y) > h - 0.7

func empurrar(c: Vector2i, d: Vector2, segundos: float) -> float:
	# poe a Vale na celula c e empurra na direcao d; devolve a menor altura relativa ao chao inicial
	var h: float = game.vila.altura(float(c.x), float(c.y))
	game.player.position = Vector3(c.x, h + 0.3, c.y)
	game.player.velocity = Vector3.ZERO
	await frames(6)
	game.ultimo_seguro = game.player.position
	var dl := Vector3(d.x, 0, d.y).normalized().rotated(Vector3.UP, -game.CAMERA_YAW)
	game.demo_input = Vector2(dl.x, dl.z)
	game.demo_running = true
	var menor := 0.0
	var t := 0.0
	while t < segundos:
		await physics_frame
		t += 1.0 / 60.0
		menor = minf(menor, game.player.position.y - h)
	game.demo_input = Vector2.ZERO
	return menor

func run() -> void:
	modo = OS.get_environment("ABISMO_MODO") if OS.get_environment("ABISMO_MODO") != "" else "depois"
	if modo == "antes":
		OS.set_environment("FID_CONFIG_EXTRA", "{\"abismo_v1\": true}")
	var save_path := "user://island_v1.json"
	var existed := FileAccess.file_exists(save_path)
	var md5 := FileAccess.get_md5(save_path) if existed else ""
	game = load("res://fidelity_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	await frames(60)
	space = game.player.get_world_3d().direct_space_state
	var v = game.vila
	var celulas := {}
	for c in game.cells:
		if c.x > 200:
			continue  # interiores
		celulas[c] = true
	print("INFO modo=%s celulas andaveis=%d barreiras=%d" % [modo, celulas.size(), game.barreiras.paredes.size() if game.barreiras else 0])
	# 1) piso
	var sem_piso: Array = []
	for c in celulas:
		var h: float = v.altura(float(c.x), float(c.y))
		for o in [Vector2(0,0), Vector2(0.4,0), Vector2(-0.4,0), Vector2(0,0.4), Vector2(0,-0.4)]:
			if not piso(c.x + o.x, c.y + o.y, h):
				sem_piso.append(c)
				break
	print("INFO celulas andaveis sem piso: %d %s" % [sem_piso.size(), str(sem_piso.slice(0, 12))])
	check(sem_piso.is_empty(), "Piso solido sob toda celula andavel (centro e bordas 0,4 m)")
	# 2) bordas de queda: celulas andaveis vizinhas de queda (> 1,5 m) ou da borda do terreno
	var bordas: Array = []
	for c in celulas:
		var h: float = v.altura(float(c.x), float(c.y))
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			var ix: int = n.x - v.origem.x
			var iz: int = n.y - v.origem.y
			var fora: bool = ix < 0 or iz < 0 or ix >= v.tam.x or iz >= v.tam.y
			var hn: float = -1000.0 if fora else float(v.alturas[iz][ix])
			var queda := fora or hn < h - 1.5
			# celula segura cuja vizinha 2 passos adiante e queda tambem conta (a borda recuou)
			var n2: Vector2i = c + d * 2
			var ix2: int = n2.x - v.origem.x
			var iz2: int = n2.y - v.origem.y
			var fora2: bool = ix2 < 0 or iz2 < 0 or ix2 >= v.tam.x or iz2 >= v.tam.y
			if queda or (not celulas.has(n) and (fora2 or float(v.alturas[iz2][ix2]) < h - 1.5)):
				bordas.append([c, d])
	print("INFO bordas de queda: %d" % bordas.size())
	var amostra: Array = []
	var passo := maxi(1, bordas.size() / 25)
	for i in range(0, bordas.size(), passo):
		amostra.append(bordas[i])
	var caiu: Array = []
	for b in amostra:
		var m: float = await empurrar(b[0], Vector2(b[1].x, b[1].y), 1.2)
		if m < -1.0:
			caiu.append(b[0])
	print("INFO amostra %d bordas, quedas: %d %s" % [amostra.size(), caiu.size(), str(caiu.slice(0, 10))])
	check(caiu.is_empty(), "Vale empurrada contra %d bordas de queda nao cai" % amostra.size())
	# 3) caminho das ruinas (norte): empurrar para o abismo a partir da trilha
	var ruinas_caiu := 0
	for c in [Vector2i(-6, -20), Vector2i(-5, -20), Vector2i(-12, -19), Vector2i(2, -20), Vector2i(-6, -19)]:
		if not celulas.has(c):
			continue
		for d in [Vector2(0, -1), Vector2(-0.7, -0.7), Vector2(0.7, -0.7)]:
			var m: float = await empurrar(c, d, 2.0)
			if m < -1.0:
				ruinas_caiu += 1
	check(ruinas_caiu == 0, "Trilha das ruinas: empurrar para o abismo nao derruba a Vale (%d quedas)" % ruinas_caiu)
	if OS.get_environment("ABISMO_CAP") == "1":
		await capturar()
		if modo == "depois":
			await capturar_borda()
	# 4) queda forcada -> reaparece no ultimo ponto seguro
	var seguro := Vector3(-6, v.altura(-6, -19) + 0.3, -19)
	game.player.position = seguro
	await frames(10)
	var q0: int = game.quedas
	game.player.position = Vector3(-6, -3.0, -26)
	game.player.velocity = Vector3.ZERO
	await frames(120)
	var voltou: bool = game.quedas > q0 and game.player.position.distance_to(game.ultimo_seguro) < 1.0 and game.player.position.y > -1.0
	check(voltou, "Queda forcada: reaparece em terra firme em ~1 s (y=%.1f)" % game.player.position.y)
	check(FileAccess.file_exists(save_path) == existed and (not existed or FileAccess.get_md5(save_path) == md5), "Save do jogador intocado")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func capturar() -> void:
	var v = game.vila
	game.camera_travada = true
	v.cam_alvo = Vector3(-6, 0, -21)
	v.cam_size = 14.0
	game.apply_camera()
	var c := Vector2i(-6, -20)
	var h: float = v.altura(-6.0, -20.0)
	game.player.position = Vector3(c.x, h + 0.3, c.y)
	game.player.velocity = Vector3.ZERO
	await frames(6)
	var dl := Vector3(0, 0, -1).rotated(Vector3.UP, -game.CAMERA_YAW)
	game.demo_input = Vector2(dl.x, dl.z)
	await frames(55)
	await process_frame
	var img: Image = game.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/vila-abismo-%s.png" % modo))
	print("INFO captura docs/vila-abismo-%s.png (y relativo %.2f)" % [modo, game.player.position.y - h])
	game.demo_input = Vector2.ZERO
	game.camera_travada = false

func foto(nome: String, alvo: Vector3, tam: float) -> void:
	var v = game.vila
	game.camera_travada = true
	v.cam_alvo = Vector3(alvo.x, 0, alvo.z)
	v.cam_size = tam
	game.apply_camera()
	await frames(4)
	await process_frame
	var img: Image = game.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % nome))
	print("INFO captura docs/%s.png alvo=%s" % [nome, str(alvo)])

func capturar_borda() -> void:
	var b = game.barreiras
	var no: Node3D = b.raiz.get_parent().get_node_or_null("BordaNatural") if b.raiz else null
	if no == null:
		for n in game.find_children("BordaNatural", "", true, false):
			no = n
	if no == null:
		print("INFO sem BordaNatural"); return
	print("INFO borda natural: %d pecas" % int(no.get_meta("pecas", 0)))
	var v = game.vila
	var c := Vector2i(-6, -19)
	game.player.position = Vector3(c.x, v.altura(-6.0, -19.0) + 0.3, c.y)
	game.player.velocity = Vector3.ZERO
	await frames(10)
	await foto("vila-borda-natural", Vector3(-6, 0, -20), 11.0)
	# outra borda: a peca mais distante das ruinas (borda do terreno / penhasco)
	var melhor := Vector3.ZERO
	var dmax := -1.0
	for p in no.get_children():
		var d: float = Vector2(p.position.x + 6, p.position.z + 20).length()
		if d > dmax and d < 30.0:
			dmax = d
			melhor = p.position
	await foto("vila-borda-natural-2", melhor, 12.0)
	game.camera_travada = false
