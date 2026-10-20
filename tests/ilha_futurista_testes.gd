extends SceneTree
## Testes headless da Estação Depois-de-Ontem (ilha futurista, PROPOSTA).
## Rodar:  godot --headless --path . -s res://tests/ilha_futurista_testes.gd
## 1) a cena carrega, monta o terreno, as estruturas "fut" e assa a navegação;
## 2) spawn_em_marcadores cria um morador por marcador, todos do registro FUTURISTAS;
## 3) a primeira conversa de cada morador roda até o fim (caixa em modo automático), com a jogadora travada;
## 4) cada morador é alcançável a pé a partir do spawn (NavigationServer3D.map_get_path);
## 5) os nós de minério (grupo "veio_minerio") apontam para materiais de data/forja/materiais.json.
const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Forja = preload("res://scripts/forja/forja.gd")
const CENA := "res://scenes/ilha_futurista/ilha_futurista.tscn"

var checks := 0
var falhas := 0

func check(ok: bool, texto: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
	print(("PASS " if ok else "FAIL ") + texto)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(root.get_node_or_null("DialogueManager") != null, "autoload DialogueManager presente")
	Estado.reiniciar_global()
	var t0 := Time.get_ticks_msec()
	var cena: PackedScene = load(CENA)
	check(cena != null, "cena carrega (%s)" % CENA)
	if cena == null:
		_fim()
		return
	var mapa: Node3D = cena.instantiate()
	root.add_child(mapa)
	for i in 8:
		await physics_frame
	print("montagem + navegação: %d ms" % (Time.get_ticks_msec() - t0))
	check(mapa.name == "IlhaFuturista", "raiz IlhaFuturista")
	check(mapa.fut_raiz != null and mapa.fut_raiz.get_child_count() > 150, "estruturas futuristas montadas (%d nós)" % mapa.fut_raiz.get_child_count())
	check(int(mapa.stats.modelos) > 80, "modelos CC0 do layout (%d)" % int(mapa.stats.modelos))
	for nome in ["HologramaRelogio", "AnomaliaTemporal", "NucleoDaForjaQuantica", "HologramaDaLua"]:
		check(mapa.fut_raiz.get_node_or_null(nome) != null, "estrutura '%s' presente" % nome)
	check(mapa.navegacao != null and mapa.navegacao.navigation_mesh.get_polygon_count() > 50, "navegação assada (%d polígonos)" % (mapa.navegacao.navigation_mesh.get_polygon_count() if mapa.navegacao else 0))
	# moradores
	var marcadores_npc: Array = mapa.get_tree().get_nodes_in_group("npc_marcador").filter(func(n): return mapa.is_ancestor_of(n))
	check(marcadores_npc.size() >= 5 and marcadores_npc.size() <= 8, "5 a 8 marcadores de NPC (%d)" % marcadores_npc.size())
	check(mapa.npcs.size() == marcadores_npc.size(), "um morador por marcador (%d)" % mapa.npcs.size())
	for mk in marcadores_npc:
		var id := String(mk.name)
		check(Registro.FUTURISTAS.has(id), "'%s' está no registro FUTURISTAS" % id)
		check(ResourceLoader.exists(Registro.caminho_dialogo(id)), "'%s' tem dialogos/%s.dialogue" % [id, id])
		var n = mapa.npc(id)
		check(n != null and n.global_position.distance_to(mk.global_position) < 0.01, "'%s' nasceu no marcador" % id)
	check(Registro.ids().size() == 12, "registro principal continua com 12 moradores com história")
	# alcançáveis a pé
	# o mapa de navegação sincroniza de forma assíncrona: espera até ele ter a região (máx. ~4 s)
	var mapa_nav: RID = mapa.get_world_3d().navigation_map
	var sp: Vector3 = mapa.marcador("spawn_jogador").global_position
	var ini := Vector3.ZERO
	for _t in 240:
		await physics_frame
		ini = NavigationServer3D.map_get_closest_point(mapa_nav, sp)
		if NavigationServer3D.map_get_iteration_id(mapa_nav) > 0 and ini.distance_to(sp) < 2.0:
			break
	for n in mapa.npcs:
		var alvo := NavigationServer3D.map_get_closest_point(mapa_nav, n.global_position + Vector3(0, 0, 1.0))
		var cam := NavigationServer3D.map_get_path(mapa_nav, ini, alvo, true)
		var ok := cam.size() > 1 and cam[cam.size() - 1].distance_to(alvo) < 0.6 and alvo.distance_to(n.global_position) < 2.6
		check(ok, "'%s' alcançável a pé a partir do spawn (caminho %d pts, ini %s, alvo %s)" % [n.npc_id, cam.size(), str(ini.snapped(Vector3.ONE * 0.1)), str(alvo.snapped(Vector3.ONE * 0.1))])
	# conversas
	var dlg = mapa.dialogos
	check(dlg != null and dlg.jogador == mapa.jogador, "gerente de conversas ligado à jogadora")
	for n in mapa.npcs:
		await _conversar(mapa, n)
	# veios de minério
	var f = Forja.new()
	var veios: Array = mapa.get_tree().get_nodes_in_group("veio_minerio")
	check(veios.size() >= 6, "nós de minério na ilha (%d)" % veios.size())
	var tem_cronostio := false
	for v in veios:
		var mid := String(v.get_meta("material", ""))
		check(f.materiais.has(mid), "veio '%s' -> material '%s' existe em materiais.json" % [v.name, mid])
		check(int(v.get_meta("picareta_minima", -1)) == int(f.materiais.get(mid, {}).get("picareta_minima", 0)), "veio '%s' com picareta mínima do JSON" % v.name)
		if mid == "minerio_cronostio": tem_cronostio = true
	check(tem_cronostio, "há veio de cronóstio (metal da ilha)")
	mapa.queue_free()
	for i in 4:
		await process_frame
	_fim()

func _conversar(mapa, npc) -> void:
	var dlg = mapa.dialogos
	var caixa = dlg.caixa
	var id := String(npc.npc_id)
	caixa.automatico = true
	var falas := [0]
	var falantes := {}
	var conta := func(quem: String, texto: String):
		if texto != "":
			falas[0] += 1
			falantes[quem] = true
	caixa.linha_mostrada.connect(conta)
	var fim := [false]
	var ao_fim := func(_x): fim[0] = true
	dlg.conversa_encerrada.connect(ao_fim)
	check(dlg.conversar(npc), "conversa com '%s' abre" % id)
	check(mapa.demo_mode, "jogadora travada durante a conversa com '%s'" % id)
	var t := 0.0
	while not fim[0] and t < 12.0:
		await process_frame
		t += 0.016
	check(fim[0], "primeira conversa com '%s' vai até o fim (%d falas)" % [id, falas[0]])
	check(falas[0] >= 3, "'%s' disse pelo menos 3 falas" % id)
	check(falantes.has(npc.nome_exibido()), "'%s' fala com o nome '%s'" % [id, npc.nome_exibido()])
	check(not mapa.demo_mode and not dlg.conversando, "jogadora solta depois da conversa com '%s'" % id)
	caixa.linha_mostrada.disconnect(conta)
	dlg.conversa_encerrada.disconnect(ao_fim)
	caixa.automatico = false

func _fim() -> void:
	print("\n%s: %d verificacoes, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	Estado.reiniciar_global()
	Registro._fonte = null
	await process_frame
	quit(0 if falhas == 0 else 1)
