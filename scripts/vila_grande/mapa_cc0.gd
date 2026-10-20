extends Node3D
## Mapa autonomo montado a partir de um layout JSON (Vila Grande / Porto Velho, Vila dos Orcs,
## Cidade Fantasma). Nao depende da Vale, do equipamento nem do combate: usa um marcador de
## jogador provisorio (capsula) e Marker3D para spawn e NPCs (grupo "npc_marcador").
## Controles: WASD/setas movem | roda do mouse = zoom | Tab = visao geral | F12 = captura.
## Capturas automaticas: VG_CAPTURA=/pasta/saida godot --path . res://scenes/.../x.tscn
const VisualWorld = preload("res://scripts/visual_world.gd")
const Atmosphere = preload("res://scripts/visual_atmosphere.gd")
const Mundo = preload("res://scripts/vila_grande/mundo_cc0.gd")
const Construtor = preload("res://scripts/vila_grande/construtor_quaternius.gd")
const Estruturas = preload("res://scripts/vila_grande/estruturas.gd")
const Interacao = preload("res://scripts/dialogos/interacao_npcs.gd")
const CAMERA_OFFSET := Vector3(24, 24, 24)   # igual a scripts/island.gd (yaw 45)
const TAM_CAMERA := 21.5

@export_file("*.json") var layout := "res://scripts/vila_grande/vila_grande_layout.json"

var data: Dictionary
var tema: Dictionary
var ground: Node3D            # exigido por visual_atmosphere.gd
var art_world                  # VisualWorld (materiais)
var vila                       # mundo_cc0.gd
var construtor
var estruturas
var atmosphere
var camera: Camera3D
var jogador: CharacterBody3D
var marcadores: Node3D
## Gerente de conversas (no "Dialogos" da cena, script interacao_npcs.gd). E conversa com o morador mais perto.
var dialogos: Node
## true enquanto uma conversa esta aberta: o InteracaoNpcs liga isto e a jogadora para de andar.
var demo_mode := false
var npcs: Array = []
var zoom := 1.0
var visao_geral := false
var _cache := {}
var _tintas := {}
var rng := RandomNumberGenerator.new()
var stats := {"edificios": 0, "casas_kit": 0, "arvores": 0, "modelos": 0, "pecas_kit": 0, "marcadores": 0}

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	rng.seed = 909
	data = JSON.parse_string(FileAccess.get_file_as_string(layout))
	tema = data.get("tema", {})
	name = String(data.get("nome_no", name))
	ground = Node3D.new()
	ground.name = "Mundo"
	add_child(ground)
	art_world = VisualWorld.new()
	art_world.parent = ground
	art_world.rng.seed = 77
	art_world._make_materials()
	# mesma afinacao de cor da vila V7 (fidelity_village.gd) + ajustes do tema
	art_world.materials.grey_roof_tiles.albedo_color = Color("3d4656")
	art_world.materials.brown_planks_03.albedo_color = Color("9a7650")
	art_world.materials.plastered_stone_wall.albedo_color = Color("d9bf93")
	art_world.materials.castle_brick_01.albedo_color = Color("8d8a80")
	art_world.materials.glow.emission = Color("ff9f32")
	vila = Mundo.new()
	vila.tema = tema
	vila.fundo_vila = false
	vila.build(art_world, ground, layout, 5)
	for k in tema.get("materiais", {}):
		if art_world.materials.has(k):
			art_world.materials[k].albedo_color = Color(String(tema.materiais[k]))
	stats.pecas_kit = vila.lista_pecas.size()
	for p in vila.lista_pecas:
		if String(p.get_meta("modulo", "")) == "casa":
			stats.casas_kit += 1
			p.add_to_group("navegavel")
		if String(p.get_meta("modulo", "")).begins_with("arvore"):
			stats.arvores += 1
	construtor = Construtor.new(art_world)
	estruturas = Estruturas.new(art_world, vila.kit)
	_edificios()
	_casas_queimadas()
	_modelos()
	_especiais()
	_lagos()
	_borda_da_ilha()
	_fundo()
	_marcadores()
	atmosphere = Atmosphere.new()
	atmosphere.install(self)
	atmosphere.transition_active = false
	atmosphere.set_hour(float(tema.get("hora", 17.2)))
	# os raios de sol estilizados foram pensados para a vila pequena; num mapa grande
	# eles projetam faixas de sombra compridas, então são removidos (como na reference_village)
	for shaft in atmosphere.shafts:
		shaft.queue_free()
	atmosphere.shafts.clear()
	_aplicar_clima()
	_jogador_e_camera()
	_ligar_dialogos()
	print("[mapa_cc0] %s montado em %d ms | %s" % [name, Time.get_ticks_msec()-t0, JSON.stringify(stats)])
	if OS.get_environment("VG_CAPTURA") != "":
		_capturas(OS.get_environment("VG_CAPTURA"))

