extends SceneTree
## Equipamento: dados (vestir/tirar/defesa/camadas), save (novo, antigo sem a chave, ida e volta),
## tela (I abre e pausa; Enter veste; I fecha), visual na vila, fazenda e combate (quadros compostos),
## forma Adamantium (G) por cima do visual e volta ao vestido. Defesa reduz dano no combate.
## EQ_CAP=1 (com janela) grava docs/equip-{tela,antes,depois,fazenda,combate}.png
const Equip = preload("res://scripts/ilha/equipamento.gd")
const Visual = preload("res://scripts/ilha/equipamento_visual.gd")
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const SAVE := "user://ilha_equip_teste.json"
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

func cap() -> bool:
	return OS.get_environment("EQ_CAP") == "1"

func foto(nome: String) -> void:
	if not cap():
		return
	await fr(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % nome))
	print("INFO captura docs/%s.png" % nome)

func perto(a, spawn := "") -> void:
	# camera fechada na Vale (vila/fazenda), num ponto aberto, olhando para o sul
	if not cap() or a.get("vila") == null:
		return
	if spawn != "":
		a.nascer(spawn)
		a.player.velocity = Vector3.ZERO
		await fr(3)
	a.sprite.facing_direction = "south-east"
	a.sprite.play(a.sprite.animation_for("idle"))
	a.camera_travada = true
	a.vila.cam_alvo = Vector3(a.player.position.x, 0, a.player.position.z)
	a.vila.cam_size = 11.0
	a.apply_camera()

## pixel diferente na tela (dois transparentes contam como iguais: o import do Godot preenche o RGB
## invisivel da borda com fix_alpha_border, e a composicao parte do PNG do disco)
func _difere(p: Color, q: Color) -> bool:
	if p.a < 0.01 and q.a < 0.01:
		return false
	return not p.is_equal_approx(q)

func dif(a: Texture2D, b: Texture2D) -> int:
	var ia := a.get_image()
	var ib := b.get_image()
	if ia.is_compressed(): ia.decompress()
	if ib.is_compressed(): ib.decompress()
	ia.convert(Image.FORMAT_RGBA8)
	ib.convert(Image.FORMAT_RGBA8)
	if ia.get_size() != ib.get_size():
		return -1
	var n := 0
	for y in ia.get_height():
		for x in ia.get_width():
			if _difere(ia.get_pixel(x, y), ib.get_pixel(x, y)):
				n += 1
	return n

func dif_regiao(a: Texture2D, b: Texture2D, y0: int, y1: int) -> int:
	var ia := a.get_image()
	var ib := b.get_image()
	if ia.is_compressed(): ia.decompress()
	if ib.is_compressed(): ib.decompress()
	var n := 0
	for y in range(y0, y1):
		for x in ia.get_width():
			if _difere(ia.get_pixel(x, y), ib.get_pixel(x, y)):
				n += 1
	return n

