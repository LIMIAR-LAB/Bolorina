extends SceneTree
## Capturas + video do inventario e do bau (com janela, xvfb; save de teste proprio).
## Uso: xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 30 -s res://tests/inventario_bau_captura.gd
## Saida: docs/inventario_bau/*.png e quadros do video em INV_QUADROS (padrao /tmp/inv_quadros) -> ffmpeg.
const SAVE := "user://ilha_inventario_bau_captura.json"
const Inv = preload("res://scripts/ilha/inventario.gd")
var jogo
var f
var gravando := false
var quadro := 0
var pasta_q := "/tmp/inv_quadros/"
var legenda: Label
var legenda_fundo: Panel
## INV_MODO=fotos (so as capturas, sem gravar quadros) | video (so os quadros) | vazio = os dois
var modo := OS.get_environment("INV_MODO")
var fps := int(OS.get_environment("INV_FPS")) if OS.get_environment("INV_FPS") != "" else 30

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame
		if gravando:
			await _gravar()

func seg(s: float) -> void:
	await fr(int(s * fps))

func _gravar() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	if img.get_width() > 1280:
		img.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
	img.save_jpg(pasta_q + "q%05d.jpg" % quadro, 0.9)
	quadro += 1

func foto(nome: String) -> void:
	if modo == "video":
		return
	await fr(6)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var p := ProjectSettings.globalize_path("res://docs/inventario_bau/%s.png" % nome)
	img.save_png(p)
	print("INFO ", p)

func tecla(k: int, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	ev.shift_pressed = shift
	root.push_input(ev)
	await fr(2)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)
	await fr(2)

func dizer(t: String) -> void:
	legenda.text = t
	legenda_fundo.visible = t != ""
	legenda_fundo.size = Vector2(legenda.get_minimum_size().x + 36, 46)
	legenda_fundo.position = Vector2(800 - legenda_fundo.size.x * 0.5, 8)

