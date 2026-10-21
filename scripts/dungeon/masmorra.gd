extends "res://scripts/minas_da_cinza/minas_da_cinza.gd"
## Masmorra procedural jogável com temas (PROPOSTA, não é canon).
## Estende scripts/minas_da_cinza/minas_da_cinza.gd (reaproveita rocha em corte, minério, luz,
## navegação, NPCs das minas) e acrescenta o laço de jogo:
##   * tema = "minas_da_cinza" | "criptas_de_cinzalta" | "fenda_cronal" (data/dungeon/temas.json)
##   * andar e semente vêm de SessaoMasmorra (semente aleatória por incursão; fixa com DUNGEON_SEMENTE)
##   * jogadora de combate real (scripts/combate/jogador_combate.gd) + inimigos 3D que lutam
##     (scripts/dungeon/inimigos/*) ligados por scripts/dungeon/combate_masmorra.gd
##   * baús com materiais da forja, nós de minério mineráveis, loot vai para SessaoMasmorra.inventario
##   * cada andar: saída de volta para a cidade de origem (chegada) + escada para o próximo andar;
##     andar final: mini-chefe, baú do chefe e portal de volta
## Variáveis de ambiente: DUNGEON_TEMA, DUNGEON_ANDAR, DUNGEON_SEMENTE, DUNGEON_CAPTURA=/pasta.
const GeradorTema = preload("res://scripts/dungeon/gerador_masmorra.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Combate = preload("res://scripts/dungeon/combate_masmorra.gd")
const Hud = preload("res://scripts/dungeon/hud_masmorra.gd")
const JogadorCombate = preload("res://scripts/combate/jogador_combate.gd")
## Bolorina 21/10: mesma camera da arena (scripts/combate/arena_combate.gd: YAW 45, PITCH 40, tamanho 15.5)
## para Vale e os orcs terem o mesmo tamanho e angulo na tela nos dois lugares.
const TAM_CAMERA_COMBATE := 15.5
const CAM_YAW_COMBATE := 45.0
const CAM_PITCH_COMBATE := 40.0

signal saiu_da_masmorra(area: String, ponto: String)
signal desceu(de: int, para: int)
signal bau_aberto(id: String, itens: Dictionary)

const COR_EXTRA := {
	"minerio_prata_tumular": ["dce8f4", 1.5], "minerio_cronostio": ["6af0ff", 2.6], "chip_anomalia": ["5aff9a", 2.0],
	"cristal_celeste_bruto": ["9ad0ff", 2.2], "minerio_ferro_brasa": ["ff6a2a", 2.2],
}

@export var tema := "minas_da_cinza"
@export var modo_teste := false

var dados: Dictionary = {}
var combate
var hud
var baus: Array = []
var minerios_tema: Array = []
var portal_volta: Marker3D
var interagir_com: Node3D
var chefe_derrotado := false
var _tremor := 0.0
var _morta := false
var _saindo := false
var _t_morte := 0.0
var _segurando_k := false
var paleta: Dictionary = {}

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	# integracao 20/10: a tecla M e o mapa-mundi sao do jogo_ilha.gd (o hub antigo ficou em nao_usado/)
	if OS.get_environment("DUNGEON_TEMA") != "":
		tema = OS.get_environment("DUNGEON_TEMA")
	var andar_env := OS.get_environment("DUNGEON_ANDAR")
	Sessao.garantir(tema, int(andar_env) if andar_env != "" else 1)
	dados = Sessao.dados_tema(tema)
	paleta = dados.get("paleta", {})
	if andar_env != "":
		Sessao.andar = int(andar_env)
	andar = Sessao.andar
	var lista: Array = Sessao.andares(tema)
	if not (andar in lista):
		andar = int(lista[0])
		Sessao.andar = andar
	Sessao.marcar_profundidade(tema, andar)
	if OS.get_environment("DUNGEON_TESTE") != "":
		modo_teste = true
	name = "Masmorra_" + tema
	forja = Forja.new()
	materiais_json = _ler_materiais()
	g = GeradorTema.new(tema, andar, Sessao.semente_do_andar(andar))
	g.gerar()
	_rng.seed = g.semente + 17
	minerios_tema = GeradorTema.minerios_do_andar(dados, andar, materiais_json)
	for e in minerios_tema:
		materiais_do_andar.append(e.m)
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
	if tema == "minas_da_cinza":
		_trilhos()
	_saidas()
	if g.estilo == "coracao":
		_coracao_soterrado()
	_minerios()
	_spawns_inimigos()
	if tema == "minas_da_cinza":
		_npcs_marcadores()
		_lanternas_e_tochas()
		_cristais_de_brasa()
		_aderecos()
		_trocar_bau_decorativo()
	elif tema == "criptas_de_cinzalta":
		_tochas("kaykit_dungeon/torch_mounted.gltf", Color(paleta.get("luz", "8ab0ff")), 14)
		_aderecos_criptas()
	else:
		_aderecos_fenda()
	_baus()
	_ambiente()
	_jogador_e_camera()
	navegacao = assar_navegacao()
	_montar_combate()
	if tema == "minas_da_cinza":
		_ligar_dialogos()
		_visuais_npcs()
	_montar_hud()
	stats.merge({"tema": tema, "andar": andar, "estilo": g.estilo, "semente": g.semente, "grade": "%dx%d" % [g.w, g.h],
		"chao": g.distancia.size(), "minerios": nos_minerio.get_child_count(), "spawns": inimigos.get_child_count(),
		"inimigos": combate.inimigos.size(), "baus": baus.size(), "chefe": g.chefe, "luzes": luzes.size()}, true)
	print("[masmorra] %s andar %d montado em %d ms | %s" % [tema, andar, Time.get_ticks_msec() - t0, JSON.stringify(stats)])
	if OS.get_environment("DUNGEON_CAPTURA") != "":
		_capturas_tema(OS.get_environment("DUNGEON_CAPTURA"))

# ------------------------------------------------------------------ materiais por tema
func _tex_em(caminho: String) -> Texture2D:
	return load(caminho) if ResourceLoader.exists(caminho) else null

func _pbr(m: StandardMaterial3D, albedo: String, normal: String, escala: float, cor: Color) -> void:
	m.albedo_texture = _tex_em(albedo)
	if normal != "":
		m.normal_enabled = true
		m.normal_texture = _tex_em(normal)
		m.normal_scale = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * escala
	m.vertex_color_use_as_albedo = true
	m.albedo_color = cor

func mat(nome: String) -> StandardMaterial3D:
	if _mats.has(nome):
		return _mats[nome]
	if nome.begins_with("minerio:") and COR_EXTRA.has(nome.substr(8)):
		var info: Array = COR_EXTRA[nome.substr(8)]
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(String(info[0]))
		mm.roughness = 0.3
		mm.metallic = 0.5
		mm.emission_enabled = true
		mm.emission = Color(String(info[0]))
		mm.emission_energy_multiplier = float(info[1])
		_mats[nome] = mm
		return mm
	if tema == "minas_da_cinza" or tema == "":
		return super.mat(nome)
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	var cripta := tema == "criptas_de_cinzalta"
	match nome:
		"rocha":
			if cripta:
				_pbr(m, "res://art/materials/castle_brick_01/albedo.jpg", "res://art/materials/castle_brick_01/normal.jpg", 0.45, Color("8a8ea0"))
			else:
				_pbr(m, "res://art/materials/dungeon/metal_plate_02_diff.jpg", "res://art/materials/dungeon/metal_plate_02_nor_gl.jpg", 0.35, Color("5a5670"))
				m.metallic = 0.6
				m.roughness = 0.45
		"rocha_topo":
			if cripta:
				_pbr(m, "res://art/materials/castle_brick_01/albedo.jpg", "", 0.45, Color("3a3c4a"))
			else:
				m.albedo_color = Color("1a1428")
				m.emission_enabled = true
				m.emission = Color("6a2aa0")
				m.emission_energy_multiplier = 0.4
		"chao":
			if cripta:
				var base := "res://art/materials/plastered_stone_wall/" if g.estilo == "nave" else "res://art/materials/mossy_cobblestone/"
				_pbr(m, base + "albedo.jpg", base + "normal.jpg", 0.3, Color("a8acb4") if g.estilo != "nave" else Color("9a9cab"))
			else:
				_pbr(m, "res://art/materials/dungeon/metal_plate_02_diff.jpg", "res://art/materials/dungeon/metal_plate_02_nor_gl.jpg", 0.25, Color("a0a4c0"))
				m.metallic = 0.55
				m.roughness = 0.4
		"poco":
			if cripta:
				m.albedo_color = Color("08080c")
			else:
				# o vazio da Fenda: violeta que brilha com manchas (estrelas do tempo)
				var ruido := FastNoiseLite.new()
				ruido.frequency = 0.08
				var tex := NoiseTexture2D.new()
				tex.noise = ruido
				tex.seamless = true
				tex.width = 256
				tex.height = 256
				var grad := Gradient.new()
				grad.set_color(0, Color("05020c"))
				grad.set_color(1, Color("ff7af0"))
				grad.add_point(0.62, Color("1a0a3a"))
				tex.color_ramp = grad
				m.albedo_color = Color("100820")
				m.emission_enabled = true
				m.emission_texture = tex
				m.emission = Color.WHITE
				m.emission_energy_multiplier = 1.4
				m.uv1_triplanar = true
				m.uv1_world_triplanar = true
				m.uv1_scale = Vector3.ONE * 0.05
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"cristal_tema":
			var c := Color(String(paleta.get("cristal", "ff4af0")))
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 2.6
			m.roughness = 0.2
		"luz_fria":
			var c2 := Color(String(paleta.get("luz", "8ab0ff")))
			m.albedo_color = c2
			m.emission_enabled = true
			m.emission = c2
			m.emission_energy_multiplier = 3.0
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"portal":
			m.albedo_color = Color(0.4, 0.9, 1.0, 0.75)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("5af0ff")
			m.emission_energy_multiplier = 3.0
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"portal_baixo":
			m.albedo_color = Color(0.5, 0.2, 0.9, 0.8)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true
			m.emission = Color("9a4aff")
			m.emission_energy_multiplier = 2.4
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_:
			_mats.erase(nome)
			return super.mat(nome)
	_mats[nome] = m
	return m

# ------------------------------------------------------------------ saídas
func _nome_origem() -> String:
	return Registro.nome(Sessao.origem_area) if Sessao.origem_area != "" else "a superfície"

func _saidas() -> void:
	var grupo := _grupo("Saidas")
	var e: Vector3 = g.mundo(g.entrada)
	_ocupadas[g.entrada] = true
	for d in g._vizinhos4(g.entrada):
		_ocupadas[d] = true
	_marcador("spawn_jogador", e + Vector3(1.2, 0, 1.2), "spawn", "Chegada ao andar")
	var texto_volta := "Voltar para %s" % _nome_origem()
	match tema:
		"minas_da_cinza":
			if andar == 1 and Sessao.origem_area in ["porto_velho", ""]:
				_elevador(grupo, e)
			else:
				_escada_de_mao(grupo, e)
				for l in grupo.get_node("EscadaDeMao").find_children("*", "Label3D", true, false):
					l.text = "↑ %s" % _nome_origem()
		"criptas_de_cinzalta":
			_saida_cripta(grupo, e)
		_:
			_saida_fenda(grupo, e)
	var s := _marcador("saida_origem", e, "saida", texto_volta)
	s.set_meta("destino", "origem")
	if g.escada.x >= 0:
		var p: Vector3 = g.mundo(g.escada)
		_ocupadas[g.escada] = true
		var pa: Vector3 = g.mundo(g.aproximacao)
		var dir := (p - pa).normalized()
		var prox := Sessao.proximo_andar(tema, andar)
		var rot_txt := "↓ Andar %d" % prox
		if prox == int(dados.get("andar_chefe", -1)):
			rot_txt += "\n" + ("covil do chefe" if tema != "minas_da_cinza" else "Coração Soterrado (chefe)")
		match tema:
			"minas_da_cinza":
				modelo("kaykit_dungeon/stairs_wood.gltf", grupo, p + Vector3(0, -2.75, 0) - dir * 1.0, atan2(-dir.x, -dir.z), 0.5)
				modelo("kenney_mini_dungeon/wood-support.glb", grupo, p, atan2(dir.x, dir.z), 1.0)
				_luz(grupo, p + Vector3(0, -1.6, 0), Color("ff9a4a"), 1.6, 5.0)
			"criptas_de_cinzalta":
				modelo("kaykit_dungeon/stairs.gltf", grupo, p + Vector3(0, -2.75, 0) - dir * 1.0, atan2(-dir.x, -dir.z), 0.5)
				modelo("kaykit_dungeon/pillar.gltf", grupo, p - dir * 0.9 + dir.cross(Vector3.UP) * 1.2, 0.0, 0.42)
				modelo("kaykit_dungeon/pillar.gltf", grupo, p - dir * 0.9 - dir.cross(Vector3.UP) * 1.2, 0.0, 0.42)
				_luz(grupo, p + Vector3(0, -1.0, 0), Color("8a6aff"), 2.0, 6.0)
			_:
				_portal(grupo, p, "portal_baixo", 1.0, true)
		_rotulo(grupo, rot_txt, p + Vector3(0, 2.8, 0), Color(String(paleta.get("leitura", "ffd27a"))), 1.0)
		var d := _marcador("escada_descer", pa, "escada", "Descer para o andar %d" % prox)
		d.set_meta("destino_andar", prox)
	var titulo := _rotulo(grupo, GeradorTema.nome_do_andar_tema(dados, andar), e + Vector3(4.5, 5.5, -4.5), Color(String(paleta.get("leitura", "ffe6b0"))), 1.2)
	titulo.name = "TituloDoAndar"

func _saida_cripta(grupo: Node3D, e: Vector3) -> void:
	var n := Node3D.new()
	n.name = "EscadariaDeSaida"
	n.position = e
	grupo.add_child(n)
	modelo("kaykit_dungeon/stairs.gltf", n, Vector3(-1.4, 0, -1.4), PI * 0.25, 0.5)
	modelo("kaykit_dungeon/pillar.gltf", n, Vector3(-2.2, 0, 0.2), 0.0, 0.45)
	modelo("kaykit_dungeon/pillar.gltf", n, Vector3(0.2, 0, -2.2), 0.0, 0.45)
	modelo("kaykit_dungeon/candle_triple.gltf", n, Vector3(1.4, 0, -0.8), 0.0, 0.6)
	modelo("kaykit_dungeon/candle_lit.gltf", n, Vector3(-0.8, 0, 1.4), 0.0, 0.6)
	_luz(n, Vector3(0.4, 1.6, 0.4), Color("ffc890"), 1.8, 7.0)
	_luz(n, Vector3(-1.6, 3.0, -1.6), Color("8aa8ff"), 1.4, 6.0, false)
	_rotulo(n, "↑ %s\n(escadaria da cripta)" % _nome_origem(), Vector3(0, 3.4, 0), Color("dfe6ff"), 0.95)

func _saida_fenda(grupo: Node3D, e: Vector3) -> void:
	var n := _portal(grupo, e + Vector3(-0.8, 0, -0.8), "portal", 1.15, false)
	n.name = "PortalDeVolta"
	_rotulo(n, "↺ %s\n(fio de volta)" % _nome_origem(), Vector3(0, 3.6, 0), Color("c8f8ff"), 0.95)

## portal circular de pé (volta) ou deitado no chão (desce)
func _portal(grupo: Node3D, p: Vector3, material: String, tam: float, deitado: bool) -> Node3D:
	var n := Node3D.new()
	n.position = p
	grupo.add_child(n)
	var aro := TorusMesh.new()
	aro.inner_radius = 1.0 * tam
	aro.outer_radius = 1.22 * tam
	var miolo := CylinderMesh.new()
	miolo.top_radius = 1.0 * tam
	miolo.bottom_radius = 1.0 * tam
	miolo.height = 0.04
	var ouro := mat("trilho")
	if deitado:
		_malha(n, aro, Vector3(0, 0.08, 0), ouro)
		var m := _malha(n, miolo, Vector3(0, 0.05, 0), mat(material))
		pulsantes.append({"no": m, "tipo": "pulsa", "fase": 0.0})
	else:
		var giro := Node3D.new()
		giro.position = Vector3(0, 1.4 * tam, 0)
		giro.rotation.y = PI * 0.25
		n.add_child(giro)
		_malha(giro, aro, Vector3.ZERO, ouro, Vector3(PI / 2, 0, 0))
		var m := _malha(giro, miolo, Vector3.ZERO, mat(material), Vector3(PI / 2, 0, 0))
		pulsantes.append({"no": m, "tipo": "pulsa", "fase": 0.0})
		for k in 12:
			var b := BoxMesh.new()
			b.size = Vector3(0.06, 0.18, 0.06)
			var ang := k * TAU / 12.0
			_malha(giro, b, Vector3(sin(ang), cos(ang), 0) * 1.32 * tam, mat("luz_fria"), Vector3(0, 0, -ang))
	var cor := Color("5af0ff") if material == "portal" else Color("9a4aff")
	_luz(n, Vector3(0, 1.2, 0), cor, 2.6, 7.0)
	var part := _particulas(Color(cor.r, cor.g, cor.b, 0.8), 40, Vector3(0.8, 0.2, 0.8), 2.0, 0.9)
	n.add_child(part)
	return n

# ------------------------------------------------------------------ minério do tema
func _minerios() -> void:
	var livres: Array = g.celulas_de_parede(_ocupadas) if tema != "fenda_cronal" else _bordas()
	if livres.size() < 8:
		livres = g.distancia.keys()
	livres.sort()
	_embaralhar(livres)
	var postos: Array = []
	var contagem := {}
	for e in minerios_tema:
		var m: Dictionary = e.m
		var id := String(m.id)
		for k in int(e.qtd):
			var c := _celula_livre(livres, postos, 3)
			if c.x < 0:
				break
			postos.append(c)
			_ocupadas[c] = true
			contagem[id] = int(contagem.get(id, 0)) + 1
			_no_de_minerio(m, c, contagem[id])
			if COR_EXTRA.has(id):
				var mk: Marker3D = nos_minerio.get_child(nos_minerio.get_child_count() - 1)
				_luz(mk.get_node("Visual"), Vector3(0, 0.8, 0), Color(String(COR_EXTRA[id][0])), 1.0, 3.5, false)
	stats["minerio_por_material"] = contagem

# ------------------------------------------------------------------ inimigos
func _spawns_inimigos() -> void:
	var conta: Dictionary = GeradorTema.inimigos_do_andar_tema(dados, andar)
	var livres: Array = []
	var dist_min := 7 if g.distancia.size() > 250 else 5
	for c in g.distancia:
		if g.distancia[c] >= dist_min and g.cercado(c, 1) and not _ocupadas.has(c):
			livres.append(c)
	if livres.size() < 6:
		for c in g.distancia:
			if g.distancia[c] >= 4 and not _ocupadas.has(c):
				livres.append(c)
	livres.sort()
	_embaralhar(livres)
	var postos: Array = []
	if g.chefe and String(dados.get("chefe", "")) != "":
		var cc: Vector2i = g.alvo_chefe if g.alvo_chefe.x >= 0 else g.aproximacao
		postos.append(cc)
		_spawn(String(dados.chefe), cc, 1, true)
	var tipos := conta.keys()
	tipos.sort()
	for tipo in tipos:
		for k in int(conta[tipo]):
			var c := _celula_livre(livres, postos, 4)
			if c.x < 0:
				c = _celula_livre(livres, postos, 2)
			if c.x < 0:
				break
			postos.append(c)
			_spawn(String(tipo), c, k + 1, false)

func _spawn(tipo: String, c: Vector2i, n: int, chefe: bool) -> void:
	_ocupadas[c] = true
	var mk := Marker3D.new()
	mk.name = ("chefe_%s" if chefe else "inimigo_%s_%02d") % ([tipo] if chefe else [tipo, n])
	mk.position = g.mundo(c)
	mk.add_to_group("inimigo_spawn")
	mk.set_meta("tipo", tipo)
	mk.set_meta("chefe", chefe)
	mk.set_meta("script", "res://scripts/dungeon/inimigos/%s.gd" % ("chefe_masmorra" if chefe else "inimigo_masmorra"))
	inimigos.add_child(mk)

func _indice_andar() -> int:
	return maxi(0, Sessao.andares(tema).find(andar))

func _montar_combate() -> void:
	combate = Combate.new()
	combate.name = "Combate"
	add_child(combate)
	var i := _indice_andar()
	combate.mult_hp = 1.0 + 0.06 * i
	combate.mult_dano = 1.0 + 0.04 * i
	combate.nome_item = func(id: String) -> String: return forja.nome(id)
	combate.iniciar(jogador, g.semente + 991)
	for mk in inimigos.get_children():
		combate.gerar(String(mk.get_meta("tipo")), mk.position)
	combate.inimigo_morreu.connect(_inimigo_morreu)
	combate.chefe_morreu.connect(_chefe_morreu)
	combate.tremor.connect(func(f): _tremor = maxf(_tremor, f))
	combate.loot_coletado.connect(func(id, q): if hud: hud.loot("+%d %s" % [q, forja.nome(id)], combate._cor_item(id).lerp(Color.WHITE, 0.4)))
	combate.jogador_caiu.connect(_jogadora_caiu)

func _inimigo_morreu(_e, _tipo: String) -> void:
	pass

func _chefe_morreu(e) -> void:
	chefe_derrotado = true
	Sessao.chefes_derrotados[tema] = true
	var p: Vector3 = e.global_position
	if hud:
		hud.mostrar_banner("%s derrotado!" % String(e.def.get("nome", "Chefe")), 3.5, Color(String(paleta.get("leitura", "ffd27a"))))
	# baú do chefe + portal de volta
	var c: Vector2i = g.celula_de(p)
	var alvo := c
	var melhor := 1e9
	for cand in g.distancia:
		var d := Vector2(cand - c).length()
		if d >= 1.5 and d < melhor and not _ocupadas.has(cand):
			melhor = d
			alvo = cand
	_criar_bau(g.mundo(alvo), dados.get("bau_chefe", []), true, "bau_do_chefe")
	var grupo := _grupo("Saidas")
	var pp := p + Vector3(-2.2, 0, 2.2)
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(mapa) > 0:
		pp = NavigationServer3D.map_get_closest_point(mapa, pp)
	var portal := _portal(grupo, Vector3(pp.x, 0, pp.z), "portal", 1.0, false)
	portal.name = "PortalDoChefe"
	_rotulo(portal, "↺ %s" % _nome_origem(), Vector3(0, 3.4, 0), Color("c8f8ff"), 0.9)
	portal_volta = _marcador("saida_chefe", Vector3(pp.x, 0, pp.z), "saida", "Voltar para %s" % _nome_origem())
	portal_volta.set_meta("destino", "origem")

# ------------------------------------------------------------------ baús
func _baus() -> void:
	var faixa: Array = dados.get("baus_por_andar", [1, 2])
	var n := _rng.randi_range(int(faixa[0]), int(faixa[1]))
	var cands: Array = []
	for c in g.distancia:
		if _ocupadas.has(c) or g.distancia[c] < 6:
			continue
		var rochas := 0
		for d in g._vizinhos4(c):
			if g.valor(d) != Gerador.CHAO:
				rochas += 1
		if rochas >= 2:
			cands.append([-(rochas * 1000 + int(g.distancia[c])), c])
	cands.sort()
	var postos: Array = []
	for item in cands:
		if postos.size() >= n:
			break
		var c: Vector2i = item[1]
		var longe := true
		for p in postos:
			if absi(p.x - c.x) + absi(p.y - c.y) < 8:
				longe = false
		if not longe:
			continue
		postos.append(c)
		_ocupadas[c] = true
		_criar_bau(g.mundo(c), dados.get("bau", []), false, "bau_%02d" % postos.size())
	if postos.is_empty():
		# andar sem becos (ilhas da Fenda): o baú vai para a célula livre mais distante
		var melhor := Vector2i(-1, -1)
		for c in g.distancia:
			if not _ocupadas.has(c) and g.cercado(c, 0) and (melhor.x < 0 or int(g.distancia[c]) > int(g.distancia[melhor])):
				melhor = c
		if melhor.x >= 0:
			_ocupadas[melhor] = true
			_criar_bau(g.mundo(melhor), dados.get("bau", []), false, "bau_01")

func _modelo_bau(chefe: bool) -> Array:
	match tema:
		"fenda_cronal": return ["quaternius_scifi_modular/Prop_Chest.gltf", 0.75 if chefe else 0.6]
		_: return ["kaykit_dungeon/chest_gold.gltf" if chefe else "kaykit_dungeon/chest.gltf", 0.62 if chefe else 0.5]

func _criar_bau(p: Vector3, tabela: Array, chefe: bool, id: String) -> Node3D:
	var grupo := _grupo("Baus")
	var n := Node3D.new()
	n.name = id
	n.position = p
	n.add_to_group("bau_masmorra")
	n.set_meta("tabela", tabela)
	n.set_meta("aberto", false)
	n.set_meta("chefe", chefe)
	grupo.add_child(n)
	var mb := _modelo_bau(chefe)
	var ang := 0.0
	for d in g._vizinhos4(g.celula_de(p)):
		if g.valor(d) == Gerador.CHAO:
			var v: Vector2i = d - g.celula_de(p)
			ang = atan2(v.x, v.y)
			break
	var vis := modelo(String(mb[0]), n, Vector3.ZERO, ang, float(mb[1]), Vector3(1.1, 0.8, 0.8))
	vis.name = "Visual"
	var cor := Color("ffd27a") if tema != "fenda_cronal" else Color("7af4ff")
	var l := _luz(n, Vector3(0, 1.2, 0), cor, 1.6 if chefe else 1.0, 4.5, false)
	l.name = "Brilho"
	var r := _rotulo(n, "Baú do chefe" if chefe else "Baú", Vector3(0, 1.6, 0), cor, 0.6)
	r.name = "Rotulo"
	baus.append(n)
	return n

func abrir_bau(b: Node3D) -> Dictionary:
	if b == null or bool(b.get_meta("aberto")):
		return {}
	b.set_meta("aberto", true)
	var tabela: Array = b.get_meta("tabela")
	var itens: Dictionary = combate.rolar(tabela)
	if itens.is_empty() and tabela.size() > 0:
		itens[String(tabela[0][0])] = int(tabela[0][2])
	var i := 0
	for id in itens:
		var ang := TAU * i / maxf(itens.size(), 1) + 0.3
		combate.soltar(String(id), int(itens[id]), b.global_position + Vector3(cos(ang), 0, sin(ang)) * 1.1)
		i += 1
	(b.get_node("Rotulo") as Label3D).text = "aberto"
	(b.get_node("Brilho") as OmniLight3D).light_energy = 0.3
	var vis: Node3D = b.get_node("Visual")
	vis.rotation.x = -0.12
	combate._explosao(b.global_position + Vector3(0, 0.8, 0), 30, Color(3.0, 2.6, 1.4), Color(1.0, 0.7, 0.2, 0.0), 3.5, 0.6)
	bau_aberto.emit(String(b.name), itens)
	return itens

## o _aderecos() das minas põe um baú decorativo no beco mais distante: vira um baú de verdade
func _trocar_bau_decorativo() -> void:
	var grupo := _grupo("Aderecos")
	for ch in grupo.get_children():
		if ch is Node3D and String(ch.scene_file_path).ends_with("kaykit_dungeon/chest.gltf"):
			var p: Vector3 = ch.position
			for b in grupo.get_children():
				if b is StaticBody3D and b.position.distance_to(p) < 0.01:
					b.queue_free()
			ch.queue_free()
			_criar_bau(p, dados.get("bau", []), false, "bau_do_beco")

# ------------------------------------------------------------------ adereços dos temas
func _tochas(caminho: String, cor_fria: Color, maximo: int) -> void:
	var grupo := _grupo("Tochas")
	var faces: Array = []
	for c in _altura:
		if float(_altura[c]) < ALTO - 0.01:
			continue
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if g.chao(c + d) and not _ocupadas.has(c + d):
				faces.append([c, d])
	faces.sort()
	_embaralhar(faces)
	var usadas: Array = []
	for f in faces:
		if usadas.size() >= maximo:
			break
		var c: Vector2i = f[0]
		var ok := true
		for u in usadas:
			if absi(u.x - c.x) + absi(u.y - c.y) < 5:
				ok = false
				break
		if not ok:
			continue
		usadas.append(c)
		var d: Vector2i = f[1]
		var face: Vector3 = g.mundo(c) + Vector3(d.x, 0, d.y) * (Gerador.CELULA * 0.5)
		modelo(caminho, grupo, face + Vector3(0, 1.7, 0), 0.0 if d.y == 1 else PI / 2, 0.75)
		var chama := SphereMesh.new()
		chama.radius = 0.09
		chama.height = 0.2
		_malha(grupo, chama, face + Vector3(d.x, 0, d.y) * 0.32 + Vector3(0, 2.25, 0), mat("luz_fria"))
		_luz(grupo, face + Vector3(d.x, 0, d.y) * 0.8 + Vector3(0, 2.3, 0), cor_fria if usadas.size() % 2 == 0 else Color("ffb070"), 1.8, 8.5)
	stats["tochas"] = usadas.size()

func _espalhar(props: Array, qtd: int, encostar := true) -> int:
	var grupo := _grupo("Aderecos")
	var livres: Array = _bordas() if encostar else g.distancia.keys()
	livres.sort()
	_embaralhar(livres)
	var postos: Array = []
	for k in qtd:
		var c := _celula_livre(livres, postos, 2)
		if c.x < 0:
			break
		postos.append(c)
		_ocupadas[c] = true
		var pr: Array = props[_rng.randi() % props.size()]
		var p: Vector3 = g.mundo(c)
		if encostar:
			for d in g._vizinhos4(c):
				if g.valor(d) != Gerador.CHAO:
					p += Vector3(d.x - c.x, 0, d.y - c.y) * 0.5
					break
		modelo(String(pr[0]), grupo, p, _rng.randf() * TAU, float(pr[1]), pr[2])
	return postos.size()

## células de chão encostadas em parede OU vazio (a Fenda quase não tem rocha)
func _bordas() -> Array:
	var out: Array = []
	for c in g.distancia:
		if _ocupadas.has(c) or int(g.distancia[c]) < 3:
			continue
		var fora := 0
		for v in g._vizinhos4(c):
			if g.valor(v) != Gerador.CHAO:
				fora += 1
		if fora >= 1 and fora <= 2:
			out.append(c)
	out.sort()
	return out

func _aderecos_criptas() -> void:
	var grupo := _grupo("Aderecos")
	# pilares onde o gerador deixou pilastras isoladas (1 célula de rocha cercada de chão)
	var pilares := 0
	for c in _altura:
		var livres := 0
		for d in g._vizinhos4(c):
			if g.chao(d):
				livres += 1
		if livres >= 3:
			modelo("kaykit_dungeon/column.gltf", grupo, g.mundo(c) + Vector3(0, float(_altura[c]), 0), 0.0, 0.5)
			pilares += 1
	stats["pilares"] = pilares
	var props := [
		["kaykit_dungeon/candle_triple.gltf", 0.6, Vector3.ZERO],
		["kaykit_dungeon/candle_lit.gltf", 0.6, Vector3.ZERO],
		["kaykit_dungeon/rubble_half.gltf", 0.35, Vector3.ZERO],
		["kaykit_dungeon/rubble_large.gltf", 0.35, Vector3(1.2, 0.6, 1.2)],
		["kaykit_dungeon/sword_shield_broken.gltf", 0.5, Vector3.ZERO],
		["kaykit_dungeon/shelf_small_candles.gltf", 0.5, Vector3(1.0, 1.0, 0.5)],
		["kaykit_dungeon/trunk_small_A.gltf", 0.6, Vector3(1.0, 0.7, 0.7)],
		["kaykit_dungeon/barrel_small.gltf", 0.5, Vector3(0.6, 0.7, 0.6)],
		["kenney_space_kit/bones.glb", 1.6, Vector3.ZERO],
		["kenney_mini_dungeon/stones.glb", 1.0, Vector3.ZERO],
		["kenney_mini_dungeon/banner.glb", 1.2, Vector3.ZERO],
		["kaykit_skeletons/Skeleton_Blade.gltf", 0.9, Vector3.ZERO],
		["kaykit_skeletons/Skeleton_Shield_Small_A.gltf", 0.9, Vector3.ZERO],
	]
	stats["aderecos"] = _espalhar(props, 18 + andar * 3)
	# velas espalhadas com luz fria e poeira de túmulo
	for k in 6:
		var cs: Array = g.celulas_de_parede(_ocupadas)
		if cs.is_empty():
			break
		var c: Vector2i = cs[_rng.randi() % cs.size()]
		_ocupadas[c] = true
		modelo("kaykit_dungeon/candle_triple.gltf", grupo, g.mundo(c), _rng.randf() * TAU, 0.6)
		_luz(grupo, g.mundo(c) + Vector3(0, 1.0, 0), Color("ffc890"), 1.2, 5.0)
	# sinos afogados pendurados na nave do chefe
	if g.estilo == "nave":
		for k in 5:
			var c: Vector2i = g.alvo_chefe + Vector2i(_rng.randi_range(-5, 5), _rng.randi_range(-8, 2))
			if not g.chao(c):
				continue
			var sino := CylinderMesh.new()
			sino.top_radius = 0.18
			sino.bottom_radius = 0.45
			sino.height = 0.6
			var bronze := StandardMaterial3D.new()
			bronze.albedo_color = Color("6a5a3a")
			bronze.metallic = 0.8
			bronze.roughness = 0.4
			var mi := _malha(grupo, sino, g.mundo(c) + Vector3(0, 3.0 + _rng.randf(), 0), bronze)
			pulsantes.append({"no": mi, "tipo": "pulsa", "fase": k * 1.3})
		_rotulo(grupo, "Nave dos Sinos Afogados", g.mundo(g.alvo_chefe) + Vector3(0, 5.5, 0), Color("bff0e8"), 1.0)

func _aderecos_fenda() -> void:
	var grupo := _grupo("Aderecos")
	var props := [
		["quaternius_scifi_modular/Column_Astra.gltf", 0.55, Vector3(0.8, 2.0, 0.8)],
		["quaternius_scifi_modular/Prop_Light_Floor.gltf", 0.8, Vector3.ZERO],
		["quaternius_scifi_modular/Prop_Crate3.gltf", 0.6, Vector3(0.9, 0.9, 0.9)],
		["quaternius_scifi_modular/Prop_Barrel_Large.gltf", 0.55, Vector3(0.8, 1.0, 0.8)],
		["quaternius_scifi_modular/Prop_Computer.gltf", 0.6, Vector3(0.8, 1.0, 0.6)],
		["kenney_space_station/container.glb", 1.0, Vector3(1.0, 1.0, 1.0)],
		["kenney_space_station/computer-system.glb", 1.0, Vector3(1.0, 1.2, 0.6)],
		["kenney_space_kit/rock_crystals.glb", 1.2, Vector3.ZERO],
		["kenney_space_kit/rocks_smallA.glb", 1.2, Vector3.ZERO],
		["kenney_space_kit/machine_wireless.glb", 1.0, Vector3(0.8, 1.2, 0.8)],
		["quaternius_scifi_essentials/Prop_Crate_Large.gltf", 0.5, Vector3(1.0, 1.0, 1.0)],
	]
	stats["aderecos"] = _espalhar(props, 14 + andar * 3)
	# cristais cronais nas bordas das ilhas
	var prisma := CylinderMesh.new()
	prisma.top_radius = 0.0
	prisma.bottom_radius = 0.14
	prisma.height = 1.1
	prisma.radial_segments = 6
	prisma.rings = 1
	var bordas: Array = _bordas()
	_embaralhar(bordas)
	var postos: Array = []
	for k in 10 + andar * 2:
		var c := _celula_livre(bordas, postos, 3)
		if c.x < 0:
			break
		postos.append(c)
		_ocupadas[c] = true
		var cl := Node3D.new()
		cl.name = "CristalCronal"
		cl.position = g.mundo(c)
		grupo.add_child(cl)
		for j in _rng.randi_range(3, 5):
			var ang := _rng.randf() * TAU
			var s := _rng.randf_range(0.5, 1.3)
			var mi := _malha(cl, prisma, Vector3(cos(ang), 0, sin(ang)) * 0.25 + Vector3(0, 0.4 * s, 0), mat("cristal_tema"), Vector3(_rng.randf_range(-0.6, 0.6), ang, _rng.randf_range(-0.6, 0.6)))
			mi.scale = Vector3.ONE * s
		if k % 2 == 0:
			_luz(cl, Vector3(0, 0.8, 0), Color(String(paleta.get("cristal", "ff4af0"))), 1.3, 5.0)
		pulsantes.append({"no": cl, "tipo": "brasa", "fase": k * 0.77})
	# engrenagens de relógio flutuando sobre o vazio
	var ouro := StandardMaterial3D.new()
	ouro.albedo_color = Color("d8b060")
	ouro.metallic = 0.85
	ouro.roughness = 0.3
	ouro.emission_enabled = true
	ouro.emission = Color("ffb030")
	ouro.emission_energy_multiplier = 0.5
	var vazios: Array = []
	for y in range(0, g.h, 3):
		for x in range(0, g.w, 3):
			var c := Vector2i(x, y)
			if g.valor(c) == Gerador.ABISMO and g.cercado(c, 0):
				vazios.append(c)
	_embaralhar(vazios)
	for k in mini(12, vazios.size()):
		var c: Vector2i = vazios[k]
		var t := TorusMesh.new()
		var r := _rng.randf_range(0.8, 2.2)
		t.inner_radius = r
		t.outer_radius = r + 0.22
		t.rings = 24
		var piv := Node3D.new()
		piv.position = g.mundo(c) + Vector3(0, _rng.randf_range(-2.5, -0.8), 0)
		piv.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6))
		grupo.add_child(piv)
		_malha(piv, t, Vector3.ZERO, ouro)
		for d in 8:
			var b := BoxMesh.new()
			b.size = Vector3(0.3, 0.2, 0.3)
			var ang := d * TAU / 8.0
			_malha(piv, b, Vector3(cos(ang), 0, sin(ang)) * (r + 0.3), ouro, Vector3(0, -ang, 0))
		pulsantes.append({"no": piv, "tipo": "gira_y", "fase": _rng.randf_range(0.15, 0.5) * (1 if k % 2 == 0 else -1)})
	# o anel do chefe: mostrador gigante no chão
	if g.estilo == "anel":
		var centro: Vector3 = g.mundo(g.alvo_chefe)
		for h in 12:
			var ang := h * TAU / 12.0
			var b := BoxMesh.new()
			b.size = Vector3(0.35, 0.06, 1.4 if h % 3 == 0 else 0.8)
			_malha(grupo, b, centro + Vector3(sin(ang), 0.03, cos(ang)) * 9.5, mat("luz_fria"), Vector3(0, ang, 0))
		_rotulo(grupo, "O Relógio Partido", centro + Vector3(0, 6.0, 0), Color("ffd0ff"), 1.1)