# ------------------------------------------------------------------ utilidades
func _y(x: float, z: float) -> float:
	return vila.altura(x, z)

func _carregar(caminho: String) -> PackedScene:
	if not _cache.has(caminho):
		_cache[caminho] = load("res://art/models/" + caminho)
	return _cache[caminho]

## multiplica a cor-base de todos os materiais do no (cache por material + tinta)
func _tingir(no: Node, mult: Color, rough := -1.0) -> void:
	for m: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var orig = m.get_active_material(s)
			if not (orig is BaseMaterial3D):
				continue
			var key := str(orig.get_instance_id()) + mult.to_html() + str(rough)
			if not _tintas.has(key):
				var nm: BaseMaterial3D = orig.duplicate()
				nm.albedo_color = nm.albedo_color * mult
				if rough >= 0.0:
					nm.roughness = rough
				_tintas[key] = nm
			m.set_surface_override_material(s, _tintas[key])

func _colisao_cilindro(pai: Node3D, raio: float, altura: float) -> void:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = raio
	s.height = altura
	c.shape = s
	b.position.y = altura*0.5
	b.add_child(c)
	pai.add_child(b)

func _colisao_caixa(pai: Node3D, tam: Vector3) -> void:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tam
	c.shape = s
	b.position.y = tam.y*0.5
	b.add_child(c)
	pai.add_child(b)

func _grupo(nome: String) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	ground.add_child(n)
	return n

# ------------------------------------------------------------------ construcoes
func _edificios() -> void:
	var g := _grupo("Construcoes")
	for e in data.get("edificios", []):
		var b: Node3D = construtor.construir(e)
		var p: Array = e.pos
		b.position = Vector3(float(p[0]), float(e.get("y", _y(float(p[0]), float(p[1])))), float(p[1]))
		b.rotation.y = deg_to_rad(float(e.get("ang", 0.0)))
		b.set_meta("rotulo", String(e.get("rotulo", "")))
		b.add_to_group("navegavel")
		g.add_child(b)
		if e.has("tinta"):
			_tingir(b, Color(String(e.tinta)))
		if e.has("rotulo") and not bool(data.get("sem_placas", false)):
			_placa(g, b.position + Vector3(0, 0, 0).rotated(Vector3.UP, b.rotation.y), String(e.rotulo), e)
		stats.edificios += 1

func _placa(g: Node3D, base: Vector3, texto: String, e: Dictionary) -> void:
	# placa pendurada na fachada (texto 3D, legivel na camera isometrica)
	var D := float(e.get("profundidade", 6))
	var W := float(e.get("largura", 6))
	var ang := deg_to_rad(float(e.get("ang", 0.0)))
	var local := Vector3(W*0.5 - 0.4, 2.6, D*0.5 + 0.55)
	var p := base + local.rotated(Vector3.UP, ang)
	var suporte := Node3D.new()
	suporte.name = "Placa_" + texto.replace(" ", "_")
	suporte.position = p
	suporte.rotation.y = ang
	g.add_child(suporte)
	art_world.box(Vector3(0, 0.45, -0.3), Vector3(0.08, 0.08, 0.7), "iron", false, suporte)
	art_world.box(Vector3(0, 0, -0.05), Vector3(2.6, 0.6, 0.08), "brown_planks_03", false, suporte)
	var l := Label3D.new()
	l.text = texto
	l.font_size = 48
	l.pixel_size = 0.0075
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.outline_size = 8
	l.modulate = Color("f3e2b8")
	l.outline_modulate = Color("2a1d12")
	l.position = Vector3(0, 0, 0.06)
	suporte.add_child(l)

