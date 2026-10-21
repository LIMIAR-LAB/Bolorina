extends "res://scripts/combate/inimigo_orc.gd"
## Inimigo 3D da masmorra (PROPOSTA). ESTENDE scripts/combate/inimigo_orc.gd sem editá-lo e
## reaproveita a máquina de estados do orc (surgindo -> perseguir -> preparo com telegrafo no
## chão -> golpe -> recuperação; atordoamento, postura/super-armadura, morte) e a MESMA interface
## de combate: sinais ataque(inimigo, centro, raio, dano) e morto(inimigo), receber_golpe(valor,
## empurrao, pesado) e alvejavel(). O que muda:
##   * visual: modelo 3D CC0 animado (Quaternius / KayKit) no lugar do sprite do orc;
##   * dados por tipo em data/dungeon/temas.json ("inimigos"): hp, dano, velocidade, alcance...
##   * ataque "corpo" (o do orc), "distancia" (telegrafo onde a jogadora está + projétil) e
##     "area" (golpe em volta do próprio corpo);
##   * desperta por proximidade/visão e segue o navmesh (isca_alvo.gd) quando não vê a jogadora;
##   * comportamentos: fantasma (atravessa paredes, pisca para perto da jogadora), flutua,
##     olho (flutua + mostrador de relógio; acerto deixa a jogadora lenta), duplicata
##     (rebobina para onde estava 2 s antes e teleporta para as costas da jogadora).
const IscaAlvo = preload("res://scripts/dungeon/inimigos/isca_alvo.gd")
signal disparo(inimigo, de: Vector3, para: Vector3, tipo: String)
signal efeito(inimigo, texto: String, cor: Color)

static var _cenas := {}
static var _tintas := {}

var tipo_id := ""
var def: Dictionary = {}
var jogador_real: Node3D
var isca: Node3D
var corpo_visual: Node3D
var tinta_sprite := Color(1, 1, 1, 1)
var modelo: Node3D
var anim: AnimationPlayer
var nomes_anim := {}
var tipo_ataque := "corpo"
var comportamento := ""
var alcance_min := 0.0
var raio_aggro := 9.5
var acordado := false
var voo := 0.0
var rebobinar_rest := 0
var overlay: StandardMaterial3D
var mat_fantasma: StandardMaterial3D
var barra_fundo: MeshInstance3D
var barra_mat: ShaderMaterial
var ponteiros: Node3D
var _anim_atual := ""
var _caminho := PackedVector3Array()
var _t_caminho := 0.0
var _t_visao := 0.0
var _ve := false
var _t_vida := 0.0
var _invisivel := false
var _piscar_fase := 0
var _t_piscar := 0.0
var _t_teleporte := 0.0
var _hist: Array = []
var _t_hist := 0.0
var _t_barra := 0.0
var _glitch := 0.0

func configurar(id: String, d: Dictionary, j: Node3D, mult_hp := 1.0, mult_dano := 1.0) -> void:
	tipo_id = id
	def = d
	hp_max = int(round(float(d.get("hp", 60)) * mult_hp))
	hp = hp_max
	dano = int(round(float(d.get("dano", 12)) * mult_dano))
	velocidade = float(d.get("velocidade", 3.1))
	alcance_ataque = float(d.get("alcance", 2.2))
	raio_golpe = float(d.get("raio_golpe", 1.45))
	preparo = float(d.get("preparo", 0.8))
	postura_max = float(d.get("postura", 22))
	escala = float(d.get("porte", 1.0))
	bruto = bool(d.get("bruto", false))
	tipo_ataque = String(d.get("ataque", "corpo"))
	comportamento = String(d.get("comportamento", ""))
	alcance_min = float(d.get("alcance_min", 0.0))
	voo = float(d.get("voo", 0.0))
	rebobinar_rest = int(d.get("rebobinar", 0))
	if tipo_ataque == "area":
		distancia_golpe = 0.0
	jogador_real = j
	alvo = null

