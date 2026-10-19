extends CharacterBody3D
## Vale no prototipo de combate (estilo Hades): movimento em 8 direcoes, combo de 3 golpes com
## buffer de entrada, dash com i-frames e recarga curta (cancela ataques), golpe de investida
## (ataque logo apos o dash) e especial com recarga. Toda a logica e determinista e dirigida
## por pedir_ataque()/pedir_dash()/pedir_especial() + entrada_mov, para os testes roteirizados.
const Folhas = preload("res://scripts/combate/folhas.gd")
const FormaAdamantium = preload("res://scripts/combate/forma_adamantium.gd")
signal golpe(dados: Dictionary)
signal ferido(dano: int)
signal morreu
signal dash_feito
signal transformacao_iniciada
signal transformou(ativo: bool)
signal raio_disparou

const DIRS8 := ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]
const DADOS := "res://art/combate/vale_combate_dados.json"
const PASTA_COMBATE := "res://art/characters/vale_combate_gamelab/"
## golpes Gamelab remapeados para a paleta da Vale V6 da vila (art/characters/vale_combate_v6pal/README.md)
const PASTA_COMBATE_V6 := "res://art/characters/vale_combate_v6pal/"
## golpes TRANSFORMADO: mesmos quadros com a armadura de adamantium (tools/vale_armadura.py)
const PASTA_ARMADURA := "res://art/characters/vale_combate_armadura/"
static var armadura_golpes := true
static var paleta_v6 := true
static func pasta_golpes() -> String:
	if paleta_v6 and FileAccess.file_exists(PASTA_COMBATE_V6 + "README.md"):
		return PASTA_COMBATE_V6
	return PASTA_COMBATE
const PASTA_BASE := "res://art/characters/original_vale_v6/"
const MOVS := ["slash_combo", "dash", "hit", "special"]
# Escala medida (tests/combate_testes.gd confere): corpo em pe = 45 px nas animacoes V6 (run) e
# nos quadros Gamelab de 112 px (44-46 px no quadro 0); o idle (rotations/) desenha o mesmo
# corpo com 48 px. Mesma altura em tela (ALTURA_CORPO) em idle, corrida e golpes.
const ALTURA_CORPO := 1.72 / 48.0 * 45.0
const PX_BASE := ALTURA_CORPO / 45.0
const PX_IDLE := ALTURA_CORPO / 48.0
const PX_COMBATE := ALTURA_CORPO / 45.0

# ---- ajustes de sensacao (segundos, metros, m/s) ----
var velocidade := 6.6
var combo_ativo := [0.07, 0.08, 0.13]      # instante do golpe dentro de cada ataque
var combo_total := [0.26, 0.28, 0.46]      # duracao de cada ataque
var combo_cancelar := [0.15, 0.17, 0.46]   # a partir daqui o golpe seguinte do buffer comeca
var combo_janela := 0.30                    # depois do fim de um golpe, ainda continua o combo
var buffer_tempo := 0.22                    # entrada antecipada guardada (livre)
var combo_dano := [10, 12, 24]
var combo_alcance := [2.2, 2.3, 2.7]
var combo_arco := [120.0, 130.0, 160.0]
var combo_empurrao := [3.5, 4.0, 9.0]
var combo_avanco := [2.4, 2.6, 4.2]
var investida_janela := 0.20
var investida_dano := 18
var dash_duracao := 0.19
var dash_distancia := 4.4
var dash_recarga := 0.32
var dash_iframes_extra := 0.05
var especial_ativo := 0.34
var especial_total := 0.78
var especial_recarga := 4.0
var especial_dano := 30
var especial_raio := 3.4
var hp_max := 100
var hp := 100
var iframes_dano := 0.75
var ferido_duracao := 0.32
var multiplicador_dano := 1.0
# ---- forma Adamantium (G) e Raio de Adamantium (segurar Q/RMB transformado)
var energia_max := 100.0
var energia := 100.0                 # barra ADAMANTIUM: enche com acertos; cheia = pode transformar
var energia_por_acerto := 7.0
var forma_duracao := 20.0            # segundos transformado (a barra esvazia)
var transformar_duracao := 0.5       # explosao de transformacao (i-frames + camera lenta na arena)
var raio_carga_min := 0.25
var raio_carga_max := 1.0            # carga cheia em 1 s segurando
var raio_segurar_max := 3.0          # dispara sozinho depois disso
var raio_duracao_base := 1.0         # 1,0 s (carga minima) a 1,45 s (carga cheia)
var raio_duracao_extra := 0.45
var raio_tick := 0.1
var raio_dano_base := 5              # por tick: 5 (min) a 11 (cheia), atravessa todos no feixe
var raio_dano_extra := 6
var raio_comprimento := 15.0
var raio_recarga := 7.0
var raio_lento_carga := 0.4          # fracao da velocidade ao carregar
var raio_lento_disparo := 0.22       # fracao da velocidade disparando
var raio_virada := deg_to_rad(75.0)  # giro maximo do feixe por segundo seguindo a mira

