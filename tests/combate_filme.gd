extends SceneTree
## Clipe de jogabilidade (Movie Maker): o piloto automatico joga a sala 1 inteira
## (2 ondas, combo, dash, especial, quebraveis, bencao e porta). Rodar com --write-movie.
var a
var tempo := 0.0
var legenda: Label
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	a = load("res://combat_arena.tscn").instantiate()
	root.add_child(a)
	a.piloto = true
	a.dicas.text = "Prototipo de combate (Hades-like) | piloto automatico: combo 3 golpes, dash com i-frames, especial, forma Adamantium + Raio de Adamantium, quebraveis"

func _process(delta: float) -> bool:
	if a == null:
		return false
	tempo += delta / maxf(Engine.time_scale, 0.001)
	if tempo > 45.0 or (a.estado_sala == "inicio" and a.sala == 2 and a.t_sala > 1.5):
		Engine.time_scale = 1.0
		quit()
		return true
	return false
