extends Node3D
## PROTOTIPO DE COMBATE estilo Hades 2 (cena separada: combat_arena.tscn).
## Plataforma de ruinas sobre o abismo montada com o kit modular da vila V7 (pecas, materiais,
## braseiros com fogo). Nao le nem grava o save do jogo (user://island_v1.json).
## Controles: WASD mover | LMB/J atacar (combo 3) | Espaco/Shift dash | RMB/K especial | R reiniciar
##            F2 piloto automatico | F3 desempenho | F4 caixas de golpe | Esc sair. Controle: X/A/Y + analogico.
const VisualWorld = preload("res://scripts/visual_world.gd")
const KitModular = preload("res://scripts/modular/kit_modular.gd")
const Jogador = preload("res://scripts/combate/jogador_combate.gd")
const Orc = preload("res://scripts/combate/inimigo_orc.gd")
const Quebravel = preload("res://scripts/combate/quebravel.gd")
const Folhas = preload("res://scripts/combate/folhas.gd")
const RaioFx = preload("res://scripts/combate/raio_adamantium.gd")

const LARGURA := 22.0   # eixo x
const FUNDO := 18.0     # eixo z
const YAW := 45.0
const PITCH := 40.0
const CAM_TAMANHO := 15.5

var modo_teste := false
var hitstop_ativo := true
var lenta_ativa := true          # camera lenta da transformacao
var escala_tempo := 1.0         # time_scale alvo fora do hitstop (camera lenta)
var lenta_restante := 0.0
var raio_fx
var barra_forma: ProgressBar
var rotulo_forma: Label
var barra_raio: ProgressBar
var rotulo_raio: Label
var clarao: ColorRect
var tremor_ativo := true
var piloto := false

var art
var kit
var jogador
var camera: Camera3D
var sol: DirectionalLight3D
var ambiente: Environment
var inimigos: Array = []
var props: Array = []
var cam_alvo := Vector3.ZERO
var cam_direita := Vector3.ZERO
var cam_cima := Vector3.ZERO
var cam_tras := Vector3.ZERO
var tremor := 0.0
var hitstop_restante := 0.0
var t := 0.0
var mira_mouse := false
var mouse_t := -10.0
var ultimo_mouse := Vector2.ZERO

# sala
var sala := 1
var onda := 0
var ondas_total := 2
var estado_sala := "inicio"   # inicio | combate | intervalo | limpa | recompensa | porta | derrota
var t_sala := 0.0
var porta: Node3D
var porta_mat: ShaderMaterial
var porta_luz: OmniLight3D
var recompensa: Node3D
var bencaos := 0
var stats := {"lentas": 0, "raio_acertos": 0, "raio_alvos": {}, "hitstops": 0, "tremores": 0, "numeros": 0, "golpes_acertados": 0, "inimigos_mortos": 0, "props_quebrados": 0, "salas_limpas": 0, "curas": 0}

# HUD
var hud: CanvasLayer
var barra_hp: ProgressBar
var texto_hp: Label
var barra_dash: ProgressBar
var barra_especial: ProgressBar
var banner: Label
var banner_t := 0.0
var info: Label
var dicas: Label
var perf: Label
var vinheta: ColorRect
var barras_inimigos := {}
var mostrar_caixas := false
var caixas: Array = []
var corte_tex: Texture2D
var fogo_luzes: Array = []

func _ready() -> void:
	if OS.get_environment("CMB_TESTE") == "1":
		modo_teste = true
	_acoes()
	art = VisualWorld.new()
	art.parent = self
	art.rng.seed = 4242
	art._make_materials()
	art.materials.castle_brick_01.albedo_color = Color("8d8a80")
	art.materials.brown_planks_03.albedo_color = Color("9a7650")
	art.materials.glow.emission = Color("ff9f32")
	kit = KitModular.new()
	kit.setup(art)
	corte_tex = Folhas.textura("res://art/combate/vfx/fx_corte_crescente.png")
	_ambiente()
	_arena()
	_camera()
	jogador = Jogador.new()
	jogador.name = "Vale"
	add_child(jogador)
	jogador.position = Vector3(3.5, 0, 3.5)
	jogador.cam_direita = cam_direita
	jogador.cam_cima = cam_cima
	jogador._virar(-cam_cima + cam_direita * 0.3)
	jogador.golpe.connect(_golpe_jogador)
	jogador.ferido.connect(_jogador_ferido)
	jogador.morreu.connect(_jogador_morreu)
	jogador.dash_feito.connect(_dash_fx)
	jogador.transformacao_iniciada.connect(_transformacao_fx)
	jogador.transformou.connect(_transformou)
	jogador.raio_disparou.connect(_raio_disparou)
	raio_fx = RaioFx.new()
	add_child(raio_fx)
	raio_fx.setup(jogador)
	_props()
	_hud()
	cam_alvo = jogador.position
	_atualizar_camera(1.0)
	DisplayServer.window_set_title("Ilha das Cinzas | Prototipo de combate (Hades-like)")
	_mudar_sala("inicio")

