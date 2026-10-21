extends Node
## Bolorina 21/10/2026 (arte-mundos, passo 2) — autoload "DecoracaoMundos".
## So decoracao, sem logica de jogo e sem colisao. Observa os nos que entram na arvore e:
##  - cenas listadas em data/decoracao_mundos.json ("cenas"): neons (Warped City), hologramas, luzes,
##    brasas/fumaca e modelos extras (ex.: arredores da Ferraria do Porto, sem tocar no codigo da forja);
##  - masmorras (scripts/dungeon/masmorra.gd) pelo tema ("masmorras"): cristais, pilhas de minerio, lanternas;
##  - pedras de viagem (scripts/mundo/pedra_viagem.gd) e pontos de viagem (ponto_viagem.gd): portal animado.
## Desligar tudo: ILHA_SEM_DECORACAO=1.
const DADOS := "res://data/decoracao_mundos.json"
var dados := {}
var desligada := false
var _tex := {}
var _cenas := {}

func _ready() -> void:
	desligada = OS.get_environment("ILHA_SEM_DECORACAO") == "1"
	var d = JSON.parse_string(FileAccess.get_file_as_string(DADOS)) if FileAccess.file_exists(DADOS) else null
	dados = d if d is Dictionary else {}
	if not desligada:
		get_tree().node_added.connect(_no_entrou)

func _no_entrou(n: Node) -> void:
	var s = n.get_script()
	var caminho := String(s.resource_path) if s != null else ""
	if caminho.ends_with("mundo/pedra_viagem.gd") or caminho.ends_with("mundo/ponto_viagem.gd"):
		_depois(n, _portal)
	elif caminho.ends_with("dungeon/masmorra.gd"):
		_depois(n, _masmorra)
	elif n.scene_file_path != "" and dados.get("cenas", {}).has(n.scene_file_path):
		_depois(n, _cena)

func _depois(n: Node, f: Callable) -> void:
	# espera a cena montar (o _ready dos mapas constroi tudo por codigo)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(n) and n.is_inside_tree() and not n.has_meta("decorado_bolorina"):
		n.set_meta("decorado_bolorina", true)
		f.call(n)

# ------------------------------------------------------------------ utilidades
func textura(caminho: String) -> Texture2D:
	if _tex.has(caminho):
		return _tex[caminho]
	var t: Texture2D = null
	if ResourceLoader.exists(caminho):
		t = load(caminho)
	elif FileAccess.file_exists(caminho):
		t = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(caminho)))
	_tex[caminho] = t
	return t

static func _y(mapa: Node, x: float, z: float) -> float:
	return float(mapa._y(x, z)) if mapa.has_method("_y") else 0.0

func _grupo(pai: Node) -> Node3D:
	var g := pai.get_node_or_null("DecoracaoBolorina") as Node3D
	if g == null:
		g = Node3D.new()
		g.name = "DecoracaoBolorina"
		pai.add_child(g)
	return g

func _luz(g: Node3D, p: Vector3, cor: Color, energia: float, alcance: float, tremula := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.shadow_enabled = false
	l.position = p
	g.add_child(l)
	if tremula:
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "light_energy", energia * 0.75, 0.13)
		tw.tween_property(l, "light_energy", energia * 1.1, 0.09)
		tw.tween_property(l, "light_energy", energia * 0.9, 0.17)
	return l

