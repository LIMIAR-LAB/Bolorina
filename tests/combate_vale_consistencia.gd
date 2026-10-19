extends SceneTree
## A Vale do combate e a mesma da vila: idle/corrida com os mesmos PNGs V6, golpes na paleta V6, mesma escala.
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func cores(path: String) -> Dictionary:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var r := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				r[c.to_html(false)] = true
	return r

func run() -> void:
	var arena = load("res://combat_arena.tscn").instantiate()
	arena.set("modo_teste", true)
	root.add_child(arena)
	for i in 30:
		await process_frame
	var j = arena.jogador
	var sf: SpriteFrames = j.sprite.sprite_frames
	var vila_vale = load("res://scripts/modular/vale_fidelidade.gd").new()
	vila_vale.preparar(1.48)
	var vf: SpriteFrames = vila_vale.sprite_frames
	var iguais := 0
	var total := 0
	for d in ["south", "east", "north-east", "south-west"]:
		for a in ["idle_", "run_"]:
			total += 1
			if sf.has_animation(a+d) and vf.has_animation(a+d) and sf.get_frame_texture(a+d, 0).resource_path == vf.get_frame_texture(a+d, 0).resource_path:
				iguais += 1
	check(iguais == total, "Idle/corrida do combate usam os mesmos PNGs da Vale V6 da vila (%d/%d)" % [iguais, total])
	check(j.pasta_golpes().ends_with("vale_combate_v6pal/"), "Golpes carregados da pasta remapeada (%s)" % j.pasta_golpes())
	var pal := {}
	for d in ["south", "east", "north", "west", "south-east", "south-west", "north-east", "north-west"]:
		pal.merge(cores("res://art/characters/original_vale_v6/rotations/%s.png" % d))
		for f in 8:
			pal.merge(cores("res://art/characters/original_vale_v6/run/%s/%03d.png" % [d, f]))
	var dentro := 0
	var n := 0
	for mov in ["slash_combo", "hit"]:
		var c := cores("res://art/characters/vale_combate_v6pal/%s/%s_south-east_sheet.png" % [mov, mov])
		var c0 := cores("res://art/characters/vale_combate_gamelab/%s/%s_south-east_sheet.png" % [mov, mov])
		var em_pal := 0
		for k in c:
			if pal.has(k):
				em_pal += 1
		print("INFO %s: %d cores (Gamelab %d), %d na paleta V6" % [mov, c.size(), c0.size(), em_pal])
		dentro += em_pal
		n += c.size()
	check(n > 0 and float(dentro) / n > 0.85, "Cores dos golpes na paleta V6: %.0f%%" % (100.0 * dentro / maxf(1, n)))
	check(absf(j.PX_COMBATE * 45.0 - j.PX_IDLE * 48.0) < 0.001, "Mesma altura do corpo idle (48 px) x golpe (45 px)")
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	vila_vale.free()
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