func _casas_queimadas() -> void:
	# casas do kit (visual_world._house) em versao "esqueleto" queimado para a Cidade Fantasma
	var lista: Array = data.get("casas_queimadas", [])
	if lista.is_empty():
		return
	var g := _grupo("CasasQueimadas")
	var old = art_world.parent
	for c in lista:
		var holder := Node3D.new()
		holder.name = "CasaQueimada"
		var p: Array = c.pos
		holder.position = Vector3(float(p[0]), _y(float(p[0]), float(p[1])), float(p[1]))
		holder.rotation.y = deg_to_rad(float(c.get("ang", 0)))
		holder.scale = Vector3.ONE*float(c.get("escala", 1.0))
		g.add_child(holder)
		art_world.parent = holder
		art_world._house(Vector3.ZERO, true, 1.0)
		art_world.parent = old
		# vigas tombadas e telhado desabado
		for k in 5:
			art_world._beam(Vector3(rng.randf_range(-2.5,2.5),0.1,rng.randf_range(-2,2)), Vector3(rng.randf_range(-2.5,2.5),rng.randf_range(0.5,3.2),rng.randf_range(-2,2)), 0.16, "wood", holder)
		var t = art_world.box(Vector3(rng.randf_range(-1,1),1.2,0.5), Vector3(4.5,0.14,2.4), "grey_roof_tiles", false, holder)
		t.rotation = Vector3(rng.randf_range(0.3,0.7), rng.randf_range(-0.3,0.3), rng.randf_range(-0.3,0.3))
		_tingir(holder, Color(String(tema.get("tinta_queimado", "4a4448"))))
		holder.add_to_group("navegavel")
		stats.casas_kit += 1

func _modelos() -> void:
	var g := _grupo("ModelosCC0")
	var tinta_geral := Color(String(tema.get("tinta_modelos", "ffffff")))
	for m in data.get("modelos", []):
		var cena := _carregar(String(m.m))
		if cena == null:
			push_warning("Modelo ausente: " + String(m.m))
			continue
		var n: Node3D = cena.instantiate()
		var p: Array = m.pos
		var y := float(m.y) if m.has("y") else _y(float(p[0]), float(p[1]))
		n.position = Vector3(float(p[0]), y + float(m.get("dy", 0.0)), float(p[1]))
		n.rotation.y = deg_to_rad(float(m.get("ang", 0.0)))
		n.scale = Vector3.ONE*float(m.get("escala", 1.0))
		g.add_child(n)
		var tinta := tinta_geral
		if m.has("tinta"):
			tinta = Color(String(m.tinta))
		if tinta != Color.WHITE:
			_tingir(n, tinta)
		match String(m.get("col", "")):
			"tronco":
				_colisao_cilindro(n, 0.35, 3.0)
			"caixa":
				_colisao_caixa(n, Vector3(float(m.get("cx", 1.0)), float(m.get("cy", 1.0)), float(m.get("cz", 1.0))))
			"rocha":
				_colisao_cilindro(n, 0.9, 1.5)
		if String(m.get("cat", "")) == "arvore":
			stats.arvores += 1
		stats.modelos += 1

