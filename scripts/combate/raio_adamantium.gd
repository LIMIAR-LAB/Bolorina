extends Node3D
## "Raio de Adamantium" (visual): orbe de carga entre as maos (cresce com a carga, particulas
## convergindo, luz), feixe longo em 3 camadas aditivas (nucleo HDR branco-ciano para o bloom,
## camada media ciano, halo azul), clarao na boca e no fim, particulas ao longo do feixe.
## Le o estado do jogador a cada quadro (carregando/raio); o dano fica na arena (_golpe_jogador).
const Sh = preload("res://shaders/cmb_raio.gdshader")
var j
var orbe: MeshInstance3D
var orbe_mat: ShaderMaterial
var orbe_luz: OmniLight3D
var convergir: CPUParticles3D
var feixe: Node3D
var camadas: Array = []
var boca: MeshInstance3D
var ponta: MeshInstance3D
var faiscas: CPUParticles3D
var luz_boca: OmniLight3D
var luz_meio: OmniLight3D
var comprimento := 15.0
var largura := 1.0
var fade := 0.0
var t := 0.0

func _mat(cor: Color, intensidade: float, faixas := 40.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Sh
	m.set_shader_parameter("cor", Vector3(cor.r, cor.g, cor.b))
	m.set_shader_parameter("intensidade", intensidade)
	m.set_shader_parameter("faixas", faixas)
	return m

func _esfera(r: float, mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	mi.mesh = s
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _particulas(n: int, vida: float, c0: Color, c1: Color, tam: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	return p

func setup(jogador) -> void:
	j = jogador
	name = "RaioAdamantium"
	orbe_mat = _mat(Color(0.55, 0.95, 1.0), 4.0, 14.0)
	orbe = _esfera(0.5, orbe_mat)
	orbe.name = "OrbeCarga"
	add_child(orbe)
	orbe_luz = OmniLight3D.new()
	orbe_luz.light_color = Color("7fe8ff")
	orbe_luz.omni_range = 4.0
	orbe_luz.shadow_enabled = false
	add_child(orbe_luz)
	convergir = _particulas(48, 0.45, Color(0.6, 1.6, 2.2, 0.0), Color(1.6, 2.6, 3.0, 1.0), 0.07)
	convergir.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	convergir.emission_sphere_radius = 1.5
	convergir.radial_accel_min = -26.0
	convergir.radial_accel_max = -18.0
	convergir.gravity = Vector3.ZERO
	convergir.local_coords = true
	orbe.add_child(convergir)
	feixe = Node3D.new()
	feixe.name = "Feixe"
	add_child(feixe)
	# camadas: [raio relativo, cor, intensidade]
	for c in [[0.5, Color(0.1, 0.3, 1.0), 0.55], [0.3, Color(0.25, 0.8, 1.0), 1.3], [0.15, Color(0.85, 1.0, 1.0), 3.6]]:
		var mi := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.5
		cil.bottom_radius = 0.5
		cil.height = 1.0
		cil.radial_segments = 20
		cil.rings = 1
		mi.mesh = cil
		mi.material_override = _mat(c[1], c[2])
		mi.rotation.x = -PI / 2   # eixo Y do cilindro -> -Z do feixe
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("r", c[0])
		feixe.add_child(mi)
		camadas.append(mi)
	boca = _esfera(0.5, _mat(Color(0.6, 0.95, 1.0), 2.6, 10.0))
	feixe.add_child(boca)
	ponta = _esfera(0.5, _mat(Color(0.4, 0.8, 1.0), 2.0, 10.0))
	feixe.add_child(ponta)
	faiscas = _particulas(90, 0.35, Color(1.4, 2.6, 3.0, 1.0), Color(0.2, 0.5, 1.0, 0.0), 0.09)
	faiscas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	faiscas.direction = Vector3(0, 1, 0)
	faiscas.spread = 180.0
	faiscas.initial_velocity_min = 1.5
	faiscas.initial_velocity_max = 4.5
	faiscas.gravity = Vector3.ZERO
	faiscas.local_coords = false
	feixe.add_child(faiscas)
	luz_boca = OmniLight3D.new()
	luz_boca.light_color = Color("8ff0ff")
	luz_boca.omni_range = 6.5
	feixe.add_child(luz_boca)
	luz_meio = OmniLight3D.new()
	luz_meio.light_color = Color("5fb8ff")
	luz_meio.omni_range = 7.5
	feixe.add_child(luz_meio)
	orbe.visible = false
	feixe.visible = false

func carregando() -> bool:
	return j.estado == "carregando"

func disparando() -> bool:
	return j.estado == "raio"

func atualizar(real: float, comp: float) -> void:
	t += real
	comprimento = comp
	var mao: Vector3 = j.raio_origem()
	# ---- orbe de carga
	var c: float = j.carga
	orbe.visible = carregando() or (disparando() and j.t_estado < 0.12)
	if orbe.visible:
		var pulso := 1.0 + 0.12 * sin(t * 40.0)
		var r := (0.1 + 0.3 * c) * pulso
		orbe.global_position = mao
		orbe.scale = Vector3.ONE * r * 2.0
		orbe_mat.set_shader_parameter("intensidade", 2.0 + 2.5 * c)
		orbe_luz.global_position = mao
		orbe_luz.light_energy = 1.0 + 5.0 * c
		orbe_luz.visible = true
		convergir.emitting = carregando()
		convergir.scale = Vector3.ONE / maxf(orbe.scale.x, 0.05)
	else:
		orbe_luz.visible = false
		convergir.emitting = false
	# ---- feixe
	if disparando():
		fade = minf(1.0, fade + real / 0.06)
	else:
		fade = maxf(0.0, fade - real / 0.16)
	feixe.visible = fade > 0.0
	if not feixe.visible:
		faiscas.emitting = false
		return
	var dir: Vector3 = j.raio_dir
	largura = float(j.raio_largura_atual())
	var tremido := 1.0 + 0.07 * sin(t * 53.0) + 0.05 * sin(t * 31.0)
	feixe.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mao)
	for mi: MeshInstance3D in camadas:
		var rr: float = float(mi.get_meta("r")) * largura * tremido * (0.6 + 0.4 * fade)
		mi.scale = Vector3(rr * 2.0, comprimento, rr * 2.0)
		mi.position = Vector3(0, 0, -comprimento * 0.5)
		(mi.material_override as ShaderMaterial).set_shader_parameter("alfa", fade)
	boca.scale = Vector3.ONE * largura * 0.9 * tremido
	ponta.position = Vector3(0, 0, -comprimento)
	ponta.scale = Vector3.ONE * largura * 0.8 * tremido
	faiscas.emitting = disparando()
	faiscas.emission_box_extents = Vector3(largura * 0.3, largura * 0.3, comprimento * 0.5)
	faiscas.position = Vector3(0, 0, -comprimento * 0.5)
	luz_boca.light_energy = 7.0 * fade
	luz_meio.position = Vector3(0, 0, -comprimento * 0.5)
	luz_meio.light_energy = 5.0 * fade
