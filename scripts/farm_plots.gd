extends Node3D
const VisualWorld = preload("res://scripts/visual_world.gd")
var plots: Array[Dictionary] = []
var selection: Node3D
var selected := -1
var art
func setup(world) -> void:
	art = world
	for row in range(3):
		for col in range(3):
			var pos := Vector3(-8.2+col*1.7,0.03,-0.25+row*1.75)
			var soil: MeshInstance3D = art.box(pos,Vector3(1.05,0.055,1.05),"soil")
			var dry: StandardMaterial3D = art.materials.soil.duplicate()
			dry.albedo_color = Color("66513a")
			soil.material_override = dry
			var plant := Node3D.new()
			plant.position = pos+Vector3(0,0.04,0)
			add_child(plant)
			for dx in [-0.22,0.22]:
				for dz in [-0.22,0.22]:
					var leaf := MeshInstance3D.new()
					var shape := SphereMesh.new()
					shape.radius = 0.17
					shape.height = 0.24
					shape.radial_segments = 7
					shape.rings = 4
					leaf.mesh = shape
					leaf.material_override = art.materials.crop
					leaf.position = Vector3(dx,0.12,dz)
					plant.add_child(leaf)
			plots.append({"position":pos,"stage":0,"watered":false,"soil":soil,"plant":plant})
	selection = Node3D.new()
	add_child(selection)
	for x in [-0.57,0.57]:
		art.box(Vector3(x,0.07,0),Vector3(0.025,0.025,1.14),"gold",false,selection)
	for z in [-0.57,0.57]:
		art.box(Vector3(0,0.07,z),Vector3(1.14,0.025,0.025),"gold",false,selection)
	refresh()
func nearest(pos: Vector3, reach: float = 1.35) -> int:
	var best := -1
	for i in range(plots.size()):
		var distance := Vector2(pos.x,pos.z).distance_to(Vector2(plots[i].position.x,plots[i].position.z))
		if distance<reach:
			reach=distance
			best=i
	return best
func highlight(pos: Vector3) -> void:
	selected=nearest(pos)
	selection.visible=selected>=0
	if selected>=0:
		selection.position=plots[selected].position
func interact(pos: Vector3, water: bool = false) -> Dictionary:
	var index := nearest(pos)
	if index<0:
		return {"message":"Aproxime-se de um quadrado de terra. E planta/colhe; R rega.","harvest":0,"acted":false}
	var plot: Dictionary=plots[index]
	var harvest:=0
	var acted:=true
	var text: String
	if water:
		if plot.stage==1 and not plot.watered:
			plot.watered=true
			text="Terra regada. A muda cresce no proximo amanhecer."
			_splash(plot.position)
		else:
			acted=false
			text="Este canteiro ja esta regado." if plot.watered else "Plante uma semente com E antes de regar."
	elif plot.stage==0:
		plot.stage=1
		text="Semente plantada. R rega este quadrado; N avanca o dia."
	elif plot.stage==2:
		plot.stage=0
		plot.watered=false
		harvest=1
		text="Colheita recebida. O quadrado esta livre para plantar."
	else:
		acted=false
		text="A muda precisa de agua (R)." if not plot.watered else "A muda esta regada; aguarde o amanhecer (N)."
	refresh()
	return {"message":text,"harvest":harvest,"acted":acted}
func next_day() -> void:
	for plot in plots:
		if plot.stage==1 and plot.watered:
			plot.stage=2
		plot.watered=false
	refresh()
func refresh() -> void:
	for plot in plots:
		plot.plant.visible=plot.stage>0
		plot.plant.scale=Vector3.ONE*(1.35 if plot.stage==2 else 0.55)
		var mat: StandardMaterial3D=plot.soil.material_override
		mat.albedo_color=Color("302b22") if plot.watered else Color("66513a")
		mat.roughness=0.8 if plot.watered else 0.95
		mat.metallic_specular=0.12
func serialize() -> Array:
	var result: Array=[]
	for plot in plots:
		result.append({"stage":plot.stage,"watered":plot.watered})
	return result
func restore(data: Array) -> void:
	for i in range(mini(data.size(),plots.size())):
		if data[i] is Dictionary:
			plots[i].stage=clampi(int(data[i].get("stage",0)),0,2)
			plots[i].watered=bool(data[i].get("watered",false))
	refresh()
func _splash(pos: Vector3) -> void:
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("8dbed1")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(10):
		var drop:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=0.025
		sphere.height=0.08
		drop.mesh=sphere
		drop.material_override=material
		drop.position=pos+Vector3(randf_range(-0.4,0.4),0.65+randf()*0.35,randf_range(-0.4,0.4))
		add_child(drop)
		var tween:=create_tween()
		tween.tween_property(drop,"position:y",0.1,0.35)
		tween.tween_callback(drop.queue_free)