func _process(delta: float) -> void:
	super._process(delta)
	for p in pulsantes:
		if String(p.tipo) == "gira_y" and is_instance_valid(p.no):
			p.no.rotation.y += delta * float(p.fase)

# ------------------------------------------------------------------ ambiente
func _ambiente() -> void:
	if tema == "minas_da_cinza":
		super._ambiente()
		return
	var we := WorldEnvironment.new()
	we.name = "AmbienteDaMasmorra"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(String(paleta.get("fundo", "08080c")))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(String(paleta.get("ambiente", "6a7090")))
	env.ambient_light_energy = float(paleta.get("ambiente_energia", 0.5))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(String(paleta.get("neblina", "4a5070")))
	env.fog_light_energy = 0.7
	env.fog_density = 0.0
	env.fog_height = 0.6 if tema != "fenda_cronal" else -1.0
	env.fog_height_density = float(paleta.get("neblina_densidade", 0.2))
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.name = "LuzDeLeitura"
	sol.light_color = Color(String(paleta.get("luz", "d0d8ff"))).lerp(Color.WHITE, 0.5)
	sol.light_energy = 0.4
	sol.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 80.0
	add_child(sol)
	var tam := Vector3(g.w, 1.5, g.h) * (Gerador.CELULA * 0.5)
	if tema == "criptas_de_cinzalta":
		var poeira := _particulas(Color(0.7, 0.78, 0.9, 0.45), 240, tam, 10.0, 0.15)
		poeira.position = Vector3(0, 1.4, 0)
		poeira.name = "PoeiraDeTumulo"
		add_child(poeira)
		var almas := _particulas(Color(0.5, 0.95, 1.0, 0.8), 60, tam, 6.0, 0.4)
		almas.position = Vector3(0, 0.6, 0)
		almas.name = "Almas"
		add_child(almas)
	else:
		var faiscas := _particulas(Color(0.4, 0.95, 1.0, 0.9), 220, Vector3(tam.x, 2.0, tam.z), 6.0, 0.9)
		faiscas.position = Vector3(0, -2.0, 0)
		faiscas.name = "FagulhasDoTempo"
		add_child(faiscas)
		var rosa := _particulas(Color(1.0, 0.45, 0.95, 0.85), 120, Vector3(tam.x, 2.0, tam.z), 7.0, 0.6)
		rosa.position = Vector3(0, -1.5, 0)
		rosa.name = "FagulhasRosa"
		add_child(rosa)
		# luz de baixo para cima vinda do vazio
		var vazio := OmniLight3D.new()
		vazio.light_color = Color("a05aff")
		vazio.light_energy = 3.0
		vazio.omni_range = maxf(g.w, g.h) * 1.4
		vazio.position = Vector3(0, -6.0, 0)
		add_child(vazio)
	# véus de neblina rasteira
	var veu := QuadMesh.new()
	veu.size = Vector2(7, 7)
	var mv := StandardMaterial3D.new()
	mv.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var nc := Color(String(paleta.get("neblina", "4a5070")))
	mv.albedo_color = Color(nc.r, nc.g, nc.b, 0.22)
	mv.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	mv.albedo_texture = gt
	var grupo := _grupo("NeblinaRasteira")
	var k := 0
	for c in g.distancia:
		if g.cercado(c, 1) and (c.x * 7 + c.y * 13) % 11 == 0 and k < 22:
			_malha(grupo, veu, g.mundo(c) + Vector3(0, 0.35 + (k % 3) * 0.12, 0), mv, Vector3(-PI / 2, k * 0.6, 0))
			k += 1

