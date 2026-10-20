extends SceneTree
## Integracao 20/10: adaptador area_mapa_novo nos mapas reais da Bolorina dentro do jogo do Claude (jogo_ilha).
## Para cada cidade: a Vale entra no lugar da capsula, anda, fica no chao e conversa (E / Dialogue Manager).
## Porto Velho: elenco unificado (20 NPCs), balcao do Gaspar depois da conversa, ida e volta pelo Elevador do Tiao.
## Save de teste (user://ilha_reais_teste.json); o save real nao e tocado.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const SAVE := "user://ilha_reais_teste.json"
var checks := 0
var failures := 0
var jogo

func check(ok: bool, t: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + t)

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await physics_frame

func esperar_area(id: String, limite := 900) -> bool:
	for i in limite:
		await process_frame
		if jogo.nome == id and not jogo.ocupado and jogo.atual != null:
			return true
	return false

func segurar(k: int, quadros: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	await fr(quadros)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await fr(2)

func _run() -> void:
	create_timer(1500.0).timeout.connect(func():
		print("FAIL tempo esgotado")
		quit(2))
	var v_ilha := FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	OS.set_environment("ILHA_SAVE", SAVE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "porto_velho")
	OS.set_environment("ILHA_SPAWN", "viagem")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	check(await esperar_area("porto_velho"), "jogo abre Porto Velho (mapa real)")
	for it in ["mapa_vila_orcs", "mapa_cidade_fantasma", "mapa_minas", "bussola_temporal"]:
		jogo.estado.somar(it, 1)
	for id in ["porto_velho", "vila_orcs", "cidade_fantasma", "estacao_depois_de_ontem"]:
		if jogo.nome != id:
			jogo.viajar(id)
			check(await esperar_area(id), "%s: chegou pelo mapa" % id)
		await _cidade(id)
		if id == "porto_velho":
			await _porto_velho()
	check((FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else "") == v_ilha, "save real intacto")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO mapa_novo_reais: %d/%d" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)

func _cidade(id: String) -> void:
	var a = jogo.atual
	await fr(20)
	check(a.get("adotado") == true and a.player == a.mapa.get("jogador"), "%s: adaptador adota a jogadora do mapa" % id)
	check(a.mapa.find_child("SubstituirPeloSpriteDaVale", true, false) == null and a.sprite != null and a.sprite.get_parent() == a.player, "%s: Vale no lugar da capsula" % id)
	var p: Vector3 = a.player.global_position
	var pt: Dictionary = Registro.ponto(id, "viagem")
	check(pt.has("pos") and Vector2(p.x - float(pt.pos[0]), p.z - float(pt.pos[1])).length() < 2.0, "%s: nasceu no ponto 'viagem' do registro" % id)
	await fr(40)
	check(a.player.is_on_floor(), "%s: Vale no chao" % id)
	var antes: Vector3 = a.player.global_position
	await segurar(KEY_A, 30)
	await segurar(KEY_W, 30)
	check(a.player.global_position.distance_to(antes) > 1.0 and a.player.global_position.y > -10.0, "%s: WASD move a Vale (%.1f m)" % [id, a.player.global_position.distance_to(antes)])
	var dl = a.dialogos
	check(dl != null, "%s: gerente de dialogos do mapa encontrado" % id)
	if dl == null:
		return
	var alvo := ""
	for n in root.get_tree().get_nodes_in_group("npc_conversavel"):
		if a.mapa.is_ancestor_of(n):
			alvo = String(n.npc_id)
			break
	check(alvo != "" and dl.conversar_com(alvo), "%s: conversa com %s" % [id, alvo])
	await fr(3)
	check(dl.conversando and a.travado(), "%s: conversa trava a Vale" % id)
	dl.caixa._fechar()
	await fr(4)
	check(not dl.conversando and not a.travado(), "%s: fim da conversa solta a Vale" % id)

func _porto_velho() -> void:
	var a = jogo.atual
	var an = a.area_npcs
	check(an != null and an.moradores_do_mapa and an.npcs.size() == 20, "Porto Velho: elenco unificado com 20 papeis (%d)" % (an.npcs.size() if an else 0))
	var vinc := 0
	for n in an.npcs:
		if n.vinculado:
			vinc += 1
	check(vinc == 11, "Porto Velho: 11 papeis no elenco da Bolorina, 9 moradores novos (%d)" % vinc)
	var ig: int = an.npc_por_id("ferreiro")
	check(ig >= 0 and an.npcs[ig].no.get("npc_id") == "ferreiro", "Ferraria: Gaspar Bigorna e o NPC do mapa")
	var it: int = an.npc_por_id("minerador_aposentado")
	check(it >= 0 and is_instance_valid(an.npcs[it].no) and an.npcs[it].no.get("npc_id") == "minerador_aposentado", "Seu Tiao Lamparina criado perto do elevador")
	var longe := 0
	for n in an.npcs:
		if not n.vinculado:
			var q: Array = n.dados.pos
			if Vector2(n.no.global_position.x - float(q[0]), n.no.global_position.z - float(q[1])).length() > 6.5:
				longe += 1
	check(longe == 0, "moradores novos no chao livre perto da posicao (%d longe)" % longe)
	# conversa do Gaspar no Dialogue Manager e, no fim, o balcao da ferraria
	a.player.global_position = an.npcs[ig].no.global_position + Vector3(1.2, 0.3, 0.6)
	await fr(6)
	a.dialogos.conversar_com("ferreiro")
	await fr(3)
	a.dialogos.caixa._fechar()
	await fr(5)
	check(an.balcao and an.abas.has("forjar") and an.abas.has("fundir"), "fim da conversa com o Gaspar abre o balcao (%s)" % str(an.abas))
	an.fechar()
	await fr(2)
	# Elevador do Tiao: entra nas Minas da Cinza e volta ao elevador
	var ent = null
	for n in a.mapa.find_children("*", "Node3D", true, false):
		if n.has_method("entrar") and n.has_method("andar_de_entrada"):
			ent = n
	check(ent != null, "Porto Velho: entrada de masmorra (elevador) montada")
	if ent == null:
		return
	ent.entrar(1234)
	check(await esperar_area("minas_da_cinza"), "elevador -> Minas da Cinza pela API de viagem do jogo")
	check(Sessao.ativa and Sessao.origem_area == "porto_velho", "sessao da masmorra com origem Porto Velho")
	await fr(20)
	var m = jogo.atual
	if not m.has_method("sair_para_origem"):
		for n in m.find_children("*", "Node", true, false):
			if n.has_method("sair_para_origem"):
				m = n
				break
	check(m.has_method("sair_para_origem"), "masmorra carregada")
	m.sair_para_origem()
	check(await esperar_area("porto_velho"), "saida da masmorra volta a Porto Velho")
	await fr(20)
	var pv: Vector3 = jogo.atual.player.global_position
	var pe: Dictionary = Registro.ponto("porto_velho", "elevador_minas")
	check(Vector2(pv.x - float(pe.pos[0]), pv.z - float(pe.pos[1])).length() < 3.0, "volta no ponto elevador_minas (%.1f, %.1f)" % [pv.x, pv.z])
