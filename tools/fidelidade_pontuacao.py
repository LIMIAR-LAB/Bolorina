"""Pontuacao composta de fidelidade (fase 1).
  40% composicao  - checklist de elementos da referencia (docs/fidelidade-checklist.json):
                    presente=1, parcial=0,5, ausente=0, com pesos.
  30% cor/luz     - grade 8x6: diferenca de cor media em Lab (CIE76) e intersecao do
                    histograma de L* (16 faixas) por regiao.
  20% detalhe     - grade 8x6: densidade de bordas (Sobel) por regiao, razao menor/maior.
  10% avaliacao   - nota visual do usuario (0-1); pendente = relatada sem ela e com 0,5 neutro.
Uso: python tools/fidelidade_pontuacao.py <captura.png> [saida_prefixo]
Gera <prefixo>-pontuacao.json, <prefixo>-mapa-calor.png, <prefixo>-lado-a-lado.png em docs/."""
import sys, os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); DOCS = os.path.join(os.path.dirname(HERE), 'docs')
REF = os.path.join(DOCS, 'referencia-usuario.png')
COLS, ROWS = 8, 6
W, H = 800, 450
EDGE_T = 0.10
DE_MAX = 40.0

def load(path):
    return np.asarray(Image.open(path).convert('RGB').resize((W, H), Image.LANCZOS), dtype=np.float64) / 255.0

def to_lab(rgb):
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = lin @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)

def edges(rgb):
    g = rgb @ np.array([0.2126, 0.7152, 0.0722])
    p = np.pad(g, 1, mode='edge')
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    return np.hypot(gx, gy) / 4.0 > EDGE_T

