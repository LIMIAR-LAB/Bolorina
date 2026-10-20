extends Node3D
## Pesca no lago da fazenda: vara (slot 0) na agua -> boia -> espera 1,2-3,5 s -> "!" (fisgou)
## -> usar de novo dentro de 0,9 s pega o peixe. Cedo demais ou tarde demais: escapa.
## Cada lancamento gasta energia (CUSTO.vara).
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const JANELA := 0.9
var g
var estado_pesca := "livre"   # livre | esperando | fisgou
var t := 0.0
var espera := 0.0
var alvo := Vector2i.ZERO
var rng := RandomNumberGenerator.new()
var boia: Node3D
var aviso: Label3D
var linha: MeshInstance3D
var pescados := 0

func montar(game) -> void:
	g = game
	name = "Pesca"
	rng.randomize()
	boia = Node3D.new()
	boia.name = "Boia"
	add_child(boia)
	var vm := StandardMaterial3D.new()
	vm.albedo_color = Color("d8392b")
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color("f4efe4")
	g.vila.kit.ball(boia, Vector3(0, 0.06, 0), Vector3(0.16, 0.12, 0.16), vm)
	g.vila.kit.ball(boia, Vector3(0, 0.14, 0), Vector3(0.1, 0.08, 0.1), bm)
	aviso = Label3D.new()
	aviso.text = "!"
	aviso.font_size = 96
	aviso.pixel_size = 0.006
	aviso.outline_size = 18
	aviso.modulate = Color("ffe14a")
	aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	aviso.no_depth_test = true
	aviso.position = Vector3(0, 0.75, 0)
	boia.add_child(aviso)
	boia.visible = false

func ativa() -> bool:
	return estado_pesca != "livre"

func lago(c: Vector2i) -> bool:
	return g.vila.altura(float(c.x), float(c.y)) < -0.3

## lanca a linha na celula c (agua). Devolve a mensagem.
func lancar(c: Vector2i) -> String:
	if ativa():
		return puxar()
	if not lago(c):
		return "Lance a vara na agua do lago."
	if not g.estado.gastar("vara"):
		return "Cansada demais para pescar. Durma (F9) para recuperar energia."
	alvo = c
	estado_pesca = "esperando"
	t = 0.0
	espera = rng.randf_range(1.2, 3.5)
	var h: float = maxf(g.vila.altura(float(c.x), float(c.y)), -0.55)
	boia.position = Vector3(c.x, h + 0.25, c.y)
	boia.visible = true
	aviso.visible = false
	return "Linha na agua... espere o peixe morder (!) e use a vara de novo."

## usar a vara com a linha na agua
func puxar() -> String:
	match estado_pesca:
		"esperando":
			_fim()
			return "Puxou cedo demais. Nada mordeu."
		"fisgou":
			var p := sortear()
			g.estado.somar(p, 1)
			pescados += 1
			_fim()
			return "Pescou 1 %s! (total %d)" % [String(Estado.PEIXES[p].nome).to_lower(), g.estado.qtd(p)]
	return ""

func sortear() -> String:
	var total := 0
	for k in Estado.PEIXES:
		total += int(Estado.PEIXES[k].chance)
	var r := rng.randi_range(1, total)
	for k in Estado.PEIXES:
		r -= int(Estado.PEIXES[k].chance)
		if r <= 0:
			return k
	return "peixe_carpa"

func _fim() -> void:
	estado_pesca = "livre"
	boia.visible = false
	aviso.visible = false

func cada_quadro(delta: float) -> void:
	if not ativa():
		return
	t += delta
	if estado_pesca == "esperando":
		boia.get_child(0).position.y = 0.06 + sin(t * 3.0) * 0.015
		if t >= espera:
			estado_pesca = "fisgou"
			t = 0.0
			aviso.visible = true
			g.message.text = "Fisgou! Use a vara AGORA (J / clique)."
	elif estado_pesca == "fisgou":
		boia.get_child(0).position.y = 0.06 - absf(sin(t * 22.0)) * 0.08
		if t > JANELA:
			_fim()
			g.message.text = "O peixe escapou... tente de novo."
	# afastou-se demais: recolhe a linha
	if ativa() and Vector2(g.player.position.x - alvo.x, g.player.position.z - alvo.y).length() > 3.5:
		_fim()
		g.message.text = "Linha recolhida."
