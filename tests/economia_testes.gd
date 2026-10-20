extends SceneTree
## Economia da noite: itens, lojas (comprar/vender/estoque), servicos, forja (fundir/forjar), conjuntos da forja
## no equipamento, Porto Velho provisorio com 20 NPCs no jogo e minerio com picareta.
## Save de teste (user://ilha_economia_teste.json); o save real nao e tocado.
const Itens = preload("res://scripts/economia/itens.gd")
const Loja = preload("res://scripts/economia/loja.gd")
const Servicos = preload("res://scripts/economia/servicos.gd")
const Forja = preload("res://scripts/economia/forja.gd")
const Equip = preload("res://scripts/ilha/equipamento.gd")
const Visual = preload("res://scripts/ilha/equipamento_visual.gd")
const Estado = preload("res://scripts/ilha/fazenda_estado.gd")
const SAVE := "user://ilha_economia_teste.json"
var checks := 0
var failures := 0
var jogo

func check(ok: bool, t: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + t)

func _init() -> void:
	call_deferred("_run")

func fr(n: int) -> void:
	for i in n:
		await process_frame

func esperar_area(id: String) -> bool:
	for i in 600:
		await process_frame
		if jogo.nome == id and not jogo.ocupado and jogo.atual != null:
			return true
	return false

func estado_novo():
	var e = Estado.new()
	e.arquivo = SAVE
	e.gravar = false
	e.reiniciar()
	return e

