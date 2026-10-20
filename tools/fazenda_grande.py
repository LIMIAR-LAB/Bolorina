"""Fazenda grande (variante): parte do layout atual (scripts/ilha/fazenda_layout.json, que NAO e alterado) e amplia:
  - area jogavel de x -28..28 / z -24..24 para x -40..40 / z -34..32 (pomar a oeste, pastagem ao sul)
  - mais 4 canteiros ja arados ao lado da casa
  - pomar (12 macieiras/laranjeiras em fileiras) a oeste
  - celeiro + area dos animais cercada ao sul
  - caminho de terra ate um corredor no sudeste -> Porto Velho (saida no fim do corredor)
Saida: scripts/ilha/fazenda_grande_layout.json + fazenda_grande_cercas.json (cena: scripts/ilha/fazenda_grande.tscn).
Uso: python tools/fazenda_grande.py <raiz>"""
import json, math, os, sys, random
R = sys.argv[1] if len(sys.argv) > 1 else '.'
D = os.path.join(R, 'scripts', 'ilha')
base = json.load(open(os.path.join(D, 'fazenda_layout.json'), encoding='utf-8'))
cercas = json.load(open(os.path.join(D, 'fazenda_cercas.json'), encoding='utf-8'))
OX, OZ = base['origem']
W, H = base['tamanho']
alt = base['alturas']
tip = [list(r) for r in base['tipos']]
rnd = random.Random(2026_10_20)


def antigo(x, z):
    return -28 <= x <= 28 and -24 <= z <= 24


def corredor_vila(x, z):
    return 28 < x <= 50 and -13 <= z <= -9


def corredor_porto(x, z):
    return 38 < x <= 50 and 15 <= z <= 21


def novo(x, z):
    return (-40 <= x <= 40 and -34 <= z <= 32) or corredor_vila(x, z) or corredor_porto(x, z)


def lago(x, z):
    cx, cz, rx, rz = -19.0, 14.0, 6.5, 4.2
    return ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2


# distancia (chebyshev) ate a area jogavel nova, para refazer as colinas em volta
INF = 99
dist = [[INF] * W for _ in range(H)]
for iz in range(H):
    for ix in range(W):
        if novo(OX + ix, OZ + iz):
            dist[iz][ix] = 0
for _ in range(12):
    for iz in range(H):
        for ix in range(W):
            if dist[iz][ix] == 0:
                continue
            m = INF
            for dz in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    jz, jx = iz + dz, ix + dx
                    if 0 <= jz < H and 0 <= jx < W:
                        m = min(m, dist[jz][jx] + 1)
            dist[iz][ix] = min(dist[iz][ix], m)
for iz in range(H):
    z = OZ + iz
    for ix in range(W):
        x = OX + ix
        if antigo(x, z) and not corredor_porto(x, z):
            continue                                    # o miolo antigo fica igual (lago, casa, detritos)
        d = dist[iz][ix]
        if d == 0:
            alt[iz][ix] = round(0.02 * math.sin(x * 0.7) + 0.02 * math.cos(z * 0.9), 3)
            tip[iz][ix] = 'g'
        else:
            alt[iz][ix] = round(min(1.3 + 0.35 * (d - 1), 4.5) + 0.25 * math.sin(x * 0.45) * math.cos(z * 0.37), 3)
            tip[iz][ix] = 'r' if d <= 1 else 'g'


def pinta(x, z, t):
    if 0 <= z - OZ < H and 0 <= x - OX < W:
        tip[z - OZ][x - OX] = t


# caminho: casa -> sul -> corredor do Porto Velho (sudeste)
for z in range(-10, 19):
    pinta(4, z, 'c'); pinta(5, z, 'c')
for x in range(4, 51):
    pinta(x, 17, 'c'); pinta(x, 18, 'c')
# caminho do pomar (oeste) e do celeiro (sul)
for x in range(-36, -12):
    pinta(x, -11, 'c')
for z in range(18, 27):
    pinta(-2, z, 'c'); pinta(-1, z, 'c')
