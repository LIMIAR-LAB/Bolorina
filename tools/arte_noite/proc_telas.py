from PIL import Image
import glob,os
S='/workspace/arte_noite/_fontes/telas'; OUT='/workspace/arte_noite/art/ui/telas'
os.makedirs(OUT,exist_ok=True)
for f in sorted(glob.glob(S+'/*.jpg')):
    n=os.path.basename(f)[:-4]
    im=Image.open(f).convert('RGB')
    w,h=im.size; th=int(w*9/16)
    if th!=h: im=im.crop((0,(h-th)//2,w,(h-th)//2+th))
    small=im.resize((640,360),Image.LANCZOS)
    q=small.quantize(colors=96,method=Image.FASTOCTREE,dither=Image.Dither.NONE).convert('RGB')
    q.save(f'{OUT}/{n}_640x360.png',optimize=True)
    big=im.resize((1280,720),Image.LANCZOS) if im.size!=(1280,720) else im
    big.quantize(colors=128,method=Image.FASTOCTREE,dither=Image.Dither.NONE).convert('RGB').save(f'{OUT}/{n}.png',optimize=True)
print(sorted(os.listdir(OUT)))
