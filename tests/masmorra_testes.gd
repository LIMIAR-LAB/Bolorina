extends SceneTree
## Masmorra procedural: gerador deterministico/conexo, saida longe do inicio, tesouro, andares
## maiores; cena dungeon_teste.tscn monta salas, orcs, props, escada e portal. MAS_CAP=1 grava docs/masmorra-teste.png
const Gen = preload("res://scripts/masmorra/masmorra_gerador.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + text)
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var todos_conexos := true
	var saida_ok := true
	var tesouros := 0
	var n := 0
	var tam := {1: 0, 4: 0}
	for sem in range(1, 41):
		for andar in [1, 2, 3, 4]:
			var m: Dictionary = Gen.gerar(sem, andar)
			n += 1
			if not Gen.conexo(m): todos_conexos = false
			if m.saida == m.inicio or m.salas[m.saida].tipo != "saida": saida_ok = false
			for c in m.salas:
				if m.salas[c].tipo == "tesouro":
					tesouros += 1
					break
			if andar in tam: tam[andar] += m.salas.size()
	check(todos_conexos, "%d masmorras geradas, todas conexas" % n)
	check(saida_ok, "saida sempre numa sala diferente do inicio")
	check(tesouros >= n * 0.9, "sala de tesouro em %d/%d" % [tesouros, n])
	check(tam[4] > tam[1], "andar 4 maior que andar 1 (%d vs %d salas somadas)" % [tam[4], tam[1]])
	var a: Dictionary = Gen.gerar(77, 2)
	var b: Dictionary = Gen.gerar(77, 2)
	check(str(a) == str(b), "mesma semente = mesma masmorra")
	check(str(a) != str(Gen.gerar(78, 2)), "semente diferente = masmorra diferente")
	var inim := 0
	for c in a.salas:
		inim += a.salas[c].inimigos
	check(inim > 0, "orcs distribuidos (%d no andar 2)" % inim)
	# cena
	OS.set_environment("MASMORRA_SEMENTE", "77")
	var cena = load("res://dungeon_teste.tscn").instantiate()
	root.add_child(cena)
	for i in 10:
		await process_frame
	check(cena.mapa.salas.size() >= 8 and cena.orcs.size() > 0, "cena montou %d salas e %d orcs" % [cena.mapa.salas.size(), cena.orcs.size()])
	check(cena.escada != Vector3.ZERO and cena.portal != Vector3.ZERO, "escada e portal de volta existem")
	var andar0: int = cena.andar
	cena.player.global_position = cena.escada + Vector3(0, 0.3, 0)
	for i in 6:
		await physics_frame
	check(cena.andar == andar0 + 1, "pisar na escada desce para o andar %d" % cena.andar)
	if OS.get_environment("MAS_CAP") == "1":
		for i in 6:
			await process_frame
		var img: Image = cena.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/masmorra-teste.png"))
		print("INFO captura docs/masmorra-teste.png")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
