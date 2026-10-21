extends Node3D
## Bolorina 21/10/2026 — Mirante da Cascata (primeira ilha). Vista "Elden Ring": penhasco com cachoeira
## caindo no abismo, por do sol ao fundo, raios de luz, bruma e a Arvore-Ambar dourada.
## Tudo em 3D + luz: WorldEnvironment (glow, neblina volumetrica, neblina de profundidade), sol baixo de
## contraluz, cachoeiras com shader, particulas de bruma/brasas e um ceu pintado que acompanha a camera.
## Props CC0: Kenney Graveyard Kit, KayKit Halloween Bits, Kenney Pirate Kit (ver art/terceiros/CREDITOS_ARTE_MUNDOS.md).
##
## Modos:
##  - jogo (padrao): area do data/areas.json com o adaptador area_mapa_novo.gd (Vale, WASD e camera isometrica).
##    Ao pisar no Mirante (beira do penhasco) a camera vira uma tomada cinematografica em perspectiva.
##  - vitrine (vitrine = true): fundo vivo da tela inicial; camera em perspectiva passeando devagar.
const SH := "res://shaders/mirante/"
const M := "res://art/models/"
const YAW := 50.0
@export var vitrine := false
var vista: Node3D
var ceu: MeshInstance3D
var cam_cine: Camera3D
var cam_antes: Camera3D
var no_mirante := false
var relogio := 0.0
var legenda: Label
var _mats := {}
var _cache := {}

func _ready() -> void:
	vista = Node3D.new()
	vista.name = "Vista"
	vista.rotation_degrees.y = YAW
	add_child(vista)
	_ambiente()
	_terreno()
	_agua()
	_props()
	_particulas()
	_ceu()
	cam_cine = Camera3D.new()
	cam_cine.name = "CameraCinematica"
	cam_cine.fov = 52.0
	cam_cine.far = 900.0
	vista.add_child(cam_cine)
	_pose_cine(0.0)
	if vitrine:
		cam_cine.current = true
	else:
		var cap := Marker3D.new()
		cap.name = "SubstituirPeloSpriteDaVale"
		vista.add_child(cap)
		cap.position = Vector3(0, 0.15, 7.5)
		_mirante_area()
		var camada := CanvasLayer.new()
		camada.layer = 5
		add_child(camada)
		legenda = Label.new()
		legenda.text = "MIRANTE DA CASCATA\no sol nunca termina de se pôr aqui"
		legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legenda.set_anchors_preset(Control.PRESET_TOP_WIDE)
		legenda.offset_top = 60
		legenda.offset_bottom = 180
		legenda.add_theme_font_size_override("font_size", 40)
		legenda.add_theme_color_override("font_color", Color("f6d9a0"))
		legenda.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.08, 0.9))
		legenda.add_theme_constant_override("outline_size", 8)
		legenda.modulate.a = 0.0
		camada.add_child(legenda)

# ------------------------------------------------------------------ util
func _sh(nome: String) -> Shader:
	return load(SH + nome + ".gdshader")

