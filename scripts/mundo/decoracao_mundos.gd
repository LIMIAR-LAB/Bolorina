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
	var salas := {}
	if bool(cfg.get("acampamento_orc", false)):
		salas = _acampamento_orc(m, gen, ocupadas, usados, g)
	m.set_meta("decoracao_bolorina", {"cristais": int(cfg.get("cristais", 0)), "celulas": usados.size(), "salas": salas})

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

# ------------------------------------------------------------------ acampamento orc (Minas da Cinza)
## Bolorina 21/10 (passo 4): o andar dos orcs vira acampamento de guerra. Salas por distancia da entrada:
## acampamento (tendas, fogueira, paliçada), jaulas (gaiolas, ossos), sala de guerra (mesa, estandartes,
## armas) e covil do chefe (totens, fogueiras grandes, ossadas). Tudo com RNG proprio (semente do andar),
## sem colisao e fora das celulas ocupadas (trilho, minerio, baus, inimigos), entao o layout e os testes
## do gerador nao mudam.
const PROPS := "res://art/models/"
var _mats := {}

func _mat(cor: String, rug := 0.9, emissao := 0.0) -> StandardMaterial3D:
	var k := "%s_%s_%s" % [cor, rug, emissao]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(cor)
		m.roughness = rug
		if emissao > 0.0:
			m.emission_enabled = true
			m.emission = Color(cor)
			m.emission_energy_multiplier = emissao
		_mats[k] = m
	return _mats[k]

