extends RefCounted
## Estado das conversas, acessivel de dentro dos arquivos .dialogue:
##   if tem("mira_conheceu")        -> condicao
##   $> marcar("mira_conheceu")     -> mutacao
##   $> confiar("mira", 1)          -> sobe a confianca do morador
##   $> comer("Ensopado de Brasa")  -> bonus de refeicao da Estalagem
##   $> pedir_missao("guardia_ratos")
## Fica so na memoria. salvar()/carregar() usam um arquivo NOVO e separado
## (user://dialogos_estado_v1.json); o save da fazenda nao e tocado.

signal evento(nome: String, valor: Variant)

const ARQUIVO := "user://dialogos_estado_v1.json"
static var _global = null

var marcas: Dictionary = {}
var confianca: Dictionary = {}
var missoes: Array = []
var refeicao := ""
var nome_jogadora := "Vale"

static func global():
	if _global == null:
		_global = load("res://scripts/dialogos/estado_dialogos.gd").new()
	return _global

static func reiniciar_global() -> void:
	_global = null

func marcar(marca: String) -> void:
	marcas[marca] = true
	evento.emit("marca", marca)

func tem(marca: String) -> bool:
	return bool(marcas.get(marca, false))

func confiar(npc_id: String, quanto: int = 1) -> void:
	confianca[npc_id] = int(confianca.get(npc_id, 0)) + quanto
	evento.emit("confianca", {"npc": npc_id, "valor": confianca[npc_id]})

func confianca_de(npc_id: String) -> int:
	return int(confianca.get(npc_id, 0))

func comer(prato: String) -> void:
	refeicao = prato
	evento.emit("refeicao", prato)

func pedir_missao(missao: String) -> void:
	if not missao in missoes:
		missoes.append(missao)
	evento.emit("missao", missao)

func salvar() -> bool:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"marcas": marcas, "confianca": confianca, "missoes": missoes, "refeicao": refeicao}, "\t"))
	return true

func carregar() -> bool:
	if not FileAccess.file_exists(ARQUIVO):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not d is Dictionary:
		return false
	marcas = d.get("marcas", {})
	confianca = d.get("confianca", {})
	missoes = d.get("missoes", [])
	refeicao = String(d.get("refeicao", ""))
	return true
