extends Node
## Gerenciador de missões (PROPOSTA). Máquina de estados independente, sem depender de cena.
## Lê data/missoes/*.json, escuta as marcas de scripts/dialogos/estado_dialogos.gd e recebe eventos do jogo.
##
## Ganchos que o jogo chama:
##   notificar(evento, alvo, qtd)    "chegou_area", "inimigo_derrotado", "eco_acertou", "trava_acertada_eco",
##                                   "forja_reforco_feito", "bau_aberto", "item_coletado"...
##   coletar_item(id, n)             pegou algo no mundo (soma + evento "item_coletado")
##   adicionar_item(id, n)           soma sem evento (minério minerado, loja...)
##   pode_gastar(custo) / gastar_excedente(custo)   a forja e as lojas SÓ gastam o excedente
##   dialogo_para(npc_id)            {arquivo, cue, origem} ou {} (= usar o diálogo padrão do morador)
##   interacao(alvo_id)              {arquivo, cue, npc} para objetos (guindaste, cesto, placa)
##   cenas_disponiveis(periodo)      cenas de ambiente que podem tocar agora; cena_vista(id) depois
##   periodo = "manha" | "tarde" | "noite"
## Sinais para a cena ligar: ver lista abaixo.

signal missao_iniciada(missao_id: String)
signal etapa_iniciada(missao_id: String, etapa_id: String, objetivo: String, dica: String)
signal objetivo_atualizado(missao_id: String, texto: String)
signal etapa_concluida(missao_id: String, etapa_id: String)
signal etapa_pulada(missao_id: String, etapa_id: String)
signal escolha_feita(missao_id: String, etapa_id: String, marca: String)
signal opcional_iniciado(missao_id: String, opcional_id: String, objetivo: String)
signal opcional_concluido(missao_id: String, opcional_id: String)
signal opcional_expirado(missao_id: String, opcional_id: String)
signal missao_concluida(missao_id: String, recompensas: Dictionary)
signal mudanca_mundo(mudanca_id: String, dados: Dictionary)
signal item_missao_alterado(item_id: String, quantidade: int)
signal material_alterado(item_id: String, total: int, excedente: int)
signal arma_trocada(de: String, para: String)
signal variacao_eco_alterada(variacao_id: String, dados: Dictionary)
signal provisao_escolhida(provisao_id: String, dados: Dictionary)
signal dialogo_pedido(npc_id: String, arquivo: String, cue: String)
signal cena_ambiente_pedida(cena_id: String)
signal desbloqueado(o_que: String)

const Missao = preload("res://scripts/missoes/missao.gd")
const Cond = preload("res://scripts/missoes/condicoes.gd")
const Seletor = preload("res://scripts/missoes/seletor_dialogos.gd")
const MISSOES_PADRAO := ["res://data/missoes/atrasada_desde_amanha.json"]
const MORADORES := "res://data/missoes/moradores_principais.json"
const CENAS := "res://data/missoes/cenas_ambiente.json"
const ARQUIVO_SAVE := "user://missoes_estado_v1.json"

var estado = null                 # estado_dialogos.gd (marcas, confiança)
var tutorial = null               # opcional: scripts/tutorial/tutorial.gd, consultado por dialogo_para()
var missoes: Dictionary = {}      # id -> Missao
var ordem: Array = []
var itens_missao: Dictionary = {} # obrigatórios: nunca gastáveis
var materiais: Dictionary = {}    # comuns (inclui "ouro"); parte pode estar reservada
var reservas: Dictionary = {}     # id -> quantidade obrigatória ainda reservada
var variacao_eco := ""
var arma_atual := "facao_fazenda"
var periodo := "tarde"
var moradores_dados: Dictionary = {}
var cenas_dados: Dictionary = {}
var mundo_aplicado: Array = []
var historico: Array = []         # [tipo, ...] para depuração e testes

var _fila: Array = []
var _processando := false

func _init(estado_inicial = null, carregar_padrao := true) -> void:
	usar_estado(estado_inicial if estado_inicial != null else load("res://scripts/dialogos/estado_dialogos.gd").global())
	if carregar_padrao:
		for c in MISSOES_PADRAO:
			carregar_missao(c)
		moradores_dados = _ler_json(MORADORES)
		cenas_dados = _ler_json(CENAS)

