extends SceneTree
## Testes headless da interface da forja (scenes/ui/forja_ui.tscn + scripts/ui/forja_modelo.gd). PROPOSTA.
## godot --headless --path . -s res://tests/forja_ui_testes.gd
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")
const Modelo = preload("res://scripts/ui/forja_modelo.gd")
const Forja = preload("res://scripts/forja/forja.gd")
const UI = preload("res://scripts/ui/forja_ui.gd")

var ok_n := 0
var falhas: Array = []

func check(ok: bool, texto: String) -> void:
	if ok:
		ok_n += 1
		print("  ok   ", texto)
	else:
		falhas.append(texto)
		print("  FALHA ", texto)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("== forja_ui_testes ==")
	_testar_dados()
	_testar_situacoes_e_reserva()
	_testar_forjar_equipar_comparar()
	_testar_origens()
	_testar_icones()
	_testar_missao_reforco_e_eco()
	_testar_fiado_e_livre()
	await _testar_cena()
	print("\nRESULTADO forja_ui_testes: %s  (%d ok, %d falhas)" % ["PASS" if falhas.is_empty() else "FAIL", ok_n, falhas.size()])
	for f in falhas:
		print("  - ", f)
	quit(0 if falhas.is_empty() else 1)

func _novo(itens: Dictionary, iniciar := true):
	var est = Estado.new()
	var g = Gerenciador.new(est)
	root.add_child(g)
	if iniciar:
		est.marcar("tutorial_pulado")    # começa a missão: reserva 3 cobres
	for k in itens:
		g.adicionar_item(k, int(itens[k]))
	return g

func _testar_dados() -> void:
	print("\n-- dados --")
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/forja/forja_ui.json"))
	check(d is Dictionary and d.has("itens_extra") and d.has("eco"), "forja_ui.json lê")
	var f = Forja.new()
	check(f.validar().is_empty(), "dados da forja continuam válidos")
	check(ResourceLoader.exists("res://scenes/ui/forja_ui.tscn"), "cena existe")
	check(DirAccess.get_files_at("res://art/ui/icones_forja/").size() >= 24, "ícones em art/ui/icones_forja")

func _testar_situacoes_e_reserva() -> void:
	print("\n-- situações e reserva de cobre --")
	var g = _novo({"ouro": 100, "minerio_cobre": 5, "carvao": 2, "lingote_cobre": 3, "madeira": 2})
	var m = Modelo.new(g)
	check(g.reservado("minerio_cobre") == 3 and g.excedente("minerio_cobre") == 2, "missão reserva 3 de 5 cobres")
	check(m.situacao("fundir_cobre") == "falta", "fundir cobre (3) falta: só 2 livres")
	var det: Dictionary = m.detalhe("fundir_cobre")
	var linha: Dictionary = {}
	for l in det.materiais:
		if l.id == "minerio_cobre":
			linha = l
	check(int(linha.get("livre", -1)) == 2 and int(linha.get("reservado", -1)) == 3 and not bool(linha.get("ok", true)), "detalhe mostra livre 2 / reservado 3")
	check(String(linha.get("origem", "")).contains("reservado") and String(linha.get("origem", "")).contains("Minas da Cinza"), "origem avisa da reserva e diz onde achar: " + String(linha.get("origem", "")))
	check(not m.forjar("fundir_cobre").ok and int(g.materiais.minerio_cobre) == 5, "forjar com cobre reservado é recusado e nada é gasto")
	check(m.situacao("forjar_espada_cobre") == "pode", "espada de cobre dá para forjar")
	check(m.situacao("forjar_espada_ferro") == "travado", "espada de ferro travada (forja nível 1)")
	check(String(m.detalhe("forjar_espada_ferro").motivo).contains("Fornalha de tijolo"), "motivo do travado cita o nível: " + String(m.detalhe("forjar_espada_ferro").motivo))
	var c: Dictionary = m.contagem()
	check(c.pode + c.falta + c.travado == c.tudo and c.tudo == m.receitas_visiveis().size(), "contagem dos filtros fecha (%s)" % str(c))
	for f in ["pode", "falta", "travado"]:
		var ok := true
		for id in m.lista(f):
			if m.situacao(id) != f:
				ok = false
		check(ok and m.lista(f).size() == int(c[f]), "filtro %s só lista %s" % [f, f])
	check(m.lista("tudo")[0].begins_with("fundir"), "fundição vem primeiro na lista")
	g.free()

