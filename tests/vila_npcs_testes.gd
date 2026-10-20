extends SceneTree
## Vila: 3 moradores (Sr. Armando loja, Dona Lurdes, Tobias guia), conversa com E, amizade +1/dia,
## loja compra/vende com ouro; mapa (M) abre/fecha; entrada da masmorra nas ruinas.
## NPC_CAP=1 grava docs/vila-npcs.png, docs/vila-loja.png, docs/mapa-jogo.png
var checks := 0
var failures := 0
var jogo
var v
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + text)
func _init() -> void:
	call_deferred("_run")
func fr(n: int) -> void:
	for i in n:
		await process_frame
func foto(nome: String) -> void:
	if OS.get_environment("NPC_CAP") != "1":
		return
	await fr(4)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/%s.png" % nome))
	print("INFO captura docs/%s.png" % nome)
func perto_de(i: int) -> void:
	var n: Node3D = v.npcs.npcs[i].no
	v.player.position = n.position + Vector3(0.9, 0.2, 0.6)
	v.player.velocity = Vector3.ZERO
	await create_timer(1.2).timeout

func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_npcs_teste.json")
	OS.set_environment("ILHA_AREA", "vila")
	OS.set_environment("ILHA_SPAWN", "da_fazenda")
	if FileAccess.file_exists("user://ilha_npcs_teste.json"):
		DirAccess.remove_absolute("user://ilha_npcs_teste.json")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 200:
		await process_frame
		if jogo.atual and jogo.atual.get("npcs") != null and jogo.atual.npcs != null and jogo.atual.npcs.npcs.size() > 0:
			break
	v = jogo.atual
	await create_timer(0.8).timeout
	var m = v.npcs
	var ids := []
	for n in m.npcs:
		ids.append(String(n.dados.id))
	check(ids.size() == 3 and "armando" in ids and "lurdes" in ids and "tobias" in ids, "3 moradores na vila %s" % str(ids))
	var andaveis := true
	for n in m.npcs:
		var p: Vector3 = n.no.position
		if absf(p.y) > 3.0: andaveis = false
	check(andaveis, "moradores em chao valido")
	var e = jogo.estado
	var it := ids.find("tobias")
	await perto_de(it)
	check(m.perto() == it, "perto do Tobias")
	var am0: int = int(e.amizade.get("tobias", 0))
	check(m.tecla_e() and m.painel.visible and String(m.texto_l.text).length() > 5, "E: Tobias fala (%s)" % String(m.texto_l.text).left(60))
	check(int(e.amizade.get("tobias", 0)) == am0 + 1, "amizade +1 ao conversar")
	var ruinas := false
	for f in m.npcs[it].dados.falas:
		if String(f).to_lower().contains("ruina") or String(f).to_lower().contains("ruína"):
			ruinas = true
	check(ruinas, "guia fala das ruinas")
	await foto("vila-npcs")
	while m.falando >= 0:
		m.tecla_e()
	m.falar(it)
	check(int(e.amizade.get("tobias", 0)) == am0 + 1, "so +1 de amizade por dia")
	m.fechar()
	# loja
	var ia := ids.find("armando")
	await perto_de(ia)
	e.ouro = 100
	m.tecla_e()
	m.tecla_e()
	check(m.loja_aberta, "Sr. Armando abre a loja")
	var n0: int = e.qtd("semente_nabo")
	var msg: String = m.opcao_loja(1)
	check(e.qtd("semente_nabo") == n0 + 1 and e.ouro == 80, "comprou semente de nabo por 20 (%s)" % msg)
	var r0: int = e.qtd("racao")
	m.opcao_loja(4)
	check(e.qtd("racao") == r0 + 5 and e.ouro == 50, "comprou racao x5 por 30")
	e.ouro = 10
	msg = m.opcao_loja(3)
	check(e.ouro == 10 and msg != "" and not msg.begins_with("Comprou"), "sem ouro nao compra (%s)" % msg)
	e.itens["ovo"] = 4
	e.itens["peixe_dourado"] = 1
	m.opcao_loja(5)
	check(e.ouro == 10 + 4 * e.PRECO_OVO + 140 and e.qtd("ovo") == 0, "vendeu ovos e peixe (ouro %d)" % e.ouro)
	await foto("vila-loja")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	check(m.entrada(ev) and not m.loja_aberta and not m.painel.visible, "Esc fecha a loja")
	# mapa
	jogo.alternar_mapa()
	check(jogo.mapa_camada.visible and jogo.mapa_img.texture != null, "M: mapa abre com imagem")
	await foto("mapa-jogo")
	jogo.alternar_mapa()
	check(not jogo.mapa_camada.visible, "M: mapa fecha")
	# entrada da masmorra
	var tem := false
	for s in v.SAIDAS:
		if String(s.area) == "masmorra": tem = true
	check(tem and v.SPAWNS.has("da_masmorra"), "portao das ruinas leva a masmorra e volta (da_masmorra)")
	var sp: Vector2 = v.SPAWNS.da_masmorra
	check(sp.distance_to(Vector2(-6, -20)) > 1.5, "spawn de volta fora do gatilho")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
