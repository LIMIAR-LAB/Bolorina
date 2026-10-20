"""Vale unica: o desenho do combate (Gamelab) tambem na vila/fazenda/masmorra.
Local, sem rede, sem custo. Entrada: work/vale_unica/bases/<dir>.png (pose parada sem espada, 512 px, fundo
transparente) e work/vale_unica/videos/{run,tend}_<dir>.mp4 (960 px, fundo magenta #FF00FF, 24 qps).
Saida: art/characters/vale_unica/ no MESMO formato de original_vale_v6 (rotations/, run/<dir>/NNN.png,
tend/<dir>/NNN.png, walk = run, manifest.json), celula 48 px, pes embaixo, paleta da V6 (a mesma ideia das
folhas vale_combate_v6pal: cada cor vai para a cor mais proxima da paleta V6 em Lab).
- escala: a pose parada de cada direcao fica com ALTURA px (igual a Vale de guarda do combate, ~45 px);
  correr/agir usam a escala da propria base daquela direcao (o 1o quadro do video e a base).
- run: um ciclo de passada (periodo medido no video) em 8 quadros; tend: 5 quadros no ciclo inteiro.
- west/south-west/north-west: espelho de east/south-east/north-east; tend_north = tend_north-east (nao gerado).
Uso: python tools/vale_unica_quadros.py <raiz> [--previa]"""
import os, sys, json, glob
import numpy as np, cv2
from PIL import Image
R = sys.argv[1] if len(sys.argv) > 1 else '.'
W = os.path.join(R, 'work/vale_unica/')
OUT = os.path.join(R, 'art/characters/vale_unica/')
V6 = os.path.join(R, 'art/characters/original_vale_v6/')
CEL = 48
ALTURA = 45
GERADAS = ['south', 'south-east', 'east', 'north-east', 'north']
ESPELHO = {'west': 'east', 'south-west': 'south-east', 'north-west': 'north-east'}
DIRS = ['south', 'south-west', 'west', 'north-west', 'north', 'north-east', 'east', 'south-east']


def lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


# paleta V6 (rotacoes + corrida), cores que aparecem pelo menos 3 vezes
_cont = {}
for f in glob.glob(V6 + 'rotations/*.png') + glob.glob(V6 + 'run/*/*.png'):
    a = np.asarray(Image.open(f).convert('RGBA'))
    for c in map(tuple, a[a[..., 3] > 128][:, :3]):
        _cont[c] = _cont.get(c, 0) + 1
PAL = np.array([c for c, n in _cont.items() if n >= 3], float)
PAL_L = lab(PAL)


def paleta_v6(rgb):
    L = lab(rgb.astype(float))
    i = np.argmin(((L[:, None, :] - PAL_L[None]) ** 2).sum(-1), 1)
    return PAL[i].astype(np.uint8)


def sem_magenta(bgr):
    """RGBA a partir do quadro do video (fundo magenta)"""
    rgb = bgr[..., ::-1].astype(int)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mag = np.minimum(r, b) - g
    fundo = (mag > 90) & (r > 120) & (b > 120)
    borda = (mag > 45) & (r > 90) & (b > 90)     # franja rosada do chroma
    a = np.where(fundo | borda, 0, 255).astype(np.uint8)
    # tira ilhas pequenas (sujeira do video)
    n, lab_, st, _ = cv2.connectedComponentsWithStats((a > 0).astype(np.uint8), 8)
    if n > 1:
        maior = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
        keep = np.zeros(n, bool)
        keep[maior] = True
        keep[1:] |= st[1:, cv2.CC_STAT_AREA] > 0.02 * st[maior, cv2.CC_STAT_AREA]
        a[~keep[lab_]] = 0
    return np.dstack([rgb.astype(np.uint8), a])


