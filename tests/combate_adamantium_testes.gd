extends SceneTree
## Testes da forma Adamantium + Raio de Adamantium no combate (combat_arena.tscn):
## transformacao (G) com i-frames/camera lenta/asas/aura/sprites blindados, barra enchida por
## acertos, carga (orbe crescente, tremor, movimento lento), feixe (atravessa varios inimigos,
## ticks de dano, empurrao, quebra props, para na parede, gira com a mira), duracao 1-1,5 s,
## recarga, superarmadura, fim da forma, save intocado.
var checks := 0
var failures := 0
var a
var j

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + text)

func _initialize() -> void:
	call_deferred("run")

func fis(n: int) -> void:
	for i in n:
		await physics_frame

func esperar(s: float) -> void:
	var alvo: float = j.relogio + s
	var guarda := 0
	while j.relogio < alvo - 0.0001 and guarda < 3000:
		await physics_frame
		guarda += 1

func limpar() -> void:
	for e in a.inimigos.duplicate():
		if is_instance_valid(e):
			a._inimigo_removido(e)
			e.queue_free()
	await fis(2)
	j.reiniciar(Vector3.ZERO)
	j.invulneravel_ate = 0.0
	j.entrada_mov = Vector2.ZERO
	await esperar(0.1)

func orc_parado(pos: Vector3):
	var e = a.gerar_inimigo(pos)
	e.alvo = null
	return e

func pronto_para_golpe(e) -> void:
	var g := 0
	while not e.alvejavel() and g < 400:
		await physics_frame
		g += 1

func transformar() -> void:
	j.energia = j.energia_max
	j.pedir_transformar()
	await esperar(j.transformar_duracao + 0.05)

