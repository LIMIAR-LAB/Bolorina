"""Mapa-mundi esquematico da Ilha das Cinzas (pergaminho), gerado por codigo.
Saida: art/ui/mapa_esquematico.png (1200x800) + art/ui/mapa_mundi.json (centro/raio de cada area no mapa
e limites do mundo de cada cena, usado pelo jogo para pôr o "Você está aqui" na posicao real do jogador).
Conexoes = as saidas reais do codigo (scripts/ilha/caminhos_ilha.gd):
  Fazenda (saida leste) -> Vila (entrada sul) | Vila (leste) -> Arena | Vila (portao das ruinas, norte) -> Masmorra.
Planejado (em breve): Floresta/Bento, Ermida da Iara, Lago Grande/Joaquim, Vila Grande (lojas/porto), ilhas flutuantes."""
import sys, os, math, random, json
from PIL import Image, ImageDraw, ImageFont
raiz = sys.argv[1] if len(sys.argv) > 1 else '.'
W, H = 1200, 800
rnd = random.Random(7)
im = Image.new('RGB', (W, H), (40, 52, 74))
d = ImageDraw.Draw(im, 'RGBA')
def fonte(t, bold=True):
    for f in (['/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'] if bold else
              ['/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']):
        if os.path.exists(f): return ImageFont.truetype(f, t)
    return ImageFont.load_default()
F1, F2, F3, F4 = fonte(30), fonte(18), fonte(14), fonte(13, False)
TINTA = (80, 60, 40)
# ilha (blob) — mesmo pergaminho do mapa anterior
pts = []
for i in range(90):
    a = i / 90 * math.tau
    r = 1 + 0.08 * math.sin(a * 5 + 1) + 0.05 * math.sin(a * 11) + rnd.uniform(-0.02, 0.02)
    pts.append((600 + math.cos(a) * 520 * r, 410 + math.sin(a) * 340 * r))
d.polygon(pts, fill=(214, 196, 150), outline=(120, 92, 60))
# ilhas flutuantes (futuro), no ceu do canto
for (x, y, r) in [(120, 120, 34), (205, 78, 22), (60, 205, 18)]:
    d.ellipse([x - r, y - r * 0.55, x + r, y + r * 0.55], fill=(150, 160, 170, 140))
    for k in range(0, 360, 20):
        a0, a1 = math.radians(k), math.radians(k + 10)
        d.line([(x + math.cos(a0) * r, y + math.sin(a0) * r * 0.55), (x + math.cos(a1) * r, y + math.sin(a1) * r * 0.55)], fill=(220, 226, 236), width=2)
d.text((40, 240), "Ilhas flutuantes (futuro)", font=F4, fill=(220, 226, 236))

# regioes: id, nome, centro, raio, cor, estado ('jogavel' | 'prototipo' | 'em_breve'), mundo (xmin,zmin,xmax,zmax)
REG = [
    ("fazenda", "Fazenda", (360, 610), 115, (150, 176, 92), "jogavel", (-27, -23, 46, 23)),
    ("vila", "Vila", (620, 440), 108, (196, 160, 112), "jogavel", (-43, -41, 31, 29)),
    ("ruinas", "Ruínas do Norte (borda da vila)", (600, 272), 70, (150, 140, 128), "jogavel", None),
    ("arena", "Arena dos Orcs", (905, 430), 80, (176, 120, 96), "jogavel", (-11, -9, 11, 9)),
    ("masmorra", "Masmorra (protótipo)", (585, 98), 86, (122, 112, 104), "prototipo", None),
    ("floresta", "Floresta / Cabana do Bento", (180, 505), 72, (86, 120, 70), "em_breve", None),
    ("ermida", "Ermida da Iara (penhasco)", (880, 225), 60, (160, 150, 150), "em_breve", None),
    ("lago", "Lago Grande / Seu Joaquim", (690, 690), 66, (96, 146, 184), "em_breve", None),
    ("vila_grande", "Vila Grande (lojas/porto)", (810, 545), 60, (196, 160, 112), "em_breve", None),
]
def elipse_tracejada(x, y, r, cor=TINTA, w=3, passo=12):
    for k in range(0, 360, passo):
        a0, a1 = math.radians(k), math.radians(k + passo / 2)
        d.line([(x + math.cos(a0) * r, y + math.sin(a0) * r * 0.72), (x + math.cos(a1) * r, y + math.sin(a1) * r * 0.72)], fill=cor, width=w)
