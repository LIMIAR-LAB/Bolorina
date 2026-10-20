extends Node3D
## Ponto físico de viagem numa área (PROPOSTA): doca de dirigível ou totem. Mostra o rótulo e
## "[E] Viajar" perto da jogadora e abre o mapa-mundi pintado do jogo no modo viagem (jogo_ilha.gd -> abrir_viagem).
## Integracao 20/10: antes abria o hub "Mapa das Ilhas" (guardado sem uso em nao_usado/hub_mapa_das_ilhas/).
## Posição/tipo/rótulo vêm de data/areas.json (ponto_de_viagem da área); as exportações servem
## para áreas sem pos no registro (gerenciador da ilha põe o totem por código).
const Registro = preload("res://scripts/mundo/registro_areas.gd")

signal abriu_mapa

@export var area_id := ""
@export var tipo := ""                 # "dirigivel" | "totem" (vazio = do registro)
@export var pos_xz := Vector2.INF      # INF = do registro
@export var angulo := 0.0
@export var rotulo_texto := ""
@export var raio_interacao := 3.4

var mapa: Node
var dados: Dictionary = {}
var prompt: Label3D
var rotulo: Label3D
var perto := false
var pronto := false
var acento := Color("ffcf7a")
var _giram: Array = []
var _flutuam: Array = []
var _t := 0.0

func _ready() -> void:
	add_to_group("ponto_viagem")
	call_deferred("_montar")

func _montar() -> void:
	mapa = get_parent()
	dados = Registro.area(area_id).get("ponto_de_viagem", {}).duplicate()
	if tipo != "":
		dados["tipo"] = tipo
	if pos_xz != Vector2.INF:
		dados["pos"] = [pos_xz.x, pos_xz.y]
		dados["ang"] = angulo
	if rotulo_texto != "":
		dados["rotulo"] = rotulo_texto
	if not dados.has("pos"):
		push_warning("ponto_viagem: %s sem ponto_de_viagem em data/areas.json" % area_id)
		return
	var cores := {"vila_orcs": "ff8a3a", "cidade_fantasma": "9fd8ff", "estacao_depois_de_ontem": "7af4ff", "fazenda_do_alto": "c8f08a", "arena_das_cinzas": "ff9a7a"}
	acento = Color(String(cores.get(area_id, "ffcf7a")))
	var x := float(dados.pos[0])
	var z := float(dados.pos[1])
	position = Vector3(x, altura(x, z), z)
	rotation.y = deg_to_rad(float(dados.get("ang", 0.0)))
	name = "PontoViagem"
	var t := String(dados.get("tipo", "totem"))
	if t == "dirigivel":
		_dirigivel()
	else:
		_totem()
	var h := 8.4 if t == "dirigivel" else 5.6
	rotulo = _label(String(dados.get("rotulo", "Mapa-múndi")), Vector3(0, h, 0), Color("ffe6b0"), 0.013)
	prompt = _label("[E] Viajar", Vector3(0, h - 1.5, 0), Color("fff6c8"), 0.011)
	prompt.visible = false
	pronto = true

## altura do chão no mapa (mapa_cc0._y, vila.altura ou raio para baixo)
func altura(x: float, z: float) -> float:
	if mapa.has_method("_y"):
		return float(mapa._y(x, z))
	var v = mapa.get("vila")
	if v is Object and v.has_method("altura"):
		return float(v.altura(x, z))
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -40, z))
	var w := get_world_3d()
	if w:
		var hit := w.direct_space_state.intersect_ray(q)
		if hit:
			return float(hit.position.y)
	return 0.0

## frente do ponto (onde a jogadora chega pelo mapa)
func ponto_de_chegada() -> Vector3:
	var a := rotation.y
	var p := position + Vector3(sin(a), 0, cos(a)) * 2.8
	p.y = altura(p.x, p.z)
	return p

func jogador() -> Node3D:
	for k in ["jogador", "player"]:
		var j = mapa.get(k)
		if j is Node3D:
			return j
	return null

