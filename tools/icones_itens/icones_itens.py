"""Icones de itens 16x16 (Ilha das Cinzas), desenhados em codigo no estilo de tools/icones_fazenda.py.
Mesma paleta base + contorno escuro automatico de 1 px. Uso: python3 icones_itens.py <raiz_saida>"""
import os, sys
from PIL import Image
RAIZ = sys.argv[1] if len(sys.argv) > 1 else '.'
C = {'k': (34, 24, 20), 'w': (125, 78, 40), 'W': (176, 120, 62), 'u': (86, 52, 28), 'd': (88, 98, 112), 's': (150, 162, 176),
     'S': (220, 228, 234), 'b': (58, 104, 150), 'B': (104, 160, 206), 'p': (214, 190, 140), 'P': (178, 148, 98),
     'g': (70, 128, 52), 'G': (130, 184, 78), 'q': (40, 84, 40), 'o': (222, 132, 40), 'O': (248, 182, 80), 'z': (176, 88, 30),
     'v': (150, 74, 160), 'V': (196, 128, 206), 'n': (240, 236, 244), 'N': (190, 182, 204), 'r': (160, 60, 40),
     'R': (214, 66, 58), 'm': (100, 30, 34), 'h': (236, 196, 160), 'H': (204, 156, 120), 'y': (232, 196, 60),
     'Y': (255, 240, 150), 't': (40, 128, 130), 'T': (118, 212, 200), 'c': (54, 52, 62), 'C': (104, 102, 116),
     'i': (50, 56, 132), 'I': (98, 112, 204), 'l': (214, 116, 140), 'L': (246, 170, 182)}
METAL = {'cobre': [(110, 52, 30), (176, 92, 48), (222, 140, 80), (252, 204, 150)],
         'ferro': [(56, 64, 86), (96, 112, 142), (150, 168, 194), (216, 226, 238)],
         'prata': [(64, 100, 104), (128, 170, 170), (190, 222, 216), (238, 252, 248)]}
RAMPAS = {'carpa': [(150, 70, 30), (210, 120, 50), (240, 168, 80), (255, 220, 160)],
          'tilapia': [(60, 76, 92), (104, 124, 140), (156, 176, 186), (214, 226, 230)],
          'dourado': [(170, 110, 20), (226, 170, 40), (250, 214, 80), (255, 248, 190)]}

def grade(rows, base=None):
    m = dict(base or {})
    assert len(rows) <= 16, rows
    for y, r in enumerate(rows):
        assert len(r) <= 16, (r, len(r))
        for x, ch in enumerate(r):
            if ch != '.': m[(x, y)] = ch
    return m

def render(m, ramp=None):
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    for (x, y), ch in m.items():
        col = ramp[int(ch) - 1] if ch.isdigit() else C[ch]
        im.putpixel((x, y), col + (255,))
    o = im.copy()
    for x in range(16):
        for y in range(16):
            if im.getpixel((x, y))[3] == 0 and any(0 <= x+dx < 16 and 0 <= y+dy < 16 and im.getpixel((x+dx, y+dy))[3] > 0
                                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o.putpixel((x, y), C['k'] + (255,))
    return o

I = {}   # id -> (grade, rampa)
def add(n, rows, base=None, ramp=None): I[n] = (grade(rows, base), ramp)

SACO = grade(["", "", "....PPPPPPPP", "...ppppppppppp", ] )  # placeholder, substituido abaixo
# saco igual ao da fazenda
SACO = {}
def ret(m, x0, y0, x1, y1, c):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1): m[(x, y)] = c
ret(SACO, 3, 4, 12, 14, 'p'); ret(SACO, 3, 4, 3, 14, 'P'); ret(SACO, 4, 2, 11, 3, 'P'); SACO[(7, 1)] = 'P'; SACO[(8, 1)] = 'P'; ret(SACO, 3, 13, 12, 13, 'P')

add('semente_girassol', ["", "", "", "", "", "",
    ".....y.yy.y",
    "......yYYy",
    ".....yYuuyy",
    ".....yyuuyy",
    "......yyyy",
    ".....y.yy.y",
    ".......nn"], SACO)
