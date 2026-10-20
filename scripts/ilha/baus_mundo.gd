extends Node3D
## Baus no mundo (fazenda e fazenda grande, inclusive dentro da casa da Vale) + modo de colocar.
## Criado pelo jogo_ilha.gd ao entrar numa area de Inv.AREAS_BAU (filho da area, como os minerios).
## E perto de um bau: abre a tela do bau (inventario_tela.gd). O bau que ja enfeitava a Casa da Vale
## (interiores.gd, sala 0) passa a guardar coisas tambem (id "casa_vale", fixo).
## Colocar (Inventario > Fabricar > Colocar bau): bau-fantasma na celula a frente da Vale (ou sob o mouse,
## como o cursor das ferramentas); verde = livre. Clique/E/J/Enter coloca, Esc/botao direito cancela.
## Modelo: caixas por codigo no estilo do bau da casa (madeira escura, tampa clara, cintas de ferro, fecho dourado).
const Inv = preload("res://scripts/ilha/inventario.gd")
const DIST := 1.45
var jogo
var area_no
var area_id := ""
var jogador: Node3D
var nos := {}            # id do bau -> Node3D
var casa_no: Node3D      # movel "bau" da Casa da Vale (sala 0)
var colocando := false
var fantasma: Node3D
var mat_ok: StandardMaterial3D
var mat_nao: StandardMaterial3D
var alvo := Vector3.ZERO
var alvo_ok := false
var alvo_motivo := ""
var dica: Label3D
var aberto_id := ""
var _mats := {}

func montar(j, area, id: String, player: Node3D) -> void:
	jogo = j
	area_no = area
	area_id = id
	jogador = player
	name = "BausMundo"
	for b in jogo.estado.baus:
		if String(b.area) == area_id:
			_criar(b)
	_achar_casa()
	dica = Label3D.new()
	dica.text = "E: abrir baú"
	dica.font_size = 36
	dica.pixel_size = 0.005
	dica.outline_size = 8
	dica.modulate = Color("fff1b8")
	dica.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dica.no_depth_test = true
	dica.shaded = false
	dica.visible = false
	add_child(dica)

# ---------------------------------------------------------------- modelo
func _mat(nome: String, cor: Color) -> StandardMaterial3D:
	if not _mats.has(nome):
		var m := StandardMaterial3D.new()
		m.albedo_color = cor
		m.roughness = 0.95
		_mats[nome] = m
	return _mats[nome]

func _caixa(pai: Node3D, pos: Vector3, tam: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = tam
	mi.mesh = bx
	mi.material_override = m
	mi.position = pos
	pai.add_child(mi)
	return mi

## origem no chao, frente = +Z. sobrepor: material unico (fantasma)
func modelo(sobrepor: Material = null) -> Node3D:
	var n := Node3D.new()
	var md: Material = sobrepor if sobrepor else _mat("escura", Color("5c3a22"))
	var cl: Material = sobrepor if sobrepor else _mat("clara", Color("9a6a3c"))
	var fe: Material = sobrepor if sobrepor else _mat("ferro", Color("4a4a54"))
	var ou: Material = sobrepor if sobrepor else _mat("ouro", Color("e0b040"))
	_caixa(n, Vector3(0, 0.24, 0), Vector3(0.84, 0.46, 0.56), md)
	for x in [-0.27, 0.27]:
		_caixa(n, Vector3(x, 0.25, 0), Vector3(0.07, 0.48, 0.59), fe)
	# tampa com dobradica atras (abre ao usar)
	var tampa := Node3D.new()
	tampa.name = "Tampa"
	tampa.position = Vector3(0, 0.47, -0.29)
	n.add_child(tampa)
	_caixa(tampa, Vector3(0, 0.07, 0.29), Vector3(0.88, 0.14, 0.6), cl)
	for x in [-0.27, 0.27]:
		_caixa(tampa, Vector3(x, 0.075, 0.29), Vector3(0.07, 0.15, 0.62), fe)
	_caixa(tampa, Vector3(0, 0.0, 0.6), Vector3(0.11, 0.13, 0.04), ou)
	if sobrepor == null:
		var corpo := StaticBody3D.new()
		corpo.name = "Corpo"
		corpo.set_meta("bau", true)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.86, 0.6, 0.58)
		cs.shape = sh
		cs.position.y = 0.3
		corpo.add_child(cs)
		n.add_child(corpo)
	return n

