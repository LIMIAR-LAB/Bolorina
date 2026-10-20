"""Camadas de equipamento (paper-doll) da Vale V6 - local, sem servico externo, sem geracao paga.

Cada CAMADA e uma folha transparente com SO os pixels que a peca troca, alinhada quadro a quadro
com a arte base. O jogo (scripts/ilha/equipamento_visual.gd) compoe base + camadas por z.
  - vila: atlas 16 colunas x celula 48 com todos os quadros do manifest original_vale_v6
    (ordem em indice.json -> vila.quadros = caminho do PNG base).
  - combate: mesmo formato das folhas vale_combate_v6pal (<mov>/<mov>_<dir>_sheet.png, 112 px, 8 col, 49).
Classes de cor (paleta V6): camisa (verde-azulado), calca (cinza), pele, cabelo, marrom (colete/botas), contorno.
Pecas:
  camisa_*  : troca so a camisa (matiz/saturacao/brilho, mantem o sombreado)
  calca_*   : troca so a calca
  adam_peito/adam_grevas: camisa+colete / calca+botas -> paleta metalica da armadura v99 (quantil de
              luminancia, mesmo metodo de tools/vale_armadura.py)
  capacetes : (aposentados) eram PROVISORIOS desenhados por codigo; hoje capuz_couro/elmo_* e as armaduras
              couro_cacador/malha_guarda vem do PixelLab via tools/vale_pecas_pixellab.py (que importa este modulo).
Uso: python tools/vale_trajes.py <raiz do projeto>"""
import os, sys, json, glob, colorsys
import numpy as np
from PIL import Image
R = sys.argv[1] if len(sys.argv) > 1 else '.'
# arte base da vila/fazenda/masmorra: Vale unica (desenho do combate, 20/10/2026). Antes: original_vale_v6
BASE_VILA = 'vale_unica'
V = os.path.join(R, 'art/characters/%s/' % BASE_VILA)
PAL = os.path.join(R, 'art/characters/vale_combate_v6pal/')
ADAM = os.path.join(R, 'art/characters/experimental_adamantium_v99/rotations/')
OUT = os.path.join(R, 'art/characters/vale_trajes/')
MOVS = ['slash_combo', 'dash', 'hit', 'special']
DIRS6 = ['east', 'north-east', 'north-west', 'south-east', 'south-west', 'west']
COL_VILA = 16

man = json.load(open(V + 'manifest.json'))
quadros = []
for a, info in man['anims'].items():
    for f in info['files']:
        if f not in quadros:
            quadros.append(f)

def carregar(p):
    return np.asarray(Image.open(p).convert('RGBA')).copy()

# ---------------------------------------------------------------- classes de cor
pos = {}
# estatistica das cores: quadros da base atual + os da V6 original (as folhas do combate usam a paleta da V6;
# assim as classes e o conjunto V6SET continuam os mesmos para o combate)
V6ORIG = os.path.join(R, 'art/characters/original_vale_v6/')
_fontes = [V + f for f in quadros]
if os.path.normpath(V) != os.path.normpath(V6ORIG):
    for _a, _i in json.load(open(V6ORIG + 'manifest.json'))['anims'].items():
        _fontes += [V6ORIG + f for f in _i['files']]
for f in _fontes:
    a = carregar(f); ys, xs = np.where(a[..., 3] > 128)
    if len(ys) == 0: continue
    y0, y1 = ys.min(), ys.max()
    for y, x in zip(ys, xs):
        pos.setdefault(tuple(int(v) for v in a[y, x, :3]), []).append((y - y0) / max(1, y1 - y0))
MEDY = {c: float(np.median(p)) for c, p in pos.items()}
_cl = {}
def classe(c):
    if c in _cl: return _cl[c]
    r, g, b = [v / 255 for v in c]; h, s, v = colorsys.rgb_to_hsv(r, g, b); h *= 360
    if v < 0.12: k = 'contorno'
    elif 125 <= h <= 200 and s > 0.18: k = 'camisa'
    elif (195 < h <= 300 and v < 0.5) or (s < 0.16 and v < 0.45): k = 'calca'
    elif s < 0.16: k = 'outro'
    elif h <= 40 or h >= 340:
        if v > 0.78 and s < 0.72 and MEDY.get(c, 0.5) >= 0.30: k = 'pele'
        else: k = 'cabelo' if MEDY.get(c, 0.5) < 0.40 else 'marrom'
    else: k = 'outro'
    _cl[c] = k
    return k
