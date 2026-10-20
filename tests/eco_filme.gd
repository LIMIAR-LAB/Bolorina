extends SceneTree
## Clipe do protótipo do eco (Movie Maker): o piloto automático mostra Eco, Eco rápido, Eco pesado
## (quebra a guarda do Escudeiro) e abre as 3 travas do Bate-Estaca. Rodar com --write-movie.
## ECO_QUADROS=pasta salva também alguns quadros-chave em PNG.
var a
var tempo := 0.0
var pasta := ""
var marcas: Array = []
var _feitas := 0
const FPS := 30.0
var _fim_em := -1.0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	pasta = OS.get_environment("ECO_QUADROS")
	a = load("res://scenes/prototipos/eco/arena_eco.tscn").instantiate()
	a.demo = true
	root.add_child(a)

func _process(delta: float) -> bool:
	if a == null:
		return false
	tempo += 1.0 / FPS     # Movie Maker roda com --fixed-fps 30: 1 quadro = 1/30 s de vídeo
	if a.demo_fim and _fim_em < 0.0:
		_fim_em = tempo + 1.0
	if pasta != "" and _feitas < marcas.size() and tempo >= marcas[_feitas]:
		var img := root.get_texture().get_image()
		img.save_png(pasta.path_join("eco_%02d.png" % (_feitas + 1)))
		_feitas += 1
	if tempo > 45.0 or (_fim_em > 0.0 and tempo >= _fim_em):
		Engine.time_scale = 1.0
		print("FILME fim t=%.2f passo=%d stats=%s" % [tempo, a.passo_i, str(a.stats)])
		quit()
		return true
	return false
