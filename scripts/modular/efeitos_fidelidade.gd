extends Node3D
## Efeitos do video de referencia (docs/estilo-video-referencia.md), todos alternaveis:
## 1 grade golden hour x sombras indigo | 2 orvalho | 3 vaga-lumes/orbes | 4 fogo cintilante + faiscas
## 5 vento na folhagem | 6 agua animada | 7 tilt-shift (DoF) | 8 sombras de contato | 9 filtro pixel art | 0 nevoa do abismo
var game
var vila
var estados := {"grade": true, "orvalho": true, "vagalumes": true, "fogo": true, "vento": true, "agua": true, "dof": true, "sombras": true, "pixel": false, "nevoa": true}
const TECLAS := {KEY_1: "grade", KEY_2: "orvalho", KEY_3: "vagalumes", KEY_4: "fogo", KEY_5: "vento", KEY_6: "agua", KEY_7: "dof", KEY_8: "sombras", KEY_9: "pixel", KEY_0: "nevoa"}
var orvalho: CPUParticles3D
var vagalumes: CPUParticles3D
var orbes: CPUParticles3D
var lente: CameraAttributesPractical
var pixel_layer: CanvasLayer
var lut: GradientTexture1D
var vinheta: ColorRect
const VINHETA_SH := """shader_type canvas_item;
uniform float forca = 0.55;
uniform vec3 cor = vec3(0.05, 0.03, 0.09);
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.38, 0.86, length(d));
	COLOR = vec4(cor, v * forca);
}"""
var atores_sombra: Array[MeshInstance3D] = []
var t := 0.0
var fase := 5

func setup(g, v, fase_ativa: int) -> void:
	game = g
	vila = v
	fase = fase_ativa
	name = "EfeitosFidelidade"
	var bc: Array = vila.basis_cam()
	var alvo: Vector3 = vila.cam_alvo
	# vinheta escura nas bordas (moldura da referencia), abaixo da sobreposicao/HUD
	var camada := CanvasLayer.new()
	camada.name = "VinhetaCrepusculo"
	camada.layer = -1   # acima do 3D, abaixo do HUD
	add_child(camada)
	vinheta = ColorRect.new()
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	var vsh := Shader.new()
	vsh.code = VINHETA_SH
	vm.shader = vsh
	vinheta.material = vm
	camada.add_child(vinheta)
	# 2 orvalho: pontos 1-3 px brancos, sem brilho, caindo em diagonal (alto-direita -> baixo-esquerda)
	orvalho = CPUParticles3D.new()
	orvalho.name = "Orvalho"
	orvalho.amount = 900
	orvalho.lifetime = 9.0
	orvalho.preprocess = 9.0
	orvalho.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	orvalho.emission_box_extents = Vector3(30, 7, 30)
	orvalho.position = alvo + Vector3(0, 7, 0) + bc[0]*6.0
	var dir: Vector3 = (-bc[0]*0.75 + Vector3.DOWN*0.65).normalized()
	orvalho.direction = dir
	orvalho.spread = 4
	orvalho.gravity = Vector3.ZERO
	orvalho.initial_velocity_min = 1.3
	orvalho.initial_velocity_max = 2.1
	orvalho.scale_amount_min = 0.5
	orvalho.scale_amount_max = 1.5
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.86, 0.88, 0.9)
	q.material = m
	orvalho.mesh = q
	add_child(orvalho)
	# 3 vaga-lumes amarelos (bloom moderado) na praca e orbes ciano grandes
	vagalumes = _flutuantes("VagaLumes", 46, Vector3(9, 1.2, 9), vila.tela_para_mundo(820, 500, 0.0)+Vector3(0, 1.6, 0), 0.07, Color(3.2, 2.1, 0.6))
	orbes = _flutuantes("OrbesCiano", 7, Vector3(14, 2.0, 14), vila.tela_para_mundo(800, 380, 0.0)+Vector3(0, 2.4, 0), 0.2, Color(0.6, 2.6, 3.0))
	# 7 tilt-shift: DoF na distancia da camera (topo = longe, base = perto)
	lente = CameraAttributesPractical.new()
	lente.dof_blur_far_enabled = true
	lente.dof_blur_far_distance = 96.0
	lente.dof_blur_far_transition = 14.0
	lente.dof_blur_near_enabled = true
	lente.dof_blur_near_distance = 84.0
	lente.dof_blur_near_transition = 10.0
	lente.dof_blur_amount = float(game.config.get("dof", 0.03))
	# 1 LUT por canal: luzes quentes douradas, sombras indigo/roxas
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(0.035, 0.025, 0.075))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(1.0, 0.96, 0.86))
	grad.add_point(0.22, Color(0.20, 0.14, 0.24))
	grad.add_point(0.5, Color(0.56, 0.45, 0.42))
	grad.add_point(0.75, Color(0.85, 0.73, 0.60))
	lut = GradientTexture1D.new()
	lut.gradient = grad
	lut.width = 256
	# 9 filtro pixel art (pos-processo), desligado por padrao
	pixel_layer = CanvasLayer.new()
	pixel_layer.layer = 30
	pixel_layer.name = "FiltroPixel"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/fid_pixel.gdshader")
	rect.material = sm
	pixel_layer.add_child(rect)
	add_child(pixel_layer)
	# 8 sombras de contato dos atores
	for actor in [game.sprite, game.npc, game.village_cat, game.village_resident]:
		if actor == null:
			continue
		var s := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.9, 0.6) if actor != game.village_cat else Vector2(0.55, 0.4)
		s.mesh = plane
		var sh := ShaderMaterial.new()
		sh.shader = load("res://shaders/contact_shadow.gdshader")
		s.material_override = sh
		s.position.y = 0.035
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(s)
		atores_sombra.append(s)
	estados.pixel = bool(game.config.get("pixel", false))
	if fase < 4:
		for k in estados:
			estados[k] = k == "vento" or k == "agua" or k == "nevoa"
	if bool(game.config.get("efeitos_off", false)) or OS.get_environment("FID_EFEITOS_OFF") == "1":
		definir_todos(false)
	aplicar()