def reduzir(rgba, s):
    """reducao por area (pre-multiplicada) para escala s, alfa por limiar, paleta V6"""
    H, W_ = rgba.shape[:2]
    h, w = max(1, int(round(H * s))), max(1, int(round(W_ * s)))
    a = rgba[..., 3:4].astype(float) / 255
    pm = rgba[..., :3].astype(float) * a
    pm_s = cv2.resize(pm, (w, h), interpolation=cv2.INTER_AREA)
    a_s = cv2.resize(a[..., 0], (w, h), interpolation=cv2.INTER_AREA)
    out = np.zeros((h, w, 4), np.uint8)
    m = a_s > 0.5
    cor = pm_s[m] / np.maximum(a_s[m][:, None], 1e-3)
    out[m, :3] = paleta_v6(np.clip(cor, 0, 255))
    out[m, 3] = 255
    return out


def caixa(a):
    ys, xs = np.where(a[..., 3] > 0)
    return ys.min(), ys.max(), xs.min(), xs.max()


def celula(spr, cx, base_y=CEL - 1):
    """poe o sprite reduzido numa celula 48x48: pes na linha base_y, centro x do corpo em 24"""
    out = np.zeros((CEL, CEL, 4), np.uint8)
    y0, y1, x0, x1 = caixa(spr)
    oy = base_y - y1
    ox = int(round(CEL / 2 - cx))
    for y in range(y0, y1 + 1):
        ty = y + oy
        if not 0 <= ty < CEL:
            continue
        for x in range(x0, x1 + 1):
            tx = x + ox
            if 0 <= tx < CEL and spr[y, x, 3]:
                out[ty, tx] = spr[y, x]
    return out


def contorno(a):
    """1 px de contorno escuro onde a reducao deixou a borda sem linha (como os sprites da V6)"""
    m = a[..., 3] > 0
    viz = np.zeros_like(m)
    viz[1:] |= m[:-1]; viz[:-1] |= m[1:]; viz[:, 1:] |= m[:, :-1]; viz[:, :-1] |= m[:, 1:]
    lum = a[..., :3].astype(int).sum(-1)
    borda = m & ~(np.pad(m, 1)[2:, 1:-1] & np.pad(m, 1)[:-2, 1:-1] & np.pad(m, 1)[1:-1, 2:] & np.pad(m, 1)[1:-1, :-2])
    escuro = borda & (lum > 200)
    a = a.copy()
    a[escuro, :3] = (a[escuro, :3].astype(int) * 0.45).astype(np.uint8)
    return a


def largura_cabeca(a):
    """largura do sprite na linha a 18% da altura (cabelo/cabeca): nao muda com pernas e bracos"""
    y0, y1, x0, x1 = caixa(a)
    y = int(y0 + 0.18 * (y1 - y0))
    xs = np.where(a[y, :, 3] > 0)[0]
    return float(xs.max() - xs.min() + 1) if len(xs) else 1.0


def quadros_video(caminho):
    c = cv2.VideoCapture(caminho)
    fr = []
    while True:
        ok, f = c.read()
        if not ok:
            break
        fr.append(sem_magenta(f))
    return fr


