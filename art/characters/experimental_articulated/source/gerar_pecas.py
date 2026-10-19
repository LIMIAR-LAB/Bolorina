"""Gera as pecas originais de pixel art do personagem articulado experimental.

Ilha das Cinzas - experimento de esqueleto 3D (19/10/2026).
Desenho autoral por regras de pixel (elipses, linhas e pixels posicionados
manualmente). Nao recorta nem copia os PNGs existentes: apenas a paleta foi
amostrada de art/characters/original_apprentice/rotations/*.png para manter
coerencia com o protagonista V4. Sem servicos pagos.

Uso: python gerar_pecas.py <pasta_destino>
"""
import hashlib, json, math, os, sys
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H = lambda s: tuple(int(s[i:i+2], 16) for i in (1, 3, 5))
PAL = {
    'o': H('#010105'),
    'hair': H('#823e20'), 'hairH': H('#d37744'), 'hairS': H('#5e1d20'), 'hairD': H('#461325'),
    'skin': H('#f8c497'), 'skinS': H('#e7855e'), 'blush': H('#dd6d4c'), 'mouth': H('#c94b37'), 'white': H('#f8faf8'),
    'shirt': H('#519b72'), 'shirtH': H('#6bb27c'), 'shirtS': H('#2e5967'), 'shirtD': H('#193d4f'), 'shirtM': H('#387772'),
    'leather': H('#773422'), 'leatherH': H('#ba6733'), 'buckle': H('#e9a24d'),
    'pants': H('#261930'), 'pantsH': H('#504960'),
    'boot': H('#461325'), 'bootH': H('#773422'),
    'iron': H('#9ea7a8'), 'ironH': H('#d2d9d6'), 'ironS': H('#5a6370'),
    'wood': H('#694225'), 'woodH': H('#a06a3a'),
    'can': H('#7f9aa3'), 'canH': H('#c8d6d8'), 'canS': H('#4e6670'),
}

class Canvas:
    def __init__(self, w, h):
        self.w, self.h, self.p = w, h, {}
    def set(self, x, y, k):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[(x, y)] = k
    def has(self, x, y):
        return (x, y) in self.p
    def ellipse(self, cx, cy, rx, ry, k, cond=None):
        for y in range(self.h):
            for x in range(self.w):
                v = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if v <= 1.0 and (cond is None or cond(x, y)):
                    self.set(x, y, k)
    def rect(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, k)
    def recolor(self, fn):
        for (x, y), k in list(self.p.items()):
            n = fn(x, y, k)
            if n:
                self.p[(x, y)] = n
    def line(self, x0, y0, x1, y1, k, only_filled=True):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            if not only_filled or self.has(x, y):
                self.set(x, y, k)
    def outline(self, k='o'):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if (x, y) in self.p:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = self.p.get((x + dx, y + dy))
                    if q is not None and q != k:
                        add.append((x, y))
                        break
        for a in add:
            self.p[a] = k
        return self
    def image(self):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for (x, y), k in self.p.items():
            im.putpixel((x, y), PAL[k] + (255,))
        return im

# ---------------------------------------------------------------- cabeca
HCX, HCY, HRX, HRY = 15.0, 12.6, 13.4, 12.0

def hair_shade(c):
    def fn(x, y, k):
        if k != 'hair':
            return None
        nx = (x + 0.5 - HCX) / HRX
        ny = (y + 0.5 - HCY) / HRY
        light = -nx * 0.55 - ny * 0.83
        dark = nx * 0.6 + ny * 0.8
        if dark > 0.86:
            return 'hairD'
        if dark > 0.55:
            return 'hairS'
        if 0.52 < light < 0.82 and (x + y) % 3 != 0:
            return 'hairH'
        if y in range(3, 9) and x in (8, 13, 19, 23) and dark < 0.4:
            return 'hairS'
        return None
    c.recolor(fn)

def fringe(x):
    return 11 + [0, 1, 2, 1][x % 4]