func _flutuantes(nome: String, amount: int, ext: Vector3, pos: Vector3, size: float, cor: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nome
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.position = pos
	p.direction = Vector3.UP
	p.spread = 180
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.orbit_velocity_min = 0.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = cor
	m.albedo_texture = vila.kit._soft_dot()
	q.material = m
	p.mesh = q
	add_child(p)
	return p

func alternar(chave: String) -> void:
	estados[chave] = not estados[chave]
	aplicar()

func definir_todos(ligado: bool) -> void:
	for k in estados:
		estados[k] = ligado if k != "pixel" else false
	aplicar()

func aplicar() -> void:
	orvalho.visible = estados.orvalho
	orvalho.emitting = estados.orvalho
	vagalumes.visible = estados.vagalumes
	orbes.visible = estados.vagalumes
	for f in vila.kit.fogos:
		if is_instance_valid(f):
			f.visible = estados.fogo
	for s in vila.kit.fumacas:
		s.visible = estados.fogo
	vila.kit.folhagem.set_shader_parameter("vento", 1.0 if estados.vento else 0.0)
	if vila.agua_mat:
		vila.agua_mat.set_shader_parameter("efeitos", 1.0 if estados.agua else 0.0)
	if vila.cachoeira_mat:
		vila.cachoeira_mat.set_shader_parameter("efeitos", 1.0 if estados.agua else 0.0)
	game.fidelity_camera.attributes = lente if estados.dof else null
	for s in vila.kit.sombras + atores_sombra:
		s.visible = estados.sombras
	pixel_layer.visible = estados.pixel
	for n in vila.nevoa:
		n.visible = estados.nevoa
	_grade()

func _grade() -> void:
	var env: Environment = game.atmosphere.settings
	var sun: DirectionalLight3D = game.atmosphere.sun
	var bc: Array = vila.basis_cam()
	if estados.grade:
		# sol baixo vindo do alto-esquerda da tela: sombras longas para baixo-direita
		var toward: Vector3 = (bc[0]*0.55 + Vector3(bc[2].x, 0, bc[2].z).normalized()*0.35 + Vector3.DOWN*0.42).normalized()
		sun.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO).looking_at(toward, Vector3.UP)
		env.adjustment_color_correction = _lut_calibrada()
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = float(game.config.get("exposicao", 1.0))
		if v1():
			sun.light_color = Color("ffc47e")
			sun.light_energy = float(game.config.get("sol", 1.7))
			env.adjustment_saturation = float(game.config.get("saturacao", 1.0))
			env.adjustment_contrast = 1.0
			env.adjustment_brightness = 1.0
			env.glow_intensity = 0.75
			env.glow_bloom = 0.06
			env.fog_light_color = Color("7d7f98")
		else:
			# Crepusculo v2 (sem "fosco"): sol ambar mais forte, sombras indigo profundas, contraste e
			# saturacao maiores, sem bloom geral (so o que passa de HDR 1,0 brilha = brilho nitido),
			# sem neblina volumetrica; neblina comum so por altura (abismo), nao como veu plano na tela.
			sun.light_color = Color(String(cfg("crep_sol_cor", "ffca8c")))
			sun.light_energy = float(cfg("crep_sol", 1.8))
			env.adjustment_saturation = float(game.config.get("saturacao", 1.0)) * float(cfg("crep_saturacao", 0.97))
			env.adjustment_contrast = float(cfg("crep_contraste", 1.06))
			env.adjustment_brightness = float(cfg("crep_brilho", 1.06))
			env.tonemap_exposure = float(cfg("crep_exposicao", 1.25))
			(vinheta.material as ShaderMaterial).set_shader_parameter("forca", float(cfg("crep_vinheta", 0.28)))
			env.glow_intensity = float(cfg("crep_glow", 0.8))
			env.glow_bloom = 0.0
			env.glow_hdr_threshold = 1.0
			env.glow_strength = 1.0
			for i in 7:
				env.set_glow_level(i, i >= 1 and i <= 3)
			env.volumetric_fog_enabled = false
			_neblina(env)
	else:
		env.adjustment_color_correction = null
	env.fog_enabled = estados.nevoa or not estados.grade
	vinheta.visible = estados.grade and not v1()