func _mat(nome: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sh(nome)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _rocha() -> ShaderMaterial:
	if not _mats.has("rocha"):
		_mats.rocha = _mat("rocha")
	return _mats.rocha

func _bloco(pai: Node3D, pos: Vector3, tam: Vector3, rot := Vector3.ZERO, colide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = _rocha()
	mi.position = pos
	mi.rotation_degrees = rot
	pai.add_child(mi)
	if colide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = tam
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _parede(pos: Vector3, tam: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = tam
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	vista.add_child(sb)

func _modelo(caminho: String, pos: Vector3, escala := 1.0, ang := 0.0, pai: Node3D = null) -> Node3D:
	if not _cache.has(caminho):
		_cache[caminho] = load(M + caminho) if ResourceLoader.exists(M + caminho) else null
	var ps: PackedScene = _cache[caminho]
	if ps == null:
		push_warning("mirante: modelo ausente " + caminho)
		return null
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.scale = Vector3.ONE * escala
	n.rotation_degrees.y = ang
	(pai if pai else vista).add_child(n)
	return n

# ------------------------------------------------------------------ luz e ambiente
func _ambiente() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color(0.16, 0.11, 0.30)
	ps.sky_horizon_color = Color(1.0, 0.56, 0.32)
	ps.ground_horizon_color = Color(0.62, 0.34, 0.30)
	ps.ground_bottom_color = Color(0.10, 0.07, 0.12)
	ps.sun_angle_max = 8.0
	ps.sun_curve = 0.08
	sky.sky_material = ps
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.52, 0.42)
	env.fog_density = 0.0022
	env.fog_sun_scatter = 0.55
	env.fog_aerial_perspective = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0045
	env.volumetric_fog_albedo = Color(1.0, 0.80, 0.66)
	env.volumetric_fog_emission = Color(0.12, 0.06, 0.08)
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_length = 80.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.name = "AmbientePoente"
	we.environment = env
	add_child(we)
	# sol baixo atras da cachoeira (contraluz): brilha na direcao +Z local
	var sol := DirectionalLight3D.new()
	sol.name = "SolPoente"
	sol.light_color = Color(1.0, 0.63, 0.36)
	sol.light_energy = 1.6
	sol.light_volumetric_fog_energy = 2.5
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 120.0
	vista.add_child(sol)
	_sol = sol
	sol.shadow_blur = 1.5
	var rim := DirectionalLight3D.new()
	rim.name = "LuzDeContorno"
	rim.light_color = Color(1.0, 0.70, 0.45)
	rim.light_energy = 0.0
	rim.light_specular = 1.2
	vista.add_child(rim)
	rim.rotation_degrees = Vector3(-14.0, 180.0, 0.0)
	_rim = rim
	sol.rotation_degrees = Vector3(-19.0, 172.0, 0.0)
	# luz de preenchimento fria vinda do lado da camera
	var fill := DirectionalLight3D.new()
	fill.name = "PreenchimentoCeu"
	fill.light_color = Color(0.55, 0.55, 0.85)
	fill.light_energy = 0.35
	vista.add_child(fill)
	fill.rotation_degrees = Vector3(-50.0, 20.0, 0.0)

# ------------------------------------------------------------------ terreno
func _terreno() -> void:
	var t := Node3D.new()
	t.name = "Terreno"
	vista.add_child(t)
	# planalto da chegada (topo em y=0)
	_bloco(t, Vector3(0, -3.0, 11.0), Vector3(30, 6, 30))
	# saliencia do mirante
	_bloco(t, Vector3(0, -2.5, -6.0), Vector3(7, 5, 5))
	# encosta caindo para o abismo (pedras empilhadas)
	var r := RandomNumberGenerator.new()
	r.seed = 2110
	for i in 22:
		var x := -13.0 + i * 1.25
		if absf(x) < 4.0:
			continue
		var h := r.randf_range(8.0, 22.0)
		_bloco(t, Vector3(x, -h * 0.5 - 0.6, -4.6 - r.randf_range(0.0, 1.2)), Vector3(r.randf_range(1.6, 2.6), h, r.randf_range(1.5, 3.0)), Vector3(r.randf_range(-6, 6), r.randf_range(-20, 20), r.randf_range(-5, 5)), false)
	for i in 6:
		_bloco(t, Vector3(r.randf_range(-3.0, 3.0), -6.0 - i * 3.0, -8.2 - r.randf_range(0, 1.0)), Vector3(r.randf_range(2.0, 4.0), 4.0, 2.0), Vector3(0, r.randf_range(-30, 30), r.randf_range(-8, 8)), false)
	# penhasco do outro lado (a cachoeira cai dele): topo em y=+7
	_bloco(t, Vector3(-17, -10, -30), Vector3(26, 34, 22), Vector3.ZERO, false)
	_bloco(t, Vector3(17, -10, -30), Vector3(26, 34, 22), Vector3.ZERO, false)
	_bloco(t, Vector3(0, -12, -32), Vector3(9, 34, 18), Vector3.ZERO, false)
	# laterais do canion (fecham o enquadramento)
	_bloco(t, Vector3(-24, -17, -14), Vector3(12, 30, 16), Vector3(0, 8, 0), false)
	_bloco(t, Vector3(24, -17, -14), Vector3(12, 30, 16), Vector3(0, -8, 0), false)
	# picos ao longe (silhuetas 3D com neblina)
	for i in 0:
		var x := -70.0 + i * 17.0 + r.randf_range(-5, 5)
		var alt := r.randf_range(18, 42)
		var pico := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r.randf_range(0.3, 2.5)
		cm.bottom_radius = r.randf_range(9.0, 16.0)
		cm.height = alt + 14.0
		cm.radial_segments = 7
		cm.rings = 3
		pico.mesh = cm
		pico.material_override = _rocha()
		pico.position = Vector3(x * 1.6, (alt + 14.0) * 0.5 - 14.0, -110.0 - r.randf_range(0, 40))
		pico.rotation_degrees = Vector3(r.randf_range(-3, 3), r.randf_range(0, 90), r.randf_range(-3, 3))
		pico.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.add_child(pico)
	# paredes invisiveis da borda (o abismo e so para os olhos)
	_parede(Vector3(0, 1, -8.7), Vector3(7, 3, 0.4))
	_parede(Vector3(-3.6, 1, -6.2), Vector3(0.4, 3, 5))
	_parede(Vector3(3.6, 1, -6.2), Vector3(0.4, 3, 5))
	_parede(Vector3(-8.5, 1, -3.9), Vector3(10, 3, 0.4))
	_parede(Vector3(8.5, 1, -3.9), Vector3(10, 3, 0.4))
	_parede(Vector3(-13.1, 1, 11), Vector3(0.4, 3, 30))
	_parede(Vector3(13.1, 1, 11), Vector3(0.4, 3, 30))
	_parede(Vector3(0, 1, 25.9), Vector3(26, 3, 0.4))

# ------------------------------------------------------------------ agua
func _queda(pos: Vector3, larg: float, alt: float, vel: float, semente: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(larg, alt)
	mi.mesh = q
	mi.material_override = _mat("cachoeira", {"vel": vel, "semente": semente})
	mi.position = pos + Vector3(0, -alt * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vista.add_child(mi)

func _agua() -> void:
	# rio no alto do penhasco, correndo para a beira
	var rio := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(7.5, 22)
	rio.mesh = pm
	rio.material_override = _mat("agua", {"fluxo": Vector2(0.0, 0.9)})
	rio.position = Vector3(0, 7.05, -32)
	vista.add_child(rio)
	# margens do rio
	_bloco(vista, Vector3(-4.6, 6.6, -31), Vector3(1.6, 1.4, 22), Vector3.ZERO, false)
	_bloco(vista, Vector3(4.6, 6.6, -31), Vector3(1.6, 1.4, 22), Vector3.ZERO, false)
	# cortina principal em camadas + duas quedas finas
	_queda(Vector3(0, 7.1, -20.9), 7.6, 34.0, 1.5, 0.0)
	_queda(Vector3(0.2, 7.0, -20.6), 6.4, 34.0, 1.9, 17.0)
	_queda(Vector3(-0.3, 7.0, -20.3), 4.0, 33.0, 2.3, 41.0)
	_queda(Vector3(-11.5, 6.4, -18.9), 1.6, 30.0, 1.7, 5.0)
	_queda(Vector3(12.5, 6.0, -18.9), 1.2, 29.0, 2.0, 9.0)
	# poco la embaixo
	var poco := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(60, 26)
	poco.mesh = pp
	poco.material_override = _mat("agua", {"fluxo": Vector2(0.05, 0.12), "centro_ondas": vista.to_global(Vector3(0, -26.5, -20.5)), "ondas": 1.0})
	poco.position = Vector3(0, -26.5, -14)
	vista.add_child(poco)

# ------------------------------------------------------------------ props CC0
func _props() -> void:
	var k := "kenney_graveyard_kit/"
	var h := "kaykit_halloween_bits/"
	# Arvore-Ambar: pinheiro dourado gigante no alto do penhasco (o "Erdtree" da ilha)
	var arv := _modelo(h + "tree_pine_yellow_large.gltf", Vector3(-15, 7, -36), 6.0, 20)
	_modelo(h + "tree_pine_orange_large.gltf", Vector3(-22, 7, -26), 3.0, 70)
	_modelo(h + "tree_pine_yellow_medium.gltf", Vector3(-9, 7, -25), 2.2, 10)
	_modelo(h + "tree_pine_orange_medium.gltf", Vector3(16, 7, -27), 2.4, 40)
	_modelo(h + "tree_pine_yellow_large.gltf", Vector3(25, 7, -32), 3.2, 120)
	_modelo(h + "tree_dead_large.gltf", Vector3(-7.5, 7, -22.5), 2.2, 200)
	if arv:
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.78, 0.35)
		luz.light_energy = 2.5
		luz.omni_range = 16.0
		luz.position = Vector3(-15, 16, -34)
		vista.add_child(luz)
	# arco em ruina na beira da queda
	_modelo(h + "arch.gltf", Vector3(5.2, 7, -21.6), 2.6, 0)
	_modelo(k + "column-large.gltf".replace(".gltf", ".glb"), Vector3(-5.6, 7, -21.6), 2.4, 15)
	_modelo(k + "pillar-obelisk.glb", Vector3(-6.4, 7, -25), 3.0, 0)
	# rochas Kenney (Pirate Kit) quebrando as arestas retas dos penhascos
	var rr := RandomNumberGenerator.new()
	rr.seed = 909
	for i in 0:
		var x := -28.0 + i * 4.4 + rr.randf_range(-0.6, 0.6)
		if absf(x) < 4.2:
			continue
		_modelo("kenney_pirate_kit/" + ["rocks-a.glb", "rocks-b.glb", "rocks-c.glb"][i % 3], Vector3(x, 6.6, -19.8 - rr.randf_range(0, 2.5)), rr.randf_range(0.8, 1.5), rr.randf_range(0, 360))
	for i in 10:
		_modelo("kenney_pirate_kit/" + ["rocks-a.glb", "rocks-c.glb"][i % 2], Vector3(rr.randf_range(-16, 16), -26.0, rr.randf_range(-18, -9)), rr.randf_range(1.5, 3.0), rr.randf_range(0, 360))
	# planalto: pinheiros, rochas, cerca de pedra quebrada e o caminho
	var r := RandomNumberGenerator.new()
	r.seed = 77
	_planalto()
	# o Mirante: altar de pedra com chama dourada (a "graca" do lugar) e braseiros
	_modelo(k + "altar-stone.glb", Vector3(0, 0, -7.4), 1.6, 0)
	for x in [-2.9, 2.9]:
		_modelo(k + "fire-basket.glb", Vector3(x, 0, -4.4), 1.7, 0)
		var fogo := OmniLight3D.new()
		fogo.light_color = Color(1.0, 0.55, 0.25)
		fogo.light_energy = 1.8
		fogo.omni_range = 6.0
		fogo.position = Vector3(x, 1.4, -4.4)
		fogo.set_meta("tremula", true)
		vista.add_child(fogo)
	var graca := OmniLight3D.new()
	graca.name = "LuzDaGraca"
	graca.light_color = Color(1.0, 0.82, 0.42)
	graca.light_energy = 2.2
	graca.omni_range = 7.0
	graca.position = Vector3(0, 1.6, -7.4)
	vista.add_child(graca)
	# raios de luz falsos saindo do sol, atravessando o canion
	for i in 4:
		var raio := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(5.0 + i * 1.5, 60.0)
		raio.mesh = q
		raio.material_override = _mat("raio_luz", {"forca": 0.035 + 0.01 * i})
		raio.position = Vector3(-14.0 + i * 9.0, 2.0, -26.0)
		raio.rotation_degrees = Vector3(-78.0, 0.0, -10.0 + i * 7.0)
		raio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vista.add_child(raio)

# ------------------------------------------------------------------ planalto (passo 2)
const QN := "quaternius_natureza/"
func _trilha_x(z: float) -> float:
	# mesma curva do shader chao.gdshader (z local da malha = z da vista - 11)
	return sin((z - 11.0) * 0.22) * 1.3

func _longe_da_trilha(p: Vector3, folga: float) -> bool:
	return absf(p.x - _trilha_x(p.z)) > folga

func _planalto() -> void:
	# chao com textura (grama dourada, flores e trilha ate o altar)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	pm.subdivide_width = 1
	chao.mesh = pm
	chao.material_override = _mat("chao")
	chao.position = Vector3(0, 0.012, 11.0)
	vista.add_child(chao)
	var lip := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(7, 5)
	lip.mesh = pm2
	lip.material_override = _mat("chao", {"trilha_z0": -40.0})
	lip.position = Vector3(0, 0.012, -6.0)
	vista.add_child(lip)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	# pedras da trilha
	var z := 20.0
	while z > -6.0:
		_modelo(QN + ["RockPath_Round_Small_1.gltf", "RockPath_Round_Small_2.gltf", "RockPath_Round_Small_3.gltf"][r.randi() % 3], Vector3(_trilha_x(z) + r.randf_range(-0.4, 0.4), 0.02, z), r.randf_range(0.9, 1.3), r.randf_range(0, 360))
		z -= r.randf_range(1.4, 2.2)
	# arvores variadas (outono/poente), longe da trilha e das bordas do penhasco
	var arvores := ["CommonTree_3_Outono.gltf", "Pine_1.gltf", "CommonTree_4_Outono.gltf", "TwistedTree_1.gltf", "TwistedTree_3.gltf", "Pine_2.gltf", "Pine_4.gltf"]
	var spots := [Vector3(-11.5, 0, 9.5), Vector3(-10.5, 0, 1.5), Vector3(-12, 0, 16), Vector3(-9, 0, 21), Vector3(11, 0, 8.5), Vector3(12, 0, 2), Vector3(9.5, 0, 15), Vector3(12, 0, 21), Vector3(-6, 0, 24), Vector3(6, 0, 24)]
	for i in spots.size():
		_modelo(QN + arvores[i % arvores.size()], spots[i], r.randf_range(0.75, 1.05), r.randf_range(0, 360))
	_modelo("kaykit_halloween_bits/tree_pine_yellow_medium.gltf", Vector3(-12.2, 0, 5), 1.8, 10)
	_modelo("kaykit_halloween_bits/tree_pine_orange_medium.gltf", Vector3(12.4, 0, 12), 1.8, 50)
	# grama alta, flores, arbustos, samambaias, seixos
	var miudos := ["Grass_Common_Tall.gltf", "Grass_Wispy_Tall.gltf", "Flower_3_Group.gltf", "Flower_4_Group.gltf", "Bush_Common_Flowers.gltf", "Fern_1.gltf", "Clover_1.gltf", "Pebble_Round_1.gltf", "Plant_1.gltf"]
	var n := 0
	var tent := 0
	while n < 90 and tent < 600:
		tent += 1
		var p := Vector3(r.randf_range(-12.5, 12.5), 0.0, r.randf_range(-3.0, 25.0))
		if not _longe_da_trilha(p, 1.6) or p.distance_to(Vector3(0, 0, 7.5)) < 2.2 or p.distance_to(Vector3(-7.5, 0, 6)) < 3.0:
			continue
		_modelo(QN + miudos[r.randi() % miudos.size()], p, r.randf_range(0.7, 1.3), r.randf_range(0, 360))
		n += 1
	# rochas naturais na beira do penhasco (balaustrada natural) e nas quinas
	for i in 11:
		var x := -12.5 + i * 2.5
		if absf(x) < 3.6:
			continue
		_modelo(QN + ["Rock_Medium_1.gltf", "Rock_Medium_2.gltf", "Rock_Medium_3.gltf"][i % 3], Vector3(x + r.randf_range(-0.5, 0.5), -0.2, -3.6 + r.randf_range(-0.3, 0.3)), r.randf_range(1.3, 2.1), r.randf_range(0, 360))
	for p in [Vector3(-3.5, 0, -8.2), Vector3(3.4, 0, -8.0), Vector3(-3.8, 0, -4.2), Vector3(3.9, 0, -4.0)]:
		_modelo(QN + "Rock_Medium_2.gltf", p, r.randf_range(1.0, 1.4), r.randf_range(0, 360))
	_modelo("kenney_graveyard_kit/pillar-small.glb", Vector3(-2.2, 0, -5.0), 1.6, 0)
	_modelo("kenney_graveyard_kit/pillar-small.glb", Vector3(2.2, 0, -5.0), 1.6, 0)
	_modelo("kenney_graveyard_kit/bench-damaged.glb", Vector3(5.2, 0, -1.6), 1.6, 200)
	_modelo("kenney_graveyard_kit/trunk-long.glb", Vector3(-8.5, 0, 12.5), 1.8, 70)
	# lagoa com mini cascata (ondulacoes) a esquerda da trilha
	var lagoa := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 2.6
	cil.bottom_radius = 2.6
	cil.height = 0.05
	cil.radial_segments = 28
	lagoa.mesh = cil
	lagoa.material_override = _mat("agua", {"fluxo": Vector2(0.02, 0.05), "centro_ondas": vista.to_global(Vector3(-8.6, 0, 4.4)), "ondas": 1.0})
	lagoa.position = Vector3(-7.5, 0.05, 6.0)
	vista.add_child(lagoa)
	for i in 12:
		var ang := TAU * i / 12.0
		_modelo(QN + ["Rock_Medium_1.gltf", "Pebble_Round_2.gltf", "Rock_Medium_3.gltf"][i % 3], Vector3(-7.5 + cos(ang) * 2.8, -0.15, 6.0 + sin(ang) * 2.8), r.randf_range(0.55, 0.9) if i % 3 != 1 else 1.4, r.randf_range(0, 360))
	_modelo(QN + "Rock_Medium_1.gltf", Vector3(-8.9, 0, 3.6), 2.0, 30)
	_queda(Vector3(-8.6, 1.35, 4.25), 0.9, 1.35, 2.2, 3.0)
	_parede(Vector3(-7.5, 1, 6.0), Vector3(4.6, 3, 4.6))

# ------------------------------------------------------------------ particulas
func _textura_suave() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt

func _emissor(nome: String, pos: Vector3, caixa: Vector3, qtd: int, vida: float, tam: float, cor: Color, vel: Vector3, aditivo := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	p.amount = qtd
	p.lifetime = vida
	p.preprocess = vida
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caixa
	pm.direction = vel.normalized() if vel.length() > 0 else Vector3.UP
	pm.initial_velocity_min = vel.length() * 0.6
	pm.initial_velocity_max = vel.length() * 1.2
	pm.spread = 35.0
	pm.gravity = Vector3(0, -0.2 if not aditivo else 0.05, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.2))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.alpha_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = cor
	sm.albedo_texture = _textura_suave()
	sm.disable_receive_shadows = true
	q.material = sm
	p.draw_pass_1 = q
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vista.add_child(p)
	return p

func _particulas() -> void:
	_emissor("BrumaDaQueda", Vector3(0, -24.5, -19), Vector3(7, 1.0, 2.5), 90, 6.0, 9.0, Color(1.0, 0.9, 0.85, 0.35), Vector3(0, 1.8, 1.2))
	_emissor("BrumaDoTopo", Vector3(0, 6.6, -20.6), Vector3(3.8, 0.4, 0.6), 30, 2.5, 3.0, Color(1, 0.95, 0.9, 0.3), Vector3(0, 0.6, 0.8))
	_emissor("BrasasDouradas", Vector3(-15, 12, -34), Vector3(6, 6, 5), 70, 7.0, 0.35, Color(1.0, 0.75, 0.35, 0.9), Vector3(0.4, 0.3, 0.5), true)
	_emissor("GracaDoMirante", Vector3(0, 1.0, -7.4), Vector3(0.4, 0.1, 0.4), 40, 3.0, 0.25, Color(1.0, 0.85, 0.45, 1.0), Vector3(0, 1.2, 0), true)
	_emissor("CinzasNoAr", Vector3(0, 4, 2), Vector3(14, 4, 10), 60, 9.0, 0.18, Color(1.0, 0.7, 0.45, 0.8), Vector3(0.3, 0.15, -0.2), true)

# ------------------------------------------------------------------ ceu pintado que acompanha a camera
func _ceu() -> void:
	ceu = MeshInstance3D.new()
	ceu.name = "CeuPoente"
	var q := QuadMesh.new()
	q.size = Vector2(2, 1)
	ceu.mesh = q
	ceu.material_override = _mat("ceu_poente")
	ceu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ceu.extra_cull_margin = 16384.0
	add_child(ceu)

func _ceu_seguir() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or ceu == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var asp := vp.x / maxf(vp.y, 1.0)
	var dist := minf(cam.far * 0.92, 360.0)
	var alt: float
	var hz := 0.55
	if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		alt = cam.size * 1.02
		hz = 0.34
	else:
		alt = 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) * 1.02
		var pitch := asin(clampf(-cam.global_transform.basis.z.y, -0.99, 0.99))
		hz = clampf(0.5 + tan(pitch) / (2.0 * tan(deg_to_rad(cam.fov) * 0.5)) + 0.04, 0.12, 0.8)
	var b := cam.global_transform.basis
	ceu.global_transform = Transform3D(b.scaled(Vector3(alt * asp * 0.5, alt, 1.0)), cam.global_position - b.z * dist)
	var m: ShaderMaterial = ceu.material_override
	m.set_shader_parameter("horizonte", hz)
	m.set_shader_parameter("aspecto", asp)
	m.set_shader_parameter("sol", Vector2(0.66 if vitrine else 0.5, hz - 0.03))

# ------------------------------------------------------------------ o mirante (tomada cinematografica)
func _mirante_area() -> void:
	var a := Area3D.new()
	a.name = "Mirante"
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6.6, 3.0, 4.4)
	cs.shape = sh
	a.add_child(cs)
	a.position = Vector3(0, 1.0, -6.4)
	vista.add_child(a)
	a.body_entered.connect(_entrou)
	a.body_exited.connect(_saiu)

func _entrou(b: Node) -> void:
	if not (b is CharacterBody3D) or no_mirante:
		return
	no_mirante = true
	cam_antes = get_viewport().get_camera_3d()
	relogio = 0.0
	cam_cine.current = true
	if legenda:
		create_tween().tween_property(legenda, "modulate:a", 1.0, 1.2)

func _saiu(b: Node) -> void:
	if not (b is CharacterBody3D) or not no_mirante:
		return
	no_mirante = false
	if is_instance_valid(cam_antes):
		cam_antes.current = true
	if legenda:
		create_tween().tween_property(legenda, "modulate:a", 0.0, 0.6)

func _pose_cine(t: float) -> void:
	# passeio lento: de frente para a queda, com o sol atras da cortina d'agua
	var s := sin(t * 0.07)
	if vitrine:
		# tela inicial: menu a esquerda; cachoeira e sol a direita do centro
		cam_cine.position = Vector3(-4.0 + s * 1.5, 12.0 + cos(t * 0.05) * 0.6, 9.0 - s * 1.0)
		cam_cine.look_at(vista.to_global(Vector3(-7.5 + s * 1.0, 4.0, -34.0)), Vector3.UP)
		return
	var pos := Vector3(4.0 + s * 5.0, 13.0 + cos(t * 0.05) * 1.2, 15.0 - s * 2.0)
	cam_cine.position = pos
	cam_cine.look_at(vista.to_global(Vector3(-1.0 + s * 2.0, 3.0, -34.0)), Vector3.UP)

var _we: WorldEnvironment
var _sol: DirectionalLight3D
var _rim: DirectionalLight3D
func _ajustar_neblina() -> void:
	# camera isometrica (ortografica, 40 m de distancia) acumula neblina demais: versao mais limpa
	var cam := get_viewport().get_camera_3d()
	if _we == null:
		_we = get_node_or_null("AmbientePoente")
	if cam == null or _we == null:
		return
	var orto := cam.projection == Camera3D.PROJECTION_ORTHOGONAL
	_we.environment.volumetric_fog_density = 0.0008 if orto else 0.0028
	_we.environment.fog_density = 0.0006 if orto else 0.0016
	_we.environment.adjustment_contrast = 1.06 if orto else 1.12
	# isometrica: sol mais alto e de lado (sombras curtas e suaves) + luz de contorno quente por tras;
	# cinematografica: sol baixo em contraluz, sombras longas do poente
	if _sol:
		_sol.rotation_degrees = Vector3(-42.0, 205.0, 0.0) if orto else Vector3(-19.0, 172.0, 0.0)
		_sol.shadow_opacity = 0.55 if orto else 0.85
		_sol.light_energy = 1.35 if orto else 1.6
	if _rim:
		_rim.light_energy = 0.9 if orto else 0.35
	if orto and is_instance_valid(get_parent()) and get_parent().get("cam_size") != null and cam.size < 22.0:
		get_parent().cam_size = 22.0
		cam.size = 22.0

func _process(delta: float) -> void:
	relogio += delta
	_ajustar_neblina()
	if vitrine or no_mirante:
		_pose_cine(relogio + (12.0 if vitrine else 0.0))
	_ceu_seguir()
	# braseiros tremulando
	for l in vista.get_children():
		if l is OmniLight3D and l.has_meta("tremula"):
			(l as OmniLight3D).light_energy = 1.6 + sin(relogio * 11.0 + l.position.x) * 0.25 + sin(relogio * 23.0) * 0.12
