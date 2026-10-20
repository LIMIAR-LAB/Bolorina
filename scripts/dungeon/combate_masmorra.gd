extends Node3D
## Ponte de combate da masmorra (PROPOSTA). Liga a jogadora real (scripts/combate/jogador_combate.gd)
## aos inimigos (inimigo_masmorra.gd, que estende inimigo_orc.gd), reproduzindo a resolução de
## acertos de scripts/combate/arena_combate.gd:
##   _golpe_jogador(dados)  == arena_combate._golpe_jogador (combo: alcance + 0,5 e arco/2; especial:
##                              raio + 0,5; raio: feixe com largura) + checagem de parede (raycast)
##   _inimigo_ataca(...)    == arena_combate._inimigo_ataca (dist <= raio + 0,35 -> receber_dano)
## e acrescenta: projéteis (visuais), efeito de lentidão, loot que cai no chão e vai para o
## inventário da incursão (SessaoMasmorra.inventario, formato da forja {"itens": {id: qtd}}).
## Para fundir com a arena do Claude: os dois só dependem dos sinais golpe/ataque/morto e de
## receber_golpe/receber_dano, então esta classe pode virar um componente comum às duas.
const Sessao = preload("res://scripts/dungeon/sessao_masmorra.gd")
const Folhas = preload("res://scripts/combate/folhas.gd")
const Inimigo = preload("res://scripts/dungeon/inimigos/inimigo_masmorra.gd")
const Chefe = preload("res://scripts/dungeon/inimigos/chefe_masmorra.gd")

signal inimigo_morreu(e, tipo: String)
signal chefe_morreu(e)
signal loot_caiu(id: String, qtd: int)
signal loot_coletado(id: String, qtd: int)
signal aviso(texto: String, cor: Color)
signal tremor(forca: float)
signal jogador_caiu

var jogador: CharacterBody3D
var inimigos: Array = []
var pickups: Array = []
var rng := RandomNumberGenerator.new()
var nome_item: Callable = func(id: String) -> String: return id
var corte_tex: Texture2D
var mult_hp := 1.0
var mult_dano := 1.0
var cam_direita := Vector3(0.7071, 0, -0.7071)
var velocidade_base := 6.6
var lento_ate := 0.0
var relogio := 0.0
var stats := {"golpes": 0, "acertos": 0, "inimigos_mortos": 0, "chefes_mortos": 0, "dano_recebido": 0, "loot_drops": 0, "loot_coletado": 0, "projeteis": 0}

func iniciar(j: CharacterBody3D, semente: int) -> void:
	jogador = j
	rng.seed = semente
	velocidade_base = j.velocidade
	corte_tex = Folhas.textura("res://art/combate/vfx/fx_corte_crescente.png")
	j.golpe.connect(_golpe_jogador)

func gerar(tipo: String, pos: Vector3, acordado := false) -> CharacterBody3D:
	var d := Sessao.dados_inimigo(tipo)
	if d.is_empty():
		push_warning("combate_masmorra: tipo desconhecido " + tipo)
		return null
	var e: CharacterBody3D = (Chefe if bool(d.get("chefe", false)) else Inimigo).new()
	e.name = "%s_%d" % [tipo, inimigos.size()]
	var chefe_ := bool(d.get("chefe", false))
	e.configurar(tipo, d, jogador, 1.0 if chefe_ else mult_hp, 1.0 if chefe_ else mult_dano)
	e.vizinhos = inimigos
	e.cam_direita = cam_direita
	e.position = Vector3(pos.x, 0, pos.z)
	add_child(e)
	inimigos.append(e)
	e.ataque.connect(_inimigo_ataca)
	e.morto.connect(_inimigo_morto)
	e.disparo.connect(_disparo)
	e.efeito.connect(func(quem, texto, cor): _texto(quem.global_position + Vector3(0, 2.6 * quem.escala, 0), texto, cor))
	if e is Chefe:
		e.invocar.connect(_invocar)
		e.fase_mudou.connect(func(_c, _f): tremor.emit(0.8))
	if acordado:
		e.acordar()
	return e

func vivos() -> Array:
	return inimigos.filter(func(e): return is_instance_valid(e) and e.vivo)

func chefe() -> CharacterBody3D:
	for e in inimigos:
		if is_instance_valid(e) and e is Chefe:
			return e
	return null

