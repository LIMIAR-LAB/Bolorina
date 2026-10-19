extends SceneTree
## Sondagem: custo de GPU de cada recurso da arena (liga/desliga um por vez).
func _initialize() -> void:
	call_deferred("run")

func medir(n: int) -> String:
	var vp := root.get_viewport_rid()
	var gpu := 0.0
	var cpu := 0.0
	var proc := 0.0
	for i in n:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return "gpu %.2f cpu %.2f proc %.2f draws %d" % [gpu / n, cpu / n, proc / n, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]

func run() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	for i in 60:
		await process_frame
	print("INFO base ", await medir(90))
	a.sol.shadow_enabled = false
	print("INFO sem_sombra ", await medir(90))
	a.sol.shadow_enabled = true
	a.ambiente.glow_enabled = false
	print("INFO sem_glow ", await medir(90))
	a.ambiente.glow_enabled = true
	a.ambiente.fog_enabled = false
	print("INFO sem_fog ", await medir(90))
	a.ambiente.fog_enabled = true
	var planos := []
	for c in a.get_children():
		if c is MeshInstance3D and c.mesh is PlaneMesh and c.mesh.size.x > 100:
			c.visible = false
			planos.append(c)
	print("INFO sem_planos_nevoa ", await medir(90))
	for c in planos:
		c.visible = true
	a.ambiente.adjustment_enabled = false
	print("INFO sem_ajuste_cor ", await medir(90))
	a.ambiente.adjustment_enabled = true
	root.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	print("INFO sem_msaa ", await medir(90))
	root.get_viewport().msaa_3d = Viewport.MSAA_2X
	for l in a.fogo_luzes:
		l.visible = false
	print("INFO sem_luzes_fogo ", await medir(90))
	for l in a.fogo_luzes:
		l.visible = true
	print("INFO luzes ", a.fogo_luzes.size(), " vsync ", DisplayServer.window_get_vsync_mode(), " fps ", Engine.get_frames_per_second())
	a.queue_free()
	await process_frame
	quit()
