"""Gera scripts/modular/vila_layout.json: vila V7 modular (grade 1 m) desenhada sobre a referencia.
As posicoes sao escritas em pixels da referencia 1600x900, convertidas pela camera V7
(tools/fidelidade_mapa.py) para o chao e ENCAIXADAS na grade. Uso: python tools/fidelidade_layout.py [--preview]"""
import json, math, sys, numpy as np
sys.path.insert(0, __file__.rsplit("\\",1)[0].rsplit("/",1)[0])
import fidelidade_mapa as M
ROOT = __file__.replace("\\","/").rsplit("/tools/",1)[0]
DELTA = np.array([-4.67, 0.0, -7.0])   # desloca a vila: rio na faixa z~7.5, ponte em x=0
T = M.T + DELTA
def W(px, py, h=0.0):
    w = M.to_world(px, py, T, h); return [round(float(w[0]),2), round(float(w[2]),2)]
def S(x, z, h=0.0):
    return M.to_screen([x,h,z], T)
def cell(px, py, h=0.0):
    x, z = W(px, py, h); return [int(round(x)), int(round(z))]

X0, X1, Z0, Z1 = -44, 32, -42, 30   # vertices da grade de terreno
# ---------------------------------------------------------------- rio e caminhos (pixels)
RIO = [(70,215),(115,330),(150,460),(240,600),(330,700),(470,770),(640,830),(820,870),(1000,900),(1150,940)]
RIO_LARG = 3.6
CAMINHOS = [
    ([(170,285),(420,335),(600,395),(780,440),(900,455),(1100,475)], 3.0),
    ([(860,170),(885,300),(875,430)], 2.4),
    ([(880,460),(810,560),(720,680),(600,735)], 2.8),
    ([(290,795),(170,880)], 2.6),
    ([(900,480),(950,600),(1010,760),(1080,900)], 2.4),
    ([(1000,520),(1250,770),(1450,900)], 2.0),
]
PRACAS = [((880,450), 3.4), ((1140,470), 1.6), ((600,395), 1.6)]
CAMPO = [(1100,585),(1310,505),(1500,600),(1260,690)]
HORTA = [(120,405),(330,330),(560,455),(370,535)]
def borda(px):   # limite superior do plato (pixels); acima disso: abismo com nevoa
    if px <= 980: return -1e9
    if px <= 1340: return 140 + (px-980)/360*130
    return 270 + min(1.0,(px-1340)/80)*160
def saliencia(px, py):   # patamar alto da cachoeira (canto superior esquerdo)
    return px < 300 and py < 205 - max(0, px-200)*0.6

def dist_seg(p, a, b):
    ab = b-a; t = np.clip(np.dot(p-a,ab)/max(1e-9,np.dot(ab,ab)), 0, 1); return np.linalg.norm(p-(a+ab*t))
def dist_poly(p, pts):
    return min(dist_seg(p, pts[i], pts[i+1]) for i in range(len(pts)-1))
def inside(p, poly):
    c = False; n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i+1)%n]
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1]+1e-12)+a[0]: c = not c
    return c
def smooth(e0, e1, x):
    t = min(1,max(0,(x-e0)/(e1-e0))); return t*t*(3-2*t)

rio_w = [np.array(W(*p)) for p in RIO]
cam_w = [([np.array(W(*p)) for p in pts], w) for pts, w in CAMINHOS]
pra_w = [(np.array(W(*c)), r) for c, r in PRACAS]
campo_w = [W(*p) for p in CAMPO]; horta_w = [W(*p) for p in HORTA]

alturas = []; tipos = []
for z in range(Z0, Z1+1):
    linha = []; ltipo = []
    for x in range(X0, X1+1):
        p = np.array([x, z], float)
        px, py = S(x, z)
        h = 0.0; t = "g"
        if py < borda(px):
            h = -30.0; t = "r"
        elif saliencia(px, py):
            h = 3.6; t = "r"
        d = dist_poly(p, rio_w)
        if h > -1 and d < RIO_LARG/2+0.7:
            h = min(h, -0.85*(1-smooth(RIO_LARG/2-0.5, RIO_LARG/2+0.6, d)) if h <= 0 else h)
            if d < RIO_LARG/2+0.2 and h <= 0: t = "b"   # margem/leito
        linha.append(round(h,2))
        if t == "g":
            if any(dist_poly(p, pts) < w/2 for pts, w in cam_w) or any(np.linalg.norm(p-c) < r for c, r in pra_w): t = "c"
            elif inside([x,z], campo_w): t = "t"
            elif inside([x,z], horta_w): t = "h"
        ltipo.append(t)
    alturas.append(linha); tipos.append("".join(ltipo))

pecas = []
def P(mid, px, py, rot=0, h=0.0, **extra):
    c = cell(px, py, h); d = {"id": mid, "celula": c, "rot": rot}
    if h: d["y"] = h
    d.update(extra); pecas.append(d)
def cerca(a, b, h=0.0):
    (x0, z0), (x1, z1) = cell(*a), cell(*b)
    # cerca encaixada: corrida em x e depois em z (modulos de 1 m)
    sx = 1 if x1 >= x0 else -1
    for x in range(x0, x1, sx): pecas.append({"id":"cerca","celula":[x+0.5*sx-0.5*sx,z0],"rot":0,"de":[x,z0],"ate":[x+sx,z0]})
    sz = 1 if z1 >= z0 else -1
    for z in range(z0, z1, sz): pecas.append({"id":"cerca","celula":[x1,z],"rot":1,"de":[x1,z],"ate":[x1,z+sz]})

