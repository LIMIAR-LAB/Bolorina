extends RefCounted
## Carrega folhas PNG em tempo de execucao (Image.load_from_file), sem depender da importacao
## do editor: a pasta art/characters/vale_combate_gamelab/ nao recebe arquivos .import.
static var _cache := {}

static func textura(caminho: String) -> Texture2D:
	if _cache.has(caminho):
		return _cache[caminho]
	var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if img == null or img.is_empty():
		push_warning("Folha nao encontrada: " + caminho)
		img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	_cache[caminho] = tex
	return tex

static func quadros(caminho: String, celula: Vector2i, colunas: int, total: int) -> Array[Texture2D]:
	var base := textura(caminho)
	var lista: Array[Texture2D] = []
	for i in total:
		var at := AtlasTexture.new()
		at.atlas = base
		at.region = Rect2((i % colunas) * celula.x, (i / colunas) * celula.y, celula.x, celula.y)
		lista.append(at)
	return lista