# ---- estado ----
var estado := "livre"   # livre | ataque | dash | especial | ferido | morto
var t_estado := 0.0
var relogio := 0.0
var combo_i := -1
var combo_fim_t := -10.0
var investida := false
var golpe_aplicado := false
var buffer_ataque := -10.0
var buffer_dash := -10.0
var buffer_especial := -10.0
var inicio_estado := 0.0
var dash_dir := Vector3.RIGHT
var dash_fim := -10.0
var dash_cd_ate := 0.0
var especial_cd_ate := 0.0
var invulneravel_ate := 0.0
var ultimo_dano_t := -10.0
var empurrao := Vector3.ZERO
var olhar := Vector3(1, 0, 0)       # direcao no chao para onde o Vale olha
var mira := Vector3.ZERO             # direcao pedida para o proximo golpe (zero = usar movimento/olhar)
var dir8 := "south-east"
var lado := 1
var entrada_mov := Vector2.ZERO      # tela: x direita, y para cima
var cam_direita := Vector3(0.7071, 0, -0.7071)
var cam_cima := Vector3(-0.7071, 0, -0.7071)
var stats := {"golpes": 0, "dashes": 0, "especiais": 0, "dano_recebido": 0, "esquivados": 0, "investidas": 0, "transformacoes": 0, "raios": 0, "raio_ticks": 0}
var log_eventos: Array = []

var sprite: AnimatedSprite3D
var dados: Dictionary = {}
var base_manifest: Dictionary = {}
var sombra: MeshInstance3D
var adamantium
var transformado := false
var forma_ate := 0.0
var carga := 0.0
var raio_dir := Vector3.RIGHT
var raio_mira := Vector3.ZERO
var raio_solto := false
var raio_cd_ate := 0.0
var raio_duracao := 1.0
var raio_proximo := 0.0
var raio_ticks := 0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	var forma := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.36
	cap.height = 1.4
	forma.shape = cap
	forma.position.y = 0.7
	add_child(forma)
	dados = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	_montar_sprite()
	adamantium = FormaAdamantium.new()
	add_child(adamantium)
	adamantium.setup(self)

func _montar_sprite() -> void:
	sprite = AnimatedSprite3D.new()
	sprite.name = "SpriteVale"
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	base_manifest = JSON.parse_string(FileAccess.get_file_as_string(PASTA_BASE + "manifest.json"))
	for anim: String in base_manifest.anims:
		if not (anim.begins_with("idle_") or anim.begins_with("run_")):
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(base_manifest.anims[anim].fps))
		frames.set_animation_loop(anim, true)
		for file: String in base_manifest.anims[anim].files:
			frames.add_frame(anim, load(PASTA_BASE + file))
	for mov: String in MOVS:
		for d: String in dados.direcoes:
			var nome := "c_%s_%s" % [mov, d]
			frames.add_animation(nome)
			frames.set_animation_speed(nome, 0.0)
			frames.set_animation_loop(nome, false)
			for tex in Folhas.quadros(pasta_golpes() + "%s/%s_%s_sheet.png" % [mov, mov, d], Vector2i(112, 112), 8, 49):
				frames.add_frame(nome, tex)
			var arq := PASTA_ARMADURA + "%s/%s_%s_sheet.png" % [mov, mov, d]
			if armadura_golpes and FileAccess.file_exists(PASTA_ARMADURA + "README.md"):
				var nx := "x_%s_%s" % [mov, d]
				frames.add_animation(nx)
				frames.set_animation_speed(nx, 0.0)
				frames.set_animation_loop(nx, false)
				for tex in Folhas.quadros(arq, Vector2i(112, 112), 8, 49):
					frames.add_frame(nx, tex)
	sprite.sprite_frames = frames
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.shaded = false
	add_child(sprite)
	sombra = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.95, 0.6)
	sombra.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/contact_shadow.gdshader")
	sombra.material_override = m
	sombra.position.y = 0.03
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sombra)
	_tocar_base("idle")

