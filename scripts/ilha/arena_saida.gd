extends Node
## Ponte arena -> vila: B ou ESC (fora de combate intenso) / placa no canto sul.
## A porta oficial da arena (apos limpar salas) tambem dispara a volta.
var gerenciador
var arena
var t := 0.0
var placar: Label

func montar(g, a) -> void:
	gerenciador = g
	arena = a
	var camada := CanvasLayer.new()
	camada.layer = 55
	add_child(camada)
	placar = Label.new()
	placar.position = Vector2(24, 120)
	placar.add_theme_font_size_override("font_size", 14)
	placar.add_theme_color_override("font_color", Color("f1e2bd"))
	placar.add_theme_color_override("font_shadow_color", Color.BLACK)
	placar.text = "B / ESC: voltar a vila  |  limpe a sala e atravesse a porta"
	camada.add_child(placar)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode in [KEY_B, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		gerenciador.ir("vila", "da_arena")

func _process(delta: float) -> void:
	t += delta
	# se a porta estiver ativa e o jogador atravessar, volta
	if arena.porta and arena.estado_sala in ["porta", "limpa", "recompensa"] and arena.jogador:
		var p: Vector3 = arena.jogador.position
		var q: Vector3 = arena.porta.position
		if Vector2(p.x - q.x, p.z - q.z).length() < 1.4 and t > 2.0:
			gerenciador.ir("vila", "da_arena")