# ------------------------------------------------------------------ jogadora de combate / câmera
func _mirar(alvo: Vector3, tam: float) -> void:
	var y := deg_to_rad(CAM_YAW_COMBATE)
	var p := deg_to_rad(CAM_PITCH_COMBATE)
	var tras := Vector3(cos(p) * sin(y), sin(p), cos(p) * cos(y))
	camera.size = tam
	camera.global_transform = Transform3D(Basis.IDENTITY, alvo + tras * 60.0).looking_at(alvo, Vector3.UP)

func _jogador_e_camera() -> void:
	jogador = JogadorCombate.new()
	jogador.name = "Vale"
	jogador.add_to_group("jogador")
	var sp := marcador("spawn_jogador")
	jogador.position = sp.position if sp else Vector3.ZERO
	add_child(jogador)
	if Sessao.hp_jogador > 0:
		jogador.hp = mini(Sessao.hp_jogador, jogador.hp_max)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("ffd29a") if tema != "fenda_cronal" else Color("c8f0ff")
	lamp.light_energy = 1.3
	lamp.omni_range = 6.5
	lamp.position = Vector3(0.3, 1.8, 0.3)
	lamp.name = "LampiaoDeMao"
	jogador.add_child(lamp)
	camera = Camera3D.new()
	camera.name = "CameraIsometrica"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = TAM_CAMERA_COMBATE
	camera.near = 0.15
	camera.far = 600
	add_child(camera)
	camera.make_current()
	_mirar(jogador.position, TAM_CAMERA_COMBATE)
	_aviso = _rotulo(self, "", Vector3.ZERO, Color("fff0c0"), 0.8)
	_aviso.name = "AvisoDeSaida"
	_aviso.visible = false
	jogador.morreu.connect(_jogadora_caiu)

