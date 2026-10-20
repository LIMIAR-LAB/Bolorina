extends SceneTree
## Capturas do mapa das ilhas e dos pontos de viagem (com janela; xvfb + vulkan no box).
##   HUB_CAPTURA=/pasta godot --path . -s res://tests/hub_captura.gd           -> PNGs
##   HUB_TOUR=1 godot --path . --resolution 1024x576 --write-movie tour.avi --fixed-fps 30 -s res://tests/hub_captura.gd
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Viagem = preload("res://scripts/mundo/viagem.gd")
var pasta := ""
var viajante: Node

func _init() -> void:
	call_deferred("_rodar")

func _f(n: int) -> void:
	for i in n:
		await process_frame

func _chegar(id: String) -> void:
	for i in 900:
		await process_frame
		if Viagem.area_atual(self) == id and viajante and viajante.ultima_chegada.get("area", "") == id and current_scene.get("ocupado") != true:
			break

func _tecla(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)

func _foto(nome: String) -> void:
	await process_frame
	var arq := pasta.path_join(nome + ".png")
	root.get_viewport().get_texture().get_image().save_png(arq)
	print("[hub_captura] ", arq)

func _ir(id: String) -> void:
	viajante = Viagem.garantir_viajante(self)
	await _f(1)
	viajante.partir(id)
	await _chegar(id)

func _rodar() -> void:
	OS.set_environment("ILHA_SEM_SAVE", "1")
	Viagem.visitadas = {}
	if OS.get_environment("HUB_TOUR_SEG") != "":
		await _segmento(OS.get_environment("HUB_TOUR_SEG"))
	elif OS.get_environment("HUB_TOUR") != "":
		await _tour()
	else:
		pasta = OS.get_environment("HUB_CAPTURA")
		DirAccess.make_dir_recursive_absolute(pasta)
		root.size = Vector2i(1600, 900)
		await _fotos()
	quit()

func _fotos() -> void:
	# 1. pontos de viagem nas áreas + mapa por cima
	var so := OS.get_environment("HUB_CAPTURA_SO")
	for id in ["porto_velho", "vila_orcs", "cidade_fantasma", "estacao_depois_de_ontem", "fazenda_do_alto", "vila_da_ilha", "arena_das_cinzas"]:
		if so != "" and not so.contains(id):
			continue
		await _ir(id)
		await _f(70)
		var c := current_scene
		var pv: Node = null
		for n in get_nodes_in_group("ponto_viagem"):
			if is_instance_valid(n) and n.pronto:
				pv = n
		if c.get("zoom") != null:
			c.zoom = 0.8
		await _f(20)
		await _foto("%s_ponto_de_viagem" % id)
		if pv:
			pv.abrir_mapa()
			await _f(40)
			await _foto("%s_mapa_sobreposto" % id)
			viajante.fechar_mapa()
			await _f(4)
	if so != "" and not so.contains("ui"):
		return
	# 2. a tela do mapa: começo (só o hub visitado), depois de explorar, dev
	Viagem.visitadas = {"porto_velho": true}
	change_scene_to_file(Viagem.MAPA)
	await _f(30)
	var m = current_scene
	m.area_atual = "porto_velho"
	m._atualizar()
	for sel in ["porto_velho", "vila_orcs", "criptas_de_cinzalta", "minas_da_cinza"]:
		m.selecionar(sel)
		await _f(30)
		await _foto("mapa_ui_%s" % sel)
	m.ilhas["cidade_fantasma"].hover = true
	m.selecionar("cidade_fantasma")
	await _f(30)
	await _foto("mapa_ui_hover_cidade_fantasma")
	m.ilhas["cidade_fantasma"].hover = false
	m.viajar_para("criptas_de_cinzalta")   # bloqueada: treme + aviso
	await _f(10)
	await _foto("mapa_ui_bloqueada_aviso")
	await _f(60)
	for k in Registro.ids():
		Viagem.visitadas[k] = true
	m.area_atual = "cidade_fantasma"
	m._atualizar()
	m.selecionar("fenda_cronal")
	await _f(30)
	await _foto("mapa_ui_tudo_liberado")
	# animação de viagem no meio
	Viagem.animacao_rapida = false
	m.viajar_para("fenda_cronal")
	await _f(40)
	await _foto("mapa_ui_viajando")

func _tour() -> void:
	# ~20 s: Porto Velho -> Vila dos Orcs -> Cidade Fantasma -> Criptas -> Estação
	root.size = Vector2i(1024, 576)
	await _ir("porto_velho")
	await _f(60)
	var rota := [["vila_orcs", 2], ["cidade_fantasma", 1], ["criptas_de_cinzalta", 1], ["estacao_depois_de_ontem", 2]]
	for passo in rota:
		_tecla(KEY_M)
		await _f(18)
		var m: Control = viajante.mapa if viajante.mapa_aberto_agora() else null
		if m == null:
			continue
		var alvo: String = passo[0]
		var i: int = m.ordem.find(m.selecionada)
		var j: int = m.ordem.find(alvo)
		var direcao := KEY_RIGHT if j >= i else KEY_LEFT
		var n := absi(j - i)
		var passos := 0
		while m.selecionada != alvo and passos < 12:
			_tecla(direcao)
			passos += 1
			await _f(9 if n <= 3 else 5)
		await _f(14)
		_tecla(KEY_ENTER)
		await _chegar(alvo)
		await _f(40 + int(passo[1]) * 10)

## um trecho curto do vídeo (para gravar em partes): HUB_TOUR_SEG="de>para" [HUB_TOUR_VISITADAS="a,b"]
func _segmento(seg: String) -> void:
	var partes := seg.split(">")
	var de := partes[0]
	var alvo := partes[1]
	for v in OS.get_environment("HUB_TOUR_VISITADAS").split(",", false):
		Viagem.visitadas[v] = true
	await _ir(de)
	await _f(45)
	print("[hub_captura] INICIO_FRAME ", Engine.get_frames_drawn())
	await _f(20)
	_tecla(KEY_M)
	await _f(24)
	var m: Control = viajante.mapa if viajante.mapa_aberto_agora() else null
	if m == null:
		push_error("mapa não abriu")
		return
	var i: int = m.ordem.find(m.selecionada)
	var j: int = m.ordem.find(alvo)
	var direcao := KEY_RIGHT if j >= i else KEY_LEFT
	var passos := 0
	while m.selecionada != alvo and passos < 12:
		_tecla(direcao)
		passos += 1
		await _f(8)
	await _f(20)
	_tecla(KEY_ENTER)
	await _chegar(alvo)
	await _f(60)
	print("[hub_captura] FIM_FRAME ", Engine.get_frames_drawn())
