extends Node3D
## Minas da Cinza: dungeon sob Porto Velho (PROPOSTA, não é canon).
## Cena autônoma e jogável: cada andar é gerado por scripts/minas_da_cinza/gerador_minas.gd
## (semente fixa por andar), com rocha em corte para a câmera isométrica, trilhos de vagoneta,
## lanternas, tochas, cristais de brasa, neblina baixa, marcadores de minério (dados de
## data/forja/materiais.json), marcadores de inimigos (só marcadores), escadas/saídas,
## navegação assada, jogadora provisória e moradores via InteracaoNpcs.spawn_em_marcadores.
##
## Andar: propriedade "andar" (1-12 e 20) ou variável de ambiente MINAS_ANDAR.
## Capturas: VG_CAPTURA=/pasta  (gera as imagens do andar e sai). MINAS_SEM_NAV=1 pula a navegação.
## Gancho de dados: nos_de_minerio(), minerar(id, picareta_id, inventario), sinal minerio_minerado.

signal minerio_minerado(no_id: String, material: String, quantidade: int)
signal trocou_de_andar(de: int, para: int)
signal saiu_para_porto_velho

const Gerador = preload("res://scripts/minas_da_cinza/gerador_minas.gd")
const Interacao = preload("res://scripts/dialogos/interacao_npcs.gd")
const Forja = preload("res://scripts/forja/forja.gd")
const NpcsMinas = preload("res://scripts/minas_da_cinza/npcs_minas.gd")
const CENA_GENERICA := "res://scenes/minas_da_cinza/minas_da_cinza.tscn"
const CAMERA_OFFSET := Vector3(24, 24, 24)
const TAM_CAMERA := 21.5
const ALTO := 3.4       # altura da rocha que não tapa nada
const BAIXO := 0.8      # rocha "em corte" na frente dos salões
const INIMIGO_ORC := "res://scripts/combate/inimigo_orc.gd"
const COR_MINERIO := {
	"minerio_cobre": ["e07a3a", 1.1], "minerio_ferro": ["b8c4d0", 0.5], "carvao": ["2a2420", 0.0],
	"minerio_adamantium": ["7af4ff", 3.2],
}

@export var andar := 1
@export var mostrar_marcadores := true

var g                              # gerador_minas.gd
var forja
var materiais_json: Array = []
var materiais_do_andar: Array = []
var raiz: Node3D
var marcadores: Node3D
var nos_minerio: Node3D
var inimigos: Node3D
var jogador: CharacterBody3D
var camera: Camera3D
var dialogos: Node
var navegacao: NavigationRegion3D
var npcs: Array = []
var demo_mode := false
var zoom := 1.0
var visao_geral := false
var stats := {}
var luzes: Array = []           # [{"luz", "base", "fase"}]
var pulsantes: Array = []
var _mats := {}
var _cache := {}
var _altura := {}               # Vector2i -> altura da rocha
var _ocupadas := {}             # células já usadas por algo
var _aviso: Label3D
var _alvo_saida: Marker3D
var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	if OS.get_environment("MINAS_ANDAR") != "":
		andar = int(OS.get_environment("MINAS_ANDAR"))
	andar = clampi(andar, 1, 20)
	if andar > 12 and andar < 20:
		andar = 20
	name = "MinasDaCinza"
	forja = Forja.new()
	materiais_json = _ler_materiais()
	g = Gerador.new(andar)
	g.gerar()
	_rng.seed = g.semente + 17
	materiais_do_andar = Gerador.materiais_do_andar(andar, materiais_json)
	raiz = Node3D.new()
	raiz.name = "Andar%02d" % andar
	add_child(raiz)
	marcadores = Node3D.new()
	marcadores.name = "Marcadores"
	add_child(marcadores)
	nos_minerio = Node3D.new()
	nos_minerio.name = "NosDeMinerio"
	add_child(nos_minerio)
	inimigos = Node3D.new()
	inimigos.name = "SpawnsDeInimigos"
	add_child(inimigos)
	for c in g.caminho:
		_ocupadas[c] = true
	_rocha_e_chao()
	_trilhos()
	_saidas()
	if andar >= 20:
		_coracao_soterrado()
	_minerios()
	_inimigos()
	_npcs_marcadores()
	_lanternas_e_tochas()
	_cristais_de_brasa()
	_aderecos()
	_ambiente()
	_jogador_e_camera()
	if OS.get_environment("MINAS_SEM_NAV") == "":
		navegacao = assar_navegacao()
	_ligar_dialogos()
	_visuais_npcs()
	stats.merge({"andar": andar, "estilo": g.estilo, "grade": "%dx%d" % [g.w, g.h], "chao": g.distancia.size(),
		"minerios": nos_minerio.get_child_count(), "inimigos": inimigos.get_child_count(), "npcs": npcs.size(),
		"luzes": luzes.size(), "trilho": g.caminho.size()}, true)
	print("[minas_da_cinza] andar %d montado em %d ms | %s" % [andar, Time.get_ticks_msec() - t0, JSON.stringify(stats)])
	if OS.get_environment("VG_CAPTURA") != "":
		_capturas(OS.get_environment("VG_CAPTURA"))

func _ler_materiais() -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(Gerador.MATERIAIS))
	return d.get("materiais", []) if d is Dictionary else []

# ------------------------------------------------------------------ materiais
func _tex(n: String) -> Texture2D:
	var p := "res://art/materials/minas_da_cinza/" + n
	return load(p) if ResourceLoader.exists(p) else null

func mat(nome: String) -> StandardMaterial3D:
	if _mats.has(nome):
		return _mats[nome]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.92
	match nome:
		"rocha", "rocha_topo", "chao":
			var base := "rocky_trail" if nome == "chao" else "rock_wall_10"
			m.albedo_texture = _tex(base + "_diff.jpg")
			m.normal_enabled = true
			m.normal_texture = _tex(base + "_nor_gl.jpg")
			m.normal_scale = 0.8
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * (0.22 if nome == "chao" else 0.3)
			m.vertex_color_use_as_albedo = true
			m.albedo_color = {"rocha": Color("b39c88"), "rocha_topo": Color("6e5a4c"), "chao": Color("b39a80")}[nome]
			if andar >= 6 and andar < 20:
				# andares de ferro: pedra mais fria e acinzentada
				m.albedo_color = {"rocha": Color("a3a2a6"), "rocha_topo": Color("5c5c66"), "chao": Color("a0988e")}[nome]
		"madeira":
			m.albedo_color = Color("7a5232")
		"trilho":
			m.albedo_color = Color("6c6a70")
			m.metallic = 0.7
			m.roughness = 0.45
		"corda":
			m.albedo_color = Color("a88a5a")
		"poco":
			m.albedo_color = Color("120d0a")
		"brasa", "brasa_forte", "lava":
			m.albedo_color = Color("ff7a2a") if nome != "lava" else Color("ff5a12")
			m.emission_enabled = true
			m.emission = Color("ff6a1a") if nome != "lava" else Color("ff4a0a")
			m.emission_energy_multiplier = {"brasa": 2.2, "brasa_forte": 4.0, "lava": 3.0}[nome]
			m.roughness = 0.3
		"vidro_lanterna":
			m.albedo_color = Color("ffd08a")
			m.emission_enabled = true
			m.emission = Color("ffb35a")
			m.emission_energy_multiplier = 3.0
		"marcador_orc", "marcador_morcego", "marcador_lodo_de_cinza":
			var c: Color = {"marcador_orc": Color("e03a2a"), "marcador_morcego": Color("9a5ad0"), "marcador_lodo_de_cinza": Color("8a8a7a")}[nome]
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 1.2
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_:
			if nome.begins_with("minerio:"):
				var id := nome.substr(8)
				var info: Array = COR_MINERIO.get(id, ["d8c070", 0.8])
				m.albedo_color = Color(String(info[0]))
				m.roughness = 0.35
				m.metallic = 0.4 if id != "carvao" else 0.0
				if float(info[1]) > 0.0:
					m.emission_enabled = true
					m.emission = Color(String(info[0]))
					m.emission_energy_multiplier = float(info[1])
	_mats[nome] = m
	return m

