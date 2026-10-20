extends Node
## Executor do tutorial (PROPOSTA). Independente de cena: lê data/tutorial/tutorial.json,
## escuta as marcas de estado_dialogos.gd e recebe eventos do jogo por notificar().
## Cada passo: espera o "gatilho", mostra a "dica", espera a "conclusao". Tudo pode ser pulado.
##
## Ganchos:
##   iniciar()                         começa (o jogo também manda notificar("jogo_iniciado"))
##   notificar(evento, alvo, qtd)      "perto_de", "golpe_acertou", "golpe_pesado", "esquivou", "forja_aberta",
##                                     "forja_reforco_feito", "eco_acertou", "jogo_salvo", "mapa_aberto", "teleportou"...
##   pular_passo() / pular_tudo()
##   dica_atual() -> String            texto para a faixa de dica na tela
##   dialogo_para(npc_id) -> Dictionary  usado pelo seletor de diálogos (passo "conversar" com o Pipo)

signal passo_iniciado(passo_id: String, dica: String)
signal passo_concluido(passo_id: String)
signal passo_pulado(passo_id: String)
signal dica_alterada(texto: String)
signal dialogo_pedido(npc_id: String, arquivo: String, cue: String)
signal tutorial_concluido(pulado: bool)

const Cond = preload("res://scripts/missoes/condicoes.gd")
const PADRAO := "res://data/tutorial/tutorial.json"

var estado = null
var dados: Dictionary = {}
var passos: Array = []
var indice := 0
var fase := "parado"          # parado | aguardando | ativo | fim
var contadores: Dictionary = {}
var concluidos: Array = []
var pulados: Array = []
var foi_pulado := false
var _avaliando := false

func _init(estado_inicial = null, caminho := PADRAO) -> void:
	estado = estado_inicial if estado_inicial != null else load("res://scripts/dialogos/estado_dialogos.gd").global()
	estado.evento.connect(_ao_evento_estado)
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	dados = d if d is Dictionary else {}
	passos = dados.get("passos", [])

func iniciar() -> void:
	if fase != "parado":
		return
	indice = 0
	fase = "aguardando"
	if estado.tem(String(dados.get("marca_pulado", "tutorial_pulado"))):
		pular_tudo()
		return
	_avaliar()

func terminou() -> bool:
	return fase == "fim"

func passo_atual() -> Dictionary:
	return passos[indice] if indice < passos.size() and fase in ["aguardando", "ativo"] else {}

func dica_atual() -> String:
	return String(passo_atual().get("dica", "")) if fase == "ativo" else ""

func dialogo_para(npc_id: String) -> Dictionary:
	var p := passo_atual()
	if fase != "ativo" or p.is_empty():
		return {}
	var d: Dictionary = p.get("dialogo", {})
	if not d.is_empty() and String(d.get("npc", "")) == npc_id and bool(d.get("ao_apertar_e", false)):
		return {"arquivo": String(d.arquivo), "cue": String(d.cue), "origem": "tutorial", "de": String(p.id)}
	return {}

func notificar(evento: String, alvo: String = "", quantidade: int = 1) -> void:
	if fase == "parado" and evento == "jogo_iniciado":
		iniciar()
	var p := passo_atual()
	if p.is_empty():
		return
	var pid := String(p.id)
	if fase == "aguardando":
		Cond.contar([p.get("gatilho", {"tipo": "imediato"})], evento, alvo, quantidade, contadores, pid + "/g")
	elif fase == "ativo":
		Cond.contar(p.get("conclusao", []), evento, alvo, quantidade, contadores, pid + "/c")
	_avaliar()

func _ao_evento_estado(nome: String, valor) -> void:
	if nome != "marca" or fase == "fim" or fase == "parado":
		return
	if String(valor) == String(dados.get("marca_pulado", "tutorial_pulado")):
		pular_tudo()
	else:
		_avaliar()

func _avaliar() -> void:
	if _avaliando:
		return
	_avaliando = true
	var voltas := 0
	while fase in ["aguardando", "ativo"] and voltas < 50:
		voltas += 1
		var p := passo_atual()
		if p.is_empty():
			break
		var pid := String(p.id)
		if fase == "aguardando":
			if Cond.ok([p.get("gatilho", {"tipo": "imediato"})], estado, contadores, {}, pid + "/g"):
				_ativar(p)
				continue
			break
		if Cond.ok(p.get("conclusao", []), estado, contadores, {}, pid + "/c"):
			_concluir(p, false)
			continue
		break
	_avaliando = false

func _ativar(p: Dictionary) -> void:
	fase = "ativo"
	passo_iniciado.emit(String(p.id), String(p.get("dica", "")))
	dica_alterada.emit(String(p.get("dica", "")))
	var d: Dictionary = p.get("dialogo", {})
	if not d.is_empty() and not bool(d.get("ao_apertar_e", false)) and not bool(d.get("ao_abrir_forja", false)):
		dialogo_pedido.emit(String(d.get("npc", "")), String(d.arquivo), String(d.cue))

func _concluir(p: Dictionary, pulou: bool) -> void:
	var pid := String(p.id)
	if pulou:
		pulados.append(pid)
		passo_pulado.emit(pid)
	else:
		concluidos.append(pid)
		passo_concluido.emit(pid)
		var d: Dictionary = p.get("dialogo_ao_concluir", {})
		if not d.is_empty():
			dialogo_pedido.emit(String(d.get("npc", "")), String(d.arquivo), String(d.cue))
	for mk in p.get("marcas_ao_concluir", []):
		if not estado.tem(String(mk)):
			estado.marcar(String(mk))
	dica_alterada.emit("")
	indice += 1
	if indice >= passos.size():
		_fim(false)
	else:
		fase = "aguardando"

func pular_passo() -> void:
	var p := passo_atual()
	if p.is_empty():
		return
	_concluir(p, true)
	_avaliar()

func pular_tudo() -> void:
	if fase == "fim":
		return
	foi_pulado = true
	var mp := String(dados.get("marca_pulado", "tutorial_pulado"))
	fase = "fim"   # trava antes de marcar, para não reentrar
	if not estado.tem(mp):
		estado.marcar(mp)
	for i in range(indice, passos.size()):
		pulados.append(String(passos[i].id))
		for mk in passos[i].get("marcas_ao_concluir", []):
			if not estado.tem(String(mk)):
				estado.marcar(String(mk))
	indice = passos.size()
	_fim(true)

func _fim(pulou: bool) -> void:
	fase = "fim"
	var mc := String(dados.get("marca_concluido", "tutorial_concluido"))
	if not estado.tem(mc):
		estado.marcar(mc)
	dica_alterada.emit("")
	tutorial_concluido.emit(pulou or foi_pulado)

func serializar() -> Dictionary:
	return {"indice": indice, "fase": fase, "contadores": contadores.duplicate(), "concluidos": concluidos.duplicate(), "pulados": pulados.duplicate(), "foi_pulado": foi_pulado}

func desserializar(d: Dictionary) -> void:
	indice = int(d.get("indice", 0))
	fase = String(d.get("fase", "parado"))
	contadores = d.get("contadores", {})
	concluidos = d.get("concluidos", [])
	pulados = d.get("pulados", [])
	foi_pulado = bool(d.get("foi_pulado", false))
