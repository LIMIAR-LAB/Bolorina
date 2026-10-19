extends Node
## Barra de ferramentas (estilo Stardew) + cursor de celula + uso das ferramentas.
## 1-9 / roda do mouse: escolhe o slot | LMB ou J: usa no alvo (celula a frente ou sob o mouse, alcance 1)
const SLOTS := [
	{"id": "enxada", "nome": "Enxada", "cor": Color("b0b6ba")},
	{"id": "picareta", "nome": "Picareta", "cor": Color("9aa3b5")},
	{"id": "machado", "nome": "Machado", "cor": Color("c98a4a")},
	{"id": "foice", "nome": "Foice", "cor": Color("d8d2a0")},
	{"id": "regador", "nome": "Regador", "cor": Color("6fa8d6")},
	{"id": "semente_nabo", "nome": "Sementes de nabo", "cor": Color("e8e1f0")},
	{"id": "semente_couve", "nome": "Sementes de couve", "cor": Color("7fb04a")},
	{"id": "semente_abobora", "nome": "Sementes de abobora", "cor": Color("e39a2e")},
	{"id": "mao", "nome": "Mao (colher)", "cor": Color("e6c9a0")},
]
var g
var camada: CanvasLayer
var caixas: Array[Panel] = []
var contagens: Array[Label] = []
var nome_label: Label
var inv_label: Label
var cursor: Node3D
var cursor_mat: StandardMaterial3D
var alvo := Vector2i.ZERO
var mouse_t := -10.0
var mouse_pos := Vector2.ZERO
var t := 0.0
var cd := 0.0

func montar(game) -> void:
	g = game
	camada = CanvasLayer.new()
	camada.layer = 30
	add_child(camada)
	var w := 9 * 66 + 8 * 6
	var x0 := (1600 - w) / 2
	var fundo := Panel.new()
	fundo.position = Vector2(x0 - 10, 900 - 63 - 90)
	fundo.size = Vector2(w + 20, 82)
	fundo.add_theme_stylebox_override("panel", _estilo(Color(0.16, 0.1, 0.06, 0.88), Color("6b4a2a"), 3))
	camada.add_child(fundo)
	for i in SLOTS.size():
		var p := Panel.new()
		p.position = Vector2(x0 + i * 72, 900 - 63 - 82)
		p.size = Vector2(66, 66)
		camada.add_child(p)
		caixas.append(p)
		var ic := Icone.new()
		ic.id = String(SLOTS[i].id)
		ic.cor = SLOTS[i].cor
		ic.position = Vector2(5, 5)
		ic.size = Vector2(56, 56)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		var n: Label = Label.new()
		n.text = str(i + 1)
		n.position = Vector2(4, 0)
		n.add_theme_font_size_override("font_size", 12)
		n.add_theme_color_override("font_color", Color("f1e2bd"))
		p.add_child(n)
		var c := Label.new()
		c.position = Vector2(30, 44)
		c.size = Vector2(32, 18)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.add_theme_font_size_override("font_size", 13)
		c.add_theme_color_override("font_color", Color.WHITE)
		c.add_theme_color_override("font_shadow_color", Color.BLACK)
		c.add_theme_constant_override("shadow_offset_x", 1)
		c.add_theme_constant_override("shadow_offset_y", 1)
		p.add_child(c)
		contagens.append(c)
	nome_label = _rotulo(Vector2(x0, 900 - 63 - 116), 16)
	inv_label = _rotulo(Vector2(1180, 24), 14)
	inv_label.size = Vector2(400, 120)
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# cursor de celula no chao
	cursor = Node3D.new()
	cursor.name = "CursorCelula"
	g.add_child(cursor)
	cursor_mat = StandardMaterial3D.new()
	cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_mat.albedo_color = Color(1, 1, 1, 0.9)
	cursor_mat.no_depth_test = true
	cursor_mat.render_priority = 2
	for s in [Vector3(0, 0, -0.48), Vector3(0, 0, 0.48)]:
		_barra(s, Vector3(1.0, 0.03, 0.05))
	for s in [Vector3(-0.48, 0, 0), Vector3(0.48, 0, 0)]:
		_barra(s, Vector3(0.05, 0.03, 1.0))
	var fill: MeshInstance3D = MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.92, 0.01, 0.92)
	fill.mesh = q
	var fm := cursor_mat.duplicate()
	fm.albedo_color = Color(1, 1, 1, 0.14)
	fill.material_override = fm
	fill.name = "Preenchimento"
	cursor.add_child(fill)
	atualizar()

