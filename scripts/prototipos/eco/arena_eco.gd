extends Node3D
## Protótipo jogável do ECO TEMPORAL (PROPOSTA). Cena: res://scenes/prototipos/eco/arena_eco.tscn
## Vale (jogador_combate.gd, sprites vale_combate_gamelab), poste de treino, bonecos, Escudeiro de Palha
## e um Bate-Estaca com 3 travas que só abrem com o eco.
##
## O 3º golpe do combo (pesado) — ou H / LB para um golpe pesado direto — deixa um fantasma da Vale e
## um relógio no chão. Quando o relógio fecha, o tempo repete o golpe ali.
## 1 / 2 / 3 (ou direcional ← ↑ →) trocam Eco / Eco rápido / Eco pesado. R reinicia. Esc sai.
##
## Ganchos: var gerenciador (gerenciador_missoes.gd, opcional) recebe notificar("eco_acertou", alvo),
## notificar("trava_acertada_eco", "bate_estaca") e coletar_item("catraca_mestra").
## Sinais: eco_marcado, eco_disparou, eco_acertou, trava_aberta, bate_estaca_aberto, variacao_mudou.
signal eco_marcado(eco: Dictionary)
signal eco_disparou(eco: Dictionary, acertos: int)
signal eco_acertou(alvo_id: String, dano: int, variacao: String)
signal trava_aberta(indice: int, abertas: int)
signal bate_estaca_aberto
signal variacao_mudou(variacao_id: String)
signal demo_terminou

const Jogador = preload("res://scripts/combate/jogador_combate.gd")
const Folhas = preload("res://scripts/combate/folhas.gd")
const Eco = preload("res://scripts/prototipos/eco/eco_temporal.gd")
const Alvo = preload("res://scripts/prototipos/eco/alvo_treino.gd")
const BateEstaca = preload("res://scripts/prototipos/eco/bate_estaca.gd")
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"
const YAW := 45.0
const PITCH := 40.0
const CAM_TAMANHO := 10.0
const LARGURA := 26.0
const FUNDO := 20.0
const COR_ECO := Color(0.45, 0.9, 1.0)
const TECLAS_VAR := {KEY_1: "eco_base", KEY_2: "eco_rapido", KEY_3: "eco_pesado", KEY_KP_1: "eco_base", KEY_KP_2: "eco_rapido", KEY_KP_3: "eco_pesado"}

var gerenciador = null
var modo_teste := false
var demo := false
var demo_fim := false
var eco
var jogador
var camera: Camera3D
var cam_direita := Vector3.RIGHT
var cam_cima := Vector3.FORWARD
var cam_tras := Vector3.BACK
var cam_alvo := Vector3.ZERO
var alvos: Array = []
var bate
var tempo := 0.0
var t_real := 0.0
var hitstop_restante := 0.0
var tremor := 0.0
var _escala_quadro := 1.0
var corte_tex: Texture2D
var anel_tex: Texture2D
var _shader_relogio: Shader
var _visuais: Dictionary = {}
var _fonte: Font
var stats := {"ecos_marcados": 0, "ecos_disparados": 0, "acertos_eco": 0, "acertos_normais": 0, "bloqueios": 0,
	"guardas_quebradas": 0, "travas_abertas": 0, "clangs": 0, "hitstops": 0, "numeros": 0, "dash_bonus": 0, "pancadas": 0}
var log_ecos: Array = []
var mira_mouse := false
# HUD
var hud: CanvasLayer
var chips: Dictionary = {}
var lbl_var: Label
var lbl_cont: Label
var lbl_banner: Label
var _banner_ate := 0.0
# piloto automático (demo / vídeo)
var roteiro: Array = []
var passo_i := 0
var passo_t := 0.0
var _passo_dados: Dictionary = {}

