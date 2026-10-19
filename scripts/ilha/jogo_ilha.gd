extends Node
## Gerenciador das 3 areas: Fazenda <-> Vila <-> Arena. Fade + spawns.
## Debug: F10 vila | F11 arena | F12 fazenda. Save: user://ilha_fazenda_v1.json.
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const FAZENDA := "res://scripts/ilha/fazenda.tscn"
const VILA := "res://scripts/ilha/vila_jogo.tscn"
const ARENA := "res://combat_arena.tscn"
const FADE := 0.35
var estado
var atual: Node
var nome := ""
var ocupado := false
var fade: ColorRect

func _ready() -> void:
	estado = Estado.new()
	estado.carregar()
	var camada := CanvasLayer.new()
	camada.layer = 80
	add_child(camada)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.015, 0.03, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fade)
	DisplayServer.window_set_title("Ilha das Cinzas | Fazenda, Vila e Combate")
	var area: String = OS.get_environment("ILHA_AREA")
	var spawn: String = OS.get_environment("ILHA_SPAWN")
	await _trocar(area if area != "" else "fazenda", spawn if spawn != "" else "inicio", false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or ocupado:
		return
	match event.physical_keycode:
		KEY_F10:
			ir("vila", "da_fazenda" if nome == "fazenda" else "da_arena")
		KEY_F11:
			ir("arena", "da_vila")
		KEY_F12:
			ir("fazenda", "da_vila" if nome == "vila" else "inicio")

func ir(area: String, spawn: String) -> void:
	if ocupado or area == nome:
		return
	ocupado = true  # sincroniza antes do 1o await do _trocar
	_trocar(area, spawn, true)

func _trocar(area: String, spawn: String, com_fade: bool) -> void:
	ocupado = true
	estado.area = area
	estado.salvar()
	if com_fade:
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, FADE)
		await tw.finished
	if atual:
		atual.queue_free()
		atual = null
		await get_tree().process_frame
		await get_tree().process_frame
	Engine.time_scale = 1.0
	nome = area
	match area:
		"fazenda":
			atual = load(FAZENDA).instantiate()
			atual.estado = estado
			atual.gerenciador = self
			add_child(atual)
			await get_tree().process_frame
			if atual.has_method("nascer"):
				atual.nascer(spawn)
		"vila":
			atual = load(VILA).instantiate()
			atual.estado = estado
			atual.gerenciador = self
			add_child(atual)
			await get_tree().process_frame
			if atual.has_method("nascer"):
				atual.nascer(spawn)
		"arena":
			atual = load(ARENA).instantiate()
			add_child(atual)
			await get_tree().process_frame
			var s := Node.new()
			s.name = "SaidaIlha"
			s.set_script(load("res://scripts/ilha/arena_saida.gd"))
			atual.add_child(s)
			s.montar(self, atual)
		_:
			push_error("Area desconhecida: " + area)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, FADE * (1.5 if not com_fade else 1.0))
	await tw2.finished
	ocupado = false
