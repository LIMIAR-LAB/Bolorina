"""Camadas derivadas: ancora da coroa por pose, realces sem branco puro e sem ilhas soltas.
Nao modifica as fontes originais nem a correcao v2. Sem rede ou geracao paga.
"""
from pathlib import Path
import json,shutil,importlib.util,numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('alinhamento',ROOT/'tools/equipamento_realinhar.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
GEAR=a.GEAR;OUT=GEAR/'correcao_v3'

def limpar(layer,base):
    out=layer.copy();m=out[:,:,3]>128
    # Highlights com branco quase puro pareciam faíscas nas bordas em movimento.
    white=m&(out[:,:,:3].min(2)>225)
    out[white,:3]=np.minimum(out[white,:3],205)
    # Apenas componentes que encostam no corpo (ou na margem de 1 pixel).
    contact=a.dilation(base[:,:,3]>128);seen=np.zeros(m.shape,bool)
    for y,x in zip(*np.where(m)):
        if seen[y,x]:continue
        stack=[(y,x)];seen[y,x]=True;points=[];touch=False
        while stack:
            yy,xx=stack.pop();points.append((yy,xx));touch|=bool(contact[yy,xx])
            for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
                ny,nx=yy+dy,xx+dx
                if 0<=ny<m.shape[0] and 0<=nx<m.shape[1] and m[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=True;stack.append((ny,nx))
        if not touch:
            for yy,xx in points:out[yy,xx]=0
    out[out[:,:,3]==0]=0
    return out

def main():
    OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').write_text('')
    patch=json.loads((GEAR/'correcao_v2/indice.json').read_text())
    anchors=json.loads((GEAR/'correcao_v2/ancoras.json').read_text())
    maskindex=a.MASKS
    audit=[]
    for piece,info in patch['camadas'].items():
        new=np.zeros_like(a.read(GEAR/info['vila']));erase=np.zeros_like(new)
        for i,file in enumerate(a.IX['vila']['quadros']):
            source=a.IX['vila']['base']+file;base=a.read(ROOT/source[6:]);ids=a.read(ROOT/maskindex[source]['mask'][6:])[:,:,0]
            record=anchors[source];direction=record['direction'];anchor=list(record['anchors'][0]);scale=anchor[3] if len(anchor)>3 else 1.
            if file.startswith('run/'):
                ref,b,_,_=a.TEMPLATES[direction];x0,y0,x1,y1=b
                ys,xs=np.where((ids==4)&(np.indices(ids.shape)[0]<20))
                if len(xs):
                    # Coroa acompanha o deslocamento real da cabeca, nao a camisa/rosto.
                    top=int(ys.min());upper=(ids==4)&(np.indices(ids.shape)[0]<top+12)
                    yy,xx=np.where(upper)
                    anchor[0]=round((xx.min()+xx.max()+1)/2-x0-(x1-x0)*scale/2)
                    anchor[1]=top-y0
            old=a.cell(a.read(GEAR/a.IX['camadas'][piece]['vila']),i,48)
            layer,ap,_,_=a.fix(base,ids,old,direction,piece,anchor)
            layer=limpar(layer,base)
            y=i//16*48;x=i%16*48;new[y:y+48,x:x+48]=layer
            mask=np.zeros_like(base);mask[ap]=255;erase[y:y+48,x:x+48]=mask
            if piece in a.HEAD:audit.append({'peca':piece,'arquivo':file,'ancora':anchor})
        a.save(OUT/piece/'vila.png',new);a.save(OUT/piece/'vila_apagar.png',erase)
        for typ in ['combate','apagar_combate']:
            src=GEAR/info[typ];dst=OUT/piece/('combate' if typ=='combate' else 'combate_apagar')
            dst.mkdir(parents=True,exist_ok=True)
            for path in src.glob('*.png'):
                if typ=='apagar_combate':shutil.copy2(path,dst/path.name);continue
                layer=a.read(path).copy()
                basepath=next(k for k in maskindex if k.endswith('/'+path.name) and 'vale_combate_v6pal/' in k)
                base=a.read(ROOT/basepath[6:])
                for f in range(49):
                    cleaned=limpar(a.cell(layer,f,112),a.cell(base,f,112));y=f//8*112;x=f%8*112
                    layer[y:y+112,x:x+112]=cleaned
                a.save(dst/path.name,layer)
        for key in ['vila','apagar_vila','combate','apagar_combate']:info[key]=info[key].replace('correcao_v2/','correcao_v3/')
        print('REVISADO',piece,flush=True)
    patch['versao']=3
    (OUT/'indice.json').write_text(json.dumps(patch,indent=2))
    (OUT/'ancoras.json').write_text(json.dumps(audit,indent=2))
if __name__=='__main__':main()
