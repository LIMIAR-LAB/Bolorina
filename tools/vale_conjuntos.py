"""Camadas dos conjuntos da forja (cobre, ferro, prata de tumulo): so cor e paleta, sem geracao paga.
Local, sem custo. Usa as mascaras de tools/vale_trajes.py (base atual da Vale) e a camada do elmo de ferro (PixelLab).
  capacete_<metal>: camada elmo_ferro (vila + combate + apagar) com a luminancia levada para a rampa do metal
  peito_<metal> : camisa + colete -> rampa do metal
  luvas_<metal> : maos/antebracos (pele abaixo da cabeca) -> rampa do metal escurecida
  botas_<metal> : botas -> rampa do metal
Metais e cores: data/forja/materiais.json. Saida: art/characters/vale_trajes/camadas/<peca>/ + indice.json.
Uso: python tools/vale_conjuntos.py <raiz> [--so-vila]"""
import os, sys, json
import numpy as np
from PIL import Image
R = sys.argv[1] if len(sys.argv) > 1 else '.'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vale_trajes as T  # noqa: E402

OUT = T.OUT
MAT = json.load(open(os.path.join(R, 'data/forja/materiais.json'), encoding='utf-8'))['materiais']
CONTORNO = np.array([26, 15, 14])


def rampa(cor, n=6):
    """tons do escuro ao claro em volta da cor do metal (com brilho quase branco no topo)"""
    c = np.array(cor, float)
    tons = []
    for t in np.linspace(0, 1, n):
        if t < 0.65:
            v = c * (0.28 + 1.1 * t)
        else:
            v = c + (np.array([255, 255, 255]) - c) * (t - 0.65) * 0.9
        tons.append(np.clip(v, 0, 255))
    return np.array(tons)


def lum(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def recolor(a, m, cor, escuro=1.0):
    out = np.zeros_like(a)
    if not m.any():
        return out
    L = lum(a[..., :3][m].astype(float))
    lo, hi = np.percentile(L, 3), np.percentile(L, 97)
    q = np.clip((L - lo) / max(1.0, hi - lo), 0, 1)
    tons = rampa(cor) * escuro
    idx = np.clip((q * (len(tons) - 1)).round().astype(int), 0, len(tons) - 1)
    rgb = tons[idx].astype(np.uint8)
    rgb[L < 40] = CONTORNO
    s = out[..., :3]
    s[m] = rgb
    out[..., :3] = s
    out[..., 3][m] = 255
    return out


def luvas_mask(a, mk, so_paleta):
    k, rel = T.mapas(a, so_paleta)
    if rel is None:
        return np.zeros(a.shape[:2], bool)
    return (k == 'pele') & (rel > 0.45)


def peca(nome, a, mk, so_paleta, cor):
    if nome == 'peito':
        return recolor(a, mk['camisa'] | mk['colete'], cor)
    if nome == 'botas':
        return recolor(a, mk['botas'], cor)
    if nome == 'luvas':
        return recolor(a, luvas_mask(a, mk, so_paleta), cor, 0.8)
    raise KeyError(nome)


def elmo_de(img, cor):
    """recolore uma camada pronta (elmo de ferro) para o metal"""
    a = np.asarray(img).copy()
    m = a[..., 3] > 0
    if not m.any():
        return a
    return recolor(a, m, cor)


def main():
    so_vila = '--so-vila' in sys.argv
    indice = json.load(open(OUT + 'indice.json', encoding='utf-8'))
    quadros = indice['vila']['quadros']
    col, cel = indice['vila']['colunas'], indice['vila']['celula']
    linhas = (len(quadros) + col - 1) // col
    base_elmo = indice['camadas']['elmo_ferro']
    for m in MAT:
        cor = m['cor']
        for nome in ('peito', 'botas', 'luvas'):
            pid = '%s_%s' % (nome, m['id'])
            os.makedirs(OUT + 'camadas/%s/combate' % pid, exist_ok=True)
            atlas = np.zeros((linhas * cel, col * cel, 4), np.uint8)
            for i, f in enumerate(quadros):
                x, y = (i % col) * cel, (i // col) * cel
                atlas[y:y + cel, x:x + cel] = peca(nome, T.base_vila[f], T.mk_vila[f], False, cor)
            Image.fromarray(atlas).save(OUT + 'camadas/%s/vila.png' % pid, optimize=True)
            indice['camadas'][pid] = {'vila': 'camadas/%s/vila.png' % pid, 'combate': 'camadas/%s/combate/' % pid, 'fonte': 'forja_cor'}
        pid = 'capacete_%s' % m['id']
        os.makedirs(OUT + 'camadas/%s/combate' % pid, exist_ok=True)
        os.makedirs(OUT + 'camadas/%s/combate_apagar' % pid, exist_ok=True)
        Image.fromarray(elmo_de(Image.open(OUT + base_elmo['vila']).convert('RGBA'), cor)).save(OUT + 'camadas/%s/vila.png' % pid, optimize=True)
        Image.open(OUT + base_elmo['apagar_vila']).save(OUT + 'camadas/%s/vila_apagar.png' % pid, optimize=True)
        indice['camadas'][pid] = {'vila': 'camadas/%s/vila.png' % pid, 'combate': 'camadas/%s/combate/' % pid,
                                  'apagar_vila': 'camadas/%s/vila_apagar.png' % pid, 'apagar_combate': 'camadas/%s/combate_apagar/' % pid,
                                  'fonte': 'forja_cor (elmo_ferro do PixelLab recolorido)'}
        print('vila', m['id'])
    json.dump(indice, open(OUT + 'indice.json', 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    if so_vila:
        return
    for folha in indice['combate']['folhas']:
        s = T.carregar(T.PAL + folha)
        nome_f = os.path.basename(folha)
        cels = []
        for i in range(indice['combate']['total']):
            cx, cy = (i % 8) * 112, (i // 8) * 112
            a = s[cy:cy + 112, cx:cx + 112]
            cels.append((cx, cy, a, T.mascaras(a, True)))
        el = Image.open(OUT + base_elmo['combate'] + nome_f).convert('RGBA')
        el_ap = Image.open(OUT + base_elmo['apagar_combate'] + nome_f)
        for m in MAT:
            for nome in ('peito', 'botas', 'luvas'):
                out = np.zeros_like(s)
                for cx, cy, a, mk in cels:
                    out[cy:cy + 112, cx:cx + 112] = peca(nome, a, mk, True, m['cor'])
                Image.fromarray(out).save(OUT + 'camadas/%s_%s/combate/%s' % (nome, m['id'], nome_f), optimize=True)
            Image.fromarray(elmo_de(el, m['cor'])).save(OUT + 'camadas/capacete_%s/combate/%s' % (m['id'], nome_f), optimize=True)
            el_ap.save(OUT + 'camadas/capacete_%s/combate_apagar/%s' % (m['id'], nome_f), optimize=True)
        print('combate', folha)
    print('ok')


if __name__ == '__main__':
    main()
