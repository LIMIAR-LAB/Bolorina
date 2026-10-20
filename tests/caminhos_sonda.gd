extends SceneTree
## Sonda: mapa de celulas andaveis perto de cada saida + caminhadas (normal/correndo/diagonal/deslocada).
var jogo
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await process_frame
func esperar(area: String) -> void:
	for i in 400:
		await process_frame
		if jogo.nome == area and jogo.atual and not jogo.ocupado:
			return
func ascii(a, c: Vector3, r := 7) -> void:
	for z in range(int(round(c.z)) - r, int(round(c.z)) + r + 1):
		var s := "%4d " % z
		for x in range(int(round(c.x)) - r, int(round(c.x)) + r + 1):
			var ch := "#"
			if a.cells.has(Vector2i(x, z)): ch = "."
			if Vector2(x - c.x, z - c.z).length() < 0.6: ch = "X"
			s += ch
		print(s)
	print("     x de %d a %d" % [int(round(c.x)) - r, int(round(c.x)) + r])
func andar(a, alvo: Vector3, de: Vector3, correr: bool, area0: String) -> String:
	a.player.position = de
	a.player.velocity = Vector3.ZERO
	a.demo_mode = true
	a.demo_running = correr
	var mind := 999.0
	for i in 420:
		await physics_frame
		if jogo.nome != area0 or jogo.ocupado:
			a.demo_input = Vector2.ZERO
			return "TROCOU apos %d frames" % i
		var d: Vector3 = alvo - a.player.position
		d.y = 0
		mind = minf(mind, d.length())
		var dl := d.normalized().rotated(Vector3.UP, -a.CAMERA_YAW)
		a.demo_input = Vector2(dl.x, dl.z).normalized()
	a.demo_input = Vector2.ZERO
	return "NAO trocou (dist min %.2f, parou em %.1f,%.1f)" % [mind, a.player.position.x, a.player.position.z]
func run() -> void:
	OS.set_environment("ILHA_SAVE", "user://caminhos_sonda.json")
	OS.set_environment("HORIZONTE", "0")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await esperar("fazenda")
	for area in ["fazenda", "vila"]:
		if jogo.nome != area:
			jogo.ir(area, "inicio")
			await esperar(area)
		var a = jogo.atual
		await frames(10)
		print("=== ", area, " CAMERA_YAW ", a.CAMERA_YAW, " cells ", a.cells.size())
		for s in a.saidas:
			print("-- saida ", s.area, " pos ", s.pos, " raio ", s.raio, " celula andavel? ", a.cells.has(Vector2i(roundi(s.pos.x), roundi(s.pos.z))))
			ascii(a, s.pos)
		for s in a.saidas:
			var p: Vector3 = s.pos
			for desl in [Vector3(0,0,0), Vector3(4,0,0), Vector3(-4,0,0), Vector3(0,0,4), Vector3(0,0,-4), Vector3(3,0,3), Vector3(-3,0,-3), Vector3(3,0,-3), Vector3(-3,0,3)]:
				var de: Vector3 = p + desl
				if not a.cells.has(Vector2i(roundi(de.x), roundi(de.z))) or desl == Vector3.ZERO:
					continue
				de.y = a.vila.altura(de.x, de.z) + 0.4
				for correr in [false, true]:
					# so para testar alcance: desliga temporariamente o gerenciador e mede
					var g = a.gerenciador
					a.gerenciador = null
					var r := await andar(a, p, de, correr, area)
					a.gerenciador = g
					print("  ", s.area, " de ", desl, " correr=", correr, ": ", r)
	quit(0)
