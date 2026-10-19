extends CharacterBody3D
## Orc corpo a corpo: persegue, para a distancia de golpe, PREPARA (telegrafo: anel vermelho no
## chao + brilho vermelho, machado acima da cabeca), GOLPEIA (area em frente), RECUPERA (janela
## de punicao). Golpes leves o atordoam; durante o preparo tem "postura" (super-armadura) que so
## quebra com dano acumulado ou golpe pesado (finalizador do combo / especial).
const Folhas = preload("res://scripts/combate/folhas.gd")
signal ataque(inimigo, centro: Vector3, raio: float, dano: int)
signal morto(inimigo)
const PASTA := "res://art/combate/orc/"
const ANIMS := {"idle": 8.0, "run": 14.0, "windup": 0.0, "strike": 0.0, "recover": 0.0, "hurt": 0.0, "death": 0.0}

var hp_max := 60
var hp := 60
var dano := 14
var velocidade := 3.1
var alcance_ataque := 2.2
var raio_golpe := 1.45
var distancia_golpe := 1.25
var preparo := 0.8
var golpe_dur := 0.28
var recuperacao := 0.8
var postura_max := 22.0
var escala := 1.0
var bruto := false

var estado := "surgindo"   # surgindo | perseguir | preparo | golpe | recuperacao | atordoado | morrendo
var t := 0.0
var postura := 0.0
var alvo: Node3D
var empurrao := Vector3.ZERO
var flash := 0.0
var lado := 1
var dir_ataque := Vector3.RIGHT
var cam_direita := Vector3(0.7071, 0, -0.7071)
var vizinhos: Array = []
var sprite: AnimatedSprite3D
var aviso: MeshInstance3D
var aviso_mat: ShaderMaterial
var sombra: MeshInstance3D
var manifest: Dictionary
var px := 1.72 / 48.0 * 42.0 / 45.0
var golpeou := false
var vivo := true

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = 0.55 * escala
	cil.height = 1.6
	forma.shape = cil
	forma.position.y = 0.8
	add_child(forma)
	manifest = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "manifest.json"))
	sprite = AnimatedSprite3D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for a: String in ANIMS:
		frames.add_animation(a)
		frames.set_animation_speed(a, ANIMS[a])
		frames.set_animation_loop(a, a == "idle" or a == "run")
		var info: Dictionary = manifest.anims[a]
		for tex in Folhas.quadros(PASTA + info.sheet, Vector2i(72, 72), int(info.frames), int(info.frames)):
			frames.add_frame(a, tex)
	sprite.sprite_frames = frames
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.shaded = false
	sprite.pixel_size = px * escala
	var anc: Array = manifest.anchor_feet_px
	sprite.offset = Vector2(36.0 - float(anc[0]), float(anc[1]) - 36.0)
	add_child(sprite)
	sprite.play("idle")
	sombra = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.5, 0.95) * escala
	sombra.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/contact_shadow.gdshader")
	sombra.material_override = sm
	sombra.position.y = 0.03
	add_child(sombra)
	# telegrafo no chao (anel que enche ate o golpe)
	aviso = MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2.ONE * raio_golpe * 2.0
	aviso.mesh = p
	aviso_mat = ShaderMaterial.new()
	aviso_mat.shader = load("res://shaders/cmb_aviso.gdshader")
	aviso.material_override = aviso_mat
	aviso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aviso.top_level = true
	aviso.visible = false
	add_child(aviso)
	if bruto:
		sprite.modulate = Color(1.0, 0.82, 0.78)
	_mudar("surgindo")

func _mudar(novo: String) -> void:
	estado = novo
	t = 0.0
	match novo:
		"perseguir":
			sprite.play("run")
		"preparo":
			sprite.animation = "windup"
			postura = 0.0
			golpeou = false
		"golpe":
			sprite.animation = "strike"
		"recuperacao":
			sprite.animation = "recover"
		"atordoado":
			sprite.animation = "hurt"
		"morrendo":
			sprite.animation = "death"
		"surgindo":
			sprite.play("idle")
	aviso.visible = novo == "preparo" or novo == "golpe"

func alvejavel() -> bool:
	return vivo and estado != "surgindo"

