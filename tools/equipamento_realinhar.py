"""Realinha camadas existentes à Vale atual. Sem rede, geração paga ou alterações nas fontes.
Templates da cabeça vêm da própria Vale; efeitos não são candidatos a âncora por cor isolada.
Saída derivada: vale_trajes/correcao_v2. Execute a partir de qualquer diretório.
"""
from pathlib import Path
from functools import lru_cache
import json, hashlib, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent.parent
GEAR=ROOT/'art/characters/vale_trajes'
OUT=GEAR/'correcao_v2'
IX=json.loads((GEAR/'indice.json').read_text(encoding='utf-8-sig'))
MASKS=json.loads((ROOT/'art/characters/avatar_mascaras/indice.json').read_text())['sources']
HEAD=['capuz_couro','elmo_ferro','elmo_adamantium','capacete_cobre','capacete_ferro','capacete_prata']
BODY=['couro_cacador','malha_guarda','peito_cobre','peito_ferro','peito_prata']
DIRS=['south','south-east','east','north-east','north','north-west','west','south-west']

@lru_cache(maxsize=128)
def read(p): return np.array(Image.open(p).convert('RGBA'))
def box(m):
    y,x=np.where(m)
    return (int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)) if len(x) else None
def dilation(m):
    p=np.pad(m,1);h,w=m.shape
    return np.logical_or.reduce([p[y:y+h,x:x+w] for y in range(3) for x in range(3)])
