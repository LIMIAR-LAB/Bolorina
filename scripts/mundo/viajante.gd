extends Node
## Nó persistente na raiz da árvore (instalado por Viagem.garantir_viajante). Sobrevive às trocas
## de cena e dá a todas as áreas: tecla M (mapa das ilhas por cima do jogo, com pausa), a cortina
## de viagem com o cartão de chegada, a chegada genérica (põe a jogadora no ponto do registro) e
## marca a área como visitada. Não depende de autoload nem de mudar as cenas antigas.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Viagem = preload("res://scripts/mundo/viagem.gd")
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"

signal mapa_aberto
signal mapa_fechado
signal chegou(area: String, ponto: String)

var camada_mapa: CanvasLayer
var mapa: Control
var cortina: CanvasLayer
var _preto: ColorRect
var _cartao: Control
var _titulo: Label
var _sub: Label
var _dica: Label
var _cena_id := 0
var _frames_cena := 0
var _chegada_tratada := true
var _pausou := false
## última chegada tratada (testes): {area, ponto, pos, metodo}
var ultima_chegada: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_cortina()

# ------------------------------------------------------------------ mapa
func mapa_aberto_agora() -> bool:
	return is_instance_valid(mapa)

func abrir_mapa() -> Control:
	if is_instance_valid(mapa):
		return mapa
	var c := get_tree().current_scene
	if c and c.scene_file_path == Viagem.MAPA:
		return c   # já é a tela do mapa
	camada_mapa = CanvasLayer.new()
	camada_mapa.name = "CamadaMapa"
	camada_mapa.layer = 95
	camada_mapa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada_mapa)
	mapa = load(Viagem.MAPA).instantiate()
	mapa.modo = "sobreposicao"
	mapa.area_atual = Viagem.area_atual(get_tree())
	mapa.process_mode = Node.PROCESS_MODE_ALWAYS
	camada_mapa.add_child(mapa)
	mapa.fechar_pedido.connect(fechar_mapa)
	_pausou = not get_tree().paused
	get_tree().paused = true
	if _dica:
		_dica.visible = false
	mapa_aberto.emit()
	return mapa

func fechar_mapa() -> void:
	if is_instance_valid(camada_mapa):
		camada_mapa.queue_free()
	camada_mapa = null
	mapa = null
	if _pausou:
		get_tree().paused = false
	_pausou = false
	_atualizar_dica()
	mapa_fechado.emit()

## chamado pelo mapa depois da animação: cortina preta, troca de cena, cartão de chegada
func partir(id: String, ponto := "") -> int:
	_preto.color.a = 1.0
	_cartao.modulate.a = 0.0
	if is_instance_valid(mapa):
		fechar_mapa()
	get_tree().paused = false
	_chegada_tratada = false
	var r := Viagem.ir(get_tree(), id, ponto)
	if r != OK:
		_preto.color.a = 0.0
		_chegada_tratada = true
	return r

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_M:
		return
	if is_instance_valid(mapa):
		return   # o próprio mapa trata M/Esc
	var c := get_tree().current_scene
	if c == null or c.scene_file_path == Viagem.MAPA:
		return
	if c.get("demo_mode") == true and not get_tree().paused:
		return   # conversa/menu aberto
	get_viewport().set_input_as_handled()
	abrir_mapa()

# ------------------------------------------------------------------ chegada
func _process(_delta: float) -> void:
	var c := get_tree().current_scene
	var cid := c.get_instance_id() if c else 0
	if cid != _cena_id:
		_cena_id = cid
		_frames_cena = 0
		_atualizar_dica()
	_frames_cena += 1
	if _frames_cena == 5 and c:
		_tratar_chegada(c)

