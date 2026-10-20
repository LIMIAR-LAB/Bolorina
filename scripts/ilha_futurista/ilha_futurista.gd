extends "res://scripts/vila_grande/mapa_cc0.gd"
## Estação Depois-de-Ontem: ilha futurista caída do futuro (PROPOSTA, não é canon).
## Usa a mesma base dos mapas CC0 (terreno, borda flutuante, clima, marcadores, jogador provisório,
## conversas por spawn_em_marcadores) e acrescenta a lista "fut" do layout:
##   modelo, neon, anel_neon, poste_energia, cabo, holo_relogio, holo_placa, holo_lua, anomalia,
##   detrito_flutuante, drone, trilho, forja_nucleo, totem_orc, veio_minerio
## Os nós de minério são Marker3D no grupo "veio_minerio" (metadados vindos de data/forja/materiais.json).
## Layout: tools/ilha_futurista_layout.py -> scripts/ilha_futurista/ilha_futurista_layout.json

const Futuristas = preload("res://scripts/ilha_futurista/npcs_futuristas.gd")
const MATERIAIS_FORJA := "res://data/forja/materiais.json"

var fut_raiz: Node3D
var veios: Node3D
var animados: Array = []      # [{"no", "tipo", ...}]
var glitches: Array = []
var _t := 0.0
var _mats_neon := {}
var _materiais_forja := {}
var navegacao: NavigationRegion3D

func _ready() -> void:
	super._ready()
	_montar_futuro()
	_visuais_npcs()
	_ceu_futurista()
	if OS.get_environment("FUT_SEM_NAV") == "":
		navegacao = assar_navegacao()
	stats["fut"] = fut_raiz.get_child_count()
	stats["veios"] = veios.get_child_count()
	print("[ilha_futurista] ", JSON.stringify(stats))

# ------------------------------------------------------------------ materiais
func neon(hex: String, forca := 3.0, alfa := 1.0) -> StandardMaterial3D:
	var k := hex + str(forca) + str(alfa)
	if not _mats_neon.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.albedo_color.a = alfa
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = forca
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if alfa < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats_neon[k] = m
	return _mats_neon[k]

