extends SceneTree
## Estados visuais do solo: sem arar -> arada -> semeada -> crescendo -> pronta; molhada mais escura.
## Usa a ferramenta de verdade (ui.usar) para arar, plantar e regar. FAZ_CAP=1 grava docs/fazenda-terra-*.png
var checks := 0
var failures := 0
var f
func check(ok: bool, t: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + t)

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func usar_em(c: Vector2i, slot: int) -> String:
	f.player.position = Vector3(c.x - 1, f.vila.altura(float(c.x - 1), float(c.y)) + 0.4, c.y)
	f.facing = Vector3(1, 0, 0)
	f.ui.mouse_t = -100.0
	f.estado.slot = slot
	f.ui.cd = 0.0
	f.ui.usar()
	await fr(2)
	return String(f.message.text)

func tex(c: Vector2i) -> String:
	return String(f.solo.nos[c].get_meta("textura_solo", "")) if f.solo.nos.has(c) else ""

func lum(c: Vector2i) -> float:
	var n: MeshInstance3D = f.solo.nos[c].get_node_or_null("Topo")
	if n == null or n.material_override == null:
		return -1.0
	var img: Image = (n.material_override as StandardMaterial3D).albedo_texture.get_image()
	var soma := 0.0
	for y in range(4, 28):
		for x in range(4, 28):
			soma += img.get_pixel(x, y).get_luminance()
	return soma / 576.0

func foto(nome: String, alvo: Vector3, tam: float) -> void:
	f.camera_travada = true
	f.vila.cam_alvo = Vector3(alvo.x, 0, alvo.z)
	f.vila.cam_size = tam
	f.apply_camera()
	await fr(4)
	var img: Image = f.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % nome))
	print("INFO captura docs/%s.png" % nome)

