extends RefCounted
## Equipamento da Vale: catalogo de pecas, slots, inventario e salvamento.
## Fica no save da ilha (user://ilha_fazenda_v1.json, chave "equipamento"); saves antigos sem a chave
## recebem o equipamento inicial (nada quebra). Visual: scripts/ilha/equipamento_visual.gd compoe as
## CAMADAS de cada peca (art/characters/vale_trajes/) sobre a arte base da Vale.
## Detalhes: docs/EQUIPAMENTO.md
## maos/pes/escudo/arma: conjuntos da forja (noite 20/10). Escudo e espada nao aparecem fora do combate.
const SLOTS := ["cabeca", "corpo", "pernas", "acessorio", "maos", "pes", "escudo", "arma"]
const NOME_SLOT := {"cabeca": "Cabeça", "corpo": "Corpo", "pernas": "Pernas", "acessorio": "Acessório", "maos": "Mãos", "pes": "Pés", "escudo": "Escudo", "arma": "Arma"}
## ordem de desenho das camadas (menor = mais embaixo)
const Z_SLOT := {"pernas": 1, "pes": 2, "corpo": 3, "maos": 4, "acessorio": 5, "cabeca": 6, "escudo": 7, "arma": 8}
## padrao de cada slot ao tirar a peca (corpo e pernas nunca ficam vazios: volta a roupa de aprendiz)
const PADRAO := {"cabeca": "", "corpo": "roupa_aprendiz", "pernas": "calca_lida", "acessorio": "", "maos": "", "pes": "", "escudo": "", "arma": ""}
## camadas: ids em art/characters/vale_trajes/indice.json (vazio = arte base). Capacetes e armaduras de
## couro/malha vem da arte do PixelLab (tools/vale_pecas_pixellab.py); o resto e recolor por codigo.
const ITENS := {
	"roupa_aprendiz": {"nome": "Roupa de aprendiz", "slot": "corpo", "defesa": 0, "camadas": [],
		"desc": "Camisa verde-mar e colete de couro. A roupa de sempre da Vale."},
	"tunica_pescador": {"nome": "Túnica do pescador", "slot": "corpo", "defesa": 1, "camadas": ["camisa_azul"],
		"desc": "Lona azul encerada. Seca rápido depois da pesca."},
	"camisa_lenhador": {"nome": "Camisa do lenhador", "slot": "corpo", "defesa": 1, "camadas": ["camisa_vermelha"],
		"desc": "Flanela vermelha grossa, boa contra farpas."},
	"bata_cinzas": {"nome": "Bata das cinzas", "slot": "corpo", "defesa": 2, "camadas": ["camisa_cinzas"],
		"desc": "Tecido tingido com a cinza do vulcão. Não pega fogo fácil."},
	"peitoral_adamantium": {"nome": "Peitoral de adamantium", "slot": "corpo", "defesa": 5, "camadas": ["adam_peito"],
		"desc": "Placas do mesmo metal da forma Adamantium (G), em versão de vestir."},
	"calca_lida": {"nome": "Calça de lida", "slot": "pernas", "defesa": 0, "camadas": [],
		"desc": "Calça cinza de trabalho. Aguenta terra e espinho."},
	"calca_anil": {"nome": "Calça anil", "slot": "pernas", "defesa": 1, "camadas": ["calca_anil"],
		"desc": "Tingida com anil da vila. Combina com a túnica do pescador."},
	"calca_caqui": {"nome": "Calça cáqui", "slot": "pernas", "defesa": 1, "camadas": ["calca_caqui"],
		"desc": "Cor de areia, fresca para o sol da fazenda."},
	"grevas_adamantium": {"nome": "Grevas de adamantium", "slot": "pernas", "defesa": 3, "camadas": ["adam_grevas"],
		"desc": "Proteção de metal para pernas e botas."},
	"couro_cacador": {"nome": "Couraça do caçador", "slot": "corpo", "defesa": 3, "camadas": ["couro_cacador"],
		"desc": "Gibão de couro com ombreira, cinto com bolsa e braçadeiras."},
	"malha_guarda": {"nome": "Cota de malha do guarda", "slot": "corpo", "defesa": 4, "camadas": ["malha_guarda"],
		"desc": "Malha de ferro com tabardo vermelho e cinto de couro."},
	"capuz_couro": {"nome": "Capuz de couro", "slot": "cabeca", "defesa": 1, "camadas": ["capuz_couro"],
		"desc": "Capuz de couro costurado à mão. Esconde o cabelo, deixa a franja."},
	"elmo_ferro": {"nome": "Elmo de ferro", "slot": "cabeca", "defesa": 2, "camadas": ["elmo_ferro"],
		"desc": "Elmo redondo de ferro, com aba rebitada e proteção de nariz."},
	"elmo_adamantium": {"nome": "Elmo de adamantium", "slot": "cabeca", "defesa": 4, "camadas": ["elmo_adamantium"],
		"desc": "Metal prateado-azulado com uma runa ciano na testa e uma crista curta."},
	# ---- conjuntos da forja (data/forja/itens.json; camadas por cor em tools/vale_conjuntos.py)
	"capacete_cobre": {"nome": "Capacete de cobre", "slot": "cabeca", "defesa": 2, "ataque": 0, "camadas": ["capacete_cobre"], "forja": true, "nivel": 1,
		"desc": "Capacete forjado na forja da Helena."},
	"peito_cobre": {"nome": "Peitoral de cobre", "slot": "corpo", "defesa": 3, "ataque": 0, "camadas": ["peito_cobre"], "forja": true, "nivel": 1,
		"desc": "Peitoral forjado. Pesa, mas protege."},
	"luvas_cobre": {"nome": "Luvas de cobre", "slot": "maos", "defesa": 1, "ataque": 0, "camadas": ["luvas_cobre"], "forja": true, "nivel": 1,
		"desc": "Luvas com placas nos dedos."},
	"botas_cobre": {"nome": "Botas de cobre", "slot": "pes", "defesa": 1, "ataque": 0, "camadas": ["botas_cobre"], "forja": true, "nivel": 1,
		"desc": "Botas com biqueira de metal."},
	"escudo_cobre": {"nome": "Escudo de cobre", "slot": "escudo", "defesa": 2, "ataque": 0, "camadas": [], "forja": true, "nivel": 1,
		"desc": "Escudo redondo (só aparece no combate)."},
	"espada_cobre": {"nome": "Espada de cobre", "slot": "arma", "defesa": 0, "ataque": 3, "camadas": [], "forja": true, "nivel": 1,
		"desc": "Espada forjada (só aparece no combate)."},
	"capacete_ferro": {"nome": "Capacete de ferro", "slot": "cabeca", "defesa": 4, "ataque": 0, "camadas": ["capacete_ferro"], "forja": true, "nivel": 2,
		"desc": "Capacete forjado na forja da Helena."},
	"peito_ferro": {"nome": "Peitoral de ferro", "slot": "corpo", "defesa": 6, "ataque": 0, "camadas": ["peito_ferro"], "forja": true, "nivel": 2,
		"desc": "Peitoral forjado. Pesa, mas protege."},
	"luvas_ferro": {"nome": "Luvas de ferro", "slot": "maos", "defesa": 2, "ataque": 0, "camadas": ["luvas_ferro"], "forja": true, "nivel": 2,
		"desc": "Luvas com placas nos dedos."},
	"botas_ferro": {"nome": "Botas de ferro", "slot": "pes", "defesa": 2, "ataque": 0, "camadas": ["botas_ferro"], "forja": true, "nivel": 2,
		"desc": "Botas com biqueira de metal."},
	"escudo_ferro": {"nome": "Escudo de ferro", "slot": "escudo", "defesa": 4, "ataque": 0, "camadas": [], "forja": true, "nivel": 2,
		"desc": "Escudo redondo (só aparece no combate)."},
	"espada_ferro": {"nome": "Espada de ferro", "slot": "arma", "defesa": 0, "ataque": 6, "camadas": [], "forja": true, "nivel": 2,
		"desc": "Espada forjada (só aparece no combate)."},
	"capacete_prata": {"nome": "Capacete de prata de túmulo", "slot": "cabeca", "defesa": 6, "ataque": 0, "camadas": ["capacete_prata"], "forja": true, "nivel": 3,
		"desc": "Capacete forjado na forja da Helena."},
	"peito_prata": {"nome": "Peitoral de prata de túmulo", "slot": "corpo", "defesa": 9, "ataque": 0, "camadas": ["peito_prata"], "forja": true, "nivel": 3,
		"desc": "Peitoral forjado. Pesa, mas protege."},
	"luvas_prata": {"nome": "Luvas de prata de túmulo", "slot": "maos", "defesa": 3, "ataque": 0, "camadas": ["luvas_prata"], "forja": true, "nivel": 3,
		"desc": "Luvas com placas nos dedos."},
	"botas_prata": {"nome": "Botas de prata de túmulo", "slot": "pes", "defesa": 3, "ataque": 0, "camadas": ["botas_prata"], "forja": true, "nivel": 3,
		"desc": "Botas com biqueira de metal."},
	"escudo_prata": {"nome": "Escudo de prata de túmulo", "slot": "escudo", "defesa": 6, "ataque": 0, "camadas": [], "forja": true, "nivel": 3,
		"desc": "Escudo redondo (só aparece no combate)."},
	"espada_prata": {"nome": "Espada de prata de túmulo", "slot": "arma", "defesa": 0, "ataque": 9, "camadas": [], "forja": true, "nivel": 3,
		"desc": "Espada forjada (só aparece no combate)."},
	"amuleto_brasa": {"nome": "Amuleto de brasa", "slot": "acessorio", "defesa": 1, "camadas": [],
		"desc": "Uma brasa que nunca apaga. Ainda sem visual no corpo (arte futura)."},
}
## pecas que entraram depois do primeiro save com equipamento: saves que ja tem a chave as recebem ao carregar
const NOVAS := ["couro_cacador", "malha_guarda"]
## pecas que a Vale ja tem no comeco (save novo ou save antigo sem equipamento)
const INICIAIS := ["roupa_aprendiz", "tunica_pescador", "camisa_lenhador", "bata_cinzas", "peitoral_adamantium",
	"couro_cacador", "malha_guarda", "calca_lida", "calca_anil", "calca_caqui", "grevas_adamantium", "capuz_couro", "elmo_ferro", "elmo_adamantium", "amuleto_brasa"]

