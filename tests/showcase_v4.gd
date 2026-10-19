extends SceneTree
var game
var phase:=0
var elapsed:=0.0
var caption: Label
var phases: Array=[]
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo_mode=true
	game.suppress_saves=true
	game.recruited=false
	game.zoom_target=0.85
	game.farm.restore([])
	for plot in game.farm.plots:
		plot.stage=0
		plot.watered=false
	game.farm.refresh()
	game.atmosphere.set_hour(16)
	if game.cut_tree.felled:
		push_error("A captura precisa de uma arvore ainda em pe no save.")
		quit(1)
		return
	caption=Label.new()
	caption.position=Vector2(28,90)
	caption.add_theme_font_size_override("font_size",20)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	game.ui_layer.add_child(caption)
	phases=[
		["wait",Vector3.ZERO,1.3,"Personagem original em proporcoes compactas"],
		["move",Vector3(-3.9,0,1.5),5.0,"Horta: quadrados individuais e corredores"],
		["plant",Vector3.ZERO,1.0,"E: plantar no quadrado selecionado"],
		["water",Vector3.ZERO,1.2,"R: regar; a terra escurece e recebe agua"],
		["move",Vector3(-9.9,0,1.5),7.0,"Passagem pela horta ate a arvore de recurso"],
		["chop",Vector3.ZERO,0.7,"F: primeiro golpe; folhas e tronco reagem"],
		["chop",Vector3.ZERO,0.7,"F: segundo golpe"],
		["chop",Vector3.ZERO,2.0,"F: terceiro golpe; queda e toco"],
		["collect",Vector3.ZERO,1.0,"E: recolher a madeira"],
		["move",Vector3(-4,0,1.5),7.0,"Retorno pelo portao"],
		["move",Vector3(0,0,2),5.0,"Praca e lote reservado para construcao"],
		["sunset",Vector3.ZERO,36.0,"L: o sol se move ate anoitecer"],
		["wait",Vector3.ZERO,2.0,"Lua, lanternas e sombras ao anoitecer"]]
	if "--interactions-only" in OS.get_cmdline_user_args():
		phases=phases.slice(0,11)
		phases.append(["wait",Vector3.ZERO,1.5,"Horta individual, madeira e passagem pelo portao"])
func _physics_process(delta: float) -> bool:
	if game==null or phases.is_empty():
		return false
	if phase>=phases.size():
		game.queue_free()
		quit()
		return true
	var current: Array=phases[phase]
	caption.text=current[3]
	game.demo_input=Vector2.ZERO
	if current[0]=="move":
		var difference: Vector3=current[1]-game.player.position
		difference.y=0
		if difference.length()<0.18:
			elapsed=0
			phase+=1
			return false
		var direction:=difference.normalized().rotated(Vector3.UP,-PI/4)
		game.demo_input=Vector2(direction.x,direction.z)
	elif elapsed==0:
		match current[0]:
			"plant":game._farm_action(false)
			"water":game._farm_action(true)
			"chop":
				var input:=InputEventKey.new()
				input.pressed=true
				input.physical_keycode=KEY_F
				game._unhandled_key_input(input)
			"collect":game._interact()
			"sunset":game.atmosphere.toggle()
	elapsed+=delta
	if elapsed>=current[2]:
		if current[0]=="move":
			push_error("Movimento de demonstracao nao alcancou o alvo: "+str(current[1])+" a partir de "+str(game.player.position))
			quit(1)
		elapsed=0
		phase+=1
	return false
