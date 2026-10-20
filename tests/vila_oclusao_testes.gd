extends SceneTree
## Oclusao das casas + patamar de rocha: telhado desbota com a Vale sob/atras da casa e volta ao sair;
## dica "E: entrar na casa" some ao se afastar. OCL_CAP=1 grava docs/casas/depois-*.png
var checks := 0
var failures := 0
var v
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + text)
func _init() -> void:
	call_deferred("_run")
func fr(n: int) -> void:
	for i in n:
		await process_frame
func foto(nome: String) -> void:
	if OS.get_environment("OCL_CAP") != "1":
		return
	await fr(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/casas"))
	img.save_png(ProjectSettings.globalize_path("res://docs/casas/depois-%s.png" % nome))
	print("INFO captura docs/casas/depois-%s.png" % nome)
func ir(p: Vector3) -> void:
	v.player.position = Vector3(p.x, v.vila.altura(p.x, p.z) + 0.4, p.z)
	v.player.velocity = Vector3.ZERO
	v.interior_mudou()
	await create_timer(1.0).timeout
func area(nome: String) -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_oclusao_teste.json")
	OS.set_environment("ILHA_AREA", nome)
	OS.set_environment("ILHA_SPAWN", "da_fazenda" if nome == "vila" else "inicio")
	if FileAccess.file_exists("user://ilha_oclusao_teste.json"):
		DirAccess.remove_absolute("user://ilha_oclusao_teste.json")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 300:
		await process_frame
		if jogo.atual and jogo.atual.get("oclusao") != null and jogo.atual.oclusao != null:
			break
	v = jogo.atual
	await create_timer(0.8).timeout
	var oc = v.oclusao
	var it = v.interiores
	check(oc != null and oc.casas.size() == it.casas.size() and it.casas.size() > 0, "%s: oclusao em todas as casas com interior (%d)" % [nome, it.casas.size()])
	var malhas_ok := true
	for d in oc.casas:
		if d.malhas.size() < 6: malhas_ok = false
	check(malhas_ok, "%s: telhado de cada casa identificado (%s malhas)" % [nome, str(oc.casas.map(func(d): return d.malhas.size()))])
	for i in it.casas.size():
		var c: Node3D = it.casas[i]
		await ir(c.to_global(Vector3(0, 0, 9.0)))
		check(oc.opacidade(i) > 0.99, "%s casa %d: longe -> telhado opaco" % [nome, i])
		await ir(c.to_global(Vector3(0.6, 0, -3.4)))
		check(oc.opacidade(i) < 0.3, "%s casa %d: Vale atras da casa -> telhado desbotado (%.2f)" % [nome, i, oc.opacidade(i)])
		if i == it.casas.size() - 1: await foto("%s-atras-casa%d" % [nome, i])
		await ir(it.porta_fora(i))
		check(oc.opacidade(i) < 0.3, "%s casa %d: Vale na porta (sob o alpendre) -> desbotado" % [nome, i])
		await ir(c.to_global(Vector3(0, 0, 9.0)))
		check(oc.opacidade(i) > 0.99, "%s casa %d: saiu -> telhado volta" % [nome, i])
		check(String(v.message.text) != "E: entrar na casa", "%s casa %d: dica da porta some ao se afastar" % [nome, i])
	jogo.queue_free()
	await fr(3)

func _run() -> void:
	await area("vila")
	# patamar de rocha a oeste da vila (laje listrada da captura do usuario)
	await area("fazenda")
	OS.set_environment("ILHA_AREA", "vila")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 300:
		await process_frame
		if jogo.atual and jogo.atual.get("oclusao") != null and jogo.atual.oclusao != null:
			break
	v = jogo.atual
	await create_timer(0.8).timeout
	await ir(Vector3(-32.4, 0, -16.4))
	await foto("patamar")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
