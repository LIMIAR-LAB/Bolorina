extends SceneTree
## Testes da fazenda: ferramentas, ciclo de cultivo, save novo, island_v1 intacto.
## ILHA_SAVE aponta para arquivo temporario; ILHA_SEM_SAVE nao e usado (gravamos o novo).
const SAVE_V1 := "user://island_v1.json"
var ok := 0
var falhas: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var md5_antes := ""
	if FileAccess.file_exists(SAVE_V1):
		md5_antes = FileAccess.get_md5(SAVE_V1)
	OS.set_environment("ILHA_SAVE", "user://ilha_fazenda_teste.json")
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	if FileAccess.file_exists("user://ilha_fazenda_teste.json"):
		DirAccess.remove_absolute("user://ilha_fazenda_teste.json")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await process_frame
	await process_frame
	for i in 90:
		await process_frame
		if jogo.atual and jogo.atual.has_method("nascer") and jogo.atual.get("ui") != null and jogo.atual.ui != null:
			break
	var f = jogo.atual
	_check(f != null and String(jogo.nome) == "fazenda", "cena fazenda carregada")
	if f == null:
		_fim(md5_antes); return
	_check(f.estado != null and f.estado.arquivo == "user://ilha_fazenda_teste.json", "save novo apontado")
	_check(f.estado.qtd("semente_nabo") == 15 and f.estado.qtd("semente_couve") == 5 and f.estado.qtd("semente_abobora") == 3, "sementes iniciais 15/5/3")
	_check(f.detritos != null, "detritos montados")
	_check(f.detritos != null and f.detritos.mapa.size() > 50, "detritos no campo (%d)" % (f.detritos.mapa.size() if f.detritos else 0))
	_check(f.solo != null and f.solo.nos.size() >= 12, "canteiro inicial arado")
	_check(f.galinheiro != null and f.galinheiro.galinhas.size() == 5, "5 galinhas")
	_check(f.vila.fundo_vila == false, "sem abismo/moldura da vila")
	_check(f.saidas.size() >= 1, "saida para a vila")
	# enxada: ara celula livre perto do spawn
	f.player.position = Vector3(-6, f.vila.altura(-6, -12) + 0.4, -12)
	f.facing = Vector3(1, 0, 0)
	f.estado.slot = 0
	f.ui.atualizar()
	var alvo_arar := Vector2i(-4, -12)
	# limpa detrito se houver
	if f.detritos and f.detritos.em(alvo_arar):
		f.detritos.mapa[alvo_arar].hp = 1
		f.detritos.golpe(alvo_arar, String(f.detritos.REGRAS[f.detritos.tipo(alvo_arar)].ferramenta))
	_check(f.ui.aravel(alvo_arar) or f.solo.tem(alvo_arar), "celula candidata a arar")
	if not f.solo.tem(alvo_arar) and f.ui.aravel(alvo_arar):
		f.solo.arar(alvo_arar)
	_check(f.solo.tem(alvo_arar), "enxada ara")
	# plantar nabo
	f.estado.slot = 5
	var msg: String = f.solo.plantar(alvo_arar, "nabo")
	_check(f.estado.qtd("semente_nabo") == 14 and String(f.solo.dados(alvo_arar).cultura) == "nabo", "planta nabo: " + msg)
	# regar 3 dias
	f.estado.regador = 40
	for d in 3:
		f.solo.molhar(alvo_arar)
		f.estado.novo_dia()
		f.solo.aplicar()
	_check(int(f.solo.dados(alvo_arar).estagio) >= 3, "nabo maduro apos 3 dias regados (est=%d)" % int(f.solo.dados(alvo_arar).estagio))
	msg = f.solo.colher(alvo_arar)
	_check(f.estado.qtd("nabo") == 1, "colheita nabo: " + msg)
	# pedra
	var pedra_c := Vector2i.ZERO
	for c in f.detritos.mapa:
		if f.detritos.tipo(c) == "pedra":
			pedra_c = c; break
	_check(pedra_c != Vector2i.ZERO, "existe pedra")
	if pedra_c != Vector2i.ZERO:
		var antes: int = f.estado.qtd("pedra")
		f.detritos.golpe(pedra_c, "picareta")
		_check(f.estado.qtd("pedra") == antes + 1 and not f.detritos.em(pedra_c), "picareta -> pedra")
	# mato
	var mato_c := Vector2i.ZERO
	for c in f.detritos.mapa:
		if f.detritos.tipo(c) == "mato":
			mato_c = c; break
	if mato_c != Vector2i.ZERO:
		var antesf: int = f.estado.qtd("fibra")
		f.detritos.golpe(mato_c, "foice")
		_check(f.estado.qtd("fibra") == antesf + 1, "foice -> fibra")
	# galho
	var galho_c := Vector2i.ZERO
	for c in f.detritos.mapa:
		if f.detritos.tipo(c) == "galho":
			galho_c = c; break
	if galho_c != Vector2i.ZERO:
		var antesm: int = f.estado.qtd("madeira")
		f.detritos.golpe(galho_c, "machado")
		_check(f.estado.qtd("madeira") == antesm + 1, "machado -> madeira (galho)")
	# regador no lago
	f.estado.regador = 0
	_check(f.ui.agua(Vector2i(-19, 14)), "lago e agua")
	f.estado.regador = f.estado.REGADOR_MAX
	_check(f.estado.regador == 40, "regador cheio")
	# caixa de envio
	f.estado.itens["nabo"] = 2
	var g: int = f.estado.vender_colheita()
	_check(g == 2 * 35 and f.estado.ouro == g and f.estado.qtd("nabo") == 0, "caixa envio +ouro")
	# salvar e recarregar
	_check(f.estado.salvar(), "salvar fazenda")
	_check(FileAccess.file_exists("user://ilha_fazenda_teste.json"), "arquivo novo existe")
	var e2 = load("res://scripts/ilha/fazenda_estado.gd").new()
	e2.arquivo = "user://ilha_fazenda_teste.json"
	_check(e2.carregar() and e2.dia >= 1 and e2.ouro == g, "carregar save fazenda")
	# island_v1 intacto
	var md5_depois := ""
	if FileAccess.file_exists(SAVE_V1):
		md5_depois = FileAccess.get_md5(SAVE_V1)
	_check(md5_antes == md5_depois, "island_v1.json intacto (md5)")
	# casa + interiores
	_check(f.interiores != null and f.interiores.casas.size() >= 1, "casa com interiores")
	# hotbar
	f.ui.selecionar(4)
	_check(f.ui.item() == "regador", "slot 5 = regador")
	f.ui.selecionar(0)
	_fim(md5_antes)

func _check(c: bool, nome: String) -> void:
	if c:
		ok += 1
		print("OK  ", nome)
	else:
		falhas.append(nome)
		print("FALHA  ", nome)

func _fim(md5_antes: String) -> void:
	print("--- fazenda_testes: %d ok, %d falhas ---" % [ok, falhas.size()])
	for f in falhas:
		print("  - ", f)
	quit(0 if falhas.is_empty() else 1)
