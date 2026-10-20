extends SceneTree
## Tour em video dos 3 mapas (Movie Maker). Um segmento por execucao:
##   godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/x.avi -s res://tests/video_tour.gd -- porto|orcs|fantasma
## Simula a entrada: eixos ui_* (como WASD) seguindo um caminho da navegacao assada; E/Espaco por InputEventKey.
const Estado = preload("res://scripts/dialogos/estado_dialogos.gd")
const FONTE := "res://art/ui/dialogos/fontes/PixelifySans.ttf"
const DIREITA := Vector3(0.70710678, 0, -0.70710678)
const BAIXO := Vector3(0.70710678, 0, 0.70710678)

var mapa: Node3D
var nav_map: RID
var rotulo: Label
var fonte: Font

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seg := args[0] if args.size() > 0 else "porto"
	fonte = load(FONTE)
	match seg:
		"porto": await porto()
		"orcs": await orcs()
		"fantasma": await fantasma()
	quit(0)

# ---------------------------------------------------------------- utilidades
func esperar(seg: float) -> void:
	for i in int(round(seg * 30.0)):
		await process_frame

func carregar(cena: String) -> void:
	Estado.reiniciar_global()
	mapa = load(cena).instantiate()
	root.add_child(mapa)
	await process_frame
	destacar_jogador()
	var reg: NavigationRegion3D = mapa.assar_navegacao()
	nav_map = reg.get_navigation_map()
	for i in 3:
		await physics_frame

## so no video: a capsula provisoria fica opaca e com um anel no chao para ser vista de longe
func destacar_jogador() -> void:
	var vis: MeshInstance3D = mapa.jogador.get_node_or_null("SubstituirPeloSpriteDaVale")
	if vis:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("ffd36b")
		m.emission_enabled = true
		m.emission = Color("ffb84a")
		m.emission_energy_multiplier = 0.9
		vis.material_override = m
	var anel := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.58
	anel.mesh = t
	anel.scale = Vector3(1, 0.15, 1)
	anel.position.y = 0.05
	var ma := StandardMaterial3D.new()
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ma.albedo_color = Color("fff1b8")
	anel.material_override = ma
	mapa.jogador.add_child(anel)

func pos2(p: Vector3) -> Vector3:
	return Vector3(p.x, 0, p.z)

func teleportar(x: float, z: float) -> void:
	var j: CharacterBody3D = mapa.jogador
	j.global_position = Vector3(x, mapa._y(x, z) + 0.3, z)
	j.velocity = Vector3.ZERO

func soltar_eixos() -> void:
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(a)

func eixos(dir: Vector3) -> void:
	var x := dir.dot(DIREITA)
	var y := dir.dot(BAIXO)
	soltar_eixos()
	if x > 0.01: Input.action_press("ui_right", x)
	elif x < -0.01: Input.action_press("ui_left", -x)
	if y > 0.01: Input.action_press("ui_down", y)
	elif y < -0.01: Input.action_press("ui_up", -y)

## anda ate (x, z) seguindo a navegacao; via = pontos intermediarios
func andar(pontos: Array, tol := 0.45) -> void:
	for alvo2 in pontos:
		var alvo := Vector3(alvo2.x, mapa._y(alvo2.x, alvo2.y), alvo2.y)
		var de: Vector3 = mapa.jogador.global_position
		var caminho: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, de, alvo, true)
		if caminho.size() < 2:
			caminho = PackedVector3Array([de, alvo])
		var final := pos2(caminho[caminho.size() - 1])
		if final.distance_to(pos2(alvo)) > 1.5:
			caminho.append(alvo)
		print("[video] caminho ate ", alvo2, ": ", caminho.size(), " pontos")
		for k in range(1, caminho.size()):
			var p := pos2(caminho[k])
			var limite := 60 * 5
			var ult := tol if k == caminho.size() - 1 else 0.6
			while limite > 0:
				var d := p - pos2(mapa.jogador.global_position)
				if d.length() < ult:
					break
				eixos(d.normalized())
				await physics_frame
				limite -= 1
			if limite <= 0:
				print("[video] AVISO: travou indo para ", p)
	soltar_eixos()
	await physics_frame

## ultimo trecho sem navegacao: anda reto ate ficar a 'dist' m do morador (o colisor dele barra o resto)
func aproximar(id: String, dist := 1.35, tempo := 4.0) -> void:
	var npc = mapa.npc(id)
	if npc == null:
		print("[video] AVISO: npc nao encontrado ", id)
		return
	var n := int(tempo * 60)
	while n > 0:
		var d := pos2(npc.global_position) - pos2(mapa.jogador.global_position)
		if d.length() < dist:
			break
		eixos(d.normalized())
		await physics_frame
		n -= 1
	soltar_eixos()
	print("[video] perto de ", id, ": ", snapped(pos2(npc.global_position).distance_to(pos2(mapa.jogador.global_position)), 0.01), " m")
	await physics_frame

