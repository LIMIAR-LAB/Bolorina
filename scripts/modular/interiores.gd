extends Node3D
## Interiores das casas da vila V7 (cena de fidelidade), no estilo Stardew: sala em corte
## (parede da frente baixa, fundo e laterais inteiras), grade de 1 m, mobilia modular por
## catalogo (MOVEIS) e plantas de sala por dados (MODELO = template reutilizavel, CASA_VALE = mobiliada).
## E na porta de uma casa: entra (fade) | E no capacho dentro: sai, de volta a porta.
## Luz: lareira e lampioes quentes; janelas com luz fria do crepusculo entrando.
## Nada e salvo (a cena de fidelidade nao grava o save do jogador).
const BASE := Vector3(320, 0, 320)
const ESPACO := 40.0
const ALTURA_PAREDE := 2.7
const TAM_CAMERA := 7.5
const DIST_PORTA := 1.7
const DIST_CAPACHO := 1.3
const FADE := 0.35
## pegada em celulas de 1 m (x, z); solido = colisao; piso = pode ficar sob outros moveis
const MOVEIS := {
	"cama": {"pegada": Vector2i(2,2), "categoria": "dormir"},
	"mesa": {"pegada": Vector2i(2,1), "categoria": "mesa"},
	"cadeira": {"pegada": Vector2i(1,1), "categoria": "assento"},
	"estante": {"pegada": Vector2i(2,1), "categoria": "armazenagem"},
	"lareira": {"pegada": Vector2i(2,1), "categoria": "luz"},
	"tapete": {"pegada": Vector2i(3,2), "categoria": "piso", "piso": true},
	"bau": {"pegada": Vector2i(1,1), "categoria": "armazenagem"},
	"caixote": {"pegada": Vector2i(1,1), "categoria": "armazenagem"},
	"barril": {"pegada": Vector2i(1,1), "categoria": "armazenagem"},
	"planta": {"pegada": Vector2i(1,1), "categoria": "decoracao"},
	"lampiao": {"pegada": Vector2i(1,1), "categoria": "luz"},
	"janela": {"parede": true, "categoria": "janela"},
	"quadro": {"parede": true, "categoria": "decoracao"},
}
## Template reutilizavel: copie, mude "tam"/"moveis" e associe a uma casa em PLANTAS.
const MODELO := {"nome": "Casa simples (modelo)", "tam": [7,5], "moveis": [
	{"id": "janela", "parede": "fundo", "x": -1.5},
	{"id": "planta", "celula": [0,0]},
	{"id": "bau", "celula": [4,0]},
	{"id": "cama", "celula": [5,0]},
	{"id": "tapete", "celula": [2,2]},
	{"id": "mesa", "celula": [1,2], "lampiao": true},
	{"id": "cadeira", "celula": [0,2], "rot": 1},
	{"id": "caixote", "celula": [6,4]},
	{"id": "lampiao", "celula": [0,4]},
]}
const CASA_VALE := {"nome": "Casa da Vale", "tam": [8,6], "moveis": [
	{"id": "estante", "celula": [0,0]},
	{"id": "quadro", "parede": "fundo", "x": -1.5},
	{"id": "lareira", "celula": [3,0]},
	{"id": "bau", "celula": [5,0]},
	{"id": "cama", "celula": [6,0]},
	{"id": "janela", "parede": "fundo", "x": 3.0},
	{"id": "janela", "parede": "esquerda", "z": 0.0},
	{"id": "planta", "celula": [7,2]},
	{"id": "tapete", "celula": [2,2]},
	{"id": "mesa", "celula": [1,3], "lampiao": true},
	{"id": "cadeira", "celula": [0,3], "rot": 1},
	{"id": "cadeira", "celula": [3,3], "rot": 3},
	{"id": "barril", "celula": [0,4]},
	{"id": "caixote", "celula": [0,5]},
	{"id": "caixote", "celula": [1,5]},
	{"id": "planta", "celula": [2,5]},
	{"id": "lampiao", "celula": [5,5]},
	{"id": "planta", "celula": [7,5]},
]}
var game
var kit
var art
var casas: Array[Node3D] = []
var salas: Array[Node3D] = []
var plantas: Array = []
var ativo := -1
var ocupado := false
var conflitos: Array[String] = []
var luzes: Array[Light3D] = []
var cena_luzes_sol: Array[Light3D] = []
var fade_rect: ColorRect
var _modo_demo_antes := false
var _t := 0.0
var _dica := false

