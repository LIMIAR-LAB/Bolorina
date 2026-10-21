extends SceneTree
const Partidas=preload("res://scripts/inicio/partidas.gd")
const Aparencia=preload("res://scripts/avatar/aparencia.gd")
const Estado=preload("res://scripts/ilha/fazenda_estado.gd")
const Visual=preload("res://scripts/ilha/equipamento_visual.gd")
var checks:=0
var falhas:=0
var criados: Array[String]=[]
var real_md5:=""
func _init():call_deferred("run")
func check(ok: bool, nome: String):
	checks+=1
	if not ok:falhas+=1
	print(("PASS " if ok else "FAIL ")+nome)
func frames(n: int):
	for i in n:await process_frame
func foto(nome: String):
	if DisplayServer.get_name()=="headless":return
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/avatar/"+nome+".png"))
func run():
	create_timer(180).timeout.connect(func():print("FAIL timeout");quit(2))
	real_md5=FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/avatar"))
	var cfg_path:="user://config_inicio_teste.cfg"
	Partidas.aplicar_config({"volume":0.37,"tela_cheia":false,"vsync":false},true,cfg_path)
	var cfg:=Partidas.carregar_config(cfg_path)
	check(is_equal_approx(cfg.volume,0.37),"volume persistido")
	check(not cfg.tela_cheia and not cfg.vsync,"opcoes de video persistidas")
	DirAccess.remove_absolute(cfg_path)
	var menu=load("res://inicio.tscn").instantiate();root.add_child(menu);current_scene=menu
	await frames(4)
	check(menu.tela=="principal","menu inicial pronto")
	await foto("inicio")
	menu.configuracoes();await frames(2)
	check(menu.tela=="configuracoes","configuracoes abre")
	await foto("configuracoes")
	menu.carregar();await frames(2)
	check(menu.tela=="carregar","lista de partidas abre")
	await foto("carregar")
	menu.novo_jogo();await frames(2)
	check(menu.previa.texture!=null and menu.quadros.size()==8,"criador mostra corrida real")
	menu.cor("cabelo","aeb5bf");menu.cor("camisa","9b493c")
	check(menu.perfil.cores.cabelo=="aeb5bf","paleta alterada no perfil")
	var img0=menu.previa.texture.get_image().get_data()
	menu.cor("cabelo","b77b38")
	check(menu.previa.texture.get_image().get_data()!=img0,"paleta altera os pixels da previa")
	menu.girar(1);check(menu.dir_i==1,"previa gira")
	menu.alternar_animacao();check(menu.quadros.size()==1,"previa parada")
	menu.alternar_animacao();menu.girar(-1)
	menu.equipamento_previa=1;menu.atualizar_previa()
	check(menu.quadros.size()==8,"previa usa armadura durante corrida")
	await foto("criador-armadura")
	menu.equipamento_previa=0;menu.atualizar_previa()
	await foto("criador")
	menu.perfil.nome=""
	menu.comecar();check(not menu.entrando and menu.mensagem.text!="","impede nome vazio")
	menu.perfil.nome="Aurora";menu.perfil.fazenda="Fazenda das Cinzas"
	var path1:=Partidas.criar(menu.perfil);criados.append(path1)
	var path2:=Partidas.criar(menu.perfil);criados.append(path2)
	check(path1!="" and path2!="" and path1!=path2,"novos jogos nao sobrescrevem a mesma partida")
	var dados=JSON.parse_string(FileAccess.get_file_as_string(path1))
	check(dados.extras.aparencia.nome=="Aurora" and dados.extras.aparencia.fazenda=="Fazenda das Cinzas","nome e fazenda salvos")
	check(Partidas.listar().any(func(p):return p.arquivo==path1),"partida aparece no carregar")
	menu.iniciar_partida(path1)
	await frames(10)
	var jogo=current_scene
	for i in 600:
		await process_frame
		if jogo.atual and not jogo.ocupado:break
	check(jogo.nome=="fazenda" and jogo.atual!=null,"carregar entra na fazenda")
	check(jogo.estado.extras.aparencia.nome=="Aurora","jogo recebe personagem criado")
	check(jogo.atual.sprite.get_meta("avatar_perfil").cores.cabelo=="b77b38","aparencia aplicada no mundo")
	check(jogo.estado.equipamento.equipado.cabeca=="","equipamento da previa nao e concedido")
	jogo.ir("arena","da_vila")
	for i in 600:
		await process_frame
		if jogo.nome=="arena" and not jogo.ocupado:break
	check(jogo.atual.jogador.sprite.get_meta("avatar_perfil").cores.cabelo=="b77b38","mesma aparencia no combate")
	jogo.estado.ouro=123;jogo.estado.salvar()
	var salvo=Estado.new();salvo.arquivo=path1
	check(salvo.carregar() and salvo.ouro==123 and salvo.extras.aparencia.nome=="Aurora","progresso e personagem voltam do save")
	check(salvo.extras.ultima_area=="arena","destino persistido para continuar")
	var ev:=InputEventKey.new();ev.physical_keycode=KEY_ESCAPE;ev.pressed=true
	jogo._unhandled_key_input(ev);await frames(2)
	check(paused,"Esc pausa o jogo")
	var pausa=jogo.get_children().filter(func(n):return n.get_script()==load("res://scripts/inicio/menu_inicial.gd"))
	check(pausa.size()==1,"menu de pausa criado")
	if pausa.size():pausa[0].retomar()
	await frames(2);check(not paused,"continuar retoma o jogo")
	jogo._unhandled_key_input(ev)
	await frames(2)
	pausa=jogo.get_children().filter(func(n):return n.get_script()==load("res://scripts/inicio/menu_inicial.gd"))
	if pausa.size():pausa[0].voltar_inicio()
	await frames(10)
	check(current_scene.get_script()==load("res://scripts/inicio/menu_inicial.gd") and not paused,"salvar e voltar abre o inicio")
	check(FileAccess.file_exists(path1),"partida mantida ao sair para o menu")
	var md5:=FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	check(md5==real_md5,"save original intacto")
	if is_instance_valid(jogo):jogo.queue_free()
	await frames(4)
	for path in criados:
		if path!="":DirAccess.remove_absolute(path)
	print("RESULTADO inicio_personagem: %d/%d" % [checks-falhas,checks])
	quit(1 if falhas else 0)
