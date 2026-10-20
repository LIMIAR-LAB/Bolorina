extends RefCounted
## Estruturas especiais montadas em codigo (sem creditos pagos): torre do arquimago, doca e
## dirigivel, quadro de missoes, palicada/totens/cabanas/salao orc, capela em ruinas e lapides.
## Todas usam os materiais do VisualWorld (art.materials) e o kit modular (kit).
var art
var kit
var rng := RandomNumberGenerator.new()
var _mats := {}

func _init(world, kit_modular) -> void:
	art = world
	kit = kit_modular
	rng.seed = 4242

func cor(hex: String, emissao := 0.0) -> StandardMaterial3D:
	var k := hex + str(emissao)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.9
		if emissao > 0.0:
			m.emission_enabled = true
			m.emission = Color(hex)
			m.emission_energy_multiplier = emissao
		_mats[k] = m
	return _mats[k]

func malha(n: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = escala
	n.add_child(m)
	return m

func cilindro(r1: float, r2: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r1
	c.bottom_radius = r2
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

func colisao_caixa(n: Node3D, centro: Vector3, tamanho: Vector3) -> void:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tamanho
	c.shape = s
	b.position = centro
	b.add_child(c)
	n.add_child(b)

func luz(n: Node3D, pos: Vector3, cor_luz: Color, energia := 1.5, alcance := 6.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = cor_luz
	l.light_energy = energia
	l.omni_range = alcance
	l.add_to_group("night_lights")
	n.add_child(l)
	return l

# ------------------------------------------------------------------ Porto Velho
func torre_arquimago(n: Node3D) -> void:
	# Torre torta de 3 tambores desalinhados + telhado conico do kit Quaternius + aneis de portal.
	var y := 0.0
	var off := Vector3.ZERO
	var raios := [3.0, 2.6, 2.3]
	for i in 3:
		var h: float = [5.0, 4.5, 4.0][i]
		var r: float = raios[i]
		var seg := malha(n, cilindro(r, r+0.15, h, 14), off+Vector3(0, y+h*0.5, 0), art.materials.castle_brick_01)
		seg.rotation.z = (i-1)*0.035
		# cinta de madeira e janelas violetas
		malha(n, cilindro(r+0.12, r+0.12, 0.25, 14), off+Vector3(0, y+h, 0), art.materials.wood)
		for k in 4:
			var a := k*TAU/4 + i*0.6
			var w = art.box(off+Vector3(cos(a)*r, y+h*0.55, sin(a)*r), Vector3(0.5,1.0,0.5), "glow", false, n)
			w.material_override = cor("b07cff", 2.2)
		y += h
		off += Vector3(rng.randf_range(-0.25,0.25), 0, rng.randf_range(-0.25,0.25))
	var tel = load("res://art/models/quaternius_vila_medieval/Roof_Tower_RoundTiles.gltf").instantiate()
	tel.position = off + Vector3(0, y, 0)
	tel.scale = Vector3.ONE*0.85
	n.add_child(tel)
	# porta e escadinha
	art.box(Vector3(0,1.1,raios[0]+0.05), Vector3(1.2,2.2,0.2), "brown_planks_03", false, n)
	for k in 3:
		art.box(Vector3(0,0.1+k*0.12,raios[0]+0.5+k*-0.25), Vector3(1.8,0.2,0.5), "castle_brick_01", false, n)
	# aneis de portal flutuando (o lado "multiverso" do Arquimago)
	for k in 3:
		var t := TorusMesh.new()
		t.inner_radius = 1.0+k*0.45
		t.outer_radius = 1.12+k*0.45
		t.rings = 32
		t.ring_segments = 6
		var anel := malha(n, t, off+Vector3(0, y+3.5+k*0.6, 0), cor(["57ffb0","b07cff","7fd8ff"][k], 3.0), Vector3(0.5+k*0.4, k*0.9, 0.3))
		anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	luz(n, off+Vector3(0, y+4, 0), Color("9dffcf"), 3.0, 12.0)
	colisao_caixa(n, Vector3(0, 7, 0), Vector3(6, 14, 6))

func quadro_missoes(n: Node3D) -> void:
	for x in [-1.1, 1.1]:
		art.box(Vector3(x,1.2,0), Vector3(0.16,2.4,0.16), "wood", false, n)
	art.box(Vector3(0,1.55,0), Vector3(2.4,1.3,0.1), "brown_planks_03", false, n)
	for side in [-1,1]:
		var t = art.box(Vector3(side*0.6,2.45,0), Vector3(1.4,0.08,0.7), "grey_roof_tiles", false, n)
		t.rotation.z = -side*0.35
	for i in 6:
		var p = art.box(Vector3(rng.randf_range(-0.9,0.9), rng.randf_range(1.1,2.0), 0.07), Vector3(0.32,0.4,0.01), "flower", false, n)
		p.rotation.z = rng.randf_range(-0.2,0.2)
	colisao_caixa(n, Vector3(0,1,0), Vector3(2.4,2,0.3))

func doca(n: Node3D, comprimento: float, largura: float) -> void:
	# Deck de madeira que avanca alem da borda da ilha, com pilares descendo pela rocha.
	for i in int(comprimento/0.5):
		var x := i*0.5
		var t = art.box(Vector3(x,0.12,0), Vector3(0.46,0.1,largura), "brown_planks_03", false, n)
		t.rotation.x = rng.randf_range(-0.01,0.01)
	for x in range(0, int(comprimento)+1, 3):
		for z in [-largura*0.5, largura*0.5]:
			art.box(Vector3(x,-3.0,z), Vector3(0.35,6.4,0.35), "wood", false, n)
			art.box(Vector3(x,0.7,z), Vector3(0.16,1.2,0.16), "wood", false, n)
		art._beam(Vector3(x,-5.5,-largura*0.5), Vector3(x,-0.1,largura*0.5), 0.18, "wood", n)
	for z in [-largura*0.5, largura*0.5]:
		art._beam(Vector3(0,1.15,z), Vector3(comprimento,1.15,z), 0.1, "brown_planks_03", n)
	# guindaste de carga
	art.box(Vector3(comprimento-2,2.5,largura*0.5-0.6), Vector3(0.3,5,0.3), "wood", false, n)
	art._beam(Vector3(comprimento-2,4.8,largura*0.5-0.6), Vector3(comprimento+1.5,4.8,largura*0.5-0.6), 0.2, "wood", n)
	art.box(Vector3(comprimento+1.5,3.6,largura*0.5-0.6), Vector3(0.6,0.6,0.6), "brown_planks_03", false, n)
	var corpo := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(comprimento, 0.3, largura)
	c.shape = s
	corpo.position = Vector3(comprimento*0.5, 0.05, 0)
	corpo.add_child(c)
	corpo.add_to_group("navegavel")
	n.add_child(corpo)

func dirigivel(n: Node3D) -> void:
	# Dirigivel mercante: balao de lona, casco de madeira, helices e lanternas.
	var balao := SphereMesh.new()
	balao.radius = 1.0
	balao.height = 2.0
	balao.radial_segments = 20
	balao.rings = 10
	malha(n, balao, Vector3(0,7.2,0), cor("cdb48a"), Vector3.ZERO, Vector3(9.5,3.0,3.2))
	for k in 5:
		malha(n, cilindro(3.25,3.25,0.12,20), Vector3(-6+k*3,7.2,0), cor("6b1414"), Vector3(0,0,PI/2), Vector3(1, 1, 1)*(1.0-absf(k-2)*0.18))
	var casco = art.box(Vector3(0,2.6,0), Vector3(9,1.4,3.0), "brown_planks_03", false, n)
	art.box(Vector3(4.9,2.9,0), Vector3(1.4,1.0,2.2), "brown_planks_03", false, n).rotation.z = 0.3
	art.box(Vector3(-4.8,3.0,0), Vector3(1.2,1.8,2.6), "wood", false, n)
	art.box(Vector3(0,3.4,0), Vector3(8.6,0.1,2.8), "wood", false, n)
	for x in [-3.0, 0.0, 3.0]:
		for z in [-1.3, 1.3]:
			art._beam(Vector3(x,3.4,z), Vector3(x*1.1,6.0,z*1.6), 0.06, "wood", n)
	for z in [-1.7, 1.7]:
		var h := malha(n, cilindro(0.05,0.05,2.2,6), Vector3(-5.6,3.0,z), art.materials.iron, Vector3(PI/2,0,0))
		h.rotation = Vector3(0, 0, PI/2)
	art.box(Vector3(2.5,3.8,1.0), Vector3(0.6,0.6,0.6), "brown_planks_03", false, n)
	art.box(Vector3(1.6,3.75,-0.8), Vector3(0.7,0.5,0.7), "brown_planks_03", false, n)
	for x in [-4.0, 4.0]:
		art.box(Vector3(x,3.8,1.5), Vector3(0.22,0.3,0.22), "glow", false, n)
		luz(n, Vector3(x,3.9,1.8), Color("ffb05a"), 1.6, 6.0)
	casco.name = "CascoDoDirigivel"

# ------------------------------------------------------------------ Vila dos Orcs
func palicada(n: Node3D, centro: Vector2, raio: float, portoes: Array) -> void:
	# Estacas de tora pontudas em anel; portoes = angulos (graus) com 5 m de abertura.
	var passo := 0.55
	var count := int(TAU*raio/passo)
	var tora := cilindro(0.26, 0.3, 1.0, 7)
	var ponta := cilindro(0.0, 0.26, 0.6, 7)
	for i in count:
		var a := i*TAU/count
		var livre := false
		for g in portoes:
			var d := absf(wrapf(a - deg_to_rad(float(g)), -PI, PI))*raio
			if d < 2.6:
				livre = true
		if livre:
			continue
		var h := rng.randf_range(3.0, 3.8)
		var p := Vector3(centro.x+cos(a)*raio, 0, centro.y+sin(a)*raio)
		malha(n, tora, p+Vector3(0,h*0.5-0.3,0), art.materials.wood, Vector3(rng.randf_range(-0.05,0.05),0,rng.randf_range(-0.05,0.05)), Vector3(1,h,1))
		malha(n, ponta, p+Vector3(0,h-0.3+0.3,0), art.materials.wood)
		if i % 4 == 0:
			art._beam(p+Vector3(0,1.2,0), Vector3(centro.x+cos(a+passo*4/raio)*raio,1.2,centro.y+sin(a+passo*4/raio)*raio), 0.12, "brown_planks_03", n)
	# colisao em segmentos
	for i in 48:
		var a := (i+0.5)*TAU/48
		var livre := false
		for g in portoes:
			if absf(wrapf(a - deg_to_rad(float(g)), -PI, PI))*raio < 2.6:
				livre = true
		if livre:
			continue
		var p := Vector3(centro.x+cos(a)*raio, 1.5, centro.y+sin(a)*raio)
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.6, 3, TAU*raio/48+0.2)
		c.shape = s
		b.position = p
		b.rotation.y = -a
		b.add_child(c)
		n.add_child(b)
	# torres de vigia nos portoes
	for g in portoes:
		for lado in [-1, 1]:
			var a: float = deg_to_rad(float(g)) + lado*3.2/raio
			torre_vigia(n, Vector3(centro.x+cos(a)*raio, 0, centro.y+sin(a)*raio))

func torre_vigia(n: Node3D, p: Vector3) -> void:
	for dx in [-0.8, 0.8]:
		for dz in [-0.8, 0.8]:
			art.box(p+Vector3(dx,2.5,dz), Vector3(0.22,5,0.22), "wood", false, n)
	art.box(p+Vector3(0,4.6,0), Vector3(2.2,0.15,2.2), "brown_planks_03", false, n)
	for side in [-1,1]:
		var t = art.box(p+Vector3(side*0.6,5.9,0), Vector3(1.5,0.12,2.6), "kit_palha", false, n)
		t.rotation.z = -side*0.6
	totem_caveira(n, p+Vector3(0,4.7,1.2), 0.5)

func totem(n: Node3D, p: Vector3, altura := 4.0) -> void:
	malha(n, cilindro(0.32, 0.38, altura, 8), p+Vector3(0,altura*0.5,0), art.materials.wood)
	for k in 3:
		var y := altura*(0.35+k*0.22)
		var cabeca = art.box(p+Vector3(0,y,0), Vector3(0.9,0.6,0.9), "brown_planks_03", false, n)
		cabeca.rotation.y = k*0.4
		for side in [-1,1]:
			var olho = art.box(p+Vector3(side*0.2,y+0.08,0.46).rotated(Vector3.UP,0) , Vector3(0.14,0.1,0.04), "glow", false, n)
			olho.material_override = cor("ff5a1e", 2.0)
		art.box(p+Vector3(0,y-0.15,0.47), Vector3(0.5,0.08,0.05), "kit_vermelho", false, n)
	# asas/chifres
	for side in [-1,1]:
		art._beam(p+Vector3(0,altura-0.2,0), p+Vector3(side*1.3,altura+0.8,0), 0.14, "kit_palha", n)
	totem_caveira(n, p+Vector3(0,altura+0.15,0), 0.7)
	var cap := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.45
	s.height = altura
	c.shape = s
	cap.position = p+Vector3(0,altura*0.5,0)
	cap.add_child(c)
	n.add_child(cap)

func totem_caveira(n: Node3D, p: Vector3, s: float) -> void:
	var osso := cor("d8ccb0")
	var b := SphereMesh.new()
	b.radius = 0.25
	b.height = 0.45
	b.radial_segments = 8
	b.rings = 5
	malha(n, b, p+Vector3(0,0.2*s,0), osso, Vector3.ZERO, Vector3.ONE*s*1.4)
	for side in [-1,1]:
		art._beam(p+Vector3(side*0.15*s,0.35*s,0), p+Vector3(side*0.55*s,0.75*s,0), 0.07*s, "flower", n)

func fogueira(n: Node3D, p: Vector3, escala := 1.0) -> void:
	for i in 10:
		var a := i*TAU/10
		var pedra = kit.ball(n, p+Vector3(cos(a),0.1,sin(a))*0.75*escala, Vector3(0.28,0.22,0.26)*escala, art.materials.lichen_rock)
		pedra.rotation.y = a
	for i in 5:
		var a := i*TAU/5
		art._beam(p+Vector3(cos(a)*0.55,0.05,sin(a)*0.55)*escala, p+Vector3(0,0.7*escala,0), 0.12*escala, "wood", n)
	kit._fire(n, p+Vector3(0,0.35*escala,0), 1.6*escala)

func cabana_orc(n: Node3D, raio: float, altura: float) -> void:
	# Cabana redonda de toras com teto conico de palha/peles e porta voltada para +z.
	var seg := 16
	var tora := cilindro(0.17, 0.19, 1.0, 6)
	for i in seg:
		var a := i*TAU/seg
		if absf(wrapf(a - PI/2, -PI, PI)) < 0.3:
			continue
		malha(n, tora, Vector3(cos(a)*raio, altura*0.5, sin(a)*raio), art.materials.wood, Vector3(0,0,rng.randf_range(-0.04,0.04)), Vector3(1, altura+rng.randf_range(-0.2,0.2), 1))
	var parede := malha(n, cilindro(raio-0.1, raio-0.1, altura, seg), Vector3(0, altura*0.5, 0), art.materials.brown_planks_03)
	parede.name = "ParedeInterna"
	var teto := malha(n, cilindro(0.15, raio+0.9, altura*1.1, seg), Vector3(0, altura+altura*0.55-0.1, 0), art.materials.kit_palha)
	teto.rotation.y = rng.randf()*TAU
	for k in 6:
		var a := k*TAU/6 + 0.3
		art._beam(Vector3(cos(a)*(raio+0.8), altura-0.05, sin(a)*(raio+0.8)), Vector3(0, altura*2.2, 0), 0.08, "wood", n)
	# porta de pele
	var porta = art.box(Vector3(0, altura*0.42, raio+0.05), Vector3(1.0, altura*0.8, 0.08), "kit_vermelho", false, n)
	porta.name = "PortaDePele"
	totem_caveira(n, Vector3(0.9, altura*0.85, raio+0.2), 0.5)
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = raio
	s.height = altura*2
	c.shape = s
	b.position = Vector3(0, altura, 0)
	b.add_child(c)
	n.add_child(b)

func salao_guerra(n: Node3D, largura: float, comprimento: float) -> void:
	# Salao comprido de toras com telhado de duas aguas de palha, chifres na cumeeira e fogo na entrada.
	var h := 3.2
	for x in [-largura*0.5, largura*0.5]:
		for i in int(comprimento/0.45):
			var z := -comprimento*0.5 + i*0.45
			malha(n, cilindro(0.2,0.22,1.0,6), Vector3(x, h*0.5, z), art.materials.wood, Vector3.ZERO, Vector3(1, h, 1))
	for z in [-comprimento*0.5, comprimento*0.5]:
		art.box(Vector3(0, h*0.5, z), Vector3(largura, h, 0.35), "brown_planks_03", false, n)
	art.box(Vector3(0, 1.4, comprimento*0.5+0.2), Vector3(2.2, 2.8, 0.2), "kit_vermelho", false, n)
	var cume := h + largura*0.45
	for side in [-1,1]:
		var t = art.box(Vector3(side*largura*0.27, (h+cume)*0.5, 0), Vector3(largura*0.62, 0.3, comprimento+1.6), "kit_palha", false, n)
		t.rotation.z = -side*atan2(cume-h, largura*0.5)
	for z in [-comprimento*0.5-0.1, comprimento*0.5+0.1]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for p in [Vector3(-largura*0.5,h,z), Vector3(0,cume,z), Vector3(largura*0.5,h,z)]:
			st.add_vertex(p)
		st.generate_normals()
		var m: StandardMaterial3D = art.materials.brown_planks_03.duplicate()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		malha(n, st.commit(), Vector3.ZERO, m)
		# chifres cruzados na cumeeira
		for side in [-1,1]:
			art._beam(Vector3(0,cume,z), Vector3(side*1.4,cume+1.6,z+signf(z)*0.4), 0.16, "flower", n)
	art._beam(Vector3(0,cume,-comprimento*0.5-0.8), Vector3(0,cume,comprimento*0.5+0.8), 0.3, "wood", n)
	for x in [-1.8, 1.8]:
		totem(n, Vector3(x, 0, comprimento*0.5+1.6), 3.0)
	colisao_caixa(n, Vector3(0, h*0.5+0.5, 0), Vector3(largura+0.4, h+1, comprimento))

# ------------------------------------------------------------------ Cidade Fantasma
func capela_ruina(n: Node3D) -> void:
	# Capela gotica em ruinas: nave sem teto, paredes quebradas com janelas em arco, torre partida.
	var W := 8.0
	var L := 16.0
	var h := 6.0
	for side in [-1,1]:
		for i in 8:
			var z := -L*0.5 + 1.0 + i*2.0
			var hh: float = h if rng.randf() > 0.35 else rng.randf_range(1.5, 4.0)
			if i % 2 == 1:
				art.box(Vector3(side*W*0.5, hh*0.5, z), Vector3(0.8, hh, 2.0), "castle_brick_01", false, n)
			else:
				art.box(Vector3(side*W*0.5, 1.0, z), Vector3(0.8, 2.0, 2.0), "castle_brick_01", false, n)
				if hh > 4.0:
					art.box(Vector3(side*W*0.5, h-0.5, z), Vector3(0.8, 1.0, 2.0), "castle_brick_01", false, n)
					var vit = art.box(Vector3(side*W*0.5, 3.6, z), Vector3(0.15, 2.4, 1.2), "glow", false, n)
					vit.material_override = cor("6b5bd6", 1.4)
	# fachada com portal em arco e rosacea
	for x in [-3.0, 3.0]:
		art.box(Vector3(x, h*0.6, L*0.5), Vector3(2.0, h*1.2, 0.9), "castle_brick_01", false, n)
	art.box(Vector3(0, h, L*0.5), Vector3(4.0, 2.4, 0.9), "castle_brick_01", false, n)
	var ros := TorusMesh.new()
	ros.inner_radius = 0.6
	ros.outer_radius = 0.95
	ros.rings = 20
	ros.ring_segments = 6
	malha(n, ros, Vector3(0, h+0.2, L*0.5+0.5), art.materials.castle_brick_01, Vector3(PI/2,0,0))
	# torre do sino partida
	art.box(Vector3(0, 5.5, -L*0.5-1.5), Vector3(4, 11, 4), "castle_brick_01", false, n)
	for x in [-1.6, 1.6]:
		art.box(Vector3(x, 12.2, -L*0.5-1.5), Vector3(0.8, rng.randf_range(1.0,3.0), 4), "castle_brick_01", false, n)
	var sino := malha(n, cilindro(0.3, 0.7, 1.0, 10), Vector3(0, 11.6, -L*0.5-1.5), art.materials.iron)
	sino.rotation.z = 0.3
	# entulho, bancos tombados, altar
	for i in 30:
		var e = art.box(Vector3(rng.randf_range(-W*0.6,W*0.6), 0.2, rng.randf_range(-L*0.5,L*0.6)), Vector3(rng.randf_range(0.3,1.0),rng.randf_range(0.2,0.6),rng.randf_range(0.3,0.9)), "castle_brick_01", false, n)
		e.rotation = Vector3(rng.randf()*0.3, rng.randf()*TAU, 0)
	for i in 5:
		var b = art.box(Vector3(rng.randf_range(-2,2), 0.25, -4+i*2.2), Vector3(2.4,0.12,0.5), "wood", false, n)
		b.rotation = Vector3(rng.randf_range(-0.4,0.4), rng.randf_range(-0.5,0.5), rng.randf_range(-0.3,0.3))
	art.box(Vector3(0, 0.6, -L*0.5+1.2), Vector3(2.4, 1.2, 1.0), "castle_brick_01", false, n)
	luz(n, Vector3(0, 2.0, -L*0.5+1.4), Color("8c7bff"), 2.5, 9.0)
	colisao_caixa(n, Vector3(-W*0.5, 2, 0), Vector3(0.8, 4, L))
	colisao_caixa(n, Vector3(W*0.5, 2, 0), Vector3(0.8, 4, L))
	colisao_caixa(n, Vector3(0, 5.5, -L*0.5-1.5), Vector3(4, 11, 4))

func lapide(n: Node3D, p: Vector3, tipo: int) -> void:
	var r := rng.randf_range(-0.25, 0.25)
	match tipo % 3:
		0:
			var l = art.box(p+Vector3(0,0.45,0), Vector3(0.6,0.9,0.16), "lichen_rock", false, n)
			l.rotation = Vector3(rng.randf_range(-0.15,0.15), r, rng.randf_range(-0.12,0.12))
			var topo := malha(n, cilindro(0.3,0.3,0.16,10), p+Vector3(0,0.9,0), art.materials.lichen_rock, Vector3(PI/2, 0, 0))
			topo.rotation.y = r
		1:
			art.box(p+Vector3(0,0.6,0), Vector3(0.14,1.2,0.14), "lichen_rock", false, n).rotation.z = rng.randf_range(-0.2,0.2)
			art.box(p+Vector3(0,0.85,0), Vector3(0.6,0.14,0.14), "lichen_rock", false, n).rotation.y = r
		2:
			art.box(p+Vector3(0,0.15,0), Vector3(0.8,0.3,1.6), "castle_brick_01", false, n).rotation.y = r
			art.box(p+Vector3(0,0.5,-0.7), Vector3(0.7,0.6,0.15), "lichen_rock", false, n).rotation.y = r
	# terra revolvida
	art.box(p+Vector3(0,0.02,0.7), Vector3(0.7,0.06,1.2), "soil", false, n).rotation.y = r

func lanterna_espectral(n: Node3D, p: Vector3) -> void:
	art.box(p+Vector3(0,1.3,0), Vector3(0.14,2.6,0.14), "iron", false, n)
	art._beam(p+Vector3(0,2.5,0), p+Vector3(0.5,2.5,0), 0.07, "iron", n)
	var g = art.box(p+Vector3(0.5,2.15,0), Vector3(0.24,0.34,0.24), "glow", false, n)
	g.material_override = cor("7fe0ff", 2.5)
	luz(n, p+Vector3(0.5,2.0,0.2), Color("8fd8ff"), 1.8, 7.0)