for rid, nome, (x, y), r, cor, est, _ in REG:
    bb = [x - r, y - r * 0.72, x + r, y + r * 0.72]
    if est == "em_breve":
        d.ellipse(bb, fill=cor + (95,))          # desbotada
        elipse_tracejada(x, y, r, (80, 60, 40, 170))
    elif est == "prototipo":
        d.ellipse(bb, fill=cor, outline=TINTA, width=3)
        hach = Image.new('RGBA', (W, H), (0, 0, 0, 0)); hd = ImageDraw.Draw(hach)
        for k in range(-int(r) - 30, int(r) + 30, 14):      # hachura = prototipo
            hd.line([(x + k - 20, y + r * 0.72), (x + k + 20, y - r * 0.72)], fill=(70, 62, 58, 110), width=2)
        mask = Image.new('L', (W, H), 0); ImageDraw.Draw(mask).ellipse([bb[0] + 3, bb[1] + 3, bb[2] - 3, bb[3] - 3], fill=255)
        im.paste(hach, (0, 0), Image.composite(hach, Image.new('RGBA', (W, H), (0, 0, 0, 0)), mask))
    else:
        d.ellipse(bb, fill=cor, outline=TINTA, width=3)

# rio da vila (atravessa a borda oeste da vila e segue para o lago)
d.line([(565, 345), (588, 410), (615, 480), (655, 560), (688, 640)], fill=(80, 130, 180), width=8)

def trilha(pontos, plan=False, cor=(110, 76, 44), w=6):
    for a, b in zip(pontos, pontos[1:]):
        n = max(1, int(math.dist(a, b) / 14))
        for i in range(n):
            if plan and i % 2: continue
            t0, t1 = i / n, (i + (0.6 if plan else 0.85)) / n
            d.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0), (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], fill=cor, width=w)
def portao(x, y, rot):
    d.rectangle([x - 7, y - 7, x + 7, y + 7], fill=(255, 196, 96), outline=(90, 50, 20), width=2)
    w = d.textlength(rot, font=F4)
    d.text((x - w / 2, y + 9), rot, font=F4, fill=(60, 36, 16))
# conexoes REAIS (saidas no codigo). Pontas calculadas na borda de cada elipse.
R = {rid: (c, r) for rid, nome, c, r, cor, est, m in REG}
def borda(rid, ang):
    (x, y), r = R[rid]
    a = math.radians(ang)
    return (x + math.cos(a) * r, y + math.sin(a) * r * 0.72)
f_e, v_s = borda("fazenda", -8), borda("vila", 95)
trilha([f_e, (f_e[0] + 60, f_e[1] - 4), (v_s[0] - 25, v_s[1] + 45), v_s])   # fazenda: saida leste -> vila: entrada sul
v_l, a_o = borda("vila", 0), borda("arena", 180)
trilha([v_l, a_o])                                                       # vila leste -> arena (portao oeste)
v_n, r_s = borda("vila", 265), borda("ruinas", 90)
trilha([v_n, r_s])                                                       # vila -> ruinas (mesma cena)
r_n, m_s = borda("ruinas", 268), borda("masmorra", 90)
trilha([r_n, m_s], cor=(70, 110, 170))                                   # ruinas: portao -> masmorra
portao(*f_e, "saída leste")
portao(*v_s, "")
portao(*v_l, "")
portao(*a_o, "")
portao(*r_n, "")
# planejadas
trilha([borda("fazenda", 190), borda("floresta", 20)], True)            # fazenda (oeste do lago) -> floresta
trilha([borda("ruinas", -10), borda("ermida", 175)], True)              # ruinas -> ermida (escadaria)
trilha([borda("vila", 35), borda("vila_grande", 210)], True)            # vila -> vila grande (lojas/porto)
trilha([borda("vila", 75), borda("lago", 265)], True)                   # vila -> lago (ponte)

def casa(x, y):
    d.polygon([(x - 10, y), (x, y - 10), (x + 10, y)], fill=(130, 60, 40)); d.rectangle([x - 8, y, x + 8, y + 10], fill=(230, 210, 170), outline=(60, 40, 30))
for c in [(345, 590), (605, 425), (645, 440), (630, 405), (180, 495), (880, 215), (690, 680), (810, 535)]: casa(*c)
# lago da fazenda
d.ellipse([290, 620, 335, 650], fill=(96, 146, 184), outline=(70, 110, 150))
# canteiros da fazenda
for i in range(3):
    d.rectangle([380 + i * 16, 615, 392 + i * 16, 640], fill=(110, 84, 54))
