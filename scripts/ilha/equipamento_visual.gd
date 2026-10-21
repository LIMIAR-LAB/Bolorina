extends RefCounted
## Paper-doll da Vale: compoe a arte base + CAMADAS das pecas vestidas, quadro a quadro.
## Camadas (tools/vale_trajes.py -> art/characters/vale_trajes/): folhas transparentes alinhadas com
## a arte base, so com os pixels que a peca troca. Uma peca nova = uma camada nova no indice.json
## (vila: atlas 16 col x 48 px na ordem de indice.vila.quadros; combate: folhas iguais as de
## vale_combate_v6pal). Ordem de desenho: Equipamento.camadas() (pernas, corpo, acessorio, cabeca).
## A forma Adamantium (G, combate) usa animacoes proprias (a_*, x_*) que nao sao tocadas: transformar
## sobrepoe o visual; ao sair, volta o que esta vestido.
## Camada com "apagar_vila"/"apagar_combate" no indice (pecas do PixelLab, tools/vale_pecas_pixellab.py):
## mascara do mesmo tamanho; onde ela e opaca o pixel da base fica transparente antes da peca ser desenhada
## (ex. cabelo que sobrava para fora do elmo).
const PASTA := "res://art/characters/vale_trajes/"
const Aparencia = preload("res://scripts/avatar/aparencia.gd")
static var _indice := {}
static var _imgs := {}
static var _vila := {}
static var _folhas := {}
static var _manifest := {}
static var composicoes := 0   # quantos quadros/folhas foram compostos (testes/desempenho)

static func indice() -> Dictionary:
	if _indice.is_empty():
		var txt := FileAccess.get_file_as_string(PASTA + "indice.json")
		var d = JSON.parse_string(txt) if txt != "" else null
		_indice = d if d is Dictionary else {"vila": {"quadros": []}, "camadas": {}}
		# Patch derivado: fontes anteriores continuam intactas para auditoria/regressao.
		var correcao := PASTA + "correcao_v3/indice.json"
		if not FileAccess.file_exists(correcao): correcao=PASTA+"correcao_v2/indice.json"
		if OS.get_environment("EQUIP_LEGADO") != "1" and FileAccess.file_exists(correcao):
			var patch = JSON.parse_string(FileAccess.get_file_as_string(correcao))
			if patch is Dictionary and patch.get("base_id", "") == Aparencia.BASE_ID:
				for id in patch.get("camadas", {}):
					if _indice.camadas.has(id):
						_indice.camadas[id].merge(patch.camadas[id], true)
	return _indice

static func existe(camada: String) -> bool:
	return indice().camadas.has(camada)

## imagem RGBA8 de um PNG do projeto (arquivo solto no disco; senao o recurso importado)
static func imagem(caminho: String) -> Image:
	if _imgs.has(caminho):
		return _imgs[caminho]
	var img: Image = null
	var g := ProjectSettings.globalize_path(caminho)
	if FileAccess.file_exists(g):
		img = Image.load_from_file(g)
	if (img == null or img.is_empty()) and ResourceLoader.exists(caminho):
		var tex = load(caminho)
		if tex is Texture2D:
			img = tex.get_image()
			if img and img.is_compressed():
				img.decompress()
	if img == null or img.is_empty():
		push_warning("Equipamento: imagem nao encontrada " + caminho)
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_imgs[caminho] = img
	return img

static var _vazias := {}

## imagem transparente do tamanho pedido (fonte do blit que apaga)
static func _vazia(tam: Vector2i) -> Image:
	if not _vazias.has(tam):
		_vazias[tam] = Image.create(tam.x, tam.y, false, Image.FORMAT_RGBA8)
	return _vazias[tam]

## apaga da img (no ponto dst) os pixels onde a mascara e opaca, dentro do retangulo r da mascara
static func _apagar(img: Image, caminho: String, r: Rect2i, dst: Vector2i) -> void:
	var m := imagem(caminho)
	if m.get_width() < r.end.x or m.get_height() < r.end.y:
		return
	img.blit_rect_mask(_vazia(m.get_size()), m, r, dst)

