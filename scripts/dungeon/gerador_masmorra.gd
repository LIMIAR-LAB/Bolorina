extends "res://scripts/minas_da_cinza/gerador_minas.gd"
## Gerador de andares da masmorra procedural com temas (PROPOSTA, não é canon).
## Estende scripts/minas_da_cinza/gerador_minas.gd (mesma grade, mesmos valores e helpers) e
## acrescenta os estilos dos temas novos. Os dados de cada tema vêm de data/dungeon/temas.json.
##   minas_da_cinza:      galerias (1-5), cavernas (6-12), coracao (20, chefe)        [estilos herdados]
##   criptas_de_cinzalta: criptas (1-5: salas retangulares em grade, corredores retos, pilares),
##                        nave (6, chefe: antessala + nave comprida com fileiras de pilares)
##   fenda_cronal:        fenda (1-5: ilhas de chão partido sobre o vazio, pontes estreitas),
##                        anel (6, chefe: plataforma redonda com buracos, ilha de chegada e ponte)
## Determinístico para (tema, andar, semente). Semente por incursão: sessao_masmorra.gd.

const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")

var tema := ""
var dados: Dictionary = {}
var andar_chefe := 99
var chefe := false
var alvo_chefe := Vector2i(-1, -1)

func _init(t := "minas_da_cinza", a := 1, s := -1) -> void:
	tema = t
	dados = Sessao.dados_tema(t)
	andar_chefe = int(dados.get("andar_chefe", 99))
	super(a, s)
	estilo = estilo_tema(dados, a)
	chefe = a == andar_chefe

static func estilo_tema(d: Dictionary, a: int) -> String:
	for e in d.get("estilos", []):
		if a <= int(e[0]):
			return String(e[1])
	return "galerias"

## Minérios do andar: tabela do tema ([material, de, até, qtd]) cruzada com data/forja/materiais.json.
## Devolve [{"m": <dicionário do material>, "qtd": n}] só com ids que existem no JSON.
static func minerios_do_andar(d: Dictionary, a: int, todos: Array) -> Array:
	var por_id := {}
	for m in todos:
		if m is Dictionary:
			por_id[String(m.get("id", ""))] = m
	var out: Array = []
	for e in d.get("minerios", []):
		if a < int(e[1]) or a > int(e[2]) or not por_id.has(String(e[0])):
			continue
		var qtd := int(e[3])
		if String(por_id[String(e[0])].get("tipo", "")) == "minerio":
			qtd += mini(a / 3, 3)
		out.append({"m": por_id[String(e[0])], "qtd": qtd})
	return out

static func inimigos_do_andar_tema(d: Dictionary, a: int) -> Dictionary:
	for e in d.get("inimigos_por_andar", []):
		if a >= int(e[0]) and a <= int(e[1]):
			return e[2]
	return {}

static func nome_do_andar_tema(d: Dictionary, a: int) -> String:
	var n := String(d.get("nome", "Masmorra"))
	if a == int(d.get("andar_chefe", -1)):
		return "%s · andar %d · covil do chefe" % [n, a]
	return "%s · andar %d" % [n, a]

func gerar() -> void:
	match estilo:
		"galerias", "cavernas", "coracao":
			super.gerar()
			if chefe:
				alvo_chefe = aproximacao
			return
		"criptas":
			w = 30 + andar * 2
			h = 28 + andar * 2
		"nave":
			w = 26
			h = 36
		"fenda":
			w = 32 + andar * 2
			h = 30 + andar * 2
		_:
			w = 34
			h = 36
	grade = PackedByteArray()
	grade.resize(w * h)
	grade.fill(ABISMO if estilo in ["fenda", "anel"] else ROCHA)
	match estilo:
		"criptas": _criptas()
		"nave": _nave()
		"fenda": _fenda()
		_: _anel()
	_maior_regiao()
	if estilo in ["fenda", "anel"]:
		# ilhas soltas viram vazio (o _maior_regiao herdado as transforma em rocha)
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if valor(Vector2i(x, y)) == ROCHA:
					por(Vector2i(x, y), ABISMO)
	_distancias()
	_escolher_escada()