func _barra(pos: Vector3, size: Vector3) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = cursor_mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.add_child(m)

func _rotulo(pos: Vector2, tam: int) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color("f1e2bd"))
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	camada.add_child(l)
	return l

func _estilo(bg: Color, borda: Color, w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borda
	s.set_border_width_all(w)
	s.set_corner_radius_all(4)
	return s

func item() -> String:
	return String(SLOTS[g.estado.slot].id)

func selecionar(i: int) -> void:
	g.estado.slot = clampi(i, 0, SLOTS.size() - 1)
	atualizar()

func atualizar() -> void:
	var e = g.estado
	for i in caixas.size():
		var sel: bool = i == e.slot
		caixas[i].add_theme_stylebox_override("panel", _estilo(Color("e8cf98") if sel else Color("c9a46a"), Color("fff1b8") if sel else Color("7a5230"), 4 if sel else 2))
		var id := String(SLOTS[i].id)
		if id.begins_with("semente_"):
			contagens[i].text = str(e.qtd(id))
		elif id == "regador":
			contagens[i].text = "%d" % e.regador
		else:
			contagens[i].text = ""
	nome_label.text = String(SLOTS[e.slot].nome)
	inv_label.text = linha_inventario()

func linha_inventario() -> String:
	var e = g.estado
	return "Dia %d   Ouro %d\nMadeira %d  Pedra %d  Fibra %d\nNabo %d  Couve %d  Abobora %d\nRegador %d/%d" % [e.dia, e.ouro, e.qtd("madeira"), e.qtd("pedra"), e.qtd("fibra"), e.qtd("nabo"), e.qtd("couve"), e.qtd("abobora"), e.regador, e.REGADOR_MAX]

func linha_hud() -> String:
	return "FAZENDA | Dia %d" % g.estado.dia

# ---------------------------------------------------------------- entrada
func entrada(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if event.position.distance_to(mouse_pos) > 2.0:
			mouse_t = t
		mouse_pos = event.position
		return false
	if event is InputEventMouseButton and event.pressed:
		if event.ctrl_pressed:
			return false
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				selecionar((g.estado.slot + SLOTS.size() - 1) % SLOTS.size())
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				selecionar((g.estado.slot + 1) % SLOTS.size())
				return true
			MOUSE_BUTTON_LEFT:
				mouse_pos = event.position
				usar()
				return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			selecionar(k - KEY_1)
			return true
	return false

# ---------------------------------------------------------------- alvo
func celula_jogador() -> Vector2i:
	return Vector2i(roundi(g.player.position.x), roundi(g.player.position.z))

func calcular_alvo() -> Vector2i:
	var pc := celula_jogador()
	# mouse recente: celula sob o cursor, se estiver a 1 celula do jogador
	if t - mouse_t < 2.5 and g.fidelity_camera:
		var o: Vector3 = g.fidelity_camera.project_ray_origin(mouse_pos)
		var d: Vector3 = g.fidelity_camera.project_ray_normal(mouse_pos)
		var y: float = g.player.position.y - 0.4
		if absf(d.y) > 0.01:
			var hit := o + d * ((y - o.y) / d.y)
			var c := Vector2i(roundi(hit.x), roundi(hit.z))
			if absi(c.x - pc.x) <= 1 and absi(c.y - pc.y) <= 1:
				return c
	var f := Vector2(g.facing.x, g.facing.z)
	if f.length() < 0.1:
		f = Vector2(0, 1)
	f = f.normalized()
	var p := Vector2(g.player.position.x, g.player.position.z) + f * 0.95
	var c2 := Vector2i(roundi(p.x), roundi(p.y))
	if c2 == pc:
		p = Vector2(g.player.position.x, g.player.position.z) + f * 1.45
		c2 = Vector2i(roundi(p.x), roundi(p.y))
	return c2

func cada_quadro(delta: float) -> void:
	t += delta
	cd = maxf(0.0, cd - delta)
	if g.detritos == null or g.solo == null:
		return
	var dentro: bool = g.interiores and g.interiores.ativo >= 0
	cursor.visible = not dentro
	if dentro:
		return
	alvo = calcular_alvo()
	var h: float = g.vila.altura(float(alvo.x), float(alvo.y))
	cursor.position = Vector3(alvo.x, maxf(h, -0.45) + 0.07, alvo.y)
	var ok := pode_usar(item(), alvo)
	cursor_mat.albedo_color = Color(0.55, 1.0, 0.55, 0.95) if ok else Color(1, 1, 1, 0.55)
	g.hud.text = linha_hud()

# ---------------------------------------------------------------- regras
func agua(c: Vector2i) -> bool:
	if g.vila.altura(float(c.x), float(c.y)) < -0.3:
		return true
	for p in g.vila.lista_pecas:
		if String(p.get_meta("modulo", "")) == "poco" and Vector2(p.position.x + 0.5, p.position.z + 0.5).distance_to(Vector2(c.x, c.y)) < 1.6:
			return true
	return false

func aravel(c: Vector2i) -> bool:
	var f: Dictionary = g.vila.data.fazenda
	if c.x < int(f.aravel.min[0]) or c.x > int(f.aravel.max[0]) or c.y < int(f.aravel.min[1]) or c.y > int(f.aravel.max[1]):
		return false
	if not g.cells.has(c):
		return false
	var tp: String = g.vila.tipo(c.x, c.y)
	if tp == "c" or tp == "b" or tp == "r":
		return false
	if g.detritos.em(c) or g.solo.tem(c):
		return false
	var gal: Dictionary = f.galinheiro
	if c.x >= int(gal.min[0]) - 1 and c.x <= int(gal.max[0]) + 1 and c.y >= int(gal.min[1]) - 1 and c.y <= int(gal.max[1]) + 1:
		return false
	# casa, poco, caixa de envio e pecas solidas: teste fisico simples na celula
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.7, 0.6, 0.7)
	q.shape = b
	q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, g.vila.altura(float(c.x), float(c.y)) + 0.45, c.y))
	q.exclude = [g.player.get_rid()]
	for r in space.intersect_shape(q, 4):
		var col = r.collider
		if col and col.name != "TerrenoModular" and not (col.get_parent() and col.get_parent().name == "TerrenoModular"):
			return false
	return true