# ------------------------------------------------------------------ entrada
func pedir_ataque(dir := Vector3.ZERO) -> void:
	buffer_ataque = relogio
	if dir.length_squared() > 0.01:
		mira = Vector3(dir.x, 0, dir.z).normalized()
	if estado == "livre":
		_tentar_acoes(true)   # responde no mesmo quadro da entrada

func pedir_dash() -> void:
	buffer_dash = relogio
	if estado == "livre":
		_tentar_acoes(true)   # responde no mesmo quadro da entrada

func pedir_especial(dir := Vector3.ZERO) -> void:
	buffer_especial = relogio
	if dir.length_squared() > 0.01:
		mira = Vector3(dir.x, 0, dir.z).normalized()
	if estado == "livre":
		_tentar_acoes(true)   # responde no mesmo quadro da entrada

# ---- forma Adamantium / raio
func pode_transformar() -> bool:
	return not transformado and energia >= energia_max - 0.001 and estado in ["livre", "ataque", "ferido"]

func pedir_transformar() -> bool:
	if not pode_transformar():
		return false
	combo_i = -1
	_mudar("transformando")
	invulneravel_ate = maxf(invulneravel_ate, relogio + transformar_duracao + 0.3)
	stats.transformacoes += 1
	transformacao_iniciada.emit()
	return true

func ganhar_energia(v: float) -> void:
	if not transformado:
		energia = minf(energia_max, energia + v)

func _destransformar() -> void:
	transformado = false
	energia = 0.0
	adamantium.ativar(false)
	transformou.emit(false)

func pode_raio() -> bool:
	return transformado and relogio >= raio_cd_ate and estado in ["livre", "ataque"]

func pedir_raio(dir := Vector3.ZERO) -> bool:
	if not pode_raio():
		return false
	raio_dir = Vector3(dir.x, 0, dir.z).normalized() if dir.length_squared() > 0.01 else olhar
	raio_mira = Vector3.ZERO
	_virar(raio_dir)
	combo_i = -1
	carga = 0.0
	raio_solto = false
	_mudar("carregando")
	return true

func soltar_raio() -> void:
	raio_solto = true

func raio_largura_atual() -> float:
	return 0.75 + 0.55 * carga

func raio_origem() -> Vector3:
	return global_position + Vector3(0, 0.95, 0) + raio_dir * 0.55

func raio_recarga_restante() -> float:
	return maxf(0.0, raio_cd_ate - relogio)

func _girar_raio(delta: float) -> void:
	if raio_mira.length_squared() < 0.01:
		return
	var alvo := Vector3(raio_mira.x, 0, raio_mira.z).normalized()
	var ang := raio_dir.signed_angle_to(alvo, Vector3.UP)
	raio_dir = raio_dir.rotated(Vector3.UP, clampf(ang, -raio_virada * delta, raio_virada * delta)).normalized()
	_virar(raio_dir)

func _disparar_raio() -> void:
	raio_duracao = raio_duracao_base + raio_duracao_extra * carga
	raio_ticks = 0
	raio_proximo = relogio
	_mudar("raio")
	stats.raios += 1
	raio_disparou.emit()

func mov_mundo() -> Vector3:
	var v := entrada_mov.limit_length(1.0)
	return cam_direita * v.x + cam_cima * v.y

func dash_pronto() -> bool:
	return relogio >= dash_cd_ate and estado != "dash"

func especial_pronto() -> bool:
	return relogio >= especial_cd_ate

func invulneravel() -> bool:
	return relogio < invulneravel_ate or estado == "morto"

