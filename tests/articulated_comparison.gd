extends SceneTree
## Testes do personagem articulado experimental na cena de comparacao.
## Executar COM janela (renderizacao real), por exemplo:
##   Godot --path . --script tests/articulated_comparison.gd
## Em modo --headless as capturas e medicoes de GPU sao puladas.
## Capturas: docs/articulado-*.png. Recortes brutos: work/articulado_recortes.
## Resultados numericos: docs/articulado-resultados.json.
const SCENE := "res://articulated_comparison.tscn"
const CROPS := "C:/Users/tsmar/Documents/Codex/2026-10-18/referenced-chatgpt-conversation-this-is-an/work/articulado_recortes/"
var game
var rig
var checks := 0
var failures := 0
var results := {}
var headless := false

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func info(text: String) -> void:
	print("INFO " + text)

func _initialize() -> void:
	call_deferred("run")

func wait_frames(n: int) -> void:
	for i in n:
		await process_frame

func wait_physics(n: int) -> void:
	for i in n:
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	game._unhandled_key_input(event)

func settle() -> void:
	# Amostra o estado que sera desenhado (depois da atualizacao das pecas).
	if headless:
		await process_frame
		rig._update_parts()
	else:
		await RenderingServer.frame_pre_draw

func capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func screen_of(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point)

