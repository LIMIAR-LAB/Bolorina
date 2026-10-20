extends Node3D
## Galinhas vagando no cercado + cuidado: E no cocho = racao (1 por galinha/dia),
## E perto de uma galinha = carinho (afeto 0-10, 1x/dia), ovos aparecem no dia seguinte
## (galinhas alimentadas; afeto aumenta a chance) e E perto dos ovos coleta.
var g
var galinhas: Array = []
var rng := RandomNumberGenerator.new()
var area := Rect2()

var cocho: Node3D
var cocho_racao: MeshInstance3D
var ovos_nos: Array = []
var mat_ovo: StandardMaterial3D
var mat_racao: StandardMaterial3D
var coracoes: Array = []

func montar(game) -> void:
	g = game
	name = "Galinheiro"
	rng.seed = 808
	var gal: Dictionary = g.vila.data.fazenda.galinheiro
	area = Rect2(float(gal.min[0]) + 0.3, float(gal.min[1]) + 2.6, float(gal.max[0]) - float(gal.min[0]) - 0.6, float(gal.max[1]) - float(gal.min[1]) - 3.0)
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color("f2ece0")
	var marrom := StandardMaterial3D.new()
	marrom.albedo_color = Color("b0703a")
	var crista := StandardMaterial3D.new()
	crista.albedo_color = Color("d23a2a")
	var bico := StandardMaterial3D.new()
	bico.albedo_color = Color("e7a530")
	for i in 5:
		var n: Node3D = Node3D.new()
		n.name = "Galinha%d" % i
		add_child(n)
		var corpo: Node3D = Node3D.new()
		corpo.name = "Corpo"
		n.add_child(corpo)
		var mat: StandardMaterial3D = marrom if i % 3 == 2 else branco
		g.vila.kit.ball(corpo, Vector3(0, 0.22, 0), Vector3(0.34, 0.28, 0.42), mat)
		g.vila.kit.ball(corpo, Vector3(0, 0.3, -0.2), Vector3(0.18, 0.24, 0.12), mat)
		g.vila.kit.ball(corpo, Vector3(0, 0.42, 0.2), Vector3(0.18, 0.2, 0.18), mat)
		g.vila.kit.ball(corpo, Vector3(0, 0.54, 0.2), Vector3(0.05, 0.08, 0.1), crista)
		g.vila.kit.ball(corpo, Vector3(0, 0.42, 0.31), Vector3(0.06, 0.04, 0.08), bico)
		for s in [-0.07, 0.07]:
			g.art_world.box(Vector3(s, 0.05, 0), Vector3(0.025, 0.1, 0.025), "gold", false, corpo)
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		n.position = Vector3(p.x, g.vila.altura(p.x, p.y), p.y)
		galinhas.append({"no": n, "alvo": p, "pausa": rng.randf_range(0.0, 2.0), "t": rng.randf() * 10.0})
		var nome: Label3D = Label3D.new()
		nome.name = "Nome"
		nome.text = g.estado.GALINHAS[i]
		nome.font_size = 30
		nome.pixel_size = 0.004
		nome.outline_size = 8
		nome.position = Vector3(0, 0.85, 0)
		nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nome.modulate = Color("f1e2bd")
		nome.visible = false
		n.add_child(nome)
	_montar_cocho(gal)
	aplicar()