func _ler_json(c: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(c))
	return d if d is Dictionary else {}

func usar_estado(e) -> void:
	if estado != null and estado.evento.is_connected(_ao_evento_estado):
		estado.evento.disconnect(_ao_evento_estado)
	estado = e
	if estado != null:
		estado.evento.connect(_ao_evento_estado)

func carregar_missao(caminho: String) -> String:
	var m = Missao.de_arquivo(caminho)
	if m == null:
		return ""
	missoes[m.id] = m
	if not m.id in ordem:
		ordem.append(m.id)
	return m.id

func missao(missao_id: String):
	return missoes.get(missao_id)

func missoes_em_ordem() -> Array:
	var r: Array = []
	for i in ordem:
		r.append(missoes[i])
	return r

## Força o início (para depuração). O normal é começar sozinho quando "inicio.condicoes" valem.
func iniciar(missao_id: String) -> void:
	var m = missoes.get(missao_id)
	if m != null and m.situacao == "inativa":
		_iniciar(m)
		_drenar()

func avaliar() -> void:
	_fila.append(["avaliar"])
	_drenar()

# ---------------------------------------------------------------- eventos

func notificar(evento: String, alvo: String = "", quantidade: int = 1) -> void:
	_fila.append(["evento", evento, alvo, quantidade])
	_drenar()

func chegou_area(area: String) -> void:
	notificar("chegou_area", area)

func coletar_item(item_id: String, quantidade: int = 1) -> void:
	adicionar_item(item_id, quantidade)
	notificar("item_coletado", item_id, quantidade)

func _ao_evento_estado(nome: String, valor) -> void:
	if nome == "marca":
		_fila.append(["marca", String(valor)])
		_drenar()

func _drenar() -> void:
	if _processando:
		return
	_processando = true
	var voltas := 0
	while not _fila.is_empty() and voltas < 500:
		voltas += 1
		var item: Array = _fila.pop_front()
		match String(item[0]):
			"marca":
				_processar_marca(String(item[1]))
			"evento":
				_processar_evento(String(item[1]), String(item[2]), int(item[3]))
		_avaliar_tudo()
	_processando = false

func _processar_marca(marca: String) -> void:
	historico.append(["marca", marca])
	for m in missoes_em_ordem():
		if m.ativa():
			var e: Dictionary = m.etapa_atual()
			for esc in e.get("escolhas", []):
				if String(esc.marca) == marca and not m.escolhas.has(String(e.id)):
					_aplicar_escolha(m, e, esc)
		for o in m.opcionais_ativos():
			var ef: Dictionary = o.get("efeitos_marca", {})
			if ef.has(marca):
				_aplicar_efeitos(m, ef[marca])

func _processar_evento(evento: String, alvo: String, qtd: int) -> void:
	historico.append(["evento", evento, alvo, qtd])
	for m in missoes_em_ordem():
		if m.ativa():
			_contar_na_etapa(m, evento, alvo, qtd, true)
		for o in m.opcionais_ativos():
			Cond.contar(o.get("condicoes", []), evento, alvo, qtd, m.contadores, "opc:" + String(o.id) + "/c")

func _contar_na_etapa(m, evento: String, alvo: String, qtd: int, pode_repassar: bool) -> void:
	var e: Dictionary = m.etapa_atual()
	if e.is_empty():
		return
	var eid := String(e.id)
	var contou: bool = Cond.contar(e.get("condicoes", []), evento, alvo, qtd, m.contadores, eid + "/c")
	var pular: Array = e.get("pular_quando", [])
	if not pular.is_empty():
		Cond.contar(pular, evento, alvo, qtd, m.contadores, eid + "/p")
		if Cond.ok(pular, estado, m.contadores, itens_missao, eid + "/p") and not Cond.ok(e.get("condicoes", []), estado, m.contadores, itens_missao, eid + "/c"):
			_pular_etapa(m)
			# o mesmo evento que pulou a etapa opcional vale para a próxima (ex.: chegar na mina)
			if pode_repassar:
				_contar_na_etapa(m, evento, alvo, qtd, false)
			return
	if contou:
		objetivo_atualizado.emit(m.id, m.texto_objetivo())

