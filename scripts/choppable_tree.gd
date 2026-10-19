extends Node3D
var health:=3
var felled:=false
var logs:=0
var cooldown:=0.0
var fall_pivot: Node3D
var trunk_body: StaticBody3D
var stump: MeshInstance3D
var log_root: Node3D
var art
var canopy_material: ShaderMaterial
var canopy_visibility:=1.0
func setup(world, location: Vector3, already_felled: bool = false, remaining_logs: int = 0) -> void:
	art=world
	position=location
	fall_pivot=Node3D.new()
	add_child(fall_pivot)
	var tree: Node3D=_make_tree()
	fall_pivot.add_child(tree)
	trunk_body=StaticBody3D.new()
	add_child(trunk_body)
	var collision:=CollisionShape3D.new()
	var shape:=CylinderShape3D.new()
	shape.radius=0.32
	shape.height=1.5
	collision.shape=shape
	collision.position.y=0.75
	trunk_body.add_child(collision)
	stump=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=0.3
	cylinder.bottom_radius=0.4
	cylinder.height=0.4
	stump.mesh=cylinder
	stump.material_override=art.materials.brown_planks_03
	stump.position.y=0.2
	add_child(stump)
	stump.visible=false
	log_root=Node3D.new()
	add_child(log_root)
	if already_felled:
		felled=true
		health=0
		fall_pivot.visible=false
		trunk_body.process_mode=Node.PROCESS_MODE_DISABLED
		stump.visible=true
		logs=remaining_logs
		_spawn_logs()
func _process(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta)
	var game=get_parent().get_parent()
	if game.get("player")!=null and canopy_material!=null:
		var distance: float=game.player.position.distance_to(global_position)
		var desired:=lerpf(0.4,1.0,smoothstep(1.0,2.5,distance))
		canopy_visibility=lerpf(canopy_visibility,desired,1-exp(-5*delta))
		canopy_material.set_shader_parameter("canopy_visibility",canopy_visibility)
func hit(from: Vector3) -> String:
	if from.distance_to(global_position)>2.0:
		return "Aproxime-se do tronco da arvore junto da horta. F usa o machado."
	if felled:
		return "Tronco cortado. E recolhe a madeira no chao."
	if cooldown>0:
		return ""
	cooldown=0.5
	health-=1
	_chips()
	if health>0:
		var tween:=create_tween()
		tween.tween_property(fall_pivot,"rotation:z",0.07,0.08)
		tween.tween_property(fall_pivot,"rotation:z",0.0,0.15)
		return "Golpe no tronco: %d de 3. A copa balanca."%(3-health)
	felled=true
	logs=3
	trunk_body.process_mode=Node.PROCESS_MODE_DISABLED
	stump.visible=true
	var fall:=create_tween()
	fall.tween_property(fall_pivot,"rotation:z",PI/2,1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_interval(0.3)
	fall.tween_callback(func(): fall_pivot.visible=false; _spawn_logs())
	return "Arvore derrubada. E recolhe 3 madeiras junto do toco."
func collect(from: Vector3) -> int:
	if not felled or logs==0 or from.distance_to(global_position)>2.0:
		return 0
	var count:=logs
	logs=0
	for child in log_root.get_children():
		child.queue_free()
	return count
func _spawn_logs() -> void:
	for i in range(logs):
		var log:=MeshInstance3D.new()
		var cylinder:=CylinderMesh.new()
		cylinder.top_radius=0.14
		cylinder.bottom_radius=0.17
		cylinder.height=0.7
		cylinder.radial_segments=9
		log.mesh=cylinder
		log.material_override=art.materials.brown_planks_03
		log.rotation=Vector3(PI/2,0,i*0.5)
		log.position=Vector3(-0.6+i*0.45,0.16,0.65)
		log_root.add_child(log)

func _chips() -> void:
	for i in range(7):
		var chip:=MeshInstance3D.new()
		var cube:=BoxMesh.new()
		cube.size=Vector3(0.055,0.035,0.025)
		chip.mesh=cube
		chip.material_override=art.materials.brown_planks_03
		chip.position=Vector3(0,0.7,0)
		add_child(chip)
		var tween:=create_tween()
		tween.tween_property(chip,"position",Vector3(randf_range(-0.8,0.8),randf_range(0.8,1.2),randf_range(-0.8,0.8)),0.2)
		tween.tween_property(chip,"position:y",0.05,0.25)
		tween.tween_callback(chip.queue_free)

func _make_tree() -> Node3D:
	var tree:=Node3D.new()
	var random:=RandomNumberGenerator.new()
	random.seed=91842
	var trunk_points: Array[Vector3]=[Vector3.ZERO,Vector3(0.12,1,0),Vector3(-0.08,2.2,0.1),Vector3(0.15,3.4,0)]
	for i in range(trunk_points.size()-1):
		_branch(tree,trunk_points[i],trunk_points[i+1],0.28-i*0.06)
	var leaf_surface:=SurfaceTool.new()
	leaf_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_points: Array[Vector3]=[Vector3(0,0,0),Vector3(-0.15,0.03,0.2),Vector3(0,0.10,0.48),Vector3(0.15,0.03,0.2),Vector3(0,0.09,0.20)]
	for index in [0,1,4,1,2,4,2,3,4,3,0,4]:
		leaf_surface.add_vertex(leaf_points[index])
	leaf_surface.generate_normals()
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=leaf_surface.commit()
	multi.instance_count=850
	for cluster in range(8):
		var angle:=cluster*2.4
		var center:=Vector3(cos(angle)*1.3,3.15+(cluster%3)*0.45,sin(angle)*1.25)
		if cluster==7:
			center=Vector3(0,4.4,0)
		_branch(tree,Vector3(0.05,1.7+cluster*0.13,0),center,0.11)
		for j in range(106 if cluster<7 else 108):
			var index:=cluster*106+j
			var point:=Vector3(random.randf_range(-1,1),random.randf_range(-0.65,0.65),random.randf_range(-1,1))
			if point.length()>1:
				point=point.normalized()*random.randf_range(0.6,1.0)
			var basis:=Basis.from_euler(Vector3(random.randf_range(-0.8,0.8),random.randf()*TAU,random.randf_range(-0.4,0.4)))
			basis=basis.scaled(Vector3.ONE*random.randf_range(0.8,1.45))
			multi.set_instance_transform(index,Transform3D(basis,center+point))
			var color:=Color("426325").lerp(Color("7e8e30"),random.randf()*0.6)
			if index%9==0:
				color=Color("928638")
			multi.set_instance_color(index,color)
	var leaves:=MultiMeshInstance3D.new()
	leaves.name="FolhasLargasAoSol"
	leaves.multimesh=multi
	canopy_material=ShaderMaterial.new()
	canopy_material.shader=load("res://shaders/resource_leaves.gdshader")
	leaves.material_override=canopy_material
	tree.add_child(leaves)
	return tree

func _branch(tree: Node3D,start: Vector3,end: Vector3,radius: float) -> void:
	var branch:=MeshInstance3D.new()
	var cylinder:=CylinderMesh.new()
	cylinder.bottom_radius=radius
	cylinder.top_radius=radius*0.6
	cylinder.height=start.distance_to(end)
	cylinder.radial_segments=9
	branch.mesh=cylinder
	branch.material_override=art.materials.brown_planks_03
	branch.position=(start+end)/2
	branch.quaternion=Quaternion(Vector3.UP,(end-start).normalized())
	tree.add_child(branch)
