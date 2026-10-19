extends Node3D
## Forma Adamantium em combate: sprites PixelLab da armadura (experimental_adamantium_v99: idle e
## caminhada em 8 direcoes), asas de pixel art batendo atras/na frente do corpo conforme a vista,
## aura aditiva (particulas + anel, sem luz). Golpes Gamelab sem versao blindada recebem um tom
## de adamantium (TINTA) + a aura. Escala: corpo da armadura (idle 44 px, caminhada 41 px) com a
## mesma altura em tela do Vale (ALTURA_CORPO do jogador).
const ART := "res://art/characters/experimental_adamantium_v99/"
const TINTA := Color(0.78, 0.93, 1.28)
const REF := {"idle": 44.0, "walk": 41.0, "run": 41.0}
const VISTAS_FRENTE := ["north", "north-east", "north-west"]
const VISTAS_LADO := ["east", "west"]
const ESCALA_ASA := 0.58
const COSTAS_PX := 25.0
var j
var ativo := false
var manifest: Dictionary
var pes := {}
var asas := {}
var aura: CPUParticles3D
var anel: MeshInstance3D
var bater := 0.0
var px := 0.0

func setup(jogador) -> void:
	j = jogador
	name = "FormaAdamantium"
	px = float(j.ALTURA_CORPO) / 44.0
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ART + "manifest.json"))
	var frames: SpriteFrames = j.sprite.sprite_frames
	for anim: String in manifest.anims:
		var mov := anim.get_slice("_", 0)
		if mov == "run":
			continue
		var d := anim.substr(mov.length() + 1)
		var nomes := ["a_idle_" + d] if mov == "idle" else ["a_walk_" + d, "a_run_" + d]
		for nome: String in nomes:
			frames.add_animation(nome)
			frames.set_animation_speed(nome, 6.0 if mov == "idle" else (13.0 if nome.begins_with("a_run") else 9.0))
			frames.set_animation_loop(nome, true)
			for f: String in manifest.anims[anim].files:
				frames.add_frame(nome, load(ART + f))
			pes[nome] = manifest.anims[anim].feet
	for lado in ["asa_esquerda", "asa_direita"]:
		var info: Dictionary = manifest.wings[lado]
		var s := Sprite3D.new()
		s.name = "Asa_" + lado
		s.texture = load(ART + String(info.file))
		s.pixel_size = px * ESCALA_ASA
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.alpha_scissor_threshold = 0.3
		s.double_sided = true
		s.shaded = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.top_level = true
		var tam: Array = info.size
		var raiz: Array = info.root
		s.offset = Vector2(float(tam[0]) / 2.0 - float(raiz[0]) - 0.5, float(raiz[1]) + 0.5 - float(tam[1]) / 2.0)
		add_child(s)
		asas[lado] = s
	_aura()
	ativar(false)

func ref(mov: String) -> float:
	return float(REF.get(mov, 44.0))

func pe(nome: String, quadro: int) -> float:
	var arr: Array = pes.get(nome, [46])
	return float(arr[mini(quadro, arr.size() - 1)])

func _aura() -> void:
	aura = CPUParticles3D.new()
	aura.name = "AuraAdamantium"
	aura.amount = 64
	aura.lifetime = 1.1
	aura.local_coords = false
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	aura.emission_ring_axis = Vector3.UP
	aura.emission_ring_radius = 0.55
	aura.emission_ring_inner_radius = 0.32
	aura.emission_ring_height = 0.05
	aura.direction = Vector3.UP
	aura.spread = 14.0
	aura.gravity = Vector3(0, 1.4, 0)
	aura.initial_velocity_min = 0.4
	aura.initial_velocity_max = 0.9
	aura.scale_amount_min = 0.8
	aura.scale_amount_max = 1.5
	var g := Gradient.new()
	g.set_color(0, Color(1.4, 2.6, 3.0, 0.95))
	g.set_color(1, Color(0.2, 0.55, 1.0, 0.0))
	aura.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(px * 2.2, px * 2.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	q.material = m
	aura.mesh = q
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = Vector3(0, 0.05, 0)
	add_child(aura)
	anel = MeshInstance3D.new()
	anel.name = "AnelAdamantium"
	var p := QuadMesh.new()
	p.size = Vector2(1.7, 1.7)
	anel.mesh = p
	anel.rotation.x = -PI / 2
	anel.position.y = 0.05
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/aura_ring.gdshader")
	anel.material_override = am
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anel)

func ativar(on: bool) -> void:
	ativo = on
	visible = on
	aura.emitting = on
	for s in asas.values():
		s.visible = on
	if on:
		aura.restart()
		atualizar(0.0)

func asas_na_frente() -> bool:
	return String(j.dir8) in VISTAS_FRENTE

func _process(delta: float) -> void:
	if ativo:
		atualizar(delta)

func atualizar(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var correndo: bool = j.estado == "livre" and j.mov_mundo().length() > 0.1
	var periodo := 0.55 if correndo else (0.35 if j.estado == "raio" else 1.2)
	bater = fmod(bater + delta / periodo, 1.0)
	var cam := camera.global_basis.orthonormalized()
	var frente := asas_na_frente()
	var lado_v: bool = String(j.dir8) in VISTAS_LADO
	var base: Vector3 = j.global_position + cam.y * COSTAS_PX * px
	var abertura := 0.70 + (0.22 if j.estado == "raio" else 0.14) * sin(TAU * bater)
	var prof := 0.13 if frente else -0.13
	for lado: String in asas:
		var s: Sprite3D = asas[lado]
		var sinal := -1.0 if lado == "asa_esquerda" else 1.0
		var ang := -abertura if lado == "asa_esquerda" else abertura
		var largura := 0.55 if lado_v else 1.0
		var b := cam * Basis(Vector3(0, 0, 1), ang) * Basis.from_scale(Vector3(largura, 1, 1))
		s.global_transform = Transform3D(b, base + cam.x * sinal * 1.5 * px + cam.z * prof)
		s.modulate = j.sprite.modulate if j.sprite.modulate.r < 1.5 else Color.WHITE
		s.visible = ativo and j.sprite.visible
