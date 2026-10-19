extends SceneTree
## Varredura de travamento + cercas da vila V7 (fidelity_village):
## 1) celulas livres (sem colisor) e grafo de passagem (test_move entre vizinhas) a partir do spawn;
## 2) sonda CharacterBody3D (mesma capsula da Vale) tenta sair de cada celula alcancavel nas 4 direcoes
##    respeitando a regra de celulas do island.gd -> lista pontos de travamento;
## 3) a Vale real percorre rotas (A*/BFS) ate portas, portoes, ponte, deck e saidas;
## 4) cercas: postes nas bordas das celulas, vaos <= 1 m, sem duplicatas, travessas ligando topos,
##    sem cruzar outros colisores, portoes atravessaveis.
##   Godot --path . --resolution 1600x900 --script tests/vila_travamento.gd
var checks := 0
var failures := 0
var game
var space: PhysicsDirectSpaceState3D
var sonda: CharacterBody3D
var cap := CapsuleShape3D.new()
var livre := {}
var piso := {}
var spawn := Vector3.ZERO
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

func chao(c: Vector2i) -> float:
	# topo do que estiver na celula (terreno, ponte); props altos marcam a celula como ocupada
	var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, 8, c.y), Vector3(c.x, -6, c.y))
	q.exclude = [game.player.get_rid(), sonda.get_rid()]
	var r := space.intersect_ray(q)
	return float(r.position.y) if r else -99.0

func capsula_livre(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.55, 0))
	q.exclude = [game.player.get_rid(), sonda.get_rid()]
	return space.intersect_shape(q, 1).is_empty()

