#!/usr/bin/env python3
"""Gera docs/FORJA_E_ITENS.md a partir de data/forja/*.json (PROPOSTA).
Uso: python3 tools/forja_gerar_doc.py   (rodar na raiz do projeto)"""
import json, math, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def j(n): return json.load(open(os.path.join(R, "data/forja", n + ".json"), encoding="utf-8"))
M, I, RC = j("materiais"), j("itens"), j("receitas")
mats = {m["id"]: m for m in M["materiais"]}
itens = I["itens"]
locais = M["locais"]
todas_rec = RC["fundicao"] + RC["receitas"]
rec_por_res = {r["resultado"]: r for r in RC["receitas"]}
forjas = RC["forjas"]
TIERS = {1: "Cobre", 2: "Ferro", 3: "Aço do Porto", 4: "Ferro-Brasa", 5: "Prata Tumular",
         6: "Cristal Celeste", 7: "Cronóstio", 8: "Adamantium", 9: "Liga Paradoxal"}
def nm(i): return mats.get(i, {}).get("nome") or next((x["nome"] for x in itens if x["id"] == i), i)
def mlist(d): return ", ".join(f"{q}× {nm(k)}" for k, q in d.items()) or "—"
def fz(r): return f"{forjas[r['forja']]['ferreiro_nome']} ({forjas[r['forja']]['nome']} N{r['nivel_forja']})"
o = []; w = o.append
w("# Forja e Itens — Ilha das Cinzas\n")
w("> **PROPOSTA — não é canon.** Documento gerado por `tools/forja_gerar_doc.py` a partir de `data/forja/*.json` "
  "(gerados por `tools/forja_gerar_dados.py`). Nada aqui está ligado ao `main.tscn`, ao Vale ou ao combate; "
  "`scripts/forja/forja.gd` é um sistema isolado, testado por `tests/forja_testes.gd`.\n")
n_tipo = {}
for x in itens: n_tipo[x["tipo"]] = n_tipo.get(x["tipo"], 0) + 1
w(f"**Totais:** {len(M['materiais'])} materiais · {len(itens)} itens ({n_tipo.get('armadura',0)} peças de armadura, "
  f"{n_tipo.get('arma',0)} armas, {n_tipo.get('ferramenta',0)} ferramentas, {n_tipo.get('acessorio',0)} acessórios) · "
  f"{len(RC['receitas'])} receitas de forja + {len(RC['fundicao'])} de fundição.\n")
w("## 1. Ciclo do jogador\n")
w("1. **Minerar** (picareta com nível ≥ `picareta_minima` do minério) na dungeon (Minas da Cinza) ou em outras ilhas.\n"
  "2. **Fundir** minério + carvão em lingote na forja certa.\n"
  "3. **Forjar** o item no ferreiro (cada forja tem níveis; cada nível libera tiers).\n"
  "4. **Reforjar** (+1..+3) e **encantar** com essências da Mira (Botica) ou do Ozório (Torre Torta).\n"
  "5. Vestir 3 ou 5 peças do mesmo conjunto para o **bônus de conjunto**.\n")
w("## 2. Metais (9 tiers) e onde minerar\n")
w("| Tier | Metal | Minério / origem | Onde | Picareta mínima | Lingote (fundição) |\n|---|---|---|---|---|---|")
fund = {r["resultado"]: r for r in RC["fundicao"]}
lingote_por_tier = {}
for r in RC["fundicao"]:
    t = mats.get(r["resultado"], {}).get("tier")
    if t: lingote_por_tier.setdefault(t, r)
for t in range(1, 10):
    minerios = [m for m in M["materiais"] if m.get("tier") == t and m["tipo"] in ("minerio",)]
    rf = lingote_por_tier.get(t)
    if minerios:
        mi = minerios[0]
        onde = "; ".join(f"{locais[l]['nome']} ({locais[l]['regiao']})" for l in mi.get("onde", []))
        if mi.get("andares"): onde += f" — andares {mi['andares'][0]}–{mi['andares'][1]}"
        orig, pm = mi["nome"], mi.get("picareta_minima", 0)
    else:
        orig, onde, pm = "liga (sem minério)", "feita na forja", "—"
    lg = f"{nm(rf['resultado'])}: {mlist(rf['materiais'])} + {rf['ouro']} ouro — {fz(rf)}" if rf else "—"
    w(f"| {t} | {TIERS[t]} | {orig} | {onde} | {pm} | {lg} |")
w("\n### Locais de mineração\n")
for k, l in locais.items():
    w(f"- **{l['nome']}** — {l['regiao']}. {l['descricao']}" + (f" Cena: `{l['cena']}`." if l.get("cena") else " (cena ainda não existe)"))
