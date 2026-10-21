extends CanvasLayer
const UI = preload("res://scripts/ui/tema_vilarejo.gd")
const Partidas = preload("res://scripts/inicio/partidas.gd")
const Aparencia = preload("res://scripts/avatar/aparencia.gd")
const Visual = preload("res://scripts/ilha/equipamento_visual.gd")
const DIRS := ["south","south-west","west","north-west","north","north-east","east","south-east"]
const CORES := {
	"pele":["e7b382","f4c99e","dba17c","be8059","9b6347","754832","50352d"],
	"cabelo":["432c27","75482d","b77b38","e6c77e","943f2b","aeb5bf","4d486e","dfb6c7"],
	"camisa":["3e8275","476b9b","9b493c","74618c","aa8b47","677d3c","bc7893","d1c6ae"],
	"calca":["3c3a45","3d536e","695849","8d805b","475644","785759"]}
var raiz: Control
var pagina: Control
var perfil := Aparencia.novo()
var previa: TextureRect
var nome_campo: LineEdit
var fazenda_campo: LineEdit
var quadros: Array[Texture2D] = []
var dir_i := 0
var andando := true
var equipamento_previa := 0
var quadro := 0
var relogio := 0.0
var tela := "principal"
var mensagem: Label
var gerenciador: Node
var entrando := false
var config := {}
var paletas := {}
var previa_tipo: OptionButton

func _ready() -> void:
	layer=100
	process_mode=Node.PROCESS_MODE_ALWAYS
	config=Partidas.carregar_config()
	if gerenciador == null:
		DisplayServer.window_set_title("Ilha das Cinzas | Início")
		Partidas.aplicar_config(config,false)
	raiz=Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.theme=UI.tema()
	add_child(raiz)
	var bg:=TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var imagem:=Image.load_from_file(ProjectSettings.globalize_path("res://art/ui/telas/porto_velho.png"))
	var atlas:=AtlasTexture.new()
	atlas.atlas=ImageTexture.create_from_image(imagem)
	# Usa a parte do cenario sem a legenda incorporada na imagem de apresentacao.
	atlas.region=Rect2(0,0,imagem.get_width(),imagem.get_height()*0.78)
	bg.texture=atlas
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(bg)
	var shade:=ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.04,0.05,0.07,0.70)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(shade)
	pagina=Control.new()
	pagina.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(pagina)
	principal()

func limpar(id: String) -> void:
	tela=id
	previa=null
	quadros.clear()
	paletas.clear()
	previa_tipo=null
	for c in pagina.get_children():
		pagina.remove_child(c)
		c.queue_free()

func painel(pos: Vector2, tam: Vector2) -> Panel:
	var p:=Panel.new()
	p.position=pos;p.size=tam
	p.add_theme_stylebox_override("panel",UI.caixa("moldura"))
	pagina.add_child(p)
	return p

func texto(pai: Node, txt: String, pos: Vector2, tam := 22) -> Label:
	return UI.rotulo(pai,txt,pos,tam)

func botao(pai: Node, txt: String, pos: Vector2, tam: Vector2, acao: Callable) -> Button:
	var b:=Button.new()
	b.text=txt;b.position=pos;b.size=tam
	b.pressed.connect(acao)
	pai.add_child(b)
	if tela=="principal" and pos.y==80: b.call_deferred("grab_focus")
	if txt in ["Novo jogo","Começar aventura","Continuar"]:
		b.add_theme_stylebox_override("normal",UI.caixa("botao_ativo",10))
		b.add_theme_color_override("font_color",Color("302317"))
	return b

func principal() -> void:
	limpar("principal")
	UI.rotulo(pagina,"ILHA DAS\nCINZAS",Vector2(110,210),78,true)
	texto(pagina,"Cultive um lar. Explore o que restou.",Vector2(118,430),25)
	var p:=painel(Vector2(1000,190),Vector2(460,530))
	UI.cabecalho(p,"PAUSA" if gerenciador else "BEM-VINDO",Vector2(30,-30),Vector2(400,72))
	var y:=80.0
	if gerenciador:
		botao(p,"Continuar",Vector2(40,y),Vector2(380,60),retomar);y+=76
	else:
		botao(p,"Novo jogo",Vector2(40,y),Vector2(380,60),novo_jogo);y+=76
	var b:=botao(p,"Carregar jogo",Vector2(40,y),Vector2(380,60),carregar)
	b.disabled=Partidas.listar().is_empty() or gerenciador!=null;y+=76
	botao(p,"Configurações",Vector2(40,y),Vector2(380,60),configuracoes);y+=76
	if gerenciador:
		botao(p,"Salvar e voltar ao início",Vector2(40,y),Vector2(380,60),voltar_inicio)
	else:
		botao(p,"Sair",Vector2(40,y),Vector2(380,60),func():get_tree().quit())
	texto(pagina,"Ilha das Cinzas · Protótipo em desenvolvimento",Vector2(116,814),18)

