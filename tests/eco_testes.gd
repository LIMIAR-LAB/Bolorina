extends SceneTree
## Testes headless do protótipo do eco temporal (scenes/prototipos/eco/). PROPOSTA.
## godot --headless --path . --fixed-fps 60 -s res://tests/eco_testes.gd
const Eco = preload("res://scripts/prototipos/eco/eco_temporal.gd")
const Alvo = preload("res://scripts/prototipos/eco/alvo_treino.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")

var ok_n := 0
var falhas: Array = []

class GerenciadorFalso:
	extends RefCounted
	var variacao_eco := ""
	var eventos: Array = []
	var itens: Array = []
	func notificar(evento: String, alvo: String = "", qtd: int = 1) -> void:
		eventos.append([evento, alvo, qtd])
	func coletar_item(id: String, qtd: int = 1) -> void:
		itens.append([id, qtd])
	func contar(evento: String, alvo := "") -> int:
		var n := 0
		for e in eventos:
			if e[0] == evento and (alvo == "" or e[1] == alvo):
				n += 1
		return n

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
	print("== eco_testes ==")
	_testar_logica()
	await _testar_alvos()
	await _testar_arena()
	await _testar_missao_real()
	Engine.time_scale = 1.0
	print("\nRESULTADO eco_testes: %s  (%d ok, %d falhas)" % ["PASS" if falhas.is_empty() else "FAIL", ok_n, falhas.size()])
	for f in falhas:
		print("  - ", f)
	quit(0 if falhas.is_empty() else 1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# ------------------------------------------------------------------ 1) lógica pura
func _testar_logica() -> void:
	print("\n-- eco_temporal.gd (tabela da missão) --")
	var e = Eco.new()
	check(e.atual == "eco_base" and is_equal_approx(e.atraso(), 0.6) and is_equal_approx(e.dano_relativo(), 0.6) and is_equal_approx(e.raio(), 1.6), "eco base 0,6 s / 60% / 1,6 m")
	check(is_equal_approx(e.atraso("eco_rapido"), 0.35) and is_equal_approx(e.dano_relativo("eco_rapido"), 0.45) and is_equal_approx(e.bonus_dash("eco_rapido"), 0.1), "rápido 0,35 s / 45% / dash −0,1 s")
	check(is_equal_approx(e.atraso("eco_pesado"), 0.9) and is_equal_approx(e.dano_relativo("eco_pesado"), 1.0) and is_equal_approx(e.raio("eco_pesado"), 2.2) and e.quebra_guarda("eco_pesado"), "pesado 0,9 s / 100% / 2,2 m / quebra guarda")
	check(not e.quebra_guarda("eco_base") and not e.quebra_guarda("eco_rapido") and e.bonus_dash("eco_base") == 0.0, "só o pesado quebra guarda; só o rápido mexe no dash")
	check(not e.definir("eco_inexistente") and e.atual == "eco_base", "variação desconhecida é recusada")
	var leve := {"tipo": "combo", "indice": 0, "pesado": false, "origem": Vector3.ZERO, "dir": Vector3.FORWARD, "alcance": 2.2, "dano": 10}
	var pesado := {"tipo": "combo", "indice": 2, "pesado": true, "origem": Vector3(1, 0, 2), "dir": Vector3(0, 0, -1), "alcance": 2.7, "dano": 24}
	check(e.registrar(leve, 0.0).is_empty() and e.pendentes.is_empty(), "golpe leve não deixa eco")
	check(e.registrar({"tipo": "especial", "pesado": true, "dano": 30}, 0.0).is_empty(), "especial não deixa eco")
	var marcados := []
	e.eco_marcado.connect(func(x): marcados.append(x))
	var x: Dictionary = e.registrar(pesado, 10.0)
	check(marcados.size() == 1 and int(x.dano) == 14 and x.centro.is_equal_approx(Vector3(1, 0, 2) + Vector3(0, 0, -1) * 2.7 * 0.55), "3º golpe marca eco: dano 24×60%=14, centro na frente")
	check(e.atualizar(10.59).is_empty() and e.atualizar(10.6).size() == 1 and e.pendentes.is_empty(), "dispara exatamente 0,6 s depois")
	check(is_equal_approx(Eco.progresso(x, 10.3), 0.5), "progresso do relógio no meio = 0,5")
	e.definir("eco_rapido")
	var r: Dictionary = e.registrar(pesado, 0.0)
	check(int(r.dano) == 11 and is_equal_approx(float(r.t_disparo), 0.35) and is_equal_approx(float(r.bonus_dash), 0.1), "rápido: 11 de dano, 0,35 s, bônus de dash")
	e.definir("eco_pesado")
	var p: Dictionary = e.registrar(pesado, 0.0)
	check(int(p.dano) == 24 and bool(p.quebra_guarda) and is_equal_approx(float(p.raio), 2.2), "pesado: 24 de dano, quebra guarda, raio 2,2")
	check(Eco.dentro(p, p.centro + Vector3(2.5, 0, 0), 0.4) and not Eco.dentro(p, p.centro + Vector3(2.7, 0, 0), 0.4), "alcance do círculo (raio + tamanho do alvo)")
	check(e.registrar({"tipo": "combo", "pesado": true, "e_eco": true}, 0.0).is_empty(), "eco não gera eco de eco")
	check(e.registrar({"tipo": "combo", "pesado": false, "eco": true, "dano": 20}, 0.0).size() > 0, "golpe marcado com eco=true também deixa eco")
	e.limpar()
	check(e.pendentes.is_empty(), "limpar")

# ------------------------------------------------------------------ 2) alvos
func _testar_alvos() -> void:
	print("\n-- alvos e travas --")
	var t = Alvo.new().configurar("trava", "trava_x")
	root.add_child(t)
	var es = Alvo.new().configurar("escudeiro", "esc")
	root.add_child(es)
	var po = Alvo.new().configurar("poste", "poste")
	root.add_child(po)
	var bo = Alvo.new().configurar("boneco", "bon")
	root.add_child(bo)
	await process_frame
	var r: Dictionary = t.receber_golpe(24, Vector3.ZERO, true, false, false)
	check(r.acertou and r.bloqueado and not t.esta_aberta and r.texto.begins_with("CLANG"), "trava: golpe pesado normal faz CLANG e não abre")
	var abriu := []
	t.aberta.connect(func(_a): abriu.append(1))
	r = t.receber_golpe(14, Vector3.ZERO, false, true, false)
	check(r.abriu and t.esta_aberta and abriu.size() == 1, "trava: eco abre")
	check(not t.alvejavel() and not t.receber_golpe(14, Vector3.ZERO, false, true).acertou, "trava aberta não é mais alvo")
	r = es.receber_golpe(24, Vector3.ZERO, true, false, false)
	check(r.bloqueado and int(r.dano) == 5 and es.hp == 155, "escudeiro bloqueia até o 3º golpe (20%)")
	r = es.receber_golpe(14, Vector3.ZERO, false, true, false)
	check(r.bloqueado and es.guarda_ativa, "eco base também é bloqueado")
	r = es.receber_golpe(24, Vector3.ZERO, true, true, true)
	check(r.quebrou_guarda and not r.bloqueado and int(r.dano) == 24 and not es.guarda_ativa, "eco pesado quebra a guarda e entra cheio")
	r = es.receber_golpe(10, Vector3.ZERO, false, false, false)
	check(not r.bloqueado and int(r.dano) == 10, "guarda quebrada: golpe leve entra cheio")
	for i in 200:
		await process_frame
	check(es.guarda_ativa, "guarda volta depois de 3 s")
	var hp0: int = po.hp
	po.receber_golpe(50, Vector3.ZERO, true, true)
	check(po.hp == hp0 and po.golpes == 1 and po.ecos == 1, "poste não cai e conta golpes/ecos")
	bo.receber_golpe(100, Vector3.ZERO, true)
	r = bo.receber_golpe(60, Vector3.ZERO, true)
	check(r.derrubado and bo.caido and not bo.alvejavel(), "boneco cai com 160 de dano")
	for i in 170:
		await process_frame
	check(not bo.caido and bo.hp == bo.hp_max, "boneco levanta")
	for n in [t, es, po, bo]:
		n.queue_free()

# ------------------------------------------------------------------ 3) arena jogável (sem janela)
func _tecla(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	return ev

func _posicionar(a, alvo: Node3D, de: Vector3, dist := 1.6) -> Vector3:
	var d := de.normalized()
	a.jogador.position = alvo.global_position + d * dist
	a.jogador.velocity = Vector3.ZERO
	a.jogador._virar(-d)
	return -d

func _combo(a, dir: Vector3) -> void:
	for i in 3:
		a.jogador.pedir_ataque(dir)
		await _frames(13)

func _esperar_eco(a, n_antes: int, maximo := 150) -> void:
	for i in maximo:
		if int(a.stats.ecos_disparados) > n_antes and a.eco.pendentes.is_empty():
			break
		await physics_frame
	await _frames(4)

func _testar_arena() -> void:
	print("\n-- arena do eco --")
	var a = load("res://scenes/prototipos/eco/arena_eco.tscn").instantiate()
	a.modo_teste = true
	var gf := GerenciadorFalso.new()
	a.gerenciador = gf
	root.add_child(a)
	await _frames(5)
	check(a.jogador != null and a.alvos.size() == 4 and a.bate != null and a.bate.travas.size() == 3, "arena montada: Vale, poste, 2 bonecos, escudeiro, Bate-Estaca com 3 travas")
	check(a.jogador.sprite != null and a.jogador.sprite.sprite_frames.has_animation("c_slash_combo_east"), "Vale usa as folhas vale_combate_gamelab")
	a.processar_entrada(_tecla(KEY_2))
	check(a.eco.atual == "eco_rapido" and gf.variacao_eco == "eco_rapido", "tecla 2 = eco rápido (e avisa o gerenciador)")
	a.processar_entrada(_tecla(KEY_3))
	check(a.eco.atual == "eco_pesado", "tecla 3 = eco pesado")
	a.processar_entrada(_tecla(KEY_1))
	check(a.eco.atual == "eco_base", "tecla 1 = eco")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_DPAD_UP
	jb.pressed = true
	a.processar_entrada(jb)
	check(a.eco.atual == "eco_rapido", "direcional ↑ = eco rápido")
	a.processar_entrada(_tecla(KEY_1))
	# eco base no boneco A
	var ba: Node3D = a.alvos[1]
	var dir := _posicionar(a, ba, Vector3(0, 0, 1))
	var marcados := []
	var disparos := []
	var acertos := []
	a.eco_marcado.connect(func(e): marcados.append(e))
	a.eco_disparou.connect(func(e, n): disparos.append([e, n, a.tempo]))
	a.eco_acertou.connect(func(id, d, v): acertos.append([id, d, v]))
	var hp0: int = ba.hp
	await _combo(a, dir)
	check(marcados.size() == 1 and a.stats.ecos_marcados == 1, "3º golpe do combo marca 1 eco (os dois primeiros não)")
	check(a._visuais.size() == 1 and a._visuais.values()[0].has("fantasma") and a._visuais.values()[0].has("anel"), "telegrafia: relógio no chão + fantasma da Vale")
	var f: AnimatedSprite3D = a._visuais.values()[0].fantasma
	check(f.modulate.a > 0.2 and f.sprite_frames == a.jogador.sprite.sprite_frames, "fantasma visível com os quadros da Vale")
	var hp_antes_eco: int = ba.hp
	check(hp_antes_eco < hp0, "combo acertou o boneco (%d → %d)" % [hp0, hp_antes_eco])
	await _esperar_eco(a, 0)
	check(disparos.size() == 1, "eco disparou")
	var le: Dictionary = a.log_ecos[0]
	check(absf(float(le.disparado) - float(le.marcado) - 0.6) < 0.02, "atraso medido %.3f s (≈0,6)" % (float(le.disparado) - float(le.marcado)))
	check(acertos.size() >= 1 and acertos[0][0] == "boneco_a" and int(acertos[0][1]) == 14 and ba.hp == hp_antes_eco - 14, "eco acerta o boneco no mesmo lugar: 14 de dano")
	check(gf.contar("eco_acertou", "boneco_a") >= 1, "gerenciador recebe notificar('eco_acertou', 'boneco_a')")
	check(a._visuais.is_empty(), "relógio some depois do disparo")
	check(a.stats.hitstops >= 2 and a.stats.numeros >= 4, "hitstop e números de dano")
	await _frames(20)
	check(is_equal_approx(Engine.time_scale, 1.0), "tempo volta ao normal depois do hitstop")
	# eco rápido: tira 0,1 s do dash
	a.processar_entrada(_tecla(KEY_2))
	ba.hp = ba.hp_max
	dir = _posicionar(a, ba, Vector3(0, 0, 1))
	await _frames(30)
	var n0: int = a.stats.ecos_disparados
	await _combo(a, dir)
	a.jogador.dash_cd_ate = a.jogador.relogio + 2.0
	var cd_antes: float = a.jogador.dash_cd_ate
	await _esperar_eco(a, n0)
	var le2: Dictionary = a.log_ecos[a.log_ecos.size() - 1]
	check(String(le2.variacao) == "eco_rapido" and absf(float(le2.disparado) - float(le2.marcado) - 0.35) < 0.02, "eco rápido dispara em 0,35 s")
	check(is_equal_approx(a.jogador.dash_cd_ate, cd_antes - 0.1) and a.stats.dash_bonus >= 1, "acerto do eco rápido tira 0,1 s da recarga do dash")
	check(int(acertos[acertos.size() - 1][1]) == 11, "eco rápido: 11 de dano")
	# eco pesado no escudeiro
	a.processar_entrada(_tecla(KEY_3))
	var es: Node3D = a.alvos[3]
	dir = _posicionar(a, es, Vector3(0, 0, 1))
	await _frames(30)
	var bloq0: int = a.stats.bloqueios
	n0 = a.stats.ecos_disparados
	await _combo(a, dir)
	check(a.stats.bloqueios >= bloq0 + 3 and es.guarda_ativa, "escudeiro bloqueia os 3 golpes do combo")
	await _esperar_eco(a, n0)
	var le3: Dictionary = a.log_ecos[a.log_ecos.size() - 1]
	check(absf(float(le3.disparado) - float(le3.marcado) - 0.9) < 0.03, "eco pesado dispara em 0,9 s")
	check(a.stats.guardas_quebradas == 1 and not es.guarda_ativa, "eco pesado quebra a guarda")
	# golpe pesado direto
	await _frames(40)
	n0 = a.stats.ecos_marcados
	check(a.golpe_pesado_direto(dir), "H / LB: golpe pesado direto")
	await _frames(20)
	check(a.stats.ecos_marcados == n0 + 1, "golpe pesado direto também deixa eco")
	await _esperar_eco(a, a.stats.ecos_disparados - 0)
	await _frames(60)
	# Bate-Estaca
	a.processar_entrada(_tecla(KEY_1))
	var bate = a.bate
	var abertos := []
	a.bate_estaca_aberto.connect(func(): abertos.append(1))
	var t0: Node3D = bate.travas[0]
	var fora: Vector3 = t0.global_position - bate.global_position
	dir = _posicionar(a, t0, fora, 1.6)
	await _frames(30)
	var clang0: int = a.stats.clangs
	a.jogador.pedir_ataque(dir)
	await _frames(40)
	check(a.stats.clangs == clang0 + 1 and not t0.esta_aberta, "trava: golpe normal faz CLANG")
	for i in 3:
		var t: Node3D = bate.travas[i]
		fora = t.global_position - bate.global_position
		dir = _posicionar(a, t, fora, 1.6)
		await _frames(45)
		n0 = a.stats.ecos_disparados
		await _combo(a, dir)
		check(not t.esta_aberta, "trava %d: o combo sozinho não abre" % (i + 1))
		await _esperar_eco(a, n0)
		check(t.esta_aberta, "trava %d: o eco abre" % (i + 1))
	check(bate.abertas == 3 and bate.esta_aberto and abertos.size() == 1, "3 travas abertas: Bate-Estaca para")
	check(gf.contar("trava_acertada_eco", "bate_estaca") == 3, "gerenciador recebe 3× trava_acertada_eco")
	var outras_abertas := 0
	for t in bate.travas:
		if t.esta_aberta:
			outras_abertas += 1
	check(outras_abertas == 3, "cada eco abriu só a trava da vez")
	a.jogador.position = bate.posicao_catraca() + Vector3(0.3, 0, 0.3)
	a.jogador.position.y = 0
	await _frames(5)
	check(bate.catraca_pega and gf.itens.size() == 1 and gf.itens[0][0] == "catraca_mestra", "Catraca-Mestra coletada → coletar_item('catraca_mestra')")
	# pancada do pilão
	a.reiniciar()
	await _frames(5)
	a.jogador.position = a.bate.global_position + Vector3(0.4, 0, 0.4)
	a.jogador.invulneravel_ate = 0.0
	var hp_v: int = a.jogador.hp
	await _frames(200)
	check(a.jogador.hp < hp_v and a.stats.pancadas >= 1, "pilão do Bate-Estaca machuca quem fica embaixo (ciclo de 3 s)")
	check(a.bate.abertas == 0 and a.bate.travas.size() == 3, "R reinicia o Bate-Estaca")
	a.queue_free()
	await _frames(3)

# ------------------------------------------------------------------ 4) ligado ao gerenciador de missões de verdade
func _testar_missao_real() -> void:
	print("\n-- ganchos com a missão (etapa testar_arena) --")
	var est = Estado.new()
	var g = Gerenciador.new(est)
	root.add_child(g)
	est.marcar("tutorial_pulado")
	est.marcar("atrasada_conta_lida")
	est.marcar("atrasada_defeito_visto")
	est.marcar("atrasada_gaspar_explicou_minas")
	g.notificar("forja_reforco_feito", "facao_fazenda")
	g.chegou_area("minas_andar_1")
	g.notificar("eco_acertou", "lodo_casca_grossa")
	g.notificar("inimigo_derrotado", "lodo_casca_grossa", 3)
	g.chegou_area("minas_andar_4")
	g.notificar("trava_acertada_eco", "bate_estaca", 3)
	g.coletar_item("catraca_mestra")
	g.chegou_area("porto_velho")
	est.marcar("atrasada_peca_entregue")
	est.marcar("atrasada_eco_pesado")
	g.chegou_area("arena_das_cinzas")
	var m = g.missao("atrasada_desde_amanha")
	check(String(m.etapa_atual().get("id", "")) == "testar_arena" and g.variacao_eco == "eco_pesado", "missão em testar_arena com eco pesado")
	var a = load("res://scenes/prototipos/eco/arena_eco.tscn").instantiate()
	a.modo_teste = true
	a.gerenciador = g
	root.add_child(a)
	await _frames(5)
	check(a.eco.atual == "eco_pesado", "arena começa na variação escolhida na forja")
	var p: Node3D = a.alvos[0]
	var dir := _posicionar(a, p, Vector3(0, 0, 1))
	for i in 3:
		var n0: int = a.stats.ecos_disparados
		await _combo(a, dir)
		await _esperar_eco(a, n0)
		await _frames(20)
	check(String(m.etapa_atual().get("id", "")) == "religar_guindaste", "3 acertos de eco no poste concluem 'Prova na Arena'")
	a.queue_free()
	await _frames(3)
	g.free()
