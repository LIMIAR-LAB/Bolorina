extends SceneTree
## Testes das conversas dos moradores (Dialogue Manager + caixa_dialogo + demo).
## Rodar:  godot --headless --path . -s res://tests/dialogos_testes.gd
## 1) cada morador do registro tem dialogos/<id>.dialogue que compila e tem o cue "start";
## 2) percorre TODOS os ramos de escolha de cada conversa do inicio ao fim;
## 3) a segunda conversa cai no cue "de_novo" (falas curtas de retorno);
## 4) a caixa de dialogo roda cada conversa sozinha ate o fim (modo automatico);
## 5) a cena demo carrega, cria os 12 moradores nos Marker3D e a conversa com a Mira
##    funciona por teclado (E para abrir, E para avancar e escolher).
const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const CenaCaixa = preload("res://scenes/ui/caixa_dialogo.tscn")
const CenaDemo = preload("res://scenes/dialogos/demo_dialogos.tscn")

var checks := 0
var failures := 0
var dm
var relatorio: Array = []

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
	dm = root.get_node_or_null("DialogueManager")
	check(dm != null, "autoload DialogueManager presente")
	if dm == null:
		_fim()
		return
	check(Registro.ids().size() == 12, "registro com 12 moradores (%d)" % Registro.ids().size())
	for id in Registro.ids():
		await _testar_arquivo(String(id))
	for id in Registro.ids():
		await _testar_caixa(String(id))
	await _testar_demo()
	_fim()

