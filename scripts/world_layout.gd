extends RefCounted
## Geometria deterministica: nucleo seguro fixo, costa e detalhes por seed.
const RADIUS := 25

static func generate(world_seed: int) -> Array[Vector2i]:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.12
	var cells: Array[Vector2i] = []
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var point := Vector2i(x, z)
			# Um disco central garante fazenda/vila/arena e caminhos conectados.
			if Vector2(point).length() < 9.0 or Vector2(point).length() < 22.0 + noise.get_noise_2d(x, z) * 2.5:
				cells.append(point)
	# Ruido pode deixar uma celula diagonal isolada na costa; guardar so o continente.
	var available := {}
	for cell in cells:
		available[cell] = true
	var visited := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if available.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	var connected: Array[Vector2i] = []
	for cell in cells:
		if visited.has(cell):
			connected.append(cell)
	return connected
