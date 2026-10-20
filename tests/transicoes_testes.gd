extends SceneTree
## Transicoes entre areas (saidas_area.gd): a Vale real anda ate cada saida, de varios angulos,
## andando e correndo (Shift), com deslocamento lateral, e o jogo TEM que trocar de area.
## Tambem: nada dispara ao nascer (rearme), nenhuma placa no caminho, saida da fazenda desligada dentro de casa,
## portao oeste da arena so fora do combate, varredura do passo (esquiva rapida nao "pula" o portao).
##   Godot --headless --path . --script tests/transicoes_testes.gd
const C = preload("res://scripts/ilha/caminhos_ilha.gd")
var checks := 0
var failures := 0
var jogo
var log_falhas: Array[String] = []

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		log_falhas.append(text)
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func esperar(area: String, n := 600) -> bool:
	for i in n:
		await process_frame
		if jogo.nome == area and jogo.atual and not jogo.ocupado:
			return true
	return false

func ir_para(area: String, spawn: String) -> void:
	if jogo.nome != area:
		jogo.ir(area, spawn)
	await esperar(area)
	for i in 6:
		await physics_frame

func saidas_de(a) -> Node:
	return a.get("saidas_novas")

## anda com a entrada de teclado simulada (demo_input) na direcao mundo `dir` ate trocar de area
func caminhar(a, de: Vector2, dir: Vector2, correr: bool, area0: String, max_q := 360) -> Dictionary:
	a.player.position = Vector3(de.x, a.vila.altura(de.x, de.y) + 0.4, de.y)
	a.player.velocity = Vector3.ZERO
	await physics_frame
	a.demo_mode = true
	a.demo_running = correr
	var d3 := Vector3(dir.x, 0, dir.y).normalized().rotated(Vector3.UP, -a.CAMERA_YAW)
	a.demo_input = Vector2(d3.x, d3.z).normalized()
	for i in max_q:
		await physics_frame
		if jogo.ocupado or jogo.nome != area0:
			return {"trocou": true, "q": i}
		if not is_instance_valid(a):
			return {"trocou": true, "q": i}
	a.demo_input = Vector2.ZERO
	return {"trocou": false, "q": max_q, "fim": Vector2(a.player.position.x, a.player.position.z)}

## versao rapida: so o sinal da saida (sem trocar a cena), para a matriz de angulos
func caminhar_sinal(a, de: Vector2, dir: Vector2, correr: bool, max_q := 360) -> String:
	var s = saidas_de(a)
	var g = a.gerenciador
	a.gerenciador = null
	var got := [""]
	var cb := func(ar: String, _sp: String): got[0] = ar
	s.saiu.connect(cb)
	s.armado = false
	a.player.position = Vector3(de.x, a.vila.altura(de.x, de.y) + 0.4, de.y)
	a.player.velocity = Vector3.ZERO
	s.anterior = Vector3.INF
	await physics_frame
	a.demo_mode = true
	a.demo_running = correr
	var d3 := Vector3(dir.x, 0, dir.y).normalized().rotated(Vector3.UP, -a.CAMERA_YAW)
	a.demo_input = Vector2(d3.x, d3.z).normalized()
	for i in max_q:
		await physics_frame
		if got[0] != "":
			break
	a.demo_input = Vector2.ZERO
	a.demo_mode = false
	s.saiu.disconnect(cb)
	if got[0] == "":
		print("   (de %s parou em %.2f, %.2f)" % [de, a.player.position.x, a.player.position.z])
	a.gerenciador = g
	return got[0]

func matriz(area: String, defs: Array) -> void:
	var a = jogo.atual
	for d in defs:
		var c: Vector2 = d.centro
		var dir: Vector2 = Vector2(d.dir).normalized()
		var lado := Vector2(dir.y, -dir.x)
		var borda: Vector2 = c - dir * (float(d.tam.y) * 0.5)
		var tp: Dictionary = d.get("teste", {})
		var recuo: float = float(tp.get("recuo", 5.0))
		var lmax: float = float(tp.get("lado", 0.35))
		for ang in tp.get("angulos", [-40.0, 0.0, 40.0]):
			for desl in [-lmax, 0.0, lmax]:
				for correr in [false, true]:
					var dd := dir.rotated(deg_to_rad(ang))
					# ponto de partida: 5 m antes da borda, deslocado de lado; ajusta para celula andavel
					var de: Vector2 = borda - dd * recuo + lado * (desl * minf(d.tam.x, 6.0))
					if not a.andavel(Vector3(de.x, 0, de.y)):
						de = borda - dir * recuo
					var r := await caminhar_sinal(a, de, dd, correr)
					check(r == String(d.area), "%s -> %s: angulo %+d, lado %+.2f, %s (%s)" % [area, d.area, int(ang), desl, "correndo" if correr else "andando", r if r != "" else "nao disparou"])

