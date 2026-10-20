extends Node3D
## Trilhas legiveis entre as areas (estilo Stardew): faixas de terra batida / pedra seguindo o terreno,
## pedrinhas nas bordas, lampioes, placas de madeira nas bifurcacoes e pegadas leves (no shader).
## So visual: nada aqui tem colisao (as barreiras naturais continuam as mesmas, sem paredes invisiveis).
const SHADER := "res://shaders/trilha.gdshader"
const PASSO := 0.5
var art
var altura_fn: Callable
var rng := RandomNumberGenerator.new()
var n_luzes := 0
const MAX_LUZES := 6
var faixas: Array = []

func montar(art_mundo, alt: Callable, semente := 11) -> void:
	art = art_mundo
	altura_fn = alt
	rng.seed = semente
	name = "Trilhas"

func _y(x: float, z: float) -> float:
	return float(altura_fn.call(x, z)) if altura_fn.is_valid() else 0.0

## pontos: Array de Vector2 (x,z). tipo: "terra" ou "pedra"
func faixa(pontos: Array, largura := 2.2, tipo := "terra", pegadas := true) -> MeshInstance3D:
	# reamostra a polilinha a cada PASSO metros
	var amostras: Array = []
	for i in pontos.size() - 1:
		var a: Vector2 = pontos[i]
		var b: Vector2 = pontos[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / PASSO))
		for k in n:
			amostras.append(a.lerp(b, float(k) / n))
	amostras.append(pontos[pontos.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var anterior: Vector2 = amostras[0]
	var esq: Array = []
	var dir_: Array = []
	var vs: Array = []
	for i in amostras.size():
		var p: Vector2 = amostras[i]
		dist += p.distance_to(anterior)
		anterior = p
		var t: Vector2 = (Vector2(amostras[mini(i + 1, amostras.size() - 1)]) - Vector2(amostras[maxi(i - 1, 0)])).normalized()
		var nrm := Vector2(-t.y, t.x)
		# largura com leve ondulacao (borda gasta)
		var w := largura * (0.5 + 0.06 * sin(dist * 1.7 + 0.8) + 0.04 * sin(dist * 4.1))
		var l := p + nrm * w
		var r := p - nrm * w
		esq.append(Vector3(l.x, _y(l.x, l.y) + 0.035, l.y))
		dir_.append(Vector3(r.x, _y(r.x, r.y) + 0.035, r.y))
		vs.append(dist)
	for i in amostras.size() - 1:
		var a0: Vector3 = esq[i]
		var b0: Vector3 = dir_[i]
		var a1: Vector3 = esq[i + 1]
		var b1: Vector3 = dir_[i + 1]
		for q in [[a0, 0.0, vs[i]], [b0, 1.0, vs[i]], [a1, 0.0, vs[i + 1]], [a1, 0.0, vs[i + 1]], [b0, 1.0, vs[i]], [b1, 1.0, vs[i + 1]]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(q[1], q[2]))
			st.add_vertex(q[0])
	var mi := MeshInstance3D.new()
	mi.name = "Trilha_" + tipo
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("pedra", 1.0 if tipo == "pedra" else 0.0)
	mat.set_shader_parameter("pegadas", 1.0 if pegadas else 0.0)
	mat.set_shader_parameter("largura", largura)
	mi.material_override = mat
	add_child(mi)
	faixas.append({"pontos": pontos, "largura": largura, "tipo": tipo})
	# pedrinhas nas bordas
	var acc := 0.0
	for i in range(1, amostras.size()):
		acc += Vector2(amostras[i]).distance_to(amostras[i - 1])
		if acc < 1.6:
			continue
		acc = 0.0
		if rng.randf() < 0.45:
			continue
		var p: Vector2 = amostras[i]
		var t2: Vector2 = (Vector2(amostras[i]) - Vector2(amostras[i - 1])).normalized()
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var q2 := p + Vector2(-t2.y, t2.x) * lado * (largura * 0.5 + 0.25 + rng.randf() * 0.2)
		pedra(Vector3(q2.x, _y(q2.x, q2.y), q2.y), 0.16 + rng.randf() * 0.14)
	return mi

func pedra(pos: Vector3, tam := 0.2) -> void:
	if art == null:
		return
	var m: MeshInstance3D = art.box(pos + Vector3(0, tam * 0.3, 0), Vector3(tam * 1.4, tam * 0.7, tam), "lichen_rock", false, self)
	m.rotation.y = rng.randf() * TAU
	m.rotation.x = rng.randf_range(-0.2, 0.2)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func lampiao(p: Vector2) -> Node3D:
	var n := Node3D.new()
	n.name = "Lampiao"
	n.position = Vector3(p.x, _y(p.x, p.y), p.y)
	add_child(n)
	if art:
		art.box(Vector3(0, 0.8, 0), Vector3(0.12, 1.6, 0.12), "wood", false, n)
		art.box(Vector3(0.18, 1.55, 0), Vector3(0.4, 0.07, 0.07), "wood", false, n)
		var lamp: MeshInstance3D = art.box(Vector3(0.34, 1.38, 0), Vector3(0.2, 0.26, 0.2), "glow", false, n)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.box(Vector3(0.34, 1.54, 0), Vector3(0.26, 0.05, 0.26), "iron", false, n)
	if n_luzes < MAX_LUZES:
		n_luzes += 1
		var l := OmniLight3D.new()
		l.light_color = Color("ffb35a")
		l.light_energy = 0.7
		l.omni_range = 4.0
		l.position = Vector3(0.34, 1.35, 0)
		n.add_child(l)
	return n

## placa de bifurcacao: bracos = [[texto, alvo Vector2 (x,z)], ...]. A seta de cada braco e calculada
## pela camera real (direcao na tela), entao "↗ Ruinas" aponta para onde o jogador ve as ruinas.
var placas: Array = []
func placa(p: Vector2, bracos: Array) -> Node3D:
	var n := Node3D.new()
	n.name = "PlacaBifurcacao"
	n.position = Vector3(p.x, _y(p.x, p.y), p.y)
	add_child(n)
	if art:
		art.box(Vector3(0, 0.9, 0), Vector3(0.14, 1.8, 0.14), "brown_planks_03", false, n)
	var l := Label3D.new()
	l.name = "Texto"
	var linhas: Array = []
	for b in bracos:
		linhas.append(String(b[0]))
	l.text = "\n".join(linhas)
	l.font_size = 44
	l.pixel_size = 0.0085
	l.outline_size = 10
	l.modulate = Color("f1e2bd")
	l.outline_modulate = Color(0.12, 0.07, 0.03, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.position = Vector3(0, 2.1 + 0.2 * bracos.size(), 0)
	n.add_child(l)
	if art:
		for i in bracos.size():
			var tab: MeshInstance3D = art.box(Vector3(0, 1.62 - i * 0.27, 0), Vector3(0.95, 0.2, 0.06), "brown_planks_03", false, n)
			var alvo: Vector2 = bracos[i][1]
			var dd := (alvo - p).normalized()
			tab.rotation.y = atan2(-dd.y, dd.x)
			tab.position += Vector3(dd.x, 0, dd.y) * 0.4
	placas.append({"no": n, "rotulo": l, "bracos": bracos, "ok": false})
	return n

const SETAS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
func _process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for pl in placas:
		if pl.ok:
			continue
		var base: Vector3 = pl.no.global_position
		var linhas: Array = []
		for b in pl.bracos:
			var alvo: Vector2 = b[1]
			var v: Vector2 = cam.unproject_position(Vector3(alvo.x, base.y, alvo.y)) - cam.unproject_position(base)
			linhas.append("%s %s" % [SETAS[posmod(roundi(v.angle() / (PI / 4.0)), 8)], b[0]])
		pl.rotulo.text = "\n".join(linhas)
		pl.ok = true
