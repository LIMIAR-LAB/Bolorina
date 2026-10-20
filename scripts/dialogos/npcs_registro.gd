extends RefCounted
## Registro dos moradores que conversam (Ilha das Cinzas).
## Fonte unica de id -> nome, titulo, regiao, arte, cor e arquivo de dialogo.
## Para adicionar um morador: crie dialogos/<id>.dialogue e acrescente uma entrada aqui.
## "arte" aponta para uma pasta em res://art/characters/ (sprite 8 direcoes). Vazio = boneco provisorio.
## "visual": o que aparece no mundo. manifest.json de art/characters (ActorVisual), npc.json de art/npcs
## (sprite pixel billboard com idle de 2 quadros) ou modelo .glb/.gltf/.tscn. Ver visual(id).
## Retrato da caixa de dialogo: res://art/ui/retratos/<id>.png (grade 64 px ampliada 2x). Ver retrato(id).

const PASTA_DIALOGOS := "res://dialogos/"
const PASTA_RETRATOS := "res://art/ui/retratos/"
const PASTA_NPCS := "res://art/npcs/"
const PASTA_MODELOS := "res://art/models/"
## Lado interno do retrato na caixa de dialogo (TextureRect de 176 - 2*6 de margem = 164 px).
## O retrato sai num tamanho que divide 164 exatamente (82 = 2x, 41 = 4x) para pixels inteiros.
const LADO_SLOT_RETRATO := 164
const ARTE_VALE := "original_vale_v6"

const NPCS := {
	"mira": {"nome": "Mira", "titulo": "Herbalista · Botica da Mira", "regiao": "Porto Velho", "arte": "original_mira_v6", "cor": "b5482f", "visual": "res://art/characters/original_mira_v6/manifest.json"},
	"jardineira": {"nome": "Dona Iolanda", "titulo": "Horticultora · Celeiro das Sementes", "regiao": "Porto Velho", "arte": "original_gardener", "cor": "c96a2b", "visual": "res://art/characters/original_gardener/manifest.json"},
	"guardia": {"nome": "Brida Ferrolho", "titulo": "Guardiã · Posto da Guarda", "regiao": "Porto Velho", "arte": "original_guardian", "cor": "4f6b3a", "visual": "res://art/characters/original_guardian/manifest.json"},
	"sineiro": {"nome": "Mestre Anselmo", "titulo": "Sineiro · Torre do Sino", "regiao": "Porto Velho", "arte": "", "cor": "7b6a8f", "visual": "res://art/npcs/sineiro/npc.json"},
	"ferreiro": {"nome": "Gaspar Bigorna", "titulo": "Ferreiro · Ferraria do Porto", "regiao": "Porto Velho", "arte": "", "cor": "8c3b22", "visual": "res://art/npcs/ferreiro/npc.json"},
	"estalajadeira": {"nome": "Dona Rosalva", "titulo": "Estalajadeira · Estalagem da Lanterna", "regiao": "Porto Velho", "arte": "", "cor": "d9a441", "visual": "res://art/npcs/estalajadeira/npc.json"},
	"arquimago": {"nome": "Ozório Pêndulo", "titulo": "Arquimago · Torre Torta", "regiao": "Porto Velho", "arte": "", "cor": "5a4fcf", "visual": "res://art/npcs/arquimago/npc.json"},
	"capitao": {"nome": "Capitão Bartolomeu Nuvem", "titulo": "Capitão do dirigível Andorinha", "regiao": "Porto Velho", "arte": "", "cor": "2f6f8f", "visual": "res://art/npcs/capitao/npc.json"},
	"lider_orc": {"nome": "Grusha Dente-de-Ferro", "titulo": "Líder do Clã Brasa-Velha", "regiao": "Vila dos Orcs", "arte": "", "cor": "5c7d2e", "visual": "res://art/npcs/lider_orc/npc.json"},
	"condessa": {"nome": "Condessa Ofélia de Cinzalta", "titulo": "Mercado Noturno de Relíquias", "regiao": "Cidade Fantasma", "arte": "", "cor": "6e1f3a", "visual": "res://art/npcs/condessa/npc.json"},
	"lobisomem": {"nome": "Tobias do Ermo", "titulo": "Eremita da Ilha Selvagem", "regiao": "Ilha Selvagem", "arte": "", "cor": "6b5a45", "visual": "res://art/npcs/lobisomem/npc.json"},
	"dragao": {"nome": "Ambarion", "titulo": "Guardião da Rota do Âmbar", "regiao": "Rota Aérea", "arte": "", "cor": "c4572a", "visual": "res://art/npcs/dragao/npc.json"},
}

