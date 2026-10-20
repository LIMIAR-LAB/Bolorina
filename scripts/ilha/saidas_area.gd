extends Node3D
## Saidas robustas entre areas (fazenda, vila, arena...).
## Cada saida e um PORTAO LARGO (retangulo que cobre a largura toda da trilha e o terreno andavel em volta),
## nao um ponto: Area3D (body_entered) + checagem a cada quadro de fisica (ponto dentro + varredura do passo,
## para corrida/esquiva) + rearme so depois de o jogador ficar fora de todos os portoes (sem ida-e-volta).
## Visual: arco de madeira + brilho pulsante no chao com setas + rotulo "-> Vila"; dica no HUD ao se aproximar.
## defs: [{area, spawn, centro: Vector2 (x,z), tam: Vector2 (largura, profundidade), dir: Vector2 (para onde sai),
##         rotulo: String, arco: bool = true, cor: Color}]
signal saiu(area: String, spawn: String)

const SHADER_BRILHO := "res://shaders/saida_brilho.gdshader"
const DICA_DIST := 8.0
var no_area: Node          # cena da area (tem .player, .gerenciador)
var art                    # VisualWorld (box / materials) ou null
var altura_fn: Callable    # (x, z) -> y
var bloqueio: Callable     # () -> bool: true desativa as saidas (ex.: dentro de casa)
var defs: Array = []
var armado := false
var t := 0.0
var anterior := Vector3.INF
var disparos := 0
var ultimo_disparo := ""
var hud_camada: CanvasLayer
var hud: Label
var areas3d: Array = []

func montar(area_no: Node, lista: Array, art_mundo = null, alt: Callable = Callable(), bloq: Callable = Callable()) -> void:
	no_area = area_no
	art = art_mundo
	altura_fn = alt
	bloqueio = bloq
	name = "SaidasArea"
	for d in lista:
		var s: Dictionary = d.duplicate()
		s.dir = Vector2(s.get("dir", Vector2(0, 1))).normalized()
		s.centro = Vector2(s.centro)
		s.tam = Vector2(s.tam)
		s.rotulo = String(s.get("rotulo", s.area))
		defs.append(s)
		_volume(s)
		_marcador(s)
	_montar_hud()

func _y(x: float, z: float) -> float:
	return float(altura_fn.call(x, z)) if altura_fn.is_valid() else 0.0

## base local da saida: +z local = direcao de saida
func _base(s: Dictionary) -> Basis:
	var d: Vector2 = s.dir
	return Basis(Vector3.UP, atan2(d.x, d.y))

func _volume(s: Dictionary) -> void:
	var a := Area3D.new()
	a.name = "Saida_" + String(s.area)
	a.monitorable = false
	var c: Vector2 = s.centro
	a.position = Vector3(c.x, _y(c.x, c.y), c.y)
	a.basis = _base(s)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(s.tam.x, 8.0, s.tam.y)
	cs.shape = bx
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(func(b): if _eh_jogador(b): _tentar(s, "area3d"))
	areas3d.append(a)

func _eh_jogador(b) -> bool:
	return no_area != null and b == no_area.get("player")

## ponto (x,z) dentro do retangulo da saida (folga opcional)
func dentro(s: Dictionary, p: Vector2, folga := 0.0) -> bool:
	var d: Vector2 = p - Vector2(s.centro)
	var ao_longo := d.dot(s.dir)
	var lado := d.dot(Vector2(s.dir.y, -s.dir.x))
	return absf(lado) <= s.tam.x * 0.5 + folga and absf(ao_longo) <= s.tam.y * 0.5 + folga

func _varre(s: Dictionary, a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, ceili(a.distance_to(b) / 0.2))
	for i in n + 1:
		if dentro(s, a.lerp(b, float(i) / n)):
			return true
	return false

func _physics_process(delta: float) -> void:
	t += delta
	var pl = no_area.get("player") if no_area else null
	if pl == null:
		return
	var p: Vector3 = pl.position
	var cur := Vector2(p.x, p.z)
	var ant := cur if anterior == Vector3.INF else Vector2(anterior.x, anterior.z)
	anterior = p
	var em_algum := false
	for s in defs:
		if dentro(s, cur):
			em_algum = true
	if not armado:
		if not em_algum and t > 0.2:
			armado = true
		return
	for s in defs:
		if dentro(s, cur) or _varre(s, ant, cur):
			_tentar(s, "quadro")
			return

func _process(delta: float) -> void:
	_atualizar_hud()