w("\n### Outros materiais (auxiliares, drops, essências)\n")
w("| Material | Tipo | Tier | Onde / fornecedor | Nota |\n|---|---|---|---|---|")
for m in M["materiais"]:
    if m["tipo"] == "minerio": continue
    onde = ", ".join(locais.get(l, {}).get("nome", l) for l in m.get("onde", [])) or m.get("fornecedor") or (f"fundição ({fz(fund[m['id']])})" if m["id"] in fund else ("fazenda" if m["tipo"] == "auxiliar" else "—"))
    w(f"| {m['nome']} | {m['tipo']} | {m.get('tier','')} | {onde} | {m.get('nota', m.get('efeito',''))} |")
nos = M["nos_de_minerio"]
w("\n### Nós de minério na Estação Depois-de-Ontem (`veio_da_fenda`)\n")
w("| Nó | Material | Posição (x,z) m | Quantidade | Renasce (dias) |\n|---|---|---|---|---|")
for k, lst in nos.items():
    for n in lst:
        w(f"| {n['id']} | {nm(n['material'])} | {n['pos'][0]}, {n['pos'][1]} | {n['quantidade'][0]}–{n['quantidade'][1]} | {n['renasce_dias']} |")
def tabela(tipo, cols, cab):
    w("| " + " | ".join(cab + ["Receita", "Ferreiro / forja"]) + " |\n|" + "---|" * (len(cab) + 2))
    for x in sorted([x for x in itens if x["tipo"] == tipo], key=lambda x: (x["tier"], x["categoria"])):
        r = rec_por_res.get(x["id"])
        rc = f"{mlist(r['materiais'])} + {r['ouro']} ouro" if r else "—"
        w("| " + " | ".join(str(c(x)) for c in cols) + f" | {rc} | {fz(r) if r else '—'} |")
w("\n## 3. Picaretas e ferramentas\n")
w("Nível de mineração da picareta precisa ser ≥ `picareta_minima` do minério (cobre 0, ferro 1, ferro-brasa 3, prata 4, cristal celeste 5, cronóstio 6, adamantium 7).\n")
tabela("ferramenta", [lambda x: x["nome"], lambda x: x["tier"], lambda x: x.get("nivel_mineracao", "—"), lambda x: x["efeito"], lambda x: x["valor_ouro"]],
       ["Ferramenta", "Tier", "Nível mineração", "Efeito", "Valor"])
w("\n## 4. Armas\n")
tabela("arma", [lambda x: x["nome"], lambda x: x["tier"], lambda x: x["ataque"], lambda x: x["multiplicador_dano"], lambda x: x["velocidade"], lambda x: x["especial"] or "—"],
       ["Arma", "Tier", "Ataque", "Mult. dano", "Veloc.", "Especial"])
w("\n## 5. Armaduras (5 peças por tier: elmo, peitoral, luvas, botas, escudo)\n")
tabela("armadura", [lambda x: x["nome"], lambda x: x["tier"], lambda x: x["defesa"]], ["Peça", "Tier", "Defesa"])
w("\n### Bônus de conjunto\n")
w("| Conjunto | Tier | 3 peças | 5 peças |\n|---|---|---|---|")
for k, c in I["conjuntos"].items():
    w(f"| {c['nome']} | {c['tier']} | {c['bonus_3_pecas']} | {c['bonus_5_pecas']} |")
w("\n## 6. Acessórios\n")
tabela("acessorio", [lambda x: x["nome"], lambda x: x["tier"], lambda x: x["efeito"], lambda x: x["valor_ouro"]], ["Acessório", "Tier", "Efeito", "Valor"])
w("\n## 7. Ferreiros e níveis de forja\n")
for k, f in forjas.items():
    w(f"### {f['nome']} — {f['ferreiro_nome']} ({f['regiao']})\n")
    w("| Nível | Nome | Custo | Libera tier | Nota |\n|---|---|---|---|---|")
    for n in f["niveis"]:
        custo = f"{n['custo_ouro']} ouro" + (f" + {mlist(n['materiais'])}" if n["materiais"] else "")
        w(f"| {n['nivel']} | {n['nome']} | {custo} | {', '.join(map(str, n['libera_tier']))} | {n.get('nota', n.get('requisito', ''))} |")
    w("")
w("**Quem forja o quê:** tiers 1–3 Gaspar (N1–N3) · tier 4 Krag (Forja do Clã) · tiers 5–6 Gaspar N4 (fole feito pelo Krag) · "
  "tier 7 Mestra Ione (Forja Quântica N1) · tier 8 Gaspar N5 (Bigorna Cronal comprada da Ione) · tier 9 Forja Quântica N2.\n")
w("## 8. Mecânicas\n")
w("### Fundição\n")
w("| Receita | Resultado | Materiais | Ouro | Onde |\n|---|---|---|---|---|")
for r in RC["fundicao"]:
    w(f"| {r['id']} | {r['quantidade']}× {nm(r['resultado'])} | {mlist(r['materiais'])} | {r['ouro']} | {fz(r)} |")