# ------------------------------------------------------------------ entrada
func _acoes() -> void:
	var teclas := {
		"cmb_esquerda": [KEY_A, KEY_LEFT], "cmb_direita": [KEY_D, KEY_RIGHT],
		"cmb_cima": [KEY_W, KEY_UP], "cmb_baixo": [KEY_S, KEY_DOWN],
		"cmb_ataque": [KEY_J], "cmb_dash": [KEY_SPACE, KEY_SHIFT], "cmb_especial": [KEY_K],
		"cmb_forma": [KEY_G], "cmb_raio": [KEY_Q]}
	for a: String in teclas:
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a, 0.25)
		for k: int in teclas[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var botoes := {"cmb_ataque": [JOY_BUTTON_X, MOUSE_BUTTON_LEFT], "cmb_dash": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER], "cmb_especial": [JOY_BUTTON_Y, MOUSE_BUTTON_RIGHT]}
	for a: String in botoes:
		var lista: Array = botoes[a]
		for i in lista.size():
			if a == "cmb_dash" or i == 0:
				var jb := InputEventJoypadButton.new()
				jb.button_index = lista[i]
				InputMap.action_add_event(a, jb)
			else:
				var mb := InputEventMouseButton.new()
				mb.button_index = lista[i]
				InputMap.action_add_event(a, mb)
	for par in [["cmb_forma", JOY_BUTTON_LEFT_SHOULDER], ["cmb_forma", JOY_BUTTON_DPAD_UP]]:
		var fb := InputEventJoypadButton.new()
		fb.button_index = par[1]
		InputMap.action_add_event(par[0], fb)
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event("cmb_raio", rt)
	for par in [["cmb_esquerda", JOY_AXIS_LEFT_X, -1.0], ["cmb_direita", JOY_AXIS_LEFT_X, 1.0], ["cmb_cima", JOY_AXIS_LEFT_Y, -1.0], ["cmb_baixo", JOY_AXIS_LEFT_Y, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = par[1]
		jm.axis_value = par[2]
		InputMap.action_add_event(par[0], jm)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.position.distance_to(ultimo_mouse) > 3.0:
			mira_mouse = true
			mouse_t = t
		ultimo_mouse = event.position
	if event is InputEventMouseButton and event.pressed:
		mira_mouse = true
		mouse_t = t
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			pass
		else:
			mira_mouse = false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				reiniciar_sala()
			KEY_F2:
				piloto = not piloto
				mostrar_banner("PILOTO AUTOMATICO " + ("LIGADO" if piloto else "DESLIGADO"), 1.2)
			KEY_F3:
				perf.visible = not perf.visible
			KEY_F4:
				mostrar_caixas = not mostrar_caixas
			KEY_ESCAPE:
				get_tree().quit()
	if piloto:
		return
	if event.is_action_pressed("cmb_forma"):
		if not jogador.pedir_transformar() and not jogador.transformado:
			mostrar_banner("ADAMANTIUM %d%% - acerte golpes para encher" % roundi(jogador.energia), 1.0)
	elif event.is_action_pressed("cmb_raio") or (jogador.transformado and event.is_action_pressed("cmb_especial")):
		jogador.pedir_raio(_mira())
	elif event.is_action_pressed("cmb_ataque"):
		jogador.pedir_ataque(_mira())
	elif event.is_action_pressed("cmb_dash"):
		jogador.pedir_dash()
	elif event.is_action_pressed("cmb_especial"):
		jogador.pedir_especial(_mira())

func _mira() -> Vector3:
	# Mouse: aponta para o cursor no chao. Controle: analogico direito. Teclado: direcao do movimento.
	var jx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if Vector2(jx, jy).length() > 0.4:
		return cam_direita * jx - cam_cima * jy
	if mira_mouse and not modo_teste:
		var mp := get_viewport().get_mouse_position()
		var o := camera.project_ray_origin(mp)
		var n := camera.project_ray_normal(mp)
		if absf(n.y) > 0.001:
			var p := o + n * ((0.7 - o.y) / n.y)
			var d: Vector3 = p - jogador.global_position
			d.y = 0
			if d.length() > 0.2:
				return d.normalized()
	return Vector3.ZERO

# ------------------------------------------------------------------ ambiente e arena
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color("1a1830")
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("6c6aa3")
	ambiente.ambient_light_energy = 0.55
	ambiente.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.8
	ambiente.glow_bloom = 0.06
	ambiente.glow_hdr_threshold = 1.0
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color("3b3560")
	ambiente.fog_density = 0.004
	ambiente.fog_height = -3.0
	ambiente.fog_height_density = 0.25
	ambiente.adjustment_enabled = true
	ambiente.adjustment_saturation = 1.05
	var lut := "res://scripts/modular/lut_fidelidade.png"
	if FileAccess.file_exists(lut):
		ambiente.adjustment_color_correction = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(lut)))
	we.environment = ambiente
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.light_color = Color("ffc47e")
	sol.light_energy = 1.6
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 60.0
	add_child(sol)
	sol.rotation_degrees = Vector3(-38, 200, 0)

