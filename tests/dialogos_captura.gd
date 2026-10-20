extends SceneTree
## Captura da caixa de dialogo na cena demo (precisa de tela; no box: xvfb-run).
## godot --path . -s res://tests/dialogos_captura.gd -- <saida.png> <npc_id> <n_falas>
const CenaDemo = preload("res://scenes/dialogos/demo_dialogos.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(40.0).timeout.connect(func(): quit(1))
	var args := OS.get_cmdline_user_args()
	var saida := args[0] if args.size() > 0 else "user://dialogo.png"
	var id := args[1] if args.size() > 1 else "arquimago"
	var avancos := int(args[2]) if args.size() > 2 else 0
	var demo = CenaDemo.instantiate()
	root.add_child(demo)
	current_scene = demo
	for i in 10:
		await process_frame
	var npc
	for n in get_nodes_in_group("npc_conversavel"):
		if n.npc_id == id:
			npc = n
	demo.jogador.global_position = npc.global_position + Vector3(0.9, 0.05, 1.1)
	for i in 20:
		await physics_frame
	demo.dialogos.tecla_e()
	var caixa = demo.dialogos.caixa
	for k in avancos:
		await create_timer(0.3).timeout
		caixa.texto.skip_typing()
		await process_frame
		if caixa.esperando:
			caixa.esperando = false
			caixa.proxima(caixa.linha.next_id)
	await create_timer(2.5).timeout
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(saida)
	print("captura salva: ", saida)
	quit()
