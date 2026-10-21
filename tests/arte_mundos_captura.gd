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
			for i in 240:
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
		menu.carregar(); await frames(10); await foto("inicio_carregar")
		menu.configuracoes(); await frames(10); await foto("inicio_configuracoes")
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
