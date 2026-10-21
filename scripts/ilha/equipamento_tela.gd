extends CanvasLayer
signal fechada
## Tela de equipamento (I): previa grande da Vale ao vivo, slots, mochila de pecas, defesa.
## Pausa o jogo enquanto aberta (get_tree().paused); esta camada roda em PROCESS_MODE_ALWAYS.
## Teclado: setas/WASD escolhem | Enter/F veste ou tira | X tira a peca do slot | Q/E giram a previa |
## Espaco anda/para | I/Esc fecha. Mouse: clique na peca veste/tira, clique no slot tira.
const UI = preload("res://scripts/ui/tema_vilarejo.gd")
const Equip = preload("res://scripts/ilha/equipamento.gd")
const Visual = preload("res://scripts/ilha/equipamento_visual.gd")
const PASTA_ICONES := "res://art/ui/icones_equip/"
const DIRS := ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"]
const NOME_DIR := {"south": "sul", "south-west": "sudoeste", "west": "oeste", "north-west": "noroeste", "north": "norte", "north-east": "nordeste", "east": "leste", "south-east": "sudeste"}
const COLS := 8
const CAIXA := 64
const BEGE := Color("f1e2bd")
var g          # gerenciador (jogo_ilha.gd) ou qualquer no com .estado e vestir_atual()
var estado
var aberta := false
var mudou := false
var sel := 0
var dir_i := 0
var andando := true
var quadros: Array[Texture2D] = []
var q_i := 0
var t_ms := 0
var raiz: Control
var previa: TextureRect
var previa_dir: Label
var defesa_label: Label
var slot_caixas := {}
var slot_icones := {}
var slot_nomes := {}
var grade: Array[Panel] = []
var grade_icones: Array = []
var grade_marcas: Array = []
var info_nome: Label
var info_slot: Label
var info_desc: Label
var dica: Label
var selo: Label
static var _icones := {}
var embutida := false
var hospedeiro: Control
var _pausa_antes := false

## Para a aba do inventario: o chamador controla pausa e visibilidade do menu.
## Retorna o Control filho, sem abrir a aba automaticamente nem gravar o estado.
func montar_embutido(gerenciador, host: Control, est = null) -> Control:
	embutida = true
	hospedeiro = host
	montar(gerenciador, est)
	raiz.reparent(host)
	raiz.set_anchors_preset(Control.PRESET_TOP_LEFT)
	raiz.size = Vector2(1600, 900)
	host.resized.connect(_ajustar_aba)
	_ajustar_aba()
	return raiz

func _ajustar_aba() -> void:
	if not is_instance_valid(hospedeiro) or not is_instance_valid(raiz):
		return
	var fator := minf(hospedeiro.size.x / 1600.0, hospedeiro.size.y / 900.0)
	raiz.scale = Vector2.ONE * maxf(0.01, fator)
	raiz.position = (hospedeiro.size - Vector2(1600,900) * raiz.scale) * 0.5

func _exit_tree() -> void:
	if embutida and is_instance_valid(raiz):
		raiz.queue_free()

func montar(gerenciador, est = null) -> void:
	g = gerenciador
	estado = est if est != null else g.estado
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TelaEquipamento"
	if not embutida:
		_selo()
	_construir()
	raiz.visible = false