add('racao', ["",
    ".......y.y",
    "......yYyYy",
    "....yYyyYyyy",
    "...PyyYyyyYyP",
    "...PPPPPPPPPP",
    "...ppppppppPP",
    "..pppppPpppPPP",
    "..ppppPyPppPPP",
    "..ppppPyPppPPP",
    "..pppppPpppPPP",
    "..ppppppppppPP",
    "..ppppppppppPP",
    "...PPPPPPPPPP"])
MUDA = ["",
    ".......G",
    ".....GGgG.GG",
    "....GgGggGgG",
    "....gGgXgggg",
    ".....ggwgGg",
    "......gwgg",
    ".......w",
    ".......w",
    "....RRRRRRRR",
    "....rrrrrrrr",
    ".....Rrrrrm",
    ".....Rrrrrm",
    "......rrrm"]
add('muda_macieira', [r.replace('X', 'R') for r in MUDA])
add('muda_laranjeira', [r.replace('X', 'o') for r in MUDA])
I['muda_macieira'][0][(6, 2)] = 'R'; I['muda_laranjeira'][0][(10, 3)] = 'O'
# terracota do vaso diferente da maca: usa H/z
for k_ in ('muda_macieira', 'muda_laranjeira'):
    g_ = I[k_][0]
    for p, ch in list(g_.items()):
        if p[1] >= 9: g_[p] = {'R': 'o', 'r': 'z', 'm': 'r'}[ch]
add('nabo', ["",
    ".....g...g",
    "....gGg.gGg",
    ".....gGgGg",
    "......gGg",
    ".....vvVvv",
    "....vVVvvvv",
    "...vVvvvvvvv",
    "...nnvvvvvnn",
    "...nnnnnnnnN",
    "...nnnnnnnNN",
    "....nnnnnNN",
    ".....nnnNN",
    "......nNN",
    ".......N"])
add('couve', ["", "",
    "......GGG",
    "....GGgGGGG",
    "...GgGGgGgGG",
    "..GGgGgGGgGgG",
    "..GgGGqGGqGGG",
    "..gGgGGqqGGgg",
    "...ggGGqGGgg",
    "...gqgGqGgqg",
    "....gqgqgqg",
    ".....gggqgg",
    "......pGp",
    ".......p"])
add('abobora', ["", "",
    ".......ww",
    "........wGG",
    ".....oooooo",
    "...ooOozOOzoo",
    "..oOOozOOOzooo",
    "..oOoozOOozooz",
    "..oOoozOoozooz",
    "..ooozoooozozz",
    "..ooozoooozozz",
    "...oozoooozoz",
    "....zzzzzzzz"])
add('ovo', ["", "",
    ".......pp",
    "......pppp",
    ".....pnpppp",
    "....pnnppppP",
    "....pnpppppP",
    "...ppppppppPP",
    "...ppppppppPP",
    "...ppppppppPP",
    "...pppppppPPP",
    "....pppppPPP",
    ".....PpPPPP",
    "......PPPP"])
add('maca', ["",
    "........w",
    ".......w.GG",
    ".......wGGG",
    "...RRRRmRRRR",
    "..RnRRRRRRRrr",
    "..RnRRRRRRRrr",
    "..RRRRRRRRrrr",
    "..RRRRRRRRrrr",
    "..RRRRRRRrrrr",
    "...RRRRRrrrr",
    "...RRRrrrrrm",
    "....rrmrrmm"])
add('laranja', ["",
    "",
    ".......wGG",
    ".......GGgG",
    "....ooooooo",
    "...oOOoooooo",
    "..oOYOooooooz",
    "..oOOoooooooz",
    "..ooooooooozz",
    "..ooooooooozz",
    "..oooooooozzz",
    "...oooooozzz",
    "....ozozzzz",
    ".....zzzzz"])
PEIXE = ["", "", "", "",
    ".......444",
    ".....4433333...1",
    "....43k333333.11",
    "...4333333333211",
    "...3332222222211",
    "....222222221.11",
    ".....11122221..1",
    ".......111"]