func setup(g) -> void:
	game = g
	kit = g.vila.kit
	art = g.art_world
	name = "Interiores"
	_materiais()
	for p in game.vila.lista_pecas:
		if String(p.get_meta("modulo", "")) == "casa":
			casas.append(p)
	for i in casas.size():
		var planta: Dictionary = CASA_VALE if i == 0 else MODELO
		plantas.append(planta)
		var sala := construir(planta, BASE + Vector3(i*ESPACO, 0, 0), "Interior%d" % i)
		sala.visible = false
		salas.append(sala)
	# celulas caminhaveis (island.gd so deixa andar em celulas conhecidas)
	for sala in salas:
		for x in range(-7, 8):
			for z in range(-7, 8):
				var c := Vector2i(roundi(sala.position.x)+x, roundi(sala.position.z)+z)
				if not game.cells.has(c):
					game.cells.append(c)
	var camada := CanvasLayer.new()
	camada.layer = 45
	camada.name = "FadeInterior"
	add_child(camada)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.02, 0.015, 0.03, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fade_rect)

# ---------------------------------------------------------------- consulta
func porta_fora(i: int) -> Vector3:
	return casas[i].to_global(Vector3(0, 0, 2.7))

func saida_fora(i: int) -> Vector3:
	var p := casas[i].to_global(Vector3(0, 0, 3.7))
	return Vector3(p.x, game.vila.altura(p.x, p.z) + 0.4, p.z)

func capacho(i: int) -> Vector3:
	var t: Vector2 = _tam(plantas[i])
	return salas[i].to_global(Vector3(0, 0, t.y*0.5 - 0.55))

func entrada(i: int) -> Vector3:
	var t: Vector2 = _tam(plantas[i])
	return salas[i].to_global(Vector3(0, 0.4, t.y*0.5 - 1.1))

func centro() -> Vector3:
	# ponto medio vertical da sala em tela (piso da frente ate o topo da parede do fundo)
	return salas[ativo].to_global(Vector3(0, ALTURA_PAREDE*0.5, 0)) if ativo >= 0 else Vector3.ZERO

func casa_proxima() -> int:
	var melhor := -1
	var d := DIST_PORTA
	for i in casas.size():
		var p := porta_fora(i)
		var dd := Vector2(p.x - game.player.position.x, p.z - game.player.position.z).length()
		if dd < d:
			d = dd
			melhor = i
	return melhor

func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func moveis(i: int) -> Array[Node3D]:
	var r: Array[Node3D] = []
	for n in salas[i].get_node("Moveis").get_children():
		r.append(n)
	return r

# ---------------------------------------------------------------- tecla E
func tecla_e() -> bool:
	if ocupado:
		return true
	if ativo >= 0:
		if _dist_xz(game.player.position, capacho(ativo)) < DIST_CAPACHO:
			sair()
		else:
			game.message.text = "%s | va ate o capacho da porta e pressione E para sair" % String(plantas[ativo].nome)
		return true
	var i := casa_proxima()
	if i >= 0:
		entrar(i)
		return true
	return false

func entrar(i: int) -> void:
	_transicao(func(): _trocar_para(i))

func sair() -> void:
	_transicao(func(): _trocar_para(-1))

