"""Gera docs/fidelidade-checklist-<rotulo>.json a partir do checklist base (fase 1) e de um codigo
de 60 letras (P presente, Q parcial, A ausente) na ordem dos itens. Uso: python tools/fidelidade_checklist.py <rotulo> <codigo> [notas.json]"""
import json, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
base = json.load(open(os.path.join(ROOT, "docs", "fidelidade-checklist.json"), encoding="utf-8"))
rot, code = sys.argv[1], sys.argv[2]
assert len(code) == len(base["itens"]), (len(code), len(base["itens"]))
notas = json.load(open(sys.argv[3], encoding="utf-8")) if len(sys.argv) > 3 else {}
m = {"P": "presente", "Q": "parcial", "A": "ausente"}
for i, (it, c) in enumerate(zip(base["itens"], code)):
    it["estado"] = m[c]; it["nota"] = notas.get(str(i), "")
base["captura"] = f"docs/fid-v7-{rot}.png"; base["avaliador"] = "agente (avaliacao visual manual, subjetiva) - vila V7 modular"
json.dump(base, open(os.path.join(ROOT, "docs", f"fidelidade-checklist-{rot}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print({k: code.count(k) for k in "PQA"})