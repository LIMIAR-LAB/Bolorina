extends SceneTree
## Horizonte vivo: clima por dia (estavel), fundo em CANVAS liga/desliga e restaura o ceu antigo,
## ilhas derivam e mudam por dia, aurora 3D liga por clima/tecla. HZ_CAP=1 grava capturas em docs/.
var checks := 0
var failures := 0
var jogo
var v
var hz
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + text)
func _init() -> void:
	call_deferred("_run")
func fr(n: int) -> void:
	for i in n:
		await process_frame
func foto(nome: String) -> void:
	if OS.get_environment("HZ_CAP") != "1":
		return
	await fr(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % nome))
	print("INFO captura docs/%s.png" % nome)

func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_horizonte_teste.json")
	OS.set_environment("ILHA_AREA", "vila")
	OS.set_environment("ILHA_SPAWN", "da_masmorra")
	if FileAccess.file_exists("user://ilha_horizonte_teste.json"):
		DirAccess.remove_absolute("user://ilha_horizonte_teste.json")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 200:
		await process_frame
		if jogo.atual and jogo.atual.get("horizonte") != null and jogo.atual.horizonte != null:
			break
	v = jogo.atual
	hz = v.horizonte
	await create_timer(1.0).timeout
	v.message.text = ""
	# enquadramento com bastante ceu (borda norte/ruinas, como na captura do usuario)
	v.camera_travada = true
	v.vila.cam_alvo = Vector3(-8, 0, -20)
	v.vila.cam_size = 24.0
	v.apply_camera()
	var env: Environment = v.atmosphere.settings
	check(hz.clima_do_dia(1) == "ensolarado" and hz.clima_do_dia(6) == "ensolarado" and hz.clima_do_dia(5) == "aurora", "clima = dia %% 5 (estavel)")
	var nomes := {}
	for d in range(1, 6):
		nomes[hz.clima_do_dia(d)] = true
	check(nomes.size() == 5, "5 climas na rotacao %s" % str(nomes.keys()))
	check(env.background_mode == Environment.BG_CANVAS and hz.camada.visible, "fundo do Environment em CANVAS (horizonte vivo ligado)")
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "luz ambiente da cena nao muda (cor)")
	check(hz.base.texture != null and hz.ilhas.size() == 3 and hz.ilhas[0].no.texture != null, "camadas carregadas (base + 3 ilhas)")
	# antes / depois
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_K
	ev.pressed = true
	hz.tecla(ev)
	await fr(3)
	check(env.background_mode == Environment.BG_SKY and not hz.camada.visible, "K desliga: volta ao ceu antigo (BG_SKY)")
	var nev_ok: bool = hz.nevoa_orig.size() == 4
	for par in hz.nevoa_orig:
		if par[0].get_shader_parameter("cor") != par[1]: nev_ok = false
	check(nev_ok, "K desliga: nevoa do abismo volta ao original (4 planos)")
	await foto("horizonte-antes")
	hz.tecla(ev)
	await fr(3)
	check(env.background_mode == Environment.BG_CANVAS, "K liga de novo")
	var a0: float = hz.nevoa_orig[0][1].a
	check(absf(hz.nevoa_orig[0][0].get_shader_parameter("cor").a - a0 * hz.NEVOA_FATOR) < 0.01, "ligado: nevoa afinada (alfa %.2f -> %.2f)" % [a0, a0 * hz.NEVOA_FATOR])
	jogo.estado.dia = 1
	await fr(3)
	check(hz.clima == "ensolarado", "dia 1: ensolarado")
	var x0: float = hz.ilhas[0].no.position.x
	await create_timer(1.5).timeout
	check(absf(hz.ilhas[0].no.position.x - x0) > 0.05, "ilhas derivam (%.1f -> %.1f px)" % [x0, hz.ilhas[0].no.position.x])
	await foto("horizonte-depois")
	await foto("horizonte-dia-1-ensolarado")
	var y1: float = hz.ilhas[0].y
	jogo.estado.dia = 2
	await fr(3)
	check(hz.clima == "nublado" and hz.ilhas[0].y != y1, "dia 2: nublado, ilhas em outro lugar")
	await foto("horizonte-dia-2-nublado")
	jogo.estado.dia = 3
	await fr(3)
	check(hz.clima == "chuva_leve", "dia 3: chuva leve")
	await foto("horizonte-dia-3-chuva")
	jogo.estado.dia = 4
	await fr(3)
	check(hz.clima == "por_do_sol", "dia 4: por do sol")
	await foto("horizonte-dia-4-por-do-sol")
	# aurora 3D
	jogo.estado.dia = 5
	await fr(3)
	check(hz.clima == "aurora", "dia 5: aurora")
	var u := InputEventKey.new()
	u.physical_keycode = KEY_U
	u.pressed = true
	hz.tecla(u)
	hz.tecla(u)   # auto -> ligada -> desligada
	await create_timer(2.5).timeout
	check(not hz.aurora.visible, "U: aurora desligada")
	await foto("aurora-efeito-off")
	hz.tecla(u)   # -> automatica
	hz.aurora_f = hz.aurora_alvo()
	await fr(3)
	check(hz.aurora.visible and hz.aurora.get_parent() is Camera3D, "aurora 3D presa a camera, visivel no dia de aurora")
	await foto("aurora-efeito-on")
	v.atmosphere.transition_active = false
	v.atmosphere.set_hour(20.6)
	hz.aurora_f = hz.aurora_alvo()
	await create_timer(0.6).timeout
	check(hz._noite() > 0.9, "noite pelo relogio")
	await foto("aurora-efeito-noite")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
