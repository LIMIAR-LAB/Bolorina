"""Folhas de combate da Vale com ARMADURA de adamantium (para ataques transformado).
Corpo abaixo da cabeca (roupa, maos, pernas) -> paleta metalica do corpo da armadura v99 por quantil de
luminancia; cabeca (cabelo/pele, ~42% superior do corpo no quadro), espada (baixa saturacao clara) e efeitos
(cores fora da paleta V6) preservados. Saida: out_arm/*.png (+ relatorio)."""
import numpy as np, glob, os, json, colorsys
from PIL import Image
def lum(rgb): return rgb@np.array([0.299,0.587,0.114])
V6=set()
for f in glob.glob('am/v6_rot/*.png')+glob.glob('am/v6_run/*/*.png'):
    a=np.asarray(Image.open(f).convert('RGBA')); V6|=set(map(tuple,a[a[...,3]>128][:,:3]))
# paleta do CORPO da armadura (abaixo da cabeca nas rotacoes)
arm=[]
for f in glob.glob('adam/rotations/*.png'):
    a=np.asarray(Image.open(f).convert('RGBA')); ys,xs=np.where(a[...,3]>128)
    y0,y1=ys.min(),ys.max(); corte=y0+0.45*(y1-y0)
    sel=(a[...,3]>128)&(np.arange(a.shape[0])[:,None]>corte)
    arm.append(a[sel][:,:3])
arm=np.concatenate(arm).astype(float); armL=np.sort(lum(arm))
cols={}
for c in map(tuple,arm.astype(int)): cols[c]=cols.get(c,0)+1
AP=np.array([c for c,n in cols.items() if n>=3],float); APL=lum(AP)
def sat(rgb):
    mx=rgb.max(-1); mn=rgb.min(-1); return np.where(mx>0,(mx-mn)/np.maximum(mx,1),0)
os.makedirs('out_arm',exist_ok=True)
sheets={f:np.asarray(Image.open(f).convert('RGBA')).copy() for f in sorted(glob.glob('out_pal/*_sheet.png'))}
# quantis de luminancia das roupas (todas as folhas)
def regioes(a):
    H,W=a.shape[:2]; mapa=np.zeros((H,W),np.uint8)  # 1=armadura
    for cy in range(0,H,112):
        for cx in range(0,W,112):
            c=a[cy:cy+112,cx:cx+112]; m=c[...,3]>0
            if not m.any(): continue
            rgb=c[...,:3]
            corpo=np.zeros_like(m)
            idx=np.argwhere(m)
            for (y,x) in idx:
                if tuple(rgb[y,x]) in V6: corpo[y,x]=True
            if not corpo.any(): continue
            ys=np.where(corpo.any(1))[0]; y0,y1=ys.min(),ys.max()
            cabeca=np.arange(112)[:,None] < y0+0.42*(y1-y0)
            s=sat(rgb.astype(float)); v=rgb.max(-1)
            espada=(s<0.16)&(v>120)
            arm_m=corpo&~cabeca&~espada
            mapa[cy:cy+112,cx:cx+112]=arm_m
    return mapa
mapas={f:regioes(a) for f,a in sheets.items()}
CL=np.sort(np.concatenate([lum(a[...,:3][mapas[f]>0].astype(float)) for f,a in sheets.items()]))
rel={}
for f,a in sheets.items():
    mk=mapas[f]>0; rgb=a[...,:3][mk].astype(float); L=lum(rgb)
    q=np.searchsorted(CL,L)/len(CL)
    q=np.where(q<0.10,q,0.10+0.90*((q-0.10)/0.90)**0.42)  # contorno escuro mantido; placas mais claras (prata)
    alvo=armL[np.clip((q*len(armL)).astype(int),0,len(armL)-1)]
    i=np.abs(APL[None,:]-alvo[:,None]).argmin(1)
    out=a.copy(); s=out[...,:3]; s[mk]=AP[i].astype(np.uint8); out[...,:3]=s
    Image.fromarray(out).save('out_arm/'+os.path.basename(f))
    rel[os.path.basename(f)]={'armadura_px':int(mk.sum())}
json.dump({'metodo':'corpo abaixo da cabeca -> paleta do corpo da armadura v99 (quantil de luminancia); cabeca, espada e efeitos preservados','paleta_armadura':len(AP),'folhas':rel},open('out_arm/relatorio_armadura.json','w'),indent=1)
print('ok',len(rel),'paleta',len(AP))