static func novo() -> Dictionary:
	return {"possui": INICIAIS.duplicate(), "equipado": PADRAO.duplicate()}

## le o que veio do save (pode ser null, antigo ou com ids que nao existem mais)
static func normalizar(d) -> Dictionary:
	var eq := novo()
	if not d is Dictionary:
		return eq
	# encantos do Arquimago (economia): {id_da_peca: bonus}
	if d.get("encantos", null) is Dictionary:
		var enc := {}
		for k in d.encantos:
			if ITENS.has(String(k)):
				enc[String(k)] = int(d.encantos[k])
		if not enc.is_empty():
			eq["encantos"] = enc
	var possui = d.get("possui", null)
	if possui is Array:
		var lista: Array = []
		for id in possui:
			if ITENS.has(String(id)) and not lista.has(String(id)):
				lista.append(String(id))
		for id in PADRAO.values() + NOVAS:
			if id != "" and not lista.has(id):
				lista.append(id)
		eq.possui = lista
	var equipado = d.get("equipado", null)
	if equipado is Dictionary:
		for s in SLOTS:
			var id := String(equipado.get(s, PADRAO[s]))
			if id == "":
				id = PADRAO[s]
			if id != "" and not (ITENS.has(id) and String(ITENS[id].slot) == s and eq.possui.has(id)):
				id = PADRAO[s]
			eq.equipado[s] = id
	return eq

