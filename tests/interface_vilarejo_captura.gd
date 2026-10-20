extends SceneTree
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const Inv = preload("res://scripts/ilha/inventario.gd")
class Hospedeiro:
	extends Node
	var estado
	var atual = null
	func vestir_atual(): pass
var ui
func _init(): call_deferred("run")
func frames(n):
	for i in n: await process_frame
func foto(nome):
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/interface/"+nome+OS.get_environment("INTERFACE_SUFIXO")+".png"))
func run():
	OS.set_environment("ILHA_SAVE","user://ilha_interface_captura.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/interface"))
	var bg=TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://art/ui/telas/porto_velho.png")))
	root.add_child(bg)
	var g=Hospedeiro.new();g.estado=Estado.new();root.add_child(g)
	g.estado.ouro=340
	for par in [["madeira",30],["pedra",23],["fibra",14],["carvao",4],["ovo",6],["nabo",5],["minerio_cobre",6],["pocao_vida",2]]:
		g.estado.somar(par[0],par[1])
	ui=load("res://scripts/ilha/inventario_tela.gd").new()
	root.add_child(ui);ui.montar(g)
	ui.abrir("tudo");await foto("inventario")
	ui.ir_aba("equipamento");await foto("equipamento")
	ui.ir_aba("fabricar");await foto("fabricar")
	ui.fechar()
	ui.abrir_bau(Inv.bau_casa(g.estado))
	await foto("bau")
	ui.fechar()
	print("CAPTURAS_OK")
	quit()

