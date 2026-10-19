"""LUT por canal (256x1) que leva a distribuicao de cor da captura para a da referencia
(casamento de histograma em sRGB), misturada com a identidade. Uso:
python tools/fidelidade_lut.py <captura_sem_lut.png> [mistura=0.8] [lut_anterior.png]"""
import sys, os, numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cap = np.asarray(Image.open(sys.argv[1]).convert("RGB")).reshape(-1,3)
ref = np.asarray(Image.open(os.path.join(ROOT,"docs","referencia-usuario.png")).convert("RGB")).reshape(-1,3)
mix = float(sys.argv[2]) if len(sys.argv) > 2 else 0.8
prev = np.asarray(Image.open(sys.argv[3]).convert("RGB"))[0].astype(float) if len(sys.argv) > 3 else None
lut = np.zeros((256,3))
for c in range(3):
    hc = np.bincount(cap[:,c], minlength=256).astype(float); hr = np.bincount(ref[:,c], minlength=256).astype(float)
    cc = np.cumsum(hc)/hc.sum(); cr = np.cumsum(hr)/hr.sum()
    m = np.interp(cc, cr, np.arange(256))
    m = np.convolve(np.pad(m,4,mode="edge"), np.ones(9)/9, mode="valid")
    curve = mix*m + (1-mix)*np.arange(256)
    if prev is not None:   # compoe: a captura ja passou pela LUT anterior
        curve = np.interp(prev[:,c], np.arange(256), curve)
    lut[:,c] = np.clip(np.maximum.accumulate(curve),0,255)
out = os.path.join(ROOT,"scripts","modular","lut_fidelidade.png")
Image.fromarray(lut.astype(np.uint8)[None,:,:]).save(out)
print("LUT", out, "amostras", [list(lut[i].astype(int)) for i in (0,32,64,128,192,255)])