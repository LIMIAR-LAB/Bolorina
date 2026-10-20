extends RefCounted
## Posicao do jogador no mapa-mundi (M). Le art/ui/mapa_mundi.json (gerado por tools/mapa_esquematico.py
## junto com a imagem): centro/raio de cada area no mapa + limites (x,z) do mundo da cena.
## O marcador fica dentro da elipse da area, na posicao proporcional do jogador (norte = -z = cima).
const JSON_MAPA := "res://art/ui/mapa_mundi.json"
## mapa pintado (tools/mapa_mundi_pintado.py, a partir de data/areas.json): usado quando a imagem dele e a escolhida
const JSON_PINTADO := "res://art/ui/mapa_mundi_pintado.json"
const NOMES := {"fazenda": "Fazenda", "vila": "Vila", "arena": "Arena dos Orcs", "masmorra": "Masmorra (protótipo)"}
const Registro = preload("res://scripts/mundo/registro_areas.gd")
static var _dados = null
static var arquivo := JSON_MAPA

## troca o JSON de posicoes (o jogo chama ao escolher a imagem do mapa)
static func usar(caminho: String) -> void:
	if caminho != arquivo:
		arquivo = caminho
		_dados = null

static func dados() -> Dictionary:
	if _dados == null:
		_dados = {}
		var g := ProjectSettings.globalize_path(arquivo)
		var txt := FileAccess.get_file_as_string(g) if FileAccess.file_exists(g) else FileAccess.get_file_as_string(arquivo)
		var j = JSON.parse_string(txt) if txt != "" else null
		if j is Dictionary:
			_dados = j
	return _dados

## area -> ponto em pixels do mapa (1200x800); fallback = MAPA_POS do jogo
static func ponto(area: String, no_area: Node, padrao: Vector2) -> Vector2:
	var d: Dictionary = dados()
	if not d.has(area):
		return padrao
	var r: Dictionary = d[area]
	var c := Vector2(float(r.centro[0]), float(r.centro[1]))
	var m = r.get("mundo")
	var pl = no_area.get("player") if no_area else null
	if pl == null and no_area and no_area.get("jogador"):
		pl = no_area.get("jogador")
	if m == null or pl == null or not (pl is Node3D):
		return c
	var p: Vector3 = pl.position
	var u := clampf((p.x - float(m[0])) / maxf(float(m[2]) - float(m[0]), 0.01) * 2.0 - 1.0, -1.0, 1.0)
	var v := clampf((p.z - float(m[1])) / maxf(float(m[3]) - float(m[1]), 0.01) * 2.0 - 1.0, -1.0, 1.0)
	var o := Vector2(u, v)
	if o.length() > 1.0:
		o = o.normalized()
	return c + Vector2(o.x * float(r.raio[0]), o.y * float(r.raio[1])) * 0.78

static func nome(area: String) -> String:
	if Registro.existe(area):
		return Registro.nome(area)
	return String(NOMES.get(area, area.capitalize()))
