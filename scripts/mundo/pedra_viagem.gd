extends Node3D
## Pedra de viagem: ponto de chegada / volta ao mapa-mundi em cada area (montada por jogo_ilha.gd).
## Perto dela (RAIO) aparece "T: viajar"; T abre o mapa-mundi no modo viagem (clique ou Enter numa area).
const RAIO := 2.2
var gerenciador
var alvo: Node3D            # jogador (player/jogador da area)
var perto := false
var dica: Label3D
var cristal: MeshInstance3D
var t := 0.0

func montar(g, jogador: Node3D) -> void:
	gerenciador = g
	alvo = jogador
	var base := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.42
	cil.bottom_radius = 0.55
	cil.height = 0.5
	base.mesh = cil
	base.position.y = 0.25
	var mb := StandardMaterial3D.new()
	mb.albedo_color = Color("6f6a73")
	mb.roughness = 0.9
	base.material_override = mb
	add_child(base)
	cristal = MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(0.38, 0.9, 0.38)
	cristal.mesh = pr
	cristal.position.y = 1.0
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color("5fe6ff")
	mc.emission_enabled = true
	mc.emission = Color("39c8ff")
	mc.emission_energy_multiplier = 1.6
	cristal.material_override = mc
	add_child(cristal)
	var anel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	anel.mesh = tor
	anel.position.y = 0.04
	var ma := StandardMaterial3D.new()
	ma.albedo_color = Color(0.4, 0.9, 1.0, 0.55)
	ma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anel.material_override = ma
	add_child(anel)
	dica = Label3D.new()
	dica.text = "T: viajar (mapa-múndi)"
	dica.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dica.font_size = 40
	dica.pixel_size = 0.008
	dica.outline_size = 10
	dica.position.y = 1.9
	dica.no_depth_test = true
	dica.visible = false
	add_child(dica)

func _process(delta: float) -> void:
	t += delta
	if cristal:
		cristal.rotation.y = t * 1.2
		cristal.position.y = 1.0 + sin(t * 2.0) * 0.06
	if alvo == null or not is_instance_valid(alvo):
		perto = false
	else:
		var d := Vector2(alvo.global_position.x - global_position.x, alvo.global_position.z - global_position.z)
		perto = d.length() < RAIO
	if dica:
		dica.visible = perto

func _unhandled_key_input(event: InputEvent) -> void:
	if not perto or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_T and gerenciador and not gerenciador.ocupado:
		get_viewport().set_input_as_handled()
		gerenciador.abrir_viagem()
