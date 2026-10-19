extends SceneTree
## Sonda: converte pixels da referencia (1600x900) em pontos do chao da cena de fidelidade.
func _initialize() -> void:
	call_deferred("run")

func ground_at(cam: Camera3D, px: Vector2) -> Vector3:
	var o := cam.project_ray_origin(px)
	var d := cam.project_ray_normal(px)
	var t := 0.0
	for i in 4000:
		var q := o + d*t
		if q.y <= VisualWorld.height_at(q.x,q.z):
			return q
		t += 0.05
	return Vector3.INF

const VisualWorld = preload("res://scripts/visual_world.gd")

func run() -> void:
	var game = load("res://fidelity_village.tscn").instantiate()
	game.camera_travada = true
	root.add_child(game)
	for i in 30:
		await process_frame
	var cam: Camera3D = game.fidelity_camera
	var pts := {}
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://work/probe_in.json"))
	for k in data:
		var g := ground_at(cam, Vector2(data[k][0],data[k][1]))
		pts[k] = [snappedf(g.x,0.1),snappedf(g.y,0.1),snappedf(g.z,0.1)]
		print("PT ",k," ",pts[k])
	for n in game.ground.get_children():
		if n.name.begins_with("CasaModular") or n.name.begins_with("Ponte") or n.name=="TabuleiroContinuoDaPonte":
			print("NODE ",n.name," ",n.position," scr ",cam.unproject_position(n.global_position))
	print("PLAYER ",game.player.position," scr ",cam.unproject_position(game.player.global_position))
	for c in [Vector2(0,0),Vector2(1600,0),Vector2(0,900),Vector2(1600,900),Vector2(800,450)]:
		print("CORNER ",c," ",ground_at(cam,c))
	FileAccess.open("res://work/probe_out.json",FileAccess.WRITE).store_string(JSON.stringify(pts))
	quit()