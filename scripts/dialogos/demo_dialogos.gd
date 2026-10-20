extends Node3D
## Cena de teste das conversas (nao mexe em main.tscn). Abra scenes/dialogos/demo_dialogos.tscn e rode com F6.
## Os moradores nascem nos Marker3D filhos de "Marcadores" (nome = id do morador).
## WASD andar | Shift correr | E conversar | F2 zerar conversas

const Interacao = preload("res://scripts/dialogos/interacao_npcs.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const ActorVisual = preload("res://scripts/actor_visual.gd")

const VELOCIDADE := 3.4
const CORRIDA := 5.6
const REGIOES := [
	{"nome": "Porto Velho", "centro": Vector2(0, 0), "raio": 9.0, "cor": "4f6b3a"},
	{"nome": "Vila dos Orcs", "centro": Vector2(19, 2), "raio": 5.0, "cor": "6b4a2a"},
	{"nome": "Cidade Fantasma", "centro": Vector2(-19, 2), "raio": 5.0, "cor": "3d3a4a"},
	{"nome": "Ilha Selvagem", "centro": Vector2(0, -19), "raio": 5.0, "cor": "2f4a2a"},
	{"nome": "Rota do Âmbar", "centro": Vector2(0, 19), "raio": 5.0, "cor": "8a6a3a"},
]

var jogador: CharacterBody3D
var sprite: Node3D
var camera: Camera3D
var dialogos
var hud: Label
var registro_eventos: Label
var _eventos: Array = []

func _ready() -> void:
	_ambiente()
	_chao()
	_jogador()
	_camera()
	_hud()
	dialogos = Interacao.new()
	dialogos.name = "InteracaoNpcs"
	dialogos.jogador = jogador
	add_child(dialogos)
	var npcs := Interacao.spawn_em_marcadores($Marcadores, $Moradores)
	for n in npcs:
		n.olhar_para(Vector3(0, 0, 0) if n.position.length() > 0.1 else Vector3(0, 0, 5))
	Estado.global().evento.connect(_evento)
	dialogos.conversa_encerrada.connect(func(id): _evento("fim", id))

func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("141a24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a7a9c")
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("3a2f3f")
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color("ffd9a8")
	sol.light_energy = 1.25
	sol.rotation_degrees = Vector3(-52, -35, 0)
	sol.shadow_enabled = true
	add_child(sol)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _chao() -> void:
	var chao := StaticBody3D.new()
	chao.name = "Chao"
	var malha := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(64, 64)
	malha.mesh = pm
	malha.material_override = _mat(Color("2b2f26"))
	chao.add_child(malha)
	var forma := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(64, 1, 64)
	forma.shape = bs
	forma.position.y = -0.5
	chao.add_child(forma)
	add_child(chao)
	for r in REGIOES:
		var disco := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r.raio
		cm.bottom_radius = r.raio
		cm.height = 0.04
		cm.radial_segments = 24
		disco.mesh = cm
		disco.material_override = _mat(Color(r.cor))
		disco.position = Vector3(r.centro.x, 0.02, r.centro.y)
		add_child(disco)
		var placa := Label3D.new()
		placa.text = r.nome
		placa.font = preload("res://scripts/dialogos/npcs_registro.gd").fonte()
		placa.font_size = 64
		placa.pixel_size = 0.008
		placa.outline_size = 14
		placa.modulate = Color("f1e2bd")
		placa.outline_modulate = Color("1b1410")
		placa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		placa.position = Vector3(r.centro.x, 3.4, r.centro.y - r.raio * 0.55)
		add_child(placa)
	# caminhos de terra ligando as regioes ao porto
	for alvo in [Vector2(19, 2), Vector2(-19, 2), Vector2(0, -19), Vector2(0, 19)]:
		var trilha := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var comp: float = alvo.length() - 12.0
		bm.size = Vector3(1.6, 0.03, comp)
		trilha.mesh = bm
		trilha.material_override = _mat(Color("5a4a36"))
		var meio: Vector2 = alvo.normalized() * (9.0 + comp * 0.5)
		trilha.position = Vector3(meio.x, 0.025, meio.y)
		trilha.rotation.y = atan2(alvo.x, alvo.y)
		add_child(trilha)

func _jogador() -> void:
	jogador = CharacterBody3D.new()
	jogador.name = "Vale"
	jogador.add_to_group("jogador")
	var forma := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.4
	forma.shape = cap
	forma.position.y = 0.7
	jogador.add_child(forma)
	var a := ActorVisual.new()
	a.setup("original_apprentice")
	sprite = a
	jogador.add_child(sprite)
	jogador.position = Vector3(0, 0.05, 4.5)
	add_child(jogador)

func _camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.rotation_degrees = Vector3(-35.264, 45, 0)
	add_child(camera)
	camera.current = true
	_seguir(1.0)

func _seguir(peso: float) -> void:
	var alvo := jogador.position + Vector3(0, 0.8, 0)
	var desloc := camera.basis.z * 30.0
	camera.position = camera.position.lerp(alvo + desloc, peso)

func _hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.add_theme_font_override("font", preload("res://scripts/dialogos/npcs_registro.gd").fonte())
	hud.text = "Demo de conversas · WASD andar · Shift correr · E conversar · F2 zerar conversas"
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("f1e2bd"))
	hud.add_theme_color_override("font_outline_color", Color("1b1410"))
	hud.add_theme_constant_override("outline_size", 6)
	cl.add_child(hud)
	registro_eventos = Label.new()
	registro_eventos.add_theme_font_override("font", preload("res://scripts/dialogos/npcs_registro.gd").fonte())
	registro_eventos.position = Vector2(24, 54)
	registro_eventos.add_theme_font_size_override("font_size", 18)
	registro_eventos.add_theme_color_override("font_color", Color("c9a25a"))
	registro_eventos.add_theme_color_override("font_outline_color", Color("1b1410"))
	registro_eventos.add_theme_constant_override("outline_size", 5)
	cl.add_child(registro_eventos)