func _escolher_escada() -> void:
	if not chefe or estilo == "coracao":
		super._escolher_escada()
		return
	# andar do chefe: sem escada; o fim é a arena (onde o chefe nasce)
	var melhor := alvo_chefe
	if melhor.x < 0 or not distancia.has(melhor):
		var dmax := -1
		for c in distancia:
			if distancia[c] > dmax and cercado(c, 1):
				dmax = distancia[c]
				melhor = c
	alvo_chefe = melhor
	aproximacao = melhor
	escada = Vector2i(-1, -1)
	caminho = _caminho_ate(aproximacao)

# ------------------------------------------------------------------ Criptas
func _criptas() -> void:
	var cols := 3 if andar < 3 else 4
	var lins := 3
	var sw := (w - 2) / cols
	var sh := (h - 2) / lins
	var grade_salas := {}
	salas = []
	for j in lins:
		for i in cols:
			var rw := rng.randi_range(5, mini(8, sw - 2))
			var rh := rng.randi_range(5, mini(7, sh - 2))
			var x0 := 1 + i * sw + rng.randi_range(1, maxi(1, sw - rw - 1))
			var y0 := 1 + j * sh + rng.randi_range(1, maxi(1, sh - rh - 1))
			var r := Rect2i(x0, y0, rw, rh)
			grade_salas[Vector2i(i, j)] = r
			salas.append(r)
			_sala(r)
	# árvore geradora aleatória entre salas vizinhas da grade + 2 atalhos
	var ligadas := {Vector2i(0, 0): true}
	var arestas: Array = []
	for k in grade_salas:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if grade_salas.has(k + d):
				arestas.append([k, k + d, rng.randf()])
	arestas.sort_custom(func(a, b): return a[2] < b[2])
	var usadas: Array = []
	while ligadas.size() < grade_salas.size():
		for a in arestas:
			if ligadas.has(a[0]) != ligadas.has(a[1]):
				ligadas[a[0]] = true
				ligadas[a[1]] = true
				usadas.append(a)
				break
	var extras := 0
	for a in arestas:
		if extras >= 2:
			break
		if not (a in usadas):
			usadas.append(a)
			extras += 1
	for a in usadas:
		var ra: Rect2i = grade_salas[a[0]]
		var rb: Rect2i = grade_salas[a[1]]
		_tunel(ra.get_center(), rb.get_center(), 2)
	# pilares nas salas grandes (rocha dentro da sala = coluna)
	for r in salas:
		if r.size.x >= 7 and r.size.y >= 6:
			for p in [Vector2i(r.position.x + 1, r.position.y + 1), Vector2i(r.end.x - 2, r.position.y + 1),
					Vector2i(r.position.x + 1, r.end.y - 2), Vector2i(r.end.x - 2, r.end.y - 2)]:
				por(p, ROCHA)
	entrada = (grade_salas[Vector2i(0, 0)] as Rect2i).get_center()

func _nave() -> void:
	var cx := w / 2 + rng.randi_range(-3, 3)
	var ante := Rect2i(cx - 3, 2, 6, 5)
	_sala(ante)
	var porta := cx - 1 + rng.randi_range(-1, 1)
	_tunel(Vector2i(porta, 6), Vector2i(porta, 10), 2)
	var nave := Rect2i(4, 10, w - 8, h - 13)
	_sala(nave)
	var passo := rng.randi_range(3, 4)
	var recuo := rng.randi_range(2, 3)
	for y in range(nave.position.y + 2, nave.end.y - 2, passo):
		por(Vector2i(nave.position.x + recuo, y), ROCHA)
		por(Vector2i(nave.end.x - 1 - recuo, y), ROCHA)
	# túmulos/lajes no meio da nave (sorteados) e absides laterais
	for k in rng.randi_range(2, 4):
		var c := Vector2i(rng.randi_range(nave.position.x + 5, nave.end.x - 6), rng.randi_range(nave.position.y + 3, nave.end.y - 10))
		por(c, ROCHA)
		por(c + Vector2i(1, 0), ROCHA)
	var ay := rng.randi_range(h - 16, h - 11)
	_sala(Rect2i(1, ay, 3, rng.randi_range(4, 6)))
	_sala(Rect2i(w - 4, h - 27 + rng.randi_range(0, 10), 3, rng.randi_range(4, 6)))
	salas = [ante, nave]
	entrada = ante.get_center()
	alvo_chefe = Vector2i(clampi(cx + rng.randi_range(-2, 2), nave.position.x + 4, nave.end.x - 5), nave.end.y - 4)