func _carregar(caminho: String) -> PackedScene:
	if not _cache.has(caminho):
		var p := "res://art/models/" + caminho
		_cache[caminho] = load(p) if ResourceLoader.exists(p) else null
	return _cache[caminho]

func modelo(caminho: String, pai: Node3D, pos: Vector3, rot_y := 0.0, escala := 1.0, colisao := Vector3.ZERO) -> Node3D:
	var cena := _carregar(caminho)
	var n: Node3D
	if cena:
		n = cena.instantiate()
	else:
		n = Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * escala
	pai.add_child(n)
	if colisao != Vector3.ZERO:
		var b := StaticBody3D.new()
		b.add_to_group("navegavel_minas")
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = colisao
		cs.shape = s
		cs.position.y = colisao.y * 0.5
		b.add_child(cs)
		b.position = pos
		b.rotation.y = rot_y
		pai.add_child(b)
	stats["modelos"] = int(stats.get("modelos", 0)) + 1
	return n

func _malha(pai: Node3D, m: Mesh, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	pai.add_child(mi)
	return mi

func _grupo(nome: String) -> Node3D:
	var n := raiz.get_node_or_null(nome)
	if n == null:
		n = Node3D.new()
		n.name = nome
		raiz.add_child(n)
	return n

func _rotulo(pai: Node3D, texto: String, pos: Vector3, cor := Color("f6e2b8"), tam := 1.0) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 64
	l.pixel_size = 0.0115 * tam
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = cor
	l.outline_modulate = Color("1a110b")
	l.position = pos
	pai.add_child(l)
	return l

func _luz(pai: Node3D, pos: Vector3, cor: Color, energia: float, alcance: float, tremula := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.omni_attenuation = 1.1
	l.position = pos
	l.shadow_enabled = false
	pai.add_child(l)
	if tremula:
		luzes.append({"luz": l, "base": energia, "fase": _rng.randf() * TAU})
	return l

# ------------------------------------------------------------------ geometria (SurfaceTool)
const _FACES := [
	[Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
	[Vector3(1, 0, 0), [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
	[Vector3(-1, 0, 0), [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)]],
	[Vector3(0, 0, 1), [Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1)]],
	[Vector3(0, 0, -1), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
]

func _caixa(st: SurfaceTool, xf: Transform3D, tam: Vector3, cor: Color, faces := 31) -> void:
	var meio := tam * 0.5
	for k in _FACES.size():
		if not (faces & (1 << k)):
			continue
		var n: Vector3 = (xf.basis * _FACES[k][0]).normalized()
		var vs: Array = []
		for v in _FACES[k][1]:
			vs.append(xf * (v * meio))
		var sombra := cor * (1.0 if k == 0 else 0.86)
		sombra.a = 1.0
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_color(sombra)
			st.add_vertex(vs[idx])

func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _fechar(st: SurfaceTool, pai: Node3D, material: Material, nome: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	mi.material_override = material
	pai.add_child(mi)
	return mi

## a rocha tapa algum chão visto da câmera (que olha de +x,+z)?
func _tapa_chao(c: Vector2i) -> bool:
	for d in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(-2, -2), Vector2i(-2, 0), Vector2i(0, -2)]:
		var v: int = g.valor(c + d)
		if v != Gerador.ROCHA:
			return true
	return false

func _encosta_chao(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if g.valor(c + Vector2i(dx, dy)) != Gerador.ROCHA:
				return true
	return false

func _rocha_e_chao() -> void:
	var grupo := _grupo("RochaEChao")
	var st_rocha := _st()
	var st_topo := _st()
	var st_chao := _st()
	var st_poco := _st()
	var col_chao := _st()
	var col_paredes := _st()
	var C: float = Gerador.CELULA
	var ruido := FastNoiseLite.new()
	ruido.seed = g.semente
	ruido.frequency = 0.21
	for y in range(-1, g.h + 1):
		for x in range(-1, g.w + 1):
			var c := Vector2i(x, y)
			var p: Vector3 = g.mundo(c)
			var v: int = g.valor(c)
			if v == Gerador.CHAO:
				# chão: escurece perto da rocha (oclusão falsa) e varia com ruído
				var perto := 0
				for d in g._vizinhos4(c):
					if g.valor(d) == Gerador.ROCHA:
						perto += 1
				var k := 1.0 - 0.09 * perto + ruido.get_noise_2d(x * 3.0, y * 3.0) * 0.2
				_caixa(st_chao, Transform3D(Basis.IDENTITY, p + Vector3(0, -0.1, 0)), Vector3(C, 0.2, C), Color(k, k * 0.97, k * 0.94), 1)
				_caixa(col_chao, Transform3D(Basis.IDENTITY, p + Vector3(0, -0.1, 0)), Vector3(C, 0.2, C), Color.WHITE, 1)
			elif v == Gerador.ROCHA:
				var alto := not _tapa_chao(c)
				var hh := (ALTO + maxf(0.0, ruido.get_noise_2d(x * 1.7, y * 1.7)) * 1.4) if alto else BAIXO + ruido.get_noise_2d(x * 2.3, y * 2.3) * 0.15
				_altura[c] = hh
				var cor := Color(1, 1, 1) if _encosta_chao(c) else Color(0.62, 0.58, 0.56)
				_caixa(st_rocha, Transform3D(Basis.IDENTITY, p + Vector3(0, (hh - 1.2) * 0.5, 0)), Vector3(C, hh + 1.2, C), cor, 30)
				_caixa(st_topo, Transform3D(Basis.IDENTITY, p + Vector3(0, hh - 0.01, 0)), Vector3(C, 0.02, C), Color(1, 1, 1), 1)
				if _encosta_chao(c):
					_caixa(col_paredes, Transform3D(Basis.IDENTITY, p + Vector3(0, 1.0, 0)), Vector3(C, 2.0, C), Color.WHITE)
					# lascas de rocha soltas na face que dá para o chão (só visual)
					for n in _rng.randi_range(1, 2):
						var off := Vector3(_rng.randf_range(-0.7, 0.7), 0, _rng.randf_range(-0.7, 0.7))
						var tam := Vector3(_rng.randf_range(0.8, 1.5), _rng.randf_range(0.5, minf(hh + 0.2, 2.2)), _rng.randf_range(0.8, 1.5))
						var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.2, 0.2))
						_caixa(st_rocha, Transform3D(b, p + off + Vector3(0, tam.y * 0.5 - 0.1, 0)), tam, Color(0.9, 0.86, 0.84))
			else:
				# abismo / poço: paredes escuras para baixo
				var fundo := -2.8 if v == Gerador.POCO else -3.2
				_caixa(st_poco, Transform3D(Basis.IDENTITY, p + Vector3(0, fundo - 0.1, 0)), Vector3(C, 0.2, C), Color(1, 1, 1), 1)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if g.valor(c + d) == Gerador.CHAO:
						var meio := p + Vector3(d.x, 0, d.y) * (C * 0.5)
						var tam := Vector3(0.1 if d.x != 0 else C, -fundo, 0.1 if d.y != 0 else C)
						_caixa(st_rocha, Transform3D(Basis.IDENTITY, meio + Vector3(0, fundo * 0.5, 0)), tam, Color(0.45, 0.4, 0.38))
				# bloqueio invisível (física) para não cair
				_caixa(col_paredes, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.6, 0)), Vector3(C, 1.2, C), Color.WHITE)
	_fechar(st_rocha, grupo, mat("rocha"), "Rocha")
	_fechar(st_topo, grupo, mat("rocha_topo"), "TopoDaRocha")
	_fechar(st_chao, grupo, mat("chao"), "Chao")
	_fechar(st_poco, grupo, mat("poco"), "FundoDosPocos")
	# colisores: o chão entra na navegação; paredes e bloqueios só na física
	var corpo_chao := StaticBody3D.new()
	corpo_chao.name = "ColisaoChao"
	corpo_chao.add_to_group("navegavel_minas")
	var s1 := CollisionShape3D.new()
	s1.shape = col_chao.commit().create_trimesh_shape()
	corpo_chao.add_child(s1)
	grupo.add_child(corpo_chao)
	var corpo_par := StaticBody3D.new()
	corpo_par.name = "ColisaoParedes"
	var s2 := CollisionShape3D.new()
	s2.shape = col_paredes.commit().create_trimesh_shape()
	corpo_par.add_child(s2)
	grupo.add_child(corpo_par)

# ------------------------------------------------------------------ trilhos de vagoneta
func _trilhos() -> void:
	var cam: Array = g.caminho
	if cam.size() < 3:
		return
	var grupo := _grupo("Trilhos")
	var st_ferro := _st()
	var st_mad := _st()
	var pontos: Array = []
	for c in cam:
		pontos.append(g.mundo(c))
	for k in pontos.size() - 1:
		var a: Vector3 = pontos[k]
		var b: Vector3 = pontos[k + 1]
		var dir := (b - a).normalized()
		var lado := dir.cross(Vector3.UP).normalized()
		var bas := Basis.looking_at(dir, Vector3.UP)
		var comp := a.distance_to(b)
		for s in [-0.42, 0.42]:
			var meio: Vector3 = (a + b) * 0.5 + lado * float(s) + Vector3(0, 0.07, 0)
			_caixa(st_ferro, Transform3D(bas, meio), Vector3(0.07, 0.08, comp + 0.08), Color.WHITE)
		for d in [0.0, 0.67, 1.33]:
			var q: Vector3 = a + dir * float(d) + Vector3(0, 0.02, 0)
			_caixa(st_mad, Transform3D(bas, q), Vector3(1.15, 0.06, 0.2), Color(0.85 + _rng.randf() * 0.15, 0.8, 0.75))
	_fechar(st_ferro, grupo, mat("trilho"), "Trilho")
	_fechar(st_mad, grupo, mat("madeira"), "Dormentes")
	# vagonetas paradas nos trechos largos do trilho (com colisão, a navegação desvia)
	var postas := 0
	for frac in [0.35, 0.72]:
		var idx := int(cam.size() * frac)
		for tentativa in 6:
			var j := clampi(idx + tentativa, 1, cam.size() - 2)
			var c: Vector2i = cam[j]
			if g.cercado(c, 1):
				var dir: Vector3 = (g.mundo(cam[j + 1]) - g.mundo(cam[j - 1])).normalized()
				var ang := atan2(dir.x, dir.z)
				var nome := "kenney_train_kit/train-carriage-coal.glb" if postas == 0 else "kenney_train_kit/train-carriage-dirt.glb"
				var v := modelo(nome, grupo, g.mundo(c) + Vector3(0, 0.08, 0), ang, 0.5, Vector3(1.0, 1.0, 1.4))
				v.name = "Vagoneta%d" % postas
				postas += 1
				break

# ------------------------------------------------------------------ saídas e escadas
func _marcador(id: String, pos: Vector3, papel: String, descricao: String, ang := 0.0) -> Marker3D:
	var mk := Marker3D.new()
	mk.name = id
	mk.position = pos
	mk.rotation.y = ang
	mk.set_meta("papel", papel)
	mk.set_meta("descricao", descricao)
	mk.add_to_group("spawn" if id.begins_with("spawn") else ("npc_marcador" if Interacao.id_do_marcador(id) != "" else "saida_minas"))
	marcadores.add_child(mk)
	return mk

func marcador(id: String) -> Marker3D:
	return marcadores.get_node_or_null(id)

func _saidas() -> void:
	var grupo := _grupo("Saidas")
	var e: Vector3 = g.mundo(g.entrada)
	_ocupadas[g.entrada] = true
	_marcador("spawn_jogador", e + Vector3(1.2, 0, 1.2), "spawn", "Chegada ao andar")
	if andar == 1:
		_elevador(grupo, e)
		var s := _marcador("saida_porto_velho", e, "saida", "Elevador do Tião: sobe para a cisterna atrás da Ferraria do Porto (Porto Velho)")
		s.set_meta("destino", "porto_velho")
	else:
		_escada_de_mao(grupo, e)
		var s := _marcador("escada_subir", e, "saida", "Escada de mão para o andar %d" % (andar - 1 if andar < 20 else 12))
		s.set_meta("destino_andar", andar - 1 if andar < 20 else 12)
	if g.escada.x >= 0:
		var p: Vector3 = g.mundo(g.escada)
		_ocupadas[g.escada] = true
		var pa: Vector3 = g.mundo(g.aproximacao)
		var dir := (p - pa).normalized()
		modelo("kaykit_dungeon/stairs_wood.gltf", grupo, p + Vector3(0, -2.75, 0) - dir * 1.0, atan2(-dir.x, -dir.z), 0.5)
		_luz(grupo, p + Vector3(0, -1.6, 0), Color("ff9a4a"), 1.6, 5.0)
		var prox := andar + 1 if andar < 12 else 20
		var texto := "↓ Andar %d" % prox if andar < 12 else "↓ Profundezas\n(13-19 ainda não escavados)\nCoração Soterrado"
		_rotulo(grupo, texto, p + Vector3(0, 2.6, 0), Color("ffd27a"), 1.0)
		var d := _marcador("escada_descer", pa, "escada", "Poço com escada para o andar %d" % prox)
		d.set_meta("destino_andar", prox)
		# suportes de madeira na boca do poço
		modelo("kenney_mini_dungeon/wood-support.glb", grupo, p + Vector3(0, 0, 0), atan2(dir.x, dir.z), 1.0)
	var titulo := _rotulo(grupo, Gerador.nome_do_andar(andar), e + Vector3(4.5, 5.5, -4.5), Color("ffe6b0"), 1.25)
	titulo.name = "TituloDoAndar"

func _elevador(grupo: Node3D, e: Vector3) -> void:
	var el := Node3D.new()
	el.name = "ElevadorDoTiao"
	el.position = e + Vector3(-0.6, 0, -0.6)
	grupo.add_child(el)
	var plat := BoxMesh.new()
	plat.size = Vector3(2.4, 0.16, 2.4)
	_malha(el, plat, Vector3(0, 0.08, 0), mat("madeira"))
	var poste := BoxMesh.new()
	poste.size = Vector3(0.22, 9.0, 0.22)
	for sx in [-1.2, 1.2]:
		for sz in [-1.2, 1.2]:
			_malha(el, poste, Vector3(sx, 4.5, sz), mat("madeira"))
	var trave := BoxMesh.new()
	trave.size = Vector3(2.8, 0.22, 0.22)
	for yy in [2.6, 8.8]:
		_malha(el, trave, Vector3(0, yy, -1.2), mat("madeira"))
		_malha(el, trave, Vector3(0, yy, 1.2), mat("madeira"))
	var roda := CylinderMesh.new()
	roda.top_radius = 0.55
	roda.bottom_radius = 0.55
	roda.height = 0.14
	var r := _malha(el, roda, Vector3(0, 8.9, 0), mat("trilho"), Vector3(0, 0, PI / 2))
	pulsantes.append({"no": r, "tipo": "gira"})
	var corda := CylinderMesh.new()
	corda.top_radius = 0.03
	corda.bottom_radius = 0.03
	corda.height = 8.6
	for sx in [-0.5, 0.5]:
		_malha(el, corda, Vector3(sx, 4.6, 0), mat("corda"))
	var grade_lat := BoxMesh.new()
	grade_lat.size = Vector3(2.4, 0.08, 0.06)
	for yy in [0.55, 1.0]:
		_malha(el, grade_lat, Vector3(0, yy, -1.15), mat("madeira"))
	_luz(el, Vector3(0, 2.3, 0), Color("ffc27a"), 2.2, 9.0)
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.25, 0.32, 0.25)
	_malha(el, lamp, Vector3(1.2, 2.3, 1.2), mat("vidro_lanterna"))
	_rotulo(el, "Elevador do Tião\n↑ Porto Velho (cisterna da Ferraria)", Vector3(0, 3.4, 0), Color("ffe0a0"), 0.95)
	# barulho visual: caixas e barris da cisterna
	modelo("kaykit_dungeon/crates_stacked.gltf", grupo, e + Vector3(2.6, 0, -2.4), 0.3, 0.5, Vector3(1.6, 1.4, 1.6))
	modelo("kaykit_dungeon/barrel_large.gltf", grupo, e + Vector3(-2.6, 0, 2.2), 0.0, 0.45, Vector3(0.8, 0.9, 0.8))
	modelo("kenney_survival_kit/signpost.glb", grupo, e + Vector3(2.4, 0, 1.6), -0.6, 1.4)
	_ocupadas[g.entrada + Vector2i(1, -1)] = true

