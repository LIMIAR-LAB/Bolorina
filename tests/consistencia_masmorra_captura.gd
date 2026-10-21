extends SceneTree
## Bolorina 21/10: capturas das salas decoradas da masmorra (acampamento, jaulas, guerra, chefe) e
## de um combate com os orcs em sprite. Uso (com janela): godot --path . -s res://tests/consistencia_masmorra_captura.gd -- <pasta> <tema> <andar> [frames_filme]
var pasta := "/tmp/cons"
var tema := "minas_da_cinza"
var andar := "1"
var filme := 0
var n_quadro := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: pasta = a[0]
	if a.size() > 1: tema = a[1]
	if a.size() > 2: andar = a[2]
	if a.size() > 3: filme = int(a[3])
	DirAccess.make_dir_recursive_absolute(pasta)
	OS.set_environment("ILHA_SEM_MUSICA", "1")
	OS.set_environment("DUNGEON_TEMA", tema)
	OS.set_environment("DUNGEON_ANDAR", andar)
	if OS.get_environment("DUNGEON_SEMENTE") == "": OS.set_environment("DUNGEON_SEMENTE", "4242")
	OS.set_environment("DUNGEON_TESTE", "1")
	call_deferred("run")
func fis(n: int) -> void:
	for i in n: await physics_frame
func salvar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
	print("CAPTURA ", nome)
func quadro() -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(pasta.path_join("f_%05d.png" % n_quadro))
	n_quadro += 1
func run() -> void:
	root.size = Vector2i(1600, 900)
	var m = load("res://scenes/dungeon/%s.tscn" % tema).instantiate()
	root.add_child(m)
	for i in 10: await process_frame
	var j = m.jogador
	j.invulneravel_ate = 1e9
	var info: Dictionary = m.get_meta("decoracao_bolorina", {}).get("salas", {})
	var mapa = m.get_world_3d().navigation_map
	var alvos: Array = []
	for papel in ["acampamento", "jaulas", "guerra", "chefe"]:
		if info.has("centro_" + papel): alvos.append([papel, info["centro_" + papel]])
	var vivos: Array = m.combate.vivos()
	if not vivos.is_empty():
		alvos.append(["combate", vivos[0].global_position])
	for a in alvos:
		var p: Vector3 = a[1]
		var q: Vector3 = NavigationServer3D.map_get_closest_point(mapa, p + Vector3(1.5, 0, 1.5))
		j.global_position = Vector3(q.x, 0, q.z)
		if a[0] == "combate":
			for e in m.combate.vivos():
				if e.global_position.distance_to(p) < 9.0: e.acordar()
		var n := 40 if filme == 0 else filme
		for i in n:
			await physics_frame
			if a[0] == "combate" and i == 30 and is_instance_valid(vivos[0]): j.pedir_ataque(vivos[0].global_position - j.global_position)
			if filme > 0:
				m._mirar(Vector3(j.global_position.x, 0, j.global_position.z) + Vector3(sin(i * 0.03), 0, cos(i * 0.03)) * 0.6, m.TAM_CAMERA_COMBATE)
				await quadro()
		if filme == 0:
			m._mirar(Vector3((p.x + j.global_position.x) * 0.5, 0, (p.z + j.global_position.z) * 0.5), m.TAM_CAMERA_COMBATE)
			await process_frame
			await salvar("%s_andar_%s_%s" % [tema, andar.pad_zeros(2), a[0]])
	quit(0)