static func item(id: String) -> Dictionary:
	return ITENS.get(id, {})

static func equipado(eq: Dictionary, slot: String) -> String:
	return String(eq.equipado.get(slot, ""))

static func esta_equipado(eq: Dictionary, id: String) -> bool:
	return ITENS.has(id) and equipado(eq, String(ITENS[id].slot)) == id

## veste a peca no slot dela (troca a anterior). false se nao existe ou a Vale nao tem.
static func equipar(eq: Dictionary, id: String) -> bool:
	if not ITENS.has(id) or not eq.possui.has(id):
		return false
	eq.equipado[String(ITENS[id].slot)] = id
	return true

## tira a peca do slot (corpo/pernas voltam para a roupa padrao)
static func desequipar(eq: Dictionary, slot: String) -> bool:
	if not PADRAO.has(slot) or equipado(eq, slot) == PADRAO[slot]:
		return false
	eq.equipado[slot] = PADRAO[slot]
	return true

## veste ou tira (clique / Enter na grade)
static func alternar(eq: Dictionary, id: String) -> bool:
	if esta_equipado(eq, id):
		return desequipar(eq, String(ITENS[id].slot))
	return equipar(eq, id)

static func ganhar(eq: Dictionary, id: String) -> bool:
	if not ITENS.has(id) or eq.possui.has(id):
		return false
	eq.possui.append(id)
	return true

static func defesa(eq: Dictionary) -> int:
	var t := 0
	var enc: Dictionary = eq.get("encantos", {})
	for s in SLOTS:
		var id := equipado(eq, s)
		if id != "":
			t += int(ITENS[id].get("defesa", 0)) + int(enc.get(id, 0))
	return t

## ataque somado (espadas da forja)
static func ataque(eq: Dictionary) -> int:
	var t := 0
	for s in SLOTS:
		var id := equipado(eq, s)
		if id != "":
			t += int(ITENS[id].get("ataque", 0))
	return t

## defesa se a peca fosse vestida (para comparar na tela)
static func defesa_com(eq: Dictionary, id: String) -> int:
	var copia := {"possui": eq.possui, "equipado": (eq.equipado as Dictionary).duplicate()}
	alternar(copia, id)
	return defesa(copia)

## camadas visuais na ordem de desenho (pernas -> corpo -> acessorio -> cabeca)
static func camadas(eq: Dictionary) -> Array:
	var ordem := SLOTS.duplicate()
	ordem.sort_custom(func(a, b): return int(Z_SLOT[a]) < int(Z_SLOT[b]))
	var out: Array = []
	for s in ordem:
		var id := equipado(eq, s)
		if id != "":
			for c in ITENS[id].get("camadas", []):
				out.append(String(c))
	return out