func _arena() -> void:
	var hx := LARGURA * 0.5
	var hz := FUNDO * 0.5
	# piso de pedra + bordas de grama, laterais de rocha descendo ao abismo
	art.box(Vector3(0, -0.5, 0), Vector3(LARGURA, 1.0, FUNDO), "mossy_cobblestone", true)
	art.box(Vector3(0, -7.0, 0), Vector3(LARGURA - 0.6, 12.0, FUNDO - 0.6), "lichen_rock")
	art.box(Vector3(-1.0, -16.0, -1.0), Vector3(LARGURA - 5.0, 8.0, FUNDO - 5.0), "lichen_rock")
	for lado in [[Vector3(0, 0.02, -hz + 0.9), Vector3(LARGURA, 0.06, 1.8)], [Vector3(-hx + 0.9, 0.02, 0), Vector3(1.8, 0.06, FUNDO)]]:
		art.box(lado[0], lado[1], "leafy_grass")
	# lajes claras no centro (circulo ritual)
	var laje: StandardMaterial3D = art.materials.castle_brick_01.duplicate()
	laje.albedo_color = Color("b3aa98")
	art.materials["cmb_laje"] = laje
	for i in 16:
		var a := TAU * i / 16.0
		var b: MeshInstance3D = art.box(Vector3(cos(a) * 3.2, 0.015, sin(a) * 3.2), Vector3(1.3, 0.05, 0.7), "cmb_laje")
		b.rotation.y = -a
	var runa := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.3
	tor.outer_radius = 2.45
	tor.rings = 48
	runa.mesh = tor
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("c99a3f")
	gm.emission_enabled = true
	gm.emission = Color("d7882a")
	gm.emission_energy_multiplier = 0.5
	runa.material_override = gm
	runa.scale.y = 0.05
	add_child(runa)
	# paredes invisiveis nas bordas (nao se cai no abismo)
	for w in [[Vector3(0, 1.5, -hz - 0.5), Vector3(LARGURA + 2, 3, 1)], [Vector3(0, 1.5, hz + 0.5), Vector3(LARGURA + 2, 3, 1)], [Vector3(-hx - 0.5, 1.5, 0), Vector3(1, 3, FUNDO + 2)], [Vector3(hx + 0.5, 1.5, 0), Vector3(1, 3, FUNDO + 2)]]:
		var corpo := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		cs.shape = bs
		corpo.add_child(cs)
		corpo.position = w[0]
		add_child(corpo)
	# muros baixos em ruina nos lados do fundo (topo da tela)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 11:
		if i == 5:
			continue
		var x := -hx + 1.0 + i * 2.0
		var h := rng.randf_range(0.5, 1.5)
		art.box(Vector3(x, h * 0.5, -hz + 0.4), Vector3(1.9, h, 0.7), "castle_brick_01", true)
	for i in 9:
		var z := -hz + 1.0 + i * 2.0
		var h := rng.randf_range(0.5, 1.4)
		art.box(Vector3(-hx + 0.4, h * 0.5, z), Vector3(0.7, h, 1.9), "castle_brick_01", true)
	# pecas do kit modular (vila V7)
	_peca("pilar_braseiro", Vector3(-hx + 1.2, 0, -hz + 1.2))
	_peca("pilar_braseiro", Vector3(hx - 1.2, 0, -hz + 1.2))
	_peca("pilar_braseiro", Vector3(-hx + 1.2, 0, hz - 1.2))
	_peca("pilar_braseiro", Vector3(hx - 1.6, 0, hz - 1.6))
	_peca("ruina_arco", Vector3(-6.0, 0, -hz - 1.6), {"fundo": 18.0})
	_peca("ruina_arco", Vector3(-hx - 1.6, 0, -4.0), {"fundo": 18.0}, 1)
	_peca("ruina_pilar", Vector3(6.5, 0, -hz - 1.0))
	_peca("ruina_pilar", Vector3(-hx - 1.0, 0, 5.0))
	_peca("menir_runa", Vector3(-6.0, 0, -5.5))
	_peca("poste_lampiao", Vector3(4.0, 0, -hz + 1.2))
	_peca("poste_lampiao", Vector3(-hx + 1.2, 0, 3.0))
	_peca("estandarte", Vector3(-2.0, 0, -hz + 1.0))
	_peca("estandarte", Vector3(2.0, 0, -hz + 1.0))
	for p in [Vector3(-hx - 2.5, -0.4, -hz - 2.5), Vector3(hx + 0.5, -0.3, -hz - 2.2), Vector3(-hx - 2.2, -0.3, hz - 1.0)]:
		_peca("arbusto_escuro", p)
	_peca("arvore_seca", Vector3(hx - 2.5, 0, -hz + 2.0))
	_peca("arvore_escura", Vector3(-hx - 2.8, -0.2, 0.5))
	# porta (canto do fundo = topo da tela) com barreira ate limpar a sala
	porta = Node3D.new()
	porta.name = "Porta"
	porta.position = Vector3(0.0, 0, -hz + 0.4)
	add_child(porta)
	for x in [-1.5, 1.5]:
		art.box(Vector3(x, 1.7, 0), Vector3(0.9, 3.4, 0.9), "castle_brick_01", true, porta)
	art.box(Vector3(0, 3.6, 0), Vector3(4.0, 0.7, 1.0), "castle_brick_01", false, porta)
	var cortina := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.1, 3.2)
	cortina.mesh = qm
	porta_mat = ShaderMaterial.new()
	porta_mat.shader = load("res://shaders/cmb_barreira.gdshader")
	cortina.material_override = porta_mat
	cortina.position = Vector3(0, 1.6, 0.05)
	porta.add_child(cortina)
	porta_luz = OmniLight3D.new()
	porta_luz.position = Vector3(0, 2.0, 0.8)
	porta_luz.light_color = Color("ff4a2a")
	porta_luz.light_energy = 1.4
	porta_luz.omni_range = 5.0
	porta.add_child(porta_luz)
	# abismo: camadas de nevoa e colunas distantes
	for camada in [[-14.0, Color(0.16, 0.13, 0.30, 0.9)], [-8.0, Color(0.30, 0.22, 0.42, 0.55)], [-4.0, Color(0.55, 0.38, 0.45, 0.25)]]:
		var nm := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(160, 160)
		nm.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = camada[1]
		nm.material_override = mat
		nm.position.y = camada[0]
		nm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(nm)
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var r := rng.randf_range(24.0, 34.0)
		var h := rng.randf_range(10.0, 22.0)
		art.box(Vector3(cos(a) * r, -16.0 + h * 0.5, sin(a) * r), Vector3(rng.randf_range(2.0, 4.0), h, rng.randf_range(2.0, 4.0)), "lichen_rock")
	# brasas subindo (ambiente)
	var brasas := CPUParticles3D.new()
	brasas.amount = 60
	brasas.lifetime = 6.0
	brasas.preprocess = 6.0
	brasas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	brasas.emission_box_extents = Vector3(hx, 0.2, hz)
	brasas.direction = Vector3.UP
	brasas.spread = 25
	brasas.gravity = Vector3(0.15, 0.25, 0)
	brasas.initial_velocity_min = 0.2
	brasas.initial_velocity_max = 0.6
	var bq := QuadMesh.new()
	bq.size = Vector2(0.06, 0.06)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bmat.albedo_color = Color(2.6, 1.2, 0.4)
	bq.material = bmat
	brasas.mesh = bq
	add_child(brasas)
	fogo_luzes = kit.luzes_fogo

func _peca(id: String, pos: Vector3, dados := {}, rot := 0) -> Node3D:
	var n: Node3D = kit.make(id, dados)
	n.position = Vector3(roundf(pos.x), pos.y, roundf(pos.z))
	n.rotation.y = rot * PI * 0.5
	add_child(n)
	return n

func _props() -> void:
	var lista := [["caixote", Vector3(-7.5, 0, -2.0)], ["caixote", Vector3(-8.3, 0, -1.1)], ["urna", Vector3(-7.4, 0, -0.6)],
		["caixote", Vector3(7.0, 0, -5.8)], ["urna", Vector3(7.8, 0, -6.4)], ["urna", Vector3(-3.5, 0, 6.6)],
		["caixote", Vector3(-4.4, 0, 7.1)], ["urna", Vector3(8.4, 0, 4.0)], ["rocha", Vector3(4.2, 0, -1.8)], ["rocha", Vector3(-3.4, 0, 2.4)]]
	for item in lista:
		var p = Quebravel.new()
		p.setup(item[0])
		p.position = item[1]
		add_child(p)
		p.quebrou.connect(_prop_quebrou)
		props.append(p)

func _camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAM_TAMANHO
	camera.far = 300.0
	add_child(camera)
	var y := deg_to_rad(YAW)
	var p := deg_to_rad(PITCH)
	cam_tras = Vector3(cos(p) * sin(y), sin(p), cos(p) * cos(y))
	cam_direita = Vector3(cos(y), 0, -sin(y))
	cam_cima = -Vector3(sin(y), 0, cos(y))
	camera.make_current()

func _atualizar_camera(peso: float) -> void:
	var lead: Vector3 = jogador.olhar * 0.8
	var alvo: Vector3 = jogador.global_position + lead
	alvo.x = clampf(alvo.x, -6.5, 6.5)
	alvo.z = clampf(alvo.z, -5.5, 5.5)
	cam_alvo = cam_alvo.lerp(alvo, peso)
	var sacudida := Vector3.ZERO
	if tremor > 0.0:
		var forca := tremor * tremor * 0.45
		sacudida = cam_direita * randf_range(-1, 1) * forca + Vector3.UP * randf_range(-1, 1) * forca
	camera.global_transform = Transform3D(Basis.IDENTITY, cam_alvo + cam_tras * 60.0 + sacudida).looking_at(cam_alvo + sacudida, Vector3.UP)