func pode_usar(id: String, c: Vector2i) -> bool:
	match id:
		"enxada":
			return aravel(c)
		"picareta":
			return g.detritos.tipo(c) == "pedra"
		"machado":
			return g.detritos.tipo(c) in ["galho", "toco", "arvore"]
		"foice":
			return g.detritos.tipo(c) == "mato" or g.solo.maduro(c)
		"regador":
			return agua(c) or (g.solo.tem(c) and g.estado.regador > 0)
		"mao":
			return g.solo.maduro(c)
	if id.begins_with("semente_"):
		return g.solo.tem(c) and g.solo.vazio(c) and g.estado.qtd(id) > 0
	return false

func usar() -> void:
	if cd > 0 or (g.interiores and (g.interiores.ativo >= 0 or g.interiores.ocupado)):
		return
	cd = 0.28
	alvo = calcular_alvo()
	var id := item()
	var c := alvo
	var msg := ""
	var dir := Vector3(c.x - g.player.position.x, 0, c.y - g.player.position.z)
	if dir.length() > 0.05:
		g.facing = dir.normalized()
		var d2: Vector3 = dir.rotated(Vector3.UP, -g.CAMERA_YAW)
		g.sprite.set_direction(Vector2(d2.x, d2.z))
	if g.solo.maduro(c) and (id == "mao" or id == "foice" or id.begins_with("semente_")):
		msg = g.solo.colher(c)
	elif id == "enxada":
		if aravel(c):
			g.solo.arar(c)
			msg = "Terra arada."
		else:
			msg = "Nao da para arar aqui (caminho, agua, detrito ou construcao)."
	elif id == "picareta" or id == "machado" or id == "foice":
		msg = g.detritos.golpe(c, id)
	elif id == "regador":
		if agua(c):
			g.estado.regador = g.estado.REGADOR_MAX
			msg = "Regador cheio (%d)." % g.estado.regador
		elif g.solo.tem(c):
			msg = g.solo.molhar(c)
		else:
			msg = "Regue terra arada, ou encha o regador no lago/poco."
	elif id.begins_with("semente_"):
		msg = g.solo.plantar(c, id.trim_prefix("semente_"))
	else:
		msg = "Use a mao/foice em plantas maduras."
	if g.tools_visual:
		g.tools_visual.use_tool("water" if id == "regador" else "axe", Vector3(dir.x, 0, dir.z))
	if g.sprite.has_method("play_action"):
		g.sprite.play_action("tend")
	g.estado.salvar()
	g.message.text = msg
	atualizar()

