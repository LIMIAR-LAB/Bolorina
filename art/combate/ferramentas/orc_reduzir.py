import numpy as np, os, json
from PIL import Image, ImageFilter
S=0.11; C=72
segs={'run':list(range(9,20)),'idle':[0,1,2,3,2,1],'windup':list(range(22,31)),'strike':list(range(31,35)),'recover':list(range(35,45)),'hurt':list(range(1,9)),'death':list(range(16,35))}
src={'run':'run','idle':'axe_combo','windup':'axe_combo','strike':'axe_combo','recover':'axe_combo','hurt':'hurt_death','death':'hurt_death'}
def shrink(path):
    im=Image.open(path).convert('RGBA')
    a=np.array(im).astype(float)/255
    rgb=a[:,:,:3]*a[:,:,3:4]
    pm=Image.fromarray((np.dstack([rgb,a[:,:,3:4]])*255).astype(np.uint8))
    sz=int(640*S)
    small=np.array(pm.resize((sz,sz),Image.LANCZOS)).astype(float)/255
    al=small[:,:,3]; rgbs=np.where(al[...,None]>0.01,small[:,:,:3]/np.maximum(al[...,None],1e-3),0)
    out=np.zeros((C,C,4)); off=(C-sz)//2
    keep=al>0.5
    out[off:off+sz,off:off+sz,:3]=np.clip(rgbs,0,1); out[off:off+sz,off:off+sz,3]=keep
    return (out*255).astype(np.uint8)
frames={}
allpx=[]
for k,lst in segs.items():
    frames[k]=[shrink(f'cut/{src[k]}/{i:03d}.png') for i in lst]
    for f in frames[k]: allpx.append(f[f[:,:,3]>0][:,:3])
pal_src=np.concatenate(allpx)[None,:,:]
pal_img=Image.fromarray(pal_src.astype(np.uint8)).quantize(48,method=Image.Quantize.MEDIANCUT)
os.makedirs('out',exist_ok=True)
man={'source':'Gamelab Studio 67660 (run), 67661 (axe_combo), 67663 (hurt_death) - Orc motion v3, conta do usuario','scale_from_640_crop':S,'cell':C,'facing':'east (espelhar para oeste)','anchor_feet_px':[C//2, int(605*S)+(C-int(640*S))//2],'anims':{}}
for k,fl in frames.items():
    q=[]
    for f in fl:
        rgb=Image.fromarray(f[:,:,:3]).quantize(palette=pal_img,dither=Image.Dither.NONE).convert('RGB')
        arr=np.dstack([np.array(rgb),f[:,:,3]])
        # contorno escuro 1px
        al=arr[:,:,3]>0
        edge=np.zeros_like(al)
        for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
            edge|=np.roll(al,(dy,dx),(0,1))
        edge&=~al
        arr[edge]=[28,20,24,255]
        q.append(arr)
    cols=len(q)
    sheet=np.zeros((C,C*cols,4),np.uint8)
    for i,a in enumerate(q): sheet[:,i*C:(i+1)*C]=a
    Image.fromarray(sheet).save(f'out/orc_{k}.png')
    man['anims'][k]={'sheet':f'orc_{k}.png','frames':cols,'source_frames':segs[k]}
json.dump(man,open('out/manifest.json','w'),indent=1,ensure_ascii=False)
# preview at 4x
prev=Image.new('RGBA',(C*4*11, C*4*7),(70,90,120,255))
for r,k in enumerate(frames):
    sh=Image.open(f'out/orc_{k}.png'); sh=sh.resize((sh.width*4,sh.height*4),Image.NEAREST)
    prev.alpha_composite(sh.crop((0,0,min(sh.width,C*4*11),sh.height)),(0,r*C*4))
prev.save('/workspace/combate/prev_orc_small.png')
print(man['anchor_feet_px'])
