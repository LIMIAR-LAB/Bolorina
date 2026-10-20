extends "res://scripts/ilha/jogo_ilha.gd"
## Gerenciador da Ilha do Alto (fazenda, vilarejo, arena) ligado ao mapa das ilhas (PROPOSTA).
## Mesma lógica de scripts/ilha/jogo_ilha.gd (herdado, sem editar o original): troca de área com
## fade, F10/F11/F12 e as saídas a pé. Diferenças: lê a chegada do registro
## (Registro.viajar(..., "fazenda_do_alto" | "vila_da_ilha" | "arena_das_cinzas", ponto)),
## responde area_registro() para o mapa e põe um totem de viagem em cada área.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Viagem = preload("res://scripts/mundo/viagem.gd")
const PontoViagem = preload("res://scripts/mundo/ponto_viagem.gd")
const DO_REGISTRO := {"fazenda_do_alto": "fazenda", "vila_da_ilha": "vila", "arena_das_cinzas": "arena"}
## onde fica o totem de viagem em cada área (x, z) e para onde ele olha (graus)
const TOTENS := {
	"fazenda": {"pos": Vector2(-3.0, -15.0), "ang": -40.0, "rotulo": "Totem de Viagem\nMapa das Ilhas"},
	"vila": {"pos": Vector2(-1.5, -8.0), "ang": -40.0, "rotulo": "Totem de Viagem\nMapa das Ilhas"},
	"arena": {"pos": Vector2(0.5, 0.5), "ang": 45.0, "rotulo": "Totem de Viagem\nMapa das Ilhas"},
}
var totem: Node3D

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
	Viagem.garantir_viajante(get_tree())
	var area := "fazenda"
	var spawn := "inicio"
	var c: Dictionary = Registro.chegada_pendente
	var rid := String(c.get("area", ""))
	if DO_REGISTRO.has(rid):
		Registro.consumir_chegada(rid)
		area = DO_REGISTRO[rid]
		spawn = String(Registro.ponto(rid, String(c.get("ponto", ""))).get("spawn", spawn))
	elif OS.get_environment("ILHA_AREA") != "":
		area = OS.get_environment("ILHA_AREA")
		if OS.get_environment("ILHA_SPAWN") != "":
			spawn = OS.get_environment("ILHA_SPAWN")
	await _trocar(area, spawn, false)

## id da área no registro (data/areas.json) para o mapa das ilhas
func area_registro() -> String:
	for k in DO_REGISTRO:
		if DO_REGISTRO[k] == nome:
			return k
	return ""

func _trocar(area: String, spawn: String, com_fade: bool) -> void:
	await super._trocar(area, spawn, com_fade)
	Viagem.marcar_visitada(area_registro())
	_por_totem()

func _por_totem() -> void:
	if atual == null or not TOTENS.has(nome):
		return
	var t: Dictionary = TOTENS[nome]
	totem = Node3D.new()
	totem.set_script(PontoViagem)
	totem.area_id = area_registro()
	totem.tipo = "totem"
	totem.pos_xz = t.pos
	totem.angulo = float(t.ang)
	totem.rotulo_texto = String(t.rotulo)
	atual.add_child(totem)