func _testar_forjar_equipar_comparar() -> void:
	print("\n-- forjar, comparar e equipar --")
	var g = _novo({"ouro": 100, "minerio_cobre": 6, "carvao": 2, "lingote_cobre": 3, "madeira": 2})
	var m = Modelo.new(g)
	var cmp: Dictionary = m.comparar("espada_cobre")
	var at: Dictionary = {}
	for l in cmp.linhas:
		if l.stat == "ataque":
			at = l
	check(cmp.equipado == "facao_fazenda" and float(at.atual) == 3.0 and float(at.novo) == 5.0 and float(at.delta) == 2.0 and at.melhor, "espada vs facão: ataque 3 → 5 (+2, verde)")
	var vel: Dictionary = {}
	for l in cmp.linhas:
		if l.stat == "velocidade":
			vel = l
	check(vel.pior and float(vel.delta) < 0.0, "velocidade 1,1 → 1,0 aparece como piora (vermelho)")
	var sinais := []
	m.item_forjado.connect(func(r, i): sinais.append([r, i]))
	var r: Dictionary = m.forjar("forjar_espada_cobre")
	check(r.ok and int(g.materiais.get("lingote_cobre", 0)) == 0 and int(g.materiais.ouro) == 60, "forjar gasta lingotes, madeira e 40 de ouro")
	check(sinais.size() == 1 and sinais[0][1] == "espada_cobre", "sinal item_forjado")
	check(m.possui("espada_cobre") and m.equipado.arma == "facao_fazenda", "espada vai para a mochila, facão segue equipado")
	check(m.equipar("espada_cobre") and m.equipado.arma == "espada_cobre" and g.arma_atual == "espada_cobre", "equipar troca a arma (e avisa o gerenciador)")
	check(m.possui("facao_fazenda"), "facão volta para a mochila")
	check(not m.equipar("espada_ferro"), "não equipa o que não tem")
	check(m.forjar("fundir_cobre").ok and int(g.materiais.lingote_cobre) == 1 and g.reservado("minerio_cobre") == 3, "fundir com 6 cobres usa os 3 livres e deixa os 3 reservados")
	var cmp2: Dictionary = m.comparar("elmo_cobre")
	check(cmp2.slot == "elmo" and cmp2.equipado == "" and float(cmp2.linhas[0].delta) == 2.0, "elmo comparado com nada: defesa +2")
	check(m.comparar("anel_cobre").linhas.size() == 1 and m.comparar("anel_cobre").linhas[0].stat == "defesa", "anel: '+3 de defesa' vira stat")
	check(m.testavel("espada_cobre") and not m.testavel("elmo_cobre"), "só arma vai para a Arena")
	g.free()

func _testar_origens() -> void:
	print("\n-- de onde vem cada material --")
	var g = _novo({}, false)
	var m = Modelo.new(g)
	check(m.origem("minerio_cobre") == "Minas da Cinza, andares 1–5", "cobre: " + m.origem("minerio_cobre"))
	check(m.origem("minerio_ferro").contains("andares 6–12"), "ferro: " + m.origem("minerio_ferro"))
	check(m.origem("lingote_ferro").begins_with("Fundir aqui") and m.origem("lingote_ferro").contains("andares 6–12"), "lingote de ferro: " + m.origem("lingote_ferro"))
	check(m.origem("lasca_de_eco").contains("andar 4"), "lasca de eco: " + m.origem("lasca_de_eco"))
	check(m.origem("couro").contains("Veio das Cinzas"), "couro: " + m.origem("couro"))
	var sem: Array = []
	for id in m.receitas_visiveis():
		for k in Modelo.custo_de(m.forja.receitas[id]):
			var o: String = m.origem(k)
			if o == "" or o == "Origem ainda não definida.":
				if not k in sem:
					sem.append(k)
	check(sem.is_empty(), "todo material das receitas da Ferraria tem origem (%s)" % str(sem))
	g.free()