# ------------------------------------------------------------------ ciclo
func _physics_process(delta: float) -> void:
	relogio += delta
	t_estado += delta
	var mm := mov_mundo()
	velocity = Vector3.ZERO
	if transformado:
		energia = energia_max * clampf((forma_ate - relogio) / forma_duracao, 0.0, 1.0)
		if relogio >= forma_ate and estado != "carregando" and estado != "raio":
			_destransformar()
	match estado:
		"transformando":
			if t_estado >= transformar_duracao:
				transformado = true
				forma_ate = relogio + forma_duracao
				energia = energia_max
				adamantium.ativar(true)
				transformou.emit(true)
				_mudar("livre")
		"carregando":
			velocity = mm * velocidade * raio_lento_carga
			carga = clampf(t_estado / raio_carga_max, 0.0, 1.0)
			_girar_raio(delta)
			if _quer_dash():
				carga = 0.0
				_iniciar_dash()
			elif (raio_solto and t_estado >= raio_carga_min) or t_estado >= raio_segurar_max:
				_disparar_raio()
		"raio":
			velocity = mm * velocidade * raio_lento_disparo
			_girar_raio(delta)
			while relogio >= raio_proximo - 0.0001 and raio_ticks * raio_tick < raio_duracao:
				golpe.emit({"tipo": "raio", "origem": raio_origem(), "dir": raio_dir, "comprimento": raio_comprimento,
					"largura": raio_largura_atual(), "dano": roundi((raio_dano_base + raio_dano_extra * carga) * multiplicador_dano),
					"empurrao": 4.5, "pesado": raio_ticks % 4 == 0, "tick": raio_ticks})
				raio_ticks += 1
				stats.raio_ticks += 1
				raio_proximo += raio_tick
			if t_estado >= raio_duracao:
				raio_cd_ate = relogio + raio_recarga
				carga = 0.0
				_mudar("livre")
		"livre":
			velocity = mm * velocidade
			if mm.length() > 0.1:
				_virar(mm)
			_tentar_acoes(true)
		"ataque":
			_proc_ataque(mm)
		"dash":
			velocity = dash_dir * (dash_distancia / dash_duracao)
			if t_estado >= dash_duracao:
				_mudar("livre")
				dash_fim = relogio
				dash_cd_ate = relogio + dash_recarga
				collision_mask = 1 | 4 | 8
				_tentar_acoes(false)
		"especial":
			if t_estado >= especial_ativo and not golpe_aplicado:
				golpe_aplicado = true
				golpe.emit({"tipo": "especial", "origem": global_position, "dir": olhar, "raio": especial_raio, "dano": roundi(especial_dano * multiplicador_dano), "empurrao": 11.0, "pesado": true})
			if golpe_aplicado and _quer_dash():
				_iniciar_dash()
			elif t_estado >= especial_total:
				_mudar("livre")
				_tentar_acoes(false)
		"ferido":
			if t_estado >= 0.12 and _quer_dash():
				_iniciar_dash()
			elif t_estado >= ferido_duracao:
				_mudar("livre")
		"morto":
			pass
	velocity += empurrao
	empurrao = empurrao.move_toward(Vector3.ZERO, 28.0 * delta)
	velocity.y = 0
	move_and_slide()
	position.y = 0
	_animar()

func _quer_dash() -> bool:
	return relogio - buffer_dash <= buffer_tempo and relogio >= dash_cd_ate

func _tentar_acoes(permitir_atraso: bool) -> void:
	var janela := buffer_tempo if permitir_atraso else buffer_tempo + 0.2
	if _quer_dash():
		_iniciar_dash()
	elif relogio - buffer_especial <= janela and especial_pronto():
		_iniciar_especial()
	elif relogio - buffer_ataque <= janela:
		var prox := 0
		if combo_i >= 0 and combo_i < 2 and relogio - combo_fim_t <= combo_janela:
			prox = combo_i + 1
		_iniciar_ataque(prox)

func _mudar(novo: String) -> void:
	estado = novo
	t_estado = 0.0
	inicio_estado = relogio
	log_eventos.append([snappedf(relogio, 0.001), novo, combo_i])

func _aplicar_mira() -> void:
	var mm := mov_mundo()
	if mira.length_squared() > 0.01:
		_virar(mira)
	elif mm.length() > 0.2:
		_virar(mm)
	mira = Vector3.ZERO

func _iniciar_ataque(i: int) -> void:
	buffer_ataque = -10.0
	investida = i == 0 and relogio - dash_fim <= investida_janela
	combo_i = i
	golpe_aplicado = false
	_aplicar_mira()
	_mudar("ataque")
	stats.golpes += 1
	if investida:
		stats.investidas += 1

