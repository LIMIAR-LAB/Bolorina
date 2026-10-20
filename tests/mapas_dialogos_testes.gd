extends SceneTree
## Testes de integracao: conversas nos 3 mapas grandes (Porto Velho, Vila dos Orcs, Cidade Fantasma).
## Rodar:  godot --headless --path . -s res://tests/mapas_dialogos_testes.gd
## Para cada mapa:
## 1) a cena carrega e tem o no "Dialogos" (interacao_npcs.gd) ligado a jogadora;
## 2) spawn_em_marcadores criou um morador em CADA Marker3D de NPC (todo marcador conversa);
## 3) os moradores com historia esperados estao no mapa certo;
## 4) a primeira conversa de cada morador roda ate o fim na caixa (modo automatico),
##    com a jogadora travada (demo_mode) durante e solta depois;
## 5) em Porto Velho: E perto da Mira abre a conversa e a jogadora nao anda durante a conversa.
const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")

const MAPAS := [
	{"cena": "res://scenes/vila_grande/vila_grande.tscn", "nome": "Porto Velho",
	 "esperados": ["mira", "jardineira", "guardia", "sineiro", "ferreiro", "estalajadeira", "arquimago", "capitao", "dragao"]},
	{"cena": "res://scenes/vila_orcs/vila_orcs.tscn", "nome": "Vila dos Orcs", "esperados": ["lider_orc"]},
	{"cena": "res://scenes/cidade_fantasma/cidade_fantasma.tscn", "nome": "Cidade Fantasma", "esperados": ["condessa", "lobisomem"]},
]

var checks := 0
var failures := 0
var relatorio: Array = []
var nomeados_vistos := {}

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func esperar(s: float) -> void:
	await create_timer(s).timeout