# casas (frente local +z; rot 1 = frente para +x)
P("casa", 640, 300, rot=1)
P("casa", 1170, 380, rot=0)
P("poco", 775, 640)
P("menir_runa", 1040, 655)
for q in [(963,478),(690,730),(540,560),(265,375),(55,470),(1005,840),(1240,470)]:
    P("poste_lampiao", *q)
P("carroca_abobora", 175, 355, rot=1)
P("estandarte", 105, 500); P("estandarte", 1120, 285)
P("ponte", 470, 755, rot=0)
# pilares/menires do topo e braseiro
P("pilar_pedra", 840, 150); P("pilar_braseiro", 880, 150); P("pilar_pedra", 985, 190)
# ruinas no abismo (sobre pilares de rocha que sobem do fundo)
P("ruina_arco", 1300, 215, rot=0, h=-1.0); P("ruina_arco", 1540, 300, rot=1, h=-1.5); P("ruina_arco", 1545, 445, rot=1, h=-0.5)
P("ruina_pilar", 270, 230); P("ruina_pilar", 120, 230)
# arvores (recurso madeira) e arbustos
for q, kind in [((390,250),"arvore_escura"),((470,90),"arvore_outono"),((1390,390),"arbusto_flor"),((1600,600),"arbusto_flor"),
                ((760,40),"arvore_seca"),((1310,260),"arvore_seca"),((1580,700),"arvore_escura"),((40,820),"arbusto_flor"),
                ((300,120),"arvore_escura"),((560,60),"arvore_outono"),((1450,620),"arbusto_flor"),((220,850),"arbusto_escuro"),
                ((480,880),"arbusto_escuro"),((1250,880),"arbusto_escuro"),((60,620),"arbusto_flor"),((1500,820),"arbusto_escuro")]:
    P(kind, *q)
for q in [(1350,640),(1330,700),(1430,700),(1450,390),(600,180),(1050,330),(680,860),(1180,720),(130,700)]:
    P("rocha", *q)
for q in [(1060,560),(480,325),(500,360),(445,420),(730,350),(1080,420),(210,580),(980,300)]:
    P("caixote" if q[0]%2 else "barril", *q)
P("banco", 520, 425, rot=1); P("banco", 1010, 545); P("mesa", 1075, 575)
P("cogumelos", 1365, 660); P("cogumelos", 150, 690); P("cogumelos", 620, 200); P("deck", 45, 525, rot=0)
# horta: canteiros com abobora em estagios e couves
for i,q in enumerate([(200,410),(250,395),(300,380),(260,440),(310,425),(360,410),(330,470),(380,455),(430,440),(400,500),(450,485),(500,470)]):
    P("canteiro", *q, cultura=["abobora","couve","abobora","couve"][i%4], estagio=3 if i%3 else 2)
cerca((110,410),(330,325)); cerca((330,325),(560,450)); cerca((560,450),(420,530))
cerca((1100,585),(1310,505)); cerca((1310,505),(1500,600)); cerca((1260,690),(1100,585))
cerca((300,650),(560,560)); cerca((800,760),(1060,880)); cerca((40,500),(140,560))
camera = {"yaw": M.PSI, "pitch": M.THETA, "tamanho": M.SIZE, "alvo": [round(float(T[0]),3), 0.0, round(float(T[2]),3)]}
atores = {"jogador": W(762,500), "mira": W(617,392), "morador": W(918,452), "gato": W(820,490)}
out = {"versao": "v7_modular", "grade_m": 1.0, "origem": [X0, Z0], "tamanho": [X1-X0+1, Z1-Z0+1],
       "legenda_tipos": {"g":"grama","c":"caminho de pedra","t":"terra arada","h":"horta","b":"margem","r":"rocha"},
       "camera": camera, "atores": atores, "rio": {"pontos": [list(map(float,p)) for p in rio_w], "largura": RIO_LARG, "nivel": -0.45},
       "alturas": alturas, "tipos": tipos, "pecas": pecas}
json.dump(out, open(ROOT+"/scripts/modular/vila_layout.json","w",encoding="utf-8"), separators=(",",":"))
print("pecas", len(pecas), "camera", camera, "atores", atores)
if "--preview" in sys.argv:
    from PIL import Image, ImageDraw
    im = Image.open(ROOT+"/docs/referencia-usuario.png").convert("RGB"); d = ImageDraw.Draw(im, "RGBA")
    col = {"g":None,"c":(255,220,120,70),"t":(150,90,40,90),"h":(80,200,80,90),"b":(60,140,255,90),"r":(255,0,255,60)}
    for zi, z in enumerate(range(Z0, Z1)):
        for xi, x in enumerate(range(X0, X1)):
            c = col[tipos[zi][xi]]
            if alturas[zi][xi] < -10: c = (255,0,255,50)
            if c: d.polygon([S(x-0.5,z-0.5),S(x+0.5,z-0.5),S(x+0.5,z+0.5),S(x-0.5,z+0.5)], fill=c)
    for pc in pecas:
        x, z = pc.get("de", pc["celula"]); sx, sy = S(x, z, pc.get("y",0)); d.ellipse([sx-5,sy-5,sx+5,sy+5], outline=(255,0,0,255), width=2); d.text((sx+6,sy-6), pc["id"][:8], fill=(255,255,255,255))
    im.save(ROOT+"/work/layout_preview.png"); print("preview ok")