from PIL import Image, ImageDraw, ImageFont
import glob, os
B='/workspace/arte_noite'
try: F=ImageFont.truetype('/workspace/bolorina_integrado/art/ui/dialogos/fontes/PixelifySans.ttf',14)
except: F=ImageFont.load_default()
BG=(40,26,18,255)
def sheet(files,cell,cols,scale,out,label=True):
    rows=(len(files)+cols-1)//cols; lh=20 if label else 0
    W,H=cell[0]*scale+12,cell[1]*scale+12+lh
    s=Image.new('RGBA',(cols*W,rows*H),BG); d=ImageDraw.Draw(s)
    for i,f in enumerate(files):
        im=Image.open(f).convert('RGBA'); im=im.resize((im.width*scale,im.height*scale),Image.NEAREST) if scale!=1 else im
        x,y=(i%cols)*W+6,(i//cols)*H+6
        s.alpha_composite(im,(x,y))
        if label: d.text((x,y+cell[1]*scale+2),os.path.basename(f)[:-4],fill=(230,210,180),font=F)
    s.convert('RGB').save(out,optimize=True); print(out,s.size)
ordem=['guardia','sineiro','ferreiro','estalajadeira','arquimago','capitao','jardineira','lider_orc','condessa','lobisomem','dragao','mira',
'mercador_praca','morador_1','morador_2','crianca_praca','gato','xama_orc','ferreiro_orc','guerreiro_orc_1','guerreiro_orc_2','cacadora_orc','anciao_orc','prisioneiro',
'espectro_sineiro','eco_arquimago','mercador_reliquias','coveiro','vampiro_menor_1','espectro_1']
sheet([f'{B}/art/ui/retratos/{i}.png' for i in ordem],(128,128),6,1,f'{B}/previews/contato_retratos.png')
sheet(sorted(glob.glob(f'{B}/art/ui/icones/*.png')),(32,32),6,4,f'{B}/previews/contato_icones.png')
sheet(sorted(glob.glob(f'{B}/art/ui/telas/*_640x360.png')),(640,360),2,1,f'{B}/previews/contato_telas.png')
