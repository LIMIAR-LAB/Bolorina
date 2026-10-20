extends RefCounted
## Placa de madeira com texto (saidas entre areas). Mesmo material de madeira do kit.
static func criar(art, parent: Node3D, pos: Vector3, texto: String, cor := Color("f1e2bd")) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "Placa"
	n.position = pos
	parent.add_child(n)
	art.box(Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), "brown_planks_03", false, n)  # sem colisao: placa de saida nao pode travar quem anda para o portao
	var tabua: MeshInstance3D = art.box(Vector3(0, 1.05, 0.02), Vector3(1.25, 0.42, 0.07), "brown_planks_03", false, n)
	tabua.rotation.z = 0.03
	art.box(Vector3(0, 1.28, 0.02), Vector3(1.3, 0.05, 0.09), "brown_planks_03", false, n)
	var l: Label3D = Label3D.new()
	l.text = texto
	l.font_size = 46
	l.pixel_size = 0.0055
	l.outline_size = 10
	l.modulate = cor
	l.outline_modulate = Color(0.12, 0.07, 0.03, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = Vector3(0, 1.62, 0)
	l.shaded = false
	n.add_child(l)
	return n