def head(view):
    c = Canvas(30, 27)
    c.ellipse(HCX, HCY, HRX, HRY, 'hair')
    hair_shade(c)
    inside = lambda x, y: c.has(x, y)
    if view == 'south':
        fx, frx = 15.0, 9.6
    elif view == 'south-east':
        fx, frx = 17.6, 8.6
    elif view == 'east':
        fx, frx = 22.2, 6.4
    elif view == 'north-east':
        fx, frx = 26.4, 3.3
    else:
        fx = None
    if fx is not None:
        ry = 7.5 if view != 'north-east' else 5.6
        fy = 17.6 if view != 'north-east' else 18.4
        lo = {'south': 0, 'south-east': 6, 'east': 17, 'north-east': 24}[view]
        c.ellipse(fx, fy, frx, ry, 'skin', lambda x, y: inside(x, y) and y >= fringe(x) and x >= lo)
        def face_shade(x, y, k):
            if k != 'skin':
                return None
            if y == fringe(x) or (x + 0.5 - fx) / frx > 0.62 or y >= 23:
                return 'skinS'
            return None
        c.recolor(face_shade)
    def eye(x, y, shine_right=False):
        for dx in (0, 1):
            for dy in (0, 1):
                c.set(x + dx, y + dy, 'o')
        c.set(x + (1 if shine_right else 0), y, 'white')
    if view == 'south':
        eye(10, 16); eye(18, 16)
        for x in (8, 9, 20, 21):
            c.set(x, 19, 'blush')
        c.set(14, 21, 'mouth'); c.set(15, 21, 'mouth')
    elif view == 'south-east':
        eye(13, 16); eye(21, 16, True)
        c.set(11, 19, 'blush'); c.set(12, 19, 'blush'); c.set(23, 19, 'blush'); c.set(24, 19, 'blush')
        c.set(18, 21, 'mouth'); c.set(19, 21, 'mouth')
    elif view == 'east':
        eye(24, 16, True)
        c.set(22, 19, 'blush'); c.set(23, 19, 'blush')
        c.set(26, 21, 'mouth')
        for (x, y, k) in ((17, 16, 'skin'), (18, 16, 'skin'), (17, 17, 'skin'), (18, 17, 'skinS'), (17, 18, 'skinS')):
            c.set(x, y, k)
    elif view == 'north-east':
        for (x, y, k) in ((21, 17, 'skin'), (22, 17, 'skin'), (21, 18, 'skinS'), (22, 18, 'skinS')):
            c.set(x, y, k)
    else:  # north: redemoinho no topo
        for x in range(12, 17):
            c.set(x, 4, 'hairH')
        c.set(15, 5, 'hairS'); c.set(16, 5, 'hairS'); c.set(13, 3, 'hairH')
    return c.outline()

# ---------------------------------------------------------------- tronco
def torso(view):
    c = Canvas(18, 16)
    wide = {'south': (3, 14), 'north': (3, 14), 'south-east': (4, 13), 'north-east': (4, 13), 'east': (5, 12)}[view]
    x0, x1 = wide
    for y in range(1, 14):
        a, b = x0, x1
        if y == 1:
            a, b = x0 + 2, x1 - 2
        elif y == 2:
            a, b = x0 + 1, x1 - 1
        for x in range(a, b + 1):
            c.set(x, y, 'shirt' if y <= 9 else ('leather' if y == 10 else 'pants'))
    def shade(x, y, k):
        if k == 'shirt':
            if x <= x0 + 1:
                return 'shirtH'
            if x >= x1 - 1:
                return 'shirtS'
            if y == 9:
                return 'shirtM'
        if k == 'pants' and x == x0 + 1 and y < 13:
            return 'pantsH'
        return None
    c.recolor(shade)
    if view == 'south':
        c.set(8, 1, 'shirtD'); c.set(9, 1, 'shirtD'); c.set(8, 2, 'shirtD')
        c.line(5, 2, 12, 9, 'leather'); c.line(5, 3, 12, 10, 'leatherH')
        c.set(8, 10, 'buckle'); c.set(9, 10, 'buckle')
        c.rect(11, 11, 12, 12, 'leather'); c.set(11, 11, 'leatherH')
        c.set(8, 13, 'o'); c.set(9, 13, 'o')
    elif view == 'south-east':
        c.set(10, 1, 'shirtD'); c.set(10, 2, 'shirtD')
        c.line(6, 2, 12, 9, 'leather')
        c.set(10, 10, 'buckle'); c.set(11, 10, 'buckle')
        c.set(9, 13, 'o')
    elif view == 'east':
        c.line(8, 1, 8, 9, 'leather'); c.set(9, 5, 'leatherH')
        c.set(12, 10, 'buckle')
        for (x, y) in ((4, 9), (4, 10), (4, 11), (3, 10), (3, 11)):
            c.set(x, y, 'leather')
        c.set(4, 9, 'leatherH')
    elif view == 'north-east':
        c.line(12, 2, 6, 9, 'leather')
        for (x, y) in ((3, 10), (3, 11), (4, 11)):
            c.set(x, y, 'leather')
    else:
        c.line(12, 2, 5, 9, 'leather')
        c.set(8, 13, 'o'); c.set(9, 13, 'o')
    return c.outline()

# ---------------------------------------------------------------- membros
def limb(w, h, x0, x1, rows, kinds):
    c = Canvas(w, h)
    for y in range(rows):
        for x in range(x0, x1 + 1):
            c.set(x, y, kinds(x, y))
    return c.outline()

def sleeve(x, y):
    return 'shirtH' if x == 2 else ('shirtS' if x == 4 else 'shirt')

