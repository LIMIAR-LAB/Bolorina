extends SceneTree
## Capturas da interface da forja (precisa de janela: xvfb-run). Salva PNGs em FORJA_CAPTURA (padrão user://).
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")
const UI = preload("res://scripts/ui/forja_ui.gd")
var pasta := ""

func _initialize() -> void:
	call_deferred("run")

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _salvar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(pasta.path_join(nome))
	print("captura ", pasta.path_join(nome), " ", img.get_size())

func _g(itens: Dictionary, iniciar := true):
	var est = Estado.new()
	var g = Gerenciador.new(est)
	root.add_child(g)
	if iniciar:
		est.marcar("tutorial_pulado")
	for k in itens:
		g.adicionar_item(k, int(itens[k]))
	return g

func run() -> void:
	pasta = OS.get_environment("FORJA_CAPTURA")
	if pasta == "":
		pasta = OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(pasta)
	var fundo := TextureRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://art/ui/telas/porto_velho.png"))
	if img != null and not img.is_empty():
		fundo.texture = ImageTexture.create_from_image(img)
	root.add_child(fundo)
	var g = _g({"ouro": 140, "minerio_cobre": 5, "carvao": 2, "lingote_cobre": 3, "madeira": 4, "couro": 1, "lasca_de_eco": 1})
	var ui = load("res://scenes/ui/forja_ui.tscn").instantiate()
	ui.demo_se_sozinha = false
	root.add_child(ui)
	ui.abrir(g)
	await _quadros(3)
	# 1) dá para forjar + comparação
	ui.selecionado = "forjar_espada_cobre"
	ui._atualizar_tudo()
	ui._botao_de("forjar_espada_cobre").grab_focus()
	await _quadros(3)
	await _salvar("forja_01_pode_forjar_comparacao.png")
	# 2) falta material: de onde vem + reserva da missão
	ui._mudar_filtro("falta")
	ui.selecionado = "fundir_cobre"
	ui._atualizar_tudo()
	ui._botao_de("fundir_cobre").grab_focus()
	await _quadros(3)
	await _salvar("forja_02_falta_material_origem.png")
	ui.selecionado = "forjar_peitoral_cobre"
	ui._atualizar_tudo()
	if ui._botao_de("forjar_peitoral_cobre") != null:
		ui._botao_de("forjar_peitoral_cobre").grab_focus()
	await _quadros(3)
	await _salvar("forja_03_falta_lingote.png")
	# 3) travado
	ui._mudar_filtro("travado")
	ui.selecionado = "forjar_espada_ferro"
	ui._atualizar_tudo()
	ui._botao_de("forjar_espada_ferro").grab_focus()
	await _quadros(3)
	await _salvar("forja_04_travado.png")
	# 4) forjou e equipou
	ui._mudar_filtro("tudo")
	ui.selecionado = "forjar_espada_cobre"
	ui._atualizar_tudo()
	ui._acao_forjar()
	ui._acao_equipar()
	ui.selecionado = "forjar_espada_cobre"
	ui._atualizar_tudo()
	ui.btn_testar.grab_focus()
	ui._avisar("Equipado: Espada de Cobre. Testar na Arena manda o sinal testar_na_arena(item, variação).")
	await _quadros(3)
	await _salvar("forja_05_equipado_testar.png")
	# 5) têmpera em cinza (missão)
	var g2 = _g({"ouro": 60, "lingote_cobre": 1, "madeira": 2})
	for mk in ["atrasada_conta_lida", "atrasada_defeito_visto", "atrasada_gaspar_explicou_minas"]:
		g2.estado.marcar(mk)
	ui.abrir(g2)
	await _quadros(3)
	await _salvar("forja_06_tempera_em_cinza.png")
	# 6) escolha do eco
	ui.modelo.fazer_reforco()
	g2.chegou_area("minas_andar_1")
	g2.notificar("eco_acertou", "lodo_casca_grossa")
	g2.notificar("inimigo_derrotado", "lodo_casca_grossa", 3)
	g2.chegou_area("minas_andar_4")
	g2.notificar("trava_acertada_eco", "bate_estaca", 3)
	g2.coletar_item("catraca_mestra")
	g2.chegou_area("porto_velho")
	g2.estado.marcar("atrasada_peca_entregue")
	ui.abrir(g2)
	ui.selecionado = UI.ESPECIAL_ECO
	ui._atualizar_tudo()
	ui._ir_para_acoes()
	await _quadros(3)
	await _salvar("forja_07_eco_rapido_ou_pesado.png")
	quit(0)
