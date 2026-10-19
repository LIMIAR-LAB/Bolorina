import numpy as np, os, json
from PIL import Image
from scipy import ndimage
os.makedirs('cut',exist_ok=True)
stats={}
for v in ['67660_orc_motion_v3_run','67661_orc_motion_v3_axe_combo','67663_orc_motion_v3_hurt_death']:
    key=v.split('v3_')[1]
    os.makedirs(f'cut/{key}',exist_ok=True)
    rows=[]
    for i,f in enumerate(sorted(os.listdir(v))):
        a=np.array(Image.open(f'{v}/{f}').convert('RGB'))[160:800,160:800].astype(int)
        mn=a.min(2); mx=a.max(2)
        bgl=(mn>222)&((mx-mn)<22)
        lab,n=ndimage.label(bgl)
        border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])).tolist())-{0}
        bg=np.isin(lab,list(border))
        fg=~bg
        fg=ndimage.binary_opening(fg,iterations=1)
        lab2,n2=ndimage.label(fg)
        if n2>1:
            sizes=ndimage.sum(fg,lab2,range(1,n2+1)); keep=np.where(sizes>400)[0]+1
            fg=np.isin(lab2,keep)
        rgba=np.dstack([a,fg*255]).astype(np.uint8)
        Image.fromarray(rgba).save(f'cut/{key}/{i:03d}.png')
        ys,xs=np.nonzero(fg)
        rows.append((i,int(xs.min()),int(xs.max()),int(ys.min()),int(ys.max()),int(fg.sum())))
    stats[key]=rows
    print(key); print(' '.join(f"{r[0]}:{r[1]}-{r[2]},{r[3]}-{r[4]}" for r in rows))
json.dump(stats,open('stats.json','w'))