func _tentar(s: Dictionary, origem: String) -> void:
	if not armado or t < 0.2:
		return
	if bloqueio.is_valid() and bool(bloqueio.call()):
		return
	var g = no_area.get("gerenciador") if no_area else null
	if g != null and g.ocupado:
		return
	armado = false
	disparos += 1
	ultimo_disparo = String(s.area) + " (" + origem + ")"
	saiu.emit(String(s.area), String(s.spawn))
	if g != null:
		g.ir(String(s.area), String(s.spawn))

# ------------------------------------------------------------ visual
func _marcador(s: Dictionary) -> void:
	var raiz := Node3D.new()
	raiz.name = "Marcador_" + String(s.area)
	var c: Vector2 = s.centro
	# o marcador fica na borda de entrada do portao (lado de dentro da area)
	var borda: Vector2 = c - Vector2(s.dir) * (s.tam.y * 0.5)
	raiz.position = Vector3(borda.x, _y(borda.x, borda.y), borda.y)
	raiz.basis = _base(s)
	add_child(raiz)
	var cor: Color = s.get("cor", Color(1.0, 0.68, 0.3))
	var larg: float = minf(float(s.get("largura_visual", s.tam.x)), 7.0)
	# brilho no chao (setas que correm para fora)
	var chao := MeshInstance3D.new()
	chao.name = "Brilho"
	var pm := PlaneMesh.new()
	pm.size = Vector2(larg, 3.2)
	chao.mesh = pm
	chao.position = Vector3(0, 0.07, 1.1)
	chao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_BRILHO)
	mat.set_shader_parameter("cor", cor)
	chao.material_override = mat
	raiz.add_child(chao)
	# arco de madeira (sem colisao: so marca, nao vira parede)
	if bool(s.get("arco", true)) and art != null:
		var meio := larg * 0.5 + 0.25
		for lado in [-1.0, 1.0]:
			art.box(Vector3(meio * lado, 1.35, 0.0), Vector3(0.22, 2.7, 0.22), "brown_planks_03", false, raiz)
			var lan: MeshInstance3D = art.box(Vector3(meio * lado, 2.2, -0.25), Vector3(0.22, 0.26, 0.22), "glow", false, raiz)
			lan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.box(Vector3(0, 2.75, 0), Vector3(meio * 2.0 + 0.6, 0.22, 0.3), "brown_planks_03", false, raiz)
		art.box(Vector3(0, 2.45, 0.02), Vector3(meio * 2.0 - 0.2, 0.08, 0.12), "brown_planks_03", false, raiz)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 0.9
	luz.omni_range = 4.5
	luz.shadow_enabled = false
	luz.position = Vector3(0, 1.8, -0.3)
	raiz.add_child(luz)
	var l := Label3D.new()
	l.name = "Rotulo"
	l.text = "→ " + String(s.rotulo)
	l.font_size = 52
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Color("fff1c8")
	l.outline_modulate = Color(0.12, 0.07, 0.03, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.position = Vector3(0, 3.35, 0)
	raiz.add_child(l)
	s["marcador"] = raiz

func _montar_hud() -> void:
	hud_camada = CanvasLayer.new()
	hud_camada.layer = 54
	add_child(hud_camada)
	hud = Label.new()
	hud.name = "DicaSaida"
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color("ffe7b0"))
	hud.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03))
	hud.add_theme_constant_override("outline_size", 8)
	hud.anchor_left = 0.5
	hud.anchor_right = 0.5
	hud.offset_left = -320
	hud.offset_right = 320
	hud.offset_top = 62
	hud.offset_bottom = 96
	hud.visible = false
	hud_camada.add_child(hud)

const SETAS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
func seta_para(alvo: Vector3) -> String:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var pl = no_area.get("player") if no_area else null
	if cam == null or pl == null:
		return "→"
	var v: Vector2 = cam.unproject_position(alvo) - cam.unproject_position(pl.global_position)
	if v.length() < 1.0:
		return "↓"
	var i := posmod(roundi(v.angle() / (PI / 4.0)), 8)
	return SETAS[i]

## texto da dica para a saida mais proxima (vazio se longe)
func dica() -> String:
	var pl = no_area.get("player") if no_area else null
	if pl == null or (bloqueio.is_valid() and bool(bloqueio.call())):
		return ""
	var p := Vector2(pl.position.x, pl.position.z)
	var melhor := ""
	var md := DICA_DIST
	for s in defs:
		var borda: Vector2 = Vector2(s.centro) - Vector2(s.dir) * (s.tam.y * 0.5)
		var d := p.distance_to(borda)
		if d < md:
			md = d
			var y := _y(borda.x, borda.y)
			melhor = "%s %s" % [seta_para(Vector3(borda.x, y, borda.y)), s.rotulo]
	return melhor

func _atualizar_hud() -> void:
	if hud == null:
		return
	var txt := dica()
	hud.visible = txt != ""
	if txt != "":
		hud.text = txt + "   (siga a trilha)"