func run() -> void:
	var save_existe := FileAccess.file_exists("user://island_v1.json")
	var save_hash := FileAccess.get_sha256("user://island_v1.json") if save_existe else ""
	a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	await fis(5)
	j = a.jogador
	a.hitstop_ativo = false
	await limpar()
	# ---------- barra e transformacao
	j.energia = 40.0
	check(not j.pedir_transformar() and j.estado == "livre", "Sem barra cheia nao transforma (energia 40)")
	var e1 = orc_parado(Vector3(1.6, 0, 0))
	await pronto_para_golpe(e1)
	var en0: float = j.energia
	j.pedir_ataque(Vector3(1, 0, 0))
	await esperar(0.3)
	check(j.energia > en0, "Acertar golpes enche a barra ADAMANTIUM (%.0f -> %.0f)" % [en0, j.energia])
	await limpar()
	check(not j.pode_raio() and not j.pedir_raio(Vector3(1, 0, 0)), "Raio indisponivel sem a forma")
	j.energia = j.energia_max
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_G
	var lentas0: int = a.stats.lentas
	a._unhandled_input(ev)
	await fis(1)
	check(j.estado == "transformando" and j.invulneravel(), "Tecla G inicia a transformacao em batalha com i-frames")
	check(a.stats.lentas == lentas0 + 1 and a.lenta_restante > 0.0 and Engine.time_scale < 0.5, "Camera lenta na explosao de transformacao (time_scale %.2f)" % Engine.time_scale)
	await esperar(j.transformar_duracao + 0.05)
	await process_frame
	check(j.transformado and j.estado == "livre", "Transformado depois de %.1f s" % j.transformar_duracao)
	var t_espera := 0
	while Engine.time_scale < 1.0 and t_espera < 200:
		await process_frame
		t_espera += 1
	check(Engine.time_scale == 1.0, "Camera lenta termina")
	await fis(2)
	check(String(j.sprite.animation).begins_with("a_idle_") and j.adamantium.visible and j.adamantium.aura.emitting, "Sprite da armadura PixelLab + aura ativos (%s)" % j.sprite.animation)
	check(j.adamantium.asas.asa_esquerda.visible and j.adamantium.asas.asa_direita.visible, "Asas visiveis")
	var h_normal: float = j.ALTURA_CORPO
	var h_forma: float = 44.0 * j.sprite.pixel_size
	check(absf(h_forma - h_normal) < 0.02, "Armadura na mesma altura do Vale (%.2f x %.2f m)" % [h_forma, h_normal])
	j.entrada_mov = Vector2(1, 0)
	await esperar(0.2)
	check(String(j.sprite.animation).begins_with("a_run_"), "Caminhada blindada ao mover (%s)" % j.sprite.animation)
	j.entrada_mov = Vector2.ZERO
	j.pedir_ataque(Vector3(1, 0, 0))
	await esperar(0.05)
	check(String(j.sprite.animation).begins_with("x_slash") and j.sprite.modulate.is_equal_approx(j.adamantium.TINTA), "Golpes com armadura (x_slash) e tom de adamantium durante a forma (%s)" % j.sprite.animation)
	await esperar(0.5)
	# ---------- raio: carga
	j.position = Vector3(-8, 0, 0)
	await fis(2)
	var linha := [orc_parado(Vector3(-5, 0, 0)), orc_parado(Vector3(-2, 0, 0.3)), orc_parado(Vector3(1.5, 0, -0.3))]
	var fora = orc_parado(Vector3(-4, 0, 5))
	var cx = a.props[0]
	for p in a.props:
		if is_instance_valid(p) and p.quebravel() and p.tipo == "caixote":
			cx = p
			break
	cx.global_position = Vector3(3.5, 0, 0)
	for e in linha + [fora]:
		await pronto_para_golpe(e)
	var hp0 := []
	for e in linha:
		hp0.append(e.hp)
	var fora_hp0: int = fora.hp
	check(j.pedir_raio(Vector3(1, 0, 0)) and j.estado == "carregando", "Segurar Q/RMB transformado carrega o Raio")
	await esperar(0.15)
	var orbe0: float = a.raio_fx.orbe.scale.x
	j.entrada_mov = Vector2(0, 1)
	var p0: Vector3 = j.global_position
	await esperar(0.5)
	var vel_carga: float = (j.global_position - p0).length() / 0.5
	j.entrada_mov = Vector2.ZERO
	await process_frame
	check(a.raio_fx.orbe.visible and a.raio_fx.orbe.scale.x > orbe0 * 1.5 and j.carga > 0.5, "Orbe de energia cresce com a carga (%.2f -> %.2f, carga %.0f%%)" % [orbe0, a.raio_fx.orbe.scale.x, j.carga * 100])
	check(a.tremor > 0.1, "Tremor de tela crescente durante a carga (%.2f)" % a.tremor)
	check(vel_carga < j.velocidade * 0.5, "Movimento lento carregando (%.1f m/s de %.1f)" % [vel_carga, j.velocidade])
	j.position = Vector3(-8, 0, 0)
	j.raio_dir = Vector3(1, 0, 0)
	await esperar(0.5)
	j.soltar_raio()
	await fis(2)
	check(j.estado == "raio" and a.raio_fx.feixe.visible, "Soltar dispara o feixe")
	var dur: float = j.raio_duracao
	await esperar(0.6)
	await process_frame
	var comp: float = a.raio_fx.comprimento
	check(comp >= 12.0, "Feixe longo (%.1f m)" % comp)
	var cor_ok: bool = (a.raio_fx.camadas[2].material_override as ShaderMaterial).get_shader_parameter("intensidade") > 2.0 and a.ambiente.glow_enabled
	check(cor_ok, "Nucleo aditivo HDR com glow/bloom ligado")
	j.entrada_mov = Vector2(0, 1)
	p0 = j.global_position
	await esperar(0.3)
	var vel_raio: float = (j.global_position - p0).length() / 0.3
	j.entrada_mov = Vector2.ZERO
	check(vel_raio < j.velocidade * 0.3, "Movimento lento disparando (%.1f m/s)" % vel_raio)
	var hp_meio: int = j.hp
	j.receber_dano(5, j.global_position + Vector3(1, 0, 0))
	check(j.estado == "raio" and j.hp < hp_meio, "Superarmadura: dano nao interrompe o raio")
	await esperar(dur)
	var feridos := 0
	var ticks_ok := true
	for i in linha.size():
		var e = linha[i]
		var perdeu: int = hp0[i] - (e.hp if is_instance_valid(e) else 0)
		if perdeu > 0:
			feridos += 1
		if perdeu < 2 * j.raio_dano_base:
			ticks_ok = false
	check(feridos == 3, "Feixe atravessa os 3 inimigos em linha (%d atingidos)" % feridos)
	check(ticks_ok and j.stats.raio_ticks >= 10, "Dano em ticks (%d ticks, cada inimigo >= 2 ticks)" % j.stats.raio_ticks)
	check(not is_instance_valid(fora) or fora.hp == fora_hp0, "Inimigo fora do feixe nao e atingido")
	var empurrado := false
	for e in linha:
		if is_instance_valid(e) and e.hp > 0 and e.global_position.x > -5.2 and absf(e.global_position.z) < 2.0:
			empurrado = true
	check(empurrado or a.stats.inimigos_mortos > 0, "Empurrao ao longo do feixe")
	check(not cx.inteiro, "Feixe quebra props no caminho (caixote)")
	check(dur >= 1.0 and dur <= 1.5, "Duracao do feixe %.2f s (1-1,5 s)" % dur)
	await fis(2)
	check(j.estado == "livre" and not a.raio_fx.disparando(), "Raio termina e volta ao livre")
	check(j.raio_recarga >= 6.0 and j.raio_recarga <= 8.0 and j.raio_recarga_restante() > j.raio_recarga - 1.0, "Recarga do raio %.1f s (restam %.1f s)" % [j.raio_recarga, j.raio_recarga_restante()])
	check(not j.pedir_raio(Vector3(1, 0, 0)), "Raio bloqueado durante a recarga")
	j.raio_cd_ate = 0.0
	# ---------- giro com a mira e parede
	j.position = Vector3(0, 0, 0)
	check(j.pedir_raio(Vector3(1, 0, 0)), "Raio de novo apos a recarga")
	j.soltar_raio()
	await esperar(0.3)
	j.raio_mira = Vector3(0, 0, 1)
	var d0: Vector3 = j.raio_dir
	await esperar(0.4)
	var giro := rad_to_deg(d0.angle_to(j.raio_dir))
	check(giro > 10.0 and giro < 40.0, "Feixe gira seguindo a mira com limite (%.0f graus em 0,4 s)" % giro)
	await process_frame
	var cmax: float = a.comprimento_raio(j.raio_origem(), Vector3(1, 0, 0), 15.0)
	check(cmax < 12.0, "Feixe para na parede da arena (%.1f m a partir do centro)" % cmax)
	await esperar(1.5)
	# ---------- fim da forma
	j.forma_ate = j.relogio + 0.1
	await esperar(0.2)
	await fis(2)
	check(not j.transformado and not j.adamantium.visible and not String(j.sprite.animation).begins_with("a_") and j.energia == 0.0, "Forma acaba no tempo e volta ao Vale normal (barra zerada)")
	check(a.dicas.text.contains("Raio de Adamantium") and a.dicas.text.contains("G"), "Controles na legenda do HUD")
	check(FileAccess.file_exists("user://island_v1.json") == save_existe and (not save_existe or FileAccess.get_sha256("user://island_v1.json") == save_hash), "Save intocado")
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	Engine.time_scale = 1.0
	a.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
