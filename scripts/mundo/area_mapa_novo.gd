extends Node3D
## Adaptador dos mapas novos (Bolorina: scenes/vila_grande, vila_orcs, cidade_fantasma...): carrega o mapa e poe a
## Vale real (ValeFidelidade = Vale unica, sem espada) no lugar da capsula "SubstituirPeloSpriteDaVale",
## com o mesmo controle (WASD, Shift corre) e a mesma camera isometrica ortografica do jogo.
## E conversa com os NPCs do roster data/npcs/<area>.json (marcadores npc_<id> do mapa); minerio pelos marcadores
## minerio_* (jogo_ilha.gd monta). Colisao: CharacterBody3D contra os corpos do mapa (StaticBody3D / GridMap / CSG).
## Usado pelo registro de areas quando a area tem "adaptador": jogo_ilha.gd cria este no e chama carregar(cena).
const ValeFidelidade = preload("res://scripts/modular/vale_fidelidade.gd")
const NpcsArea = preload("res://scripts/economia/npcs_area.gd")
const CAPSULA := "SubstituirPeloSpriteDaVale"
const SPEED := 2.8
const RUN_MULT := 1.8
const YAW := deg_to_rad(50.0)
const PITCH := deg_to_rad(28.0)
var estado
var gerenciador
var area_id := ""
var mapa: Node
var player: CharacterBody3D
var sprite
var camera: Camera3D
var cam_size := 18.0
var area_npcs
var message: Label

func carregar(cena: String, id: String) -> void:
	area_id = id
	mapa = load(cena).instantiate()
	add_child(mapa)
	var cap := mapa.find_child(CAPSULA, true, false)
	var inicio := Vector3.ZERO
	if cap is Node3D:
		inicio = (cap as Node3D).global_position
		cap.queue_free()
	_montar_vale(inicio)
	_montar_camera()
	var roster := String(load("res://scripts/mundo/registro_areas.gd").info(id).get("roster", "res://data/npcs/%s.json" % id))
	if FileAccess.file_exists(roster):
		area_npcs = NpcsArea.new()
		add_child(area_npcs)
		area_npcs.montar(self, roster)
	var camada := CanvasLayer.new()
	add_child(camada)
	message = Label.new()
	message.position = Vector2(24, 862)
	message.add_theme_font_size_override("font_size", 14)
	message.text = "%s | WASD andar · Shift correr · E conversar · M mapa" % id.capitalize()
	camada.add_child(message)

func _montar_vale(p: Vector3) -> void:
	player = CharacterBody3D.new()
	player.name = "Vale"
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.4
	col.shape = cap
	col.position.y = 0.7
	player.add_child(col)
	add_child(player)
	player.global_position = p
	sprite = ValeFidelidade.new()
	sprite.preparar(1.72)
	player.add_child(sprite)
	sprite.play(sprite.animation_for("idle"))

func _montar_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.far = 400.0
	add_child(camera)
	camera.current = true
	_seguir(1.0)

func _seguir(t: float) -> void:
	var alvo := player.global_position + Vector3(0, 0.8, 0)
	var off := Vector3(sin(YAW), 0, cos(YAW)) * cos(PITCH) * 40.0 + Vector3(0, sin(PITCH) * 40.0, 0)
	camera.global_position = camera.global_position.lerp(alvo + off, t)
	camera.look_at(alvo, Vector3.UP)

func nascer(_spawn: String) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var parado: bool = area_npcs != null and area_npcs.aberto()
	var input := Vector2.ZERO
	if not parado:
		input = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var correndo := Input.is_physical_key_pressed(KEY_SHIFT)
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, YAW)
	var vy := player.velocity.y
	var h := Vector3(player.velocity.x, 0, player.velocity.z).move_toward(dir * SPEED * (RUN_MULT if correndo else 1.0), 32 * delta)
	player.velocity = h
	player.velocity.y = 0.0 if player.is_on_floor() else vy - 18.0 * delta
	player.move_and_slide()
	if sprite:
		sprite.set_direction(input)
		sprite.set_motion(h.length() > 0.1, correndo, false, false)
	_seguir(clampf(delta * 6.0, 0.0, 1.0))

func _process(delta: float) -> void:
	if area_npcs:
		area_npcs.cada_quadro(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if area_npcs and area_npcs.entrada(event):
		get_viewport().set_input_as_handled()
