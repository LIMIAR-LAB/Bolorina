extends RefCounted
## Partidas independentes; nenhum novo jogo sobrescreve um arquivo existente.
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const Aparencia = preload("res://scripts/avatar/aparencia.gd")
const CONFIG := "user://configuracoes.cfg"
static func listar() -> Array:
	var out: Array = []
	var dir := DirAccess.open("user://")
	if dir == null: return out
	for file in dir.get_files():
		if not file.ends_with(".json"): continue
		if not (file.begins_with("partida_") or file in ["ilha_fazenda_v1.json","ilha_interface_preview.json"]): continue
		var path := "user://"+file
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not d is Dictionary or int(d.get("versao",0)) != Estado.VERSAO: continue
		var extras: Dictionary = d.get("extras",{}) if d.get("extras",{}) is Dictionary else {}
		var perfil := Aparencia.normalizar(extras.get("aparencia",{}))
		out.append({"arquivo":path,"nome":perfil.nome,"fazenda":perfil.fazenda,"dia":int(d.get("dia",1)),"ouro":int(d.get("ouro",0)),"hora":FileAccess.get_modified_time(path),"area":String(extras.get("ultima_area","fazenda"))})
	out.sort_custom(func(a,b): return a.hora > b.hora)
	return out
static func criar(perfil: Dictionary) -> String:
	var path := "user://partida_%d.json" % Time.get_unix_time_from_system()
	var count := 1
	while FileAccess.file_exists(path):
		path="user://partida_%d_%d.json" % [Time.get_unix_time_from_system(),count]
		count+=1
	var state = Estado.new()
	state.arquivo=path
	state.gravar=true
	state.extras.aparencia=Aparencia.normalizar(perfil)
	state.extras.ultima_area="fazenda"
	return path if state.salvar() else ""
static func carregar_config(caminho := CONFIG) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(caminho)
	return {"volume":clampf(float(cfg.get_value("audio","volume",0.8)),0,1),"tela_cheia":bool(cfg.get_value("video","tela_cheia",false)),"vsync":bool(cfg.get_value("video","vsync",true))}
static func aplicar_config(d: Dictionary, salvar := true, caminho := CONFIG) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,float(d.volume))))
	AudioServer.set_bus_mute(0,float(d.volume)<=0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if d.tela_cheia else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if d.vsync else DisplayServer.VSYNC_DISABLED)
	if salvar:
		var cfg := ConfigFile.new()
		cfg.set_value("audio","volume",d.volume)
		cfg.set_value("video","tela_cheia",d.tela_cheia)
		cfg.set_value("video","vsync",d.vsync)
		cfg.save(caminho)