upper_arm = lambda: limb(7, 8, 2, 4, 6, sleeve)
upper_arm_short = lambda: limb(7, 6, 2, 4, 4, sleeve)
lower_arm = lambda: limb(7, 7, 2, 4, 5, lambda x, y: 'shirtD' if y >= 3 else sleeve(x, y))
lower_arm_short = lambda: limb(7, 5, 2, 4, 3, lambda x, y: 'shirtD' if y >= 2 else sleeve(x, y))
trouser = lambda x, y: 'pantsH' if x == 2 else 'pants'
thigh = lambda: limb(7, 6, 2, 4, 4, trouser)
thigh_short = lambda: limb(7, 5, 2, 4, 3, trouser)
shin = lambda: limb(7, 6, 2, 4, 4, trouser)

def hand(grip=False):
    c = Canvas(6, 6)
    c.ellipse(3.0, 3.0, 1.9, 1.9, 'skin')
    c.recolor(lambda x, y, k: 'skinS' if (x >= 3 and y >= 3) else None)
    if grip:
        c.set(2, 3, 'skinS'); c.set(3, 3, 'o')
    return c.outline()

def cap():
    c = Canvas(7, 6)
    c.ellipse(3.5, 2.9, 2.5, 1.95, 'shirt')
    c.recolor(lambda x, y, k: 'shirtH' if y <= 1 else ('shirtS' if x >= 5 else None))
    return c.outline()

def boot(view):
    c = Canvas(9, 7)
    c.rect(2, 1, 5, 3, 'boot')
    if view == 'side':
        c.rect(6, 2, 7, 3, 'boot'); c.set(7, 2, 'bootH')
    for x in range(2, 6):
        c.set(x, 1, 'bootH' if view != 'back' else 'boot')
    if view == 'back':
        c.set(3, 2, 'bootH'); c.set(4, 2, 'bootH')
    for x in range(2, 8 if view == 'side' else 6):
        c.set(x, 4, 'o')
    return c.outline()

def axe():
    c = Canvas(11, 21)
    for y in range(1, 18):
        c.set(5, y, 'woodH'); c.set(6, y, 'wood')
    c.rect(7, 13, 9, 18, 'iron')
    for y in range(13, 19):
        c.set(9, y, 'ironH')
    c.set(7, 13, 'ironS'); c.set(7, 18, 'ironS')
    c.rect(3, 14, 4, 16, 'ironS')
    return c.outline()

def can():
    c = Canvas(15, 12)
    for (x, y) in ((4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (4, 2), (8, 2)):
        c.set(x, y, 'canS')
    c.rect(2, 3, 9, 9, 'can')
    c.recolor(lambda x, y, k: 'canH' if (k == 'can' and x == 3 and 4 <= y <= 7) else ('canS' if k == 'can' and (x == 9 or y == 9) else None))
    for (x, y) in ((10, 6), (11, 5), (12, 4), (10, 7), (11, 6)):
        c.set(x, y, 'can')
    c.set(13, 3, 'canH'); c.set(13, 2, 'canH'); c.set(12, 3, 'canH')
    return c.outline()

PARTS = {}
for v in ('south', 'south-east', 'east', 'north-east', 'north'):
    PARTS['head_' + v] = head(v)
    PARTS['torso_' + v] = torso(v)
PARTS.update({
    'upper_arm': upper_arm(), 'upper_arm_short': upper_arm_short(),
    'lower_arm': lower_arm(), 'lower_arm_short': lower_arm_short(),
    'hand': hand(), 'hand_grip': hand(True), 'cap': cap(),
    'thigh': thigh(), 'thigh_short': thigh_short(), 'shin': shin(),
    'boot_front': boot('front'), 'boot_side': boot('side'), 'boot_back': boot('back'),
    'axe': axe(), 'can': can(),
})

os.makedirs(OUT, exist_ok=True)
manifest = {
    'original': True,
    'character': 'experimental_articulated',
    'created': '2026-10-19',
    'method': 'Pixel art autoral desenhada por regras em Python/Pillow (source/gerar_pecas.py). Nenhum recorte de sprites existentes; paleta amostrada de original_apprentice.',
    'paid_services': 'nenhum',
    'texel_world_size': 1.28 / 48.0,
    'parts': {},
}
for name, canvas in PARTS.items():
    im = canvas.image()
    path = os.path.join(OUT, name + '.png')
    im.save(path)
    manifest['parts'][name] = {'file': name + '.png', 'size': [im.width, im.height],
                               'sha256': hashlib.sha256(open(path, 'rb').read()).hexdigest()}
with open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8') as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)

# folha de conferencia ampliada (fora da importacao: salva em source/)
S = 8
names = list(PARTS)
cols = 10
rows = math.ceil(len(names) / cols)
cell = 32 * S
sheet = Image.new('RGBA', (cols * cell, rows * cell), (52, 60, 56, 255))
for i, name in enumerate(names):
    im = PARTS[name].image()
    big = im.resize((im.width * S, im.height * S), Image.NEAREST)
    x = (i % cols) * cell + (cell - big.width) // 2
    y = (i // cols) * cell + (cell - big.height) // 2
    sheet.alpha_composite(big, (x, y))
sheet.save(os.path.join(OUT, 'source', 'folha_pecas.png'))
print('pecas geradas:', len(PARTS))