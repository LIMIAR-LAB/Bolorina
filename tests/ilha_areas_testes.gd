extends SceneTree
## Transicoes Fazenda <-> Vila <-> Arena; save island_v1 intacto.
const SAVE_V1 := "user://island_v1.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var md5 := ""
	if FileAccess.file_exists(SAVE_V1):
		md5 = FileAccess.get_md5(SAVE_V1)
	OS.set_environment("ILHA_SAVE", "user://ilha_areas_teste.json")
	OS.set_environment("ILHA_AREA", "fazenda")
	if FileAccess.file_exists("user://ilha_areas_teste.json"):
		DirAccess.remove_absolute("user://ilha_areas_teste.json")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	var ok := 0
	var falhas: Array[String] = []
	for i in 240:
		await process_frame
		if jogo.nome == "fazenda" and jogo.atual and not jogo.ocupado:
			break
	if jogo.nome == "fazenda" and not jogo.ocupado: ok += 1; print("OK  inicia na fazenda")
	else: falhas.append("inicia na fazenda (nome=%s ocupado=%s)" % [jogo.nome, jogo.ocupado])
	# F10 -> vila
	jogo.ir("vila", "da_fazenda")
	for i in 300:
		await process_frame
		if jogo.nome == "vila" and not jogo.ocupado and jogo.atual:
			break
	if jogo.nome == "vila": ok += 1; print("OK  fazenda->vila")
	else: falhas.append("fazenda->vila (nome=%s ocupado=%s)" % [jogo.nome, jogo.ocupado])
	# F11 -> arena
	if jogo.nome == "vila":
		jogo.ir("arena", "da_vila")
		for i in 300:
			await process_frame
			if jogo.nome == "arena" and not jogo.ocupado and jogo.atual:
				break
		if jogo.nome == "arena": ok += 1; print("OK  vila->arena")
		else: falhas.append("vila->arena")
		# volta
		if jogo.nome == "arena":
			jogo.ir("vila", "da_arena")
			for i in 300:
				await process_frame
				if jogo.nome == "vila" and not jogo.ocupado:
					break
			if jogo.nome == "vila": ok += 1; print("OK  arena->vila")
			else: falhas.append("arena->vila")
			jogo.ir("fazenda", "da_vila")
			for i in 300:
				await process_frame
				if jogo.nome == "fazenda" and not jogo.ocupado:
					break
			if jogo.nome == "fazenda": ok += 1; print("OK  vila->fazenda")
			else: falhas.append("vila->fazenda")
	var md5b := ""
	if FileAccess.file_exists(SAVE_V1):
		md5b = FileAccess.get_md5(SAVE_V1)
	if md5 == md5b: ok += 1; print("OK  island_v1 intacto")
	else: falhas.append("island_v1")
	print("--- ilha_areas: %d ok, %d falhas ---" % [ok, falhas.size()])
	for x in falhas: print("  - ", x)
	quit(0 if falhas.is_empty() else 1)
