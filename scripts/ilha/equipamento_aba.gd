extends "res://scripts/ilha/equipamento_tela.gd"
## ADAPTADOR (Bolorina, 20/10): a tela de equipamento do Codex (equipamento_tela.gd, NAO editada) dentro da aba
## "Equipamento" do inventario (scripts/ilha/inventario_tela.gd). Mesma API publica (abrir/fechar/aberta/raiz/sel/
## possui_lista/vestir_sel/tirar_slot/girar/previa/quadros), entao jogo_ilha.equip_tela continua valendo.
## O que o adaptador muda, sem tocar no arquivo original:
## - _selo(): nao cria o selo "I Equipamento" do HUD (o inventario mostra o dele);
## - embutir(pai): move o `raiz` da tela para dentro da aba e esconde o fundo escuro de tela cheia
##   (o inventario ja escurece a tela); o raiz deixa de engolir cliques fora do painel;
## - fechar(): ao trocar de aba o jogo continua pausado (o inventario e quem despausa);
## - _input(): I/B/Esc/Tab/PgUp/PgDn e o controle ficam com o inventario (fechar e trocar de aba).
## Lista do que seria melhor mudar no original (para o Codex) em docs/INVENTARIO_BAU.md.
var inventario  # inventario_tela.gd (dono da pausa)

func _selo() -> void:
	pass

func embutir(pai: Control) -> void:
	if raiz == null:
		return
	if raiz.get_parent():
		raiz.get_parent().remove_child(raiz)
	pai.add_child(raiz)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embutida = true
	raiz.set_anchors_preset(Control.PRESET_TOP_LEFT)
	raiz.size = Vector2(1600,900)
	raiz.scale = Vector2(0.9,0.9)
	raiz.position = Vector2(80,105)
	# Apenas a moldura externa do inventario, sem painel duplicado.
	(raiz.get_child(1) as Panel).add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	raiz.get_child(3).position = Vector2(1300,-39)
	# Cabecalho e rodape pertencem ao inventario nesta aba.
	for child in raiz.get_children():
		if child is Control and (child.position.y == 74 or child.position.y == 798):
			child.hide()
	if raiz.get_child_count() > 0 and raiz.get_child(0) is ColorRect:
		(raiz.get_child(0) as ColorRect).visible = false

func fechar() -> void:
	if not aberta:
		return
	super.fechar()
	if inventario and inventario.aberto:
		get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not aberta:
		return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_I, KEY_B, KEY_ESCAPE, KEY_TAB, KEY_PAGEUP, KEY_PAGEDOWN]:
			return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return
	super._input(event)
