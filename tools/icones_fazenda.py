"""Icones pixel-art 16x16 da barra de ferramentas da fazenda (gerados por codigo, sem servico externo).
Saida: art/ui/icones_fazenda/<id>.png (+ previa 4x). Contorno escuro automatico de 1 px."""
import os, sys
from PIL import Image
raiz = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(raiz, 'art', 'ui', 'icones_fazenda')
os.makedirs(OUT, exist_ok=True)
C = {'k': (34, 24, 20), 'w': (125, 78, 40), 'W': (176, 120, 62), 'd': (88, 98, 112), 's': (150, 162, 176),
     'S': (220, 228, 234), 'b': (58, 104, 150), 'B': (104, 160, 206), 'p': (214, 190, 140), 'P': (178, 148, 98),
     'g': (70, 128, 52), 'G': (130, 184, 78), 'o': (222, 132, 40), 'O': (248, 182, 80), 'v': (150, 74, 160),
     'n': (240, 236, 244), 'r': (160, 60, 40), 'h': (236, 196, 160), 'H': (204, 156, 120)}
def novo(): return {}
def px(m, x, y, c):
    if 0 <= x < 16 and 0 <= y < 16: m[(x, y)] = c
def linha(m, a, b, c):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1-x0), -abs(y1-y0); sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1; e = dx+dy
    while True:
        px(m, x0, y0, c)
        if (x0, y0) == (x1, y1): break
        e2 = 2*e
        if e2 >= dy: e += dy; x0 += sx
        if e2 <= dx: e += dx; y0 += sy
def ret(m, x0, y0, x1, y1, c):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1): px(m, x, y, c)
def cabo(m, a, b):
    linha(m, a, b, 'w'); linha(m, (a[0]+1, a[1]), (b[0]+1, b[1]), 'W')