# ---------------------------------------------------------------- transições

func _avaliar_tudo() -> void:
	var mudou := true
	var voltas := 0
	while mudou and voltas < 100:
		voltas += 1
		mudou = false
		for m in missoes_em_ordem():
			if m.situacao == "inativa":
				if Cond.ok(m.dados.get("inicio", {}).get("condicoes", []), estado, m.contadores, itens_missao, "inicio/c"):
					_iniciar(m)
					mudou = true
			elif m.ativa():
				var e: Dictionary = m.etapa_atual()
				if not e.is_empty() and Cond.ok(e.get("condicoes", []), estado, m.contadores, itens_missao, String(e.id) + "/c"):
					_concluir_etapa(m)
					mudou = true
			if _avaliar_opcionais(m):
				mudou = true
		_atualizar_marcas_derivadas()

func _avaliar_opcionais(m) -> bool:
	var mudou := false
	for o in m.dados.get("opcionais", []):
		var oid := String(o.id)
		var s := String(m.opcionais.get(oid, "inativo"))
		var de: int = m.indice_de(String(o.get("de_etapa", "")))
		var ate: int = m.indice_de(String(o.get("ate_etapa", "")))
		if s == "inativo" and m.ativa() and m.indice >= de:
			m.opcionais[oid] = "ativo"
			opcional_iniciado.emit(m.id, oid, String(o.get("objetivo", "")))
			mudou = true
			s = "ativo"
		if s == "ativo":
			if Cond.ok(o.get("condicoes", []), estado, m.contadores, itens_missao, "opc:" + oid + "/c"):
				m.opcionais[oid] = "concluido"
				_aplicar_efeitos(m, o.get("ao_concluir", {}))
				opcional_concluido.emit(m.id, oid)
				mudou = true
			elif not bool(o.get("persistente", false)) and ((m.ativa() and ate >= 0 and m.indice > ate) or m.concluida()):
				m.opcionais[oid] = "expirado"
				opcional_expirado.emit(m.id, oid)
				mudou = true
	return mudou

func _iniciar(m) -> void:
	m.situacao = "ativa"
	historico.append(["missao_iniciada", m.id])
	var marca := String(m.dados.get("marca_ativa", ""))
	if marca != "":
		estado.marcar(marca)
	var res: Dictionary = m.dados.get("reservas", {}).get("reservar", {})
	for k in res:
		reservas[k] = int(reservas.get(k, 0)) + int(res[k])
	missao_iniciada.emit(m.id)
	_ativar_etapa(m, 0)

func _ativar_etapa(m, i: int) -> void:
	m.indice = i
	var e: Dictionary = m.etapa_atual()
	if e.is_empty():
		return
	historico.append(["etapa_iniciada", m.id, String(e.id)])
	_aplicar_efeitos(m, e.get("ao_iniciar", {}))
	etapa_iniciada.emit(m.id, String(e.id), String(e.get("objetivo", "")), String(e.get("dica", "")))
	objetivo_atualizado.emit(m.id, m.texto_objetivo())

func _concluir_etapa(m) -> void:
	var e: Dictionary = m.etapa_atual()
	historico.append(["etapa_concluida", m.id, String(e.id)])
	m.etapas_concluidas.append(String(e.id))
	_aplicar_efeitos(m, e.get("ao_concluir", {}))
	etapa_concluida.emit(m.id, String(e.id))
	_proxima(m)

func _pular_etapa(m) -> void:
	var e: Dictionary = m.etapa_atual()
	historico.append(["etapa_pulada", m.id, String(e.id)])
	m.etapas_puladas.append(String(e.id))
	etapa_pulada.emit(m.id, String(e.id))
	_proxima(m)

func _proxima(m) -> void:
	if m.indice + 1 < m.etapas().size():
		_ativar_etapa(m, m.indice + 1)
	else:
		_concluir_missao(m)