## icone: pixel-art 16x16 de art/ui/icones_fazenda/<id>.png (tools/icones_fazenda.py) ampliado 3x
## sem filtro; se o PNG faltar, cai no desenho vetorial antigo.
class Icone extends Control:
	const PASTA_ICONES := "res://art/ui/icones_fazenda/"
	static var _cache := {}
	static func textura_icone(nome: String) -> Texture2D:
		if _cache.has(nome):
			return _cache[nome]
		var tex: Texture2D = null
		var cam := ProjectSettings.globalize_path(PASTA_ICONES + nome + ".png")
		if FileAccess.file_exists(cam):
			var img := Image.load_from_file(cam)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		_cache[nome] = tex
		return tex
	var id := ""
	var cor := Color.WHITE
	var pixel := true
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var tex: Texture2D = textura_icone(id) if pixel else null
		if tex != null:
			var lado := 48.0
			draw_texture_rect(tex, Rect2((size - Vector2(lado, lado)) * 0.5, Vector2(lado, lado)), false)
			return
		var m := Color("5a3a1e")
		var c := size * 0.5
		match id:
			"enxada":
				draw_line(c + Vector2(-14, 18), c + Vector2(12, -14), m, 5)
				draw_rect(Rect2(c + Vector2(4, -22), Vector2(18, 9)), cor)
			"picareta":
				draw_line(c + Vector2(-12, 18), c + Vector2(8, -10), m, 5)
				draw_arc(c + Vector2(6, -6), 18, -2.6, -0.4, 12, cor, 5)
			"machado":
				draw_line(c + Vector2(-12, 18), c + Vector2(10, -16), m, 5)
				draw_colored_polygon(PackedVector2Array([c + Vector2(2, -18), c + Vector2(20, -20), c + Vector2(18, -2), c + Vector2(6, -6)]), Color("aab2b6"))
			"foice":
				draw_line(c + Vector2(-10, 20), c + Vector2(4, -12), m, 5)
				draw_arc(c + Vector2(-4, -10), 16, -0.2, 2.2, 12, cor, 4)
			"regador":
				draw_rect(Rect2(c + Vector2(-14, -8), Vector2(22, 22)), cor)
				draw_line(c + Vector2(8, 0), c + Vector2(20, -12), cor, 4)
				draw_arc(c + Vector2(-3, -10), 8, PI, TAU, 8, Color("2f5f86"), 3)
			"mao":
				draw_circle(c + Vector2(0, 4), 12, cor)
				for i in 4:
					draw_rect(Rect2(c + Vector2(-11 + i * 6, -16), Vector2(5, 14)), cor)
			_:
				# saquinho de sementes
				draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -10), c + Vector2(14, -10), c + Vector2(17, 20), c + Vector2(-17, 20)]), Color("d7c08e"))
				draw_rect(Rect2(c + Vector2(-10, -16), Vector2(20, 6)), Color("b49660"))
				draw_circle(c + Vector2(0, 6), 8, cor)