V6SET = set(MEDY.keys())

def mapas(a, so_paleta=False):
    """classes por pixel de UM quadro (celula). so_paleta: combate -> efeitos fora da paleta V6 ignorados"""
    H, W = a.shape[:2]
    k = np.full((H, W), '', dtype=object)
    m = a[..., 3] > 128
    ys, xs = np.where(m)
    for y, x in zip(ys, xs):
        c = tuple(int(v) for v in a[y, x, :3])
        if so_paleta and c not in V6SET: continue
        k[y, x] = classe(c)
    corpo = k != ''
    if not corpo.any(): return k, None
    yy = np.where(corpo.any(1))[0]; y0, y1 = yy.min(), yy.max()
    rel = (np.arange(H)[:, None] - y0) / max(1, y1 - y0) * np.ones((1, W))
    return k, rel

def mascaras(a, so_paleta=False):
    k, rel = mapas(a, so_paleta)
    H, W = k.shape
    z = np.zeros((H, W), bool)
    if rel is None: return {n: z for n in ['camisa', 'calca', 'colete', 'botas', 'cabelo']}
    # rel >= 0.38: os olhos da Vale unica (desenho do combate) sao verde-azulados como a camisa
    camisa = (k == 'camisa') & (rel >= 0.38)
    calca = (k == 'calca') & (rel > 0.35)
    marrom = k == 'marrom'
    cab = k == 'cabelo'
    botas = (marrom | cab) & (rel >= 0.82)
    # colete: marrom que NAO esta no meio do cabelo (vizinhanca 5x5 com maioria cabelo = reflexo do cabelo)
    colete = np.zeros_like(marrom)
    for y, x in zip(*np.where(marrom & (rel < 0.82) & (rel > 0.25))):
        jan = k[max(0, y - 2):y + 3, max(0, x - 2):x + 3]
        nc = np.sum(jan == 'cabelo'); nm = np.sum((jan == 'marrom') | (jan == 'camisa') | (jan == 'calca'))
        if nm >= nc: colete[y, x] = True
    cabelo = (cab | (marrom & ~colete)) & (rel < 0.6)
    if so_paleta:
        # combate: a lamina da espada usa tons da camisa/calca depois do remapeamento V6 -> tirar
        # componentes longe do tronco (fora da largura da cabeca) ou finos e compridos (linha da lamina)
        camisa = sem_espada(camisa, cabelo)
        calca = sem_espada(calca, cabelo)
        botas = sem_espada(botas, cabelo)
        colete = sem_espada(colete, cabelo)
    return {'camisa': camisa, 'calca': calca, 'colete': colete, 'botas': botas, 'cabelo': cabelo}

from scipy import ndimage
def sem_espada(m, cabelo):
    if not m.any() or not cabelo.any(): return m
    ys, xs = np.where(cabelo); hx0, hx1 = xs.min(), xs.max(); hw = hx1 - hx0 + 1
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    out = np.zeros_like(m)
    for i in range(1, n + 1):
        c = lab == i; yy, xx = np.where(c)
        bw, bh = xx.max() - xx.min() + 1, yy.max() - yy.min() + 1
        dens = len(yy) / float(bw * bh)
        cx = xx.mean()
        fora = cx < hx0 - 0.35 * hw or cx > hx1 + 0.35 * hw
        fino = max(bw, bh) >= 6 and dens < 0.34
        if not (fora or fino): out |= c
    return out

# ---------------------------------------------------------------- recolores
def hsv_troca(a, m, hue, ks=1.0, kv=1.0, mistura=0.25, smin=0.0):
    out = np.zeros_like(a)
    for y, x in zip(*np.where(m)):
        r, g, b = a[y, x, :3] / 255.0
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        h2 = (hue / 360.0 + (h - 160 / 360.0) * mistura) % 1.0
        s2 = min(1.0, max(smin, s * ks)); v2 = min(1.0, v * kv)
        rr, gg, bb = colorsys.hsv_to_rgb(h2, s2, v2)
        out[y, x] = [round(rr * 255), round(gg * 255), round(bb * 255), 255]
    return out