func _concluir_missao(m) -> void:
	m.situacao = "concluida"
	m.indice = m.etapas().size()
	historico.append(["missao_concluida", m.id])
	var r: Dictionary = m.dados.get("recompensas_finais", {})
	if r.has("ouro"):
		adicionar_item("ouro", int(r.ouro))
	var ex: Dictionary = r.get("excedente", {})
	for k in ex:
		adicionar_item(k, int(ex[k]))
	var conf: Dictionary = r.get("confianca", {})
	for k in conf:
		estado.confiar(k, int(conf[k]))
	# libera o que sobrou reservado por esta missão
	var res: Dictionary = m.dados.get("reservas", {}).get("reservar", {})
	for k in res:
		reservas[k] = maxi(0, int(reservas.get(k, 0)) - int(res[k]))
		if int(reservas[k]) == 0:
			reservas.erase(k)
	var ativa := String(m.dados.get("marca_ativa", ""))
	if ativa != "":
		estado.marcas.erase(ativa)
	for d in r.get("desbloqueia", []):
		estado.marcar("desbloqueado_" + String(d))
		desbloqueado.emit(String(d))
	for mk in r.get("marcas", []):
		estado.marcar(String(mk))
	var fim := String(m.dados.get("marca_concluida", ""))
	if fim != "":
		estado.marcar(fim)
	missao_concluida.emit(m.id, r)

# ---------------------------------------------------------------- efeitos

func _aplicar_escolha(m, e: Dictionary, esc: Dictionary) -> void:
	m.escolhas[String(e.id)] = String(esc.marca)
	var ef: Dictionary = esc.get("efeito", {})
	if ef.has("gastar_excedente"):
		var fiado := String(e.get("marca_fiado", ""))
		var custo: Dictionary = m.dados.get("custos", {}).get(String(ef.gastar_excedente), {})
		if fiado == "" or not estado.tem(fiado):
			if not gastar_excedente(custo) and fiado != "":
				estado.marcar(fiado)   # rede de segurança: a missão nunca trava por falta de material
	if ef.has("variacao_eco"):
		_definir_variacao(m, String(ef.variacao_eco))
	if ef.has("provisao"):
		provisao_escolhida.emit(String(ef.provisao), ef)
	escolha_feita.emit(m.id, String(e.id), String(esc.marca))

func _definir_variacao(m, vid: String) -> void:
	variacao_eco = vid
	estado.marcar("variacao_" + vid)
	variacao_eco_alterada.emit(vid, m.dados.get("variacoes_eco", {}).get(vid, {}))

func _aplicar_efeitos(m, ef: Dictionary) -> void:
	if ef.is_empty():
		return
	var dar: Dictionary = ef.get("dar_itens_missao", {})
	for k in dar:
		itens_missao[k] = int(itens_missao.get(k, 0)) + int(dar[k])
		item_missao_alterado.emit(k, int(itens_missao[k]))
	var tirar: Dictionary = ef.get("consumir_itens_missao", {})
	for k in tirar:
		itens_missao[k] = maxi(0, int(itens_missao.get(k, 0)) - int(tirar[k]))
		item_missao_alterado.emit(k, int(itens_missao[k]))
		if int(itens_missao[k]) == 0:
			itens_missao.erase(k)
	var mats: Dictionary = ef.get("dar_materiais", {})
	for k in mats:
		adicionar_item(k, int(mats[k]))
	var cons: Dictionary = ef.get("consumir_reservas", {})
	for k in cons:
		var q := mini(int(cons[k]), int(materiais.get(k, 0)))
		materiais[k] = int(materiais.get(k, 0)) - q
		reservas[k] = maxi(0, int(reservas.get(k, 0)) - int(cons[k]))
		if int(reservas[k]) == 0:
			reservas.erase(k)
		material_alterado.emit(k, int(materiais[k]), excedente(k))
	if ef.has("trocar_arma"):
		var t: Dictionary = ef.trocar_arma
		arma_atual = String(t.para)
		estado.marcar("arma_" + arma_atual)
		arma_trocada.emit(String(t.de), String(t.para))
	if ef.has("variacao_eco"):
		_definir_variacao(m, String(ef.variacao_eco))
	for mk in ef.get("marcas", []):
		estado.marcar(String(mk))
	for mid in ef.get("mudancas_mundo", []):
		_mudar_mundo(m, String(mid))
	if ef.has("cena_ambiente"):
		cena_ambiente_pedida.emit(String(ef.cena_ambiente))
	if ef.has("dialogo_pos"):
		var d: Dictionary = ef.dialogo_pos
		dialogo_pedido.emit(String(d.get("npc", "")), String(d.arquivo), String(d.cue))