w("\n### Reforja (+1 a +3)\n")
w("| Nível | Bônus no atributo | Lingotes do tier | Ouro (fração do valor) | Extra |\n|---|---|---|---|---|")
for n in RC["reforja"]["niveis"]:
    w(f"| +{n['nivel']} | +{int(n['bonus_atributo']*100)}% | {n['lingotes_do_tier']} | {int(n['ouro_fracao']*100)}% | {mlist(n.get('extra', {})) if n.get('extra') else '—'} |")
w(f"\n{RC['reforja']['regra']}\n")
w("### Encantamento\n")
e = RC["encantamento"]
w(f"{e['regra']} Custo: {e['ouro_por_tier']} ouro × tier do item + 1 essência.\n")
for s in e["essencias"]:
    m = mats.get(s, {})
    w(f"- **{m.get('nome', s)}** — {m.get('efeito', m.get('nota', ''))} (fornecedor: {m.get('fornecedor', '—')})")
w("\n## 9. Tabela de balanceamento\n")
w(f"Fórmulas: multiplicador de dano = `{I['formula']['multiplicador_dano']}` (aplicado em `jogador_combate.multiplicador_dano`); "
  f"dano recebido = `{I['formula']['dano_recebido']}`. Referência do combate atual: combo 10/12/24 (46 por combo), Vale 100 de vida, orc 60 de vida e 14 de dano.\n")
w("| Tier | Melhor arma (ataque) | Mult. | Dano do combo | Combos p/ orc (60) | Defesa do conjunto (5 peças) | Dano do orc (14) recebido | Golpes do orc p/ derrubar Vale (100) |\n|---|---|---|---|---|---|---|---|")
for t in range(1, 10):
    ar = [x for x in itens if x["tipo"] == "arma" and x["tier"] == t]
    a = max(ar, key=lambda x: x["ataque"]) if ar else None
    mult = 1 + (a["ataque"] if a else 0) / 25
    combo = round(10*mult) + round(12*mult) + round(24*mult)
    d = sum(x["defesa"] for x in itens if x["tipo"] == "armadura" and x["tier"] == t)
    rec = 14 * 100 / (100 + d)
    w(f"| {t} | {a['nome'] + ' (' + str(a['ataque']) + ')' if a else '—'} | {mult:.2f} | {combo} | {math.ceil(60/combo*10)/10} | {d} | {rec:.1f} | {math.ceil(100/max(1,round(rec)))} |")
w("\n> Inimigos de tiers altos devem escalar vida/dano junto (sugestão: vida do orc × 1,6 por tier) — senão o tier 9 vira trivial.\n")
w("## 10. MVP (primeira fatia)\n")
mv = RC["mvp"]
w(mv["descricao"] + "\n")
w("- Materiais: " + ", ".join(nm(x) for x in mv["materiais"]))
w("- Receitas: " + ", ".join(f"`{x}`" for x in mv["receitas"]))
w("- Mecânicas: " + ", ".join(mv["mecanicas"]))
w("\n## 11. Peças de equipamento da PixelLab\n")
w("Todo item tem `arte_pixellab: null` no JSON, pronto para receber o caminho do sprite. As 5 peças geradas na PixelLab **não estão no clone** "
  "(LIMIAR-LAB/Bolorina @96314ad); só existe a forma `experimental_adamantium_v99` do combate, que casa com o **Conjunto de Adamantium (tier 8)**. "
  "Mapeamento sugerido assim que as peças aparecerem: elmo → `elmo_<tier>`, peitoral → `peitoral_<tier>`, luvas → `luvas_<tier>`, botas → `botas_<tier>`, escudo → `escudo_<tier>` "
  "do tier cujo visual combinar (preencher `arte_pixellab` em `tools/forja_gerar_dados.py` e regenerar). Nenhum crédito pago foi usado.\n")
w("## 12. Como usar no código\n")
w("```gdscript\nconst Forja = preload(\"res://scripts/forja/forja.gd\")\nvar f = Forja.new()                        # carrega data/forja/*.json\nvar inv := {\"ouro\": 200, \"itens\": {\"minerio_cobre\": 9, \"carvao\": 3}}\n"
  "var niveis := {\"ferraria_porto\": 1}\nif f.pode_fazer(\"fundir_cobre\", inv, niveis, 3).ok:\n    f.fazer(\"fundir_cobre\", inv, niveis, 3)\n"
  "f.pode_minerar(\"minerio_ferro\", \"picareta_cobre\")  # true: nível 1 ≥ mínimo 1\n```\n")
w("Testes: `godot --headless --path . -s res://tests/forja_testes.gd`.\n")
open(os.path.join(R, "docs/FORJA_E_ITENS.md"), "w", encoding="utf-8").write("\n".join(o) + "\n")
print("ok", len(o))
