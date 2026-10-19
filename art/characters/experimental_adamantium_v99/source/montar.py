"""Monta o personagem de teste Adamantium nivel 99 a partir das geracoes PixelLab
(copiadas sem retoque) e gera variantes recoloridas por codigo das pecas articuladas.
Uso: python montar.py <pasta_work_pixellab>"""
import sys, os, json, shutil, hashlib, colorsys
from PIL import Image
SRC = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
ART = os.path.dirname(OUT)
DIRS = ['south','south-west','west','north-west','north','north-east','east','south-east']
def bbox(path):
    im = Image.open(path).convert('RGBA'); a = im.getchannel('A').point(lambda v: 255 if v > 76 else 0)
    return im.size, a.getbbox()
anims = {}
def add(name, files, fps, loop=True):
    boxes = [bbox(os.path.join(OUT, f)) for f in files]
    size = boxes[0][0]
    x0 = min(b[1][0] for b in boxes); y0 = min(b[1][1] for b in boxes)
    x1 = max(b[1][2] for b in boxes); y1 = max(b[1][3] for b in boxes)
    anims[name] = {'files': files, 'fps': fps, 'loop': loop, 'bounds': [x0, y0, x1, y1], 'size': list(size), 'feet': [b[1][3] for b in boxes]}
for d in DIRS:
    os.makedirs(os.path.join(OUT, 'rotations'), exist_ok=True)
    shutil.copyfile(os.path.join(SRC, 'zip/Idle/rotations', d + '.png'), os.path.join(OUT, 'rotations', d + '.png'))
    os.makedirs(os.path.join(OUT, 'walk', d), exist_ok=True)
    walk = []
    for f in range(6):
        rel = 'walk/%s/%03d.png' % (d, f)
        shutil.copyfile(os.path.join(SRC, 'zip/Idle/animations/walking', d, 'frame_%03d.png' % f), os.path.join(OUT, rel))
        walk.append(rel)
    add('idle_' + d, ['rotations/%s.png' % d], 6)
    add('walk_' + d, walk, 9)
    add('run_' + d, walk, 14)   # sem corrida gerada: reaproveita a caminhada mais rapida
# Asas: uma geracao simetrica dividida no centro em duas pecas articuladas.
wings = Image.open(os.path.join(SRC, 'asas_raw.png')).convert('RGBA')
W, H = wings.size
wing_info = {}
for name, box in (('asa_esquerda', (0, 0, W // 2, H)), ('asa_direita', (W // 2, 0, W, H))):
    half = wings.crop(box); bb = half.getchannel('A').point(lambda v: 255 if v > 76 else 0).getbbox()
    half = half.crop(bb); half.save(os.path.join(OUT, name + '.png'))
    # raiz da asa: borda interna, na altura do encontro das duas asas (linha 20 do original)
    root_x = half.width - 1 if name == 'asa_esquerda' else 0
    wing_info[name] = {'file': name + '.png', 'size': [half.width, half.height], 'root': [root_x, 20 - bb[1]]}
shutil.copyfile(os.path.join(SRC, 'asas_raw.png'), os.path.join(HERE, 'pixellab', 'asas_pixflux_64.png'))
shutil.copyfile(os.path.join(SRC, 'quantized_image_sul.png'), os.path.join(HERE, 'pixellab', 'armadura_sul_edit_pixen.png'))
shutil.copyfile(os.path.join(SRC, 'zip/metadata.json'), os.path.join(HERE, 'pixellab', 'metadata.json'))
gens = json.load(open(os.path.join(SRC, 'geracoes.json')))
json.dump(gens, open(os.path.join(HERE, 'pixellab', 'geracoes.json'), 'w'), indent=1, ensure_ascii=False)
def sha(p): return hashlib.sha256(open(p, 'rb').read()).hexdigest()
files = sorted(os.path.relpath(os.path.join(r, f), OUT).replace('\\', '/') for r, _, fs in os.walk(OUT) for f in fs if f.endswith('.png') and 'source' not in r)
manifest = {'original': True, 'directional': True, 'experimental': True,
    'source': 'PixelLab (assinatura do usuario), 19/10/2026: edit-image-pixen + create-character-v3 (referencia) + template walking + pixflux (asas)',
    'derived_from': 'original_apprentice (V4) rotations/south.png como imagem de entrada da edicao',
    'character_id': '39d5ea40-d5f8-405f-8ce4-2097c4db6634', 'directions': DIRS,
    'world_height': 1.28, 'min_normalization_height': 24, 'anims': anims, 'wings': wing_info,
    'sha256': {f: sha(os.path.join(OUT, f)) for f in files}}
json.dump(manifest, open(os.path.join(OUT, 'manifest.json'), 'w'), indent=1, ensure_ascii=False)
# Variantes "adamantium" das pecas articuladas (recolor por codigo, sem IA).
PARTS = os.path.join(ART, 'experimental_articulated'); DEST = os.path.join(PARTS, 'adamantium'); os.makedirs(DEST, exist_ok=True)
STEEL = [(38, 48, 72), (78, 96, 128), (132, 156, 186), (190, 210, 228), (236, 244, 252)]
def steel(c, rune=False):
    r, g, b, a = c
    if a == 0: return c
    l = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    if l < 0.12: return c  # contorno
    i = min(4, int(l * 6.2))
    return (*STEEL[i], a)
def recolor(name, rule):
    im = Image.open(os.path.join(PARTS, name)).convert('RGBA'); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0: continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if rule(h * 360, s, v): px[x, y] = steel((r, g, b, a))
    # runa ciano: um pixel brilhante no centro de pecas grandes
    if im.width >= 12 and im.height >= 12:
        cx, cy = im.width // 2, im.height // 2
        if px[cx, cy][3] > 0: px[cx, cy] = (110, 240, 255, 255); 
    im.save(os.path.join(DEST, name))
cloth = lambda h, s, v: (140 <= h <= 210 and s > 0.15) or (200 <= h <= 260 and v < 0.45)
leather = lambda h, s, v: (10 <= h <= 45 and v < 0.62 and s > 0.25)
everything = lambda h, s, v: True
for f in sorted(os.listdir(PARTS)):
    if not f.endswith('.png'): continue
    if f.startswith('torso_'): recolor(f, lambda h, s, v: cloth(h, s, v) or leather(h, s, v))
    elif f.startswith(('upper_arm', 'lower_arm', 'cap', 'thigh', 'shin', 'boot_')): recolor(f, lambda h, s, v: cloth(h, s, v) or leather(h, s, v) or (s < 0.35 and v < 0.5))
    elif f.startswith('hand'): recolor(f, everything)
    else: shutil.copyfile(os.path.join(PARTS, f), os.path.join(DEST, f))
print('ok', len(files), 'pngs;', len(anims), 'animacoes;', wing_info)