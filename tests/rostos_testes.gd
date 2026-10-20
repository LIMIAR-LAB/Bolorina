extends SceneTree
## Testes dos rostos e corpos dos moradores.
## Rodar:  godot --headless --path . -s res://tests/rostos_testes.gd
## 1) todo morador registrado tem retrato em art/ui/retratos/<id>.png e o retrato sai em escala inteira
##    no slot de 164 px da caixa de dialogo (82 px = 2x; recorte de sprite = 41 px = 4x);
## 2) todo morador tem visual de mundo que NAO e a capsula provisoria (sprite pixel, sprite 8 direcoes
##    ou modelo 3D) e o NpcConversavel monta esse visual;
## 3) sprites pixel: billboard em Y, filtro nearest, densidade da Vale, 2 quadros de idle diferentes;
## 4) fantasmas translucidos; dragao grande; caixa de dialogo mede o slot do retrato.
const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Npc = preload("res://scripts/dialogos/npc_conversavel.gd")
const CenaCaixa = preload("res://scenes/ui/caixa_dialogo.tscn")

var checks := 0
var failures := 0
var tipos := {}

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ids: Array = Registro.todos_ids()
	check(ids.size() >= 41, "registro com %d moradores" % ids.size())
	_testar_retratos(ids)
	_testar_fallbacks()
	await _testar_visuais(ids)
	await _testar_caixa()
	print("\nVISUAL POR MORADOR")
	for id in ids:
		print("  %-22s %s" % [id, tipos.get(id, "?")])
	print("\n%s: %d verificacoes, %d falhas" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	await process_frame
	quit(0 if failures == 0 else 1)

func _testar_retratos(ids: Array) -> void:
	for id in ids:
		var c := Registro.caminho_retrato(id)
		check(c != "", "%s: tem retrato art/ui/retratos/%s.png" % [id, id])
		var t := Registro.retrato(id)
		check(t != null and t is ImageTexture, "%s: retrato carregado do PNG" % id)
		if t:
			var lado := t.get_width()
			check(t.get_height() == lado and Registro.LADO_SLOT_RETRATO % lado == 0 and lado == 82,
				"%s: retrato %dx%d (164/%d = %dx inteiro)" % [id, lado, t.get_height(), lado, Registro.LADO_SLOT_RETRATO / maxi(1, lado)])
			# a grade de 64 dentro do quadro: cada pixel 2x2 no PNG original vira 1 pixel aqui
			var orig: Texture2D = load(c)
			check(orig.get_width() == 128 and orig.get_height() == 128, "%s: PNG do retrato 128x128" % id)

func _testar_fallbacks() -> void:
	var v := Registro.retrato_vale()
	check(v != null and Registro.LADO_SLOT_RETRATO % v.get_width() == 0, "retrato da Vale (recorte) em escala inteira: %d px" % (v.get_width() if v else 0))
	var b := Registro.retrato("ninguem_registrado")
	check(b != null, "id desconhecido cai no busto provisorio")
	check(Registro.lado_inteiro(64) == 82 and Registro.lado_inteiro(34) == 41 and Registro.lado_inteiro(100) == 164, "lado_inteiro escolhe divisores de 164")

func _testar_visuais(ids: Array) -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 10)
	mundo.add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var x := 0.0
	for id in ids:
		var tipo := Registro.tipo_visual(id)
		tipos[id] = tipo + "  " + Registro.visual(id).replace("res://", "")
		check(tipo != "provisorio", "%s: visual do registro nao e capsula (%s)" % [id, tipo])
		var n = Npc.new()
		n.npc_id = id
		n.position = Vector3(x, 0, 0)
		x += 3.0
		mundo.add_child(n)
		await process_frame
		var vis: Node = n.get_node_or_null("Visual")
		check(vis != null and n.tipo_visual == tipo, "%s: NpcConversavel montou o Visual (%s)" % [id, n.tipo_visual])
		if vis == null:
			continue
		var capsulas := 0
		for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh is CapsuleMesh:
				capsulas += 1
		check(capsulas == 0, "%s: nenhuma capsula no visual" % id)
		match tipo:
			"sprite":
				var spr: AnimatedSprite3D = vis.get_node_or_null("Sprite")
				check(spr != null, "%s: tem AnimatedSprite3D" % id)
				if spr:
					check(spr.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y and spr.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s: billboard Y + nearest" % id)
					check(is_equal_approx(spr.pixel_size, 1.72 / 48.0), "%s: densidade da Vale (%.4f m/px)" % [id, spr.pixel_size])
					var fr := spr.sprite_frames
					check(fr.get_frame_count("idle_frente") == 2 and fr.get_animation_speed("idle_frente") > 0.0, "%s: idle de 2 quadros" % id)
					var a := fr.get_frame_texture("idle_frente", 0).get_image()
					var b := fr.get_frame_texture("idle_frente", 1).get_image()
					check(a.get_data() != b.get_data(), "%s: os 2 quadros do idle sao diferentes" % id)
					var usado := a.get_used_rect()
					var altura := usado.size.y * spr.pixel_size
					var esperado := Vector2(0.6, 1.95)
					if id == "dragao":
						esperado = Vector2(3.0, 3.9)
					elif id == "gato":
						esperado = Vector2(0.5, 1.0)
					elif id == "crianca_praca":
						esperado = Vector2(0.9, 1.3)
					check(altura >= esperado.x and altura <= esperado.y, "%s: altura no mundo %.2f m" % [id, altura])
					check(usado.end.y == a.get_height() - 1, "%s: pe na base do quadro (sem flutuar nem afundar)" % id)
					if Registro.eh_fantasma(id):
						check(spr.modulate.a < 0.8 and spr.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED, "%s: fantasma translucido" % id)
					else:
						check(spr.modulate.a == 1.0, "%s: opaco" % id)
			"ator":
				check(vis.has_method("set_direction"), "%s: ActorVisual de 8 direcoes" % id)
			"modelo":
				check(vis.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s: modelo 3D com malhas" % id)
		# virar para um alvo nao quebra
		n.olhar_para(n.global_position + Vector3(0, 0, -3))
		n.olhar_para(n.global_position + Vector3(0, 0, 3))
	mundo.queue_free()
	await process_frame

func _testar_caixa() -> void:
	var caixa = CenaCaixa.instantiate()
	root.add_child(caixa)
	caixa.automatico = true
	caixa.iniciar(load(Registro.caminho_dialogo("mira")), "mira")
	for i in 20:
		await process_frame
	var r: TextureRect = caixa.retrato
	var lado := r.size
	var t := r.texture
	print("slot do retrato na caixa: %s, textura %s" % [lado, t.get_size() if t else Vector2.ZERO])
	check(t != null, "caixa: retrato presente")
	if t:
		var k := lado.x / t.get_width()
		check(is_equal_approx(lado.x, lado.y) and is_equal_approx(k, roundf(k)), "caixa: retrato em escala inteira no slot (%.0f px / %d px = %.2fx)" % [lado.x, t.get_width(), k])
	caixa.queue_free()
	await process_frame
