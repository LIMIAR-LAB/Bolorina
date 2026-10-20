extends Node3D
## Bate-Estaca de teste (PROPOSTA). Um pilão que repete os mesmos 3 segundos e 3 travas em volta.
## Cada trava só abre com acerto de ECO (golpe normal faz "CLANG"). Com as 3 abertas o pilão para,
## a grade sobe e aparece a Catraca-Mestra nº 3. Na missão isso é a etapa "bate_estaca":
##   gerenciador.notificar("trava_acertada_eco", "bate_estaca") por trava e coletar_item("catraca_mestra").
signal trava_aberta(indice: int, abertas: int)
signal aberto
signal catraca_coletada
signal pancada(centro: Vector3, raio: float)

const Alvo = preload("res://scripts/prototipos/eco/alvo_treino.gd")
const CICLO := 3.0
const T_AVISO := 1.8
const T_BATIDA := 2.4
const RAIO_PANCADA := 1.3
const RAIO_TRAVAS := 2.3

var travas: Array = []
var abertas := 0
var esta_aberto := false
var catraca_pega := false
var relogio := 0.0
var _pilao: Node3D
var _aviso: MeshInstance3D
var _aviso_mat: StandardMaterial3D
var _grade: Node3D
var _catraca: Node3D
var _bateu_neste_ciclo := false

func _ready() -> void:
	var ferro := StandardMaterial3D.new(); ferro.albedo_color = Color("5d5a5a"); ferro.metallic = 0.5; ferro.roughness = 0.5
	var madeira := StandardMaterial3D.new(); madeira.albedo_color = Color("5a3d22")
	var col := BoxMesh.new(); col.size = Vector3(0.35, 3.6, 0.35)
	for x in [-1.1, 1.1]:
		var c := MeshInstance3D.new(); c.mesh = col; c.material_override = madeira; c.position = Vector3(x, 1.8, 0); add_child(c)
	var viga := BoxMesh.new(); viga.size = Vector3(2.8, 0.35, 0.5)
	var v := MeshInstance3D.new(); v.mesh = viga; v.material_override = madeira; v.position = Vector3(0, 3.7, 0); add_child(v)
	var base := CylinderMesh.new(); base.top_radius = 0.9; base.bottom_radius = 1.0; base.height = 0.18
	var b := MeshInstance3D.new(); b.mesh = base; b.material_override = ferro; b.position = Vector3(0, 0.09, 0); add_child(b)
	_pilao = Node3D.new(); _pilao.position = Vector3(0, 3.0, 0); add_child(_pilao)
	var cab := BoxMesh.new(); cab.size = Vector3(1.2, 0.8, 1.2)
	var pm := MeshInstance3D.new(); pm.mesh = cab; pm.material_override = ferro; pm.position = Vector3(0, 0.4, 0); _pilao.add_child(pm)
	var haste := CylinderMesh.new(); haste.top_radius = 0.1; haste.bottom_radius = 0.1; haste.height = 1.2
	var hm := MeshInstance3D.new(); hm.mesh = haste; hm.material_override = ferro; hm.position = Vector3(0, 1.2, 0); _pilao.add_child(hm)
	_aviso = MeshInstance3D.new()
	var pl := PlaneMesh.new(); pl.size = Vector2(RAIO_PANCADA * 2, RAIO_PANCADA * 2)
	_aviso.mesh = pl
	_aviso_mat = StandardMaterial3D.new()
	_aviso_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aviso_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aviso_mat.albedo_texture = _textura_anel()
	_aviso_mat.albedo_color = Color(1.0, 0.25, 0.15, 0.0)
	_aviso.material_override = _aviso_mat
	_aviso.position = Vector3(0, 0.2, 0)
	add_child(_aviso)
	# grade atrás e a catraca escondida
	_grade = Node3D.new(); _grade.position = Vector3(0, 0, -1.6); add_child(_grade)
	var barra := BoxMesh.new(); barra.size = Vector3(0.1, 2.2, 0.1)
	for i in 7:
		var gb := MeshInstance3D.new(); gb.mesh = barra; gb.material_override = ferro; gb.position = Vector3(-0.9 + i * 0.3, 1.1, 0); _grade.add_child(gb)
	_catraca = Node3D.new(); _catraca.position = Vector3(0, 0.9, -2.3); _catraca.visible = false; add_child(_catraca)
	var ouro := StandardMaterial3D.new(); ouro.albedo_color = Color("d9a53a"); ouro.metallic = 0.9; ouro.roughness = 0.3
	ouro.emission_enabled = true; ouro.emission = Color("6a4a10")
	var anel := TorusMesh.new(); anel.inner_radius = 0.22; anel.outer_radius = 0.38
	var am := MeshInstance3D.new(); am.mesh = anel; am.material_override = ouro; am.rotation_degrees.x = 90; _catraca.add_child(am)
	for k in 8:
		var dente := BoxMesh.new(); dente.size = Vector3(0.12, 0.12, 0.1)
		var dm := MeshInstance3D.new(); dm.mesh = dente; dm.material_override = ouro
		var a := TAU * k / 8.0
		dm.position = Vector3(cos(a) * 0.43, sin(a) * 0.43, 0); _catraca.add_child(dm)
	var luz := OmniLight3D.new(); luz.light_color = Color("ffcf6a"); luz.light_energy = 2.0; luz.omni_range = 2.5; _catraca.add_child(luz)
	# travas
	for i in 3:
		var t: Node3D = Alvo.new().configurar("trava", "trava_%d" % (i + 1))
		var ang := deg_to_rad(-30.0 + i * 120.0) + PI * 0.5
		t.position = Vector3(cos(ang), 0, sin(ang)) * RAIO_TRAVAS
		t.name = "Trava%d" % (i + 1)
		add_child(t)
		t.aberta.connect(_ao_abrir.bind(i))
		travas.append(t)

