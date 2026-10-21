extends SceneTree
## Bolorina 21/10: captura da arena (orcs + Vale) para comparar com a masmorra.
## godot --path . -s res://tests/consistencia_captura.gd -- <pasta> [prefixo]
var pasta := "/tmp/cons"
var pref := "arena"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: pasta = a[0]
	if a.size() > 1: pref = a[1]
	DirAccess.make_dir_recursive_absolute(pasta)
	call_deferred("run")
func fis(n: int) -> void:
	for i in n: await physics_frame
func salvar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(pasta.path_join(pref + "_" + nome + ".png"))
	print("CAPTURA ", nome)
func run() -> void:
	root.size = Vector2i(1600, 900)
	var a = load("res://combat_arena.tscn").instantiate()
	a.modo_teste = true
	root.add_child(a)
	await fis(20)
	var j = a.jogador
	a.hitstop_ativo = false
	j.invulneravel_ate = 1e9
	a.gerar_onda(0)
	await fis(90)
	await salvar("inicio")
	var alvo = null
	for e in a.inimigos:
		if is_instance_valid(e) and e.vivo: alvo = e; break
	if alvo:
		for e in a.inimigos:
			if is_instance_valid(e) and e.has_method("acordar"): e.acordar()
		j.global_position = alvo.global_position + Vector3(2.4, 0, 2.4)
		for i in 60:
			await physics_frame
			if i == 40: j.pedir_ataque(alvo.global_position - j.global_position)
	await salvar("combate")
	quit(0)