func _tratar_chegada(c: Node) -> void:
	var area := Viagem.area_atual(get_tree())
	var pend: Dictionary = Registro.chegada_pendente
	var ponto := String(pend.get("ponto", ""))
	if area != "" and String(pend.get("area", "")) == area:
		Registro.consumir_chegada(area)
		var p: Dictionary = Registro.ponto(area, ponto)
		ultima_chegada = {"area": area, "ponto": ponto, "metodo": "cena"}
		if p.has("pos"):
			var j = _jogador(c)
			if j:
				var x := float(p.pos[0])
				var z := float(p.pos[1])
				var y := _altura(c, x, z)
				j.position = Vector3(x, y + 0.3, z)
				if j is CharacterBody3D:
					j.velocity = Vector3.ZERO
				ultima_chegada.metodo = "registro"
				ultima_chegada["pos"] = j.position
	elif area != "":
		ultima_chegada = {"area": area, "ponto": "", "metodo": "propria"}
	if area != "":
		Viagem.marcar_visitada(area)
		chegou.emit(area, ponto)
	if not _chegada_tratada:
		_chegada_tratada = true
		_mostrar_cartao(area)

func _jogador(c: Node):
	for k in ["jogador", "player"]:
		var j = c.get(k)
		if j is Node3D:
			return j
	if c.get("atual") is Node:   # gerenciador da ilha
		return _jogador(c.atual)
	return null

func _altura(c: Node, x: float, z: float) -> float:
	if c.has_method("_y"):
		return float(c._y(x, z))
	var v = c.get("vila")
	if v is Object and v.has_method("altura"):
		return float(v.altura(x, z))
	var w := (c as Node3D).get_world_3d() if c is Node3D else null
	if w:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -60, z))
		var h := w.direct_space_state.intersect_ray(q)
		if h:
			return float(h.position.y)
	return 0.0

# ------------------------------------------------------------------ cortina / cartão / dica
func _montar_cortina() -> void:
	cortina = CanvasLayer.new()
	cortina.name = "Cortina"
	cortina.layer = 120
	cortina.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cortina)
	_preto = ColorRect.new()
	_preto.color = Color(0.03, 0.02, 0.05, 0.0)
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cortina.add_child(_preto)
	var fonte: Font = load(FONTE)
	_cartao = Control.new()
	_cartao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.modulate.a = 0.0
	cortina.add_child(_cartao)
	_titulo = Label.new()
	_titulo.add_theme_font_override("font", fonte)
	_titulo.add_theme_font_size_override("font_size", 58)
	_titulo.add_theme_color_override("font_color", Color("ffe2a8"))
	_titulo.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.03))
	_titulo.add_theme_constant_override("outline_size", 10)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_titulo.anchor_left = 0.0
	_titulo.anchor_right = 1.0
	_titulo.offset_top = 300
	_cartao.add_child(_titulo)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color("e8d6c0"))
	_sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03))
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.offset_top = 384
	_cartao.add_child(_sub)
	_dica = Label.new()
	_dica.text = "M · Mapa das Ilhas"
	_dica.add_theme_font_override("font", fonte)
	_dica.add_theme_font_size_override("font_size", 17)
	_dica.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.72))
	_dica.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_dica.add_theme_constant_override("outline_size", 5)
	_dica.anchor_left = 1.0
	_dica.anchor_right = 1.0
	_dica.anchor_top = 1.0
	_dica.anchor_bottom = 1.0
	_dica.offset_left = -230
	_dica.offset_top = -36
	_dica.offset_right = -18
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dica.visible = false
	var camada_dica := CanvasLayer.new()
	camada_dica.layer = 60
	add_child(camada_dica)
	camada_dica.add_child(_dica)

func _atualizar_dica() -> void:
	if _dica:
		_dica.visible = Viagem.area_atual(get_tree()) != "" and not is_instance_valid(mapa)

func _mostrar_cartao(area: String) -> void:
	_titulo.text = Registro.nome(area) if area != "" else ""
	var a := Registro.area(area)
	_sub.text = String(a.get("regiao", ""))
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if area != "":
		tw.tween_property(_cartao, "modulate:a", 1.0, 0.25)
		tw.tween_interval(0.35)
	tw.tween_property(_preto, "color:a", 0.0, 0.55)
	if area != "":
		tw.tween_interval(0.6)
		tw.tween_property(_cartao, "modulate:a", 0.0, 0.6)
