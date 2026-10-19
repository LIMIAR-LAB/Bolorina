extends SceneTree
class RampDriver extends Node:
	var body: CharacterBody3D
	var maximum_error := 0.0
	func _physics_process(_delta: float) -> void:
		if body.position.z > -13.1:
			body.velocity = Vector3(0,0 if body.is_on_floor() else -4,-3)
			body.move_and_slide()
		var layout = preload("res://scripts/visual_world.gd")
		maximum_error = maxf(maximum_error,absf(body.position.y-layout.height_at(body.position.x,body.position.z)))
var failures := 0
var checks := 0
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		await physics_frame
	check(game.sprite.sprite_frames.get_frame_count("run_south") == 8,"Corrida usa multiplos quadros reais")
	check(game.npc.sprite_frames.get_frame_count("idle_south") >= 1,"NPC possui pose original de repouso")
	game.sprite.set_motion(true,true,false,false)
	check(game.sprite.animation == "run_south","Corrida seleciona animacao correta")
	game.sprite.set_motion(false,false,false,false)
	check(game.sprite.animation == "idle_south","Repouso retorna a idle")
	for i in range(8):
		var direction := Vector2(cos(i*PI/4),sin(i*PI/4))
		game.sprite.set_direction(direction)
		game.sprite.set_motion(true,false,false,false)
		check(game.sprite.sprite_frames.get_frame_count(game.sprite.animation)==8,"Oito quadros na direcao %d"%i)
		check(not game.sprite.flip_h,"Direcao tem arte propria, sem espelhamento")
	check(game.sprite.manifest.original and game.npc.manifest.original,"Personagens ativos sao originais")
	check(game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,"Camera usa projecao isometrica")
	var orientation: Quaternion = game.phantom.quaternion
	game.player.position.x += 5
	for i in range(30):
		await process_frame
	check(game.phantom.quaternion.is_equal_approx(orientation),"Orientacao permanece fixa ao mover")
	check(game.phantom != null and game.camera.get_child_count() > 0,"Phantom Camera conectado")
	check(game.ground.find_child("VegetacaoSimpleGrass",true,false) != null,"Vegetacao do addon integrada")
	var mesh: Mesh = game.art_world.ground_mesh.mesh
	print("Normal terreno: ",mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0])
	check(mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0].y > 0,"Normais do terreno apontam para cima")
	game.set_physics_process(false)
	game.player.position = Vector3(0,0.1,0)
	var driver := RampDriver.new()
	driver.body = game.player
	root.add_child(driver)
	for i in range(360):
		await physics_frame
	var maximum_error: float = driver.maximum_error
	driver.queue_free()
	print("Fim da rampa: ",game.player.position)
	for i in range(game.player.get_slide_collision_count()):
		var collision: KinematicCollision3D = game.player.get_slide_collision(i)
		print("Colisao rampa: ",collision.get_normal()," em ",collision.get_position()," objeto ",collision.get_collider().get_parent().name)
	check(game.player.position.z < -12,"Rampa alcanca o patamar superior")
	check(game.player.position.y > 2,"Subida tem altura real")
	check(maximum_error < 0.4,"Personagem acompanha a superficie da rampa")
	var camera_before: Vector3 = game.camera.position
	game.player.position = Vector3(4,0.1,1)
	await process_frame
	check(game.camera.position.distance_to(camera_before) < 10,"Camera amortece mudanca de posicao")
	# Cruza o canal com a mesma entrada e fisica usadas pelo jogador.
	game.set_physics_process(true)
	game.demo_mode = true
	game.demo_input = Vector2(-1,1).normalized()
	game.player.position = Vector3(0,0.35,4.5)
	game.player.velocity = Vector3.ZERO
	var bridge_minimum := 100.0
	for i in range(190):
		await physics_frame
		if game.player.position.z > 6 and game.player.position.z < 9:
			bridge_minimum = minf(bridge_minimum,game.player.position.y)
	print("Travessia: ",game.player.position," altura minima ",bridge_minimum)
	check(game.player.position.z>12,"Ponte permite atravessar o canal")
	check(bridge_minimum > -0.5 and bridge_minimum<0.5,"Pes apoiados no tabuleiro da ponte")
	game.demo_input = Vector2(1,-1).normalized()
	for i in range(190):
		await physics_frame
	check(game.player.position.z<5,"Ponte permite retorno pela margem baixa")
	game.demo_input = Vector2.ZERO
	game.player.position = Vector3(-4,0,2)
	game.sprite.play_action("tend")
	check(game.sprite.animation.begins_with("tend_") and game.sprite.action_timer>0,"Cultivo aciona gesto original")
	game.atmosphere.toggle()
	game.atmosphere.advance(36)
	check(not game.atmosphere.shafts[0].visible,"Raios solares acompanham troca de luz")
	print("Cena visual: ",checks-failures,"/",checks," verificacoes. Erro maximo de altura: ",maximum_error)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