func _process(delta: float) -> void:
	relogio += delta
	if jogador and lento_ate > 0.0 and relogio >= lento_ate:
		lento_ate = 0.0
		jogador.velocidade = velocidade_base
		jogador.sprite.modulate = Color.WHITE
	_atualizar_pickups(delta)

# ------------------------------------------------------------------ golpes da jogadora
func _parede_entre(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 0.9, 0), b + Vector3(0, 0.9, 0), 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func comprimento_raio(origem: Vector3, dir: Vector3, maximo: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(origem + Vector3(0, 0.9, 0), origem + Vector3(0, 0.9, 0) + dir * maximo, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return maximo
	return clampf((r.position - origem - Vector3(0, 0.9, 0)).length(), 1.0, maximo)

func _golpe_jogador(d: Dictionary) -> void:
	stats.golpes += 1
	var origem: Vector3 = d.origem
	var dir: Vector3 = d.dir
	var comp := 0.0
	if d.tipo == "combo":
		_fx_corte(origem, dir, int(d.get("indice", 0)), bool(d.get("investida", false)))
	elif d.tipo == "especial":
		_fx_anel(origem, float(d.raio))
	elif d.tipo == "raio":
		comp = comprimento_raio(origem, dir, float(d.comprimento))
	var acertos := 0
	for a in vivos():
		if not a.alvejavel():
			continue
		var para: Vector3 = a.global_position - origem
		para.y = 0
		var dist := para.length()
		var dentro := false
		match String(d.tipo):
			"combo":
				if dist <= float(d.alcance) + 0.5 * a.escala:
					var ang := rad_to_deg(dir.angle_to(para.normalized())) if dist > 0.05 else 0.0
					dentro = ang <= float(d.arco) * 0.5 or dist < 0.8
			"especial":
				dentro = dist <= float(d.raio) + 0.5 * a.escala
			"raio":
				var s := para.dot(dir)
				var lateral: Vector3 = para - dir * s
				dentro = s >= -0.5 and s <= comp + 0.5 and lateral.length() <= float(d.largura) * 0.5 + 0.5 * a.escala
		if not dentro:
			continue
		if d.tipo != "raio" and dist > 1.0 and not (a.comportamento in ["fantasma", "chefe_sineiro"]) and _parede_entre(origem, a.global_position):
			continue
		var emp: Vector3 = (para.normalized() if dist > 0.05 else dir) * float(d.empurrao)
		if a.receber_golpe(int(d.dano), emp, bool(d.pesado)):
			acertos += 1
			stats.acertos += 1
			var grande: bool = bool(d.pesado) or bool(d.get("investida", false))
			numero_dano(a.global_position + Vector3(0, 2.2 * a.escala + a.voo, 0), int(d.dano), grande)
			_explosao(a.global_position + Vector3(0, 1.0 * a.escala + a.voo, 0), 14 if grande else 8, Color(3.0, 2.6, 2.0), Color(1.2, 0.5, 0.1, 0.0), 4.0, 0.3)
			jogador.ganhar_energia(jogador.energia_por_acerto * (2.0 if bool(d.pesado) else 1.0))
	if acertos > 0:
		tremor.emit(0.5 if bool(d.pesado) else 0.25)

# ------------------------------------------------------------------ ataques dos inimigos
func _inimigo_ataca(e, centro: Vector3, raio: float, dano: int) -> void:
	if not is_instance_valid(jogador):
		return
	tremor.emit(0.2 if raio < 2.5 else 0.55)
	_explosao(centro + Vector3(0, 0.15, 0), 12 if raio < 2.5 else 30, Color(0.75, 0.62, 0.5), Color(0.45, 0.38, 0.33, 0.0), 2.4, 0.5)
	var para: Vector3 = jogador.global_position - centro
	para.y = 0
	if para.length() <= raio + 0.35:
		if jogador.receber_dano(dano, e.global_position):
			stats.dano_recebido += dano
			numero_dano(jogador.global_position + Vector3(0, 2.0, 0), dano, false, Color(1.0, 0.35, 0.3))
			if String(e.def.get("efeito", "")) == "lentidao":
				lento_ate = relogio + 2.5
				jogador.velocidade = velocidade_base * 0.55
				_texto(jogador.global_position + Vector3(0, 2.6, 0), "lenta!", Color("ffcf5a"))
			if jogador.hp <= 0:
				jogador_caiu.emit()

func _disparo(_e, de: Vector3, para: Vector3, tipo: String) -> void:
	stats.projeteis += 1
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cor: Color = {"flecha": Color("ffd08a"), "fogo": Color("ff7a2a"), "osso": Color("e8e0c8"), "magia": Color("9a6aff"), "laser": Color("5af0ff"), "relogio": Color("ffcf5a")}.get(tipo, Color.WHITE)
	mat.albedo_color = cor * 2.0
	if tipo == "flecha" or tipo == "osso":
		var b := BoxMesh.new()
		b.size = Vector3(0.06, 0.06, 0.7)
		m.mesh = b
	else:
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.36
		m.mesh = s
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var alvo := para + Vector3(0, 0.6, 0)
	m.global_position = de
	if (alvo - de).length() > 0.1:
		m.look_at(alvo, Vector3.UP)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.5
	luz.omni_range = 2.5
	m.add_child(luz)
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", alvo, 0.14)
	tw.tween_callback(m.queue_free)

func _invocar(c, tipos: Array) -> void:
	_texto(c.global_position + Vector3(0, 3.5, 0), "reforços!", Color("ff9a4a"))
	for i in tipos.size():
		var ang := TAU * i / maxf(tipos.size(), 1) + 0.4
		var p: Vector3 = c.global_position + Vector3(cos(ang), 0, sin(ang)) * 3.0
		var mapa := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(mapa) > 0:
			p = NavigationServer3D.map_get_closest_point(mapa, p)
		gerar(String(tipos[i]), p, true)

func _inimigo_morto(e) -> void:
	stats.inimigos_mortos += 1
	var tipo: String = e.tipo_id
	var drops := rolar(e.def.get("loot", []))
	var i := 0
	for id in drops:
		var ang := TAU * i / maxf(drops.size(), 1)
		soltar(String(id), int(drops[id]), e.global_position + Vector3(cos(ang), 0, sin(ang)) * 0.7)
		i += 1
	inimigos.erase(e)
	inimigo_morreu.emit(e, tipo)
	if e is Chefe:
		stats.chefes_mortos += 1
		chefe_morreu.emit(e)

## tabela [[id, chance, min, max], ...] -> {id: qtd}
func rolar(tabela: Array) -> Dictionary:
	var r := {}
	for linha in tabela:
		if rng.randf() <= float(linha[1]):
			var q := rng.randi_range(int(linha[2]), int(linha[3]))
			if q > 0:
				r[String(linha[0])] = int(r.get(String(linha[0]), 0)) + q
	return r

# ------------------------------------------------------------------ loot no chão
func soltar(id: String, qtd: int, pos: Vector3) -> Node3D:
	stats.loot_drops += 1
	var p := Node3D.new()
	p.name = "Loot_" + id
	p.set_meta("item", id)
	p.set_meta("qtd", qtd)
	p.set_meta("t", 0.0)
	add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)
	var cor := _cor_item(id)
	var m := MeshInstance3D.new()
	if id.begins_with("minerio") or id.begins_with("cristal") or id == "carvao":
		var pm := PrismMesh.new()
		pm.size = Vector3(0.32, 0.4, 0.32)
		m.mesh = pm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.3, 0.3)
		m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 1.6
	mat.metallic = 0.4
	m.material_override = mat
	m.name = "Gema"
	m.position.y = 0.45
	p.add_child(m)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 0.9
	luz.omni_range = 2.2
	luz.position.y = 0.6
	p.add_child(luz)
	var l := Label3D.new()
	l.text = "%s ×%d" % [nome_item.call(id), qtd]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.font_size = 26
	l.outline_size = 8
	l.modulate = cor.lerp(Color.WHITE, 0.6)
	l.position.y = 1.0
	p.add_child(l)
	pickups.append(p)
	loot_caiu.emit(id, qtd)
	return p

