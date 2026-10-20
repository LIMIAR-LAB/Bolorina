extends SceneTree
## Testes da missão "Atrasada desde amanhã", dos moradores principais, das cenas de ambiente e do tutorial (PROPOSTA).
## Rodar:  godot --headless --path . -s res://tests/missao_testes.gd
## 1) todo .dialogue novo compila, tem cues e só usa falantes do registro (ou Vale / narração);
## 2) todo {arquivo, cue} citado nos JSON existe;
## 3) todo cue novo é percorrido em todos os ramos até o fim;
## 4) toda marca citada (tem(), condições, exige/proibe) é marcada em algum lugar;
## 5) a missão roda do começo ao fim com eventos roteirizados, em 3 caminhos (seguro, arriscado, fiado),
##    usando as conversas de verdade (as marcas vêm dos .dialogue);
## 6) itens obrigatórios e reservas não podem ser gastos como excedente;
## 7) o tutorial conclui todos os passos, pode ser pulado inteiro, por passo e pela escolha no primeiro diálogo;
## 8) seletor de diálogos, cenas de ambiente, moradores e save/load.

const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const Gerenciador = preload("res://scripts/missoes/gerenciador_missoes.gd")
const Tutorial = preload("res://scripts/tutorial/tutorial.gd")
const Cond = preload("res://scripts/missoes/condicoes.gd")

const PASTAS_NOVAS := ["res://dialogos/missao_atrasada/", "res://dialogos/reacoes/", "res://dialogos/tutorial/"]
const JSONS := ["res://data/missoes/atrasada_desde_amanha.json", "res://data/missoes/moradores_principais.json",
	"res://data/missoes/cenas_ambiente.json", "res://data/tutorial/tutorial.json"]

var checks := 0
var failures := 0
var dm
var _cache := {}
var _cues := {}

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	dm = root.get_node_or_null("DialogueManager")
	check(dm != null, "autoload DialogueManager presente")
	if dm == null:
		_fim()
		return
	_testar_compilacao()
	_testar_referencias()
	await _testar_ramos()
	_testar_marcas()
	_testar_dados()
	await _cenario_seguro()
	await _cenario_arriscado()
	await _cenario_fiado()
	_testar_reservas()
	await _testar_tutorial()
	_testar_save()
	_fim()

func _fim() -> void:
	Estado.reiniciar_global()
	_cache.clear()
	print("\n%s: %d verificacoes, %d falhas" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	await process_frame
	quit(0 if failures == 0 else 1)

# ------------------------------------------------------------------ utilitários

func _arquivos_novos() -> Array:
	var r: Array = []
	for p in PASTAS_NOVAS:
		var d := DirAccess.open(p)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".dialogue"):
				r.append(p + f)
	r.sort()
	return r

func _todos_dialogos() -> Array:
	var r: Array = []
	var pilha: Array = ["res://dialogos/"]
	while not pilha.is_empty():
		var p: String = pilha.pop_back()
		var d := DirAccess.open(p)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".dialogue"):
				r.append(p + f)
		for sub in d.get_directories():
			pilha.append(p + sub + "/")
	return r

func _compilar(caminho: String):
	return DMCompiler.compile_string(FileAccess.get_file_as_string(caminho), caminho)

func _recurso(caminho: String) -> Resource:
	if _cache.has(caminho):
		return _cache[caminho]
	var r = _compilar(caminho)
	var res := DialogueResource.new()
	res.using_states = r.using_states
	res.cues = r.cues
	res.first_cue = r.first_cue
	res.character_names = r.character_names
	res.lines = r.lines
	_cache[caminho] = res
	_cues[caminho] = r.cues.keys() if r.cues is Dictionary else Array(r.cues)
	return res

func _json(c: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(c))
	return d if d is Dictionary else {}

## Roda uma conversa (escolhas pela lista; falta = 0). Devolve {linhas, falantes, escolhas, passos}.
func _rodar(caminho: String, cue: String, estado, roteiro: Array = []) -> Dictionary:
	var recurso := _recurso(caminho)
	var linhas := 0
	var falantes := {}
	var vistas: Array = []
	var passos := 0
	var linha = await dm.get_next_dialogue_line(recurso, cue, [estado])
	while linha != null and passos < 300:
		passos += 1
		if String(linha.text) != "":
			linhas += 1
			falantes[String(linha.character)] = true
		if linha.responses.size() > 0:
			var k := vistas.size()
			var i := int(roteiro[k]) if k < roteiro.size() else 0
			i = clampi(i, 0, linha.responses.size() - 1)
			vistas.append(linha.responses.size())
			linha = await dm.get_next_dialogue_line(recurso, linha.responses[i].next_id, [estado])
		else:
			linha = await dm.get_next_dialogue_line(recurso, linha.next_id, [estado])
	return {"linhas": linhas, "falantes": falantes, "escolhas": vistas, "passos": passos}

## Conversa com o morador do jeito que o jogo faria: pergunta ao gerenciador qual conversa usar.
func _falar(g, npc: String, roteiro: Array = [], esperado_cue := "") -> Dictionary:
	var d: Dictionary = g.dialogo_para(npc)
	if d.is_empty():
		check(false, "dialogo_para(%s) devolveu vazio (esperado %s)" % [npc, esperado_cue])
		return {}
	if esperado_cue != "":
		check(String(d.cue) == esperado_cue, "dialogo_para(%s) -> %s (%s)" % [npc, esperado_cue, String(d.cue)])
	return await _rodar(String(d.arquivo), String(d.cue), g.estado, roteiro)

