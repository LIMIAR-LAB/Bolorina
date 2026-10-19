extends RefCounted
## Cercas modulares em grade (V7): cada cerca e uma polilinha nas BORDAS das celulas de 1 m
## (postes em coordenadas x.5 / z.5), subdividida em vaos de 1 m. Postes em todos os nos
## (canto/ponta = poste reforcado com capitel), 2 travessas por vao ligando os topos dos postes
## (acompanham o declive do terreno), colisao por vao e portoes (vao aberto, folha girada).
## Dados: {"pontos": [[x,z],...], "fechada": bool, "portoes": [indice_do_vao, ...]}
const ALTURA := 1.0
const TRAVESSAS := [0.4, 0.8]
var kit
var vila
var postes: Array[Dictionary] = []   # {pos: Vector3, canto: bool, cerca: int}
var vaos: Array[Dictionary] = []     # {a: Vector3, b: Vector3, portao: bool, cerca: int, travessas: Array}
var raiz: Node3D

func construir(v, parent: Node3D, cercas: Array) -> Node3D:
	vila = v
	kit = v.kit
	raiz = Node3D.new()
	raiz.name = "CercasModulares"
	parent.add_child(raiz)
	for i in cercas.size():
		_cerca(i, cercas[i])
	return raiz

func _y(x: float, z: float) -> float:
	return vila.altura(x, z)

func _cerca(indice: int, c: Dictionary) -> void:
	var pts: Array = c.pontos.duplicate()
	if c.get("fechada", false):
		pts.append(pts[0])
	var portoes: Array = c.get("portoes", [])
	var nos: Array[Vector2] = []
	var cantos := {}
	for k in pts.size() - 1:
		var a := Vector2(float(pts[k][0]), float(pts[k][1]))
		var b := Vector2(float(pts[k+1][0]), float(pts[k+1][1]))
		var n := maxi(1, ceili(a.distance_to(b) - 0.001))
		if nos.is_empty():
			nos.append(a)
		cantos[nos.size() - 1] = true
		for s in range(1, n + 1):
			nos.append(a.lerp(b, float(s) / n))
	cantos[nos.size() - 1] = true
	var fechada: bool = c.get("fechada", false)
	if fechada:
		nos.remove_at(nos.size() - 1)
		cantos[0] = true
	var node := Node3D.new()
	node.name = "Cerca%d" % indice
	raiz.add_child(node)
	var n_vaos := nos.size() if fechada else nos.size() - 1
	var eh_portao := {}
	for p in portoes:
		eh_portao[int(p)] = true
	for i in nos.size():
		var q := nos[i]
		var base := Vector3(q.x, _y(q.x, q.y), q.y)
		var canto: bool = cantos.has(i) or eh_portao.has(i) or eh_portao.has(posmod(i - 1, n_vaos))
		_poste(node, base, canto)
		postes.append({"pos": base, "canto": canto, "cerca": indice})
	for i in n_vaos:
		var a2 := nos[i]
		var b2 := nos[(i + 1) % nos.size()]
		var a := Vector3(a2.x, _y(a2.x, a2.y), a2.y)
		var b := Vector3(b2.x, _y(b2.x, b2.y), b2.y)
		var vao := {"a": a, "b": b, "portao": eh_portao.has(i), "cerca": indice, "travessas": []}
		if vao.portao:
			_portao(node, a, b)
		else:
			for h in TRAVESSAS:
				var ra := a + Vector3(0, h, 0)
				var rb := b + Vector3(0, h, 0)
				kit.beam(node, ra, rb, 0.075, "brown_planks_03")
				vao.travessas.append([ra, rb])
			_colisao(node, a, b)
		vaos.append(vao)

func _poste(node: Node3D, base: Vector3, canto: bool) -> void:
	var w := 0.17 if canto else 0.13
	var h := ALTURA + (0.12 if canto else 0.04)
	# enterrado 0,15 m para nunca flutuar em terreno inclinado
	kit.box(node, base + Vector3(0, (h - 0.15) * 0.5, 0), Vector3(w, h + 0.15, w), "wood")
	if canto:
		kit.box(node, base + Vector3(0, h + 0.03, 0), Vector3(w + 0.06, 0.06, w + 0.06), "wood")

func _colisao(node: Node3D, a: Vector3, b: Vector3) -> void:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	var d := Vector2(b.x - a.x, b.z - a.z)
	forma.size = Vector3(d.length(), ALTURA, 0.16)
	col.shape = forma
	corpo.position = (a + b) * 0.5 + Vector3(0, ALTURA * 0.5, 0)
	corpo.rotation.y = atan2(-d.y, d.x)
	corpo.add_child(col)
	corpo.set_meta("cerca", true)
	node.add_child(corpo)

func _portao(node: Node3D, a: Vector3, b: Vector3) -> void:
	# folha do portao aberta ~100 graus a partir do poste 'a' (vao livre para passar)
	var folha := Node3D.new()
	folha.name = "Portao"
	folha.position = a
	var d := Vector2(b.x - a.x, b.z - a.z)
	folha.rotation.y = atan2(-d.y, d.x) + deg_to_rad(100)
	node.add_child(folha)
	var L := d.length() - 0.16
	for h in [0.3, 0.75]:
		kit.box(folha, Vector3(0.1 + L * 0.5, h, 0), Vector3(L, 0.08, 0.05), "brown_planks_03")
	kit.box(folha, Vector3(0.1 + L - 0.03, 0.52, 0), Vector3(0.07, 0.62, 0.06), "wood")
	kit.beam(folha, Vector3(0.12, 0.3, 0.0), Vector3(0.1 + L - 0.06, 0.75, 0.0), 0.05, "wood")
	kit.box(folha, Vector3(0.1, 0.52, 0.04), Vector3(0.05, 0.08, 0.04), "iron")