def cell(a,i,size):return a[i//(a.shape[1]//size)*size:i//(a.shape[1]//size)*size+size,i%(a.shape[1]//size)*size:i%(a.shape[1]//size)*size+size].copy()
def place(dst,src,x,y):
    h,w=dst.shape[:2];sh,sw=src.shape[:2];x0=max(0,x);y0=max(0,y);x1=min(w,x+sw);y1=min(h,y+sh)
    if x1>x0 and y1>y0:dst[y0:y1,x0:x1]=src[y0-y:y1-y,x0-x:x1-x]
def compose(base,layer,erase):
    out=base.copy();out[erase]=0;out[layer[:,:,3]>0]=layer[layer[:,:,3]>0];return out
def save(path,a):
    path.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(a).save(path,optimize=True)

def template(direction):
    path='res://art/characters/vale_unica/rotations/'+direction+'.png'
    a=read(ROOT/path[6:]);ids=read(ROOT/MASKS[path]['mask'][6:])[:,:,0]
    hair=ids==4;x0,y0,x1,y1=box(hair)
    # Include face/eyes in matching, so a flame with brown pixels cannot become the head.
    bottom=min(48,y1+3)
    return a,(x0,y0,x1,bottom),hair,ids

TEMPLATES={d:template(d) for d in DIRS}

def compact_head(ids):
    mask=ids==4;seen=np.zeros(mask.shape,bool);best=None
    for y,x in zip(*np.where(mask)):
        if seen[y,x]:continue
        pending=[(y,x)];seen[y,x]=True;points=[]
        while pending:
            yy,xx=pending.pop();points.append((yy,xx))
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    ny,nx=yy+dy,xx+dx
                    if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;pending.append((ny,nx))
        a=np.array(points);y0,x0=a.min(0);y1,x1=a.max(0)
        if len(points)>=18 and x1-x0<38 and y1-y0<36:
            if best is None or len(points)>best[0]:best=(len(points),int(x0),int(y0))
    return best

def locate(base,direction,ids):
    ref,b,hair,refids=TEMPLATES[direction];x0,y0,x1,y1=b
    best=None;rough=compact_head(ids) if base.shape[0]!=48 else None
    for scale in ([0.75,0.85,1.0,1.1] if base.shape[0]==48 else [1.0]):
        patch=np.array(Image.fromarray(ref[y0:y1,x0:x1]).resize((round((x1-x0)*scale),round((y1-y0)*scale)),Image.Resampling.NEAREST))
        ph,pw=patch.shape[:2]
        if base.shape[0]==48:
            yr=range(0,49-ph);xr=range(0,49-pw)
        elif rough:
            yr=range(max(0,rough[2]-8),min(base.shape[0]-ph+1,rough[2]+9))
            xr=range(max(0,rough[1]-8),min(base.shape[1]-pw+1,rough[1]+9))
        else:
            yr=range(0,base.shape[0]-ph+1);xr=range(0,base.shape[1]-pw+1)
        if not len(yr) or not len(xr):
            yr=range(0,base.shape[0]-ph+1);xr=range(0,base.shape[1]-pw+1)
        ys=np.array(list(yr),dtype=np.int32);xs=np.array(list(xr),dtype=np.int32)
        py,px=np.where(patch[:,:,3]>128)
        step=max(1,len(px)//150);py=py[::step];px=px[::step]
        scores=np.zeros((len(ys),len(xs)),np.float32)
        for yy,xx in zip(py,px):
            target=base[(ys+yy)[:,None],(xs+xx)[None,:]]
            diff=np.minimum(np.abs(target[:,:,:3].astype(np.int16)-patch[yy,xx,:3]).sum(2),180)
            scores+=np.where(target[:,:,3]>128,diff,220)
        scores=scores/len(px)+abs(1-scale)*8
        iy,ix=np.unravel_index(scores.argmin(),scores.shape)
        candidate=(int(xs[ix])-x0,int(ys[iy])-y0,float(scores[iy,ix]),scale)
        if best is None or candidate[2]<best[2]:best=candidate
    if best[2]>100 and rough:
        # A detached fire fragment can be larger than the actual hair component.
        # In that case search the whole cell using the complete head template.
        return locate(base,direction,np.zeros_like(ids))
    return best

def shade_fill(base,selection,layer,palette):
    """Hide residual base cloth/hair with existing material shades, preserving source luminance."""
    if not selection.any():return
    values=palette[:,:3].max(1)
    order=np.argsort(values);palette=palette[order]
    l=base[:,:,:3].max(2)/255
    ranks=np.minimum(len(palette)-1,np.maximum(0,(l*(len(palette)-1)).astype(int)))
    layer[selection]=palette[ranks[selection]];layer[selection,3]=255

def fix(base,ids,old,direction,piece,anchor):
    dx,dy,error,scale=anchor;ref,b,hair,refids=TEMPLATES[direction];h,w=base.shape[:2]
    region=np.zeros((h,w),bool);x0,y0,x1,y1=b
    right=x0+dx+round((x1-x0)*scale);bottom=y0+dy+round((y1-y0)*scale)
    region[max(0,y0+dy-1):min(h,bottom+1),max(0,x0+dx-2):min(w,right+2)]=True
    true_hair=(ids==4)&region
    if piece in HEAD:
        region[:]=False
        region[max(0,y0+dy-5):min(h,bottom+2),max(0,x0+dx-5):min(w,right+5)]=True
        true_hair=(ids==4)&region
        yy=np.indices((h,w))[0]
        rgb=base[:,:,:3].astype(np.int16)
        # Old semantic masks omit dark brown outline/stray hair pixels. They are
        # still visible above a helmet, particularly on the moving south view.
        crown=region&(yy<y0+dy+round((y1-y0)*scale*.52))&(base[:,:,3]>128)
        brown=(rgb[:,:,0]>=rgb[:,:,1])&(rgb[:,:,0]>rgb[:,:,2]+5)&(rgb.max(2)<190)&(rgb.max(2)>30)
        true_hair |= crown&brown&(ids!=1)
        # One stable material template per direction, positioned by the actual current head.
        i=IX['vila']['quadros'].index('rotations/'+direction+'.png')
        src=cell(read(GEAR/IX['camadas'][piece]['vila']),i,48)
        layer=np.array(Image.fromarray(src).transform((w,h),Image.Transform.AFFINE,(1/scale,0,x0-(x0+dx)/scale,0,1/scale,y0-(y0+dy)/scale),resample=Image.Resampling.NEAREST))
        layer[~region]=0
        opaque=src[:,:,3]>128
        palette=src[opaque & (np.indices(opaque.shape)[0] < y0+8)]
        if len(palette)==0:palette=src[opaque]
        material=palette[palette[:,:3].max(1)>55]
        if len(material):palette=material
        # Never leave a hole revealing brown hair through/above the equipment.
        shade_fill(base,true_hair & (layer[:,:,3]==0),layer,palette)
        erase=true_hair.copy()
        # Preserve intentional silhouette cutouts of the authored helmet (old hair fringe).
        source_info=IX['camadas'][piece]
        if 'apagar_vila' in source_info:
            cut=cell(read(GEAR/source_info['apagar_vila']),i,48)
            cut=np.array(Image.fromarray(cut).transform((w,h),Image.Transform.AFFINE,(1/scale,0,x0-(x0+dx)/scale,0,1/scale,y0-(y0+dy)/scale),resample=Image.Resampling.NEAREST))[:,:,3]>128
            cut &= region & (base[:,:,3]>128) & (ids!=1) & (ids!=2)
            layer[cut]=0;erase|=cut
    else:
        layer=old.copy()
        # Torso art may extend one pixel beyond the body, but never cover the actual head.
        head=true_hair.copy()
        yy=np.indices((h,w))[0]
        # Only actual hair and facial skin are protected. A rectangular head box
        # would also erase the chest behind the lower side strands of hair.
        head |= (ids==1)&region&(yy<y0+dy+round((y1-y0)*scale*.82))
        valid=dilation(base[:,:,3]>128)&~head
        layer[~valid]=0
        shirt=(ids==2)&~head
        # Restrict semantic shirt classification to the body near the head; weapon/VFX are protected.
        near=np.zeros((h,w),bool)
        near[max(0,bottom-6):min(h,bottom+22),max(0,x0+dx-7):min(w,right+7)]=True
        shirt &= near
        palette=old[(old[:,:,3]>128)&near]
        if len(palette)==0:palette=old[old[:,:,3]>128]
        if len(palette):shade_fill(base,shirt & (layer[:,:,3]==0),layer,palette)
        erase=np.zeros((h,w),bool)
    return layer,erase,true_hair,error

def main():
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').write_text('')
    records={};sources={};anchors={}
    previous=json.loads((OUT/'ancoras.json').read_text()) if (OUT/'ancoras.json').exists() else {}
    previous_sources=json.loads((OUT/'fontes.json').read_text()) if (OUT/'fontes.json').exists() else {}
    template_hash=hashlib.sha256(b''.join((ROOT/'art/characters/vale_unica/rotations'/f'{d}.png').read_bytes() for d in DIRS)).hexdigest()
    for source,meta in MASKS.items():
        path=ROOT/source[6:];sources[source]=hashlib.sha256(path.read_bytes()).hexdigest()
        base=read(path);ids=read(ROOT/meta['mask'][6:])[:,:,0]
        combat='vale_combate_v6pal/' in source
        size=112 if combat else 48
        direction=path.name.split('_')[-2] if combat else path.parent.name
        if not combat and path.parent.name=='rotations':direction=path.stem
        for frame in range(49 if combat else 1):
            if source in previous and previous[source].get('algorithm')==4 and previous[source].get('template_hash')==template_hash and previous_sources.get(source)==sources[source]:
                prior=previous[source]['anchors'][frame]
                anchors[(source,frame)]=locate(cell(base,frame,size),direction,cell(ids[:,:,None],frame,size)[:,:,0]) if prior[2]>100 else tuple(prior[:3])+((prior[3] if len(prior)>3 else 1.0),)
            else:anchors[(source,frame)]=locate(cell(base,frame,size),direction,cell(ids[:,:,None],frame,size)[:,:,0])
        records[source]={'algorithm':4,'template_hash':template_hash,'direction':direction,'size':size,'anchors':[anchors[(source,f)] for f in range(49 if combat else 1)]}
        (OUT/'ancoras.json').write_text(json.dumps(records,indent=2))
        if combat:print('ANCORAS',path.name,flush=True)
    (OUT/'ancoras.json').write_text(json.dumps(records,indent=2))
    head_only='--cabeca' in sys.argv
    overrides=json.loads((OUT/'indice.json').read_text())['camadas'] if head_only and (OUT/'indice.json').exists() else {}
    for piece in (HEAD if head_only else HEAD+BODY):
        info=IX['camadas'][piece];entry={}
        atlas=read(GEAR/info['vila']);new=np.zeros_like(atlas);erase=np.zeros_like(atlas)
        for i,file in enumerate(IX['vila']['quadros']):
            source=IX['vila']['base']+file;meta=MASKS[source];base=read(ROOT/source[6:]);ids=read(ROOT/meta['mask'][6:])[:,:,0]
            layer,ap,_,_=fix(base,ids,cell(atlas,i,48),records[source]['direction'],piece,anchors[(source,0)])
            mask=np.zeros_like(base);mask[ap]=255
            x=i%16*48;y=i//16*48;new[y:y+48,x:x+48]=layer;erase[y:y+48,x:x+48]=mask
        save(OUT/piece/'vila.png',new);save(OUT/piece/'vila_apagar.png',erase)
        entry.update(vila=f'correcao_v2/{piece}/vila.png',apagar_vila=f'correcao_v2/{piece}/vila_apagar.png',combate=f'correcao_v2/{piece}/combate/',apagar_combate=f'correcao_v2/{piece}/combate_apagar/')
        for source,record in records.items():
            if record['size']!=112:continue
            name=Path(source).name;base=read(ROOT/source[6:]);ids=read(ROOT/MASKS[source]['mask'][6:])[:,:,0];old=read(GEAR/info['combate']/name);new=np.zeros_like(old);erase=np.zeros_like(old)
            for frame in range(49):
                bcell=cell(base,frame,112);mid=cell(ids[:,:,None],frame,112)[:,:,0]
                layer,ap,_,_=fix(bcell,mid,cell(old,frame,112),record['direction'],piece,anchors[(source,frame)])
                mask=np.zeros_like(bcell);mask[ap]=255
                x=frame%8*112;y=frame//8*112;new[y:y+112,x:x+112]=layer;erase[y:y+112,x:x+112]=mask
            save(OUT/piece/'combate'/name,new);save(OUT/piece/'combate_apagar'/name,erase)
        overrides[piece]=entry
        print('CORRIGIDO',piece,flush=True)
    (OUT/'indice.json').write_text(json.dumps({'versao':2,'base_id':'vale_unica_gamelab_v1','camadas':overrides},indent=2))
    (OUT/'ancoras.json').write_text(json.dumps(records,indent=2))
    (OUT/'fontes.json').write_text(json.dumps(sources,indent=2))
    print('Concluido; fontes originais preservadas.')

if __name__=='__main__':main()
