extends SceneTree
## Captura do Raio de Adamantium: docs/combate-raio.png (janela 1600x900).
var a
var j
func _initialize() -> void:
	call_deferred("run")

func fis(n: int) -> void:
	for i in n:
		await physics_frame

func run() -> void:
	a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	await fis(10)
	j = a.jogador
	a.hitstop_ativo = false
	a.lenta_ativa = false
	j.invulneravel_ate = 1e9
	j.position = Vector3(-6.5, 0, 2.0)
	var alvos := [a.gerar_inimigo(Vector3(-2.5, 0, 0.6)), a.gerar_inimigo(Vector3(0.5, 0, -0.6), true), a.gerar_inimigo(Vector3(3.5, 0, -1.8))]
	for e in alvos:
		e.alvo = null
	await fis(70)
	j.energia = j.energia_max
	j.pedir_transformar()
	await fis(40)
	j._virar(-a.cam_cima + a.cam_direita * 0.4)
	await fis(20)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/combate-forma.png"))
	var dir: Vector3 = (Vector3(4, 0, -2.4) - j.global_position).normalized()
	j.pedir_raio(dir)
	await fis(55)
	j.soltar_raio()
	await fis(16)
	a.tremor = 0.0
	a.tremor_ativo = false
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/combate-raio.png"))
	print("INFO captura combate-raio.png estado ", j.estado, " carga ", j.carga)
	await fis(30)
	quit()