func _fim() -> void:
	Estado.reiniciar_global()
	Registro._fonte = null
	print("\nRESUMO DAS CONVERSAS")
	for l in relatorio:
		print("  " + l)
	print("\n%s: %d verificacoes, %d falhas" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	await process_frame
	quit(0 if failures == 0 else 1)

## Percorre uma conversa seguindo 'roteiro' (indices de escolha). Retorna dados do caminho.
func _percorrer(recurso: Resource, estado, roteiro: Array, cue := "start") -> Dictionary:
	var linhas := 0
	var escolhas_vistas: Array = []
	var falantes := {}
	var problemas: Array = []
	var linha = await dm.get_next_dialogue_line(recurso, cue, [estado])
	var passos := 0
	while linha != null and passos < 300:
		passos += 1
		if String(linha.text) != "":
			linhas += 1
			falantes[String(linha.character)] = true
			if String(linha.character) == "":
				problemas.append("fala sem personagem: " + String(linha.text))
		if linha.responses.size() > 0:
			var i := 0
			var k := escolhas_vistas.size()
			if k < roteiro.size():
				i = int(roteiro[k])
			escolhas_vistas.append(linha.responses.size())
			for r in linha.responses:
				if String(r.text).strip_edges() == "":
					problemas.append("escolha vazia")
			linha = await dm.get_next_dialogue_line(recurso, linha.responses[i].next_id, [estado])
		else:
			linha = await dm.get_next_dialogue_line(recurso, linha.next_id, [estado])
	if passos >= 300:
		problemas.append("conversa nao termina (laco?)")
	return {"linhas": linhas, "escolhas": escolhas_vistas, "falantes": falantes, "problemas": problemas}

func _testar_arquivo(id: String) -> void:
	var caminho := Registro.caminho_dialogo(id)
	check(ResourceLoader.exists(caminho), "%s: arquivo %s existe" % [id, caminho])
	var recurso: Resource = load(caminho)
	check(recurso != null and recurso.get_class() == "Resource" and "cues" in recurso or recurso != null, "%s: dialogo compila e carrega" % id)
	if recurso == null:
		return
	var cues = recurso.get("cues")
	if cues is Dictionary or cues is Array:
		check("start" in cues and "de_novo" in cues, "%s: cues 'start' e 'de_novo' presentes" % id)
	var nome := String(Registro.dados(id).nome)
	# enumera todos os ramos
	var fila: Array = [[]]
	var ramos := 0
	var total_linhas := 0
	var ok_ramos := true
	var minimo := 999
	while not fila.is_empty() and ramos < 64:
		var roteiro: Array = fila.pop_front()
		var estado = Estado.new()
		var r: Dictionary = await _percorrer(recurso, estado, roteiro)
		ramos += 1
		total_linhas += int(r.linhas)
		minimo = mini(minimo, int(r.linhas))
		for f in r.falantes:
			if f != nome and f != "Vale":
				ok_ramos = false
				print("   falante inesperado em %s: %s" % [id, f])
		if not r.problemas.is_empty():
			ok_ramos = false
			print("   problemas em %s %s: %s" % [id, str(roteiro), str(r.problemas)])
		if not estado.tem(id + "_conheceu"):
			ok_ramos = false
			print("   %s ramo %s nao marcou %s_conheceu" % [id, str(roteiro), id])
		var vistas: Array = r.escolhas
		for k in range(roteiro.size(), vistas.size()):
			for alt in range(1, int(vistas[k])):
				var novo: Array = roteiro.duplicate()
				while novo.size() < k:
					novo.append(0)
				novo.append(alt)
				fila.append(novo)
	check(ok_ramos and ramos >= 2, "%s: %d ramos percorridos do inicio ao fim (%d falas, minimo %d por ramo)" % [id, ramos, total_linhas, minimo])
	check(minimo >= 4, "%s: primeira conversa tem pelo menos 4 falas em todo ramo" % id)
	# segunda visita -> de_novo
	var est = Estado.new()
	await _percorrer(recurso, est, [])
	var r2: Dictionary = await _percorrer(recurso, est, [])
	check(int(r2.linhas) >= 1 and int(r2.linhas) <= 2 and r2.falantes.has(nome), "%s: segunda visita usa as falas curtas de retorno (%d fala)" % [id, int(r2.linhas)])
	relatorio.append("%-14s %-30s ramos=%d falas=%d" % [id, nome, ramos, total_linhas])

func _testar_caixa(id: String) -> void:
	Estado.reiniciar_global()
	var caixa = CenaCaixa.instantiate()
	root.add_child(caixa)
	caixa.automatico = true
	caixa.escolha_automatica = func(resps): return resps.size() - 1
	var fim := [false]
	var falas := [0]
	caixa.encerrado.connect(func(_i): fim[0] = true)
	caixa.linha_mostrada.connect(func(_q, _t): falas[0] += 1)
	caixa.iniciar(load(Registro.caminho_dialogo(id)), id)
	var t := 0
	while not fim[0] and t < 400:
		await process_frame
		t += 1
	check(fim[0] and falas[0] >= 4, "%s: caixa de dialogo mostrou %d falas e fechou sozinha" % [id, falas[0]])
	check(caixa.nome.text != "" and caixa.retrato.texture != null, "%s: caixa tem nome e retrato" % id)
	check(Estado.global().tem(id + "_conheceu"), "%s: estado marcou a conversa como feita" % id)
	caixa.queue_free()
	await process_frame

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

func _testar_demo() -> void:
	Estado.reiniciar_global()
	var demo = CenaDemo.instantiate()
	root.add_child(demo)
	current_scene = demo
	for i in 10:
		await physics_frame
	var npcs := get_nodes_in_group("npc_conversavel")
	check(npcs.size() == 12, "demo: %d moradores criados nos Marker3D" % npcs.size())
	var ids := {}
	for n in npcs:
		ids[String(n.npc_id)] = n
		if n.get_node_or_null("AreaConversa") == null:
			check(false, "demo: %s sem Area3D" % n.npc_id)
	check(ids.size() == 12, "demo: um morador por id")
	var mira = ids.get("mira")
	check(mira != null and mira.global_position.distance_to(demo.get_node("Marcadores/mira").global_position) < 0.01, "demo: Mira nasceu no Marker3D 'mira'")
	# longe de todos: E nao abre nada
	demo.jogador.global_position = Vector3(10, 0.05, 10)
	for i in 6:
		await physics_frame
	check(demo.dialogos.mais_proximo() == null and not demo.dialogos.tecla_e(), "demo: longe dos moradores o E nao e consumido")
	# chega perto da Mira
	demo.jogador.global_position = mira.global_position + Vector3(0, 0.05, 1.2)
	for i in 8:
		await physics_frame
	await process_frame
	check(demo.dialogos.mais_proximo() == mira, "demo: Area3D detectou a jogadora perto da Mira")
	check(mira.aviso.visible and mira.aviso.text == "E - Conversar", "demo: aviso 'E - Conversar' aparece")
	await _tecla(KEY_E)
	check(demo.dialogos.conversando and demo.dialogos.caixa.ativo, "demo: E abriu a conversa com a Mira")
	await esperar(0.1)
	check(demo.dialogos.caixa.nome.text == "Mira", "demo: caixa mostra o nome 'Mira'")
	check(not mira.aviso.visible, "demo: aviso some durante a conversa")
	var antes: Vector3 = demo.jogador.global_position
	var n := 0
	while demo.dialogos.conversando and n < 120:
		await esperar(0.21)
		await _tecla(KEY_D) # andar nao pode mexer a jogadora
		await _tecla(KEY_E)
		n += 1
	check(not demo.dialogos.conversando, "demo: conversa terminou so com a tecla E (%d toques)" % n)
	check(Estado.global().tem("mira_conheceu"), "demo: Mira marcada como conhecida")
	check(demo.jogador.global_position.distance_to(antes) < 0.05, "demo: jogadora parada durante a conversa")
	await esperar(0.1)
	check(mira.aviso.visible, "demo: aviso volta depois da conversa")
	# segunda conversa
	await _tecla(KEY_E)
	await esperar(0.1)
	check(demo.dialogos.conversando, "demo: segunda conversa abre")
	n = 0
	while demo.dialogos.conversando and n < 40:
		await esperar(0.21)
		await _tecla(KEY_SPACE)
		n += 1
	check(not demo.dialogos.conversando, "demo: segunda conversa fecha com Espaço")
	# helper de spawn em outro mapa
	var mapa := Node3D.new()
	root.add_child(mapa)
	var m := Marker3D.new()
	m.name = "NPC_dragao"
	m.position = Vector3(3, 0, 4)
	mapa.add_child(m)
	var m2 := Marker3D.new()
	m2.name = "SpawnJogador"
	mapa.add_child(m2)
	var criados: Array = preload("res://scripts/dialogos/interacao_npcs.gd").spawn_em_marcadores(mapa)
	check(criados.size() == 1 and criados[0].npc_id == "dragao" and criados[0].global_position.is_equal_approx(Vector3(3, 0, 4)), "spawn_em_marcadores: 'NPC_dragao' vira o dragao; outros Marker3D sao ignorados")
	mapa.queue_free()
	demo.queue_free()
	await process_frame