func _run() -> void:
	create_timer(400.0).timeout.connect(func():
		print("FAIL tempo esgotado")
		quit(2))
	# ------------------------------------------------ dados
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/porto_velho.json"))
	var npcs: Array = roster.npcs
	var lojas_ok := true
	var papeis := {}
	for n in npcs:
		lojas_ok = lojas_ok and Loja.existe(String(n.loja))
		papeis[String(n.papel)] = true
	check(npcs.size() >= 20 and papeis.size() >= 20, "Porto Velho: %d NPCs com %d papeis diferentes" % [npcs.size(), papeis.size()])
	check(lojas_ok, "cada NPC tem uma loja/servico em data/lojas/")
	var itens_ok := true
	var ruins: Array = []
	for lid in Loja.ids():
		for c in Loja.dados(lid).get("compra", []):
			if not Itens.existe(String(c.item)):
				itens_ok = false
				ruins.append(String(c.item))
	for r in Forja.receitas():
		for m in r.materiais:
			if not Itens.existe(String(m.id)):
				itens_ok = false
				ruins.append(String(m.id))
		if not Itens.existe(String(r.resultado)):
			itens_ok = false
			ruins.append(String(r.resultado))
	check(itens_ok, "todo item das lojas e receitas existe no catalogo %s" % str(ruins))
	check(Itens.icone("pocao_vida") != null and Itens.icone("capacete_cobre") != null and Itens.icone("xyz_inexistente") != null, "icone com fallback para qualquer item")
	# ------------------------------------------------ loja
	var e = estado_novo()
	e.ouro = 100
	check(Loja.comprar(e, "ervas", "pocao_vida") == "" and e.qtd("pocao_vida") == 1 and e.ouro == 60, "compra pocao de vida (40)")
	var est0: int = Loja.estoque(e, "ervas", "pocao_vida")
	check(est0 == 9, "estoque diminui (%d)" % est0)
	e.ouro = 10
	check(Loja.comprar(e, "ervas", "pocao_vida") != "" and e.ouro == 10, "sem ouro nao compra")
	e.somar("nabo", 4)
	var pv: int = Loja.preco_venda("mercado", "nabo")
	check(Loja.vender(e, "mercado", "nabo", 1) == "" and e.ouro == 10 + pv and e.qtd("nabo") == 3, "vende nabo no mercado (%d)" % pv)
	check(Loja.vender(e, "forja", "nabo", 1) != "", "a forja nao compra nabo")
	var ganho: int = Loja.vender_tudo(e, "mercado")
	check(ganho == 3 * pv + Loja.preco_venda("mercado", "pocao_vida") and e.qtd("nabo") == 0 and e.qtd("pocao_vida") == 0, "vender tudo: nabos e a pocao (+%d)" % ganho)
	e.ouro = 1000
	for i in 10:
		Loja.comprar(e, "ervas", "pocao_energia")
	check(Loja.comprar(e, "ervas", "pocao_energia").contains("estoque"), "estoque acaba no dia")
	e.novo_dia()
	check(Loja.estoque(e, "ervas", "pocao_energia") == 10, "estoque volta no dia seguinte")
	# ------------------------------------------------ forja
	e = estado_novo()
	e.ouro = 2000
	check(Forja.fazer(e, "fundir_cobre") != "", "sem minerio nao funde")
	e.somar("minerio_cobre", 9)
	e.somar("carvao", 3)
	check(Forja.fazer(e, "fundir_cobre") == "" and e.qtd("lingote_cobre") == 1 and e.qtd("minerio_cobre") == 6 and e.qtd("carvao") == 2, "funde 3 minerios + 1 carvao em 1 lingote de cobre")
	Forja.fazer(e, "fundir_cobre")
	Forja.fazer(e, "fundir_cobre")
	check(e.qtd("lingote_cobre") == 3, "3 lingotes de cobre")
	var ouro0: int = e.ouro
	check(Forja.fazer(e, "forjar_capacete_cobre") == "" and e.equipamento.possui.has("capacete_cobre") and e.ouro == ouro0 - int(Forja.receita("forjar_capacete_cobre").ouro), "forja o capacete de cobre (vai para a mochila de roupas)")
	check(Forja.fazer(e, "forjar_capacete_cobre").contains("já tem"), "nao forja a mesma peca duas vezes")
	e.somar("lingote_ferro", 10)
	check(Forja.fazer(e, "forjar_peito_ferro").contains("nível"), "ferro pede forja nivel 2")
	e.somar("lingote_cobre", 20)
	for p in ["luvas", "botas"]:
		Forja.fazer(e, "forjar_%s_cobre" % p)
	check(Forja.nivel(e) == 2 and Forja.fazer(e, "forjar_peito_ferro") == "", "3 pecas forjadas sobem a forja para nivel 2 e o ferro libera")
	# ------------------------------------------------ conjuntos no equipamento
	var eq: Dictionary = e.equipamento
	for p in ["peito_cobre", "botas_cobre", "escudo_cobre", "espada_cobre"]:
		Equip.ganhar(eq, p)
	for p in ["capacete_cobre", "peito_cobre", "luvas_cobre", "botas_cobre", "escudo_cobre", "espada_cobre"]:
		Equip.equipar(eq, p)
	var cam: Array = Equip.camadas(eq)
	check(cam == ["botas_cobre", "peito_cobre", "luvas_cobre", "capacete_cobre"], "conjunto de cobre: camadas pes -> corpo -> maos -> cabeca (%s)" % str(cam))
	check(Equip.defesa(eq) == 2 + 3 + 1 + 1 + 2 and Equip.ataque(eq) == 3, "defesa %d e ataque %d do conjunto" % [Equip.defesa(eq), Equip.ataque(eq)])
	var vis_ok := true
	for m in ["cobre", "ferro", "prata"]:
		for p in ["capacete", "peito", "luvas", "botas"]:
			vis_ok = vis_ok and Visual.existe("%s_%s" % [p, m])
	check(vis_ok, "camadas dos 3 conjuntos no indice do paper-doll")
	var t: Texture2D = Visual.quadro_vila(cam, "run/east/003.png")
	var b: Texture2D = Visual.quadro_vila([], "run/east/003.png")
	check(t is ImageTexture and t.get_image().get_data() != b.get_image().get_data(), "conjunto muda a Vale num quadro de corrida")
	# ------------------------------------------------ servicos
	e = estado_novo()
	e.ouro = 1000
	e.energia = 10
	check(Servicos.executar(e, null, "estalagem", "descansar").contains("Energia cheia") and e.energia == e.ENERGIA_MAX and e.ouro == 960, "estalagem: descansar recupera energia (40 ouro)")
	check(Servicos.executar(e, null, "estalagem", "boato") != "" and e.ouro == 945, "estalagem: boato")
	var msg: String = Servicos.executar(e, null, "guarda", "missao")
	check(msg.begins_with("Nova missão") and e.extras.has("missao"), "guardia da missao (%s)" % msg)
	check(Servicos.executar(e, null, "guarda", "entregar_missao").begins_with("Ainda falta"), "missao sem os itens nao conclui")
	e.somar(String(e.extras.missao.item), int(e.extras.missao.qtd))
	var o1: int = e.ouro
	check(Servicos.executar(e, null, "guarda", "entregar_missao").begins_with("Missão cumprida") and e.ouro > o1 and e.qtd("insignia_guarda") == 1, "missao cumprida da ouro e insignia")
	Servicos.executar(e, null, "banco", "depositar")
	e.novo_dia()
	e.novo_dia()
	var antes: int = e.ouro
	Servicos.executar(e, null, "banco", "sacar")
	check(e.ouro - antes == 102, "banco: 100 depositados rendem 1%% ao dia (sacou %d)" % (e.ouro - antes))
	check(Servicos.executar(e, null, "mensageria", "pegar_entrega").contains("Marina") and e.qtd("carta_entrega") == 1, "Nina da a carta")
	check(Servicos.executar(e, null, "mensageria", "concluir_entrega").contains("ainda não chegou"), "sem entregar nao paga")
	check(Servicos.ao_falar(e, "marina") != "" and e.qtd("carta_entrega") == 0, "falar com a Capita Marina entrega a carta")
	var o2: int = e.ouro
	check(Servicos.executar(e, null, "mensageria", "concluir_entrega").begins_with("Obrigada") and e.ouro == o2 + 60, "entrega concluida: +60")
	Equip.equipar(e.equipamento, "peitoral_adamantium")
	var d0: int = Equip.defesa(e.equipamento)
	Servicos.executar(e, null, "torre_ozorio", "encantar")
	check(Equip.defesa(e.equipamento) == d0 + 1, "Arquimago encanta a peca do corpo (+1 DEF)")
	var n: Dictionary = Equip.normalizar(JSON.parse_string(JSON.stringify(e.equipamento)))
	check(int(n.get("encantos", {}).get("peitoral_adamantium", 0)) == 1, "encanto sobrevive ao save")
	check(Servicos.executar(e, null, "biblioteca", "ler_codex").begins_with("Página 1") and Servicos.executar(e, null, "biblioteca", "ler_codex").begins_with("Página 2"), "codex vira a pagina")
	var dia0: int = e.dia
	Servicos.executar(e, null, "sino", "pular_dia")
	check(e.dia == dia0 + 1, "sineiro: tocar o sino pula o dia")
	e.somar("peixe_carpa", 1)
	var r1: String = Servicos.executar(e, null, "dragao", "presente_dragao")
	check(r1.begins_with("Fagulha engole") and e.qtd("peixe_carpa") == 0, "dragao aceita peixe (%s)" % r1)
	check(Servicos.executar(e, null, "dragao", "presente_dragao").contains("amanhã"), "dragao: uma vez por dia")
	# ------------------------------------------------ jogo: Porto Velho provisorio + minerio
	var v_ilha := FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else ""
	OS.set_environment("ILHA_SAVE", SAVE)
	OS.set_environment("ILHA_SEM_SAVE", "")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	OS.set_environment("ILHA_AREA", "porto_velho")
	OS.set_environment("ILHA_SPAWN", "padrao")
	jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	check(await esperar_area("porto_velho"), "jogo abre Porto Velho (cena provisoria)")
	await fr(4)
	var pv_area = jogo.atual
	var an = pv_area.get("area_npcs")
	check(an != null and an.npcs.size() >= 20, "Porto Velho com %d NPCs no mapa" % (an.npcs.size() if an else 0))
	jogo.estado.ouro = 500
	var ih: int = an.npc_por_id("helena")
	an.falar(ih)
	an.abrir_balcao()
	check(an.balcao and an.abas.has("comprar") and an.abas.has("fundir") and an.abas.has("forjar"), "Helena abre o balcao com comprar/fundir/forjar (%s)" % str(an.abas))
	an.aba = an.abas.find("comprar")
	an._listar()
	var o3: int = jogo.estado.ouro
	var m3: String = an.escolher(0)
	check(jogo.estado.qtd("carvao") >= 1 and jogo.estado.ouro < o3, "compra pelo balcao (%s)" % m3)
	an.fechar()
	var imar: int = an.npc_por_id("marina")
	an.falar(imar)
	an.abrir_balcao()
	check(an.abas == ["servicos"], "Capita Marina: servico de viagem")
	an.fechar()
	# minerio na fazenda
	jogo.viajar("fazenda")
	check(await esperar_area("fazenda"), "Porto Velho -> fazenda")
	await fr(4)
	var mins = jogo.atual.get_node_or_null("MineriosArea")
	check(mins != null and mins.nos.size() == 3, "fazenda com 3 nos de minerio (%d)" % (mins.nos.size() if mins else 0))
	if mins:
		var c0: int = jogo.estado.qtd("minerio_cobre")
		var mm: String = mins.minerar(0)
		check(jogo.estado.qtd("minerio_cobre") > c0 and not mins.disponivel(0), "minera cobre (%s) e o no esgota no dia" % mm)
		jogo.estado.novo_dia()
		check(mins.disponivel(0), "o no volta no dia seguinte")
	check((FileAccess.get_md5("user://ilha_fazenda_v1.json") if FileAccess.file_exists("user://ilha_fazenda_v1.json") else "") == v_ilha, "save real intacto")
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("RESULTADO economia: %d/%d" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