func _cor_item(id: String) -> Color:
	for k in [["prata", "c8d8e8"], ["cronostio", "7af4ff"], ["chip", "5aff9a"], ["cristal", "9ad8ff"], ["brasa", "ff6a2a"], ["adamantium", "c06aff"], ["cobre", "e08a4a"], ["ferro", "b0b0c0"], ["carvao", "505058"], ["essencia", "aaffaa"], ["eco", "ff7af0"], ["po_de", "ffe08a"], ["areia", "e8c87a"], ["couro", "a0704a"], ["osso", "e8e0c8"], ["presa", "ff5a6a"], ["engrenagem", "d0b060"], ["lingote", "ffd070"]]:
		if id.contains(k[0]):
			return Color(k[1])
	return Color("ffe08a")

func _atualizar_pickups(delta: float) -> void:
	if jogador == null or not is_instance_valid(jogador):
		return
	for p in pickups.duplicate():
		if not is_instance_valid(p):
			pickups.erase(p)
			continue
		var t: float = p.get_meta("t") + delta
		p.set_meta("t", t)
		var g: Node3D = p.get_node("Gema")
		g.rotation.y += delta * 2.0
		g.position.y = 0.45 + 0.08 * sin(t * 3.0)
		if t < 0.5 or jogador.estado == "morto":
			continue
		var para: Vector3 = jogador.global_position - p.global_position
		para.y = 0
		var d := para.length()
		if d < 0.8:
			coletar(p)
		elif d < 3.0:
			p.global_position += para / d * minf(d, (3.0 - d) * 5.0 + 2.0) * delta

