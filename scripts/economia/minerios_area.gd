extends Node3D
## Nos de minerio mineraveis numa area (montado por jogo_ilha.gd ao trocar de area).
## Onde: marcadores "minerio_<metal>[_n]" da cena (mapas da Bolorina) ou data/minerios.json (lista de metais em volta
## do ponto de chegada). E perto: minera com a picareta (prata de tumulo pede a picareta de ferro); cada no da
## 1-2 minerios + chance de carvao e volta no dia seguinte (estado.extras.minerios = {chave: dia}).
const Itens = preload("res://scripts/economia/itens.gd")
const DADOS := "res://data/minerios.json"
const RAIO := 1.6
const COR := {"cobre": Color("b8622e"), "ferro": Color("7c8494"), "prata": Color("c8d4ec"), "prata_tumular": Color("c8d4ec")}
var g                      # gerenciador (jogo_ilha)
var area_id := ""
var nos: Array = []        # {no, metal, chave, rotulo}
var ultima := ""

func montar(gerenciador, area: Node, id: String, jogador: Node3D) -> void:
	g = gerenciador
	area_id = id
	name = "MineriosArea"
	var pontos: Array = []
	for n in _marcadores(area):
		var partes := String(n.name).split("_")
		var metal := partes[1] if partes.size() > 1 else "cobre"
		pontos.append({"metal": metal, "pos": (n as Node3D).global_position})
	if pontos.is_empty() and jogador:
		var d = JSON.parse_string(FileAccess.get_file_as_string(DADOS)) if FileAccess.file_exists(DADOS) else null
		var lista: Array = d.get("areas", {}).get(id, []) if d is Dictionary else []
		for i in lista.size():
			var ang := -0.6 + i * 0.75
			var p := jogador.global_position + Vector3(cos(ang), 0, sin(ang)) * (4.0 + (i % 2))
			pontos.append({"metal": String(lista[i]), "pos": _chao(area, p)})
	for i in pontos.size():
		_criar(String(pontos[i].metal), pontos[i].pos, "%s_%d" % [id, i])

func _marcadores(area: Node) -> Array:
	var out: Array = []
	for n in area.find_children("minerio_*", "Node3D", true, false):
		out.append(n)
	return out

func _chao(area: Node, p: Vector3) -> Vector3:
	var w: World3D = area.get_viewport().get_world_3d() if area.get_viewport() else null
	if w == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 6, 0), p + Vector3(0, -12, 0))
	var r := w.direct_space_state.intersect_ray(q)
	return r.position if r.has("position") else p

func _criar(metal: String, pos: Vector3, chave: String) -> void:
	var n := Node3D.new()
	n.name = "Minerio_" + chave
	add_child(n)
	n.global_position = pos
	for k in 3:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.32 - k * 0.06
		sm.height = 0.5 - k * 0.08
		sm.radial_segments = 6
		sm.rings = 3
		m.mesh = sm
		m.position = Vector3((k - 1) * 0.28, 0.2 + (k % 2) * 0.08, (k % 2) * 0.18)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("5f5a58") if k != 1 else COR.get(metal, Color.WHITE)
		mat.roughness = 0.85
		if k == 1:
			mat.metallic = 0.6
			mat.emission_enabled = true
			mat.emission = COR.get(metal, Color.WHITE) * 0.25
		m.material_override = mat
		n.add_child(m)
	var r := Label3D.new()
	r.text = "%s\nE: minerar" % Itens.nome("minerio_" + metal)
	r.font_size = 30
	r.pixel_size = 0.0045
	r.outline_size = 8
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r.no_depth_test = true
	r.position = Vector3(0, 1.2, 0)
	r.visible = false
	n.add_child(r)
	nos.append({"no": n, "metal": metal, "chave": chave, "rotulo": r})
	_atualizar(nos.size() - 1)

func _estado():
	return g.estado if g else null

func disponivel(i: int) -> bool:
	var e = _estado()
	if e == null:
		return false
	var feitos: Dictionary = e.extras.get("minerios", {})
	return int(feitos.get(String(nos[i].chave), -1)) != int(e.dia)

func _atualizar(i: int) -> void:
	var n: Node3D = nos[i].no
	n.visible = disponivel(i)

func perto() -> int:
	var j = g._jogador_atual() if g else null
	if not (j is Node3D):
		return -1
	for i in nos.size():
		var n: Node3D = nos[i].no
		if n.visible and Vector2(n.global_position.x - j.global_position.x, n.global_position.z - j.global_position.z).length() < RAIO:
			return i
	return -1

## minera o no i; devolve a mensagem
func minerar(i: int) -> String:
	var e = _estado()
	if e == null or i < 0 or i >= nos.size() or not disponivel(i):
		return ""
	var metal := String(nos[i].metal)
	if metal in ["prata", "prata_tumular"] and e.qtd("picareta_ferro") <= 0:
		ultima = "A prata de túmulo só sai com a picareta de ferro (Gaspar Bigorna, na Ferraria do Porto, ou Seu Tião)."
		return ultima
	var qtd := 1 + int((int(e.dia) + i) % 2 == 0)
	e.somar("minerio_" + metal, qtd)
	var extra := ""
	if (int(e.dia) * 3 + i) % 3 == 0:
		e.somar("carvao", 1)
		extra = " e 1 carvão"
	var feitos: Dictionary = e.extras.get("minerios", {})
	feitos[String(nos[i].chave)] = int(e.dia)
	e.extras["minerios"] = feitos
	e.salvar()
	_atualizar(i)
	ultima = "+%d %s%s." % [qtd, Itens.nome("minerio_" + metal), extra]
	return ultima

func _process(_d: float) -> void:
	var i := perto()
	for k in nos.size():
		nos[k].rotulo.visible = k == i

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or event.physical_keycode != KEY_E:
		return
	var i := perto()
	if i < 0:
		return
	get_viewport().set_input_as_handled()
	var msg := minerar(i)
	var area = g.atual if g else null
	if area and area.get("message") is Label and msg != "":
		area.message.text = msg
