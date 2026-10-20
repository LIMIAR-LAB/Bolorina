extends SceneTree
## Testes headless das Minas da Cinza (PROPOSTA).
## Rodar:  godot --headless --path . -s res://tests/minas_da_cinza_testes.gd
## 1) o gerador é determinístico e todos os andares 1-12 (e o 20) saem conectados, com escada e trilho;
## 2) cada cena de andar carrega, monta a rocha, assa a navegação e tem spawn, saída e escada/porta;
## 3) os marcadores minerio_<material>_<nn> batem com data/forja/materiais.json (material, picareta, faixa de andares);
## 4) marcadores de inimigos (orc = inimigo existente; morcego/lodo = provisórios);
## 5) spawn_em_marcadores cria os moradores do registro MINAS e a primeira conversa de cada um vai até o fim;
## 6) da entrada a pé se chega à escada (ou à porta selada), a cada nó de minério e a cada morador;
## 7) o gancho minerar() respeita a picareta mínima e soma no inventário.
const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerador = preload("res://scripts/minas_da_cinza/gerador_minas.gd")
const CENAS := {
	1: "res://scenes/minas_da_cinza/minas_da_cinza_andar_01.tscn",
	4: "res://scenes/minas_da_cinza/minas_da_cinza_andar_04.tscn",
	9: "res://scenes/minas_da_cinza/minas_da_cinza_andar_09.tscn",
	20: "res://scenes/minas_da_cinza/minas_da_cinza_andar_20.tscn",
}

var checks := 0
var falhas := 0
var materiais := {}