func _montar_cocho(gal: Dictionary) -> void:
	var cel: Array = gal.celeiro
	var pos := Vector2(float(cel[0]) - 2.8, float(cel[1]) + 2.6)
	cocho = Node3D.new()
	cocho.name = "Cocho"
	cocho.position = Vector3(pos.x, g.vila.altura(pos.x, pos.y), pos.y)
	add_child(cocho)
	g.art_world.box(Vector3(0, 0.18, 0), Vector3(1.2, 0.12, 0.45), "brown_planks_03", true, cocho)
	g.art_world.box(Vector3(0, 0.3, 0.2), Vector3(1.2, 0.2, 0.06), "brown_planks_03", false, cocho)
	g.art_world.box(Vector3(0, 0.3, -0.2), Vector3(1.2, 0.2, 0.06), "brown_planks_03", false, cocho)
	mat_racao = StandardMaterial3D.new()
	mat_racao.albedo_color = Color("e2b45a")
	cocho_racao = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.08, 0.08, 0.32)
	cocho_racao.mesh = bm
	cocho_racao.material_override = mat_racao
	cocho_racao.position = Vector3(0, 0.3, 0)
	cocho.add_child(cocho_racao)
	var l: Label3D = Label3D.new()
	l.text = "COCHO"
	l.font_size = 30
	l.pixel_size = 0.004
	l.position = Vector3(0, 0.75, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color("f1e2bd")
	cocho.add_child(l)
	mat_ovo = StandardMaterial3D.new()
	mat_ovo.albedo_color = Color("f6ead2")

## sincroniza visual com o estado: racao no cocho e ovos no chao do galinheiro
func aplicar() -> void:
	var an: Dictionary = g.estado.animais
	cocho_racao.visible = int(an.alimentado_dia) == int(g.estado.dia)
	for o in ovos_nos:
		o.queue_free()
	ovos_nos.clear()
	var cel: Array = g.vila.data.fazenda.galinheiro.celeiro
	var r := RandomNumberGenerator.new()
	r.seed = 99 + int(g.estado.dia)
	for i in int(an.ovos):
		var p := Vector2(float(cel[0]) + r.randf_range(-1.6, 1.6), float(cel[1]) + 2.0 + r.randf_range(0.0, 1.0))
		var o := Node3D.new()
		o.name = "Ovo%d" % i
		o.position = Vector3(p.x, g.vila.altura(p.x, p.y), p.y)
		add_child(o)
		g.vila.kit.ball(o, Vector3(0, 0.07, 0), Vector3(0.1, 0.13, 0.1), mat_ovo)
		ovos_nos.append(o)

## tecla E: devolve true se tratou (cocho, ovos ou galinha perto)
func tecla_e() -> bool:
	var pp := Vector2(g.player.position.x, g.player.position.z)
	for o in ovos_nos:
		if Vector2(o.position.x, o.position.z).distance_to(pp) < 1.6:
			var n: int = g.estado.coletar_ovos()
			aplicar()
			g.message.text = "Coletou %d ovo%s! (total %d)" % [n, "" if n == 1 else "s", g.estado.qtd("ovo")]
			g.estado.salvar()
			return true
	if Vector2(cocho.position.x, cocho.position.z).distance_to(pp) < 1.7:
		var c: int = g.estado.alimentar()
		if c < 0:
			g.message.text = "O cocho ja tem racao hoje."
		elif c == 0:
			g.message.text = "Sem racao! Compre na loja da vila (Sr. Armando)."
		else:
			g.message.text = "Racao no cocho: %d galinhas comeram (racao restante %d). Ovos amanha!" % [c, g.estado.qtd("racao")]
			aplicar()
			g.estado.salvar()
		return true
	var melhor := -1
	var dm := 1.4
	for i in galinhas.size():
		var n: Node3D = galinhas[i].no
		var d := Vector2(n.position.x, n.position.z).distance_to(pp)
		if d < dm:
			dm = d
			melhor = i
	if melhor >= 0:
		carinho(melhor)
		return true
	return false

func carinho(i: int) -> void:
	var nome: String = g.estado.GALINHAS[i]
	var af: int = g.estado.carinho(i)
	var n: Node3D = galinhas[i].no
	galinhas[i].pausa = 1.5
	if af < 0:
		g.message.text = "%s ja ganhou carinho hoje. (afeto %d/10)" % [nome, int(g.estado.animais.afeto[i])]
		return
	g.message.text = "%s adorou o carinho! Afeto %s %d/10" % [nome, "♥".repeat(maxi(1, af / 2)), af]
	var h: Label3D = Label3D.new()
	h.text = "♥"
	h.font_size = 64
	h.pixel_size = 0.006
	h.outline_size = 10
	h.modulate = Color("ff5f7e")
	h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	h.no_depth_test = true
	h.position = n.position + Vector3(0, 0.75, 0)
	add_child(h)
	coracoes.append({"no": h, "t": 0.0})
	g.estado.salvar()

func cada_quadro(delta: float) -> void:
	for c in coracoes.duplicate():
		c.t += delta
		var h: Label3D = c.no
		h.position.y += delta * 0.6
		h.modulate.a = clampf(1.4 - c.t, 0.0, 1.0)
		if c.t > 1.4:
			h.queue_free()
			coracoes.erase(c)
	var pp := Vector2(g.player.position.x, g.player.position.z)
	for gl in galinhas:
		var nl: Label3D = gl.no.get_node("Nome")
		nl.visible = Vector2(gl.no.position.x, gl.no.position.z).distance_to(pp) < 2.5
	for gl in galinhas:
		var n: Node3D = gl.no
		gl.t += delta
		var corpo: Node3D = n.get_node("Corpo")
		if gl.pausa > 0:
			gl.pausa -= delta
			corpo.rotation.x = 0.35 * maxf(0.0, sin(gl.t * 9.0))  # bicando
			corpo.position.y = 0.0
			if gl.pausa <= 0:
				gl.alvo = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			continue
		corpo.rotation.x = 0.0
		var p := Vector2(n.position.x, n.position.z)
		var d: Vector2 = gl.alvo - p
		if d.length() < 0.1:
			gl.pausa = rng.randf_range(0.8, 3.0)
			continue
		var passo := d.normalized() * minf(d.length(), delta * 0.9)
		p += passo
		n.position = Vector3(p.x, g.vila.altura(p.x, p.y), p.y)
		n.rotation.y = atan2(passo.x, passo.y)
		corpo.position.y = absf(sin(gl.t * 14.0)) * 0.04