func _escada_de_mao(grupo: Node3D, e: Vector3) -> void:
	var es := Node3D.new()
	es.name = "EscadaDeMao"
	es.position = e + Vector3(-0.9, 0, -0.9)
	grupo.add_child(es)
	var lado := BoxMesh.new()
	lado.size = Vector3(0.1, 6.5, 0.1)
	var degrau := BoxMesh.new()
	degrau.size = Vector3(0.8, 0.07, 0.07)
	for sx in [-0.4, 0.4]:
		_malha(es, lado, Vector3(sx, 3.2, 0), mat("madeira"), Vector3(-0.12, PI / 4, 0))
	for k in 14:
		_malha(es, degrau, Vector3(0, 0.3 + k * 0.45, -0.05 * k), mat("madeira"), Vector3(0, PI / 4, 0))
	_luz(es, Vector3(0.6, 2.2, 0.6), Color("ffb26a"), 1.6, 7.0)
	_rotulo(es, "↑ Andar %d" % (andar - 1 if andar < 20 else 12), Vector3(0, 3.6, 0), Color("ffe0a0"), 0.95)

# ------------------------------------------------------------------ Coração Soterrado (andar 20)
func _coracao_soterrado() -> void:
	var grupo := _grupo("CoracaoSoterrado")
	var centro := Vector3.ZERO
	var n := 0
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if g.valor(c) == Gerador.ABISMO:
				var p: Vector3 = g.mundo(c)
				centro += p
				n += 1
				var lava := BoxMesh.new()
				lava.size = Vector3(Gerador.CELULA, 0.1, Gerador.CELULA)
				var mi := _malha(grupo, lava, p + Vector3(0, -2.9, 0), mat("lava"))
				if (x + y) % 3 == 0:
					pulsantes.append({"no": mi, "tipo": "lava", "fase": float(x * 0.7 + y)})
	if n > 0:
		centro /= n
		_luz(grupo, centro + Vector3(0, -0.5, 0), Color("ff6a2a"), 6.0, 16.0)
		_luz(grupo, centro + Vector3(4, 0.5, 3), Color("ff7a3a"), 2.5, 10.0)
		_rotulo(grupo, "Abismo de Brasa", centro + Vector3(0, 1.4, 0), Color("ffb070"), 1.0)
		var part := _particulas(Color("ff8a3a"), 160, Vector3(6, 0.5, 6), 3.0, 1.5)
		part.position = centro + Vector3(0, -2.4, 0)
		grupo.add_child(part)
	# porta selada no fim do salão
	var pf: Vector3 = g.mundo(g.aproximacao)
	var porta := modelo("kenney_mini_dungeon/gate.glb", grupo, pf + Vector3(0, 0, 1.0), 0.0, 1.6, Vector3(2.4, 2.4, 0.4))
	porta.name = "PortaSelada"
	modelo("kaykit_dungeon/pillar.gltf", grupo, pf + Vector3(-1.9, 0, 1.0), 0.0, 0.5)
	modelo("kaykit_dungeon/pillar.gltf", grupo, pf + Vector3(1.9, 0, 1.0), 0.0, 0.5)
	_luz(grupo, pf + Vector3(0, 2.0, -0.4), Color("9a7aff"), 2.0, 6.0)
	_rotulo(grupo, "Porta Selada\nsó abre com a Bigorna Cronal (forja nível 5)", pf + Vector3(0, 4.6, 0.6), Color("d8c2ff"), 0.9)
	var s := _marcador("porta_selada", pf, "porta_selada", "Porta selada do Coração Soterrado (teaser: Bigorna Cronal)")
	s.set_meta("requisito", "ferraria_porto nível 5 (Bigorna Cronal)")
	_ocupadas[g.aproximacao] = true
	# sussurros dos veios
	var frases := ["...três e quinze...", "...ainda não...", "...ontem, de novo...", "...quem bateu primeiro?"]
	for k in frases.size():
		var cs: Array = g.celulas_de_parede(_ocupadas)
		if cs.is_empty():
			break
		var c: Vector2i = cs[_rng.randi() % cs.size()]
		var l := _rotulo(grupo, frases[k], g.mundo(c) + Vector3(0, 2.2, 0), Color(0.75, 0.95, 1.0, 0.75), 0.7)
		pulsantes.append({"no": l, "tipo": "sussurro", "fase": k * 1.7})