## Moradores de fundo (marcadores extras dos mapas grandes): 1-2 falas genericas cada, boneco provisorio.
## Ficam fora de ids() para o registro principal continuar com os 12 moradores com historia.
const GENERICOS := {
	"mercador_praca": {"nome": "Mercador da Praça", "titulo": "Barracas da praça · Porto Velho", "regiao": "Porto Velho", "arte": "", "cor": "a0672e", "visual": "res://art/npcs/mercador_praca/npc.json"},
	"morador_1": {"nome": "Seu Lauro", "titulo": "Morador do bairro sul", "regiao": "Porto Velho", "arte": "", "cor": "6f7d4a", "visual": "res://art/npcs/morador_1/npc.json"},
	"morador_2": {"nome": "Dona Cecília", "titulo": "Moradora da rua norte", "regiao": "Porto Velho", "arte": "", "cor": "8a5a7a", "visual": "res://art/npcs/morador_2/npc.json"},
	"crianca_praca": {"nome": "Pipo", "titulo": "Criança da praça", "regiao": "Porto Velho", "arte": "", "cor": "d08a3a", "visual": "res://art/npcs/crianca_praca/npc.json"},
	"gato": {"nome": "Gato da Praça", "titulo": "Dono da praça (segundo ele)", "regiao": "Porto Velho", "arte": "", "cor": "3a3a3a", "visual": "res://art/npcs/gato/npc.json"},
	"xama_orc": {"nome": "Xamã Urzaga", "titulo": "Xamã do Clã Brasa-Velha", "regiao": "Vila dos Orcs", "arte": "", "cor": "4f6a3a", "visual": "res://art/npcs/xama_orc/npc.json"},
	"ferreiro_orc": {"nome": "Krag Martelo-Torto", "titulo": "Forja do clã", "regiao": "Vila dos Orcs", "arte": "", "cor": "6a4a2a", "visual": "res://art/npcs/ferreiro_orc/npc.json"},
	"guerreiro_orc_1": {"nome": "Guerreiro Orc", "titulo": "Campo de treino", "regiao": "Vila dos Orcs", "arte": "", "cor": "5a6a2a", "visual": "res://art/npcs/guerreiro_orc_1/npc.json"},
	"guerreiro_orc_2": {"nome": "Sentinela Orc", "titulo": "Torre de vigia do portão sul", "regiao": "Vila dos Orcs", "arte": "", "cor": "4a5a2a", "visual": "res://art/npcs/guerreiro_orc_2/npc.json"},
	"cacadora_orc": {"nome": "Caçadora Orc", "titulo": "Caçadora do clã", "regiao": "Vila dos Orcs", "arte": "", "cor": "7a6a3a", "visual": "res://art/npcs/cacadora_orc/npc.json"},
	"anciao_orc": {"nome": "Ancião Borgo", "titulo": "Conselho da fogueira", "regiao": "Vila dos Orcs", "arte": "", "cor": "6a6a5a", "visual": "res://art/npcs/anciao_orc/npc.json"},
	"prisioneiro": {"nome": "Prisioneiro", "titulo": "Jaula perto da fogueira", "regiao": "Vila dos Orcs", "arte": "", "cor": "8a8070", "visual": "res://art/npcs/prisioneiro/npc.json"},
	"espectro_sineiro": {"nome": "Espectro do Sineiro", "titulo": "Capela do Relógio Partido", "regiao": "Cidade Fantasma", "arte": "", "cor": "8a90c8", "visual": "res://art/npcs/espectro_sineiro/npc.json"},
	"eco_arquimago": {"nome": "Eco de Ozório", "titulo": "Versão alternativa do Arquimago", "regiao": "Cidade Fantasma", "arte": "", "cor": "7a4fcf", "visual": "res://art/npcs/eco_arquimago/npc.json"},
	"mercador_reliquias": {"nome": "Mercador de Relíquias", "titulo": "Barraca abandonada", "regiao": "Cidade Fantasma", "arte": "", "cor": "5a4a6a", "visual": "res://art/npcs/mercador_reliquias/npc.json"},
	"coveiro": {"nome": "Coveiro Ermelindo", "titulo": "Portão do cemitério", "regiao": "Cidade Fantasma", "arte": "", "cor": "4a4a5a", "visual": "res://art/npcs/coveiro/npc.json"},
	"vampiro_menor_1": {"nome": "Vampiro Menor", "titulo": "Patrulha noturna", "regiao": "Cidade Fantasma", "arte": "", "cor": "5a1a2a", "visual": "res://art/npcs/vampiro_menor_1/npc.json"},
	"espectro_1": {"nome": "Espectro Queimado", "titulo": "Ruína queimada a oeste", "regiao": "Cidade Fantasma", "arte": "", "cor": "9a9ab0", "visual": "res://art/npcs/espectro_1/npc.json"},
}

