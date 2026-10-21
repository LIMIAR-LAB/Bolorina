extends Node
## Bolorina 21/10: gerenciador de musica (autoload "Musica").
## Escolhe a trilha sozinho olhando a cena atual, sem mexer nos sistemas do jogo:
##  - inicio.tscn (menu inicial) -> "titulo"
##  - jogo_ilha (tem "nome" da area) -> data/musica.json: areas[id] / categorias[categoria] / "exploracao"
##  - combat_arena.tscn, dungeon_teste.tscn soltos -> "batalha"
## Crossfade entre dois AudioStreamPlayer no barramento "Musica" (envia para o Master, que ja segue
## o volume geral das Configuracoes). Pausa: abaixa um pouco o volume em vez de parar.
## Outras cenas podem forcar: Musica.forcar("batalha") / Musica.liberar().
const DADOS := "res://data/musica.json"
const BUS := "Musica"
var dados := {}
var trilha := ""
var forcada := ""
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _ativo: AudioStreamPlayer
var _cache := {}
var _relogio := 0.0
var _tw: Tween
var desligada := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dados = carregar_dados()
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, "Master")
	_a = _player("MusicaA")
	_b = _player("MusicaB")
	_ativo = _a
	# testes headless e capturas nao precisam de musica
	desligada = OS.get_environment("ILHA_SEM_MUSICA") == "1"

func _player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = BUS
	p.volume_db = -80.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

static func carregar_dados() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DADOS)) if FileAccess.file_exists(DADOS) else null
	return d if d is Dictionary else {"trilhas": {}}

## trilha que combina com a cena (puro: usado pelo teste)
static func trilha_para(d: Dictionary, cena: Node) -> String:
	if cena == null:
		return ""
	var cenas: Dictionary = d.get("cenas", {})
	if cenas.has(cena.scene_file_path) and cena.get("nome") == null:
		return String(cenas[cena.scene_file_path])
	var s = cena.get_script()
	if s != null and String(s.resource_path).ends_with("inicio/menu_inicial.gd"):
		return "titulo"
	var area = cena.get("nome")
	if area is String and area != "":
		return trilha_da_area(d, area)
	if cenas.has(cena.scene_file_path):
		return String(cenas[cena.scene_file_path])
	return "exploracao"

static func trilha_da_area(d: Dictionary, area: String) -> String:
	var areas: Dictionary = d.get("areas", {})
	if areas.has(area):
		return String(areas[area])
	var Reg = load("res://scripts/mundo/registro_areas.gd")
	var cat := String(Reg.categoria(area)) if Reg.existe(area) else ""
	var cats: Dictionary = d.get("categorias", {})
	if cats.has(cat):
		return String(cats[cat])
	return "exploracao"

func forcar(id: String) -> void:
	forcada = id
	tocar(id)

func liberar() -> void:
	forcada = ""

func _process(delta: float) -> void:
	_relogio += delta
	if _relogio < 0.25:
		return
	_relogio = 0.0
	var alvo := forcada if forcada != "" else trilha_para(dados, get_tree().current_scene)
	if alvo != "" and alvo != trilha:
		tocar(alvo)
	# pausa: abaixa a musica
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), -6.0 if get_tree().paused else 0.0)

func stream(id: String) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := String(dados.get("trilhas", {}).get(id, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	_cache[id] = s
	return s

func tocar(id: String) -> void:
	trilha = id
	if desligada:
		return
	var s := stream(id)
	var novo := _b if _ativo == _a else _a
	var velho := _ativo
	var t := float(dados.get("crossfade_s", 2.0))
	var vol := float(dados.get("volume_db", {}).get(id, -8.0))
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	if s:
		novo.stream = s
		novo.volume_db = -40.0
		novo.play()
		_tw.tween_property(novo, "volume_db", vol, t).set_trans(Tween.TRANS_SINE)
		_ativo = novo
	_tw.tween_property(velho, "volume_db", -80.0, t).set_trans(Tween.TRANS_SINE)
	_tw.chain().tween_callback(velho.stop)