func _proc_ataque(_mm: Vector3) -> void:
	var i := combo_i
	var ativo: float = combo_ativo[i]
	if t_estado < ativo:
		velocity = olhar * float(combo_avanco[i]) * (1.6 if investida else 1.0)
	if t_estado >= ativo and not golpe_aplicado:
		golpe_aplicado = true
		var dano: int = investida_dano if investida else combo_dano[i]
		golpe.emit({"tipo": "combo", "indice": i, "investida": investida, "origem": global_position, "dir": olhar,
			"alcance": combo_alcance[i], "arco": combo_arco[i], "dano": roundi(dano * multiplicador_dano),
			"empurrao": combo_empurrao[i], "pesado": i == 2})
	# cancelamentos: dash a qualquer momento; especial depois do golpe; proximo golpe pelo buffer
	if _quer_dash():
		combo_fim_t = relogio
		_iniciar_dash()
		return
	if golpe_aplicado and relogio - buffer_especial <= buffer_tempo and especial_pronto():
		_iniciar_especial()
		return
	if i < 2 and buffer_ataque > inicio_estado - 0.001 and t_estado >= combo_cancelar[i]:
		_iniciar_ataque(i + 1)
		return
	if t_estado >= combo_total[i]:
		combo_fim_t = relogio
		if i == 2:
			combo_i = -1
		_mudar("livre")
		_tentar_acoes(false)

func _iniciar_dash() -> void:
	buffer_dash = -10.0
	var mm := mov_mundo()
	dash_dir = mm.normalized() if mm.length() > 0.2 else olhar
	_virar(dash_dir)
	_mudar("dash")
	invulneravel_ate = maxf(invulneravel_ate, relogio + dash_duracao + dash_iframes_extra)
	collision_mask = 1 | 4   # atravessa inimigos durante o dash
	stats.dashes += 1
	dash_feito.emit()

func _iniciar_especial() -> void:
	buffer_especial = -10.0
	especial_cd_ate = relogio + especial_recarga
	golpe_aplicado = false
	combo_i = -1
	_aplicar_mira()
	_mudar("especial")
	stats.especiais += 1

func receber_dano(dano: int, de: Vector3) -> bool:
	if invulneravel():
		if estado == "dash":
			stats.esquivados += 1
		return false
	hp = maxi(0, hp - dano)
	stats.dano_recebido += dano
	invulneravel_ate = relogio + iframes_dano
	ultimo_dano_t = relogio
	var fora := global_position - de
	fora.y = 0
	empurrao = (fora.normalized() if fora.length() > 0.01 else -olhar) * 7.0
	ferido.emit(dano)
	if hp <= 0:
		combo_i = -1
		if estado == "raio":
			raio_cd_ate = relogio + raio_recarga
		_mudar("morto")
		morreu.emit()
	elif estado == "carregando" or estado == "raio":
		empurrao *= 0.25   # superarmadura: o raio nao e interrompido
	else:
		combo_i = -1
		_mudar("ferido")
	return true

func curar(valor: int) -> void:
	hp = mini(hp_max, hp + valor)

func reiniciar(pos: Vector3) -> void:
	hp = hp_max
	position = pos
	_mudar("livre")
	combo_i = -1
	empurrao = Vector3.ZERO
	invulneravel_ate = relogio + 1.0
	dash_cd_ate = 0.0
	especial_cd_ate = 0.0
	if transformado:
		_destransformar()
	energia = energia_max
	raio_cd_ate = 0.0
	carga = 0.0
	sprite.modulate = Color.WHITE

# ------------------------------------------------------------------ direcao e animacao
func tela(dir: Vector3) -> Vector2:
	return Vector2(dir.dot(cam_direita), dir.dot(cam_cima))

