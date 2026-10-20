"""Gera as pecas de equipamento reais da Vale V6 com PixelLab (edit-image-pixen, 1 geracao cada).
Plano aprovado: 3 capacetes + 2 armaduras, 5 vistas cada (south, south-east, east, north-east, north);
west/south-west/north-west sao espelhadas depois por tools/vale_trajes.py. Total = 25 geracoes. Teto duro = 30.
A chave vem SO da variavel de ambiente PIXELLAB_API_KEY (nunca gravada em arquivo).
Uso:
  python tools/pixellab_equip.py <raiz> --plano                 # so mostra o plano, sem rede
  python tools/pixellab_equip.py <raiz> --executar [--so peca:vista ...]  # gera (gasta)
Saida: work/pixellab_equip/<peca>/<vista>.png + geracoes.json (prompt, seed, job, saldo antes/depois)."""
import os, sys, json, time, base64, io, urllib.request, urllib.error, datetime
from PIL import Image
R = sys.argv[1]; ARGS = sys.argv[2:]
API = 'https://api.pixellab.ai/v2'
SRC = os.path.join(R, 'art/characters/original_vale_v6/rotations/')
OUT = os.path.join(R, 'work/pixellab_equip/')
VISTAS = ['south', 'south-east', 'east', 'north-east', 'north']
TETO = 30
# vistas de costas: sem isto o modelo virava a Vale de frente (1a rodada de north/north-east refeita)
COSTAS = ("BACK VIEW, seen from behind, facing away from the camera: the face is NOT visible, show only the back "
          "of the head and the back of the body. ")
BASE = ("Same chibi character, exact same pose, size, proportions and face. Keep 1px dark outline, crisp pixels, "
        "same palette style. Change ONLY what is described: ")
PECAS = {  # id da camada -> (prompt, seed)
  'capuz_couro': ("now wearing a snug brown leather hood-cap with stitched seams and a small fold at the brow; "
                  "hair hidden on top, only a little fringe visible. Clothes unchanged.", 7101),
  'elmo_ferro': ("now wearing a rounded grey iron helmet with a nose guard and riveted brim band, "
                 "covering the top of the head and hair. Clothes unchanged.", 7102),
  'elmo_adamantium': ("now wearing a polished silver-blue adamantium helmet with a small cyan rune on the front "
                      "and a short crest, covering the top of the head and hair. Clothes unchanged.", 7103),
  'couro_cacador': ("now wearing hunter's leather armor: brown leather jerkin with shoulder pad, belt with pouch, "
                    "leather bracers, and dark leather trousers with knee pads. Head and hair unchanged.", 7104),
  'malha_guarda': ("now wearing guard's iron chainmail: grey mail shirt to mid-thigh with a dark red tabard and "
                   "leather belt, iron greaves over grey trousers. Head and hair unchanged.", 7105),
}

def req(metodo, caminho, corpo=None):
    chave = os.environ.get('PIXELLAB_API_KEY')
    if not chave: sys.exit('PIXELLAB_API_KEY ausente: nada foi gerado.')
    r = urllib.request.Request(API + caminho, method=metodo,
        data=json.dumps(corpo).encode() if corpo is not None else None,
        headers={'Authorization': 'Bearer ' + chave, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(r, timeout=120) as f:
        return json.loads(f.read())

def saldo():
    return req('GET', '/balance')

def b64(p):
    return 'data:image/png;base64,' + base64.b64encode(open(p, 'rb').read()).decode()

def plano():
    for p, (txt, seed) in PECAS.items():
        for v in VISTAS:
            assert Image.open(SRC + v + '.png').size == (48, 48), v
            pre = COSTAS if v in ('north', 'north-east') else ''
            yield p, v, pre + BASE + txt, seed + VISTAS.index(v)

def baixar(g, s):
    lr = s.get('last_response') or {}
    im = (lr.get('image') or (lr.get('images') or [{}])[0]).get('base64', '')
    im = im.split(',', 1)[-1]
    os.makedirs(OUT + g['peca'], exist_ok=True)
    Image.open(io.BytesIO(base64.b64decode(im))).save(OUT + g['peca'] + '/' + g['vista'] + '.png')

def recuperar():
    """busca o resultado de jobs ja pagos que ficaram sem resposta (processo interrompido); nao gasta"""
    logp = OUT + 'geracoes.json'; log = json.load(open(logp))
    for g in log:
        if g.get('resultado') is None:
            s = req('GET', '/background-jobs/' + g['job']); g['resultado'] = s.get('status')
            if s.get('status') == 'completed': baixar(g, s)
            g['saldo_depois'] = saldo(); print('recuperado', g['peca'], g['vista'], g['resultado'])
    json.dump(log, open(logp, 'w'), indent=1, ensure_ascii=False)

def main():
    if '--recuperar' in ARGS: return recuperar()
    alvo = list(plano())
    if '--so' in ARGS:
        so = set(ARGS[ARGS.index('--so') + 1:]); alvo = [a for a in alvo if f'{a[0]}:{a[1]}' in so]
    if '--executar' not in ARGS:
        for a in alvo: print(a[0], a[1], 'seed', a[3])
        print(len(alvo), 'geracoes planejadas (teto', TETO, ')'); return
    os.makedirs(OUT, exist_ok=True)
    logp = OUT + 'geracoes.json'
    log = json.load(open(logp)) if os.path.exists(logp) else []
    usadas = sum(1 for g in log if g.get('status') == 'enviada')
    for p, v, prompt, seed in alvo:
        if usadas >= TETO: print('TETO atingido, parando'); break
        antes = saldo()
        j = req('POST', '/edit-image-pixen', {'image': {'base64': b64(SRC + v + '.png')}, 'description': prompt[:500],
                                              'width': 48, 'height': 48, 'seed': seed, 'no_background': True})
        usadas += 1
        g = {'peca': p, 'vista': v, 'prompt': prompt[:500], 'seed': seed, 'job': j.get('background_job_id'),
             'data': datetime.datetime.now().isoformat(timespec='seconds'), 'saldo_antes': antes, 'status': 'enviada'}
        log.append(g); json.dump(log, open(logp, 'w'), indent=1, ensure_ascii=False)
        while True:
            time.sleep(6); s = req('GET', '/background-jobs/' + g['job'])
            if s.get('status') in ('completed', 'failed'): break
        g['resultado'] = s.get('status')
        if s['status'] == 'completed':
            if os.path.exists(OUT + p + '/' + v + '.png'):  # refacao: guarda a anterior
                os.replace(OUT + p + '/' + v + '.png', OUT + p + '/' + v + '_rejeitada%d.png' % usadas)
            baixar(g, s)
        g['saldo_depois'] = saldo()
        json.dump(log, open(logp, 'w'), indent=1, ensure_ascii=False)
        print(p, v, g['resultado'], 'usadas', usadas)

main()