static func _textura_anel() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			var a := 0.0
			if d <= 1.0:
				a = 0.25 + 0.75 * smoothstep(0.78, 0.92, d) * (1.0 - smoothstep(0.96, 1.0, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func fase() -> float:
	return fmod(relogio, CICLO)

func _process(delta: float) -> void:
	relogio += delta
	if _catraca.visible:
		_catraca.rotation.y += delta * 2.0
	if esta_aberto:
		_pilao.position.y = lerpf(_pilao.position.y, 3.0, minf(1.0, delta * 4.0))
		_aviso_mat.albedo_color.a = 0.0
		return
	var f := fase()
	if f < 0.05:
		_bateu_neste_ciclo = false
	if f < T_AVISO:
		_pilao.position.y = lerpf(0.25, 3.0, clampf(f / 0.9, 0.0, 1.0))
		_aviso_mat.albedo_color.a = 0.0
	elif f < T_BATIDA:
		var k := (f - T_AVISO) / (T_BATIDA - T_AVISO)
		_pilao.position.y = 3.0 + 0.25 * k + sin(relogio * 60.0) * 0.03
		_aviso_mat.albedo_color = Color(1.0, 0.25, 0.15, 0.25 + 0.55 * k)
	else:
		_pilao.position.y = 0.25
		_aviso_mat.albedo_color.a = maxf(0.0, _aviso_mat.albedo_color.a - delta * 3.0)
		if not _bateu_neste_ciclo:
			_bateu_neste_ciclo = true
			pancada.emit(global_position, RAIO_PANCADA)

func _ao_abrir(_t, indice: int) -> void:
	abertas += 1
	trava_aberta.emit(indice, abertas)
	if abertas >= travas.size() and not esta_aberto:
		esta_aberto = true
		var tw := create_tween()
		tw.tween_property(_grade, "position:y", 2.4, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_catraca.visible = true
		aberto.emit()

## A arena chama com a posição da Vale; pega a catraca quando ela chega perto.
func tentar_coletar(pos: Vector3) -> bool:
	if not esta_aberto or catraca_pega:
		return false
	var c := _catraca.global_position
	if Vector2(pos.x - c.x, pos.z - c.z).length() <= 1.1:
		catraca_pega = true
		_catraca.visible = false
		catraca_coletada.emit()
		return true
	return false

func posicao_catraca() -> Vector3:
	return _catraca.global_position
