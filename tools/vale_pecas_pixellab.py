"""Camadas de equipamento a partir da arte do PixelLab (work/pixellab_equip/<peca>/<vista>.png).
Local, sem rede, sem custo. Complementa tools/vale_trajes.py (importa dele as classes de cor e mascaras).

1. RECORTE por vista (rotacao 48 px): alinha a imagem gerada com a rotacao original (deslocamento de ate
   3 px medido na parte que a peca nao toca), tira a diferenca e guarda so a peca:
     capacete: diferenca acima do pescoco (componente ligado a cabeca);  armadura: do pescoco para baixo.
   Pixels que a peca TIRA (cabelo que sobrava para fora do elmo, etc.) viram mascara de apagar.
2. ESPELHO: west/south-west/north-west = east/south-east/north-east espelhadas.
   Vistas que faltam (ex. malha_guarda east/north) sao ADAPTADAS: tabela de cores (cor original -> cor da
   peca) aprendida na vista vizinha e aplicada na rotacao que falta.
3. CARIMBO em cada quadro (vila 48 px: idle/run/walk/tend; combate 112 px: 24 folhas x 49):
     capacete: ancora na caixa do cabelo do quadro (topo + centro; escala pela largura no combate);
     armadura: tronco carimbado pela ancora do corpo (topo + centro; escala pela altura no combate),
               cortado ao corpo do quadro; o resto da roupa (pernas, bracos balancando) pela tabela de cores.
   As rotacoes das 5 vistas geradas entram exatamente como o PixelLab desenhou.
Saida: art/characters/vale_trajes/camadas/<peca>/{vila.png, vila_apagar.png, combate/, combate_apagar/}
       + entradas no indice.json. Previa: docs/equip-pixellab-vistas.png
Uso: python tools/vale_pecas_pixellab.py <raiz do projeto> [--so-vila]"""
import os, sys, json
import numpy as np
from PIL import Image
from scipy import ndimage
R = sys.argv[1] if len(sys.argv) > 1 else '.'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vale_trajes as T  # noqa: E402  (calcula as classes da paleta V6; nao grava nada ao importar)

SRC = os.path.join(R, 'work/pixellab_equip/')
OUT = T.OUT
PECAS = {'capuz_couro': 'cabeca', 'elmo_ferro': 'cabeca', 'elmo_adamantium': 'cabeca',
         'couro_cacador': 'corpo', 'malha_guarda': 'corpo'}
VISTAS = ['south', 'south-east', 'east', 'north-east', 'north']
ESPELHO = {'west': 'east', 'south-west': 'south-east', 'north-west': 'north-east'}
# vista que falta -> vista vizinha de onde vem a tabela de cores
VIZINHA = {'east': ['south-east', 'north-east'], 'north': ['north-east'], 'south': ['south-east'],
           'south-east': ['south', 'east'], 'north-east': ['north', 'east']}
CONTORNO = (26, 15, 14)


# as pecas foram geradas em cima das rotacoes da V6: o recorte e as vistas usam a V6; os quadros do jogo
# (T.base_vila, hoje a Vale unica) recebem a peca pelo carimbo
V6 = os.path.join(R, 'art/characters/original_vale_v6/')
EXATA = os.path.normpath(T.V) == os.path.normpath(V6)  # base do jogo = V6: rotacoes entram exatas


def rot(d):
    return T.carregar(V6 + 'rotations/%s.png' % d)


def pescoco(a, mk):
    """primeira linha da roupa (camisa/colete) = fim da cabeca"""
    roupa = mk['camisa'] | mk['colete']
    ys = np.where(roupa.any(1))[0]
    return int(ys.min()) if len(ys) else a.shape[0] // 2


