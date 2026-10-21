extends SceneTree
## Bolorina 21/10: musica (autoload Musica), area Mirante da Cascata e props CC0 novos.
var checks := 0
var falhas := 0
func check(ok: bool, nome: String) -> void:
	checks += 1
	if not ok: falhas += 1
	print(("PASS " if ok else "FAIL ") + nome)
func frames(n: int) -> void:
	for i in n: await process_frame
func _init() -> void: call_deferred("run")
func run() -> void:
	create_timer(240).timeout.connect(func(): print("FAIL timeout"); quit(2))
	var Mus = load("res://scripts/audio/musica.gd")
	var d: Dictionary = Mus.carregar_dados()
	for id in ["titulo", "exploracao", "batalha", "vila"]:
		var path := String(d.trilhas.get(id, ""))
		var s = load(path) if ResourceLoader.exists(path) else null
		check(s is AudioStream and s.get_length() > 30.0, "trilha %s carrega (%s)" % [id, path.get_file()])
	var titulo := ["titulo", "exploracao", "batalha"].map(func(i): return String(d.trilhas[i]))
	check(titulo[0] != titulo[1] and titulo[1] != titulo[2] and titulo[0] != titulo[2], "titulo, jogo e batalha sao trilhas diferentes")
	check(Mus.trilha_da_area(d, "arena") == "batalha", "arena -> batalha")
	check(Mus.trilha_da_area(d, "minas_da_cinza") == "batalha", "masmorra -> batalha (categoria)")
	check(Mus.trilha_da_area(d, "fazenda") == "exploracao", "fazenda -> exploracao")
	check(Mus.trilha_da_area(d, "porto_velho") == "vila", "porto velho -> vila")
	var musica = root.get_node_or_null("Musica")
	check(musica != null, "autoload Musica presente")
	check(AudioServer.get_bus_index("Musica") != -1 and AudioServer.get_bus_send(AudioServer.get_bus_index("Musica")) == &"Master", "barramento Musica envia ao Master (volume geral)")
	var menu = load("res://inicio.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	await frames(20)
	check(Mus.trilha_para(d, menu) == "titulo", "menu inicial -> titulo")
	await create_timer(0.6).timeout
	check(musica.trilha == "titulo", "gerenciador tocou o titulo (%s)" % musica.trilha)
	check(menu.tela == "principal" and menu.pagina.get_child_count() > 0, "menu redesenhado montado")
	var botoes: Array = menu.pagina.find_children("*", "Button", true, false)
	var nomes: Array = botoes.map(func(b): return b.text)
	check(nomes.has("Novo jogo") and nomes.has("Carregar jogo") and nomes.has("Configurações") and nomes.has("Sair"), "botoes do inicio preservados")
	var fv = menu.find_child("FundoVivo", true, false)
	check(fv != null, "fundo vivo no inicio")
	var pintura = fv.get_node_or_null("Pintura") if fv else null
	check(pintura != null and pintura.texture != null and pintura.texture.get_width() >= 1600, "fundo pintado (referencia do Thiago) em resolucao cheia")
	check(pintura != null and pintura.material is ShaderMaterial, "brilho de cachoeira e sol no fundo")
	var com_icone := botoes.filter(func(b): return b.get_node_or_null("Icone") != null and b.get_node("Icone").texture != null)
	check(com_icone.size() == 4, "4 placas com icone")
	check(botoes[0].focus_neighbor_bottom != NodePath() and botoes[3].focus_neighbor_top != NodePath(), "navegacao por teclado/controle entre as placas")
	menu.configuracoes(); await frames(2)
	check(menu.tela == "configuracoes", "configuracoes abre")
	menu.principal(); await frames(2)
	menu.queue_free(); await frames(2)
	# area nova
	var Reg = load("res://scripts/mundo/registro_areas.gd")
	check(Reg.existe("mirante_cascata") and Reg.cena("mirante_cascata") != "", "mirante_cascata registrado com cena")
	check(Reg.validar().is_empty(), "registro valido: %s" % str(Reg.validar()))
	var ad = load("res://scripts/mundo/area_mapa_novo.gd").new()
	root.add_child(ad)
	ad.carregar(Reg.cena("mirante_cascata"), "mirante_cascata", "viagem")
	await frames(10)
	check(ad.player != null and ad.player.global_position.distance_to(ad.mapa.vista.to_global(Vector3(0, 0.15, 7.5))) < 1.0, "Vale nasce no planalto do mirante")
	for i in 30:
		await physics_frame
	check(ad.player.is_on_floor() or ad.player.global_position.y > -1.0, "chao do mirante segura a Vale")
	ad.player.global_position = ad.mapa.vista.to_global(Vector3(0, 0.3, -6.5))
	for i in 10:
		await physics_frame
	await frames(2)
	check(ad.mapa.no_mirante and ad.mapa.cam_cine.current, "pisar no mirante liga a camera cinematografica")
	ad.player.global_position = ad.mapa.vista.to_global(Vector3(0, 0.3, 7.0))
	for i in 10:
		await physics_frame
	await frames(2)
	check(not ad.mapa.no_mirante and ad.camera.current, "sair do mirante devolve a camera do jogo")
	ad.queue_free(); await frames(2)
	# props novos existem
	var faltando := []
	for f in ["scripts/vila_grande/vila_grande_layout.json", "scripts/vila_grande/cidade_fantasma_layout.json", "scripts/vila_grande/vila_orcs_layout.json"]:
		var lay = JSON.parse_string(FileAccess.get_file_as_string("res://" + f))
		for m in lay.modelos:
			if String(m.get("origem", "")).begins_with("bolorina_arte_mundos") and not ResourceLoader.exists("res://art/models/" + String(m.m)):
				faltando.append(m.m)
	check(faltando.is_empty(), "props CC0 das areas existem %s" % str(faltando))
	# passo 2: decoracao (autoload DecoracaoMundos)
	check(root.get_node_or_null("DecoracaoMundos") != null, "autoload DecoracaoMundos presente")
	var Reg2 = load("res://scripts/mundo/registro_areas.gd")
	var ad2 = load("res://scripts/mundo/area_mapa_novo.gd").new()
	root.add_child(ad2)
	ad2.carregar(Reg2.cena("estacao_depois_de_ontem"), "estacao_depois_de_ontem", "")
	await frames(8)
	var dec = ad2.mapa.get_node_or_null("DecoracaoBolorina")
	check(dec != null and dec.find_children("*", "AnimatedSprite3D", true, false).size() >= 8, "Estacao com neons Warped City")
	var pv: Array = get_nodes_in_group("ponto_viagem")
	check(pv.size() > 0 and pv[0].find_child("PortalAnimado", true, false) != null, "portal animado no ponto de viagem")
	ad2.queue_free(); await frames(2)
	var pedra = load("res://scripts/mundo/pedra_viagem.gd").new()
	root.add_child(pedra)
	await frames(4)
	check(pedra.find_child("PortalAnimado", true, false) != null, "portal animado na pedra de viagem")
	pedra.queue_free()
	var mas = load("res://scenes/dungeon/minas_da_cinza.tscn").instantiate()
	root.add_child(mas)
	await frames(8)
	var md = mas.get_meta("decoracao_bolorina", {})
	check(int(md.get("celulas", 0)) >= 20, "Minas com cristais/minerio/lanternas (%s)" % str(md))
	# passo 4: consistencia arena x masmorra dos orcs
	var salas: Dictionary = md.get("salas", {})
	var total_salas := 0
	for k in salas:
		if not String(k).begins_with("centro_"): total_salas += int(salas[k])
	check(int(salas.get("acampamento", 0)) >= 1 and total_salas >= 8, "Minas: acampamento orc decorado (%d itens nas salas: %s)" % [total_salas, str(salas.keys())])
	check(salas.keys().filter(func(k): return not String(k).begins_with("centro_")).size() >= 3, "Minas: salas com papeis variados (%s)" % str(salas.keys()))
	var orcs: Array = mas.combate.inimigos.filter(func(e): return is_instance_valid(e) and String(e.def.get("visual", "")) == "sprite_orc")
	check(orcs.size() > 0 and orcs.all(func(e): return e.sprite.visible and e.modelo == null), "orcs da masmorra usam o sprite pixel da arena (sem modelo 3D)")
	check(orcs.size() > 0 and orcs[0].sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not orcs[0].sprite.shaded, "sprite do orc: nearest e sem sombreamento, igual a arena")
	check(is_equal_approx(mas.camera.size, 15.5), "camera da masmorra no mesmo tamanho da arena (%.1f)" % mas.camera.size)
	mas.queue_free(); await frames(2)
	print("RESULTADO arte_mundos: %d/%d" % [checks - falhas, checks])
	quit(1 if falhas else 0)
