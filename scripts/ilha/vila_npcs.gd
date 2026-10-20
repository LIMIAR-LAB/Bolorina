extends Node
## Moradores interativos da vila (dados em moradores.json, "ativo": true).
## E perto: conversa (E de novo avanca as falas). Sr. Armando abre a loja:
## 1-4 compra, 5 vende tudo (colheita, ovos, peixes), E/Esc fecha.
## Amizade: +1 ponto na 1a conversa do dia (10 pontos = 1 coracao), salvo no estado.
const DADOS := "res://scripts/ilha/moradores.json"
const RAIO := 1.9
var g
var npcs: Array = []      # {dados, no, rotulo}
var camada: CanvasLayer
var painel: Panel
var nome_l: Label
var texto_l: Label
var dica_l: Label
var falando := -1
var fala_i := 0
var loja_aberta := false
var t_fechar := 0.0

func montar(game) -> void:
	g = game
	name = "MoradoresVila"
	var d = JSON.parse_string(FileAccess.get_file_as_string(DADOS)) if FileAccess.file_exists(DADOS) else null
	if d == null:
		return
	for m in d.moradores:
		if not bool(m.get("ativo", false)):
			continue
		var p: Array = m.pos
		var pos := _livre(Vector2(float(p[0]), float(p[1])))
		var a: AnimatedSprite3D = g._actor(String(m.personagem))
		a.name = "Morador_" + String(m.id)
		a.position = Vector3(pos.x, g.vila.altura(pos.x, pos.y), pos.y)
		g.ground.add_child(a)
		if a.has_method("set_direction"):
			a.set_direction(Vector2(0, 1))
		var r := Label3D.new()
		r.text = String(m.nome) + ("\n[loja]" if bool(m.get("loja", false)) else "")
		r.font_size = 30
		r.pixel_size = 0.0045
		r.outline_size = 8
		r.modulate = Color("ffe9b0")
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.no_depth_test = true
		r.position = a.position + Vector3(0, 2.15, 0)
		r.visible = false
		g.ground.add_child(r)
		npcs.append({"dados": m, "no": a, "rotulo": r})
		if bool(m.get("loja", false)):
			_banca(a.position)
	_ui()

## celula andavel livre mais proxima (o layout da vila pode mudar)
func _livre(p: Vector2) -> Vector2:
	var melhor := p
	var dm := 1e9
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var c := Vector2i(roundi(p.x) + dx, roundi(p.y) + dz)
			if not g.cells.has(c):
				continue
			var d := Vector2(c).distance_to(p)
			if d < dm and _vazio(c):
				dm = d
				melhor = Vector2(c)
	return melhor

func _vazio(c: Vector2i) -> bool:
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.6, 1.0, 0.6)
	q.shape = b
	q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, g.vila.altura(float(c.x), float(c.y)) + 0.7, c.y))
	q.exclude = [g.player.get_rid()]
	return space.intersect_shape(q, 1).is_empty()

func _banca(pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = "BancaSementes"
	n.position = pos + Vector3(0.9, 0, -0.6)
	g.ground.add_child(n)
	g.art_world.box(Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6), "brown_planks_03", true, n)
	g.art_world.box(Vector3(0, 1.75, 0), Vector3(1.5, 0.12, 0.9), "grey_roof_tiles", false, n)
	for sx in [-0.65, 0.65]:
		g.art_world.box(Vector3(sx, 1.1, -0.35), Vector3(0.08, 1.3, 0.08), "brown_planks_03", false, n)
	var cores := [Color("e8e1f0"), Color("7fb04a"), Color("e39a2e")]
	for i in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = cores[i]
		g.vila.kit.ball(n, Vector3(-0.35 + i * 0.35, 0.98, 0.05), Vector3(0.22, 0.14, 0.22), m)
	var l := Label3D.new()
	l.text = "SEMENTES"
	l.font_size = 34
	l.pixel_size = 0.005
	l.modulate = Color("f1e2bd")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 2.05, 0)
	n.add_child(l)

func _ui() -> void:
	camada = CanvasLayer.new()
	camada.layer = 35
	add_child(camada)
	painel = Panel.new()
	painel.position = Vector2(330, 570)
	painel.size = Vector2(940, 230)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.09, 0.05, 0.94)
	st.border_color = Color("c9a46a")
	st.set_border_width_all(3)
	st.set_corner_radius_all(6)
	painel.add_theme_stylebox_override("panel", st)
	painel.visible = false
	camada.add_child(painel)
	nome_l = Label.new()
	nome_l.position = Vector2(20, 10)
	nome_l.add_theme_font_size_override("font_size", 20)
	nome_l.add_theme_color_override("font_color", Color("ffd98a"))
	painel.add_child(nome_l)
	texto_l = Label.new()
	texto_l.position = Vector2(20, 44)
	texto_l.size = Vector2(900, 150)
	texto_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto_l.add_theme_font_size_override("font_size", 17)
	texto_l.add_theme_color_override("font_color", Color("f6ecd2"))
	painel.add_child(texto_l)
	dica_l = Label.new()
	dica_l.position = Vector2(20, 198)
	dica_l.add_theme_font_size_override("font_size", 13)
	dica_l.add_theme_color_override("font_color", Color("c9b48a"))
	painel.add_child(dica_l)

