extends StaticBody3D
## Prop quebravel (caixote / urna) ou cobertura indestrutivel (rocha), sprites Gamelab 2.5D.
const Folhas = preload("res://scripts/combate/folhas.gd")
signal quebrou(prop)
var tipo := "caixote"
var inteiro := true
var sprite: Sprite3D
var px := 1.72 / 48.0 * 42.0 / 45.0
var forma: CollisionShape3D

func setup(t: String) -> void:
	tipo = t
	name = "Prop_" + t
	collision_layer = 4
	collision_mask = 0
	forma = CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = {"caixote": 0.45, "urna": 0.33, "rocha": 0.75}[t]
	cil.height = 1.2
	forma.shape = cil
	forma.position.y = 0.6
	add_child(forma)
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.pixel_size = px
	add_child(sprite)
	_textura("inteiro")
	var sombra := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(1.2, 0.8) * (1.5 if t == "rocha" else 1.0)
	sombra.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/contact_shadow.gdshader")
	sombra.material_override = sm
	sombra.position.y = 0.03
	add_child(sombra)

func _textura(st: String) -> void:
	var tex := Folhas.textura("res://art/combate/props/prop_%s_%s.png" % [tipo, st])
	sprite.texture = tex
	sprite.offset = Vector2(0, tex.get_height() * 0.5 - 2.0)

func quebravel() -> bool:
	return inteiro and tipo != "rocha"

func receber_golpe(_valor: int, _emp: Vector3, _pesado: bool) -> bool:
	if not quebravel():
		return false
	inteiro = false
	_textura("quebrado")
	forma.disabled = true
	quebrou.emit(self)
	return true
