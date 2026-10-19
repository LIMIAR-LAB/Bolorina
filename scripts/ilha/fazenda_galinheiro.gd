extends Node3D
## Galinhas placeholder vagando dentro do cercado do galinheiro.
var g
var galinhas: Array = []
var rng := RandomNumberGenerator.new()
var area := Rect2()

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

func cada_quadro(delta: float) -> void:
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
