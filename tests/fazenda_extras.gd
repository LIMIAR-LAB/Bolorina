extends SceneTree
## Fazenda: energia (ferramentas gastam, dormir restaura), pesca no lago (lancar -> "!" -> puxar),
## galinhas (racao no cocho, carinho/afeto, ovos no dia seguinte, coleta), arvores fora da vista
## do canteiro, slot 0 = vara. FAZ_CAP=1 grava docs/fazenda-{pesca,animais,energia,canteiro-vista}.png
var checks := 0
var failures := 0
var f
func check(ok: bool, t: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + t)

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func por(c: Vector2, olhar: Vector3) -> void:
	f.player.position = Vector3(c.x, f.vila.altura(c.x, c.y) + 0.4, c.y)
	f.player.velocity = Vector3.ZERO
	f.facing = olhar
	f.ui.mouse_t = -100.0

func usar(slot: int) -> String:
	f.estado.slot = slot
	f.ui.cd = 0.0
	f.ui.usar()
	await fr(2)
	return String(f.message.text)

func foto(nome: String, alvo: Vector3, tam: float) -> void:
	if OS.get_environment("FAZ_CAP") != "1":
		return
	f.camera_travada = true
	f.vila.cam_alvo = Vector3(alvo.x, 0, alvo.z)
	f.vila.cam_size = tam
	f.apply_camera()
	await fr(4)
	var img: Image = f.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % nome))
	print("INFO captura docs/%s.png" % nome)
	f.camera_travada = false

