extends RefCounted
## Definicoes de saidas (portoes largos) e trilhas de cada area. Chamado por vila_jogo / fazenda_mundo /
## arena_saida com 1 linha cada. Coordenadas em metros do mundo da area (x, z); norte = -z, leste = +x.
## Medidas tiradas da grade andavel real (tests/caminhos_sonda.gd): ver docs/MAPA_MUNDI.md.
const Saidas = preload("res://scripts/ilha/saidas_area.gd")
const Trilhas = preload("res://scripts/ilha/trilhas.gd")

## VILA: sul -> Fazenda, leste -> Arena, norte (portao das ruinas) -> Masmorra
const VILA_SAIDAS := [
	# faixa sul inteira em volta da trilha (x -12..12, z 19.5..30): nao da para "passar ao lado"
	{"area": "fazenda", "spawn": "da_vila", "centro": Vector2(0.0, 24.75), "tam": Vector2(24.0, 10.5), "dir": Vector2(0, 1), "rotulo": "Fazenda", "largura_visual": 5.0},
	# borda leste (x 21.5..32, z -12..4)
	{"area": "arena", "spawn": "da_vila", "centro": Vector2(26.75, -4.0), "tam": Vector2(16.0, 10.5), "dir": Vector2(1, 0), "rotulo": "Arena dos Orcs", "largura_visual": 5.0, "cor": Color(1.0, 0.45, 0.25)},
	# corredor das ruinas: celulas z=-20, x -7..-5, + soleira de 0,5 m na fileira z=-19 (quem encosta na borda entra)
	{"area": "masmorra", "spawn": "inicio", "centro": Vector2(-6.0, -20.35), "tam": Vector2(4.2, 2.7), "dir": Vector2(0, -1), "rotulo": "Masmorra", "largura_visual": 3.0, "cor": Color(0.45, 0.7, 1.0), "teste": {"angulos": [-15.0, 0.0, 15.0], "lado": 0.15, "recuo": 3.0}},
]
## FAZENDA: fim do corredor leste (celulas x 28..45, z -12..-10) -> Vila
const FAZENDA_SAIDAS := [
	{"area": "vila", "spawn": "da_fazenda", "centro": Vector2(44.5, -11.0), "tam": Vector2(5.0, 3.0), "dir": Vector2(1, 0), "rotulo": "Vila", "largura_visual": 3.4, "teste": {"angulos": [-15.0, 0.0, 15.0], "lado": 0.25, "recuo": 4.0}},
]
## ARENA: portao oeste na faixa de grama (so fora do combate) -> Vila
const ARENA_SAIDAS := [
	{"area": "vila", "spawn": "da_arena", "centro": Vector2(-10.2, 3.5), "tam": Vector2(6.0, 1.8), "dir": Vector2(-1, 0), "rotulo": "Vila", "largura_visual": 4.0, "arco": false},
]

static func vila(v) -> Node3D:
	var alt := func(x: float, z: float) -> float: return v.vila.altura(x, z)
	var tr = Trilhas.new()
	v.ground.add_child(tr)
	tr.montar(v.art_world, alt, 21)
	# sul: o calcamento acaba em z~17; a terra batida leva ate o portao
	tr.faixa([Vector2(0.0, 16.6), Vector2(0.2, 18.5), Vector2(0.0, 20.6)], 2.4, "terra")
	# leste: calcamento acaba em x~21
	tr.faixa([Vector2(19.6, -4.4), Vector2(21.0, -4.2), Vector2(22.6, -4.0)], 2.4, "terra")
	# norte: praca -> portao das ruinas
	tr.faixa([Vector2(-8.6, -12.2), Vector2(-7.4, -14.6), Vector2(-6.4, -17.0), Vector2(-6.0, -19.6)], 1.9, "pedra")
	for p in [Vector2(-1.8, 19.0), Vector2(1.9, 15.2), Vector2(20.6, -6.0), Vector2(-8.2, -15.6), Vector2(-4.7, -18.4)]:
		tr.lampiao(p)
	tr.placa(Vector2(-2.6, -9.2), [["Ruínas / Masmorra", Vector2(-6.0, -20.0)], ["Arena dos Orcs", Vector2(24.0, -4.0)], ["Fazenda", Vector2(0.0, 21.0)]])
	var s = Saidas.new()
	v.ground.add_child(s)
	s.montar(v, VILA_SAIDAS, v.art_world, alt)
	s.set_meta("trilhas", tr)
	return s

static func fazenda(f) -> Node3D:
	var alt := func(x: float, z: float) -> float: return f.vila.altura(x, z)
	var tr = Trilhas.new()
	f.ground.add_child(tr)
	tr.montar(f.art_world, alt, 33)
	# a trilha de pedra da fazenda ja existe (casa -> corredor leste); aqui so sinalizacao
	for x in [4.0, 14.0, 24.0, 31.0, 37.0]:
		tr.lampiao(Vector2(x, -12.7))
	tr.placa(Vector2(-9.2, -12.1), [["Vila", Vector2(44.0, -11.0)], ["Lago", Vector2(-19.0, 9.0)], ["Floresta (em breve)", Vector2(-27.0, -6.0)]])
	tr.placa(Vector2(-25.5, -9.0), [["Floresta do Bento — em breve", Vector2(-40.0, -9.0)]])
	var bloq := func() -> bool: return f.interiores != null and (f.interiores.ativo >= 0 or bool(f.interiores.get("ocupado")))
	var s = Saidas.new()
	f.ground.add_child(s)
	s.montar(f, FAZENDA_SAIDAS, f.art_world, alt, bloq)
	s.set_meta("trilhas", tr)
	return s

## ponte: arena_saida (tem .player e .gerenciador) + a arena
static func arena(ponte, a) -> Node3D:
	var bloq := func() -> bool: return String(a.estado_sala) in ["combate", "intervalo"]
	var s = Saidas.new()
	a.add_child(s)
	s.montar(ponte, ARENA_SAIDAS, a.art, Callable(), bloq)
	return s
