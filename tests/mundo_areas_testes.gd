extends SceneTree
## Registro de areas + mapa-mundi + teleporte: entra e sai de cada area disponivel pelo mapa (viajar),
## confere a pedra de viagem no ponto de chegada, o modo viagem (T perto da pedra) e as areas "em breve".
## Save de teste (user://ilha_mundo_teste.json); o save real nao e tocado.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const SAVE := "user://ilha_mundo_teste.json"
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

func esperar_area(id: String, limite := 600) -> bool:
	for i in limite:
		await process_frame
		if jogo.nome == id and not jogo.ocupado and jogo.atual != null:
			return true
	return false

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

func _run() -> void:
	create_timer(1800.0).timeout.connect(func():
		print("FAIL tempo esgotado")
		quit(2))
	# ------------------------------------------------ registro
	var ids: Array = Registro.ids()
	check(ids.size() >= 9 and ids.has("porto_velho") and ids.has("vila_orcs") and ids.has("cidade_fantasma") and ids.has("minas_da_cinza") and ids.has("estacao_depois_de_ontem") and ids.has("criptas_de_cinzalta") and ids.has("fenda_cronal"), "registro com todas as areas (%d)" % ids.size())
	var unicos := {}
	var campos := true
	for a in Registro.lista():
		unicos[String(a.id)] = true
		campos = campos and a.has("nome") and a.has("cena") and a.has("chegada") and a.has("mapa") and a.has("raio")
	check(unicos.size() == ids.size() and campos, "ids unicos e campos obrigatorios")
	var disp: Array = Registro.disponiveis()
	check(disp.has("fazenda") and disp.has("vila") and disp.has("arena") and disp.has("masmorra"), "areas jogaveis hoje disponiveis (%s)" % str(disp))
	var pj = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/mapa_mundi_pintado.json"))
	var no_mapa := pj is Dictionary
	for id in ids:
		no_mapa = no_mapa and (pj as Dictionary).has(id)
	check(no_mapa and FileAccess.file_exists("res://art/ui/mapa_mundi_pintado.png"), "mapa pintado tem todas as areas do registro")
	check(FileAccess.file_exists("res://art/ui/mapa_esquematico.png"), "mapa esquematico original preservado")
	# ------------------------------------------------ jogo
	var v_ilha := FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	check(await esperar_area("fazenda"), "comeca na fazenda")
	await fr(3)
	check(jogo.pedra != null and is_instance_valid(jogo.pedra), "fazenda: pedra de viagem no ponto de chegada")
	# mapa aberto: botoes por area, em breve desligado
	jogo.alternar_mapa()
	await fr(2)
	check(jogo.mapa_camada.visible and jogo.mapa_botoes.get_child_count() == ids.size(), "mapa (M) com um ponto por area (%d)" % jogo.mapa_botoes.get_child_count())
	var b_futuro = jogo.mapa_botoes.get_node_or_null("Area_estacao_depois_de_ontem")
	check(b_futuro != null and (b_futuro.disabled or Registro.disponivel("estacao_depois_de_ontem")), "area sem cena aparece desligada (em breve)")
	check(not jogo.viajar("estacao_depois_de_ontem") or Registro.disponivel("estacao_depois_de_ontem"), "viajar para area sem cena e recusado")
	# integracao 20/10: Ilha da Mare do Tempo (Claude, d0914dd), segunda ilha, em breve (sem cena ainda)
	var info_mare: Dictionary = Registro.info("ilha_mare")
	check(not info_mare.is_empty() and String(info_mare.get("ilha", "")) == "ilha_mare_do_tempo" and String(info_mare.get("requer", "")) == "tabua_das_mares", "ilha_mare no registro: segunda ilha, requer a Tabua das Mares")
	var primeira := true
	for a in Registro.lista():
		if String(a.id) != "ilha_mare":
			primeira = primeira and String(a.get("ilha", "")) == "primeira_ilha"
	check(primeira, "todas as outras areas continuam na primeira ilha")
	var b_mare = jogo.mapa_botoes.get_node_or_null("Area_ilha_mare")
	check(b_mare != null and (b_mare.disabled or Registro.disponivel("ilha_mare")), "ilha_mare aparece no mapa (em breve enquanto nao tiver cena)")
	check(Registro.disponivel("ilha_mare") or not jogo.viajar("ilha_mare"), "viajar para a ilha_mare sem cena e recusado, sem travar")
	check(await esperar_area("fazenda"), "depois da recusa continua na fazenda")
	jogo.alternar_mapa()
	await fr(2)
	# integracao 20/10: areas com "requer" pedem os mapas do cartografo; o teste ja os da (save de teste)
	check(Registro.bloqueio("vila_orcs", jogo.estado) == "", "viagens livres: dispensa mapa do cartografo")
	check(Registro.bloqueio("criptas_de_cinzalta", jogo.estado) == "", "viagens livres: dispensa visita previa a Cidade Fantasma")
	for it in ["mapa_vila_orcs", "mapa_cidade_fantasma", "mapa_minas", "bussola_temporal"]:
		jogo.estado.somar(it, 1)
	# entra e sai de cada area disponivel
	var anterior := "fazenda"
	for id in disp:
		if id == "fazenda":
			continue
		var ok_ida: bool = jogo.viajar(id)
		var chegou: bool = await esperar_area(id)
		await fr(4)
		var j = jogo._jogador_atual()
		var pedra_ok: bool = jogo.pedra != null and is_instance_valid(jogo.pedra) and j != null and jogo.pedra.global_position.distance_to(j.global_position) < 3.5
		check(ok_ida and chegou and pedra_ok, "%s -> %s pelo mapa: chegou, pedra de viagem perto da chegada" % [anterior, id])
		# volta ao mapa pela pedra: T perto dela abre o modo viagem
		if j != null and jogo.pedra:
			j.global_position = jogo.pedra.global_position + Vector3(0.6, 0.4, 0.0)
			await fr(3)
			await tecla(KEY_T)
			await fr(2)
			check(jogo.mapa_camada.visible and jogo.mapa_viagem, "%s: T na pedra abre o mapa no modo viagem" % id)
			if jogo.mapa_camada.visible:
				jogo.alternar_mapa()
				await fr(2)
		anterior = id
	# volta para a fazenda pelo teclado do mapa (setas + Enter)
	jogo.alternar_mapa()
	await fr(2)
	jogo.mapa_sel = Registro.ids().find("fazenda")
	await tecla(KEY_ENTER)
	check(await esperar_area("fazenda"), "%s -> fazenda pelo mapa (Enter)" % anterior)
	check(not jogo.mapa_camada.visible, "mapa fecha ao viajar")
	check((FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else "") == v_ilha, "save real intacto")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO mundo_areas: %d/%d" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
