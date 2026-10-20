extends RefCounted
## Gerador de andares das Minas da Cinza (PROPOSTA, não é canon).
## Determinístico: o mesmo (andar, semente) gera sempre o mesmo andar.
##   andares 1-5  -> "galerias": salas escavadas ligadas por túneis (cobre)
##   andares 6-12 -> "cavernas": cavernas naturais por autômato celular (ferro)
##   andar 20+    -> "coracao": o Coração Soterrado, salão redondo com um abismo de brasa (adamantium)
## Grade em células de CELULA metros. Valores: 0 rocha, 1 chão, 2 abismo, 3 poço da escada.
## Os minérios de cada andar vêm de data/forja/materiais.json (local + faixa "andares").

const CELULA := 2.0
const MATERIAIS := "res://data/forja/materiais.json"
const ROCHA := 0
const CHAO := 1
const ABISMO := 2
const POCO := 3

const NPCS_POR_ANDAR := {
	1: ["minerador_aposentado", "vagoneta_falante"],
	4: ["fantasma_mineiro"],
	9: ["mercador_minerio", "vagoneta_falante"],
	20: ["fantasma_mineiro"],
}

var andar := 1
var semente := 0
var w := 24
var h := 24
var grade := PackedByteArray()
var rng := RandomNumberGenerator.new()
var estilo := "galerias"
var salas: Array = []          # [Rect2i]
var entrada := Vector2i.ZERO
var escada := Vector2i(-1, -1) # célula do poço que desce
var aproximacao := Vector2i.ZERO
var distancia := {}            # Vector2i -> passos desde a entrada
var caminho: Array = []        # células da entrada até a escada (trilho)

static func estilo_do_andar(a: int) -> String:
	if a >= 20:
		return "coracao"
	return "cavernas" if a >= 6 else "galerias"

static func nome_do_andar(a: int) -> String:
	if a >= 20:
		return "Coração Soterrado · andar %d" % a
	if a >= 6:
		return "Minas da Cinza · andar %d · veios de ferro" % a
	return "Minas da Cinza · andar %d · galerias de cobre" % a

## Materiais mineráveis deste andar, lidos de materiais.json (o "gancho de dados").
static func materiais_do_andar(a: int, todos: Array) -> Array:
	var local := "coracao_soterrado" if a >= 20 else "minas_da_cinza"
	var out: Array = []
	for m in todos:
		if not (m is Dictionary) or not m.has("picareta_minima"):
			continue
		if not (local in m.get("onde", [])):
			continue
		var f = m.get("andares", null)
		if f is Array and f.size() == 2 and (a < int(f[0]) or a > int(f[1])):
			continue
		out.append(m)
	return out

static func inimigos_do_andar(a: int) -> Dictionary:
	if a >= 20:
		return {"orc": 2, "morcego": 3, "lodo_de_cinza": 4}
	var orc := 0 if a <= 2 else (1 if a <= 5 else (2 if a <= 9 else 3))
	var lodo := 0 if a == 1 else (2 if a <= 5 else 3)
	return {"orc": orc, "morcego": 2 + a / 3, "lodo_de_cinza": lodo}

func _init(a := 1, s := -1) -> void:
	andar = a
	semente = s if s >= 0 else 1500 + a * 7919
	rng.seed = semente
	estilo = estilo_do_andar(a)

func _ix(c: Vector2i) -> int:
	return c.y * w + c.x

func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

func valor(c: Vector2i) -> int:
	return grade[_ix(c)] if dentro(c) else ROCHA

func por(c: Vector2i, v: int) -> void:
	if dentro(c):
		grade[_ix(c)] = v

func chao(c: Vector2i) -> bool:
	return valor(c) == CHAO

## centro da célula em metros (a grade fica centrada na origem)
func mundo(c: Vector2i) -> Vector3:
	return Vector3((c.x - w * 0.5 + 0.5) * CELULA, 0.0, (c.y - h * 0.5 + 0.5) * CELULA)

func celula_de(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELULA + w * 0.5)), int(floor(p.z / CELULA + h * 0.5)))

