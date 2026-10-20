extends Node
## NPCs com funcao de jogo (lojas e servicos) numa area. Roster: data/npcs/<area>.json.
## Posicao: marcador "npc_<id>" da cena (mapas da Bolorina) ou "pos" do roster (x,z). Retrato: art/ui/retratos/<id>.png.
## E perto: conversa (E avanca); depois das falas abre o balcao: Tab troca a aba (Comprar/Vender/Servicos/Fundir/Forjar),
## setas escolhem, Enter (ou 1-9) executa, Esc/E fecha.
const Itens = preload("res://scripts/economia/itens.gd")
const Loja = preload("res://scripts/economia/loja.gd")
const Servicos = preload("res://scripts/economia/servicos.gd")
const Forja = preload("res://scripts/economia/forja.gd")
const RAIO := 1.9
var g                       # area (precisa de: player, estado; opcional: ground, vila, _actor, message, gerenciador)
var npcs: Array = []        # {dados, no, rotulo}
var camada: CanvasLayer
var painel: Panel
var retrato: TextureRect
var nome_l: Label
var texto_l: Label
var lista_l: Label
var dica_l: Label
var falando := -1
var fala_i := 0
var balcao := false
var abas: Array = []
var aba := 0
var sel := 0
var opcoes: Array = []      # [{texto, acao: Callable}]
var ultima_msg := ""

func montar(area, roster: String) -> void:
	g = area
	name = "NpcsArea"
	var d = JSON.parse_string(FileAccess.get_file_as_string(roster)) if FileAccess.file_exists(roster) else null
	if not d is Dictionary:
		return
	for m in d.npcs:
		var a := _ator(m)
		var pos := _posicao(m)
		var raiz: Node = g.get("ground") if g.get("ground") else g
		raiz.add_child(a)
		a.global_position = pos
		a.name = "Npc_" + String(m.id)
		if a.has_method("set_direction"):
			a.set_direction(Vector2(0, 1))
		var r := Label3D.new()
		r.text = "%s\n[%s]" % [String(m.nome), String(m.papel)]
		r.font_size = 28
		r.pixel_size = 0.0045
		r.outline_size = 8
		r.modulate = Color("ffe9b0")
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.no_depth_test = true
		r.visible = false
		raiz.add_child(r)
		r.global_position = pos + Vector3(0, 2.15 * float(m.get("escala", 1.0)), 0)
		npcs.append({"dados": m, "no": a, "rotulo": r})
	_ui()

func _ator(m: Dictionary) -> Node3D:
	var a: Node3D
	if g.has_method("_actor"):
		a = g._actor(String(m.personagem))
	else:
		a = load("res://scripts/actor_visual.gd").new()
		a.setup(String(m.personagem))
	if a is SpriteBase3D:
		(a as SpriteBase3D).modulate = Color(String(m.get("cor", "ffffff")))
	a.scale = Vector3.ONE * float(m.get("escala", 1.0))
	return a

func _posicao(m: Dictionary) -> Vector3:
	var marc := (g as Node).find_child("npc_" + String(m.id), true, false)
	if marc is Node3D:
		return (marc as Node3D).global_position
	var p: Array = m.pos
	var x := float(p[0])
	var z := float(p[1])
	var v = g.get("vila")
	if v and v.has_method("altura"):
		var livre := _livre(Vector2(x, z))
		return Vector3(livre.x, v.altura(livre.x, livre.y), livre.y)
	return Vector3(x, 0, z)

## celula andavel livre mais proxima (mesma ideia de vila_npcs.gd)
func _livre(p: Vector2) -> Vector2:
	var cells = g.get("cells")
	if cells == null:
		return p
	var melhor := p
	var dm := 1e9
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var c := Vector2i(roundi(p.x) + dx, roundi(p.y) + dz)
			if not cells.has(c):
				continue
			var d := Vector2(c).distance_to(p)
			if d >= dm:
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(0.6, 1.0, 0.6)
			q.shape = b
			q.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, g.vila.altura(float(c.x), float(c.y)) + 0.7, c.y))
			q.exclude = [g.player.get_rid()]
			if space.intersect_shape(q, 1).is_empty():
				dm = d
				melhor = Vector2(c)
	return melhor

func _ui() -> void:
	camada = CanvasLayer.new()
	camada.layer = 36
	add_child(camada)
	painel = Panel.new()
	painel.position = Vector2(250, 470)
	painel.size = Vector2(1100, 330)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.09, 0.05, 0.95)
	st.border_color = Color("c9a46a")
	st.set_border_width_all(3)
	st.set_corner_radius_all(6)
	painel.add_theme_stylebox_override("panel", st)
	painel.visible = false
	camada.add_child(painel)
	retrato = TextureRect.new()
	retrato.position = Vector2(16, 16)
	retrato.size = Vector2(128, 128)
	retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	painel.add_child(retrato)
	nome_l = _label(Vector2(160, 10), 20, Color("ffd98a"))
	texto_l = _label(Vector2(160, 44), 17, Color("f6ecd2"))
	texto_l.size = Vector2(920, 90)
	texto_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista_l = _label(Vector2(160, 120), 15, Color("f1e2bd"))
	lista_l.size = Vector2(920, 180)
	dica_l = _label(Vector2(160, 302), 13, Color("c9b48a"))