func novo_jogo() -> void:
	perfil=Aparencia.novo()
	perfil.usar_cores=true
	dir_i=0;andando=true;equipamento_previa=0
	criador()

func criador() -> void:
	limpar("criador")
	var p:=painel(Vector2(94,105),Vector2(1412,686))
	UI.cabecalho(pagina,"CRIE SEU PERSONAGEM",Vector2(116,65),Vector2(630,76))
	var bg:=TextureRect.new()
	bg.position=Vector2(28,56);bg.size=Vector2(468,554)
	bg.texture=UI.textura("clareira.png")
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	p.add_child(bg)
	previa=TextureRect.new()
	previa.position=Vector2(84,168);previa.size=Vector2(360,360)
	previa.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	previa.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previa.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(previa)
	botao(p,"◀",Vector2(42,322),Vector2(52,54),func():girar(-1))
	botao(p,"▶",Vector2(428,322),Vector2(52,54),func():girar(1))
	botao(p,"Andar / parar",Vector2(120,622),Vector2(278,42),alternar_animacao)
	texto(p,"Seu nome",Vector2(548,58),20)
	nome_campo=LineEdit.new();nome_campo.position=Vector2(548,90);nome_campo.size=Vector2(356,48)
	nome_campo.max_length=24;nome_campo.text=perfil.nome;p.add_child(nome_campo)
	nome_campo.text_changed.connect(func(v):perfil.nome=v)
	texto(p,"Nome da fazenda",Vector2(940,58),20)
	fazenda_campo=LineEdit.new();fazenda_campo.position=Vector2(940,90);fazenda_campo.size=Vector2(426,48)
	fazenda_campo.max_length=32;fazenda_campo.text=perfil.fazenda;p.add_child(fazenda_campo)
	fazenda_campo.text_changed.connect(func(v):perfil.fazenda=v)
	var labels:={"pele":"Tom de pele","cabelo":"Cor do cabelo","camisa":"Roupa","calca":"Calça"}
	var y:=170.0
	for campo in ["pele","cabelo","camisa","calca"]:
		texto(p,String(labels[campo]),Vector2(548,y),21)
		for i in CORES[campo].size():
			var hex:String=CORES[campo][i]
			var b:=botao(p,"",Vector2(770+i*70,y-5),Vector2(52,46),cor.bind(campo,hex))
			var swatch:=StyleBoxFlat.new();swatch.bg_color=Color(hex)
			swatch.border_color=UI.OURO;swatch.set_border_width_all(2);swatch.set_corner_radius_all(6)
			b.add_theme_stylebox_override("normal",swatch)
			paletas[campo+":"+hex]=b
			b.tooltip_text=String(labels[campo])+" · #"+hex
		y+=78
	texto(p,"Visualizar equipamento",Vector2(548,494),20)
	var op:=OptionButton.new();op.position=Vector2(838,486);op.size=Vector2(422,46)
	for item in ["Sem equipamento","Armadura e elmo de ferro","Armadura de couro e capuz"]:op.add_item(item)
	previa_tipo=op
	op.selected=equipamento_previa
	op.item_selected.connect(func(i):equipamento_previa=i;atualizar_previa())
	p.add_child(op)
	texto(p,"O equipamento acima é apenas uma prévia.\nPenteado base disponível nesta etapa.",Vector2(548,548),18)
	botao(p,"Voltar",Vector2(548,616),Vector2(198,46),principal)
	botao(p,"Começar aventura",Vector2(1000,606),Vector2(366,60),comecar)
	mensagem=texto(pagina,"",Vector2(652,805),19)
	atualizar_previa()

func cor(campo: String, valor: String) -> void:
	perfil.cores[campo]=valor
	atualizar_previa()
func girar(n: int) -> void:
	dir_i=posmod(dir_i+n,8);atualizar_previa()
func alternar_animacao() -> void:
	andando=not andando;atualizar_previa()