func _montar_hud() -> void:
	hud = Hud.new()
	hud.name = "HudMasmorra"
	add_child(hud)
	var sub := String(dados.get("subtitulo", ""))
	if g.chefe:
		sub = "Covil: " + String(Sessao.dados_inimigo(String(dados.get("chefe", ""))).get("nome", "chefe"))
	hud.definir_titulo(GeradorTema.nome_do_andar_tema(dados, andar), sub, Color(String(paleta.get("leitura", "ffd27a"))))
	hud.mostrar_banner(GeradorTema.nome_do_andar_tema(dados, andar), 2.2, Color(String(paleta.get("leitura", "ffd27a"))))

func _mira() -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var mp := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(mp)
	var n := camera.project_ray_normal(mp)
	if absf(n.y) < 0.001:
		return Vector3.ZERO
	var p := o + n * (-o.y / n.y)
	var d := p - jogador.global_position
	d.y = 0
	return d.normalized() if d.length() > 0.3 else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if jogador == null:
		return
	var capturando := OS.get_environment("DUNGEON_CAPTURA") != ""
	if not (modo_teste or capturando):
		var inp := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"): inp.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"): inp.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"): inp.y += 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"): inp.y -= 1
		jogador.entrada_mov = Vector2.ZERO if (demo_mode or _morta) else inp.limit_length(1.0)
	if not capturando:
		var tam := maxf(g.w, g.h) * Gerador.CELULA * 0.8 if visao_geral else TAM_CAMERA_COMBATE * zoom
		var alvo := Vector3.ZERO if visao_geral else Vector3(jogador.position.x, 0, jogador.position.z)
		_tremor = maxf(0.0, _tremor - delta * 2.5)
		if _tremor > 0.0:
			alvo += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * _tremor * 0.25
		_mirar(alvo, tam)
	interagir_com = _alvo_interacao()
	if hud:
		hud.mostrar_prompt("" if interagir_com == null or demo_mode or _morta else "[E] " + _texto_interacao(interagir_com))
		var info := "inimigos %d · baús %d/%d · itens na bolsa %d" % [combate.vivos().size(), baus.filter(func(b): return bool(b.get_meta("aberto"))).size(), baus.size(), _total_itens()]
		hud.atualizar(jogador, combate.chefe(), info)
	if _morta and not modo_teste:
		_t_morte += delta
		if _t_morte > 3.0 and not _saindo:
			sair_para_origem()

