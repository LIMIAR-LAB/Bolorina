from PIL import Image
import numpy as np, os, sys
S='/workspace/arte_noite/_fontes/icones'; OUT='/workspace/arte_noite/art/ui/icones'
os.makedirs(OUT,exist_ok=True)
MODE=sys.argv[1] if len(sys.argv)>1 else 'nearest'
FOLHAS={
 'folha_minerios_1':['minerio_cobre','minerio_ferro','minerio_ferro_brasa','minerio_prata_tumular'],
 'folha_minerios_2':['cristal_celeste_bruto','minerio_cronostio','minerio_adamantium','carvao'],
 'folha_lingotes_1':['lingote_cobre','lingote_ferro','lingote_ferro_brasa','lingote_prata_tumular'],
 'folha_lingotes_2':['cristal_celeste','lingote_cronostio','lingote_adamantium','lingote_aco_porto'],
 'folha_equip_1':['espada_cobre','escudo_cobre','elmo_cobre','peitoral_cobre'],
 'folha_equip_2':['luvas_cobre','botas_cobre','picareta_cobre','adaga_cobre'],
}
def bgmask(a):
    r,g,b=a[...,0].astype(int),a[...,1].astype(int),a[...,2].astype(int)
    return (g>120)&(g-np.maximum(r,b)>70)
n=0
for folha,ids in FOLHAS.items():
    im=np.array(Image.open(f'{S}/{folha}.jpg').convert('RGB')); H,W,_=im.shape
    for k,iid in enumerate(ids):
        y0,x0=(k//2)*H//2,(k%2)*W//2
        q=im[y0:y0+H//2,x0:x0+W//2]
        fg=~bgmask(q)
        # remove tiny specks
        ys,xs=np.where(fg)
        y1,y2,x1,x2=ys.min(),ys.max()+1,xs.min(),xs.max()+1
        side=max(y2-y1,x2-x1); cy,cx=(y1+y2)//2,(x1+x2)//2
        half=side//2+2
        rgba=np.zeros((H//2,W//2,4),np.uint8); rgba[...,:3]=q; rgba[...,3]=np.where(fg,255,0)
        # despill green
        r,g,b=rgba[...,0].astype(int),rgba[...,1].astype(int),rgba[...,2].astype(int)
        rgba[...,1]=np.minimum(g,np.maximum(r,b)+10).astype(np.uint8)
        pad=np.zeros((H//2+2*half,W//2+2*half,4),np.uint8); pad[half:half+H//2,half:half+W//2]=rgba
        crop=Image.fromarray(pad[cy:cy+2*half,cx:cx+2*half])
        T=30
        if MODE=='nearest': small=crop.resize((T,T),Image.NEAREST)
        else: small=crop.resize((T,T),Image.BOX)
        a=np.array(small); alpha=a[...,3]>=128
        rgb=Image.fromarray(a[...,:3]).quantize(colors=16,method=Image.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
        o=np.zeros((T,T,4),np.uint8); o[...,:3]=np.array(rgb); o[...,3]=np.where(alpha,255,0)
        canvas=Image.new('RGBA',(32,32),(0,0,0,0)); canvas.paste(Image.fromarray(o),(1,1))
        canvas.save(f'{OUT}/{iid}.png',optimize=True); n+=1
print(n)