func _especiais() -> void:
	var g := _grupo("EstruturasEspeciais")
	for e in data.get("especiais", []):
		var n := Node3D.new()
		n.name = String(e.get("nome", e.tipo))
		var p: Array = e.pos
		n.position = Vector3(float(p[0]), float(e.y) if e.has("y") else _y(float(p[0]), float(p[1])), float(p[1]))
		n.rotation.y = deg_to_rad(float(e.get("ang", 0.0)))
		g.add_child(n)
		match String(e.tipo):
			"torre_arquimago": estruturas.torre_arquimago(n)
			"quadro_missoes": estruturas.quadro_missoes(n)
			"doca":
				estruturas.doca(n, float(e.get("comprimento", 16)), float(e.get("largura", 7)))
			"dirigivel": estruturas.dirigivel(n)
			"palicada":
				n.position = Vector3.ZERO
				estruturas.palicada(n, Vector2(float(p[0]), float(p[1])), float(e.raio), e.get("portoes", []))
			"totem": estruturas.totem(n, Vector3.ZERO, float(e.get("altura", 4.0)))
			"fogueira": estruturas.fogueira(n, Vector3.ZERO, float(e.get("escala", 1.0)))
			"cabana_orc": estruturas.cabana_orc(n, float(e.get("raio", 2.6)), float(e.get("altura", 2.2)))
			"salao_guerra": estruturas.salao_guerra(n, float(e.get("largura", 9)), float(e.get("comprimento", 15)))
			"torre_vigia": estruturas.torre_vigia(n, Vector3.ZERO)
			"capela_ruina": estruturas.capela_ruina(n)
			"lapide": estruturas.lapide(n, Vector3.ZERO, int(e.get("variante", 0)))
			"lanterna_espectral": estruturas.lanterna_espectral(n, Vector3.ZERO)
		if e.has("tinta"):
			_tingir(n, Color(String(e.tinta)))
		if e.has("rotulo"):
			_placa_livre(n, String(e.rotulo), float(e.get("altura_placa", 3.2)))

func _placa_livre(n: Node3D, texto: String, h: float) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 48
	l.pixel_size = 0.009
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("f3e2b8")
	l.outline_modulate = Color("2a1d12")
	l.position = Vector3(0, h, 0)
	l.name = "Rotulo"
	n.add_child(l)

func _lagos() -> void:
	for lg in data.get("lagos", []):
		var m := MeshInstance3D.new()
		m.name = "Lago"
		var c := CylinderMesh.new()
		var r := float(lg.raio)
		c.top_radius = r
		c.bottom_radius = r
		c.height = 0.02
		c.radial_segments = 32
		m.mesh = c
		m.material_override = vila.agua_mat
		var p: Array = lg.centro
		m.position = Vector3(float(p[0]), float(lg.get("nivel", -0.45)), float(p[1]))
		m.scale = Vector3(1, 1, float(lg.get("achatamento", 0.8)))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ground.add_child(m)