func run() -> void:
	headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(CROPS)
	var save_path := "user://island_v1.json"
	var save_existed := FileAccess.file_exists(save_path)
	var save_hash := FileAccess.get_md5(save_path) if save_existed else ""
	game = load(SCENE).instantiate()
	root.add_child(game)
	game.demo_mode = true
	game.ui_layer.visible = false
	await wait_frames(60)
	await wait_physics(10)
	rig = game.rig
	await test_structure()
	await test_toggle_and_parity()
	await test_speed()
	await test_directions()
	await test_watering()
	await test_axe()
	await test_regression_full_sprite()
	if not headless:
		await test_lighting()
		await test_direction_sheet()
		await test_performance()
	check(game.suppress_saves, "Cena de comparacao nao grava progresso")
	var exists_after := FileAccess.file_exists(save_path)
	check(exists_after == save_existed and (not exists_after or FileAccess.get_md5(save_path) == save_hash), "Save do jogador inalterado (existia: %s)" % save_existed)
	results["checks"] = checks
	results["failures"] = failures
	var file := FileAccess.open("res://docs/articulado-resultados.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

# ------------------------------------------------------------- estrutura
func test_structure() -> void:
	check(rig != null and rig.skeleton is Skeleton3D, "Personagem articulado usa Skeleton3D")
	check(rig.skeleton.get_bone_count() == 17, "Esqueleto com 17 ossos")
	var attached := 0
	for bone in rig.attachments:
		var a = rig.attachments[bone]
		if a is BoneAttachment3D and a.bone_name == bone and rig.skeleton.find_bone(bone) >= 0:
			attached += 1
	check(attached == 17, "Um BoneAttachment3D valido por osso")
	var parented := 0
	for part in rig.parts:
		if part.sprite.get_parent() is BoneAttachment3D:
			parented += 1
	check(parented == rig.parts.size() and rig.parts.size() == 18, "18 pecas de pixel art presas a BoneAttachment3D")
	var anims: PackedStringArray = rig.animator.get_animation_list()
	for name in ["idle","walk","run","tend","water","chop"]:
		check(anims.has(name), "Animacao esqueletica " + name)
	check(game.full_sprite.role == "original_apprentice", "Sprite completo comparado e o protagonista V4")
	check(absf(game.full_sprite.pixel_size-rig.PX) < 0.0001, "Densidade de pixel equivalente (sprite %.5f x pecas %.5f)" % [game.full_sprite.pixel_size, rig.PX])
	results["estrutura"] = {"ossos": rig.skeleton.get_bone_count(), "pecas": rig.parts.size(), "texturas": rig.textures.size()}

func test_toggle_and_parity() -> void:
	check(not game.articulated and game.full_sprite.visible and not rig.visible, "Inicia no sprite completo")
	check(game.mode_label.text.contains("SPRITE COMPLETO"), "Rotulo identifica sprite completo")
	var position: Vector3 = game.player.position
	var cam: Transform3D = game.camera.global_transform
	var anchor: Vector3 = game.camera_anchor.position
	var basis: Basis = game.camera.global_basis
	key(KEY_T)
	check(game.camera.global_transform.is_equal_approx(cam) and game.camera_anchor.position == anchor, "Alternar nao move camera nem enquadramento")
	await wait_frames(2)
	check(game.camera.global_basis.is_equal_approx(basis), "Orientacao da camera fixa apos alternar")
	check(game.articulated and rig.visible and not game.full_sprite.visible, "T ativa o articulado")
	check(game.mode_label.text.contains("ARTICULADO"), "Rotulo identifica articulado")
	check(game.player.position.distance_to(position) < 0.001, "Posicao preservada ao alternar")
	check(game.fill_light.get_parent() == game.player, "Luz de preenchimento compartilhada no corpo fisico")
	var same := true
	for part in rig.parts:
		var s: Sprite3D = part.sprite
		same = same and s.shaded == game.full_sprite.shaded and s.layers == game.full_sprite.layers
		same = same and s.modulate == game.full_sprite.modulate and s.material_override == null
		same = same and s.cast_shadow == game.full_sprite.cast_shadow and s.double_sided == game.full_sprite.double_sided
	check(same, "Mesmos parametros de luz/material/camada em todas as pecas")
	var extra_lights := 0
	for node in rig.find_children("*","Light3D",true,false):
		extra_lights += 1
	check(extra_lights == 0, "Nenhuma luz exclusiva no articulado")
	key(KEY_F6)
	await wait_frames(2)
	check(rig.parts[0].sprite.shaded == game.full_sprite.shaded and not game.full_sprite.shaded, "F6 afeta os dois modos igualmente")
	key(KEY_F6)
	await wait_frames(2)
	key(KEY_T)
	await wait_frames(2)
	check(not game.articulated and game.full_sprite.visible, "T retorna ao sprite completo")

# ------------------------------------------------------------- velocidade
func walk_distance(art: bool, input: Vector2, running: bool, frames: int) -> float:
	game.set_articulated(art)
	game.teleport(Vector3(0,0.4,2))
	await wait_physics(8)
	var start: Vector3 = game.player.position
	game.demo_running = running
	game.demo_input = input
	await wait_physics(frames)
	game.demo_input = Vector2.ZERO
	game.demo_running = false
	var end: Vector3 = game.player.position
	await wait_physics(10)
	return Vector2(end.x-start.x,end.z-start.z).length()

func test_speed() -> void:
	var a: float = await walk_distance(false, Vector2(0,-1), false, 60)
	var b: float = await walk_distance(true, Vector2(0,-1), false, 60)
	check(absf(a-b) < 0.01, "Mesma distancia caminhando: %.3f x %.3f m" % [a,b])
	var c: float = await walk_distance(false, Vector2(0,-1), true, 40)
	var d: float = await walk_distance(true, Vector2(0,-1), true, 40)
	check(absf(c-d) < 0.01, "Mesma distancia correndo: %.3f x %.3f m" % [c,d])
	results["velocidade"] = {"caminhada_60q": [a,b], "corrida_40q": [c,d]}

# ------------------------------------------------------------- direcoes
func test_directions() -> void:
	game.set_articulated(true)
	var report := {}
	var max_pivot_error := 0.0
	for i in 8:
		var expected: String = rig.DIRECTIONS[i]
		for running in [false,true]:
			game.teleport(Vector3(0,0.4,2))
			await wait_physics(4)
			game.demo_running = running
			game.demo_input = Vector2(cos(i*PI/4.0),sin(i*PI/4.0))
			var lowest := INF
			var highest_low := -INF
			var below := 0.0
			var slide := 0.0
			var slide_frames := 0
			var last_foot := ""
			var last_pos := Vector3.ZERO
			for f in 40:
				await settle()
				var floor_y: float = game.player.global_position.y
				var fr: Vector3 = rig.bone_position("foot_r")
				var fl: Vector3 = rig.bone_position("foot_l")
				var low_name := "foot_r" if fr.y <= fl.y else "foot_l"
				var low: Vector3 = fr if fr.y <= fl.y else fl
				var h := low.y-floor_y
				if f >= 12:
					lowest = minf(lowest,h)
					highest_low = maxf(highest_low,h)
					below = minf(below, minf(fr.y,fl.y)-floor_y)
					if low_name == last_foot and h < 0.01:
						slide += Vector2(low.x-last_pos.x,low.z-last_pos.z).length()
						slide_frames += 1
					for part in rig.parts:
						if part.mode in ["limb","boot","hand","view"] and part.sprite.visible:
							var a := screen_of(part.sprite.global_position)
							var b := screen_of(rig.bone_position_interpolated(part.bone))
							max_pivot_error = maxf(max_pivot_error, a.distance_to(b))
				last_foot = low_name
				last_pos = low
			game.demo_input = Vector2.ZERO
			var anim: String = rig.animator.current_animation
			var forward: Vector3 = -rig.body.global_basis.z
			var label := expected + (" correndo" if running else " caminhando")
			check(rig.facing_direction == expected and forward.dot(rig.world_direction(expected)) > 0.99, "Direcao " + label)
			check(anim == ("run" if running else "walk") and str(game.full_sprite.animation).begins_with("run_" if running else "walk_"), "Animacao equivalente em " + label)
			check(lowest > -0.012 and highest_low < 0.012 and below > -0.012, "Pe apoiado no chao em %s (min %.3f, max %.3f m)" % [label,lowest,highest_low])
			if not running:
				var head: Dictionary = rig.get_part("head")
				var view: Array = rig.VIEW_TEXTURE[expected]
				check(head.key == "head_" + view[0] and head.flip == view[1], "Vista desenhada da cabeca em " + expected)
				await check_layering(expected)
			var dt := 1.0/float(Engine.get_frames_per_second()) if Engine.get_frames_per_second() > 1 else 1.0/60.0
			report[label] = {"pe_min_m": lowest, "pe_apoio_max_m": highest_low, "deslize_pe_apoio_m_por_quadro": slide/maxf(1,slide_frames)}
	check(max_pivot_error < 2.0, "Pecas presas aos ossos na tela (erro max %.2f px)" % max_pivot_error)
	results["direcoes"] = report
	results["erro_pivo_px"] = max_pivot_error

func depth_of(part_name: String) -> float:
	# Maior = mais perto da camera.
	var sprite: Sprite3D = rig.get_part(part_name).sprite
	return sprite.global_position.dot(game.camera.global_basis.z)

func check_layering(direction: String) -> void:
	game.demo_input = Vector2.ZERO
	await wait_physics(20)
	var ok := depth_of("head") > depth_of("torso")
	var forward_h: Vector3 = rig.world_direction(direction)
	var cam_h: Vector3 = Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
	var dr: float = (rig.bone_position("upper_arm_r")-rig.global_position).dot(cam_h)
	var dl: float = (rig.bone_position("upper_arm_l")-rig.global_position).dot(cam_h)
	if absf(dr-dl) > 0.12:
		var near := "r" if dr > dl else "l"
		var far := "l" if near == "r" else "r"
		ok = ok and depth_of("upper_arm_"+near) > depth_of("torso") and depth_of("upper_arm_"+far) < depth_of("torso")
		ok = ok and depth_of("hand_"+near) > depth_of("lower_arm_"+near)
	ok = ok and depth_of("boot_r") > depth_of("shin_r") and depth_of("boot_l") > depth_of("shin_l")
	check(ok, "Sobreposicao de cabeca, bracos e botas em " + direction)

# ------------------------------------------------------------- interacoes
func floor_near(point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var hit = game._floor_at(space, point.x, point.z)
	return hit if hit != null else point

func track_tool(tool: String, duration: float, shot: String, shot_at: float) -> Dictionary:
	var elapsed := 0.0
	var max_err := 0.0
	var visible_frames := 0
	var image: Image = null
	var tool_tip := Vector3.ZERO
	while elapsed < duration:
		await settle()
		elapsed += get_root().get_process_delta_time()
		var part: Dictionary = rig.get_part(tool)
		if part.sprite.visible:
			visible_frames += 1
			var a := screen_of(part.sprite.global_position)
			var b := screen_of(rig.bone_position_interpolated("hand_r"))
			max_err = maxf(max_err, a.distance_to(b))
		if image == null and elapsed >= shot_at and not headless:
			image = await capture()
			tool_tip = rig.bone_position("hand_r")+(rig.bone_position("tool_r")-rig.bone_position("hand_r")).normalized()*0.45
	if image != null:
		image.save_png("res://docs/" + shot)
	return {"erro_px": max_err, "quadros_visiveis": visible_frames, "ponta": tool_tip}

func test_watering() -> void:
	game.set_articulated(true)
	var plot_index := 8
	var plot: Dictionary = game.farm.plots[plot_index]
	plot.stage = 0
	plot.watered = false
	game.farm.refresh()
	game.teleport(floor_near(plot.position+Vector3(0.78,0,0)))
	await wait_physics(10)
	game.zoom_target = 0.65
	await wait_frames(30)
	check(game.farm.nearest(game.player.position) == plot_index, "Articulado posicionado junto do canteiro")
	key(KEY_E)
	check(plot.stage == 1, "E planta pelo farm.interact() real no modo articulado")
	await wait_physics(50)
	key(KEY_R)
	check(plot.watered, "R rega pelo farm.interact() real no modo articulado")
	check(rig.current_action == "water", "Animacao de rega articulada iniciada")
	var to_plot: Vector3 = plot.position-game.player.position
	to_plot.y = 0
	check(rig.world_direction(rig.facing_direction).dot(to_plot.normalized()) > 0.7, "Articulado voltado para o canteiro")
	var tracked: Dictionary = await track_tool("can", 1.0, "articulado-rega.png", 0.55)
	await wait_frames(8)
	check(tracked.quadros_visiveis > 20 and tracked.erro_px < 2.0, "Regador preso a mao (erro max %.2f px)" % tracked.erro_px)
	check(not rig.get_part("can").sprite.visible and rig.current_action == "", "Regador guardado ao fim da acao")
	results["rega"] = {"erro_px": tracked.erro_px, "quadros": tracked.quadros_visiveis}

func test_axe() -> void:
	game.set_articulated(true)
	var tree = game.cut_tree
	check(not tree.felled and tree.health == 3, "Arvore de recurso intacta no inicio")
	var spot := floor_near(tree.global_position+Vector3(0.88,0,0))
	game.teleport(spot)
	await wait_physics(10)
	await wait_frames(20)
	key(KEY_F)
	check(tree.health == 2, "F golpeia via cut_tree.hit() real no modo articulado")
	await process_frame
	check(rig.current_action == "chop" and rig.get_part("axe").sprite.visible, "Machado na mao durante o golpe")
	var tracked: Dictionary = await track_tool("axe", 0.62*0.52, "articulado-machado.png", 0.62*0.5)
	var tip: Vector3 = tracked.ponta
	var trunk: Vector3 = tree.global_position
	var reach := Vector2(tip.x-trunk.x,tip.z-trunk.z).length()
	check(tracked.erro_px < 2.0, "Machado acompanha a mao (erro max %.2f px)" % tracked.erro_px)
	if not headless:
		check(reach < 0.6, "Lamina alcanca o tronco no quadro de impacto (%.2f m do eixo, raio 0,32)" % reach)
	await wait_frames(30)
	for i in 2:
		tree.cooldown = 0
		await wait_physics(4)
		key(KEY_F)
		await wait_frames(45)
	check(tree.felled and tree.logs == 3, "Tres golpes articulados derrubam a arvore real")
	results["machado"] = {"erro_px": tracked.erro_px, "distancia_lamina_eixo_m": reach, "impacto_s": 0.62*0.52}

func test_regression_full_sprite() -> void:
	game.set_articulated(false)
	game.zoom_target = 0.94
	var plot: Dictionary = game.farm.plots[5]
	plot.stage = 1
	plot.watered = false
	game.farm.refresh()
	game.teleport(floor_near(plot.position+Vector3(0.78,0,0)))
	await wait_physics(10)
	key(KEY_R)
	check(plot.watered, "Sprite completo continua regando pelo mesmo caminho")
	await wait_frames(60)

# ------------------------------------------------------------- iluminacao
func set_visual(art: bool, shown: bool) -> void:
	game.set_articulated(art)
	if not shown:
		game.full_sprite.visible = false
		rig.visible = false

func character_stats(with_char: Image, without: Image) -> Dictionary:
	var count := 0
	var lum := 0.0
	for y in with_char.get_height():
		for x in with_char.get_width():
			var a := with_char.get_pixel(x,y)
			var b := without.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.12:
				count += 1
				lum += 0.2126*a.r+0.7152*a.g+0.0722*a.b
	return {"pixels": count, "luminancia": lum/maxf(1.0,count)}

func region_at(img: Image, center: Vector2, size: Vector2i) -> Image:
	var origin := Vector2i(center) - size/2
	origin.x = clampi(origin.x,0,img.get_width()-size.x)
	origin.y = clampi(origin.y,0,img.get_height()-size.y)
	return img.get_region(Rect2i(origin,size))

func test_lighting() -> void:
	var waited := 0
	while game.spots.size() < 3 and waited < 60:
		await wait_physics(1)
		waited += 1
	check(game.spots.has("sol") and game.spots.has("sombra") and game.spots.has("lanterna"), "Pontos de sol, sombra e lanterna encontrados")
	var table := {}
	for spot in ["sol","sombra","lanterna"]:
		if not game.spots.has(spot):
			continue
		game.go_to_spot(spot)
		game.full_sprite.set_direction(Vector2(0,1))
		game.zoom_target = 0.65
		game.zoom_current = 0.65
		game.camera.size = 21.5*0.65
		await wait_physics(10)
		await wait_frames(50)
		var entry := {}
		for art in [false,true]:
			set_visual(art,true)
			await wait_frames(12)
			var shown: Image = await capture()
			set_visual(art,false)
			await wait_frames(12)
			var hidden: Image = await capture()
			set_visual(art,true)
			# Mesma pose sem luz 3D (F6): separa a resposta a luz da paleta de cada arte.
			game.lit_sprites = false
			game._set_sprite_lighting()
			await wait_frames(12)
			var unlit: Image = await capture()
			game.lit_sprites = true
			game._set_sprite_lighting()
			await wait_frames(4)
			var center := screen_of(game.player.global_position+Vector3(0,0.6,0))
			var a := region_at(shown,center,Vector2i(120,130))
			var b := region_at(hidden,center,Vector2i(120,130))
			var u := region_at(unlit,center,Vector2i(120,130))
			var name := "articulado" if art else "sprite"
			a.save_png(CROPS + "luz_%s_%s.png" % [spot,name])
			entry[name] = character_stats(a,b)
			var flat: Dictionary = character_stats(u,b)
			entry[name]["luminancia_sem_luz"] = flat.luminancia
			entry[name]["fator_luz"] = entry[name].luminancia/maxf(0.001,flat.luminancia)
			var ground := 0.0
			# Chao em volta dos pes na captura sem personagem (evita o beiral do telhado no canto inferior).
			for gy in range(55,92):
				for gx in range(30,110):
					var c := b.get_pixel(gx,gy)
					ground += 0.2126*c.r+0.7152*c.g+0.0722*c.b
			entry[name]["chao_luminancia"] = ground/(37.0*80.0)
			if spot == "sol":
				shown.save_png("res://docs/articulado-dia-%s.png" % name)
			elif spot == "lanterna":
				shown.save_png("res://docs/articulado-noite-%s.png" % name)
			info("Luz %s, %s: %d px, luminancia %.3f, sem luz %.3f, fator %.3f, chao %.3f" % [spot,name,entry[name].pixels,entry[name].luminancia,entry[name].luminancia_sem_luz,entry[name].fator_luz,entry[name].chao_luminancia])
		table[spot] = entry
	results["iluminacao"] = table
	if table.has("sol") and table.has("sombra"):
		check(table.sombra.sprite.chao_luminancia < table.sol.sprite.chao_luminancia, "Ponto de sombra realmente mais escuro que o de sol (chao %.3f x %.3f)" % [table.sombra.sprite.chao_luminancia, table.sol.sprite.chao_luminancia])
		var sprite_order: bool = table.sol.sprite.fator_luz > table.sombra.sprite.fator_luz
		var art_order: bool = table.sol.articulado.fator_luz > table.sombra.articulado.fator_luz
		check(sprite_order == art_order, "Sol/sombra afetam os dois modos no mesmo sentido")
		for spot in table:
			var ratio: float = table[spot].articulado.fator_luz/maxf(0.001,table[spot].sprite.fator_luz)
			check(absf(ratio-1.0) < 0.12, "Resposta a luz equivalente em %s (articulado/sprite %.3f)" % [spot,ratio])
	game.atmosphere.set_hour(16.0)
	game.zoom_target = 0.94

func test_direction_sheet() -> void:
	game.atmosphere.transition_active = false
	game.atmosphere.set_hour(16.0)
	game.zoom_target = 0.65
	game.zoom_current = 0.65
	game.camera.size = 21.5*0.65
	for art in [false,true]:
		var name := "articulado" if art else "sprite"
		for i in 8:
			game.set_articulated(art)
			game.teleport(Vector3(0,0.4,2))
			game.full_sprite.set_direction(Vector2(cos(i*PI/4.0),sin(i*PI/4.0)))
			await wait_physics(6)
			await wait_frames(14)
			var img: Image = await capture()
			region_at(img,screen_of(game.player.global_position+Vector3(0,0.6,0)),Vector2i(110,110)).save_png(CROPS + "dir_%s_parado_%d.png" % [name,i])
			game.demo_input = Vector2(cos(i*PI/4.0),sin(i*PI/4.0))
			await wait_physics(13)
			game.demo_input = Vector2.ZERO
			img = await capture()
			region_at(img,screen_of(game.player.global_position+Vector3(0,0.6,0)),Vector2i(110,110)).save_png(CROPS + "dir_%s_andando_%d.png" % [name,i])
	game.zoom_target = 0.94

# ------------------------------------------------------------- desempenho
func sample(frames: int) -> Dictionary:
	var times: Array = []
	var draws := 0
	var objects := 0
	var prims := 0
	var last := Time.get_ticks_usec()
	for i in frames:
		game.demo_input = Vector2(0,-1) if (i/60)%2 == 0 else Vector2(0,1)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	game.demo_input = Vector2.ZERO
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	return {"quadro_ms_medio": total/frames, "quadro_ms_p95": times[int(frames*0.95)], "draw_calls": float(draws)/frames, "objetos": float(objects)/frames, "primitivas": float(prims)/frames}

func count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += count_nodes(child)
	return total

func test_performance() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game.atmosphere.set_hour(16.0)
	var perf := {}
	for art in [false,true]:
		game.set_articulated(art)
		game.teleport(Vector3(0,0.4,2))
		await wait_frames(60)
		rig.update_count = 0
		rig.update_usec = 0
		var name := "articulado" if art else "sprite"
		perf[name] = await sample(600)
		if art:
			perf[name]["atualizacao_pecas_us"] = float(rig.update_usec)/maxf(1,rig.update_count)
			perf[name]["atualizacoes_por_quadro"] = float(rig.update_count)/600.0
	perf["nos_sprite_completo"] = count_nodes(game.full_sprite)
	perf["nos_articulado"] = count_nodes(rig)
	perf["instancias_visuais_sprite"] = 2
	perf["instancias_visuais_articulado"] = rig.parts.size()+1
	# Carga: 40 copias extras de cada tipo, em grade visivel, animando.
	var crowd := Node3D.new()
	game.ground.add_child(crowd)
	for kind in ["sprite","articulado"]:
		for child in crowd.get_children():
			child.queue_free()
		await wait_frames(4)
		for i in 40:
			var actor
			if kind == "sprite":
				actor = game.ActorVisual.new()
				actor.setup("original_apprentice")
				crowd.add_child(actor)
				actor.play("walk_south")
			else:
				actor = game.ArticulatedActor.new()
				crowd.add_child(actor)
				actor.setup(null)
				actor.set_motion(true,false)
			actor.position = Vector3(-3.5+(i%8)*1.0, 0.0, -2.5+int(i/8)*1.0) + game.player.position
			actor.layers = 1 << 19
		await wait_frames(30)
		perf["multidao_40_" + kind] = await sample(400)
	crowd.queue_free()
	await wait_frames(4)
	results["desempenho"] = perf
	info("Desempenho: " + JSON.stringify(perf))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)