func _transicao(meio: Callable) -> void:
	ocupado = true
	_modo_demo_antes = game.demo_mode
	game.demo_mode = true
	var entrada_demo: Vector2 = game.demo_input
	game.demo_input = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, FADE)
	tw.tween_callback(meio)
	tw.tween_interval(0.08)
	tw.tween_property(fade_rect, "color:a", 0.0, FADE)
	tw.tween_callback(func():
		game.demo_mode = _modo_demo_antes
		game.demo_input = entrada_demo if _modo_demo_antes else Vector2.ZERO
		ocupado = false)

func _trocar_para(i: int) -> void:
	var saindo := ativo
	ativo = i
	for k in salas.size():
		salas[k].visible = k == i
	game.player.velocity = Vector3.ZERO
	if i >= 0:
		if cena_luzes_sol.is_empty():
			for l in game.find_children("*", "DirectionalLight3D", true, false):
				if (l as Light3D).visible:
					cena_luzes_sol.append(l)
		for l in cena_luzes_sol:
			l.visible = false
		game.player.position = entrada(i)
		game.sprite.set_direction(Vector2(0, -1))
		game.message.text = "%s | E no capacho: sair" % String(plantas[i].nome)
	else:
		for l in cena_luzes_sol:
			l.visible = true
		cena_luzes_sol.clear()
		if saindo >= 0:
			game.player.position = saida_fora(saindo)
			game.sprite.set_direction(Vector2(0, 1))
		game.message.text = "De volta a vila."
	game.interior_mudou()

# ---------------------------------------------------------------- por quadro
func cada_quadro(delta: float, env: Environment) -> void:
	_t += delta
	if ativo >= 0:
		# sala: sombras indigo profundas, so as luzes locais aquecem
		env.ambient_light_color = Color("4a3a6c")
		env.ambient_light_energy = 0.75
		env.fog_density = 0.0
		env.fog_height_density = 0.0
		for l in luzes:
			if l.has_meta("base") and l.is_visible_in_tree():
				l.light_energy = float(l.get_meta("base")) * (1.0 + 0.06*sin(_t*9.0 + l.get_instance_id()%7) + 0.04*sin(_t*23.0))
	elif not ocupado:
		var perto := casa_proxima() >= 0
		if perto and not _dica:
			game.message.text = "E: entrar na casa"
		elif _dica and not perto and game.message.text == "E: entrar na casa":
			game.message.text = ""
		_dica = perto

# ---------------------------------------------------------------- construcao
func _tam(planta: Dictionary) -> Vector2:
	return Vector2(float(planta.tam[0]), float(planta.tam[1]))

func construir(planta: Dictionary, pos: Vector3, nome: String) -> Node3D:
	var sala := Node3D.new()
	sala.name = nome
	sala.position = pos
	# frente da sala (+Z local) virada para a camera: parede da frente em corte
	sala.rotation.y = game.vila.cam_yaw
	add_child(sala)
	var t := _tam(planta)
	_paredes(sala, t)
	var grupo := Node3D.new()
	grupo.name = "Moveis"
	sala.add_child(grupo)
	var ocup := {}
	# celula da porta reservada (frente, centro)
	var porta_cel := [Vector2i(int(t.x/2.0) - (1 if int(t.x) % 2 == 0 else 0), int(t.y)-1), Vector2i(int(t.x/2.0), int(t.y)-1)]
	for c in porta_cel:
		ocup[c] = "porta"
	for m in planta.moveis:
		var id: String = m.id
		var info: Dictionary = MOVEIS.get(id, {})
		var n := Node3D.new()
		n.name = id
		n.set_meta("modulo", id)
		n.set_meta("categoria", info.get("categoria", "outro"))
		if info.get("parede", false):
			_na_parede(n, m, t)
		else:
			var rot := int(m.get("rot", 0))
			var peg: Vector2i = info.pegada
			if rot % 2 == 1:
				peg = Vector2i(peg.y, peg.x)
			var cel := Vector2i(int(m.celula[0]), int(m.celula[1]))
			n.set_meta("celula", cel)
			n.set_meta("pegada", peg)
			n.position = Vector3(cel.x + peg.x*0.5 - t.x*0.5, 0, cel.y + peg.y*0.5 - t.y*0.5)
			n.rotation.y = rot*PI/2
			if cel.x < 0 or cel.y < 0 or cel.x + peg.x > int(t.x) or cel.y + peg.y > int(t.y):
				conflitos.append("%s/%s fora da sala" % [nome, id])
			if not info.get("piso", false):
				for x in peg.x:
					for z in peg.y:
						var c := Vector2i(cel.x+x, cel.y+z)
						if ocup.has(c):
							conflitos.append("%s/%s sobre %s em %s" % [nome, id, ocup[c], str(c)])
						ocup[c] = id
		grupo.add_child(n)
		call("_m_"+id, n, m)
	return sala

