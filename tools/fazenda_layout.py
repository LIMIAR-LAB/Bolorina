"""Gera scripts/ilha/fazenda_layout.json e fazenda_cercas.json (Fazenda, inspirada na Standard Farm).
Grade de 1 m, mesmo formato da vila V7 (scripts/modular/vila_layout.json).
Uso: python tools/fazenda_layout.py <raiz_do_projeto>"""
import json, math, random, sys, os
raiz = sys.argv[1] if len(sys.argv) > 1 else '.'
OX, OZ, W, H = -52, -46, 104, 92
rnd = random.Random(7031)
# area andavel (planicie): x -28..28, z -24..24 ; saida leste (corredor) z -12..-10 ate x 40
def dentro(x, z):
    return -28 <= x <= 28 and -24 <= z <= 24
def corredor(x, z):
    return 28 < x <= 46 and -13 <= z <= -9
LAGO = (-19.0, 14.0, 6.5, 4.2)  # centro x, z, raios
def lago(x, z):
    cx, cz, rx, rz = LAGO
    return ((x-cx)/rx)**2 + ((z-cz)/rz)**2
alt = []; tip = []
for iz in range(H):
    z = OZ + iz
    ra = []; rt = ''
    for ix in range(W):
        x = OX + ix
        h = 0.0; t = 'g'
        if dentro(x, z) or corredor(x, z):
            h = 0.02*math.sin(x*0.7)+0.02*math.cos(z*0.9)
            L = lago(x, z)
            if L < 1.0:
                h = -0.95 if L < 0.75 else -0.55; t = 'b'
            elif L < 1.45:
                h = -0.12; t = 'b'
        else:
            # colinas com floresta em volta (borda natural, nao andavel)
            dx = max(-28 - x, x - 28, 0) if not corredor(x, z) else 0
            dz = max(-24 - z, z - 24, 0)
            if 28 < x <= 46 and (-15 <= z <= -7):
                dz = min(abs(z+13) if z < -13 else 99, abs(z+9) if z > -9 else 99)
                dx = 0 if dz != 99 else dx
                d = max(dz, 1)
            else:
                d = max(dx, dz)
            h = min(1.3 + 0.35*(d-1), 4.5) + 0.25*math.sin(x*0.45)*math.cos(z*0.37)
            t = 'r' if d <= 1 else 'g'
        ra.append(round(h, 3)); rt += t
    alt.append(ra); tip.append(rt)
def pinta(x, z, t):
    tip[z-OZ] = tip[z-OZ][:x-OX] + t + tip[z-OZ][x-OX+1:]
# caminhos: varanda da casa -> leste ate a saida; ramal ate o lago e ao galinheiro
for z in range(-14, -10):
    for x in (-7, -6):
        pinta(x, z, 'c')
for x in range(-7, 47):
    for z in (-11, -10):
        pinta(x, z, 'c')
for z in range(-10, 6):
    pinta(-12 + (1 if z % 5 == 0 else 0), z, 'c')
for x in range(-13, -11):
    for z in (6, 7):
        pinta(x, z, 'c')
# canteiro inicial ja arado (terra 't'): 4x3 ao lado da casa
INICIAL = [(x, z) for x in range(-3, 1) for z in range(-8, -5)]
for (x, z) in INICIAL:
    pinta(x, z, 't')
pecas = []
casa = {"id": "casa", "celula": [-6, -17], "rot": 0}
pecas.append(casa)
pecas += [{"id": "poste_lampiao", "celula": [-9, -13], "rot": 0}, {"id": "poste_lampiao", "celula": [-3, -13], "rot": 0},
          {"id": "poco", "celula": [-13, -15], "rot": 0}, {"id": "barril", "celula": [-10, -14], "rot": 0},
          {"id": "caixote", "celula": [-2, -14], "rot": 0}, {"id": "banco", "celula": [-11, -12], "rot": 0},
          {"id": "poste_lampiao", "celula": [27, -12], "rot": 0}, {"id": "poste_lampiao", "celula": [9, -12], "rot": 0},
          {"id": "deck", "celula": [-14, 9], "rot": 0}, {"id": "cogumelos", "celula": [-24, 3], "rot": 0},
          {"id": "carroca_abobora", "celula": [-1, -16], "rot": 0}]
# floresta nas colinas
ocup = set()
def livre(x, z, r=2):
    return all((x+a, z+b) not in ocup for a in range(-r, r+1) for b in range(-r, r+1))
arvs = 0
for tent in range(4000):
    x = rnd.randint(-40, 40); z = rnd.randint(-36, 36)
    if dentro(x, z) or corredor(x, z):
        continue
    d = max(-28-x, x-28, -24-z, z-24)
    if d > 9 or d < 1 or (28 < x and -14 <= z <= -8):
        continue
    if not livre(x, z, 1 if d > 2 else 2):
        continue
    ocup.add((x, z))
    k = rnd.random()
    pid = "arvore_escura" if k < 0.45 else ("arvore_outono" if k < 0.75 else ("arbusto_escuro" if k < 0.9 else "arbusto_flor"))
    pecas.append({"id": pid, "celula": [x, z], "rot": rnd.randint(0, 3)})
    arvs += 1
    if arvs > 150:
        break
