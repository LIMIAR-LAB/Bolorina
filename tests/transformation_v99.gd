extends SceneTree
## Testes da forma de teste "Armadura de adamantium nivel 99" (tecla G) na cena
## de comparacao. Executar COM janela: Godot --path . --script tests/transformation_v99.gd
## Capturas: docs/adamantium-*.png. Resultados: docs/adamantium-resultados.json.
const SCENE := "res://articulated_comparison.tscn"
const CROPS := "C:/Users/tsmar/Documents/Codex/2026-10-18/referenced-chatgpt-conversation-this-is-an/work/adamantium_recortes/"
var game
var rig
var tf
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
	if headless:
		await process_frame
		rig._update_parts()
		tf.update_now()
	else:
		await RenderingServer.frame_pre_draw

func capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func screen_of(point: Vector3) -> Vector2:
	return game.camera.unproject_position(point)

func region_at(img: Image, center: Vector2, size: Vector2i) -> Image:
	var origin := Vector2i(center) - size/2
	origin.x = clampi(origin.x,0,img.get_width()-size.x)
	origin.y = clampi(origin.y,0,img.get_height()-size.y)
	return img.get_region(Rect2i(origin,size))

func floor_near(point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var hit = game._floor_at(space, point.x, point.z)
	return hit if hit != null else point

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
	tf = game.transformation
	await test_structure()
	await test_toggle_sprite()
	await test_directions(false)
	await test_articulated()
	await test_directions(true)
	await test_mechanics()
	await test_toggle_back()
	if not headless:
		await test_captures()
		await test_performance()
	check(game.suppress_saves, "Cena nao grava progresso")
	var exists_after := FileAccess.file_exists(save_path)
	check(exists_after == save_existed and (not exists_after or FileAccess.get_md5(save_path) == save_hash), "Save do jogador inalterado (existia: %s)" % save_existed)
	results["checks"] = checks
	results["failures"] = failures
	var file := FileAccess.open("res://docs/adamantium-resultados.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	print("RESULTADO: %d/%d verificacoes" % [checks-failures, checks])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

func test_structure() -> void:
	check(tf != null and tf.skeleton is Skeleton3D and tf.skeleton.get_bone_count() == 3, "Asas em Skeleton3D proprio (costas, asa_esquerda, asa_direita)")
	var ok := true
	for side in ["asa_esquerda","asa_direita"]:
		var attachment = tf.attachments[side]
		ok = ok and attachment is BoneAttachment3D and attachment.bone_name == side and tf.wings[side].get_parent() == attachment
		ok = ok and tf.skeleton.get_bone_parent(tf.skeleton.find_bone(side)) == tf.skeleton.find_bone("costas")
	check(ok, "Cada asa e uma peca presa a BoneAttachment3D filho do osso das costas")
	var anims: Dictionary = tf.armor_manifest.anims
	var complete := true
	for d in ["east","south-east","south","south-west","west","north-west","north","north-east"]:
		for kind in ["idle","walk","run"]:
			complete = complete and anims.has(kind+"_"+d) and tf.armor_frames.has_animation(kind+"_"+d)
	check(complete and anims.size() == 24, "Armadura PixelLab com parado/caminhada/corrida nas 8 direcoes (%d animacoes)" % anims.size())
	# Pe de cada quadro do manifesto confere com a imagem (aterramento pelo mesmo metodo do V4)
	var worst := 0
	for anim in anims:
		for i in anims[anim].files.size():
			var img: Image = load(tf.ART + str(anims[anim].files[i])).get_image()
			var bottom := 0
			for y in range(img.get_height()-1,-1,-1):
				var found := false
				for x in img.get_width():
					if img.get_pixel(x,y).a > 0.3:
						found = true
						break
				if found:
					bottom = y+1
					break
			worst = maxi(worst, absi(bottom-int(anims[anim].feet[i])))
	check(worst <= 1, "Linha do pe registrada confere com cada quadro (diferenca max %d px)" % worst)
	var lights: int = tf.find_children("*","Light3D",true,false).size()
	check(lights == 0, "Aura sem nenhuma luz (nao ilumina cenario nem sprites)")
	var material: StandardMaterial3D = tf.aura.mesh.material
	check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Particulas da aura aditivas e sem iluminacao")
	check(not tf.active and not tf.visible and not tf.aura.emitting, "Forma normal ao abrir a cena")

func test_toggle_sprite() -> void:
	game.set_articulated(false)
	game.teleport(Vector3(0,0.4,2))
	await wait_physics(6)
	var normal_frames: SpriteFrames = game.full_sprite.sprite_frames
	var position: Vector3 = game.player.position
	var cam: Transform3D = game.camera.global_transform
	key(KEY_G)
	var unchanged: bool = game.player.position.distance_to(position) < 0.001 and game.camera.global_transform.is_equal_approx(cam)
	await wait_frames(2)
	check(tf.active and game.full_sprite.sprite_frames == tf.armor_frames, "G transforma o sprite completo na armadura")
	check(tf.visible and tf.aura.emitting and tf.wings.asa_esquerda.is_visible_in_tree() and tf.wings.asa_direita.is_visible_in_tree(), "Aura e asas visiveis na forma transformada")
	check(game.mode_label.text.contains("ADAMANTIUM") and game.mode_panel.get_global_rect().end.x <= game.get_viewport().get_visible_rect().size.x, "Rotulo mostra a forma transformada (dentro da tela)")
	check(unchanged, "Transformar nao move personagem nem camera")
	check(absf(game.full_sprite.pixel_size-rig.PX) < 0.0012, "Escala de pixel da armadura proxima da original (%.5f x %.5f)" % [game.full_sprite.pixel_size, rig.PX])
	key(KEY_G)
	await wait_frames(2)
	check(not tf.active and game.full_sprite.sprite_frames == normal_frames and not tf.visible and not tf.aura.emitting, "G de novo volta a forma normal")
	check(not game.mode_label.text.contains("ADAMANTIUM"), "Rotulo volta ao normal")
	key(KEY_G)
	await wait_frames(2)

func test_directions(art: bool) -> void:
	game.set_articulated(art)
	if not tf.active:
		key(KEY_G)
	var label := "articulado" if art else "sprite"
	var report := {}
	var worst_root := 0.0
	var worst_attach := 0.0
	var all_sorted := true
	var all_grounded := true
	var wings_low := INF
	for i in 8:
		var expected: String = rig.DIRECTIONS[i]
		for running in [false,true]:
			game.teleport(Vector3(0,0.4,2))
			await wait_physics(4)
			game.demo_running = running
			game.demo_input = Vector2(cos(i*PI/4.0),sin(i*PI/4.0))
			var angles: Array = []
			var foot_low := INF
			var foot_high := -INF
			var anim_ok := true
			var ground_ok := true
			for f in 72:
				await settle()
				if f < 12:
					continue
				var cam: Basis = game.camera.global_basis.orthonormalized()
				var floor_y: float = game.player.global_position.y
				var expected_anchor: Vector3
				if art:
					var mid: Vector3 = (rig.bone_position_interpolated("upper_arm_r")+rig.bone_position_interpolated("upper_arm_l"))*0.5
					var origin: Vector3 = rig.get_global_transform_interpolated().origin
					expected_anchor = mid+cam.z*((mid-origin).dot(-cam.z))-cam.y*tf.SHOULDER_DROP_PX*tf.PX
					var fr: Vector3 = rig.bone_position("foot_r")
					var fl: Vector3 = rig.bone_position("foot_l")
					var low := minf(fr.y,fl.y)-floor_y
					foot_low = minf(foot_low,low)
					foot_high = maxf(foot_high,low)
				else:
					expected_anchor = game.full_sprite.get_global_transform_interpolated().origin+cam.y*tf.BACK_HEIGHT_PX*tf.PX
					var sprite: AnimatedSprite3D = game.full_sprite
					var info: Dictionary = sprite.manifest.anims[str(sprite.animation)]
					var foot := float(info.feet[mini(sprite.frame,info.feet.size()-1)])
					ground_ok = ground_ok and absf(sprite.offset.y-(foot-float(info.size[1])/2.0)) < 0.01
					anim_ok = anim_ok and str(sprite.animation) == ("run_" if running else "walk_")+expected and sprite.sprite_frames == tf.armor_frames
				var back: Vector3 = tf.skeleton.get_bone_global_pose(0).origin
				worst_root = maxf(worst_root, screen_of(back).distance_to(screen_of(expected_anchor)))
				for side in ["asa_esquerda","asa_direita"]:
					var sprite3: Sprite3D = tf.wings[side]
					var depth: float = (sprite3.global_position-tf.wing_root(side)).dot(cam.z)
					var root_screen := screen_of(sprite3.global_position-cam.z*depth)
					worst_attach = maxf(worst_attach, root_screen.distance_to(screen_of(tf.attachments[side].global_position)))
					var in_front: bool = depth > 0.0
					all_sorted = all_sorted and in_front == (expected in ["north","north-east","north-west"])
					wings_low = minf(wings_low, tf.wing_lowest_point(side)-floor_y)
				angles.append(tf.flap_angle)
			game.demo_input = Vector2.ZERO
			game.demo_running = false
			var spread: float = angles.max()-angles.min()
			var name := expected + (" correndo" if running else " caminhando")
			if art:
				ground_ok = foot_low > -0.012 and foot_high < 0.012
			all_grounded = all_grounded and ground_ok
			check(game.full_sprite.facing_direction == expected and (art or anim_ok), "Transformado (%s) %s: direcao e animacao da armadura" % [label,name])
			check(ground_ok, "Transformado (%s) %s: pe no chao" % [label,name] + ((" (min %.3f, max %.3f m)" % [foot_low,foot_high]) if art else " (pivo por quadro do manifesto)"))
			check(spread > 0.03, "Transformado (%s) %s: asas batem (variacao %.2f rad)" % [label,name,spread])
			report[name] = {"bater_rad": spread}
	check(worst_root < 1.0, "Osso das costas segue o corpo (%s, erro max %.2f px)" % [label,worst_root])
	check(worst_attach < 1.0, "Asas presas ao osso (%s, erro max %.2f px)" % [label,worst_attach])
	check(all_sorted, "Asas atras do corpo de frente/lado e na frente de costas (%s)" % label)
	check(wings_low > -0.03, "Asas nao atravessam o chao (%s, ponto mais baixo %.3f m)" % [label,wings_low])
	results["direcoes_"+label] = {"erro_costas_px": worst_root, "erro_asas_px": worst_attach, "asa_mais_baixa_m": wings_low, "detalhe": report}

func test_articulated() -> void:
	game.set_articulated(true)
	await wait_frames(3)
	var adamantium := 0
	for part in rig.parts:
		if part.sprite.texture != null and str(part.sprite.texture.resource_path).contains("/adamantium/"):
			adamantium += 1
	check(rig.art_folder == tf.PARTS_ART and adamantium >= 12, "Articulado transformado usa pecas recoloridas (%d pecas visiveis)" % adamantium)
	check(tf.visible and tf.wings.asa_esquerda.is_visible_in_tree(), "Asas e aura tambem no modo articulado")

func test_mechanics() -> void:
	for art in [false,true]:
		game.set_articulated(art)
		var plot_index := 7 if art else 6
		var plot: Dictionary = game.farm.plots[plot_index]
		plot.stage = 1
		plot.watered = false
		game.farm.refresh()
		game.teleport(floor_near(plot.position+Vector3(0.78,0,0)))
		await wait_physics(10)
		await wait_frames(10)
		key(KEY_R)
		check(plot.watered and tf.active, "Transformado (%s) rega pelo farm.interact() real" % ("articulado" if art else "sprite"))
		await wait_frames(70)
	var tree = game.cut_tree
	game.set_articulated(false)
	game.teleport(floor_near(tree.global_position+Vector3(0.88,0,0)))
	await wait_physics(10)
	var health: int = tree.health
	tree.cooldown = 0
	key(KEY_F)
	check(tree.health == health-1, "Transformado golpeia a arvore pelo cut_tree.hit() real")
	await wait_frames(40)

func test_toggle_back() -> void:
	game.set_articulated(true)
	key(KEY_G)
	await wait_frames(3)
	var adamantium := 0
	for part in rig.parts:
		if part.sprite.texture != null and str(part.sprite.texture.resource_path).contains("/adamantium/"):
			adamantium += 1
	check(not tf.active and rig.art_folder == rig.ART and adamantium == 0, "G desfaz a transformacao tambem no articulado")
	game.set_articulated(false)
	await wait_frames(2)
	check(game.full_sprite.manifest.get("character_id","") == "8cbad4bb-678d-4004-985e-8728b31c4454", "Sprite completo volta ao original_apprentice V4")

func test_captures() -> void:
	var waited := 0
	while game.spots.size() < 3 and waited < 60:
		await wait_physics(1)
		waited += 1
	var lum := {}
	for spot in ["sol","lanterna"]:
		var label := "dia" if spot == "sol" else "noite"
		game.set_articulated(false)
		game.go_to_spot(spot)
		game.full_sprite.set_direction(Vector2(0,1))
		game.zoom_target = 0.65
		game.zoom_current = 0.65
		game.camera.size = 21.5*0.65
		await wait_physics(10)
		await wait_frames(50)
		for on in [false,true]:
			if tf.active != on:
				key(KEY_G)
			await wait_frames(30)
			var img: Image = await capture()
			var name := "transformado" if on else "normal"
			img.save_png("res://docs/adamantium-%s-%s.png" % [label,name])
			region_at(img,screen_of(game.player.global_position+Vector3(0,0.7,0)),Vector2i(150,150)).save_png(CROPS+"%s_%s.png" % [label,name])
			if on:
				# Mesma pose sem aura: quanto a aura clareia a regiao do personagem.
				tf.aura.visible = false
				tf.ring.visible = false
				await wait_frames(4)
				var no_aura: Image = await capture()
				tf.aura.visible = true
				tf.ring.visible = true
				var a := region_at(img,screen_of(game.player.global_position+Vector3(0,0.7,0)),Vector2i(150,150))
				var b := region_at(no_aura,screen_of(game.player.global_position+Vector3(0,0.7,0)),Vector2i(150,150))
				var la := 0.0
				var lb := 0.0
				for y in a.get_height():
					for x in a.get_width():
						var c1 := a.get_pixel(x,y)
						var c2 := b.get_pixel(x,y)
						la += 0.2126*c1.r+0.7152*c1.g+0.0722*c1.b
						lb += 0.2126*c2.r+0.7152*c2.g+0.0722*c2.b
				lum[label] = {"com_aura": la/(150.0*150.0), "sem_aura": lb/(150.0*150.0)}
				info("Aura %s: luminancia media do recorte %.3f com aura x %.3f sem aura" % [label,lum[label].com_aura,lum[label].sem_aura])
		if tf.active:
			key(KEY_G)
	# Articulado transformado de dia, para comparar
	game.go_to_spot("sol")
	game.set_articulated(true)
	key(KEY_G)
	await wait_physics(10)
	await wait_frames(40)
	var art_img: Image = await capture()
	art_img.save_png("res://docs/adamantium-dia-articulado-transformado.png")
	region_at(art_img,screen_of(game.player.global_position+Vector3(0,0.7,0)),Vector2i(150,150)).save_png(CROPS+"dia_articulado_transformado.png")
	# Folha de 8 direcoes andando (sprite transformado)
	game.set_articulated(false)
	for i in 8:
		game.teleport(Vector3(0,0.4,2))
		await wait_physics(4)
		game.demo_input = Vector2(cos(i*PI/4.0),sin(i*PI/4.0))
		await wait_physics(13)
		game.demo_input = Vector2.ZERO
		var img2: Image = await capture()
		region_at(img2,screen_of(game.player.global_position+Vector3(0,0.7,0)),Vector2i(130,130)).save_png(CROPS+"dir_%d.png" % i)
	key(KEY_G)
	await wait_frames(4)
	results["aura_luminancia"] = lum
	game.zoom_target = 0.94

func sample(frames: int) -> Dictionary:
	var times: Array = []
	var draws := 0
	var last := Time.get_ticks_usec()
	for i in frames:
		game.demo_input = Vector2(0,-1) if (i/60)%2 == 0 else Vector2(0,1)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now-last)/1000.0)
		last = now
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	game.demo_input = Vector2.ZERO
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	return {"quadro_ms_medio": total/frames, "quadro_ms_p95": times[int(frames*0.95)], "draw_calls": float(draws)/frames}

func test_performance() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game.atmosphere.set_hour(16.0)
	game.set_articulated(false)
	var perf := {}
	for on in [false,true,false,true]:
		if tf.active != on:
			key(KEY_G)
		game.teleport(Vector3(0,0.4,2))
		await wait_frames(40)
		var r: Dictionary = await sample(400)
		var name := "transformado" if on else "normal"
		if perf.has(name):
			for k in r:
				perf[name][k] = (perf[name][k]+r[k])*0.5
		else:
			perf[name] = r
	if tf.active:
		key(KEY_G)
	results["desempenho"] = perf
	info("Desempenho: " + JSON.stringify(perf))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)