func _malha(pai: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, esc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi

func _luz(pai: Node3D, pos: Vector3, cor: Color, energia := 1.6, alcance := 7.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.shadow_enabled = false
	pai.add_child(l)
	return l

# ------------------------------------------------------------------ montagem
func _montar_futuro() -> void:
	fut_raiz = _grupo("Futuro")
	veios = Node3D.new()
	veios.name = "VeiosDeMinerio"
	add_child(veios)
	var dm = JSON.parse_string(FileAccess.get_file_as_string(MATERIAIS_FORJA)) if FileAccess.file_exists(MATERIAIS_FORJA) else {}
	if dm is Dictionary:
		for m in dm.get("materiais", []):
			_materiais_forja[String(m.id)] = m
		for zona in dm.get("nos_de_minerio", {}):
			for n in dm.nos_de_minerio[zona]:
				_materiais_forja["no:" + String(n.id)] = n
	for e in data.get("fut", []):
		var p: Array = e.pos
		var base := Vector3(float(p[0]), _y(float(p[0]), float(p[1])), float(p[1]))
		match String(e.tipo):
			"modelo": _fut_modelo(e, base)
			"neon": _fut_neon(e, base)
			"anel_neon": _fut_anel(e, base)
			"poste_energia": _fut_poste(e, base)
			"cabo": _fut_cabo(e, base)
			"holo_relogio": _fut_relogio(e, base)
			"holo_placa": _fut_placa(e, base)
			"holo_lua": _fut_lua(e, base)
			"anomalia": _fut_anomalia(e, base)
			"detrito_flutuante": _fut_detrito(e, base)
			"drone": _fut_drone(e, base)
			"trilho": _fut_trilho(e)
			"forja_nucleo": _fut_forja(e, base)
			"totem_orc":
				var n := Node3D.new()
				n.position = base
				n.name = "TotemDeOutraEpoca"
				fut_raiz.add_child(n)
				estruturas.totem(n, Vector3.ZERO, float(e.get("altura", 3.6)))
				glitches.append({"no": n, "fase": 1.7})
			"veio_minerio": _fut_veio(e, base)

func _fut_modelo(e: Dictionary, base: Vector3) -> void:
	var cena := _carregar(String(e.m))
	if cena == null:
		push_warning("Modelo ausente: " + String(e.m))
		return
	var n: Node3D = cena.instantiate()
	n.name = String(e.m).get_file().get_basename()
	n.position = base + Vector3(0, float(e.get("dy", 0.0)), 0)
	n.rotation.y = deg_to_rad(float(e.get("ang", 0.0)))
	if e.has("inclina"):
		var r: Array = e.inclina
		n.rotation.x = deg_to_rad(float(r[0]))
		n.rotation.z = deg_to_rad(float(r[2]))
	n.scale = Vector3.ONE * float(e.get("escala", 1.0))
	fut_raiz.add_child(n)
	if e.has("tinta") and String(e.tinta) != "ffffff":
		_tingir(n, Color(String(e.tinta)))
	if e.has("col"):
		var c: Array = e.col
		var b := StaticBody3D.new()
		b.name = "Colisao_" + n.name
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(float(c[0]), float(c[1]), float(c[2]))
		cs.shape = bs
		cs.position.y = float(c[1]) * 0.5
		b.add_child(cs)
		b.position = n.position
		b.rotation.y = n.rotation.y
		b.add_to_group("navegavel")
		fut_raiz.add_child(b)
	if e.has("rotulo"):
		_rotulo(n.position + Vector3(0, float(e.get("altura_rotulo", 3.0)), 0), String(e.rotulo), String(e.get("cor_rotulo", "b8f0ff")), 0.009)
	if bool(e.get("glitch", false)):
		glitches.append({"no": n, "fase": n.position.x * 0.37})
	if bool(e.get("emissao_extra", false)):
		_luz(fut_raiz, n.position + Vector3(0, 6.2, 0), Color("ff3df0"), 1.2, 6.0)

func _fut_neon(e: Dictionary, base: Vector3) -> void:
	var a := Vector2(float(e.pos[0]), float(e.pos[1]))
	var b := Vector2(float(e.ate[0]), float(e.ate[1]))
	var L := a.distance_to(b)
	var passos := maxi(1, int(L / 2.0))
	var box := BoxMesh.new()
	box.size = Vector3(float(e.get("largura", 0.14)), 0.05, L / passos + 0.02)
	for k in passos:
		var q := a.lerp(b, (k + 0.5) / passos)
		var y := _y(q.x, q.y) + 0.04
		var mi := _malha(fut_raiz, box, Vector3(q.x, y, q.y), neon(String(e.cor), 2.6))
		mi.rotation.y = atan2(b.x - a.x, b.y - a.y)
		mi.name = "FaixaNeon"

func _fut_anel(e: Dictionary, base: Vector3) -> void:
	var t := TorusMesh.new()
	var r := float(e.get("raio", 12.0))
	t.inner_radius = r - 0.09
	t.outer_radius = r + 0.09
	t.rings = 96
	_malha(fut_raiz, t, base + Vector3(0, 0.05, 0), neon(String(e.cor), 2.6), Vector3.ZERO, Vector3(1, 0.3, 1)).name = "AnelNeonDaPraca"

func _fut_poste(e: Dictionary, base: Vector3) -> void:
	var n := Node3D.new()
	n.name = "PosteDeEnergia"
	n.position = base
	fut_raiz.add_child(n)
	var cena := _carregar("kenney_space_kit/pipe_supportHigh.glb")
	if cena:
		var m: Node3D = cena.instantiate()
		m.scale = Vector3(2.0, 4.0, 2.0)
		n.add_child(m)
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	_malha(n, s, Vector3(0, 4.25, 0), neon(String(e.cor), 4.0))
	_luz(n, Vector3(0, 4.0, 0), Color(String(e.cor)), 1.4, 7.5)
	_colisao_cilindro(n, 0.45, 4.0)

func _fut_cabo(e: Dictionary, base: Vector3) -> void:
	var a := Vector3(float(e.pos[0]), 0, float(e.pos[1]))
	var b := Vector3(float(e.ate[0]), 0, float(e.ate[1]))
	a.y = _y(a.x, a.z) + float(e.altura)
	b.y = _y(b.x, b.z) + float(e.altura)
	var segs := 8
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.035
	c.radial_segments = 5
	for k in segs:
		var t0 := float(k) / segs
		var t1 := float(k + 1) / segs
		var p0 := a.lerp(b, t0) + Vector3(0, -sin(t0 * PI) * 0.7, 0)
		var p1 := a.lerp(b, t1) + Vector3(0, -sin(t1 * PI) * 0.7, 0)
		c.height = p0.distance_to(p1)
		var mi := _malha(fut_raiz, c, (p0 + p1) * 0.5, neon(String(e.cor), 2.0))
		mi.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.99 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2)
		mi.name = "Cabo"

func _rotulo(pos: Vector3, texto: String, cor: String, px := 0.009, tam := 48) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tam
	l.pixel_size = px
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(cor)
	l.outline_modulate = Color("0a0820")
	l.position = pos
	l.no_depth_test = false
	l.font = Registro_fonte()
	fut_raiz.add_child(l)
	return l

func Registro_fonte() -> Font:
	return preload("res://scripts/dialogos/npcs_registro.gd").fonte()

func _fut_placa(e: Dictionary, base: Vector3) -> void:
	var l := _rotulo(base + Vector3(0, float(e.get("altura", 4.0)), 0), String(e.texto), String(e.cor), 0.016, 64)
	l.name = "Holograma_" + String(e.texto).left(12).replace(" ", "_")
	animados.append({"no": l, "tipo": "pisca", "fase": base.x})

func _fut_relogio(e: Dictionary, base: Vector3) -> void:
	var n := Node3D.new()
	n.name = "HologramaRelogio"
	n.position = base
	fut_raiz.add_child(n)
	var r := float(e.get("raio", 3.0))
	var h := float(e.get("altura", 4.0))
	var cores := ["3ae8ff", "ff3df0", "b8f0ff"]
	for i in 3:
		var t := TorusMesh.new()
		t.inner_radius = r * (1.0 - i * 0.22) - 0.06
		t.outer_radius = r * (1.0 - i * 0.22) + 0.06
		t.rings = 64
		var anel := _malha(n, t, Vector3(0, h, 0), neon(cores[i], 3.0, 0.85))
		anel.rotation = Vector3(deg_to_rad(70 - i * 25), 0, deg_to_rad(i * 30))
		animados.append({"no": anel, "tipo": "gira", "vel": Vector3(0.0, 0.5 + i * 0.35, 0.2 * (i - 1))})
	var feixe := CylinderMesh.new()
	feixe.top_radius = 0.9
	feixe.bottom_radius = 1.6
	feixe.height = h
	_malha(n, feixe, Vector3(0, h * 0.5, 0), neon("3ae8ff", 1.2, 0.12))
	var l := _rotulo(Vector3(0, h + r * 0.15, 0), "00:00", "e8fcff", 0.012, 64)
	l.name = "MostradorDoRelogio"
	animados.append({"no": l, "tipo": "relogio"})
	_rotulo(Vector3(0, h + r + 1.0, 0), String(e.get("rotulo", "")), "ffc23a", 0.016, 64)
	_luz(n, Vector3(0, h, 0), Color("3ae8ff"), 2.4, 12.0)

func _fut_lua(e: Dictionary, base: Vector3) -> void:
	var s := SphereMesh.new()
	s.radius = 1.1
	s.height = 2.2
	var mi := _malha(fut_raiz, s, base + Vector3(0, float(e.get("altura", 6.0)), 0), neon("d8f6ff", 2.2, 0.75))
	mi.name = "HologramaDaLua"
	animados.append({"no": mi, "tipo": "flutua", "base": mi.position, "fase": 0.0, "amp": 0.25})
	_luz(fut_raiz, mi.position, Color("bfefff"), 1.2, 8.0)
	var feixe := CylinderMesh.new()
	feixe.top_radius = 0.05
	feixe.bottom_radius = 0.5
	feixe.height = float(e.get("altura", 6.0)) - 1.0
	_malha(fut_raiz, feixe, base + Vector3(0, feixe.height * 0.5, 0), neon("bfefff", 1.0, 0.15))

func _fut_anomalia(e: Dictionary, base: Vector3) -> void:
	var n := Node3D.new()
	n.name = "AnomaliaTemporal"
	n.position = base
	fut_raiz.add_child(n)
	var r := float(e.get("raio", 3.0))
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform vec4 cor_a : source_color = vec4(1.0, 0.24, 0.94, 1.0);
uniform vec4 cor_b : source_color = vec4(0.23, 0.9, 1.0, 1.0);
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float faixa = step(0.5, fract(UV.y * 18.0 + TIME * 0.7 + sin(UV.x * 40.0 + TIME * 3.0) * 0.08));
	float glitch = step(0.92, fract(sin(floor(TIME * 9.0) * 12.9898 + floor(UV.y * 24.0)) * 43758.5453));
	vec3 c = mix(cor_a.rgb, cor_b.rgb, faixa * 0.6 + glitch * 0.4);
	ALBEDO = c;
	ALPHA = clamp(f * 0.9 + glitch * 0.25 + 0.06, 0.0, 1.0);
	EMISSION = c * (1.5 + glitch * 2.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	var esfera := _malha(n, s, Vector3(0, r * 0.75, 0), mat)
	esfera.name = "FendaDoTempo"
	animados.append({"no": esfera, "tipo": "pulsa", "fase": 0.0})
	var nucleo := SphereMesh.new()
	nucleo.radius = r * 0.25
	nucleo.height = r * 0.5
	_malha(n, nucleo, Vector3(0, r * 0.75, 0), neon("ffffff", 6.0))
	_luz(n, Vector3(0, r * 0.75, 0), Color("ff3df0"), 3.0, 14.0)
	# faíscas subindo
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 3.0
	p.position = Vector3(0, r * 0.75, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = r
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, 0.4, 0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = neon("ff8af4", 4.0)
	(q.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.draw_pass_1 = q
	n.add_child(p)
	_rotulo(Vector3(0, r * 2.0 + 1.2, 0), "FENDA DO TEMPO\n(não toque. já tocaram.)", "ffb8f8", 0.011, 56)
	_colisao_cilindro(n, r * 0.7, 3.0)

func _fut_detrito(e: Dictionary, base: Vector3) -> void:
	var cena := _carregar("kenney_space_kit/meteor_detailed.glb")
	if cena == null:
		return
	var n: Node3D = cena.instantiate()
	n.name = "DetritoFlutuante"
	n.scale = Vector3.ONE * float(e.get("escala", 1.0))
	n.position = base + Vector3(0, float(e.get("altura", 2.5)), 0)
	fut_raiz.add_child(n)
	animados.append({"no": n, "tipo": "flutua", "base": n.position, "fase": float(e.get("fase", 0)), "amp": 0.35, "gira": 0.4})

func _fut_drone(e: Dictionary, base: Vector3) -> void:
	var cena := _carregar(String(e.m))
	if cena == null:
		return
	var n: Node3D = cena.instantiate()
	n.name = "DroneZelador"
	n.scale = Vector3.ONE * float(e.get("escala", 0.6))
	n.position = base + Vector3(0, float(e.get("altura", 3.0)), 0)
	fut_raiz.add_child(n)
	var luz := SpotLight3D.new()
	luz.light_color = Color("3ae8ff")
	luz.light_energy = 2.0
	luz.spot_range = 6.0
	luz.spot_angle = 22
	luz.rotation.x = -PI / 2
	n.add_child(luz)
	animados.append({"no": n, "tipo": "drone", "base": n.position, "fase": base.x * 0.3})

func _fut_trilho(e: Dictionary) -> void:
	var pts: Array = e.pontos
	var cena := _carregar(String(e.modelo))
	var esc := float(e.get("escala", 3.0))
	for i in pts.size() - 1:
		var a := Vector2(float(pts[i][0]), float(pts[i][1]))
		var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var L := a.distance_to(b)
		var n := int(ceil(L / esc))
		for k in n:
			var q := a.lerp(b, (k + 0.5) / n)
			if cena:
				var t: Node3D = cena.instantiate()
				t.position = Vector3(q.x, _y(q.x, q.y) + 0.02, q.y)
				t.rotation.y = atan2(b.x - a.x, b.y - a.y)
				t.scale = Vector3(esc, esc, L / n)
				fut_raiz.add_child(t)

func _fut_forja(e: Dictionary, base: Vector3) -> void:
	var n := Node3D.new()
	n.name = "NucleoDaForjaQuantica"
	n.position = base
	fut_raiz.add_child(n)
	var c := CylinderMesh.new()
	c.top_radius = 0.6
	c.bottom_radius = 0.9
	c.height = 0.9
	_malha(n, c, Vector3(0, 0.45, 0), art_world.materials.iron)
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	var nucleo := _malha(n, s, Vector3(0, 1.5, 0), neon(String(e.cor), 5.0))
	animados.append({"no": nucleo, "tipo": "flutua", "base": nucleo.position, "fase": 0.0, "amp": 0.15, "gira": 1.2})
	for i in 2:
		var t := TorusMesh.new()
		t.inner_radius = 0.85
		t.outer_radius = 0.95
		var anel := _malha(n, t, Vector3(0, 1.5, 0), neon("ffc23a", 3.5))
		animados.append({"no": anel, "tipo": "gira", "vel": Vector3(1.3 * (i * 2 - 1), 0.7, 0.0)})
	_luz(n, Vector3(0, 1.6, 0), Color(String(e.cor)), 3.0, 9.0)
	_colisao_cilindro(n, 0.9, 1.2)

func _fut_veio(e: Dictionary, base: Vector3) -> void:
	var id := String(e.id)
	var mat_id := String(e.material)
	var info: Dictionary = _materiais_forja.get(mat_id, {})
	var no_info: Dictionary = _materiais_forja.get("no:" + id, {})
	var mk := Marker3D.new()
	mk.name = id
	mk.position = base
	mk.add_to_group("veio_minerio")
	mk.set_meta("material", mat_id)
	mk.set_meta("nome", String(info.get("nome", mat_id)))
	mk.set_meta("tier", int(info.get("tier", 0)))
	mk.set_meta("picareta_minima", int(info.get("picareta_minima", 0)))
	mk.set_meta("quantidade", no_info.get("quantidade", [1, 1]))
	mk.set_meta("renasce_dias", int(no_info.get("renasce_dias", 1)))
	veios.add_child(mk)
	var cores := {"minerio_cronostio": "3ae8ff", "chip_anomalia": "ff3df0", "carvao": "6a6a80", "cristal_celeste_bruto": "9ab8ff", "minerio_adamantium": "ffd84a"}
	var cor := String(cores.get(mat_id, "ffffff"))
	var cena := _carregar("kenney_space_kit/rocks_smallA.glb")
	if cena:
		var r: Node3D = cena.instantiate()
		r.scale = Vector3.ONE * 2.6
		r.rotation.y = base.x
		mk.add_child(r)
		_tingir(r, Color("6a6488"))
	# aglomerado de cristais (prismas emissivos) com a cor do material
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = hash(id)
	var mat_c := neon(cor, 2.2 if mat_id != "carvao" else 0.6)
	for k in 6:
		var c := CylinderMesh.new()
		var h := rng2.randf_range(0.7, 1.6) * (1.3 if k == 0 else 1.0)
		c.top_radius = 0.02
		c.bottom_radius = rng2.randf_range(0.14, 0.26)
		c.height = h
		c.radial_segments = 6
		c.rings = 1
		var a := k * TAU / 6.0
		var mi := _malha(mk, c, Vector3(cos(a) * 0.35 * float(k > 0), h * 0.45 + 0.2, sin(a) * 0.35 * float(k > 0)), mat_c)
		mi.rotation = Vector3(rng2.randf_range(-0.45, 0.45) * float(k > 0), 0, rng2.randf_range(-0.45, 0.45) * float(k > 0))
	var l := _rotulo(Vector3(0, 2.4, 0), String(info.get("nome", mat_id)), cor, 0.0065, 40)
	fut_raiz.remove_child(l)
	mk.add_child(l)
	_luz(mk, Vector3(0, 1.2, 0), Color(cor), 0.9, 4.0)
	_colisao_cilindro(mk, 0.9, 1.2)

# ------------------------------------------------------------------ NPCs com modelo 3D CC0
func _visuais_npcs() -> void:
	for n in npcs:
		var d: Dictionary = Futuristas.NPCS.get(String(n.npc_id), {})
		if not d.has("modelo"):
			continue
		var cena := _carregar(String(d.modelo))
		if cena == null:
			continue
		var velho: Node = n.get_node_or_null("Visual")
		if velho:
			velho.visible = false
		var m: Node3D = cena.instantiate()
		m.name = "VisualModelo3D"
		m.scale = Vector3.ONE * float(d.get("escala_modelo", 1.0))
		m.position.y = float(d.get("flutua", 0.0))
		n.add_child(m)
		if d.has("flutua"):
			animados.append({"no": m, "tipo": "flutua", "base": m.position, "fase": 0.5, "amp": 0.2})

# ------------------------------------------------------------------ céu
func _ceu_futurista() -> void:
	var g := _grupo("CeuFuturista")
	var t := TorusMesh.new()
	t.inner_radius = 58
	t.outer_radius = 60
	t.rings = 128
	var anel := _malha(g, t, Vector3(-170, 30, -170), neon("3ae8ff", 1.4, 0.55), Vector3(deg_to_rad(64), deg_to_rad(45), 0))
	anel.name = "AnelDoRelogioNoCeu"
	var t2 := TorusMesh.new()
	t2.inner_radius = 40
	t2.outer_radius = 41
	t2.rings = 128
	var anel2 := _malha(g, t2, Vector3(-170, 30, -170), neon("ff3df0", 1.2, 0.45), Vector3(deg_to_rad(70), deg_to_rad(45), deg_to_rad(20)))
	animados.append({"no": anel2, "tipo": "gira", "vel": Vector3(0, 0, 0.03)})
	var s := SphereMesh.new()
	s.radius = 26
	s.height = 52
	_malha(g, s, Vector3(-170, 30, -170), neon("2a1a5a", 1.0, 0.9)).name = "PlanetaDeOutraEpoca"

# ------------------------------------------------------------------ animação
func _process(delta: float) -> void:
	_t += delta
	for a in animados:
		var n: Node3D = a.no
		if not is_instance_valid(n):
			continue
		match String(a.tipo):
			"gira":
				n.rotate_object_local(Vector3.UP, a.vel.y * delta)
				n.rotate_object_local(Vector3.RIGHT, a.vel.x * delta)
				n.rotate_object_local(Vector3.FORWARD, a.vel.z * delta)
			"flutua":
				n.position = a.base + Vector3(0, sin(_t * 1.3 + float(a.fase)) * float(a.amp), 0)
				if a.has("gira"):
					n.rotate_y(float(a.gira) * delta)
			"drone":
				var f := float(a.fase)
				n.position = a.base + Vector3(cos(_t * 0.5 + f) * 1.4, sin(_t * 2.1 + f) * 0.2, sin(_t * 0.5 + f) * 1.4)
				n.rotation.y = -(_t * 0.5 + f)
			"pulsa":
				n.scale = Vector3.ONE * (1.0 + sin(_t * 2.6) * 0.04)
			"pisca":
				var v := 0.85 + 0.15 * sin(_t * 3.0 + float(a.fase))
				if fmod(_t * 7.0 + float(a.fase), 11.0) < 0.15:
					v = 0.3
				n.modulate.a = v
			"relogio":
				# mostrador que anda para trás e às vezes pula de século
				var s := int(_t * 4.0)
				var h := 23 - (s / 60) % 24
				var mm := 59 - s % 60
				(n as Label3D).text = ("%02d:%02d" % [h, mm]) if fmod(_t, 9.0) > 0.4 else "ERRO: ONTEM"
	for g in glitches:
		var n2: Node3D = g.no
		if is_instance_valid(n2):
			n2.visible = fmod(_t * 1.7 + float(g.fase), 4.0) > 0.25

func veio(id: String) -> Marker3D:
	return veios.get_node_or_null(id)