func _folha_frames(folha: String, n: int, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", true)
	var t := textura(folha)
	if t == null:
		return sf
	var w := t.get_width() / n
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = t
		at.region = Rect2(i * w, 0, w, t.get_height())
		sf.add_frame("default", at)
	return sf

func _lista_frames(quadros: Array, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", true)
	for q in quadros:
		var t := textura(String(q))
		if t:
			sf.add_frame("default", t)
	return sf

func _sprite(g: Node3D, sf: SpriteFrames, p: Vector3, altura: float, cor := Color(1, 1, 1), billboard := true) -> AnimatedSprite3D:
	var a := AnimatedSprite3D.new()
	a.sprite_frames = sf
	var h := 32.0
	if sf.get_frame_count("default") > 0:
		h = float(sf.get_frame_texture("default", 0).get_height())
	a.pixel_size = altura / h
	a.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	a.shaded = false
	a.double_sided = true
	a.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	a.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	a.modulate = cor
	a.centered = true
	a.offset = Vector2(0, h * 0.5)
	a.position = p
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(a)
	a.play("default")
	return a

func _particulas(g: Node3D, p: Vector3, cor: Color, area: Vector3, qtd: int, vel: Vector3, tam: float, vida: float, tex: String, aditivo := true) -> void:
	var ps := CPUParticles3D.new()
	ps.amount = qtd
	ps.lifetime = vida
	ps.preprocess = vida
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = area
	ps.direction = vel.normalized()
	ps.spread = 20.0
	ps.gravity = Vector3.ZERO
	ps.initial_velocity_min = vel.length() * 0.6
	ps.initial_velocity_max = vel.length() * 1.3
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.4
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	rampa.colors = PackedColorArray([Color(cor, 0.0), Color(cor, cor.a), Color(cor, 0.0)])
	ps.color_ramp = rampa
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = textura(tex)
	q.material = m
	ps.mesh = q
	ps.position = p
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(ps)

func _modelo(g: Node3D, caminho: String, p: Vector3, ang: float, escala: float) -> Node3D:
	if not ResourceLoader.exists(caminho):
		push_warning("decoracao: modelo ausente " + caminho)
		return null
	var n: Node3D = load(caminho).instantiate()
	n.position = p
	n.rotation_degrees.y = ang
	n.scale = Vector3.ONE * escala
	g.add_child(n)
	return n

func _holograma(g: Node3D, p: Vector3, tam: Vector2, cor: Color, texto: String, gira: bool) -> void:
	var raiz := Node3D.new()
	raiz.position = p
	g.add_child(raiz)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = tam
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/mirante/holograma.gdshader")
	m.set_shader_parameter("cor", cor)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(mi)
	var lb := Label3D.new()
	lb.text = texto
	lb.font_size = 64
	lb.pixel_size = 0.006
	lb.modulate = Color(cor.r * 1.6, cor.g * 1.6, cor.b * 1.6)
	lb.outline_size = 0
	lb.shaded = false
	lb.double_sided = true
	lb.position = Vector3(0, 0, 0.02)
	raiz.add_child(lb)
	# feixe do projetor ate o chao
	var feixe := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.05
	cil.bottom_radius = tam.x * 0.35
	cil.height = p.y - _y(g.get_parent(), p.x, p.z)
	feixe.mesh = cil
	var mf := ShaderMaterial.new()
	mf.shader = m.shader
	mf.set_shader_parameter("cor", cor)
	mf.set_shader_parameter("forca", 0.25)
	feixe.material_override = mf
	feixe.position = Vector3(0, -cil.height * 0.5 - tam.y * 0.5, 0)
	feixe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(feixe)
	_luz(g, p - Vector3(0, 1.0, 0), cor, 1.6, 7.0)
	if gira:
		var tw := raiz.create_tween().set_loops()
		tw.tween_property(raiz, "rotation:y", TAU, 14.0).from(0.0)
	var flut := mi.create_tween().set_loops()
	flut.tween_property(mi, "position:y", 0.12, 1.6).set_trans(Tween.TRANS_SINE)
	flut.tween_property(mi, "position:y", -0.12, 1.6).set_trans(Tween.TRANS_SINE)

# ------------------------------------------------------------------ cenas (mapas)
func _cena(mapa: Node) -> void:
	var g := _grupo(mapa)
	for it in dados.cenas.get(mapa.scene_file_path, []):
		var xz: Array = it.get("pos", [0, 0])
		var x := float(xz[0])
		var z := float(xz[1])
		var p := Vector3(x, _y(mapa, x, z) + float(it.get("y", 0.0)), z)
		var cor := Color(String(it.get("cor", it.get("luz", "ffffff"))))
		match String(it.get("tipo", "")):
			"neon":
				var sf := _lista_frames(it.get("quadros", []), float(it.get("fps", 4)))
				_sprite(g, sf, p, float(it.get("altura", 3.0)), Color(1.35, 1.35, 1.35))
				if it.has("luz"):
					_luz(g, p + Vector3(0, float(it.get("altura", 3.0)) * 0.6, 0.6), Color(String(it.luz)), 1.8, 6.0)
			"holograma":
				var tam: Array = it.get("tam", [4, 2])
				_holograma(g, p, Vector2(float(tam[0]), float(tam[1])), cor, String(it.get("texto", "")), bool(it.get("gira", false)))
			"luz":
				_luz(g, p, cor, float(it.get("energia", 1.5)), float(it.get("alcance", 6.0)), bool(it.get("tremula", false)))
			"faiscas":
				var a: Array = it.get("area", [3, 1, 3])
				_particulas(g, p, Color(cor, 0.9), Vector3(float(a[0]), float(a[1]), float(a[2])), 50, Vector3(0, 0.5, 0), 0.25, 4.0, "res://art/vfx/particulas/spark_01.png")
			"brasas":
				var a2: Array = it.get("area", [1, 0.3, 1])
				_particulas(g, p, Color(cor, 1.0), Vector3(float(a2[0]), float(a2[1]), float(a2[2])), 30, Vector3(0.1, 1.4, 0), 0.12, 2.2, "res://art/vfx/particulas/spark_01.png")
			"fumaca":
				_particulas(g, p, Color(cor, 0.55), Vector3(0.4, 0.2, 0.4), 18, Vector3(0.3, 1.0, 0), 2.2, 6.0, "res://art/vfx/particulas/smoke_04.png", false)
			"modelo":
				_modelo(g, String(it.m), p, float(it.get("ang", 0)), float(it.get("escala", 1.0)))

# ------------------------------------------------------------------ portais de viagem
func _portal(n: Node) -> void:
	if not (n is Node3D):
		return
	var cfg: Dictionary = dados.get("portal", {})
	var g := Node3D.new()
	g.name = "PortalBolorina"
	(n as Node3D).add_child(g)
	var sf := _folha_frames(String(cfg.get("folha", "res://art/vfx/portal/portal-32px_strip8.png")), int(cfg.get("quadros", 8)), float(cfg.get("fps", 10)))
	var alt := float(cfg.get("altura", 2.4))
	var spr := _sprite(g, sf, Vector3(0, float(cfg.get("y", 1.5)) - alt * 0.5, 0), alt, Color(1.6, 1.4, 1.9))
	spr.name = "PortalAnimado"
	var cor := Color(String(cfg.get("cor_luz", "b07cff")))
	_luz(g, Vector3(0, float(cfg.get("y", 1.5)), 0.3), cor, 1.6, 5.0)
	_particulas(g, Vector3(0, 0.3, 0), Color(cor.lightened(0.3), 0.9), Vector3(0.5, 0.1, 0.5), 18, Vector3(0, 0.9, 0), 0.16, 2.5, "res://art/vfx/particulas/magic_02.png")

# ------------------------------------------------------------------ masmorras (cristais, minerio, lanternas)
func _masmorra(m: Node) -> void:
	var cfg: Dictionary = dados.get("masmorras", {}).get(String(m.get("tema")), {})
	if cfg.is_empty() or m.get("g") == null:
		return
	var gen = m.g
	var ocupadas: Dictionary = m.get("_ocupadas") if m.get("_ocupadas") is Dictionary else {}
	var celulas: Array = []
	for c in gen.distancia:
		if not ocupadas.has(c) and int(gen.distancia[c]) >= 3:
			celulas.append(c)
	celulas.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.semente) ^ 0x5bd1
	for i in range(celulas.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = celulas[i]; celulas[i] = celulas[j]; celulas[j] = t
	var g := _grupo(m)
	var usados: Array = []
	var pegar := func() -> Variant:
		while not celulas.is_empty():
			var c: Vector2i = celulas.pop_back()
			var ok := true
			for u in usados:
				if absi(u.x - c.x) + absi(u.y - c.y) < 3:
					ok = false
					break
			if ok:
				usados.append(c)
				return c
		return null
	var cores: Array = cfg.get("cores", ["58e0ff"])
	for i in int(cfg.get("cristais", 0)):
		var c = pegar.call()
		if c == null: break
		_cristal(g, gen.mundo(c) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), Color(String(cores[i % cores.size()])), rng, i % 3 == 0)
	var pilhas: Array = cfg.get("modelos_pilha", [])
	for i in int(cfg.get("pilhas", 0)):
		var c = pegar.call()
		if c == null or pilhas.is_empty(): break
		_modelo(g, String(pilhas[rng.randi() % pilhas.size()]), gen.mundo(c), rng.randf_range(0, 360), rng.randf_range(1.3, 1.9))
	for i in int(cfg.get("lanternas", 0)):
		var c = pegar.call()
		if c == null: break
		var p: Vector3 = gen.mundo(c)
		_modelo(g, String(cfg.get("lanterna", "")), p, rng.randf_range(0, 360), 1.6)
		_luz(g, p + Vector3(0, 1.6, 0), Color("ffb070"), 1.4, 6.0, true)
	m.set_meta("decoracao_bolorina", {"cristais": int(cfg.get("cristais", 0)), "celulas": usados.size()})

func _cristal(g: Node3D, p: Vector3, cor: Color, rng: RandomNumberGenerator, com_luz: bool) -> void:
	var raiz := Node3D.new()
	raiz.position = p
	g.add_child(raiz)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor.darkened(0.3)
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.15
	mat.metallic = 0.2
	for k in rng.randi_range(3, 5):
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = rng.randf_range(0.12, 0.28)
		cm.height = rng.randf_range(0.6, 1.6)
		cm.radial_segments = 5
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat
		mi.position = Vector3(rng.randf_range(-0.3, 0.3), cm.height * 0.4, rng.randf_range(-0.3, 0.3))
		mi.rotation_degrees = Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 360), rng.randf_range(-25, 25))
		raiz.add_child(mi)
	if com_luz:
		_luz(g, p + Vector3(0, 0.9, 0), cor, 1.2, 4.5)
