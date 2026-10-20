"""Texturas pixel-art 32x32 do solo da fazenda (geradas por codigo, sem servico externo).
Terra fofa com 3 camalhoes arredondados e irregulares (nao parece tabua), borda organica.
Estados: arada, semeada (covas com semente), plantada (monte central), cada um seco e molhado.
Saida: art/fazenda/solo/<estado>[_molhada].png + previa."""
import os, sys, random, math
from PIL import Image
raiz = sys.argv[1] if len(sys.argv) > 1 else '.'
OUT = os.path.join(raiz, 'art', 'fazenda', 'solo'); os.makedirs(OUT, exist_ok=True)
N = 32
# rampa de terra (escuro -> claro), seca
SECO = [(58, 40, 28), (78, 54, 36), (98, 68, 45), (116, 82, 54), (134, 97, 64), (150, 112, 76)]
MOLH = [(30, 22, 18), (42, 30, 23), (54, 39, 29), (66, 48, 35), (80, 58, 42), (94, 70, 52)]
SEMENTE = {False: (232, 212, 150), True: (206, 188, 134)}
def perfil(y, x, rnd_off):
    # 3 camalhoes, periodo ~10 px, com ondulacao em x
    yy = y + rnd_off[x]
    f = ((yy - 1) % 10.5) / 10.5           # 0..1 dentro do camalhao
    v = math.sin(f * math.pi)               # 0 no sulco, 1 no topo
    luz = 0.25 if f < 0.45 else -0.15        # face de cima (norte) mais clara
    return v, luz, f
def tile(estado, molh, seed):
    R = MOLH if molh else SECO
    rnd = random.Random(seed)
    off = [round(math.sin(x * 0.55 + seed) * 0.9 + rnd.uniform(-0.4, 0.4)) for x in range(N)]
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0)); px = im.load()
    for y in range(N):
        for x in range(N):
            # borda organica: recorta cantos e alguns pixels da beirada
            dx = min(x, N - 1 - x); dy = min(y, N - 1 - y)
            if dx + dy < 2: continue
            if (dx == 0 or dy == 0) and rnd.random() < 0.35: continue
            v, luz, f = perfil(y, x, off)
            n = rnd.uniform(-0.35, 0.35)
            i = 1 + v * 3.0 + luz * 2 + n
            if dx == 0 or dy == 0: i -= 1.2
            i = max(0, min(len(R) - 1, round(i)))
            px[x, y] = R[i] + (255,)
    # torroes e pedrinhas
    for _ in range(16):
        x, y = rnd.randint(3, N - 4), rnd.randint(3, N - 4)
        v, _, _ = perfil(y, x, off)
        if v > 0.6:
            px[x, y] = R[-1] + (255,); px[x, y + 1] = R[1] + (255,)
    for _ in range(2):
        x, y = rnd.randint(4, N - 5), rnd.randint(4, N - 5)
        px[x, y] = ((128, 122, 112) if not molh else (92, 88, 82)) + (255,)
    if estado == 'semeada':
        for k in range(3):
            ytopo = 1 + k * 10.5 + 10.5 * 0.42
            for j, x in enumerate(range(6 + (k % 2) * 4, N - 4, 8)):
                y = int(round(ytopo - off[x]))
                for ddx in (-1, 0, 1, 2):
                    for ddy in (-1, 0, 1, 2):
                        if abs(ddx - 0.5) + abs(ddy - 0.5) < 2.5:
                            px[x + ddx, y + ddy] = R[0] + (255,)
                for ddx in (-1, 0, 1, 2):
                    px[x + ddx, y - 2] = R[-1] + (255,)
                for p in ((0, 0), (1, 0), (0, 1), (1, 1)):
                    px[x + p[0], y + p[1]] = SEMENTE[molh] + (255,)
                px[x, y] = (255, 246, 210, 255) if not molh else (236, 224, 180, 255)
    if estado == 'plantada':
        c = N / 2 - 0.5
        for y in range(3, N - 3):
            for x in range(3, N - 3):
                d = math.hypot(x - c, (y - c) * 1.1)
                if d < 6.5:
                    i = 2 + (6.5 - d) / 6.5 * 3 + (0.8 if y < c else -0.4) + rnd.uniform(-0.3, 0.3)
                    px[x, y] = R[max(0, min(5, round(i)))] + (255,)
                elif d < 7.8:
                    px[x, y] = R[0] + (255,)
    return im
ims = []
for e in ('arada', 'semeada', 'plantada'):
    for m in (False, True):
        im = tile(e, m, 11); im.save(os.path.join(OUT, e + ('_molhada' if m else '') + '.png')); ims.append(im)
# previa: cada estado em 2x2 lado a lado (mostra emenda entre celulas)
prev = Image.new('RGB', (6 * 140 + 8, 148), (86, 128, 52))
for i, im in enumerate(ims):
    big = im.resize((64, 64), Image.NEAREST)
    for a in range(2):
        for b in range(2):
            prev.paste(big, (8 + i * 140 + a * 64, 10 + b * 64), big)
prev.save(os.path.join(raiz, 'solo_previa.png'))
print('ok')