add('peixe_carpa', PEIXE, ramp=RAMPAS['carpa'])
add('peixe_dourado', PEIXE, ramp=RAMPAS['dourado'])
I['peixe_dourado'][0][(8, 5)] = '4'; I['peixe_dourado'][0][(10, 7)] = '4'
add('peixe_tilapia', PEIXE, ramp=RAMPAS['tilapia'])
for x in (7, 10):
    for y in range(5, 10):
        if (x, y) in I['peixe_tilapia'][0]: I['peixe_tilapia'][0][(x, y)] = '1'
add('madeira', ["", "", "", "",
    "....PPPwwwwwwww",
    "...PpppPWWWWWWw",
    "..PpPPPpPwuwwww",
    "..PpPwPpPWWWWuw",
    "..PpPPPpPwwwwww",
    "...PpppPWWuWWWw",
    "....PPPwwwwwwww",
    ])
add('pedra', ["", "", "", "",
    "......CCC",
    "....CCsCCC",
    "...CsSsCCCC",
    "..CCsCCCCCcC",
    "..CCCCCCCcCCC",
    "..CCCCCCCCccC",
    "..cCCCCCcCCcc",
    "...cccCCCCcc",
    "....ccccccc"])
add('fibra', ["",
    "..G.......G",
    "...G..G..G",
    "...yG.G.Gy",
    "....yGyGy",
    ".....yGy",
    ".....ywy",
    ".....WwW",
    ".....yGy",
    "....yGyGy",
    "...yG.y.Gy",
    "..yG..y..Gy",
    "..y...G...y"])
add('tabuas', ["", "",
    "......WWWWWWW",
    "....WWWWWWWWw",
    "..WWWWWWWWWwww",
    "..wwwwwwwwwwkw",
    "..kkkkkkkkkkww",
    "..WWWWWWWWWWkw",
    "..wwwuwwwwwwww",
    "..kkkkkkkkkkkw",
    "..WWWWWWWWWWWk",
    "..wwwwwwwuwwww",
    "..uuuuuuuuuuuu"])
add('corda', ["", "",
    ".....PPPPP",
    "....PpPPpPP",
    "...PpPkkkPpP",
    "...pPk...kPp",
    "...Pp.PPP.pP",
    "...pP.pkP.Pp",
    "...Pp.P.....",
    "...pPk...kPp.",
    "...PpPkkkPpP",
    "....PpPPpPP",
    "......PPPpP",
    "..........pP",
    "...........P"])
# corrige o miolo da corda (furo do rolo)
for p in [(6, 8), (7, 8), (8, 8), (9, 8), (10, 8), (11, 8)]: I['corda'][0].pop(p, None)
I['corda'][0].update({(6, 8): 'P', (7, 8): 'p', (8, 8): 'P', (10, 8): 'P', (11, 8): 'p'})
add('tocha', ["",
    ".......y",
    "......yYy",
    ".....oyYyo",
    ".....oYYyo",
    "....oooyooo",
    ".....zooozz",
    "......sSs",
    "......wWw",
    "......wW",
    "......wW",
    "......wW",
    "......wW",
    "......uw",
    ""])
add('sal', ["", "", "",
    ".......n",
    "......nSn",
    ".....nnnNn",
    "....nnSnnNn",
    "...nnnnnnNNn",
    "..WWWWWWWWWWW",
    "..wWWWWWWWWWw",
    "...wwWWWWWww",
    "....wwwwwww",
    ".....uuuuu"])
add('isca_minhoca', ["", "", "",
    "..........LL",
    ".........LllL",
    "........lL..l",
    "...LL...l",
    "..LllL.lL",
    "..l..LlL",
    "..k...l",
    "",
    "", ])
# minhoca simples em S
I['isca_minhoca'] = (grade(["", "", "",
    "..........LL",
    ".........LlkL",
    ".........Ll",
    "........Ll",
    "...LLL..Ll",
    "..LlllLLl",
    "..Ll..lll",
    "..Ll",
    "...ll",
    ""]), None)