func _paredes(sala: Node3D, t: Vector2) -> void:
	var w := t.x
	var d := t.y
	var h := ALTURA_PAREDE
	# vazio escuro ao redor (como o fundo preto do Stardew)
	var vazio := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 70)
	vazio.mesh = pm
	vazio.material_override = _mat_u(Color("07060c"))
	vazio.position.y = -0.3
	sala.add_child(vazio)
	kit.box(sala, Vector3(0, -0.1, 0), Vector3(w+0.5, 0.2, d+0.5), "brown_planks_03", true)
	# tabuas do piso: faixas alternadas para detalhe
	for i in int(w*2):
		if i % 3 == 0:
			kit.box(sala, Vector3(-w*0.5 + 0.25 + i*0.5, 0.004, 0), Vector3(0.03, 0.01, d), "int_junta")
	# fundo
	kit.box(sala, Vector3(0, h*0.5, -d*0.5-0.12), Vector3(w+0.5, h, 0.24), "plastered_stone_wall", true)
	kit.box(sala, Vector3(0, 0.3, -d*0.5-0.02), Vector3(w+0.5, 0.6, 0.1), "castle_brick_01")
	kit.box(sala, Vector3(0, h-0.08, -d*0.5-0.02), Vector3(w+0.5, 0.16, 0.12), "wood")
	var x := -w*0.5
	while x <= w*0.5 + 0.01:
		kit.box(sala, Vector3(x, h*0.5, -d*0.5+0.0), Vector3(0.16, h, 0.12), "wood")
		x += 2.0
	# laterais
	for s in [-1.0, 1.0]:
		kit.box(sala, Vector3(s*(w*0.5+0.12), h*0.5, 0), Vector3(0.24, h, d+0.5), "plastered_stone_wall", true)
		kit.box(sala, Vector3(s*(w*0.5+0.02), 0.3, 0), Vector3(0.1, 0.6, d+0.3), "castle_brick_01")
		kit.box(sala, Vector3(s*(w*0.5+0.02), h-0.08, 0), Vector3(0.12, 0.16, d+0.3), "wood")
	# frente em corte com vao da porta
	var vao := 1.3
	var seg := (w - vao)*0.5
	for s in [-1.0, 1.0]:
		kit.box(sala, Vector3(s*(vao*0.5 + seg*0.5), 0.3, d*0.5+0.12), Vector3(seg+0.25, 0.6, 0.24), "castle_brick_01", true)
		kit.box(sala, Vector3(s*(vao*0.5 + 0.08), 0.45, d*0.5+0.12), Vector3(0.16, 0.9, 0.3), "wood")
	# barreira invisivel no vao (sai-se com E no capacho)
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(vao, 2.0, 0.3)
	col.shape = forma
	corpo.position = Vector3(0, 1.0, d*0.5+0.15)
	corpo.add_child(col)
	sala.add_child(corpo)
	# capacho
	kit.box(sala, Vector3(0, 0.012, d*0.5-0.45), Vector3(1.1, 0.025, 0.6), "int_capacho")
	kit.box(sala, Vector3(0, 0.02, d*0.5-0.45), Vector3(0.9, 0.025, 0.42), "kit_palha")