func _interagir(g, alvo: String, roteiro: Array = [], esperado_cue := "") -> void:
	var d: Dictionary = g.interacao(alvo)
	if d.is_empty():
		check(false, "interacao(%s) devolveu vazio" % alvo)
		return
	if esperado_cue != "":
		check(String(d.cue) == esperado_cue, "interacao(%s) -> %s (%s)" % [alvo, esperado_cue, String(d.cue)])
	await _rodar(String(d.arquivo), String(d.cue), g.estado, roteiro)

func _etapa(g) -> String:
	var m = g.missao("atrasada_desde_amanha")
	var e: Dictionary = m.etapa_atual()
	return String(e.get("id", "(" + m.situacao + ")"))

# ------------------------------------------------------------------ 1) compilação e falantes

func _testar_compilacao() -> void:
	var arquivos := _arquivos_novos()
	check(arquivos.size() >= 18, "%d arquivos .dialogue novos encontrados" % arquivos.size())
	for c in arquivos:
		var r = _compilar(c)
		var erros: Array = []
		for e in r.errors:
			erros.append("linha %d: %s" % [e.line_number + 1, DMConstants.get_error_message(e.error)])
		check(r.errors.size() == 0, "%s compila sem erros %s" % [c.get_file(), "" if erros.is_empty() else str(erros)])
		_recurso(c)
		check(_cues[c].size() >= 1, "%s tem %d cues" % [c.get_file(), _cues[c].size()])
		var estranhos: Array = []
		for nome in r.character_names:
			if String(nome) != "Vale" and Registro.id_por_nome(String(nome)) == "":
				estranhos.append(nome)
		check(estranhos.is_empty(), "%s: todos os falantes estão no registro %s" % [c.get_file(), str(estranhos)])
		check(ResourceLoader.exists(c), "%s importado (load() funciona no jogo)" % c.get_file())

# ------------------------------------------------------------------ 2) referências {arquivo, cue}

func _refs() -> Array:
	var r: Array = []
	var q := _json(JSONS[0])
	for e in q.etapas + q.opcionais:
		for npc in e.get("dialogos", {}):
			r.append([e.dialogos[npc].arquivo, e.dialogos[npc].cue, "dialogos " + e.id])
		for a in e.get("interacoes", {}):
			r.append([e.interacoes[a].arquivo, e.interacoes[a].cue, "interacao " + a])
		for ef in [e.get("ao_iniciar", {}), e.get("ao_concluir", {})]:
			if ef.has("dialogo_pos"):
				r.append([ef.dialogo_pos.arquivo, ef.dialogo_pos.cue, "dialogo_pos " + e.id])
	var mor := _json(JSONS[1])
	for id in mor.moradores:
		var arq: String = "res://dialogos/reacoes/" + id + ".dialogue"
		for rr in mor.moradores[id].reacoes:
			r.append([rr.get("arquivo", arq), rr.cue, "reacao " + id])
		for per in mor.moradores[id].rotina:
			r.append([arq, mor.moradores[id].rotina[per].cue, "rotina %s %s" % [id, per]])
	var cen := _json(JSONS[2])
	for c in cen.cenas:
		r.append([cen.arquivo, c.cue, "cena " + c.id])
		if c.has("cue_disfarce"):
			r.append([cen.arquivo, c.cue_disfarce, "cena disfarce " + c.id])
	var tut := _json(JSONS[3])
	for p in tut.passos:
		for k in ["dialogo", "dialogo_ao_concluir"]:
			if p.has(k):
				r.append([p[k].arquivo, p[k].cue, "tutorial " + p.id])
	return r

func _testar_referencias() -> void:
	for c in JSONS:
		check(not _json(c).is_empty(), "%s é JSON válido" % c.get_file())
	var refs := _refs()
	var ruins: Array = []
	for ref in refs:
		var arq := String(ref[0])
		if not FileAccess.file_exists(arq):
			ruins.append("%s: arquivo %s" % [ref[2], arq])
			continue
		_recurso(arq)
		if not String(ref[1]) in _cues[arq]:
			ruins.append("%s: cue %s em %s" % [ref[2], ref[1], arq.get_file()])
	check(ruins.is_empty(), "%d referências {arquivo, cue} dos JSON existem %s" % [refs.size(), str(ruins)])

# ------------------------------------------------------------------ 3) todos os ramos

func _testar_ramos() -> void:
	var total_ramos := 0
	var total_linhas := 0
	var problemas: Array = []
	for c in _arquivos_novos():
		_recurso(c)
		for cue in _cues[c]:
			for estado_base in [false, true]:
				var fila: Array = [[]]
				var ramos := 0
				while not fila.is_empty() and ramos < 40:
					var roteiro: Array = fila.pop_front()
					var est = Estado.new()
					if estado_base:
						_estado_rico(est)
					var r := await _rodar(c, String(cue), est, roteiro)
					ramos += 1
					total_linhas += int(r.linhas)
					if int(r.passos) >= 300:
						problemas.append("%s/%s não termina" % [c.get_file(), cue])
					if int(r.linhas) == 0 and not estado_base:
						problemas.append("%s/%s sem falas" % [c.get_file(), cue])
					var vistas: Array = r.escolhas
					for k in range(roteiro.size(), vistas.size()):
						for alt in range(1, int(vistas[k])):
							var novo: Array = roteiro.duplicate()
							while novo.size() < k:
								novo.append(0)
							novo.append(alt)
							fila.append(novo)
				total_ramos += ramos
	check(problemas.is_empty(), "todos os cues novos terminam e têm falas %s" % str(problemas))
	check(total_ramos >= 120, "%d ramos percorridos (%d falas)" % [total_ramos, total_linhas])