# ------------------------------------------------------------------ ilha flutuante
func _borda_da_ilha() -> void:
	# Base rochosa conica sob a ilha (a partir do poligono "borda" gerado pelo layout).
	var borda: Array = data.get("borda", [])
	if borda.size() < 3:
		return
	var aneis := [[0.995, -0.6], [0.99, -6.0], [0.97, -16.0], [0.9, -26.0], [0.72, -36.0], [0.48, -46.0], [0.22, -56.0]]
	var centro := Vector2.ZERO
	for p in borda:
		centro += Vector2(float(p[0]), float(p[1]))
	centro /= borda.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r2 := RandomNumberGenerator.new()
	r2.seed = 31
	var pts: Array = []
	for a in aneis:
		var ring: Array = []
		for p in borda:
			var v := Vector2(float(p[0]), float(p[1])) - centro
			var j := 1.0 if a[1] > -1.0 else r2.randf_range(0.95, 1.0)
			var q: Vector2 = centro + v*float(a[0])*j
			ring.append(Vector3(q.x, float(a[1]) + (0.0 if a[1] > -1.0 else r2.randf_range(-2.0, 2.0)), q.y))
		pts.append(ring)
	var nb := borda.size()
	for k in pts.size()-1:
		for i in nb:
			var a: Vector3 = pts[k][i]
			var b: Vector3 = pts[k][(i+1)%nb]
			var c: Vector3 = pts[k+1][i]
			var d: Vector3 = pts[k+1][(i+1)%nb]
			for v in [a, c, b, b, c, d]:
				st.add_vertex(v)
	var ponta := Vector3(centro.x, -66.0, centro.y)
	var last: Array = pts[pts.size()-1]
	for i in nb:
		for v in [last[i], ponta, last[(i+1)%nb]]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "BaseRochosaDaIlha"
	mi.mesh = st.commit()
	var mat: StandardMaterial3D = art_world.materials.lichen_rock.duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3.ONE*0.12
	mat.albedo_color = Color(String(tema.get("rocha_base", "8a7a6a")))
	mi.material_override = mat
	ground.add_child(mi)
	# raizes/pedras penduradas
	for i in 40:
		var p: Array = borda[r2.randi() % nb]
		var q := Vector2(float(p[0]), float(p[1])).lerp(centro, r2.randf_range(0.05, 0.4))
		var pedra: MeshInstance3D = vila.kit.ball(ground, Vector3(q.x, r2.randf_range(-40, -8), q.y), Vector3(r2.randf_range(1.5,4), r2.randf_range(3,8), r2.randf_range(1.5,4)), mat)
		pedra.name = "RochaPendurada"
	# cachoeira caindo da borda no fim do rio
	if data.has("rio"):
		var pr: Array = data.rio.pontos
		var fim := Vector2(float(pr[pr.size()-1][0]), float(pr[pr.size()-1][1]))
		var antes := Vector2(float(pr[pr.size()-2][0]), float(pr[pr.size()-2][1]))
		var dir := (fim - antes).normalized()
		var q := QuadMesh.new()
		q.size = Vector2(float(data.rio.largura)+0.6, 34.0)
		var queda := MeshInstance3D.new()
		queda.name = "CachoeiraDaBorda"
		queda.mesh = q
		queda.material_override = vila.cachoeira_mat if vila.cachoeira_mat else _mat_cachoeira()
		var pos := Vector3(fim.x + dir.x*0.6, -17.0, fim.y + dir.y*0.6)
		queda.transform = Transform3D(Basis.IDENTITY, pos).looking_at(pos + Vector3(dir.x, 0, dir.y), Vector3.UP)
		queda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ground.add_child(queda)

func _mat_cachoeira() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode cull_disabled;\nvoid fragment(){ float s=sin(UV.x*90.0+sin(UV.x*13.0)*3.0)*0.5+0.5; float f=fract(UV.y*6.0-TIME*1.6+s*0.3); float streak=smoothstep(0.55,1.0,s)*smoothstep(0.2,0.9,f); vec3 c=mix(vec3(0.10,0.24,0.27),vec3(0.82,0.88,0.86),streak*0.8); ALBEDO=c; ROUGHNESS=0.2; ALPHA=smoothstep(0.0,0.08,UV.x)*smoothstep(1.0,0.92,UV.x)*smoothstep(1.0,0.6,UV.y); EMISSION=c*0.08; }"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _fundo() -> void:
	var g := _grupo("FundoDoCeu")
	# ilhas distantes (mesmo gerador do visual_world)
	var old = art_world.parent
	art_world.parent = g
	for ilha in data.get("ilhas_distantes", []):
		var p := Vector3(float(ilha[0]), float(ilha[1]), float(ilha[2]))
		art_world._distant_island(p)
		if ilha.size() > 3 and bool(ilha[3]):
			art_world._tower(p + Vector3(0, 11, 0), 1.3)
	art_world.parent = old
	# ilhas distantes nao projetam sombra na vila (sol baixo do fim de tarde)
	for gi: GeometryInstance3D in g.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# mar de nuvens/nevoa no abismo
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	noise.noise = fn
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\nuniform sampler2D ruido : repeat_enable, filter_linear;\nuniform vec4 cor : source_color = vec4(0.48,0.55,0.66,0.6);\nuniform float vel = 0.01;\nvarying vec3 w;\nvoid vertex(){ w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }\nvoid fragment(){ float n=texture(ruido,w.xz*0.008+vec2(TIME*vel,TIME*vel*0.6)).r; vec2 c=UV-0.5; float e=1.0-smoothstep(0.3,0.5,length(c)); ALBEDO=cor.rgb; ALPHA=cor.a*smoothstep(0.3,0.75,n)*e; }"
	var cores: Array = tema.get("nevoa_abismo", ["7d8ea6", "9aa7b8", "b9c0c8"])
	var alturas := [-64.0, -44.0, -28.0]
	for i in 3:
		var q := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(520, 520)
		q.mesh = plane
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("ruido", noise)
		var c := Color(String(cores[i]))
		c.a = [0.95, 0.7, 0.4][i]
		m.set_shader_parameter("cor", c)
		m.set_shader_parameter("vel", 0.004 + i*0.003)
		q.material_override = m
		q.position = Vector3(0, alturas[i], 0)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.name = "NevoaAbismo%d" % i
		g.add_child(q)