func _total_itens() -> int:
	var n := 0
	for k in Sessao.inventario.get("itens", {}):
		n += int(Sessao.inventario.itens[k])
	return n

func _alvo_interacao() -> Node3D:
	var p := jogador.global_position
	var melhor: Node3D = null
	var dmin := 1e9
	for mk in marcadores.get_children():
		if mk.has_meta("destino") or mk.has_meta("destino_andar"):
			var d := Vector2(mk.global_position.x - p.x, mk.global_position.z - p.z).length()
			if d < 1.8 and d < dmin:
				dmin = d
				melhor = mk
	for b in baus:
		if is_instance_valid(b) and not bool(b.get_meta("aberto")):
			var d := Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length()
			if d < 1.9 and d < dmin:
				dmin = d
				melhor = b
	for mk in nos_minerio.get_children():
		if not bool(mk.get_meta("esgotado")):
			var d := Vector2(mk.global_position.x - p.x, mk.global_position.z - p.z).length()
			if d < 1.7 and d < dmin:
				dmin = d
				melhor = mk
	return melhor

func _texto_interacao(n: Node3D) -> String:
	if n.is_in_group("bau_masmorra"):
		return "Abrir " + ("baú do chefe" if bool(n.get_meta("chefe")) else "baú")
	if n.is_in_group("minerio_no"):
		var ok: bool = forja.pode_minerar(String(n.get_meta("material")), Sessao.picareta)
		return "Minerar %s%s" % [String(n.get_meta("nome")), "" if ok else " (picareta fraca)"]
	if n.has_meta("destino_andar"):
		var bloq := _escada_bloqueada()
		return String(n.get_meta("descricao")) + (" (derrote os guardiões perto da escada)" if bloq else "")
	return String(n.get_meta("descricao"))

