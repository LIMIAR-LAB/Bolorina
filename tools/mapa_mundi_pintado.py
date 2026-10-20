"""Mapa-mundi pintado (1200x800) a partir do registro de areas (data/areas.json). Local, sem custo.
Saida: art/ui/mapa_mundi_pintado.png + art/ui/mapa_mundi_pintado.json (mesmo formato de mapa_mundi.json:
centro/raio/mundo/estado por area, lido por scripts/ilha/mapa_mundi.gd). O esquematico antigo
(tools/mapa_esquematico.py -> art/ui/mapa_esquematico.png) continua intacto.
Uso: python tools/mapa_mundi_pintado.py <raiz>"""
import os, sys, json, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

R = sys.argv[1] if len(sys.argv) > 1 else '.'
K = 2                      # desenha em 2x e reduz (bordas suaves)
W, H = 1200 * K, 800 * K
random.seed(20261020)
np.random.seed(20261020)
areas = [a for a in json.load(open(os.path.join(R, 'data/areas.json'), encoding='utf-8'))['areas'] if not a.get('oculto')]


def fonte(tam, negrito=True):
    for f in (['C:/Windows/Fonts/georgiab.ttf', 'C:/Windows/Fonts/timesbd.ttf'] if negrito else
              ['C:/Windows/Fonts/georgia.ttf', 'C:/Windows/Fonts/times.ttf']):
        if os.path.exists(f):
            return ImageFont.truetype(f, tam)
    return ImageFont.load_default()


