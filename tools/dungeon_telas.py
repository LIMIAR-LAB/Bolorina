#!/usr/bin/env python3
"""Gera art/ui/telas/<id>.png (1280x720) para as 7 áreas a partir das capturas da masmorra.
Uso: python3 tools/dungeon_telas.py <pasta_capturas>"""
import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
CAP = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "art", "ui", "telas")
os.makedirs(OUT, exist_ok=True)
F = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
F2 = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
AREAS = {
    "porto_velho": ("porto_velho_entrada_elevador_minas_local.png", "Porto Velho", "Ilha das Cinzas · Elevador do Tião para as Minas", "ffd27a"),
    "vila_orcs": ("vila_orcs_entrada_boca_da_caverna_local.png", "Vila dos Orcs", "Clã Brasa-Velha · Boca do Veio das Cinzas", "ff9a5a"),
    "cidade_fantasma": ("cidade_fantasma_entrada_portao_da_cripta_local.png", "Cidade Fantasma", "Cinzalta · Portão da Cripta", "bfe8ff"),
    "estacao_depois_de_ontem": ("estacao_depois_de_ontem_entrada_fenda_temporal_local.png", "Estação Depois-de-Ontem", "Ilha caída do futuro · Fenda Temporal", "7af4ff"),
    "minas_da_cinza": ("minas_da_cinza_andar_08_visao_geral.png", "Minas da Cinza", "Orcs · andares 1-12 e o Coração Soterrado (20)", "ffb070"),
    "criptas_de_cinzalta": ("criptas_de_cinzalta_andar_02_visao_geral.png", "Criptas de Cinzalta", "Zumbis, esqueletos e fantasmas · 5 andares + chefe", "bff0e8"),
    "fenda_cronal": ("fenda_cronal_andar_03_visao_geral.png", "Fenda Cronal", "Anomalias temporais · 5 andares + chefe", "ff9af0"),
}
for aid, (arq, nome, sub, cor) in AREAS.items():
    src = os.path.join(CAP, arq)
    if not os.path.exists(src):
        print("faltou", src); continue
    im = Image.open(src).convert("RGB").resize((1280, 720), Image.LANCZOS)
    # vinheta + faixa escura embaixo para o título
    v = Image.new("L", (1280, 720), 0)
    d = ImageDraw.Draw(v)
    for i in range(120):
        d.rectangle([i * 2, i * 1, 1280 - i * 2, 720 - i * 1], outline=int(255 * (1 - i / 120) ** 2))
    v = v.filter(ImageFilter.GaussianBlur(30))
    im = Image.composite(Image.new("RGB", im.size, (8, 6, 10)), im, v.point(lambda p: int(p * 0.6)))
    faixa = Image.new("RGBA", (1280, 180), (0, 0, 0, 0))
    fd = ImageDraw.Draw(faixa)
    for y in range(180):
        fd.line([(0, y), (1280, y)], fill=(6, 4, 8, int(220 * y / 180)))
    im.paste(faixa, (0, 540), faixa)
    d = ImageDraw.Draw(im)
    c = tuple(int(cor[i:i + 2], 16) for i in (0, 2, 4))
    ft, fs = ImageFont.truetype(F, 60), ImageFont.truetype(F2, 26)
    d.text((52, 590), nome, font=ft, fill=c, stroke_width=3, stroke_fill=(10, 6, 6))
    d.text((56, 664), sub, font=fs, fill=(235, 230, 220), stroke_width=2, stroke_fill=(10, 6, 6))
    im.save(os.path.join(OUT, aid + ".png"), optimize=True)
    print("ok", aid)