func check(ok: bool, texto: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
	print(("PASS " if ok else "FAIL ") + texto)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(root.get_node_or_null("DialogueManager") != null, "autoload DialogueManager presente")
	var d = JSON.parse_string(FileAccess.get_file_as_string(Gerador.MATERIAIS))
	for m in d.materiais:
		materiais[String(m.id)] = m
	_gerador()
	check(ResourceLoader.exists("res://scenes/minas_da_cinza/minas_da_cinza.tscn"), "cena genérica existe")
	for a in CENAS:
		await _andar(a, CENAS[a])
	_fim()

func _gerador() -> void:
	var g1 = Gerador.new(4)
	g1.gerar()
	var g2 = Gerador.new(4)
	g2.gerar()
	check(g1.grade == g2.grade and g1.escada == g2.escada, "gerador determinístico (andar 4 duas vezes)")
	var g3 = Gerador.new(5)
	g3.gerar()
	check(g1.grade != g3.grade, "andares diferentes têm layouts diferentes (4 x 5)")
	var estilos := {}
	for a in range(1, 13) + [20]:
		var g = Gerador.new(a)
		g.gerar()
		estilos[g.estilo] = true
		var mats: Array = Gerador.materiais_do_andar(a, materiais.values()).map(func(m): return String(m.id))
		var ok_escada: bool = (g.escada.x >= 0) if a < 20 else true
		var esperado := "minerio_adamantium" if a >= 20 else ("minerio_ferro" if a >= 6 else "minerio_cobre")
		check(ok_escada and g.caminho.size() >= 6 and g.distancia.size() >= 60 and esperado in mats and (a >= 20 or "carvao" in mats),
			"andar %d (%s): %d células, trilho %d, minérios %s" % [a, g.estilo, g.distancia.size(), g.caminho.size(), str(mats)])
	check(estilos.size() == 3, "três estilos de andar (galerias, cavernas, coração)")

func _andar(a: int, caminho_cena: String) -> void:
	Estado.reiniciar_global()
	var t0 := Time.get_ticks_msec()
	var cena: PackedScene = load(caminho_cena)
	check(cena != null, "andar %d: cena carrega (%s)" % [a, caminho_cena])
	if cena == null:
		return
	var mapa = cena.instantiate()
	check(mapa.get_script() != null and "andar" in mapa, "andar %d: script da mina compila e está na raiz" % a)
	if mapa.get_script() == null:
		mapa.free()
		return
	root.add_child(mapa)
	for i in 6:
		await physics_frame
	print("andar %d montado + navegação: %d ms" % [a, Time.get_ticks_msec() - t0])
	check(mapa.andar == a and mapa.name == "MinasDaCinza", "andar %d: raiz MinasDaCinza com andar certo" % a)
	check(mapa.raiz.get_node_or_null("RochaEChao/Rocha") != null and mapa.raiz.get_node_or_null("RochaEChao/Chao") != null, "andar %d: rocha e chão montados" % a)
	check(mapa.navegacao != null and mapa.navegacao.navigation_mesh.get_polygon_count() > 50, "andar %d: navegação assada (%d polígonos)" % [a, mapa.navegacao.navigation_mesh.get_polygon_count() if mapa.navegacao else 0])
	check(mapa.marcador("spawn_jogador") != null, "andar %d: spawn_jogador" % a)
	check(mapa.marcador("saida_porto_velho" if a == 1 else "escada_subir") != null, "andar %d: saída para cima (%s)" % [a, "elevador" if a == 1 else "escada"])
	var fim_id := "porta_selada" if a >= 20 else "escada_descer"
	check(mapa.marcador(fim_id) != null, "andar %d: marcador %s" % [a, fim_id])
	if a < 20:
		check(int(mapa.marcador("escada_descer").get_meta("destino_andar")) == (a + 1 if a < 12 else 20), "andar %d: escada leva ao andar seguinte" % a)
	check(int(mapa.stats.get("tochas", 0)) >= 4 and mapa.luzes.size() >= 10, "andar %d: tochas e lanternas (%d tochas, %d luzes)" % [a, int(mapa.stats.get("tochas", 0)), mapa.luzes.size()])
	check(int(mapa.stats.get("cristais_de_brasa", 0)) >= 6, "andar %d: cristais de brasa (%d)" % [a, int(mapa.stats.get("cristais_de_brasa", 0))])
	check(mapa.raiz.get_node_or_null("Trilhos/Trilho") != null, "andar %d: trilho da vagoneta" % a)
	# minério
	var nos: Array = mapa.get_tree().get_nodes_in_group("minerio_no").filter(func(n): return mapa.is_ancestor_of(n))
	check(nos.size() >= 6, "andar %d: nós de minério (%d) %s" % [a, nos.size(), str(mapa.stats.get("minerio_por_material", {}))])
	var re := RegEx.create_from_string("^minerio_[a-z_]+_\\d\\d$")
	var ok_nos := true
	for n in nos:
		var mid := String(n.get_meta("material"))
		var m: Dictionary = materiais.get(mid, {})
		var faixa = m.get("andares", null)
		var na_faixa: bool = not (faixa is Array) or (a >= int(faixa[0]) and a <= int(faixa[1]))
		var ok: bool = re.search(String(n.name)) != null and String(n.name).begins_with("minerio_" + mid.trim_prefix("minerio_") + "_") \
			and not m.is_empty() and int(n.get_meta("picareta_minima")) == int(m.get("picareta_minima", -1)) and na_faixa
		if not ok:
			print("   nó inválido: ", n.name, " ", mid)
		ok_nos = ok_nos and ok
	check(ok_nos, "andar %d: todos os nós batem com materiais.json (nome, material, picareta, andares)" % a)
	# inimigos
	var ini: Array = mapa.get_tree().get_nodes_in_group("inimigo_spawn").filter(func(n): return mapa.is_ancestor_of(n))
	var tipos := {}
	var ok_ini := true
	for n in ini:
		tipos[String(n.get_meta("tipo"))] = true
		if String(n.get_meta("tipo")) == "orc":
			ok_ini = ok_ini and ResourceLoader.exists(String(n.get_meta("script")))
		else:
			ok_ini = ok_ini and bool(n.get_meta("provisorio"))
	check(ini.size() >= 2 and ok_ini and tipos.has("morcego"), "andar %d: marcadores de inimigos (%d, tipos %s)" % [a, ini.size(), str(tipos.keys())])
	if a >= 3:
		check(tipos.has("orc"), "andar %d: tem orc (inimigo existente)" % a)
	# moradores
	var esperados: Array = Gerador.NPCS_POR_ANDAR.get(a, [])
	check(mapa.npcs.size() == esperados.size() and esperados.size() >= 1, "andar %d: %d morador(es) via spawn_em_marcadores" % [a, mapa.npcs.size()])
	for id in esperados:
		var n = mapa.npc(id)
		check(n != null and Registro.MINAS.has(id) and ResourceLoader.exists(Registro.caminho_dialogo(id)), "andar %d: '%s' do registro MINAS com diálogo" % [a, id])
		if n:
			check(n.global_position.distance_to(mapa.marcador(id).global_position) < 0.01, "andar %d: '%s' nasceu no marcador" % [a, id])
	# alcance a pé
	var mapa_nav: RID = mapa.get_world_3d().navigation_map
	var sp: Vector3 = mapa.marcador("spawn_jogador").global_position
	var ini_p := Vector3.ZERO
	for _t in 240:
		await physics_frame
		ini_p = NavigationServer3D.map_get_closest_point(mapa_nav, sp)
		if NavigationServer3D.map_get_iteration_id(mapa_nav) > 0 and ini_p.distance_to(sp) < 1.5:
			break
	check(_alcanca(mapa_nav, ini_p, mapa.marcador(fim_id).global_position, 1.6), "andar %d: da entrada até %s a pé" % [a, fim_id])
	var sem_alcance: Array = []
	for n in nos:
		if not _alcanca(mapa_nav, ini_p, n.global_position, 1.8):
			sem_alcance.append(String(n.name))
	check(sem_alcance.is_empty(), "andar %d: todos os %d nós de minério alcançáveis %s" % [a, nos.size(), str(sem_alcance)])
	for n in mapa.npcs:
		check(_alcanca(mapa_nav, ini_p, n.global_position, 2.0), "andar %d: '%s' alcançável a pé" % [a, n.npc_id])
	# gancho minerar()
	var principal: Array = nos.filter(func(n): return String(materiais[String(n.get_meta("material"))].tipo) == "minerio")
	if principal.size() > 0:
		var no = principal[0]
		var inv := {"ouro": 0, "itens": {}}
		var mid := String(no.get_meta("material"))
		var pm := int(no.get_meta("picareta_minima"))
		if pm > 0:
			check(not mapa.minerar(String(no.name), "picareta_inexistente", inv).ok, "andar %d: sem picareta certa não minera %s" % [a, mid])
		var r: Dictionary = mapa.minerar(String(no.name), "picareta_cronostio", inv)
		check(r.ok and int(inv.itens.get(mid, 0)) >= 2, "andar %d: minerar() soma %s no inventário (%d)" % [a, mid, int(inv.itens.get(mid, 0))])
		check(not mapa.minerar(String(no.name), "picareta_cronostio", inv).ok, "andar %d: nó fica esgotado" % a)
	# conversas
	var dlg = mapa.dialogos
	check(dlg != null and dlg.jogador == mapa.jogador, "andar %d: gerente de conversas ligado à jogadora" % a)
	for n in mapa.npcs:
		await _conversar(mapa, n)
	mapa.queue_free()
	for i in 4:
		await process_frame

func _alcanca(mapa_nav: RID, de: Vector3, alvo_mundo: Vector3, tol: float) -> bool:
	var alvo := NavigationServer3D.map_get_closest_point(mapa_nav, alvo_mundo)
	var cam := NavigationServer3D.map_get_path(mapa_nav, de, alvo, true)
	return cam.size() > 1 and cam[cam.size() - 1].distance_to(alvo) < 0.6 and Vector2(alvo.x - alvo_mundo.x, alvo.z - alvo_mundo.z).length() < tol

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
	check(fim[0] and falas[0] >= 3, "primeira conversa com '%s' vai até o fim (%d falas)" % [id, falas[0]])
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