add('isca_brilhante', ["",
    ".......n",
    "..T...nkn",
    "...T...k",
    "......TTT",
    ".....TTnTT",
    ".....tTTTt",
    ".....tTTTt",
    ".....ytyty",
    "......tyt",
    ".......s",
    "....S..s..S",
    ".......s",
    "...T..ss",
    "......."])
add('vara_reforcada', ["",
    "............wS",
    "...........wWn",
    "..........wW.n",
    ".........sS..n",
    "........wW...n",
    ".......wW....n",
    "......sS.....n",
    ".....wW......n",
    "....kdk......n",
    "...wdsdk.....S",
    "..wWkdk.....SsS",
    ".uW..........S",
    ".u"])
GARRAFA = ["",
    "......www",
    "......WWw",
    ".......n",
    ".......n",
    ".....nnnnn",
    "....n22222n",
    "...n2422222n",
    "...n2422222n",
    "...n2222221n",
    "...n2222211n",
    "....n22111n",
    ".....nnnnn"]
add('pocao_vida', GARRAFA, ramp=[(110, 24, 34), (200, 44, 56), (240, 110, 110), (255, 200, 200)])
add('pocao_energia', GARRAFA, ramp=[(170, 120, 10), (236, 196, 40), (255, 230, 110), (255, 250, 210)])
add('antidoto', ["",
    "......ww",
    "......WW",
    "......nn",
    ".....n43n",
    ".....n32n",
    ".....n32n",
    ".....n32n",
    ".....n32n",
    ".....n22n",
    ".....n21n",
    ".....n21n",
    "......nn",
    ""], ramp=[(30, 100, 70), (60, 170, 110), (130, 220, 150), (220, 255, 220)])
for p in [(7, 4), (7, 5), (7, 6)]: pass
add('cha_calmante', ["",
    "......S...S",
    ".....S...S",
    "......S...S",
    ".....S...S",
    "",
    "...nnnnnnnnn",
    "...ngGGgGGgnNN",
    "...nnnnnnnnn.N",
    "...nnnnnnnNn.N",
    "...NnnnnnnNNNN",
    "....NnnnnNN",
    "..NNNNNNNNNNN",
    "...NNNNNNNNN"])
add('sopa_peixe', ["",
    "",
    ".....S...S",
    "......S...S",
    ".....S...S",
    "..........1",
    "..ooOooooo11",
    ".oOOoOGoooo1",
    ".WoooooOGoooW",
    ".wWWWWWWWWWWw",
    "..wWWWWWWWWw",
    "...wwWWWWww",
    "....uwwwwu",
    "......uu"], ramp=RAMPAS['carpa'])
add('pao_cinzas', ["", "", "", "",
    ".....HHHHHH",
    "...HHwHHHwHHH",
    "..HhHHwHHwHHHw",
    "..HhHcHHHHcHHw",
    "..HHHHwHHwHHHw",
    "..wHcHHwHHHcww",
    "..wwHHHHHHHwww",
    "...wwwwwwwwww",
    "....uuuuuuuu"])
add('torta_abobora', ["", "", "", "",
    ".....PPPPPP",
    "...PPooooooPP",
    "..PoOOooonoooP",
    "..PoOoooooOooP",
    "..PPooooooooPP",
    "..pPPPPPPPPPPp",
    "..ppPpPpPpPpPp",
    "...pppppppppp",
    "....PPPPPPPP"])
# picareta (mesma da fazenda) refeita para recolorir em ferro
PIC = {}
def linha(m, a, b, c):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1-x0), -abs(y1-y0); sx = 1 if x0 < x1 else -1; sy = 1 if y0 < y1 else -1; e = dx+dy
    while True:
        m[(x0, y0)] = c
        if (x0, y0) == (x1, y1): break
        e2 = 2*e
        if e2 >= dy: e += dy; x0 += sx
        if e2 <= dx: e += dx; y0 += sy
