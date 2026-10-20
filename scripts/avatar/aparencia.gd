extends RefCounted
## Corpo unico. Cores/hair antes das camadas de equipamento; nao escreve assets nem save.
const BASE_ID := "vale_unica_gamelab_v1"
const INDICE := "res://art/characters/avatar_mascaras/indice.json"
const ORDEM := ["pele","camisa","calca","cabelo"]
const PADRAO := {"pele":"e7b382","camisa":"3e8275","calca":"3c3a45","cabelo":"6c341e"}
static var _indice := {}
static var _cache := {}
static var composicoes := 0
const LIMITE_CACHE := 208

static func limpar_cache() -> void:
	_cache.clear()

static func novo() -> Dictionary:
	return {"versao":1,"base_id":BASE_ID,"nome":"Vale","fazenda":"Fazenda do Alto","cabelo_id":"original","usar_cores":false,"cores":PADRAO.duplicate()}

static func normalizar(valor) -> Dictionary:
	var out := novo()
	if not valor is Dictionary:
		return out
	for campo in ["nome","fazenda"]:
		if valor.get(campo) is String:
			var text: String = valor[campo].strip_edges().replace("\n"," ").replace("\r"," ").replace("\t"," ").left(40)
			if not text.is_empty(): out[campo] = text
	out.usar_cores = valor.get("usar_cores",false)==true
	if valor.get("cores") is Dictionary:
		for campo in ORDEM:
			var text: String = str(valor.cores.get(campo,PADRAO[campo])).trim_prefix("#")
			if text.length()==6 and text.is_valid_hex_number():
				out.cores[campo] = text.to_lower()
	return out

static func chave(perfil: Dictionary) -> String:
	var p := normalizar(perfil)
	if not p.usar_cores: return ""
	return BASE_ID+"|"+"|".join(ORDEM.map(func(c):return p.cores[c]))

static func indice() -> Dictionary:
	if _indice.is_empty() and FileAccess.file_exists(INDICE):
		_indice = JSON.parse_string(FileAccess.get_file_as_string(INDICE))
	return _indice

static func compor(base: Image, caminho: String, perfil: Dictionary) -> Image:
	var key := chave(perfil)
	if key.is_empty(): return base.duplicate()
	var full := caminho+"|"+key
	if _cache.has(full): return _cache[full].duplicate()
	var source: Dictionary = indice().get("sources",{}).get(caminho,{})
	if source.is_empty():
		push_warning("Aparencia: sem mascara para "+caminho)
		return base.duplicate()
	var mask := Image.load_from_file(ProjectSettings.globalize_path(source.mask))
	if mask==null or mask.get_size()!=base.get_size():
		push_error("Aparencia: mascara incompativel "+caminho)
		return base.duplicate()
	var p := normalizar(perfil)
	var colors: Array[Color] = [Color.WHITE]
	for campo in ORDEM: colors.append(Color(p.cores[campo]))
	var pixels := base.get_data()
	var ids := mask.get_data()
	var lookup := {}
	for i in range(0,pixels.size(),4):
		var region: int = ids[i]
		if region==0 or pixels[i+3]==0: continue
		var original := int(pixels[i])<<16 | int(pixels[i+1])<<8 | int(pixels[i+2])
		var lookup_key := region*16777216+original
		var rgb: Color
		if lookup.has(lookup_key):
			rgb = lookup[lookup_key]
		else:
			var value := float(maxi(pixels[i],maxi(pixels[i+1],pixels[i+2])))/255.0
			var shade := value/maxf(0.1,float(source.value_ref.get(str(region),0.6)))
			var target: Color = colors[region]
			rgb = Color.from_hsv(target.h,target.s,clampf(target.v*shade,0,1))
			lookup[lookup_key] = rgb
		pixels[i] = roundi(rgb.r*255)
		pixels[i+1] = roundi(rgb.g*255)
		pixels[i+2] = roundi(rgb.b*255)
	var result := Image.create_from_data(base.get_width(),base.get_height(),false,Image.FORMAT_RGBA8,pixels)
	if _cache.size() >= LIMITE_CACHE:
		_cache.erase(_cache.keys()[0])
	_cache[full] = result
	composicoes += 1
	return result.duplicate()
