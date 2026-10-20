extends SceneTree
## Testes roteirizados do prototipo de combate (combat_arena.tscn): movimento 8 direcoes, tempos do
## combo com buffer, janela do combo, dash (i-frames, distancia, recarga, cancelamento, investida),
## dano/empurrao/flash/numeros, hitstop/tremor, telegrafo e golpe do inimigo, postura, morte,
## especial (area + recarga), quebraveis + cura, sala limpa -> recompensa -> porta, derrota/reinicio
## e verificacao de que o save e as cenas originais nao foram tocados.
var checks := 0
var failures := 0
var a
var j
const DIRS8 := ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]

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
	while j.relogio < alvo - 0.0001 and guarda < 2000:
		await physics_frame
		guarda += 1

func reais(n: int) -> void:
	for i in n:
		await process_frame

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

func altura_png(path: String, celula: Rect2i) -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path)).get_region(celula)
	var topo := -1
	var base := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 16.0 / 255.0:
				if topo < 0:
					topo = y
				base = y + 1
				break
	return base - topo

func run() -> void:
	var save_existe := FileAccess.file_exists("user://island_v1.json")
	var save_hash := FileAccess.get_sha256("user://island_v1.json") if save_existe else ""
	a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	await fis(5)
	j = a.jogador
	a.hitstop_ativo = false
	check(j != null and a.camera.current and a.estado_sala == "inicio" and a.props.size() == 10, "Cena combat_arena carrega (Vale, camera iso, HUD, 10 props)")
	check(j.sprite.sprite_frames.has_animation("c_slash_combo_east") and j.sprite.sprite_frames.get_frame_count("c_dash_south-west") == 49, "Animacoes Gamelab do Vale carregadas (6 direcoes x 4 movimentos, 49 quadros)")
	# ---------- movimento 8 direcoes
	var ok8 := true
	var falhas8 := []
	for i in 8:
		j.position = Vector3.ZERO
		await fis(1)
		var v := Vector2(cos(i * PI / 4.0), sin(i * PI / 4.0))
		j.entrada_mov = v
		var p0: Vector3 = j.global_position
		await fis(12)
		j.entrada_mov = Vector2.ZERO
		var desl: Vector3 = j.global_position - p0
		var esperado: Vector3 = (a.cam_direita * v.x + a.cam_cima * v.y).normalized()
		if desl.length() < 0.5 or desl.normalized().dot(esperado) < 0.97 or j.dir8 != DIRS8[i]:
			ok8 = false
			falhas8.append([i, j.dir8, desl])
	check(ok8, "Movimento em 8 direcoes relativo a camera + sprite na direcao certa %s" % str(falhas8))
	j.lado = 1
	j.dir8 = "north"
	var n_ok: bool = j.dir6() == "north-east"
	j.dir8 = "south"
	j.lado = -1
	check(n_ok and j.dir6() == "south-west", "N/S usam a diagonal mais proxima (NE / SW conforme o lado)")
	await limpar()
	# ---------- combo com buffer
	var golpes: Array = []
	var cb := func(d: Dictionary): golpes.append([j.relogio, int(d.get("indice", -1))])
	j.golpe.connect(cb)
	var t0: float = j.relogio
	j.pedir_ataque(Vector3(1, 0, 0))
	await esperar(0.05)
	j.pedir_ataque()          # durante o golpe 1 (antes do ponto de cancelamento): fica no buffer
	await esperar(0.15)
	j.pedir_ataque()          # durante o golpe 2
	await esperar(0.7)
	var tempos := []
	for g in golpes:
		tempos.append(snappedf(g[0] - t0, 0.001))
	var esperado := [j.combo_ativo[0], j.combo_cancelar[0] + j.combo_ativo[1], j.combo_cancelar[0] + j.combo_cancelar[1] + j.combo_ativo[2]]
	var ok_t := golpes.size() == 3
	if ok_t:
		for i in 3:
			ok_t = ok_t and golpes[i][1] == i and absf(tempos[i] - esperado[i]) <= 0.034
	check(ok_t, "Combo de 3 golpes com buffer: impactos em %s s (esperado %s)" % [str(tempos), str(esperado)])
	check(j.estado == "livre" and j.combo_i == -1, "Combo termina e reinicia apos o 3o golpe")
	golpes.clear()
	j.pedir_ataque()
	await esperar(0.40)       # golpe 1 termina em 0,26 s; janela do combo vai ate 0,56 s
	j.pedir_ataque()
	await fis(2)
	check(j.combo_i == 1, "Ataque dentro da janela continua o combo (golpe 2)")
	await esperar(0.9)
	j.pedir_ataque()
	await fis(2)
	check(j.combo_i == 0, "Ataque fora da janela recomeca o combo (golpe 1)")
	await esperar(0.5)
	j.golpe.disconnect(cb)
	# ---------- dash
	await limpar()
	j.position = Vector3(-3, 0, 3)
	await fis(1)
	j._virar(a.cam_direita)
	var p0: Vector3 = j.global_position
	j.pedir_dash()
	await fis(2)
	check(j.estado == "dash" and j.invulneravel(), "Dash inicia com invulnerabilidade")
	var hp0: int = j.hp
	a._inimigo_ataca(orc_parado(Vector3(8, 0, 6)), j.global_position, 1.4, 14)
	check(j.hp == hp0 and j.stats.esquivados == 1, "Golpe durante o dash nao causa dano (i-frames)")
	check(j.collision_mask & 8 == 0, "Dash atravessa inimigos (mascara sem a camada de inimigos)")
	await esperar(j.dash_duracao)
	var dist: float = (j.global_position - p0).length()
	check(absf(dist - j.dash_distancia) < 0.45, "Distancia do dash ~%.1f m (medido %.2f)" % [j.dash_distancia, dist])
	j.pedir_dash()
	await fis(3)
	check(j.estado != "dash", "Recarga impede dash imediato")
	await esperar(j.dash_recarga + 0.05)
	await esperar(j.dash_iframes_extra + 0.05)
	a._inimigo_ataca(a.inimigos[0], j.global_position, 1.4, 14)
	check(j.hp == hp0 - 14, "Fora do dash o mesmo golpe causa 14 de dano")
	await esperar(j.iframes_dano + 0.4)
	j.pedir_dash()
	await fis(2)
	check(j.estado == "dash", "Dash disponivel de novo apos a recarga (%.2f s)" % j.dash_recarga)
	j.pedir_ataque()
	await esperar(j.dash_duracao + 0.05)
	check(j.estado == "ataque" and j.investida, "Ataque logo apos o dash vira golpe de investida")
	await esperar(0.5)
	j.pedir_ataque()
	await esperar(0.03)
	j.pedir_dash()
	await fis(2)
	check(j.estado == "dash", "Dash cancela o ataque no inicio do golpe")
	# ---------- dano, empurrao, flash, numeros
	await limpar()
	j.position = Vector3(0, 0, 0)
	var e = orc_parado(Vector3(1.6, 0, 0))
	await esperar(0.8)
	var num0: int = a.stats.numeros
	var pe0: Vector3 = e.global_position
	j.pedir_ataque(Vector3(1, 0, 0))
	await esperar(0.1)
	check(e.hp == e.hp_max - 10, "Golpe 1 tira 10 de vida (%d/%d)" % [e.hp, e.hp_max])
	check(e.flash > 0.0, "Inimigo pisca branco ao ser atingido")
	check(a.stats.numeros == num0 + 1, "Numero de dano aparece")
	await esperar(0.2)
	check((e.global_position - pe0).x > 0.15, "Empurrao afasta o inimigo (%.2f m)" % (e.global_position - pe0).x)
	check(e.estado == "atordoado" or e.estado == "perseguir", "Golpe leve atordoa fora do preparo (%s)" % e.estado)
	await esperar(0.5)
	var hp_atras: int = e.hp
	j._virar(Vector3(-1, 0, 0))
	j.pedir_ataque(Vector3(-1, 0, 0))
	await esperar(0.3)
	check(e.hp == hp_atras, "Golpe para o lado oposto nao acerta (arco de ataque)")
	# ---------- hitstop e tremor
	a.hitstop_ativo = true
	await esperar(0.5)
	j.position = e.global_position - Vector3(1.4, 0, 0)
	await fis(1)
	var hs0: int = a.stats.hitstops
	j.pedir_ataque(Vector3(1, 0, 0))
	var viu_hitstop := false
	for i in 120:
		await process_frame
		if Engine.time_scale < 0.5:
			viu_hitstop = true
			break
	check(viu_hitstop and a.stats.hitstops == hs0 + 1 and a.tremor > 0.0, "Hitstop (time_scale %.2f) + tremor de tela no acerto" % Engine.time_scale)
	await reais(40)
	check(Engine.time_scale == 1.0, "Hitstop termina e a velocidade volta ao normal")
	a.hitstop_ativo = false
	# ---------- telegrafo e golpe do inimigo
	await limpar()
	j.position = Vector3(0, 0, 0)
	var orc = a.gerar_inimigo(Vector3(2.0, 0, 0))
	var guarda := 0
	while orc.estado != "preparo" and guarda < 240:
		await physics_frame
		guarda += 1
	check(orc.estado == "preparo" and orc.aviso.visible, "Inimigo entra em preparo com telegrafo no chao")
	var tp: float = j.relogio
	var hp1: int = j.hp
	while orc.estado == "preparo":
		await physics_frame
	var dur: float = j.relogio - tp
	check(absf(dur - orc.preparo) < 0.05, "Preparo dura %.2f s antes do golpe (medido %.2f)" % [orc.preparo, dur])
	await fis(2)
	check(j.hp == hp1 - orc.dano, "Golpe do orc acerta quem fica parado (%d de dano)" % orc.dano)
	await fis(int(orc.golpe_dur * 60) + 2)
	check(orc.estado == "recuperacao", "Depois do golpe o orc fica vulneravel (recuperacao)")
	# postura
	await limpar()
	j.position = Vector3(0, 0, 0)
	orc = a.gerar_inimigo(Vector3(2.0, 0, 0))
	guarda = 0
	while orc.estado != "preparo" and guarda < 240:
		await physics_frame
		guarda += 1
	orc.receber_golpe(10, Vector3.RIGHT, false)
	check(orc.estado == "preparo", "Postura: golpe leve nao interrompe o preparo")
	orc.receber_golpe(10, Vector3.RIGHT, true)
	check(orc.estado == "atordoado", "Golpe pesado quebra a postura e interrompe o golpe")
	# ---------- morte
	var mortos0: int = a.stats.inimigos_mortos
	orc.alvo = null
	j.position = orc.global_position - Vector3(1.3, 0, 0)
	await fis(1)
	var guarda2 := 0
	while orc.vivo and guarda2 < 30:
		j.position = orc.global_position - Vector3(1.3, 0, 0)
		await fis(1)
		j.pedir_ataque((orc.global_position - j.global_position).normalized())
		await esperar(0.3)
		guarda2 += 1
	check(not orc.vivo and orc.estado == "morrendo", "Inimigo morre ao zerar a vida")
	await esperar(1.8)
	check(not is_instance_valid(orc) and a.inimigos.is_empty() and a.stats.inimigos_mortos == mortos0 + 1, "Inimigo morto sai da cena e da lista")
	# ---------- especial
	await limpar()
	j.position = Vector3(0, 0, 0)
	var e1 = orc_parado(Vector3(2.2, 0, 0))
	var e2 = orc_parado(Vector3(-1.5, 0, 1.5))
	var e3 = orc_parado(Vector3(-6, 0, -4))
	await esperar(0.8)
	j.pedir_especial()
	await fis(2)
	check(j.estado == "especial" and not j.especial_pronto(), "Especial inicia e entra em recarga (%.1f s)" % j.especial_recarga)
	await esperar(j.especial_ativo + 0.05)
	check(e1.hp == e1.hp_max - j.especial_dano and e2.hp == e2.hp_max - j.especial_dano and e3.hp == e3.hp_max, "Especial atinge em area (raio %.1f m) e nao alcanca quem esta longe" % j.especial_raio)
	await esperar(j.especial_total)
	j.pedir_especial()
	await fis(2)
	check(j.estado != "especial", "Especial bloqueado durante a recarga")
	await esperar(j.especial_recarga)
	j.pedir_especial()
	await fis(2)
	check(j.estado == "especial", "Especial volta apos a recarga")
	await esperar(1.0)
	# ---------- quebraveis
	await limpar()
	var caixa = a.props[0]
	var urna = a.props[2]
	var rocha = a.props[8]
	j.position = caixa.global_position + Vector3(1.4, 0, 0)
	await fis(1)
	j.pedir_ataque(Vector3(-1, 0, 0))
	await esperar(0.3)
	check(not caixa.inteiro and caixa.forma.disabled, "Caixote quebra com um golpe (sprite quebrado, sem colisao)")
	j.position = urna.global_position + Vector3(0, 0, 1.4)
	await fis(1)
	j.pedir_ataque(Vector3(0, 0, -1))
	await esperar(0.3)
	var orbes: Array = get_nodes_in_group("cmb_cura")
	check(not urna.inteiro and orbes.size() >= 1, "Urna quebra e deixa um orbe de cura")
	j.hp = 50
	j.position = Vector3(orbes[0].position.x, 0, orbes[0].position.z)
	await esperar(0.1)
	check(j.hp == 60, "Orbe de cura recupera 10 de vida")
	j.position = rocha.global_position + Vector3(1.5, 0, 0)
	await fis(1)
	j.pedir_ataque(Vector3(-1, 0, 0))
	await esperar(0.3)
	check(rocha.inteiro, "Rocha e cobertura indestrutivel")
	# ---------- sala: ondas -> limpa -> recompensa -> porta
	await limpar()
	a.reiniciar_sala()
	await fis(2)
	a.onda = 0
	a.gerar_onda(0)
	a._mudar_sala("combate")
	var n_onda1: int = a.inimigos.size()
	await esperar(0.8)
	for x in a.inimigos.duplicate():
		x.receber_golpe(999, Vector3.ZERO, true)
	var g3 := 0
	while a.estado_sala != "intervalo" and g3 < 200:
		await physics_frame
		g3 += 1
	check(n_onda1 >= 2 and a.estado_sala == "intervalo", "Onda 1 (%d orcs) derrotada -> intervalo" % n_onda1)
	g3 = 0
	while a.estado_sala != "combate" and g3 < 200:
		await physics_frame
		g3 += 1
	var tem_bruto := false
	for x in a.inimigos:
		tem_bruto = tem_bruto or x.bruto
	check(a.onda == 1 and a.inimigos.size() >= 3 and tem_bruto, "Onda 2 com %d orcs (inclui um bruto)" % a.inimigos.size())
	await esperar(0.8)
	for x in a.inimigos.duplicate():
		x.receber_golpe(999, Vector3.ZERO, true)
	g3 = 0
	while a.estado_sala != "recompensa" and g3 < 400:
		await physics_frame
		g3 += 1
	check(a.stats.salas_limpas == 1 and a.recompensa != null and a.porta_mat.get_shader_parameter("aberto") == 0.0, "Sala limpa -> recompensa aparece; porta ainda fechada")
	j.position = Vector3(a.recompensa.position.x, 0, a.recompensa.position.z)
	await esperar(0.1)
	check(a.estado_sala == "porta" and a.porta_mat.get_shader_parameter("aberto") == 1.0 and is_equal_approx(j.multiplicador_dano, 1.2), "Pegar a bencao (+20% dano) abre a porta")
	j.position = a.porta.global_position + Vector3(0, 0, 1.2)
	await esperar(0.1)
	check(a.sala == 2 and a.estado_sala == "inicio", "Entrar na porta leva a proxima sala (placeholder: sala 2)")
	# ---------- derrota e reinicio
	await limpar()
	j.hp = 5
	a._inimigo_ataca(orc_parado(Vector3(6, 0, 6)), j.global_position, 1.4, 14)
	await fis(2)
	check(j.estado == "morto" and a.estado_sala == "derrota", "Vida zerada -> derrota")
	a.reiniciar_sala()
	await fis(3)
	check(j.hp == j.hp_max and j.estado == "livre" and a.estado_sala == "inicio" and a.sala == 1, "R reinicia a sala com vida cheia")
	# ---------- isolamento: save e cenas originais
	check(FileAccess.file_exists("user://island_v1.json") == save_existe and (not save_existe or FileAccess.get_sha256("user://island_v1.json") == save_hash), "Save do jogador intocado (user://island_v1.json %s)" % ("igual" if save_existe else "continua inexistente"))
	var limpo := true
	for f in DirAccess.get_files_at("res://scripts/combate"):
		if f.ends_with(".gd"):
			for linha in FileAccess.get_file_as_string("res://scripts/combate/" + f).split("\n"):
				var l := linha.strip_edges()
				if not l.begins_with("#") and l.contains("user://"):
					limpo = false
	check(limpo, "Scripts de combate nao acessam user://")
	check(FileAccess.get_sha256("res://main.tscn").to_upper().begins_with("9277F464F494") and FileAccess.get_sha256("res://reference_village.tscn").to_upper().begins_with("45E60611A0FE"), "main.tscn e reference_village.tscn inalterados (sha256)")
	var imports := 0
	for sub in ["slash_combo", "dash", "hit", "special"]:
		for f in DirAccess.get_files_at("res://art/characters/vale_combate_gamelab/" + sub):
			if f.ends_with(".import"):
				imports += 1
	check(imports == 0, "Pasta vale_combate_gamelab nao recebeu .import (folhas carregadas em tempo de execucao)")
	# ---------- escala: idle/corrida (PASTA_BASE: Vale unica) x quadros Gamelab (sem "salto" de tamanho ao atacar)
	var alturas_esc := {}
	var pior_esc := 1.0
	var pior_corrida := 1.0
	for d: String in j.dados.direcoes:
		var idle_h := altura_png(j.PASTA_BASE + String(j.base_manifest.anims["idle_" + d].files[0]), Rect2i(0, 0, 48, 48))
		var run_hs := []
		for f in j.base_manifest.anims["run_" + d].files:
			run_hs.append(altura_png(j.PASTA_BASE + String(f), Rect2i(0, 0, 48, 48)))
		var run_h: float = run_hs.max()  # corpo em pe no pico da passada
		var golpe_h := altura_png("res://art/characters/vale_combate_gamelab/slash_combo/slash_combo_%s_sheet.png" % d, Rect2i(0, 0, 112, 112))
		var hs := [idle_h * j.get_script().PX_IDLE, run_h * j.get_script().PX_BASE, golpe_h * j.get_script().PX_COMBATE]
		alturas_esc[d] = "idle %.2f / corrida %.2f / golpe %.2f m" % hs
		pior_esc = maxf(pior_esc, maxf(hs[0], hs[2]) / minf(hs[0], hs[2]))
		pior_corrida = maxf(pior_corrida, maxf(hs[1], hs[2]) / minf(hs[1], hs[2]))
	print("INFO escala Vale combate: ", alturas_esc)
	check(pior_esc <= 1.05, "Escala Vale: idle -> golpe Gamelab sem salto (pior razao %.3f, limite 1,05; antes 1,17)" % pior_esc)
	check(pior_corrida <= 1.08, "Escala Vale: corrida -> golpe Gamelab sem salto (pior razao %.3f, limite 1,08 = pulo da passada)" % pior_corrida)
	print("RESULTADO: %d/%d verificacoes" % [checks - failures, checks])
	Engine.time_scale = 1.0
	a.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