static func _validas(camadas: Array) -> Array:
	var out: Array = []
	for c in camadas:
		if existe(String(c)):
			out.append(String(c))
	return out

## um quadro da Vale da vila/fazenda/masmorra (arquivo relativo a original_vale_v6/, ex. "run/east/003.png")
static func quadro_vila(camadas: Array, arquivo: String, perfil: Dictionary = {}) -> Texture2D:
	var ix: Dictionary = indice().vila
	var base_dir: String = String(ix.get("base", "res://art/characters/original_vale_v6/"))
	var cs := _validas(camadas)
	var i: int = (ix.quadros as Array).find(arquivo)
	if (cs.is_empty() and Aparencia.chave(perfil).is_empty()) or i < 0:
		return load(base_dir + arquivo)
	var chave := ",".join(cs) + "|" + arquivo + "|" + Aparencia.chave(perfil)
	if _vila.has(chave):
		return _vila[chave]
	var cel: int = int(ix.get("celula", 48))
	var col: int = int(ix.get("colunas", 16))
	var img: Image = Aparencia.compor(imagem(base_dir + arquivo),base_dir + arquivo,perfil)
	var r := Rect2i((i % col) * cel, (i / col) * cel, cel, cel)
	for c in cs:
		var info: Dictionary = indice().camadas[c]
		if info.has("apagar_vila"):
			_apagar(img, PASTA + String(info.apagar_vila), r, Vector2i.ZERO)
		img.blend_rect(imagem(PASTA + String(info.vila)), r, Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_vila[chave] = tex
	composicoes += 1
	return tex

## uma folha de golpes (ex. "slash_combo/slash_combo_east_sheet.png"), 8 colunas x 112 px
static func folha_combate(camadas: Array, folha: String, base_tex: Texture2D = null, perfil: Dictionary = {}) -> Texture2D:
	var ic: Dictionary = indice().get("combate", {})
	var base_dir: String = String(ic.get("base", "res://art/characters/vale_combate_v6pal/"))
	var cs := _validas(camadas)
	if cs.is_empty() and Aparencia.chave(perfil).is_empty():
		return base_tex
	var chave := ",".join(cs) + "|" + folha + "|" + Aparencia.chave(perfil)
	if _folhas.has(chave):
		return _folhas[chave]
	# base: o PNG da folha no disco (o mesmo que Folhas carregou); senao a imagem da textura
	var img: Image
	if FileAccess.file_exists(ProjectSettings.globalize_path(base_dir + folha)) or base_tex == null:
		img = imagem(base_dir + folha).duplicate()
	else:
		img = base_tex.get_image().duplicate()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img = Aparencia.compor(img,base_dir + folha,perfil)
	var nome := folha.get_file()
	for c in cs:
		var info: Dictionary = indice().camadas[c]
		if info.has("apagar_combate"):
			_apagar(img, PASTA + String(info.apagar_combate) + nome, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		var cam := PASTA + String(info.combate) + nome
		var li := imagem(cam)
		if li.get_size() == img.get_size():
			img.blend_rect(li, Rect2i(Vector2i.ZERO, li.get_size()), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_folhas[chave] = tex
	composicoes += 1
	return tex

static func _guardar_base(frames: SpriteFrames, sprite: Node) -> Dictionary:
	if sprite.has_meta("eq_base"):
		return sprite.get_meta("eq_base")
	var base := {}
	for anim in frames.get_animation_names():
		var lista: Array = []
		for i in frames.get_frame_count(anim):
			lista.append(frames.get_frame_texture(anim, i))
		base[String(anim)] = lista
	sprite.set_meta("eq_base", base)
	return base

static func _arquivo_vila(tex: Texture2D) -> String:
	if tex == null:
		return ""
	var base_dir: String = String(indice().vila.get("base", "res://art/characters/original_vale_v6/"))
	var p := tex.resource_path
	return p.substr(base_dir.length()) if p.begins_with(base_dir) else ""

## Vale da vila/fazenda/masmorra (ValeFidelidade) e idle/corrida do combate: troca cada quadro que
## veio de original_vale_v6 pelo quadro composto. Outros quadros (a_*, x_*) ficam como estao.
static func vestir_sprite(sprite: AnimatedSprite3D, camadas: Array, perfil: Dictionary = {}) -> int:
	if sprite == null or sprite.sprite_frames == null:
		return 0
	var frames := sprite.sprite_frames
	var base := _guardar_base(frames, sprite)
	var n := 0
	for anim: String in base:
		if not frames.has_animation(anim):
			continue
		var lista: Array = base[anim]
		for i in mini(lista.size(), frames.get_frame_count(anim)):
			var arq := _arquivo_vila(lista[i])
			if arq == "":
				continue
			var t := quadro_vila(camadas, arq,perfil)
			if frames.get_frame_texture(anim, i) != t:
				frames.set_frame(anim, i, t, frames.get_frame_duration(anim, i))
				n += 1
	sprite.set_meta("eq_camadas", camadas.duplicate())
	sprite.set_meta("avatar_perfil", Aparencia.normalizar(perfil))
	return n

## Vale do combate (jogador_combate.gd): idle/corrida + golpes c_<mov>_<dir>
static func vestir_combate(jogador, camadas: Array, perfil: Dictionary = {}, animacoes: Array = []) -> int:
	if jogador == null or jogador.get("sprite") == null:
		return 0
	var sprite: AnimatedSprite3D = jogador.sprite
	var n := vestir_sprite(sprite, camadas,perfil)
	var frames := sprite.sprite_frames
	var base: Dictionary = sprite.get_meta("eq_base")
	for anim: String in base:
		if not anim.begins_with("c_") or not frames.has_animation(anim):
			continue
		if not animacoes.is_empty() and not animacoes.has(anim):
			continue
		var lista: Array = base[anim]
		if lista.is_empty() or not lista[0] is AtlasTexture:
			continue
		var partes := anim.substr(2)
		var dir := partes.get_slice("_", partes.get_slice_count("_") - 1)
		var mov := partes.substr(0, partes.length() - dir.length() - 1)
		var folha := "%s/%s_%s_sheet.png" % [mov, mov, dir]
		var base_atlas: Texture2D = (lista[0] as AtlasTexture).atlas
		var atlas := folha_combate(camadas, folha, base_atlas,perfil)
		for i in mini(lista.size(), frames.get_frame_count(anim)):
			var orig: AtlasTexture = lista[i]
			if atlas == base_atlas:
				frames.set_frame(anim, i, orig, frames.get_frame_duration(anim, i))
				continue
			var at := AtlasTexture.new()
			at.atlas = atlas
			at.region = orig.region
			frames.set_frame(anim, i, at, frames.get_frame_duration(anim, i))
			n += 1
	return n

## Descarta apenas previews personalizados. Sprites em uso mantem suas referencias.
static func limpar_cache_personalizado() -> void:
	for cache in [_vila,_folhas]:
		for key in cache.keys():
			if String(key).contains(Aparencia.BASE_ID): cache.erase(key)

## quadros compostos de uma animacao da vila (previa da tela de equipamento)
static func quadros_previa(camadas: Array, anim: String, perfil: Dictionary = {}) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if _manifest.is_empty():
		var m = JSON.parse_string(FileAccess.get_file_as_string(String(indice().vila.get("base", "res://art/characters/original_vale_v6/")) + "manifest.json"))
		_manifest = m if m is Dictionary else {"anims": {}}
	var man: Dictionary = _manifest
	if not man.anims.has(anim):
		return out
	for f in man.anims[anim].files:
		out.append(quadro_vila(camadas, String(f), perfil))
	return out
