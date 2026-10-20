extends RefCounted
## Gerador de andares de masmorra (Stardew minas + Hades salas), deterministico por semente.
## gerar(semente, andar) -> {"salas": {Vector2i: sala}, "arestas": [[a, b]], "inicio", "saida"}
## sala = {"celula", "tipo": inicio|combate|tesouro|descanso|saida, "inimigos": int, "props": [...], "portas": [dirs]}
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func gerar(semente: int, andar: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente * 7919 + andar * 104729
	var alvo: int = mini(6 + andar * 2, 14)
	var salas := {}
	var arestas: Array = []
	var atual := Vector2i.ZERO
	salas[atual] = {"celula": atual, "tipo": "combate", "inimigos": 0, "props": [], "portas": []}
	var guarda := 0
	# caminhada aleatoria com ramificacao (volta a uma sala existente as vezes)
	while salas.size() < alvo and guarda < 500:
		guarda += 1
		if rng.randf() < 0.3:
			atual = salas.keys()[rng.randi_range(0, salas.size() - 1)]
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var nova: Vector2i = atual + d
		if not salas.has(nova):
			salas[nova] = {"celula": nova, "tipo": "combate", "inimigos": 0, "props": [], "portas": []}
			arestas.append([atual, nova])
		elif not _tem_aresta(arestas, atual, nova) and rng.randf() < 0.15:
			arestas.append([atual, nova])  # laco ocasional
		atual = nova
	for a in arestas:
		salas[a[0]].portas.append(a[1] - a[0])
		salas[a[1]].portas.append(a[0] - a[1])
	# saida = sala mais distante (BFS) do inicio
	var dist := _bfs(salas, Vector2i.ZERO)
	var saida := Vector2i.ZERO
	for c in dist:
		if int(dist[c]) > int(dist.get(saida, 0)):
			saida = c
	salas[Vector2i.ZERO].tipo = "inicio"
	salas[saida].tipo = "saida"
	# tesouro numa folha (1 porta) que nao seja inicio/saida; descanso a partir do andar 2
	var folhas: Array = []
	for c in salas:
		if salas[c].portas.size() == 1 and c != Vector2i.ZERO and c != saida:
			folhas.append(c)
	folhas.sort()
	if not folhas.is_empty():
		salas[folhas[rng.randi_range(0, folhas.size() - 1)]].tipo = "tesouro"
	if andar >= 2:
		for c in salas:
			if salas[c].tipo == "combate" and int(dist[c]) == int(dist[saida]) / 2:
				salas[c].tipo = "descanso"
				break
	# spawns
	for c in salas:
		var s: Dictionary = salas[c]
		if s.tipo == "combate" or s.tipo == "saida":
			s.inimigos = 1 + andar + rng.randi_range(0, 2)
		var np := rng.randi_range(3, 6) if s.tipo != "descanso" else 1
		for i in np:
			var r := rng.randf()
			s.props.append({"tipo": "caixote" if r < 0.45 else ("urna" if r < 0.8 else "rocha"),
				"pos": Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-3.2, 3.2))})
	return {"salas": salas, "arestas": arestas, "inicio": Vector2i.ZERO, "saida": saida, "semente": semente, "andar": andar}

static func _tem_aresta(arestas: Array, a: Vector2i, b: Vector2i) -> bool:
	for e in arestas:
		if (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a):
			return true
	return false

static func _bfs(salas: Dictionary, ini: Vector2i) -> Dictionary:
	var dist := {ini: 0}
	var fila: Array = [ini]
	while not fila.is_empty():
		var c: Vector2i = fila.pop_front()
		for d in salas[c].portas:
			var n: Vector2i = c + d
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				fila.append(n)
	return dist

## conectividade: todas as salas alcancaveis a partir do inicio
static func conexo(m: Dictionary) -> bool:
	return _bfs(m.salas, m.inicio).size() == m.salas.size()