func _testar_icones() -> void:
	print("\n-- ícones --")
	var g = _novo({}, false)
	var m = Modelo.new(g)
	check(m.icone_info("espada_cobre").caminho.ends_with("espada_cobre.png") and m.icone_info("espada_cobre").cor == Color.WHITE, "ícone próprio")
	var fe: Dictionary = m.icone_info("espada_ferro")
	check(fe.caminho.ends_with("espada_cobre.png") and fe.cor != Color.WHITE, "espada de ferro usa a de cobre tingida")
	var falt := 0
	for id in m.receitas_visiveis():
		if m.icone(String(m.forja.receitas[id].resultado)) == null:
			falt += 1
	check(falt == 0, "todo resultado tem ícone (%d sem)" % falt)
	g.free()

func _ate_escolher_eco(g) -> void:
	var est = g.estado
	est.marcar("tutorial_pulado")
	est.marcar("atrasada_conta_lida")
	est.marcar("atrasada_defeito_visto")
	est.marcar("atrasada_gaspar_explicou_minas")

func _depois_do_reforco(g) -> void:
	g.chegou_area("minas_andar_1")
	g.notificar("eco_acertou", "lodo_casca_grossa")
	g.notificar("inimigo_derrotado", "lodo_casca_grossa", 3)
	g.chegou_area("minas_andar_4")
	g.notificar("trava_acertada_eco", "bate_estaca", 3)
	g.coletar_item("catraca_mestra")
	g.chegou_area("porto_velho")
	g.estado.marcar("atrasada_peca_entregue")

func _etapa(g) -> String:
	return String(g.missao("atrasada_desde_amanha").etapa_atual().get("id", ""))

func _testar_missao_reforco_e_eco() -> void:
	print("\n-- missão: têmpera em cinza e escolha do eco --")
	var g = _novo({"ouro": 50}, false)
	var m = Modelo.new(g)
	check(not m.reforco_disponivel() and m.modo_eco() == "", "fora da missão: sem reforço e sem eco")
	_ate_escolher_eco(g)
	check(_etapa(g) == "reforco_arma" and m.reforco_disponivel(), "etapa reforco_arma: forja oferece a Têmpera em cinza")
	var info: Dictionary = m.reforco_info()
	check(info.para == "facao_fazenda_eco" and info.comparacao[0].melhor, "têmpera compara facão → facão temperado")
	check(m.fazer_reforco() and g.arma_atual == "facao_fazenda_eco" and g.estado.tem("eco_desbloqueado") and g.variacao_eco == "eco_base", "temperar troca a arma e libera o eco (base)")
	check(m.equipado.arma == "facao_fazenda_eco", "UI acompanha a troca de arma")
	check(not m.reforco_disponivel() and not m.fazer_reforco(), "reforço some depois de feito")
	_depois_do_reforco(g)
	check(_etapa(g) == "escolher_eco" and m.modo_eco() == "missao", "etapa escolher_eco: forja mostra Eco rápido / Eco pesado")
	var ops: Array = m.eco_opcoes()
	check(ops.size() == 2 and ops[0].id == "eco_rapido" and ops[1].id == "eco_pesado", "duas opções")
	check(ops[0].pode_pagar and not ops[0].fiado, "dá para pagar com o excedente (lascas do Bate-Estaca + cobre)")
	var at_r: Dictionary = ops[0].comparacao[0]
	var dn_p: Dictionary = ops[1].comparacao[1]
	check(at_r.stat == "atraso_s" and at_r.melhor and is_equal_approx(float(at_r.novo), 0.35), "rápido: atraso 0,35 (menor = verde)")
	check(dn_p.stat == "dano_relativo" and dn_p.melhor and is_equal_approx(float(dn_p.novo), 1.0), "pesado: dano 100% (verde)")
	check(ops[0].comparacao[1].pior, "rápido: dano 45% (vermelho)")
	var lascas := int(g.materiais.get("lasca_de_eco", 0))
	var cobre := int(g.materiais.get("minerio_cobre", 0))
	var r: Dictionary = m.escolher_eco("eco_pesado")
	check(r.ok and r.pago and g.variacao_eco == "eco_pesado" and g.estado.tem("atrasada_eco_pesado"), "escolher eco pesado (pago)")
	check(int(g.materiais.lasca_de_eco) == lascas - 3 and int(g.materiais.minerio_cobre) == cobre - 2, "gastou 3 lascas e 2 cobres do excedente")
	check(_etapa(g) == "testar_arena", "missão segue para testar_arena")
	check(m.modo_eco() == "", "eco some da forja até o fim da missão")
	g.free()

