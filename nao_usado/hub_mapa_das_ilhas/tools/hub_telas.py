#!/usr/bin/env python3
"""Gera art/ui/telas/<id>.png (1280x720) das áreas da Ilha do Alto (fazenda, vilarejo, arena)
a partir de capturas do próprio jogo em docs/ (recorta a HUD) e refaz as 4 cidades com vistas limpas
(capturas das entregas anteriores, quando estão no box). Mesmo estilo de tools/dungeon_telas.py.
Uso: python3 tools/hub_telas.py"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(RAIZ, "art", "ui", "telas")
F = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
F2 = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
AREAS = {
    # id: (captura, recorte (x0, y0, x1, y1) em 1600x900, nome, subtítulo, cor)
    "fazenda_do_alto": ("docs/fazenda-geral.png", (186, 66, 1414, 757), "Fazenda do Alto", "Ilha do Alto · horta, galinheiro e lago", "c8f08a"),
    "vila_da_ilha": ("docs/fid-v7-final.png", (100, 60, 1500, 848), "Vilarejo do Alto", "Ilha do Alto · casas, rio e a estrada das ruínas", "ffd99a"),
    "arena_das_cinzas": ("docs/combate-captura-1.png", (200, 150, 1400, 825), "Arena das Cinzas", "Ruínas do Alto · treino e teste de equipamento", "ffb09a"),
}
# cidades: vistas limpas (sem rótulos de entrada) das entregas anteriores, se existirem no box
EXTRA = {
    "porto_velho": ("/workspace/vila_grande_previews/vila_grande_praca.png", (0, 0, 1600, 900), "Porto Velho", "Ilha das Cinzas · praça, Ferraria do Porto e a doca do dirigível", "ffd27a"),
    "vila_orcs": ("/workspace/vila_grande_previews/vila_orcs_fogueira_e_salao.png", (0, 0, 1600, 900), "Vila dos Orcs", "Clã Brasa-Velha · fogueira do conselho e a forja do Krag", "ff9a5a"),
    "cidade_fantasma": ("/workspace/vila_grande_previews/cidade_fantasma_praca_e_ruinas.png", (0, 0, 1600, 900), "Cidade Fantasma", "Cinzalta · ruínas noturnas e o cemitério das criptas", "bfe8ff"),
    "estacao_depois_de_ontem": ("/workspace/forja_entrega/previews/ilha_futurista_forja_quantica.png", (0, 0, 1600, 900), "Estação Depois-de-Ontem", "Ilha caída do futuro · Forja Quântica e a Fenda", "7af4ff"),
}
for k, v in EXTRA.items():
    if os.path.exists(v[0]):
        AREAS[k] = v
for aid, (arq, caixa, nome, sub, cor) in AREAS.items():
    im = Image.open(os.path.join(RAIZ, arq)).convert("RGB").crop(caixa).resize((1280, 720), Image.LANCZOS)
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
    d.text((56, 666), sub, font=fs, fill=(235, 225, 210), stroke_width=2, stroke_fill=(10, 6, 6))
    im.save(os.path.join(OUT, aid + ".png"), optimize=True)
    print("ok", aid)
