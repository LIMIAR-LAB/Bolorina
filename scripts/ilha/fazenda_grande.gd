extends "res://scripts/ilha/fazenda_mundo.gd"
## Fazenda GRANDE (variante; a fazenda original continua igual): layout de tools/fazenda_grande.py com area jogavel
## quase o dobro, 60 celulas de canteiro ja aradas, pomar a oeste, celeiro + pasto cercado ao sul e caminho no
## sudeste ate Porto Velho (portao no fim do corredor). Entra no registro de areas como "fazenda_grande".
const Saidas = preload("res://scripts/ilha/saidas_area.gd")
const LAYOUT_GRANDE := "res://scripts/ilha/fazenda_grande_layout.json"
const CERCAS_GRANDE := "res://scripts/ilha/fazenda_grande_cercas.json"
const PORTO_SAIDA := [
	{"area": "porto_velho", "spawn": "padrao", "centro": Vector2(48.5, 18.0), "tam": Vector2(4.0, 6.0), "dir": Vector2(1, 0),
	 "rotulo": "Porto Velho", "largura_visual": 4.0, "cor": Color(0.45, 0.75, 1.0)},
]
var saida_porto

func layout_arquivo() -> String:
	return LAYOUT_GRANDE

func cercas_arquivo() -> String:
	return CERCAS_GRANDE

func _ready() -> void:
	super._ready()
	var alt := func(x: float, z: float) -> float: return vila.altura(x, z)
	var bloq := func() -> bool: return interiores != null and (interiores.ativo >= 0 or bool(interiores.get("ocupado")))
	saida_porto = Saidas.new()
	ground.add_child(saida_porto)
	saida_porto.montar(self, PORTO_SAIDA, art_world, alt, bloq)
	_canteiros_novos()
	_rotulos()
	if message:
		message.text = "Fazenda grande | pomar a oeste, celeiro e pasto ao sul, caminho do sudeste: Porto Velho | M: mapa"

## save que ja existia (fazenda original): na 1a visita a fazenda grande, ara os canteiros novos uma vez
func _canteiros_novos() -> void:
	if estado == null or bool(estado.extras.get("fazenda_grande_canteiros", false)):
		return
	for c in vila.data.fazenda.canteiro_inicial:
		var cel := Vector2i(int(c[0]), int(c[1]))
		if not estado.solo.has(estado.chave(cel)):
			if solo:
				solo.arar(cel)
			else:
				estado.arar(cel)
	estado.extras["fazenda_grande_canteiros"] = true
	estado.salvar()

func _rotulos() -> void:
	var f: Dictionary = vila.data.fazenda
	var pontos := [["Pomar", f.pomar[0]], ["Celeiro", f.celeiro], ["Pasto", [10.5, 27.0]]]
	for p in pontos:
		var c: Array = p[1]
		var l := Label3D.new()
		l.text = String(p[0])
		l.font_size = 46
		l.pixel_size = 0.006
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color("f1e2bd")
		l.position = Vector3(float(c[0]), vila.altura(float(c[0]), float(c[1])) + 3.2, float(c[1]))
		ground.add_child(l)
