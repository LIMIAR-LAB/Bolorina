extends Node3D
## Morador que conversa. Coloque no mapa (ou use InteracaoNpcs.spawn_em_marcadores) e defina npc_id.
## Monta sozinho: visual (campo "visual" do registro: sprite 8 direcoes, sprite pixel de art/npcs,
## modelo 3D ou, sem nada, boneco provisorio), corpo solido,
## Area3D de proximidade e o aviso flutuante "E - Conversar".
## Quem inicia a conversa e o no InteracaoNpcs (scripts/dialogos/interacao_npcs.gd).

signal jogador_entrou(npc)
signal jogador_saiu(npc)

const Registro = preload("res://scripts/dialogos/npcs_registro.gd")
const ActorVisual = preload("res://scripts/actor_visual.gd")

@export var npc_id := "mira"
@export var raio_conversa := 1.9
## Opcional: arquivo .dialogue diferente do padrao dialogos/<npc_id>.dialogue
@export_file("*.dialogue") var dialogo_personalizado := ""
@export var cue_inicial := "start"
@export var mostrar_nome := true

var visual: Node3D
var area: Area3D
var aviso: Label3D
var placa_nome: Label3D
var jogador_perto := false
var conversando := false
var _corpos := 0
## "ator", "sprite", "modelo" ou "provisorio" (ver Registro.tipo_visual).
var tipo_visual := "provisorio"
var _sprite_npc: AnimatedSprite3D
var _flutuar := false
var _t := 0.0

func _ready() -> void:
	set_process(false)
	add_to_group("npc_conversavel")
	if name.begins_with("@") or name == "NpcConversavel":
		name = "NPC_" + npc_id
	_montar_visual()
	_montar_area()
	_montar_avisos()

func dados() -> Dictionary:
	return Registro.dados(npc_id)

func nome_exibido() -> String:
	return String(dados().get("nome", npc_id))

func caminho_dialogo() -> String:
	return dialogo_personalizado if dialogo_personalizado != "" else Registro.caminho_dialogo(npc_id)

func carregar_dialogo() -> Resource:
	var c := caminho_dialogo()
	return load(c) if ResourceLoader.exists(c) else null

func _montar_visual() -> void:
	var caminho := Registro.visual(npc_id)
	tipo_visual = Registro.tipo_visual(npc_id)
	visual = null
	match tipo_visual:
		"ator":
			var a := ActorVisual.new()
			a.setup(caminho.get_base_dir().get_file())
			visual = a
		"sprite":
			visual = _sprite_pixel(caminho)
		"modelo":
			visual = _modelo_3d(caminho)
	if visual == null:
		tipo_visual = "provisorio"
		visual = _boneco_provisorio(Registro.cor(npc_id))
	visual.name = "Visual"
	visual.set_meta("tipo_visual", tipo_visual)
	add_child(visual)
	# corpo solido para a jogadora nao atravessar
	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	var forma := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32 if npc_id != "dragao" else 0.9
	cap.height = 1.5 if npc_id != "dragao" else 2.4
	forma.shape = cap
	forma.position.y = cap.height / 2.0
	corpo.add_child(forma)
	add_child(corpo)

## Sprite pixel (art/npcs/<id>/npc.json): billboard em Y, filtro nearest, mesma densidade da Vale
## (1.72 m / 48 px), idle de 2 quadros (respira 1 px) e vista de costas quando o morador tem.
func _sprite_pixel(caminho: String) -> Node3D:
	var info = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if typeof(info) != TYPE_DICTIONARY or not info.has("vistas"):
		return null
	var pasta := caminho.get_base_dir() + "/"
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for vista: String in info.vistas:
		var anim := "idle_" + vista
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info.get("fps", 2.0)))
		frames.set_animation_loop(anim, true)
		for f: String in info.vistas[vista]:
			var tex: Texture2D = load(pasta + f)
			if tex:
				frames.add_frame(anim, tex)
	if not frames.has_animation("idle_frente") or frames.get_frame_count("idle_frente") == 0:
		return null
	var raiz := Node3D.new()
	var spr := AnimatedSprite3D.new()
	spr.name = "Sprite"
	spr.sprite_frames = frames
	spr.pixel_size = float(info.get("pixel_size", 1.72 / 48.0))
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.shaded = false
	spr.double_sided = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.alpha_scissor_threshold = 0.5
	# pe na linha de baixo do quadro (a ultima linha do canvas e vazia)
	var canvas: Array = info.get("canvas", [48, 48])
	spr.centered = true
	spr.offset = Vector2(0, float(canvas[1]) / 2.0 - 1.0)
	raiz.add_child(spr)
	spr.play("idle_frente")
	# cada morador respira num ritmo levemente diferente
	var h := absi(npc_id.hash())
	spr.frame = h % 2
	spr.speed_scale = 0.85 + float(h % 7) * 0.05
	_sprite_npc = spr
	set_process(true)
	if Registro.eh_fantasma(npc_id):
		_fantasma(raiz, spr)
	else:
		_sombra(raiz, float(canvas[0]) * spr.pixel_size)
	return raiz

