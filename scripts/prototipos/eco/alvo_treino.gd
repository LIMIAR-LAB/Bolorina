extends Node3D
## Alvos do protótipo do eco (PROPOSTA). Um script para quatro tipos, feitos com malhas simples:
##   "boneco"     boneco de palha: cai com 160 de vida e levanta 2,5 s depois
##   "escudeiro"  Escudeiro de Palha: guarda bloqueia tudo (20% do dano) até levar um golpe que
##                quebra a guarda (Eco pesado). Guarda quebrada por 3 s = dano cheio.
##   "poste"      poste de treino: não cai, conta golpes e ecos
##   "trava"      trava do Bate-Estaca: só abre com acerto de eco ("CLANG" no golpe normal)
signal golpeado(alvo: Node3D, info: Dictionary)
signal derrubado(alvo: Node3D)
signal aberta(alvo: Node3D)

@export var tipo := "boneco"
@export var id_alvo := "boneco"
var hp_max := 120
var hp := 120
var raio_alvo := 0.5
var guarda_ativa := false
var guarda_volta_em := 0.0
var esta_aberta := false
var caido := false
var levanta_em := 0.0
var golpes := 0
var ecos := 0
var relogio := 0.0
var _materiais: Array = []
var _corpo: Node3D
var _escudo: Node3D
var _argola: Node3D
var _rotulo: Label3D

func configurar(t: String, ident: String) -> Node3D:
	tipo = t
	id_alvo = ident
	return self

func _ready() -> void:
	guarda_ativa = tipo == "escudeiro"
	raio_alvo = 0.35 if tipo == "trava" else 0.5
	hp_max = 160
	hp = hp_max
	_montar()