static func _cena(caminho: String) -> PackedScene:
	if not _cenas.has(caminho):
		var p := "res://art/models/" + caminho
		_cenas[caminho] = load(p) if ResourceLoader.exists(p) else null
	return _cenas[caminho]

func _ready() -> void:
	super._ready()
	# Bolorina 21/10: "visual": "sprite_orc" mantem o sprite pixel do orc da arena (mesma arte, escala,
	# filtro nearest e sem sombreamento); o modelo 3D so entra nos tipos sem sprite proprio.
	var usa_sprite := String(def.get("visual", "")) == "sprite_orc"
	sprite.visible = usa_sprite
	if usa_sprite:
		tinta_sprite = Color(String(def.get("tinta_sprite", "ffffff")))
	add_to_group("inimigo_masmorra")
	if comportamento in ["fantasma", "chefe_sineiro"]:
		collision_mask = 0          # atravessa paredes
	corpo_visual = Node3D.new()
	corpo_visual.name = "CorpoVisual"
	add_child(corpo_visual)
	if not usa_sprite:
		_montar_modelo()
	isca = IscaAlvo.new()
	isca.name = "Isca"
	isca.top_level = true
	add_child(isca)
	overlay = StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	overlay.albedo_color = Color(0, 0, 0, 0)
	for mi: MeshInstance3D in corpo_visual.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = overlay
	_montar_barra()
	_anim_estado(estado)

# ------------------------------------------------------------------ modelo
func _montar_modelo() -> void:
	var caminho := String(def.get("modelo", ""))
	if caminho == "":
		return
	var cena := _cena(caminho)
	if cena == null:
		push_warning("inimigo_masmorra: modelo ausente %s" % caminho)
		return
	modelo = cena.instantiate()
	modelo.name = "Modelo"
	modelo.scale = Vector3.ONE * float(def.get("escala", 1.0))
	corpo_visual.add_child(modelo)
	for nome in def.get("esconder", []):
		var n := modelo.find_child(String(nome), true, false)
		if n is Node3D:
			n.visible = false
	if def.has("tinta") or def.has("brilho"):
		_tingir(Color(String(def.get("tinta", "ffffff"))), String(def.get("brilho", "")))
	if comportamento in ["fantasma", "chefe_sineiro"]:
		_fantasmagorico(Color(String(def.get("fantasma_cor", "8ad8ff"))))
	for k in ["arma", "arma2"]:
		if def.has(k):
			_anexar(def[k])
	anim = modelo.find_child("AnimationPlayer", true, false)
	var mapa: Dictionary = def.get("anims", {})
	for chave in mapa:
		nomes_anim[chave] = _achar_anim(String(mapa[chave]))
	for chave in ["idle", "run"]:
		var n := String(nomes_anim.get(chave, ""))
		if n != "" and anim:
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if comportamento == "olho":
		_mostrador()
	if def.has("brilho"):
		var l := OmniLight3D.new()
		l.light_color = Color(String(def.brilho))
		l.light_energy = 1.6
		l.omni_range = 5.0 * escala
		l.position = Vector3(0, 1.4 * escala, 0)
		corpo_visual.add_child(l)

func _achar_anim(n: String) -> String:
	if n == "" or anim == null:
		return ""
	var lista := anim.get_animation_list()
	for a in lista:
		if String(a) == n or String(a).ends_with("|" + n):
			return String(a)
	for a in lista:
		if String(a).to_lower().contains(n.to_lower()):
			return String(a)
	return ""

func _tingir(tinta: Color, brilho: String) -> void:
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base := mi.get_active_material(s)
			if not (base is StandardMaterial3D):
				continue
			var chave := "%d|%s|%s" % [base.get_instance_id(), tinta.to_html(), brilho]
			if not _tintas.has(chave):
				var m: StandardMaterial3D = base.duplicate()
				m.albedo_color = m.albedo_color * tinta
				if brilho != "":
					m.emission_enabled = true
					m.emission = Color(brilho)
					m.emission_energy_multiplier = 0.45
				_tintas[chave] = m
			mi.set_surface_override_material(s, _tintas[chave])