func _mudar_mundo(m, mid: String) -> void:
	if not mid in mundo_aplicado:
		mundo_aplicado.append(mid)
	estado.marcar("mundo_" + mid)
	mudanca_mundo.emit(mid, m.dados.get("mudancas_mundo", {}).get(mid, {}))

func _atualizar_marcas_derivadas() -> void:
	for m in missoes_em_ordem():
		if not m.ativa():
			continue
		for e in m.etapas():
			var mp: Dictionary = e.get("marca_pode_pagar", {})
			if mp.is_empty():
				continue
			var custo: Dictionary = m.dados.get("custos", {}).get(String(mp.custo), {})
			var marca := String(mp.marca)
			if pode_gastar(custo):
				if not estado.tem(marca):
					estado.marcas[marca] = true   # derivada: sem sinal, para não reentrar
			else:
				estado.marcas.erase(marca)

## Marcas que o gerenciador escreve sozinho (para o teste de "toda marca citada é marcada em algum lugar").
func marcas_que_escreve() -> Array:
	var r: Array = []
	for m in missoes_em_ordem():
		for k in ["marca_ativa", "marca_concluida"]:
			if m.dados.has(k):
				r.append(String(m.dados[k]))
		for mid in m.dados.get("mudancas_mundo", {}):
			r.append("mundo_" + String(mid))
		for vid in m.dados.get("variacoes_eco", {}):
			r.append("variacao_" + String(vid))
		for d in m.dados.get("recompensas_finais", {}).get("desbloqueia", []):
			r.append("desbloqueado_" + String(d))
		r.append_array(m.dados.get("recompensas_finais", {}).get("marcas", []))
		for e in m.etapas() + m.dados.get("opcionais", []):
			for ef in [e.get("ao_iniciar", {}), e.get("ao_concluir", {})]:
				r.append_array(ef.get("marcas", []))
				if ef.has("trocar_arma"):
					r.append("arma_" + String(ef.trocar_arma.para))
			if e.has("marca_pode_pagar"):
				r.append(String(e.marca_pode_pagar.marca))
			if e.has("marca_fiado"):
				r.append(String(e.marca_fiado))
	for c in cenas_dados.get("cenas", []):
		r.append("cena_" + String(c.id) + "_vista")
	return r

# ---------------------------------------------------------------- mochila

func adicionar_item(item_id: String, quantidade: int = 1) -> void:
	for m in missoes_em_ordem():
		if m.item_e_de_missao(item_id):
			itens_missao[item_id] = int(itens_missao.get(item_id, 0)) + quantidade
			item_missao_alterado.emit(item_id, int(itens_missao[item_id]))
			_fila.append(["avaliar"])
			_drenar()
			return
	materiais[item_id] = int(materiais.get(item_id, 0)) + quantidade
	material_alterado.emit(item_id, int(materiais[item_id]), excedente(item_id))
	_fila.append(["avaliar"])
	_drenar()

func tem_item_missao(item_id: String) -> bool:
	return int(itens_missao.get(item_id, 0)) > 0

func reservado(item_id: String) -> int:
	return mini(int(materiais.get(item_id, 0)), int(reservas.get(item_id, 0)))

func excedente(item_id: String) -> int:
	return maxi(0, int(materiais.get(item_id, 0)) - int(reservas.get(item_id, 0)))

## Só o excedente pode ser gasto. Itens de missão e quantidades reservadas nunca entram.
func pode_gastar(custo: Dictionary) -> bool:
	for k in custo:
		var v = custo[k]
		if not (v is int or v is float):
			continue
		if int(v) <= 0:
			continue
		if itens_missao.has(k) or _e_item_de_missao(String(k)):
			return false
		if excedente(String(k)) < int(v):
			return false
	return true

