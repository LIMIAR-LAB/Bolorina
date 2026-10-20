import sys, glob, os
from PIL import Image, ImageDraw, ImageFont
raiz, saida = sys.argv[1], sys.argv[2]
fs = sorted(glob.glob(raiz + '/art/ui/icones/*.png')) + sorted(glob.glob(raiz + '/art/ui/icones_equip/*.png'))
try: fonte = ImageFont.truetype('/workspace/bolorina_integrado/art/ui/dialogos/fontes/PixelifySans.ttf', 11)
except Exception: fonte = ImageFont.load_default()
cols = 10; cw, ch = 104, 96
W = Image.new('RGBA', (cols*cw, ((len(fs)+cols-1)//cols)*ch), (60, 40, 24, 255)); d = ImageDraw.Draw(W)
for i, f in enumerate(fs):
    x, y = (i % cols)*cw, (i//cols)*ch
    d.rectangle([x+4, y+4, x+cw-5, y+72], fill=(201, 164, 106, 255))
    im = Image.open(f).convert('RGBA')
    W.alpha_composite(im.resize((64, 64), Image.NEAREST), (x+8, y+6))
    W.alpha_composite(im, (x+80, y+30))
    n = os.path.basename(f)[:-4]
    d.text((x+4, y+76), n if len(n) <= 17 else n[:17], fill=(255, 240, 210, 255), font=fonte)
W.save(saida); print(len(fs))
