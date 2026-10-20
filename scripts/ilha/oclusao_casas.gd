extends Node
## Oclusao das casas (estilo Stardew): quando a Vale esta sob o telhado/alpendre de uma casa, ou atras
## dela vista da camera, o telhado (paineis, empenas, chamine, cumeeira e toldo) desbota para alfa baixo
## e volta suave quando ela sai. Vale para todas as casas com interior (interiores.casas), na vila e na fazenda.
## Env: OCLUSAO=0 desliga.
const ALFA_MIN := 0.22        # opacidade do telhado quando desbotado
const VEL := 3.5              # unidades de alfa por segundo
const ALTURA_TELHADO := 2.3   # malhas com base acima disto (m, local da casa) contam como telhado
const MARGEM_PX := 28.0
var game
var ativo := true
var casas: Array = []   # {no, malhas: Array[GeometryInstance3D], f (0 opaco .. 1 desbotado)}

func montar(g) -> void:
	game = g
	name = "OclusaoCasas"
	ativo = OS.get_environment("OCLUSAO") != "0"
	if game.get("interiores") == null or game.interiores == null:
		return
	for c in game.interiores.casas:
		var malhas: Array = []
		var inv: Transform3D = (c as Node3D).global_transform.affine_inverse()
		for mi in (c as Node3D).find_children("*", "GeometryInstance3D", true, false):
			if mi is CPUParticles3D or mi is GPUParticles3D:
				continue
			var ab: AABB = (inv * (mi as GeometryInstance3D).global_transform) * (mi as GeometryInstance3D).get_aabb()
			if ab.position.y > ALTURA_TELHADO:
				malhas.append(mi)
		casas.append({"no": c, "malhas": malhas, "f": 0.0})

## a Vale esta embaixo do telhado/alpendre (pegada da casa em coordenadas locais)
func sob_telhado(c: Node3D, p: Vector3) -> bool:
	var l := c.to_local(p)
	return absf(l.x) < 3.2 and l.z > -2.5 and l.z < 3.9

## a Vale esta atras da casa vista da camera: projeta dentro do telhado na tela e mais longe que a casa
func atras(c: Node3D, malhas: Array, p: Vector3, cam: Camera3D) -> bool:
	if cam == null or malhas.is_empty():
		return false
	var fundo := -cam.global_basis.z
	var prof_p := (p - cam.global_position).dot(fundo)
	var prof_c := (c.global_position - cam.global_position).dot(fundo)
	if prof_p < prof_c - 1.0:
		return false
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for mi in malhas:
		var ab: AABB = (mi as GeometryInstance3D).global_transform * (mi as GeometryInstance3D).get_aabb()
		for i in 8:
			var s := cam.unproject_position(ab.get_endpoint(i))
			mn = mn.min(s)
			mx = mx.max(s)
	# testa a cabeca e os pes da Vale
	for h in [0.2, 1.4]:
		var s := cam.unproject_position(p + Vector3(0, h, 0))
		if s.x > mn.x - MARGEM_PX and s.x < mx.x + MARGEM_PX and s.y > mn.y - MARGEM_PX and s.y < mx.y + MARGEM_PX:
			return true
	return false

func alvo(i: int) -> float:
	if not ativo or game.interiores.ativo >= 0:
		return 0.0
	var c: Node3D = casas[i].no
	var p: Vector3 = game.player.global_position
	if sob_telhado(c, p) or atras(c, casas[i].malhas, p, get_viewport().get_camera_3d()):
		return 1.0
	return 0.0

func _process(delta: float) -> void:
	if game == null:
		return
	for i in casas.size():
		var d: Dictionary = casas[i]
		var f0: float = d.f
		d.f = move_toward(f0, alvo(i), delta * VEL)
		if f0 == d.f:
			continue
		var tr: float = (1.0 - ALFA_MIN) * smoothstep(0.0, 1.0, float(d.f))
		for mi in d.malhas:
			(mi as GeometryInstance3D).transparency = tr

func opacidade(i: int) -> float:
	return 1.0 - (1.0 - ALFA_MIN) * smoothstep(0.0, 1.0, float(casas[i].f))