func _na_parede(n: Node3D, m: Dictionary, t: Vector2) -> void:
	match String(m.parede):
		"fundo":
			n.position = Vector3(float(m.get("x", 0.0)), 0, -t.y*0.5)
		"esquerda":
			n.position = Vector3(-t.x*0.5, 0, float(m.get("z", 0.0)))
			n.rotation.y = PI/2
		"direita":
			n.position = Vector3(t.x*0.5, 0, float(m.get("z", 0.0)))
			n.rotation.y = -PI/2

# ---------------------------------------------------------------- materiais
func _materiais() -> void:
	var cores := {"int_assoalho": "8a6440", "int_junta": "3a2616", "int_lencol": "e6dcc4", "int_cobertor": "8e2f2a", "int_cobertor2": "c98b3a",
		"int_capacho": "5a3a22", "int_livro1": "7a2a2a", "int_livro2": "2f4a6e", "int_livro3": "4f6b2e", "int_livro4": "b88a3a",
		"int_tapete_borda": "6e1f24", "int_tapete_meio": "2c2a5c", "int_tapete_det": "c9a04a", "int_pedra_escura": "1e1714",
		"int_cortina": "9b3a30", "int_cesto": "a07a44", "int_vaso": "9a5a3a", "int_quadro": "5b7aa0"}
	for k in cores:
		if not art.materials.has(k):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(cores[k])
			m.roughness = 0.9
			art.materials[k] = m
	var emissores := {"int_vidro": [Color("8297e8"), 0.8], "int_brasa": [Color("ff6a1c"), 1.8], "int_chama": [Color("ffb45a"), 1.6], "int_quadro_luz": [Color("e8b46a"), 0.0]}
	for k in emissores:
		if not art.materials.has(k):
			var m := StandardMaterial3D.new()
			m.albedo_color = emissores[k][0]
			m.emission_enabled = float(emissores[k][1]) > 0.0
			m.emission = emissores[k][0]
			m.emission_energy_multiplier = float(emissores[k][1])
			art.materials[k] = m

func _mat_u(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

func _luz(n: Node3D, pos: Vector3, cor: Color, energia: float, alcance: float, sombra := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.4
	l.shadow_enabled = sombra
	l.set_meta("base", energia)
	l.set_meta("tipo", "quente")
	n.add_child(l)
	luzes.append(l)
	return l

func _solido(n: Node3D, centro: Vector3, tam: Vector3) -> void:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tam
	col.shape = forma
	corpo.position = centro
	corpo.add_child(col)
	n.add_child(corpo)

# ---------------------------------------------------------------- mobilia (origem = centro da pegada no piso, frente = +Z)
func _m_cama(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.22, 0.05), Vector3(1.35, 0.3, 1.95), "wood")
	for x in [-0.62, 0.62]:
		for z in [-0.88, 0.95]:
			kit.box(n, Vector3(x, 0.2, z), Vector3(0.1, 0.4, 0.1), "kit_madeira_escura")
	kit.box(n, Vector3(0, 0.45, 0.05), Vector3(1.25, 0.18, 1.85), "int_lencol")
	kit.box(n, Vector3(0, 0.56, 0.38), Vector3(1.3, 0.1, 1.2), "int_cobertor")
	kit.box(n, Vector3(0, 0.615, 0.38), Vector3(1.0, 0.02, 0.9), "int_cobertor2")
	kit.box(n, Vector3(0, 0.6, -0.65), Vector3(0.85, 0.14, 0.38), "int_lencol")
	kit.box(n, Vector3(0, 0.6, -0.97), Vector3(1.45, 1.0, 0.12), "kit_madeira_escura")
	kit.box(n, Vector3(0, 1.12, -0.97), Vector3(1.55, 0.1, 0.16), "wood")
	_solido(n, Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 2.0))