func _ready() -> void:
	if OS.get_environment("ECO_TESTE") == "1":
		modo_teste = true
	if OS.get_environment("ECO_DEMO") == "1":
		demo = true
	_fonte = load(FONTE) if ResourceLoader.exists(FONTE) else ThemeDB.fallback_font
	_acoes()
	eco = Eco.new()
	eco.eco_marcado.connect(_ao_marcar)
	corte_tex = Folhas.textura("res://art/combate/vfx/fx_corte_crescente.png")
	anel_tex = BateEstaca._textura_anel()
	_shader_relogio = _criar_shader_relogio()
	_ambiente()
	_chao()
	_camera()
	jogador = Jogador.new()
	jogador.name = "Vale"
	add_child(jogador)
	jogador.position = Vector3(0, 0, 4.5)
	jogador.cam_direita = cam_direita
	jogador.cam_cima = cam_cima
	jogador._virar(cam_cima)
	jogador.golpe.connect(_golpe_jogador)
	_montar_alvos()
	_montar_bate_estaca()
	_hud()
	var v0 := "eco_base"
	if gerenciador != null and String(gerenciador.variacao_eco) != "":
		v0 = String(gerenciador.variacao_eco)
	if OS.get_environment("ECO_VARIACAO") != "":
		v0 = OS.get_environment("ECO_VARIACAO")
	definir_variacao(v0)
	cam_alvo = jogador.position
	_atualizar_camera(1.0)
	DisplayServer.window_set_title("Ilha das Cinzas | Protótipo do Eco temporal")
	if demo:
		roteiro = _roteiro_demo()
		mostrar_banner("ECO TEMPORAL · o golpe pesado se repete no mesmo lugar", 2.4)
	else:
		mostrar_banner("3º golpe do combo (J/clique) deixa um ECO · 1 / 2 / 3 trocam a variação", 3.0)