## a escada só abre sem inimigos acordados por perto (evita fugir correndo de tudo)
func _escada_bloqueada() -> bool:
	for e in combate.vivos():
		if e.acordado and e.global_position.distance_to(jogador.global_position) < 6.0:
			return true
	return false

func interagir() -> String:
	var n := interagir_com if interagir_com else _alvo_interacao()
	if n == null:
		return ""
	if n.is_in_group("bau_masmorra"):
		abrir_bau(n)
		return "bau"
	if n.is_in_group("minerio_no"):
		var r: Dictionary = minerar(String(n.name), Sessao.picareta, Sessao.inventario)
		if r.get("ok", false):
			if hud:
				hud.loot("+%d %s" % [int(r.quantidade), forja.nome(String(r.material))], Color("ffe9c2"))
		elif hud:
			hud.mostrar_banner(String(r.get("motivo", "")), 1.6, Color("ffb0a0"))
		return "minerio"
	if n.has_meta("destino_andar"):
		if _escada_bloqueada():
			if hud:
				hud.mostrar_banner("Inimigos por perto!", 1.2, Color("ff9a8a"))
			return "bloqueada"
		descer(int(n.get_meta("destino_andar")))
		return "descer"
	if n.has_meta("destino"):
		sair_para_origem()
		return "sair"
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if modo_teste or _morta:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP: zoom = maxf(0.5, zoom * 0.9)
				MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(3.0, zoom * 1.1)
				MOUSE_BUTTON_LEFT: jogador.pedir_ataque(_mira())
				MOUSE_BUTTON_RIGHT: _especial(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_especial(false)
	if event is InputEventKey and not event.echo:
		var k: int = event.physical_keycode
		if event.pressed:
			match k:
				KEY_TAB: visao_geral = not visao_geral
				KEY_E: if not demo_mode: interagir()
				KEY_J: jogador.pedir_ataque(_mira())
				KEY_K: _especial(true)
				KEY_SPACE: jogador.pedir_dash()
				KEY_G: jogador.pedir_transformar()
		elif k == KEY_K:
			_especial(false)

func _especial(apertou: bool) -> void:
	if jogador.transformado:
		if apertou:
			jogador.pedir_raio(_mira())
		else:
			jogador.soltar_raio()
	elif apertou:
		jogador.pedir_especial(_mira())

# ------------------------------------------------------------------ fluxo entre andares / cidade
func descer(novo: int) -> void:
	if _saindo or novo < 0:
		return
	_saindo = true
	combate.coletar_tudo()
	Sessao.hp_jogador = jogador.hp
	Sessao.andar = novo
	Sessao.marcar_profundidade(tema, novo)
	desceu.emit(andar, novo)
	trocou_de_andar.emit(andar, novo)
	var caminho := scene_file_path if scene_file_path != "" else Registro.cena(tema)
	if modo_teste:
		return
	# dentro do jogo (jogo_ilha.gd) a masmorra e uma area filha: recarrega so ela, sem trocar a cena inteira
	var g: Node = Registro.gerenciador(get_tree())
	if g != null and g.has_method("recarregar"):
		g.recarregar("andar_%d" % novo)
		return
	get_tree().call_deferred("change_scene_to_file", caminho)

func sair_para_origem() -> void:
	if _saindo:
		return
	_saindo = true
	if not _morta:
		combate.coletar_tudo()
	Sessao.hp_jogador = -1
	Sessao.ativa = false
	var area := Sessao.origem_area if Sessao.origem_area != "" else String(dados.get("origem_padrao", ""))
	saiu_da_masmorra.emit(area, Sessao.origem_ponto)
	if modo_teste:
		return
	if Registro.viajar(get_tree(), area, Sessao.origem_ponto) != OK and hud:
		hud.mostrar_banner("Cena de %s não encontrada" % area, 2.0, Color("ff9a8a"))
		_saindo = false

func _jogadora_caiu() -> void:
	if _morta:
		return
	_morta = true
	_t_morte = 0.0
	if hud:
		hud.mostrar_banner("A Vale caiu... o loot no chão se perde.\nVoltando para %s" % _nome_origem(), 3.0, Color("ff8a7a"))

# ------------------------------------------------------------------ capturas (previews)
func _capturas_tema(pasta: String) -> void:
	get_window().size = Vector2i(1600, 900)
	jogador.invulneravel_ate = 1e9
	var so := OS.get_environment("DUNGEON_CAPTURA_SO")
	for i in 20:
		await get_tree().physics_frame
	var lista: Array = []
	if so == "" or so.contains("visao"):
		lista.append({"nome": "visao_geral", "alvo": Vector3.ZERO, "tam": maxf(g.w, g.h) * Gerador.CELULA * 0.74, "esconder_hud": true})
	if so == "" or so.contains("entrada"):
		lista.append({"nome": "entrada", "alvo": g.mundo(g.entrada) + Vector3(1.5, 0, 1.5), "tam": 17.0, "pos": g.mundo(g.entrada) + Vector3(1.2, 0, 1.2)})
	# combate: grupo de inimigos mais próximo de um ponto médio
	var vivos: Array = combate.vivos().filter(func(e): return not e.is_in_group("chefe_masmorra"))
	if (so == "" or so.contains("combate")) and vivos.size() > 0:
		var e0 = vivos[vivos.size() / 2]
		var melhor := -1
		for e in vivos:
			var n := 0
			for f in vivos:
				if f.global_position.distance_to(e.global_position) < 7.0:
					n += 1
			if n > melhor:
				melhor = n
				e0 = e
		lista.append({"nome": "combate", "alvo": e0.global_position, "tam": 12.5, "lutar": e0})
	var ch = combate.chefe()
	if (so == "" or so.contains("chefe")) and ch:
		lista.append({"nome": "chefe", "alvo": ch.global_position, "tam": 16.0, "lutar": ch})
	for c in lista:
		hud.visible = not c.get("esconder_hud", false)
		if c.has("pos"):
			jogador.global_position = c.pos
		if c.has("lutar"):
			var e = c.lutar
			var p: Vector3 = e.global_position
			var mapa := get_world_3d().navigation_map
			var alvo: Vector3 = NavigationServer3D.map_get_closest_point(mapa, p + Vector3(2.6, 0, 2.6))
			jogador.global_position = Vector3(alvo.x, 0, alvo.z)
			for f in combate.vivos():
				if f.global_position.distance_to(p) < 9.0:
					f.acordar()
			for i in 50:
				await get_tree().physics_frame
				if i == 30:
					jogador.pedir_ataque(e.global_position - jogador.global_position)
			c.alvo = (jogador.global_position + e.global_position) * 0.5
		_mirar(Vector3(c.alvo.x, 0, c.alvo.z), float(c.tam))
		for i in 4:
			await get_tree().process_frame
		var arq := pasta.path_join("%s_andar_%02d_%s.png" % [tema, andar, String(c.nome)])
		get_viewport().get_texture().get_image().save_png(arq)
		print("[masmorra] captura: ", arq)
	get_tree().quit()