func run() -> void:
	OS.set_environment("ILHA_SAVE", "user://transicoes_teste.json")
	OS.set_environment("HORIZONTE", "0")
	if FileAccess.file_exists("user://transicoes_teste.json"):
		DirAccess.remove_absolute("user://transicoes_teste.json")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	check(await esperar("fazenda"), "inicia na fazenda")
	# ---------------- FAZENDA
	var f = jogo.atual
	check(saidas_de(f) != null and saidas_de(f).defs.size() == C.FAZENDA_SAIDAS.size(), "fazenda: portoes montados")
	for d in C.FAZENDA_SAIDAS:
		var s: Dictionary = d
		check(s.tam.x >= 4.0, "fazenda: portao %s cobre a largura do corredor (%.1f m)" % [s.area, s.tam.x])
	await matriz("fazenda", C.FAZENDA_SAIDAS)
	# dentro de casa a saida nao dispara
	if f.interiores:
		var s = saidas_de(f)
		check(s.bloqueio.is_valid(), "fazenda: saida tem bloqueio para interiores")
	# troca REAL: correndo do spawn inicial ate a vila pela trilha leste (sem teleporte perto da saida)
	var r := await caminhar(f, Vector2(36.0, -11.0), Vector2(1, 0), true, "fazenda")
	check(r.trocou, "fazenda -> vila correndo pelo corredor leste (%d quadros)" % r.q)
	check(await esperar("vila"), "chegou na vila")
	# ---------------- VILA
	var v = jogo.atual
	for i in 60:
		await physics_frame
	check(jogo.nome == "vila", "vila: nascer em da_fazenda nao dispara saida (rearme)")
	check(saidas_de(v) != null and saidas_de(v).defs.size() == C.VILA_SAIDAS.size(), "vila: portoes montados")
	await matriz("vila", C.VILA_SAIDAS)
	# a placa nao fica mais no meio da trilha sul: do spawn da_fazenda anda reto ate o portao
	r = await caminhar(v, Vector2(0.0, 16.0), Vector2(0, 1), false, "vila")
	check(r.trocou, "vila -> fazenda andando reto do spawn (sem placa no caminho) (%d quadros)" % r.q)
	check(await esperar("fazenda"), "voltou para a fazenda")
	for i in 60:
		await physics_frame
	check(jogo.nome == "fazenda", "fazenda: nascer em da_vila nao dispara saida (rearme)")
	# fazenda -> vila diagonal correndo
	f = jogo.atual
	r = await caminhar(f, Vector2(39.0, -12.2), Vector2(1, 0.25), true, "fazenda")
	check(r.trocou, "fazenda -> vila diagonal correndo (%d quadros)" % r.q)
	await esperar("vila")
	v = jogo.atual
	for i in 10:
		await physics_frame
	# vila -> arena (real), diagonal, correndo, deslocado do centro do portao
	r = await caminhar(v, Vector2(16.0, -1.0), Vector2(1, -0.3), true, "vila")
	check(r.trocou, "vila -> arena diagonal correndo (%d quadros)" % r.q)
	check(await esperar("arena"), "chegou na arena")
	# ---------------- ARENA (portao oeste so fora do combate)
	var ar = jogo.atual
	ar.modo_teste = true
	var sa = ar.get_node_or_null("SaidaIlha")
	var gate = null
	for n in ar.get_children():
		if n.name == "SaidasArea":
			gate = n
	check(gate != null, "arena: portao oeste montado")
	if gate:
		ar.estado_sala = "combate"
		gate.armado = true
		ar.jogador.position = Vector3(-10.3, 0, 3.5)
		for i in 20:
			await physics_frame
		check(jogo.nome == "arena" and not jogo.ocupado, "arena: em combate o portao nao tira o jogador")
		ar.estado_sala = "limpa"
		ar.jogador.position = Vector3(-6.0, 0, 3.0)
		for i in 10:
			await physics_frame
		# varredura: um passo que atravessa um portao fino inteiro (ponta antes e depois) ainda conta
		var fino := {"centro": Vector2(0, 0), "tam": Vector2(4, 0.3), "dir": Vector2(1, 0)}
		check(not gate.dentro(fino, Vector2(-0.6, 0)) and not gate.dentro(fino, Vector2(0.6, 0)) and gate._varre(fino, Vector2(-0.6, 0), Vector2(0.6, 0)), "varredura do passo pega portao atravessado num quadro so (esquiva/corrida)")
		var ok := false
		for i in 40:
			ar.jogador.position.x = maxf(ar.jogador.position.x - 0.15, -10.9)
			await physics_frame
			if jogo.ocupado or jogo.nome != "arena":
				ok = true
				break
		check(ok, "arena -> vila pelo portao oeste (varredura pega passo rapido)")
		check(await esperar("vila"), "voltou para a vila (da_arena)")
	# ---------------- VILA -> MASMORRA (real) e volta
	v = jogo.atual
	for i in 10:
		await physics_frame
	r = await caminhar(v, Vector2(-7.4, -16.5), Vector2(0.15, -1), true, "vila")
	check(r.trocou, "vila -> masmorra pelo portao das ruinas, pela borda do corredor, correndo (%d quadros)" % r.q)
	check(await esperar("masmorra"), "chegou na masmorra")
	var m = jogo.atual
	for i in 20:
		await physics_frame
	# portal azul (raio maior): pisa a 1,2 m do centro
	m.player.position = m.portal + Vector3(1.2, 0.5, 0)
	var ok2 := false
	for i in 30:
		await physics_frame
		if jogo.ocupado or jogo.nome != "masmorra":
			ok2 = true
			break
	check(ok2, "masmorra -> vila pelo portal (raio 1,5 m)")
	check(await esperar("vila"), "voltou para a vila (da_masmorra)")
	for i in 60:
		await physics_frame
	check(jogo.nome == "vila", "vila: nascer em da_masmorra nao dispara o portao de novo")
	# ---------------- mapa
	jogo.alternar_mapa()
	check(jogo.mapa_camada.visible and jogo.mapa_img.texture != null, "mapa abre com a imagem nova")
	check(jogo.mapa_marca.text.find("Vila") >= 0, "mapa: marcador mostra a area atual (%s)" % jogo.mapa_marca.text)
	jogo.alternar_mapa()
	print("--- transicoes: %d/%d verificacoes ---" % [checks - failures, checks])
	for x in log_falhas:
		print("  - ", x)
	quit(0 if failures == 0 else 1)