for x, y in [(555, 95), (595, 75), (628, 102)]:
    d.polygon([(x - 30, y + 25), (x, y - 25), (x + 30, y + 25)], fill=(100, 92, 86), outline=(60, 54, 50))
    d.polygon([(x - 9, y - 10), (x, y - 25), (x + 9, y - 10)], fill=(236, 236, 240))
for x, y in [(585, 265), (615, 260), (600, 288)]:
    d.rectangle([x - 4, y - 18, x + 4, y + 8], fill=(120, 116, 110), outline=(60, 56, 52))
# arena: circulo ritual
d.ellipse([885, 415, 925, 445], outline=(215, 160, 70), width=3)

for rid, nome, (x, y), r, cor, est, _ in REG:
    rot = nome + ("  · em breve" if est == "em_breve" else "")
    f = F2 if est != "em_breve" else F3
    w = d.textlength(rot, font=f)
    tx = min(max(x - w / 2 + {"vila": -70}.get(rid, 0), 18), W - w - 18)
    d.text((tx + 1, y + r * 0.72 + 5), rot, font=f, fill=(30, 20, 12, 160 if est == "em_breve" else 255))
    d.text((tx, y + r * 0.72 + 4), rot, font=f, fill=(54, 34, 18, 170 if est == "em_breve" else 255))
d.text((40, 24), "ILHA DAS CINZAS — mapa", font=F1, fill=(246, 230, 190))
# legenda
LX, LY = 860, 618
d.rectangle([LX, LY, LX + 320, LY + 162], fill=(232, 216, 176), outline=(90, 64, 40), width=3)
d.text((LX + 15, LY + 8), "Legenda", font=F2, fill=(60, 40, 20))
d.ellipse([LX + 18, LY + 40, LX + 42, LY + 56], fill=(196, 160, 112), outline=TINTA, width=2); d.text((LX + 52, LY + 38), "área jogável", font=F3, fill=(60, 40, 20))
d.ellipse([LX + 18, LY + 64, LX + 42, LY + 80], fill=(122, 112, 104), outline=TINTA, width=2)
d.line([(LX + 22, LY + 78), (LX + 36, LY + 66)], fill=(96, 88, 82), width=2); d.text((LX + 52, LY + 62), "protótipo", font=F3, fill=(60, 40, 20))
d.ellipse([LX + 18, LY + 88, LX + 42, LY + 104], fill=(196, 160, 112, 95), outline=(80, 60, 40, 170), width=2); d.text((LX + 52, LY + 86), "em breve (planejada)", font=F3, fill=(60, 40, 20))
d.line([(LX + 18, LY + 122), (LX + 42, LY + 122)], fill=(110, 76, 44), width=6); d.text((LX + 52, LY + 113), "trilha real", font=F3, fill=(60, 40, 20))
d.line([(LX + 150, LY + 122), (LX + 160, LY + 122)], fill=(110, 76, 44), width=5); d.line([(LX + 166, LY + 122), (LX + 176, LY + 122)], fill=(110, 76, 44), width=5); d.text((LX + 184, LY + 113), "planejada", font=F3, fill=(60, 40, 20))
d.rectangle([LX + 24, LY + 136, LX + 36, LY + 148], fill=(255, 196, 96), outline=(90, 50, 20), width=2); d.text((LX + 52, LY + 134), "saída / portão", font=F3, fill=(60, 40, 20))
d.line([(LX + 180, LY + 142), (LX + 204, LY + 142)], fill=(80, 130, 180), width=7); d.text((LX + 212, LY + 134), "rio", font=F3, fill=(60, 40, 20))
# rosa dos ventos
cx, cy = 1110, 90
d.polygon([(cx, cy - 40), (cx + 9, cy), (cx, cy + 40), (cx - 9, cy)], fill=(246, 230, 190), outline=(60, 40, 20))
d.text((cx - 6, cy - 66), "N", font=F2, fill=(246, 230, 190))
saida = os.path.join(raiz, 'art', 'ui')
os.makedirs(saida, exist_ok=True)
im.save(os.path.join(saida, 'mapa_esquematico.png'))
meta = {rid: {"nome": nome, "centro": list(c), "raio": [r, round(r * 0.72, 1)], "estado": est, "mundo": list(m) if m else None}
        for rid, nome, c, r, cor, est, m in REG}
json.dump(meta, open(os.path.join(saida, 'mapa_mundi.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(json.dumps({k: v["centro"] for k, v in meta.items()}))