func _testar_fiado_e_livre() -> void:
	print("\n-- fiado e depois da missão --")
	var g = _novo({}, false)
	var m = Modelo.new(g)
	_ate_escolher_eco(g)
	m.fazer_reforco()
	_depois_do_reforco(g)
	check(g.gastar_excedente({"lasca_de_eco": 3}), "gastou as lascas em outra coisa")
	var ops: Array = m.eco_opcoes()
	check(not ops[0].pode_pagar and ops[0].fiado, "sem excedente: opção aparece como fiado")
	var r: Dictionary = m.escolher_eco("eco_rapido")
	check(r.ok and r.fiado and g.estado.tem("atrasada_eco_fiado") and g.variacao_eco == "eco_rapido" and _etapa(g) == "testar_arena", "fiado: escolhe sem gastar e a missão não trava")
	# depois da missão: troca livre entre as compradas, a outra custa
	g.estado.marcar("desbloqueado_forja_variacoes_eco")
	var g2 = _novo({"lasca_de_eco": 3, "minerio_cobre": 2}, false)
	g2.estado.marcar("desbloqueado_forja_variacoes_eco")
	g2.variacao_eco = "eco_rapido"
	var m2 = Modelo.new(g2)
	check(m2.modo_eco() == "livre", "depois da missão o eco fica livre na forja")
	var o2: Array = m2.eco_opcoes()
	check(o2[0].comprada and o2[0].atual and not o2[1].comprada, "rápido já é seu; pesado ainda não")
	check(m2.escolher_eco("eco_pesado").ok and g2.variacao_eco == "eco_pesado" and int(g2.materiais.lasca_de_eco) == 0, "compra o pesado com o excedente")
	check(m2.escolher_eco("eco_rapido").ok and g2.variacao_eco == "eco_rapido" and int(g2.materiais.minerio_cobre) == 0, "volta para o rápido de graça")
	g.free()
	g2.free()