def regions(fn):
    out = []
    for r in range(ROWS):
        for c in range(COLS):
            ys = slice(r * H // ROWS, (r + 1) * H // ROWS); xs = slice(c * W // COLS, (c + 1) * W // COLS)
            out.append(fn(ys, xs, r, c))
    return out

def composition(path):
    data = json.load(open(path, encoding='utf-8'))
    val = {'presente': 1.0, 'parcial': 0.5, 'ausente': 0.0}
    tw = sum(i.get('peso', 1) for i in data['itens'])
    score = sum(i.get('peso', 1) * val[i['estado']] for i in data['itens']) / tw
    gaps = sorted([{'item': i['item'], 'estado': i['estado'], 'ganho_pontos': round(40 * i.get('peso', 1) * (1 - val[i['estado']]) / tw, 2)} for i in data['itens'] if i['estado'] != 'presente'], key=lambda g: -g['ganho_pontos'])
    counts = {k: sum(1 for i in data['itens'] if i['estado'] == k) for k in val}
    return score, gaps, counts, len(data['itens'])

def main():
    cap_path = sys.argv[1]; prefix = sys.argv[2] if len(sys.argv) > 2 else 'fidelidade'
    ref = load(REF); cap = load(cap_path)
    lr, lc = to_lab(ref), to_lab(cap); er, ec = edges(ref), edges(cap)
    def region(ys, xs, r, c):
        a, b = lr[ys, xs].reshape(-1, 3), lc[ys, xs].reshape(-1, 3)
        de = float(np.linalg.norm(a.mean(0) - b.mean(0)))
        ha, _ = np.histogram(a[:, 0], 16, (0, 100)); hb, _ = np.histogram(b[:, 0], 16, (0, 100))
        hist = float(np.minimum(ha / ha.sum(), hb / hb.sum()).sum())
        color = max(0.0, 1 - de / DE_MAX)
        light = 0.5 * color + 0.5 * hist
        dr, dc = float(er[ys, xs].mean()), float(ec[ys, xs].mean())
        edge = min(dr, dc) / max(dr, dc) if max(dr, dc) > 1e-6 else 1.0
        return {'linha': r, 'coluna': c, 'delta_e': round(de, 1), 'L_ref': round(float(a[:, 0].mean()), 1), 'L_cap': round(float(b[:, 0].mean()), 1),
                'hist_L': round(hist, 3), 'cor_luz': round(light, 3), 'bordas_ref': round(dr, 3), 'bordas_cap': round(dc, 3), 'detalhe': round(edge, 3)}
    regs = regions(region)
    light = float(np.mean([g['cor_luz'] for g in regs])); detail = float(np.mean([g['detalhe'] for g in regs]))
    comp, gaps, counts, n = composition(sys.argv[3] if len(sys.argv) > 3 else os.path.join(DOCS, 'fidelidade-checklist.json'))
    without = (0.4 * comp + 0.3 * light + 0.2 * detail) / 0.9
    neutral = 0.4 * comp + 0.3 * light + 0.2 * detail + 0.1 * 0.5
    result = {'captura': os.path.basename(cap_path), 'composicao_40': round(comp * 100, 1), 'cor_luz_30': round(light * 100, 1), 'detalhe_20': round(detail * 100, 1),
              'avaliacao_usuario_10': 'pendente', 'total_sem_avaliacao': round(without * 100, 1), 'total_com_avaliacao_neutra_0_5': round(neutral * 100, 1),
              'pontos_ponderados': {'composicao': round(40 * comp, 1), 'cor_luz': round(30 * light, 1), 'detalhe': round(20 * detail, 1)},
              'checklist': {'itens': n, **counts}, 'lacunas_checklist': gaps, 'regioes': regs,
              'ganho_por_regiao': sorted([{'linha': g['linha'], 'coluna': g['coluna'], 'ganho_pontos': round(30 * (1 - g['cor_luz']) / len(regs) + 20 * (1 - g['detalhe']) / len(regs), 2)} for g in regs], key=lambda x: -x['ganho_pontos'])[:12],
              'parametros': {'grade': [COLS, ROWS], 'resolucao_analise': [W, H], 'limiar_borda': EDGE_T, 'delta_e_max': DE_MAX}}
    json.dump(result, open(os.path.join(DOCS, prefix + '-pontuacao.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    # Mapa de calor sobre a captura
    font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 15); small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 12)
    base = Image.open(cap_path).convert('RGB').resize((1600, 900)); over = Image.new('RGBA', base.size, (0, 0, 0, 0)); d = ImageDraw.Draw(over)
    cw, ch = 1600 // COLS, 900 // ROWS
    for g in regs:
        miss = 1 - (0.6 * g['cor_luz'] + 0.4 * g['detalhe'])
        x0, y0 = g['coluna'] * cw, g['linha'] * ch
        col = (int(255 * min(1, miss * 2)), int(255 * max(0, 1 - miss * 2)), 40, int(70 + 110 * miss))
        d.rectangle([x0, y0, x0 + cw - 1, y0 + ch - 1], fill=col, outline=(255, 255, 255, 120))
        d.text((x0 + 6, y0 + 4), '%d%%' % round(100 * (1 - miss)), font=font, fill=(255, 255, 255, 255))
        d.text((x0 + 6, y0 + 24), 'luz %d  det %d' % (round(100 * g['cor_luz']), round(100 * g['detalhe'])), font=small, fill=(255, 255, 255, 230))
        d.text((x0 + 6, y0 + 40), 'L* %.0f/%.0f' % (g['L_cap'], g['L_ref']), font=small, fill=(255, 255, 255, 230))
    heat = Image.alpha_composite(base.convert('RGBA'), over).convert('RGB')
    hd = ImageDraw.Draw(heat); hd.rectangle([0, 868, 1600, 900], fill=(0, 0, 0))
    hd.text((10, 874), 'Mapa de fidelidade por regiao (verde = proximo da referencia). Total sem avaliacao: %.1f | composicao %.1f, cor/luz %.1f, detalhe %.1f' % (without * 100, comp * 100, light * 100, detail * 100), font=font, fill=(255, 255, 255))
    heat.save(os.path.join(DOCS, prefix + '-mapa-calor.png'))
    side = Image.new('RGB', (1600, 450 + 34), (20, 20, 24)); side.paste(Image.open(REF).convert('RGB').resize((800, 450), Image.LANCZOS), (0, 34)); side.paste(Image.open(cap_path).convert('RGB').resize((800, 450), Image.LANCZOS), (800, 34))
    sd = ImageDraw.Draw(side); sd.text((10, 8), 'Referencia do usuario', font=font, fill=(255, 255, 255)); sd.text((810, 8), 'Cena de fidelidade (V6 alinhado) - %.1f sem avaliacao' % (without * 100), font=font, fill=(255, 255, 255))
    side.save(os.path.join(DOCS, prefix + '-lado-a-lado.png'))
    print(json.dumps({k: result[k] for k in ['composicao_40', 'cor_luz_30', 'detalhe_20', 'total_sem_avaliacao', 'total_com_avaliacao_neutra_0_5', 'checklist']}, ensure_ascii=False))

if __name__ == '__main__':
    main()