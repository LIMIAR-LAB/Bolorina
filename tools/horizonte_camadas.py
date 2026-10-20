"""Camadas do horizonte vivo (codigo, original): mesmo lugar da Vila/Fazenda flutuante.
- art/environment/horizonte_base.png : ilhas distantes + mar de nuvens (fixo; o clima so tinge)
- art/environment/ilha_flutuante_1..3.png : ilhas que derivam no ceu (camadas separadas)
Paleta da cena: grama 6f9a3e/8db552, folhas outono c8402a/e07a2a/f0a040, arvore escura 2f4a2a,
rocha lilas 6b5a6e/4e4258/3a3045 (cores das capturas da vila). Uso: python tools/horizonte_camadas.py [projeto]"""
import sys, os, math, random
from PIL import Image, ImageDraw, ImageFilter

raiz = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(raiz, 'art', 'environment')
os.makedirs(OUT, exist_ok=True)

def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

GRAMA, GRAMA_L = hexc('6f9a3e'), hexc('9cc45a')
TERRA = hexc('7a5a3e')
ROCHA = [hexc('7a6a7e'), hexc('5e5068'), hexc('463a52'), hexc('342a3e')]
FOLHAS = [hexc('c8402a'), hexc('e07a2a'), hexc('f0a040'), hexc('2f4a2a'), hexc('3d6a34'), hexc('a3302a')]

def ilha(d, cx, top, larg, prof, rng, haze=None, ht=0.0, detalhe=True, extra=None):
    """desenha uma ilha flutuante: topo de grama, base de rocha em cone irregular, arvores low-poly"""
    c = (lambda col: mix(col, haze, ht)) if haze else (lambda col: col)
    # base de rocha (cone serrilhado)
    pts = [(cx - larg / 2, top)]
    n = 9
    for i in range(1, n):
        t = i / n
        x = cx - larg / 2 + larg * t
        y = top + prof * (1 - abs(t - 0.5) * 2) ** 0.8 * rng.uniform(0.7, 1.0) + rng.uniform(4, 14)
        pts.append((x, y))
    pts.append((cx + larg / 2, top))
    d.polygon(pts, fill=c(ROCHA[2]))
    # estratos (faixas mais claras em cima)
    for k, frac in enumerate([0.18, 0.4]):
        sub = [(x, top + (y - top) * frac) for x, y in pts]
        d.polygon(pts[:1] + sub[1:-1] + pts[-1:], fill=c(ROCHA[k]))
    # lado sombreado (direita)
    d.polygon([(cx + larg * 0.05, top + 4)] + [p for p in pts if p[0] > cx + larg * 0.05] , fill=c(ROCHA[3]))
    # terra + grama
    d.rectangle([cx - larg / 2, top - 2, cx + larg / 2, top + 7], fill=c(TERRA))
    d.ellipse([cx - larg / 2 - 4, top - 12, cx + larg / 2 + 4, top + 6], fill=c(GRAMA))
    d.ellipse([cx - larg / 2 + 6, top - 12, cx + larg / 2 - 10, top - 1], fill=c(GRAMA_L))
    if extra == 'ruina':
        bx = cx + larg * 0.18
        for dx in (0, 26):
            d.rectangle([bx + dx, top - 46, bx + dx + 8, top - 4], fill=c(ROCHA[0]))
        d.rectangle([bx - 3, top - 52, bx + 37, top - 44], fill=c(ROCHA[1]))
    if extra == 'cascata':
        x0 = cx - larg * 0.22
        d.rectangle([x0, top + 2, x0 + 6, top + prof * 1.25], fill=c(hexc('cfe6f2')))
        d.rectangle([x0 + 1, top + 2, x0 + 3, top + prof * 1.25], fill=c(hexc('ffffff')))
    # arvores low-poly (triangulos como as folhas da cena)
    if detalhe:
        for i in range(rng.randint(3, 6)):
            tx = cx + rng.uniform(-larg * 0.38, larg * 0.32)
            th = rng.uniform(26, 46) * larg / 220
            d.rectangle([tx - 2, top - th * 0.5, tx + 2, top - 4], fill=c(hexc('4a3426')))
            base = rng.choice(FOLHAS)
            for j in range(16):
                ax = tx + rng.uniform(-th * 0.45, th * 0.45)
                ay = top - th * 0.55 + rng.uniform(-th * 0.45, th * 0.3)
                s = rng.uniform(5, 10) * larg / 220
                col = mix(base, rng.choice(FOLHAS), 0.25)
                col = mix(col, (255, 230, 190), 0.25) if ay < top - th * 0.7 else col
                d.polygon([(ax, ay - s), (ax + s, ay + s * 0.6), (ax - s, ay + s * 0.4)], fill=c(col))