# ------------------------------------------------------------------ clima / tema
func _aplicar_clima() -> void:
	var env: Environment = atmosphere.settings
	atmosphere.sun.directional_shadow_max_distance = 140
	if tema.has("sol_elevacao"):
		# mantém a cor dourada da hora, mas com o sol mais alto: sombras de árvores
		# muito compridas viram faixas escuras borradas num mapa grande
		atmosphere.sun.rotation_degrees.x = -float(tema.sol_elevacao)
		atmosphere.sun.light_angular_distance = 0.6
	if tema.has("ambiente"):
		env.ambient_light_color = Color(String(tema.ambiente))
	if tema.has("ambiente_energia"):
		env.ambient_light_energy = float(tema.ambiente_energia)
	if tema.has("sol_cor"):
		atmosphere.sun.light_color = Color(String(tema.sol_cor))
	if tema.has("sol_energia"):
		atmosphere.sun.light_energy = float(tema.sol_energia)
	if tema.has("lua_energia"):
		atmosphere.moon.light_energy = float(tema.lua_energia)
		atmosphere.moon.shadow_enabled = true
	if tema.has("lua_cor"):
		atmosphere.moon.light_color = Color(String(tema.lua_cor))
	if tema.has("ceu"):
		var c: Array = tema.ceu
		atmosphere.sky_colors.sky_top_color = Color(String(c[0]))
		atmosphere.sky_colors.sky_horizon_color = Color(String(c[1]))
		atmosphere.sky_colors.ground_horizon_color = Color(String(c[2]))
		atmosphere.sky_colors.ground_bottom_color = Color(String(c[2])).darkened(0.5)
	if tema.has("nevoa_cor"):
		env.fog_light_color = Color(String(tema.nevoa_cor))
		env.volumetric_fog_albedo = Color(String(tema.nevoa_cor))
	if tema.has("nevoa_densidade"):
		env.fog_density = float(tema.nevoa_densidade)
	if tema.has("nevoa_volumetrica"):
		env.volumetric_fog_density = float(tema.nevoa_volumetrica)
	if tema.has("saturacao"):
		env.adjustment_saturation = float(tema.saturacao)
	if tema.has("brilho_janelas"):
		art_world.materials.glow.emission_energy_multiplier = float(tema.brilho_janelas)
	if tema.has("cor_janelas"):
		art_world.materials.glow.emission = Color(String(tema.cor_janelas))
		art_world.materials.glow.albedo_color = Color(String(tema.cor_janelas))
	for l in get_tree().get_nodes_in_group("night_lights"):
		if tema.has("energia_luzes"):
			l.light_energy = float(tema.energia_luzes)
	for b in atmosphere.beams:
		b.visible = bool(tema.get("raios_sol", true))
	for s in atmosphere.shafts:
		s.visible = bool(tema.get("raios_sol", true))
	# cinzas/poeira caindo (Cidade Fantasma e Vila dos Orcs)
	if tema.has("cinzas"):
		var cz: Dictionary = tema.cinzas
		var p := GPUParticles3D.new()
		p.name = "CinzasCaindo"
		p.amount = int(cz.get("quantidade", 1500))
		p.lifetime = 14.0
		p.preprocess = 14.0
		p.visibility_aabb = AABB(Vector3(-70, -5, -70), Vector3(140, 40, 140))
		p.position = Vector3(0, 18, 0)
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(60, 2, 60)
		pm.direction = Vector3(0.3, -1, 0.15)
		pm.spread = 20
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.4
		pm.gravity = Vector3(0, -0.15, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 0.6
		p.process_material = pm
		var quad := QuadMesh.new()
		quad.size = Vector2(0.07, 0.07)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(String(cz.get("cor", "b9b4c4")))
		mat.albedo_color.a = 0.75
		if cz.has("emissao"):
			mat.emission_enabled = true
			mat.emission = Color(String(cz.get("cor", "ff7a2a")))
			mat.emission_energy_multiplier = float(cz.emissao)
		quad.material = mat
		p.draw_pass_1 = quad
		add_child(p)
	for nv in tema.get("bruma_local", []):
		var f := FogVolume.new()
		f.name = "Bruma"
		f.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		f.size = Vector3(float(nv[2]), float(nv[3]), float(nv[2]))
		f.position = Vector3(float(nv[0]), 1.0, float(nv[1]))
		var fm := FogMaterial.new()
		fm.density = float(nv[4])
		fm.albedo = Color(String(tema.get("nevoa_cor", "a1b4c1")))
		f.material = fm
		add_child(f)

# ------------------------------------------------------------------ marcadores
func _marcadores() -> void:
	marcadores = Node3D.new()
	marcadores.name = "Marcadores"
	add_child(marcadores)
	var lista: Dictionary = data.get("marcadores", {})
	for id in lista:
		var v: Dictionary = lista[id]
		var p: Array = v.pos
		var mk := Marker3D.new()
		mk.name = String(id)
		mk.position = Vector3(float(p[0]), float(v.y) if v.has("y") else _y(float(p[0]), float(p[1])), float(p[1]))
		mk.rotation.y = deg_to_rad(float(v.get("ang", 0.0)))
		mk.set_meta("papel", String(v.get("papel", "")))
		mk.set_meta("descricao", String(v.get("descricao", "")))
		mk.add_to_group("spawn" if String(id).begins_with("spawn") else "npc_marcador")
		marcadores.add_child(mk)
		stats.marcadores += 1

func marcador(id: String) -> Marker3D:
	return marcadores.get_node_or_null(id)

# ------------------------------------------------------------------ conversas
## Liga o gerente de conversas e cria um morador em cada Marker3D cujo nome seja um id do
## registro (scripts/dialogos/npcs_registro.gd). Os marcadores spawn_* sao ignorados.
func _ligar_dialogos() -> void:
	dialogos = get_node_or_null("Dialogos")
	if dialogos == null:
		dialogos = Interacao.new()
		dialogos.name = "Dialogos"
		add_child(dialogos)
	dialogos.jogador = jogador
	dialogos.game = self
	npcs = Interacao.spawn_em_marcadores(marcadores)
	stats["npcs"] = npcs.size()

func npc(id: String) -> Node3D:
	for n in npcs:
		if is_instance_valid(n) and String(n.npc_id) == id:
			return n
	return null

# ------------------------------------------------------------------ jogador / camera
func _jogador_e_camera() -> void:
	jogador = CharacterBody3D.new()
	jogador.name = "JogadorProvisorio"
	jogador.add_to_group("jogador")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.48
	col.shape = cap
	col.position.y = 0.74
	jogador.add_child(col)
	var vis := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.48
	vis.mesh = cm
	vis.position.y = 0.74
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.95, 0.85, 0.55, 0.55)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.material_override = mm
	vis.name = "SubstituirPeloSpriteDaVale"
	jogador.add_child(vis)
	var sp := marcador("spawn_jogador")
	jogador.position = (sp.position if sp else Vector3.ZERO) + Vector3(0, 0.3, 0)
	add_child(jogador)
	camera = Camera3D.new()
	camera.name = "CameraIsometrica"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = TAM_CAMERA
	camera.near = 0.15
	camera.far = 600
	add_child(camera)
	camera.make_current()
	_mirar(jogador.position, TAM_CAMERA)