func gastar_excedente(custo: Dictionary) -> bool:
	if not pode_gastar(custo):
		return false
	for k in custo:
		var v = custo[k]
		if (v is int or v is float) and int(v) > 0:
			materiais[k] = int(materiais[k]) - int(v)
			material_alterado.emit(k, int(materiais[k]), excedente(k))
	_atualizar_marcas_derivadas()
	return true

func _e_item_de_missao(item_id: String) -> bool:
	for m in missoes_em_ordem():
		if m.item_e_de_missao(item_id):
			return true
	return false

## Para a interface da forja/loja mostrar o que está travado.
func itens_reservados() -> Dictionary:
	var r := {}
	for k in reservas:
		r[k] = reservado(k)
	for k in itens_missao:
		r[k] = itens_missao[k]
	return r

# ---------------------------------------------------------------- diálogos, objetos e cenas

func dialogo_para(npc_id: String) -> Dictionary:
	return Seletor.escolher(npc_id, self)

func interacao(alvo_id: String) -> Dictionary:
	for m in missoes_em_ordem():
		for o in m.opcionais_ativos():
			var it: Dictionary = o.get("interacoes", {}).get(alvo_id, {})
			if not it.is_empty() and _gate(it):
				return _com_origem(it, "opcional", m.id, String(o.id))
		var e: Dictionary = m.etapa_atual()
		var it2: Dictionary = e.get("interacoes", {}).get(alvo_id, {})
		if not it2.is_empty() and _gate(it2):
			return _com_origem(it2, "etapa", m.id, String(e.id))
	return {}

func _gate(it: Dictionary) -> bool:
	var q := String(it.get("quando", ""))
	var n := String(it.get("nao_quando", ""))
	return (q == "" or estado.tem(q)) and (n == "" or not estado.tem(n))

func _com_origem(it: Dictionary, origem: String, mid: String, sub: String) -> Dictionary:
	var r := it.duplicate()
	r["origem"] = origem
	r["missao"] = mid
	r["de"] = sub
	return r

func cenas_disponiveis(p: String = "") -> Array:
	var per := p if p != "" else periodo
	var r: Array = []
	for c in cenas_dados.get("cenas", []):
		var cp := String(c.get("periodo", "*"))
		if cp != "*" and cp != per:
			continue
		if not bool(c.get("repetir", false)) and estado.tem("cena_" + String(c.id) + "_vista"):
			continue
		if not _marcas_ok(c.get("exige", []), c.get("proibe", [])):
			continue
		r.append(c)
	return r

func cena_vista(cena_id: String) -> void:
	estado.marcar("cena_" + cena_id + "_vista")

func _marcas_ok(exige: Array, proibe: Array) -> bool:
	for x in exige:
		if not estado.tem(String(x)):
			return false
	for x in proibe:
		if estado.tem(String(x)):
			return false
	return true

func objetivo_atual() -> String:
	for m in missoes_em_ordem():
		if m.ativa():
			return m.texto_objetivo()
	return ""

# ---------------------------------------------------------------- salvar (arquivo próprio, não toca no save da fazenda)

func salvar_dados() -> Dictionary:
	var ms := {}
	for k in missoes:
		ms[k] = missoes[k].serializar()
	return {"missoes": ms, "itens_missao": itens_missao.duplicate(), "materiais": materiais.duplicate(),
		"reservas": reservas.duplicate(), "variacao_eco": variacao_eco, "arma_atual": arma_atual,
		"mundo_aplicado": mundo_aplicado.duplicate()}

func carregar_dados(d: Dictionary) -> void:
	for k in d.get("missoes", {}):
		if missoes.has(k):
			missoes[k].desserializar(d.missoes[k])
	itens_missao = d.get("itens_missao", {})
	materiais = d.get("materiais", {})
	reservas = d.get("reservas", {})
	variacao_eco = String(d.get("variacao_eco", ""))
	arma_atual = String(d.get("arma_atual", "facao_fazenda"))
	mundo_aplicado = d.get("mundo_aplicado", [])

func salvar() -> bool:
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(salvar_dados(), "\t"))
	return true

func carregar() -> bool:
	if not FileAccess.file_exists(ARQUIVO_SAVE):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_SAVE))
	if not d is Dictionary:
		return false
	carregar_dados(d)
	return true