# ------------------------------------------------------------------ entrada
func _acoes() -> void:
	var teclas := {
		"cmb_esquerda": [KEY_A, KEY_LEFT], "cmb_direita": [KEY_D, KEY_RIGHT],
		"cmb_cima": [KEY_W, KEY_UP], "cmb_baixo": [KEY_S, KEY_DOWN],
		"cmb_ataque": [KEY_J], "cmb_dash": [KEY_SPACE, KEY_SHIFT], "eco_pesado_direto": [KEY_H]}
	for a: String in teclas:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
			for k: int in teclas[a]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(a, ev)
	var botoes := {"cmb_ataque": JOY_BUTTON_X, "cmb_dash": JOY_BUTTON_A, "eco_pesado_direto": JOY_BUTTON_LEFT_SHOULDER}
	for a: String in botoes:
		var jb := InputEventJoypadButton.new()
		jb.button_index = botoes[a]
		InputMap.action_add_event(a, jb)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("cmb_ataque", mb)
	for par in [["cmb_esquerda", JOY_AXIS_LEFT_X, -1.0], ["cmb_direita", JOY_AXIS_LEFT_X, 1.0], ["cmb_cima", JOY_AXIS_LEFT_Y, -1.0], ["cmb_baixo", JOY_AXIS_LEFT_Y, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = par[1]
		jm.axis_value = par[2]
		InputMap.action_add_event(par[0], jm)

func _unhandled_input(event: InputEvent) -> void:
	processar_entrada(event)

## Separado para os testes poderem mandar eventos sem janela.
func processar_entrada(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		mira_mouse = true
	if event is InputEventKey and event.pressed and not event.echo:
		if TECLAS_VAR.has(event.physical_keycode):
			definir_variacao(TECLAS_VAR[event.physical_keycode])
			return
		match event.physical_keycode:
			KEY_R:
				reiniciar()
				return
			KEY_ESCAPE:
				if not modo_teste:
					get_tree().quit()
				return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: definir_variacao("eco_base"); return
			JOY_BUTTON_DPAD_UP: definir_variacao("eco_rapido"); return
			JOY_BUTTON_DPAD_RIGHT: definir_variacao("eco_pesado"); return
			JOY_BUTTON_BACK: reiniciar(); return
	if demo:
		return
	if event.is_action_pressed("eco_pesado_direto"):
		golpe_pesado_direto(_mira())
	elif event.is_action_pressed("cmb_ataque"):
		jogador.pedir_ataque(_mira())
	elif event.is_action_pressed("cmb_dash"):
		jogador.pedir_dash()

func _mira() -> Vector3:
	var jx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if Vector2(jx, jy).length() > 0.4:
		return cam_direita * jx - cam_cima * jy
	if mira_mouse and not modo_teste and camera != null:
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

## Golpe pesado sem precisar dos dois primeiros (H / LB): pula direto para o 3º golpe do combo.
func golpe_pesado_direto(dir := Vector3.ZERO) -> bool:
	if jogador.estado != "livre":
		return false
	jogador.combo_i = 1
	jogador.combo_fim_t = jogador.relogio
	jogador.pedir_ataque(dir)
	return jogador.estado == "ataque" and jogador.combo_i == 2

func definir_variacao(vid: String) -> bool:
	if not eco.definir(vid):
		return false
	if gerenciador != null:
		gerenciador.variacao_eco = vid
	_atualizar_hud_variacao()
	variacao_mudou.emit(vid)
	var d: Dictionary = eco.dados()
	mostrar_banner("%s · %s s · %d%% · raio %s m" % [String(d.get("nome", vid)).to_upper(), _num(eco.atraso()), roundi(eco.dano_relativo() * 100), _num(eco.raio())], 1.4)
	return true

static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".").replace(".", ",")

# ------------------------------------------------------------------ cenário
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("120c12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b39a8a")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color("3a2630")
	env.fog_density = 0.004
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color("ffc79a")
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	sol.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sol)
	for p in [Vector3(-11, 0, -8), Vector3(11, 0, -8), Vector3(-11, 0, 8), Vector3(11, 0, 8), Vector3(0, 0, -9.3)]:
		_braseiro(p)

func _braseiro(p: Vector3) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new(); c.top_radius = 0.45; c.bottom_radius = 0.3; c.height = 0.9
	m.mesh = c
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("3a3030")
	m.material_override = mat
	m.position = p + Vector3(0, 0.45, 0)
	add_child(m)
	var fogo := MeshInstance3D.new()
	var s := SphereMesh.new(); s.radius = 0.35; s.height = 0.5
	fogo.mesh = s
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color(2.6, 1.2, 0.35)
	fogo.material_override = fm
	fogo.position = p + Vector3(0, 1.0, 0)
	add_child(fogo)
	var l := OmniLight3D.new(); l.light_color = Color("ff9f4a"); l.light_energy = 2.2; l.omni_range = 7.0
	l.position = p + Vector3(0, 1.6, 0)
	add_child(l)

func _chao() -> void:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var ladrilho := ((x / 8) + (y / 8)) % 2
			var c := Color("4a3a36") if ladrilho == 0 else Color("40322f")
			if x % 8 == 0 or y % 8 == 0:
				c = Color("2a201e")
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(LARGURA, FUNDO)
	chao.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(LARGURA / 4.0, FUNDO / 4.0, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.95
	chao.material_override = mat
	add_child(chao)
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	add_child(corpo)
	var paredes := [[Vector3(0, 0.5, -FUNDO * 0.5), Vector3(LARGURA, 1.0, 0.6)], [Vector3(0, 0.5, FUNDO * 0.5), Vector3(LARGURA, 1.0, 0.6)],
		[Vector3(-LARGURA * 0.5, 0.5, 0), Vector3(0.6, 1.0, FUNDO)], [Vector3(LARGURA * 0.5, 0.5, 0), Vector3(0.6, 1.0, FUNDO)]]
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color("6b5a52")
	for w in paredes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new(); bs.size = w[1]
		cs.shape = bs
		cs.position = w[0]
		corpo.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = w[1]
		mi.mesh = bm; mi.material_override = pmat; mi.position = w[0]
		add_child(mi)

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
	var alvo: Vector3 = jogador.global_position + jogador.olhar * 0.6
	alvo.x = clampf(alvo.x, -7.0, 7.0)
	alvo.z = clampf(alvo.z, -5.0, 5.0)
	cam_alvo = cam_alvo.lerp(alvo, peso)
	var sac := Vector3.ZERO
	if tremor > 0.0:
		var f := tremor * tremor * 0.4
		sac = cam_direita * randf_range(-1, 1) * f + Vector3.UP * randf_range(-1, 1) * f
	camera.global_transform = Transform3D(Basis.IDENTITY, cam_alvo + cam_tras * 60.0 + sac).looking_at(cam_alvo + sac, Vector3.UP)

func _alvo(tipo: String, ident: String, pos: Vector3) -> Node3D:
	var a: Node3D = Alvo.new().configurar(tipo, ident)
	a.name = ident
	a.position = pos
	add_child(a)
	_colisor(a, 0.38)
	alvos.append(a)
	return a

func _colisor(n: Node3D, r: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 4
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new(); cy.radius = r; cy.height = 1.6
	cs.shape = cy
	cs.position.y = 0.8
	sb.add_child(cs)
	n.add_child(sb)

func _montar_alvos() -> void:
	_alvo("poste", "poste_treino", Vector3(-6.5, 0, 1.0))
	_alvo("boneco", "boneco_a", Vector3(-3.2, 0, -1.2))
	_alvo("boneco", "boneco_b", Vector3(0.4, 0, -3.4))
	_alvo("escudeiro", "escudeiro_palha", Vector3(2.6, 0, -0.6))

func _montar_bate_estaca() -> void:
	if bate != null and is_instance_valid(bate):
		bate.queue_free()
	bate = BateEstaca.new()
	bate.name = "BateEstaca"
	bate.position = Vector3(7.5, 0, -4.5)
	add_child(bate)
	for t in bate.travas:
		_colisor(t, 0.3)
	bate.trava_aberta.connect(_ao_abrir_trava)
	bate.aberto.connect(_ao_abrir_bate)
	bate.catraca_coletada.connect(_ao_pegar_catraca)
	bate.pancada.connect(_ao_pancada)

func todos_alvos() -> Array:
	var l: Array = []
	for a in alvos:
		if is_instance_valid(a) and a.alvejavel():
			l.append(a)
	if bate != null and is_instance_valid(bate):
		for t in bate.travas:
			if t.alvejavel():
				l.append(t)
	return l

func reiniciar() -> void:
	jogador.reiniciar(Vector3(0, 0, 4.5))
	eco.limpar()
	for id in _visuais.keys():
		_remover_visual(id)
	_montar_bate_estaca()
	mostrar_banner("Reiniciado", 0.8)

# ------------------------------------------------------------------ ciclo
func _process(delta: float) -> void:
	# o delta deste quadro foi escalado com o time_scale do começo do quadro (antes de um hitstop novo)
	var real := delta / maxf(_escala_quadro, 0.001)
	t_real += real
	if hitstop_restante > 0.0:
		hitstop_restante -= real
		if hitstop_restante <= 0.0:
			Engine.time_scale = 1.0
	tremor = maxf(0.0, tremor - real * 2.6)
	if demo:
		_piloto(real)
	elif not modo_teste:
		jogador.entrada_mov = Vector2(Input.get_axis("cmb_esquerda", "cmb_direita"), Input.get_axis("cmb_baixo", "cmb_cima"))
	_atualizar_visuais()
	_atualizar_camera(1.0 - exp(-8.0 * real))
	if bate != null and is_instance_valid(bate):
		bate.tentar_coletar(jogador.global_position)
	_hud_atualizar()
	_escala_quadro = Engine.time_scale

func _physics_process(delta: float) -> void:
	tempo += delta
	for e in eco.atualizar(tempo):
		_disparar(e)

# ------------------------------------------------------------------ golpes normais
func _golpe_jogador(d: Dictionary) -> void:
	if String(d.get("tipo", "")) != "combo":
		return
	var origem: Vector3 = d.origem
	var dir: Vector3 = d.dir
	_fx_corte(origem, dir, int(d.indice), Color(2.4, 1.1, 0.5) if bool(d.pesado) else Color(1.6, 1.35, 1.1))
	var acertos := 0
	for a in todos_alvos():
		var para: Vector3 = a.global_position - origem
		para.y = 0
		var dist := para.length()
		if dist > float(d.alcance) + float(a.raio_alvo):
			continue
		var ang := rad_to_deg(dir.angle_to(para.normalized())) if dist > 0.05 else 0.0
		if ang > float(d.arco) * 0.5 and dist > 0.8:
			continue
		var r: Dictionary = a.receber_golpe(int(d.dano), (para.normalized() if dist > 0.05 else dir) * float(d.empurrao), bool(d.pesado), false, false)
		if not r.acertou:
			continue
		acertos += 1
		_feedback(a, r, bool(d.pesado), false)
	if acertos > 0:
		hitstop(0.09 if bool(d.pesado) else 0.05)
		sacudir(0.5 if bool(d.pesado) else 0.25)
	eco.registrar(d, tempo)

func _feedback(a: Node3D, r: Dictionary, grande: bool, de_eco: bool) -> void:
	var topo: Vector3 = a.global_position + Vector3(0, 2.2 if a.tipo != "trava" else 1.3, 0)
	if r.bloqueado:
		stats.bloqueios += 1
		if a.tipo == "trava":
			stats.clangs += 1
		numero(topo, String(r.texto) + ((" %d" % int(r.dano)) if int(r.dano) > 0 else ""), false, Color("a39a8c"))
		_faisca(topo - Vector3(0, 0.9, 0), Color(2.0, 2.0, 2.2), 8)
		return
	if de_eco:
		stats.acertos_eco += 1
	else:
		stats.acertos_normais += 1
	if r.quebrou_guarda:
		stats.guardas_quebradas += 1
		numero(topo + Vector3(0, 0.45, 0), "GUARDA QUEBRADA", true, Color("ffae5a"))
	if r.abriu:
		numero(topo, "DESTRAVOU!", true, Color("7fe07a"))
		_faisca(topo - Vector3(0, 0.6, 0), Color(1.2, 3.0, 1.4), 20)
		return
	var txt := ("ECO %d" if de_eco else "%d") % int(r.dano)
	numero(topo, txt, grande, COR_ECO if de_eco else (Color(1.0, 0.62, 0.2) if grande else Color.WHITE))
	_faisca(topo - Vector3(0, 1.0, 0), Color(1.4, 2.6, 3.0) if de_eco else Color(3.0, 2.6, 2.0), 16 if grande else 10)

# ------------------------------------------------------------------ eco: telegrafia, fantasma e disparo
func _ao_marcar(e: Dictionary) -> void:
	stats.ecos_marcados += 1
	eco_marcado.emit(e)
	var vis := {}
	var anel := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2.ONE * float(e.raio) * 2.0
	anel.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _shader_relogio
	mat.set_shader_parameter("p", 0.0)
	mat.set_shader_parameter("cor", Color("7fe6ff") if e.variacao != "eco_pesado" else Color("b7a0ff"))
	anel.material_override = mat
	anel.position = Vector3(float(e.centro.x), 0.04, float(e.centro.z))
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anel)
	vis.anel = anel
	vis.mat = mat
	var s: AnimatedSprite3D = jogador.sprite
	var f := AnimatedSprite3D.new()
	f.sprite_frames = s.sprite_frames
	f.animation = s.animation
	f.frame = s.frame
	f.pixel_size = s.pixel_size
	f.offset = s.offset
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	f.shaded = false
	f.transparent = true
	f.no_depth_test = true
	f.render_priority = 2
	f.modulate = Color(0.45, 0.85, 1.6, 0.0)
	f.position = Vector3(float(e.origem.x), 0.0, float(e.origem.z))
	add_child(f)
	vis.fantasma = f
	vis.seg = jogador.dados.direcoes[jogador.dir6()].combo[2]
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0014
	l.font = _fonte
	l.font_size = 28
	l.outline_size = 8
	l.modulate = COR_ECO
	l.outline_modulate = Color(0.05, 0.08, 0.12)
	l.position = anel.position + Vector3(0, 0.6, 0)
	add_child(l)
	vis.rotulo = l
	_visuais[int(e.id)] = vis
	log_ecos.append({"id": e.id, "marcado": tempo, "variacao": e.variacao})

func _atualizar_visuais() -> void:
	for e in eco.pendentes:
		var vis: Dictionary = _visuais.get(int(e.id), {})
		if vis.is_empty():
			continue
		var p := Eco.progresso(e, tempo)
		vis.mat.set_shader_parameter("p", p)
		var f: AnimatedSprite3D = vis.fantasma
		f.modulate.a = 0.25 + 0.4 * p
		var seg: Array = vis.seg
		if p > 0.55:
			f.frame = roundi(lerpf(float(seg[0]), float(seg[1]), clampf((p - 0.55) / 0.45, 0.0, 1.0)))
		else:
			f.frame = int(seg[1])
		vis.rotulo.text = _num(maxf(0.0, float(e.t_disparo) - tempo)) + " s"

func _remover_visual(id: int) -> void:
	var vis: Dictionary = _visuais.get(id, {})
	for k in ["anel", "fantasma", "rotulo"]:
		if vis.has(k) and is_instance_valid(vis[k]):
			vis[k].queue_free()
	_visuais.erase(id)

func _disparar(e: Dictionary) -> void:
	stats.ecos_disparados += 1
	var vis: Dictionary = _visuais.get(int(e.id), {})
	var centro: Vector3 = e.centro
	var pesado := bool(e.quebra_guarda)
	_fx_corte(e.origem, e.dir, 2, Color(0.8, 2.0, 2.8) if not pesado else Color(1.6, 1.2, 3.0))
	_onda(centro, float(e.raio), Color(0.6, 1.8, 2.6) if not pesado else Color(1.4, 1.1, 2.8))
	if not vis.is_empty():
		var f: AnimatedSprite3D = vis.fantasma
		var seg: Array = vis.seg
		f.modulate = Color(1.2, 2.0, 2.6, 0.9)
		var tw := f.create_tween()
		tw.tween_method(func(v: float): f.frame = roundi(v), float(seg[1]), float(seg[2]), 0.25)
		tw.parallel().tween_property(f, "modulate:a", 0.0, 0.3)
		tw.tween_callback(f.queue_free)
		for k in ["anel", "rotulo"]:
			if is_instance_valid(vis[k]):
				vis[k].queue_free()
		_visuais.erase(int(e.id))
	var acertos := 0
	for a in todos_alvos():
		if not Eco.dentro(e, a.global_position, float(a.raio_alvo)):
			continue
		var para: Vector3 = a.global_position - centro
		para.y = 0
		var emp: Vector3 = (para.normalized() if para.length() > 0.05 else Vector3(e.dir)) * (9.0 if pesado else 5.0)
		var r: Dictionary = a.receber_golpe(int(e.dano), emp, pesado, true, pesado)
		if not r.acertou:
			continue
		acertos += 1
		_feedback(a, r, true, true)
		if not r.bloqueado:
			eco_acertou.emit(String(a.id_alvo), int(r.dano), String(e.variacao))
			if gerenciador != null:
				gerenciador.notificar("eco_acertou", String(a.id_alvo))
	if acertos > 0:
		hitstop(0.11 if pesado else 0.07)
		sacudir(0.65 if pesado else 0.35)
		var bonus := float(e.bonus_dash)
		if bonus > 0.0:
			jogador.dash_cd_ate = maxf(jogador.relogio, jogador.dash_cd_ate - bonus)
			stats.dash_bonus += 1
			numero(jogador.global_position + Vector3(0, 2.3, 0), "dash −0,1 s", false, Color("9fe8ff"))
	for le in log_ecos:
		if int(le.id) == int(e.id):
			le["disparado"] = tempo
			le["acertos"] = acertos
	eco_disparou.emit(e, acertos)

# ------------------------------------------------------------------ Bate-Estaca
func _ao_abrir_trava(indice: int, abertas: int) -> void:
	stats.travas_abertas = abertas
	trava_aberta.emit(indice, abertas)
	if gerenciador != null:
		gerenciador.notificar("trava_acertada_eco", "bate_estaca")
	mostrar_banner("Trava %d/3 aberta pelo eco" % abertas, 1.2)

func _ao_abrir_bate() -> void:
	bate_estaca_aberto.emit()
	sacudir(0.6)
	mostrar_banner("O BATE-ESTACA PAROU · a Catraca-Mestra nº 3 apareceu", 2.4)

func _ao_pegar_catraca() -> void:
	if gerenciador != null:
		gerenciador.coletar_item("catraca_mestra")
	mostrar_banner("Catraca-Mestra nº 3! Gravado na borda: 'feita amanhã'", 2.4)

func _ao_pancada(centro: Vector3, raio: float) -> void:
	sacudir(0.35)
	_faisca(centro + Vector3(0, 0.3, 0), Color(1.4, 1.2, 1.0), 14)
	var d: Vector3 = jogador.global_position - centro
	if Vector2(d.x, d.z).length() <= raio + 0.36:
		if jogador.receber_dano(12, centro):
			stats.pancadas += 1
			numero(jogador.global_position + Vector3(0, 2.2, 0), "12", false, Color("ff6b5a"))

# ------------------------------------------------------------------ efeitos
func hitstop(segundos: float) -> void:
	stats.hitstops += 1
	Engine.time_scale = 0.05
	hitstop_restante = maxf(hitstop_restante, segundos)

func sacudir(forca: float) -> void:
	tremor = clampf(maxf(tremor, forca), 0.0, 1.0)

func numero(pos: Vector3, texto: String, grande: bool, cor := Color.WHITE) -> void:
	stats.numeros += 1
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0017
	l.font = _fonte
	l.font_size = 40 if grande else 30
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.03, 0.05)
	l.modulate = cor
	l.render_priority = 10
	l.position = pos + cam_direita * randf_range(-0.25, 0.25)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 0.9, 0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)

