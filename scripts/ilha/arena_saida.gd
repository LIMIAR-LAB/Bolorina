extends Node
## Ponte arena -> vila: B ou ESC / PORTAO OESTE (faixa de grama, fora do combate) -> vila.
## A porta do fundo da arena leva a PROXIMA SALA (arena_combate.gd) — ela nunca levou de volta a vila:
## a checagem antiga daqui competia com a da arena (raio 1,4 m em z+1,2) e perdia sempre.
const Caminhos = preload("res://scripts/ilha/caminhos_ilha.gd")
var gerenciador
var arena
var player            # = arena.jogador (lido por saidas_area.gd)
var saidas_novas
var t := 0.0
var placar: Label

func montar(g, a) -> void:
	gerenciador = g
	arena = a
	player = a.jogador
	var camada := CanvasLayer.new()
	camada.layer = 55
	add_child(camada)
	placar = Label.new()
	placar.position = Vector2(24, 176)
	placar.add_theme_font_size_override("font_size", 14)
	placar.add_theme_color_override("font_color", Color("f1e2bd"))
	placar.add_theme_color_override("font_shadow_color", Color.BLACK)
	placar.text = "B / ESC: voltar à vila  |  portão oeste (←) abre quando a sala está limpa  |  porta do fundo: próxima sala"
	camada.add_child(placar)
	saidas_novas = Caminhos.arena(self, a)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode in [KEY_B, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		gerenciador.ir("vila", "da_arena")

func _process(delta: float) -> void:
	t += delta
	if arena and arena.jogador:
		player = arena.jogador
