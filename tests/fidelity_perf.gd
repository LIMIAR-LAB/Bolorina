extends SceneTree
## Desempenho da cena de fidelidade (fase do docs/fidelidade-camera.json), 1600x900:
## tempo de render CPU/GPU medio com efeitos ligados e desligados + draw calls.
func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func medir(n: int) -> Dictionary:
	var vp := root.get_viewport_rid()
	var cpu := 0.0
	var gpu := 0.0
	var frame := 0.0
	var draws := 0.0
	for i in n:
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		frame += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return {"cpu_ms": snappedf(cpu/n,0.01), "gpu_ms": snappedf(gpu/n,0.01), "process_ms": snappedf(frame/n,0.01), "draw_calls": roundi(draws/n)}

func run() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var game = load("res://fidelity_village.tscn").instantiate()
	game.camera_travada = true
	root.add_child(game)
	game.demo_mode = true
	await frames(120)
	var on := await medir(240)
	var result := {"fase": game.config.get("fase"), "modo": game.config.get("modo"), "efeitos_ligados": on}
	if game.efeitos:
		game.efeitos.definir_todos(false)
		await frames(30)
		result["efeitos_desligados"] = await medir(240)
		game.efeitos.definir_todos(true)
	print("PERF ", JSON.stringify(result))
	var f := FileAccess.open("res://docs/fid-perf-fase%s.json" % str(game.config.get("fase")), FileAccess.WRITE)
	f.store_string(JSON.stringify(result, " "))
	f.close()
	game.queue_free()
	await process_frame
	quit()