## Estado com as marcas de "meio de jogo" ligadas, para exercitar os ramos condicionais.
func _estado_rico(est) -> void:
	for m in ["atrasada_gaspar_explicou_minas", "atrasada_pista_mira", "atrasada_peca_recuperada", "atrasada_pode_pagar_eco",
			"atrasada_provisao_lampiao", "zeca_pediu_recado", "atrasada_amostra_raspada", "atrasada_arena_testada",
			"atrasada_eco_pesado", "tiao_recebeu_recado"]:
		est.marcas[m] = true

# ------------------------------------------------------------------ 4) marcas

func _testar_marcas() -> void:
	var re_marcar := RegEx.create_from_string("marcar\\(\"([^\"]+)\"\\)")
	var re_tem := RegEx.create_from_string("tem\\(\"([^\"]+)\"\\)")
	var marcadas := {}
	var citadas := {}
	for c in _todos_dialogos():
		var txt := FileAccess.get_file_as_string(c)
		for mm in re_marcar.search_all(txt):
			marcadas[mm.get_string(1)] = true
		if c.begins_with("res://dialogos/missao_atrasada/") or c.begins_with("res://dialogos/reacoes/") or c.begins_with("res://dialogos/tutorial/"):
			for mm in re_tem.search_all(txt):
				citadas[mm.get_string(1)] = c.get_file()
	var g = Gerenciador.new(Estado.new())
	for m in g.marcas_que_escreve():
		marcadas[m] = true
	g.free()
	var tut := _json(JSONS[3])
	marcadas[String(tut.marca_pulado)] = true
	marcadas[String(tut.marca_concluido)] = true
	for p in tut.passos:
		for mk in p.get("marcas_ao_concluir", []):
			marcadas[mk] = true
		for mk in Cond.marcas_citadas([p.get("gatilho", {})] + p.get("conclusao", [])):
			citadas[mk] = "tutorial.json " + p.id
	var q := _json(JSONS[0])
	for mk in Cond.marcas_citadas(q.inicio.condicoes):
		citadas[mk] = "inicio"
	for e in q.etapas + q.opcionais:
		for mk in Cond.marcas_citadas(e.get("condicoes", []) + e.get("pular_quando", [])):
			citadas[mk] = "missao " + e.id
		for esc in e.get("escolhas", []):
			citadas[esc.marca] = "escolha " + e.id
		for k in e.get("efeitos_marca", {}):
			citadas[k] = "efeitos_marca " + e.id
		for a in e.get("interacoes", {}):
			for k in ["quando", "nao_quando"]:
				if e.interacoes[a].has(k):
					citadas[e.interacoes[a][k]] = "interacao " + a
	var mor := _json(JSONS[1])
	citadas[mor.marca_pos_missao] = "moradores"
	for id in mor.moradores:
		for rr in mor.moradores[id].reacoes:
			for mk in rr.get("exige", []) + rr.get("proibe", []):
				citadas[mk] = "reacao " + id
	for c in _json(JSONS[2]).cenas:
		for mk in c.get("exige", []) + c.get("proibe", []):
			citadas[mk] = "cena " + c.id
	var soltas: Array = []
	for mk in citadas:
		if not marcadas.has(mk):
			soltas.append("%s (%s)" % [mk, citadas[mk]])
	check(soltas.is_empty(), "%d marcas citadas, todas marcadas em algum lugar %s" % [citadas.size(), str(soltas)])
	check(citadas.size() >= 40, "cobertura de marcas razoável (%d)" % citadas.size())

# ------------------------------------------------------------------ 8a) dados

func _testar_dados() -> void:
	var mor: Dictionary = _json(JSONS[1]).moradores
	check(mor.size() == 6, "6 moradores principais (%d)" % mor.size())
	var na_missao := 0
	for id in mor:
		var m: Dictionary = mor[id]
		check(Registro.existe(id), "morador %s existe no registro" % id)
		var ok := true
		for k in ["desejo", "contradicao", "relacao", "situacao", "mudanca", "rotina"]:
			if not m.has(k) or str(m[k]) == "":
				ok = false
		for per in ["manha", "tarde", "noite", "pos_missao"]:
			if not m.rotina.has(per):
				ok = false
		check(ok, "%s tem desejo, contradição, relação, situação, mudança e rotina manhã/tarde/noite/pós" % id)
		check(Registro.existe(String(m.relacao.com)), "%s se relaciona com %s (existe)" % [id, m.relacao.com])
		if m.na_missao is bool and m.na_missao:
			na_missao += 1
	check(na_missao == 3, "3 moradores participam da missão principal (%d)" % na_missao)
	var cenas: Array = _json(JSONS[2]).cenas
	var ambiente := 0
	for c in cenas:
		if c.tipo == "ambiente":
			ambiente += 1
		for p in c.participantes:
			check(Registro.existe(String(p)), "cena %s: participante %s existe" % [c.id, p])
	check(ambiente >= 4 and ambiente <= 7, "%d cenas de ambiente" % ambiente)
	var q := _json(JSONS[0])
	check(q.etapas.size() >= 10, "missão com %d etapas" % q.etapas.size())
	var sem_texto: Array = []
	for e in q.etapas:
		if String(e.get("objetivo", "")) == "":
			sem_texto.append(e.id)
	check(sem_texto.is_empty(), "toda etapa tem texto de objetivo na tela %s" % str(sem_texto))