# ------------------------------------------------------------------ minério (gancho de dados)
func _minerios() -> void:
	var livres: Array = g.celulas_de_parede(_ocupadas)
	_embaralhar(livres)
	var postos: Array = []
	var contagem := {}
	for m in materiais_do_andar:
		var id := String(m.id)
		var principal := String(m.get("tipo", "")) == "minerio"
		var qtd := (5 + andar / 3) if principal else 3
		if andar >= 20 and principal:
			qtd = 7
		for k in qtd:
			var c := _celula_livre(livres, postos, 3)
			if c.x < 0:
				break
			postos.append(c)
			_ocupadas[c] = true
			contagem[id] = int(contagem.get(id, 0)) + 1
			_no_de_minerio(m, c, contagem[id])
	stats["minerio_por_material"] = contagem

func _embaralhar(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var t = a[k]
		a[k] = a[j]
		a[j] = t

func _celula_livre(livres: Array, postos: Array, dist_min: int) -> Vector2i:
	for k in livres.size():
		var c: Vector2i = livres[k]
		if _ocupadas.has(c):
			continue
		var ok := true
		for p in postos:
			if absi(p.x - c.x) + absi(p.y - c.y) < dist_min:
				ok = false
				break
		if ok:
			return c
	return Vector2i(-1, -1)

## nome do marcador: minerio_<material sem o prefixo "minerio_">_<nn>  (ex.: minerio_cobre_03, minerio_carvao_01)
static func nome_no_minerio(material_id: String, n: int) -> String:
	return "minerio_%s_%02d" % [material_id.trim_prefix("minerio_"), n]

func _no_de_minerio(m: Dictionary, c: Vector2i, n: int) -> void:
	var id := String(m.id)
	var p: Vector3 = g.mundo(c)
	# encosta na rocha
	for d in g._vizinhos4(c):
		if g.valor(d) == Gerador.ROCHA:
			p += Vector3(d.x - c.x, 0, d.y - c.y) * 0.45
			break
	var mk := Marker3D.new()
	mk.name = nome_no_minerio(id, n)
	mk.position = p
	mk.add_to_group("minerio_no")
	mk.set_meta("material", id)
	mk.set_meta("nome", String(m.get("nome", id)))
	mk.set_meta("tier", int(m.get("tier", 0)))
	mk.set_meta("picareta_minima", int(m.get("picareta_minima", 0)))
	mk.set_meta("quantidade", [2, 4] if String(m.get("tipo", "")) == "minerio" else [3, 6])
	mk.set_meta("renasce_dias", 2 if andar < 20 else 7)
	mk.set_meta("andar", andar)
	mk.set_meta("esgotado", false)
	nos_minerio.add_child(mk)
	# visual: pedra + cristais na cor do minério
	var vis := Node3D.new()
	vis.name = "Visual"
	vis.scale = Vector3.ONE * 1.35
	mk.add_child(vis)
	var pedras := ["kenney_survival_kit/rock-a.glb", "kenney_survival_kit/rock-b.glb", "kenney_survival_kit/rock-c.glb"]
	modelo(pedras[n % 3], vis, Vector3.ZERO, _rng.randf() * TAU, 0.9)
	var prisma := CylinderMesh.new()
	prisma.top_radius = 0.0
	prisma.bottom_radius = 0.16
	prisma.height = 0.8
	prisma.radial_segments = 5
	prisma.rings = 1
	for k in _rng.randi_range(4, 6):
		var ang := _rng.randf() * TAU
		var off := Vector3(cos(ang), 0, sin(ang)) * _rng.randf_range(0.1, 0.42)
		var s := _rng.randf_range(0.6, 1.25)
		var mi := _malha(vis, prisma, off + Vector3(0, 0.3 * s, 0), mat("minerio:" + id), Vector3(_rng.randf_range(-0.5, 0.5), ang, _rng.randf_range(-0.5, 0.5)))
		mi.scale = Vector3.ONE * s
	var info: Array = COR_MINERIO.get(id, ["d8c070", 0.8])
	if float(info[1]) > 0.8:
		_luz(vis, Vector3(0, 0.8, 0), Color(String(info[0])), 0.9 if andar < 20 else 1.6, 3.5, false)
	if andar >= 20:
		pulsantes.append({"no": vis, "tipo": "pulsa", "fase": n * 0.9})
	var rot := _rotulo(vis, "%s · picareta %d" % [String(m.get("nome", id)).replace("Minério de ", ""), int(m.get("picareta_minima", 0))], Vector3(0, 1.3, 0), Color("ffe9c2"), 0.5)
	rot.name = "Rotulo"

func nos_de_minerio() -> Array:
	var out: Array = []
	for mk in nos_minerio.get_children():
		out.append({"id": String(mk.name), "material": mk.get_meta("material"), "pos": mk.global_position,
			"picareta_minima": mk.get_meta("picareta_minima"), "esgotado": mk.get_meta("esgotado")})
	return out

## Minera um nó: confere a picareta pela forja (data/forja), soma no inventário {"itens": {id: qtd}}
## e marca o nó como esgotado. Retorna {"ok", "material", "quantidade", "motivo"}.
func minerar(no_id: String, picareta_id: String, inv: Dictionary) -> Dictionary:
	var mk: Marker3D = nos_minerio.get_node_or_null(no_id)
	if mk == null:
		return {"ok": false, "motivo": "nó não existe"}
	if mk.get_meta("esgotado"):
		return {"ok": false, "motivo": "esgotado (volta em %d dias)" % int(mk.get_meta("renasce_dias"))}
	var material := String(mk.get_meta("material"))
	if not forja.pode_minerar(material, picareta_id):
		return {"ok": false, "material": material, "motivo": "precisa de picareta nível %d" % int(mk.get_meta("picareta_minima"))}
	var faixa: Array = mk.get_meta("quantidade")
	var r := RandomNumberGenerator.new()
	r.seed = hash(no_id) + g.semente
	var qtd := r.randi_range(int(faixa[0]), int(faixa[1]))
	if not inv.has("itens"):
		inv["itens"] = {}
	inv.itens[material] = int(inv.itens.get(material, 0)) + qtd
	mk.set_meta("esgotado", true)
	var vis := mk.get_node_or_null("Visual")
	if vis:
		vis.visible = false
	minerio_minerado.emit(no_id, material, qtd)
	return {"ok": true, "material": material, "quantidade": qtd, "motivo": ""}

# ------------------------------------------------------------------ inimigos (só marcadores)
func _inimigos() -> void:
	var conta: Dictionary = Gerador.inimigos_do_andar(andar)
	var livres: Array = []
	for c in g.distancia:
		if g.distancia[c] >= 7 and g.cercado(c, 1) and not _ocupadas.has(c):
			livres.append(c)
	livres.sort()
	_embaralhar(livres)
	var postos: Array = []
	for tipo in conta:
		for k in int(conta[tipo]):
			var c := _celula_livre(livres, postos, 4)
			if c.x < 0:
				break
			postos.append(c)
			_ocupadas[c] = true
			var mk := Marker3D.new()
			mk.name = "inimigo_%s_%02d" % [tipo, k + 1]
			mk.position = g.mundo(c)
			mk.add_to_group("inimigo_spawn")
			mk.set_meta("tipo", tipo)
			mk.set_meta("script", INIMIGO_ORC if tipo == "orc" else "")
			mk.set_meta("provisorio", tipo != "orc")
			mk.set_meta("quantidade", 1 if tipo == "orc" else (3 if tipo == "morcego" else 2))
			inimigos.add_child(mk)
			if mostrar_marcadores:
				var anel := TorusMesh.new()
				anel.inner_radius = 0.55
				anel.outer_radius = 0.68
				_malha(mk, anel, Vector3(0, 0.05, 0), mat("marcador_" + tipo))
				var nome: String = {"orc": "orc", "morcego": "morcegos", "lodo_de_cinza": "lodos de cinza"}[tipo]
				_rotulo(mk, "⚔ %s" % nome, Vector3(0, 0.9, 0), Color("ffb0a0") if tipo == "orc" else Color("e0d0ff"), 0.55)

# ------------------------------------------------------------------ moradores (marcadores)
func _npcs_marcadores() -> void:
	var ids: Array = Gerador.NPCS_POR_ANDAR.get(andar, [])
	for id in ids:
		var c := Vector2i(-1, -1)
		var melhor := -1.0
		for cand in g.distancia:
			if _ocupadas.has(cand) or not g.cercado(cand, 1):
				continue
			var d: int = g.distancia[cand]
			var nota := 0.0
			match id:
				"minerador_aposentado": nota = -absf(d - 4.0)
				"vagoneta_falante": nota = -absf(d - 10.0) - (0.0 if _perto_do_trilho(cand) else 30.0)
				"fantasma_mineiro": nota = float(d) if andar < 20 else -absf(d - 8.0)
				"mercador_minerio": nota = -absf(d - g.distancia.size() * 0.02 - 12.0)
				_: nota = -absf(d - 8.0)
			nota += _rng.randf() * 0.5
			if nota > melhor or melhor == -1.0:
				melhor = nota
				c = cand
		if c.x < 0:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				_ocupadas[c + Vector2i(dx, dy)] = true
		var desc: String = NpcsMinas.NPCS.get(id, {}).get("titulo", "")
		_marcador(id, g.mundo(c), "morador", desc, PI * 0.25)

func _perto_do_trilho(c: Vector2i) -> bool:
	for d in g._vizinhos4(c):
		if d in g.caminho:
			return true
	return false

# ------------------------------------------------------------------ luz
func _lanternas_e_tochas() -> void:
	var grupo := _grupo("Lanternas")
	# lanternas penduradas em postes ao longo do trilho
	var cam: Array = g.caminho
	var k := 3
	while k < cam.size() - 1:
		var c: Vector2i = cam[k]
		var dir: Vector3 = (g.mundo(cam[mini(k + 1, cam.size() - 1)]) - g.mundo(cam[k - 1])).normalized()
		var lado := dir.cross(Vector3.UP).normalized()
		_lanterna(grupo, g.mundo(c) + lado * 0.8)
		k += 5
	# tochas presas na rocha alta que olha para o chão (+x / +z, de frente para a câmera)
	var postas := 0
	var faces: Array = []
	for c in _altura:
		if float(_altura[c]) < ALTO - 0.01:
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if g.chao(c + d):
				faces.append([c, d])
	faces.sort()
	_embaralhar(faces)
	var usadas: Array = []
	for f in faces:
		if postas >= 14:
			break
		var c: Vector2i = f[0]
		var ok := true
		for u in usadas:
			if absi(u.x - c.x) + absi(u.y - c.y) < 4:
				ok = false
				break
		if not ok:
			continue
		usadas.append(c)
		var d: Vector2i = f[1]
		var face: Vector3 = g.mundo(c) + Vector3(d.x, 0, d.y) * (Gerador.CELULA * 0.5)
		var ang := 0.0 if d.y == 1 else PI / 2
		modelo("kaykit_dungeon/torch_mounted.gltf", grupo, face + Vector3(0, 1.7, 0), ang, 0.75)
		var chama := SphereMesh.new()
		chama.radius = 0.09
		chama.height = 0.2
		_malha(grupo, chama, face + Vector3(d.x, 0, d.y) * 0.32 + Vector3(0, 2.25, 0), mat("brasa_forte"))
		_luz(grupo, face + Vector3(d.x, 0, d.y) * 0.8 + Vector3(0, 2.3, 0), Color("ff9a40"), 2.0, 8.5)
		postas += 1
	stats["tochas"] = postas

func _lanterna(pai: Node3D, p: Vector3) -> void:
	var n := Node3D.new()
	n.name = "Lanterna"
	n.position = p
	pai.add_child(n)
	var poste := BoxMesh.new()
	poste.size = Vector3(0.12, 2.3, 0.12)
	_malha(n, poste, Vector3(0, 1.15, 0), mat("madeira"))
	var braco := BoxMesh.new()
	braco.size = Vector3(0.5, 0.08, 0.08)
	_malha(n, braco, Vector3(0.2, 2.2, 0), mat("madeira"))
	var vidro := BoxMesh.new()
	vidro.size = Vector3(0.2, 0.28, 0.2)
	_malha(n, vidro, Vector3(0.4, 1.95, 0), mat("vidro_lanterna"))
	_luz(n, Vector3(0.4, 1.9, 0), Color("ffb868"), 1.7, 8.0)

func _cristais_de_brasa() -> void:
	var grupo := _grupo("CristaisDeBrasa")
	var livres: Array = g.celulas_de_parede(_ocupadas)
	_embaralhar(livres)
	var qtd := 10 + andar if andar < 20 else 26
	var postos: Array = []
	var prisma := CylinderMesh.new()
	prisma.top_radius = 0.0
	prisma.bottom_radius = 0.13
	prisma.height = 0.9
	prisma.radial_segments = 6
	prisma.rings = 1
	for k in qtd:
		var c := _celula_livre(livres, postos, 2)
		if c.x < 0:
			break
		postos.append(c)
		_ocupadas[c] = true
		var p: Vector3 = g.mundo(c)
		for d in g._vizinhos4(c):
			if g.valor(d) == Gerador.ROCHA:
				p += Vector3(d.x - c.x, 0, d.y - c.y) * 0.7
				break
		var cl := Node3D.new()
		cl.name = "CristalDeBrasa"
		cl.position = p
		grupo.add_child(cl)
		for j in _rng.randi_range(3, 5):
			var ang := _rng.randf() * TAU
			var s := _rng.randf_range(0.5, 1.2)
			var mi := _malha(cl, prisma, Vector3(cos(ang), 0, sin(ang)) * 0.22 + Vector3(0, 0.35 * s, 0), mat("brasa"), Vector3(_rng.randf_range(-0.6, 0.6), ang, _rng.randf_range(-0.6, 0.6)))
			mi.scale = Vector3.ONE * s
		if k % 3 == 0:
			_luz(cl, Vector3(0, 0.7, 0), Color("ff6a2a"), 1.1, 4.5)
		pulsantes.append({"no": cl, "tipo": "brasa", "fase": k * 0.77})
	stats["cristais_de_brasa"] = postos.size()

# ------------------------------------------------------------------ adereços
func _aderecos() -> void:
	var grupo := _grupo("Aderecos")
	# esteios de madeira nos túneis (células com rocha dos dois lados)
	var esteios := 0
	for c in g.caminho:
		if esteios > 18 or _ocupadas.has(c) and not (c in g.caminho):
			continue
		var ns: bool = g.valor(c + Vector2i(0, -1)) == Gerador.ROCHA and g.valor(c + Vector2i(0, 1)) == Gerador.ROCHA
		var lo: bool = g.valor(c + Vector2i(-1, 0)) == Gerador.ROCHA and g.valor(c + Vector2i(1, 0)) == Gerador.ROCHA
		if (ns or lo) and (c.x + c.y) % 3 == 0:
			modelo("kenney_mini_dungeon/wood-support.glb", grupo, g.mundo(c), 0.0 if lo else PI / 2, 1.0)
			esteios += 1
	stats["esteios"] = esteios
	# caixas, barris, ferramentas e pedras espalhadas
	var livres: Array = g.celulas_de_parede(_ocupadas)
	_embaralhar(livres)
	var props := [
		["kaykit_dungeon/barrel_large.gltf", 0.45, Vector3(0.8, 0.9, 0.8)],
		["kaykit_dungeon/barrel_small_stack.gltf", 0.5, Vector3(1.0, 0.8, 1.0)],
		["kaykit_dungeon/box_large.gltf", 0.5, Vector3(0.9, 0.9, 0.9)],
		["kaykit_dungeon/crates_stacked.gltf", 0.5, Vector3(1.4, 1.3, 1.4)],
		["kaykit_dungeon/keg.gltf", 0.5, Vector3(0.8, 0.8, 0.8)],
		["kaykit_dungeon/rubble_half.gltf", 0.35, Vector3.ZERO],
		["kenney_survival_kit/bucket.glb", 0.9, Vector3.ZERO],
		["kenney_survival_kit/tool-pickaxe.glb", 1.0, Vector3.ZERO],
		["kenney_survival_kit/tool-shovel.glb", 1.0, Vector3.ZERO],
		["kenney_mini_dungeon/rocks.glb", 1.0, Vector3.ZERO],
		["kenney_mini_dungeon/stones.glb", 1.0, Vector3.ZERO],
		["kaykit_dungeon/candle_triple.gltf", 0.6, Vector3.ZERO],
		["kenney_survival_kit/box-large.glb", 1.0, Vector3(0.9, 0.8, 0.9)],
	]
	var qtd := 14 + andar * 2 if andar < 20 else 18
	var postos: Array = []
	for k in qtd:
		var c := _celula_livre(livres, postos, 2)
		if c.x < 0:
			break
		postos.append(c)
		_ocupadas[c] = true
		var pr: Array = props[_rng.randi() % props.size()]
		if andar >= 20 and k % 2 == 0:
			pr = props[5 + _rng.randi() % 5]
		var p: Vector3 = g.mundo(c)
		for d in g._vizinhos4(c):
			if g.valor(d) == Gerador.ROCHA:
				p += Vector3(d.x - c.x, 0, d.y - c.y) * 0.5
				break
		modelo(String(pr[0]), grupo, p, _rng.randf() * TAU, float(pr[1]), pr[2])
	# baú escondido no beco mais distante (fora do trilho)
	var beco := Vector2i(-1, -1)
	var dmax := -1
	for c in g.distancia:
		if _ocupadas.has(c):
			continue
		var rochas := 0
		for d in g._vizinhos4(c):
			if g.valor(d) == Gerador.ROCHA:
				rochas += 1
		if rochas == 3 and g.distancia[c] > dmax:
			dmax = g.distancia[c]
			beco = c
	if beco.x >= 0:
		_ocupadas[beco] = true
		modelo("kaykit_dungeon/chest.gltf", grupo, g.mundo(beco), _rng.randf() * TAU, 0.5, Vector3(1.0, 0.8, 0.7))
		stats["bau"] = str(beco)

# ------------------------------------------------------------------ ambiente
func _particulas(cor: Color, qtd: int, caixa: Vector3, vida: float, subida: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = qtd
	p.lifetime = vida
	p.preprocess = vida
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = caixa
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = subida * 0.3
	pm.initial_velocity_max = subida
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = cor
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(-caixa - Vector3(2, 2, 2), caixa * 2 + Vector3(4, 8, 4))
	return p

func _ambiente() -> void:
	var we := WorldEnvironment.new()
	we.name = "AmbienteDaMina"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0806") if andar < 20 else Color("0e0608")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8a705c") if andar < 6 else (Color("6e7084") if andar < 20 else Color("7a5a64"))
	env.ambient_light_energy = 0.55 if andar < 6 else (0.48 if andar < 20 else 0.42)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	# neblina baixa de caverna (densa perto do chão, rala no alto)
	env.fog_enabled = true
	env.fog_light_color = Color("6a5040") if andar < 6 else (Color("4c5060") if andar < 20 else Color("6a3a3a"))
	env.fog_light_energy = 0.6
	env.fog_density = 0.0
	env.fog_height = 0.6
	env.fog_height_density = 0.18 if andar < 6 else 0.24
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	# luz-chave fraca vinda do lado da câmera: mantém a leitura do isométrico sem matar o clima
	var sol := DirectionalLight3D.new()
	sol.name = "LuzDeLeitura"
	sol.light_color = Color("ffd9b0")
	sol.light_energy = 0.42 if andar < 20 else 0.3
	sol.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 80.0
	add_child(sol)
	# cinza e fagulhas no ar
	var tam := Vector3(g.w, 1.5, g.h) * (Gerador.CELULA * 0.5)
	var cinza := _particulas(Color(0.75, 0.68, 0.6, 0.55), 260, tam, 9.0, 0.25)
	cinza.position = Vector3(0, 1.4, 0)
	cinza.name = "Cinza"
	add_child(cinza)
	var fagulhas := _particulas(Color(1.0, 0.6, 0.25, 0.9), 90, tam, 6.0, 0.5)
	fagulhas.position = Vector3(0, 0.8, 0)
	fagulhas.name = "Fagulhas"
	add_child(fagulhas)
	# véus de neblina rasteira (quads translúcidos) nos salões
	var veu := QuadMesh.new()
	veu.size = Vector2(7, 7)
	var mv := StandardMaterial3D.new()
	mv.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mv.albedo_color = Color(0.62, 0.52, 0.44, 0.22) if andar < 20 else Color(0.66, 0.4, 0.34, 0.22)
	mv.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	mv.albedo_texture = gt
	var grupo := _grupo("NeblinaRasteira")
	var k := 0
	for c in g.distancia:
		if g.cercado(c, 2) and (c.x * 7 + c.y * 13) % 11 == 0 and k < 22:
			_malha(grupo, veu, g.mundo(c) + Vector3(0, 0.35 + (k % 3) * 0.12, 0), mv, Vector3(-PI / 2, k * 0.6, 0))
			k += 1

# ------------------------------------------------------------------ jogadora / câmera
func _jogador_e_camera() -> void:
	jogador = CharacterBody3D.new()
	jogador.name = "JogadorProvisorio"
	jogador.add_to_group("jogador")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.48
	col.shape = cap
	col.position.y = 0.74
	jogador.add_child(col)
	var vis := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.48
	vis.mesh = cm
	vis.position.y = 0.74
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.95, 0.85, 0.55, 0.6)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.material_override = mm
	vis.name = "SubstituirPeloSpriteDaVale"
	jogador.add_child(vis)
	# lampião de mão da jogadora: luz curta que acompanha
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffd29a")
	lamp.light_energy = 1.2
	lamp.omni_range = 6.0
	lamp.position = Vector3(0.3, 1.6, 0.3)
	lamp.name = "LampiaoDeMao"
	jogador.add_child(lamp)
	var sp := marcador("spawn_jogador")
	jogador.position = (sp.position if sp else Vector3.ZERO) + Vector3(0, 0.3, 0)
	add_child(jogador)
	camera = Camera3D.new()
	camera.name = "CameraIsometrica"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = TAM_CAMERA
	camera.near = 0.15
	camera.far = 600
	add_child(camera)
	camera.make_current()
	_mirar(jogador.position, TAM_CAMERA)
	_aviso = _rotulo(self, "", Vector3.ZERO, Color("fff0c0"), 0.8)
	_aviso.name = "AvisoDeSaida"
	_aviso.visible = false

