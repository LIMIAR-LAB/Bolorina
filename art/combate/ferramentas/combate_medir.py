# Mede, nas folhas do Vale (art/characters/vale_combate_gamelab), os quadros de impacto do combo
# (picos de pixels brancos do rastro), o deslocamento embutido do dash (centroide dos pixels escuros),
# o quadro de liberacao do especial (pico de area opaca) e o golpe recebido. Gera vale_combate_dados.json.
# Uso (box): python3 combate_medir.py  (espera sheets/<mov>_<dir>_sheet.png e sheets/manifest.json)
from PIL import Image
import numpy as np, json
dirs=['east','north-east','south-east','west','north-west','south-west']
man=json.load(open('sheets/manifest.json'))
def cells(mov,d):
    im=np.array(Image.open(f'sheets/{mov}_{d}_sheet.png').convert('RGBA')).astype(int)
    return [im[(f//8)*112:(f//8+1)*112,(f%8)*112:(f%8+1)*112] for f in range(49)]
def body(c):
    a=c[:,:,3]>40; mx=c[:,:,:3].max(2)
    m=a&(mx<170); ys,xs=np.nonzero(m); return np.array([xs.mean(),ys.mean()])
out={'fonte':'medido por art/combate/ferramentas/combate_medir.py','direcoes':{}}
for d in dirs:
    cs=cells('slash_combo',d)
    w=np.array([((c[:,:,0]>215)&(c[:,:,1]>215)&(c[:,:,2]>215)&(c[:,:,3]>40)).sum() for c in cs])
    p1,p2,p3=[i for i in range(1,48) if w[i]>40 and w[i]>=w[i-1] and w[i]>=w[i+1]][:3]
    combo=[[p1-3,p1,int((p1+p2)//2)],[int((p1+p2)//2)+1,p2,int((p2+p3)//2)],[p3-3,p3,min(p3+9,44)]]
    ds=cells('dash',d); b=[body(c) for c in ds]; b0=b[5]
    disp=[float(np.linalg.norm(x-b0)) for x in b]
    moving=[i for i in range(8,46) if disp[i]>4]
    run=[moving[0]]
    for i in moving[1:]:
        if i==run[-1]+1: run.append(i)
        else: break
    ds0=max(8,run[0]-3); ds1=run[-1]
    comp={str(i):[round(float(-(b[i]-b0)[0]),1),round(float((b[i]-b0)[1]),1)] for i in range(ds0,ds1+1)}
    sp=cells('special',d); n=np.array([(c[:,:,3]>40).sum() for c in sp]); rel=int(np.argmax(n[8:42])+8)
    hs=cells('hit',d); hw=np.array([((c[:,:,0]>215)&(c[:,:,1]>215)&(c[:,:,2]>215)&(c[:,:,3]>40)).sum() for c in hs]); h1=int(np.argmax(hw[2:24])+2)
    anc={k:man['animations'][f'{k}_{d}']['anchor_feet_px'] for k in ['slash_combo','dash','hit','special']}
    out['direcoes'][d]={'combo':combo,'dash':[ds0,ds1],'dash_comp_px':comp,'especial':[max(3,rel-12),rel,min(rel+10,46)],'dano':[max(0,h1-1),h1,h1+9],'ancora':anc}
json.dump(out,open('vale_combate_dados.json','w'),indent=1)