func run() -> void:
	var save_path := "user://island_v1.json"
	var existed := FileAccess.file_exists(save_path)
	var md5 := FileAccess.get_md5(save_path) if existed else ""
	game = load("res://fidelity_village.tscn").instantiate()
	root.add_child(game)
	game.demo_mode = true
	await frames(60)
	space = game.player.get_world_3d().direct_space_state
	spawn = game.player.position
	cap.radius = 0.25
	cap.height = 1.0
	sonda = CharacterBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.5
	sonda.add_child(col)
	sonda.floor_snap_length = 0.6
	sonda.floor_max_angle = deg_to_rad(48)
	sonda.floor_constant_speed = true
	sonda.collision_mask = game.player.collision_mask
	sonda.collision_layer = 0
	game.add_child(sonda)
	sonda.position = Vector3(0, -50, 0)
	var camada_jogador: int = game.player.collision_layer
	game.player.collision_layer = 0
	await frames(3)
	var celulas: Array = []
	for c in game.cells:
		if absf(c.x) < 150 and absf(c.y) < 150:
			celulas.append(c)
	var conj := {}
	for c in celulas:
		conj[c] = true
	check(celulas.size() > 1500, "Grade andavel V7 (%d celulas, terreno modular + ponte)" % celulas.size())
	for c in celulas:
		var y := chao(c)
		piso[c] = y
		livre[c] = y > -1.5 and y < 0.9 and capsula_livre(Vector3(c.x, y + 0.25, c.y))
	# BFS de passagem
	var inicio := Vector2i(roundi(game.player.position.x), roundi(game.player.position.z))
	check(livre.get(inicio, false), "Spawn livre %s" % str(inicio))
	var veio := {inicio: inicio}
	var fila: Array = [inicio]
	var vizs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while not fila.is_empty():
		var a: Vector2i = fila.pop_front()
		for o in vizs:
			var b: Vector2i = a + o
			if veio.has(b) or not livre.get(b, false):
				continue
			var pa := Vector3(a.x, float(piso[a]) + 0.25, a.y)
			var pb := Vector3(b.x, float(piso[b]) + 0.25, b.y)
			if not sonda.test_move(Transform3D(Basis(), pa), pb - pa):
				veio[b] = a
				fila.append(b)
	var n_livres := 0
	for c in livre:
		if livre[c]:
			n_livres += 1
	var bolsoes: Array = []
	var visto := {}
	for c in livre:
		if livre[c] and not veio.has(c) and not visto.has(c):
			var comp := [c]
			visto[c] = true
			var f2: Array = [c]
			while not f2.is_empty():
				var a: Vector2i = f2.pop_front()
				for o in vizs:
					var b: Vector2i = a + o
					if livre.get(b, false) and not veio.has(b) and not visto.has(b):
						visto[b] = true
						comp.append(b)
						f2.append(b)
			bolsoes.append(comp)
	bolsoes.sort_custom(func(x, y): return x.size() > y.size())
	var resumo := []
	for b in bolsoes.slice(0, 6):
		resumo.append("%d@%s" % [b.size(), str(b[0])])
	print("INFO alcancaveis %d de %d livres; bolsoes isolados %d %s" % [veio.size(), n_livres, bolsoes.size(), str(resumo)])
	check(veio.size() > 0.9 * n_livres, "Area alcancavel a partir do spawn: %d/%d celulas livres (%.1f%%)" % [veio.size(), n_livres, 100.0 * veio.size() / maxf(1, n_livres)])
	# sonda: sair de cada celula alcancavel
	var presos: Array = []
	for c in veio:
		var y0: float = float(piso[c])
		var saiu := false
		for o in [Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,0,1), Vector3(0,0,-1), Vector3(0.707,0,0.707), Vector3(-0.707,0,-0.707)]:
			sonda.position = Vector3(c.x, y0 + 0.05, c.y)
			sonda.velocity = Vector3.ZERO
			var p0 := sonda.position
			for k in 8:
				var antes := sonda.position
				sonda.velocity = o * 2.8 + Vector3(0, -2.0, 0)
				sonda.move_and_slide()
				if not conj.has(Vector2i(roundi(sonda.position.x), roundi(sonda.position.z))):
					sonda.position = antes
			if Vector2(sonda.position.x - p0.x, sonda.position.z - p0.z).length() > 0.15:
				saiu = true
				break
		if not saiu:
			presos.append(c)
	print("INFO pontos de travamento: %s" % str(presos.slice(0, 20)))
	check(presos.is_empty(), "Sonda sai de todas as %d celulas alcancaveis (presos: %d)" % [veio.size(), presos.size()])
	sonda.position = Vector3(0, -50, 0)
	if game.vila.cercas != null:
		await cercas_checks()
	else:
		check(false, "Cercas modulares ativas (cercas antigas em uso)")
	game.player.collision_layer = camada_jogador
	await rotas(veio)
	check(FileAccess.file_exists(save_path) == existed and (not existed or FileAccess.get_md5(save_path) == md5), "Save do jogador intocado")
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func cercas_checks() -> void:
	var cz = game.vila.cercas
	check(cz != null and cz.postes.size() > 20, "Cercas modulares ativas (%d postes, %d vaos)" % [cz.postes.size() if cz else 0, cz.vaos.size() if cz else 0])
	var antigas := 0
	for p in game.vila.lista_pecas:
		if String(p.get_meta("modulo", "")) == "cerca":
			antigas += 1
	check(antigas == 0, "Pecas de cerca antigas removidas (%d)" % antigas)
	var fora_grade := 0
	var dup := 0
	var vistos := {}
	for p in cz.postes:
		var v: Vector3 = p.pos
		if absf(absf(fposmod(v.x, 1.0)) - 0.5) > 0.01 or absf(absf(fposmod(v.z, 1.0)) - 0.5) > 0.01:
			fora_grade += 1
		var k := Vector2i(roundi(v.x * 2), roundi(v.z * 2))
		if vistos.has(k):
			dup += 1
		vistos[k] = true
		if absf(v.y - game.vila.altura(v.x, v.z)) > 0.01:
			fora_grade += 1
	check(fora_grade == 0, "Postes nas bordas das celulas (x.5/z.5) e no chao (%d fora)" % fora_grade)
	check(dup == 0, "Sem postes sobrepostos (%d duplicados)" % dup)
	var ruins := 0
	var portoes := 0
	for v in cz.vaos:
		var a: Vector3 = v.a
		var b: Vector3 = v.b
		var L := Vector2(b.x - a.x, b.z - a.z).length()
		if L > 1.001 or L < 0.5:
			ruins += 1
		if v.portao:
			portoes += 1
			continue
		for t in v.travessas:
			var ra: Vector3 = t[0]
			var rb: Vector3 = t[1]
			if not (vistos.has(Vector2i(roundi(ra.x * 2), roundi(ra.z * 2))) and vistos.has(Vector2i(roundi(rb.x * 2), roundi(rb.z * 2)))):
				ruins += 1
		# travessa de baixo nunca entra no chao no meio do vao
		var m := (a + b) * 0.5
		if (a.y + b.y) * 0.5 + 0.4 - game.vila.altura(m.x, m.z) < 0.25:
			ruins += 1
	check(ruins == 0, "Vaos de 1 m continuos, travessas presas nos postes e acima do chao (%d ruins)" % ruins)
	check(portoes >= 2, "Portoes nas cercas da horta e do campo (%d)" % portoes)
	# cada vao nao invade colisores de casas/props
	var invade: Array = []
	for v in cz.vaos:
		if v.portao:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var bx := BoxShape3D.new()
		var a: Vector3 = v.a
		var b: Vector3 = v.b
		var d := Vector2(b.x - a.x, b.z - a.z)
		bx.size = Vector3(maxf(0.1, d.length() - 0.3), 0.6, 0.1)
		q.shape = bx
		q.transform = Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), (a + b) * 0.5 + Vector3(0, 0.55, 0))
		q.exclude = [game.player.get_rid(), sonda.get_rid()]
		for h in space.intersect_shape(q, 8):
			var o = h.collider
			if o is StaticBody3D and not o.has_meta("cerca") and not (o.get_parent() is MeshInstance3D and String(o.get_parent().name) == "TerrenoModular"):
				invade.append(str((a + b) * 0.5))
				break
	check(invade.is_empty(), "Cercas nao atravessam casas/props %s" % str(invade.slice(0, 5)))
	# portoes: a Vale real atravessa cada portao nos dois sentidos
	game.player.collision_layer = 1
	var cruzou := 0
	for v in cz.vaos:
		if not v.portao:
			continue
		var a: Vector3 = v.a
		var b: Vector3 = v.b
		var m := (a + b) * 0.5
		var nrm := Vector3(-(b.z - a.z), 0, b.x - a.x).normalized()
		var ok := true
		for s in [1.0, -1.0]:
			var de: Vector3 = m - nrm * s * 1.5
			game.player.position = Vector3(de.x, game.vila.altura(de.x, de.z) + 0.3, de.z)
			game.player.velocity = Vector3.ZERO
			await physics_frame
			var ate: Vector3 = m + nrm * s * 1.5
			var r: String = await andar([Vector2i(0, 0), Vector2(ate.x, ate.z)])
			var passou: bool = (game.player.position - m).dot(nrm * s) > 1.0
			print("INFO portao %s sentido %d: %s" % [str(m), int(s), "ok" if passou else "travou em " + str(game.player.position)])
			ok = ok and passou
		if ok:
			cruzou += 1
	check(cruzou == portoes, "Portoes atravessaveis pela Vale nos dois sentidos (%d/%d)" % [cruzou, portoes])
	sonda.position = Vector3(0, -50, 0)