func _fx_corte(origem: Vector3, dir: Vector3, indice: int, cor: Color) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var w: float = [2.6, 2.7, 3.4][clampi(indice, 0, 2)]
	pm.size = Vector2(w, w * 81.0 / 128.0)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_texture = corte_tex
	mat.albedo_color = cor
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
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18).set_delay(0.05)
	tw.chain().tween_callback(m.queue_free)

func _onda(centro: Vector3, raio: float, cor: Color) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2.ONE * raio * 2.0
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = true
	mat.albedo_texture = anel_tex
	mat.albedo_color = cor
	m.material_override = mat
	m.position = Vector3(centro.x, 0.06, centro.z)
	m.scale = Vector3.ONE * 0.4
	add_child(m)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 1.1, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3).set_delay(0.08)
	tw.chain().tween_callback(m.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color(cor.r, cor.g, cor.b).clamp()
	luz.light_energy = 4.0
	luz.omni_range = raio * 2.4
	luz.position = centro + Vector3(0, 1.0, 0)
	add_child(luz)
	var tl := luz.create_tween()
	tl.tween_property(luz, "light_energy", 0.0, 0.3)
	tl.tween_callback(luz.queue_free)
	_faisca(centro + Vector3(0, 0.5, 0), cor, 26)

func _faisca(pos: Vector3, cor: Color, n: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var q := QuadMesh.new(); q.size = Vector2(0.08, 0.08)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = cor
	q.material = qm
	p.mesh = q
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8, true, false, true).timeout.connect(p.queue_free)

func _criar_shader_relogio() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float p = 0.0;
uniform vec4 cor : source_color = vec4(0.5, 0.9, 1.0, 1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	if (d > 1.0) { discard; }
	float ang = fract(atan(uv.x, -uv.y) / 6.28318 + 1.0);
	float borda = smoothstep(0.88, 0.94, d) * (1.0 - smoothstep(0.97, 1.0, d));
	float marcas = step(0.74, d) * step(d, 0.86) * step(0.9, fract(ang * 12.0));
	float fatia = step(ang, p) * step(d, 0.86) * 0.32;
	float ponteiro = step(abs(fract(ang - p + 0.5) - 0.5), 0.012) * step(d, 0.86);
	float fim = smoothstep(0.82, 1.0, p);
	float pulso = mix(1.0, 0.6 + 0.4 * sin(TIME * 50.0), fim);
	float a = (borda * (0.55 + 0.45 * p) + marcas * 0.6 + fatia + ponteiro * 0.9) * pulso;
	ALBEDO = cor.rgb * (1.0 + 1.6 * fim);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	return s

# ------------------------------------------------------------------ HUD
func _estilo(fundo: Color, borda: Color, largura := 3, margem := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(margem)
	return s

func _lbl(t: String, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", _fonte)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color("1b1410"))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.106, 0.078, 0.063, 0.88), Color("c9a25a")))
	painel.position = Vector2(24, 20)
	hud.add_child(painel)
	var v := VBoxContainer.new()
	painel.add_child(v)
	v.add_child(_lbl("ECO TEMPORAL · protótipo", 32, Color("ffd27a")))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var i := 1
	for vid in Eco.ORDEM:
		var p := PanelContainer.new()
		var l := _lbl("%d %s" % [i, eco.nome(vid)], 26, Color("f1e2bd"))
		p.add_child(l)
		h.add_child(p)
		chips[vid] = p
		i += 1
	lbl_var = _lbl("", 24, Color("f1e2bd"))
	v.add_child(lbl_var)
	lbl_cont = _lbl("", 26, Color("f1e2bd"))
	lbl_cont.position = Vector2(0, 24)
	lbl_cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_cont.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_cont.offset_left = -700; lbl_cont.offset_right = -24; lbl_cont.offset_top = 20
	hud.add_child(lbl_cont)
	var rod := _lbl("WASD mover · J/clique atacar (3º golpe = pesado + eco) · H/LB golpe pesado · Espaço dash · 1/2/3 variação · R reiniciar", 22, Color("b8a07a"))
	rod.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rod.offset_top = -46; rod.offset_bottom = -12
	hud.add_child(rod)
	lbl_banner = _lbl("", 36, Color("ffd27a"))
	lbl_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_banner.offset_left = -700; lbl_banner.offset_right = 700; lbl_banner.offset_top = 210; lbl_banner.offset_bottom = 260
	hud.add_child(lbl_banner)

func _atualizar_hud_variacao() -> void:
	if lbl_var == null:
		return
	for vid in chips:
		var atual: bool = vid == eco.atual
		chips[vid].add_theme_stylebox_override("panel", _estilo(Color("4a3220") if atual else Color("2a1f17"), Color("ffd27a") if atual else Color("5a3d22"), 3, 6))
	var d: Dictionary = eco.dados()
	var extra := String(d.get("extra", ""))
	lbl_var.text = "atraso %s s · dano %d%% · raio %s m%s" % [_num(eco.atraso()), roundi(eco.dano_relativo() * 100), _num(eco.raio()), ("\n" + extra) if extra != "" else ""]

func _hud_atualizar() -> void:
	if lbl_cont == null:
		return
	lbl_cont.text = "ecos %d · acertos de eco %d · travas %d/3\nbloqueios %d · guardas quebradas %d" % [stats.ecos_disparados, stats.acertos_eco, stats.travas_abertas, stats.bloqueios, stats.guardas_quebradas]
	if t_real > _banner_ate:
		lbl_banner.modulate.a = maxf(0.0, lbl_banner.modulate.a - 0.05)

func mostrar_banner(t: String, s: float) -> void:
	if lbl_banner == null:
		return
	lbl_banner.text = t
	lbl_banner.modulate.a = 1.0
	_banner_ate = t_real + s

# ------------------------------------------------------------------ piloto automático (vídeo)
func _frente(a: Node3D, de: Vector3, dist := 1.6) -> Vector3:
	var d: Vector3 = de
	d.y = 0
	return a.global_position + d.normalized() * dist

func _roteiro_demo() -> Array:
	var ba: Node3D = alvos[1]
	var bb: Node3D = alvos[2]
	var es: Node3D = alvos[3]
	var c: Vector3 = bate.global_position
	var tr: Array = bate.travas
	return [
		["esperar", 1.0],
		["ir_alvo", ba, Vector3(0.6, 0, 1)], ["combo", ba], ["esperar", 1.2],
		["var", "eco_rapido"], ["esperar", 0.4],
		["ir_alvo", bb, Vector3(1, 0, 1)], ["combo", bb], ["esperar", 0.5], ["dash", Vector3(1, 0, 0.6)], ["esperar", 0.9],
		["var", "eco_pesado"], ["esperar", 0.4],
		["ir_alvo", es, Vector3(-0.3, 0, 1)], ["combo", es], ["esperar", 0.35], ["dash", Vector3(-1, 0, 0.3)], ["esperar", 1.0],
		["ir_alvo", es, Vector3(-0.3, 0, 1)], ["combo", es], ["esperar", 1.3],
		["banner", "BATE-ESTACA · as travas só abrem com o eco", 1.8],
		["ir_alvo", tr[0], tr[0].global_position - c], ["golpe", tr[0]], ["esperar", 0.5], ["combo", tr[0]], ["esperar", 1.3],
		["ir_ponto", c + Vector3(-3.6, 0, 2.2)],
		["ir_alvo", tr[1], tr[1].global_position - c], ["combo", tr[1]], ["esperar", 1.3],
		["ir_ponto", c + Vector3(-3.4, 0, -3.0)],
		["ir_alvo", tr[2], tr[2].global_position - c], ["combo", tr[2]], ["esperar", 1.6],
		["ir_ponto", c + Vector3(-1.4, 0, -2.6)], ["ir_catraca"], ["esperar", 2.2], ["fim"]]

func _andar_para(p: Vector3) -> bool:
	var d: Vector3 = p - jogador.global_position
	d.y = 0
	if d.length() < 0.25:
		jogador.entrada_mov = Vector2.ZERO
		return true
	var n := d.normalized()
	jogador.entrada_mov = Vector2(n.dot(cam_direita), n.dot(cam_cima)) * (1.0 if d.length() > 0.6 else 0.6)
	return false

func _piloto(real: float) -> void:
	if passo_i >= roteiro.size():
		return
	var p: Array = roteiro[passo_i]
	passo_t += real
	var feito := false
	match String(p[0]):
		"esperar":
			jogador.entrada_mov = Vector2.ZERO
			feito = passo_t >= float(p[1])
		"banner":
			mostrar_banner(String(p[1]), float(p[2]))
			feito = true
		"var":
			definir_variacao(String(p[1]))
			feito = true
		"ir_alvo":
			if not _passo_dados.has("destino"):
				_passo_dados.destino = _frente(p[1], p[2])
			feito = _andar_para(_passo_dados.destino) or passo_t > 4.0
		"ir_ponto":
			feito = _andar_para(p[1]) or passo_t > 4.0
		"ir_catraca":
			feito = _andar_para(bate.posicao_catraca()) or bate.catraca_pega or passo_t > 4.0
		"golpe", "combo":
			jogador.entrada_mov = Vector2.ZERO
			var alvo: Node3D = p[1]
			var dir: Vector3 = alvo.global_position - jogador.global_position
			dir.y = 0
			var n := 1 if String(p[0]) == "golpe" else 3
			var dados_n := int(_passo_dados.get("n", 0))
			if dados_n < n and passo_t >= dados_n * 0.21:
				jogador.pedir_ataque(dir.normalized())
				_passo_dados.n = dados_n + 1
			feito = int(_passo_dados.get("n", 0)) >= n and passo_t >= n * 0.21 + 0.25
		"dash":
			var dv: Vector3 = p[1]
			var nn := dv.normalized()
			jogador.entrada_mov = Vector2(nn.dot(cam_direita), nn.dot(cam_cima))
			if not _passo_dados.has("ok"):
				_passo_dados.ok = true
				jogador.pedir_dash()
			feito = passo_t > 0.25
		"fim":
			jogador.entrada_mov = Vector2.ZERO
			if not demo_fim:
				demo_fim = true
				demo_terminou.emit()
			return
	if feito:
		passo_i += 1
		passo_t = 0.0
		_passo_dados = {}