def desloca(a, dy, dx):
    out = np.zeros_like(a)
    H, W = a.shape[:2]
    ys0, ys1 = max(0, dy), min(H, H + dy)
    xs0, xs1 = max(0, dx), min(W, W + dx)
    out[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def dif(a, b):
    return (np.abs(a.astype(int) - b.astype(int))[..., :3].sum(2) > 30) | ((a[..., 3] > 128) != (b[..., 3] > 128))


def limpa(m, minimo=3):
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    out = np.zeros_like(m)
    for i in range(1, n + 1):
        c = lab == i
        if c.sum() >= minimo:
            out |= c
    return out


def recorte(peca, d):
    """camada (RGBA) + mascara de apagar da peca numa vista gerada, no espaco da rotacao original"""
    B = rot(d)
    G = T.carregar(SRC + '%s/%s.png' % (peca, d))
    mk = T.mascaras(B)
    ny = pescoco(B, mk)
    cab = PECAS[peca] == 'cabeca'
    H = B.shape[0]
    fixo = (np.arange(H)[:, None] >= ny + 2) if cab else (np.arange(H)[:, None] < ny - 4)
    fixo = fixo & (B[..., 3] > 128)
    # alinhamento: deslocamento que mais casa a parte que a peca nao deveria mexer
    melhor = None
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            Gs = desloca(G, dy, dx)
            e = (dif(Gs, B) & fixo).sum()
            if melhor is None or e < melhor[0]:
                melhor = (e, dy, dx)
    _, dy, dx = melhor
    G = desloca(G, dy, dx)
    m = dif(G, B)
    linhas = np.arange(H)[:, None]
    if cab:
        m &= linhas < ny + 3
        # so o que esta ligado a cabeca (o maior componente) + pedacos grandes
        lab, n = ndimage.label(m, structure=np.ones((3, 3)))
        if n:
            tam = ndimage.sum(m, lab, range(1, n + 1))
            grande = np.argmax(tam) + 1
            m = (lab == grande) | np.isin(lab, [i + 1 for i, t in enumerate(tam) if t >= 12])
    else:
        m &= linhas >= ny - 3
        m = limpa(m)
    camada = np.zeros_like(B)
    sel = m & (G[..., 3] > 128)
    camada[sel] = G[sel]
    camada[sel, 3] = 255
    if cab and d in ('north', 'north-east'):
        costas(camada, B, peca, d)
    apagar = m & (G[..., 3] < 128) & (B[..., 3] > 128)
    return camada, apagar, (dy, dx)


def costas(camada, B, peca, d):
    """vista de costas em que o PixelLab desenhou rosto dentro do capacete (capuz NE, elmo de ferro N):
    pele/olhos viram material da peca, com o sombreado da nuca original (quantil de luminancia do cabelo
    da rotacao -> tons da propria peca, sem os extremos de contorno e brilho)"""
    op = camada[..., 3] > 0
    pele = np.zeros_like(op)
    escuro = np.zeros_like(op)
    for y, x in zip(*np.where(op)):
        c = tuple(int(v) for v in camada[y, x, :3])
        if T.classe(c) == 'pele':
            pele[y, x] = True
        elif max(c) < 70:
            escuro[y, x] = True
    peca_m = op & ~pele & ~escuro
    # nao exige o rosto cercado: a abertura do capuz/elmo pode encostar no queixo (fim da camada)
    rosto = pele | (escuro & ndimage.binary_dilation(pele, np.ones((3, 3)), iterations=2))
    rosto &= ndimage.binary_erosion(op | (B[..., 3] > 128), np.ones((3, 3)))  # contorno de fora fica
    if rosto.sum() < 4 or peca_m.sum() < 10:
        return
    if peca.startswith('elmo'):
        # elmo nao cobre a nuca: onde o PixelLab pos rosto, volta o cabelo da rotacao (sai da camada)
        if d == 'north':
            # de costas puras nao ha protecao de nariz: limpa tudo dentro da abertura do rosto
            ys, xs = np.where(rosto)
            cx0, cx1 = np.percentile(xs, 5), np.percentile(xs, 95)
            jan = np.zeros_like(rosto)
            jan[int(ys.min()):, int(cx0):int(cx1) + 1] = True
            rosto |= jan & op
        camada[rosto] = 0
        print('  costas: %s %s -> %d px de rosto tirados (aparece a nuca original)' % (peca, d, int(rosto.sum())))
        return
    tons = camada[peca_m][:, :3].astype(float)
    tons = tons[np.argsort(T.lum(tons))]
    tons = tons[int(0.20 * len(tons)):int(0.92 * len(tons))]
    ref = np.sort(T.lum(B[rosto & (B[..., 3] > 128)][:, :3].astype(float)))
    for y, x in zip(*np.where(rosto)):
        L = T.lum(B[y, x, :3].astype(float)) if B[y, x, 3] > 128 else ref[len(ref) // 2]
        q = np.searchsorted(ref, L) / max(1, len(ref))
        camada[y, x, :3] = tons[min(len(tons) - 1, int(q * len(tons)))]
    print('  costas: %s %s -> %d px de rosto viraram peca' % (peca, d, int(rosto.sum())))


def tabela(peca, vistas_cam):
    """cor original -> cor da peca (a mais comum nos pixels trocados), por regiao (alto/baixo)"""
    cont = {}
    for d, (cam, _ap) in vistas_cam.items():
        if d not in VISTAS:
            continue
        B = rot(d)
        mk = T.mascaras(B)
        roupa = mk['camisa'] | mk['colete'] | mk['calca'] | mk['botas']
        for y, x in zip(*np.where(roupa)):
            reg = 'baixo' if (mk['calca'][y, x] or mk['botas'][y, x]) else 'alto'
            k = (reg, tuple(int(v) for v in B[y, x, :3]))
            # pixel que a peca nao trocou conta como "fica igual"
            c = tuple(int(v) for v in (cam[y, x, :3] if cam[y, x, 3] > 0 else B[y, x, :3]))
            cont.setdefault(k, {}).setdefault(c, 0)
            cont[k][c] += 1
    # contorno preto do PixelLab (tiras, bordas) nao vota, a nao ser que a cor original ja seja contorno
    out = {}
    for k, v in cont.items():
        claro = {c: n for c, n in v.items() if max(c) >= 40} if max(k[1]) >= 40 else v
        out[k] = max((claro or v).items(), key=lambda kv: kv[1])[0]
    return out


def cor_tab(tab, reg, c):
    if (reg, c) in tab:
        return tab[(reg, c)]
    ks = [k for k in tab if k[0] == reg] or list(tab)
    if not ks:
        return None
    a = np.array([k[1] for k in ks], float)
    i = np.abs(a - np.array(c, float)).sum(1).argmin()
    return tab[ks[i]]


def por_tabela(a, mk, tab, so=None):
    """aplica a tabela de cores na roupa de um quadro (so: mascara extra que limita onde pintar)"""
    out = np.zeros_like(a)
    roupa = mk['camisa'] | mk['colete'] | mk['calca'] | mk['botas']
    if so is not None:
        roupa &= so
    for y, x in zip(*np.where(roupa)):
        reg = 'baixo' if (mk['calca'][y, x] or mk['botas'][y, x]) else 'alto'
        orig = tuple(int(v) for v in a[y, x, :3])
        c = cor_tab(tab, reg, orig)
        if c is not None and c != orig:
            out[y, x, :3] = c
            out[y, x, 3] = 255
    return out


def escala(img, s, ancora):
    """reamostra (vizinho mais proximo) mantendo o ponto ancora (y, x) no lugar"""
    if abs(s - 1.0) < 0.06:
        return img
    H, W = img.shape[:2]
    ay, ax = ancora
    yy, xx = np.mgrid[0:H, 0:W]
    sy = np.round(ay + (yy - ay) / s).astype(int)
    sx = np.round(ax + (xx - ax) / s).astype(int)
    ok = (sy >= 0) & (sy < H) & (sx >= 0) & (sx < W)
    out = np.zeros_like(img)
    out[ok] = img[sy[ok], sx[ok]]
    return out


def em_celula(img, H, W, oy, ox):
    """poe img (48x48, espaco da vista) numa celula HxW deslocada por (oy, ox)"""
    h, w = img.shape[:2]
    out = np.zeros((H, W) + img.shape[2:], img.dtype)
    for y in range(h):
        ty = y + oy
        if 0 <= ty < H:
            x0, x1 = max(0, -ox), min(w, W - ox)
            if x1 > x0:
                out[ty, x0 + ox:x1 + ox] = img[y, x0:x1]
    return out


def caixa(m):
    ys, xs = np.where(m)
    if len(ys) == 0:
        return None
    return int(ys.min()), int(ys.max()), int(xs.min()), int(xs.max())


class Vista:
    """camada pronta de uma direcao (no espaco 48 px da rotacao daquela direcao)"""

    def __init__(self, base, camada, apagar, tab):
        self.base, self.camada, self.apagar, self.tab = base, camada, apagar, tab
        self.mk = T.mascaras(base)
        self.ny = pescoco(base, self.mk)
        self.cab = caixa(self.mk['cabelo'])
        roupa = self.mk['camisa'] | self.mk['colete'] | self.mk['calca'] | self.mk['botas']
        self.corpo = caixa(roupa)
        cy = caixa(self.mk['calca'])
        self.cintura = cy[0] if cy else self.ny + 10


def corpo_mask(a, mk=None):
    """pixels do corpo da Vale: maior bloco das classes da paleta V6 (tira arco do golpe, fogo, poeira)"""
    if mk is None:
        mk = T.mascaras(a, a.shape[0] != 48)
    m = mk['cabelo'] | mk['camisa'] | mk['colete'] | mk['calca'] | mk['botas']
    # + pele/contorno da paleta V6 (sem isso a cabeca vira um bloco separado do corpo)
    op = a[..., 3] > 128
    for y, x in zip(*np.where(op & ~m)):
        if tuple(int(v) for v in a[y, x, :3]) in T.V6SET:
            m[y, x] = True
    lab, n = ndimage.label(ndimage.binary_dilation(m, np.ones((3, 3))))
    if n == 0:
        return a[..., 3] > 128
    tam = ndimage.sum(np.ones_like(m), lab, range(1, n + 1))
    return (lab == np.argmax(tam) + 1) & (a[..., 3] > 128)


def topo_centro(a, linhas=10, mk=None):
    """topo do corpo e centro x dos pixels do corpo nas primeiras linhas (cabeca)"""
    if mk is None:
        mk = T.mascaras(a, a.shape[0] != 48)
    op = corpo_mask(a, mk)
    # topo pelo cabelo (o arco branco do golpe pode encostar no corpo e subir o topo)
    cab = mk['cabelo'] & op
    lab, n = ndimage.label(ndimage.binary_closing(cab, np.ones((3, 3))), structure=np.ones((3, 3)))
    if n:  # so o maior bloco de cabelo (fiapos do arco tambem caem na classe cabelo)
        tam = ndimage.sum(np.ones_like(cab), lab, range(1, n + 1))
        cab &= lab == np.argmax(tam) + 1
    ys = np.where((cab if cab.sum() >= 6 else op).any(1))[0]
    if len(ys) == 0:
        return None
    t = int(ys[0])
    xs = np.where((cab if cab.sum() >= 6 else op)[t:t + linhas].any(0))[0]
    return t, (xs.min() + xs.max()) / 2.0


ESCALAS = (0.84, 0.92, 1.0, 1.08)


def casar(v, a, y0, y1, raio=5, mk=None, perto_de=None, custo=False):
    """acha (escala, oy, ox) que poe a regiao [y0, y1) da rotacao da vista em cima do quadro a
    (comparando cor pixel a pixel: e o mesmo personagem desenhado de novo, entao a cabeca/tronco casam)"""
    tb, tq = topo_centro(v.base, mk=v.mk), topo_centro(a, mk=mk)
    if tb is None or tq is None:
        return (999.0, 1.0, 0, 0) if custo else (1.0, 0, 0)
    # perto_de: (oy, ox) de outro encaixe (quadro anterior) para procurar em volta dele
    base_oy = perto_de[0] if perto_de else tq[0] - tb[0]
    base_ox = perto_de[1] if perto_de else int(round(tq[1] - tb[1]))
    H, W = a.shape[:2]
    ys, xs = np.where(v.base[..., 3] > 128)
    sel = (ys >= y0) & (ys < y1)
    ys, xs = ys[sel], xs[sel]
    cor = v.base[ys, xs, :3].astype(int)
    alvo = a[..., :3].astype(int)
    opaco = corpo_mask(a, mk)
    melhor = None
    for s in ESCALAS:
        py = tb[0] + (ys - tb[0]) * s
        px = tb[1] + (xs - tb[1]) * s
        for dy in range(-raio, raio + 1):
            for dx in range(-raio, raio + 1):
                oy = base_oy + dy
                ox = base_ox + dx
                qy = np.round(py + oy).astype(int)
                qx = np.round(px + ox).astype(int)
                ok = (qy >= 0) & (qy < H) & (qx >= 0) & (qx < W)
                e = np.full(len(ys), 120.0)
                q = ok.copy()
                q[ok] = opaco[qy[ok], qx[ok]]
                e[q] = np.minimum(np.abs(alvo[qy[q], qx[q]] - cor[q]).sum(1), 120)
                c = e.mean() + 4 * abs(1 - s) * 10
                if melhor is None or c < melhor[0]:
                    melhor = (c, s, oy, ox)
    return melhor if custo else (melhor[1], melhor[2], melhor[3])


def por_em(v, img, a, s, oy, ox):
    """leva img (espaco da vista) para o quadro: escala em torno do topo da vista e desloca"""
    tb = topo_centro(v.base, mk=v.mk)
    img = escala(img, s, (tb[0], tb[1])) if tb else img
    H, W = a.shape[:2]
    return em_celula(img, H, W, oy, ox)


_casos = {}
_ultimo = {}


def carimbo_cabeca(v, a, mk, chave=None):
    H, W = a.shape[:2]
    k = (chave, 'cabeca') if chave else None
    if k and k in _casos:
        s, oy, ox = _casos[k]
    else:
        c, s, oy, ox = casar(v, a, 0, v.ny + 1, raio=6, mk=mk, custo=True)
        seq = (chave[0][0], chave[1]) if chave and isinstance(chave[0], tuple) else None
        if seq in _ultimo:
            # efeitos (fogo/arco do golpe) podem enganar a ancora: compara com a procura em volta do
            # encaixe do quadro anterior da mesma folha e fica com o que casa melhor a cor da cabeca
            p_ = _ultimo[seq]
            c2 = casar(v, a, 0, v.ny + 1, raio=4, mk=mk, perto_de=(p_[1], p_[2]), custo=True)
            if c2[0] < c:
                c, s, oy, ox = c2
        if seq:
            _ultimo[seq] = (s, oy, ox)
        if k:
            _casos[k] = (s, oy, ox)
    cam = por_em(v, v.camada, a, s, oy, ox)
    ap = por_em(v, v.apagar.astype(np.uint8), a, s, oy, ox) > 0
    ap &= (a[..., 3] > 128) & ~(cam[..., 3] > 0)
    return cam, ap


def carimbo_corpo(v, a, mk, chave=None):
    H, W = a.shape[:2]
    k = (chave, 'corpo') if chave else None
    if k and k in _casos:
        s, oy, ox = _casos[k]
    else:
        s, oy, ox = casar(v, a, v.ny - 2, v.cintura + 2, mk=mk)
        if k:
            _casos[k] = (s, oy, ox)
    # tronco carimbado (acima da cintura da vista); pernas e o resto pela tabela de cores
    tronco = v.camada.copy()
    tronco[v.cintura:] = 0
    cam = por_em(v, tronco, a, s, oy, ox)
    opaco = a[..., 3] > 128
    perto = ndimage.binary_dilation(opaco, np.ones((3, 3)))
    ok = (cam[..., 3] > 0) & perto & ~mk['cabelo']
    cam[~ok] = 0
    resto = por_tabela(a, mk, v.tab, so=~ok)
    cam[resto[..., 3] > 0] = resto[resto[..., 3] > 0]
    return cam, np.zeros((H, W), bool)


def vistas_da_peca(peca):
    cams = {}
    for d in VISTAS:
        if os.path.exists(SRC + '%s/%s.png' % (peca, d)):
            c, ap, desl = recorte(peca, d)
            cams[d] = (c, ap)
            print('  recorte', peca, d, 'desloc', desl, 'px', int((c[..., 3] > 0).sum()), 'apagar', int(ap.sum()))
    tab = tabela(peca, cams) if PECAS[peca] == 'corpo' else {}
    adaptadas = []
    for d in VISTAS:
        if d in cams:
            continue
        B = rot(d)
        mk = T.mascaras(B)
        viz = [x for x in VIZINHA[d] if x in cams]
        tl = tabela(peca, {x: cams[x] for x in viz}) if viz else tab
        if PECAS[peca] == 'corpo':
            cams[d] = (por_tabela(B, mk, tl or tab), np.zeros(B.shape[:2], bool))
        else:
            cams[d] = (np.zeros_like(B), np.zeros(B.shape[:2], bool))
        adaptadas.append(d)
        print('  ADAPTADA', peca, d, 'pela tabela de cores de', viz or 'todas')
    out = {}
    for d, (c, ap) in cams.items():
        out[d] = Vista(rot(d), c, ap, tab)
    for w, e in ESPELHO.items():
        c, ap = cams[e]
        out[w] = Vista(rot(e)[:, ::-1].copy(), c[:, ::-1].copy(), ap[:, ::-1].copy(), tab)
        out[w].espelho = True
    return out, adaptadas


def camada_quadro(peca, vistas, a, mk, d, arquivo=None, chave=None):
    v = vistas[d]
    # rotacao exata de uma vista gerada/adaptada: entra como esta
    if EXATA and arquivo == 'rotations/%s.png' % d and not getattr(v, 'espelho', False):
        ap = v.apagar & (a[..., 3] > 128)
        return v.camada.copy(), ap
    ch = (chave, d) if chave is not None else None
    if PECAS[peca] == 'cabeca':
        return carimbo_cabeca(v, a, mk, ch)
    return carimbo_corpo(v, a, mk, ch)


def main():
    so_vila = '--so-vila' in sys.argv
    indice = json.load(open(OUT + 'indice.json', encoding='utf-8'))
    quadros = indice['vila']['quadros']
    col, cel = indice['vila']['colunas'], indice['vila']['celula']
    linhas = (len(quadros) + col - 1) // col
    todas = {}
    for p in PECAS:
        print(p)
        vs, adapt = vistas_da_peca(p)
        todas[p] = vs
        os.makedirs(OUT + 'camadas/%s/combate' % p, exist_ok=True)
        os.makedirs(OUT + 'camadas/%s/combate_apagar' % p, exist_ok=True)
        atlas = np.zeros((linhas * cel, col * cel, 4), np.uint8)
        apag = np.zeros_like(atlas)
        for i, f in enumerate(quadros):
            a = T.base_vila[f]
            c, ap = camada_quadro(p, vs, a, T.mk_vila[f], T.dir_de(f), f, f)
            x, y = (i % col) * cel, (i // col) * cel
            atlas[y:y + cel, x:x + cel] = c
            apag[y:y + cel, x:x + cel][ap] = (255, 0, 255, 255)
        Image.fromarray(atlas).save(OUT + 'camadas/%s/vila.png' % p, optimize=True)
        Image.fromarray(apag).save(OUT + 'camadas/%s/vila_apagar.png' % p, optimize=True)
        indice['camadas'][p] = {'vila': 'camadas/%s/vila.png' % p, 'combate': 'camadas/%s/combate/' % p,
                                'apagar_vila': 'camadas/%s/vila_apagar.png' % p,
                                'apagar_combate': 'camadas/%s/combate_apagar/' % p,
                                'fonte': 'pixellab', 'adaptadas': adapt}
        print('vila', p, int((atlas[..., 3] > 0).sum()), 'px, apagar', int((apag[..., 3] > 0).sum()))
    json.dump(indice, open(OUT + 'indice.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    previa(todas)
    if so_vila:
        return
    for folha in indice['combate']['folhas']:
        s = T.carregar(T.PAL + folha)
        d = folha.split('/')[1].replace('_sheet.png', '').split('_')[-1]
        celulas = []
        for i in range(indice['combate']['total']):
            cx, cy = (i % 8) * 112, (i // 8) * 112
            a = s[cy:cy + 112, cx:cx + 112]
            celulas.append((cx, cy, a, T.mascaras(a, True)))
        for p in PECAS:
            out = np.zeros_like(s)
            apo = np.zeros_like(s)
            for n, (cx, cy, a, mk) in enumerate(celulas):
                c, ap = camada_quadro(p, todas[p], a, mk, d, None, (folha, n))
                out[cy:cy + 112, cx:cx + 112] = c
                apo[cy:cy + 112, cx:cx + 112][ap] = (255, 0, 255, 255)
            nome = os.path.basename(folha)
            Image.fromarray(out).save(OUT + 'camadas/%s/combate/%s' % (p, nome), optimize=True)
            Image.fromarray(apo).save(OUT + 'camadas/%s/combate_apagar/%s' % (p, nome), optimize=True)
        print('combate', folha)
    print('ok', len(PECAS), 'pecas')


def compor(base, cam, ap):
    o = base.copy()
    o[ap] = 0
    m = cam[..., 3] > 0
    o[m] = cam[m]
    return o


def previa(todas):
    """docs/equip-pixellab-vistas.png: original + cada peca nas 8 direcoes (idle) e um quadro de corrida"""
    ordem = ['south', 'south-east', 'east', 'north-east', 'north', 'north-west', 'west', 'south-west']
    k = 3
    lin = 1 + 2 * len(todas)
    im = Image.new('RGBA', (len(ordem) * 48 * k, lin * 48 * k), (201, 164, 106, 255))
    for c, d in enumerate(ordem):
        f = 'rotations/%s.png' % d
        im.alpha_composite(Image.fromarray(T.base_vila[f]).resize((48 * k, 48 * k), Image.NEAREST), (c * 48 * k, 0))
        for r, (p, vs) in enumerate(todas.items()):
            for j, f in enumerate(['rotations/%s.png' % d, 'run/%s/002.png' % d]):
                a = T.base_vila[f]
                cam, ap = camada_quadro(p, vs, a, T.mk_vila[f], d, f, f)
                o = compor(a, cam, ap)
                im.alpha_composite(Image.fromarray(o).resize((48 * k, 48 * k), Image.NEAREST),
                                   (c * 48 * k, (1 + 2 * r + j) * 48 * k))
    im.save(os.path.join(R, 'docs/equip-pixellab-vistas.png'))


if __name__ == '__main__':
    main()
