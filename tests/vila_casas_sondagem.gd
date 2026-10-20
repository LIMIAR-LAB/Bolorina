extends SceneTree
## Sondagem: Vale na porta de cada casa da vila, camera seguindo. Grava docs/casas/<tag>-casa<i>[-zoom].png
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
	print("CAM near=%.2f far=%.1f size=%.2f proj=%d yaw=%.1f zoom=%.2f travada=%s" % [cam.near, cam.far, cam.size, cam.projection, rad_to_deg(v.vila.cam_yaw), v.zoom_current, v.camera_travada])
	for i in it.casas.size():
		var c: Node3D = it.casas[i]
		var p: Vector3 = it.saida_fora(i)
		print("CASA %d pos=%s rot=%.1f escala=%s porta=%s" % [i, str(c.global_position), rad_to_deg(c.rotation.y), str(c.scale), str(p)])
	for i in it.casas.size():
		var p: Vector3 = it.porta_fora(i)
		v.player.position = Vector3(p.x, v.vila.altura(p.x, p.z) + 0.4, p.z)
		v.player.velocity = Vector3.ZERO
		v.interior_mudou()
		await create_timer(1.2).timeout
		print("PLAYER %d pos=%s tela=%s cam=%s" % [i, str(v.player.position), str(cam.unproject_position(v.player.global_position)), str(cam.global_position)])
		await foto("casa%d" % i)
		v.zoom_target = 0.65
		v.zoom_current = 0.65
		await create_timer(0.6).timeout
		await foto("casa%d-zoom" % i)
		v.zoom_target = 0.94
		v.zoom_current = 0.94
	quit(0)