def lum(rgb): return rgb @ np.array([0.299, 0.587, 0.114])
arm = []
for f in glob.glob(ADAM + '*.png'):
    a = carregar(f); ys, xs = np.where(a[..., 3] > 128)
    y0, y1 = ys.min(), ys.max(); corte = y0 + 0.45 * (y1 - y0)
    sel = (a[..., 3] > 128) & (np.arange(a.shape[0])[:, None] > corte)
    arm.append(a[sel][:, :3])
arm = np.concatenate(arm).astype(float); ARML = np.sort(lum(arm))
cnt = {}
for c in map(tuple, arm.astype(int)): cnt[c] = cnt.get(c, 0) + 1
# so tons metalicos (azulados/cinza): fora pele e cabelo que aparecem abaixo do corte
AP = np.array([c for c, n in cnt.items() if n >= 3 and c[2] >= c[0] - 6], float); APL = lum(AP)
ARML = np.sort(lum(AP.repeat([max(1, cnt[tuple(int(v) for v in c)]) for c in AP], axis=0)))
REF_L = []  # luminancia de referencia (todas as roupas da vila) para os quantis
def metal(a, m, brilho=0.55):
    out = np.zeros_like(a)
    if not m.any(): return out
    L = lum(a[..., :3][m].astype(float))
    q = np.searchsorted(REF_L, L) / len(REF_L)
    q = np.where(q < 0.10, q, 0.10 + 0.90 * (np.clip(q - 0.10, 0, None) / 0.90) ** brilho)
    alvo = ARML[np.clip((q * len(ARML)).astype(int), 0, len(ARML) - 1)]
    i = np.abs(APL[None, :] - alvo[:, None]).argmin(1)
    s = out[..., :3]; s[m] = AP[i].astype(np.uint8); out[..., :3] = s; out[..., 3][m] = 255
    return out

