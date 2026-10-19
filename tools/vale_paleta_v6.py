import numpy as np, glob, os, json, sys
from PIL import Image
def srgb2lab(rgb):
    c=rgb/255.0
    c=np.where(c>0.04045,((c+0.055)/1.055)**2.4,c/12.92)
    M=np.array([[0.4124,0.3576,0.1805],[0.2126,0.7152,0.0722],[0.0193,0.1192,0.9505]])
    xyz=c@M.T/np.array([0.95047,1.0,1.08883])
    f=np.where(xyz>0.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack([116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])],-1)
# V6 palette (rotations + run)
pal={}
for f in glob.glob('am/v6_rot/*.png')+glob.glob('am/v6_run/*/*.png'):
    a=np.asarray(Image.open(f).convert('RGBA'))
    px=a[a[...,3]>128][:,:3]
    for c in map(tuple,px): pal[c]=pal.get(c,0)+1
P=np.array([c for c,n in pal.items() if n>=3],dtype=float)
PL=srgb2lab(P)
print('paleta V6:',len(P))
# V6 stats
v6=np.concatenate([np.asarray(Image.open(f).convert('RGBA')).reshape(-1,4) for f in glob.glob('am/v6_rot/*.png')])
v6=v6[v6[:,3]>128][:,:3].astype(float); v6L=srgb2lab(v6)
mu6,sd6=v6L.mean(0),v6L.std(0)
T=float(sys.argv[1]) if len(sys.argv)>1 else 20.0
os.makedirs('out_pal',exist_ok=True)
rel={}
allc=[]
for f in sorted(glob.glob('sh/*_sheet.png')):
    a=np.asarray(Image.open(f).convert('RGBA')).copy()
    m=a[...,3]>0
    rgb=a[...,:3][m].astype(float); L=srgb2lab(rgb)
    # nearest before transfer (to detect character vs effect)
    def nearest(Lx):
        d=np.sqrt(((Lx[:,None,:]-PL[None,:,:])**2).sum(-1)); i=d.argmin(1); return i,d[np.arange(len(i)),i]
    i0,d0=nearest(L)
    corpo=d0<T
    allc.append(L[corpo])
    rel[os.path.basename(f)]={'px':int(m.sum()),'corpo':float(corpo.mean()),'dE_antes':float(d0[corpo].mean())}
    a_store=(a,m,L,corpo,f)
    rel[os.path.basename(f)]['_']=a_store
C=np.concatenate(allc); muG,sdG=C.mean(0),C.std(0)
print('stats Lab corpo gamelab',muG.round(1),sdG.round(1),' V6',mu6.round(1),sd6.round(1))
res={}
for k,v in rel.items():
    a,m,L,corpo,f=v.pop('_')
    Lt=(L-muG)/sdG*sd6+mu6   # transferencia global
    d=np.sqrt(((Lt[:,None,:]-PL[None,:,:])**2).sum(-1)); i=d.argmin(1)
    novo=a[...,:3][m].copy()
    novo[corpo]=P[i[corpo]].astype(np.uint8)
    out=a.copy(); sub=out[...,:3]; sub[m]=novo; out[...,:3]=sub
    Image.fromarray(out).save('out_pal/'+k)
    v['dE_depois']=0.0
    v['dE_transfer_mais_proximo']=float(d[np.arange(len(i)),i][corpo].mean())
    res[k]=v
json.dump({'paleta_v6_cores':len(P),'limiar_dE_corpo':T,'lab_medio_gamelab':muG.round(2).tolist(),'lab_medio_v6':mu6.round(2).tolist(),'folhas':res},open('out_pal/relatorio_paleta.json','w'),indent=1)
print(json.dumps({k:{kk:round(vv,3) for kk,vv in v.items()} for k,v in list(res.items())[:6]},indent=0))