func _mirar(alvo: Vector3, tam: float) -> void:
	var dist := 1.0 if tam < 60 else 6.0
	camera.size = tam
	camera.global_transform = Transform3D(Basis.IDENTITY, alvo + CAMERA_OFFSET*dist).looking_at(alvo, Vector3.UP)

func _physics_process(delta: float) -> void:
	if jogador == null or OS.get_environment("VG_CAPTURA") != "":
		return
	var inp := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): inp.x -= 1
	if Input.is_physical_key_pressed(KEY_D): inp.x += 1
	if Input.is_physical_key_pressed(KEY_W): inp.y -= 1
	if Input.is_physical_key_pressed(KEY_S): inp.y += 1
	inp = inp.limit_length(1.0)
	if demo_mode:
		inp = Vector2.ZERO   # conversa aberta: a jogadora fica parada
	# eixos da tela projetados no chao (camera em yaw 45)
	var direita := Vector3(1, 0, -1).normalized()
	var baixo := Vector3(1, 0, 1).normalized()
	var v := (direita*inp.x + baixo*inp.y) * 5.0
	jogador.velocity.x = v.x
	jogador.velocity.z = v.z
	jogador.velocity.y = 0.0 if jogador.is_on_floor() else jogador.velocity.y - 18.0*delta
	jogador.move_and_slide()
	if jogador.position.y < -20.0:
		var sp := marcador("spawn_jogador")
		jogador.position = sp.position + Vector3(0, 0.5, 0)
		jogador.velocity = Vector3.ZERO
	var tam := 140.0 if visao_geral else TAM_CAMERA*zoom
	_mirar(Vector3(jogador.position.x, 0, jogador.position.z) if not visao_geral else Vector3.ZERO, tam)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(0.5, zoom*0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(3.0, zoom*1.1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB: visao_geral = not visao_geral
		if event.physical_keycode == KEY_F12:
			get_viewport().get_texture().get_image().save_png("user://captura_%s.png" % name)

# ------------------------------------------------------------------ capturas automaticas
func _capturas(pasta: String) -> void:
	get_window().size = Vector2i(1600, 900)
	jogador.visible = false
	for i in 30:
		await get_tree().process_frame
	for c in data.get("capturas", []):
		var a: Array = c.alvo
		var alvo := Vector3(float(a[0]), _y(float(a[0]), float(a[1])), float(a[1]))
		_mirar(alvo, float(c.get("tamanho", TAM_CAMERA)))
		if float(c.get("tamanho", TAM_CAMERA)) > 60:
			atmosphere.sun.directional_shadow_max_distance = 400
		for i in 12:
			await get_tree().process_frame
		var arq := pasta.path_join("%s_%s.png" % [String(data.get("id", "mapa")), String(c.nome)])
		get_viewport().get_texture().get_image().save_png(arq)
		print("[mapa_cc0] captura: ", arq)
	get_tree().quit()

# ------------------------------------------------------------------ navegacao (opcional)
## Cria um NavigationRegion3D e assa a malha de navegacao a partir dos colisores estaticos
## do grupo "navegavel" (terreno, casas, construcoes, doca). Chamar quando houver NPCs andando:
##   $VilaGrande.assar_navegacao()   (roda em thread; ~alguns segundos)
func assar_navegacao() -> NavigationRegion3D:
	## Cria e assa (de forma síncrona) um NavigationRegion3D a partir dos colisores
	## estáticos do mapa inteiro: terreno, casas, rochas, troncos, muros, paliçadas.
	var reg := NavigationRegion3D.new()
	reg.name = "Navegacao"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 35.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	reg.navigation_mesh = nm
	add_child(reg)
	var fonte := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, fonte, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, fonte)
	reg.navigation_mesh = nm
	return reg
