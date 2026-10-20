extends SceneTree
## Sondagem 2: reproduz o enquadramento do usuario (NW da casa 0, patamar da cachoeira) e identifica a malha da "laje".
var v
var tag := "antes"
func _init() -> void:
	call_deferred("_run")
func fr(n: int) -> void:
	for i in n:
		await process_frame
func foto(nome: String) -> void:
	await fr(8)
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/casas"))
	img.save_png(ProjectSettings.globalize_path("res://docs/casas/%s-%s.png" % [tag, nome]))
	print("INFO captura ", nome)
func pick(cam: Camera3D, px: Vector2) -> Dictionary:
	var o := cam.project_ray_origin(px)
	var d := cam.project_ray_normal(px)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 400.0)
	return root.get_world_3d().direct_space_state.intersect_ray(q)
func listar(cam: Camera3D, px: Vector2) -> void:
	# malhas cujo AABB projetado contem o pixel, ordenadas pela distancia a camera
	var achados := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null: continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
		for i in 8:
			var s := cam.unproject_position(ab.get_endpoint(i))
			mn = mn.min(s); mx = mx.max(s)
		if px.x >= mn.x and px.x <= mx.x and px.y >= mn.y and px.y <= mx.y:
			var dist: float = (ab.get_center() - cam.global_position).dot(-cam.global_basis.z)
			achados.append([dist, str(mi.get_path()).right(70), str(ab.size), str(mi.material_override.resource_name if mi.material_override else ""), (mi.material_override as StandardMaterial3D).albedo_texture.resource_path if mi.material_override is StandardMaterial3D and mi.material_override.albedo_texture else ""])
	achados.sort_custom(func(a, b): return a[0] < b[0])
	for a in achados.slice(0, 8):
		print("MALHA px=%s d=%.1f %s tam=%s tex=%s" % [str(px), a[0], a[1], a[2], a[4]])
func _run() -> void:
	if OS.get_environment("SOND_TAG") != "": tag = OS.get_environment("SOND_TAG")
	OS.set_environment("ILHA_SAVE", "user://ilha_casas_teste.json")
	OS.set_environment("ILHA_AREA", "vila")
	OS.set_environment("ILHA_SPAWN", "da_fazenda")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 300:
		await process_frame
		if jogo.atual and jogo.atual.get("interiores") != null and jogo.atual.interiores != null:
			break
	v = jogo.atual
	await create_timer(1.0).timeout
	var it = v.interiores
	var cam: Camera3D = v.fidelity_camera
	var p: Vector3 = it.porta_fora(0)
	v.player.position = Vector3(p.x, v.vila.altura(p.x, p.z) + 0.4, p.z)
	v.interior_mudou()
	await create_timer(1.0).timeout
	var vp_size: Vector2 = root.get_viewport().get_visible_rect().size
	print("VP ", vp_size, " rio0=", str(v.vila.data.rio.pontos[0]))
	for alvo_px in [Vector2(407, 60), Vector2(407, 120), Vector2(300, 100)]:
		var h := pick(cam, alvo_px)
		print("PICK ", alvo_px, " -> ", str(h.get("position", "nada")), " ", str(h.get("collider", "")))
	listar(cam, Vector2(150, 60))
	listar(cam, Vector2(250, 30))
	# move a Vale para o ponto que poe a laje como na captura do usuario
	var h2 := pick(cam, Vector2(407, 60))
	if h2.has("position"):
		var q: Vector3 = h2.position
		v.player.position = Vector3(q.x, v.vila.altura(q.x, q.z) + 0.4, q.z)
		v.interior_mudou()
		await create_timer(1.5).timeout
		print("PLAYER ", v.player.position, " tela=", cam.unproject_position(v.player.global_position))
		await foto("patamar")
		listar(cam, Vector2(400, 350))
		listar(cam, Vector2(600, 250))
	quit(0)