linha(PIC, (3, 14), (9, 6), 'w'); linha(PIC, (4, 14), (10, 6), 'W')
for x in range(2, 15):
    y = 3 + round(((x-8.5)/6.5)**2*4)
    PIC[(x, y)] = '2'; PIC[(x, y-1)] = '4' if 4 < x < 13 else '3'
    if 5 < x < 12: PIC[(x, y+1)] = '1'
PIC[(2, 7)] = '1'; PIC[(14, 7)] = '1'; PIC[(8, 5)] = 'k'; PIC[(9, 5)] = 'k'
I['picareta_ferro'] = (PIC, METAL['ferro'])
add('lanterna_mina', ["",
    ".......dd",
    "......d..d",
    "......d..d",
    ".....dsssd",
    "....dSsssd",
    "....dyYYyd",
    "....syYnYs",
    "....dyYYyd",
    "....syyyyd",
    "....dsssss",
    "....ddddd",
    ""])
I['lanterna_mina'][0].update({(9, 5): 'd', (9, 6): 'd', (9, 7): 'd', (9, 8): 'd', (9, 9): 'd', (9, 10): 'd', (9, 11): 'd'})
MAPA = ["", "",
    "..PpPPPPPPPPpP",
    "..PpppppppppPP",
    "...pppppppppP",
    "...pppppppppP",
    "...pppppppppP",
    "...pppppppppP",
    "...pppppppppP",
    "...pppppppppP",
    "...pppppppppP",
    "..PpppppppppPP",
    "..PpPPPPPPPPpP"]
add('mapa_minas', MAPA)
I['mapa_minas'][0].update(grade(["", "", "", "",
    "........d",
    ".......dsd",
    "......dsSdd",
    ".....dsdsdsd",
    "....dssdddsd",
    "....RkRk..",
    ".....R...",
    "....R.R"]))
I['mapa_minas'][0].pop((8, 9), None); I['mapa_minas'][0].pop((9, 9), None)
add('mapa_cidade_fantasma', MAPA)
I['mapa_cidade_fantasma'][0].update(grade(["", "", "", "",
    ".......nnn",
    "......nnnnn",
    "......nknkn",
    "......nnnnn",
    "......nnnnN",
    "......nnnnN",
    "......nNnNn",
    "..............",
    ]))
add('mapa_vila_orcs', MAPA)
I['mapa_vila_orcs'][0].update(grade(["", "", "", "",
    "......GGGG",
    ".....GGGGGG",
    ".....GkGGkG",
    ".....gGGGGg",
    ".....gnggng",
    "......gggg",
    "",
    ]))
I['mapa_vila_orcs'][0].update({(6, 12): 'R', (7, 12): 'R', (8, 12): 'R'})
I['mapa_cidade_fantasma'][0].update({(6, 12): 'R', (7, 12): 'R', (8, 12): 'R'})
I['mapa_minas'][0].update({(6, 12): 'R', (7, 12): 'R', (8, 12): 'R'})
add('bussola_temporal', ["",
    "......yyy",
    ".....yYyyy",
    "....yyyyyyy",
    "...yytTtTtyy",
    "...ytTTnTTty",
    "..yytTTkTTtyy",
    "..yTTkkkkTTTy",
    "..yytTTkTTtyy",
    "...ytTTTTTty",
    "...yytTtTtyy",
    "....yyyyyyz",
    ".....zyyyz",
    "......zzz"])
I['bussola_temporal'][0].update({(7, 7): 'R', (6, 7): 'R', (8, 6): 'k', (8, 5): 'k'})
I['bussola_temporal'][0].pop((8, 5)); I['bussola_temporal'][0][(8, 5)] = 'n'
add('chapeu_palha', ["", "", "", "",
    "......PyyyP",
    ".....yYyyyyP",
    ".....yyyyyyP",
    ".....RRRRRRm",
    "..PyyyyyyyyyyyP",
    ".PyYyyyyyyyyyyyP",
    "..PPyyyyyyyyyPP",
    "....PPPPPPPPP",
    ""])
add('lenco_vermelho', ["", "", "",
    "..RRRRRRRRRRRR",
    "..RRnRRRRnRRrr",
    "...RRRRRRRRrr",
    "...RRnRRRnRrr",
    "....RRRRRRrr",
    ".....RRnRrr",
    "......RRrr",
    ".......Rr",
    "........r",
    ""])
