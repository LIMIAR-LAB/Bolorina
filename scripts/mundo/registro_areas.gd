extends RefCounted
## Registro unico das areas do jogo (data/areas.json). Mapa-mundi pintado, teleporte (jogo_ilha.gd), pedras de viagem,
## pontos de viagem, entradas de masmorra e as masmorras leem daqui.
## Area nova: uma entrada no JSON (id, nome, cena, chegada, mapa, raio...). Se a cena ainda nao existe,
## a area aparece no mapa como "em breve" e o teleporte fica desligado.
## Integracao 20/10: API do Claude (lista, info, cena, disponivel, chegada...) + API da Bolorina (area, ponto,
## entradas_de_masmorra, origem_de, chegada_pendente, viajar, validar). viajar() usa o gerenciador do jogo
## (jogo_ilha.gd, grupo "jogo_ilha") quando ele existe; sem ele (cena rodando sozinha) troca de cena.
const ARQUIVO := "res://data/areas.json"
static var _dados := {}
## chegada pendente depois de uma viagem: {"area": id, "ponto": id_do_ponto} (a cena de destino consome)
static var chegada_pendente: Dictionary = {}
## ultima viagem feita (para testes/depuracao)
static var ultima_viagem: Dictionary = {}

static func dados() -> Dictionary:
	if _dados.is_empty():
		var txt := FileAccess.get_file_as_string(ARQUIVO)
		var d = JSON.parse_string(txt) if txt != "" else null
		_dados = d if d is Dictionary else {"areas": []}
	return _dados

static func carregar(forcar := false) -> Dictionary:
	if forcar:
		_dados = {}
	return dados()

static func recarregar() -> void:
	_dados = {}

## lista de areas na ordem do JSON ("oculto": true = so para testes, fora do mapa)
static func lista(incluir_ocultos := false) -> Array:
	var out: Array = []
	for a in dados().get("areas", []):
		if incluir_ocultos or not bool(a.get("oculto", false)):
			out.append(a)
	return out

## todas as areas visiveis (nome da API da Bolorina)
static func areas() -> Array:
	return lista()

static func ids() -> Array:
	var out: Array = []
	for a in lista():
		out.append(String(a.id))
	return out

static func info(id: String) -> Dictionary:
	for a in lista(true):
		if String(a.id) == id:
			return a
	# ids antigos (minas_cinza, ilha_futurista) continuam funcionando
	for a in lista(true):
		if String(a.get("id_antigo", "")) == id:
			return a
	return {}

static func area(id: String) -> Dictionary:
	return info(id)

static func existe(id: String) -> bool:
	return not info(id).is_empty()

## a cena da area existe no projeto (pode teleportar)?
static func disponivel(id: String) -> bool:
	return cena(id) != ""

## cena que o jogo carrega: a oficial (mapa da Bolorina) ou, se ainda nao existe, a "cena_provisoria"
static func cena(id: String) -> String:
	var a := info(id)
	for k in ["cena", "cena_provisoria"]:
		if a.get(k) != null and ResourceLoader.exists(String(a.get(k))):
			return String(a.get(k))
	return ""

static func nome(id: String) -> String:
	return String(info(id).get("nome", id.capitalize()))

static func chegada(id: String) -> String:
	return String(info(id).get("chegada", "inicio"))

static func arte(id: String) -> String:
	return String(info(id).get("arte", ""))

static func categoria(id: String) -> String:
	return String(info(id).get("categoria", info(id).get("tipo", "")))

static func disponiveis() -> Array:
	var out: Array = []
	for a in lista():
		if disponivel(String(a.id)):
			out.append(String(a.id))
	return out

static func cidades() -> Array:
	return lista().filter(func(a): return String(a.get("categoria", "")) == "cidade")

static func masmorras() -> Array:
	return lista().filter(func(a): return String(a.get("categoria", "")) == "masmorra")

static func eh_masmorra(id: String) -> bool:
	return categoria(id) == "masmorra"

static func ponto(id: String, ponto_id: String) -> Dictionary:
	for p in info(id).get("pontos_de_entrada", []):
		if String(p.id) == ponto_id:
			return p
	return {}

static func entradas_de_masmorra(id: String) -> Array:
	return info(id).get("entradas_de_masmorra", [])

static func entrada_de_masmorra(id: String, entrada_id: String) -> Dictionary:
	for e in entradas_de_masmorra(id):
		if String(e.id) == entrada_id:
			return e
	return {}

## Cidade e entrada que levam a uma masmorra por um ponto (ex.: minas_da_cinza/tuneis_de_brasa -> vila_orcs/boca_da_caverna)
static func origem_de(masmorra_id: String, ponto_id := "") -> Dictionary:
	for c in cidades():
		for e in c.get("entradas_de_masmorra", []):
			if String(e.area) == masmorra_id and (ponto_id == "" or String(e.ponto) == ponto_id):
				return {"area": String(c.id), "ponto": String(e.id)}
	return {}

# ------------------------------------------------------------------ regras de liberacao (mapa-mundi)
## "" = pode viajar; senao, o motivo. requer = item (mapas do cartografo); requer_visita = area ja visitada.
static func bloqueio(id: String, estado) -> String:
	# Temporario para validar as regioes; false no JSON restaura a progressao.
	if bool(dados().get("viagens_livres", false)):
		return ""
	var a := info(id)
	var req := String(a.get("requer", ""))
	if req != "" and estado != null and estado.has_method("qtd") and estado.qtd(req) <= 0:
		return "Para viajar até %s, compre o mapa com o Tobias, o cartógrafo de Porto Velho." % nome(id)
	var vis := String(a.get("requer_visita", ""))
	if vis != "" and not visitou(estado, vis):
		return "%s só abre depois que a Vale visitar %s." % [nome(id), nome(vis)]
	return ""