## Moradores da ilha futurista (PROPOSTA): ficam num arquivo proprio para nao misturar com os 12 com historia.
const _Futuristas = preload("res://scripts/ilha_futurista/npcs_futuristas.gd")
const FUTURISTAS = _Futuristas.NPCS
## Moradores das Minas da Cinza (PROPOSTA), também em arquivo próprio.
const _Minas = preload("res://scripts/minas_da_cinza/npcs_minas.gd")
const MINAS = _Minas.NPCS

## "visual" dos moradores registrados em outros arquivos (ilha futurista e minas), que nao editamos aqui.
## Quem tem "modelo" no proprio registro usa o modelo 3D (robos, drone, vagoneta).
const VISUAIS_EXTRA := {
	"fabricadora": "res://art/npcs/fabricadora/npc.json",
	"mercador_temporal": "res://art/npcs/mercador_temporal/npc.json",
	"cientista_mira": "res://art/npcs/cientista_mira/npc.json",
	"fiscal_linhas": "res://art/npcs/fiscal_linhas/npc.json",
	"minerador_fenda": "res://art/npcs/minerador_fenda/npc.json",
	"minerador_aposentado": "res://art/npcs/minerador_aposentado/npc.json",
	"fantasma_mineiro": "res://art/npcs/fantasma_mineiro/npc.json",
	"mercador_minerio": "res://art/npcs/mercador_minerio/npc.json",
}

## Ids que aparecem como fantasmas (translucidos e com brilho).
const FANTASMAS := ["espectro_sineiro", "espectro_1", "fantasma_mineiro"]

static func ids_futuristas() -> Array:
	return FUTURISTAS.keys()

static func ids_minas() -> Array:
	return MINAS.keys()

static func ids() -> Array:
	return NPCS.keys()

static func ids_genericos() -> Array:
	return GENERICOS.keys()

## Todos que conversam: os 12 com historia + os de fundo.
static func todos_ids() -> Array:
	return NPCS.keys() + GENERICOS.keys() + FUTURISTAS.keys() + MINAS.keys()

static func existe(id: String) -> bool:
	return NPCS.has(id) or GENERICOS.has(id) or FUTURISTAS.has(id) or MINAS.has(id)

static func dados(id: String) -> Dictionary:
	return NPCS.get(id, GENERICOS.get(id, FUTURISTAS.get(id, MINAS.get(id, {}))))

static func caminho_dialogo(id: String) -> String:
	return PASTA_DIALOGOS + id + ".dialogue"

static func cor(id: String) -> Color:
	return Color(String(dados(id).get("cor", "888888")))

## Procura um id pelo nome exibido na fala ("Mira: ..."). Retorna "" se nao achar.
static func id_por_nome(nome: String) -> String:
	for id in NPCS:
		if String(NPCS[id].nome) == nome:
			return id
	for id in GENERICOS:
		if String(GENERICOS[id].nome) == nome:
			return id
	for id in FUTURISTAS:
		if String(FUTURISTAS[id].nome) == nome:
			return id
	for id in MINAS:
		if String(MINAS[id].nome) == nome:
			return id
	return ""

static func pasta_arte(id: String) -> String:
	var arte := String(dados(id).get("arte", ""))
	if arte == "":
		return ""
	var pasta := "res://art/characters/" + arte + "/"
	return pasta if FileAccess.file_exists(pasta + "manifest.json") else ""

## Caminho do visual de mundo do morador ("" = boneco provisorio).
static func visual(id: String) -> String:
	var d := dados(id)
	var v := String(d.get("visual", VISUAIS_EXTRA.get(id, "")))
	if v == "" and d.has("modelo"):
		v = PASTA_MODELOS + String(d.modelo)
	if v == "" and pasta_arte(id) != "":
		v = pasta_arte(id) + "manifest.json"
	if v == "" and FileAccess.file_exists(PASTA_NPCS + id + "/npc.json"):
		v = PASTA_NPCS + id + "/npc.json"
	if v.ends_with(".json"):
		return v if FileAccess.file_exists(v) else ""
	return v if v != "" and ResourceLoader.exists(v) else ""

## "sprite" (art/npcs), "ator" (art/characters), "modelo" (3D) ou "provisorio" (capsula).
static func tipo_visual(id: String) -> String:
	var v := visual(id)
	if v == "":
		return "provisorio"
	if v.ends_with("npc.json"):
		return "sprite"
	if v.ends_with("manifest.json"):
		return "ator"
	return "modelo"

static func eh_fantasma(id: String) -> bool:
	return id in FANTASMAS or bool(dados(id).get("fantasma", false))

static func caminho_retrato(id: String) -> String:
	var c := PASTA_RETRATOS + id + ".png"
	return c if ResourceLoader.exists(c) else ""