func _evento(nome: String, valor) -> void:
	var t := ""
	match nome:
		"refeicao": t = "Refeição: %s (bônus até o fim do dia)" % valor
		"missao": t = "Novo pedido no mural: %s" % valor
		"confianca": t = "Confiança de %s: %d" % [valor.npc, valor.valor]
		"fim": t = "Conversa com %s encerrada" % valor
		_: return
	_eventos.push_front(t)
	_eventos = _eventos.slice(0, 5)
	registro_eventos.text = "\n".join(_eventos)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		Estado.reiniciar_global()
		Estado.global().evento.connect(_evento)
		_eventos.clear()
		registro_eventos.text = "Conversas zeradas: todos voltam à primeira conversa."

func _physics_process(delta: float) -> void:
	var entrada := Vector2.ZERO
	if not dialogos.conversando:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): entrada.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): entrada.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): entrada.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): entrada.x += 1
	entrada = entrada.normalized()
	var correndo := Input.is_physical_key_pressed(KEY_SHIFT)
	# camera isometrica: cima na tela = (-1, 0, -1) no mundo
	var frente := Vector3(-1, 0, -1).normalized()
	var direita := Vector3(1, 0, -1).normalized()
	var dir := direita * entrada.x - frente * entrada.y
	var v := dir * (CORRIDA if correndo else VELOCIDADE)
	jogador.velocity.x = v.x
	jogador.velocity.z = v.z
	jogador.velocity.y = 0.0 if jogador.is_on_floor() else jogador.velocity.y - 9.8 * delta
	jogador.move_and_slide()
	if sprite.has_method("set_direction"):
		sprite.set_direction(entrada)
		sprite.set_motion(entrada.length() > 0.1, correndo, false, false)
	_seguir(clampf(delta * 6.0, 0.0, 1.0))
