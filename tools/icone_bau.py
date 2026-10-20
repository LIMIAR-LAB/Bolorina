#!/usr/bin/env python3
"""Icone 16x16 do Bau de madeira (pixel art desenhada por codigo, original do projeto; sem geracao paga).
Saida: art/ui/icones_fabricar/bau.png  (uso: python3 tools/icone_bau.py)"""
from PIL import Image
import os
P = {
    ".": (0, 0, 0, 0),
    "k": (43, 26, 16, 255),     # contorno
    "d": (92, 58, 34, 255),     # madeira escura
    "m": (138, 90, 50, 255),    # madeira
    "l": (178, 124, 72, 255),   # madeira clara (tampa)
    "h": (214, 164, 104, 255),  # brilho
    "i": (74, 74, 84, 255),     # ferro
    "j": (120, 122, 134, 255),  # ferro claro
    "g": (224, 176, 64, 255),   # fecho dourado
    "y": (255, 226, 130, 255),  # brilho do fecho
}
ARTE = [
    "................",
    "................",
    "..kkkkkkkkkkkk..",
    ".klhhlllllhhllk.",
    ".kllilllllilllk.",
    ".kmmimmmmmimmmk.",
    ".kkkjkkkkkjkkkk.",
    ".kmmimmggmimmmk.",
    ".kddiddgydidddk.",
    ".kmmimmggmimmmk.",
    ".kddidddddidddk.",
    ".kmmimmmmmimmmk.",
    ".kddidddddidddk.",
    ".kkkjkkkkkjkkkk.",
    "..k..........k..",
    "................",
]
img = Image.new("RGBA", (16, 16))
for y, linha in enumerate(ARTE):
    for x, c in enumerate(linha):
        img.putpixel((x, y), P[c])
base = os.path.join(os.path.dirname(__file__), "..", "art", "ui", "icones_fabricar")
os.makedirs(base, exist_ok=True)
img.save(os.path.join(base, "bau.png"))
img.resize((128, 128), Image.NEAREST).save("/tmp/bau_previa.png")
print("ok")