func gerar() -> void:
	match estilo:
		"galerias":
			w = 24 + andar * 2
			h = 22 + andar * 2
		"cavernas":
			w = 30 + (andar - 6)
			h = 28 + (andar - 6)
		_:
			w = 30
			h = 30
	grade = PackedByteArray()
	grade.resize(w * h)
	grade.fill(ROCHA)
	match estilo:
		"galerias": _galerias()
		"cavernas": _cavernas()
		_: _coracao()
	_maior_regiao()
	_distancias()
	_escolher_escada()

# ------------------------------------------------------------------ estilos
func _sala(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			por(Vector2i(x, y), CHAO)

func _tunel(a: Vector2i, b: Vector2i, largura: int) -> void:
	var c := a
	var horiz_primeiro := rng.randf() < 0.5
	var passos := [Vector2i(signi(b.x - a.x), 0), Vector2i(0, signi(b.y - a.y))]
	if not horiz_primeiro:
		passos.reverse()
	for p in passos:
		if p == Vector2i.ZERO:
			continue
		while (p.x != 0 and c.x != b.x) or (p.y != 0 and c.y != b.y):
			for k in largura:
				por(c + (Vector2i(0, k) if p.x != 0 else Vector2i(k, 0)), CHAO)
			c += p
	for k in largura:
		por(c + Vector2i(k, 0), CHAO)

func _galerias() -> void:
	# sala de entrada fixa no canto noroeste (alto da tela); o andar 1 tem a cisterna maior
	var e := Rect2i(2, 2, 7, 6) if andar == 1 else Rect2i(2, 2, 5, 5)
	salas = [e]
	var alvo := 5 + andar
	var tentativas := 0
	while salas.size() < alvo and tentativas < 400:
		tentativas += 1
		var sw := rng.randi_range(4, 7)
		var sh := rng.randi_range(4, 6)
		var r := Rect2i(rng.randi_range(2, w - sw - 2), rng.randi_range(2, h - sh - 2), sw, sh)
		var ok := true
		for s in salas:
			if s.grow(2).intersects(r):
				ok = false
				break
		if ok:
			salas.append(r)
	for s in salas:
		_sala(s)
	# cada sala liga na mais próxima das já ligadas (árvore) + 1 atalho para ter um laço
	var ligadas := [salas[0]]
	for s in salas.slice(1):
		var melhor = ligadas[0]
		for l in ligadas:
			if Vector2(l.get_center()).distance_to(Vector2(s.get_center())) < Vector2(melhor.get_center()).distance_to(Vector2(s.get_center())):
				melhor = l
		_tunel(melhor.get_center(), s.get_center(), 2 if rng.randf() < 0.6 else 1)
		ligadas.append(s)
	if salas.size() > 3:
		_tunel(salas[1].get_center(), salas[salas.size() - 1].get_center(), 1)
	_rachar(0.22)
	entrada = e.get_center()

## bordas irregulares: abre algumas células de rocha encostadas no chão
func _rachar(p: float) -> void:
	var abrir: Array = []
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			var c := Vector2i(x, y)
			if valor(c) != ROCHA:
				continue
			var viz := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if chao(c + d):
					viz += 1
			if viz >= 2 and rng.randf() < p * 2.0 or viz == 1 and rng.randf() < p:
				abrir.append(c)
	for c in abrir:
		por(c, CHAO)

func _cavernas() -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			por(Vector2i(x, y), CHAO if rng.randf() < 0.55 else ROCHA)
	for it in 5:
		var nova := grade.duplicate()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var rocha := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and valor(Vector2i(x + dx, y + dy)) == ROCHA:
							rocha += 1
				nova[y * w + x] = ROCHA if rocha >= 5 else (CHAO if rocha <= 3 else grade[y * w + x])
		grade = nova
	# moldura de rocha
	for x in w:
		por(Vector2i(x, 0), ROCHA); por(Vector2i(x, 1), ROCHA); por(Vector2i(x, h - 1), ROCHA); por(Vector2i(x, h - 2), ROCHA)
	for y in h:
		por(Vector2i(0, y), ROCHA); por(Vector2i(1, y), ROCHA); por(Vector2i(w - 1, y), ROCHA); por(Vector2i(w - 2, y), ROCHA)
	# galeria de entrada escavada pelos mineiros (sempre existe) + túnel até o centro
	var e := Rect2i(2, 2, 5, 5)
	_sala(e)
	salas = [e]
	_tunel(e.get_center(), Vector2i(w / 2, h / 2), 2)
	entrada = e.get_center()

func _coracao() -> void:
	var centro := Vector2(w * 0.5, h * 0.5)
	var ruido := FastNoiseLite.new()
	ruido.seed = semente
	ruido.frequency = 0.18
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centro)
			var raio := 12.0 + ruido.get_noise_2d(x, y) * 2.5
			if d < raio:
				por(Vector2i(x, y), CHAO)
			if d < 3.6 + ruido.get_noise_2d(x * 2.0, y * 2.0) * 1.2:
				por(Vector2i(x, y), ABISMO)
	# descida (escada que vem do andar 12) ao norte
	var e := Rect2i(int(centro.x) - 2, 2, 4, 4)
	_sala(e)
	salas = [e]
	entrada = Vector2i(int(centro.x), 3)