# ------------------------------------------------------------------ Fenda
func _disco(c: Vector2, r: float, v: int, ruido: FastNoiseLite) -> void:
	for y in range(int(c.y - r - 2), int(c.y + r + 3)):
		for x in range(int(c.x - r - 2), int(c.x + r + 3)):
			if x < 1 or y < 1 or x >= w - 1 or y >= h - 1:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < r + ruido.get_noise_2d(x * 3.0, y * 3.0) * 0.9:
				por(Vector2i(x, y), v)

func _ponte(a: Vector2, b: Vector2, larg: int) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		for o in larg:
			var q := Vector2i(int(p.x) + (o if absf(b.y - a.y) > absf(b.x - a.x) else 0), int(p.y) + (0 if absf(b.y - a.y) > absf(b.x - a.x) else o))
			if q.x >= 1 and q.y >= 1 and q.x < w - 1 and q.y < h - 1:
				por(q, CHAO)

func _fenda() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = semente
	ruido.frequency = 0.25
	var centros: Array = [Vector2(5.5, 5.5)]
	var raios: Array = [3.4]
	var alvo := 7 + andar
	var tent := 0
	while centros.size() < alvo and tent < 600:
		tent += 1
		var r := rng.randf_range(2.4, 4.4)
		var c := Vector2(rng.randf_range(r + 2, w - r - 2), rng.randf_range(r + 2, h - r - 2))
		var ok := true
		for k in centros.size():
			if c.distance_to(centros[k]) < r + float(raios[k]) + 2.2:
				ok = false
				break
		if ok:
			centros.append(c)
			raios.append(r)
	for k in centros.size():
		_disco(centros[k], raios[k], CHAO, ruido)
	# pontes: árvore pelo vizinho mais próximo já ligado + 1 atalho
	var ligados := [0]
	for k in range(1, centros.size()):
		var melhor := 0
		for l in ligados:
			if centros[k].distance_to(centros[l]) < centros[k].distance_to(centros[melhor]):
				melhor = l
		_ponte(centros[melhor], centros[k], 2 if rng.randf() < 0.45 else 1)
		ligados.append(k)
	if centros.size() > 4:
		_ponte(centros[2], centros[centros.size() - 1], 1)
	salas = []
	for k in centros.size():
		var r := int(raios[k])
		salas.append(Rect2i(int(centros[k].x) - r, int(centros[k].y) - r, r * 2, r * 2))
	entrada = Vector2i(5, 5)

func _anel() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = semente
	ruido.frequency = 0.3
	var chegada := Vector2(w * 0.5, 5.0)
	var arena := Vector2(w * 0.5, h * 0.5 + 3.0)
	_disco(chegada, 3.2, CHAO, ruido)
	_disco(arena, 11.0, CHAO, ruido)
	_ponte(chegada, arena, 2)
	for k in 4:
		var ang := PI * 0.25 + k * PI * 0.5
		_disco(arena + Vector2(cos(ang), sin(ang)) * 6.5, 1.4, ABISMO, ruido)
	salas = [Rect2i(int(chegada.x) - 3, 2, 6, 6), Rect2i(int(arena.x) - 10, int(arena.y) - 10, 20, 20)]
	entrada = Vector2i(int(chegada.x), 5)
	alvo_chefe = Vector2i(int(arena.x), int(arena.y) + 2)