func _fantasmagorico(cor: Color) -> void:
	mat_fantasma = StandardMaterial3D.new()
	mat_fantasma.albedo_color = Color(cor.r * 0.7, cor.g * 0.85, cor.b, 0.5)
	mat_fantasma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_fantasma.emission_enabled = true
	mat_fantasma.emission = cor
	mat_fantasma.emission_energy_multiplier = 1.3
	mat_fantasma.rim_enabled = true
	mat_fantasma.rim = 0.8
	mat_fantasma.roughness = 0.4
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat_fantasma
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.light_color = cor
	l.light_energy = 1.1
	l.omni_range = 4.0 * escala
	l.position = Vector3(0, 1.2 * escala + voo, 0)
	corpo_visual.add_child(l)
	sombra.visible = false

func _anexar(a: Dictionary) -> void:
	var esq: Skeleton3D = modelo.find_child("*", true, false) as Skeleton3D
	for s in modelo.find_children("*", "Skeleton3D", true, false):
		esq = s
		break
	if esq == null:
		return
	var osso := String(a.get("osso", ""))
	var idx := esq.find_bone(osso)
	if idx < 0:
		for b in esq.get_bone_count():
			if esq.get_bone_name(b).to_lower() == osso.to_lower():
				idx = b
				break
	if idx < 0:
		return
	var cena := _cena(String(a.modelo))
	if cena == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = esq.get_bone_name(idx)
	esq.add_child(ba)
	var item: Node3D = cena.instantiate()
	var p: Array = a.get("pos", [0, 0, 0])
	var r: Array = a.get("rot", [0, 0, 0])
	item.position = Vector3(p[0], p[1], p[2])
	item.rotation_degrees = Vector3(r[0], r[1], r[2])
	# compensa a escala herdada do esqueleto: a arma fica com escala "escala x escala do modelo" no mundo
	var herdada := maxf(esq.global_transform.basis.get_scale().x, 0.0001)
	item.scale = Vector3.ONE * float(a.get("escala", 1.0)) * float(def.get("escala", 1.0)) / herdada
	ba.add_child(item)

func _mostrador() -> void:
	ponteiros = Node3D.new()
	ponteiros.name = "Mostrador"
	ponteiros.position = Vector3(0, 0.36, 0)
	ponteiros.rotation = Vector3(0, PI * 0.25, 0)
	corpo_visual.add_child(ponteiros)
	var ouro := StandardMaterial3D.new()
	ouro.albedo_color = Color("ffcf5a")
	ouro.metallic = 0.8
	ouro.roughness = 0.3
	ouro.emission_enabled = true
	ouro.emission = Color("ffb030")
	ouro.emission_energy_multiplier = 1.4
	var aro := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.58
	aro.mesh = t
	aro.material_override = ouro
	aro.rotation = Vector3(PI * 0.5, 0, 0)
	ponteiros.add_child(aro)
	for k in 12:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.04, 0.1 if k % 3 == 0 else 0.05, 0.04)
		m.mesh = b
		m.material_override = ouro
		var ang := k * TAU / 12.0
		m.position = Vector3(sin(ang) * 0.66, cos(ang) * 0.66, 0)
		m.rotation.z = -ang
		ponteiros.add_child(m)
	for k in 2:
		var piv := Node3D.new()
		piv.name = "Ponteiro%d" % k
		ponteiros.add_child(piv)
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.035, 0.42 if k == 0 else 0.3, 0.03)
		m.mesh = b
		m.material_override = ouro
		m.position = Vector3(0, b.size.y * 0.5, 0.05)
		piv.add_child(m)