# ---------------------------------------------------------------- interface
func _estilo(bg: Color, borda: Color, w: int, raio := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = borda
	s.set_border_width_all(w)
	s.set_corner_radius_all(raio)
	return s

func _rotulo(pai: Control, pos: Vector2, tam: int, cor := BEGE, texto := "") -> Label:
	var l := Label.new()
	l.position = pos
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l

static func icone(id: String) -> Texture2D:
	if _icones.has(id):
		return _icones[id]
	var tex: Texture2D = null
	var cam := ProjectSettings.globalize_path(PASTA_ICONES + id + ".png")
	if FileAccess.file_exists(cam):
		var img := Image.load_from_file(cam)
		if img and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_icones[id] = tex
	return tex

func _icone_rect(pai: Control, pos: Vector2, lado: float) -> TextureRect:
	var r := TextureRect.new()
	r.position = pos
	r.size = Vector2(lado, lado)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(r)
	return r

## dica fixa no HUD (canto inferior direito, acima da barra de mensagens)
func _selo() -> void:
	var p := Panel.new()
	p.name = "SeloEquipamento"
	p.position = Vector2(1600 - 214, 900 - 63 - 40)
	p.size = Vector2(200, 32)
	p.add_theme_stylebox_override("panel", _estilo(Color(0.16, 0.1, 0.06, 0.85), Color("6b4a2a"), 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var k := Panel.new()
	k.position = Vector2(6, 5)
	k.size = Vector2(22, 22)
	k.add_theme_stylebox_override("panel", _estilo(Color("e8cf98"), Color("fff1b8"), 2, 3))
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(k)
	var kl := _rotulo(k, Vector2(0, 0), 14, Color("3a2412"), "I")
	kl.size = Vector2(22, 22)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kl.add_theme_constant_override("shadow_offset_x", 0)
	kl.add_theme_constant_override("shadow_offset_y", 0)
	selo = _rotulo(p, Vector2(36, 6), 14, BEGE, "Equipamento")

func _construir() -> void:
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.theme = UI.tema()
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UI.aplicar_fundo(fundo)
	raiz.add_child(fundo)
	var pn := Panel.new()
	pn.position=Vector2(86,115);pn.size=Vector2(1428,680)
	pn.add_theme_stylebox_override("panel",UI.caixa("moldura"))
	pn.mouse_filter=Control.MOUSE_FILTER_IGNORE
	raiz.add_child(pn)
	UI.cabecalho(raiz,"EQUIPAMENTO",Vector2(106,74),Vector2(480,80),UI.textura("mochila.svg"))
	var defesa := Panel.new()
	defesa.position=Vector2(1224,82);defesa.size=Vector2(270,68)
	defesa.add_theme_stylebox_override("panel",UI.caixa("madeira"))
	raiz.add_child(defesa)
	defesa_label=UI.rotulo(defesa,"",Vector2(18,22),20,true)
	defesa_label.size=Vector2(234,32)
	defesa_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var pv:=Panel.new()
	pv.position=Vector2(24,54);pv.size=Vector2(360,564)
	pv.add_theme_stylebox_override("panel",UI.caixa("painel"))
	pn.add_child(pv)
	var fundo_previa:=TextureRect.new()
	fundo_previa.position=Vector2(10,10);fundo_previa.size=Vector2(340,466)
	fundo_previa.texture=UI.textura("clareira.png")
	fundo_previa.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	fundo_previa.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo_previa.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pv.add_child(fundo_previa)
	previa=TextureRect.new()
	previa.position=Vector2(20,132);previa.size=Vector2(320,320)
	previa.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	previa.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	previa.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	previa.mouse_filter=Control.MOUSE_FILTER_IGNORE
	pv.add_child(previa)
	var tag:=Panel.new();tag.position=Vector2(10,10);tag.size=Vector2(116,42)
	tag.add_theme_stylebox_override("panel",UI.caixa("botao",8));pv.add_child(tag)
	UI.rotulo(tag,String(estado.extras.get("aparencia",{}).get("nome","Vale")).left(10).to_upper(),Vector2(15,9),18,true)
	previa_dir=UI.rotulo(pv,"",Vector2(12,493),16)
	previa_dir.size=Vector2(336,56);previa_dir.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for lado in [-1,1]:
		var button:=Button.new();button.text="◀" if lado<0 else "▶"
		button.position=Vector2(16 if lado<0 else 298,260);button.size=Vector2(46,50)
		button.add_theme_stylebox_override("normal",UI.caixa("botao_ativo",8))
		button.add_theme_color_override("font_color",Color("322319"))
		button.focus_mode=Control.FOCUS_NONE
		button.pressed.connect(girar.bind(lado));pv.add_child(button)
	UI.rotulo(pn,"VESTINDO",Vector2(410,60),20,true)
	for i in Equip.SLOTS.size():
		var slot:String=Equip.SLOTS[i]
		var y:=100+(i%4)*118
		var x:=410+(i/4)*184
		var card:=Panel.new();card.position=Vector2(x,y);card.size=Vector2(72,72)
		card.mouse_filter=Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_clique_slot.bind(slot));card.tooltip_text="Clique para retirar"
		card.add_theme_stylebox_override("panel",UI.caixa("slot",6))
		pn.add_child(card);slot_caixas[slot]=card
		slot_icones[slot]=_icone_rect(card,Vector2(8,8),56)
		UI.rotulo(pn,String(Equip.NOME_SLOT[slot]).to_upper(),Vector2(x,y+78),14)
		var name:=UI.rotulo(pn,"",Vector2(x+80,y+5),16)
		name.size=Vector2(96,68);name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		slot_nomes[slot]=name
	UI.rotulo(pn,"MOCHILA DE ROUPAS",Vector2(786,60),20,true)
	var items:=_lista()
	for i in items.size():
		var card:=Panel.new()
		card.position=Vector2(786+(i%COLS)*74,100+(i/COLS)*74)
		card.size=Vector2(CAIXA,CAIXA)
		card.mouse_filter=Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_clique_item.bind(i));card.mouse_entered.connect(_sobre.bind(i))
		card.add_theme_stylebox_override("panel",UI.caixa("slot",5))
		pn.add_child(card);grade.append(card)
		grade_icones.append(_icone_rect(card,Vector2(8,8),48))
		var mark:=Panel.new();mark.position=Vector2(47,-4);mark.size=Vector2(22,22)
		var badge:=StyleBoxFlat.new();badge.bg_color=Color("6ca34a");badge.set_corner_radius_all(11)
		badge.border_color=Color("d8ecad");badge.set_border_width_all(2)
		mark.add_theme_stylebox_override("panel",badge);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var arrow:=UI.rotulo(mark,"↑",Vector2(4,0),18,true);arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(mark);grade_marcas.append(mark)
	var inf:=Panel.new();inf.position=Vector2(786,350);inf.size=Vector2(612,268)
	inf.add_theme_stylebox_override("panel",UI.caixa("painel",18));pn.add_child(inf)
	info_nome=UI.rotulo(inf,"",Vector2(22,22),27,true)
	info_nome.size=Vector2(564,40)
	info_nome.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	info_slot=UI.rotulo(inf,"",Vector2(22,76),18)
	info_slot.size=Vector2(568,50);info_slot.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	info_desc=UI.rotulo(inf,"",Vector2(22,139),19)
	info_desc.size=Vector2(562,106);info_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dica=UI.rotulo(pn,"Escolha uma peça para comparar os atributos.",Vector2(410,636),16)
	UI.rodape(raiz,Vector2(104,798),[["W A S D","Escolher"],["Enter / F","Equipar"],["X","Retirar"],["Q / E","Girar"],["Espaço","Animar"],["Esc","Fechar"]],1392)

func _lista() -> Array:
	var out: Array = []
	for s in Equip.SLOTS:
		for id in Equip.INICIAIS + Equip.ITENS.keys():
			if String(Equip.ITENS[id].slot) == s and not out.has(id):
				out.append(id)
	return out

## pecas que a Vale tem, na ordem do catalogo
func possui_lista() -> Array:
	var out: Array = []
	for id in _lista():
		if estado.equipamento.possui.has(id):
			out.append(id)
	return out

# ---------------------------------------------------------------- abrir / fechar
func abrir() -> void:
	if aberta:
		return
	aberta = true
	mudou = false
	raiz.visible = true
	if not embutida:
		_pausa_antes = get_tree().paused
		get_tree().paused = true
	sel = clampi(sel, 0, maxi(0, possui_lista().size() - 1))
	t_ms = Time.get_ticks_msec()
	atualizar()

func fechar() -> void:
	if not aberta:
		return
	aberta = false
	raiz.visible = false
	if not embutida:
		get_tree().paused = _pausa_antes
	if mudou and estado.has_method("salvar"):
		estado.salvar()
	fechada.emit()

func alternar() -> void:
	if aberta:
		fechar()
	else:
		abrir()

# ---------------------------------------------------------------- acoes
func vestir_sel() -> bool:
	var lista := possui_lista()
	if sel < 0 or sel >= lista.size():
		return false
	var ok := Equip.alternar(estado.equipamento, String(lista[sel]))
	if ok:
		_aplicar()
	return ok

func tirar_slot(slot: String) -> bool:
	var ok := Equip.desequipar(estado.equipamento, slot)
	if ok:
		_aplicar()
	return ok

func _aplicar() -> void:
	mudou = true
	if estado.has_method("salvar"):
		estado.salvar()
	if g and g.has_method("vestir_atual"):
		g.vestir_atual()
	atualizar()

func girar(lado: int) -> void:
	dir_i = posmod(dir_i + lado, DIRS.size())
	_carregar_previa()

func _clique_item(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		sel = i
		vestir_sel()

func _clique_slot(ev: InputEvent, slot: String) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tirar_slot(slot)

func _sobre(i: int) -> void:
	if sel != i:
		sel = i
		atualizar()

func _input(event: InputEvent) -> void:
	if not aberta or not raiz.is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed:
		var k: int = event.physical_keycode
		var eco: bool = event.echo
		var n := possui_lista().size()
		match k:
			KEY_I, KEY_ESCAPE:
				if not eco:
					fechar()
			KEY_LEFT, KEY_A:
				sel = posmod(sel - 1, maxi(1, n))
				atualizar()
			KEY_RIGHT, KEY_D:
				sel = posmod(sel + 1, maxi(1, n))
				atualizar()
			KEY_UP, KEY_W:
				sel = sel - COLS if sel - COLS >= 0 else sel
				atualizar()
			KEY_DOWN, KEY_S:
				sel = sel + COLS if sel + COLS < n else sel
				atualizar()
			KEY_ENTER, KEY_KP_ENTER, KEY_F:
				if not eco:
					vestir_sel()
			KEY_X, KEY_BACKSPACE:
				if not eco:
					var lista := possui_lista()
					if sel < lista.size():
						tirar_slot(String(Equip.ITENS[lista[sel]].slot))
			KEY_Q:
				girar(-1)
			KEY_E:
				girar(1)
			KEY_SPACE:
				if not eco:
					andando = not andando
					_carregar_previa()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- estado visual
func _carregar_previa() -> void:
	var cam: Array = Equip.camadas(estado.equipamento)
	var d: String = DIRS[dir_i]
	quadros = Visual.quadros_previa(cam, ("run_" if andando else "idle_") + d, estado.extras.get("aparencia", {}))
	q_i = q_i % maxi(1, quadros.size())
	previa.texture = quadros[q_i] if not quadros.is_empty() else null
	previa_dir.text = "Olhando para o %s · %s\nQ/E girar · Espaço %s" % [NOME_DIR[d], "andando" if andando else "parada", "parar" if andando else "andar"]

func atualizar() -> void:
	var eq: Dictionary = estado.equipamento
	var lista := possui_lista()
	sel = clampi(sel, 0, maxi(0, lista.size() - 1))
	defesa_label.text = "DEFESA TOTAL  %d" % Equip.defesa(eq)
	for s in Equip.SLOTS:
		var id := Equip.equipado(eq, s)
		slot_icones[s].texture = icone(id) if id != "" else null
		slot_nomes[s].text = (String(Equip.ITENS[id].nome) + ("\nDEF +%d" % int(Equip.ITENS[id].defesa) if int(Equip.ITENS[id].defesa) > 0 else "")) if id != "" else "— vazio —"
		var destaque: bool = lista.size() > 0 and sel < lista.size() and String(Equip.ITENS[lista[sel]].slot) == s
		slot_caixas[s].add_theme_stylebox_override("panel", UI.caixa("slot_selecionado" if destaque else "slot",6))
	for i in grade.size():
		var tem := i < lista.size()
		grade[i].visible = tem
		if not tem:
			continue
		var id: String = lista[i]
		grade_icones[i].texture = icone(id)
		var vest := Equip.esta_equipado(eq, id)
		grade_marcas[i].visible = vest
		var e_sel := i == sel
		grade[i].add_theme_stylebox_override("panel", UI.caixa("slot_selecionado" if e_sel else ("slot_vestido" if vest else "slot"),5))
		grade[i].tooltip_text = String(Equip.ITENS[id].nome)
	if sel < lista.size():
		var id: String = lista[sel]
		var it: Dictionary = Equip.ITENS[id]
		var vest := Equip.esta_equipado(eq, id)
		var d0 := Equip.defesa(eq)
		var d1 := Equip.defesa_com(eq, id)
		var dif := d1 - d0
		info_nome.text = String(it.nome) + ("   (vestido)" if vest else "")
		info_slot.text = "%s  ·  Defesa +%d  ·  %s %s" % [String(Equip.NOME_SLOT[it.slot]), int(it.defesa), "Tirar:" if vest else "Vestir:", ("defesa %d → %d" % [d0, d1]) if dif != 0 else "defesa igual"]
		info_slot.add_theme_color_override("font_color", Color("8fd86a") if dif > 0 else (Color("e58a6a") if dif < 0 else Color("cbb48a")))
		info_desc.text = String(it.desc)
	_carregar_previa()

func _process(_delta: float) -> void:
	if not aberta or quadros.is_empty():
		return
	var agora := Time.get_ticks_msec()
	var passo := 111 if andando else 400
	if agora - t_ms >= passo:
		t_ms = agora
		q_i = (q_i + 1) % quadros.size()
		previa.texture = quadros[q_i]

## fundo da previa: grama e sombra de contato (desenho por codigo, pixelado)
class Previa extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("3c5a3a"))
		for i in 40:
			var x := float((i * 73) % int(size.x))
			var y := 250.0 + float((i * 37) % 140)
			draw_rect(Rect2(x, y, 4, 4), Color("4f7448"))
		draw_rect(Rect2(0, 0, size.x, 230), Color("2f4a5c"))
		draw_rect(Rect2(0, 226, size.x, 6), Color("2a4026"))
		var c := Vector2(size.x * 0.5, 342)
		for k in 3:
			var w := 120.0 - k * 26.0
			draw_rect(Rect2(c.x - w * 0.5, c.y - 8 + k * 4, w, 12 - k * 4), Color(0, 0, 0, 0.18))
