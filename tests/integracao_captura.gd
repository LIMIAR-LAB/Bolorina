extends SceneTree
## Capturas da integracao 20/10 (com janela, xvfb; save de teste): mapa pintado com as areas da primeira ilha,
## Porto Velho real com a Vale e o elenco (conversa com rosto), balcao da Ferraria do Gaspar e a interface da forja.
## Saida: docs/integracao-2026-10-20-*.png
const SAVE := "user://ilha_integracao_captura.json"
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")
var jogo

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func esperar(id: String) -> void:
	for i in 900:
		await process_frame
		if jogo.nome == id and not jogo.ocupado and jogo.atual != null:
			break
	await create_timer(0.8).timeout

func foto(nome: String) -> void:
	await fr(8)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/integracao-2026-10-20-%s.png" % nome))
	print("INFO docs/integracao-2026-10-20-%s.png" % nome)

func _run() -> void:
	create_timer(600.0).timeout.connect(func(): quit(2))
	OS.set_environment("ILHA_SAVE", SAVE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "porto_velho")
	OS.set_environment("ILHA_SPAWN", "viagem")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await esperar("porto_velho")
	var e = jogo.estado
	for it in ["mapa_vila_orcs", "mapa_cidade_fantasma", "mapa_minas", "bussola_temporal"]:
		e.somar(it, 1)
	jogo.alternar_mapa()
	await foto("mapa")
	jogo.alternar_mapa()
	var a = jogo.atual
	var an = a.area_npcs
	# praca com moradores
	a.player.global_position = Vector3(2, a.mapa._y(2, 6) + 0.3, 6)
	a.camera.size = 26.0
	await fr(30)
	await foto("porto-velho")
	# conversa com a Mira (rosto da Bolorina)
	var im: int = an.npc_por_id("mira")
	a.player.global_position = an.npcs[im].no.global_position + Vector3(1.2, 0.3, 1.0)
	a.camera.size = 12.0
	await fr(20)
	a.dialogos.conversar_com("mira")
	await create_timer(1.5).timeout
	await foto("conversa-mira")
	a.dialogos.caixa._fechar()
	await fr(6)
	# balcao do Gaspar Bigorna: forjar
	e.ouro = 900
	e.somar("minerio_ferro", 6)
	e.somar("carvao", 4)
	e.somar("lingote_cobre", 6)
	e.somar("madeira", 6)
	e.somar("couro", 4)
	var ig: int = an.npc_por_id("ferreiro")
	a.player.global_position = an.npcs[ig].no.global_position + Vector3(1.2, 0.3, 0.8)
	await fr(20)
	a.dialogos.conversar_com("ferreiro")
	await create_timer(1.0).timeout
	await foto("conversa-gaspar")
	a.dialogos.caixa._fechar()
	await fr(8)
	an.aba = an.abas.find("forjar")
	an._listar()
	await foto("forja-balcao")
	an.fechar()
	# morador novo do Claude (cartografo) perto da praca
	var it2: int = an.npc_por_id("tobias")
	a.player.global_position = an.npcs[it2].no.global_position + Vector3(1.4, 0.3, 1.2)
	await fr(20)
	an.falar(it2)
	await foto("cartografo")
	an.fechar()
	# interface da forja da Bolorina (scenes/ui/forja_ui.tscn), sozinha, com icones de art/ui/icones_forja
	var est = Estado.new()
	var g = Gerenciador.new(est)
	root.add_child(g)
	est.marcar("tutorial_pulado")
	for k in {"ouro": 140, "minerio_cobre": 5, "carvao": 2, "lingote_cobre": 3, "madeira": 4, "couro": 1}:
		g.adicionar_item(k, int({"ouro": 140, "minerio_cobre": 5, "carvao": 2, "lingote_cobre": 3, "madeira": 4, "couro": 1}[k]))
	var ui = load("res://scenes/ui/forja_ui.tscn").instantiate()
	ui.demo_se_sozinha = false
	root.add_child(ui)
	ui.abrir(g)
	await fr(4)
	ui.selecionado = "forjar_espada_cobre"
	ui._atualizar_tudo()
	await foto("forja-ui")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(0)