func _label(p: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.position = p
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	painel.add_child(l)
	return l

func _retrato(m: Dictionary) -> Texture2D:
	var cam := String(m.get("retrato", "res://art/ui/retratos/%s.png" % String(m.id)))
	var gl := ProjectSettings.globalize_path(cam)
	if FileAccess.file_exists(gl):
		var img := Image.load_from_file(gl)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	# fallback: quadro do proprio sprite (south) ampliado
	var no: Node = null
	for n in npcs:
		if n.dados == m:
			no = n.no
	if no is AnimatedSprite3D and (no as AnimatedSprite3D).sprite_frames:
		var sf: SpriteFrames = (no as AnimatedSprite3D).sprite_frames
		for an in ["idle_south", "idle_south-east", "default"]:
			if sf.has_animation(an) and sf.get_frame_count(an) > 0:
				return sf.get_frame_texture(an, 0)
	return null

func perto() -> int:
	var pl = g.get("player")
	if pl == null:
		return -1
	var pp := Vector2(pl.global_position.x, pl.global_position.z)
	var melhor := -1
	var dm := RAIO * maxf(1.0, 1.0)
	for i in npcs.size():
		var n: Node3D = npcs[i].no
		var d := Vector2(n.global_position.x, n.global_position.z).distance_to(pp)
		if d < dm * float(npcs[i].dados.get("escala", 1.0)):
			dm = d
			melhor = i
	return melhor

func npc_por_id(id: String) -> int:
	for i in npcs.size():
		if String(npcs[i].dados.id) == id:
			return i
	return -1

func falar(i: int) -> void:
	falando = i
	fala_i = 0
	balcao = false
	var d: Dictionary = npcs[i].dados
	var e = g.estado
	var id := String(d.id)
	if int(e.conversou.get(id, 0)) != int(e.dia):
		e.conversou[id] = int(e.dia)
		e.amizade[id] = int(e.amizade.get(id, 0)) + 1
	var aviso := Servicos.ao_falar(e, id)
	if aviso != "":
		ultima_msg = aviso
	e.salvar()
	painel.visible = true
	retrato.texture = _retrato(d)
	_mostrar()

func _mostrar() -> void:
	var d: Dictionary = npcs[falando].dados
	var falas: Array = d.falas
	nome_l.text = "%s  —  %s    %s" % [String(d.nome), String(d.papel), _coracoes(String(d.id))]
	texto_l.text = (ultima_msg + "\n" if ultima_msg != "" else "") + String(falas[mini(fala_i, falas.size() - 1)])
	lista_l.text = ""
	dica_l.text = "E: continuar" + ("  (abre o balcão)" if String(d.get("loja", "")) != "" else "")

func _coracoes(id: String) -> String:
	var pts: int = int(g.estado.amizade.get(id, 0))
	return "♥ %d" % (pts / 10) if pts >= 10 else "♡ (%d/10)" % pts

## abre o balcao da loja do NPC falando
func abrir_balcao() -> void:
	var d: Dictionary = npcs[falando].dados
	var lid := String(d.get("loja", ""))
	if lid == "" or not Loja.existe(lid):
		fechar()
		return
	balcao = true
	abas = []
	var ld := Loja.dados(lid)
	if not ld.get("compra", []).is_empty():
		abas.append("comprar")
	if not ld.get("vende_categorias", []).is_empty():
		abas.append("vender")
	if bool(ld.get("forja", false)):
		abas.append("fundir")
		abas.append("forjar")
	var servs: Array = []
	for s in ld.get("servicos", []):
		if not String(s.id) in ["fundir", "forjar"]:
			servs.append(s)
	if not servs.is_empty():
		abas.append("servicos")
	aba = clampi(aba, 0, maxi(0, abas.size() - 1))
	sel = 0
	_listar()

func _listar() -> void:
	var d: Dictionary = npcs[falando].dados
	var lid := String(d.loja)
	var e = g.estado
	opcoes = []
	match abas[aba] if not abas.is_empty() else "":
		"comprar":
			for c in Loja.dados(lid).compra:
				var it := String(c.item)
				var q := int(c.get("qtd", 1))
				opcoes.append({"texto": "%s%s — %d ouro   (estoque %d, tem %d)" % [Itens.nome(it), (" x%d" % q) if q > 1 else "", int(c.preco), Loja.estoque(e, lid, it), Itens.qtd(e, it)],
					"acao": func(): return _ok(Loja.comprar(e, lid, it, 1), "Comprou %s." % Itens.nome(it))})
		"vender":
			for it in Loja.vendaveis(e, lid):
				var item := String(it)
				opcoes.append({"texto": "Vender 1 %s — %d ouro   (tem %d)" % [Itens.nome(item), Loja.preco_venda(lid, item), e.qtd(item)],
					"acao": func(): return _ok(Loja.vender(e, lid, item, 1), "Vendeu %s." % Itens.nome(item))})
			if not opcoes.is_empty():
				opcoes.append({"texto": "Vender tudo o que ele compra", "acao": func(): return "Vendeu tudo: +%d ouro." % Loja.vender_tudo(e, lid)})
		"fundir", "forjar":
			for r in Forja.de_tipo(abas[aba]):
				var rid := String(r.id)
				var falta := Forja.falta(e, r)
				opcoes.append({"texto": ("" if falta == "" else "✗ ") + Forja.resumo(e, r),
					"acao": func(): return _ok(Forja.fazer(e, rid), "Pronto: %s!" % String(r.nome))})
		"servicos":
			for s in Loja.dados(lid).servicos:
				var sid := String(s.id)
				if sid in ["fundir", "forjar"]:
					continue
				var preco := int(s.get("preco", 0))
				opcoes.append({"texto": "%s%s" % [String(s.nome), (" — %d ouro" % preco) if preco > 0 else ""],
					"acao": func(): return Servicos.executar(e, g.get("gerenciador"), lid, sid)})
	sel = clampi(sel, 0, maxi(0, opcoes.size() - 1))
	var titulo: Array = []
	for i in abas.size():
		titulo.append(("[%s]" if i == aba else " %s ") % String(abas[i]).to_upper())
	nome_l.text = "%s    Ouro: %d    %s" % [String(Loja.dados(lid).get("nome", lid)), e.ouro, "  ".join(titulo)]
	texto_l.text = ultima_msg if ultima_msg != "" else String(d.falas[0])
	var linhas: Array = []
	var ini := clampi(sel - 4, 0, maxi(0, opcoes.size() - 8))
	for i in range(ini, mini(opcoes.size(), ini + 8)):
		linhas.append("%s %d  %s" % ["▶" if i == sel else " ", i + 1, String(opcoes[i].texto)])
	lista_l.text = "\n".join(linhas) if not linhas.is_empty() else "(nada nesta aba)"
	dica_l.text = "Tab: aba   ↑↓: escolher   Enter/1-9: fazer   E/Esc: sair"

func _ok(err: String, msg: String) -> String:
	return msg if err == "" else err

## executa a opcao i da aba atual; devolve a mensagem
func escolher(i: int) -> String:
	if not balcao or i < 0 or i >= opcoes.size():
		return ""
	var msg: String = String(opcoes[i].acao.call())
	ultima_msg = msg
	g.estado.salvar()
	var m = g.get("message")
	if m is Label and msg != "":
		m.text = msg
	if g.get("gerenciador") and g.gerenciador.has_method("vestir_atual"):
		g.gerenciador.vestir_atual()
	if balcao:
		_listar()
	return msg

func trocar_aba(n: int) -> void:
	if abas.is_empty():
		return
	aba = posmod(aba + n, abas.size())
	sel = 0
	_listar()

func tecla_e() -> bool:
	if balcao:
		fechar()
		return true
	if falando >= 0:
		fala_i += 1
		var falas: Array = npcs[falando].dados.falas
		if fala_i >= falas.size() or (String(npcs[falando].dados.get("loja", "")) != "" and fala_i >= 1):
			if String(npcs[falando].dados.get("loja", "")) != "":
				abrir_balcao()
			else:
				fechar()
			return true
		_mostrar()
		return true
	var i := perto()
	if i < 0:
		return false
	ultima_msg = ""
	falar(i)
	return true

func fechar() -> void:
	falando = -1
	fala_i = 0
	balcao = false
	ultima_msg = ""
	painel.visible = false

func aberto() -> bool:
	return falando >= 0 or balcao

func entrada(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var k: int = event.physical_keycode
	if balcao:
		match k:
			KEY_TAB, KEY_RIGHT:
				trocar_aba(1)
				return true
			KEY_LEFT:
				trocar_aba(-1)
				return true
			KEY_UP, KEY_W:
				sel = maxi(0, sel - 1)
				_listar()
				return true
			KEY_DOWN, KEY_S:
				sel = mini(opcoes.size() - 1, sel + 1)
				_listar()
				return true
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				escolher(sel)
				return true
		if k >= KEY_1 and k <= KEY_9:
			escolher(k - KEY_1)
			return true
	if aberto() and k == KEY_ESCAPE:
		fechar()
		return true
	if k == KEY_E:
		return tecla_e()
	return false

func cada_quadro(_delta: float) -> void:
	var i := perto()
	for j in npcs.size():
		npcs[j].rotulo.visible = j == i or j == falando
	if aberto() and i != falando:
		fechar()