def periodo(qs):
    """lag (em quadros) que mais repete a pose: um ciclo de passada"""
    peq = [cv2.resize(q[..., 3], (96, 96), interpolation=cv2.INTER_AREA).astype(float) for q in qs]
    melhor = None
    for p in range(8, min(40, len(peq) // 2)):
        e = np.mean([np.abs(peq[t] - peq[t + p]).mean() for t in range(4, len(peq) - p)])
        if melhor is None or e < melhor[0]:
            melhor = (e, p)
    return melhor[1]


def main():
    escala = {}
    cabeca_base = {}
    escala_run = {}
    centro = {}
    sprites = {}
    for d in GERADAS:
        b = np.asarray(Image.open(W + 'bases/%s.png' % d).convert('RGBA')).copy()
        b[..., 3] = np.where(b[..., 3] > 128, 255, 0)
        y0, y1, x0, x1 = caixa(b)
        s = ALTURA / float(y1 - y0 + 1)
        r = reduzir(b, s)
        ry0, ry1, rx0, rx1 = caixa(r)
        centro[d] = (rx0 + rx1) / 2.0
        sprites[('rot', d)] = [contorno(celula(r, centro[d]))]
        escala[d] = s
        cabeca_base[d] = largura_cabeca(b)
    for mov, n_q in (('run', 8), ('tend', 5)):
        for d in GERADAS:
            v = W + 'videos/%s_%s.mp4' % (mov, d)
            if not os.path.exists(v):
                continue
            qs = quadros_video(v)
            # escala do video: correndo, a altura mediana dos quadros = ALTURA (mesma altura da Vale parada,
            # como o jogo exige: altura constante parada/andando/correndo); agir usa a escala da corrida
            # daquela direcao (a pose agachada fica mais baixa de verdade)
            if mov == 'run':
                hs = [caixa(q)[1] - caixa(q)[0] + 1 for q in qs[::3]]
                s = ALTURA / float(np.median(hs))
                escala_run[d] = s
            else:
                s = escala_run.get(d, escala[d])
            if mov == 'run':
                p = periodo(qs)
                ini = 6
                idx = [ini + int(round(i * p / n_q)) for i in range(n_q)]
            else:
                idx = [int(round(i * (len(qs) - 2) / n_q)) for i in range(n_q)]
            red = [reduzir(qs[i], s) for i in idx]
            # centro x pela caixa do 1o quadro reduzido (o corpo nao anda dentro do video)
            r0 = reduzir(qs[0], s)
            a0 = caixa(r0)
            cx = (a0[2] + a0[3]) / 2.0
            sprites[(mov, d)] = [contorno(celula(r, cx)) for r in red]
            print(mov, d, 'quadros', idx, 'escala %.4f' % s)
    for w, e in ESPELHO.items():
        for k in ('rot', 'run', 'tend'):
            if (k, e) in sprites:
                sprites[(k, w)] = [q[:, ::-1].copy() for q in sprites[(k, e)]]
    if ('tend', 'north') not in sprites:
        sprites[('tend', 'north')] = [q.copy() for q in sprites[('tend', 'north-east')]]
    # grava no formato da V6
    man = {'original': True, 'directional': True,
           'source': 'Gamelab (projeto 32737), desenho do combate da Vale sem espada; ver work/vale_unica/jobs.json',
           'directions': DIRS, 'world_height': 1.72, 'anims': {}}
    fps = {'idle': 6, 'run': 14, 'walk': 10, 'tend': 6}
    for d in DIRS:
        for anim, k, pasta in (('idle', 'rot', 'rotations'), ('run', 'run', 'run/' + d), ('walk', 'run', 'walk/' + d),
                               ('tend', 'tend', 'tend/' + d)):
            qs = sprites[(k, d)]
            os.makedirs(OUT + pasta, exist_ok=True)
            files = []
            for i, q in enumerate(qs):
                nome = ('%s/%s.png' % (pasta, d)) if anim == 'idle' else ('%s/%03d.png' % (pasta, i))
                Image.fromarray(q).save(OUT + nome)
                files.append(nome)
            todos = np.concatenate([q[..., 3] for q in qs], 1) if qs else None
            ys = [caixa(q) for q in qs]
            x0 = min(c[2] for c in ys); x1 = max(c[3] for c in ys); y0 = min(c[0] for c in ys)
            man['anims']['%s_%s' % (anim, d)] = {'files': files, 'fps': fps[anim], 'loop': True,
                                                 'bounds': [int(x0), int(y0), int(x1) + 1, CEL], 'size': [CEL, CEL],
                                                 'feet': [CEL] * len(files)}
    json.dump(man, open(OUT + 'manifest.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    previa(sprites)
    print('ok', len(man['anims']), 'animacoes')


def previa(sprites):
    k = 4
    linhas = [('rot', 'parada'), ('run', 'correndo'), ('tend', 'agir')]
    larg = max(len(sprites[(m, d)]) for m, _ in linhas for d in DIRS)
    im = Image.new('RGBA', (len(DIRS) * larg * CEL * k // 2 + 8, 3 * CEL * k), (201, 164, 106, 255))
    x = 0
    for d in DIRS:
        for r, (m, _) in enumerate(linhas):
            for i, q in enumerate(sprites[(m, d)]):
                im.alpha_composite(Image.fromarray(q).resize((CEL * k // 2, CEL * k // 2), Image.NEAREST),
                                   (x + i * CEL * k // 2, r * CEL * k))
        x += larg * CEL * k // 2
    im.save(W + 'previa_quadros.png')


if __name__ == '__main__':
    main()
