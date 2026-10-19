extends RefCounted
## Protecao contra quedas (19/10): a grade andavel V7 tinha celulas vizinhas do abismo (h -30) e da
## borda do terreno; como os vertices ficam no centro das celulas, meia celula depois ja e penhasco.
## 1) remove da grade andavel as celulas com queda (> QUEDA m) em qualquer das 8 vizinhas ou na borda;
## 2) borda NATURAL na beira (rochas, arbustos escuros, arvores de outono, pilares de ruina) nas
##    celulas da beirada; 3) parede invisivel fina so como reserva atras dessa borda.
## Desligar: "abismo_v1": true (fidelidade-camera.json ou FID_CONFIG_EXTRA).
const QUEDA := 1.5
const ALTURA := 4.0
var removidas := {}
var paredes: Array[Dictionary] = []   # {pos: Vector3, eixo: String}
var raiz: Node3D

func _h(v, c: Vector2i) -> float:
	var ix: int = c.x - v.origem.x
	var iz: int = c.y - v.origem.y
	if ix < 0 or iz < 0 or ix >= v.tam.x or iz >= v.tam.y:
		return -1000.0
	return float(v.alturas[iz][ix])

func _queda(v, c: Vector2i) -> bool:
	var h := _h(v, c)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var n := Vector2i(c.x + dx, c.y + dz)
			if _h(v, n) < h - QUEDA:
				return true
	return false

## filtra 'andaveis' (Dictionary celula->true) e devolve o novo conjunto
func filtrar(v, andaveis: Dictionary) -> Dictionary:
	var r := {}
	for c in andaveis:
		if _h(v, c) > -999.0 and _queda(v, c):
			removidas[c] = true
		else:
			r[c] = true
	return r

func construir(v, parent: Node3D, seguras: Dictionary, visivel := false) -> Node3D:
	raiz = Node3D.new()
	raiz.name = "BarreirasAbismo"
	parent.add_child(raiz)
	var mat: StandardMaterial3D
	if visivel:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for c in seguras:
		var h := _h(v, c)
		if h < -999.0:
			continue
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = c + d
			if seguras.has(n):
				continue
			# so onde ha queda (celula removida, abismo, borda do terreno)
			if not (removidas.has(n) or _h(v, n) < h - QUEDA or _queda(v, n)):
				continue
			var pos := Vector3(c.x + d.x*0.5, h + ALTURA*0.5 - 0.6, c.y + d.y*0.5)
			var tam := Vector3(0.12, ALTURA, 1.04) if d.x != 0 else Vector3(1.04, ALTURA, 0.12)
			var body := StaticBody3D.new()
			body.name = "Barreira"
			body.set_meta("barreira_abismo", true)
			body.position = pos
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = tam
			cs.shape = bs
			body.add_child(cs)
			raiz.add_child(body)
			if visivel:
				var m := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(tam.x, 1.2, tam.z)
				m.mesh = bm
				m.material_override = mat
				m.position.y = -ALTURA*0.5 + 0.6 + 0.6
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				body.add_child(m)
			paredes.append({"pos": pos, "celula": c, "dir": d})
	return raiz

## borda natural: pecas do kit nas celulas da beirada (removidas, com piso proprio), vizinhas da grade segura
const PORTAL_RUINAS := [Vector2i(-9, -20), Vector2i(-3, -20)]
func decorar(v, parent: Node3D, seguras: Dictionary) -> Node3D:
	var n0 := Node3D.new()
	n0.name = "BordaNatural"
	parent.add_child(n0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1910
	var ocupado: Array[Vector3] = []
	for p in v.lista_pecas:
		ocupado.append(p.position)
	var borda: Array = []
	for c in removidas:
		var perto := false
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if seguras.has(c + d):
				perto = true
		if perto:
			borda.append(c)
	borda.sort()
	var i := 0
	for c in borda:
		var pos := Vector3(c.x, _h(v, c), c.y)
		var livre := true
		for o in ocupado:
			if Vector2(o.x - pos.x, o.z - pos.z).length() < 1.3:
				livre = false
				break
		if not livre:
			continue
		var id := "arbusto_escuro"
		if PORTAL_RUINAS.has(c):
			id = "ruina_pilar"
		else:
			var r := rng.randf()
			if r < 0.12:
				id = "arvore_outono" if rng.randf() < 0.6 else "arvore_escura"
			elif r < 0.45:
				id = "rocha"
			elif r < 0.55:
				id = "arbusto_flor"
		var peca: Node3D = v.kit.make(id)
		peca.position = pos
		peca.rotation.y = rng.randi_range(0, 3) * PI * 0.5
		peca.scale = Vector3.ONE * rng.randf_range(0.9, 1.25)
		n0.add_child(peca)
		ocupado.append(pos)
		i += 1
	n0.set_meta("pecas", i)
	return n0