# ------------------------------------------------------------------ ciclo
func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.001)
	t += real
	if lenta_restante > 0.0:
		lenta_restante -= real
		if lenta_restante <= 0.0:
			escala_tempo = 1.0
			if hitstop_restante <= 0.0:
				Engine.time_scale = 1.0
	if hitstop_restante > 0.0:
		hitstop_restante -= real
		if hitstop_restante <= 0.0:
			Engine.time_scale = escala_tempo
	tremor = maxf(0.0, tremor - real * 2.6)
	if piloto:
		_piloto()
	elif not modo_teste:
		jogador.entrada_mov = Vector2(Input.get_axis("cmb_esquerda", "cmb_direita"), Input.get_axis("cmb_baixo", "cmb_cima"))
		if jogador.estado == "carregando" or jogador.estado == "raio":
			var m := _mira()
			if m.length_squared() > 0.01:
				jogador.raio_mira = m
			if jogador.estado == "carregando" and not (Input.is_action_pressed("cmb_raio") or Input.is_action_pressed("cmb_especial")):
				jogador.soltar_raio()
	# carga: tremor crescente e vibracao do controle
	if jogador.estado == "carregando" and tremor_ativo:
		tremor = maxf(tremor, 0.1 + 0.28 * jogador.carga)
		if Input.get_connected_joypads().size() > 0:
			Input.start_joy_vibration(0, 0.15 + 0.4 * jogador.carga, 0.0, 0.1)
	raio_fx.atualizar(real, comprimento_raio(jogador.raio_origem(), jogador.raio_dir, float(jogador.raio_comprimento)))
	_atualizar_camera(1.0 - exp(-8.0 * real))
	for l in fogo_luzes:
		if is_instance_valid(l):
			var ph := float(l.get_instance_id() % 97)
			l.light_energy = float(l.get_meta("base", 1.5)) * (0.82 + 0.12 * sin(t * 9.0 + ph) + 0.08 * sin(t * 23.0 + ph * 1.7))
	_sala(real)
	_hud_atualizar(real)

func _physics_process(_delta: float) -> void:
	for e in inimigos:
		if is_instance_valid(e):
			e.vizinhos = inimigos

# ------------------------------------------------------------------ golpes
func alvos() -> Array:
	var lista: Array = []
	for e in inimigos:
		if is_instance_valid(e) and e.alvejavel():
			lista.append(e)
	for p in props:
		if is_instance_valid(p) and p.quebravel():
			lista.append(p)
	return lista

func _golpe_jogador(d: Dictionary) -> void:
	var acertos := 0
	var origem: Vector3 = d.origem
	var dir: Vector3 = d.dir
	if d.tipo == "raio":
		_golpe_raio(d)
		return
	if d.tipo == "combo":
		_fx_corte(origem, dir, int(d.indice), bool(d.investida))
	elif d.tipo == "especial":
		_fx_anel(origem, float(d.raio))
	for a in alvos():
		var para: Vector3 = a.global_position - origem
		para.y = 0
		var dist := para.length()
		var dentro := false
		if d.tipo == "combo":
			var raio_alvo := 0.5 if a in inimigos else 0.35
			if dist <= float(d.alcance) + raio_alvo:
				var ang := rad_to_deg(dir.angle_to(para.normalized())) if dist > 0.05 else 0.0
				dentro = ang <= float(d.arco) * 0.5 or dist < 0.8
		else:
			dentro = dist <= float(d.raio) + 0.5
		if not dentro:
			continue
		var emp: Vector3 = (para.normalized() if dist > 0.05 else dir) * float(d.empurrao)
		if a.receber_golpe(int(d.dano), emp, bool(d.pesado)):
			acertos += 1
			if a in inimigos:
				stats.golpes_acertados += 1
				var finalizador: bool = bool(d.pesado) or bool(d.get("investida", false))
				numero_dano(a.global_position + Vector3(0, 2.2, 0), int(d.dano), finalizador)
				_fx_faisca(a.global_position + Vector3(0, 1.0, 0), finalizador)
				if a.hp <= 0:
					stats.inimigos_mortos += 1
				jogador.ganhar_energia(jogador.energia_por_acerto * (2.0 if bool(d.pesado) else 1.0))
	if acertos > 0:
		var pesado: bool = bool(d.pesado)
		hitstop(0.09 if pesado else 0.05)
		sacudir(0.55 if pesado else 0.3)

# ------------------------------------------------------------------ Raio de Adamantium
func comprimento_raio(origem: Vector3, dir: Vector3, maximo: float) -> float:
	# o feixe para nas paredes da arena (caixa LARGURA x FUNDO)
	var lim := maximo
	if absf(dir.x) > 0.001:
		lim = minf(lim, ((LARGURA * 0.5 if dir.x > 0 else -LARGURA * 0.5) - origem.x) / dir.x)
	if absf(dir.z) > 0.001:
		lim = minf(lim, ((FUNDO * 0.5 if dir.z > 0 else -FUNDO * 0.5) - origem.z) / dir.z)
	return clampf(lim, 1.0, maximo)

func _golpe_raio(d: Dictionary) -> void:
	var origem: Vector3 = d.origem
	var dir: Vector3 = d.dir
	var comp := comprimento_raio(origem, dir, float(d.comprimento))
	var meia := float(d.largura) * 0.5
	var acertos := 0
	for a in alvos():
		var para: Vector3 = a.global_position - origem
		para.y = 0
		var s := para.dot(dir)
		var raio_alvo := 0.5 if a in inimigos else 0.4
		if s < -raio_alvo or s > comp + raio_alvo:
			continue
		var lateral: Vector3 = para - dir * s
		if lateral.length() > meia + raio_alvo:
			continue
		var emp: Vector3 = dir * float(d.empurrao) + (lateral.normalized() * 1.2 if lateral.length() > 0.05 else Vector3.ZERO)
		if a.receber_golpe(int(d.dano), emp, bool(d.pesado)):
			acertos += 1
			if a in inimigos:
				stats.raio_acertos += 1
				stats.raio_alvos[a.get_instance_id()] = true
				stats.golpes_acertados += 1
				numero_dano(a.global_position + Vector3(0, 2.2, 0), int(d.dano), bool(d.pesado), Color(0.6, 0.95, 1.0))
				_explosao(a.global_position + Vector3(0, 1.0, 0), 8, Color(1.5, 2.6, 3.0), Color(0.2, 0.5, 1.0, 0.0), 4.0, 0.25)
				if a.hp <= 0:
					stats.inimigos_mortos += 1
	_explosao(origem + dir * comp, 6, Color(1.5, 2.6, 3.0), Color(0.2, 0.5, 1.0, 0.0), 5.0, 0.3)
	if int(d.tick) == 0 and acertos > 0:
		hitstop(0.05)
	sacudir(0.42 if bool(d.pesado) else 0.34)
	if Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(0, 0.5, 0.9, 0.12)