func _criar(b: Dictionary) -> Node3D:
	var n := modelo()
	n.name = "Bau_" + String(b.id)
	n.set_meta("bau_id", String(b.id))
	var p: Array = b.pos
	n.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	n.rotation.y = float(b.get("rot", 0.0))
	_pai().add_child(n)
	nos[String(b.id)] = n
	return n

func _pai() -> Node3D:
	var gr = area_no.get("ground") if area_no else null
	return gr if gr is Node3D else self

func _achar_casa() -> void:
	var it = area_no.get("interiores") if area_no else null
	if it == null or not it.has_method("moveis") or it.salas.is_empty():
		return
	for m in it.moveis(0):
		if String(m.get_meta("modulo", "")) == "bau":
			casa_no = m
			return

# ---------------------------------------------------------------- consulta
func _dentro() -> bool:
	var it = area_no.get("interiores") if area_no else null
	return it != null and int(it.ativo) >= 0

func _xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## [id, no] do bau mais perto da Vale (dentro de DIST), ou ["", null]
func perto() -> Array:
	if jogador == null:
		return ["", null]
	var melhor := ""
	var no: Node3D = null
	var d := DIST
	var dentro := _dentro()
	for id in nos:
		var n: Node3D = nos[id]
		if not is_instance_valid(n):
			continue
		var dd := _xz(n.global_position, jogador.global_position)
		if dd < d and absf(n.global_position.y - jogador.global_position.y) < 1.5:
			d = dd
			melhor = id
			no = n
	if casa_no and dentro and int(area_no.interiores.ativo) == 0:
		var dc := _xz(casa_no.global_position, jogador.global_position)
		if dc < d:
			melhor = Inv.ID_CASA
			no = casa_no
	return [melhor, no]

func _process(_d: float) -> void:
	if get_tree().paused:
		dica.visible = false
		return
	if colocando:
		_atualizar_fantasma()
		dica.visible = false
		return
	var p := perto()
	dica.visible = p[1] != null
	if p[1] != null:
		dica.global_position = (p[1] as Node3D).global_position + Vector3(0, 1.15, 0)
		dica.text = "E: abrir %s" % ("o baú da casa" if p[0] == Inv.ID_CASA else "o baú")

# ---------------------------------------------------------------- abrir
func abrir(id: String) -> bool:
	var b: Dictionary = Inv.bau_casa(jogo.estado) if id == Inv.ID_CASA else Inv.achar(jogo.estado, id)
	if b.is_empty() or jogo.get("inventario_tela") == null:
		return false
	aberto_id = id
	_tampa(id, true)
	jogo.inventario_tela.abrir_bau(b, self)
	return true

func fechou(_b: Dictionary) -> void:
	_tampa(aberto_id, false)
	aberto_id = ""

func removido(id: String) -> void:
	if nos.has(id):
		var n: Node3D = nos[id]
		nos.erase(id)
		if is_instance_valid(n):
			n.queue_free()
	_msg("Baú recolhido: voltou para a mochila.")

func _tampa(id: String, abrir_tampa: bool) -> void:
	var n: Node3D = nos.get(id, null)
	if n and is_instance_valid(n) and n.has_node("Tampa"):
		(n.get_node("Tampa") as Node3D).rotation.x = -1.15 if abrir_tampa else 0.0

func _msg(t: String) -> void:
	if area_no and area_no.get("message") is Label:
		area_no.message.text = t

# ---------------------------------------------------------------- colocar
func iniciar_colocacao() -> void:
	if int(jogo.estado.qtd("bau")) <= 0:
		_msg("Sem baú na mochila. Fabrique um no inventário (aba Fabricar).")
		return
	colocando = true
	if mat_ok == null:
		mat_ok = StandardMaterial3D.new()
		mat_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_ok.albedo_color = Color(0.45, 1.0, 0.45, 0.55)
		mat_nao = mat_ok.duplicate()
		mat_nao.albedo_color = Color(1.0, 0.35, 0.3, 0.55)
	if fantasma == null:
		fantasma = modelo(mat_ok)
		fantasma.name = "BauFantasma"
		_pai().add_child(fantasma)
	fantasma.visible = true
	_atualizar_fantasma()
	_msg("Colocar baú: clique, E, J ou Enter coloca · Esc ou botão direito cancela.")

func cancelar() -> void:
	colocando = false
	if fantasma:
		fantasma.visible = false
	_msg("Colocação cancelada. O baú continua na mochila.")

