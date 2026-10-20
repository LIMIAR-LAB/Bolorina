extends SceneTree
## Fazenda grande (variante): abre pelo registro, area andavel maior que a original, canteiros iniciais arados,
## pomar/celeiro/pasto no layout, caminho ate Porto Velho funciona (portao do sudeste) e a fazenda original nao mudou.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const SAVE := "user://ilha_fazgrande_teste.json"
var checks := 0
var failures := 0
var jogo

func check(ok: bool, t: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + t)

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func esperar_area(id: String) -> bool:
	for i in 900:
		await process_frame
		if jogo.nome == id and not jogo.ocupado and jogo.atual != null:
			return true
	return false

func _run() -> void:
	create_timer(400.0).timeout.connect(func():
		print("FAIL tempo esgotado")
		quit(2))
	var orig = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/ilha/fazenda_layout.json"))
	var grande = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/ilha/fazenda_grande_layout.json"))
	check(orig.versao == "fazenda_v1" and grande.versao == "fazenda_grande_v1", "layout original intacto + variante grande")
	check(Registro.disponivel("fazenda_grande") and Registro.disponivel("fazenda"), "as duas fazendas no registro")
	var fg: Dictionary = grande.fazenda
	check(fg.canteiro_inicial.size() >= orig.fazenda.canteiro_inicial.size() * 4 and fg.pomar.size() >= 12 and fg.has("celeiro") and fg.has("animais"), "mais canteiros (%d), pomar (%d), celeiro e pasto" % [fg.canteiro_inicial.size(), fg.pomar.size()])
	var v_ilha := FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	check(await esperar_area("fazenda"), "fazenda original abre")
	await fr(3)
	var n_orig: int = jogo.atual.cells.size()
	jogo.viajar("fazenda_grande")
	check(await esperar_area("fazenda_grande"), "fazenda -> fazenda grande pelo mapa")
	await fr(5)
	var f = jogo.atual
	var n_grande: int = f.cells.size()
	check(n_grande > n_orig * 1.5, "area andavel %d -> %d celulas" % [n_orig, n_grande])
	check(f.cells.has(Vector2i(-35, -10)) and f.cells.has(Vector2i(10, 28)) and f.cells.has(Vector2i(45, 18)), "pomar, pasto e corredor do Porto Velho sao andaveis")
	var aradas := 0
	for c in fg.canteiro_inicial:
		var k := "%d,%d" % [int(c[0]), int(c[1])]
		if jogo.estado.solo.has(k):
			aradas += 1
	check(aradas == fg.canteiro_inicial.size(), "save novo com os %d canteiros ja arados" % aradas)
	check(f.saida_porto != null and jogo.pedra != null, "portao do Porto Velho e pedra de viagem")
	# anda pelo corredor ate o portao do sudeste
	f.player.global_position = Vector3(44.0, f.vila.altura(44.0, 18.0) + 0.4, 18.0)
	await fr(2)
	var chegou := false
	# passos de 0,4 m para leste ate cruzar o portao (x 46,5..50,5)
	for i in 20:
		var x := 44.0 + i * 0.4
		f.player.global_position = Vector3(x, f.vila.altura(x, 18.0) + 0.4, 18.0)
		await physics_frame
		await physics_frame
		if jogo.nome == "porto_velho" or jogo.ocupado:
			chegou = true
			break
	check(chegou and await esperar_area("porto_velho"), "caminho do sudeste leva a Porto Velho")
	check((FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else "") == v_ilha, "save real intacto")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO fazenda_grande: %d/%d" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