func tecla(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame

## aperta E e mostra n falas (espera a digitacao + tempo de leitura); fecha com Esc se pedido
func conversar(n: int, leitura := 2.2, id := "") -> void:
	await esperar(0.6)   # aviso "E - Conversar" visivel
	await tecla(KEY_E)
	var caixa = mapa.dialogos.caixa
	if not mapa.dialogos.conversando:
		print("[video] AVISO: E nao abriu conversa, abrindo pelo id")
		var npc = mapa.dialogos.mais_proximo()
		if npc == null and id != "": npc = mapa.npc(id)
		if npc: mapa.dialogos.conversar(npc)
	for i in n:
		await esperar(0.3)
		var t := 0
		while caixa.texto.is_typing and t < 30 * 12:
			await process_frame
			t += 1
		await esperar(leitura)
		if i < n - 1:
			await tecla(KEY_SPACE)

func fechar_conversa() -> void:
	var caixa = mapa.dialogos.caixa
	if caixa.ativo:
		caixa._fechar()
	await esperar(0.3)

# ---------------------------------------------------------------- titulo
func titulo(nome: String, sub: String) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 120
	root.add_child(cl)
	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.06, 0.82)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(fundo)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	fundo.add_child(box)
	for par in [[nome, 76, Color("ffd98a")], [sub, 30, Color("e8e2d4")]]:
		var l := Label.new()
		l.text = par[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", fonte)
		l.add_theme_font_size_override("font_size", par[1])
		l.add_theme_color_override("font_color", par[2])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 8)
		box.add_child(l)
	# rotulo fixo no canto
	rotulo = Label.new()
	rotulo.text = "Ilha das Cinzas  ·  " + nome
	rotulo.position = Vector2(24, 18)
	rotulo.add_theme_font_override("font", fonte)
	rotulo.add_theme_font_size_override("font_size", 28)
	rotulo.add_theme_color_override("font_color", Color("ffe3a3"))
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	rotulo.add_theme_constant_override("outline_size", 7)
	rotulo.modulate.a = 0.0
	cl.add_child(rotulo)
	await esperar(2.0)
	for i in 18:
		var a := 1.0 - float(i + 1) / 18.0
		fundo.modulate.a = a
		rotulo.modulate.a = 1.0 - a
		await process_frame
	fundo.queue_free()

# ---------------------------------------------------------------- segmentos
func porto() -> void:
	await carregar("res://scenes/vila_grande/vila_grande.tscn")
	teleportar(1.5, 11.5)
	await esperar(0.2)
	await titulo("Porto Velho", "A vila do porto de dirigíveis")
	# praca: passa pelo chafariz e pelas barracas do mercado
	await andar([Vector2(-4.2, 4.2), Vector2(-5.2, -3.5), Vector2(-11.6, -9.6)])
	await aproximar("mira")
	await conversar(3, 1.8, "mira")
	await fechar_conversa()
	# doca: dirigivel e o dragao
	await titulo_rapido("Doca dos dirigíveis")
	teleportar(50, 0)
	mapa.zoom = 1.35
	await esperar(0.3)
	await aproximar("dragao", 1.5, 3.0)
	await conversar(1, 2.4, "dragao")
	await fechar_conversa()
	await esperar(0.4)

func titulo_rapido(txt: String) -> void:
	# corte curto entre cenas: escurece, troca o rotulo
	var cl := CanvasLayer.new()
	cl.layer = 119
	root.add_child(cl)
	var f := ColorRect.new()
	f.color = Color(0, 0, 0, 0)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(f)
	for i in 9:
		f.color.a = float(i + 1) / 9.0
		await process_frame
	if rotulo:
		rotulo.text = "Ilha das Cinzas  ·  Porto Velho  ·  " + txt
	await esperar(0.15)
	set_meta("fade", f)
	_desfazer(f, cl)

func _desfazer(f: ColorRect, cl: CanvasLayer) -> void:
	await esperar(0.5)
	for i in 9:
		f.color.a = 1.0 - float(i + 1) / 9.0
		await process_frame
	cl.queue_free()

func orcs() -> void:
	await carregar("res://scenes/vila_orcs/vila_orcs.tscn")
	teleportar(1.5, 20)
	await esperar(0.2)
	await titulo("Vila dos Orcs", "Clã Brasa-Velha")
	await andar([Vector2(5.5, 7.5), Vector2(6.5, -2.5), Vector2(1.1, -9.4)])
	await conversar(2)
	await esperar(0.6)

func fantasma() -> void:
	await carregar("res://scenes/cidade_fantasma/cidade_fantasma.tscn")
	teleportar(17.5, -22.0)
	await esperar(0.2)
	await titulo("Cidade Fantasma", "Cinzalta, a antiga capital do Reino do Céu")
	await andar([Vector2(17.5, -31.0), Vector2(13.0, -20.0), Vector2(-6.0, -10.0), Vector2(-22.9, -6.9)])
	await conversar(2)
	await esperar(0.6)