# rochas e arbustos de borda, perto do lago
for c in [(-26, 18), (-25, 9), (-12, 20), (-22, 21), (26, 20), (26, 4), (-27, -6)]:
    pecas.append({"id": "rocha", "celula": list(c), "rot": 0})
for c in [(-27, -20), (24, -23), (27, 14), (-27, 22), (12, 23), (-4, 23)]:
    pecas.append({"id": "arbusto_flor", "celula": list(c), "rot": 0})
# galinheiro cercado (x 9.5..20.5, z -21.5..-13.5), portao embaixo em x=15
GAL = [[9.5, -13.5], [9.5, -21.5], [20.5, -21.5], [20.5, -13.5], [9.5, -13.5]]
cercas = {"nota": "Cercas da fazenda (mesmo sistema da vila: scripts/modular/cercas.gd, docs/CERCAS.md).",
          "cercas": [{"nome": "galinheiro", "pontos": GAL, "fechada": False, "portoes": [[15, -13.5]]},
                     {"nome": "horta_casa", "pontos": [[-4.5, -9.5], [1.5, -9.5], [1.5, -4.5]], "fechada": False, "portoes": []}]}
reserv = set()
for x in range(9, 22):
    for z in range(-22, -13):
        reserv.add((x, z))
for x in range(-10, -1):
    for z in range(-20, -12):
        reserv.add((x, z))
for x in range(-15, -10):
    for z in range(-17, -12):
        reserv.add((x, z))
for (x, z) in INICIAL:
    reserv.add((x, z))
for x in range(-5, 3):
    reserv.add((x, -9))
# detritos do campo (estilo Standard Farm): pedras, galhos, mato, tocos, arvorezinhas
det = []
usados = set()
def pode(x, z):
    if not dentro(x, z) or (x, z) in reserv or (x, z) in usados:
        return False
    t = tip[z-OZ][x-OX]
    if t != 'g' or alt[z-OZ][x-OX] < -0.3 or lago(x, z) < 1.8:
        return False
    if abs(x) >= 27 or abs(z) >= 23:
        return False
    return True
cotas = {"pedra": 34, "galho": 30, "mato": 70, "toco": 9, "arvore": 7}
for tipo, n in cotas.items():
    k = 0; tent = 0
    while k < n and tent < 5000:
        tent += 1
        x = rnd.randint(-26, 26); z = rnd.randint(-22, 22)
        if tipo in ("toco", "arvore") and (x, z) in usados:
            continue
        if not pode(x, z):
            continue
        if tipo in ("toco", "arvore") and not all(pode(x+a, z+b) or (x+a, z+b) == (x, z) for a in (-1, 0, 1) for b in (-1, 0, 1)):
            continue
        if tipo == "mato" and rnd.random() < 0.5:
            # mato em touceiras
            pass
        usados.add((x, z))
        if tipo == "arvore":
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    usados.add((x+a, z+b))
        det.append({"tipo": tipo, "celula": [x, z]})
        k += 1
        if tipo == "mato":
            for a, b in ((1, 0), (0, 1), (-1, 0)):
                if k < n and rnd.random() < 0.55 and pode(x+a, z+b):
                    usados.add((x+a, z+b)); det.append({"tipo": "mato", "celula": [x+a, z+b]}); k += 1
data = {"versao": "fazenda_v1", "grade_m": 1.0, "origem": [OX, OZ], "tamanho": [W, H],
        "legenda_tipos": {"g": "grama", "c": "caminho", "t": "terra arada", "h": "horta", "b": "margem/lago", "r": "barranco"},
        "camera": {"yaw": 50.0, "pitch": 28.0, "tamanho": 20.0, "alvo": [-7.27, 0.0, -12.17]},
        "atores": {"jogador": [-6.0, -10.0], "mira": [-60.0, -60.0], "morador": [-61.0, -60.0], "gato": [-4.2, -13.4]},
        "rio": {"pontos": [[-27.0, 11.0], [-19.0, 14.0], [-11.0, 17.0]], "largura": 9.0, "nivel": -0.45},
        "pecas": pecas, "alturas": alt, "tipos": tip,
        "fazenda": {"detritos": det, "canteiro_inicial": [list(c) for c in INICIAL], "caixa_envio": [-3.5, -13.0],
                    "galinheiro": {"min": [10, -21], "max": [20, -14], "celeiro": [15, -19.5]},
                    "lago": {"centro": [LAGO[0], LAGO[1]], "raios": [LAGO[2], LAGO[3]]},
                    "saidas": [{"pos": [44.0, -10.5], "raio": 1.6, "area": "vila", "spawn": "da_fazenda", "placa": [41.5, -13.0], "texto": "Vila  >"}],
                    "spawns": {"inicio": [-6.0, -12.0], "da_vila": [41.5, -10.5], "cama": [-6.0, -12.0]},
                    "aravel": {"min": [-27, -23], "max": [27, 23]}}}
d = os.path.join(raiz, 'scripts', 'ilha')
os.makedirs(d, exist_ok=True)
json.dump(data, open(os.path.join(d, 'fazenda_layout.json'), 'w'), separators=(',', ':'))
json.dump(cercas, open(os.path.join(d, 'fazenda_cercas.json'), 'w'), indent=1)
from collections import Counter
print('pecas', len(pecas), Counter(p['id'] for p in pecas))
print('detritos', Counter(x['tipo'] for x in det))
