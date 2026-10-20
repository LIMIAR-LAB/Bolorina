from PIL import Image
import glob,os,sys
SRC='/workspace/arte_noite/_fontes/retratos'; OUT='/workspace/arte_noite/art/ui/retratos'
os.makedirs(OUT,exist_ok=True)
GRID=int(sys.argv[1]) if len(sys.argv)>1 else 64
MODE=sys.argv[2] if len(sys.argv)>2 else 'box'
for f in sorted(glob.glob(SRC+'/*.jpg')):
    im=Image.open(f).convert('RGB'); w,h=im.size
    m=int(w*0.04); im=im.crop((m,m,w-m,h-m))
    small=im.resize((GRID,GRID),Image.BOX if MODE=='box' else Image.NEAREST)
    q=small.quantize(colors=32,method=Image.MEDIANCUT,dither=Image.Dither.NONE).convert('RGB')
    q.resize((128,128),Image.NEAREST).save(OUT+'/'+os.path.basename(f)[:-4]+'.png',optimize=True)
print(len(glob.glob(OUT+'/*.png')))
