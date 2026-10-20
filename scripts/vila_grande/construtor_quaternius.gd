extends RefCounted
## Monta construcoes a partir do kit modular CC0 "Medieval Village MegaKit" (Quaternius),
## ja recolorido para a paleta do projeto (art/models/quaternius_vila_medieval/).
## Grade do kit: paredes de 2 m de largura x 3 m de altura; face externa em +z local.
## Origem da construcao = centro da pegada no chao; fachada principal (porta) em +z.
const PASTA := "res://art/models/quaternius_vila_medieval/"
const ALTURA_ANDAR := 3.0
var cache := {}
var art   # VisualWorld (materiais compartilhados: castle_brick_01, wood, glow...)

func _init(world = null) -> void:
	art = world

func peca(nome: String) -> Node3D:
	if not cache.has(nome):
		cache[nome] = load(PASTA + nome + ".gltf")
	var n: Node3D = cache[nome].instantiate()
	n.name = nome
	return n

func _por(pai: Node3D, nome: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n := peca(nome)
	n.position = pos
	n.rotation.y = rot_y
	pai.add_child(n)
	return n

## d: {"largura":6,"profundidade":8,"andares":2,"terreo":"tijolo"|"reboco","superior":"enxaimel"|"reboco",
##     "chamine":true,"trepadeira":true,"janelas_fundo":false,"porta_lateral":false}
func construir(d: Dictionary) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = String(d.get("nome", "Construcao"))
	var W := int(d.get("largura", 6))
	var D := int(d.get("profundidade", 8))
	var andares := int(d.get("andares", 1))
	var terreo := String(d.get("terreo", "tijolo"))
	var superior := String(d.get("superior", "enxaimel"))
	var hw := W*0.5
	var hd := D*0.5
	## ruina: sem telhado, paredes faltando, entulho (usado na Cidade Fantasma)
	var ruina := bool(d.get("ruina", false))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(raiz.name)
	# base de pedra (assenta no relevo)
	if art:
		art.box(Vector3(0,-0.2,0), Vector3(W+0.5,0.6,D+0.5), "castle_brick_01", false, raiz)
	for a in andares:
		var y := a*ALTURA_ANDAR
		var estilo := terreo if a == 0 else superior
		# 4 fachadas: [rotacao, n_segmentos, funcao posicao(i)]
		for lado in 4:
			var rot: float = [0.0, PI/2, PI, -PI/2][lado]
			var n_seg := (W if lado % 2 == 0 else D)/2
			for i in n_seg:
				var u := -float(n_seg) + 1.0 + 2.0*i   # centro do segmento ao longo da fachada
				if ruina and rng.randf() < (0.22 if a == 0 else 0.55):
					continue
				var tipo: Array = _tipo_parede(estilo, a, lado, i, n_seg, d)
				var local := Vector3(u, y, (hd if lado % 2 == 0 else hw) - 0.09)
				var pos := local.rotated(Vector3.UP, rot)
				_por(raiz, tipo[0], pos, rot)
				if tipo[1] != "":
					_por(raiz, tipo[1], pos, rot)
				if tipo.size() > 2 and tipo[2] != "":
					_por(raiz, tipo[2], pos, rot)
		for cx in [-hw, hw]:
			for cz in [-hd, hd]:
				_por(raiz, "Corner_Exterior_Wood", Vector3(cx, y, cz))
	var topo := andares*ALTURA_ANDAR
	var nome_tel := "Roof_RoundTiles_%dx%d" % [W, D]
	if ruina:
		for k in 14:
			if art:
				var e = art.box(Vector3(rng.randf_range(-hw-1.5,hw+1.5),0.15,rng.randf_range(-hd-1.5,hd+1.5)), Vector3(rng.randf_range(0.3,0.9),rng.randf_range(0.2,0.5),rng.randf_range(0.3,0.8)), "castle_brick_01", false, raiz)
				e.rotation.y = rng.randf()*TAU
		for k in 4:
			if art:
				art._beam(Vector3(rng.randf_range(-hw,hw),0.1,rng.randf_range(-hd,hd)), Vector3(rng.randf_range(-hw,hw),rng.randf_range(0.3,2.5),rng.randf_range(-hd,hd)), 0.2, "wood", raiz)
	elif ResourceLoader.exists(PASTA + nome_tel + ".gltf"):
		_por(raiz, nome_tel, Vector3(0, topo, 0))
		var oit := "Roof_Front_Brick%d" % W
		if ResourceLoader.exists(PASTA + oit + ".gltf"):
			_por(raiz, oit, Vector3(0, topo, hd-0.09))
			_por(raiz, oit, Vector3(0, topo, -hd+0.09), PI)
	if bool(d.get("chamine", true)) and not ruina:
		_por(raiz, "Prop_Chimney" if terreo == "tijolo" else "Prop_Chimney2", Vector3(hw-1.2, topo-0.5, -hd*0.35))
	if bool(d.get("trepadeira", false)):
		_por(raiz, "Prop_Vine1", Vector3(-hw+1.0, 2.8, hd+0.12))
		_por(raiz, "Prop_Vine4", Vector3(hw+0.12, 2.6, hd-1.5), PI/2)
	# colisao simples da pegada
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(W, topo+1.0, D)
	col.shape = caixa
	col.position = Vector3(0, (topo+1.0)*0.5, 0)
	corpo.add_child(col)
	raiz.add_child(corpo)
	raiz.set_meta("pegada", Vector2(W, D))
	return raiz

## retorna [parede, peca_extra (janela/porta), persiana]
func _tipo_parede(estilo: String, andar: int, lado: int, i: int, n_seg: int, d: Dictionary) -> Array:
	var pref := "Wall_UnevenBrick_" if estilo == "tijolo" else "Wall_Plaster_"
	var meio := n_seg/2
	var frente := lado == 0
	var fundo := lado == 2
	if andar == 0:
		if frente and i == meio:
			return [pref+"Door_Round", "Door_1_Round" if estilo != "tijolo" else "Door_2_Round"]
		if lado == 1 and bool(d.get("porta_lateral", false)) and i == meio:
			return [pref+"Door_Round", "Door_1_Round"]
		if fundo and not bool(d.get("janelas_fundo", false)):
			return [pref+"Straight" if estilo == "tijolo" else "Wall_Plaster_Straight_Base", ""]
		if (i + lado) % 2 == 0:
			return [pref+"Window_Wide_Round", "Window_Wide_Round1", "WindowShutters_Wide_Round_Open"]
		return [pref+"Straight" if estilo == "tijolo" else "Wall_Plaster_Straight_Base", ""]
	# andares superiores
	if estilo == "enxaimel":
		if (i + lado) % 2 == 1 or fundo:
			return ["Wall_Plaster_WoodGrid", ""]
		return ["Wall_Plaster_Window_Thin_Round", "Window_Thin_Round1", "WindowShutters_Thin_Round_Open"]
	if (i + lado) % 2 == 0 and not fundo:
		return [pref+"Window_Thin_Round", "Window_Thin_Round1"]
	return [pref+"Straight", ""]