# ------------------------------------------------------------------ conectividade
func _vizinhos4(c: Vector2i) -> Array:
	return [c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]

func _maior_regiao() -> void:
	var visto := {}
	var melhor: Array = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not chao(c) or visto.has(c):
				continue
			var regiao: Array = [c]
			visto[c] = true
			var k := 0
			while k < regiao.size():
				for v in _vizinhos4(regiao[k]):
					if chao(v) and not visto.has(v):
						visto[v] = true
						regiao.append(v)
				k += 1
			if regiao.has(entrada) or regiao.size() > melhor.size() and not (melhor.has(entrada)):
				melhor = regiao
	var manter := {}
	for c in melhor:
		manter[c] = true
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if chao(c) and not manter.has(c):
				por(c, ROCHA)
	if not chao(entrada) and melhor.size() > 0:
		entrada = melhor[0]

func _distancias() -> void:
	distancia = {entrada: 0}
	var fila: Array = [entrada]
	var k := 0
	while k < fila.size():
		var c: Vector2i = fila[k]
		k += 1
		for v in _vizinhos4(c):
			if chao(v) and not distancia.has(v):
				distancia[v] = distancia[c] + 1
				fila.append(v)

func cercado(c: Vector2i, raio := 1) -> bool:
	for dy in range(-raio, raio + 1):
		for dx in range(-raio, raio + 1):
			if not chao(c + Vector2i(dx, dy)):
				return false
	return true

func _escolher_escada() -> void:
	if estilo == "coracao":
		# não há escada para baixo: o "fim" é a porta selada no lado sul
		var melhor := entrada
		for c in distancia:
			if c.y > melhor.y or c.y == melhor.y and absi(c.x - w / 2) < absi(melhor.x - w / 2):
				melhor = c
		aproximacao = melhor
		escada = Vector2i(-1, -1)
		caminho = _caminho_ate(aproximacao)
		return
	var melhor := Vector2i(-1, -1)
	var dmax := -1
	for c in distancia:
		if distancia[c] > dmax and cercado(c, 1):
			dmax = distancia[c]
			melhor = c
	if melhor.x < 0:
		for c in distancia:
			if distancia[c] > dmax:
				dmax = distancia[c]
				melhor = c
	# chega-se ao poço pela célula vizinha mais perto da entrada
	var ap := melhor
	for v in _vizinhos4(melhor):
		if distancia.has(v) and (ap == melhor or distancia[v] < distancia[ap]):
			ap = v
	aproximacao = ap
	caminho = _caminho_ate(aproximacao)
	escada = melhor
	por(escada, POCO)
	distancia.erase(escada)

func _caminho_ate(alvo: Vector2i) -> Array:
	if not distancia.has(alvo):
		return []
	var out: Array = [alvo]
	var c := alvo
	while c != entrada:
		var prox := c
		for v in _vizinhos4(c):
			if distancia.has(v) and distancia[v] == distancia[c] - 1:
				prox = v
				break
		if prox == c:
			break
		c = prox
		out.append(c)
	out.reverse()
	return out

## células de chão encostadas na rocha (boas para veios), fora do caminho do trilho
func celulas_de_parede(ocupadas: Dictionary) -> Array:
	var out: Array = []
	for c in distancia:
		if ocupadas.has(c) or distancia[c] < 4:
			continue
		var rochas := 0
		for v in _vizinhos4(c):
			if valor(v) == ROCHA:
				rochas += 1
		if rochas >= 1 and rochas <= 2:
			out.append(c)
	out.sort()   # ordem estável antes do sorteio
	return out
