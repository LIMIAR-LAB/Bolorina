extends RefCounted
## Escolhe qual conversa um morador usa agora (PROPOSTA).
## Ordem: tutorial -> etapa ativa da missão -> objetivo opcional ativo (se já conheceu) ->
##        diálogo original enquanto não conheceu -> reações (memória da cidade) -> pos_missao -> período.
## Devolve {} quando o jogo deve usar o padrão (dialogos/<id>.dialogue, cue "start").

const PASTA_REACOES := "res://dialogos/reacoes/"

static func escolher(npc_id: String, g) -> Dictionary:
	if g.tutorial != null and g.tutorial.has_method("dialogo_para"):
		var t: Dictionary = g.tutorial.dialogo_para(npc_id)
		if not t.is_empty():
			return t
	for m in g.missoes_em_ordem():
		if m.ativa():
			var e: Dictionary = m.etapa_atual()
			var d: Dictionary = e.get("dialogos", {}).get(npc_id, {})
			if not d.is_empty():
				return _r(d, "etapa", m.id, String(e.id))
	var conheceu: bool = g.estado.tem(npc_id + "_conheceu")
	if not conheceu:
		return {}
	for m in g.missoes_em_ordem():
		for o in m.opcionais_ativos():
			var d2: Dictionary = o.get("dialogos", {}).get(npc_id, {})
			if not d2.is_empty():
				return _r(d2, "opcional", m.id, String(o.id))
	var mor: Dictionary = g.moradores_dados.get("moradores", {}).get(npc_id, {})
	if mor.is_empty():
		return {}
	var arquivo := PASTA_REACOES + npc_id + ".dialogue"
	for r in mor.get("reacoes", []):
		if g._marcas_ok(r.get("exige", []), r.get("proibe", [])):
			return {"arquivo": String(r.get("arquivo", arquivo)), "cue": String(r.cue), "origem": "reacao"}
	var rot: Dictionary = mor.get("rotina", {})
	var pos := String(g.moradores_dados.get("marca_pos_missao", ""))
	if pos != "" and g.estado.tem(pos) and rot.has("pos_missao"):
		return {"arquivo": arquivo, "cue": String(rot.pos_missao.cue), "origem": "pos_missao"}
	if rot.has(g.periodo):
		return {"arquivo": arquivo, "cue": String(rot[g.periodo].cue), "origem": "rotina"}
	return {}

static func _r(d: Dictionary, origem: String, mid: String, sub: String) -> Dictionary:
	return {"arquivo": String(d.arquivo), "cue": String(d.cue), "origem": origem, "missao": mid, "de": sub}