func _mesh(g: Node3D, mesh: Mesh, p: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = p
	mi.rotation = rot
	g.add_child(mi)
	return mi

func _acampamento_orc(m: Node, gen, ocupadas: Dictionary, usados: Array, g: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.semente) ^ 0x0c0a
	_celula_mundo = func(c: Vector2i) -> Vector3: return gen.mundo(c)
	# --- salas: retangulos do gerador, ordenados pela distancia da entrada; sem salas, aglomerados por distancia
	var grupos: Array = []
	for r in gen.salas:
		var cel: Array = []
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				var c := Vector2i(x, y)
				if gen.distancia.has(c): cel.append(c)
		if cel.size() >= 6: grupos.append(cel)
	if grupos.size() < 3:
		grupos.clear()
		var maxd := 1
		for c in gen.distancia: maxd = maxi(maxd, int(gen.distancia[c]))
		for q in [0.12, 0.42, 0.7, 0.95]:
			var alvo := int(maxd * q)
			var ancora := Vector2i(-999, -999)
			for c in gen.distancia:
				if int(gen.distancia[c]) == alvo and gen.cercado(c, 1): ancora = c; break
			if ancora.x == -999: continue
			var cel: Array = []
			for c in gen.distancia:
				if absi(c.x - ancora.x) <= 4 and absi(c.y - ancora.y) <= 4: cel.append(c)
			grupos.append(cel)
	var dist := func(cel: Array) -> float:
		var s := 0.0
		for c in cel: s += float(gen.distancia[c])
		return s / maxf(cel.size(), 1)
	grupos.sort_custom(func(a, b): return dist.call(a) < dist.call(b))
	var papeis: Array = []
	for i in grupos.size():
		var pp := "mista"
		if i == 0: pp = "acampamento"
		elif i == grupos.size() - 1: pp = "chefe" if bool(gen.chefe) else "guerra"
		elif i == grupos.size() / 2: pp = "jaulas"
		elif i == grupos.size() - 2: pp = "guerra"
		papeis.append(pp)
	var livre := func(c: Vector2i) -> bool:
		if ocupadas.has(c) or not gen.distancia.has(c): return false
		for u in usados:
			if absi(u.x - c.x) + absi(u.y - c.y) < 2: return false
		return true
	var resumo := {}
	for i in grupos.size():
		var cel: Array = grupos[i].duplicate()
		cel.sort()
		for k in range(cel.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = cel[k]; cel[k] = cel[j]; cel[j] = t
		var centrais: Array = cel.filter(func(c): return gen.cercado(c, 1))
		var borda: Array = cel.filter(func(c): return not gen.cercado(c, 1))
		var tomar := func(lista: Array) -> Variant:
			while not lista.is_empty():
				var c: Vector2i = lista.pop_back()
				if livre.call(c):
					usados.append(c)
					return c
			return null
		var n := 0
		match papeis[i]:
			"acampamento":
				n += _por(tomar.call(centrais), func(p): _fogueira(g, p, rng, 1.0))
				for k in 3: n += _por(tomar.call(borda), func(p): _tenda(g, p, rng))
				for k in 3: n += _por(tomar.call(borda), func(p): _palicada(g, p, rng, 5))
				n += _por(tomar.call(cel), func(p): _ossada(g, p, rng, 4))
				n += _por(tomar.call(borda), func(p): _tocha(g, p, rng))
				n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/Banner_1.gltf", p, rng.randf_range(0, 360), 0.9))
				n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "kaykit_resource_bits/Wood_Log_Stack.gltf", p, rng.randf_range(0, 360), 1.5))
				n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/WeaponStand.gltf", p, rng.randf_range(0, 360), 0.9))
			"jaulas":
				for k in 3: n += _por(tomar.call(borda if k < 2 else centrais), func(p): _modelo(g, PROPS + "quaternius_props/Cage_Small.gltf", p, rng.randf_range(0, 360), 1.0))
				for k in 3: n += _por(tomar.call(cel), func(p): _ossada(g, p, rng, 5))
				n += _por(tomar.call(borda), func(p): _tocha(g, p, rng))
				n += _por(tomar.call(borda), func(p): _totem(g, p, rng))
				n += _por(tomar.call(borda), func(p): _palicada(g, p, rng, 6))
			"guerra":
				n += _por(tomar.call(centrais), func(p): _modelo(g, PROPS + "quaternius_props/Table_Large.gltf", p, rng.randf_range(0, 360), 0.9))
				for k in 2: n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/Banner_2.gltf", p, rng.randf_range(0, 360), 0.9))
				for k in 2: n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/WeaponStand.gltf", p, rng.randf_range(0, 360), 0.9))
				n += _por(tomar.call(borda), func(p): _totem(g, p, rng))
				n += _por(tomar.call(borda), func(p): _tocha(g, p, rng))
				n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/Shield_Wooden.gltf", p, rng.randf_range(0, 360), 1.0))
				n += _por(tomar.call(centrais), func(p): _fogueira(g, p, rng, 0.8))
			"chefe":
				for k in 2: n += _por(tomar.call(centrais), func(p): _fogueira(g, p, rng, 1.5))
				for k in 3: n += _por(tomar.call(borda), func(p): _totem(g, p, rng))
				for k in 3: n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/Banner_%d.gltf" % (1 + k % 2), p, rng.randf_range(0, 360), 1.05))
				for k in 3: n += _por(tomar.call(cel), func(p): _ossada(g, p, rng, 7))
				n += _por(tomar.call(borda), func(p): _palicada(g, p, rng, 6))
			_:
				n += _por(tomar.call(borda), func(p): _tocha(g, p, rng))
				n += _por(tomar.call(cel), func(p): _ossada(g, p, rng, 4))
				n += _por(tomar.call(borda), func(p): _tenda(g, p, rng))
				n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/Banner_%d.gltf" % (1 + rng.randi() % 2), p, rng.randf_range(0, 360), 0.9))
				if rng.randf() < 0.5:
					n += _por(tomar.call(borda), func(p): _palicada(g, p, rng, 4))
				else:
					n += _por(tomar.call(borda), func(p): _modelo(g, PROPS + "quaternius_props/Barrel.gltf", p, 0.0, 0.9))
		resumo[papeis[i]] = int(resumo.get(papeis[i], 0)) + n
		if not resumo.has("centro_" + papeis[i]):
			var soma := Vector3.ZERO
			for c in grupos[i]: soma += gen.mundo(c)
			resumo["centro_" + papeis[i]] = soma / maxf(grupos[i].size(), 1)
	# --- rochas e estalagmites encostadas nas paredes (quebram os blocos retos)
	var pedras := [PROPS + "kenney_graveyard_kit/rocks-tall.glb", PROPS + "kenney_graveyard_kit/rocks.glb", PROPS + "kenney_survival_kit/rock-a.glb", PROPS + "kenney_survival_kit/rock-b.glb", PROPS + "kenney_survival_kit/rock-c.glb"]
	var beiradas: Array = gen.distancia.keys().filter(func(c): return not gen.cercado(c, 1) and livre.call(c))
	beiradas.sort()
	for k in mini(28, beiradas.size()):
		var c: Vector2i = beiradas[rng.randi() % beiradas.size()]
		if not livre.call(c): continue
		usados.append(c)
		var o := _modelo(g, String(pedras[rng.randi() % pedras.size()]), gen.mundo(c) + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), rng.randf_range(0, 360), rng.randf_range(1.2, 2.2))
		if o:
			o.scale.y *= rng.randf_range(1.0, 1.8)
			var rocha := _mat(["3a2c24", "33261f", "42322a"][k % 3], 1.0)
			for mi: MeshInstance3D in o.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = rocha
	# --- chao de lama/terra com manchas e brasas no ar por todo o andar
	var lama := _mat("2a1a10", 1.0)
	lama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var todas: Array = gen.distancia.keys()
	todas.sort()
	for k in mini(36, todas.size()):
		var c: Vector2i = todas[rng.randi() % todas.size()]
		var d := CylinderMesh.new()
		d.top_radius = rng.randf_range(0.6, 1.4)
		d.bottom_radius = d.top_radius
		d.height = 0.01
		d.radial_segments = 9
		var mm := lama.duplicate() as StandardMaterial3D
		mm.albedo_color = Color(0.16 + rng.randf() * 0.06, 0.1 + rng.randf() * 0.04, 0.06, rng.randf_range(0.35, 0.6))
		var mi := _mesh(g, d, gen.mundo(c) + Vector3(rng.randf_range(-0.6, 0.6), 0.015 + k * 0.0004, rng.randf_range(-0.6, 0.6)), mm, Vector3(0, rng.randf() * TAU, 0))
		mi.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cx := 0.0
	var cz := 0.0
	for c in todas:
		var p: Vector3 = gen.mundo(c); cx += p.x; cz += p.z
	cx /= maxf(todas.size(), 1); cz /= maxf(todas.size(), 1)
	var ext := float(maxi(gen.w, gen.h)) * 1.0
	_particulas(g, Vector3(cx, 0.6, cz), Color(1.0, 0.55, 0.2, 0.9), Vector3(ext, 0.3, ext), 90, Vector3(0.15, 0.7, 0.05), 0.07, 6.0, "res://art/vfx/particulas/spark_01.png")
	_particulas(g, Vector3(cx, 0.4, cz), Color(0.55, 0.42, 0.36, 0.25), Vector3(ext, 0.2, ext), 40, Vector3(0.2, 0.05, 0.1), 2.6, 9.0, "res://art/vfx/particulas/smoke_04.png", false)
	return resumo