# ------------------------------------------------------------------ tutorial básico (usado pelos cenários)

func _tutorial_basico(g, t) -> void:
	var pedidos: Array = []
	t.dialogo_pedido.connect(func(npc, a, c): pedidos.append([npc, a, c]))
	t.notificar("jogo_iniciado")
	check(t.passo_atual().get("id", "") == "abertura" and t.fase == "ativo", "tutorial: abertura ativa")
	check(pedidos.size() == 1 and pedidos[0][2] == "chegada", "tutorial: pediu o diálogo de chegada")
	await _rodar(pedidos[0][1], pedidos[0][2], g.estado, [0])
	check(t.passo_atual().get("id", "") == "mover", "tutorial: mover (%s)" % t.passo_atual().get("id", ""))
	check(t.dica_atual().contains("WASD"), "tutorial: dica de movimento na tela")
	t.notificar("perto_de", "crianca_praca")
	check(t.passo_atual().get("id", "") == "conversar", "tutorial: conversar")
	await _falar(g, "crianca_praca", [1], "pipo")
	check(t.passo_atual().get("id", "") == "atacar", "tutorial: atacar")
	for i in 3:
		t.notificar("golpe_acertou", "sir_palha")
	check(t.passo_atual().get("id", "") == "atacar", "tutorial: 3 golpes sem golpe pesado ainda não concluem")
	t.notificar("golpe_pesado", "sir_palha")
	check(t.passo_atual().get("id", "") == "esquivar", "tutorial: esquivar")
	var m = g.missao("atrasada_desde_amanha")
	check(m.situacao == "inativa", "missão ainda não começou antes do fim do tutorial básico")
	t.notificar("esquivou", "sir_palha")
	for p in pedidos.slice(1):
		await _rodar(p[1], p[2], g.estado)
	check(g.estado.tem("tutorial_basico_concluido"), "tutorial básico concluído")

# ------------------------------------------------------------------ 5) cenário A: caminho seguro, eco rápido