# ------------------------------------------------ base: ilhas distantes + mar de nuvens
W, H = 2400, 600
rng = random.Random(1907)
base = Image.new('RGBA', (W, H), (0, 0, 0, 0))
HAZE = hexc('c9cfe0')
for fila, (y0, esc, ht) in enumerate([(250, 0.55, 0.72), (300, 0.8, 0.55)]):
    camada = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)
    x = rng.uniform(-80, 120)
    while x < W + 100:
        larg = rng.uniform(140, 320) * esc
        ilha(d, x, y0 + rng.uniform(-30, 25), larg, larg * rng.uniform(0.45, 0.75), rng, HAZE, ht, True,
             rng.choice([None, None, 'ruina', 'cascata']))
        x += larg + rng.uniform(140, 420) * esc
    base.alpha_composite(camada.filter(ImageFilter.GaussianBlur(1.6 - fila * 0.6)))
# mar de nuvens: fileiras de "couves-flor" claras em cima, mais densas embaixo
d = ImageDraw.Draw(base)
for fila in range(9):
    y = 330 + fila * 30
    luz = mix(hexc('ffffff'), hexc('b8bfd6'), fila / 9)
    sombra = mix(hexc('d7dbe8'), hexc('9aa1bd'), fila / 9)
    x = rng.uniform(-60, 0)
    while x < W + 60:
        r = rng.uniform(28, 64) * (1 + fila * 0.08)
        d.ellipse([x - r, y - r * 0.55 + 8, x + r, y + r * 0.9], fill=sombra + (255,))
        d.ellipse([x - r * 0.9, y - r * 0.6, x + r * 0.8, y + r * 0.55], fill=luz + (255,))
        x += r * rng.uniform(0.9, 1.4)
d.rectangle([0, 330 + 8 * 30 + 10, W, H], fill=hexc('a7aec8') + (255,))
nuvens = base.filter(ImageFilter.GaussianBlur(0.8))
base = nuvens
base.save(os.path.join(OUT, 'horizonte_base.png'), optimize=True)
print('base', base.size)

# ------------------------------------------------ ilhas flutuantes (camadas que derivam)
for i, (larg, extra, sem) in enumerate([(240, 'ruina', 11), (180, 'cascata', 23), (300, None, 37)], 1):
    r = random.Random(sem)
    im = Image.new('RGBA', (int(larg + 80), int(larg * 1.25 + 90)), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ilha(d, im.width / 2, 70, larg, larg * 0.8, r, None, 0.0, True, extra)
    # pedrinhas soltas embaixo
    for k in range(3):
        px, py, s = im.width / 2 + r.uniform(-larg * 0.3, larg * 0.3), 70 + larg * r.uniform(0.85, 1.1), r.uniform(5, 11)
        d.polygon([(px - s, py), (px, py - s * 0.6), (px + s, py), (px, py + s * 1.3)], fill=ROCHA[2])
    im = im.crop(im.getbbox())
    im.save(os.path.join(OUT, 'ilha_flutuante_%d.png' % i), optimize=True)
    print('ilha', i, im.size)