func _m_mesa(n: Node3D, m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.74, 0), Vector3(1.75, 0.08, 0.85), "brown_planks_03")
	for x in [-0.75, 0.75]:
		for z in [-0.33, 0.33]:
			kit.box(n, Vector3(x, 0.36, z), Vector3(0.09, 0.72, 0.09), "kit_madeira_escura")
	kit.box(n, Vector3(0, 0.2, 0), Vector3(1.5, 0.06, 0.06), "kit_madeira_escura")
	# pao, caneca, tigela de abobora
	kit.box(n, Vector3(-0.45, 0.83, 0.05), Vector3(0.32, 0.1, 0.2), "int_cobertor2")
	kit.ball(n, Vector3(0.1, 0.84, -0.12), Vector3(0.22, 0.12, 0.22), art.materials["kit_abobora"])
	kit.box(n, Vector3(0.45, 0.84, 0.15), Vector3(0.09, 0.12, 0.09), "iron")
	if m.get("lampiao", false):
		kit.box(n, Vector3(0.55, 0.81, -0.2), Vector3(0.16, 0.06, 0.16), "iron")
		kit.box(n, Vector3(0.55, 0.92, -0.2), Vector3(0.12, 0.16, 0.12), "int_chama")
		kit.box(n, Vector3(0.55, 1.03, -0.2), Vector3(0.16, 0.04, 0.16), "iron")
		_luz(n, Vector3(0.55, 0.93, -0.2), Color("ffb066"), 1.4, 4.8, false)
	_solido(n, Vector3(0, 0.4, 0), Vector3(1.75, 0.8, 0.85))

func _m_cadeira(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.45, 0.02), Vector3(0.46, 0.06, 0.44), "brown_planks_03")
	for x in [-0.19, 0.19]:
		for z in [-0.17, 0.19]:
			kit.box(n, Vector3(x, 0.22, z), Vector3(0.06, 0.45, 0.06), "kit_madeira_escura")
	for x in [-0.19, 0.19]:
		kit.box(n, Vector3(x, 0.72, -0.19), Vector3(0.06, 0.55, 0.06), "kit_madeira_escura")
	kit.box(n, Vector3(0, 0.85, -0.19), Vector3(0.44, 0.16, 0.05), "brown_planks_03")
	kit.box(n, Vector3(0, 0.49, 0.03), Vector3(0.36, 0.03, 0.34), "int_cobertor")
	_solido(n, Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.5))

func _m_estante(n: Node3D, _m: Dictionary) -> void:
	var cores := ["int_livro1", "int_livro2", "int_livro3", "int_livro4"]
	kit.box(n, Vector3(0, 1.0, -0.3), Vector3(1.8, 2.0, 0.06), "kit_madeira_escura")
	for x in [-0.88, 0.88]:
		kit.box(n, Vector3(x, 1.0, -0.08), Vector3(0.08, 2.0, 0.46), "wood")
	var r := RandomNumberGenerator.new()
	r.seed = 4411
	for i in 5:
		var y := 0.08 + i*0.47
		kit.box(n, Vector3(0, y, -0.08), Vector3(1.72, 0.05, 0.44), "wood")
		if i == 4:
			continue
		var x := -0.8
		while x < 0.78:
			var larg := r.randf_range(0.06, 0.12)
			if r.randf() < 0.18:
				kit.ball(n, Vector3(x+0.08, y+0.13, -0.05), Vector3(0.16, 0.2, 0.16), art.materials["int_vaso" if r.randf() < 0.5 else "int_quadro"])
				x += 0.2
				continue
			var alt := r.randf_range(0.24, 0.38)
			kit.box(n, Vector3(x+larg*0.5, y+0.025+alt*0.5, -0.1), Vector3(larg, alt, 0.3), cores[r.randi() % 4])
			x += larg + 0.012
	# cesto em cima
	kit.box(n, Vector3(-0.4, 2.12, -0.08), Vector3(0.4, 0.2, 0.3), "int_cesto")
	_solido(n, Vector3(0, 1.0, -0.08), Vector3(1.85, 2.0, 0.5))