func _raio_disparou() -> void:
	clarao.color = Color(0.7, 0.95, 1.0, 0.35)
	sacudir(0.8)
	_explosao(jogador.raio_origem(), 30, Color(2.0, 3.0, 3.2), Color(0.2, 0.5, 1.0, 0.0), 7.0, 0.35)
	mostrar_banner("RAIO DE ADAMANTIUM!", 1.0)

func camera_lenta(escala: float, segundos: float) -> void:
	stats.lentas += 1
	if not lenta_ativa:
		return
	escala_tempo = escala
	lenta_restante = segundos
	if hitstop_restante <= 0.0:
		Engine.time_scale = escala

func _transformacao_fx() -> void:
	camera_lenta(0.3, 0.45)
	clarao.color = Color(0.85, 0.97, 1.0, 0.6)
	sacudir(0.7)
	mostrar_banner("FORMA ADAMANTIUM!", 1.6)
	var o: Vector3 = jogador.global_position
	_explosao(o + Vector3(0, 0.9, 0), 70, Color(2.2, 3.0, 3.2), Color(0.25, 0.55, 1.0, 0.0), 9.0, 0.7)
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	m.mesh = q
	m.rotation.x = -PI / 2
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/aura_ring.gdshader")
	mat.set_shader_parameter("tint", Vector3(1.6, 2.6, 3.0))
	m.material_override = mat
	m.position = o + Vector3(0, 0.08, 0)
	add_child(m)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 8.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): mat.set_shader_parameter("tint", Vector3(1.6, 2.6, 3.0) * v), 1.0, 0.0, 0.55)
	tw.chain().tween_callback(m.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color("8fe8ff")
	luz.light_energy = 8.0
	luz.omni_range = 8.0
	luz.position = o + Vector3(0, 1.4, 0)
	add_child(luz)
	var tl := luz.create_tween()
	tl.tween_property(luz, "light_energy", 0.0, 0.6)
	tl.tween_callback(luz.queue_free)
	# onda de choque: empurra quem estiver perto (sem anel de fogo)
	_golpe_jogador({"tipo": "forma", "origem": o, "dir": jogador.olhar, "raio": 2.8, "dano": 8, "empurrao": 10.0, "pesado": true})

func _transformou(ativo: bool) -> void:
	if not ativo:
		mostrar_banner("FORMA NORMAL", 1.0)
		_explosao(jogador.global_position + Vector3(0, 0.9, 0), 24, Color(1.2, 1.8, 2.2), Color(0.3, 0.4, 0.6, 0.0), 4.0, 0.5)

func _inimigo_ataca(e, centro: Vector3, raio: float, dano: int) -> void:
	sacudir(0.25)
	_fx_poeira(centro)
	var para: Vector3 = jogador.global_position - centro
	para.y = 0
	if para.length() <= raio + 0.35:
		if jogador.receber_dano(dano, e.global_position):
			numero_dano(jogador.global_position + Vector3(0, 2.0, 0), dano, false, Color(1.0, 0.35, 0.3))

func _jogador_ferido(_dano: int) -> void:
	hitstop(0.07)
	sacudir(0.6)
	vinheta.color.a = 0.32

func _jogador_morreu() -> void:
	_mudar_sala("derrota")

func hitstop(segundos: float) -> void:
	if not hitstop_ativo:
		return
	stats.hitstops += 1
	Engine.time_scale = 0.05
	hitstop_restante = maxf(hitstop_restante, segundos)

func sacudir(forca: float) -> void:
	if not tremor_ativo:
		return
	stats.tremores += 1
	tremor = clampf(maxf(tremor, forca), 0.0, 1.0)

func numero_dano(pos: Vector3, valor: int, grande: bool, cor := Color(1, 1, 1)) -> void:
	stats.numeros += 1
	var l := Label3D.new()
	l.text = str(valor)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 44 if grande else 32
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.03, 0.05)
	l.modulate = Color(1.0, 0.62, 0.2) if grande and cor == Color(1, 1, 1) else cor
	l.render_priority = 10
	l.position = pos + cam_direita * randf_range(-0.3, 0.3)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 1.0, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

# ------------------------------------------------------------------ efeitos visuais
func _fx_corte(origem: Vector3, dir: Vector3, indice: int, investida: bool) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var w: float = [2.6, 2.7, 3.4][indice] * (1.15 if investida else 1.0)
	pm.size = Vector2(w, w * 81.0 / 128.0)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_texture = corte_tex
	mat.albedo_color = [Color(1.6, 1.35, 1.1), Color(1.6, 1.35, 1.1), Color(2.4, 1.1, 0.5)][indice]
	if investida:
		mat.albedo_color = Color(1.2, 1.6, 2.4)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z := dir.cross(Vector3.UP).normalized()
	if indice == 1:
		z = -z
	m.transform = Transform3D(Basis(dir, Vector3.UP, z), origem + dir * (w * 0.32) + Vector3(0, 0.75, 0))
	add_child(m)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1.15, 1, 1.15), 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.16).set_delay(0.04)
	tw.chain().tween_callback(m.queue_free)

func _fx_anel(origem: Vector3, raio: float) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * raio * 2.3
	m.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cmb_anel.gdshader")
	m.material_override = mat
	m.position = origem + Vector3(0, 0.1, 0)
	add_child(m)
	var luz := OmniLight3D.new()
	luz.light_color = Color("ff8a3a")
	luz.light_energy = 4.0
	luz.omni_range = raio * 2.2
	luz.position = origem + Vector3(0, 1.2, 0)
	add_child(luz)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float): mat.set_shader_parameter("t", v), 0.0, 1.0, 0.45)
	tw.tween_property(luz, "light_energy", 0.0, 0.45)
	tw.chain().tween_callback(func(): m.queue_free(); luz.queue_free())
	_explosao(origem + Vector3(0, 0.6, 0), 40, Color(3.0, 1.4, 0.4), Color(1.0, 0.3, 0.05), raio * 2.2, 0.6)
	sacudir(0.7)

func _fx_faisca(pos: Vector3, grande: bool) -> void:
	_explosao(pos, 18 if grande else 10, Color(3.0, 2.6, 2.0), Color(1.2, 0.5, 0.1), 5.0 if grande else 3.5, 0.3)

func _fx_poeira(pos: Vector3) -> void:
	_explosao(pos + Vector3(0, 0.15, 0), 16, Color(0.75, 0.62, 0.5), Color(0.45, 0.38, 0.33, 0.0), 2.4, 0.5)