## Retrato: art/ui/retratos/<id>.png; sem ele, recorte da cabeca do sprite de frente (south);
## sem sprite, busto provisorio na cor do morador. Sempre em escala inteira no slot de 164 px.
static var _cache_retratos := {}
static func retrato(id: String) -> Texture2D:
	var png := caminho_retrato(id)
	if png != "":
		var t := _retrato_pintado(png)
		if t:
			return t
	var pasta := pasta_arte(id)
	if pasta != "":
		var t := _recorte_cabeca(pasta + "rotations/south.png")
		if t:
			return t
	return busto_provisorio(cor(id) if existe(id) else Color("888888"))

## Lado (divisor de LADO_SLOT_RETRATO) que comporta `lado` px: 164/k para o maior k inteiro possivel.
static func lado_inteiro(lado: int) -> int:
	for k in range(LADO_SLOT_RETRATO, 0, -1):
		if LADO_SLOT_RETRATO % k == 0 and LADO_SLOT_RETRATO / k >= lado:
			return LADO_SLOT_RETRATO / k
	return LADO_SLOT_RETRATO

## O PNG tem 128 px (grade de 64 ampliada 2x). Volta para a grade de 64 e centraliza num quadro de 82
## preenchido com a cor do fundo do retrato: 164/82 = 2x exato, sem pixel torto nem borrado.
static func _retrato_pintado(caminho: String) -> Texture2D:
	if _cache_retratos.has(caminho):
		return _cache_retratos[caminho]
	var tex: Texture2D = load(caminho)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var grade := 64 if img.get_width() % 64 == 0 else img.get_width()
	if img.get_width() != grade or img.get_height() != grade:
		img.resize(grade, grade, Image.INTERPOLATE_NEAREST)
	var lado := lado_inteiro(grade)
	var out := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	out.fill(img.get_pixel(0, 0))
	var m := (lado - grade) / 2
	out.blit_rect(img, Rect2i(0, 0, grade, grade), Vector2i(m, m))
	var it := ImageTexture.create_from_image(out)
	_cache_retratos[caminho] = it
	return it

static func retrato_vale() -> Texture2D:
	var t := _recorte_cabeca("res://art/characters/" + ARTE_VALE + "/rotations/south.png")
	if t == null:
		t = _recorte_cabeca("res://art/characters/original_apprentice/rotations/south.png")
	return t if t else busto_provisorio(Color("3f6fb0"))

## Recorte da cabeca do sprite de frente, centralizado num quadro que divide 164 (41 px = 4x).
static func _recorte_cabeca(caminho: String) -> Texture2D:
	if _cache_retratos.has(caminho):
		return _cache_retratos[caminho]
	if not ResourceLoader.exists(caminho):
		return null
	var tex: Texture2D = load(caminho)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var caixa := img.get_used_rect()
	if caixa.size.x <= 0:
		caixa = Rect2i(0, 0, img.get_width(), img.get_height())
	var lado := maxi(caixa.size.x, int(caixa.size.y * 0.62))
	var cx := caixa.position.x + caixa.size.x / 2
	var r := Rect2i(cx - lado / 2, caixa.position.y, lado, lado)
	var quadro := lado_inteiro(lado)
	var out := Image.create(quadro, quadro, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var destino := Vector2i((quadro - lado) / 2, (quadro - lado) / 2)
	# blit_rect recorta sozinho o que sai da imagem; corrige o destino quando r comeca fora
	var origem := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	destino += origem.position - r.position
	out.blit_rect(img, origem, destino)
	var it := ImageTexture.create_from_image(out)
	_cache_retratos[caminho] = it
	return it

## Busto em pixel art (32x32) gerado no codigo: cabeca + ombros na cor do morador.
static func busto_provisorio(c: Color) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var escuro := c.darkened(0.45)
	for y in 32:
		for x in 32:
			var cabeca := Vector2(x - 15.5, y - 12.5).length()
			var ombro := Vector2((x - 15.5) / 1.6, y - 31.0).length()
			if cabeca <= 7.5:
				img.set_pixel(x, y, escuro if cabeca > 6.5 else c.lightened(0.15))
			elif ombro <= 10.5 and y > 20:
				img.set_pixel(x, y, escuro if ombro > 9.5 else c)
	return ImageTexture.create_from_image(img)

## Fonte pixel (Pixelify Sans, OFL) sem ligaduras: a ligadura "fi" dela parece um "A" em tamanho pequeno.
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"
static var _fonte: Font = null
static func fonte() -> Font:
	if _fonte == null:
		if not ResourceLoader.exists(FONTE):
			return ThemeDB.fallback_font
		var v := FontVariation.new()
		v.base_font = load(FONTE)
		var ts := TextServerManager.get_primary_interface()
		v.opentype_features = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0, ts.name_to_tag("calt"): 0}
		_fonte = v
	return _fonte
