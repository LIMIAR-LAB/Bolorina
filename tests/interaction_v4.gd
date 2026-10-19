extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		push_error(label)
func run() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.demo_mode=true
	for i in range(10):
		await physics_frame
	var save_path: String=game.SAVE_FILE
	var existed:=FileAccess.file_exists(save_path)
	var bytes:=FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
	check(not game.recruited,"NPC nao segue automaticamente o save anterior")
	check(game.ally==game.npc,"Companhia usa a propria NPC, sem duplicata")
	game.player.position=game.npc.position+Vector3(0.7,0,0)
	game._interact()
	check(not game.recruited,"Conversar nao ativa acompanhamento")
	game._toggle_companion()
	check(game.recruited,"C ativa companhia explicitamente")
	var original: Vector3=game.npc.position
	for i in range(90):
		await physics_frame
	check(game.npc.position.distance_to(original)<0.01,"NPC fica quieta quando jogador esta parado perto")
	game.demo_input=Vector2.DOWN
	var previous: Vector3=game.npc.position
	var largest_step:=0.0
	for i in range(60):
		await physics_frame
		largest_step=maxf(largest_step,game.npc.position.distance_to(previous))
		previous=game.npc.position
	game.demo_input=Vector2.ZERO
	for i in range(150):
		await physics_frame
	var rested: Vector3=game.npc.position
	for i in range(60):
		await physics_frame
	check(game.npc.position.distance_to(rested)<0.02,"Companheira para sem oscilar depois do percurso")
	check(largest_step<0.1,"Companheira nao teleporta ao seguir")
	game.recruited=false
	check(game.art_world.leaf_materials.size()>0,"Materiais de folhas usam shader de luz e transmissao")
	check(game.farm.plots.size()==9,"Horta possui nove quadrados individuais")
	var a: Vector3=game.farm.plots[0].position
	var b: Vector3=game.farm.plots[1].position
	check(a.distance_to(b)-1.05>0.6,"Ha corredor maior que o diametro de colisao entre colunas")
	game.farm.plots[0].stage=0
	game.farm.plots[0].watered=false
	game.player.position=a+Vector3(0.7,0,0)
	game._farm_action(false)
	check(game.farm.plots[0].stage==1,"E planta no quadrado mais proximo")
	game.farm.next_day()
	check(game.farm.plots[0].stage==1,"Muda sem agua nao amadurece")
	game._farm_action(true)
	check(game.farm.plots[0].watered,"R molha somente o canteiro selecionado")
	check(not game.farm.plots[1].watered,"Rega nao molha vizinho")
	game.farm.next_day()
	check(game.farm.plots[0].stage==2,"Muda regada cresce no amanhecer")
	var before: int=game.harvests
	game._farm_action(false)
	check(game.harvests==before+1 and game.farm.plots[0].stage==0,"Colheita libera quadrado")
	game.atmosphere.set_hour(16)
	var orientation: Vector3=game.atmosphere.sun.rotation_degrees
	game.atmosphere.toggle()
	game.atmosphere.advance(17.5)
	check(game.atmosphere.hour>17 and game.atmosphere.hour<20,"Por do sol interpola horario")
	check(game.atmosphere.sun.rotation_degrees.distance_to(orientation)>10,"Sol se move e altera direcao das sombras")
	game.atmosphere.advance(20)
	check(game.atmosphere.sun.light_energy<0.01 and game.atmosphere.moon.light_energy>0.2,"Noite substitui luz solar pela lua")
	check(not game.atmosphere.shafts[0].visible,"Feixes solares desaparecem a noite")
	if not game.cut_tree.felled:
		var location: Vector3=game.cut_tree.global_position+Vector3(1,0,0)
		game.cut_tree.hit(location)
		check(game.cut_tree.health==2,"Primeiro golpe danifica arvore")
		game.cut_tree.cooldown=0
		game.cut_tree.hit(location)
		game.cut_tree.cooldown=0
		game.cut_tree.hit(location)
		check(game.cut_tree.felled and game.cut_tree.logs==3,"Terceiro golpe derruba arvore e gera madeira")
		var collected: int=game.cut_tree.collect(location)
		check(collected==3 and game.cut_tree.collect(location)==0,"Madeira e recolhida uma unica vez")
	game.farm.plots[2].stage=1
	game.farm.plots[2].watered=true
	game._save()
	var persisted=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(persisted.plots[2].watered and persisted.plots[2].stage==1,"Save preserva rega e estagio por quadrado")
	check(persisted.tree_felled and persisted.tree_logs==0,"Save preserva arvore cortada sem duplicar madeira")
	if existed:
		var file:=FileAccess.open(save_path,FileAccess.WRITE)
		file.store_buffer(bytes)
		file.close()
	else:
		DirAccess.remove_absolute(save_path)
	print("Interacoes V4: ",checks-failures,"/",checks," verificacoes")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