func _dash_fx() -> void:
	# rastro de imagens fantasma
	for i in 4:
		var tm := get_tree().create_timer(0.035 * i, true, false, false)
		tm.timeout.connect(_fantasma)
	_fx_poeira(jogador.global_position)

func _fantasma() -> void:
	var s: AnimatedSprite3D = jogador.sprite
	var g := Sprite3D.new()
	g.texture = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	g.pixel_size = s.pixel_size
	g.offset = s.offset
	g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	g.shaded = false
	g.transparent = true
	g.modulate = Color(0.55, 0.85, 1.6, 0.55)
	g.position = jogador.global_position
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)

func _explosao(pos: Vector3, n: int, c0: Color, c1: Color, vel: float, vida: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = vida
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	p.color_ramp = g
	p.position = pos
	add_child(p)
	p.emitting = true
	var tm := get_tree().create_timer(vida + 0.3, true, false, true)
	tm.timeout.connect(p.queue_free)

func _prop_quebrou(p) -> void:
	stats.props_quebrados += 1
	var cor := Color(0.75, 0.5, 0.28) if p.tipo == "caixote" else Color(0.85, 0.42, 0.25)
	_explosao(p.global_position + Vector3(0, 0.5, 0), 14, cor, cor.darkened(0.5), 3.0, 0.6)
	if p.tipo == "urna":
		_orbe_cura(p.global_position)

func _orbe_cura(pos: Vector3) -> void:
	var o := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	o.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 2.4, 1.2)
	o.material_override = mat
	o.position = pos + Vector3(0, 0.5, 0)
	o.set_meta("cura", 10)
	o.add_to_group("cmb_cura")
	add_child(o)

# ------------------------------------------------------------------ inimigos e sala
func gerar_inimigo(pos: Vector3, bruto := false):
	var e = Orc.new()
	e.bruto = bruto
	if bruto:
		e.escala = 1.25
		e.hp_max = 110
		e.hp = 110
		e.dano = 20
		e.velocidade = 2.5
		e.preparo = 0.95
		e.postura_max = 40.0
	e.name = "Orc%d" % inimigos.size()
	e.position = pos
	e.alvo = jogador
	e.cam_direita = cam_direita
	add_child(e)
	e.ataque.connect(_inimigo_ataca)
	e.morto.connect(_inimigo_removido)
	inimigos.append(e)
	_explosao(pos + Vector3(0, 0.3, 0), 24, Color(0.9, 0.3, 1.6), Color(0.2, 0.05, 0.3, 0.0), 3.0, 0.7)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(70 if not bruto else 96, 8)
	barra.max_value = e.hp_max
	barra.value = e.hp
	barra.add_theme_stylebox_override("background", _caixa(Color(0.08, 0.05, 0.07, 0.85)))
	barra.add_theme_stylebox_override("fill", _caixa(Color("d8452f") if not bruto else Color("e07a1f")))
	hud.add_child(barra)
	barras_inimigos[e] = barra
	return e

func _inimigo_removido(e) -> void:
	inimigos.erase(e)
	if barras_inimigos.has(e):
		barras_inimigos[e].queue_free()
		barras_inimigos.erase(e)

func gerar_onda(i: int) -> void:
	var pontos := [Vector3(-6, 0, -4), Vector3(6, 0, -4), Vector3(-6, 0, 4), Vector3(6, 0, 3), Vector3(0, 0, -6), Vector3(-1, 0, 6)]
	var n := 2 + i + (sala - 1)
	for k in mini(n, pontos.size()):
		gerar_inimigo(pontos[(k + i * 2) % pontos.size()], i == 1 and k == 0)

func _mudar_sala(novo: String) -> void:
	estado_sala = novo
	t_sala = 0.0
	match novo:
		"inicio":
			mostrar_banner("SALA %d — ARENA DAS CINZAS" % sala, 1.6)
		"limpa":
			stats.salas_limpas += 1
			mostrar_banner("SALA LIMPA!", 2.0)
			if hitstop_ativo:
				Engine.time_scale = 0.3
				hitstop_restante = 0.5
		"recompensa":
			_criar_recompensa()
		"porta":
			porta_mat.set_shader_parameter("aberto", 1.0)
			porta_luz.light_color = Color("ffd27a")
			porta_luz.light_energy = 2.5
			for c in porta.get_children():
				if c is MeshInstance3D and c.material_override == porta_mat:
					c.visible = false
			mostrar_banner("A PORTA SE ABRIU", 1.6)
		"derrota":
			mostrar_banner("VALE CAIU — R para tentar de novo", 99.0)

func _sala(real: float) -> void:
	t_sala += real
	match estado_sala:
		"inicio":
			if not modo_teste and t_sala >= 1.4:
				onda = 0
				gerar_onda(0)
				_mudar_sala("combate")
		"combate":
			if inimigos.is_empty():
				if onda + 1 < ondas_total:
					_mudar_sala("intervalo")
				else:
					_mudar_sala("limpa")
		"intervalo":
			if t_sala >= 1.2:
				onda += 1
				mostrar_banner("ONDA %d/%d" % [onda + 1, ondas_total], 1.0)
				gerar_onda(onda)
				_mudar_sala("combate")
		"limpa":
			if t_sala >= 1.0:
				_mudar_sala("recompensa")
		"recompensa":
			if recompensa:
				recompensa.position.y = 1.0 + 0.15 * sin(t * 3.0)
				recompensa.rotation.y += real * 1.5
				if jogador.global_position.distance_to(Vector3(recompensa.position.x, 0, recompensa.position.z)) < 1.3:
					pegar_recompensa()
		"porta":
			var dp: Vector3 = porta.global_position + Vector3(0, 0, 1.2)
			if jogador.global_position.distance_to(dp) < 1.4:
				sala += 1
				mostrar_banner("PROXIMA SALA (placeholder) — SALA %d" % sala, 1.6)
				reiniciar_sala(false)
	# orbes de cura
	for o in get_tree().get_nodes_in_group("cmb_cura"):
		o.position.y = 0.5 + 0.1 * sin(t * 4.0)
		if jogador.global_position.distance_to(Vector3(o.position.x, 0, o.position.z)) < 0.9:
			jogador.curar(int(o.get_meta("cura")))
			stats.curas += 1
			numero_dano(jogador.global_position + Vector3(0, 2.0, 0), int(o.get_meta("cura")), false, Color(0.5, 1.0, 0.6))
			o.queue_free()