func run() -> void:
	check(root.get_node_or_null("DialogueManager") != null, "autoload DialogueManager presente")
	for m in MAPAS:
		await _testar_mapa(m)
	for id in Registro.ids():
		check(nomeados_vistos.has(id), "morador com historia '%s' aparece em algum mapa" % id)
	print("\nRESUMO POR MAPA")
	for l in relatorio:
		print("  " + l)
	print("\n%s: %d verificacoes, %d falhas" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	Estado.reiniciar_global()
	Registro._fonte = null
	await process_frame
	quit(0 if failures == 0 else 1)

func _testar_mapa(m: Dictionary) -> void:
	Estado.reiniciar_global()
	var t0 := Time.get_ticks_msec()
	var cena: PackedScene = load(m.cena)
	check(cena != null, "%s: cena carrega (%s)" % [m.nome, m.cena])
	if cena == null:
		return
	var mapa: Node3D = cena.instantiate()
	root.add_child(mapa)
	for i in 6:
		await physics_frame
	var dlg = mapa.dialogos
	check(dlg != null and dlg.get_parent() == mapa and dlg.name == "Dialogos", "%s: gerente de conversas 'Dialogos' na cena" % m.nome)
	check(dlg.jogador == mapa.jogador and dlg.game == mapa, "%s: gerente ligado a jogadora e ao mapa" % m.nome)
	var marcadores_npc: Array = mapa.get_tree().get_nodes_in_group("npc_marcador").filter(func(n): return mapa.is_ancestor_of(n))
	var ids: Array = []
	for n in mapa.npcs:
		ids.append(String(n.npc_id))
	check(mapa.npcs.size() == marcadores_npc.size(), "%s: um morador por marcador (%d moradores, %d marcadores)" % [m.nome, mapa.npcs.size(), marcadores_npc.size()])
	for mk in marcadores_npc:
		var id := String(mk.name)
		check(id in ids, "%s: marcador '%s' virou morador" % [m.nome, id])
		check(ResourceLoader.exists(Registro.caminho_dialogo(id)), "%s: '%s' tem dialogos/%s.dialogue" % [m.nome, id, id])
		var n = mapa.npc(id)
		if n:
			check(n.global_position.distance_to(mk.global_position) < 0.01, "%s: '%s' nasceu na posicao do marcador" % [m.nome, id])
	for id in m.esperados:
		check(id in ids, "%s: morador com historia '%s' presente" % [m.nome, id])
		nomeados_vistos[id] = true
	if m.nome == "Porto Velho":
		await _testar_tecla_e(mapa)
		Estado.reiniciar_global()
	var falas_total := 0
	for n in mapa.npcs:
		falas_total += await _conversar_ate_o_fim(mapa, n, m.nome)
	relatorio.append("%-16s moradores=%2d  conversas=%2d  falas=%3d  (%s)  %d ms" % [m.nome, mapa.npcs.size(), mapa.npcs.size(), falas_total, ", ".join(ids), Time.get_ticks_msec() - t0])
	mapa.queue_free()
	for i in 4:
		await process_frame

func _conversar_ate_o_fim(mapa, npc, nome_mapa: String) -> int:
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
	var abriu: bool = dlg.conversar(npc)
	check(abriu, "%s: conversa com '%s' abre" % [nome_mapa, id])
	check(mapa.demo_mode, "%s: jogadora travada durante a conversa com '%s'" % [nome_mapa, id])
	var t := 0.0
	while not fim[0] and t < 10.0:
		await process_frame
		t += 0.016
	check(fim[0], "%s: primeira conversa com '%s' vai ate o fim (%d falas)" % [nome_mapa, id, falas[0]])
	check(falas[0] >= 2, "%s: '%s' disse pelo menos 2 falas" % [nome_mapa, id])
	check(falantes.has(npc.nome_exibido()), "%s: '%s' fala com o nome '%s'" % [nome_mapa, id, npc.nome_exibido()])
	check(not mapa.demo_mode and not dlg.conversando, "%s: jogadora solta depois da conversa com '%s'" % [nome_mapa, id])
	caixa.linha_mostrada.disconnect(conta)
	dlg.conversa_encerrada.disconnect(ao_fim)
	caixa.automatico = false
	return falas[0]

func _tecla(k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var s := InputEventKey.new()
	s.physical_keycode = k
	s.keycode = k
	s.pressed = false
	Input.parse_input_event(s)
	await process_frame

func _testar_tecla_e(mapa) -> void:
	var dlg = mapa.dialogos
	var mira = mapa.npc("mira")
	var j: CharacterBody3D = mapa.jogador
	j.global_position = mira.global_position + Vector3(1.1, 0.3, 0.6)
	j.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	check(dlg.mais_proximo() == mira, "Porto Velho: perto da Mira, ela e a conversa escolhida")
	check(mira.aviso.visible, "Porto Velho: aviso 'E - Conversar' aparece sobre a Mira")
	await esperar(0.1)
	await _tecla(KEY_E)
	check(dlg.conversando and dlg.atual == mira, "Porto Velho: E abre a conversa com a Mira")
	check(dlg.caixa.painel.visible, "Porto Velho: caixa de dialogo visivel")
	var antes := j.global_position
	Input.action_press("ui_right")
	for i in 30:
		await physics_frame
	var andou := Vector2(j.global_position.x - antes.x, j.global_position.z - antes.z).length()
	check(andou < 0.05, "Porto Velho: jogadora nao anda durante a conversa (deslocou %.3f m)" % andou)
	# termina a conversa sozinha
	var fim := [false]
	var ao_fim := func(_x): fim[0] = true
	dlg.conversa_encerrada.connect(ao_fim)
	var caixa = dlg.caixa
	caixa.automatico = true
	if caixa.texto.is_typing:
		caixa.texto.skip_typing()
	await process_frame
	if caixa.linha and caixa.linha.responses.size() > 0:
		caixa.proxima(caixa.linha.responses[0].next_id)
	elif caixa.linha:
		caixa.proxima(caixa.linha.next_id)
	var t := 0.0
	while not fim[0] and t < 10.0:
		await process_frame
		t += 0.016
	dlg.conversa_encerrada.disconnect(ao_fim)
	caixa.automatico = false
	check(fim[0], "Porto Velho: conversa aberta com E termina")
	antes = j.global_position
	for i in 30:
		await physics_frame
	Input.action_release("ui_right")
	andou = Vector2(j.global_position.x - antes.x, j.global_position.z - antes.z).length()
	check(andou > 0.5, "Porto Velho: depois da conversa a jogadora volta a andar (%.2f m)" % andou)
