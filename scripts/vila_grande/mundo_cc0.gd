extends "res://scripts/modular/vila_modular.gd"
## Terreno/rio/pecas do kit a partir do JSON (mesmo formato de scripts/modular/vila_layout.json),
## com extensoes para mapas grandes: sem quadrados fora da ilha, rotacao livre e escala por peca,
## detalhes (tufos, flores, lajes, folhas) cobrindo o mapa inteiro e cores por tema.
var tema: Dictionary = {}

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
			# descarta quadrados totalmente fora da ilha (abismo); mantem as bordas (penhasco)
			var fora := 0
			for k in [[iz,ix],[iz,ix+1],[iz+1,ix],[iz+1,ix+1]]:
				if float(alturas[k[0]][k[1]]) < -20.0:
					fora += 1
			if fora == 4:
				continue
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
	m.set_shader_parameter("tom_rocha", Vector3(0.50,0.45,0.40))
	for k in ["tom_grama","tom_pedra","tom_terra","tom_rocha"]:
		if tema.has(k):
			var c := Color(String(tema[k]))
			m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	terreno.material_override = m
	terreno.add_to_group("navegavel")
	root.add_child(terreno)
	terreno.create_trimesh_collision()

func _rio() -> void:
	super._rio()
	if tema.has("agua_raso"):
		var c := Color(String(tema.agua_raso))
		agua_mat.set_shader_parameter("raso", Vector3(c.r,c.g,c.b))
	if tema.has("agua_fundo"):
		var c2 := Color(String(tema.agua_fundo))
		agua_mat.set_shader_parameter("fundo", Vector3(c2.r,c2.g,c2.b))

func _colocar(p: Dictionary) -> Node3D:
	var n := super._colocar(p)
	if p.has("ang"):
		n.rotation.y = deg_to_rad(float(p.ang))
	if p.has("escala"):
		n.scale = Vector3.ONE*float(p.escala)
	return n

func _detalhes() -> void:
	var cg: Array = tema.get("tufos", ["3f5f22","8a9b38"])
	var cf: Array = tema.get("flores", ["ece2b6","9a86c8","e3b43a"])
	var dens := float(tema.get("densidade_tufos", 1.0))
	var tuft: ArrayMesh = kit.foliage_mesh(9, Vector3(0.22,0.35,0.22), Color(String(cg[0])), Color(String(cg[1])), Color(), 0.0, 77)
	var flores: Array = []
	for i in cf.size():
		flores.append(kit.foliage_mesh(7, Vector3(0.18,0.32,0.18), Color(String(cg[0])), Color(String(cg[1])), Color(String(cf[i])), 0.45, 78+i))
	var lajes := BoxMesh.new()
	lajes.size = Vector3(0.42, 0.06, 0.34)
	var lotes := {"tufo": [], "laje": [], "folha": [], "seixo": []}
	for i in flores.size():
		lotes["flor%d" % i] = []
	var cores := {"folha": [], "seixo": []}
	var paleta: Array = []
	for c in tema.get("folhas_chao", ["c4421c","e07b26","a32a18","d9a43a","7a2416"]):
		paleta.append(Color(String(c)))
	for iz in tam.y:
		for ix in tam.x:
			var x := ix+origem.x
			var z := iz+origem.y
			var h := float(alturas[iz][ix])
			if h < -0.3:
				continue
			var t := tipo(x, z)
			if t == "g":
				for k in int(round(3*dens)):
					var q := Vector3(x+rng.randf_range(-0.5,0.5), 0, z+rng.randf_range(-0.5,0.5))
					q.y = altura(q.x, q.z)
					var r := rng.randf()
					var key := "tufo" if (r < 0.7 or flores.is_empty()) else "flor%d" % (rng.randi() % flores.size())
					lotes[key].append(Transform3D(Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(0.8,1.6)), q))
				if rng.randf() < 0.5:
					_espalhar(lotes, cores, paleta, x, z, 2, 0.2)
			elif t == "c":
				for k in 3:
					var q := Vector3(x+rng.randf_range(-0.45,0.45), 0, z+rng.randf_range(-0.45,0.45))
					q.y = altura(q.x, q.z)+0.015
					lotes.laje.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2,0.2)+(PI/2 if k%2 else 0.0)).scaled(Vector3(rng.randf_range(0.8,1.3),1,rng.randf_range(0.8,1.3))), q))
				if rng.randf() < 0.3:
					_espalhar(lotes, cores, paleta, x, z, 1, 0.4)
	var folha_m := BoxMesh.new()
	folha_m.size = Vector3(0.2, 0.012, 0.13)
	var seixo_m := SphereMesh.new()
	seixo_m.radius = 0.07
	seixo_m.height = 0.08
	seixo_m.radial_segments = 6
	seixo_m.rings = 3
	var meshes := {"tufo": tuft, "laje": lajes, "folha": folha_m, "seixo": seixo_m}
	for i in flores.size():
		meshes["flor%d" % i] = flores[i]
	for key in lotes:
		var arr: Array = lotes[key]
		if arr.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var com_cor: bool = cores.has(key)
		mm.use_colors = com_cor
		mm.mesh = meshes[key]
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
			lm.albedo_color = Color(String(tema.get("lajes", "d9b98c")))
			inst.material_override = lm
		else:
			inst.material_override = kit.folhagem
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detalhes.add_child(inst)
