extends SceneTree
## Testes do inventario central + bau de madeira (Bolorina, 20/10). Headless, save de teste proprio.
## Parte 1: modelo (scripts/ilha/inventario.gd + save). Parte 2: no jogo (fazenda): arvore -> madeira ->
## fabricar -> colocar -> guardar/retirar -> recolher; aba Equipamento embutida; save antigo.
const SAVE := "user://ilha_inventario_bau_teste.json"
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const Inv = preload("res://scripts/ilha/inventario.gd")
const Equip = preload("res://scripts/ilha/equipamento.gd")
var ok := 0
var falhas: Array[String] = []
var jogo

func _init() -> void:
	call_deferred("_run")

func check(c: bool, t: String) -> void:
	if c:
		ok += 1
		print("ok   ", t)
	else:
		falhas.append(t)
		print("FAIL ", t)

func fr(n: int) -> void:
	for i in n:
		await process_frame

func tecla(k: int, shift := false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	ev.shift_pressed = shift
	root.push_input(ev)
	await fr(2)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)
	await fr(2)

func clique(pos: Vector2, botao := MOUSE_BUTTON_LEFT, shift := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	ev.shift_pressed = shift
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if botao == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	# coordenadas da tela 1600x900 (headless: janela 64x64 com stretch; true = coords locais do viewport)
	root.push_input(ev, true)
	await fr(2)
	var up := ev.duplicate()
	up.pressed = false
	up.button_mask = 0
	root.push_input(up, true)
	await fr(2)

func soma_total(e) -> Dictionary:
	var t := {}
	for k in e.itens:
		t[k] = Inv.total(e, String(k))
	return t

func _run() -> void:
	create_timer(900.0).timeout.connect(func(): print("TIMEOUT"); _fim())
	OS.set_environment("ILHA_SAVE", SAVE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	_modelo()
	await _jogo()
	_fim()

# ================================================================ parte 1: modelo
func _modelo() -> void:
	var e := Estado.new()
	check(e.baus is Array and e.baus.is_empty(), "estado novo: sem baus")
	var tudo := Inv.lista(e, "tudo")
	var ids: Array = tudo.map(func(x): return String(x.id))
	check(ids.has("semente_nabo") and ids.has("racao") and ids.has("machado") and ids.has("roupa_aprendiz"), "aba Tudo agrega sementes, ferramentas da barra e roupas (%d entradas)" % tudo.size())
	var sem := Inv.lista(e, "sementes")
	check(sem.size() >= 3 and sem.all(func(x): return String(x.aba) == "sementes") and not sem.map(func(x): return x.id).has("madeira"), "aba Sementes so tem sementes")
	var nabo: Dictionary = sem.filter(func(x): return x.id == "semente_nabo")[0]
	check(int(nabo.q) == 15 and int(nabo.preco) == 20 and String(nabo.nome) != "" and bool(nabo.movivel), "entrada com nome/qtd/valor (sementes de nabo x15, 20 ouro)")
	check(Inv.lista(e, "equipamento").size() == e.equipamento.possui.size(), "pecas de roupa contam na aba Equipamento")
	var porq := Inv.lista(e, "tudo", "quantidade")
	check(int(porq[0].q) >= int(porq[porq.size() - 1].q), "ordenar por quantidade")
	var pornome := Inv.lista(e, "sementes", "nome")
	check(String(pornome[0].nome).naturalnocasecmp_to(String(pornome[1].nome)) <= 0, "ordenar por nome")
	check(Inv.aba_de("minerio_cobre") == "minerios" and Inv.aba_de("peixe_carpa") == "pesca" and Inv.aba_de("carta_entrega") == "missao" and Inv.aba_de("picareta_cobre") == "ferramentas" and Inv.aba_de("madeira") == "materiais", "categorias -> abas (minerio, peixe, missao, ferramenta, material)")
	check(not Inv.movivel("roupa_aprendiz") and not Inv.movivel("machado") and Inv.movivel("madeira"), "roupa e ferramenta da barra nao vao para o bau")
	check(Inv.icone("bau") != null and Inv.icone("madeira") != null and Inv.icone("item_inexistente") != null, "icones (bau desenhado, madeira do catalogo, fallback)")
	# fabricar
	var custo := int(Inv.receitas().bau.ingredientes.madeira)
	check(custo > 0 and custo <= 50, "receita do bau: %d madeira" % custo)
	check(Inv.pode_fabricar(e, "bau").begins_with("Falta"), "sem madeira nao fabrica")
	check(Inv.fabricar(e, "bau").begins_with("Falta") and e.qtd("bau") == 0, "fabricar sem madeira nao cria bau")
	e.somar("madeira", custo + 5)
	var r := Inv.fabricar(e, "bau")
	check(e.qtd("bau") == 1 and e.qtd("madeira") == 5, "fabricar gasta %d madeira e da 1 bau (%s)" % [custo, r])
	# colocar
	var b := Inv.colocar(e, "fazenda", Vector3(2, 0.1, 3), PI / 2)
	check(not b.is_empty() and e.qtd("bau") == 0 and e.baus.size() == 1 and String(b.id) == "bau_1" and b.slots.size() == 36, "colocar gasta o bau e cria grade de 36")
	check(Inv.colocar(e, "fazenda", Vector3.ZERO).is_empty() and e.baus.size() == 1, "sem bau na mochila nao coloca")
	# guardar / retirar
	var antes := soma_total(e)
	check(Inv.guardar(e, b, "semente_nabo", 10) == 10 and e.qtd("semente_nabo") == 5 and Inv.qtd_bau(b, "semente_nabo") == 10, "guardar 10 sementes")
	check(Inv.guardar(e, b, "semente_nabo", 1) == 1 and Inv.livres(b) == 35, "mesma pilha (1 espaco usado)")
	check(Inv.guardar(e, b, "roupa_aprendiz", 1) == 0 and Inv.guardar(e, b, "machado", 1) == 0, "roupa/ferramenta recusadas")
	check(Inv.guardar(e, b, "abobora", 3) == 0, "nao guarda o que nao tem")
	check(Inv.retirar(e, b, 0, 4) == 4 and e.qtd("semente_nabo") == 8 and Inv.qtd_bau(b, "semente_nabo") == 7, "retirar 4")
	check(Inv.retirar(e, b, 0, 1 << 30) == 7 and Inv.vazio(b) and e.qtd("semente_nabo") == 15, "retirar a pilha toda")
	check(soma_total(e) == antes, "nenhum item some (guardar/retirar)")
	# encher: 36 pilhas de 999
	e.somar("pedra", 999 * 36 + 5)
	var foi := Inv.guardar(e, b, "pedra", 999 * 36 + 5)
	check(foi == 999 * 36 and e.qtd("pedra") == 5 and Inv.livres(b) == 0, "bau cheio: o que nao cabe fica na mochila (%d)" % e.qtd("pedra"))
	check(Inv.guardar(e, b, "madeira", 1) == 0 and e.qtd("madeira") == 5, "bau cheio recusa item novo sem perder")
	for i in 36:
		Inv.retirar(e, b, i, 1 << 30)
	e.somar("pedra", -e.qtd("pedra"))
	# ordenar + guardar iguais
	e.somar("couve", 7)
	e.somar("madeira", 20)
	Inv.guardar(e, b, "couve", 3)
	Inv.guardar(e, b, "madeira", 2)
	Inv.retirar(e, b, 0, 1)
	b.slots[20] = {"id": "couve", "q": 1}
	e.somar("couve", -1)
	var t0 := soma_total(e)
	Inv.ordenar_bau(b)
	check(soma_total(e) == t0 and Inv.livres(b) == 34, "ordenar junta pilhas sem mudar totais")
	var n_ig := Inv.guardar_iguais(e, b)
	check(n_ig > 0 and e.qtd("couve") == 0 and e.qtd("madeira") == 0 and soma_total(e) == t0, "guardar iguais (%d)" % n_ig)
	# recolher
	check(Inv.recolher(e, String(b.id)) != "" and e.baus.size() == 1, "nao recolhe bau com itens")
	# save / load
	e.arquivo = SAVE
	e.gravar = true
	check(e.salvar(), "salva com bau")
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(d is Dictionary and d.get("baus", null) is Array and int(d.versao) == 1, "chave 'baus' no save, versao 1 mantida")
	var e2 := Estado.new()
	check(e2.carregar() and e2.baus.size() == 1 and Inv.qtd_bau(e2.baus[0], "couve") == Inv.qtd_bau(b, "couve") and Inv.qtd_bau(e2.baus[0], "madeira") == Inv.qtd_bau(b, "madeira"), "bau volta do save com os itens")
	check(soma_total(e2) == soma_total(e), "totais iguais depois de carregar")
	for i in 36:
		Inv.retirar(e2, e2.baus[0], i, 1 << 30)
	check(Inv.recolher(e2, "bau_1") == "" and e2.baus.is_empty() and e2.qtd("bau") == 1, "bau vazio recolhe e volta para a mochila")
	var casa := Inv.bau_casa(e2)
	check(bool(casa.fixo) and Inv.recolher(e2, Inv.ID_CASA) != "" and Inv.bau_casa(e2) == casa, "bau da casa: fixo, unico")
	# save antigo (sem "baus") e save com lixo
	var velho := {"versao": 1, "dia": 4, "ouro": 77, "itens": {"madeira": 9, "semente_nabo": 2}}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(velho))
	f.close()
	var e3 := Estado.new()
	check(e3.carregar() and e3.dia == 4 and e3.ouro == 77 and e3.qtd("madeira") == 9 and e3.baus.is_empty(), "save antigo sem 'baus' carrega normal")
	check(Inv.lista(e3, "materiais").map(func(x): return x.id).has("madeira"), "save antigo: madeira aparece no inventario")
	velho["baus"] = [{"id": "bau_7", "pos": [1, 2], "slots": [{"id": "pedra", "q": 3}, "lixo", {"id": "", "q": 5}]}, "lixo", {"id": "bau_7"}]
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(velho))
	f.close()
	var e4 := Estado.new()
	check(e4.carregar() and e4.baus.size() == 1 and Inv.qtd_bau(e4.baus[0], "pedra") == 3 and e4.baus[0].slots.size() == 36, "save com bau quebrado: normaliza sem perder a pedra")
	check(Inv.proximo_id(e4) == "bau_8", "ids dos baus continuam (bau_8)")
	DirAccess.remove_absolute(SAVE)