I['lenco_vermelho'][0].update({(1, 3): 'R', (14, 3): 'r', (0, 2): 'R', (15, 2): 'r'})
add('capa_viagem', ["",
    "......yy",
    ".....gyygg",
    "....gGggGgg",
    "...gGgggggGg",
    "...gGgggggqg",
    "..gGggggggqqg",
    "..gGggggggqqg",
    "..gGggggggqqg",
    ".gGgggggggqqqg",
    ".gGgggggggqqqg",
    ".gGggggggqqqqg",
    ".ggggggggqqqqq",
    "..qq.qqq.qqqq"])
add('tinta_anil', ["",
    "......www",
    ".....wWWWw",
    ".....snnns",
    "....nIIIIIn",
    "...nIIiiiiin",
    "...nIiiiiiin",
    "...nIiiPPiin",
    "...nIiPiPiin",
    "...niiiPPiin",
    "...niiiiiiin",
    "....niiiiin",
    ".....nnnnn"])
add('relogio_parado', ["",
    "......yyy",
    ".......y",
    ".....yyyyy",
    "....ynnnnny",
    "...ynnnknnny",
    "...ynnnknnny",
    "...ynnnkkkny",
    "...ynnnnnSny",
    "...ynnnnSnny",
    "...yNnnSnnNy",
    "....yNNNNNy",
    ".....yzzzy"])
add('moeda_futuro', ["", "",
    ".....TTTTT",
    "....TnTTTTt",
    "...TnTttTTTt",
    "...TTtnnttTt",
    "...TTtnTntTt",
    "...TTtnTntTt",
    "...TTttnttTt",
    "...TTTttTTtt",
    "....TTTTTtt",
    ".....ttttt",
    ""])
# moeda: rampa clara azul-petróleo com hexagono escuro
add('fossil_dragao', ["", "", "",
    "....CCCCCCC",
    "...CsSsssssC",
    "..CsnnnssssCc",
    "..CsnssnnsnsC",
    "..CsssnssnnsC",
    "..CsnnnsssnsC",
    "..CssssnnnssC",
    "..CsnnssssssC",
    "...CsssssssCc",
    "....CcccccCc"])
add('ampulheta_rachada', ["",
    "...wWWWWWWWw",
    "....wnnnnnw",
    "....wnnnnNw",
    "....wynyyNw",
    ".....wyyyw",
    "......wyw",
    "......wkw",
    ".....wnknw",
    "....wnNnkNw",
    "....wnnyknw",
    "....wyyyyyw",
    "...wWWWWWWWw"])
add('escama_dragao', ["", "",
    "......RRRR",
    ".....RRnRRr",
    "....RRnRRRrr",
    "....RnRRRRrr",
    "....RRRRRrrr",
    "....RRRRRrrr",
    ".....RRRrrrm",
    ".....RRRrrm",
    "......Rrrm",
    ".......rm",
    ""])
add('insignia_guarda', ["",
    "...yyyyyyyyy",
    "...ybbbbbbby",
    "...ybBByBbby",
    "...ybByYybby",
    "...ybyYYYyby",
    "...ybbyyybby",
    "...ybbybybby",
    "....ybbbbby",
    "....ybbbbby",
    ".....ybbby",
    "......yby",
    ".......y"])
add('racao_pet', ["", "", "", "", "",
    "....WuWWuWW",
    "...uWWuWWuWu",
    "..RRRRRRRRRRR",
    "..RLRRRRRRRrr",
    "...RRRRRRRrr",
    "...RRRRRRRrr",
    "....rrrrrrr",
    ""])
add('coleira', ["", "",
    ".....RRRRRR",
    "....Rr....RR",
    "...Rr......Rr",
    "...R.......Rr",
    "...R.......Rr",
    "...Rr.....RRr",
    "....RRsSsRRr",
    ".....rrsRrr",
    ".......y",
    "......yYy",
    "......yyz",
    ".......z"])