## Fantasma: translucido, brilho azulado (sem sombreamento + luz propria) e flutuando.
## Nas Minas, o mapa ja aplica o proprio efeito de fantasma (cor, luz e flutuacao) sobre o "Visual".
func _fantasma(raiz: Node3D, spr: AnimatedSprite3D) -> void:
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	spr.transparent = true
	spr.modulate = Color(0.78, 0.92, 1.25, 0.62)
	spr.render_priority = 1
	if Registro.dados(npc_id).has("fantasma"):
		return
	var luz := OmniLight3D.new()
	luz.name = "BrilhoFantasma"
	luz.light_color = Color("9ec8ff")
	luz.light_energy = 0.9
	luz.omni_range = 3.2
	luz.shadow_enabled = false
	luz.position = Vector3(0, 1.0, 0)
	raiz.add_child(luz)
	_flutuar = true

func _sombra(raiz: Node3D, largura: float) -> void:
	var sombra := MeshInstance3D.new()
	sombra.name = "Sombra"
	var quad := QuadMesh.new()
	quad.size = Vector2(clampf(largura * 0.55, 0.35, 2.6), clampf(largura * 0.32, 0.2, 1.5))
	sombra.mesh = quad
	sombra.rotation.x = -PI / 2
	sombra.position.y = 0.035
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/contact_shadow.gdshader")
	sombra.material_override = mat
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(sombra)

## Modelo 3D (robos, drone, vagoneta): os mapas que ja trocam o "Visual" por um modelo continuam
## funcionando (escondem este e poem o deles); fora desses mapas, este aparece sozinho.
func _modelo_3d(caminho: String) -> Node3D:
	var cena = load(caminho)
	if not (cena is PackedScene):
		return null
	var m: Node3D = cena.instantiate()
	var d := dados()
	var raiz := Node3D.new()
	m.scale = Vector3.ONE * float(d.get("escala_modelo", 1.0))
	m.position.y = float(d.get("flutua", 0.0))
	raiz.add_child(m)
	for ap: AnimationPlayer in m.find_children("*", "AnimationPlayer", true, false):
		for nome in ap.get_animation_list():
			if String(nome).to_lower().contains("idle"):
				ap.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
				ap.play(nome)
				break
	return raiz

func _process(delta: float) -> void:
	if _sprite_npc == null:
		set_process(false)
		return
	_corrigir_inclinacao()
	if _flutuar:
		_t += delta
		_sprite_npc.position.y = 0.16 + 0.09 * sin(_t * 1.7 + float(absi(npc_id.hash()) % 10))
		_sprite_npc.modulate.a = 0.55 + 0.1 * sin(_t * 2.3)

## Billboard em Y fica em pe, mas a camera olha de cima (isometrica, ~35 graus): sem correcao o sprite
## sairia achatado (cos 35 = 0.82) e com pixels mais baixos que largos. Estica no Y pelo inverso do
## cosseno da inclinacao da camera ativa: pixels quadrados na tela, iguais aos da Vale.
var _cos_cam := -1.0
func _corrigir_inclinacao() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var f := -cam.global_basis.z
	var c := clampf(Vector2(f.x, f.z).length(), 0.5, 1.0)
	if absf(c - _cos_cam) > 0.001:
		_cos_cam = c
		_sprite_npc.scale = Vector3(1.0, 1.0 / c, 1.0)

## Boneco provisorio low-poly (capsula + cabeca + capuz) na cor do morador.
func _boneco_provisorio(c: Color) -> Node3D:
	var raiz := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	var mat_pele := StandardMaterial3D.new()
	mat_pele.albedo_color = _pele_especial()
	var corpo := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.15
	corpo.mesh = cm
	corpo.material_override = mat
	corpo.position.y = 0.58
	raiz.add_child(corpo)
	var cabeca := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	cabeca.mesh = sm
	cabeca.material_override = mat_pele
	cabeca.position.y = 1.32
	raiz.add_child(cabeca)
	if npc_id == "gato":
		raiz.scale = Vector3(0.4, 0.4, 0.4)
	elif npc_id == "crianca_praca":
		raiz.scale = Vector3(0.7, 0.7, 0.7)
	if npc_id == "dragao":
		raiz.scale = Vector3(1.8, 1.8, 1.8)
		for lado in [-1, 1]:
			var asa := MeshInstance3D.new()
			var bm := PrismMesh.new()
			bm.size = Vector3(0.9, 0.5, 0.06)
			asa.mesh = bm
			asa.material_override = mat
			asa.position = Vector3(0.45 * lado, 1.0, -0.1)
			asa.rotation.z = -0.5 * lado
			raiz.add_child(asa)
	elif npc_id in ["arquimago", "sineiro", "condessa"]:
		var chapeu := MeshInstance3D.new()
		var con := CylinderMesh.new()
		con.top_radius = 0.0
		con.bottom_radius = 0.26
		con.height = 0.55 if npc_id == "arquimago" else 0.25
		chapeu.mesh = con
		chapeu.material_override = mat
		chapeu.position.y = 1.62
		raiz.add_child(chapeu)
	return raiz

