extends SceneTree
## Capturas dos moradores com rosto e corpo (precisa de janela/GPU, nao roda em --headless).
## Rodar:  godot --path . -s res://tests/rostos_capturas.gd -- /pasta/de/saida [filtro_do_nome]
## Carrega cada mapa uma vez e tira: visao do grupo de moradores, closes e uma conversa aberta (por ultimo).
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const MAPAS := [
	{"cena": "res://scenes/vila_grande/vila_grande.tscn", "fotos": [
		{"arquivo": "porto_velho_praca.png", "perto_de": "crianca_praca", "raio": 16.0, "tam": 17.0},
		{"arquivo": "porto_velho_close.png", "centro": ["crianca_praca", "gato"], "tam": 7.0},
		{"arquivo": "porto_velho_dragao_doca.png", "centro": ["dragao"], "tam": 12.0},
		{"arquivo": "dialogo_ferreiro.png", "conversa": "ferreiro"},
	]},
	{"cena": "res://scenes/vila_orcs/vila_orcs.tscn", "fotos": [
		{"arquivo": "vila_orcs_grusha.png", "perto_de": "lider_orc", "raio": 14.0, "tam": 17.0},
		{"arquivo": "vila_orcs_close.png", "centro": ["lider_orc"], "tam": 6.5},
		{"arquivo": "dialogo_grusha.png", "conversa": "lider_orc"},
	]},
	{"cena": "res://scenes/cidade_fantasma/cidade_fantasma.tscn", "fotos": [
		{"arquivo": "cidade_fantasma.png", "perto_de": "condessa", "raio": 16.0, "tam": 18.0},
		{"arquivo": "cidade_fantasma_close.png", "centro": ["espectro_sineiro"], "tam": 6.5},
		{"arquivo": "dialogo_espectro.png", "conversa": "espectro_sineiro"},
	]},
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta := args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(pasta)
	root.get_window().size = Vector2i(1600, 900)
	var so := args[1] if args.size() > 1 else ""
	for m in MAPAS:
		var fotos: Array = m.fotos.filter(func(f): return so == "" or String(f.arquivo).contains(so))
		if fotos.is_empty():
			continue
		Estado.reiniciar_global()
		var mapa: Node3D = load(m.cena).instantiate()
		root.add_child(mapa)
		for i in 20:
			await process_frame
		for n in mapa.npcs:
			print("[capturas] npc ", n.npc_id, " ", n.global_position, " ", n.tipo_visual)
		for f in fotos:
			if f.has("conversa"):
				await _conversa(mapa, String(f.conversa))
			else:
				await _vista(mapa, f)
			var arq: String = pasta.path_join(f.arquivo)
			root.get_viewport().get_texture().get_image().save_png(arq)
			print("[capturas] ", arq)
		mapa.queue_free()
		for i in 5:
			await process_frame
	quit(0)

func _vista(mapa: Node3D, f: Dictionary) -> void:
	var pts: Array = []
	if f.has("perto_de"):
		var semente = mapa.npc(String(f.perto_de))
		for n in mapa.npcs:
			if n.global_position.distance_to(semente.global_position) <= float(f.raio):
				pts.append(n.global_position)
	else:
		for id in f.centro:
			var n = mapa.npc(String(id))
			if n:
				pts.append(n.global_position)
	var soma := Vector3.ZERO
	for p in pts:
		soma += p
	var alvo := soma / maxf(1, pts.size())
	var j: CharacterBody3D = mapa.jogador
	j.global_position = alvo + Vector3(2.0, 0.3, 2.4)
	mapa.set_physics_process(true)
	for i in 10:
		await physics_frame
	mapa.set_physics_process(false)
	mapa._mirar(Vector3(alvo.x, 0, alvo.z), float(f.tam))
	for i in 20:
		await process_frame

func _conversa(mapa: Node3D, id: String) -> void:
	var npc = mapa.npc(id)
	var j: CharacterBody3D = mapa.jogador
	j.global_position = npc.global_position + Vector3(1.2, 0.3, 1.2)
	mapa.set_physics_process(true)
	for i in 20:
		await physics_frame
	mapa.set_physics_process(false)
	var alvo: Vector3 = npc.global_position + Vector3(0.6, 0, 0.6)
	mapa._mirar(Vector3(alvo.x, 0, alvo.z), 12.0)
	mapa.dialogos.conversar(npc)
	var caixa = mapa.dialogos.caixa
	for i in 10:
		await process_frame
	if caixa.texto.is_typing:
		caixa.texto.skip_typing()
	for i in 30:
		await process_frame
