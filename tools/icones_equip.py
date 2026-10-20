"""Icones pixel-art 16x16 do equipamento (mesmo estilo de tools/icones_fazenda.py: gerados por codigo,
contorno escuro de 1 px, sem servico externo). Saida: art/ui/icones_equip/<id>.png (+ previa 4x).
Capacetes e armaduras de couro/malha: cores tiradas da arte do PixelLab (work/pixellab_equip/<peca>/south.png)."""
import os, sys
from PIL import Image
raiz = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(raiz, 'art', 'ui', 'icones_equip')
os.makedirs(OUT, exist_ok=True)
K = (34, 24, 20)
def px(m, x, y, c):
    if 0 <= x < 16 and 0 <= y < 16: m[(x, y)] = c
def ret(m, x0, y0, x1, y1, c):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1): px(m, x, y, c)
def salvar(nome, m):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for (x, y), c in m.items(): im.putpixel((x, y), tuple(c) + (255,))
    o = im.copy()
    for x in range(16):
        for y in range(16):
            if im.getpixel((x, y))[3] == 0 and any(0 <= x + dx < 16 and 0 <= y + dy < 16 and im.getpixel((x + dx, y + dy))[3] > 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o.putpixel((x, y), K + (255,))
    o.save(os.path.join(OUT, nome + '.png'))
    return o
def camisa(esc, med, cla, colete=None):
    m = {}
    ret(m, 4, 3, 11, 13, med); ret(m, 1, 3, 3, 8, med); ret(m, 12, 3, 14, 8, med)
    ret(m, 1, 7, 3, 8, esc); ret(m, 12, 7, 14, 8, esc); ret(m, 4, 12, 11, 13, esc)
    ret(m, 5, 4, 6, 9, cla)
    ret(m, 6, 2, 9, 3, esc); ret(m, 7, 3, 8, 5, (236, 196, 160))
    if colete:
        ret(m, 4, 3, 5, 13, colete); ret(m, 10, 3, 11, 13, colete)
    return m
def calca(esc, med, cla):
    m = {}
    ret(m, 4, 2, 11, 6, med); ret(m, 3, 7, 6, 14, med); ret(m, 9, 7, 12, 14, med); ret(m, 7, 7, 8, 7, esc)
    ret(m, 4, 2, 11, 2, esc); ret(m, 4, 7, 4, 13, cla); ret(m, 10, 7, 10, 13, cla)
    ret(m, 3, 13, 6, 14, esc); ret(m, 9, 13, 12, 14, esc)
    px(m, 7, 3, (220, 210, 170))
    return m
def elmo(esc, med, cla, detalhe):
    m = {}
    for y in range(3, 12):
        meia = [3, 5, 6, 6, 7, 7, 7, 7, 7][y - 3]
        ret(m, 8 - meia, y, 7 + meia, y, med)
    ret(m, 2, 10, 13, 11, esc); ret(m, 5, 4, 7, 7, cla)
    if detalhe == 'nasal': ret(m, 7, 11, 8, 14, cla)
    if detalhe == 'costura':
        for x in range(3, 13, 2): px(m, x, 9, (214, 172, 112))
    if detalhe == 'crista':
        ret(m, 7, 0, 8, 3, (120, 230, 255)); px(m, 7, 0, (200, 250, 255)); ret(m, 2, 10, 13, 10, (150, 236, 255))
    return m
def capuz(esc, med, cla):
    m = {}
    for y in range(2, 14):
        meia = [3, 5, 6, 6, 7, 7, 7, 7, 7, 7, 6, 5][y - 2]
        ret(m, 8 - meia, y, 7 + meia, y, med)
    ret(m, 5, 7, 10, 12, (236, 170, 128)); ret(m, 5, 6, 10, 6, esc)   # rosto na abertura + dobra da testa
    px(m, 6, 9, (40, 24, 20)); px(m, 9, 9, (40, 24, 20))
    ret(m, 4, 3, 6, 5, cla); ret(m, 7, 2, 8, 5, esc)                   # brilho + costura do topo
    ret(m, 2, 12, 4, 13, esc); ret(m, 11, 12, 13, 13, esc)
    return m
def elmo_ferro():
    m = elmo((72, 74, 80), (115, 121, 121), (171, 173, 175), '')
    ret(m, 2, 10, 13, 10, (82, 84, 89))
    for x in range(3, 13, 3): px(m, x, 10, (190, 192, 194))            # rebites da aba
    ret(m, 7, 10, 8, 14, (137, 141, 142)); ret(m, 2, 11, 3, 13, (82, 84, 89)); ret(m, 12, 11, 13, 13, (82, 84, 89))
    return m
def elmo_adam():
    m = elmo((86, 126, 162), (170, 208, 231), (244, 254, 253), '')
    ret(m, 2, 10, 13, 11, (17, 54, 90)); ret(m, 7, 0, 8, 3, (86, 126, 162)); px(m, 7, 0, (170, 208, 231))
    ret(m, 7, 5, 8, 8, (40, 220, 255)); px(m, 7, 6, (200, 250, 255))   # runa ciano
    return m
def couraca():
    m = camisa((70, 28, 18), (130, 62, 24), (182, 97, 35))
    ret(m, 1, 3, 4, 5, (183, 98, 37)); ret(m, 1, 5, 4, 5, (70, 28, 18))   # ombreira
    for i in range(9): px(m, 4 + i, 3 + i, (70, 28, 18))                  # correia diagonal
    ret(m, 4, 11, 11, 11, (38, 52, 52)); ret(m, 9, 11, 10, 12, (116, 54, 35))  # cinto + bolsa
    ret(m, 1, 7, 3, 8, (116, 54, 35)); ret(m, 12, 7, 14, 8, (116, 54, 35))   # bracadeiras
    return m
def malha():
    m = camisa((73, 75, 90), (143, 149, 152), (186, 188, 187))
    for y in range(4, 12, 2):
        for x in range(4 + (y // 2) % 2, 12, 2): px(m, x, y, (102, 108, 116))  # aneis da malha
    ret(m, 6, 3, 9, 13, (156, 35, 60)); ret(m, 6, 3, 6, 13, (102, 23, 42))   # tabardo vermelho
    ret(m, 4, 11, 11, 11, (90, 52, 30)); px(m, 7, 11, (200, 180, 120))     # cinto
    return m
def peitoral():
    m = camisa((70, 96, 140), (150, 178, 214), (214, 232, 250))
    ret(m, 7, 4, 8, 11, (96, 124, 170)); px(m, 5, 6, (240, 250, 255)); px(m, 10, 6, (240, 250, 255))
    ret(m, 6, 2, 9, 3, (70, 96, 140)); m.pop((7, 3), None); m.pop((8, 3), None); ret(m, 7, 3, 8, 3, (96, 124, 170))
    return m
def amuleto():
    m = {}
    for i in range(3, 13): px(m, i, 2 + abs(8 - i) // 2, (176, 120, 62))
    ret(m, 6, 7, 9, 12, (222, 132, 40)); ret(m, 7, 8, 8, 10, (248, 182, 80)); px(m, 7, 8, (255, 240, 200))
    px(m, 5, 9, (222, 132, 40)); px(m, 10, 9, (222, 132, 40)); px(m, 7, 13, (160, 60, 40)); px(m, 8, 13, (160, 60, 40))
    return m
ic = {
    'roupa_aprendiz': camisa((51, 89, 89), (106, 155, 125), (150, 196, 166), (150, 90, 40)),
    'tunica_pescador': camisa((40, 62, 120), (76, 112, 186), (130, 166, 226), (150, 90, 40)),
    'camisa_lenhador': camisa((110, 30, 40), (176, 52, 60), (222, 104, 100), (150, 90, 40)),
    'bata_cinzas': camisa((60, 52, 74), (104, 94, 120), (150, 140, 166), (150, 90, 40)),
    'peitoral_adamantium': peitoral(),
    'calca_lida': calca((40, 38, 50), (72, 75, 77), (110, 112, 118)),
    'calca_anil': calca((30, 40, 92), (56, 72, 150), (96, 116, 196)),
    'calca_caqui': calca((110, 92, 60), (166, 144, 100), (204, 186, 140)),
    'grevas_adamantium': calca((70, 96, 140), (150, 178, 214), (214, 232, 250)),
    'couro_cacador': couraca(),
    'malha_guarda': malha(),
    'capuz_couro': capuz((75, 32, 20), (144, 73, 31), (181, 98, 39)),
    'elmo_ferro': elmo_ferro(),
    'elmo_adamantium': elmo_adam(),
    'amuleto_brasa': amuleto(),
}
prev = Image.new('RGBA', (len(ic) * 72, 72), (201, 164, 106, 255))
for i, (n, m) in enumerate(ic.items()):
    o = salvar(n, m)
    prev.alpha_composite(o.resize((64, 64), Image.NEAREST), (i * 72 + 4, 4))
prev.save(os.path.join(raiz, 'docs', 'equip-icones.png'))
open(os.path.join(OUT, '.gdignore'), 'w').close()
print('ok', len(ic))