func _physics_process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta)
	velocity = Vector3.ZERO
	var para_alvo := Vector3.ZERO
	var dist := 99.0
	if alvo:
		para_alvo = alvo.global_position - global_position
		para_alvo.y = 0
		dist = para_alvo.length()
	var alvo_vivo: bool = alvo != null and alvo.estado != "morto"
	match estado:
		"surgindo":
			sprite.modulate.a = clampf(t / 0.6, 0, 1)
			if t >= 0.7:
				_mudar("perseguir")
		"perseguir":
			if not alvo_vivo:
				sprite.play("idle")
			elif dist > alcance_ataque:
				var dir := para_alvo / maxf(dist, 0.001)
				for v in vizinhos:
					if v != self and is_instance_valid(v) and v.vivo:
						var fora: Vector3 = global_position - v.global_position
						fora.y = 0
						var dd := fora.length()
						if dd < 1.8 and dd > 0.01:
							dir += fora / dd * (1.8 - dd) * 0.9
				velocity = dir.normalized() * velocidade
				_lado(dir)
			else:
				dir_ataque = para_alvo / maxf(dist, 0.001)
				_lado(dir_ataque)
				_mudar("preparo")
		"preparo":
			# acompanha o jogador no inicio do preparo, depois trava a direcao
			if alvo and t < preparo * 0.45 and dist > 0.01:
				dir_ataque = dir_ataque.slerp(para_alvo / dist, 0.12).normalized()
				_lado(dir_ataque)
			_quadro(t / preparo)
			if t >= preparo:
				_mudar("golpe")
		"golpe":
			if not golpeou:
				golpeou = true
				ataque.emit(self, centro_golpe(), raio_golpe, dano)
			velocity = dir_ataque * 2.0 * (1.0 - t / golpe_dur)
			_quadro(t / golpe_dur)
			if t >= golpe_dur:
				_mudar("recuperacao")
		"recuperacao":
			_quadro(t / recuperacao)
			if t >= recuperacao:
				_mudar("perseguir")
		"atordoado":
			_quadro(t / 0.32)
			if t >= 0.32:
				_mudar("perseguir")
		"morrendo":
			_quadro(t / 1.1)
			if t > 1.1:
				sprite.modulate.a = clampf(1.0 - (t - 1.1) / 0.5, 0, 1)
			if t >= 1.6:
				morto.emit(self)
				queue_free()
	velocity += empurrao
	empurrao = empurrao.move_toward(Vector3.ZERO, 22.0 * delta)
	velocity.y = 0
	move_and_slide()
	position.y = 0
	_visual()

func centro_golpe() -> Vector3:
	return global_position + dir_ataque * distancia_golpe * escala

func _lado(dir: Vector3) -> void:
	var sx := dir.dot(cam_direita)
	if absf(sx) > 0.1:
		lado = 1 if sx > 0 else -1
	sprite.flip_h = lado < 0

func _quadro(f: float) -> void:
	var n := sprite.sprite_frames.get_frame_count(sprite.animation)
	sprite.frame = clampi(int(f * n), 0, n - 1)

func _visual() -> void:
	var base := Color(1.0, 0.82, 0.78) if bruto else Color.WHITE
	base.a = sprite.modulate.a
	if estado == "preparo":
		var pulso := 0.5 + 0.5 * sin(t * 26.0)
		base = Color(1.0 + 0.9 * pulso, 0.55, 0.5, base.a)
	if flash > 0.0:
		base = Color(5.0, 5.0, 5.0, base.a)
	sprite.modulate = base
	if aviso.visible:
		var c := centro_golpe()
		aviso.global_position = Vector3(c.x, 0.05, c.z)
		aviso_mat.set_shader_parameter("progresso", clampf(t / preparo, 0, 1) if estado == "preparo" else 1.0)
		aviso_mat.set_shader_parameter("golpe", 1.0 if estado == "golpe" else 0.0)

func receber_golpe(valor: int, emp: Vector3, pesado: bool) -> bool:
	if not alvejavel():
		return false
	hp -= valor
	flash = 0.09
	if hp <= 0:
		hp = 0
		vivo = false
		empurrao = emp * 1.2
		collision_layer = 0
		collision_mask = 1
		_mudar("morrendo")
		return true
	if estado == "preparo":
		postura += valor
		if pesado or postura >= postura_max:
			empurrao = emp
			_mudar("atordoado")
		else:
			empurrao = emp * 0.25
	elif estado == "golpe":
		empurrao = emp * 0.3
	else:
		empurrao = emp / escala
		_mudar("atordoado")
	return true