# ------------------------------------------------------------------ visual
func _mat(cor: Color, emissao := 0.0, metal := 0.0, alfa := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor, alfa)
	m.roughness = 0.75
	m.metallic = metal
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	if alfa < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _malha(mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, pai: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	(pai if pai else self).add_child(mi)
	return mi

func _caixa(tam: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, pai: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = tam
	return _malha(b, pos, m, rot, pai)

func _cilindro(r_topo: float, r_base: float, h: float, pos: Vector3, m: Material, lados := 12, pai: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_topo
	c.bottom_radius = r_base
	c.height = h
	c.radial_segments = lados
	return _malha(c, pos, m, Vector3.ZERO, pai)

func _colisao(raio: float, h: float, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.add_to_group("navegavel")
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = raio
	sh.height = h
	cs.shape = sh
	cs.position = pos + Vector3(0, h * 0.5, 0)
	sb.add_child(cs)
	add_child(sb)

func _luz(pos: Vector3, cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	add_child(l)
	return l

func _label(texto: String, pos: Vector3, cor: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.position = pos
	l.pixel_size = px
	l.font_size = 64
	l.outline_size = 14
	l.modulate = cor
	l.outline_modulate = Color(0.06, 0.03, 0.02, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f = load("res://art/ui/dialogos/fontes/PixelifySans.ttf")
	if f:
		l.font = f
	add_child(l)
	return l

func _dirigivel() -> void:
	var madeira := _mat(Color("6b4a2e"))
	var madeira2 := _mat(Color("4a3220"))
	var ferro := _mat(Color("3a3836"), 0.0, 0.6)
	# plataforma de atracação
	_caixa(Vector3(3.6, 0.28, 3.0), Vector3(0, 0.14, -0.4), madeira)
	for px in [-1.6, 1.6]:
		for pz in [-1.7, 0.9]:
			_caixa(Vector3(0.22, 0.9, 0.22), Vector3(px, 0.45, pz), madeira2)
	_caixa(Vector3(3.6, 0.1, 0.12), Vector3(0, 0.95, -1.7), madeira2)
	# mastro de amarração com lanterna
	_cilindro(0.12, 0.2, 6.2, Vector3(-1.2, 3.1, -1.2), ferro, 8)
	_caixa(Vector3(1.6, 0.12, 0.12), Vector3(-0.5, 6.0, -1.2), ferro)
	var lanterna := _caixa(Vector3(0.3, 0.4, 0.3), Vector3(0.2, 5.7, -1.2), _mat(Color("ffcf7a"), 3.0))
	_luz(Vector3(0.2, 5.4, -1.2), Color("ffcf7a"), 2.2, 9.0)
	_colisao(0.35, 6.2, Vector3(-1.2, 0, -1.2))
	# dirigível flutuando ao lado
	var nave := Node3D.new()
	nave.name = "Dirigivel"
	nave.position = Vector3(0.6, 6.4, -3.6)
	add_child(nave)
	_flutuam.append([nave, nave.position.y, 0.0])
	var balao := SphereMesh.new()
	balao.radius = 1.3
	balao.height = 2.6
	balao.radial_segments = 24
	balao.rings = 12
	var bi := _malha(balao, Vector3.ZERO, _mat(Color("8c2f3a")), Vector3.ZERO, nave)
	bi.scale = Vector3(2.5, 1.0, 1.0)
	for k in [-1.6, 0.0, 1.6]:
		var anel := TorusMesh.new()
		anel.inner_radius = 1.22 * sqrt(1.0 - pow(k / 3.25, 2.0))
		anel.outer_radius = anel.inner_radius + 0.08
		_malha(anel, Vector3(k, 0, 0), _mat(Color("d8b06a"), 0.0, 0.5), Vector3(0, 0, PI * 0.5), nave)
	_caixa(Vector3(1.8, 0.5, 0.7), Vector3(0, -1.75, 0), madeira, Vector3.ZERO, nave)
	_caixa(Vector3(0.05, 0.6, 0.05), Vector3(-0.7, -1.2, 0.3), ferro, Vector3.ZERO, nave)
	_caixa(Vector3(0.05, 0.6, 0.05), Vector3(0.7, -1.2, 0.3), ferro, Vector3.ZERO, nave)
	_caixa(Vector3(0.05, 0.6, 0.05), Vector3(-0.7, -1.2, -0.3), ferro, Vector3.ZERO, nave)
	_caixa(Vector3(0.05, 0.6, 0.05), Vector3(0.7, -1.2, -0.3), ferro, Vector3.ZERO, nave)
	_caixa(Vector3(0.06, 1.1, 0.7), Vector3(-3.3, 0.3, 0), _mat(Color("5e1e28")), Vector3.ZERO, nave)
	var helice := Node3D.new()
	helice.position = Vector3(-3.5, 0, 0)
	nave.add_child(helice)
	_caixa(Vector3(0.05, 1.2, 0.12), Vector3.ZERO, ferro, Vector3.ZERO, helice)
	_caixa(Vector3(0.05, 0.12, 1.2), Vector3.ZERO, ferro, Vector3.ZERO, helice)
	_giram.append([helice, Vector3(6.0, 0, 0)])
	var janela := _caixa(Vector3(1.4, 0.16, 0.72), Vector3(0, -1.65, 0), _mat(Color("ffd890"), 1.6), Vector3.ZERO, nave)
	# corda do mastro até o dirigível
	var a := Vector3(-1.2, 6.0, -1.2)
	var b := nave.position + Vector3(0, -1.5, 0)
	var corda := _cilindro(0.025, 0.025, a.distance_to(b), (a + b) * 0.5, madeira2, 4)
	corda.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	corda.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _totem() -> void:
	var pedra := _mat(Color("5d5652"))
	var pedra2 := _mat(Color("403b39"))
	if area_id == "cidade_fantasma":
		pedra = _mat(Color("4a4f5c"))
		pedra2 = _mat(Color("2e3240"))
	elif area_id == "estacao_depois_de_ontem":
		pedra = _mat(Color("8a93a6"), 0.0, 0.6)
		pedra2 = _mat(Color("39404e"), 0.0, 0.5)
	_cilindro(1.25, 1.45, 0.35, Vector3(0, 0.17, 0), pedra2, 8)
	_cilindro(0.95, 1.1, 0.3, Vector3(0, 0.5, 0), pedra, 8)
	_cilindro(0.28, 0.5, 3.2, Vector3(0, 2.25, 0), pedra, 4)
	_cilindro(0.34, 0.3, 0.3, Vector3(0, 3.95, 0), pedra2, 4)
	_colisao(0.6, 4.0, Vector3.ZERO)
	# runas brilhando no obelisco
	var runa := _mat(acento, 2.6)
	for k in 4:
		var r := _caixa(Vector3(0.08, 0.5, 0.06), Vector3(0, 1.4 + k * 0.55, 0.36 - k * 0.025), runa)
		r.rotation.z = 0.3 * (1 if k % 2 == 0 else -1)
	# anel girando + cristal flutuando
	var anel := TorusMesh.new()
	anel.inner_radius = 0.75
	anel.outer_radius = 0.86
	anel.rings = 32
	var ai := _malha(anel, Vector3(0, 4.6, 0), _mat(acento, 2.0, 0.3, 0.85))
	_giram.append([ai, Vector3(0.7, 1.4, 0.0)])
	var cristal := CylinderMesh.new()
	cristal.top_radius = 0.0
	cristal.bottom_radius = 0.32
	cristal.height = 0.7
	cristal.radial_segments = 4
	var piv := Node3D.new()
	piv.position = Vector3(0, 4.6, 0)
	add_child(piv)
	_malha(cristal, Vector3(0, 0.35, 0), _mat(acento.lightened(0.3), 3.0), Vector3.ZERO, piv)
	var baixo := _malha(cristal, Vector3(0, -0.35, 0), _mat(acento.lightened(0.3), 3.0), Vector3(PI, 0, 0), piv)
	_giram.append([piv, Vector3(0, 1.2, 0)])
	_flutuam.append([piv, piv.position.y, 1.3])
	_luz(Vector3(0, 4.4, 0), acento, 2.6, 10.0)
	# mapa de pedra aos pés (placa)
	_caixa(Vector3(1.2, 0.08, 0.8), Vector3(0, 0.7, 1.05), _mat(Color("c9b28a")), Vector3(-0.5, 0, 0))

func _process(delta: float) -> void:
	_t += delta
	for g in _giram:
		var n: Node3D = g[0]
		var v: Vector3 = g[1]
		n.rotation += v * delta
	for f in _flutuam:
		var n: Node3D = f[0]
		n.position.y = float(f[1]) + sin(_t * 1.2 + float(f[2])) * 0.18

func _physics_process(_delta: float) -> void:
	if not pronto:
		return
	var j := jogador()
	if j == null:
		return
	var d := Vector2(j.global_position.x - global_position.x, j.global_position.z - global_position.z).length()
	perto = d < raio_interacao
	prompt.visible = perto

func _unhandled_input(event: InputEvent) -> void:
	if not pronto or not perto:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if mapa.get("demo_mode") == true:
			return
		get_viewport().set_input_as_handled()
		abrir_mapa()

func abrir_mapa():
	abriu_mapa.emit()
	var g: Node = Registro.gerenciador(get_tree())
	if g != null and g.has_method("abrir_viagem"):
		g.abrir_viagem()
		return g
	push_warning("ponto_viagem: jogo sem gerenciador (jogo_ilha); abra pelo jogo_ilha.tscn")
	return null