func _criar_recompensa() -> void:
	recompensa = Node3D.new()
	recompensa.name = "Recompensa"
	recompensa.position = Vector3(0, 1.0, 0)
	add_child(recompensa)
	var o := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.38
	sm.height = 0.76
	o.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(2.6, 1.8, 0.6)
	o.material_override = mat
	recompensa.add_child(o)
	var l := OmniLight3D.new()
	l.light_color = Color("ffcf6a")
	l.light_energy = 2.5
	l.omni_range = 6.0
	recompensa.add_child(l)
	var rotulo := Label3D.new()
	rotulo.text = "BENÇÃO DAS CINZAS"
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.no_depth_test = true
	rotulo.fixed_size = true
	rotulo.pixel_size = 0.0009
	rotulo.font_size = 26
	rotulo.outline_size = 8
	rotulo.position = Vector3(0, 0.9, 0)
	recompensa.add_child(rotulo)
	_explosao(recompensa.position, 30, Color(3.0, 2.2, 0.8), Color(1.0, 0.6, 0.1, 0.0), 3.0, 0.8)

func pegar_recompensa() -> void:
	if recompensa == null:
		return
	bencaos += 1
	jogador.multiplicador_dano = 1.0 + 0.2 * bencaos
	_explosao(recompensa.global_position, 40, Color(3.0, 2.2, 0.8), Color(1.0, 0.6, 0.1, 0.0), 4.0, 0.8)
	recompensa.queue_free()
	recompensa = null
	mostrar_banner("BENÇÃO: +20%% DE DANO (total +%d%%)" % (20 * bencaos), 1.6)
	_mudar_sala("porta")

func reiniciar_sala(do_zero := true) -> void:
	for e in inimigos:
		if is_instance_valid(e):
			e.queue_free()
	for b in barras_inimigos.values():
		b.queue_free()
	barras_inimigos.clear()
	inimigos.clear()
	for p in props:
		p.queue_free()
	props.clear()
	for o in get_tree().get_nodes_in_group("cmb_cura"):
		o.queue_free()
	if recompensa:
		recompensa.queue_free()
		recompensa = null
	if do_zero:
		sala = 1
		bencaos = 0
		jogador.multiplicador_dano = 1.0
	_props()
	porta_mat.set_shader_parameter("aberto", 0.0)
	for c in porta.get_children():
		if c is MeshInstance3D and c.material_override == porta_mat:
			c.visible = true
	porta_luz.light_color = Color("ff4a2a")
	porta_luz.light_energy = 1.4
	jogador.reiniciar(Vector3(3.5, 0, 3.5))
	Engine.time_scale = 1.0
	hitstop_restante = 0.0
	onda = 0
	_mudar_sala("inicio")

# ------------------------------------------------------------------ piloto automatico (demo/filme/perf)
var piloto_t := 0.0
func _piloto() -> void:
	piloto_t += get_process_delta_time()
	var eu: Vector3 = jogador.global_position
	var alvo_n = null
	var melhor := 999.0
	for e in inimigos:
		if is_instance_valid(e) and e.alvejavel():
			var d: float = eu.distance_to(e.global_position)
			if d < melhor:
				melhor = d
				alvo_n = e
	var destino := Vector3.ZERO
	if alvo_n == null:
		if estado_sala == "recompensa" and recompensa:
			destino = recompensa.position
		elif estado_sala == "porta":
			destino = porta.global_position + Vector3(0, 0, 1.2)
		else:
			for p in props:
				if is_instance_valid(p) and p.quebravel():
					destino = p.global_position
					if eu.distance_to(destino) < 1.6:
						jogador.pedir_ataque((destino - eu).normalized())
					break
	else:
		destino = alvo_n.global_position
		var para_alvo: Vector3 = (destino - eu).normalized()
		if jogador.pode_transformar():
			jogador.pedir_transformar()
			return
		if jogador.estado == "carregando":
			jogador.raio_mira = para_alvo
			jogador.entrada_mov = Vector2.ZERO
			if jogador.t_estado > 0.75:
				jogador.soltar_raio()
			return
		if jogador.estado == "raio":
			jogador.raio_mira = para_alvo
			jogador.entrada_mov = Vector2.ZERO
			return
		if jogador.pode_raio() and melhor > 2.2 and melhor < 11.0:
			jogador.pedir_raio(para_alvo)
			return
		# esquiva o golpe telegrafado com dash lateral
		if alvo_n.estado == "preparo" and alvo_n.t > alvo_n.preparo * 0.55 and melhor < 2.8 and jogador.dash_pronto():
			var fora: Vector3 = (eu - alvo_n.global_position).normalized().cross(Vector3.UP)
			jogador.entrada_mov = Vector2(fora.dot(cam_direita), fora.dot(cam_cima))
			jogador.pedir_dash()
			return
		var perto := 0
		for e in inimigos:
			if is_instance_valid(e) and e.alvejavel() and eu.distance_to(e.global_position) < 3.2:
				perto += 1
		if perto >= 2 and jogador.especial_pronto():
			jogador.pedir_especial((destino - eu).normalized())
		elif melhor < 2.0:
			if fmod(piloto_t, 0.12) < 0.05:
				jogador.pedir_ataque((destino - eu).normalized())
			jogador.entrada_mov = Vector2.ZERO
			return
	var v := destino - eu
	v.y = 0
	if v.length() < 0.6:
		jogador.entrada_mov = Vector2.ZERO
	else:
		v = v.normalized()
		jogador.entrada_mov = Vector2(v.dot(cam_direita), v.dot(cam_cima))

