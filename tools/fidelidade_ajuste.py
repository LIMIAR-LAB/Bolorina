"""Ajuste de enquadramento (fase 1 de fidelidade).
Pontos de referencia marcados a mao na imagem-alvo e numa captura da cena de
fidelidade com o enquadramento base (escala 1, deslocamento 0). Ajusta uma
similaridade sem rotacao (escala s + translacao t): ref = s*(cap - c) + c + t.
Com camera ortografica de rotacao fixa isso equivale a tamanho/s e a mover a
camera d = -t/s pixels da captura base. Grava docs/fidelidade-camera.json.
Uso: python tools/fidelidade_ajuste.py"""
import json, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); DOCS = os.path.join(os.path.dirname(HERE), 'docs')
C = np.array([800.0, 450.0])
# nome: (x,y na referencia 1600x900, x,y na captura base 1600x900)
PONTOS = {
    'cume do telhado do poco':        ((788, 549), (793, 539)),
    'topo do menir com anel':         ((1048, 574), (1169, 513)),
    'lampiao do poste da praca':      ((979, 393), (1097, 378)),
    'canto norte do campo arado':     ((1301, 484), (1345, 495)),
    'janela acesa da casa esquerda':  ((747, 271), (752, 264)),
    'janela esquerda da casa direita':((1059, 322), (1199, 249)),
    'janela direita da casa direita': ((1257, 366), (1289, 315)),
}
ref = np.array([v[0] for v in PONTOS.values()], float); cap = np.array([v[1] for v in PONTOS.values()], float)
# minimos quadrados: ref - c = s*(cap - c) + t
A = []; b = []
for (rx, ry), (cx, cy) in zip(ref, cap):
    A.append([cx - C[0], 1, 0]); b.append(rx - C[0])
    A.append([cy - C[1], 0, 1]); b.append(ry - C[1])
sol, *_ = np.linalg.lstsq(np.array(A), np.array(b), rcond=None)
s, tx, ty = sol
pred = s * (cap - C) + C + np.array([tx, ty])
res = np.linalg.norm(pred - ref, axis=1)
d = [-tx / s, -ty / s]
path = os.path.join(DOCS, 'fidelidade-camera.json')
cfg = json.load(open(path)) if os.path.exists(path) else {}
cfg.update({'escala': round(float(s), 4), 'desloc_px': [round(float(d[0]), 1), round(float(d[1]), 1)],
            'ajuste': {'pontos': {k: {'referencia': v[0], 'captura_base': v[1], 'residuo_px': round(float(r), 1)} for (k, v), r in zip(PONTOS.items(), res)},
                       'residuo_medio_px': round(float(res.mean()), 1), 'residuo_max_px': round(float(res.max()), 1)}})
json.dump(cfg, open(path, 'w'), indent=1, ensure_ascii=False)
print('escala %.4f  desloc_px %s  residuo medio %.1f max %.1f' % (s, cfg['desloc_px'], res.mean(), res.max()))
for (k, v), r in zip(PONTOS.items(), res): print('  %-34s %.1f px' % (k, r))