func _run() -> void:
	create_timer(300.0).timeout.connect(func():
		print("FAIL tempo esgotado (300 s)")
		paused = false
		quit(2))
	# ------------------------------------------------ dados
	var eq := Equip.novo()
	check(Equip.equipado(eq, "corpo") == "roupa_aprendiz" and Equip.equipado(eq, "pernas") == "calca_lida" and Equip.equipado(eq, "cabeca") == "", "equipamento inicial: roupa de aprendiz + calca de lida, cabeca vazia")
	check(Equip.camadas(eq).is_empty() and Equip.defesa(eq) == 0, "inicial = arte base, defesa 0")
	check(eq.possui.size() == Equip.INICIAIS.size() and eq.possui.size() >= 12, "mochila inicial com %d pecas" % eq.possui.size())
	check(Equip.equipar(eq, "tunica_pescador") and Equip.equipado(eq, "corpo") == "tunica_pescador", "veste a tunica no corpo")
	check(Equip.equipar(eq, "elmo_ferro") and Equip.equipar(eq, "calca_anil"), "veste elmo e calca anil")
	check(Equip.camadas(eq) == ["calca_anil", "camisa_azul", "elmo_ferro"], "camadas na ordem pernas -> corpo -> cabeca (%s)" % str(Equip.camadas(eq)))
	check(Equip.defesa(eq) == 1 + 2 + 1, "defesa somada = 4 (%d)" % Equip.defesa(eq))
	check(not Equip.equipar(eq, "nao_existe"), "peca inexistente nao veste")
	var eq2 := Equip.novo()
	eq2.possui.erase("elmo_adamantium")
	check(not Equip.equipar(eq2, "elmo_adamantium"), "peca que a Vale nao tem nao veste")
	check(Equip.desequipar(eq, "cabeca") and Equip.equipado(eq, "cabeca") == "", "tirar o elmo deixa a cabeca vazia")
	check(Equip.desequipar(eq, "corpo") and Equip.equipado(eq, "corpo") == "roupa_aprendiz", "tirar a roupa volta para a roupa de aprendiz")
	check(not Equip.desequipar(eq, "corpo"), "nao tira a roupa padrao (nunca fica sem roupa)")
	check(Equip.alternar(eq, "calca_anil") and Equip.equipado(eq, "pernas") == "calca_lida", "alternar numa peca vestida tira")
	check(Equip.defesa_com(eq, "peitoral_adamantium") == Equip.defesa(eq) + 5, "comparacao de defesa ao vestir (+5)")
	for id in Equip.ITENS:
		var it: Dictionary = Equip.ITENS[id]
		var ok := Equip.SLOTS.has(String(it.slot))
		for c in it.camadas:
			ok = ok and Visual.existe(String(c))
		ok = ok and FileAccess.file_exists(ProjectSettings.globalize_path("res://art/ui/icones_equip/%s.png" % id))
		check(ok, "peca %s: slot valido, camadas no indice, icone" % id)
	# ------------------------------------------------ pecas do PixelLab (capacetes + armaduras)
	var ix: Dictionary = Visual.indice()
	for id in ["capuz_couro", "elmo_ferro", "elmo_adamantium", "couro_cacador", "malha_guarda"]:
		var info: Dictionary = ix.camadas.get(id, {})
		check(String(info.get("fonte", "")) == "pixellab" and not Equip.ITENS[id].has("provisorio") and Equip.INICIAIS.has(id), "%s: camada do PixelLab, sem marca de provisorio, na mochila" % id)
		var muda := 0
		var fora := 0
		for d in ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]:
			var arq := "rotations/%s.png" % d
			var b: Image = Visual.imagem(String(ix.vila.base) + arq)
			var t: Image = Visual.quadro_vila([id], arq).get_image()
			var n := 0
			for y in 48:
				for x in 48:
					if not b.get_pixel(x, y).is_equal_approx(t.get_pixel(x, y)):
						n += 1
						if (y >= 24) == (Equip.ITENS[id].slot == "cabeca"):
							fora += 1
			if n > 40:
				muda += 1
		check(muda == 8, "%s muda a Vale nas 8 direcoes (%d)" % [id, muda])
		check(fora < 8 * 60, "%s fica na parte certa do corpo (%d px do outro lado da linha da cintura)" % [id, fora])
	# mascara de apagar: o pixel some (cabelo que sobrava fora do elmo)
	var ap_img: Image = Visual.imagem(Visual.PASTA + String(ix.camadas.elmo_adamantium.apagar_vila))
	var cam_img: Image = Visual.imagem(Visual.PASTA + String(ix.camadas.elmo_adamantium.vila))
	var achou := Vector2i(-1, -1)
	for y in 48:
		for x in 48:
			if achou.x < 0 and ap_img.get_pixel(x, y).a > 0.5 and cam_img.get_pixel(x, y).a < 0.01:
				achou = Vector2i(x, y)
	var t_ap: Image = Visual.quadro_vila(["elmo_adamantium"], "rotations/south.png").get_image()
	var b_ap: Image = Visual.imagem(String(ix.vila.base) + "rotations/south.png")
	check(achou.x >= 0 and b_ap.get_pixelv(achou).a > 0.5 and t_ap.get_pixelv(achou).a < 0.01, "mascara de apagar tira o pixel da base %s" % str(achou))
	var c_cam: Texture2D = Visual.folha_combate(["malha_guarda", "elmo_ferro"], "hit/hit_south-west_sheet.png", null)
	check(c_cam != null and c_cam.get_size() == Vector2(896, 784), "combate: folha composta com armadura + elmo do PixelLab")
	# ------------------------------------------------ save
	var n0 := Equip.normalizar(null)
	check(n0 == Equip.novo(), "save sem equipamento -> inicial")
	var n1 := Equip.normalizar({"possui": ["elmo_ferro", "lixo"], "equipado": {"cabeca": "elmo_ferro", "corpo": "lixo", "pernas": ""}})
	check(n1.possui.has("elmo_ferro") and not n1.possui.has("lixo") and n1.possui.has("roupa_aprendiz") and n1.equipado.cabeca == "elmo_ferro" and n1.equipado.corpo == "roupa_aprendiz" and n1.equipado.pernas == "calca_lida", "save com ids invalidos e corrigido")
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	var v1 := FileAccess.get_md5("user://island_v1.json") if FileAccess.file_exists("user://island_v1.json") else ""
	var v_ilha := FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	# save antigo (sem a chave)
	var antigo := {"versao": 1, "dia": 7, "ouro": 321, "itens": {"madeira": 4}, "solo": {}, "removidos": [], "arvores": {}, "slot": 2, "energia": 50}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(antigo))
	f.close()
	var e := Estado.new()
	check(e.carregar() and e.dia == 7 and e.ouro == 321 and e.qtd("madeira") == 4, "save antigo carrega sem erro (dia/ouro/itens mantidos)")
	check(Equip.equipado(e.equipamento, "corpo") == "roupa_aprendiz" and e.equipamento.possui.size() == Equip.INICIAIS.size(), "save antigo recebe equipamento inicial")
	Equip.equipar(e.equipamento, "camisa_lenhador")
	Equip.equipar(e.equipamento, "capuz_couro")
	check(e.salvar(), "salva com equipamento")
	var e2 := Estado.new()
	e2.carregar()
	check(Equip.equipado(e2.equipamento, "corpo") == "camisa_lenhador" and Equip.equipado(e2.equipamento, "cabeca") == "capuz_couro" and e2.dia == 7, "equipamento volta do save")
	var dados = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(dados is Dictionary and dados.has("equipamento") and int(dados.versao) == 1, "chave 'equipamento' no save, versao 1 mantida")
	# comeca o jogo com save de teste limpo
	DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "vila")
	OS.set_environment("ILHA_SPAWN", "da_fazenda")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 240:
		await process_frame
		if jogo.atual and jogo.nome == "vila" and not jogo.ocupado:
			break
	await create_timer(0.6).timeout
	var v = jogo.atual
	var sp: AnimatedSprite3D = v.sprite
	var base_tex: Texture2D = sp.sprite_frames.get_frame_texture("idle_south", 0)
	check(base_tex.resource_path.ends_with("rotations/south.png"), "vila: Vale com arte base no comeco")
	check(jogo.equip_tela != null and not jogo.equip_tela.aberta, "tela de equipamento montada (fechada)")
	await perto(v, "padrao")
	await foto("equip-antes")
	# ------------------------------------------------ tela
	await tecla(KEY_I)
	var tela = jogo.equip_tela
	check(tela.aberta and tela.raiz.visible and paused, "I abre a tela e pausa o jogo")
	var p0: Vector3 = v.player.position
	Input.action_press("ui_right")
	await fr(10)
	Input.action_release("ui_right")
	check(v.player.position.distance_to(p0) < 0.001, "jogo congelado com a tela aberta")
	var lista: Array = tela.possui_lista()
	tela.sel = lista.find("tunica_pescador")
	await tecla(KEY_ENTER)
	check(Equip.equipado(jogo.estado.equipamento, "corpo") == "tunica_pescador", "Enter veste a peca selecionada")
	check(tela.previa.texture != null and tela.quadros.size() == 8, "previa ao vivo (8 quadros de corrida)")
	var t1: Texture2D = sp.sprite_frames.get_frame_texture("idle_south", 0)
	check(t1 != base_tex and t1 is ImageTexture, "vila: quadro trocado ao vestir (ao vivo)")
	var d1 := dif(base_tex, t1)
	check(d1 > 30 and dif_regiao(base_tex, t1, 0, 14) == 0, "tunica muda a camisa (%d px) e nao toca a cabeca" % d1)
	tela.sel = tela.possui_lista().find("elmo_ferro")
	tela.vestir_sel()
	tela.sel = tela.possui_lista().find("calca_anil")
	tela.vestir_sel()
	var t2: Texture2D = sp.sprite_frames.get_frame_texture("idle_south", 0)
	check(dif_regiao(base_tex, t2, 0, 14) > 20, "elmo muda o alto da cabeca")
	var walk: Texture2D = sp.sprite_frames.get_frame_texture("walk_east", 3)
	var run: Texture2D = sp.sprite_frames.get_frame_texture("run_east", 3)
	check(walk == run and walk is ImageTexture, "andar e correr usam os mesmos quadros compostos")
	var conta := 0
	for anim in sp.sprite_frames.get_animation_names():
		for i in sp.sprite_frames.get_frame_count(anim):
			if sp.sprite_frames.get_frame_texture(anim, i) is ImageTexture:
				conta += 1
	check(conta == 8 + 64 + 64 + 40, "todos os quadros (idle/andar/correr/agir x 8 direcoes) vestidos: %d" % conta)
	await foto("equip-tela")
	tela.girar(1)
	check(tela.dir_i == 1, "girar a previa")
	await tecla(KEY_I)
	check(not tela.aberta and not paused, "I fecha e despausa")
	var ds = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(ds is Dictionary and String(ds.equipamento.equipado.corpo) == "tunica_pescador" and String(ds.equipamento.equipado.cabeca) == "elmo_ferro", "save gravado ao vestir")
	await perto(v)
	await foto("equip-depois")
	# ------------------------------------------------ fazenda
	jogo.ir("fazenda", "da_vila")
	for i in 300:
		await process_frame
		if jogo.nome == "fazenda" and not jogo.ocupado:
			break
	await create_timer(0.5).timeout
	var fz = jogo.atual
	var tf: Texture2D = fz.sprite.sprite_frames.get_frame_texture("run_south", 2)
	check(tf is ImageTexture and fz.sprite.get_meta("eq_camadas", []) == Equip.camadas(jogo.estado.equipamento), "fazenda: Vale com o mesmo equipamento")
	await perto(fz, "inicio")
	await foto("equip-fazenda")
	# ------------------------------------------------ combate + forma Adamantium
	Equip.equipar(jogo.estado.equipamento, "peitoral_adamantium")
	jogo.ir("arena", "da_vila")
	for i in 400:
		await process_frame
		if jogo.nome == "arena" and not jogo.ocupado:
			break
	await create_timer(0.5).timeout
	var ar = jogo.atual
	var j = ar.jogador
	var fr_c: SpriteFrames = j.sprite.sprite_frames
	var base_c: Dictionary = j.sprite.get_meta("eq_base", {})
	var c0: Texture2D = fr_c.get_frame_texture("c_slash_combo_east", 20)
	check(c0 is AtlasTexture and base_c.has("c_slash_combo_east") and (c0 as AtlasTexture).atlas != (base_c["c_slash_combo_east"][20] as AtlasTexture).atlas, "combate: golpes com a folha composta")
	check(fr_c.get_frame_texture("idle_south-east", 0) is ImageTexture and fr_c.get_frame_texture("run_east", 0) is ImageTexture, "combate: parado/correndo vestidos")
	var x_ok := true
	var a_ok := true
	for anim: String in base_c:
		for i in (base_c[anim] as Array).size():
			if anim.begins_with("x_") and fr_c.get_frame_texture(anim, i) != base_c[anim][i]: x_ok = false
			if anim.begins_with("a_") and fr_c.get_frame_texture(anim, i) != base_c[anim][i]: a_ok = false
	check(x_ok and a_ok, "forma Adamantium (a_*/x_*) intacta")
	check(j.defesa_equip == Equip.defesa(jogo.estado.equipamento) and j.defesa_equip == 5 + 2 + 1, "defesa do equipamento no combate (%d)" % j.defesa_equip)
	j.invulneravel_ate = 0.0
	var hp0: int = j.hp
	j.receber_dano(12, j.global_position + Vector3(1, 0, 0))
	check(hp0 - j.hp == 12 - j.defesa_equip, "dano 12 - defesa %d = %d" % [j.defesa_equip, hp0 - j.hp])
	j.hp = j.hp_max
	j.invulneravel_ate = 0.0
	j.ultimo_dano_t = -10.0
	j._mudar("livre")
	await create_timer(0.5).timeout
	if cap():
		await foto("equip-combate")
	j.energia = j.energia_max
	check(j.pedir_transformar(), "G transforma vestido")
	for i in 120:
		await physics_frame
		if j.transformado:
			break
	await create_timer(0.3).timeout
	var an := String(j.sprite.animation)
	check(j.transformado and (an.begins_with("a_") or an.begins_with("x_")), "transformado: visual da forma Adamantium por cima (%s)" % an)
	j._destransformar()
	j._mudar("livre")
	await create_timer(0.3).timeout
	an = String(j.sprite.animation)
	check(not j.transformado and (an.begins_with("idle_") or an.begins_with("run_")) and j.sprite.sprite_frames.get_frame_texture(an, 0) is ImageTexture, "fim da forma: volta ao visual vestido (%s)" % an)
	# tirar tudo volta a arte base no combate
	for s in Equip.SLOTS:
		Equip.desequipar(jogo.estado.equipamento, s)
	jogo.vestir_atual()
	check(fr_c.get_frame_texture("c_slash_combo_east", 20) == base_c["c_slash_combo_east"][20] and String(fr_c.get_frame_texture("idle_south", 0).resource_path).ends_with("rotations/south.png"), "sem pecas: combate volta exatamente a arte base")
	print("INFO composicoes: %d" % Visual.composicoes)
	# ------------------------------------------------ saves reais intactos
	check((FileAccess.get_md5("user://island_v1.json") if FileAccess.file_exists("user://island_v1.json") else "") == v1, "user://island_v1.json intacto")
	check((FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else "") == v_ilha, "save real da ilha intacto (teste usa ilha_equip_teste.json)")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO equipamento: %d/%d" % [checks - failures, checks])
	paused = false
	quit(1 if failures > 0 else 0)
