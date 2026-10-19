extends SceneTree
## Desempenho do prototipo de combate a 1600x900: luta real com o piloto automatico
## (orcs, particulas, numeros, VFX), tempo medio de render CPU/GPU, processo e draw calls.
func _initialize() -> void:
	call_deferred("run")

func medir(n: int, arena) -> Dictionary:
	var vp := root.get_viewport_rid()
	var cpu := 0.0
	var gpu := 0.0
	var proc := 0.0
	var draws := 0.0
	var pior := 0.0
	var inim := 0.0
	for i in n:
		await process_frame
		var c := RenderingServer.viewport_get_measured_render_time_cpu(vp)
		var g := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += c
		gpu += g
		pior = maxf(pior, maxf(c, g))
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		inim += arena.inimigos.size()
	return {"cpu_ms": snappedf(cpu / n, 0.01), "gpu_ms": snappedf(gpu / n, 0.01), "pior_quadro_ms": snappedf(pior, 0.01), "process_ms": snappedf(proc / n, 0.01), "draw_calls": roundi(draws / n), "inimigos_medio": snappedf(inim / n, 0.1)}

func run() -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var arena = load("res://combat_arena.tscn").instantiate()
	root.add_child(arena)
	arena.piloto = true
	for i in 90:
		await process_frame
	var ocioso := await medir(60, arena)
	for i in 60:
		await process_frame
	var luta := await medir(420, arena)
	var res := {"resolucao": "1600x900", "inicio_sala": ocioso, "luta_piloto_automatico": luta, "stats": arena.stats, "jogador": arena.jogador.stats}
	print("PERF ", JSON.stringify(res))
	var f := FileAccess.open("res://docs/combate-perf.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	f.close()
	Engine.time_scale = 1.0
	arena.queue_free()
	await process_frame
	quit()