I['coleira'][0].pop((7, 10)); I['coleira'][0][(7, 10)] = 's'
add('apito_montaria', ["",
    "",
    "..R",
    "...R",
    "....R",
    ".....R",
    "......yyyyyyy",
    ".....yYYYYYYzk",
    "....yYyyyyyyzz",
    "....yyyykkyzz",
    "....zyyyyyzz",
    ".....zzzzz",
    ""])
add('carta_entrega', ["", "", "",
    "..nnnnnnnnnnnn",
    "..NnnnnnnnnnnN",
    "..nNnnnnnnnnNn",
    "..nnNnnnnnnNnn",
    "..nnnNnnnnNnnn",
    "..nnnnNRRNnnnn",
    "..nnnnRRRRnnnn",
    "..nnnnnRRnnnnN",
    "..NNNNNNNNNNNN",
    ""])

EQUIP = {}
EQUIP['capacete'] = grade(["",
    "......333",
    "....3344432",
    "...33444332",
    "..3344333322",
    "..3343333222",
    "..3333332221",
    "..3kkkkkkkk1",
    "..33k3k2k221",
    "..32k3k2k221",
    "..3222222211",
    "..2211111111",
    "...1.....1"])
EQUIP['peito'] = grade(["",
    "..333....333",
    ".33443333322",
    ".34433333222",
    ".34333333221",
    "..343332221",
    "..343332221",
    "..33333322",
    "..3wWWwww2",
    "..33k2k2221",
    "..333222221",
    "..332222211",
    "...3222211",
    "....21111"])
EQUIP['luvas'] = grade(["",
    "",
    "...333.333",
    "..34433443",
    "..34333443",
    "..33332332",
    "..3333233211",
    "..3333222211",
    "..33332222",
    "...222222",
    "...wWWWww",
    "...wWWWww",
    "...wwwwwu"])
EQUIP['luvas'].update({(3, 2): '3', (4, 2): '4', (5, 2): '3'})
EQUIP['botas'] = grade(["", "",
    "...3332",
    "...3432",
    "...3432",
    "...3332..3332",
    "...wWWw..3432",
    "...3332..3432",
    "...3332..3332",
    "...33322.wWWw",
    "...333322333222",
    "...111111332222",
    "..........111111"])
EQUIP['botas'] = grade(["", "",
    "....3332",
    "....3432",
    "....3432",
    "....3332",
    "....wWWw",
    "....3332",
    "....3332",
    "....33322",
    "....3333222",
    "....33332222",
    "....11111111",
    ""])
EQUIP['escudo'] = grade(["",
    "..33333333332",
    "..34444344432",
    "..34333433322",
    "..34333433322",
    "..33333433222",
    "..44444444441",
    "..33333432221",
    "...333343221",
    "...333343221",
    "....3334321",
    ".....33421",
    "......321",
    ".......1"])
EQUIP['espada'] = grade(["",
    ".............4",
    "............43",
    "...........432",
    "..........432",
    ".........432",
    "........432",
    "...ww..432",
    "....wW432",
    ".....w32",
    "....uWw",
    "...uWuwW",
    "..uWu..w",
    ".uu"])
EQUIP['espada'] = grade(["",
    "............44",
    "...........4431",
    "..........4431",
    ".........4431",
    "........4431",
    ".......4431",
    "..33..4431",
    "...3243",
    "....221",
    "...u21",
    "..uWuw1",
    ".uWu..2",
    ".uu"])


# ---- refeitos apos revisao ----
m = {}
for x in range(16):
    for y in range(16):
        r = ((x-7.5)**2 + (y-7.0)**2) ** 0.5
        if 1.6 <= r < 3.0: m[(x, y)] = 'P' if (x+y) % 3 else 'p'
        elif 3.0 <= r < 3.8: m[(x, y)] = 'u'
        elif 3.8 <= r < 5.6: m[(x, y)] = 'p' if (x-y) % 3 else 'P'