func caminho(veio: Dictionary, alvo: Vector2i) -> Array:
	if not veio.has(alvo):
		var melhor := alvo
		var d := 1e9
		for c in veio:
			var dd := Vector2(c - alvo).length()
			if dd < d:
				d = dd
				melhor = c
		alvo = melhor
	var r: Array = [alvo]
	while veio[r[0]] != r[0]:
		r.push_front(veio[r[0]])
	return r

func andar(cam: Array) -> String:
	# segue o caminho celula a celula; volta "" se chegou, ou a celula onde travou
	game.demo_running = true
	for i in range(1, cam.size()):
		var alvo := Vector3(float(cam[i].x), 0, float(cam[i].y))
		var t := 0.0
		while true:
			var d := Vector3(alvo.x - game.player.position.x, 0, alvo.z - game.player.position.z)
			if d.length() < 0.4:
				break
			var dl := d.normalized().rotated(Vector3.UP, -game.CAMERA_YAW)
			game.demo_input = Vector2(dl.x, dl.z)
			await physics_frame
			t += 1.0 / 60.0
			if t > 2.5:
				game.demo_input = Vector2.ZERO
				return str(cam[i])
	game.demo_input = Vector2.ZERO
	return ""

func rotas(veio: Dictionary) -> void:
	var alvos := {"porta_casa_1": game.interiores.saida_fora(0), "porta_casa_2": game.interiores.saida_fora(1) if game.interiores.casas.size() > 1 else Vector3(-3, 0, -13),
		"portao_horta": Vector3(-15, 0, -1), "portao_campo": Vector3(5, 0, -11), "poco": Vector3(1, 0, -3), "ponte_sul": Vector3(0, 0, 12),
		"deck": Vector3(-14, 0, 8), "leste": Vector3(18, 0, -4), "ruinas_norte": Vector3(-6, 0, -19)}
	var falhas: Array = []
	var inicio: Vector3 = spawn
	for nome in alvos:
		var p: Vector3 = alvos[nome]
		game.player.position = inicio
		game.player.velocity = Vector3.ZERO
		await physics_frame
		var cam := caminho(veio, Vector2i(roundi(p.x), roundi(p.z)))
		var r: String = await andar(cam)
		if r != "":
			falhas.append("%s travou em %s (pos %s)" % [nome, r, str(game.player.position.snapped(Vector3.ONE * 0.01))])
		else:
			print("INFO rota %s ok (%d celulas)" % [nome, cam.size()])
	game.demo_running = false
	game.player.position = inicio
	check(falhas.is_empty(), "Vale percorre %d rotas reais sem travar %s" % [alvos.size(), str(falhas)])