func _por(c, f: Callable) -> int:
	if c == null: return 0
	var gen_mundo: Vector3 = _celula_mundo.call(c)
	f.call(gen_mundo)
	return 1

var _celula_mundo: Callable

func _fogueira(g: Node3D, p: Vector3, rng: RandomNumberGenerator, tam: float) -> void:
	var tora := CylinderMesh.new()
	tora.top_radius = 0.09 * tam; tora.bottom_radius = 0.11 * tam; tora.height = 0.9 * tam
	for k in 5:
		var a := k * TAU / 5.0 + rng.randf() * 0.3
		_mesh(g, tora, p + Vector3(cos(a) * 0.22 * tam, 0.12, sin(a) * 0.22 * tam), _mat("4a2c18"), Vector3(PI / 2 - 0.35, -a, 0))
	var pedra := SphereMesh.new()
	pedra.radius = 0.16 * tam; pedra.height = 0.22 * tam
	for k in 9:
		var a := k * TAU / 9.0
		_mesh(g, pedra, p + Vector3(cos(a) * 0.62 * tam, 0.05, sin(a) * 0.62 * tam), _mat("4c4440"))
	var brasa := CylinderMesh.new()
	brasa.top_radius = 0.3 * tam; brasa.bottom_radius = 0.34 * tam; brasa.height = 0.06
	_mesh(g, brasa, p + Vector3(0, 0.04, 0), _mat("ff5a10", 0.6, 3.0))
	_particulas(g, p + Vector3(0, 0.45 * tam, 0), Color(1.0, 0.6, 0.2, 1.0), Vector3(0.18, 0.1, 0.18) * tam, 26, Vector3(0, 1.4, 0), 0.5 * tam, 0.7, "res://art/vfx/particulas/magic_02.png")
	_particulas(g, p + Vector3(0, 0.6 * tam, 0), Color(1.0, 0.75, 0.3, 1.0), Vector3(0.2, 0.1, 0.2) * tam, 14, Vector3(0.1, 1.8, 0), 0.06, 1.8, "res://art/vfx/particulas/spark_01.png")
	_particulas(g, p + Vector3(0, 1.4 * tam, 0), Color(0.25, 0.2, 0.2, 0.35), Vector3(0.2, 0.1, 0.2), 10, Vector3(0.15, 0.9, 0), 1.2 * tam, 3.5, "res://art/vfx/particulas/smoke_04.png", false)
	_luz(g, p + Vector3(0, 1.0, 0), Color("ff8a3a"), 2.2 * tam, 7.0 * tam, true)

