"""Molduras vetoriais originais, escalaveis por nove fatias. Sem rasterizar textos/botoes."""
from pathlib import Path
OUT=Path(__file__).resolve().parent.parent/'art/ui/vilarejo'
OUT.mkdir(parents=True,exist_ok=True)
def frame(name,top,bottom,edge,ornate=False,wood=False):
    w,h=128,128
    path='M18 5 H110 L123 18 V110 L110 123 H18 L5 110 V18 Z'
    svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs>
    <linearGradient id="fill" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
    <linearGradient id="edge" x2="0.2" y2="1"><stop stop-color="#f5d49a"/><stop offset=".35" stop-color="{edge}"/><stop offset=".8" stop-color="#70482d"/><stop offset="1" stop-color="#dc9e59"/></linearGradient>
    </defs><path d="{path}" fill="url(#fill)" stroke="#101216" stroke-width="7" stroke-linejoin="round"/>
    <path d="{path}" fill="none" stroke="url(#edge)" stroke-width="3"/>
    <path d="M20 11 H108 L117 20 V108 L108 117 H20 L11 108 V20 Z" fill="none" stroke="#956a45" stroke-opacity=".65" stroke-width="1"/>
    <path d="M21 14 H107 M14 22 V106" stroke="#ffe0ad" stroke-opacity=".16" stroke-width="1"/>'''
    if ornate:
        for transform in ['', 'translate(128 0) scale(-1 1)', 'translate(0 128) scale(1 -1)', 'translate(128 128) scale(-1 -1)']:
            svg+=f'<g transform="{transform}"><path d="M9 23 Q21 23 19 19 Q23 21 23 9" fill="none" stroke="#c08a50" stroke-width="2"/><path d="M17 11 L20 14 L17 17 L14 14 Z" fill="#e6b76e"/></g>'
    if wood:
        for y in range(26,110,12):
            svg+=f'<path d="M25 {y} Q60 {y-3} 103 {y+1}" fill="none" stroke="#281910" stroke-opacity=".22" stroke-width="1"/>'
    if name.startswith('slot') or name.startswith('botao') or name=='vazio':
        svg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><defs><linearGradient id="fill" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs><rect x="3" y="4" width="58" height="58" rx="7" fill="#17161a"/><rect x="3" y="2" width="58" height="58" rx="7" fill="url(#fill)" stroke="{edge}" stroke-width="2"/><rect x="5" y="4" width="54" height="54" rx="5" fill="none" stroke="#ffe6ba" stroke-opacity=".21"/>'''
    svg+='</svg>'
    (OUT/(name+'.svg')).write_text(svg,encoding='utf-8')
frame('moldura','#343138','#25252d','#d6a362',True)
frame('painel','#2c2b32','#24242c','#98704e',True)
frame('madeira','#71462b','#4a2e20','#e7b46b',True,True)
frame('slot','#e5bd86','#bf925d','#9b7248')
frame('slot_selecionado','#f2d39b','#d7ad6e','#ffdd81')
frame('slot_vestido','#d0c78b','#8d9f60','#d5dd91')
frame('botao','#414149','#303038','#7e7772')
frame('botao_ativo','#f4cc7e','#d69c51','#ffe5ac')
frame('vazio','#303036','#2a2a31','#4b4850')
print('9 texturas vetoriais criadas')