func _m_lareira(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.75, -0.18), Vector3(2.0, 1.5, 0.64), "castle_brick_01")
	kit.box(n, Vector3(0, 0.45, 0.0), Vector3(1.0, 0.8, 0.5), "int_pedra_escura")
	kit.box(n, Vector3(0, 0.06, 0.25), Vector3(2.2, 0.12, 0.5), "castle_brick_01")
	kit.box(n, Vector3(0, 1.55, 0.0), Vector3(2.25, 0.12, 0.72), "wood")
	kit.box(n, Vector3(0, 2.15, -0.3), Vector3(1.2, 1.1, 0.4), "castle_brick_01")
	# brasas e lenha
	kit.box(n, Vector3(0, 0.12, 0.08), Vector3(0.8, 0.05, 0.3), "int_brasa")
	for i in 3:
		kit.box(n, Vector3(-0.22 + i*0.22, 0.2, 0.08), Vector3(0.12, 0.12, 0.42), "kit_madeira_escura")
	kit._fire(n, Vector3(0, 0.22, 0.12), 0.7)
	var l := _luz(n, Vector3(0, 1.0, 0.75), Color("ff9a48"), 3.0, 7.5)
	l.shadow_enabled = true
	# objetos na cornija: velas e jarra
	for x in [-0.8, 0.8]:
		kit.box(n, Vector3(x, 1.7, 0.05), Vector3(0.08, 0.2, 0.08), "int_lencol")
		kit.box(n, Vector3(x, 1.83, 0.05), Vector3(0.04, 0.06, 0.04), "int_chama")
	kit.ball(n, Vector3(0.25, 1.72, 0.05), Vector3(0.2, 0.24, 0.2), art.materials["int_vaso"])
	_solido(n, Vector3(0, 0.8, -0.1), Vector3(2.1, 1.6, 0.8))

func _m_tapete(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.008, 0), Vector3(2.7, 0.016, 1.7), "int_tapete_borda")
	kit.box(n, Vector3(0, 0.012, 0), Vector3(2.4, 0.016, 1.4), "int_tapete_det")
	kit.box(n, Vector3(0, 0.016, 0), Vector3(2.3, 0.016, 1.3), "int_tapete_meio")
	for x in [-0.8, 0.0, 0.8]:
		kit.box(n, Vector3(x, 0.02, 0), Vector3(0.22, 0.016, 0.22), "int_tapete_det")

func _m_bau(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.25, 0), Vector3(0.85, 0.5, 0.55), "kit_madeira_escura")
	kit.box(n, Vector3(0, 0.55, 0), Vector3(0.88, 0.12, 0.58), "wood")
	for x in [-0.3, 0.3]:
		kit.box(n, Vector3(x, 0.32, 0), Vector3(0.06, 0.62, 0.6), "iron")
	kit.box(n, Vector3(0, 0.42, 0.29), Vector3(0.1, 0.12, 0.03), "kit_dourado")
	_solido(n, Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6))

func _m_caixote(n: Node3D, _m: Dictionary) -> void:
	var c: Node3D = kit.make("caixote")
	n.add_child(c)
	_solido(n, Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.8))

func _m_barril(n: Node3D, _m: Dictionary) -> void:
	var c: Node3D = kit.make("barril")
	n.add_child(c)
	_solido(n, Vector3(0, 0.45, 0), Vector3(0.7, 0.9, 0.7))