def ruido(w, h, escalas=(64, 32, 16, 8), pesos=(0.5, 0.25, 0.15, 0.1)):
    out = np.zeros((h, w))
    for e, p in zip(escalas, pesos):
        g = np.random.rand(h // e + 2, w // e + 2)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((w + e, h + e), Image.BICUBIC)
        out += np.asarray(im, float)[:h, :w] / 255 * p
    return out / sum(pesos)


# ---------------------------------------------------------------- forma das ilhas (campo de altura)
yy, xx = np.mgrid[0:H, 0:W].astype(float)
n = ruido(W, H, (160 * K, 80 * K, 40 * K, 12 * K), (0.45, 0.3, 0.17, 0.08))


def elipse(cx, cy, rx, ry):
    return 1 - np.sqrt(((xx - cx * K) / (rx * K)) ** 2 + ((yy - cy * K) / (ry * K)) ** 2)


alt = elipse(600, 420, 520, 330)
alt = np.maximum(alt, elipse(560, 170, 260, 150) * 0.9)          # serra do norte
alt = np.maximum(alt, elipse(230, 330, 190, 170) * 0.95)         # oeste (cidade fantasma)
alt = np.maximum(alt, elipse(830, 610, 170, 120) * 0.95)         # porto (sudeste)
alt = alt + (n - 0.5) * 0.55
ilha = alt > 0.08
orcs = (elipse(1075, 255, 92, 70) + (n - 0.5) * 0.5) > 0.05       # ilhota dos orcs
futuro = (elipse(1040, 680, 92, 52) + (n - 0.5) * 0.35) > 0.12    # ilha flutuante
terra = ilha | orcs

# ---------------------------------------------------------------- mar
img = np.zeros((H, W, 3), float)
dist_terra = np.asarray(Image.fromarray((terra * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(46 * K)), float) / 255
fundo = np.array([24, 44, 74]); raso = np.array([58, 112, 140])
t = np.clip(dist_terra * 2.2, 0, 1)[..., None]
img[:] = fundo * (1 - t) + raso * t
img += ((ruido(W, H, (48 * K, 16 * K), (0.6, 0.4)) - 0.5) * 18)[..., None]

# ---------------------------------------------------------------- terra: praia, campo, mato, montanha
sombra = np.asarray(Image.fromarray(((alt.clip(0, 1)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3 * K)), float) / 255
gx = np.gradient(sombra, axis=1); gy = np.gradient(sombra, axis=0)
luz = np.clip(0.5 - (gx + gy) * 260, 0, 1)
v = ruido(W, H, (90 * K, 30 * K, 10 * K), (0.5, 0.3, 0.2))
praia = terra & ~(np.asarray(Image.fromarray((terra * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(9 * K - 1 if (9 * K) % 2 == 0 else 9 * K)), float) > 0)
campo = np.array([128, 158, 86]); campo2 = np.array([96, 132, 70]); seco = np.array([178, 160, 104])
cor = campo * (1 - v[..., None]) + campo2 * v[..., None]
norte = np.clip((300 * K - yy) / (220 * K), 0, 1)[..., None]
cor = cor * (1 - norte * 0.55) + np.array([128, 118, 104]) * norte * 0.55      # rocha ao norte
oeste = np.clip((380 * K - xx) / (260 * K), 0, 1)[..., None] * np.clip((yy - 140 * K) / (120 * K), 0, 1)[..., None] * (yy < 470 * K)[..., None]
cor = cor * (1 - oeste * 0.6) + np.array([110, 112, 120]) * oeste * 0.6         # charneca da cidade fantasma
cor = cor * (0.82 + 0.3 * luz[..., None])
img[terra] = cor[terra]
img[praia] = (np.array([222, 204, 150]) * (0.9 + 0.12 * v[praia][:, None]))
# contorno da costa + espuma
borda = np.asarray(Image.fromarray((terra * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES), float) > 0
espuma = np.asarray(Image.fromarray((borda * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7)), float) > 0
img[espuma & ~terra] = img[espuma & ~terra] * 0.4 + np.array([236, 240, 236]) * 0.6
img[borda] = [70, 56, 40]

pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(pil, 'RGBA')

# ---------------------------------------------------------------- ilha flutuante (sombra no mar + nuvens)
sm = Image.fromarray((futuro * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10 * K))
pil.paste((14, 26, 46), (int(30 * K), int(40 * K)), Image.fromarray((np.asarray(sm) * 0.45).astype(np.uint8)))
fut = np.asarray(pil).copy()
fv = ruido(W, H, (40 * K, 12 * K), (0.6, 0.4))
fut[futuro] = (np.array([150, 170, 190]) * (0.8 + 0.3 * fv[futuro][:, None])).astype(np.uint8)
fb = np.asarray(Image.fromarray((futuro * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES)) > 0
fut[fb] = [60, 230, 255]
pil = Image.fromarray(fut)
d = ImageDraw.Draw(pil, 'RGBA')
for i in range(14):
    cx = random.uniform(980, 1110) * K; cy = random.uniform(640, 730) * K
    r = random.uniform(10, 22) * K
    d.ellipse([cx - r * 1.6, cy - r, cx + r * 1.6, cy + r], fill=(255, 255, 255, 46))

# ---------------------------------------------------------------- relevo: montanhas, florestas, rio
def montanha(cx, cy, s):
    cx *= K; cy *= K; s *= K
    d.polygon([(cx - s, cy), (cx, cy - s * 1.25), (cx + s, cy)], fill=(112, 104, 98))
    d.polygon([(cx, cy - s * 1.25), (cx + s, cy), (cx + s * 0.15, cy)], fill=(84, 76, 72))
    d.polygon([(cx - s * 0.32, cy - s * 0.85), (cx, cy - s * 1.25), (cx + s * 0.33, cy - s * 0.83), (cx + s * 0.08, cy - s * 0.7), (cx - s * 0.1, cy - s * 0.78)], fill=(240, 240, 236))
    d.line([(cx - s, cy), (cx, cy - s * 1.25), (cx + s, cy)], fill=(52, 42, 36), width=2 * K)

for cx, cy, s in [(470, 150, 34), (520, 112, 44), (600, 96, 50), (680, 118, 40), (735, 150, 30), (420, 190, 26), (560, 170, 26), (650, 175, 24), (760, 196, 22)]:
    montanha(cx, cy, s)


def arvore(cx, cy, s, c=(52, 96, 52)):
    cx *= K; cy *= K; s *= K
    d.ellipse([cx - s, cy - s * 1.3, cx + s, cy + s * 0.5], fill=c + (255,), outline=(30, 52, 30), width=K)
    d.line([(cx, cy + s * 0.5), (cx, cy + s * 0.95)], fill=(70, 46, 30), width=K)

for _ in range(150):
    x = random.gauss(250, 55); y = random.gauss(520, 50)
    if 120 < x < 330 and 430 < y < 620:
        arvore(x, y, random.uniform(5, 8))
for _ in range(60):
    x = random.gauss(170, 40); y = random.gauss(330, 60)
    if 90 < x < 290 and 220 < y < 440:
        arvore(x, y, random.uniform(5, 7), (70, 78, 74))       # arvores secas da nevoa
for _ in range(40):
    x = random.gauss(980, 50); y = random.gauss(470, 60)
    if 900 < x < 1080 and 380 < y < 560:
        arvore(x, y, random.uniform(4, 7))
rio = [(585, 200), (575, 260), (596, 330), (612, 400), (630, 470), (655, 540), (690, 620), (705, 700), (712, 780)]
d.line([(x * K, y * K) for x, y in rio], fill=(70, 130, 176), width=7 * K, joint='curve')
d.line([(x * K, y * K) for x, y in rio], fill=(120, 176, 210), width=3 * K, joint='curve')
# nevoa da cidade fantasma
for _ in range(26):
    cx = random.gauss(215, 70) * K; cy = random.gauss(300, 50) * K; r = random.uniform(18, 40) * K
    d.ellipse([cx - r * 1.8, cy - r * 0.6, cx + r * 1.8, cy + r * 0.6], fill=(220, 226, 236, 34))
# ondas no mar
for _ in range(120):
    x = random.uniform(20, 1180) * K; y = random.uniform(20, 780) * K
    if not terra[int(min(H - 1, y)), int(min(W - 1, x))] and dist_terra[int(min(H - 1, y)), int(min(W - 1, x))] < 0.35:
        d.arc([x, y, x + 16 * K, y + 7 * K], 200, 340, fill=(190, 214, 230, 120), width=K)

# ---------------------------------------------------------------- trilhas entre areas
pos = {a['id']: a['mapa'] for a in areas}
trilhas = [('fazenda', 'vila'), ('vila', 'arena'), ('vila', 'masmorra'), ('vila', 'porto_velho'), ('masmorra', 'minas_cinza'),
           ('fazenda', 'cidade_fantasma'), ('arena', 'vila_orcs'), ('porto_velho', 'ilha_futurista')]
for a, b in trilhas:
    (x0, y0), (x1, y1) = pos[a], pos[b]
    mar = a in ('arena', 'porto_velho') and b in ('vila_orcs', 'ilha_futurista')
    pts = []
    for i in range(41):
        t_ = i / 40
        mx = x0 + (x1 - x0) * t_ + math.sin(t_ * math.pi) * (y1 - y0) * 0.12
        my = y0 + (y1 - y0) * t_ - math.sin(t_ * math.pi) * (x1 - x0) * 0.08
        pts.append((mx * K, my * K))
    for i in range(0, 40, 2):
        d.line([pts[i], pts[i + 1]], fill=(250, 250, 255, 200) if mar else (96, 66, 38, 230), width=(3 if mar else 4) * K)

# ---------------------------------------------------------------- marcadores das areas
f_nome = fonte(19 * K); f_pequena = fonte(13 * K, False)
saida = {}
for a in areas:
    disp = any(a.get(k) is not None and os.path.exists(os.path.join(R, a[k].replace('res://', '')))
               for k in ('cena', 'cena_provisoria'))
    cx, cy = a['mapa']; rx, ry = a['raio']
    cx_, cy_ = cx * K, cy * K
    # selo circular
    rr = 17 * K
    d.ellipse([cx_ - rr - 3 * K, cy_ - rr - 3 * K, cx_ + rr + 3 * K, cy_ + rr + 3 * K], fill=(40, 28, 20, 220))
    cor = {'campo': (122, 168, 84), 'vila': (206, 160, 98), 'arena': (192, 98, 72), 'montanha': (140, 132, 126),
           'porto': (82, 140, 186), 'orc': (120, 150, 70), 'fantasma': (170, 176, 200), 'ceu': (90, 220, 250)}.get(a.get('bioma'), (200, 180, 120))
    if not disp:
        cor = tuple(int(c * 0.55 + 70) for c in cor)
    d.ellipse([cx_ - rr, cy_ - rr, cx_ + rr, cy_ + rr], fill=cor + (255,), outline=(250, 236, 200), width=2 * K)
    # icone simples por tipo
    b = a.get('bioma')
    if b in ('vila', 'campo', 'porto'):
        d.polygon([(cx_ - 8 * K, cy_ + 2 * K), (cx_, cy_ - 8 * K), (cx_ + 8 * K, cy_ + 2 * K)], fill=(150, 56, 40))
        d.rectangle([cx_ - 6 * K, cy_ + 2 * K, cx_ + 6 * K, cy_ + 9 * K], fill=(240, 222, 180))
    elif b == 'arena':
        d.ellipse([cx_ - 9 * K, cy_ - 6 * K, cx_ + 9 * K, cy_ + 6 * K], outline=(250, 220, 120), width=2 * K)
    elif b == 'montanha':
        d.polygon([(cx_ - 10 * K, cy_ + 7 * K), (cx_, cy_ - 9 * K), (cx_ + 10 * K, cy_ + 7 * K)], fill=(70, 62, 58))
    elif b == 'orc':
        d.rectangle([cx_ - 8 * K, cy_ - 2 * K, cx_ + 8 * K, cy_ + 8 * K], fill=(110, 70, 40))
        d.polygon([(cx_ - 10 * K, cy_ - 2 * K), (cx_, cy_ - 10 * K), (cx_ + 10 * K, cy_ - 2 * K)], fill=(80, 54, 30))
    elif b == 'fantasma':
        d.ellipse([cx_ - 7 * K, cy_ - 9 * K, cx_ + 7 * K, cy_ + 5 * K], fill=(246, 248, 255))
        d.ellipse([cx_ - 4 * K, cy_ - 4 * K, cx_ - 1 * K, cy_ - 1 * K], fill=(40, 40, 60))
        d.ellipse([cx_ + 1 * K, cy_ - 4 * K, cx_ + 4 * K, cy_ - 1 * K], fill=(40, 40, 60))
    elif b == 'ceu':
        d.polygon([(cx_, cy_ - 10 * K), (cx_ + 8 * K, cy_), (cx_, cy_ + 10 * K), (cx_ - 8 * K, cy_)], fill=(220, 252, 255))
    # faixa com o nome
    nome = a['nome'] + ('' if disp else '  · em breve')
    fn = f_nome if disp else f_pequena
    tw = d.textlength(nome, font=fn)
    ty = cy_ + rr + 8 * K
    d.rounded_rectangle([cx_ - tw / 2 - 10 * K, ty - 3 * K, cx_ + tw / 2 + 10 * K, ty + (fn.size + 8 * K)],
                        radius=6 * K, fill=(238, 222, 184, 235 if disp else 190), outline=(86, 60, 36), width=2 * K)
    d.text((cx_ - tw / 2, ty), nome, font=fn, fill=(52, 34, 22) if disp else (100, 86, 70))
    saida[a['id']] = {'nome': a['nome'], 'centro': [cx, cy], 'raio': [rx, ry], 'mundo': a.get('mundo'),
                      'estado': 'jogavel' if disp else 'em_breve'}

# ---------------------------------------------------------------- titulo, rosa dos ventos, moldura
f_tit = fonte(34 * K)
tit = 'Ilha das Cinzas'
tw = d.textlength(tit, font=f_tit)
d.rounded_rectangle([40 * K, 26 * K, 40 * K + tw + 40 * K, 26 * K + 56 * K], radius=10 * K, fill=(238, 222, 184, 235), outline=(86, 60, 36), width=3 * K)
d.text((60 * K, 32 * K), tit, font=f_tit, fill=(60, 36, 22))
cx, cy = 1120 * K, 90 * K
for ang, l, c in [(0, 46, (250, 240, 210)), (90, 30, (210, 196, 160)), (180, 30, (210, 196, 160)), (270, 30, (210, 196, 160))]:
    a_ = math.radians(ang - 90)
    px, py = cx + math.cos(a_) * l * K, cy + math.sin(a_) * l * K
    qx, qy = math.cos(a_ + math.pi / 2) * 7 * K, math.sin(a_ + math.pi / 2) * 7 * K
    d.polygon([(px, py), (cx + qx, cy + qy), (cx - qx, cy - qy)], fill=c, outline=(60, 40, 26))
d.text((cx - 7 * K, cy - 72 * K), 'N', font=fonte(18 * K), fill=(250, 240, 210))
img = np.asarray(pil).astype(float)
vin = np.clip(1 - (((xx / W - 0.5) * 1.6) ** 2 + ((yy / H - 0.5) * 1.6) ** 2) ** 1.5 * 0.55, 0.45, 1)
img *= vin[..., None]
pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(pil)
d.rectangle([0, 0, W - 1, H - 1], outline=(86, 60, 36), width=8 * K)
d.rectangle([10 * K, 10 * K, W - 10 * K, H - 10 * K], outline=(214, 190, 140), width=2 * K)
pil = pil.resize((1200, 800), Image.LANCZOS)
os.makedirs(os.path.join(R, 'art/ui'), exist_ok=True)
pil.save(os.path.join(R, 'art/ui/mapa_mundi_pintado.png'))
json.dump(saida, open(os.path.join(R, 'art/ui/mapa_mundi_pintado.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print('ok', len(saida), 'areas')
