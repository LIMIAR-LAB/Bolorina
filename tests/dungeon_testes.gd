extends SceneTree
## Testes headless da masmorra procedural (PROPOSTA).
##   godot --headless --path . -s res://tests/dungeon_testes.gd
## Cobre: geração determinística por semente, todos os andares alcançáveis (chegada -> escada/chefe
## -> saída) pelo navmesh, inimigos nascendo, inimigo morto por golpes roteirizados da jogadora com
## loot indo para o inventário, andar do chefe (chefe morto -> baú + portal), registro de áreas e
## as 4 entradas das cidades carregando a masmorra e voltando.
const GeradorTema = preload("res://scripts/dungeon/gerador_masmorra.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const TEMAS := ["minas_da_cinza", "criptas_de_cinzalta", "fenda_cronal"]

var falhas: Array = []
var total := 0
var relatorio := {}

func ok(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		falhas.append(msg)
		print("  FALHOU: ", msg)

func _init() -> void:
	call_deferred("_rodar")

func _rodar() -> void:
	var so := OS.get_environment("DUNGEON_TESTE_SO")
	var t0 := Time.get_ticks_msec()
	if so == "" or so.contains("semente"): _teste_semente()
	if so == "" or so.contains("andares"): await _teste_andares()
	if so == "" or so.contains("combate"): await _teste_combate()
	if so == "" or so.contains("chefe"): await _teste_chefes()
	if so == "" or so.contains("registro"): _teste_registro()
	if so == "" or so.contains("cidades"): await _teste_cidades()
	relatorio["tempo_s"] = (Time.get_ticks_msec() - t0) / 1000.0
	print("[dungeon_testes] RELATORIO ", JSON.stringify(relatorio))
	print("[dungeon_testes] %d verificações, %d falhas" % [total, falhas.size()])
	for f in falhas:
		print("  - ", f)
	quit(1 if falhas.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# ------------------------------------------------------------------ 1. semente
func _teste_semente() -> void:
	print("[dungeon_testes] semente fixa / aleatória")
	var r := {}
	for t in TEMAS:
		for a in [int(Sessao.andares(t)[0]), int(Sessao.andares(t).back())]:
			var g1 = GeradorTema.new(t, a, 4242)
			g1.gerar()
			var g2 = GeradorTema.new(t, a, 4242)
			g2.gerar()
			var g3 = GeradorTema.new(t, a, 4243)
			g3.gerar()
			ok(g1.grade == g2.grade and g1.entrada == g2.entrada and g1.escada == g2.escada and g1.alvo_chefe == g2.alvo_chefe, "%s andar %d: mesma semente gera o mesmo andar" % [t, a])
			ok(g1.grade != g3.grade, "%s andar %d: semente diferente gera outro andar" % [t, a])
			ok(g1.distancia.size() > 80, "%s andar %d: chão suficiente (%d)" % [t, a, g1.distancia.size()])
			r["%s_%d" % [t, a]] = {"estilo": g1.estilo, "grade": "%dx%d" % [g1.w, g1.h], "chao": g1.distancia.size()}
	Sessao.iniciar("fenda_cronal", "estacao_depois_de_ontem", "fenda_temporal", 1, 99)
	ok(Sessao.semente_fixa and Sessao.semente_run == 99, "semente fixa pela sessão")
	var s1 := Sessao.semente_do_andar(2)
	Sessao.iniciar("fenda_cronal", "estacao_depois_de_ontem", "fenda_temporal", 1, 99)
	ok(s1 == Sessao.semente_do_andar(2), "semente do andar estável com semente fixa")
	var vistos := {}
	for k in 4:
		Sessao.iniciar("fenda_cronal", "", "", 1)
		vistos[Sessao.semente_run] = true
	ok(not Sessao.semente_fixa and vistos.size() >= 3, "semente aleatória por incursão (%d distintas em 4)" % vistos.size())
	relatorio["geracao"] = r

# ------------------------------------------------------------------ 2. todos os andares
func _cena(t: String, a: int, semente: int) -> Node:
	Sessao.iniciar(t, String(Sessao.dados_tema(t).get("origem_padrao", "")), "", a, semente)
	var n = load(Registro.cena(t)).instantiate()
	n.modo_teste = true
	var mapa: RID = root.get_world_3d().navigation_map
	var antes := NavigationServer3D.map_get_iteration_id(mapa)
	root.add_child(n)
	for i in 60:
		await physics_frame
		if i > 2 and NavigationServer3D.map_get_iteration_id(mapa) != antes:
			break
	await _frames(2)
	return n

func _alcanca(mapa: RID, de: Vector3, para: Vector3) -> bool:
	var p := NavigationServer3D.map_get_path(mapa, de, para, true)
	return p.size() > 0 and Vector2(p[p.size() - 1].x - para.x, p[p.size() - 1].z - para.z).length() < 1.3

func _teste_andares() -> void:
	print("[dungeon_testes] todos os andares: chegada -> escada/chefe -> saída")
	var r := {}
	for t in TEMAS:
		var d := Sessao.dados_tema(t)
		for a in Sessao.andares(t):
			var n = await _cena(t, a, 777)
			var mapa: RID = n.get_world_3d().navigation_map
			var sp: Vector3 = n.marcador("spawn_jogador").global_position
			var saida: Marker3D = n.marcador("saida_origem")
			var escada: Marker3D = n.marcador("escada_descer")
			var chefe_andar: bool = a == int(d.andar_chefe)
			var fim: Vector3
			if chefe_andar:
				ok(escada == null, "%s %d: andar do chefe sem escada" % [t, a])
				var ch = n.combate.chefe()
				ok(ch != null and ch.tipo_id == String(d.chefe), "%s %d: chefe %s nasce" % [t, a, d.chefe])
				fim = ch.global_position if ch else sp
			else:
				ok(escada != null and int(escada.get_meta("destino_andar")) == Sessao.proximo_andar(t, a), "%s %d: escada para o andar %d" % [t, a, Sessao.proximo_andar(t, a)])
				fim = escada.global_position if escada else sp
			ok(saida != null and String(saida.get_meta("destino")) == "origem", "%s %d: saída de volta para a cidade" % [t, a])
			var ida := _alcanca(mapa, sp, fim)
			var volta := saida != null and _alcanca(mapa, fim, saida.global_position)
			ok(ida, "%s %d: chegada alcança %s" % [t, a, "o chefe" if chefe_andar else "a escada"])
			ok(volta, "%s %d: %s alcança a saída" % [t, a, "o chefe" if chefe_andar else "a escada"])
			var vivos: int = n.combate.vivos().size()
			ok(vivos > 0 and vivos == n.inimigos.get_child_count(), "%s %d: inimigos nascem (%d)" % [t, a, vivos])
			ok(n.baus.size() >= 1, "%s %d: baú(s) (%d)" % [t, a, n.baus.size()])
			ok(n.nos_minerio.get_child_count() > 0, "%s %d: nós de minério (%d)" % [t, a, n.nos_minerio.get_child_count()])
			var mats := {}
			for mk in n.nos_minerio.get_children():
				mats[String(mk.get_meta("material"))] = true
			var tipos := {}
			for e in n.combate.vivos():
				tipos[e.tipo_id] = int(tipos.get(e.tipo_id, 0)) + 1
			r["%s_%02d" % [t, a]] = {"estilo": n.g.estilo, "inimigos": tipos, "baus": n.baus.size(), "minerio": mats.keys(), "ida": ida, "volta": volta}
			n.free()
			await _frames(2)
	relatorio["andares"] = r

# ------------------------------------------------------------------ 3. combate + loot
func _bater_ate_morrer(n, e, limite: int) -> bool:
	var j = n.jogador
	j.invulneravel_ate = 1e9
	e.acordar()
	var mapa: RID = n.get_world_3d().navigation_map
	for i in limite:
		await physics_frame
		if not is_instance_valid(e) or not e.vivo:
			return true
		if i % 12 == 0:
			var dir: Vector3 = e.global_position - j.global_position
			dir.y = 0
			if dir.length() > 1.6 or dir.length() < 0.5:
				var lado := Vector3(1, 0, 1).normalized()
				var alvo := NavigationServer3D.map_get_closest_point(mapa, e.global_position + lado * 1.3)
				j.global_position = Vector3(alvo.x, 0, alvo.z)
				dir = e.global_position - j.global_position
				dir.y = 0
			j.invulneravel_ate = j.relogio + 1e6
			j.pedir_ataque(dir.normalized())
	return not is_instance_valid(e) or not e.vivo

func _teste_combate() -> void:
	print("[dungeon_testes] inimigo morto por golpes roteirizados -> loot -> inventário")
	var r := {}
	for t in TEMAS:
		var n = await _cena(t, int(Sessao.andares(t)[0]), 31)
		Sessao.inventario = {"itens": {}}
		var j = n.jogador
		var alvo = null
		var dmin := 1e9
		for e in n.combate.vivos():
			if e.comportamento in ["fantasma", "olho"]:
				continue
			var dd: float = e.global_position.distance_to(j.global_position)
			if dd < dmin:
				dmin = dd
				alvo = e
		if alvo == null:
			alvo = n.combate.vivos()[0]
		var tipo: String = alvo.tipo_id
		var hp0: int = alvo.hp
		var golpes0: int = n.combate.stats.acertos
		var morreu: bool = await _bater_ate_morrer(n, alvo, 1500)
		ok(morreu, "%s: %s morre com golpes da jogadora" % [t, tipo])
		ok(n.combate.stats.acertos > golpes0, "%s: golpes acertaram (%d)" % [t, n.combate.stats.acertos - golpes0])
		# espera o fim da animação de morte (sinal morto -> loot)
		for i in 180:
			await physics_frame
			if n.combate.stats.inimigos_mortos >= 1:
				break
		ok(n.combate.stats.inimigos_mortos >= 1, "%s: sinal morto emitido" % t)
		var drops: Array = n.combate.pickups.duplicate()
		ok(drops.size() > 0, "%s: loot caiu no chão (%d)" % [t, drops.size()])
		# a jogadora anda até o loot (o ímã recolhe)
		var esperado := {}
		for p in drops:
			esperado[String(p.get_meta("item"))] = int(esperado.get(String(p.get_meta("item")), 0)) + int(p.get_meta("qtd"))
		for p in drops:
			if is_instance_valid(p):
				j.global_position = Vector3(p.global_position.x, 0, p.global_position.z)
				await _frames(40)
		var ok_inv := true
		for id in esperado:
			if Sessao.qtd(id) < int(esperado[id]):
				ok_inv = false
		ok(ok_inv and not esperado.is_empty(), "%s: loot no inventário %s" % [t, JSON.stringify(Sessao.inventario.itens)])
		# baú do andar
		var bau = n.baus[0] if n.baus.size() > 0 else null
		if bau:
			j.global_position = Vector3(bau.global_position.x + 1.0, 0, bau.global_position.z)
			await _frames(2)
			var itens: Dictionary = n.abrir_bau(bau)
			ok(not itens.is_empty(), "%s: baú dá materiais da forja %s" % [t, JSON.stringify(itens)])
			n.combate.coletar_tudo()
			var todos := true
			for id in itens:
				if Sessao.qtd(id) < int(itens[id]):
					todos = false
			ok(todos, "%s: itens do baú no inventário" % t)
		# minério
		var mk = null
		for m in n.nos_minerio.get_children():
			if n.forja.pode_minerar(String(m.get_meta("material")), Sessao.picareta):
				mk = m
				break
		if mk:
			var res: Dictionary = n.minerar(String(mk.name), Sessao.picareta, Sessao.inventario)
			ok(res.get("ok", false) and Sessao.qtd(String(res.material)) >= int(res.quantidade), "%s: mineração vai para o inventário (%s)" % [t, mk.name])
		r[t] = {"inimigo": tipo, "hp": hp0, "inventario": Sessao.inventario.itens.duplicate(), "acertos": n.combate.stats.acertos, "dano_recebido": n.combate.stats.dano_recebido}
		n.free()
		await _frames(2)
	relatorio["combate"] = r

# ------------------------------------------------------------------ 4. chefes
func _teste_chefes() -> void:
	print("[dungeon_testes] andar do chefe: chefe morto -> baú do chefe + portal")
	var r := {}
	for t in TEMAS:
		var d := Sessao.dados_tema(t)
		var n = await _cena(t, int(d.andar_chefe), 55)
		Sessao.inventario = {"itens": {}}
		var ch = n.combate.chefe()
		ok(ch != null, "%s: chefe existe" % t)
		if ch == null:
			continue
		var nome: String = ch.def.nome
		var hp0: int = ch.hp_max
		n.jogador.multiplicador_dano = 8.0
		var morreu: bool = await _bater_ate_morrer(n, ch, 2400)
		ok(morreu, "%s: %s derrotado" % [t, nome])
		for i in 200:
			await physics_frame
			if n.chefe_derrotado:
				break
		ok(n.chefe_derrotado, "%s: chefe_derrotado marcado" % t)
		var bau = null
		for b in n.baus:
			if String(b.name) == "bau_do_chefe":
				bau = b
		ok(bau != null, "%s: baú do chefe aparece" % t)
		ok(n.portal_volta != null and String(n.portal_volta.get_meta("destino")) == "origem", "%s: portal de volta aparece" % t)
		if bau:
			var itens: Dictionary = n.abrir_bau(bau)
			n.combate.coletar_tudo()
			ok(itens.size() >= 2, "%s: baú do chefe %s" % [t, JSON.stringify(itens)])
		ok(Sessao.chefes_derrotados.has(t), "%s: sessão lembra o chefe derrotado" % t)
		r[t] = {"chefe": nome, "hp": hp0, "fase": ch.fase if is_instance_valid(ch) else 2, "invocados": n.combate.inimigos.size(), "inventario": Sessao.inventario.itens.duplicate()}
		n.free()
		await _frames(2)
	relatorio["chefes"] = r

# ------------------------------------------------------------------ 5. registro
func _teste_registro() -> void:
	print("[dungeon_testes] registro de áreas")
	var erros: Array = Registro.validar()
	for e in erros:
		print("    ", e)
	ok(erros.is_empty(), "registro_areas.validar() sem erros (%d)" % erros.size())
	for t in TEMAS:
		ok(Registro.existe(t) and Registro.cena(t) == "res://scenes/dungeon/%s.tscn" % t, "área %s registrada com a cena" % t)
	ok(Registro.cidades().size() >= 4, "4 cidades no registro")
	relatorio["registro"] = {"areas": Registro.ids(), "erros": erros}

# ------------------------------------------------------------------ 6. cidades
func _esperar_cena(cond: Callable, limite := 600) -> bool:
	for i in limite:
		await process_frame
		if current_scene and cond.call(current_scene):
			return true
	return false

func _teste_cidades() -> void:
	print("[dungeon_testes] entradas das cidades -> masmorra -> volta")
	var r := {}
	for c in Registro.cidades():
		var id := String(c.id)
		for e in c.get("entradas_de_masmorra", []):
			var res := {}
			change_scene_to_file(String(c.cena))
			var chegou: bool = await _esperar_cena(func(s): return s.scene_file_path == String(c.cena))
			ok(chegou, "%s: cena da cidade carrega" % id)
			await _frames(4)
			var ent = null
			for x in get_nodes_in_group("entrada_masmorra"):
				if x.entrada_id == String(e.id):
					ent = x
			ok(ent != null and ent.pronto, "%s: entrada %s montada" % [id, e.id])
			if ent == null:
				continue
			var mapa = current_scene
			mapa.jogador.position = ent.ponto_de_volta() + Vector3(0, 0.3, 0)
			await _frames(4)
			ok(ent.perto and ent.prompt.visible, "%s: prompt [E] aparece perto da entrada" % id)
			ok(ent.rotulo != null and ent.rotulo.text != "", "%s: rótulo visível" % id)
			ent.abrir_menu()
			await process_frame
			ok(ent.menu != null and mapa.demo_mode, "%s: menu abre (e trava a jogadora)" % id)
			ent.fechar_menu()
			ok(ent.menu == null and not mapa.demo_mode, "%s: Cancelar fecha o menu" % id)
			ent.abrir_menu()
			var tema_esperado := String(Registro.area(String(e.area)).get("tema", e.area))
			var andar_esperado := int(Registro.ponto(String(e.area), String(e.ponto)).get("andar", 1))
			ent.entrar(321)
			var entrou: bool = await _esperar_cena(func(s): return s.get("tema") == tema_esperado and s.get("combate") != null)
			ok(entrou, "%s: Entrar carrega %s" % [id, tema_esperado])
			if not entrou:
				continue
			var m = current_scene
			ok(m.andar == andar_esperado, "%s: começa no andar %d (%d)" % [id, andar_esperado, m.andar])
			ok(Sessao.origem_area == id and Sessao.origem_ponto == String(e.id), "%s: sessão lembra a origem" % id)
			res["masmorra"] = "%s andar %d" % [m.tema, m.andar]
			await _frames(3)
			m.sair_para_origem()
			var voltou: bool = await _esperar_cena(func(s): return s.scene_file_path == String(c.cena))
			ok(voltou, "%s: saída da masmorra volta para a cidade" % id)
			if voltou:
				await _frames(6)
				var pv: Vector3 = Vector3.ZERO
				for x in get_nodes_in_group("entrada_masmorra"):
					if x.entrada_id == String(e.id):
						pv = x.ponto_de_volta()
				var jp: Vector3 = current_scene.jogador.position
				var dist := Vector2(jp.x - pv.x, jp.z - pv.z).length()
				ok(dist < 1.5, "%s: jogadora volta para a frente da entrada (%.2f m)" % [id, dist])
				res["volta_dist_m"] = snappedf(dist, 0.01)
			r["%s/%s" % [id, e.id]] = res
	relatorio["cidades"] = r