func perto() -> int:
	var pp := Vector2(g.player.position.x, g.player.position.z)
	var melhor := -1
	var dm := RAIO
	for i in npcs.size():
		var n: Node3D = npcs[i].no
		var d := Vector2(n.position.x, n.position.z).distance_to(pp)
		if d < dm:
			dm = d
			melhor = i
	return melhor

func coracoes(id: String) -> String:
	var pts: int = int(g.estado.amizade.get(id, 0))
	var h: int = pts / 10
	return "♥".repeat(h) + "♡".repeat(maxi(0, 10 - h)) if h > 0 else "♡ (%d/10)" % (pts % 10)

## E: inicia/avanca conversa. Devolve true se tratou.
func tecla_e() -> bool:
	if loja_aberta:
		fechar()
		return true
	if falando >= 0:
		var falas: Array = npcs[falando].dados.falas
		fala_i += 1
		if bool(npcs[falando].dados.get("loja", false)) and fala_i >= 1:
			abrir_loja()
			return true
		if fala_i >= falas.size():
			fechar()
			return true
		_mostrar()
		return true
	var i := perto()
	if i < 0:
		return false
	falar(i)
	return true

func falar(i: int) -> void:
	falando = i
	fala_i = 0
	var d: Dictionary = npcs[i].dados
	var id := String(d.id)
	if int(g.estado.conversou.get(id, 0)) != int(g.estado.dia):
		g.estado.conversou[id] = int(g.estado.dia)
		g.estado.amizade[id] = int(g.estado.amizade.get(id, 0)) + 1
		g.estado.salvar()
	var a: Node3D = npcs[i].no
	if a.has_method("set_direction"):
		var dir: Vector3 = (g.player.position - a.position).rotated(Vector3.UP, -g.CAMERA_YAW)
		a.set_direction(Vector2(dir.x, dir.z))
	_mostrar()

func _mostrar() -> void:
	var d: Dictionary = npcs[falando].dados
	var falas: Array = d.falas
	painel.visible = true
	nome_l.text = "%s  —  %s    %s" % [String(d.nome), String(d.papel), coracoes(String(d.id))]
	texto_l.text = String(falas[mini(fala_i, falas.size() - 1)])
	dica_l.text = "E: continuar" + ("  (abre a loja)" if bool(d.get("loja", false)) else "")

func abrir_loja() -> void:
	loja_aberta = true
	painel.visible = true
	var e = g.estado
	nome_l.text = "Loja de Sementes do Sr. Armando    Ouro: %d" % e.ouro
	var linhas := []
	var i := 1
	for item in e.LOJA:
		var q: int = int(e.LOJA[item][0])
		linhas.append("%d  %s%s — %d ouro   (tem %d)" % [i, _nome(item), (" x%d" % q) if q > 1 else "", int(e.LOJA[item][1]), e.qtd(item)])
		i += 1
	linhas.append("5  Vender tudo (colheita, ovos, peixes) — vale %d ouro" % _valor_venda())
	texto_l.text = "\n".join(linhas)
	dica_l.text = "1-4: comprar   5: vender   E/Esc: sair"

func _nome(item: String) -> String:
	return {"semente_nabo": "Sementes de nabo", "semente_couve": "Sementes de couve", "semente_abobora": "Sementes de abobora", "racao": "Racao de galinha"}.get(item, item)

func _valor_venda() -> int:
	var e = g.estado
	var v := 0
	for c in e.CULTURAS:
		v += e.qtd(c) * int(e.CULTURAS[c].preco)
	for p in e.PEIXES:
		v += e.qtd(p) * int(e.PEIXES[p].preco)
	return v + e.qtd("ovo") * e.PRECO_OVO

## tecla durante a loja (1-5). Devolve a mensagem ("" se nao tratou)
func opcao_loja(n: int) -> String:
	if not loja_aberta:
		return ""
	var e = g.estado
	var itens: Array = e.LOJA.keys()
	var msg := ""
	if n >= 1 and n <= itens.size():
		var item: String = itens[n - 1]
		var err: String = e.comprar(item)
		msg = err if err != "" else "Comprou %s. Ouro: %d." % [_nome(item), e.ouro]
	elif n == 5:
		var ganho: int = e.vender_colheita()
		msg = ("Vendeu tudo: +%d ouro (total %d)." % [ganho, e.ouro]) if ganho > 0 else "Nada para vender."
	else:
		return ""
	e.salvar()
	abrir_loja()
	g.message.text = msg
	return msg

func fechar() -> void:
	falando = -1
	fala_i = 0
	loja_aberta = false
	painel.visible = false

func entrada(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var k: int = event.physical_keycode
	if loja_aberta and k >= KEY_1 and k <= KEY_5:
		opcao_loja(k - KEY_0)
		return true
	if (loja_aberta or falando >= 0) and k == KEY_ESCAPE:
		fechar()
		return true
	if k == KEY_E:
		return tecla_e()
	return false

func cada_quadro(_delta: float) -> void:
	var i := perto()
	for j in npcs.size():
		npcs[j].rotulo.visible = j == i or j == falando
	if (falando >= 0 or loja_aberta) and i != falando and perto() < 0:
		fechar()
