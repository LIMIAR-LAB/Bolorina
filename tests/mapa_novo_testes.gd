extends SceneTree
## Adaptador dos mapas novos (etapa 2): com um mapa de teste no formato da Bolorina (capsula SubstituirPeloSpriteDaVale,
## marcadores npc_<id> e minerio_*), a Vale unica entra no lugar da capsula, anda com WASD, colide com as paredes,
## conversa com E e a viagem entra/sai pelo mapa-mundi. Quando os mapas reais chegarem, este teste vale para eles.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const SAVE := "user://ilha_mapanovo_teste.json"
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

func tecla(k: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = apertada
	Input.parse_input_event(ev)

func _run() -> void:
	create_timer(300.0).timeout.connect(func():
		print("FAIL tempo esgotado")
		quit(2))
	check(not Registro.ids().has("teste_mapa_novo") and Registro.disponivel("teste_mapa_novo"), "area de teste oculta do mapa, mas carregavel")
	var v_ilha := FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await esperar_area("fazenda")
	jogo.viajar("teste_mapa_novo")
	check(await esperar_area("teste_mapa_novo"), "viaja para o mapa novo (adaptador)")
	await fr(10)
	var a = jogo.atual
	check(a.get("mapa") != null and a.mapa.find_child("SubstituirPeloSpriteDaVale", true, false) == null, "capsula substituida")
	check(a.player != null and a.sprite != null and String(a.sprite.role) == "vale_unica", "Vale unica no mapa (%s)" % (a.sprite.role if a.sprite else "?"))
	check(a.player.global_position.distance_to(Vector3(0, 0.2, 0)) < 1.0, "Vale nasce no lugar da capsula")
	check(jogo.pedra != null, "pedra de viagem no mapa novo")
	var mins = a.get_node_or_null("MineriosArea")
	check(mins != null and mins.nos.size() == 1 and String(mins.nos[0].metal) == "ferro", "minerio pelo marcador minerio_ferro_1")
	check(a.area_npcs != null and a.area_npcs.npcs.size() >= 20, "NPCs do roster no mapa novo")
	var ih: int = a.area_npcs.npc_por_id("helena")
	check(ih >= 0 and a.area_npcs.npcs[ih].no.global_position.distance_to(Vector3(-2, 0, 1)) < 0.2, "Helena no marcador npc_helena")
	# D = direita da tela = (cos 50°, 0, -sin 50°) no mundo; a parede (2x3x2) fica a ~4 m nessa direcao
	var x0: float = a.player.global_position.x
	tecla(KEY_D, true)
	for i in 120:
		await physics_frame
	tecla(KEY_D, false)
	var x1: float = a.player.global_position.x
	check(x1 > x0 + 0.5, "WASD move a Vale (x %.2f -> %.2f)" % [x0, x1])
	# parede: x 1,6..3,6, z -4,1..-2,1; a Vale (raio 0,3) bate na face +z e escorrega por ela, sem atravessar
	var z1: float = a.player.global_position.z
	var dentro := x1 > 1.35 and x1 < 3.85 and z1 > -4.35 and z1 < -1.85
	check(not dentro and z1 > -2.0, "colide com a parede do mapa e escorrega pela face (x %.2f z %.2f)" % [x1, z1])
	check(a.player.global_position.y > -0.5 and a.player.global_position.y < 0.6, "fica no chao do mapa (y %.2f)" % a.player.global_position.y)
	# E conversa
	a.player.global_position = Vector3(-1.2, 0.2, 1.0)
	await fr(3)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.keycode = KEY_E
	ev.pressed = true
	root.push_input(ev)
	await fr(3)
	check(a.area_npcs.falando == ih and a.area_npcs.painel.visible, "E conversa com a Helena")
	a.area_npcs.fechar()
	jogo.viajar("vila")
	check(await esperar_area("vila"), "sai do mapa novo para a vila pelo mapa-mundi")
	check((FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else "") == v_ilha, "save real intacto")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO mapa_novo: %d/%d" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