const SHADER_BARRA := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;
uniform float fill = 1.0;
uniform vec4 cor : source_color = vec4(0.88, 0.29, 0.23, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec3 c = UV.x < fill ? cor.rgb : vec3(0.08, 0.04, 0.05);
	if (UV.y < 0.18 || UV.y > 0.82 || UV.x < 0.015 || UV.x > 0.985) c = vec3(0.02);
	ALBEDO = c;
}
"""
static var _shader_barra: Shader

func _montar_barra() -> void:
	if _shader_barra == null:
		_shader_barra = Shader.new()
		_shader_barra.code = SHADER_BARRA
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.13)
	barra_mat = ShaderMaterial.new()
	barra_mat.shader = _shader_barra
	barra_mat.render_priority = 2
	barra_mat.set_shader_parameter("cor", Color("e04a3a"))
	barra_fundo = MeshInstance3D.new()
	barra_fundo.name = "BarraDeVida"
	barra_fundo.mesh = q
	barra_fundo.material_override = barra_mat
	barra_fundo.position = Vector3(0, 2.1 * escala + voo, 0)
	barra_fundo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(barra_fundo)
	barra_fundo.visible = false

# ------------------------------------------------------------------ estados / animação
func _mudar(novo: String) -> void:
	if novo == "preparo" and tipo_ataque == "distancia" and jogador_real:
		var d := jogador_real.global_position - global_position
		d.y = 0
		distancia_golpe = clampf(d.length(), 1.0, alcance_ataque + 0.5) / maxf(escala, 0.01)
	super._mudar(novo)
	if novo == "golpe" and tipo_ataque == "distancia":
		disparo.emit(self, global_position + Vector3(0, 1.1 * escala + voo, 0), centro_golpe(), String(def.get("projetil", "flecha")))
	_anim_estado(novo)

func _tocar(chave: String, vel := 1.0, reiniciar := false) -> void:
	if anim == null:
		return
	var n := String(nomes_anim.get(chave, ""))
	if n == "":
		return
	if n != _anim_atual or reiniciar:
		anim.play(n, 0.12)
		if reiniciar:
			anim.seek(0.0, true)
		_anim_atual = n
	anim.speed_scale = vel

func _anim_estado(novo: String) -> void:
	if anim == null:
		return
	match novo:
		"surgindo":
			_tocar("surgir" if String(nomes_anim.get("surgir", "")) != "" else "idle", 1.4)
		"perseguir":
			_tocar("run")
		"preparo":
			var n := String(nomes_anim.get("ataque", ""))
			if n != "":
				var comp := anim.get_animation(n).length
				_tocar("ataque", clampf(comp * 0.5 / maxf(preparo, 0.05), 0.15, 3.0), true)
		"golpe":
			anim.speed_scale = 1.7
		"recuperacao":
			anim.speed_scale = 1.0
		"atordoado":
			if String(nomes_anim.get("hit", "")) != "":
				_tocar("hit", 1.6, true)
		"morrendo":
			_tocar("morte", 1.0, true)

func alvejavel() -> bool:
	return super.alvejavel() and not _invisivel

func acordar() -> void:
	if not acordado:
		acordado = true
		alvo = jogador_real

func receber_golpe(valor: int, emp: Vector3, pesado: bool) -> bool:
	var ok := super.receber_golpe(valor, emp, pesado)
	if ok:
		acordar()
		_t_barra = 3.0
		if vivo and rebobinar_rest > 0 and hp <= hp_max * 0.5:
			_rebobinar()
	return ok

# ------------------------------------------------------------------ ciclo
func _physics_process(delta: float) -> void:
	_t_vida += delta
	if vivo and jogador_real and is_instance_valid(jogador_real):
		_despertar()
		if acordado:
			_comportamento(delta)
			_navegar(delta)
	super._physics_process(delta)
	_pos_visual(delta)

func _visao(p: Vector3) -> bool:
	var espaco := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.9, 0), p + Vector3(0, 0.9, 0), 1)
	q.exclude = [get_rid()]
	return espaco.intersect_ray(q).is_empty()

func _dist_jogador() -> float:
	var d := jogador_real.global_position - global_position
	d.y = 0
	return d.length()

func _despertar() -> void:
	if acordado:
		return
	var d := _dist_jogador()
	if d < 3.5 or d < raio_aggro and (comportamento == "fantasma" or _visao(jogador_real.global_position)):
		acordar()

func _navegar(delta: float) -> void:
	if estado != "perseguir" or comportamento in ["fantasma", "chefe_sineiro"]:
		if alvo == isca:
			alvo = jogador_real
		return
	var p := jogador_real.global_position
	var d := _dist_jogador()
	_t_visao -= delta
	if _t_visao <= 0.0:
		_t_visao = 0.2
		_ve = _visao(p)
	if tipo_ataque == "distancia" and d < alcance_min and _ve:
		var fora := global_position - p
		fora.y = 0
		isca.global_position = global_position + fora.normalized() * 30.0
		alvo = isca
		return
	if _ve:
		alvo = jogador_real
		return
	_t_caminho -= delta
	if _t_caminho <= 0.0:
		_t_caminho = 0.3
		_caminho = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, p, true)
	var prox := p
	for q in _caminho:
		if Vector2(q.x - global_position.x, q.z - global_position.z).length() > 0.6:
			prox = q
			break
	var dir := prox - global_position
	dir.y = 0
	if dir.length() < 0.05:
		alvo = jogador_real
		return
	isca.global_position = global_position + dir.normalized() * 30.0
	alvo = isca

func _comportamento(delta: float) -> void:
	match comportamento:
		"fantasma", "chefe_sineiro":
			_piscar(delta)
		"duplicata", "chefe_paradoxo":
			_historico(delta)
			_teleporte(delta)

func _piscar(delta: float) -> void:
	_t_piscar += delta
	var intervalo := float(def.get("piscar", 4.5))
	match _piscar_fase:
		0:
			if estado == "perseguir" and _t_piscar > intervalo and _dist_jogador() > 3.2:
				_piscar_fase = 1
				_t_piscar = 0.0
				_invisivel = true
		1:
			if _t_piscar > 0.32:
				var ang := randf() * TAU
				var alvo_p := jogador_real.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(2.2, 3.2)
				global_position = Vector3(alvo_p.x, 0, alvo_p.z)
				_piscar_fase = 2
				_t_piscar = 0.0
		2:
			if _t_piscar > 0.3:
				_piscar_fase = 0
				_t_piscar = 0.0
				_invisivel = false

func _historico(delta: float) -> void:
	_t_hist += delta
	if _t_hist >= 0.1:
		_t_hist = 0.0
		_hist.append([_t_vida, global_position, hp])
		while _hist.size() > 0 and _t_vida - float(_hist[0][0]) > 3.0:
			_hist.pop_front()

func _rebobinar() -> void:
	if _hist.is_empty():
		return
	var e: Array = _hist[0]
	for h in _hist:
		if _t_vida - float(h[0]) >= 2.0:
			e = h
	rebobinar_rest -= 1
	global_position = e[1]
	hp = clampi(maxi(hp, int(e[2])), 1, int(hp_max * 0.8))
	_glitch = 0.6
	efeito.emit(self, "◄◄ rebobinou", Color("7af4ff"))

func _teleporte(delta: float) -> void:
	_t_teleporte += delta
	if estado != "perseguir" or _t_teleporte < 5.5:
		return
	var d := _dist_jogador()
	if d < 3.0 or d > 10.0:
		return
	_t_teleporte = 0.0
	var olhar: Vector3 = jogador_real.get("olhar") if jogador_real.get("olhar") != null else Vector3.RIGHT
	var destino: Vector3 = jogador_real.global_position - olhar * 1.9
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(mapa) > 0:
		destino = NavigationServer3D.map_get_closest_point(mapa, destino)
	global_position = Vector3(destino.x, 0, destino.z)
	_glitch = 0.4
	efeito.emit(self, "⟲", Color("ff7af0"))

func _pos_visual(delta: float) -> void:
	if corpo_visual == null:
		return
	var dir := Vector3.ZERO
	if estado in ["preparo", "golpe", "recuperacao"]:
		dir = dir_ataque
	elif velocity.length() > 0.25:
		dir = velocity
	elif acordado and jogador_real and is_instance_valid(jogador_real):
		dir = jogador_real.global_position - global_position
	dir.y = 0
	if dir.length() > 0.01:
		corpo_visual.rotation.y = lerp_angle(corpo_visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, 12.0 * delta))
	if estado == "perseguir" and anim:
		_tocar("run" if velocity.length() > 0.3 else "idle")
	var y := voo + (0.12 * sin(_t_vida * 2.3) if voo > 0.0 else 0.0)
	var s := 1.0
	match estado:
		"surgindo":
			s = lerpf(0.3, 1.0, clampf(t / 0.6, 0, 1))
		"morrendo":
			if voo > 0.0:
				y = lerpf(voo, 0.1, clampf(t / 0.6, 0, 1))
			if t > 1.1:
				y -= (t - 1.1) * 1.6
				s = maxf(0.05, 1.0 - (t - 1.1) * 1.4)
	corpo_visual.position = Vector3(0, y, 0)
	corpo_visual.scale = Vector3.ONE * s
	# brilho de dano / telegrafo vermelho
	var c := Color(0, 0, 0, 0)
	if flash > 0.0:
		c = Color(1, 1, 1, 0.85)
	elif estado == "preparo":
		var pulso := 0.5 + 0.5 * sin(t * 26.0)
		c = Color(1.0, 0.18, 0.08, 0.25 + 0.35 * pulso)
	if _glitch > 0.0:
		_glitch -= delta
		c = Color(0.3, 1.0, 1.0, 0.6) if fmod(_t_vida, 0.1) < 0.05 else Color(1.0, 0.3, 1.0, 0.5)
		corpo_visual.position.x = randf_range(-0.12, 0.12)
	overlay.albedo_color = c
	if mat_fantasma:
		var a := 0.5
		if _piscar_fase == 1:
			a = 0.5 * (1.0 - clampf(_t_piscar / 0.32, 0, 1))
		elif _piscar_fase == 2:
			a = 0.5 * clampf(_t_piscar / 0.3, 0, 1)
		elif estado == "morrendo":
			a = 0.5 * clampf(1.0 - t / 1.4, 0, 1)
		mat_fantasma.albedo_color.a = a
		corpo_visual.visible = a > 0.02
	if ponteiros:
		var hora := _t_vida * (6.0 if estado != "preparo" else 40.0)
		ponteiros.get_node("Ponteiro0").rotation.z = -hora
		ponteiros.get_node("Ponteiro1").rotation.z = -hora / 12.0
		ponteiros.rotation.y = PI * 0.25
	# barra de vida
	_t_barra -= delta
	if barra_fundo:
		barra_fundo.visible = _t_barra > 0.0 and vivo and not bool(def.get("chefe", false)) and not _invisivel
		barra_mat.set_shader_parameter("fill", clampf(float(hp) / maxf(hp_max, 1), 0.0, 1.0))

# Bolorina 21/10: variantes do orc em sprite ganham so uma tinta por cima do visual da arena
func _visual() -> void:
	super._visual()
	if sprite.visible and tinta_sprite != Color(1, 1, 1, 1):
		var m := sprite.modulate
		sprite.modulate = Color(m.r * tinta_sprite.r, m.g * tinta_sprite.g, m.b * tinta_sprite.b, m.a)
