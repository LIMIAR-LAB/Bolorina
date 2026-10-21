from pathlib import Path
import json,numpy as np,hashlib
from PIL import Image
r=Path.cwd();g=r/'art/characters/vale_trajes';old=json.loads((g/'correcao_v2/indice.json').read_text());new=json.loads((g/'correcao_v3/indice.json').read_text());count=0;white0=0;white1=0
for piece,info in new['camadas'].items():
 for typ in ['vila','combate']:
  paths=[g/info[typ]] if typ=='vila' else list((g/info[typ]).glob('*.png'))
  for p in paths:
   a=np.array(Image.open(p).convert('RGBA'));b=np.array(Image.open(Path(str(p).replace('correcao_v3','correcao_v2'))).convert('RGBA'))
   assert a.shape==b.shape,(piece,p)
   assert np.all((a[:,:,3]==0)|(a[:,:,3]==255)),p
   white0+=int(((b[:,:,:3].min(2)>225)&(b[:,:,3]>0)).sum());white1+=int(((a[:,:,:3].min(2)>225)&(a[:,:,3]>0)).sum());count+=1
assert white1==0
sources=json.loads((g/'correcao_v2/fontes.json').read_text())
for source,sha in sources.items():assert hashlib.sha256((r/source[6:]).read_bytes()).hexdigest()==sha,source
print('QA camadas:',count,'imagens; dimensoes e alpha corretos. Realces quase brancos:',white0,'->',white1,'. Fontes originais intactas:',len(sources))