func _cenario_seguro() -> void:
	print("\n-- cenario A: caminho seguro, eco rapido, tutorial completo --")
	var est = Estado.new()
	var g = Gerenciador.new(est)
	var t = Tutorial.new(est)
	g.tutorial = t
	var sinais := {"mundo": [], "etapas": [], "pedidos": [], "objetivos": [], "puladas": [], "tut_fim": [], "arma": [], "eco": []}
	g.mudanca_mundo.connect(func(id, _d): sinais.mundo.append(id))
	g.etapa_iniciada.connect(func(_m, e, _obj, _d): sinais.etapas.append(e))
	g.etapa_iniciada.connect(func(_m, _e, obj, _d): sinais.objetivos.append(obj))
	g.etapa_pulada.connect(func(_m, e): sinais.puladas.append(e))
	g.dialogo_pedido.connect(func(npc, a, c): sinais.pedidos.append([npc, a, c]))
	g.arma_trocada.connect(func(de, para): sinais.arma.append([de, para]))
	g.variacao_eco_alterada.connect(func(v, d): sinais.eco.append([v, d]))
	t.tutorial_concluido.connect(func(p): sinais.tut_fim.append(p))
	var tut_pedidos: Array = []
	t.dialogo_pedido.connect(func(npc, a, c): tut_pedidos.append(c))
	await _tutorial_basico(g, t)
	var m = g.missao("atrasada_desde_amanha")
	check(m.ativa() and _etapa(g) == "conta_impossivel", "missão começou sozinha: conta_impossivel")
	check(g.cenas_disponiveis("tarde").any(func(c): return c.id == "brida_entrega_envelope"), "cena do envelope disponível na abertura")
	check(g.dialogo_para("guardia").get("cue", "") == "entregou_conta", "Brida tem fala da missão na abertura")
	await _falar(g, "ferreiro", [0], "conta_impossivel")
	check(_etapa(g) == "ver_guindaste" and g.tem_item_missao("conta_impossivel"), "conta lida: ver_guindaste e Conta Impossível na mochila de missão")
	check(g.objetivo_atual().contains("guindaste"), "objetivo na tela fala do guindaste")
	await _interagir(g, "guindaste_doca", [0], "guindaste_rachando")
	check(_etapa(g) == "reforco_arma" and "guindaste_rachado" in sinais.mundo, "defeito visto: reforco_arma; guindaste rachado no mundo")
	await _falar(g, "ferreiro", [], "reforco")
	check(_etapa(g) == "reforco_arma" and est.tem("atrasada_gaspar_explicou_minas"), "Gaspar explicou; falta o reforço na forja")
	check(t.passo_atual().get("id", "") == "forja" and t.fase == "ativo", "tutorial: passo da forja ativou pela fala do Gaspar")
	t.notificar("forja_aberta")
	g.notificar("forja_reforco_feito", "facao_fazenda")
	t.notificar("forja_reforco_feito", "facao_fazenda")
	check(_etapa(g) == "provisao_fazenda" and est.tem("eco_desbloqueado"), "reforço feito: eco desbloqueado")
	check(sinais.arma.size() == 1 and sinais.arma[0][1] == "facao_fazenda_eco" and g.variacao_eco == "eco_base", "arma trocada e eco base")
	check(t.passo_atual().get("id", "") == "eco" and t.fase == "ativo", "tutorial: passo do eco ativou")
	check(sinais.pedidos.any(func(p): return p[2] == "reforco_pronto"), "pediu a fala do reforço pronto")
	# o Gaspar manda bater no poste: primeiro acerto de eco ainda na Ferraria
	g.notificar("eco_acertou", "poste_treino")
	t.notificar("eco_acertou", "poste_treino")
	check(_etapa(g) == "provisao_fazenda" and t.passo_atual().get("id", "") == "salvar" and t.fase == "aguardando", "eco no poste: tutorial do eco concluído, salvar aguardando")
	# não passa na fazenda: chegar na mina pula a provisão e vale para a próxima etapa
	g.chegou_area("minas_andar_1")
	t.notificar("chegou_area", "minas_andar_1")
	check("provisao_fazenda" in sinais.puladas and _etapa(g) == "minas_entrada", "provisão opcional pulada ao chegar na mina")
	check(t.passo_atual().get("id", "") == "salvar", "tutorial: salvar ativou na mina")
	t.notificar("jogo_salvo")
	await _falar(g, "minerador_aposentado", [], "elevador")
	check(t.passo_atual().get("id", "") == "mapa" and t.fase == "aguardando", "tutorial: salvar concluído, mapa aguardando")
	g.notificar("eco_acertou", "lodo_casca_grossa")
	g.notificar("inimigo_derrotado", "lodo_casca_grossa", 2)
	check(g.objetivo_atual().contains("2/3"), "progresso na tela: %s" % g.objetivo_atual())
	g.notificar("inimigo_derrotado", "lodo_casca_grossa")
	check(_etapa(g) == "bifurcacao", "lodos vencidos: bifurcação")
	check(int(g.materiais.get("minerio_cobre", 0)) == 5 and g.reservado("minerio_cobre") == 3 and g.excedente("minerio_cobre") == 2, "5 cobres: 3 reservados, 2 de excedente")
	await _interagir(g, "placa_bifurcacao", [0], "placa_bifurcacao")
	check(est.tem("atrasada_caminho_seguro"), "escolheu o trilho")
	g.chegou_area("minas_andar_4")
	check(_etapa(g) == "bate_estaca", "andar 4: Bate-Estaca")
	await _falar(g, "fantasma_mineiro", [0], "no_bate_estaca")
	for i in 3:
		g.notificar("trava_acertada_eco", "bate_estaca")
	check(_etapa(g) == "bate_estaca", "travas quebradas, falta pegar a peça")
	g.coletar_item("catraca_mestra")
	check(_etapa(g) == "voltar_ao_porto" and g.tem_item_missao("catraca_mestra") and int(g.materiais.get("catraca_mestra", 0)) == 0, "catraca na mochila de missão (fora dos materiais)")
	check(g.excedente("lasca_de_eco") == 3, "3 lascas de eco de excedente")
	var zeca: Array = sinais.pedidos.filter(func(p): return p[2] == "sexta_feira")
	check(zeca.size() == 1, "pediu o momento do Zeca")
	await _rodar(zeca[0][1], zeca[0][2], est, [0])
	check(est.tem("zeca_pediu_recado"), "Zeca pediu o recado")
	check(not g.pode_gastar({"catraca_mestra": 1}) and not g.gastar_excedente({"catraca_mestra": 1}), "catraca não pode ser gasta")
	check(not g.gastar_excedente({"minerio_cobre": 3}) and int(g.materiais.minerio_cobre) == 5, "não dá pra gastar o cobre reservado")
	g.chegou_area("porto_velho")
	check(_etapa(g) == "entregar_peca" and est.tem("primeira_expedicao_voltou"), "voltou: primeira expedição marcada")
	check(g.dialogo_para("estalajadeira").is_empty(), "Rosalva ainda não conhecida: usa o diálogo original")
	await _falar(g, "ferreiro", [0, 0], "entrega")
	check(est.tem("atrasada_eco_rapido") and not est.tem("atrasada_eco_fiado"), "escolheu eco rápido pagando")
	check(_etapa(g) == "testar_arena" and not g.tem_item_missao("catraca_mestra"), "peça entregue e consumida: testar_arena")
	check(int(g.materiais.get("minerio_cobre", 0)) == 0 and g.excedente("lasca_de_eco") == 0 and not g.reservas.has("minerio_cobre"), "custo do eco saiu do excedente e a reserva foi consumida")
	check(g.variacao_eco == "eco_rapido" and sinais.eco[-1][0] == "eco_rapido" and float(sinais.eco[-1][1].atraso_s) < 0.6, "variação eco rápido com dados")
	check(t.passo_atual().get("id", "") == "mapa" and t.fase == "ativo", "tutorial: mapa ativou depois da escolha do eco")
	t.notificar("mapa_aberto")
	t.notificar("teleportou")
	check(t.terminou() and sinais.tut_fim == [false], "tutorial concluído sem pular")
	check(tut_pedidos.has("forja") == false and tut_pedidos.has("eco") and tut_pedidos.has("mapa"), "dicas faladas do tutorial pedidas (eco, mapa; a da forja abre com a forja)")
	g.chegou_area("arena_das_cinzas")
	for i in 3:
		g.notificar("eco_acertou", "orc_de_palha")
	check(_etapa(g) == "religar_guindaste", "arena testada: religar_guindaste")
	var arena: Array = sinais.pedidos.filter(func(p): return p[2] == "fim_teste")
	await _rodar(arena[0][1], arena[0][2], est)
	await _falar(g, "capitao", [0], "guindaste_conserto")
	for w in ["guindaste_funcionando", "carga_movida", "passagem_armazem_aberta", "encomenda_estacao_apareceu"]:
		check(w in sinais.mundo and est.tem("mundo_" + w), "mudança no mundo: " + w)
	check(g.tem_item_missao("caixa_vidro_lanterna") and g.tem_item_missao("encomenda_estacao"), "caixa do vidro e encomenda da Estação na mochila")
	check(_etapa(g) == "entregar_vidro", "entregar_vidro")
	await _falar(g, "estalajadeira", [0], "vidro")
	check(_etapa(g) == "arquivar_conta" and not g.tem_item_missao("caixa_vidro_lanterna") and est.refeicao == "Prato de Volta", "Rosalva recebeu o vidro (e o prato de volta)")
	await _falar(g, "ferreiro", [1], "arquivar")
	check(m.concluida() and est.tem("missao_atrasada_concluida") and not est.tem("missao_atrasada_ativa"), "MISSÃO CONCLUÍDA")
	check("conta_emoldurada" in sinais.mundo and not g.tem_item_missao("conta_impossivel") and g.tem_item_missao("encomenda_estacao"), "conta arquivada; encomenda da Estação continua (gancho)")
	check(est.tem("gancho_estacao_depois_de_ontem") and est.tem("desbloqueado_rota_estacao_depois_de_ontem"), "gancho da Estação Depois-de-Ontem")
	check(int(g.materiais.get("ouro", 0)) == 120 and int(g.materiais.get("lingote_cobre", 0)) == 2 and est.confianca_de("capitao") >= 2, "recompensas finais")
	var ordem := ["conta_impossivel", "ver_guindaste", "reforco_arma", "provisao_fazenda", "minas_entrada", "bifurcacao", "bate_estaca", "voltar_ao_porto", "entregar_peca", "escolher_eco", "testar_arena", "religar_guindaste", "entregar_vidro", "arquivar_conta"]
	check(sinais.etapas == ordem, "etapas na ordem certa (%d)" % sinais.etapas.size())
	check(m.opcionais.pista_da_mira == "expirado" and m.opcionais.recado_do_zeca == "ativo", "pista da Mira expirou; recado do Zeca segue ativo (persistente)")
	# memória da cidade depois da missão
	await _falar(g, "minerador_aposentado", [0], "recado")
	check(m.opcionais.recado_do_zeca == "concluido" and "lamparina_andar_4" in sinais.mundo, "recado entregue depois da missão: lamparina no andar 4")
	check(g.dialogo_para("capitao").get("cue", "") == "guindaste_usado", "Capitão comenta o guindaste em uso")
	await _falar(g, "capitao", [], "guindaste_usado")
	check(g.dialogo_para("capitao").get("cue", "") == "arma_nova", "depois, o Capitão repara no facão novo")
	await _falar(g, "capitao", [], "arma_nova")
	check(g.dialogo_para("capitao").get("cue", "") == "pos_missao", "e depois volta à rotina pós-missão")
	check(g.dialogo_para("guardia").is_empty(), "Brida não conhecida: diálogo original primeiro")
	est.marcar("guardia_conheceu")
	check(g.dialogo_para("guardia").get("cue", "") == "guindaste_usado", "Brida comenta o beco aberto")
	await _falar(g, "ferreiro", [], "pos_missao")
	check(est.tem("reacao_ferreiro_divida_zeca"), "Gaspar perdoa a dívida do Zeca")
	var tarde: Array = g.cenas_disponiveis("tarde").map(func(c): return c.id)
	var noite: Array = g.cenas_disponiveis("noite").map(func(c): return c.id)
	check("recibo_do_dragao" in tarde and not "jucas_em_dobro" in tarde, "cenas da tarde depois da missão: %s" % str(tarde))
	check("gaspar_tiao_zeca" in noite and not "gaspar_tiao_rangido" in noite and "penumbra_na_porta" in noite, "cenas da noite: %s" % str(noite))
	g.cena_vista("penumbra_na_porta")
	check(not g.cenas_disponiveis("noite").any(func(c): return c.id == "penumbra_na_porta"), "cena vista não repete")
	g.free()
	t.free()

