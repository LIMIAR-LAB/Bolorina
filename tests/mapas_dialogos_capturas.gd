extends SceneTree
## Capturas dos 3 mapas com uma caixa de dialogo aberta (precisa de janela/GPU, nao roda em --headless).
## Rodar:  godot --path . -s res://tests/mapas_dialogos_capturas.gd -- /pasta/de/saida [filtro_do_nome]
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const CAPTURAS := [
	{"cena": "res://scenes/vila_grande/vila_grande.tscn", "npc": "mira", "arquivo": "porto_velho_mira.png", "falas": 1},
	{"cena": "res://scenes/vila_orcs/vila_orcs.tscn", "npc": "lider_orc", "arquivo": "vila_orcs_grusha.png", "falas": 1},
	{"cena": "res://scenes/cidade_fantasma/cidade_fantasma.tscn", "npc": "condessa", "arquivo": "cidade_fantasma_condessa.png", "falas": 1},
	{"cena": "res://scenes/vila_grande/vila_grande.tscn", "npc": "dragao", "arquivo": "porto_velho_dragao_doca.png", "falas": 1},
]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var pasta := args[0] if args.size() > 0 else "user://"
	DirAccess.make_dir_recursive_absolute(pasta)
	root.get_window().size = Vector2i(1600, 900)
	var so := args[1] if args.size() > 1 else ""
	for c in CAPTURAS:
		if so != "" and not String(c.arquivo).contains(so):
			continue
		Estado.reiniciar_global()
		var mapa: Node3D = load(c.cena).instantiate()
		root.add_child(mapa)
		for i in 20:
			await process_frame
		var npc = mapa.npc(c.npc)
		var j: CharacterBody3D = mapa.jogador
		# jogadora diante do morador, no lado da camera
		j.global_position = npc.global_position + Vector3(1.2, 0.3, 1.2)
		for i in 20:
			await physics_frame
		mapa.set_physics_process(false)
		var alvo: Vector3 = npc.global_position + Vector3(0.6, 0, 0.6)
		mapa._mirar(Vector3(alvo.x, 0, alvo.z), 15.0)
		mapa.dialogos.conversar(npc)
		var caixa = mapa.dialogos.caixa
		for i in 10:
			await process_frame
		if caixa.texto.is_typing:
			caixa.texto.skip_typing()
		for i in 30:
			await process_frame
		var arq: String = pasta.path_join(c.arquivo)
		root.get_viewport().get_texture().get_image().save_png(arq)
		print("[capturas] ", arq)
		mapa.queue_free()
		for i in 5:
			await process_frame
	quit(0)
