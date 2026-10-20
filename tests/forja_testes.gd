extends SceneTree
## Testes headless da forja (PROPOSTA). Rodar: godot --headless --path . -s res://tests/forja_testes.gd
const Forja = preload("res://scripts/forja/forja.gd")

var checks := 0
var falhas := 0

func check(ok: bool, texto: String) -> void:
	checks += 1
	if not ok:
		falhas += 1
	print(("PASS " if ok else "FAIL ") + texto)

func _initialize() -> void:
	var f = Forja.new()
	check(f.erros.is_empty(), "JSON carregados sem erro")
	check(f.materiais.size() >= 25, "materiais carregados (%d)" % f.materiais.size())
	check(f.itens.size() >= 80, "itens carregados (%d)" % f.itens.size())
	check(f.receitas.size() == f.itens.size() + 9, "uma receita por item + 9 de fundição (%d)" % f.receitas.size())
	var probs: Array = f.validar()
	check(probs.is_empty(), "dados consistentes (%s)" % (", ".join(probs) if probs else "ok"))
	# progressão: 9 tiers de espada, ataque crescente
	var ant := 0
	var cresce := true
	for k in ["cobre", "ferro", "aco", "brasa", "prata", "celeste", "cronostio", "adamantium", "paradoxal"]:
		var a := int(f.itens["espada_" + k].ataque)
		if a <= ant: cresce = false
		ant = a
	check(cresce, "ataque das espadas cresce a cada tier")
	# cada tier tem conjunto completo de 5 peças
	for k in ["cobre", "ferro", "aco", "brasa", "prata", "celeste", "cronostio", "adamantium", "paradoxal"]:
		var ok := true
		for s in ["elmo", "peitoral", "luvas", "botas", "escudo"]:
			ok = ok and f.itens.has("%s_%s" % [s, k])
		check(ok, "conjunto %s tem elmo, peitoral, luvas, botas e escudo" % k)
	# ferreiros certos
	check(String(f.receitas["forjar_espada_cobre"].ferreiro) == "ferreiro", "Gaspar (ferreiro) forja a espada de cobre")
	check(String(f.receitas["forjar_espada_brasa"].ferreiro) == "ferreiro_orc", "Krag (ferreiro_orc) forja a lâmina Ferro-Brasa")
	check(String(f.receitas["forjar_espada_paradoxal"].ferreiro) == "fabricadora", "Fabricadora forja a espada paradoxal")
	check(String(f.receitas["forjar_martelo_torto"].forja) == "forja_cla", "Martelo Martelo-Torto sai da forja do clã")
	# ciclo completo do MVP: minério -> lingote -> espada -> reforja
	var inv := {"ouro": 1000, "itens": {"minerio_cobre": 9, "carvao": 3, "madeira": 2}}
	var niveis := {"ferraria_porto": 1}
	var r = f.fazer("fundir_cobre", inv, niveis, 3)
	check(r.ok and Forja.qtd(inv, "lingote_cobre") == 3, "fundiu 3 lingotes de cobre (9 minérios + 3 carvões)")
	check(Forja.qtd(inv, "minerio_cobre") == 0 and Forja.qtd(inv, "carvao") == 0, "minério e carvão consumidos")
	check(int(inv.ouro) == 1000 - 15, "ouro da fundição descontado (%d)" % inv.ouro)
	var sem = f.pode_fazer("forjar_espada_ferro", inv, niveis)
	check(not sem.ok and "nível" in String(sem.motivo), "espada de ferro bloqueada na forja nível 1")
	r = f.fazer("forjar_espada_cobre", inv, niveis)
	check(r.ok and inv.equipamento.size() == 1, "forjou a Espada de Cobre")
	var esp: Dictionary = inv.equipamento[0]
	check(f.atributos(esp).ataque == 5, "espada de cobre: ataque 5")
	check(is_equal_approx(float(f.atributos(esp).multiplicador_dano), 1.2), "multiplicador de dano 1,2")
	var falta = f.pode_fazer("forjar_espada_cobre", inv, niveis)
	check(not falta.ok and falta.faltando.has("lingote_cobre"), "sem lingote: informa o que falta")
	inv.itens["lingote_cobre"] = 1
	r = f.reforjar(esp, inv, niveis)
	check(r.ok and int(esp.reforja) == 1, "reforja +1")
	check(f.atributos(esp).ataque == 6, "+1 aumenta o ataque em 10%% (%d)" % f.atributos(esp).ataque)
	r = f.reforjar(esp, inv, niveis)
	check(not r.ok, "+2 sem lingotes falha")
	# encanto
	inv.itens["essencia_orvalho_lunar"] = 1
	r = f.encantar(esp, "essencia_orvalho_lunar", inv)
	check(r.ok and String(esp.encanto) == "essencia_orvalho_lunar", "encantou com Orvalho-Lunar (Mira)")
	check(not f.encantar(esp, "minerio_cobre", inv).ok, "minério não serve como encanto")
	# conjunto
	var eq := [{"id": "elmo_ferro"}, {"id": "peitoral_ferro"}, {"id": "botas_ferro"}, {"id": "luvas_cobre"}]
	var b: Dictionary = f.bonus_conjunto(eq)
	check(b.has("conjunto_ferro") and int(b.conjunto_ferro.pecas) == 3 and b.conjunto_ferro.bonus.size() == 1, "3 peças de ferro ativam o bônus de 3")
	eq += [{"id": "luvas_ferro"}, {"id": "escudo_ferro"}]
	b = f.bonus_conjunto(eq)
	check(b.conjunto_ferro.bonus.size() == 2, "5 peças ativam os dois bônus")
	# defesa
	check(Forja.dano_recebido(14, 0) == 14 and Forja.dano_recebido(14, 100) == 7, "fórmula de defesa: orc 14 -> 7 com defesa 100")
	# mineração
	check(f.pode_minerar("minerio_cobre", ""), "cobre se minera com a picareta básica")
	check(not f.pode_minerar("minerio_cronostio", "picareta_ferro"), "cronóstio não sai com picareta de ferro")
	check(f.pode_minerar("minerio_cronostio", "picareta_celeste"), "cronóstio sai com picareta celeste")
	check(not f.pode_minerar("minerio_adamantium", "picareta_celeste") and f.pode_minerar("minerio_adamantium", "picareta_cronostio"), "adamantium só com picareta de cronóstio")
	# MVP
	for id in f.mvp.receitas:
		check(f.receitas.has(id), "MVP: receita %s existe" % id)
	# nós da ilha futurista
	check(f.nos_de_minerio.has("veio_da_fenda") and f.nos_de_minerio.veio_da_fenda.size() >= 6, "nós de minério do Veio da Fenda definidos")
	print("\n%s: %d verificacoes, %d falhas" % ["PASS" if falhas == 0 else "FAIL", checks, falhas])
	quit(0 if falhas == 0 else 1)