# ------------------------------------------------------------------ cenário B: arriscado, eco pesado, opcionais

func _cenario_arriscado() -> void:
	print("\n-- cenario B: tutorial pulado, pista da Mira, provisao, galeria, eco pesado --")
	var est = Estado.new()
	var g = Gerenciador.new(est)
	var t = Tutorial.new(est)
	g.tutorial = t
	var provisoes: Array = []
	var opc: Array = []
	g.provisao_escolhida.connect(func(p, _d): provisoes.append(p))
	g.opcional_concluido.connect(func(_m, o): opc.append(o))
	est.marcar("mira_conheceu")
	t.iniciar()
	t.pular_tudo()
	var m = g.missao("atrasada_desde_amanha")
	check(t.terminou() and t.foi_pulado and est.tem("tutorial_pulado") and m.ativa(), "tutorial pulado: missão começa")
	await _falar(g, "ferreiro", [1], "conta_impossivel")
	await _falar(g, "mira", [0], "pista")
	check(est.tem("atrasada_pista_mira"), "Mira deu a pista")
	await _interagir(g, "guindaste_doca", [], "raspar")
	check(g.tem_item_missao("amostra_ferrugem") and _etapa(g) == "ver_guindaste", "amostra raspada (a etapa principal continua)")
	await _interagir(g, "guindaste_doca", [1], "guindaste_rachando")
	await _falar(g, "mira", [], "pista")
	check("pista_da_mira" in opc and not g.tem_item_missao("amostra_ferrugem") and g.excedente("essencia_raiz_brasa") == 1, "Mira reconheceu a investigação: opcional concluído")
	check(g.dialogo_para("mira").get("cue", "") == "pista_reconhecida", "Mira lembra da pista depois")
	await _falar(g, "ferreiro", [], "reforco")
	g.notificar("forja_reforco_feito", "facao_fazenda")
	check(_etapa(g) == "provisao_fazenda", "provisão")
	await _interagir(g, "cesto_provisoes", [1], "provisao")
	check(provisoes == ["oleo_de_lampiao"] and _etapa(g) == "minas_entrada" and m.etapas_puladas.is_empty(), "provisão escolhida (óleo de lampião), etapa não pulada")
	g.chegou_area("minas_andar_1")
	g.notificar("inimigo_derrotado", "lodo_casca_grossa", 3)
	check(_etapa(g) == "minas_entrada", "sem acerto de eco o encontro da entrada não termina (ensina o eco)")
	g.notificar("eco_acertou", "lodo_casca_grossa")
	check(_etapa(g) == "bifurcacao", "bifurcação")
	await _falar(g, "vagoneta_falante", [1], "vagoneta_bifurcacao")
	check(est.tem("atrasada_caminho_arriscado") and m.opcionais.galeria_desabada == "ativo", "galeria arriscada escolhida")
	g.notificar("inimigo_derrotado", "morcego", 6)
	g.notificar("bau_aberto", "bau_galeria_desabada")
	check("galeria_desabada" in opc and g.excedente("lasca_de_eco") == 3 and int(g.materiais.minerio_cobre) == 9, "galeria vencida: +4 cobre, +3 lascas")
	g.chegou_area("minas_andar_4")
	for i in 3:
		g.notificar("trava_acertada_eco", "bate_estaca")
	g.coletar_item("catraca_mestra")
	g.chegou_area("porto_velho")
	check(g.dialogo_para("minerador_aposentado").is_empty(), "Tião nunca foi conhecido nesse caminho: diálogo original")
	await _falar(g, "ferreiro", [1, 1], "entrega")
	check(est.tem("atrasada_eco_pesado") and g.variacao_eco == "eco_pesado", "eco pesado")
	check(g.excedente("lasca_de_eco") == 3 and int(g.materiais.minerio_cobre) == 4, "sobrou excedente do caminho arriscado (3 lascas, 4 cobres)")
	g.chegou_area("arena_das_cinzas")
	g.notificar("eco_acertou", "*", 3)
	await _falar(g, "capitao", [1], "guindaste_conserto")
	await _falar(g, "estalajadeira", [1], "vidro")
	check(est.tem("rosalva_pensou_em_viajar"), "Rosalva pensou em viajar")
	await _falar(g, "ferreiro", [0], "arquivar")
	check(m.concluida(), "MISSÃO CONCLUÍDA pelo caminho arriscado")
	g.free()
	t.free()