func _m_planta(n: Node3D, m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.17, 0), Vector3(0.36, 0.34, 0.36), "int_vaso")
	kit.box(n, Vector3(0, 0.35, 0), Vector3(0.4, 0.05, 0.4), "int_vaso")
	var s := int(n.get_instance_id() % 97)
	kit.foliage_instance(n, kit.foliage_mesh(46, Vector3(0.32, 0.6, 0.32), Color("2f5524"), Color("6c8f34"), Color("d8c05a"), 0.12, 300+s), Vector3(0, 0.38, 0), 1.0)
	_solido(n, Vector3(0, 0.4, 0), Vector3(0.45, 0.8, 0.45))

func _m_lampiao(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 0.04, 0), Vector3(0.36, 0.08, 0.36), "iron")
	kit.box(n, Vector3(0, 0.75, 0), Vector3(0.06, 1.4, 0.06), "iron")
	kit.box(n, Vector3(0, 1.52, 0), Vector3(0.24, 0.3, 0.24), "int_chama")
	kit.box(n, Vector3(0, 1.7, 0), Vector3(0.3, 0.06, 0.3), "iron")
	_luz(n, Vector3(0, 1.52, 0), Color("ffa850"), 1.6, 5.5, false)
	_solido(n, Vector3(0, 0.8, 0), Vector3(0.4, 1.6, 0.4))

func _m_janela(n: Node3D, _m: Dictionary) -> void:
	# moldura, vidro com luz fria do crepusculo, cruz, peitoril e cortinas
	kit.box(n, Vector3(0, 1.65, 0.03), Vector3(1.05, 1.15, 0.1), "wood")
	kit.box(n, Vector3(0, 1.65, 0.06), Vector3(0.85, 0.95, 0.04), "int_vidro")
	kit.box(n, Vector3(0, 1.65, 0.09), Vector3(0.05, 0.95, 0.04), "wood")
	kit.box(n, Vector3(0, 1.65, 0.09), Vector3(0.85, 0.05, 0.04), "wood")
	kit.box(n, Vector3(0, 1.05, 0.12), Vector3(1.15, 0.07, 0.24), "wood")
	for s in [-1.0, 1.0]:
		kit.box(n, Vector3(s*0.62, 1.6, 0.1), Vector3(0.18, 1.3, 0.05), "int_cortina")
	kit.box(n, Vector3(0, 2.28, 0.1), Vector3(1.5, 0.05, 0.05), "iron")
	kit.ball(n, Vector3(-0.3, 1.16, 0.12), Vector3(0.14, 0.14, 0.14), art.materials["int_vaso"])
	var luz := SpotLight3D.new()
	luz.position = Vector3(0, 2.0, 0.25)
	luz.basis = Basis.looking_at(Vector3(0, -0.62, 0.78), Vector3.UP)
	luz.light_color = Color("a3b2ff")
	luz.light_energy = 3.0
	luz.spot_range = 6.5
	luz.spot_angle = 34
	luz.shadow_enabled = true
	luz.set_meta("tipo", "fria")
	n.add_child(luz)
	luzes.append(luz)
	# feixe de luz suave (aditivo) no chao
	var feixe := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.9, 1.6)
	feixe.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.albedo_color = Color(0.45, 0.52, 0.95, 0.16)
	feixe.material_override = fm
	feixe.position = Vector3(0, 0.03, 1.3)
	feixe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(feixe)

func _m_quadro(n: Node3D, _m: Dictionary) -> void:
	kit.box(n, Vector3(0, 1.7, 0.03), Vector3(0.7, 0.55, 0.05), "kit_madeira_escura")
	kit.box(n, Vector3(0, 1.7, 0.06), Vector3(0.58, 0.43, 0.02), "int_quadro")
	kit.box(n, Vector3(0.08, 1.62, 0.075), Vector3(0.3, 0.12, 0.01), "int_livro3")
	kit.ball(n, Vector3(-0.12, 1.8, 0.075), Vector3(0.1, 0.1, 0.01), art.materials["int_cobertor2"])
