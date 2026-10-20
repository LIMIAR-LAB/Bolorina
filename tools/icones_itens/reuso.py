"""Reaproveita icones existentes: copia os 16x16 da fazenda e reduz os 32x32 da arte_noite para 16x16 com contorno."""
import sys, os, shutil
from PIL import Image
raiz = sys.argv[1]; out = os.path.join(raiz, 'art/ui/icones'); os.makedirs(out, exist_ok=True)
FAZ = '/workspace/bolorina_integrado/art/ui/icones_fazenda/'
NOI = '/workspace/arte_noite/art/ui/icones/'
K = (34, 24, 20, 255)
copia = {'semente_nabo': 'semente_nabo', 'semente_couve': 'semente_couve', 'semente_abobora': 'semente_abobora', 'picareta': 'picareta'}
reduz = {'minerio_cobre': 'minerio_cobre', 'minerio_ferro': 'minerio_ferro', 'minerio_prata': 'minerio_prata_tumular', 'carvao': 'carvao',
         'lingote_cobre': 'lingote_cobre', 'lingote_ferro': 'lingote_ferro', 'lingote_prata': 'lingote_prata_tumular'}
for n, s in copia.items(): shutil.copy(FAZ + s + '.png', os.path.join(out, n + '.png'))
for n, s in reduz.items():
    im = Image.open(NOI + s + '.png').convert('RGBA')
    im.putalpha(im.split()[3].point(lambda v: 255 if v > 100 else 0))
    bb = im.getbbox(); im = im.crop(bb)
    w, h = im.size; e = 14 / max(w, h); nw, nh = max(1, round(w*e)), max(1, round(h*e))
    pq = im.resize((nw, nh), Image.BOX)
    a = pq.split()[3].point(lambda v: 255 if v > 110 else 0)
    rgb = pq.convert('RGB').quantize(10, method=Image.Quantize.MEDIANCUT).convert('RGB')
    pq = rgb.convert('RGBA'); pq.putalpha(a)
    c = Image.new('RGBA', (16, 16), (0, 0, 0, 0)); c.paste(pq, ((16-nw)//2, (16-nh)//2 + (1 if nh < 14 else 0)))
    o = c.copy()
    for x in range(16):
        for y in range(16):
            if c.getpixel((x, y))[3] == 0 and any(0 <= x+dx < 16 and 0 <= y+dy < 16 and c.getpixel((x+dx, y+dy))[3] for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                o.putpixel((x, y), K)
    o.save(os.path.join(out, n + '.png'))
print('reuso ok', len(copia) + len(reduz))