# ------------------------------------------------------------------ cenário C: gastou o excedente -> fiado

func _cenario_fiado() -> void:
	print("\n-- cenario C: excedente gasto antes da escolha -> fiado, missao nao trava --")
	var est = Estado.new()
	var g = Gerenciador.new(est)
	est.marcar("tutorial_pulado")
	await _falar(g, "ferreiro", [], "conta_impossivel")
	await _interagir(g, "guindaste_doca", [], "guindaste_rachando")
	await _falar(g, "ferreiro", [], "reforco")
	g.notificar("forja_reforco_feito", "facao_fazenda")
	g.chegou_area("minas_andar_1")
	g.notificar("eco_acertou", "lodo_casca_grossa")
	g.notificar("inimigo_derrotado", "lodo_casca_grossa", 3)
	g.chegou_area("minas_andar_4")
	g.notificar("trava_acertada_eco", "bate_estaca", 3)
	g.coletar_item("catraca_mestra")
	g.chegou_area("porto_velho")
	check(g.gastar_excedente({"lasca_de_eco": 3, "minerio_cobre": 2}), "gastou o excedente numa bota nova")
	check(g.reservado("minerio_cobre") == 3, "o cobre reservado continuou lá")
	await _falar(g, "ferreiro", [0, 0], "entrega")
	check(est.tem("atrasada_eco_fiado") and est.tem("atrasada_eco_rapido") and _etapa(g) == "testar_arena", "fiado: eco rápido sem gastar, missão segue")
	g.free()

# ------------------------------------------------------------------ 6) reservas isoladas

