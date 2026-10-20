extends SceneTree
## Capturas das trilhas/portoes/mapa (janela 1600x900). Saida: work/caminhos_capturas/*.png
##   Godot --resolution 1600x900 --path . --script tests/caminhos_captura.gd
var jogo
const DIR := "res://work/caminhos_capturas/"
func _initialize() -> void:
	call_deferred("run")
func esperar(area: String) -> void:
	for i in 600:
		await process_frame
		if jogo.nome == area and jogo.atual and not jogo.ocupado:
			return
func pos(a, x: float, z: float) -> void:
	var g = a.gerenciador
	var p := Vector3(x, a.vila.altura(x, z) + 0.4, z)
	a.player.position = p
	a.player.velocity = Vector3.ZERO
	a.cam_seguir = Vector3(p.x, p.y - a.altura0, p.z) + a.cam_desloc
	a.apply_camera()
func foto(nome: String, n := 40) -> void:
	for i in n:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	img.save_png(ProjectSettings.globalize_path(DIR + nome + ".png"))
	print("foto ", nome)
func run() -> void:
	OS.set_environment("ILHA_SAVE", "user://caminhos_captura.json")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	await esperar("fazenda")
	var f = jogo.atual
	f.saidas_novas.armado = false
	pos(f, 38.5, -11.0)
	await foto("caminhos-fazenda-saida")
	pos(f, -6.5, -10.5)
	await foto("caminhos-fazenda-placa")
	jogo.ir("vila", "da_fazenda")
	await esperar("vila")
	var v = jogo.atual
	for sh in [["caminhos-vila-sul", 0.6, 15.2], ["caminhos-vila-leste", 16.8, -4.6], ["caminhos-vila-ruinas", -6.8, -15.4], ["caminhos-vila-placa", -2.0, -7.6]]:
		v.saidas_novas.armado = false
		v.saidas_novas.t = 0.0
		pos(v, sh[1], sh[2])
		await foto(sh[0])
	jogo.alternar_mapa()
	await foto("caminhos-mapa-jogo", 10)
	jogo.alternar_mapa()
	jogo.ir("arena", "da_vila")
	await esperar("arena")
	var ar = jogo.atual
	ar.modo_teste = true
	ar.estado_sala = "limpa"
	ar.jogador.position = Vector3(-6.5, 0, 3.0)
	await foto("caminhos-arena-portao", 60)
	quit(0)