# ------------------------------------------------------------------ HUD
func _caixa(cor: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(2)
	return s

func _rotulo(pos: Vector2, tamanho: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(l)
	return l

func _hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	vinheta = ColorRect.new()
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vinheta.color = Color(0.7, 0.05, 0.05, 0.0)
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vinheta)
	var nome := _rotulo(Vector2(28, 20), 18)
	nome.text = "VALE"
	barra_hp = ProgressBar.new()
	barra_hp.position = Vector2(28, 48)
	barra_hp.custom_minimum_size = Vector2(320, 20)
	barra_hp.size = Vector2(320, 20)
	barra_hp.show_percentage = false
	barra_hp.max_value = jogador.hp_max
	barra_hp.add_theme_stylebox_override("background", _caixa(Color(0.1, 0.06, 0.08, 0.85)))
	barra_hp.add_theme_stylebox_override("fill", _caixa(Color("c8322a")))
	hud.add_child(barra_hp)
	texto_hp = _rotulo(Vector2(358, 45), 16)
	for par in [["DASH", 80.0], ["ESPECIAL", 106.0]]:
		var r := _rotulo(Vector2(28, par[1] - 4), 14)
		r.text = par[0]
		var b := ProgressBar.new()
		b.position = Vector2(118, par[1])
		b.size = Vector2(140, 10)
		b.custom_minimum_size = Vector2(140, 10)
		b.show_percentage = false
		b.max_value = 1.0
		b.add_theme_stylebox_override("background", _caixa(Color(0.1, 0.06, 0.08, 0.85)))
		b.add_theme_stylebox_override("fill", _caixa(Color("6fc3e8") if par[0] == "DASH" else Color("f08a2c")))
		hud.add_child(b)
		if par[0] == "DASH":
			barra_dash = b
		else:
			barra_especial = b
	var rf := _rotulo(Vector2(28, 128), 14)
	rf.text = "FORMA"
	rotulo_forma = _rotulo(Vector2(266, 128), 14)
	rotulo_forma.text = "ADAMANTIUM"
	barra_forma = ProgressBar.new()
	barra_forma.position = Vector2(118, 132)
	barra_forma.size = Vector2(140, 10)
	barra_forma.custom_minimum_size = Vector2(140, 10)
	barra_forma.show_percentage = false
	barra_forma.max_value = 100.0
	barra_forma.add_theme_stylebox_override("background", _caixa(Color(0.1, 0.06, 0.08, 0.85)))
	barra_forma.add_theme_stylebox_override("fill", _caixa(Color("bfe9ff")))
	hud.add_child(barra_forma)
	rotulo_raio = _rotulo(Vector2(266, 154), 14)
	rotulo_raio.text = "RAIO"
	var rr := _rotulo(Vector2(28, 154), 14)
	rr.text = "RAIO"
	rr.set_meta("so_forma", true)
	rotulo_raio.set_meta("par", rr)
	barra_raio = ProgressBar.new()
	barra_raio.position = Vector2(118, 158)
	barra_raio.size = Vector2(140, 10)
	barra_raio.custom_minimum_size = Vector2(140, 10)
	barra_raio.show_percentage = false
	barra_raio.max_value = 1.0
	barra_raio.add_theme_stylebox_override("background", _caixa(Color(0.1, 0.06, 0.08, 0.85)))
	barra_raio.add_theme_stylebox_override("fill", _caixa(Color("5fd4ff")))
	hud.add_child(barra_raio)
	clarao = ColorRect.new()
	clarao.set_anchors_preset(Control.PRESET_FULL_RECT)
	clarao.color = Color(1, 1, 1, 0)
	clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(clarao)
	banner = _rotulo(Vector2(0, 150), 34)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(1600, 50)
	banner.add_theme_color_override("font_color", Color("ffd27a"))
	info = _rotulo(Vector2(1200, 20), 16)
	info.size = Vector2(372, 30)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dicas = _rotulo(Vector2(28, 862), 13)
	dicas.text = "WASD mover | LMB/J atacar (combo 3) | Espaco/Shift dash | RMB/K especial | G/LB forma Adamantium | transformado: segure Q/RMB/RT = Raio de Adamantium | R reiniciar | F2 piloto | F3 desempenho | F4 caixas"
	perf = _rotulo(Vector2(1300, 840), 13)
	perf.visible = false

func mostrar_banner(texto: String, duracao: float) -> void:
	banner.text = texto
	banner_t = duracao
	banner.modulate.a = 1.0

func _hud_atualizar(real: float) -> void:
	barra_hp.value = jogador.hp
	texto_hp.text = "%d / %d" % [jogador.hp, jogador.hp_max]
	barra_dash.value = 1.0 - clampf((jogador.dash_cd_ate - jogador.relogio) / jogador.dash_recarga, 0, 1)
	barra_especial.value = 1.0 - clampf((jogador.especial_cd_ate - jogador.relogio) / jogador.especial_recarga, 0, 1)
	barra_forma.value = jogador.energia
	if jogador.transformado:
		rotulo_forma.text = "ADAMANTIUM %ds" % ceili(maxf(0.0, jogador.forma_ate - jogador.relogio))
	elif jogador.pode_transformar() or jogador.energia >= jogador.energia_max:
		rotulo_forma.text = "G: TRANSFORMAR"
	else:
		rotulo_forma.text = "ADAMANTIUM"
	barra_raio.visible = jogador.transformado
	rotulo_raio.visible = jogador.transformado
	(rotulo_raio.get_meta("par") as Label).visible = jogador.transformado
	barra_raio.value = 1.0 - clampf(jogador.raio_recarga_restante() / jogador.raio_recarga, 0, 1)
	match jogador.estado:
		"carregando":
			rotulo_raio.text = "RAIO DE ADAMANTIUM %d%%" % roundi(jogador.carga * 100.0)
		"raio":
			rotulo_raio.text = "RAIO DE ADAMANTIUM!"
		_:
			rotulo_raio.text = "RAIO DE ADAMANTIUM (segure Q/RMB)" if jogador.pode_raio() or jogador.raio_recarga_restante() <= 0.0 else "RAIO %.1fs" % jogador.raio_recarga_restante()
	clarao.color.a = maxf(0.0, clarao.color.a - real * 2.2)
	info.text = "SALA %d  |  ONDA %d/%d  |  INIMIGOS %d%s" % [sala, mini(onda + 1, ondas_total), ondas_total, inimigos.size(), ("  |  BENÇÃOS %d" % bencaos) if bencaos > 0 else ""]
	banner_t -= real
	banner.modulate.a = clampf(banner_t / 0.4, 0, 1)
	vinheta.color.a = maxf(0.0, vinheta.color.a - real * 0.9)
	for e in barras_inimigos:
		var b: ProgressBar = barras_inimigos[e]
		if is_instance_valid(e):
			var top: Vector3 = e.global_position + Vector3(0, 2.3 * e.escala, 0)
			b.visible = e.vivo and not camera.is_position_behind(top)
			b.value = e.hp
			b.position = camera.unproject_position(top) - b.size * 0.5
	if perf.visible:
		perf.text = "FPS %d | %.1f ms | draw %d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	_caixas_debug()

func _caixas_debug() -> void:
	for c in caixas:
		c.queue_free()
	caixas.clear()
	if not mostrar_caixas:
		return
	for e in inimigos:
		if is_instance_valid(e):
			caixas.append(_disco(e.global_position, 0.5, Color(1, 0.3, 0.3, 0.35)))
	caixas.append(_disco(jogador.global_position, 0.36, Color(0.3, 0.8, 1.0, 0.35 if not jogador.invulneravel() else 0.9)))
	if jogador.estado == "ataque":
		caixas.append(_disco(jogador.global_position + jogador.olhar * 1.1, float(jogador.combo_alcance[jogador.combo_i]) * 0.5, Color(1, 1, 0.3, 0.3)))

func _disco(pos: Vector3, r: float, cor: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.04
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = cor
	mat.no_depth_test = true
	m.material_override = mat
	m.position = pos + Vector3(0, 0.06, 0)
	add_child(m)
	return m