func _celula_alvo() -> Vector2i:
	var ui = area_no.get("ui")
	if ui and ui.has_method("calcular_alvo") and not _dentro():
		return ui.calcular_alvo()
	var f: Vector3 = area_no.get("facing") if area_no.get("facing") is Vector3 else Vector3(0, 0, 1)
	var v := Vector2(f.x, f.z)
	if v.length() < 0.1:
		v = Vector2(0, 1)
	var p := Vector2(jogador.global_position.x, jogador.global_position.z) + v.normalized() * 1.0
	return Vector2i(roundi(p.x), roundi(p.y))

func _chao(c: Vector2i) -> float:
	if _dentro():
		return jogador.global_position.y - 0.4
	var v = area_no.get("vila")
	if v and v.has_method("altura"):
		return float(v.altura(float(c.x), float(c.y)))
	return jogador.global_position.y - 0.4

## "" = livre; senao o motivo
func livre(c: Vector2i) -> String:
	var y := _chao(c)
	var cells = area_no.get("cells")
	if cells is Array and not cells.has(c):
		return "Fora da área."
	if not _dentro():
		if y < -0.3:
			return "Água."
		var det = area_no.get("detritos")
		if det and det.has_method("em") and det.em(c):
			return "Tem algo no chão (use a ferramenta antes)."
		var so = area_no.get("solo")
		if so and so.has_method("tem") and so.tem(c):
			return "Terra arada."
	var pc := Vector2(jogador.global_position.x, jogador.global_position.z)
	if pc.distance_to(Vector2(c.x, c.y)) < 0.55:
		return "A Vale está em cima."
	for id in nos:
		var n: Node3D = nos[id]
		if is_instance_valid(n) and Vector2(n.global_position.x, n.global_position.z).distance_to(Vector2(c.x, c.y)) < 0.6:
			return "Já tem um baú aqui."
	if casa_no and _dentro() and Vector2(casa_no.global_position.x, casa_no.global_position.z).distance_to(Vector2(c.x, c.y)) < 0.8:
		return "Já tem um baú aqui."
	# casa, poco, cercas, moveis, caixa de envio: teste fisico na celula (como fazenda_ui.aravel)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.7, 0.55, 0.7)
	q.shape = bx
	q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, y + 0.45, c.y))
	if jogador is CollisionObject3D:
		q.exclude = [(jogador as CollisionObject3D).get_rid()]
	for r in space.intersect_shape(q, 6):
		var col = r.collider
		if col and col.name != "TerrenoModular" and not (col.get_parent() and col.get_parent().name == "TerrenoModular"):
			return "Lugar ocupado."
	return ""

func _atualizar_fantasma() -> void:
	if fantasma == null or jogador == null:
		return
	var c := _celula_alvo()
	alvo = Vector3(c.x, _chao(c), c.y)
	alvo_motivo = livre(c)
	alvo_ok = alvo_motivo == ""
	fantasma.global_position = alvo
	fantasma.rotation.y = _rot_para_vale(alvo)
	var m: Material = mat_ok if alvo_ok else mat_nao
	for mi in fantasma.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m

## a frente do bau vira para o lado da Vale (passo de 90 graus)
func _rot_para_vale(p: Vector3) -> float:
	var d := Vector2(jogador.global_position.x - p.x, jogador.global_position.z - p.z)
	if d.length() < 0.01:
		return 0.0
	return snappedf(atan2(d.x, d.y), PI / 2.0)

func confirmar() -> bool:
	if not colocando:
		return false
	_atualizar_fantasma()
	if not alvo_ok:
		_msg("Não dá para colocar aqui: %s" % alvo_motivo)
		return false
	var b := Inv.colocar(jogo.estado, area_id, alvo, _rot_para_vale(alvo))
	if b.is_empty():
		cancelar()
		return false
	_criar(b)
	jogo.estado.salvar()
	colocando = false
	fantasma.visible = false
	_msg("Baú colocado! E perto dele para abrir. (%d baú(s) ainda na mochila)" % int(jogo.estado.qtd("bau")))
	var ui = area_no.get("ui")
	if ui and ui.has_method("atualizar"):
		ui.atualizar()
	return true

# ---------------------------------------------------------------- entrada
func _unhandled_key_input(event: InputEvent) -> void:
	if get_tree().paused or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = event.physical_keycode
	if colocando:
		if k in [KEY_E, KEY_J, KEY_ENTER, KEY_KP_ENTER]:
			confirmar()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			cancelar()
			get_viewport().set_input_as_handled()
		return
	if k == KEY_E:
		var p := perto()
		if p[1] != null and abrir(String(p[0])):
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not colocando or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			confirmar()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancelar()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			confirmar()
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_B:
			cancelar()
			get_viewport().set_input_as_handled()