func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_extras_teste.json")
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	if FileAccess.file_exists("user://ilha_extras_teste.json"):
		DirAccess.remove_absolute("user://ilha_extras_teste.json")
	var v1 := FileAccess.get_md5("user://island_v1.json") if FileAccess.file_exists("user://island_v1.json") else ""
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 150:
		await process_frame
		if jogo.atual and jogo.atual.get("ui") != null and jogo.atual.ui != null and jogo.atual.get("pesca") != null:
			break
	f = jogo.atual
	await create_timer(0.8).timeout
	var e = f.estado
	# ---------- barra e slot 0
	check(f.ui.SLOTS.size() == 10 and String(f.ui.SLOTS[9].id) == "vara", "10 slots, slot 0 = vara de pesca")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_0
	ev.pressed = true
	f.ui.entrada(ev)
	check(f.ui.item() == "vara", "tecla 0 seleciona a vara")
	check(f.ui.energia_barra != null and f.ui.dia_label.text.begins_with("DIA %d" % e.dia), "painel de dia + energia (%s)" % f.ui.dia_label.text)
	# ---------- energia
	var alvo := Vector2i(-6, 2)
	for z in range(0, 8):
		for x in range(-10, 2):
			if f.ui.aravel(Vector2i(x, z)) and f.ui.aravel(Vector2i(x + 1, z)):
				alvo = Vector2i(x + 1, z)
				break
		if f.ui.aravel(alvo):
			break
	var e0: int = e.energia
	por(Vector2(alvo.x - 1, alvo.y), Vector3(1, 0, 0))
	await usar(0)
	check(f.solo.tem(alvo) and e.energia == e0 - 4, "enxada gasta 4 de energia (%d -> %d)" % [e0, e.energia])
	f.ui.atualizar()
	var w_cheia: float = f.ui.energia_barra.size.x
	e.energia = 3
	f.ui.atualizar()
	check(f.ui.energia_barra.size.x < w_cheia * 0.1, "barra encolhe com pouca energia")
	var alvo2 := alvo + Vector2i(0, 1)
	por(Vector2(alvo2.x - 1, alvo2.y), Vector3(1, 0, 0))
	var msg: String = await usar(0)
	check(not f.solo.tem(alvo2) and msg.begins_with("Cansada"), "sem energia: nao ara (%s)" % msg)
	await foto("fazenda-energia", Vector3(alvo.x, 0, alvo.y), 9.0)
	f._dormir()
	check(e.energia == e.ENERGIA_MAX, "dormir (F9) restaura a energia")
	# ---------- pesca
	var margem := Vector2i(999, 999)
	var cz := 0
	for z in range(-30, 31):
		for x in range(-30, 31):
			if f.vila.altura(float(x), float(z)) < -0.3 and f.vila.altura(float(x + 1), float(z)) > -0.15 and f.vila.altura(float(x + 2), float(z)) > -0.15:
				margem = Vector2i(x + 1, z)
				cz = z
				break
		if margem.x != 999:
			break
	check(f.vila.altura(float(margem.x - 1), float(cz)) < -0.3, "margem do lago achada %s" % str(margem))
	por(Vector2(margem.x, margem.y), Vector3(-1, 0, 0))
	await fr(3)
	check(f.ui.pode_usar("vara", f.ui.calcular_alvo()), "vara pode ser usada na agua")
	e0 = e.energia
	msg = await usar(9)
	check(f.pesca.ativa() and e.energia == e0 - 6, "lancou a linha (-6 energia): %s" % msg)
	msg = await usar(9)
	check(not f.pesca.ativa() and msg.contains("cedo"), "puxar antes do '!' nao pega nada")
	var peixes0: int = e.qtd("peixe_carpa") + e.qtd("peixe_tilapia") + e.qtd("peixe_dourado")
	await usar(9)
	var guarda := 0
	while f.pesca.estado_pesca == "esperando" and guarda < 400:
		await process_frame
		guarda += 1
	check(f.pesca.estado_pesca == "fisgou" and f.pesca.aviso.visible, "peixe mordeu: '!' aparece")
	await foto("fazenda-pesca", Vector3(margem.x - 1, 0, margem.y), 7.0)
	if f.pesca.estado_pesca != "fisgou":
		while f.pesca.estado_pesca == "esperando":
			await process_frame
	msg = await usar(9)
	var peixes1: int = e.qtd("peixe_carpa") + e.qtd("peixe_tilapia") + e.qtd("peixe_dourado")
	check(peixes1 == peixes0 + 1, "puxou na hora: pescou (%s)" % msg)
	await usar(9)
	while f.pesca.estado_pesca == "esperando":
		await process_frame
	await create_timer(1.1).timeout
	check(not f.pesca.ativa() and String(f.message.text).contains("escapou"), "demorou demais: o peixe escapa")
	var cont := {}
	for i in 400:
		cont[f.pesca.sortear()] = int(cont.get(f.pesca.sortear(), 0)) + 1
	check(cont.size() == 3, "3 especies sorteaveis %s" % str(cont.keys()))
	# ---------- galinhas
	var gal = f.galinheiro
	e.itens["racao"] = 10
	var cocho: Vector3 = gal.cocho.position
	por(Vector2(cocho.x, cocho.z + 1.0), Vector3(0, 0, -1))
	check(gal.tecla_e() and e.qtd("racao") == 5 and gal.cocho_racao.visible, "E no cocho: 5 galinhas comem (racao 10 -> %d)" % e.qtd("racao"))
	gal.tecla_e()
	check(e.qtd("racao") == 5, "nao gasta racao duas vezes no mesmo dia")
	var g0: Node3D = gal.galinhas[0].no
	por(Vector2(g0.position.x + 0.5, g0.position.z), Vector3(-1, 0, 0))
	gal.galinhas[0].pausa = 5.0
	var af0: int = int(e.animais.afeto[0])
	gal.carinho(0)
	check(int(e.animais.afeto[0]) == af0 + 1 and gal.coracoes.size() > 0, "carinho: afeto +1 e coracao")
	gal.carinho(0)
	check(int(e.animais.afeto[0]) == af0 + 1, "carinho so 1x por dia")
	await foto("fazenda-animais-cuidado", Vector3(15, 0, -17), 8.0)
	f._dormir()
	await fr(2)
	check(int(e.animais.ovos) >= 1 and gal.ovos_nos.size() == int(e.animais.ovos), "dia seguinte: %d ovo(s) no galinheiro" % int(e.animais.ovos))
	check(not gal.cocho_racao.visible, "cocho vazio no novo dia")
	# alimenta de novo e carinho para a foto
	por(Vector2(cocho.x, cocho.z + 1.0), Vector3(0, 0, -1))
	gal.tecla_e()
	gal.carinho(1)
	await foto("fazenda-animais", Vector3(14.5, 0, -17.5), 7.5)
	var ovo: Node3D = gal.ovos_nos[0] if gal.ovos_nos.size() > 0 else null
	var ovos_antes: int = e.qtd("ovo")
	var n_ovos: int = int(e.animais.ovos)
	if ovo:
		por(Vector2(ovo.position.x, ovo.position.z + 0.5), Vector3(0, 0, -1))
		gal.tecla_e()
	check(e.qtd("ovo") == ovos_antes + n_ovos and gal.ovos_nos.is_empty(), "E nos ovos: coletou %d" % n_ovos)
	var ouro0: int = e.ouro
	var ganho: int = e.vender_colheita()
	check(ganho >= n_ovos * e.PRECO_OVO + 30 and e.ouro == ouro0 + ganho, "caixa vende ovos e peixe (+%d)" % ganho)
	# ---------- arvores fora da vista do canteiro
	var bloq := 0
	for c in [Vector2i(2, -2), Vector2i(-7, -3), Vector2i(8, -2)]:
		if f.detritos.em(c) and f.detritos.tipo(c) == "arvore":
			bloq += 1
	check(bloq == 0, "arvores que tapavam o canteiro foram movidas")
	f.player.position = Vector3(-6, f.vila.altura(-6, -12) + 0.4, -12)
	await create_timer(0.3).timeout
	await foto("fazenda-canteiro-vista", Vector3(-3, 0, -9), 14.0)
	# ---------- save
	check(e.salvar(), "salvou")
	var e2 = load("res://scripts/ilha/fazenda_estado.gd").new()
	e2.arquivo = "user://ilha_extras_teste.json"
	check(e2.carregar() and int(e2.animais.afeto[0]) == af0 + 1 and e2.energia == e.energia, "save guarda energia e animais")
	var v2 := FileAccess.get_md5("user://island_v1.json") if FileAccess.file_exists("user://island_v1.json") else ""
	check(v1 == v2, "island_v1.json intacto")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