func atualizar_previa() -> void:
	if previa_tipo: previa_tipo.selected=equipamento_previa
	for key in paletas:
		var campo:String=key.get_slice(":",0)
		var hex:String=key.get_slice(":",1)
		var b:Button=paletas[key]
		b.text="✓" if perfil.cores[campo]==hex else ""
		b.add_theme_color_override("font_color",Color("151318") if Color(hex).get_luminance()>0.35 else Color.WHITE)
	var camadas: Array=[]
	if equipamento_previa==1:camadas=["malha_guarda","elmo_ferro"]
	if equipamento_previa==2:camadas=["couro_cacador","capuz_couro"]
	quadros=Visual.quadros_previa(camadas,("run_" if andando else "idle_")+DIRS[dir_i],perfil)
	quadro=0;relogio=0
	if previa and not quadros.is_empty():previa.texture=quadros[0]
func _process(delta: float) -> void:
	if previa and quadros.size()>1:
		relogio+=delta
		if relogio>=0.12:
			relogio=fmod(relogio,0.12);quadro=(quadro+1)%quadros.size();previa.texture=quadros[quadro]
func comecar() -> void:
	if entrando:return
	if perfil.nome.strip_edges().is_empty() or perfil.fazenda.strip_edges().is_empty():
		mensagem.text="Preencha o nome do personagem e da fazenda."
		return
	var path:=Partidas.criar(perfil)
	if path.is_empty():
		mensagem.text="Não foi possível salvar a nova partida. Tente novamente."
		return
	iniciar_partida(path)
func iniciar_partida(path: String) -> void:
	if entrando:return
	entrando=true
	OS.set_environment("ILHA_SAVE",path)
	OS.set_environment("ILHA_AREA","")
	OS.set_environment("ILHA_SPAWN","")
	get_tree().paused=false
	get_tree().change_scene_to_file("res://jogo_ilha.tscn")

func carregar() -> void:
	limpar("carregar")
	painel(Vector2(180,110),Vector2(1240,684))
	UI.cabecalho(pagina,"CARREGAR JOGO",Vector2(204,66),Vector2(560,76))
	var scroll:=ScrollContainer.new();scroll.position=Vector2(216,172);scroll.size=Vector2(1168,520)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;pagina.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",18);scroll.add_child(list)
	for partida in Partidas.listar():
		var b:=Button.new()
		b.text="%s · %s\nDia %d · %d ouro · %s" % [partida.nome,partida.fazenda,partida.dia,partida.ouro,partida.area.replace("_"," ").capitalize()]
		if partida.arquivo=="user://ilha_fazenda_v1.json":b.text+=" · Save anterior"
		if partida.arquivo=="user://ilha_interface_preview.json":b.text+=" · Cópia de testes"
		b.custom_minimum_size=Vector2(1120,92)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(iniciar_partida.bind(String(partida.arquivo)))
		list.add_child(b)
	if list.get_child_count()==0:texto(pagina,"Nenhuma partida salva ainda.",Vector2(236,200))
	botao(pagina,"Voltar",Vector2(216,720),Vector2(230,48),principal)

func configuracoes() -> void:
	limpar("configuracoes")
	var p:=painel(Vector2(330,145),Vector2(940,610))
	UI.cabecalho(pagina,"CONFIGURAÇÕES",Vector2(354,100),Vector2(560,76))
	texto(p,"Volume geral",Vector2(42,96),24)
	var volume:=HSlider.new();volume.position=Vector2(340,96);volume.size=Vector2(492,42)
	volume.min_value=0;volume.max_value=100;volume.step=1;volume.value=float(config.volume)*100
	p.add_child(volume)
	volume.value_changed.connect(func(v):config.volume=v/100.0;Partidas.aplicar_config(config))
	var fullscreen:=CheckButton.new();fullscreen.text="Tela cheia";fullscreen.position=Vector2(42,188)
	fullscreen.button_pressed=config.tela_cheia;p.add_child(fullscreen)
	fullscreen.toggled.connect(func(v):config.tela_cheia=v;Partidas.aplicar_config(config))
	var vsync:=CheckButton.new();vsync.text="Sincronização vertical";vsync.position=Vector2(42,262)
	vsync.button_pressed=config.vsync;p.add_child(vsync)
	vsync.toggled.connect(func(v):config.vsync=v;Partidas.aplicar_config(config))
	texto(p,"WASD: mover · Shift: correr · E: interagir\nI/B: inventário · M: mapa · Esc: pausa",Vector2(42,370),21)
	texto(p,"As configurações são salvas automaticamente.",Vector2(42,458),18)
	botao(p,"Voltar",Vector2(42,520),Vector2(230,48),principal)
func retomar() -> void:
	get_tree().paused=false
	queue_free()
func voltar_inicio() -> void:
	if gerenciador and not gerenciador.estado.salvar():return
	get_tree().paused=false
	get_tree().change_scene_to_file("res://inicio.tscn")
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		if tela!="principal":principal()
		elif gerenciador:retomar()
		get_viewport().set_input_as_handled()
