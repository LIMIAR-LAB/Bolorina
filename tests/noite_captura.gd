extends SceneTree
## Capturas da noite (com janela; save de teste): mapa-mundi, Porto Velho provisorio, balcao da forja,
## Vale com o conjunto de ferro e a fazenda grande. Saida: docs/noite-*.png
const SAVE := "user://ilha_noite_captura.json"
const Equip = preload("res://scripts/ilha/equipamento.gd")
var jogo

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func esperar(id: String) -> void:
	for i in 900:
		await process_frame
		if jogo.nome == id and not jogo.ocupado and jogo.atual != null:
			break
	await create_timer(0.8).timeout

func foto(nome: String) -> void:
	await fr(6)
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://docs/noite-%s.png" % nome))
	print("INFO docs/noite-%s.png" % nome)

func perto(a, zoom := 9.0) -> void:
	if a.get("vila") == null:
		return
	a.camera_travada = true
	a.vila.cam_alvo = Vector3(a.player.position.x, 0, a.player.position.z)
	a.vila.cam_size = zoom
	a.apply_camera()

func _run() -> void:
	create_timer(300.0).timeout.connect(func(): quit(2))
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "porto_velho")
	OS.set_environment("ILHA_SPAWN", "padrao")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await esperar("porto_velho")
	var a = jogo.atual
	perto(a, 16.0)
	await foto("porto-velho")
	jogo.alternar_mapa()
	await foto("mapa")
	jogo.alternar_mapa()
	# balcao da Helena (forja) com materiais
	var e = jogo.estado
	e.ouro = 900
	e.somar("minerio_ferro", 6)
	e.somar("carvao", 2)
	e.somar("lingote_cobre", 4)
	var an = a.area_npcs
	var i: int = an.npc_por_id("helena")
	a.player.global_position = an.npcs[i].no.global_position + Vector3(1.0, 0.3, 0.6)
	perto(a, 9.0)
	an.falar(i)
	await foto("conversa")
	an.abrir_balcao()
	an.aba = an.abas.find("forjar")
	an._listar()
	await foto("forja")
	an.fechar()
	# Vale com o conjunto de ferro
	for p in ["capacete_ferro", "peito_ferro", "luvas_ferro", "botas_ferro"]:
		Equip.ganhar(e.equipamento, p)
		Equip.equipar(e.equipamento, p)
	jogo.vestir_atual()
	perto(a, 6.0)
	await foto("conjunto-ferro")
	jogo.viajar("fazenda_grande")
	await esperar("fazenda_grande")
	perto(jogo.atual, 34.0)
	await foto("fazenda-grande")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(0)