# ================================================================ parte 2: no jogo
func _esperar(area: String) -> void:
	for i in 600:
		await process_frame
		if jogo.nome == area and not jogo.ocupado and jogo.atual != null:
			break
	await create_timer(0.5).timeout

func _jogo() -> void:
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await _esperar("fazenda")
	var f = jogo.atual
	var tela = jogo.inventario_tela
	check(tela != null and jogo.equip_tela == tela.equip and not tela.aberto, "inventario montado; equip_tela = aba Equipamento")
	check(jogo.baus_mundo != null and is_instance_valid(jogo.baus_mundo) and jogo.baus_mundo.casa_no != null, "baus da fazenda montados (com o bau da casa)")
	check(tela.selo != null and tela.equip.selo == null, "um selo so no HUD (I Inventario / B Mochila)")
	# ---- arvore -> madeira
	var e = jogo.estado
	var arv := Vector2i(999, 999)
	for c in f.detritos.mapa:
		if f.detritos.tipo(c) == "arvore":
			arv = c
			break
	check(arv != Vector2i(999, 999), "existe arvore na fazenda")
	var m0: int = e.qtd("madeira")
	for i in 3:
		f.detritos.golpe(arv, "machado")
	await create_timer(2.0).timeout
	check(e.qtd("madeira") == m0 + 3, "arvore derrubada: 3 toras viram madeira (%d -> %d)" % [m0, e.qtd("madeira")])
	f.detritos.golpe(arv, "machado")
	check(e.qtd("madeira") == m0 + 4 and not f.detritos.em(arv), "toco arrancado: +1 madeira")
	# ---- abrir / abas
	await tecla(KEY_B)
	check(tela.aberto and tela.aba == "tudo" and tela.raiz.visible and paused, "B abre a mochila (aba Tudo) e pausa")
	check(tela.itens_vis.map(func(x): return x.id).has("madeira") and tela.celulas.size() == tela.itens_vis.size(), "madeira na grade (%d itens)" % tela.itens_vis.size())
	await tecla(KEY_TAB)
	check(tela.aba == "sementes" and tela.itens_vis.all(func(x): return String(x.aba) == "sementes"), "Tab: proxima aba (Sementes)")
	await tecla(KEY_TAB, true)
	check(tela.aba == "tudo", "Shift+Tab volta")
	var s0: int = tela.sel
	await tecla(KEY_RIGHT)
	await tecla(KEY_DOWN)
	check(tela.sel == s0 + 1 + tela.COLS or tela.sel == s0 + 1, "setas navegam (%d)" % tela.sel)
	await tecla(KEY_R)
	check(tela.ordem == "nome", "R troca a ordem (nome)")
	tela.ordem = "categoria"
	# clique numa aba
	var bm: Button = tela.botoes_aba["materiais"]
	await clique(bm.global_position + bm.size * 0.5)
	check(tela.aba == "materiais", "clique na aba Materiais")
	# ---- aba Equipamento (tela do Codex embutida)
	tela.ir_aba("equipamento")
	await fr(3)
	var eq = tela.equip
	check(eq.aberta and eq.raiz.visible and eq.raiz.get_parent() == tela.conteudo_equip and paused, "aba Equipamento: a tela do Codex dentro da aba")
	eq.sel = eq.possui_lista().find("tunica_pescador")
	await tecla(KEY_ENTER)
	check(Equip.equipado(e.equipamento, "corpo") == "tunica_pescador", "Enter veste pela aba (API da tela de equipamento)")
	await tecla(KEY_TAB)
	check(tela.aba == "fabricar" and not eq.aberta and paused and tela.aberto, "sair da aba Equipamento mantem o jogo pausado")
	# ---- fabricar
	e.somar("madeira", 30)
	var mad: int = e.qtd("madeira")
	tela._atualizar_fab()
	tela.sel = 0
	await tecla(KEY_C)
	var custo := int(Inv.receitas().bau.ingredientes.madeira)
	check(e.qtd("bau") == 1 and e.qtd("madeira") == mad - custo, "C fabrica o bau (madeira %d -> %d)" % [mad, e.qtd("madeira")])
	var dsv = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(dsv is Dictionary and int(dsv.itens.get("bau", 0)) == 1, "save gravado ao fabricar")
	# ---- colocar
	var p0 := Vector3(-6, f.vila.altura(-6, -12) + 0.4, -12)
	f.player.position = p0
	f.player.velocity = Vector3.ZERO
	f.facing = Vector3(1, 0, 0)
	tela.sel = tela.fab_linhas.size()
	await tecla(KEY_ENTER)
	var mb = jogo.baus_mundo
	check(not tela.aberto and not paused and mb.colocando, "Colocar baú: fecha o inventario e entra no modo de colocar")
	await fr(3)
	# acha uma celula livre perto (limpa detritos se preciso)
	var achou := false
	for dx in [1, -1]:
		for dz in [0, 1, -1]:
			var c := Vector2i(-6 + dx, -12 + dz)
			if f.detritos.em(c):
				continue
			f.facing = Vector3(dx, 0, dz).normalized()
			await fr(2)
			mb._atualizar_fantasma()
			if mb.alvo_ok:
				achou = true
				break
		if achou:
			break
	check(achou and mb.fantasma.visible, "bau-fantasma verde numa celula livre (%s)" % str(mb.alvo))
	var en0: int = e.energia
	await tecla(KEY_E)
	check(not mb.colocando and e.baus.size() >= 1 and mb.nos.size() == 1 and e.qtd("bau") == 0, "E coloca o bau (gasta o bau da mochila)")
	check(e.energia == en0 and not tela.aberto, "colocar nao usa ferramenta nem abre o bau")
	var bid := String(mb.nos.keys()[0])
	var no: Node3D = mb.nos[bid]
	dsv = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(dsv is Dictionary and dsv.baus.size() >= 1, "bau no save")
	check(mb.livre(Vector2i(roundi(no.position.x), roundi(no.position.z))) != "", "celula do bau fica ocupada")
	# ---- abrir o bau
	await fr(10)
	check(mb.perto()[0] == bid, "Vale perto do bau")
	await tecla(KEY_E)
	check(tela.aberto and tela.modo == "bau" and tela.raiz_bau.visible and paused, "E abre a tela do bau")
	check((no.get_node("Tampa") as Node3D).rotation.x < -0.5, "tampa abre")
	var t0 := soma_total(e)
	var b: Dictionary = tela.bau
	var i_sem: int = tela.moc_vis.map(func(x): return x.id).find("semente_nabo")
	tela.painel = 1
	tela.sel_moc = i_sem
	await tecla(KEY_ENTER)
	check(Inv.qtd_bau(b, "semente_nabo") == 1, "Enter guarda 1")
	i_sem = tela.moc_vis.map(func(x): return x.id).find("semente_nabo")
	tela.sel_moc = i_sem
	await tecla(KEY_ENTER, true)
	check(Inv.qtd_bau(b, "semente_nabo") == 15 and e.qtd("semente_nabo") == 0, "Shift+Enter guarda a pilha toda")
	# mouse: clique numa celula da mochila guarda 1, shift-clique a pilha
	var i_rac: int = tela.moc_vis.map(func(x): return x.id).find("racao")
	var cel: Panel = tela.moc_cels[i_rac]
	await clique(cel.global_position + Vector2(20, 20))
	check(Inv.qtd_bau(b, "racao") == 1, "clique guarda 1 ração")
	i_rac = tela.moc_vis.map(func(x): return x.id).find("racao")
	cel = tela.moc_cels[i_rac]
	await clique(cel.global_position + Vector2(20, 20), MOUSE_BUTTON_LEFT, true)
	check(Inv.qtd_bau(b, "racao") == 10 and e.qtd("racao") == 0, "Shift+clique guarda a pilha")
	# retirar: clique na celula do bau
	var cb: Panel = tela.bau_cels[0]
	var id0 := String(b.slots[0].id)
	var q0 := int(b.slots[0].q)
	await clique(cb.global_position + Vector2(20, 20))
	check(int(b.slots[0].q) == q0 - 1 and Inv.total(e, id0) == int(t0[id0]), "clique no bau retira 1")
	await clique(cb.global_position + Vector2(20, 20), MOUSE_BUTTON_RIGHT)
	check(soma_total(e) == t0, "nenhum item some (teclado + mouse)")
	check(tela.b_recolher.disabled, "Recolher desabilitado com itens")
	await tecla(KEY_ESCAPE)
	check(not tela.aberto and not paused and (no.get_node("Tampa") as Node3D).rotation.x == 0.0, "Esc fecha o bau (tampa fecha, despausa)")
	dsv = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	var bs: Array = Inv.normalizar_baus(dsv.baus)
	var salvo: Array = bs.filter(func(x): return x.id == bid)
	check(salvo.size() == 1 and Inv.qtd_bau(salvo[0], "semente_nabo") == Inv.qtd_bau(b, "semente_nabo"), "itens do bau no save")
	# ---- trocar de area e voltar: bau continua
	jogo.ir("vila", "da_fazenda")
	await _esperar("vila")
	check(jogo.baus_mundo == null, "vila: sem baus (so na fazenda)")
	await tecla(KEY_B)
	check(tela.aberto, "B abre a mochila na vila")
	tela.ir_aba("fabricar")
	e.somar("bau", 1)
	tela.colocar_bau()
	check(tela.aberto and tela.msg.text.contains("fazenda"), "vila: nao coloca bau (%s)" % tela.msg.text)
	e.somar("bau", -1)
	await tecla(KEY_ESCAPE)
	jogo.ir("fazenda", "da_vila")
	await _esperar("fazenda")
	f = jogo.atual
	mb = jogo.baus_mundo
	check(mb != null and mb.nos.has(bid), "de volta a fazenda: o bau continua la")
	# ---- esvaziar e recolher
	var bb := Inv.achar(e, bid)
	for i in 36:
		Inv.retirar(e, bb, i, 1 << 30)
	check(soma_total(e) == t0, "esvaziar devolve tudo")
	f.player.position = mb.nos[bid].global_position + Vector3(0.9, 0.4, 0)
	await fr(6)
	check(mb.abrir(bid) and tela.modo == "bau", "abre o bau vazio")
	check(not tela.b_recolher.disabled, "Recolher habilitado com o bau vazio")
	tela.recolher_bau()
	await fr(3)
	check(not tela.aberto and Inv.achar(e, bid).is_empty() and e.qtd("bau") == 1 and not mb.nos.has(bid), "recolher: bau volta para a mochila")
	# ---- colocar com clique (nao usa a ferramenta)
	mb.iniciar_colocacao()
	await fr(3)
	en0 = e.energia
	var solo0: int = e.solo.size()
	e.slot = 0  # enxada na mao
	mb._atualizar_fantasma()
	var pode: bool = mb.alvo_ok
	if pode:
		# clique de verdade (passa pela fila de entrada: o bau tem de pegar antes da barra de ferramentas)
		await clique(Vector2(30, 30))
		await fr(2)
	check(pode and mb.nos.size() == 1 and e.energia == en0 and e.solo.size() == solo0, "clique coloca o bau sem arar (enxada na mao)")
	# ---- bau da casa
	var it = f.interiores
	it._trocar_para(0)
	await fr(4)
	f.player.position = mb.casa_no.global_position + Vector3(0, 0.4, 0.8)
	await fr(6)
	check(mb.perto()[0] == Inv.ID_CASA, "dentro de casa: perto do bau da casa")
	check(mb.abrir(Inv.ID_CASA) and tela.modo == "bau" and Inv.nome_bau(tela.bau) == "Baú da casa", "abre o baú da casa")
	e.somar("ovo", 3)
	tela._atualizar_bau(true)
	tela.mover(1, tela.moc_vis.map(func(x): return x.id).find("ovo"), 1 << 30)
	check(Inv.qtd_bau(Inv.bau_casa(e), "ovo") == 3 and tela.b_recolher.disabled, "guarda ovos no baú da casa (não recolhe)")
	tela.fechar()
	it._trocar_para(-1)
	await fr(3)
	# ---- I abre na ultima aba; I fecha
	await tecla(KEY_I)
	check(tela.aberto and tela.aba == "fabricar", "I abre na última aba usada (%s)" % tela.aba)
	await tecla(KEY_I)
	check(not tela.aberto and not paused, "I fecha e despausa")
	# fazenda grande tambem aceita baus (e tem o bau da casa)
	jogo.ir("fazenda_grande", "inicio")
	await _esperar("fazenda_grande")
	check(jogo.baus_mundo != null and is_instance_valid(jogo.baus_mundo) and jogo.baus_mundo.nos.is_empty() and jogo.baus_mundo.casa_no != null, "fazenda grande: baus montados (os da fazenda ficam na fazenda)")
	var e5 := Estado.new()
	check(e5.carregar() and Inv.qtd_bau(Inv.bau_casa(e5), "ovo") == 3 and e5.baus.size() == 2, "save final: baú colocado + baú da casa")

func _fim() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO inventario_bau: %d/%d ok" % [ok, ok + falhas.size()])
	for f in falhas:
		print("FAIL ", f)
	quit(0 if falhas.is_empty() else 1)
