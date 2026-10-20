extends SceneTree
## Sondagem dos "quadrados" no ceu do horizonte vivo: captura com cada efeito desligado.
## ILHA_AREA=fazenda|vila. Grava docs/blocos/<area>-<variante>.png
var v
var env: Environment
var cam: Camera3D
var area := "fazenda"
func _init() -> void:
	call_deferred("_run")
func fr(n: int) -> void:
	for i in n:
		await process_frame
func foto(nome: String) -> void:
	await fr(14)
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/blocos"))
	img.save_png(ProjectSettings.globalize_path("res://docs/blocos/%s-%s.png" % [area, nome]))
	print("INFO captura ", nome)
func _run() -> void:
	area = OS.get_environment("ILHA_AREA")
	if area == "": area = "fazenda"
	OS.set_environment("ILHA_SAVE", "user://ilha_horizonte_teste.json")
	OS.set_environment("HORIZONTE_CLIMA", OS.get_environment("SOND_CLIMA") if OS.get_environment("SOND_CLIMA") != "" else "ensolarado")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 300:
		await process_frame
		if jogo.atual and jogo.atual.get("horizonte") != null and jogo.atual.horizonte != null:
			break
	v = jogo.atual
	await create_timer(1.5).timeout
	if v.get("message") != null: v.message.text = ""
	if area == "vila":
		v.camera_travada = true
		v.vila.cam_alvo = Vector3(-8, 0, -20)
		v.vila.cam_size = 24.0
		v.apply_camera()
	env = v.atmosphere.settings
	cam = root.get_viewport().get_camera_3d()
	var vp := root.get_viewport()
	print("SET bg=%d ssr=%s ssil=%s ssao=%s sdfgi=%s glow=%s vol=%s fog=%s adj=%s lut=%s msaa=%d taa=%s ssaa=%d scale=%.2f mode=%d deband=%s cam_attr=%s proj=%d" % [env.background_mode, env.ssr_enabled, env.ssil_enabled, env.ssao_enabled, env.sdfgi_enabled, env.glow_enabled, env.volumetric_fog_enabled, env.fog_enabled, env.adjustment_enabled, env.adjustment_color_correction != null, vp.msaa_3d, vp.use_taa, vp.screen_space_aa, vp.scaling_3d_scale, vp.scaling_3d_mode, vp.use_debanding, str(cam.attributes) if cam else "?", cam.projection if cam else -1])
	if cam and cam.attributes is CameraAttributesPractical:
		var a: CameraAttributesPractical = cam.attributes
		print("DOF far=%s %.1f near=%s %.1f amount=%.3f" % [a.dof_blur_far_enabled, a.dof_blur_far_distance, a.dof_blur_near_enabled, a.dof_blur_near_distance, a.dof_blur_amount])
	await foto("0-base")
	var hz = v.horizonte
	hz.ceu_mat.set_shader_parameter("compensar", 0.0); hz.camada_mat.set_shader_parameter("compensar", 0.0)
	await foto("1-sem-compensar")
	hz.ceu_mat.set_shader_parameter("compensar", 1.0); hz.camada_mat.set_shader_parameter("compensar", 1.0)
	env.ssr_enabled = false
	await foto("2-sem-ssr")
	env.ssr_enabled = true
	env.ssil_enabled = false
	await foto("3-sem-ssil")
	env.ssil_enabled = true
	env.ssao_enabled = false
	await foto("4-sem-ssao")
	env.ssao_enabled = true
	env.glow_enabled = false
	await foto("5-sem-glow")
	env.glow_enabled = true
	var attr = cam.attributes if cam else null
	if cam: cam.attributes = null
	await foto("6-sem-dof")
	if cam: cam.attributes = attr
	env.adjustment_enabled = false
	await foto("7-sem-adjust")
	env.adjustment_enabled = true
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	await foto("8-sem-fog")
	env.fog_enabled = true
	var m := vp.msaa_3d
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await foto("9-sem-msaa")
	vp.msaa_3d = m
	env.ssr_enabled = false; env.ssil_enabled = false; env.ssao_enabled = false; env.glow_enabled = false
	if cam: cam.attributes = null
	env.adjustment_enabled = false
	await foto("A-tudo-off")
	quit(0)
