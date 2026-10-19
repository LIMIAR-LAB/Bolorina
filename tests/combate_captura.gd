extends SceneTree
## Capturas do prototipo de combate: 1) combo (finalizador + telegrafo de outro orc),
## 2) especial (anel de fogo), 3) sala limpa (bencao + porta aberta). Saida: docs/combate-captura-N.png
var a
var j
func _initialize() -> void:
	call_deferred("run")

func quadros(n: int) -> void:
	for i in n:
		await process_frame

func fis(n: int) -> void:
	for i in n:
		await physics_frame

func salvar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/" + nome))
	print("INFO captura ", nome)

func run() -> void:
	a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	await quadros(10)
	j = a.jogador
	a.hitstop_ativo = false
	j.invulneravel_ate = 1e9   # so para a captura: nao ser interrompido
	a.tremor_ativo = false
	j.position = Vector3(0.5, 0, 1.0)
	var e1 = a.gerar_inimigo(Vector3(2.4, 0, 0.2))
	var e2 = a.gerar_inimigo(Vector3(-2.2, 0, -1.6))
	var e3 = a.gerar_inimigo(Vector3(1.2, 0, 3.6), true)
	e1.alvo = null
	await fis(50)
	e2.alvo = j
	e3.alvo = j
	# combo ate o 3o golpe contra e1
	var dir: Vector3 = (e1.global_position - j.global_position).normalized()
	j.pedir_ataque(dir)
	await fis(6)
	j.pedir_ataque(dir)
	await fis(10)
	j.pedir_ataque(dir)
	var guarda := 0
	while not (j.estado == "ataque" and j.combo_i == 2 and j.golpe_aplicado) and guarda < 120:
		await physics_frame
		guarda += 1
	await fis(2)
	await salvar("combate-captura-1.png")
	await fis(40)
	for e in [e1, e2, e3]:
		if is_instance_valid(e):
			e.alvo = null
	j.pedir_especial()
	guarda = 0
	while not j.golpe_aplicado or j.estado != "especial":
		await physics_frame
		guarda += 1
		if guarda > 120:
			break
	await fis(7)
	await salvar("combate-captura-2.png")
	await fis(30)
	a.onda = a.ondas_total - 1
	for e in a.inimigos.duplicate():
		e.receber_golpe(999, Vector3.ZERO, true)
	a._mudar_sala("combate")
	guarda = 0
	while a.estado_sala != "recompensa" and guarda < 600:
		await physics_frame
		guarda += 1
	j.position = Vector3(1.6, 0, 1.6)
	j._virar(-a.cam_cima)
	await fis(30)
	await salvar("combate-captura-3.png")
	a.queue_free()
	await process_frame
	quit()
