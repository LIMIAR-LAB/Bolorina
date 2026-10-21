extends SceneTree
## Bolorina 21/10: capturas da entrega arte-mundos. Uso (precisa de janela, ex.: xvfb-run):
##   godot --path . -s res://tests/arte_mundos_captura.gd -- <alvo> <pasta>
## alvos: vitrine | mirante_iso | mirante_cine | inicio | area:<id_da_area> | filme_vitrine
var alvo := "vitrine"
var pasta := "/tmp/capturas"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: alvo = a[0]
	if a.size() > 1: pasta = a[1]
	DirAccess.make_dir_recursive_absolute(pasta)
	OS.set_environment("ILHA_SEM_MUSICA", "1")
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await process_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta + "/" + nome + ".png")
	print("CAPTURA ", pasta + "/" + nome + ".png")
func run() -> void:
	create_timer(600).timeout.connect(func(): print("FAIL timeout"); quit(2))
	if alvo == "vitrine" or alvo == "filme_vitrine":
		var cena = load("res://scenes/mirante_cascata/mirante_cascata.tscn").instantiate()
		cena.vitrine = true
		root.add_child(cena)
		await frames(30)
		if alvo == "vitrine":
			await foto("mirante_vitrine")
		else:
			for i in 150:
				await process_frame
				await foto("f_%04d" % i)
	elif alvo.begins_with("mirante"):
		var ad = load("res://scripts/mundo/area_mapa_novo.gd").new()
		root.add_child(ad)
		ad.carregar("res://scenes/mirante_cascata/mirante_cascata.tscn", "mirante_cascata", "")
		await frames(40)
		await foto("mirante_iso")
		ad.player.global_position = ad.mapa.vista.to_global(Vector3(0, 0.3, -6.5))
		await frames(60)
		await foto("mirante_cinematico")
	elif alvo == "inicio":
		var menu = load("res://inicio.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		await frames(45)
		await foto("inicio_titulo")
		var botoes: Array = menu.pagina.find_children("*", "Button", true, false)
		var carregar_b: Button = null
		for b in botoes:
			if b.text == "Carregar jogo": carregar_b = b
		for estado in [true, false]:
			carregar_b.disabled = estado
			carregar_b.get_node("Icone").modulate = Color(0.8, 0.72, 0.64, 0.42) if estado else Color("e8d2ae")
			for i in botoes.size():
				var b: Button = botoes[i]
				if b.disabled: continue
				b.grab_focus(); await frames(14)
				await foto("inicio_foco_%d_%s" % [i, "carregar_apagado" if estado else "carregar_ativo"])
		menu.carregar(); await frames(10); await foto("inicio_carregar")
		menu.configuracoes(); await frames(10); await foto("inicio_configuracoes")
	elif alvo == "filme_titulo":
		var menu = load("res://inicio.tscn").instantiate()
		root.add_child(menu); current_scene = menu
		await frames(20)
		var botoes: Array = menu.pagina.find_children("*", "Button", true, false)
		await gravar(210, func(t):
			var alvo_i := int(t * 4.0) % 4
			if botoes[alvo_i].disabled: alvo_i = 0
			if not botoes[alvo_i].has_focus(): botoes[alvo_i].grab_focus())
	elif alvo == "tour":
		await tour()
	elif alvo.begins_with("cena:"):
		var cena = load(alvo.substr(5)).instantiate()
		root.add_child(cena)
		current_scene = cena
		await frames(60)
		await foto("cena_" + alvo.get_file().get_basename())
	elif alvo.begins_with("area:"):
		var id := alvo.substr(5)
		var Reg = load("res://scripts/mundo/registro_areas.gd")
		var ad = load("res://scripts/mundo/area_mapa_novo.gd").new()
		root.add_child(ad)
		ad.carregar(Reg.cena(id), id, "")
		await frames(40)
		var extras: Array = OS.get_environment("CAPTURA_PONTOS").split(";", false)
		await foto("area_" + id)
		var i := 0
		for p in extras:
			var xz = p.split(",")
			ad.player.global_position = Vector3(float(xz[0]), ad.player.global_position.y + 0.5, float(xz[1]))
			await frames(25)
			await foto("area_%s_%d" % [id, i]); i += 1
	quit(0)

# ---------------------------------------------------------------- tour em video (frames numerados)
var quadro_n := 0
func gravar(n: int, cada := Callable()) -> void:
	for i in n:
		if cada.is_valid(): cada.call(float(i) / float(maxi(n - 1, 1)))
		await process_frame
		await foto("f_%05d" % quadro_n)
		quadro_n += 1
func limpar_cena(no: Node) -> void:
	if is_instance_valid(no): no.queue_free()
	await frames(3)
func area_tour(id: String, de: Vector2, ate: Vector2, n: int) -> void:
	var Reg = load("res://scripts/mundo/registro_areas.gd")
	var ad = load("res://scripts/mundo/area_mapa_novo.gd").new()
	root.add_child(ad)
	ad.carregar(Reg.cena(id), id, "")
	var y: float = ad.player.global_position.y + 0.3
	await frames(20)
	await gravar(n, func(t): ad.player.global_position = Vector3(lerpf(de.x, ate.x, t), y, lerpf(de.y, ate.y, t)))
	await limpar_cena(ad)
func tour() -> void:
	var menu = load("res://inicio.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	await frames(20)
	await gravar(75)
	await limpar_cena(menu)
	var ad = load("res://scripts/mundo/area_mapa_novo.gd").new()
	root.add_child(ad)
	ad.carregar("res://scenes/mirante_cascata/mirante_cascata.tscn", "mirante_cascata", "")
	await frames(20)
	var v: Node3D = ad.mapa.vista
	await gravar(90, func(t): ad.player.global_position = v.to_global(Vector3(sin((lerpf(18.0, -2.0, t) - 11.0) * 0.22) * 1.3, 0.3, lerpf(18.0, -2.0, t))))
	ad.player.global_position = v.to_global(Vector3(0, 0.3, -6.5))
	await gravar(75)
	await limpar_cena(ad)
	await area_tour("estacao_depois_de_ontem", Vector2(0, 26), Vector2(0, 8), 45)
	await area_tour("porto_velho", Vector2(-30, 2), Vector2(-38, -3), 45)
	await area_tour("cidade_fantasma", Vector2(4, -18), Vector2(16, -24), 30)
	var mas = load("res://scenes/dungeon/minas_da_cinza.tscn").instantiate()
	root.add_child(mas); current_scene = mas
	await frames(30)
	await gravar(40)
