extends "res://scripts/dungeon/inimigos/inimigo_masmorra.gd"
## Mini-chefe do último andar (PROPOSTA). Mesmo contrato de combate do inimigo_orc.gd.
##   * a cada 3º ataque faz um golpe em ÁREA em volta do corpo (raio_area, telegrafo maior);
##   * fase 2 com 50% de vida: +25% de velocidade, preparo mais curto e invoca reforços (sinal invocar);
##   * Chefe Orc Brasa-Viva: orc gigante em brasa (emissão + luz);
##   * Sineiro Afogado: fantasma gigante com um sino de bronze, some e reaparece perto da jogadora;
##   * O Paradoxo: um ECO da própria Vale — uma instância de jogador_combate.gd (sem colisão, sem
##     controle) usada só como corpo visual, tingida de ciano com glitch; rebobina e teleporta.
const JogadorCombate = preload("res://scripts/combate/jogador_combate.gd")
signal invocar(chefe, tipos: Array)
signal fase_mudou(chefe, fase: int)

var fase := 1
var n_ataques := 0
var em_area := false
var raio_area := 3.4
var distancia_normal := 1.25
var raio_normal := 1.45
var eco: CharacterBody3D
var sino: Node3D
var luz_brasa: OmniLight3D

func configurar(id: String, d: Dictionary, j: Node3D, mult_hp := 1.0, mult_dano := 1.0) -> void:
	super.configurar(id, d, j, mult_hp, mult_dano)
	raio_area = float(d.get("raio_area", 3.4))
	raio_aggro = 12.0

func _ready() -> void:
	super._ready()
	add_to_group("chefe_masmorra")
	distancia_normal = distancia_golpe
	raio_normal = raio_golpe
	match comportamento:
		"chefe_paradoxo":
			_montar_eco()
		"chefe_sineiro":
			_montar_sino()
		"chefe_orc":
			luz_brasa = OmniLight3D.new()
			luz_brasa.light_color = Color("ff6a20")
			luz_brasa.light_energy = 2.4
			luz_brasa.omni_range = 7.0
			luz_brasa.position = Vector3(0, 2.4, 0)
			corpo_visual.add_child(luz_brasa)

func _montar_eco() -> void:
	eco = JogadorCombate.new()
	eco.name = "EcoDaVale"
	add_child(eco)
	eco.collision_layer = 0
	eco.collision_mask = 0
	eco.velocidade = 0.0
	eco.hp_max = 999999
	eco.hp = 999999
	eco.scale = Vector3.ONE * 1.25
	sombra.visible = false
	for k in 2:   # dois "rastros" do eco, defasados
		var r := OmniLight3D.new()
		r.light_color = Color("5af0ff") if k == 0 else Color("ff5af0")
		r.light_energy = 1.4
		r.omni_range = 4.5
		r.position = Vector3(0.6 * (1 - 2 * k), 1.6, 0)
		corpo_visual.add_child(r)

func _montar_sino() -> void:
	sino = Node3D.new()
	sino.name = "Sino"
	sino.position = Vector3(0.9, 1.2, 0.5)
	corpo_visual.add_child(sino)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("8a6a3a")
	bronze.metallic = 0.85
	bronze.roughness = 0.35
	bronze.emission_enabled = true
	bronze.emission = Color("3ad0b0")
	bronze.emission_energy_multiplier = 0.35
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.55
	c.height = 0.8
	m.mesh = c
	m.material_override = bronze
	sino.add_child(m)
	var aro := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.62
	aro.mesh = t
	aro.material_override = bronze
	aro.position.y = -0.4
	sino.add_child(aro)
	var badalo := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	badalo.mesh = s
	badalo.material_override = bronze
	badalo.position.y = -0.5
	sino.add_child(badalo)

func _mudar(novo: String) -> void:
	if novo == "preparo":
		n_ataques += 1
		em_area = n_ataques % 3 == 0
		distancia_golpe = 0.0 if em_area else distancia_normal
		raio_golpe = raio_area if em_area else raio_normal
		(aviso.mesh as PlaneMesh).size = Vector2.ONE * raio_golpe * 2.0
		if em_area:
			efeito.emit(self, "ataque em área!", Color("ffb040"))
	super._mudar(novo)
	if eco:
		match novo:
			"golpe":
				eco.pedir_ataque(dir_ataque)
			"morrendo":
				eco.receber_dano(1, global_position - dir_ataque)

func receber_golpe(valor: int, emp: Vector3, pesado: bool) -> bool:
	# chefes não são atordoados por golpes leves fora do preparo (só recuam um pouco)
	var antes := estado
	var ok := super.receber_golpe(valor, emp * 0.35, pesado)
	if ok and vivo and antes == "perseguir" and estado == "atordoado" and not pesado:
		_mudar("perseguir")
	if ok and vivo and fase == 1 and hp <= hp_max * 0.5:
		fase = 2
		velocidade *= 1.25
		preparo *= 0.85
		recuperacao *= 0.8
		fase_mudou.emit(self, 2)
		invocar.emit(self, def.get("invoca", []))
		efeito.emit(self, "FASE 2", Color("ff5040"))
	return ok

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if eco and is_instance_valid(eco):
		eco.position = Vector3.ZERO
		var v := velocity
		v.y = 0
		eco.entrada_mov = eco.tela(v.normalized()) if v.length() > 0.3 and estado == "perseguir" else Vector2.ZERO
		if estado in ["preparo", "golpe"]:
			eco._virar(dir_ataque)
		elif jogador_real and is_instance_valid(jogador_real):
			eco._virar(jogador_real.global_position - global_position)

func _process(_delta: float) -> void:
	if eco and is_instance_valid(eco) and eco.sprite:
		var g := fmod(_t_vida * 7.0, 1.0)
		var c := Color(0.45, 1.6, 1.9) if g < 0.8 else Color(1.8, 0.5, 1.7)
		if flash > 0.0:
			c = Color(4, 4, 4)
		elif estado == "preparo":
			c = c.lerp(Color(2.4, 0.4, 0.4), 0.5 + 0.5 * sin(t * 26.0))
		c.a = 0.82 if estado != "morrendo" else clampf(1.0 - t / 1.5, 0, 1)
		eco.sprite.modulate = c
		eco.sprite.visible = true
		eco.position = Vector3(randf_range(-0.09, 0.09), 0, randf_range(-0.09, 0.09)) if g > 0.85 or _glitch > 0.0 else Vector3.ZERO
	if sino:
		sino.rotation.z = sin(_t_vida * (3.0 if estado != "preparo" else 14.0)) * 0.35
	if luz_brasa:
		luz_brasa.light_energy = 2.0 + 0.6 * sin(_t_vida * 9.0) + (2.0 if estado == "preparo" else 0.0)
