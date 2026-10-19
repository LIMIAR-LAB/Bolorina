extends SceneTree
## Icones pixel-art da barra: todos os 9 slots carregam PNG 16x16 e a barra e capturada
## em docs/inventario-icones.png (recorte da parte de baixo da tela, ampliado 2x).
var checks := 0
var failures := 0
func check(ok: bool, t: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + t)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_captura.json")
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	if FileAccess.file_exists("user://ilha_captura.json"):
		DirAccess.remove_absolute("user://ilha_captura.json")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 150:
		await process_frame
		if jogo.atual and jogo.atual.get("ui"):
			break
	var f = jogo.atual
	if f == null:
		push_error("fazenda nao carregou"); quit(1); return
	var ui = f.ui
	var ids := []
	var com_textura := 0
	var tamanhos := {}
	for p in ui.caixas:
		for ch in p.get_children():
			if ch.get("pixel") != null:
				ids.append(ch.id)
				var t: Texture2D = ch.textura_icone(ch.id)
				if t != null:
					com_textura += 1
					tamanhos[str(t.get_size())] = true
	check(ids.size() == 9, "9 slots com icone (%s)" % str(ids))
	check(com_textura == 9, "todos com PNG pixel-art (%d/9)" % com_textura)
	check(tamanhos.size() == 1 and tamanhos.has(str(Vector2(16, 16))), "tamanho consistente 16x16 %s" % str(tamanhos.keys()))
	await create_timer(1.0).timeout
	ui.selecionar(4)
	await process_frame
	await process_frame
	var img: Image = f.get_viewport().get_texture().get_image()
	var h := img.get_height()
	var w := img.get_width()
	var y0 := int(h * (900.0 - 63 - 82 - 40) / 900.0)
	var rec := img.get_region(Rect2i(int(w * 0.18), y0, int(w * 0.64), h - y0))
	rec.resize(rec.get_width() * 2, rec.get_height() * 2, Image.INTERPOLATE_NEAREST)
	rec.save_png(ProjectSettings.globalize_path("res://docs/inventario-icones.png"))
	img.save_png(ProjectSettings.globalize_path("res://docs/inventario-icones-tela.png"))
	print("INFO salvou docs/inventario-icones.png")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
