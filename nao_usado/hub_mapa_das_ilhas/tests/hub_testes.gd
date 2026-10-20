extends SceneTree
## Testes headless do mapa das ilhas e da viagem entre áreas (PROPOSTA).
##   godot --headless --path . -s res://tests/hub_testes.gd
## Cobre: registro (todas as áreas com cena, arte, chegada), varredura de cenas .tscn (órfãs),
## a tela do mapa (ilhas, bloqueio, seleção), tecla M (abre/fecha com pausa) e, para cada área,
## ida a partir do hub (Porto Velho, doca do dirigível -> mapa -> Viajar), chegada em chão
## caminhável, saída física existente e volta ao hub.
const Registro = preload("res://scripts/mundo/registro_areas.gd")
const Viagem = preload("res://scripts/mundo/viagem.gd")
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const HUB := "porto_velho"
const ORDEM := ["fazenda_do_alto", "vila_da_ilha", "arena_das_cinzas", "vila_orcs", "cidade_fantasma",
	"estacao_depois_de_ontem", "minas_da_cinza", "criptas_de_cinzalta", "fenda_cronal"]

var falhas: Array = []
var total := 0
var relatorio := {}
var viajante: Node

func ok(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		falhas.append(msg)
		print("  FALHOU: ", msg)

func _init() -> void:
	call_deferred("_rodar")

func _rodar() -> void:
	OS.set_environment("ILHA_SEM_SAVE", "1")   # o gerenciador da ilha não grava save
	Viagem.animacao_rapida = true
	var so := OS.get_environment("HUB_TESTE_SO")
	var t0 := Time.get_ticks_msec()
	if so == "" or so.contains("registro"): _teste_registro()
	if so == "" or so.contains("cenas"): _teste_cenas()
	if so == "" or so.contains("mapa"): await _teste_mapa()
	if so == "" or so.contains("viagens"): await _teste_viagens()
	relatorio["tempo_s"] = (Time.get_ticks_msec() - t0) / 1000.0
	print("[hub_testes] RELATORIO ", JSON.stringify(relatorio))
	print("[hub_testes] %d verificações, %d falhas" % [total, falhas.size()])
	for f in falhas:
		print("  - ", f)
	quit(1 if falhas.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

# ------------------------------------------------------------------ 1. registro
func _teste_registro() -> void:
	print("[hub_testes] registro")
	var erros: Array = Registro.validar()
	for e in erros:
		print("    ", e)
	ok(erros.is_empty(), "registro_areas.validar() sem erros (%d)" % erros.size())
	var ids := Registro.ids()
	for id in [HUB] + ORDEM:
		ok(ids.has(id), "área %s no registro" % id)
		var a := Registro.area(id)
		ok(a.has("mapa"), "%s aparece no mapa" % id)
		ok(FileAccess.file_exists(String(a.get("arte", ""))), "%s tem ilustração %s" % [id, a.get("arte", "")])
		var p := Viagem.ponto_padrao(id)
		ok(not Registro.ponto(id, p).is_empty(), "%s tem ponto de chegada pelo mapa (%s)" % [id, p])
		for k in a.get("mapa", {}).get("rotas", []) + a.get("mapa", {}).get("ligada_a", []):
			ok(Registro.existe(String(k)), "%s: rota para área existente %s" % [id, k])
	ok(Registro.carregar().get("hub", "") == HUB, "hub do registro é Porto Velho")
	relatorio["areas"] = ids

# ------------------------------------------------------------------ 2. varredura de cenas
func _listar(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for s in d.get_directories():
		if s.begins_with(".") or s == "addons" or s == "_bmad" or s == "_bmad-output":
			continue
		_listar(dir.path_join(s), out)

func _teste_cenas() -> void:
	print("[hub_testes] varredura de cenas")
	var todas: Array = []
	_listar("res://", todas)
	var no_mapa := {}
	for a in Registro.areas():
		no_mapa[String(a.cena)] = String(a.id)
	var fora := {}
	for f in Registro.carregar().get("fora_do_mapa", []):
		fora[String(f.cena)] = String(f.motivo)
	var orfas: Array = []
	var lista := {}
	for c in todas:
		if no_mapa.has(c):
			lista[c] = "área: " + no_mapa[c]
		elif fora.has(c):
			lista[c] = "fora do mapa: " + fora[c]
		else:
			orfas.append(c)
			lista[c] = "ÓRFÃ (sem área e sem motivo)"
	for c in orfas:
		print("    órfã: ", c)
	if not orfas.is_empty():
		print("    AVISO: %d cena(s) sem área e sem motivo em fora_do_mapa (órfãs)" % orfas.size())
	ok(no_mapa.size() >= 8, "cenas de área encontradas na varredura")
	for c in fora:
		ok(ResourceLoader.exists(c), "cena listada em fora_do_mapa existe: %s" % c)
	relatorio["cenas"] = lista
	relatorio["orfas"] = orfas

# ------------------------------------------------------------------ 3. tela do mapa
func _esperar(cond: Callable, limite := 900) -> bool:
	for i in limite:
		await process_frame
		if cond.call():
			return true
	return false

func _teste_mapa() -> void:
	print("[hub_testes] tela do mapa")
	Viagem.visitadas = {}
	Viagem.desbloquear_tudo = false
	change_scene_to_file(Viagem.MAPA)
	var abriu: bool = await _esperar(func(): return current_scene != null and current_scene.scene_file_path == Viagem.MAPA and current_scene.ilhas.size() > 0)
	ok(abriu, "mapa_mundi.tscn abre como cena")
	if not abriu:
		return
	await _frames(3)
	var m = current_scene
	ok(m.ilhas.size() == Viagem.areas_do_mapa().size() and m.ilhas.size() >= 10, "mapa mostra %d ilhas" % m.ilhas.size())
	ok(m.rotas.ligacoes.size() >= 10, "rotas desenhadas (%d)" % m.rotas.ligacoes.size())
	ok(Viagem.desbloqueada(HUB) and Viagem.desbloqueada("fazenda_do_alto"), "hub e fazenda liberados no começo")
	ok(not Viagem.desbloqueada("fenda_cronal") and not Viagem.desbloqueada("vila_orcs"), "fenda e vila dos orcs bloqueadas no começo")
	m.selecionar("fenda_cronal")
	ok(m.b_viajar.disabled and m.p_estado.text.contains("Bloqueada"), "painel mostra bloqueada e desliga Viajar")
	ok(not await m.viajar_para("fenda_cronal"), "Viajar numa ilha bloqueada não viaja")
	m.selecionar(HUB)
	ok(not m.b_viajar.disabled and m.p_nome.text == "Porto Velho", "painel do hub: nome e Viajar ligado")
	ok(m.p_arte.texture != null, "painel mostra a ilustração")
	viajante = root.get_node_or_null("Viajante")
	ok(viajante != null, "viajante instalado na raiz")
	m.viajar_para(HUB)
	var chegou: bool = await _esperar(func(): return Viagem.area_atual(self) == HUB and viajante.ultima_chegada.get("area", "") == HUB)
	ok(chegou, "Viajar do mapa (tela) leva a Porto Velho")
	if chegou:
		await _frames(4)
		ok(Viagem.desbloqueada("vila_orcs"), "visitar Porto Velho libera a Vila dos Orcs")
		# tecla M
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_M
		ev.keycode = KEY_M
		ev.pressed = true
		root.push_input(ev)
		await _frames(3)
		ok(viajante.mapa_aberto_agora() and paused, "M abre o mapa por cima e pausa o jogo")
		if viajante.mapa_aberto_agora():
			ok(viajante.mapa.area_atual == HUB, "mapa marca 'você está aqui' em Porto Velho")
		var ev2 := ev.duplicate()
		root.push_input(ev2)
		await _frames(3)
		ok(not viajante.mapa_aberto_agora() and not paused, "M de novo fecha o mapa e despausa")

# ------------------------------------------------------------------ 4. ida e volta de cada área
func _jogador(c: Node) -> Node3D:
	for k in ["jogador", "player"]:
		var j = c.get(k)
		if j is Node3D:
			return j
	if c.get("atual") is Node:
		return _jogador(c.atual)
	return null

func _cena_area() -> Node:
	var c := current_scene
	if c and c.get("atual") is Node:
		return c.atual
	return c

func _chegar(id: String) -> bool:
	return await _esperar(func(): return Viagem.area_atual(self) == id and viajante.ultima_chegada.get("area", "") == id and _jogador(current_scene) != null and current_scene.get("ocupado") != true, 1500)

## chão caminhável: fica no chão (move_and_slide), não afunda, não está dentro de nada e, se houver navmesh, está nela
func _checar_chao(id: String, res: Dictionary) -> void:
	var c := _cena_area()
	var j := _jogador(current_scene)
	var p0 := j.global_position
	await _frames(30)
	var p1 := j.global_position
	var no_chao := (j as CharacterBody3D).is_on_floor() if j is CharacterBody3D else false
	# a jogadora de combate não usa gravidade: confere o chão com um raio para baixo
	var rq := PhysicsRayQueryParameters3D.create(p1 + Vector3(0, 1.0, 0), p1 + Vector3(0, -0.6, 0))
	rq.exclude = [(j as CollisionObject3D).get_rid()] if j is CollisionObject3D else []
	var chao := j.get_world_3d().direct_space_state.intersect_ray(rq)
	var raio_ok: bool = not chao.is_empty() and chao.normal.y > 0.7 and absf(chao.position.y - p1.y) < 0.45
	ok(no_chao or raio_ok, "%s: jogadora nasce no chão (is_on_floor=%s, chão por raio=%s)" % [id, no_chao, raio_ok])
	no_chao = no_chao or raio_ok
	ok(absf(p1.y - p0.y) < 1.0 and p1.y > -5.0, "%s: não cai do mapa (y %.2f -> %.2f)" % [id, p0.y, p1.y])
	var esp := j.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, p1 + Vector3(0, 0.95, 0))
	q.exclude = [(j as CollisionObject3D).get_rid()] if j is CollisionObject3D else []
	var dentro := esp.intersect_shape(q, 4)
	ok(dentro.is_empty(), "%s: chegada não fica dentro de colisor (%s)" % [id, dentro.map(func(h): return String(h.collider.name))])
	res["chegada"] = [snappedf(p1.x, 0.01), snappedf(p1.y, 0.01), snappedf(p1.z, 0.01)]
	res["no_chao"] = no_chao
	# navmesh: cidades CC0 assam na hora; masmorras já têm
	var mapa_nav: RID = j.get_world_3d().navigation_map
	var tem_nav := false
	if c.has_method("assar_navegacao") and c.get("navegacao") == null:
		var it := NavigationServer3D.map_get_iteration_id(mapa_nav)
		c.assar_navegacao()
		for i in 240:
			await physics_frame
			if NavigationServer3D.map_get_iteration_id(mapa_nav) != it and NavigationServer3D.map_get_closest_point(mapa_nav, p1) != Vector3.ZERO:
				break
		tem_nav = true
	elif c.get("navegacao") != null:
		tem_nav = true
	if tem_nav:
		var nq := NavigationServer3D.map_get_closest_point(mapa_nav, p1)
		var dn := Vector2(nq.x - p1.x, nq.z - p1.z).length()
		ok(dn < 1.0, "%s: chegada está na malha de navegação (%.2f m)" % [id, dn])
		res["dist_navmesh_m"] = snappedf(dn, 0.01)
		var alvo := Vector3.INF
		if c.has_method("marcador") and c.marcador("spawn_jogador"):
			alvo = c.marcador("spawn_jogador").global_position
		var saida: Node3D = null
		for nome in ["Marcadores/escada_descer", "Marcadores/saida_origem"]:
			if saida == null and c.get("marcadores") != null:
				saida = c.get_node_or_null(nome)
		if saida:
			alvo = saida.global_position
		if alvo != Vector3.INF and alvo.distance_to(p1) > 2.0:
			var cam := NavigationServer3D.map_get_path(mapa_nav, p1, alvo, true)
			var alc := cam.size() > 0 and Vector2(cam[cam.size() - 1].x - alvo.x, cam[cam.size() - 1].z - alvo.z).length() < 1.5
			ok(alc, "%s: da chegada dá para andar até %s" % [id, String(saida.name) if saida else "o centro da cidade"])
			res["caminho_ate"] = String(saida.name) if saida else "spawn_jogador"

func _saida(id: String, res: Dictionary) -> Node:
	var c := _cena_area()
	var tipo := String(Registro.area(id).get("tipo", ""))
	var pv: Node = null
	for n in get_nodes_in_group("ponto_viagem"):
		if is_instance_valid(n) and n.pronto and c.is_ancestor_of(n):
			pv = n
	var saidas: Array = []
	if pv:
		saidas.append("ponto de viagem (%s)" % pv.dados.get("tipo", "totem"))
	if tipo == "masmorra":
		var so := c.get_node_or_null("Marcadores/saida_origem")
		ok(so != null, "%s: masmorra tem saída para a cidade (saida_origem)" % id)
		if so:
			saidas.append("saída para %s" % Registro.nome(Sessao.origem_area))
	else:
		ok(pv != null, "%s: tem ponto físico de viagem (doca/totem)" % id)
	if c.get("saidas") is Array and c.saidas.size() > 0:
		saidas.append("%d saídas a pé" % c.saidas.size())
	if c.get_node_or_null("SaidaIlha"):
		saidas.append("B/Esc volta ao vilarejo")
	saidas.append("tecla M")
	res["saidas"] = saidas
	ok(saidas.size() >= 2, "%s: tem saída além da tecla M" % id)
	return pv

func _ir_pelo_ponto(pv: Node, destino: String) -> bool:
	var mapa: Control = pv.abrir_mapa()
	await _frames(2)
	if mapa == null or not viajante.mapa_aberto_agora():
		return false
	if not mapa.ilhas.has(destino):
		return false
	mapa.selecionar(destino)
	return await mapa.viajar_para(destino)

func _teste_viagens() -> void:
	print("[hub_testes] ida e volta de cada área a partir do hub")
	if viajante == null:
		Viagem.ir(self, HUB)
		await _frames(2)
		viajante = root.get_node_or_null("Viajante")
	var r := {}
	for id in ORDEM:
		var res := {}
		# 1. estar no hub
		if Viagem.area_atual(self) != HUB:
			Viagem.garantir_viajante(self).partir(HUB)
			await _chegar(HUB)
		await _frames(4)
		var pv_hub: Node = null
		for n in get_nodes_in_group("ponto_viagem"):
			if is_instance_valid(n) and n.pronto:
				pv_hub = n
		ok(pv_hub != null, "%s: doca do dirigível no hub" % id)
		if pv_hub == null:
			continue
		ok(Viagem.desbloqueada(id), "%s: liberada quando chega a vez (%s)" % [id, Viagem.requisito(id)])
		# 2. ida pelo mapa
		var foi: bool = await _ir_pelo_ponto(pv_hub, id)
		ok(foi, "%s: doca -> mapa -> Viajar" % id)
		var chegou: bool = await _chegar(id)
		ok(chegou, "%s: cena carregada e chegada tratada" % id)
		if not chegou:
			r[id] = res
			continue
		await _frames(6)
		res["cena"] = current_scene.scene_file_path
		var pt := Registro.ponto(id, Viagem.ponto_padrao(id))
		if pt.has("pos"):
			var j := _jogador(current_scene)
			var d := Vector2(j.global_position.x - float(pt.pos[0]), j.global_position.z - float(pt.pos[1])).length()
			ok(d < 1.5, "%s: nasce no ponto do registro (%.2f m)" % [id, d])
		if String(Registro.area(id).get("tipo", "")) == "masmorra":
			var m = current_scene
			ok(m.andar == int(pt.get("andar", 1)), "%s: começa no andar %d" % [id, int(pt.get("andar", 1))])
			res["origem"] = Sessao.origem_area
		await _checar_chao(id, res)
		# 3. saída
		var pv := _saida(id, res)
		# 4. volta
		var voltou := false
		if String(Registro.area(id).get("tipo", "")) == "masmorra":
			var origem := Sessao.origem_area
			current_scene.sair_para_origem()
			var na_cidade: bool = await _chegar(origem)
			ok(na_cidade, "%s: saída da masmorra volta para %s" % [id, origem])
			if na_cidade:
				await _frames(4)
				var pvc: Node = null
				for n in get_nodes_in_group("ponto_viagem"):
					if is_instance_valid(n) and n.pronto:
						pvc = n
				if origem == HUB:
					voltou = true
				elif pvc:
					voltou = await _ir_pelo_ponto(pvc, HUB) and await _chegar(HUB)
		elif pv:
			voltou = await _ir_pelo_ponto(pv, HUB) and await _chegar(HUB)
		ok(voltou, "%s: volta ao hub (Porto Velho)" % id)
		if voltou:
			await _frames(4)
			var pvh := Registro.ponto(HUB, "viagem") if String(Registro.area(id).get("tipo", "")) != "masmorra" or Sessao.origem_area != HUB else Registro.ponto(HUB, Sessao.origem_ponto)
			var j := _jogador(current_scene)
			var d := Vector2(j.global_position.x - float(pvh.pos[0]), j.global_position.z - float(pvh.pos[1])).length()
			ok(d < 1.5, "%s: volta para a doca/entrada certa do hub (%.2f m)" % [id, d])
			res["volta_hub_dist_m"] = snappedf(d, 0.01)
		r[id] = res
	relatorio["viagens"] = r
	relatorio["visitadas"] = Viagem.visitadas.keys()