def salvar(nome, m):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for (x, y), c in m.items(): im.putpixel((x, y), C[c] + (255,))
    # contorno
    o = im.copy()
    for x in range(16):
        for y in range(16):
            if im.getpixel((x, y))[3] == 0 and any(0 <= x+dx < 16 and 0 <= y+dy < 16 and im.getpixel((x+dx, y+dy))[3] > 0 for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                o.putpixel((x, y), C['k'] + (255,))
    o.save(os.path.join(OUT, nome + '.png'))
    return o
ic = {}
m = novo(); cabo(m, (4, 14), (11, 5)); ret(m, 5, 2, 13, 3, 's'); ret(m, 5, 2, 13, 2, 'S'); ret(m, 3, 4, 7, 8, 's'); ret(m, 3, 8, 7, 8, 'S'); ret(m, 7, 4, 7, 7, 'd'); ic['enxada'] = m
m = novo(); cabo(m, (3, 14), (9, 6))
for x in range(2, 15):
    y = 3 + round(((x-8.5)/6.5)**2*4)
    px(m, x, y, 's'); px(m, x, y-1, 'S' if 4 < x < 13 else 's')
px(m, 2, 7, 'd'); px(m, 14, 7, 'd'); ic['picareta'] = m
m = novo(); cabo(m, (3, 14), (9, 4)); ret(m, 9, 2, 12, 7, 's'); ret(m, 13, 2, 13, 7, 'S'); px(m, 14, 3, 'S'); px(m, 14, 6, 'S'); ret(m, 9, 2, 9, 7, 'd'); ic['machado'] = m
m = novo(); linha(m, (4, 14), (7, 4), 'w'); linha(m, (5, 14), (8, 4), 'W'); ret(m, 3, 9, 6, 9, 'w')
for p in [(8, 3), (9, 2), (10, 2), (11, 2), (12, 3), (13, 4), (14, 5), (14, 6), (14, 7)]: px(m, *p, 'S')
for p in [(9, 3), (10, 3), (11, 3), (12, 4), (13, 5), (13, 6)]: px(m, *p, 's'); 
ic['foice'] = m
m = novo(); ret(m, 2, 7, 10, 13, 'b'); ret(m, 3, 7, 4, 12, 'B'); ret(m, 2, 7, 10, 7, 'B')
linha(m, (10, 10), (13, 6), 'b'); linha(m, (11, 10), (14, 6), 's'); ret(m, 13, 4, 15, 5, 's')
for p in [(4, 6), (4, 5), (5, 4), (6, 4), (7, 4), (8, 5), (8, 6)]: px(m, *p, 'd')
ic['regador'] = m
def saco(m):
    ret(m, 3, 4, 12, 14, 'p'); ret(m, 3, 4, 3, 14, 'P'); ret(m, 4, 2, 11, 3, 'P'); px(m, 7, 1, 'P'); px(m, 8, 1, 'P'); ret(m, 3, 13, 12, 13, 'P')
m = novo(); saco(m); ret(m, 6, 8, 9, 11, 'n'); ret(m, 6, 8, 9, 8, 'v'); px(m, 5, 9, 'v'); px(m, 10, 9, 'v'); px(m, 7, 12, 'n'); px(m, 8, 12, 'n')
for p in [(6, 6), (7, 7), (8, 6), (9, 5), (7, 5), (8, 7)]: px(m, *p, 'g')
ic['semente_nabo'] = m
m = novo(); saco(m); ret(m, 6, 7, 9, 11, 'g'); ret(m, 5, 8, 10, 10, 'g'); ret(m, 6, 6, 7, 6, 'G'); ret(m, 9, 6, 9, 7, 'G'); px(m, 4, 9, 'G'); px(m, 11, 9, 'G'); linha(m, (7, 8), (8, 11), 'G'); px(m, 6, 9, 'G'); px(m, 9, 9, 'G'); px(m, 7, 12, 'n'); px(m, 8, 12, 'n')
ic['semente_couve'] = m
m = novo(); saco(m); ret(m, 5, 8, 10, 11, 'o'); ret(m, 4, 9, 11, 10, 'o'); px(m, 7, 8, 'O'); px(m, 6, 9, 'O'); ret(m, 7, 9, 7, 11, 'r'); px(m, 8, 7, 'w'); px(m, 8, 6, 'w'); px(m, 9, 6, 'g')
ic['semente_abobora'] = m
m = novo(); ret(m, 4, 8, 11, 13, 'h'); ret(m, 4, 12, 11, 13, 'H')
for i, x in enumerate([4, 6, 8, 10]): ret(m, x, 3 + (1 if i in (0, 3) else 0), x+1, 7, 'h')
ret(m, 12, 7, 13, 9, 'h'); ret(m, 4, 14, 11, 15, 'b'); ic['mao'] = m
m = novo(); linha(m, (2, 14), (12, 2), 'w'); linha(m, (3, 14), (13, 2), 'W'); ret(m, 3, 11, 5, 12, 'd'); px(m, 4, 13, 's')
for p in [(13, 3), (14, 4), (14, 5), (14, 6), (14, 7), (14, 8), (14, 9)]: px(m, *p, 'S')
px(m, 13, 10, 's'); px(m, 12, 10, 's'); px(m, 12, 9, 's'); ret(m, 13, 12, 14, 13, 'r'); px(m, 13, 11, 'n')
ic['vara'] = m
ordem = ['enxada', 'picareta', 'machado', 'foice', 'regador', 'semente_nabo', 'semente_couve', 'semente_abobora', 'mao', 'vara']
ims = [salvar(n, ic[n]) for n in ordem]
prev = Image.new('RGBA', (len(ordem)*72+8, 80), (60, 40, 24, 255))
for i, im in enumerate(ims):
    prev.paste((201, 164, 106, 255), (4+i*72, 8, 4+i*72+64, 72))
    big = im.resize((48, 48), Image.NEAREST); prev.paste(big, (4+i*72+8, 16), big)
prev.save(os.path.join(raiz, 'icones_previa.png'))
print('ok', OUT)
