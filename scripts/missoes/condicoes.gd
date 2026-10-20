extends RefCounted
## Avaliador de condições usado pela missão e pelo tutorial (PROPOSTA).
## Tipos:
##   {"tipo": "marca", "marca": "x"}                         -> estado_dialogos.tem("x")
##   {"tipo": "evento", "evento": "e", "alvo": "a", "quantidade": n}  -> contador >= n ("alvo" "*" ou ausente = qualquer)
##   {"tipo": "item_missao", "item": "i", "quantidade": n}   -> item obrigatório na mochila de missão
##   {"tipo": "qualquer", "de": [condições]}                 -> basta uma
##   {"tipo": "imediato"}                                    -> sempre verdadeira
## Os contadores ficam num Dictionary externo, com chave "<prefixo><índice>[.<sub>]".

static func ok(conds: Array, estado, contadores: Dictionary, itens: Dictionary, prefixo := "") -> bool:
	for i in conds.size():
		if not ok_uma(conds[i], estado, contadores, itens, prefixo + str(i)):
			return false
	return true

static func ok_uma(c: Dictionary, estado, contadores: Dictionary, itens: Dictionary, chave: String) -> bool:
	match String(c.get("tipo", "")):
		"marca":
			return estado != null and estado.tem(String(c.get("marca", "")))
		"evento":
			return int(contadores.get(chave, 0)) >= int(c.get("quantidade", 1))
		"item_missao":
			return int(itens.get(String(c.get("item", "")), 0)) >= int(c.get("quantidade", 1))
		"qualquer":
			var de: Array = c.get("de", [])
			for j in de.size():
				if ok_uma(de[j], estado, contadores, itens, chave + "." + str(j)):
					return true
			return false
		"imediato":
			return true
	push_warning("condicao desconhecida: %s" % str(c))
	return false

## Soma um evento em todas as condições "evento" que batem. Devolve true se contou em alguma.
static func contar(conds: Array, evento: String, alvo: String, qtd: int, contadores: Dictionary, prefixo := "") -> bool:
	var contou := false
	for i in conds.size():
		if contar_uma(conds[i], evento, alvo, qtd, contadores, prefixo + str(i)):
			contou = true
	return contou

static func contar_uma(c: Dictionary, evento: String, alvo: String, qtd: int, contadores: Dictionary, chave: String) -> bool:
	var t := String(c.get("tipo", ""))
	if t == "evento":
		if String(c.get("evento", "")) != evento:
			return false
		var a := String(c.get("alvo", "*"))
		if a != "*" and a != alvo:
			return false
		contadores[chave] = int(contadores.get(chave, 0)) + qtd
		return true
	if t == "qualquer":
		var contou := false
		var de: Array = c.get("de", [])
		for j in de.size():
			if contar_uma(de[j], evento, alvo, qtd, contadores, chave + "." + str(j)):
				contou = true
		return contou
	return false

## Todas as marcas citadas por uma lista de condições (para os testes de marcas).
static func marcas_citadas(conds: Array) -> Array:
	var r: Array = []
	for c in conds:
		var t := String(c.get("tipo", ""))
		if t == "marca":
			r.append(String(c.marca))
		elif t == "qualquer":
			r.append_array(marcas_citadas(c.get("de", [])))
	return r
