extends RefCounted
## Estado da incursão atual na masmorra (variáveis estáticas: sobrevivem à troca de cena,
## sem autoload). PROPOSTA - quando houver save/estado global, copie estes campos para lá.
##
## Semente: aleatória por incursão (iniciar()); fixa com DUNGEON_SEMENTE=<n> no ambiente ou
## iniciar(..., semente) nos testes. Cada andar usa semente_do_andar(andar) (determinística).

const Registro = preload("res://scripts/mundo/registro_areas.gd")
const TEMAS := "res://data/dungeon/temas.json"

static var ativa := false
static var tema := ""
static var andar := 1
static var origem_area := ""          # cidade para onde voltam todas as saídas
static var origem_ponto := ""         # id do ponto de chegada na cidade (frente da entrada)
static var semente_run := 0
static var semente_fixa := false
static var profundidade := {}         # tema -> andar mais fundo alcançado
static var chefes_derrotados := {}    # tema -> true
## inventário no formato da forja: {"itens": {id: qtd}}  (scripts/forja/forja.gd: Forja.qtd)
static var inventario := {"itens": {}}
static var picareta := "picareta_cronostio"   # nível 6: minera tudo até cronóstio
static var hp_jogador := -1
static var _temas: Dictionary = {}

static func temas() -> Dictionary:
	if _temas.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(TEMAS))
		_temas = d if d is Dictionary else {}
	return _temas

static func dados_tema(t: String) -> Dictionary:
	return temas().get("temas", {}).get(t, {})

static func dados_inimigo(id: String) -> Dictionary:
	return temas().get("inimigos", {}).get(id, {})

static func iniciar(t: String, area_origem: String, ponto_origem: String, andar_inicial := 1, semente := -1) -> void:
	ativa = true
	tema = t
	andar = andar_inicial
	origem_area = area_origem
	origem_ponto = ponto_origem
	hp_jogador = -1
	if semente >= 0:
		semente_run = semente
		semente_fixa = true
	elif OS.get_environment("DUNGEON_SEMENTE") != "":
		semente_run = int(OS.get_environment("DUNGEON_SEMENTE"))
		semente_fixa = true
	else:
		var r := RandomNumberGenerator.new()
		r.randomize()
		semente_run = r.randi() % 1000000
		semente_fixa = false
	marcar_profundidade(t, andar_inicial)

## Garante uma sessão quando a cena da masmorra é aberta sozinha (F6 no editor).
static func garantir(t: String, andar_padrao := 1) -> void:
	if ativa and tema == t:
		return
	var d := dados_tema(t)
	var origem := Registro.origem_de(t)
	iniciar(t, String(origem.get("area", d.get("origem_padrao", ""))), String(origem.get("ponto", "")), andar_padrao)

static func semente_do_andar(a: int) -> int:
	return absi(hash("%s|%d|%d" % [tema, semente_run, a])) % 2000000000

static func marcar_profundidade(t: String, a: int) -> void:
	profundidade[t] = maxi(int(profundidade.get(t, 0)), a)

static func profundidade_de(t: String) -> int:
	return int(profundidade.get(t, 0))

## lista de andares do tema como inteiros (o JSON devolve floats)
static func andares(t: String) -> Array:
	var out: Array = []
	for v in dados_tema(t).get("andares", []):
		out.append(int(v))
	return out

static func proximo_andar(t: String, a: int) -> int:
	var lista: Array = andares(t)
	var i := lista.find(a)
	if i < 0 or i + 1 >= lista.size():
		return -1
	return int(lista[i + 1])

static func dar(id: String, qtd: int) -> void:
	if not inventario.has("itens"):
		inventario["itens"] = {}
	inventario.itens[id] = int(inventario.itens.get(id, 0)) + qtd

static func qtd(id: String) -> int:
	return int(inventario.get("itens", {}).get(id, 0))

static func encerrar() -> void:
	ativa = false
