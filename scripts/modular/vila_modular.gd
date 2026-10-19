extends RefCounted
## Vila V7 (cena de fidelidade): terreno em grade de 1 m, rio, pecas modulares e fundo.
## Dados: scripts/modular/vila_layout.json (gerado por tools/fidelidade_layout.py).
## fase 2: layout (terreno, caminhos, rio, casas, poco, ponte, cercas, horta, campo, lampioes)
## fase 3: fundo e bordas (abismo com nevoa, ruinas, cachoeira, pilares, arvores, moldura escura)
## fase 5: densidade (touceiras, flores, lajes do caminho, caixotes, barris, corvos extras)
const KIT = preload("res://scripts/modular/kit_modular.gd")
const Cercas = preload("res://scripts/modular/cercas.gd")
const FASE_PECA := {"casa":2,"poco":2,"ponte":2,"cerca":2,"poste_lampiao":2,"menir_runa":2,"canteiro":2,"carroca_abobora":2,"estandarte":2,
	"ruina_arco":3,"ruina_pilar":3,"pilar_pedra":3,"pilar_braseiro":3,"arvore_outono":3,"arvore_escura":3,"arvore_seca":3,"arbusto_flor":3,"arbusto_escuro":3,"rocha":3,
	"barril":5,"caixote":5,"banco":5,"mesa":5,"cogumelos":5,"deck":5}
var kit
var art
var root: Node3D
var data: Dictionary
var fase := 5
var origem := Vector2i.ZERO
var tam := Vector2i.ZERO
var alturas: Array = []
var tipos: Array = []
var pecas: Node3D
var fundo: Node3D
var detalhes: Node3D
var agua_mat: ShaderMaterial
var cachoeira_mat: ShaderMaterial
var terreno: MeshInstance3D
var nevoa: Array[MeshInstance3D] = []
var cam_yaw := 0.0
var cam_pitch := 0.0
var cam_size := 20.0
var cam_alvo := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var lista_pecas: Array[Node3D] = []
## polimento: folhas/seixos e detalhes alem do enquadramento da referencia
var densidade_extra := true
## cercas modulares por polilinha (scripts/modular/cercas.gd); quando definido, as pecas "cerca" do layout sao ignoradas
var cercas_dados: Dictionary = {}
var cercas
## false = sem abismo/cachoeira/moldura da vila (usado pela fazenda)
var fundo_vila := true

func build(world, target: Node3D, layout_path: String, fase_ativa: int) -> void:
	art = world
	root = target
	fase = fase_ativa
	rng.seed = 2207
	data = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	origem = Vector2i(int(data.origem[0]), int(data.origem[1]))
	tam = Vector2i(int(data.tamanho[0]), int(data.tamanho[1]))
	alturas = data.alturas
	tipos = data.tipos
	cam_yaw = deg_to_rad(float(data.camera.yaw))
	cam_pitch = deg_to_rad(float(data.camera.pitch))
	cam_size = float(data.camera.tamanho)
	cam_alvo = Vector3(float(data.camera.alvo[0]), 0, float(data.camera.alvo[2]))
	kit = KIT.new()
	kit.setup(art)
	pecas = _grupo("PecasModulares")
	fundo = _grupo("FundoEBordas")
	detalhes = _grupo("DetalhesDensos")
	_terreno()
	_rio()
	for m in cercas_dados.get("mover", []):
		for p in data.pecas:
			if String(p.id) == String(m.id) and Vector2(float(p.celula[0]), float(p.celula[1])).distance_to(Vector2(float(m.de[0]), float(m.de[1]))) < 0.01:
				p.celula = m.para
				if m.has("rot"):
					p.rot = m.rot
	var usar_cercas := cercas_dados.has("cercas")
	for p in data.pecas:
		var id: String = p.id
		if fase < int(FASE_PECA.get(id, 2)):
			continue
		if id == "cerca" and usar_cercas:
			continue
		_colocar(p)
	if usar_cercas:
		cercas = Cercas.new()
		cercas.construir(self, pecas, cercas_dados.cercas)
	if fase >= 3 and fundo_vila:
		_abismo()
		_cachoeira()
		_moldura()
	if fase >= 5:
		_detalhes()