func coletar(p: Node3D) -> void:
	var id := String(p.get_meta("item"))
	var q := int(p.get_meta("qtd"))
	Sessao.dar(id, q)
	stats.loot_coletado += q
	pickups.erase(p)
	_texto(p.global_position + Vector3(0, 1.4, 0), "+%d %s" % [q, nome_item.call(id)], _cor_item(id).lerp(Color.WHITE, 0.5))
	p.queue_free()
	loot_coletado.emit(id, q)

func coletar_tudo() -> int:
	var n := 0
	for p in pickups.duplicate():
		if is_instance_valid(p):
			n += int(p.get_meta("qtd"))
			coletar(p)
	return n

# ------------------------------------------------------------------ efeitos
func numero_dano(pos: Vector3, valor: int, grande: bool, cor := Color(1, 1, 1)) -> void:
	_texto(pos, str(valor), Color(1.0, 0.62, 0.2) if grande and cor == Color(1, 1, 1) else cor, 44 if grande else 32)

func _texto(pos: Vector3, texto: String, cor: Color, tam := 30) -> void:
	var l := Label3D.new()
	l.text = texto
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = tam
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.03, 0.05)
	l.modulate = cor
	l.render_priority = 10
	add_child(l)
	l.global_position = pos + cam_direita * randf_range(-0.3, 0.3)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.0, 0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)

func _fx_corte(origem: Vector3, dir: Vector3, indice: int, investida: bool) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var w: float = [2.6, 2.7, 3.4][clampi(indice, 0, 2)] * (1.15 if investida else 1.0)
	pm.size = Vector2(w, w * 81.0 / 128.0)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_texture = corte_tex
	mat.albedo_color = Color(2.4, 1.1, 0.5) if indice == 2 else Color(1.6, 1.35, 1.1)
	if investida:
		mat.albedo_color = Color(1.2, 1.6, 2.4)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z := dir.cross(Vector3.UP).normalized()
	if indice == 1:
		z = -z
	add_child(m)
	m.global_transform = Transform3D(Basis(dir, Vector3.UP, z), origem + dir * (w * 0.32) + Vector3(0, 0.75, 0))
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1.15, 1, 1.15), 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.16).set_delay(0.04)
	tw.chain().tween_callback(m.queue_free)

func _fx_anel(origem: Vector3, raio: float) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * raio * 2.3
	m.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cmb_anel.gdshader")
	m.material_override = mat
	add_child(m)
	m.global_position = origem + Vector3(0, 0.1, 0)
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("t", v), 0.0, 1.0, 0.45)
	tw.tween_callback(m.queue_free)
	_explosao(origem + Vector3(0, 0.6, 0), 40, Color(3.0, 1.4, 0.4), Color(1.0, 0.3, 0.05, 0.0), raio * 2.2, 0.6)
	tremor.emit(0.6)

func _explosao(pos: Vector3, n: int, c0: Color, c1: Color, vel: float, vida: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = vida
	p.direction = Vector3.UP
	p.spread = 180
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	p.color_ramp = g
	add_child(p)
	p.global_position = pos
	p.emitting = true
	var tm := get_tree().create_timer(vida + 0.3, true, false, true)
	tm.timeout.connect(p.queue_free)
