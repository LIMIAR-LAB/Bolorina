extends RefCounted
## Eco temporal (PROPOSTA). Lógica pura, sem nós: o golpe pesado marca um ponto no chão e, depois do
## atraso da variação, o tempo repete o golpe ali. Testável headless (tests/eco_testes.gd).
##
## Variações vêm de data/missoes/atrasada_desde_amanha.json ("variacoes_eco"), a mesma tabela da missão:
##   eco_base    0,6 s   60%   raio 1,6 m
##   eco_rapido  0,35 s  45%   raio 1,6 m   acerto do eco tira 0,1 s da recarga do dash
##   eco_pesado  0,9 s  100%   raio 2,2 m   quebra a guarda (conta como golpe pesado)
##
## Uso:
##   var eco = EcoTemporal.new()
##   eco.registrar(golpe, agora)   # golpe = dicionário do sinal golpe de jogador_combate.gd
##   for e in eco.atualizar(agora): aplicar dano em e.centro / e.raio
signal eco_marcado(eco: Dictionary)
signal eco_disparou(eco: Dictionary)
signal variacao_mudou(variacao_id: String, dados: Dictionary)

const MISSAO := "res://data/missoes/atrasada_desde_amanha.json"
const ORDEM := ["eco_base", "eco_rapido", "eco_pesado"]
const BONUS_DASH_RAPIDO := 0.1
const AVANCO_CENTRO := 0.55     # o ponto do eco fica a 55% do alcance do golpe, na frente da Vale

var variacoes: Dictionary = {}
var atual := "eco_base"
var pendentes: Array = []
var disparados := 0
var _seq := 0

func _init(caminho := MISSAO) -> void:
	var txt := FileAccess.get_file_as_string(caminho)
	var d = JSON.parse_string(txt) if txt != "" else null
	if d is Dictionary:
		variacoes = d.get("variacoes_eco", {})
	if variacoes.is_empty():
		variacoes = {"eco_base": {"nome": "Eco", "atraso_s": 0.6, "dano_relativo": 0.6, "raio_m": 1.6}}

func definir(vid: String) -> bool:
	if not variacoes.has(vid):
		return false
	atual = vid
	variacao_mudou.emit(vid, variacoes[vid])
	return true

func dados(vid := "") -> Dictionary:
	return variacoes.get(atual if vid == "" else vid, {})

func nome(vid := "") -> String:
	return String(dados(vid).get("nome", vid))

func atraso(vid := "") -> float:
	return float(dados(vid).get("atraso_s", 0.6))

func dano_relativo(vid := "") -> float:
	return float(dados(vid).get("dano_relativo", 0.6))

func raio(vid := "") -> float:
	return float(dados(vid).get("raio_m", 1.6))

func quebra_guarda(vid := "") -> bool:
	return (atual if vid == "" else vid) == "eco_pesado"

func bonus_dash(vid := "") -> float:
	return BONUS_DASH_RAPIDO if (atual if vid == "" else vid) == "eco_rapido" else 0.0

## Golpes que deixam eco: o 3º do combo (pesado) ou um golpe com "eco": true.
static func deixa_eco(golpe: Dictionary) -> bool:
	if bool(golpe.get("e_eco", false)):
		return false
	if bool(golpe.get("eco", false)):
		return true
	return String(golpe.get("tipo", "")) == "combo" and bool(golpe.get("pesado", false))

func registrar(golpe: Dictionary, agora: float) -> Dictionary:
	if not deixa_eco(golpe):
		return {}
	var origem: Vector3 = golpe.get("origem", Vector3.ZERO)
	var dir: Vector3 = golpe.get("dir", Vector3.RIGHT)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.RIGHT
	var alcance := float(golpe.get("alcance", 2.7))
	_seq += 1
	var e := {
		"id": _seq, "variacao": atual, "nome": nome(),
		"t_marcado": agora, "t_disparo": agora + atraso(), "atraso": atraso(),
		"origem": origem, "dir": dir, "centro": origem + dir * alcance * AVANCO_CENTRO,
		"raio": raio(), "dano": maxi(1, roundi(float(golpe.get("dano", 24)) * dano_relativo())),
		"quebra_guarda": quebra_guarda(), "bonus_dash": bonus_dash(), "golpe_dano": int(golpe.get("dano", 24))}
	pendentes.append(e)
	eco_marcado.emit(e)
	return e

func atualizar(agora: float) -> Array:
	var prontos: Array = []
	var resto: Array = []
	for e in pendentes:
		if agora + 0.0001 >= float(e.t_disparo):
			prontos.append(e)
		else:
			resto.append(e)
	pendentes = resto
	for e in prontos:
		disparados += 1
		eco_disparou.emit(e)
	return prontos

static func progresso(e: Dictionary, agora: float) -> float:
	return clampf((agora - float(e.t_marcado)) / maxf(float(e.atraso), 0.001), 0.0, 1.0)

## Quem está dentro do círculo do eco (posições no chão; raio_alvo soma o tamanho do alvo).
static func dentro(e: Dictionary, pos: Vector3, raio_alvo := 0.45) -> bool:
	var c: Vector3 = e.centro
	return Vector2(pos.x - c.x, pos.z - c.z).length() <= float(e.raio) + raio_alvo

func limpar() -> void:
	pendentes.clear()