func _mat(cor: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = 0.85 - metal * 0.5
	m.emission_enabled = true
	m.emission = Color.BLACK
	_materiais.append(m)
	return m

func _malha(mesh: Mesh, mat: Material, pos: Vector3, pai: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	pai.add_child(mi)
	return mi

func _montar() -> void:
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	var madeira := _mat(Color("6b4a2e"))
	var palha := _mat(Color("d9b25e"))
	var ferro := _mat(Color("6d6f78"), 0.6)
	match tipo:
		"boneco", "escudeiro":
			var poste := CylinderMesh.new(); poste.top_radius = 0.07; poste.bottom_radius = 0.09; poste.height = 1.0
			_malha(poste, madeira, Vector3(0, 0.5, 0), _corpo)
			var corpo := CapsuleMesh.new(); corpo.radius = 0.3; corpo.height = 1.0
			_malha(corpo, palha, Vector3(0, 1.15, 0), _corpo)
			var cab := SphereMesh.new(); cab.radius = 0.22; cab.height = 0.44
			_malha(cab, palha, Vector3(0, 1.85, 0), _corpo)
			var braco := BoxMesh.new(); braco.size = Vector3(1.2, 0.12, 0.12)
			_malha(braco, madeira, Vector3(0, 1.35, 0), _corpo)
			if tipo == "escudeiro":
				var elmo := CylinderMesh.new(); elmo.top_radius = 0.18; elmo.bottom_radius = 0.25; elmo.height = 0.22
				_malha(elmo, ferro, Vector3(0, 2.0, 0), _corpo)
				_escudo = Node3D.new()
				_escudo.position = Vector3(0.0, 1.2, 0.0)
				_corpo.add_child(_escudo)
				var esc := BoxMesh.new(); esc.size = Vector3(0.95, 1.05, 0.12)
				var azul := _mat(Color("3e5f8a"), 0.3)
				for ang in [0.0, 90.0]:
					var e := Node3D.new()
					e.rotation_degrees.y = ang + 45.0
					_escudo.add_child(e)
					_malha(esc, azul, Vector3(0, 0, 0.42), e)
					var aro := BoxMesh.new(); aro.size = Vector3(1.05, 0.1, 0.16)
					_malha(aro, ferro, Vector3(0, 0.5, 0.42), e)
		"poste":
			var poste := CylinderMesh.new(); poste.top_radius = 0.16; poste.bottom_radius = 0.2; poste.height = 2.2
			_malha(poste, madeira, Vector3(0, 1.1, 0), _corpo)
			var disco := CylinderMesh.new(); disco.top_radius = 0.55; disco.bottom_radius = 0.55; disco.height = 0.08
			var verm := _mat(Color("b8412f"))
			var bran := _mat(Color("efe2c4"))
			for i in 3:
				var r := 0.55 - i * 0.17
				var dm := CylinderMesh.new(); dm.top_radius = r; dm.bottom_radius = r; dm.height = 0.09 + i * 0.01
				for ang in [45.0, 135.0]:
					var piv := Node3D.new(); piv.rotation_degrees.y = ang; _corpo.add_child(piv)
					_malha(dm, verm if i % 2 == 0 else bran, Vector3(0, 1.55, 0.22), piv, Vector3(90, 0, 0))
			var base := BoxMesh.new(); base.size = Vector3(0.9, 0.2, 0.9)
			_malha(base, madeira, Vector3(0, 0.1, 0), _corpo)
		"trava":
			var cx := BoxMesh.new(); cx.size = Vector3(0.6, 0.55, 0.3)
			_malha(cx, ferro, Vector3(0, 0.55, 0), _corpo)
			var buraco := BoxMesh.new(); buraco.size = Vector3(0.12, 0.2, 0.32)
			_malha(buraco, _mat(Color("1a1410")), Vector3(0, 0.5, 0), _corpo)
			_argola = Node3D.new()
			_argola.position = Vector3(0, 0.85, 0)
			_corpo.add_child(_argola)
			var arg := TorusMesh.new(); arg.inner_radius = 0.16; arg.outer_radius = 0.24
			_malha(arg, _mat(Color("b38a3a"), 0.7), Vector3(0, 0.05, 0), _argola, Vector3(90, 45, 0))
			var pe := CylinderMesh.new(); pe.top_radius = 0.06; pe.bottom_radius = 0.06; pe.height = 0.3
			_malha(pe, ferro, Vector3(0, 0.15, 0), _corpo)
	_rotulo = Label3D.new()
	_rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_rotulo.no_depth_test = true
	_rotulo.fixed_size = true
	_rotulo.pixel_size = 0.0013
	_rotulo.font_size = 26
	_rotulo.outline_size = 8
	_rotulo.outline_modulate = Color(0.08, 0.04, 0.03)
	_rotulo.position = Vector3(0, 2.55 if tipo != "trava" else 1.45, 0)
	var f = load("res://art/ui/dialogos/fontes/PixelifySans.ttf")
	if f != null:
		_rotulo.font = f
	add_child(_rotulo)
	_atualizar_rotulo()

func _atualizar_rotulo() -> void:
	if _rotulo == null:
		return
	match tipo:
		"poste": _rotulo.text = "Poste de treino\ngolpes %d · ecos %d" % [golpes, ecos]
		"trava":
			_rotulo.text = "ABERTA" if esta_aberta else "trava"
			_rotulo.modulate = Color("7fe07a") if esta_aberta else Color("f1e2bd")
		"escudeiro": _rotulo.text = ("Escudeiro  %d" % hp) + ("" if guarda_ativa else "\nGUARDA QUEBRADA")
		_: _rotulo.text = "Boneco  %d" % hp

func alvejavel() -> bool:
	if tipo == "trava":
		return not esta_aberta
	return not caido

func receber_golpe(dano: int, empurrao: Vector3, pesado: bool, eco := false, quebra := false) -> Dictionary:
	var r := {"acertou": false, "dano": 0, "bloqueado": false, "quebrou_guarda": false, "derrubado": false, "abriu": false, "texto": "", "eco": eco}
	if not alvejavel():
		return r
	r.acertou = true
	golpes += 1
	if eco:
		ecos += 1
	match tipo:
		"trava":
			if eco:
				esta_aberta = true
				r.abriu = true
				r.texto = "DESTRAVOU!"
				_abrir_fx()
				aberta.emit(self)
			else:
				r.bloqueado = true
				r.texto = "CLANG! só o eco"
		"poste":
			r.dano = dano
		"escudeiro":
			if guarda_ativa and not quebra:
				r.bloqueado = true
				r.dano = maxi(1, roundi(dano * 0.2))
				r.texto = "BLOQ"
			else:
				if guarda_ativa:
					guarda_ativa = false
					guarda_volta_em = relogio + 3.0
					r.quebrou_guarda = true
					r.texto = "GUARDA QUEBRADA"
					if _escudo != null:
						var tw := create_tween()
						tw.tween_property(_escudo, "position:y", 0.35, 0.18)
						tw.parallel().tween_property(_escudo, "rotation_degrees:x", 70.0, 0.18)
				r.dano = dano
		_:
			r.dano = dano
	if tipo == "boneco" or tipo == "escudeiro":
		hp = maxi(0, hp - int(r.dano))
		if hp <= 0:
			caido = true
			levanta_em = relogio + 2.5
			r.derrubado = true
			var tw := create_tween()
			tw.tween_property(_corpo, "rotation_degrees:x", -82.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			derrubado.emit(self)
	_flash(Color(0.4, 1.0, 1.6) if eco else Color(1.6, 1.5, 1.3), r.bloqueado)
	if not r.derrubado and tipo != "trava":
		var lado := 1.0 if empurrao.x + empurrao.z >= 0.0 else -1.0
		var tw2 := create_tween()
		tw2.tween_property(_corpo, "rotation_degrees:z", 14.0 * lado * (0.4 if r.bloqueado else 1.0), 0.05)
		tw2.tween_property(_corpo, "rotation_degrees:z", -6.0 * lado, 0.09)
		tw2.tween_property(_corpo, "rotation_degrees:z", 0.0, 0.12)
	elif tipo == "trava" and r.bloqueado:
		var tw3 := create_tween()
		tw3.tween_property(_corpo, "position:x", 0.06, 0.03)
		tw3.tween_property(_corpo, "position:x", -0.06, 0.05)
		tw3.tween_property(_corpo, "position:x", 0.0, 0.04)
	_atualizar_rotulo()
	golpeado.emit(self, r)
	return r

func _flash(cor: Color, fraco: bool) -> void:
	for m in _materiais:
		var mat: StandardMaterial3D = m
		mat.emission = cor * (0.45 if fraco else 1.0)
		var tw := create_tween()
		tw.tween_property(mat, "emission", Color.BLACK, 0.14).set_delay(0.04)

func _abrir_fx() -> void:
	if _argola != null:
		var tw := create_tween()
		tw.tween_property(_argola, "position:y", 1.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(_argola, "rotation_degrees:y", 120.0, 0.25)
	var luz := OmniLight3D.new()
	luz.light_color = Color("7fe07a")
	luz.light_energy = 2.5
	luz.omni_range = 2.2
	luz.position = Vector3(0, 0.9, 0)
	add_child(luz)

func _process(delta: float) -> void:
	relogio += delta
	if caido and relogio >= levanta_em:
		caido = false
		hp = hp_max
		guarda_ativa = tipo == "escudeiro"
		var tw := create_tween()
		tw.tween_property(_corpo, "rotation_degrees:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_restaurar_escudo()
		_atualizar_rotulo()
	if tipo == "escudeiro" and not guarda_ativa and not caido and relogio >= guarda_volta_em:
		guarda_ativa = true
		_restaurar_escudo()
		_atualizar_rotulo()

func _restaurar_escudo() -> void:
	if _escudo != null:
		var tw := create_tween()
		tw.tween_property(_escudo, "position:y", 1.2, 0.2)
		tw.parallel().tween_property(_escudo, "rotation_degrees:x", 0.0, 0.2)