for p in [(11, 11), (12, 12), (13, 13), (12, 13), (13, 14)]: m[p] = 'P'
for p in [(11, 12), (12, 14)]: m[p] = 'p'
I['corda'] = (m, None)
add('fibra', ["",
    "....P.G.P.G",
    "...PGPGPGP",
    "....PGPGPG",
    "....PGPGP",
    ".....PGPG",
    ".....PGPG",
    ".....wWWw",
    ".....wWWw",
    ".....PGPG",
    "....PGPGPG",
    "...PGPGPGPG",
    "..PGP.GPG.PG",
    "..P...G.P..G"])
EQUIP['peito'] = grade(["",
    "...33......33",
    "..3443....3322",
    ".344433333322221",
    ".34433333322221",
    "..343333332221",
    "..343333332221",
    "..343333332221",
    "..333333322221",
    "..3wWWWWwwwww1",
    "..333333222221",
    "...3333222211",
    "....22222111"])
for y in range(4, 9): EQUIP['peito'][(7, y)] = '4' if y < 6 else '3'
EQUIP['luvas'] = grade(["", "",
    "....34.34.34",
    "....34.34.34",
    "....34234234",
    "....33333333233",
    "....3333333323",
    "....3333333332",
    "....333333332",
    "....23333322",
    "...wWWWWWWWw",
    "...wWWWWWWWw",
    "...uwwwwwwwu"])
b = {}
ret(b, 8, 2, 11, 8, '2'); ret(b, 8, 2, 11, 3, 'w'); ret(b, 9, 4, 9, 8, '3'); ret(b, 8, 9, 13, 10, '2'); ret(b, 8, 11, 13, 11, '1')
ret(b, 3, 4, 6, 10, '3'); ret(b, 4, 6, 4, 10, '4'); ret(b, 3, 4, 6, 5, 'W'); ret(b, 3, 5, 6, 5, 'w')
ret(b, 3, 11, 9, 12, '3'); ret(b, 4, 11, 6, 11, '4'); ret(b, 3, 13, 9, 13, '1'); ret(b, 6, 6, 6, 10, '2')
EQUIP['botas'] = b
add('capa_viagem', ["",
    "......ggggg",
    ".....gGgggqg",
    ".....gGkkkqg",
    ".....gGkkkqg",
    "....ggGyYyqgg",
    "...gGgGgggqqqg",
    "...gGggGgqgqqg",
    "..gGgggGgqgqqqg",
    "..gGgggGgqgqqqg",
    "..gGgggGgqgqqqg",
    ".gGggggGgqgqqqg",
    ".ggggggggqqqqqq"])
m = {}
linha(m, (3, 12), (12, 2), 'W'); linha(m, (4, 12), (13, 2), 'w')
linha(m, (1, 14), (3, 12), 'u'); linha(m, (2, 14), (4, 12), 'P')
for p in [(6, 9), (7, 9), (9, 6), (10, 6)]: m[p] = 's'
m[(5, 11)] = 'd'; m[(6, 12)] = 's'; m[(5, 12)] = 'S'; m[(6, 11)] = 'd'
for y in range(3, 12): m[(14, y)] = 'N'
m[(14, 12)] = 's'; m[(13, 13)] = 's'; m[(14, 13)] = 's'; m[(12, 12)] = 's'
I['vara_reforcada'] = (m, None)
I['escama_dragao'][0].update({(6, 7): 'r', (7, 8): 'r', (8, 8): 'r', (9, 7): 'r', (7, 10): 'r', (8, 10): 'r'})

def salvar(path, im):
    os.makedirs(os.path.dirname(path), exist_ok=True); im.save(path)

if __name__ == '__main__':
    feitos = []
    for n, (g_, rp) in I.items():
        salvar(os.path.join(RAIZ, 'art/ui/icones', n + '.png'), render(g_, rp)); feitos.append('art/ui/icones/' + n + '.png')
    for peca, g_ in EQUIP.items():
        for met, rp in METAL.items():
            salvar(os.path.join(RAIZ, 'art/ui/icones_equip', f'{peca}_{met}.png'), render(g_, rp)); feitos.append(f'art/ui/icones_equip/{peca}_{met}.png')
    print(len(feitos), 'desenhados')