func _tecla(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	return ev

func _enter() -> void:
	# botões disparam ao soltar (action_mode padrão): aperta e solta Enter
	var ev := _tecla(KEY_ENTER)
	root.push_input(ev)
	await process_frame
	var solta := _tecla(KEY_ENTER)
	solta.pressed = false
	root.push_input(solta)
	await process_frame

func _foco() -> Control:
	return root.gui_get_focus_owner()

func _testar_cena() -> void:
	print("\n-- cena: navegação por teclado e controle --")
	var g = _novo({"ouro": 100, "minerio_cobre": 5, "carvao": 2, "lingote_cobre": 3, "madeira": 2})
	var ui = load("res://scenes/ui/forja_ui.tscn").instantiate()
	ui.demo_se_sozinha = false
	root.add_child(ui)
	ui.abrir(g)
	await process_frame
	await process_frame
	check(ui.filtro == "pode" and ui.botoes_lista.size() == ui.entradas().size() and ui.botoes_lista.size() > 0, "abre no filtro 'Dá para forjar' com %d entradas" % ui.botoes_lista.size())
	check(_foco() == ui.botoes_lista[0], "foco começa no primeiro item")
	var primeiro: String = ui.selecionado
	root.push_input(_tecla(KEY_DOWN))
	await process_frame
	check(ui.botoes_lista.size() < 2 or (_foco() == ui.botoes_lista[1] and ui.selecionado != primeiro), "seta ↓ desce na lista e troca o detalhe")
	root.push_input(_tecla(KEY_RIGHT))
	await process_frame
	check(_foco() == ui.btn_forjar, "seta → vai para o botão Forjar")
	root.push_input(_tecla(KEY_ESCAPE))
	await process_frame
	check(_foco() in ui.botoes_lista, "Esc nas ações volta para a lista")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	jb.pressed = true
	root.push_input(jb)
	await process_frame
	check(ui.filtro == "falta", "RB troca o filtro para 'Falta material'")
	root.push_input(_tecla(KEY_E))
	await process_frame
	check(ui.filtro == "travado", "E troca para 'Travado'")
	root.push_input(_tecla(KEY_Q))
	root.push_input(_tecla(KEY_Q))
	await process_frame
	check(ui.filtro == "pode", "Q volta")
	# selecionar a espada e checar a comparação colorida
	ui.filtro = "tudo"
	ui.selecionado = "forjar_espada_cobre"
	ui._atualizar_tudo()
	await process_frame
	var delta: Label = ui.detalhe_box.find_child("Delta_ataque", true, false)
	check(delta != null and delta.text == "+2" and delta.get_theme_color("font_color") == UI.COR_BOM, "delta de ataque '+2' em verde")
	var dv: Label = ui.detalhe_box.find_child("Delta_velocidade", true, false)
	check(dv != null and dv.get_theme_color("font_color") == UI.COR_RUIM, "piora em vermelho")
	check(not ui.btn_forjar.disabled and ui.btn_equipar.disabled and not ui.btn_testar.disabled, "Forjar ativo, Equipar desativado (não tem), Testar ativo")
	ui.btn_forjar.grab_focus()
	await process_frame
	await _enter()
	check(ui.modelo.possui("espada_cobre") and int(g.materiais.ouro) == 60, "Enter no Forjar forja a espada")
	check(not ui.btn_equipar.disabled, "agora dá para equipar")
	var eq := []
	ui.equipado.connect(func(s, i): eq.append(i))
	root.push_input(_tecla(KEY_X))
	await process_frame
	check(eq == ["espada_cobre"] and ui.modelo.equipado.arma == "espada_cobre", "X equipa")
	var teste := []
	ui.testar_na_arena.connect(func(i, v): teste.append([i, v]))
	var jy := InputEventJoypadButton.new()
	jy.button_index = JOY_BUTTON_Y
	jy.pressed = true
	root.push_input(jy)
	await process_frame
	check(teste.size() == 1 and teste[0][0] == "espada_cobre", "Y (ou T) emite testar_na_arena")
	# origem na tela
	ui.selecionado = "fundir_cobre"
	ui._atualizar_tudo()
	await process_frame
	var orl: Label = ui.detalhe_box.find_child("Origem_minerio_cobre", true, false)
	check(orl != null and orl.text.contains("Minas da Cinza"), "tela mostra de onde vem o que falta")
	# eco na cena
	var g3 = _novo({}, false)
	_ate_escolher_eco(g3)
	ui.abrir(g3)
	await process_frame
	check(ui.entradas()[0] == UI.ESPECIAL_REFORCO, "na etapa do reforço a Têmpera aparece no topo")
	ui.selecionado = UI.ESPECIAL_REFORCO
	ui._mostrar(UI.ESPECIAL_REFORCO)
	ui._acao_forjar()
	await process_frame
	check(g3.arma_atual == "facao_fazenda_eco", "botão Temperar faz o reforço")
	_depois_do_reforco(g3)
	ui._atualizar_tudo()
	await process_frame
	check(ui.entradas()[0] == UI.ESPECIAL_ECO, "na etapa do eco a escolha aparece no topo")
	ui.selecionado = UI.ESPECIAL_ECO
	ui._mostrar(UI.ESPECIAL_ECO)
	await process_frame
	check(ui.botoes_eco.size() == 2, "dois cartões de eco com botão")
	ui._ir_para_acoes()
	await process_frame
	check(_foco() == ui.botoes_eco[0], "Enter na entrada do eco foca o primeiro cartão")
	root.push_input(_tecla(KEY_RIGHT))
	await process_frame
	check(_foco() == ui.botoes_eco[1], "→ passa para o Eco pesado")
	var esc := []
	ui.eco_escolhido.connect(func(v): esc.append(v))
	await _enter()
	check(esc == ["eco_pesado"] and g3.variacao_eco == "eco_pesado", "Enter escolhe o Eco pesado")
	var fechou := []
	ui.fechada.connect(func(): fechou.append(1))
	ui._focar_lista()
	await process_frame
	root.push_input(_tecla(KEY_ESCAPE))
	await process_frame
	check(fechou.size() == 1 and not ui.visible, "Esc na lista fecha (sinal fechada)")
	ui.queue_free()
	g.free()
	g3.free()