func _testar_reservas() -> void:
	var est = Estado.new()
	var g = Gerenciador.new(est)
	g.adicionar_item("minerio_cobre", 7)
	check(g.excedente("minerio_cobre") == 7, "sem missão ativa não há reserva")
	g.iniciar("atrasada_desde_amanha")
	check(g.reservado("minerio_cobre") == 3 and g.excedente("minerio_cobre") == 4, "missão ativa reserva 3 cobres (4 de excedente)")
	check(not g.pode_gastar({"minerio_cobre": 5}), "não gasta 5 (só 4 de excedente)")
	check(g.gastar_excedente({"minerio_cobre": 4}) and g.excedente("minerio_cobre") == 0 and int(g.materiais.minerio_cobre) == 3, "gasta os 4 e os 3 reservados ficam")
	check(not g.gastar_excedente({"minerio_cobre": 1}), "reserva intocável")
	g.adicionar_item("conta_impossivel")
	check(g.tem_item_missao("conta_impossivel") and not g.pode_gastar({"conta_impossivel": 1}), "documento de missão vai pra mochila de missão e não é gastável")
	check(g.itens_reservados().get("minerio_cobre", 0) == 3 and g.itens_reservados().has("conta_impossivel"), "itens_reservados() para a interface")
	check(g.pode_gastar({"nota": "texto", "ouro": 0}), "custo sem quantidades válidas é grátis")
	g.free()

# ------------------------------------------------------------------ 7) tutorial

func _testar_tutorial() -> void:
	# só eventos, sem missão
	var est = Estado.new()
	var t = Tutorial.new(est)
	var iniciados: Array = []
	var fim: Array = []
	t.passo_iniciado.connect(func(p, _d): iniciados.append(p))
	t.tutorial_concluido.connect(func(p): fim.append(p))
	t.notificar("jogo_iniciado")
	est.marcar("tut_abertura_vista")
	t.notificar("perto_de", "crianca_praca")
	est.marcar("tut_conversou")
	t.notificar("golpe_acertou", "sir_palha", 3)
	t.notificar("golpe_pesado", "sir_palha")
	t.notificar("esquivou", "sir_palha")
	t.notificar("eco_acertou")
	check(t.passo_atual().get("id", "") == "forja" and t.fase == "aguardando", "eventos antes do gatilho não contam (forja aguardando)")
	t.notificar("forja_aberta")
	t.notificar("forja_item_feito")
	check(t.passo_atual().get("id", "") == "eco" and t.fase == "aguardando", "forja concluída por qualquer item feito")
	est.marcar("eco_desbloqueado")
	t.notificar("eco_acertou")
	t.notificar("perto_de", "elevador_tiao")
	t.notificar("jogo_salvo")
	t.notificar("mapa_liberado")
	t.notificar("mapa_aberto")
	t.notificar("teleportou")
	check(t.terminou() and fim == [false] and t.concluidos.size() == t.passos.size(), "tutorial: todos os %d passos concluídos" % t.passos.size())
	check(iniciados.size() == t.passos.size(), "cada passo emitiu passo_iniciado")
	var sem_dica: Array = []
	for p in t.passos:
		if p.id != "abertura" and String(p.get("dica", "")) == "":
			sem_dica.append(p.id)
		if not p.has("gatilho") or not p.has("conclusao"):
			sem_dica.append(p.id + " sem gatilho/conclusao")
	check(sem_dica.is_empty(), "todo passo tem gatilho, dica e conclusão %s" % str(sem_dica))
	t.free()
	# pular tudo
	var est2 = Estado.new()
	var t2 = Tutorial.new(est2)
	var fim2: Array = []
	t2.tutorial_concluido.connect(func(p): fim2.append(p))
	t2.iniciar()
	t2.notificar("perto_de", "x")
	t2.pular_tudo()
	check(t2.terminou() and fim2 == [true] and est2.tem("tutorial_pulado") and est2.tem("tutorial_basico_concluido") and t2.pulados.size() == t2.passos.size(), "pular_tudo encerra e marca tutorial_pulado")
	t2.notificar("jogo_salvo")
	check(fim2.size() == 1, "depois de pulado, eventos não reabrem o tutorial")
	t2.free()
	# pular um passo
	var est3 = Estado.new()
	var t3 = Tutorial.new(est3)
	t3.notificar("jogo_iniciado")
	est3.marcar("tut_abertura_vista")
	t3.pular_passo()
	check(t3.passo_atual().get("id", "") == "conversar" and "mover" in t3.pulados, "pular_passo pula só o passo atual")
	t3.free()
	# pular pela escolha do primeiro diálogo
	var est4 = Estado.new()
	var t4 = Tutorial.new(est4)
	var g4 = Gerenciador.new(est4)
	t4.iniciar()
	await _rodar("res://dialogos/tutorial/abertura.dialogue", "chegada", est4, [1])
	check(t4.terminou() and t4.foi_pulado and g4.missao("atrasada_desde_amanha").ativa(), "escolha 'pular tutorial' no diálogo de chegada pula e a missão começa")
	t4.free()
	g4.free()

# ------------------------------------------------------------------ 8b) save/load

func _testar_save() -> void:
	var est = Estado.new()
	var g = Gerenciador.new(est)
	est.marcar("tutorial_pulado")
	est.marcar("atrasada_conta_lida")
	g.adicionar_item("minerio_cobre", 4)
	var dados: Dictionary = JSON.parse_string(JSON.stringify(g.salvar_dados()))
	var g2 = Gerenciador.new(est)
	g2.carregar_dados(dados)
	check(_etapa(g2) == "ver_guindaste" and g2.tem_item_missao("conta_impossivel") and g2.reservado("minerio_cobre") == 3, "save/load preserva etapa, mochila e reservas")
	est.marcar("atrasada_defeito_visto")
	check(_etapa(g2) == "reforco_arma", "gerenciador carregado continua avançando")
	g.free()
	g2.free()