static func visitou(estado, id: String) -> bool:
	if estado == null or not ("extras" in estado):
		return true
	return bool((estado.extras.get("areas_visitadas", {}) as Dictionary).get(id, false))

static func marcar_visita(estado, id: String) -> void:
	if estado == null or not ("extras" in estado) or id == "":
		return
	var v: Dictionary = estado.extras.get("areas_visitadas", {})
	v[id] = true
	estado.extras["areas_visitadas"] = v

# ------------------------------------------------------------------ viagem
## gerenciador do jogo (jogo_ilha.gd) se estiver rodando
static func gerenciador(tree: SceneTree) -> Node:
	if tree == null:
		return null
	return tree.get_first_node_in_group("jogo_ilha")

## sessao da masmorra ao entrar por viagem (mapa ou entrada); encerra ao sair de uma masmorra
static func preparar_viagem(de: String, id: String, ponto_id: String) -> void:
	var Sessao = load("res://scripts/dungeon/sessao_masmorra.gd")
	if eh_masmorra(de) and de != id:
		Sessao.encerrar()
	if eh_masmorra(id) and not (Sessao.ativa and Sessao.tema == String(info(id).get("tema", id))):
		var tema := String(info(id).get("tema", id))
		var ori := origem_de(id, ponto_id)
		if ori.is_empty():
			ori = origem_de(id)
		var andar := int(ponto(id, ponto_id).get("andar", 1))
		Sessao.iniciar(tema, String(ori.get("area", "")), String(ori.get("ponto", "")), andar)

## Viaja para a area (ponto de chegada pendente para a cena de destino). Com o jogo rodando: gerenciador.ir();
## sem ele: troca de cena (cenas soltas e testes antigos).
static func viajar(tree: SceneTree, id: String, ponto_id := "") -> int:
	var caminho := cena(id)
	if caminho == "":
		push_error("registro_areas: área sem cena: %s" % id)
		return ERR_DOES_NOT_EXIST
	var a := info(id)
	id = String(a.id)
	chegada_pendente = {"area": id, "ponto": ponto_id}
	ultima_viagem = {"area": id, "ponto": ponto_id, "cena": caminho, "msec": Time.get_ticks_msec()}
	var g := gerenciador(tree)
	if g != null:
		if String(g.nome) == id:
			g.recarregar(ponto_id if ponto_id != "" else chegada(id))
		else:
			g.ir(id, ponto_id if ponto_id != "" else chegada(id))
		return OK
	var pc: PackedScene = load(caminho)
	tree.call_deferred("change_scene_to_packed", pc)
	return OK

## A cena de destino chama isto no _ready (ou deferred): devolve a chegada se for para ela.
static func consumir_chegada(id: String) -> Dictionary:
	if String(chegada_pendente.get("area", "")) != id:
		return {}
	var c := chegada_pendente
	chegada_pendente = {}
	return c

## Checagem de consistencia (testes).
static func validar() -> Array:
	var erros: Array = []
	var vistos := {}
	for a in lista(true):
		var id := String(a.get("id", ""))
		if id == "" or vistos.has(id):
			erros.append("id vazio ou repetido: %s" % id)
		vistos[id] = true
		for k in ["nome", "cena", "chegada", "mapa", "raio"]:
			if not a.has(k):
				erros.append("%s sem campo %s" % [id, k])
		if bool(a.get("oculto", false)):
			continue
		if not a.has("pontos_de_entrada"):
			erros.append("%s sem campo pontos_de_entrada" % id)
		# "estado": "em_breve" = area planejada sem cena ainda (ex.: ilha_mare); aparece desligada no mapa
		if cena(id) == "" and String(a.get("estado", "")) != "em_breve":
			erros.append("%s: cena não existe %s" % [id, a.get("cena", "")])
		if a.has("arte") and not FileAccess.file_exists(String(a.get("arte", ""))):
			erros.append("%s: arte não existe %s" % [id, a.get("arte", "")])
		if String(a.get("categoria", "")) in ["cidade", "masmorra"] and not a.has("arte"):
			erros.append("%s sem campo arte" % id)
		var ch := String(a.get("chegada", ""))
		if a.has("pontos_de_entrada") and ponto(id, ch).is_empty():
			erros.append("%s: chegada '%s' não está em pontos_de_entrada" % [id, ch])
		for k in ["requer_visita"]:
			if a.has(k) and not existe(String(a[k])):
				erros.append("%s: %s aponta para área inexistente %s" % [id, k, a[k]])
	for a in lista(true):
		for e in a.get("entradas_de_masmorra", []):
			if not existe(String(e.area)):
				erros.append("%s/%s aponta para área inexistente %s" % [a.id, e.id, e.area])
			elif ponto(String(e.area), String(e.ponto)).is_empty():
				erros.append("%s/%s aponta para ponto inexistente %s/%s" % [a.id, e.id, e.area, e.ponto])
			if ponto(String(a.id), String(e.id)).is_empty():
				erros.append("%s: falta ponto de volta '%s'" % [a.id, e.id])
	return erros