# canteiros novos ja arados (4 de 4x3)
NOVOS = []
for (x0, z0) in [(2, -8), (8, -8), (8, -4), (2, -3)]:
    for x in range(x0, x0 + 4):
        for z in range(z0, z0 + 3):
            NOVOS.append((x, z))
            pinta(x, z, 't')
# pecas: tira o que caiu dentro da area nova (arvores da antiga borda) e acrescenta pomar, celeiro e animais
pecas = []
for p in base['pecas']:
    x, z = p['celula']
    if novo(x, z) and not antigo(x, z):
        continue
    if (x, z) in NOVOS:
        continue
    pecas.append(p)
POMAR = []
for i, x in enumerate(range(-37, -27, 3)):
    for j, z in enumerate(range(-20, 4, 6)):
        pid = 'arvore_outono' if (i + j) % 2 == 0 else 'arvore_escura'
        pecas.append({'id': pid, 'celula': [x, z], 'rot': (i + j) % 4})
        POMAR.append([x, z])
CELEIRO = [-12, 29]
pecas += [{'id': 'casa', 'celula': CELEIRO, 'rot': 2},
          {'id': 'carroca_abobora', 'celula': [-6, 27], 'rot': 1}, {'id': 'barril', 'celula': [-8, 26], 'rot': 0},
          {'id': 'caixote', 'celula': [-7, 25], 'rot': 0}, {'id': 'poste_lampiao', 'celula': [3, 18], 'rot': 0},
          {'id': 'poste_lampiao', 'celula': [24, 16], 'rot': 0}, {'id': 'poste_lampiao', 'celula': [40, 16], 'rot': 0},
          {'id': 'banco', 'celula': [-30, -12], 'rot': 0}, {'id': 'poco', 'celula': [8, 27], 'rot': 0}]
for c in [(-39, 30), (39, 30), (39, -33), (-39, -33), (20, 31), (-25, 31)]:
    pecas.append({'id': 'arbusto_flor', 'celula': list(c), 'rot': 0})
ANIMAIS = [[8.5, 23.5], [2.5, 23.5], [2.5, 31.5], [18.5, 31.5], [18.5, 23.5], [12.5, 23.5]]  # vao de 4 m = porteira
cercas = dict(cercas)
cercas['cercas'] = list(cercas['cercas']) + [
    {'nome': 'pasto_animais', 'pontos': ANIMAIS, 'fechada': False, 'portoes': []},
    {'nome': 'pomar', 'pontos': [[-39.5, -22.5], [-26.5, -22.5]], 'fechada': False, 'portoes': []}]
faz = dict(base['fazenda'])
faz['canteiro_inicial'] = list(faz['canteiro_inicial']) + [list(c) for c in NOVOS]
faz['aravel'] = {'min': [-39, -33], 'max': [39, 31]}
faz['spawns'] = dict(faz['spawns'])
faz['spawns']['da_porto'] = [44.0, 18.0]
faz['pomar'] = POMAR
faz['celeiro'] = CELEIRO
faz['animais'] = {'min': [3, 24], 'max': [18, 31]}
faz['saidas'] = list(faz['saidas']) + [{'pos': [48.5, 18.0], 'raio': 1.6, 'area': 'porto_velho', 'spawn': 'padrao', 'placa': [45.0, 15.5], 'texto': 'Porto Velho  >'}]
out = dict(base)
out['versao'] = 'fazenda_grande_v1'
out['alturas'] = alt
out['tipos'] = [''.join(r) for r in tip]
out['pecas'] = pecas
out['fazenda'] = faz
json.dump(out, open(os.path.join(D, 'fazenda_grande_layout.json'), 'w', encoding='utf-8'), separators=(',', ':'), ensure_ascii=False)
json.dump(cercas, open(os.path.join(D, 'fazenda_grande_cercas.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
area_antiga = 57 * 49
area_nova = 81 * 67
print('ok: area jogavel %d -> %d m2 (+%d%%), canteiros iniciais %d -> %d, pomar %d arvores, pecas %d'
      % (area_antiga, area_nova, round(100 * (area_nova / area_antiga - 1)), len(base['fazenda']['canteiro_inicial']), len(faz['canteiro_inicial']), len(POMAR), len(pecas)))