func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_terra_teste.json")
	OS.set_environment("ILHA_AREA", "fazenda")
	OS.set_environment("ILHA_SPAWN", "inicio")
	if FileAccess.file_exists("user://ilha_terra_teste.json"):
		DirAccess.remove_absolute("user://ilha_terra_teste.json")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 150:
		await process_frame
		if jogo.atual and jogo.atual.get("ui") != null and jogo.atual.ui != null:
			break
	f = jogo.atual
	await create_timer(0.8).timeout
	# fileira de 8 celulas livres: [grama, arada, arada molhada, semeada, semeada molhada, crescendo 1, crescendo 2, pronta]
	var linha: Array[Vector2i] = []
	var cands: Array = []
	for z in range(-18, 10):
		for x0 in range(-18, 10):
			cands.append(Vector2i(x0, z))
	cands.sort_custom(func(a, b): return Vector2(a - Vector2i(-6, -4)).length() < Vector2(b - Vector2i(-6, -4)).length())
	for cand in cands:
		var x0: int = cand.x
		var z: int = cand.y
		if true:
			var ok := true
			for k in 9:
				var c := Vector2i(x0 + k, z)
				if f.solo.tem(c) or not f.ui.aravel(c) or not f.ui.aravel(c + Vector2i(0, 1)) or not f.ui.aravel(c + Vector2i(0, -1)):
					ok = false
					break
			if ok:
				for k in range(1, 9):
					linha.append(Vector2i(x0 + k, z))
				break
		if not linha.is_empty():
			break
	check(linha.size() == 8, "fileira livre para o teste %s" % (str(linha[0]) if linha.size() > 0 else "-"))
	if linha.size() < 8:
		quit(1); return
	var grama: Vector2i = linha[0]
	check(not f.solo.nos.has(grama), "sem arar: nenhuma terra desenhada (grama)")
	for k in range(1, 8):
		await usar_em(linha[k], 0)
	check(f.solo.tem(linha[1]) and tex(linha[1]) == "arada" and f.solo.estado_visual(linha[1]) == "arada", "enxada -> terra arada limpa (%s)" % tex(linha[1]))
	f.estado.regador = 40
	await usar_em(linha[2], 4)
	check(tex(linha[2]) == "arada_molhada", "regador -> arada molhada (%s)" % tex(linha[2]))
	check(lum(linha[2]) < lum(linha[1]) * 0.75, "molhada mais escura (%.2f < %.2f)" % [lum(linha[2]), lum(linha[1])])
	var antes: int = f.estado.qtd("semente_nabo")
	for k in range(3, 8):
		await usar_em(linha[k], 5)
	check(f.estado.qtd("semente_nabo") == antes - 5, "5 sementes de nabo gastas")
	check(tex(linha[3]) == "semeada" and f.solo.estado_visual(linha[3]) == "semeada", "semente -> solo semeado (%s)" % tex(linha[3]))
	check(tex(linha[3]) != tex(linha[1]), "semeada visivelmente diferente da arada vazia")
	await usar_em(linha[4], 4)
	check(tex(linha[4]) == "semeada_molhada", "semeada + regador -> semeada molhada")
	# crescimento: estagios 1, 2 e pronta (3)
	for par in [[5, 1], [6, 2], [7, 3]]:
		var s = f.solo.dados(linha[par[0]])
		s.estagio = par[1]
		s.dias = par[1] * 2
	f.solo.aplicar()
	await fr(2)
	for par in [[5, 1], [6, 2], [7, 3]]:
		var c: Vector2i = linha[par[0]]
		var p = f.solo.plantas.get(c)
		check(tex(c) == "plantada" and p != null and int(p.get_meta("estagio")) == par[1], "estagio %d: solo cultivado + planta (%s)" % [par[1], tex(c)])
	check(f.solo.maduro(linha[7]), "ultima pronta para colher")
	check(f.solo.plantas[linha[5]].get_node_or_null("Broto") != null and f.solo.plantas[linha[6]].get_node_or_null("Broto") != null, "estagios 1 e 2 com broto visivel")
	var deco := 0
	var escondida := 0
	for k in range(1, 8):
		for e in f.solo._indice_chao.get(linha[k], []):
			deco += 1
			var t: Transform3D = e[0].get_instance_transform(int(e[1]))
			if t.basis.get_scale().x < 0.01:
				escondida += 1
	var deco_grama: int = f.solo._indice_chao.get(grama, []).size()
	check(deco > 0 and escondida == deco, "terra arada sem mato/folhas por cima (%d/%d escondidas)" % [escondida, deco])
	check(deco_grama == 0 or not f.solo.limpas.has(grama), "grama sem arar mantem a decoracao (%d)" % deco_grama)
	check(f.solo.plantas.get(linha[3]) != null and f.solo.plantas[linha[3]].get_child_count() == 0, "semeada sem bolinhas 3D (a textura mostra as covas)")
	var dist := {}
	for k in range(1, 8):
		dist[tex(linha[k])] = true
	check(dist.size() == 5, "5 visuais distintos na fileira %s" % str(dist.keys()))
	# colher a pronta com a mao: volta a arada
	await usar_em(linha[7], 8)
	check(f.estado.qtd("nabo") >= 1 and tex(linha[7]) == "arada", "mao colhe -> volta a terra arada (%s)" % tex(linha[7]))
	f.solo.dados(linha[7]).estagio = 3
	f.solo.dados(linha[7]).cultura = "nabo"
	f.solo.aplicar()
	f.ui.selecionar(0)
	check(f.ui.item() == "enxada", "barra de ferramentas intacta (slot 1 = enxada)")
	if OS.get_environment("FAZ_CAP") == "1":
		f.player.position = Vector3(grama.x - 1.5, f.vila.altura(float(grama.x) - 1.5, float(grama.y) + 1.0) + 0.4, grama.y + 1.0)
		if f.ui.cursor:
			f.ui.cursor.scale = Vector3.ONE * 0.001
		var meio := Vector3(grama.x + 3.5, 0, grama.y)
		await create_timer(0.3).timeout
		await foto("fazenda-terra-estagios", meio, 5.5)
		await foto("fazenda-terra-arada", Vector3(grama.x + 1, 0, grama.y), 3.6)
		await foto("fazenda-terra-semeada", Vector3(grama.x + 3.5, 0, grama.y), 3.6)
		await foto("fazenda-terra-crescendo", Vector3(grama.x + 6, 0, grama.y), 3.6)
		await foto("fazenda-terra-canteiro", Vector3(-1.5, 0, -7), 7.0)
		OS.set_environment("SOLO_V1", "1")
		f.solo.recriar()
		await fr(3)
		await foto("fazenda-terra-antes", meio, 7.0)
		OS.set_environment("SOLO_V1", "")
		f.solo.recriar()
		await fr(2)
		f.ui.cursor.scale = Vector3.ONE
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