func v1() -> bool:
	return bool(game.config.get("grade_v1", false))

func cfg(chave: String, padrao):
	return game.config.get(chave, padrao)

func _neblina(env: Environment) -> void:
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(String(cfg("crep_neblina_cor", "5b5788")))
	env.fog_light_energy = float(cfg("crep_neblina_luz", 1.0))
	env.fog_sun_scatter = 0.0
	env.fog_density = float(cfg("crep_neblina", 0.00035))
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.3
	env.fog_height = -1.5
	env.fog_height_density = 0.35

const LUT_ARQUIVO := "res://scripts/modular/lut_fidelidade.png"
var _lut_cache: Texture2D
func _lut_calibrada() -> Texture2D:
	# LUT por canal calibrada por casamento de histograma com a referencia (tools/fidelidade_lut.py).
	if _lut_cache == null and not bool(game.config.get("sem_lut", false)) and FileAccess.file_exists(LUT_ARQUIVO):
		_lut_cache = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(LUT_ARQUIVO)))
	return _lut_cache

func cada_quadro(delta: float) -> void:
	t += delta
	var env: Environment = game.atmosphere.settings
	if estados.grade:
		if v1():
			env.ambient_light_color = Color("6c6aa3")
			env.ambient_light_energy = 0.5
		else:
			env.ambient_light_color = Color(String(cfg("crep_ambiente_cor", "6a62b8")))
			env.ambient_light_energy = float(cfg("crep_ambiente", 1.1))
			_neblina(env)   # a atmosfera recalcula a neblina a cada quadro
	if estados.fogo:
		for l in vila.kit.luzes_fogo:
			var base: float = l.get_meta("base", 1.5)
			var ph := float(l.get_instance_id() % 97)
			l.light_energy = base*(0.82 + 0.12*sin(t*9.0+ph) + 0.08*sin(t*23.0+ph*1.7))
	else:
		for l in vila.kit.luzes_fogo:
			l.light_energy = l.get_meta("base", 1.5)

func tecla(code: int) -> bool:
	if TECLAS.has(code):
		alternar(TECLAS[code])
		return true
	return false

func texto() -> String:
	var parts: Array[String] = []
	var i := 1
	for k in ["grade","orvalho","vagalumes","fogo","vento","agua","dof","sombras","pixel","nevoa"]:
		parts.append("%d %s%s" % [i % 10, k, "" if estados[k] else " (off)"])
		i += 1
	return " | ".join(parts)