func _grupo(nome: String) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	root.add_child(n)
	return n

# ---------------------------------------------------------------- camera <-> mundo
func basis_cam() -> Array:
	var b := Vector3(cos(cam_pitch)*sin(cam_yaw), sin(cam_pitch), cos(cam_pitch)*cos(cam_yaw))
	var r := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	return [r, b.cross(r), b]

func tela_para_mundo(px: float, py: float, h := 0.0) -> Vector3:
	var bc := basis_cam()
	var k := cam_size/900.0
	var o: Vector3 = cam_alvo + bc[0]*(px-800)*k + bc[1]*(450-py)*k
	var b2: Vector3 = bc[2]
	var t := (o.y-h)/b2.y
	return o - b2*t

func mundo_para_tela(p: Vector3) -> Vector2:
	var bc := basis_cam()
	var k := cam_size/900.0
	var d := p - cam_alvo
	return Vector2(800 + d.dot(bc[0])/k, 450 - d.dot(bc[1])/k)

# ---------------------------------------------------------------- grade
func altura(x: float, z: float) -> float:
	var fx := clampf(x - origem.x, 0, tam.x-1.001)
	var fz := clampf(z - origem.y, 0, tam.y-1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx-ix
	var tz := fz-iz
	var a := lerpf(float(alturas[iz][ix]), float(alturas[iz][ix+1]), tx)
	var b := lerpf(float(alturas[iz+1][ix]), float(alturas[iz+1][ix+1]), tx)
	return lerpf(a, b, tz)

func tipo(x: int, z: int) -> String:
	var ix := clampi(x-origem.x, 0, tam.x-1)
	var iz := clampi(z-origem.y, 0, tam.y-1)
	return String(tipos[iz])[ix]

func _peso(t: String) -> Color:
	match t:
		"c": return Color(1,0,0,0)
		"t": return Color(0,1,0,1)
		"h": return Color(0,0.8,0,0)
		"b": return Color(0.25,0.35,0.55,0)
		"r": return Color(0,0,1,0)
	return Color(0,0,0,0)

func _terreno() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in tam.y:
		for ix in tam.x:
			var acc := Color(0,0,0,0)
			var wsum := 0.0
			for o in [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var w := 2.0 if o == Vector2i.ZERO else 1.0
				acc += _peso(tipo(ix+origem.x+o.x, iz+origem.y+o.y))*w
				wsum += w
			st.set_color(acc/wsum)
			st.set_uv(Vector2(ix, iz))
			st.add_vertex(Vector3(ix+origem.x, float(alturas[iz][ix]), iz+origem.y))
	for iz in tam.y-1:
		for ix in tam.x-1:
			var a := iz*tam.x+ix
			for i in [a, a+1, a+tam.x, a+1, a+tam.x+1, a+tam.x]:
				st.add_index(i)
	st.generate_normals()
	terreno = MeshInstance3D.new()
	terreno.name = "TerrenoModular"
	terreno.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/fid_terreno.gdshader")
	m.set_shader_parameter("grama", art.materials.leafy_grass.albedo_texture)
	m.set_shader_parameter("pedra", art.materials.mossy_cobblestone.albedo_texture)
	m.set_shader_parameter("terra", art.materials.forest_ground_04.albedo_texture)
	m.set_shader_parameter("rocha", art.materials.lichen_rock.albedo_texture)
	terreno.material_override = m
	root.add_child(terreno)
	terreno.create_trimesh_collision()

func _ruido_normal(seed_value: int, freq: float) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	t.noise = n
	return t

func _rio() -> void:
	var pts: Array[Vector2] = []
	for p in data.rio.pontos:
		pts.append(Vector2(float(p[0]), float(p[1])))
	# reamostra a cada 0,5 m
	var res: Array[Vector2] = [pts[0]]
	for i in range(1, pts.size()):
		var a := pts[i-1]
		var b := pts[i]
		var n := maxi(1, int(a.distance_to(b)/0.5))
		for k in range(1, n+1):
			res.append(a.lerp(b, float(k)/n))
	var w := float(data.rio.largura)+1.2
	var y := float(data.rio.nivel)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	for i in res.size():
		var dir := (res[mini(i+1,res.size()-1)] - res[maxi(i-1,0)]).normalized()
		var side := Vector2(-dir.y, dir.x)*w*0.5
		if i > 0:
			along += res[i].distance_to(res[i-1])
		for s in [-1, 1]:
			var q: Vector2 = res[i] + side*s
			st.set_uv(Vector2(along, 0.0 if s < 0 else 1.0))
			st.add_vertex(Vector3(q.x, y, q.y))
	for i in res.size()-1:
		var a := i*2
		for k in [a, a+1, a+2, a+1, a+3, a+2]:
			st.add_index(k)
	st.generate_normals()
	var rio := MeshInstance3D.new()
	rio.name = "RioModular"
	rio.mesh = st.commit()
	agua_mat = ShaderMaterial.new()
	agua_mat.shader = load("res://shaders/fid_agua.gdshader")
	agua_mat.set_shader_parameter("normal_a", _ruido_normal(3, 0.03))
	agua_mat.set_shader_parameter("normal_b", _ruido_normal(9, 0.05))
	rio.material_override = agua_mat
	rio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rio)
	# vitorias-regias
	var pad := CylinderMesh.new()
	pad.top_radius = 0.22
	pad.bottom_radius = 0.22
	pad.height = 0.02
	pad.radial_segments = 9
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("4f7a2c")
	pm.roughness = 0.6
	for i in 26:
		var c := res[rng.randi_range(0, res.size()-1)]
		var off := Vector2(rng.randf_range(-1,1), rng.randf_range(-1,1))*w*0.33
		var m := MeshInstance3D.new()
		m.mesh = pad
		m.material_override = pm
		m.position = Vector3(c.x+off.x, y+0.02, c.y+off.y)
		m.scale = Vector3.ONE*rng.randf_range(0.6,1.3)
		root.add_child(m)

func _colocar(p: Dictionary) -> Node3D:
	var id: String = p.id
	var n: Node3D = kit.make(id, p)
	var c: Array = p.celula
	var x := float(c[0])
	var z := float(c[1])
	if id == "cerca":
		x = float(p.de[0])
		z = float(p.de[1])
		var dx := float(p.ate[0]) - x
		var dz := float(p.ate[1]) - z
		n.rotation.y = atan2(-dz, dx)
	else:
		n.rotation.y = int(p.get("rot", 0))*PI/2
	var y := float(p.y) if p.has("y") else altura(x, z)
	n.position = Vector3(x, y, z)
	n.set_meta("celula", Vector2i(roundi(x), roundi(z)))
	pecas.add_child(n)
	lista_pecas.append(n)
	return n

# ---------------------------------------------------------------- fase 3
func _abismo() -> void:
	# Camadas de nevoa no abismo (quads horizontais sem luz, alfa por ruido) + penhascos distantes.
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	noise.noise = fn
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled, depth_draw_never;\nuniform sampler2D ruido : repeat_enable, filter_linear;\nuniform vec4 cor : source_color = vec4(0.48,0.55,0.66,0.6);\nuniform float vel = 0.01;\nvarying vec3 w;\nvoid vertex(){ w=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }\nvoid fragment(){ float n=texture(ruido,w.xz*0.02+vec2(TIME*vel,TIME*vel*0.6)).r; float e=smoothstep(0.0,0.25,UV.x)*smoothstep(1.0,0.75,UV.x)*smoothstep(0.0,0.25,UV.y)*smoothstep(1.0,0.75,UV.y); ALBEDO=cor.rgb; ALPHA=cor.a*smoothstep(0.25,0.75,n)*e; }"
	var centro := tela_para_mundo(1350, 120, -4.0)
	for i in 4:
		var q := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(90, 90)
		q.mesh = plane
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("ruido", noise)
		m.set_shader_parameter("cor", Color(0.5+i*0.06,0.56+i*0.06,0.68+i*0.04,0.9-i*0.12))
		m.set_shader_parameter("vel", 0.006+i*0.003)
		q.material_override = m
		q.position = Vector3(centro.x, [-14.0,-8.0,-4.5,-2.2][i], centro.z)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fundo.add_child(q)
		nevoa.append(q)
	# penhascos e arcos distantes (silhuetas) atras das ruinas
	for entry in [[1150,40,-3.0,8.0],[1260,60,-2.0,6.0],[1420,30,-1.0,9.0],[1580,90,-2.5,7.0],[1500,200,-6.0,6.0],[1000,20,-1.0,7.0]]:
		var base := tela_para_mundo(float(entry[0]), float(entry[1]), float(entry[2]))
		var rock := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(float(entry[3])*0.45, 30, float(entry[3])*0.4)
		rock.mesh = b
		rock.material_override = art.materials.lichen_rock
		rock.position = base - Vector3(0, 15, 0)
		rock.rotation.y = rng.randf()*TAU
		fundo.add_child(rock)
		var veg: Node3D = kit.make("arbusto_escuro")
		veg.position = base
		veg.scale = Vector3.ONE*1.6
		fundo.add_child(veg)
		if rng.randf() < 0.6:
			var arch: Node3D = kit.make("ruina_arco", {"fundo": 2.0})
			arch.position = base
			arch.rotation.y = rng.randf()*TAU
			arch.scale = Vector3.ONE*0.8
			fundo.add_child(arch)

func _cachoeira() -> void:
	var start: Array = data.rio.pontos[0]
	var p := Vector3(float(start[0]), 0, float(start[1]))
	var top := 3.6
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode cull_disabled;\nuniform float efeitos=1.0;\nvoid fragment(){ float s=sin(UV.x*90.0+sin(UV.x*13.0)*3.0)*0.5+0.5; float f=fract(UV.y*3.0-TIME*1.6*efeitos+s*0.3); float streak=smoothstep(0.55,1.0,s)*smoothstep(0.2,0.9,f); float base=smoothstep(0.75,1.0,UV.y); vec3 c=mix(vec3(0.10,0.24,0.27),vec3(0.82,0.88,0.86),max(streak*0.8,base*0.9)); ALBEDO=c; ROUGHNESS=0.2; SPECULAR=0.7; ALPHA=smoothstep(0.0,0.08,UV.x)*smoothstep(1.0,0.92,UV.x); EMISSION=c*0.08; }"
	cachoeira_mat = ShaderMaterial.new()
	cachoeira_mat.shader = shader
	var bc := basis_cam()
	for k in 2:
		var fall := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(2.6 - k*0.8, top+0.6)
		fall.mesh = q
		fall.material_override = cachoeira_mat
		var face: Vector3 = Vector3(bc[2].x, 0, bc[2].z).normalized()
		var fpos: Vector3 = p + Vector3(0, (top-0.45)*0.5, 0) - face*(0.9+k*0.4) + bc[0]*(k*1.6-0.6)
		fall.transform = Transform3D(Basis.IDENTITY, fpos).looking_at(fpos + face, Vector3.UP)
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fundo.add_child(fall)
	# borrifo na base
	var mist := CPUParticles3D.new()
	mist.position = p + Vector3(0, -0.2, 0)
	mist.amount = 30
	mist.lifetime = 2.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(1.4, 0.1, 1.0)
	mist.direction = Vector3.UP
	mist.initial_velocity_min = 0.3
	mist.initial_velocity_max = 0.7
	mist.gravity = Vector3(0, 0.05, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 0.7)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(0.85, 0.9, 0.9, 0.25)
	sm.albedo_texture = kit._soft_dot()
	qm.material = sm
	mist.mesh = qm
	fundo.add_child(mist)
	# rochas do patamar
	for i in 10:
		var c := tela_para_mundo(rng.randf_range(0, 290), rng.randf_range(10, 190), 3.6)
		var r: Node3D = kit.make("rocha")
		r.position = Vector3(c.x, altura(c.x, c.z), c.z)
		r.scale = Vector3.ONE*rng.randf_range(1.2, 2.2)
		fundo.add_child(r)

func _moldura() -> void:
	# Moldura escura de folhagem nas bordas (primeiro plano), como na referencia.
	var spots: Array = []
	for i in 15:
		spots.append([rng.randf_range(-40, 1640), rng.randf_range(860, 960), 1.0])
	for i in 6:
		spots.append([rng.randf_range(-40, 60), rng.randf_range(600, 880), 1.0])
	for i in 6:
		spots.append([rng.randf_range(1540, 1640), rng.randf_range(450, 880), 1.0])
	for s in spots:
		var w := tela_para_mundo(float(s[0]), float(s[1]), 0.0)
		var id := "arbusto_escuro" if rng.randf() < 0.5 else "arbusto_flor"
		var n: Node3D = kit.make(id)
		n.position = Vector3(roundf(w.x), altura(w.x, w.z), roundf(w.z))
		n.scale = Vector3.ONE*rng.randf_range(1.0, 1.6)
		fundo.add_child(n)

# ---------------------------------------------------------------- fase 5
func _detalhes() -> void:
	var tuft: ArrayMesh = kit.foliage_mesh(9, Vector3(0.22,0.35,0.22), Color("3f5f22"), Color("8a9b38"), Color(), 0.0, 77)
	var flor: ArrayMesh = kit.foliage_mesh(7, Vector3(0.18,0.32,0.18), Color("47672a"), Color("6f8a30"), Color("ece2b6"), 0.45, 78)
	var flor_roxa: ArrayMesh = kit.foliage_mesh(7, Vector3(0.18,0.3,0.18), Color("47672a"), Color("6f8a30"), Color("9a86c8"), 0.45, 79)
	var flor_amarela: ArrayMesh = kit.foliage_mesh(7, Vector3(0.18,0.3,0.18), Color("47672a"), Color("6f8a30"), Color("e3b43a"), 0.5, 80)
	var lajes := BoxMesh.new()
	lajes.size = Vector3(0.42, 0.06, 0.34)
	var lotes := {"tufo": [], "flor": [], "roxa": [], "amarela": [], "laje": [], "folha": [], "seixo": []}
	var cores := {"folha": [], "seixo": []}
	# densidade extra (polimento 19/10): area alem do enquadramento da referencia (camera seguindo),
	# folhas de outono no chao e seixos. Desligar: "densidade_extra": false em docs/fidelidade-camera.json.
	var extra := bool(densidade_extra)
	var margem := Rect2(-700, -500, 3000, 1900) if extra else Rect2(-60, -60, 1720, 1020)
	var paleta_folha := [Color("c4421c"), Color("e07b26"), Color("a32a18"), Color("d9a43a"), Color("7a2416")]
	for iz in tam.y:
		for ix in tam.x:
			var x := ix+origem.x
			var z := iz+origem.y
			var h := float(alturas[iz][ix])
			if h < -0.3:
				continue
			var s := mundo_para_tela(Vector3(x, h, z))
			if not margem.has_point(s):
				continue
			var t := tipo(x, z)
			if t == "g":
				for k in 3:
					var q := Vector3(x+rng.randf_range(-0.5,0.5), 0, z+rng.randf_range(-0.5,0.5))
					q.y = altura(q.x, q.z)
					var r := rng.randf()
					var key := "tufo" if r < 0.62 else ("flor" if r < 0.8 else ("amarela" if r < 0.92 else "roxa"))
					lotes[key].append(Transform3D(Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.8,1.6)), q))
				if extra:
					_espalhar(lotes, cores, paleta_folha, x, z, 3 if rng.randf() < 0.4 else 2, 0.3)
			elif t == "c":
				for k in 3:
					var q := Vector3(x+rng.randf_range(-0.45,0.45), 0, z+rng.randf_range(-0.45,0.45))
					q.y = altura(q.x, q.z)+0.015
					lotes.laje.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2,0.2)+(PI/2 if k%2 else 0.0)).scaled(Vector3(rng.randf_range(0.8,1.3),1,rng.randf_range(0.8,1.3))), q))
				if extra:
					_espalhar(lotes, cores, paleta_folha, x, z, 2 if rng.randf() < 0.5 else 1, 0.5)
	var folha_m := BoxMesh.new()
	folha_m.size = Vector3(0.2, 0.012, 0.13)
	var seixo_m := SphereMesh.new()
	seixo_m.radius = 0.07
	seixo_m.height = 0.08
	seixo_m.radial_segments = 6
	seixo_m.rings = 3
	var meshes := {"tufo": tuft, "flor": flor, "roxa": flor_roxa, "amarela": flor_amarela, "laje": lajes, "folha": folha_m, "seixo": seixo_m}
	for key in lotes:
		var arr: Array = lotes[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[key]
		mm.instance_count = arr.size()
		var com_cor: bool = cores.has(key)
		mm.instance_count = 0
		mm.use_colors = com_cor
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
			if com_cor:
				mm.set_instance_color(i, cores[key][i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Lote_"+key
		inst.multimesh = mm
		if com_cor:
			var cm := StandardMaterial3D.new()
			cm.vertex_color_use_as_albedo = true
			cm.roughness = 0.95
			inst.material_override = cm
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif key == "laje":
			var lm: StandardMaterial3D = art.materials.mossy_cobblestone.duplicate()
			lm.albedo_color = Color("d9b98c")
			inst.material_override = lm
		else:
			inst.material_override = kit.folhagem
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detalhes.add_child(inst)
	# corvos extras e vasos
	for q in [[120,170],[1500,240],[830,60],[1160,250]]:
		var w := tela_para_mundo(float(q[0]), float(q[1]), 0.0)
		kit._crow(detalhes, Vector3(w.x, altura(w.x,w.z)+ (2.0 if q[0]==1160 else 0.0), w.z))
## folhas de outono (cor por instancia) e seixos espalhados numa celula
func _espalhar(lotes: Dictionary, cores: Dictionary, paleta: Array, x: int, z: int, n_folhas: int, chance_seixo: float) -> void:
	for k in n_folhas:
		var q := Vector3(x+rng.randf_range(-0.5,0.5), 0, z+rng.randf_range(-0.5,0.5))
		q.y = altura(q.x, q.z)+0.012
		var b := Basis(Vector3.UP, rng.randf()*TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25,0.25))
		lotes.folha.append(Transform3D(b.scaled(Vector3.ONE*rng.randf_range(0.8,1.4)), q))
		cores.folha.append((paleta[rng.randi() % paleta.size()] as Color).darkened(rng.randf_range(0.0,0.25)))
	if rng.randf() < chance_seixo:
		var q := Vector3(x+rng.randf_range(-0.5,0.5), 0, z+rng.randf_range(-0.5,0.5))
		q.y = altura(q.x, q.z)+0.02
		lotes.seixo.append(Transform3D(Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3(rng.randf_range(0.7,1.5),rng.randf_range(0.5,0.9),rng.randf_range(0.7,1.3))), q))
		cores.seixo.append(Color("8a8478").darkened(rng.randf_range(0.0,0.35)))

## Celulas andaveis da V7 (substitui a grade V6 de island.gd): chao entre -0,3 e 0,45 m, sem degrau
## maior que 0,6 m para um vizinho, mais o tabuleiro das pontes.
func andaveis() -> Dictionary:
	var r := {}
	for iz in tam.y:
		for ix in tam.x:
			var h := float(alturas[iz][ix])
			if h < -0.3 or h > 0.45:
				continue
			var ok := true
			for o in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var jx: int = ix + o.x
				var jz: int = iz + o.y
				if jx >= 0 and jz >= 0 and jx < tam.x and jz < tam.y and absf(float(alturas[jz][jx]) - h) > 0.6 and float(alturas[jz][jx]) > h:
					ok = false
			if ok:
				r[Vector2i(ix + origem.x, iz + origem.y)] = true
	for n in lista_pecas:
		if String(n.get_meta("modulo", "")) == "ponte":
			for lz in range(-4, 5):
				for lx in [-1, 0, 1]:
					var q: Vector3 = n.position + Vector3(lx, 0, lz).rotated(Vector3.UP, n.rotation.y)
					r[Vector2i(roundi(q.x), roundi(q.z))] = true
	return r