func _mirar(alvo: Vector3, tam: float) -> void:
	camera.size = tam
	camera.global_transform = Transform3D(Basis.IDENTITY, alvo + CAMERA_OFFSET).looking_at(alvo, Vector3.UP)

func _physics_process(delta: float) -> void:
	if jogador == null or OS.get_environment("VG_CAPTURA") != "":
		return
	var inp := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): inp.x -= 1
	if Input.is_physical_key_pressed(KEY_D): inp.x += 1
	if Input.is_physical_key_pressed(KEY_W): inp.y -= 1
	if Input.is_physical_key_pressed(KEY_S): inp.y += 1
	inp = inp.limit_length(1.0)
	if demo_mode:
		inp = Vector2.ZERO
	var direita := Vector3(1, 0, -1).normalized()
	var baixo := Vector3(1, 0, 1).normalized()
	var v := (direita * inp.x + baixo * inp.y) * 5.0
	jogador.velocity.x = v.x
	jogador.velocity.z = v.z
	jogador.velocity.y = 0.0 if jogador.is_on_floor() else jogador.velocity.y - 18.0 * delta
	jogador.move_and_slide()
	if jogador.position.y < -10.0:
		jogador.position = marcador("spawn_jogador").position + Vector3(0, 0.5, 0)
		jogador.velocity = Vector3.ZERO
	var tam := maxf(g.w, g.h) * Gerador.CELULA * 0.8 if visao_geral else TAM_CAMERA * zoom
	_mirar(Vector3.ZERO if visao_geral else Vector3(jogador.position.x, 0, jogador.position.z), tam)
	# saídas: mostra o aviso perto de escadas/elevador
	_alvo_saida = null
	for mk in get_tree().get_nodes_in_group("saida_minas"):
		if not is_ancestor_of(mk) or not (mk.has_meta("destino_andar") or mk.has_meta("destino")):
			continue
		if Vector2(mk.global_position.x - jogador.position.x, mk.global_position.z - jogador.position.z).length() < 1.6:
			_alvo_saida = mk
	_aviso.visible = _alvo_saida != null and not demo_mode
	if _alvo_saida:
		_aviso.global_position = jogador.global_position + Vector3(0, 2.2, 0)
		_aviso.text = "[E] " + String(_alvo_saida.get_meta("descricao"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(0.5, zoom * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(3.0, zoom * 1.1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			visao_geral = not visao_geral
		if event.physical_keycode == KEY_E and _alvo_saida and not demo_mode:
			usar_saida(_alvo_saida)

func usar_saida(mk: Marker3D) -> void:
	if mk.has_meta("destino") and String(mk.get_meta("destino")) == "porto_velho":
		saiu_para_porto_velho.emit()
		_aviso.text = "Porto Velho (a cena principal não está ligada nesta proposta)"
		return
	if mk.has_meta("destino_andar"):
		ir_para_andar(int(mk.get_meta("destino_andar")))

## troca de andar: instancia a cena genérica com o novo andar e substitui a atual
func ir_para_andar(novo: int) -> void:
	trocou_de_andar.emit(andar, novo)
	var cena: PackedScene = load(CENA_GENERICA)
	var n = cena.instantiate()
	n.andar = novo
	get_tree().call_deferred("change_scene_to_node", n)

# ------------------------------------------------------------------ conversas
func _ligar_dialogos() -> void:
	dialogos = get_node_or_null("Dialogos")
	if dialogos == null:
		dialogos = Interacao.new()
		dialogos.name = "Dialogos"
		add_child(dialogos)
	dialogos.jogador = jogador
	dialogos.game = self
	npcs = Interacao.spawn_em_marcadores(marcadores)

func npc(id: String) -> Node3D:
	for n in npcs:
		if is_instance_valid(n) and String(n.npc_id) == id:
			return n
	return null

func _visuais_npcs() -> void:
	for n in npcs:
		var d: Dictionary = NpcsMinas.NPCS.get(String(n.npc_id), {})
		var velho: Node3D = n.get_node_or_null("Visual")
		if d.has("modelo"):
			var cena := _carregar(String(d.modelo))
			if cena:
				if velho:
					velho.visible = false
				var m: Node3D = cena.instantiate()
				m.name = "VisualModelo3D"
				m.scale = Vector3.ONE * float(d.get("escala_modelo", 1.0))
				n.add_child(m)
				var olho := SphereMesh.new()
				olho.radius = 0.07
				olho.height = 0.14
				for sx in [-0.18, 0.18]:
					_malha(m, olho, Vector3(sx * 2.0, 1.2, 1.36), mat("vidro_lanterna"))
		elif velho and d.has("escala_visual"):
			velho.scale = Vector3.ONE * float(d.escala_visual)
		if d.get("fantasma", false) and velho:
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(0.6, 0.85, 1.0, 0.45)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fm.emission_enabled = true
			fm.emission = Color("7ac8ff")
			fm.emission_energy_multiplier = 0.8
			for mi: MeshInstance3D in velho.find_children("*", "MeshInstance3D", true, false):
				mi.material_override = fm
			for sp: SpriteBase3D in velho.find_children("*", "SpriteBase3D", true, false):
				sp.modulate = Color(0.6, 0.85, 1.0, 0.5)
			pulsantes.append({"no": velho, "tipo": "flutua", "fase": 0.0, "base": velho.position})
			_luz(n, Vector3(0, 1.2, 0), Color("8ad0ff"), 1.0, 4.0)
		if d.get("glitch", false) and velho:
			pulsantes.append({"no": velho, "tipo": "glitch", "fase": 0.0, "base": velho.position})

# ------------------------------------------------------------------ animação
func _process(delta: float) -> void:
	_t += delta
	for l in luzes:
		var luz: OmniLight3D = l.luz
		luz.light_energy = float(l.base) * (0.88 + 0.12 * sin(_t * 9.0 + l.fase) * sin(_t * 3.7 + l.fase * 2.0))
	for p in pulsantes:
		var no = p.no
		if not is_instance_valid(no):
			continue
		match String(p.tipo):
			"gira": no.rotation.x += delta * 0.6
			"brasa", "pulsa": no.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 2.0 + float(p.fase)))
			"lava": no.position.y = -2.9 + 0.05 * sin(_t * 1.3 + float(p.fase))
			"sussurro": no.modulate.a = 0.35 + 0.4 * (0.5 + 0.5 * sin(_t * 0.8 + float(p.fase)))
			"flutua": no.position = p.base + Vector3(0, 0.15 + 0.1 * sin(_t * 1.6), 0)
			"glitch":
				var salto := fmod(_t, 2.3) < 0.08
				no.position = p.base + (Vector3(0.18, 0, -0.1) if salto else Vector3.ZERO)

# ------------------------------------------------------------------ navegação
## Assa a navegação só com o chão e os adereços sólidos (grupo "navegavel_minas");
## a borda do chão já recorta as paredes e os poços.
func assar_navegacao() -> NavigationRegion3D:
	var reg := NavigationRegion3D.new()
	reg.name = "Navegacao"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"navegavel_minas"
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.45
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 35.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	reg.navigation_mesh = nm
	add_child(reg)
	var fonte := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, fonte, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, fonte)
	reg.navigation_mesh = nm
	return reg

# ------------------------------------------------------------------ capturas
func _capturas(pasta: String) -> void:
	get_window().size = Vector2i(1600, 900)
	jogador.visible = false
	for i in 30:
		await get_tree().process_frame
	var lista: Array = [{"nome": "visao_geral", "alvo": Vector3.ZERO, "tam": maxf(g.w, g.h) * Gerador.CELULA * 0.78}]
	var e: Vector3 = g.mundo(g.entrada)
	lista.append({"nome": "entrada", "alvo": e + Vector3(2, 0, 2), "tam": 19.0})
	if npcs.size() > 0:
		lista.append({"nome": "morador", "alvo": npcs[npcs.size() - 1].global_position, "tam": 15.0})
	if andar >= 20:
		lista.append({"nome": "abismo", "alvo": Vector3(0, 0, 3), "tam": 34.0})
	for c in lista:
		_mirar(c.alvo, float(c.tam))
		for i in 12:
			await get_tree().process_frame
		var arq := pasta.path_join("minas_da_cinza_andar_%02d_%s.png" % [andar, String(c.nome)])
		get_viewport().get_texture().get_image().save_png(arq)
		print("[minas_da_cinza] captura: ", arq)
	get_tree().quit()