func _tenda(g: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var raiz := Node3D.new()
	raiz.position = p
	raiz.rotation.y = rng.randf() * TAU
	g.add_child(raiz)
	var lona := PrismMesh.new()
	lona.size = Vector3(1.9, 1.5, 2.2)
	var cor: String = ["4a3424", "3e2a1e", "553222"][rng.randi() % 3]
	_mesh(raiz, lona, Vector3(0, 0.75, 0), _mat(cor, 1.0))
	var porta := PrismMesh.new()
	porta.size = Vector3(0.7, 0.9, 0.02)
	_mesh(raiz, porta, Vector3(0, 0.45, 1.11), _mat("1a100a"))
	var vara := CylinderMesh.new()
	vara.top_radius = 0.04; vara.bottom_radius = 0.05; vara.height = 2.1
	for z in [-1.1, 1.1]:
		_mesh(raiz, vara, Vector3(0, 0.95, z), _mat("3a2414"))
	var faixa := BoxMesh.new()
	faixa.size = Vector3(0.05, 0.5, 0.35)
	_mesh(raiz, faixa, Vector3(0, 1.75, 1.15), _mat("8a1a12"))   # flamula vermelha do cla
	var cranio := _modelo(raiz, PROPS + "kaykit_halloween_bits/skull.gltf", Vector3(0, 2.0, 1.12), 0.0, 0.5)
	if cranio: _tingir_osso(cranio)

func _palicada(g: Node3D, p: Vector3, rng: RandomNumberGenerator, n: int) -> void:
	var raiz := Node3D.new()
	raiz.position = p
	raiz.rotation.y = rng.randf() * TAU
	g.add_child(raiz)
	var estaca := CylinderMesh.new()
	estaca.top_radius = 0.11; estaca.bottom_radius = 0.13; estaca.height = 1.6
	estaca.radial_segments = 7
	var ponta := CylinderMesh.new()
	ponta.top_radius = 0.0; ponta.bottom_radius = 0.11; ponta.height = 0.35; ponta.radial_segments = 7
	for k in n:
		var x := (k - (n - 1) * 0.5) * 0.27
		var h := rng.randf_range(0.85, 1.15)
		var mi := _mesh(raiz, estaca, Vector3(x, 0.8 * h, rng.randf_range(-0.05, 0.05)), _mat(["5a3a22", "4e321e", "634228"][k % 3]), Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)))
		mi.scale.y = h
		_mesh(raiz, ponta, Vector3(x, 1.6 * h + 0.17, 0), _mat("6e4c30"))
	var amarra := BoxMesh.new()
	amarra.size = Vector3(n * 0.27, 0.08, 0.3)
	_mesh(raiz, amarra, Vector3(0, 0.95, 0), _mat("2e2016"))

func _ossada(g: Node3D, p: Vector3, rng: RandomNumberGenerator, n: int) -> void:
	for k in n:
		var nome: String = ["bone_A", "bone_B", "bone_C", "bone_A", "skull"][rng.randi() % 5]
		var o := _modelo(g, PROPS + "kaykit_halloween_bits/%s.gltf" % nome, p + Vector3(rng.randf_range(-0.5, 0.5), 0.02 + k * 0.03, rng.randf_range(-0.5, 0.5)), rng.randf_range(0, 360), rng.randf_range(0.7, 1.0))
		if o:
			o.rotation_degrees.x = rng.randf_range(-20, 20)
			_tingir_osso(o)

func _tingir_osso(o: Node3D) -> void:
	# ossos e cranios em marfim sujo (o branco puro do kit estourava na luz da fogueira)
	for mi: MeshInstance3D in o.find_children("*", "MeshInstance3D", true, false):
		var base := mi.get_active_material(0)
		if base is StandardMaterial3D:
			var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.albedo_color = Color(0.62, 0.55, 0.45)
			mi.material_override = m

func _totem(g: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	var t := _modelo(g, PROPS + "kaykit_halloween_bits/post_skull.gltf", p, rng.randf_range(0, 360), 1.5)
	if t: _tingir_osso(t)
	var faixa := BoxMesh.new()
	faixa.size = Vector3(0.06, 0.9, 0.4)
	_mesh(g, faixa, p + Vector3(0.2, 1.3, 0), _mat("8a1a12"), Vector3(0, rng.randf() * TAU, 0.1))
	_luz(g, p + Vector3(0, 1.9, 0), Color("ff6a2a"), 0.8, 3.5, true)

func _tocha(g: Node3D, p: Vector3, rng: RandomNumberGenerator) -> void:
	_modelo(g, PROPS + "kaykit_dungeon/torch_lit.gltf", p, rng.randf_range(0, 360), 1.4)
	_particulas(g, p + Vector3(0, 1.5, 0), Color(1.0, 0.6, 0.2, 1.0), Vector3(0.05, 0.05, 0.05), 10, Vector3(0, 1.0, 0), 0.25, 0.5, "res://art/vfx/particulas/magic_02.png")
	_luz(g, p + Vector3(0, 1.6, 0), Color("ff9a40"), 1.5, 6.0, true)
