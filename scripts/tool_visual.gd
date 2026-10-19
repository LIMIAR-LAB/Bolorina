extends Node3D
var axe: Node3D
var watering_can: Node3D
var animation: Tween
func setup() -> void:
	axe=Node3D.new()
	add_child(axe)
	var wood:=StandardMaterial3D.new()
	wood.albedo_color=Color("694225")
	var iron:=StandardMaterial3D.new()
	iron.albedo_color=Color("9ea7a8")
	iron.metallic=0.6
	iron.roughness=0.4
	_box(axe,Vector3(0,0.3,0),Vector3(0.06,0.7,0.06),wood)
	_box(axe,Vector3(0.12,0.6,0),Vector3(0.3,0.22,0.07),iron)
	watering_can=Node3D.new()
	add_child(watering_can)
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=0.12
	cylinder.bottom_radius=0.15
	cylinder.height=0.24
	var body:=MeshInstance3D.new()
	body.mesh=cylinder
	body.material_override=iron
	watering_can.add_child(body)
	_box(watering_can,Vector3(0,0.03,-0.2),Vector3(0.055,0.055,0.35),iron)
	_box(watering_can,Vector3(0,0.05,-0.38),Vector3(0.15,0.05,0.08),iron)
	axe.visible=false
	watering_can.visible=false
func _box(parent: Node3D,pos: Vector3,size: Vector3,material: Material) -> void:
	var node:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	node.mesh=mesh
	node.material_override=material
	node.position=pos
	parent.add_child(node)
func use_tool(kind: String,direction: Vector3) -> void:
	if animation and animation.is_running():
		animation.kill()
	axe.visible=kind=="axe"
	watering_can.visible=kind=="water"
	rotation.y=atan2(-direction.x,-direction.z)
	position=Vector3(0,0.6,0)
	var tool: Node3D=axe if kind=="axe" else watering_can
	tool.rotation=Vector3.ZERO
	tool.position=Vector3(0.3,0,-0.25)
	animation=create_tween()
	if kind=="axe":
		tool.rotation.x=-1.2
		animation.tween_property(tool,"rotation:x",1.1,0.18).set_trans(Tween.TRANS_QUAD)
		animation.tween_property(tool,"rotation:x",0.0,0.2)
	else:
		animation.tween_property(tool,"rotation:x",-0.6,0.16)
		animation.tween_interval(0.4)
	animation.tween_callback(func(): tool.visible=false)
