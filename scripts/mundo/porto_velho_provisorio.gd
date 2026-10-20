extends "res://scripts/ilha/vila_jogo.gd"
## Porto Velho PROVISORIO: usa o cenario da vila (V7) com os 20 moradores de Porto Velho (data/npcs/porto_velho.json),
## cada um com loja/servico (scripts/economia/). Quando o mapa da Bolorina (scenes/vila_grande.tscn) chegar, o registro
## de areas passa a carregar ele, e os mesmos NPCs vao para os marcadores npc_<id> do mapa.
const NpcsArea = preload("res://scripts/economia/npcs_area.gd")
const ROSTER := "res://data/npcs/porto_velho.json"
var area_npcs

func _init() -> void:
	moradores = false

func _ready() -> void:
	super._ready()
	area_npcs = NpcsArea.new()
	add_child(area_npcs)
	area_npcs.montar(self, ROSTER)
	message.text = "Porto Velho (provisório) | E: conversar, comprar, vender e serviços | M: mapa | T na pedra: viajar"
	DisplayServer.window_set_title("Ilha das Cinzas | Porto Velho")

func _process(delta: float) -> void:
	super._process(delta)
	if area_npcs:
		area_npcs.cada_quadro(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if area_npcs and area_npcs.entrada(event):
		get_viewport().set_input_as_handled()
		return
	super._unhandled_key_input(event)