func _pele_especial() -> Color:
	match npc_id:
		"lider_orc": return Color("7d9a52")
		"dragao": return Color("d8783a")
		"lobisomem": return Color("8a7660")
		"condessa": return Color("e6dcd8")
		"gato": return Color("3a3a3a")
	if npc_id.contains("orc"):
		return Color("7d9a52")
	if npc_id.begins_with("espectro") or npc_id.begins_with("eco_"):
		return Color("c8d0f0")
	if npc_id.begins_with("vampiro"):
		return Color("e6dcd8")
	return Color("e0b48a")

func _montar_area() -> void:
	area = Area3D.new()
	area.name = "AreaConversa"
	area.monitorable = false
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = raio_conversa
	forma.shape = esfera
	forma.position.y = 0.8
	area.add_child(forma)
	add_child(area)
	area.body_entered.connect(_corpo_entrou)
	area.body_exited.connect(_corpo_saiu)

func _montar_avisos() -> void:
	var altura := 2.15 if npc_id != "dragao" else 3.6
	placa_nome = _label3d(nome_exibido(), 34, Color("ffd27a"))
	placa_nome.position.y = altura
	placa_nome.visible = false
	add_child(placa_nome)
	aviso = _label3d("E - Conversar", 30, Color("f1e2bd"))
	aviso.position.y = altura + 0.42
	aviso.visible = false
	add_child(aviso)

func _label3d(t: String, tam: int, c: Color) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = Registro.fonte()
	l.font_size = tam
	l.pixel_size = 0.0095
	l.outline_size = 10
	l.modulate = c
	l.outline_modulate = Color(0.12, 0.07, 0.03, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return l

func _eh_jogador(body: Node) -> bool:
	return body.is_in_group("jogador") or (body is CharacterBody3D and not body.is_in_group("npc_conversavel"))

func _corpo_entrou(body: Node) -> void:
	if not _eh_jogador(body):
		return
	_corpos += 1
	if not jogador_perto:
		jogador_perto = true
		jogador_entrou.emit(self)

func _corpo_saiu(body: Node) -> void:
	if not _eh_jogador(body):
		return
	_corpos = maxi(0, _corpos - 1)
	if _corpos == 0 and jogador_perto:
		jogador_perto = false
		mostrar_aviso(false)
		jogador_saiu.emit(self)

func mostrar_aviso(sim: bool) -> void:
	if aviso:
		aviso.visible = sim and not conversando
	if placa_nome:
		placa_nome.visible = mostrar_nome and (sim or conversando)

## Vira o sprite para um ponto do mundo (usa a camera ativa para achar a direcao de tela).
func olhar_para(alvo: Vector3) -> void:
	if _sprite_npc:
		_virar_sprite(alvo)
		return
	if not visual or not visual.has_method("set_direction"):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := cam.unproject_position(global_position)
	var b := cam.unproject_position(alvo)
	visual.set_direction(b - a)
	if visual.has_method("set_motion"):
		visual.set_motion(false, false, false, false)

## Sprite pixel: de frente quando o alvo esta mais perto da camera que o morador, de costas quando
## esta mais longe (se houver vista de costas). Espelha a frente para o lado do alvo.
func _virar_sprite(alvo: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := cam.unproject_position(global_position)
	var b := cam.unproject_position(alvo)
	var d := b - a
	if d.length_squared() < 1.0:
		return
	var costas := d.y < -absf(d.x) * 0.5 and _sprite_npc.sprite_frames.has_animation("idle_costas")
	var anim := "idle_costas" if costas else "idle_frente"
	if _sprite_npc.animation != anim:
		var f := _sprite_npc.frame
		_sprite_npc.play(anim)
		_sprite_npc.frame = f % _sprite_npc.sprite_frames.get_frame_count(anim)
	_sprite_npc.flip_h = false