func _run() -> void:
	create_timer(3000.0).timeout.connect(func(): print("TIMEOUT"); quit(2))
	if OS.get_environment("INV_QUADROS") != "":
		pasta_q = OS.get_environment("INV_QUADROS")
	DirAccess.make_dir_recursive_absolute(pasta_q)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/inventario_bau"))
	OS.set_environment("ILHA_SAVE", SAVE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	var cl := CanvasLayer.new()
	cl.layer = 100
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(cl)
	legenda_fundo = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.02, 0.82)
	sb.set_corner_radius_all(6)
	sb.border_color = Color("e0b040")
	sb.set_border_width_all(2)
	legenda_fundo.add_theme_stylebox_override("panel", sb)
	cl.add_child(legenda_fundo)
	legenda = Label.new()
	legenda.position = Vector2(18, 8)
	legenda.add_theme_font_size_override("font_size", 22)
	legenda.add_theme_color_override("font_color", Color("fff1b8"))
	legenda_fundo.add_child(legenda)
	dizer("")
	for i in 600:
		await process_frame
		if jogo.nome == "fazenda" and not jogo.ocupado and jogo.atual != null:
			break
	await seg(1.0)
	f = jogo.atual
	var e = jogo.estado
	# itens variados para a mochila (a Vale do save novo so tem sementes)
	for par in [["pedra", 23], ["fibra", 14], ["minerio_cobre", 6], ["carvao", 4], ["lingote_ferro", 2], ["peixe_carpa", 3],
			["peixe_dourado", 1], ["nabo", 5], ["ovo", 6], ["pocao_vida", 2], ["pao_cinzas", 3], ["carta_entrega", 1], ["mapa_minas", 1], ["picareta_cobre", 1]]:
		e.somar(String(par[0]), int(par[1]))
	e.ouro = 340
	# arvore mais perto do inicio
	var p0: Vector3 = f.player.position
	var arv := Vector2i(9999, 9999)
	for c in f.detritos.mapa:
		if f.detritos.tipo(c) == "arvore" and Vector2(c.x - p0.x, c.y - p0.z).length() < Vector2(arv.x - p0.x, arv.y - p0.z).length():
			arv = c
	var lado := Vector2i(1, 0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not f.detritos.em(arv + d) and f.vila.altura(float(arv.x + d.x), float(arv.y + d.y)) > -0.3:
			lado = d
			break
	var pv: Vector2i = arv + lado * 1
	f.player.position = Vector3(pv.x, f.vila.altura(float(pv.x), float(pv.y)) + 0.4, pv.y)
	f.player.velocity = Vector3.ZERO
	f.facing = Vector3(-lado.x, 0, -lado.y)
	e.slot = 2
	f.ui.atualizar()
	await seg(1.2)
	# ---------------- video
	gravando = modo != "fotos"
	dizer("1 · Machado na árvore (3 golpes)")
	await seg(1.0)
	for i in 3:
		f.facing = Vector3(-lado.x, 0, -lado.y)
		f.ui.usar()
		await seg(0.7)
	dizer("2 · A árvore cai: as toras viram madeira")
	await seg(2.4)
	f.facing = Vector3(-lado.x, 0, -lado.y)
	f.ui.usar()
	dizer("2 · Mais um golpe arranca o toco (+1 madeira)")
	await seg(1.6)
	e.somar("madeira", 26)
	f.ui.atualizar()
	dizer("(madeira de outros galhos e tocos, adiantada no vídeo)")
	await seg(1.4)
	dizer("3 · B abre a mochila (I abre na última aba)")
	await tecla(KEY_B)
	await seg(1.4)
	await foto("01_inventario_tudo")
	dizer("3 · Tab troca de aba: Materiais")
	for i in 3:
		await tecla(KEY_TAB)
		await seg(0.35)
	var i_mad: int = jogo.inventario_tela.itens_vis.map(func(x): return x.id).find("madeira")
	jogo.inventario_tela.sel = maxi(0, i_mad)
	jogo.inventario_tela._atualizar_itens()
	await seg(1.4)
	await foto("02_inventario_materiais")
	dizer("4 · Aba Equipamento: a tela de equipar dentro do inventário")
	jogo.inventario_tela.ir_aba("equipamento")
	await seg(1.6)
	await foto("03_aba_equipamento")
	dizer("5 · Aba Fabricar: baú de madeira (25 madeira)")
	await tecla(KEY_TAB)
	await seg(1.2)
	await foto("04_aba_fabricar")
	await tecla(KEY_C)
	dizer("5 · C fabrica o baú")
	await seg(1.4)
	await foto("05_fabricou_bau")
	dizer("6 · Colocar baú: o fantasma verde mostra onde vai")
	await tecla(KEY_DOWN)
	await seg(0.6)
	await tecla(KEY_ENTER)
	await seg(0.4)
	var mb = jogo.baus_mundo
	# celula livre perto da Vale
	var pc := Vector2i(roundi(f.player.position.x), roundi(f.player.position.z))
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		f.facing = Vector3(d.x, 0, d.y).normalized()
		await fr(2)
		mb._atualizar_fantasma()
		if mb.alvo_ok:
			break
	await seg(1.4)
	await foto("06_colocando_fantasma")
	await tecla(KEY_E)
	dizer("6 · E coloca o baú na fazenda")
	await seg(1.4)
	await foto("07_bau_no_mundo")
	dizer("7 · E perto do baú abre os 36 espaços")
	await tecla(KEY_E)
	await seg(1.0)
	var t = jogo.inventario_tela
	for id in ["pedra", "fibra", "minerio_cobre", "nabo"]:
		var i: int = t.moc_vis.map(func(x): return x.id).find(id)
		if i >= 0:
			t.painel = 1
			t.sel_moc = i
			t._atualizar_bau()
			await seg(0.35)
			await tecla(KEY_ENTER, true)
			dizer("7 · Shift+Enter guarda a pilha toda (%s)" % Inv.nome(id))
			await seg(0.6)
	var i2: int = t.moc_vis.map(func(x): return x.id).find("ovo")
	t.sel_moc = maxi(0, i2)
	t._atualizar_bau()
	for k in 3:
		await tecla(KEY_ENTER)
		dizer("7 · Enter guarda 1 (ovo)")
		await seg(0.35)
	t.painel = 0
	t.sel_bau = 0
	t._atualizar_bau()
	await seg(0.5)
	await tecla(KEY_ENTER)
	dizer("7 · No baú, Enter retira 1")
	await seg(1.0)
	await foto("08_tela_do_bau")
	await tecla(KEY_ESCAPE)
	dizer("Fecha (Esc): tudo salvo no save (chave nova \"baus\")")
	await seg(1.8)
	dizer("")
	await seg(0.4)
	gravando = false
	# casa da Vale: o bau que enfeitava a sala agora guarda coisas
	f.interiores._trocar_para(0)
	await seg(1.0)
	f.player.position = mb.casa_no.global_position + Vector3(0, 0.4, 0.9)
	await seg(1.0)
	await foto("09_bau_da_casa")
	mb.abrir(Inv.ID_CASA)
	await seg(0.6)
	await foto("10_tela_bau_da_casa")
	t.fechar()
	print("INFO quadros ", quadro, " em ", pasta_q)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(0)