func _virar(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		return
	olhar = d.normalized()
	var s := tela(olhar)
	var idx := posmod(roundi(atan2(s.y, s.x) / (PI / 4.0)), 8)
	dir8 = DIRS8[idx]
	if absf(s.x) > 0.15:
		lado = 1 if s.x > 0 else -1

func dir6() -> String:
	match dir8:
		"north":
			return "north-east" if lado > 0 else "north-west"
		"south":
			return "south-east" if lado > 0 else "south-west"
	return dir8

func _tocar_base(mov: String) -> void:
	var nome := mov + "_" + dir8
	if not sprite.sprite_frames.has_animation(nome):
		nome = "idle_" + dir8
	if sprite.animation != nome:
		sprite.play(nome)
	sprite.pixel_size = PX_IDLE if nome.begins_with("idle_") else PX_BASE
	var info: Dictionary = base_manifest.anims.get(nome, {})
	var foot := 43.0
	if info.has("feet"):
		var feet: Array = info.feet
		foot = float(feet[mini(sprite.frame, feet.size() - 1)])
	sprite.offset = Vector2(0, foot - 24.0)

func _tocar_forma(mov: String) -> void:
	var nome := "a_%s_%s" % [mov, dir8]
	if sprite.animation != nome:
		sprite.play(nome)
	sprite.pixel_size = ALTURA_CORPO / adamantium.ref(mov)
	sprite.offset = Vector2(0, adamantium.pe(nome, sprite.frame) - 24.0)

func _quadro_seg(seg: Array, ativo: float, total: float) -> int:
	var a := float(seg[0])
	var imp := float(seg[1])
	var b := float(seg[2])
	if t_estado < ativo:
		return roundi(lerpf(a, imp, clampf(t_estado / maxf(ativo, 0.001), 0, 1)))
	return roundi(lerpf(imp, b, clampf((t_estado - ativo) / maxf(total - ativo, 0.001), 0, 1)))

func _tocar_combate(mov: String, quadro: int) -> void:
	var d := dir6()
	var nome := "c_%s_%s" % [mov, d]
	# transformado: golpes com armadura (nunca o corpo sem armadura no meio do ataque)
	if transformado and sprite.sprite_frames.has_animation("x_%s_%s" % [mov, d]):
		nome = "x_%s_%s" % [mov, d]
	if sprite.animation != nome:
		sprite.animation = nome
	sprite.pause()
	sprite.frame = clampi(quadro, 0, 48)
	sprite.pixel_size = PX_COMBATE
	var anc: Array = dados.direcoes[d].ancora[mov]
	var off := Vector2(56.0 - float(anc[0]), float(anc[1]) - 56.0)
	if mov == "dash":
		var comp: Dictionary = dados.direcoes[d].dash_comp_px
		var key := str(sprite.frame)
		if comp.has(key):
			var c: Array = comp[key]
			var v := Vector2(float(c[0]), float(c[1]))
			if v.length() > 6.0:
				off += v
	sprite.offset = off

func _animar() -> void:
	var d6: Dictionary = dados.direcoes[dir6()]
	match estado:
		"livre":
			if transformado:
				_tocar_forma("run" if mov_mundo().length() > 0.1 else "idle")
			else:
				_tocar_base("run" if mov_mundo().length() > 0.1 else "idle")
		"transformando":
			_tocar_combate("special", _quadro_seg(d6.especial, transformar_duracao * 0.6, transformar_duracao))
		"carregando", "raio":
			_tocar_forma("walk" if mov_mundo().length() > 0.1 else "idle")
		"ataque":
			_tocar_combate("slash_combo", _quadro_seg(d6.combo[combo_i], combo_ativo[combo_i], combo_total[combo_i]))
		"dash":
			var seg: Array = d6.dash
			_tocar_combate("dash", roundi(lerpf(float(seg[0]), float(seg[1]), clampf(t_estado / dash_duracao, 0, 1))))
		"especial":
			_tocar_combate("special", _quadro_seg(d6.especial, especial_ativo, especial_total))
		"ferido":
			_tocar_combate("hit", _quadro_seg(d6.dano, 0.06, ferido_duracao))
		"morto":
			_tocar_combate("hit", int(d6.dano[2]))
			sprite.modulate = Color(0.55, 0.5, 0.6)
	if estado == "transformando":
		var k := clampf(t_estado / transformar_duracao, 0.0, 1.0)
		sprite.modulate = Color(1, 1, 1).lerp(Color(2.2, 2.6, 3.0), sin(k * PI))
	elif estado != "morto":
		sprite.modulate = adamantium.TINTA if transformado and String(sprite.animation).begins_with("c_") or transformado and String(sprite.animation).begins_with("x_") else Color.WHITE
	# piscar durante a invulnerabilidade pos-dano (o dash nao pisca)
	if estado != "dash" and estado != "morto" and relogio - ultimo_dano_t < iframes_dano:
		sprite.visible = fmod(relogio, 0.12) < 0.08
	else:
		sprite.visible = true