# ---------------------------------------------------------------- capacetes (provisorios)
CAPACETES = {
    # tom (rgb escuro, medio, claro), fracao do cabelo coberta, aro, detalhe
    'capuz_couro': {'tons': [(74, 46, 30), (128, 84, 50), (176, 128, 80)], 'cobre': 0.58, 'aro': (150, 104, 62), 'detalhe': 'costura'},
    'elmo_ferro': {'tons': [(62, 66, 74), (118, 124, 134), (184, 190, 198)], 'cobre': 0.62, 'aro': (214, 218, 224), 'detalhe': 'nasal'},
    'elmo_adamantium': {'tons': None, 'cobre': 0.62, 'aro': (150, 236, 255), 'detalhe': 'crista'},
}
FRENTE = {'south': 0.0, 'south-east': 0.3, 'south-west': -0.3, 'east': 0.85, 'west': -0.85}
def capacete(a, mk, nome, direcao):
    cfg = CAPACETES[nome]; out = np.zeros_like(a)
    H, W = a.shape[:2]
    cab = mk['cabelo']
    if cab.sum() < 6: return out
    ys, xs = np.where(cab); y0, y1 = ys.min(), ys.max(); hh = y1 - y0 + 1
    lim = y0 + max(3, int(round(cfg['cobre'] * hh)))
    cap = (cab | mk['colete']) & (np.arange(H)[:, None] < lim) & (np.arange(H)[:, None] >= y0)
    if cap.sum() == 0: return out
    # volume: 1 px a mais em cima e dos lados (sobre fundo transparente ou cabelo), nunca para baixo
    livre = (a[..., 3] < 128) | cab
    cap2 = cap.copy()
    for dy, dx in ((-1, 0), (0, -1), (0, 1)):
        sh = np.zeros_like(cap)
        ys0, ys1 = max(0, -dy), H - max(0, dy)
        xs0, xs1 = max(0, -dx), W - max(0, dx)
        sh[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = cap[ys0:ys1, xs0:xs1]
        cap2 |= sh & livre & (np.arange(H)[:, None] < lim)
    yy, xx = np.where(cap2)
    cx0, cx1 = xx.min(), xx.max(); top = yy.min(); meio = (cx0 + cx1) / 2.0; w = max(1.0, (cx1 - cx0) / 2.0)
    capH = max(1, lim - top)
    if cfg['tons'] is None:
        tons = [tuple(AP[np.abs(APL - ARML[int(q * (len(ARML) - 1))]).argmin()].astype(int)) for q in (0.30, 0.62, 0.95)]
    else:
        tons = cfg['tons']
    luz = -0.35 if direcao not in ('west', 'south-west', 'north-west') else 0.35
    base = {}
    for y, x in zip(yy, xx):
        base[x] = max(base.get(x, -1), y)
    for y, x in zip(yy, xx):
        u = (x - meio) / w; v = (y - top) / capH
        if abs(u - luz) < 0.32 and v < 0.55: c = tons[2]
        elif abs(u) > 0.72 or v > 0.78: c = tons[0]
        else: c = tons[1]
        out[y, x, :3] = c; out[y, x, 3] = 255
    # contorno: borda do capacete (exceto a linha do aro, que fica clara)
    for y, x in zip(yy, xx):
        viz = [(y - 1, x), (y, x - 1), (y, x + 1)]
        if any(not (0 <= j < H and 0 <= i < W) or not cap2[j, i] for j, i in viz):
            out[y, x, :3] = (26, 15, 14)
    for x, y in base.items():
        if 0 < x - cx0 and x < cx1:
            out[y, x, :3] = cfg['aro']
        if y + 1 < H and a[y + 1, x, 3] > 128 and not cap2[y + 1, x]:
            out[y + 1, x] = [26, 15, 14, 255] if cfg['detalhe'] != 'costura' else [58, 34, 22, 255]
    d = cfg['detalhe']
    topo = {}
    for y, x in zip(yy, xx):
        topo[x] = min(topo.get(x, 99), y)
    if d == 'nasal' and direcao in FRENTE:
        nx = int(round(meio + FRENTE[direcao] * w * 0.8))
        nx = min(max(nx, cx0 + 1), cx1 - 1)
        yb = base.get(nx, lim - 1)
        for k in range(1, 5):
            if yb + k < H and a[yb + k, nx, 3] > 128:
                out[yb + k, nx] = [26, 15, 14, 255] if k == 4 else [170, 176, 186, 255]
    elif d == 'costura':
        for x, y in base.items():
            if x % 2 == 0 and y - 1 >= 0 and cap2[y - 1, x] and y - 1 > top:
                out[y - 1, x, :3] = (214, 172, 112)
    elif d == 'crista':
        lado = direcao in ('east', 'west')
        sel = sorted(topo) if lado else [x for x in sorted(topo) if abs(x - meio) <= 1.0]
        if lado:
            sel = [x for x in sel if abs(x - meio) <= w * 0.7]
        for x in sel:
            y = topo[x]
            for k, c in ((0, (120, 230, 255)), (1, (200, 250, 255)), (2, (26, 15, 14))):
                if y - k >= 0 and (k == 0 or a[y - k, x, 3] < 128 or cab[y - k, x]):
                    out[y - k, x] = list(c) + [255]
    return out

# ---------------------------------------------------------------- pecas
def peca_camada(nome, a, mk, direcao):
    if nome == 'camisa_azul': return hsv_troca(a, mk['camisa'], 218, 1.25, 1.0)
    if nome == 'camisa_vermelha': return hsv_troca(a, mk['camisa'], 356, 1.45, 1.02, 0.15, 0.45)
    if nome == 'camisa_cinzas': return hsv_troca(a, mk['camisa'], 268, 0.55, 0.82)
    if nome == 'calca_anil': return hsv_troca(a, mk['calca'], 226, 1.0, 1.35, 0.1, 0.42)
    if nome == 'calca_caqui': return hsv_troca(a, mk['calca'], 38, 1.0, 1.85, 0.1, 0.30)
    if nome == 'adam_peito': return metal(a, mk['camisa'] | mk['colete'])
    if nome == 'adam_grevas': return metal(a, mk['calca'] | mk['botas'])
    if nome in CAPACETES: return capacete(a, mk, nome, direcao)
    raise KeyError(nome)
# capacetes provisorios (CAPACETES/capacete) aposentados: as camadas capuz_couro/elmo_* agora vem da arte do PixelLab
# (tools/vale_pecas_pixellab.py). Para voltar aos provisorios: + list(CAPACETES)
PECAS = ['camisa_azul', 'camisa_vermelha', 'camisa_cinzas', 'calca_anil', 'calca_caqui', 'adam_peito', 'adam_grevas']

def dir_de(f):
    p = f.split('/')
    return p[1] if p[0] != 'rotations' else p[1][:-4]

# referencia de luminancia das roupas (vila)
mk_vila = {}
base_vila = {}
for f in quadros:
    a = carregar(V + f); base_vila[f] = a; mk_vila[f] = mascaras(a)
    m = mk_vila[f]['camisa'] | mk_vila[f]['colete'] | mk_vila[f]['calca'] | mk_vila[f]['botas']
    REF_L.extend(lum(a[..., :3][m].astype(float)).tolist())
REF_L = np.sort(np.array(REF_L))

if __name__ == '__main__':  # importavel (tools/vale_pecas_pixellab.py usa as classes/mascaras)
    os.makedirs(OUT, exist_ok=True)
    linhas = (len(quadros) + COL_VILA - 1) // COL_VILA
    indice = {'versao': 1, 'vila': {'base': 'res://art/characters/%s/' % BASE_VILA, 'celula': 48, 'colunas': COL_VILA, 'quadros': quadros},
              'combate': {'base': 'res://art/characters/vale_combate_v6pal/', 'celula': 112, 'colunas': 8, 'total': 49,
                          'folhas': ['%s/%s_%s_sheet.png' % (m, m, d) for m in MOVS for d in DIRS6]},
              'camadas': {}}
    # mantem no indice as camadas feitas por outras ferramentas (ex. pecas do PixelLab)
    if os.path.exists(OUT + 'indice.json'):
        for k, v in json.load(open(OUT + 'indice.json', encoding='utf-8')).get('camadas', {}).items():
            if k not in PECAS: indice['camadas'][k] = v
    so_vila = '--so-vila' in sys.argv
    for p in PECAS:
        os.makedirs(OUT + 'camadas/' + p + '/combate', exist_ok=True)
        atlas = np.zeros((linhas * 48, COL_VILA * 48, 4), np.uint8)
        for i, f in enumerate(quadros):
            c = peca_camada(p, base_vila[f], mk_vila[f], dir_de(f))
            x, y = (i % COL_VILA) * 48, (i // COL_VILA) * 48
            atlas[y:y + 48, x:x + 48] = c
        Image.fromarray(atlas).save(OUT + 'camadas/%s/vila.png' % p, optimize=True)
        print('vila', p, int((atlas[..., 3] > 0).sum()), 'px')
        indice['camadas'][p] = {'vila': 'camadas/%s/vila.png' % p, 'combate': 'camadas/%s/combate/' % p}
    json.dump(indice, open(OUT + 'indice.json', 'w'), indent=1, ensure_ascii=False)
    if so_vila: sys.exit(0)
    for folha in indice['combate']['folhas']:
        s = carregar(PAL + folha); H, W = s.shape[:2]
        d = folha.split('/')[1].replace('_sheet.png', '').split('_')[-1]
        cel = []
        for i in range(49):
            cx, cy = (i % 8) * 112, (i // 8) * 112
            a = s[cy:cy + 112, cx:cx + 112]
            cel.append((cx, cy, a, mascaras(a, True)))
        for p in PECAS:
            out = np.zeros_like(s)
            for cx, cy, a, mk in cel:
                out[cy:cy + 112, cx:cx + 112] = peca_camada(p, a, mk, d)
            Image.fromarray(out).save(OUT + 'camadas/%s/combate/%s' % (p, os.path.basename(folha)), optimize=True)
        print('combate', folha)
    print('ok', len(PECAS), 'camadas,', len(quadros), 'quadros vila')
