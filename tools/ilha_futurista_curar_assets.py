#!/usr/bin/env python3
"""Curadoria dos packs CC0 de ficção científica para a Ilha Futurista (Estação Ontem-Amanhã).
PROPOSTA (não é canon). Mesmo espírito de tools/vila_grande_curar_assets.py:
- copia só os modelos usados (glTF+.bin ou .glb);
- reduz texturas (1024 px cor, 512 px normal); remove ORM/roughness (roughness fixa) para a luz do jogo;
- recolore para a paleta fria da ilha: aço azulado, grafite, acentos NEON ciano/magenta (emissivos);
- Kenney Space Kit: recentra a origem (os .glb vêm deslocados de (2, 0, 1.5)) e troca as cores dos materiais.
Uso: python3 tools/ilha_futurista_curar_assets.py   (espera os zips extraídos em DL; ajuste DL/REPO)
"""
import colorsys, json, os, shutil, struct, sys
import numpy as np
from PIL import Image

DL = os.environ.get('FUT_DL', '/workspace/dl_fut')
REPO = os.environ.get('FUT_REPO', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
OUT = os.path.join(REPO, 'art', 'models')

def hexrgb(h):
    return [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]

# ------------------------------------------------------------------ texturas
def hue_shift(img, hue_deg, sat_min=0.25, frio=0.10, escurece=0.9):
    """pixels saturados ganham o matiz pedido (neon); os neutros ficam levemente azulados."""
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255.0
    rgb, al = a[..., :3], a[..., 3:]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 1e-3, (mx - mn) / np.maximum(mx, 1e-3), 0)
    h = hue_deg / 360.0
    alvo = np.array(colorsys.hsv_to_rgb(h, 1.0, 1.0), np.float32)
    viv = (alvo * mx[..., None]) * 0.85 + mx[..., None] * 0.15
    w = np.clip((sat - sat_min) / 0.25, 0, 1)[..., None]
    neutro = rgb * escurece
    neutro = neutro * (1 - frio) + neutro.mean(-1, keepdims=True) * np.array([0.82, 0.92, 1.18], np.float32) * frio
    out = np.clip(neutro * (1 - w) + viv * w, 0, 1)
    return Image.fromarray((np.concatenate([out, al], -1) * 255).astype(np.uint8), 'RGBA')

def save_tex(src, dst_dir, name, fn=None, normal=False):
    im = Image.open(src)
    if fn:
        im = fn(im)
    lim = 512 if normal else 1024
    if max(im.size) > lim:
        s = lim / max(im.size)
        im = im.resize((max(1, int(im.size[0] * s)), max(1, int(im.size[1] * s))), Image.LANCZOS)
    rgba = np.asarray(im.convert('RGBA'))
    has_alpha = rgba[..., 3].min() < 250
    base = os.path.splitext(name)[0]
    if has_alpha:
        out = base + '.png'; im.convert('RGBA').save(os.path.join(dst_dir, out), optimize=True)
    else:
        out = base + '.jpg'; im.convert('RGB').save(os.path.join(dst_dir, out), quality=88)
    return out

# ------------------------------------------------------------------ glTF (Quaternius)
def curar_gltf(src_dir, nomes, dst, recolor, tex_dir=None, mat_fn=None, normal=True):
    os.makedirs(dst, exist_ok=True)
    feitos = {}
    for n in nomes:
        p = os.path.join(src_dir, n + '.gltf')
        d = json.load(open(p))
        base_dir = os.path.dirname(p)
        for b in d['buffers']:
            shutil.copy(os.path.join(base_dir, b['uri']), os.path.join(dst, os.path.basename(b['uri'])))
            b['uri'] = os.path.basename(b['uri'])
        papel = {}
        drop = set()
        for m in d.get('materials', []):
            pbr = m.setdefault('pbrMetallicRoughness', {})
            if 'baseColorTexture' in pbr: papel[pbr['baseColorTexture']['index']] = 'base'
            if 'normalTexture' in m:
                if normal: papel[m['normalTexture']['index']] = 'normal'
                else: drop.add(d['textures'][m.pop('normalTexture')['index']]['source'])
            if 'metallicRoughnessTexture' in pbr: drop.add(d['textures'][pbr.pop('metallicRoughnessTexture')['index']]['source'])
            if 'occlusionTexture' in m: drop.add(d['textures'][m.pop('occlusionTexture')['index']]['source'])
            pbr['roughnessFactor'] = 0.55
            pbr['metallicFactor'] = 0.25
            if mat_fn: mat_fn(m)
        vistos = set()
        for ti, t in enumerate(d.get('textures', [])):
            if t['source'] in drop or t['source'] in vistos: continue
            vistos.add(t['source'])
            img = d['images'][t['source']]
            uri = img['uri']
            role = papel.get(ti, 'base')
            fonte = os.path.join(tex_dir or base_dir, uri)
            if not os.path.exists(fonte): fonte = os.path.join(base_dir, uri)
            if uri not in feitos:
                feitos[uri] = save_tex(fonte, dst, uri, recolor.get(uri) if role == 'base' else None, role == 'normal')
            img['uri'] = feitos[uri]; img['mimeType'] = 'image/png' if feitos[uri].endswith('.png') else 'image/jpeg'
        for i, img in enumerate(d.get('images', [])):
            if i in drop:
                if '_px' not in feitos:
                    Image.new('RGB', (1, 1), (200, 200, 210)).save(os.path.join(dst, 'px.png')); feitos['_px'] = 'px.png'
                img['uri'] = 'px.png'; img['mimeType'] = 'image/png'
        json.dump(d, open(os.path.join(dst, n.split('/')[-1] + '.gltf'), 'w'))
    print(dst, len(nomes), 'modelos')

# ------------------------------------------------------------------ glb (Kenney)
def ler_glb(p):
    b = open(p, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + l])
    rest = b[20 + l:]
    binc = None
    if len(rest) >= 8:
        bl = struct.unpack('<I', rest[:4])[0]; binc = rest[8:8 + bl]
    return j, binc

def gravar_glb(p, j, binc):
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((4 - len(js) % 4) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 0) + struct.pack('<I4s', len(js), b'JSON') + js
    if binc is not None:
        pad = binc + b'\0' * ((4 - len(binc) % 4) % 4)
        out += struct.pack('<I4s', len(pad), b'BIN\0') + pad
    out = out[:8] + struct.pack('<I', len(out)) + out[12:]
    open(p, 'wb').write(out)

def curar_glb(src_dir, nomes, dst, cores, desloc=(0, 0, 0), tex_fn=None):
    os.makedirs(dst, exist_ok=True)
    tex_feitas = set()
    for n in nomes:
        j, binc = ler_glb(os.path.join(src_dir, n + '.glb'))
        for m in j.get('materials', []):
            nome = m.get('name', '')
            pbr = m.setdefault('pbrMetallicRoughness', {})
            pbr.pop('metallicRoughnessTexture', None)
            pbr['roughnessFactor'] = 0.6
            pbr['metallicFactor'] = 0.2
            if nome in cores:
                c = cores[nome]
                pbr['baseColorFactor'] = hexrgb(c['cor']) + [1.0]
                if 'emissao' in c:
                    m['emissiveFactor'] = hexrgb(c['emissao'])
                    m.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {'emissiveStrength': float(c.get('forca', 1.5))}
                    j.setdefault('extensionsUsed', [])
                    if 'KHR_materials_emissive_strength' not in j['extensionsUsed']:
                        j['extensionsUsed'].append('KHR_materials_emissive_strength')
                m['name'] = c.get('nome', nome)
        for img in j.get('images', []):
            if 'uri' in img:
                rel = img['uri']
                if rel not in tex_feitas:
                    os.makedirs(os.path.join(dst, os.path.dirname(rel)), exist_ok=True)
                    im = Image.open(os.path.join(src_dir, rel))
                    if tex_fn: im = tex_fn(im)
                    im.convert('RGBA').save(os.path.join(dst, rel))
                    tex_feitas.add(rel)
        if any(desloc):
            sc = j['scenes'][j.get('scene', 0)]
            for r in sc['nodes']:
                no = j['nodes'][r]
                if 'matrix' in no:
                    for k in range(3): no['matrix'][12 + k] += desloc[k]
                else:
                    t = no.get('translation', [0, 0, 0])
                    no['translation'] = [t[k] + desloc[k] for k in range(3)]
        gravar_glb(os.path.join(dst, n + '.glb'), j, binc)
    print(dst, len(nomes), 'modelos')

# ================================================================== packs
NEON_C = '19e6ff'   # ciano
NEON_M = 'ff3df0'   # magenta

def main():
    # ---- Kenney Space Kit (CC0)
    KS = DL + '/kenney_space-kit/Models/GLTF format'
    ks = """hangar_largeA hangar_largeB hangar_roundA hangar_roundB hangar_roundGlass hangar_smallA hangar_smallB
structure structure_detailed structure_closed structure_diagonal platform_large platform_center platform_low platform_high
rocket_baseA rocket_fuelA rocket_sidesA rocket_finsA rocket_topA rover satelliteDish_large satelliteDish_detailed
rock_crystalsLargeA rock_crystalsLargeB rock_crystals rock_largeA rock_largeB rocks_smallA meteor_detailed crater craterLarge
machine_generatorLarge machine_generator machine_barrelLarge machine_wireless machine_wirelessCable
astronautA astronautB alien craft_cargoA craft_cargoB craft_miner craft_speederA craft_racer
monorail_trackStraight monorail_trackSupport monorail_trainFront monorail_trainCargo turret_double gate_complex gate_simple
barrels barrels_rail pipe_straight pipe_ring pipe_supportHigh pipe_corner pipe_ringHigh desk_computer desk_computerScreen
supports_high supports_low chimney_detailed corridor corridor_window corridor_roof corridor_open stairs bones""".split()
    cores = {
        'metal': {'cor': 'b4bed0'}, 'metalDark': {'cor': '5c667c'}, 'dark': {'cor': '20263a'},
        'metalRed': {'cor': NEON_C, 'emissao': NEON_C, 'forca': 1.6, 'nome': 'neon'},
        'crystal': {'cor': '8cfbff', 'emissao': '3ae0ff', 'forca': 1.2, 'nome': 'cristal'},
        'rock': {'cor': '5e5874'}, 'rockDark': {'cor': '3e3a54'}, 'rockTrack': {'cor': '6c6688'},
    }
    curar_glb(KS, ks, OUT + '/kenney_space_kit', cores, desloc=(-2.0, 0.0, -1.5))
    shutil.copy(DL + '/kenney_space-kit/License.txt', OUT + '/kenney_space_kit/License.txt')

    # ---- Kenney Space Station Kit (CC0): textura colormap compartilhada, neon magenta
    KST = DL + '/kenney_space-station-kit/Models/GLB format'
    kst = """container container-tall container-wide display-wall display-wall-wide table-display-planet table-display
computer-system computer-wide skip-rocks skip structure-barrier-high structure-barrier""".split()
    curar_glb(KST, kst, OUT + '/kenney_space_station', {}, tex_fn=lambda im: hue_shift(im, 300, 0.3, 0.15, 0.95))
    shutil.copy(DL + '/kenney_space-station-kit/License.txt', OUT + '/kenney_space_station/License.txt')

    # ---- Kenney Modular Space Kit (CC0): portão de lasers e cabos
    KM = DL + '/kenney_modular-space-kit/Models/GLB format'
    curar_glb(KM, ['gate-lasers', 'cables'], OUT + '/kenney_modular_space', {}, tex_fn=lambda im: hue_shift(im, 185, 0.3, 0.15, 0.95))
    shutil.copy(DL + '/kenney_modular-space-kit/License.txt', OUT + '/kenney_modular_space/License.txt')

    # ---- Quaternius Modular SciFi MegaKit [Standard] (CC0)
    QM = DL + '/qmod/Modular SciFi MegaKit[Standard]'
    qm = """Platforms/Platform_Metal Platforms/Platform_DarkPlates Platforms/Platform_Round1 Platforms/Platform_Squares
Platforms/Platform_Simple Platforms/Platform_Rails_4Wide Platforms/Platform_Stairs_4Wide Platforms/Door_Frame_Square
Platforms/Door_Metal Platforms/Platform_X Columns/Column_Astra Columns/Column_Pipes Columns/Column_MetalSupport Columns/Column_Round
Walls/WallAstra_Straight Walls/WallAstra_Straight_Window Walls/WallWindow_Straight Walls/WallBand_Straight
Walls/WallAstra_Corner_Square_Outer Walls/WallBand_Corner_Square_Outer Walls/TopAstra_Straight Walls/TopCables_Straight
Props/Prop_Computer Props/Prop_Crate3 Props/Prop_Barrel_Large Props/Prop_Light_Floor Props/Prop_Chest Props/Prop_Vent_Big
Props/Prop_Fan_Small Props/Prop_ItemHolder Props/Prop_Light_Wide Aliens/Alien_Cyclop Aliens/Alien_Oculichrysalis Decals/Decal_Logo
Decals/Decal_Line_Straight Decals/Decal_Dashes""".split()
    rc = {}
    for t in ['T_Trim_01_BaseColor_Red.png', 'T_Trim_02_BaseColor_Red.png', 'T_Decals.png', 'T_Trim_03_Cables.png']:
        rc[t] = lambda im: hue_shift(im, 300, 0.3, 0.15, 0.92)
    for t in ['T_Trim_01_BaseColor.png', 'T_Trim_02_BaseColor.png', 'T_Trim_02_BaseColor_Blue.png', 'T_Trim_03_BaseColor.png', 'T_PaddedWall_BaseColor.png']:
        rc[t] = lambda im: hue_shift(im, 188, 0.3, 0.2, 0.9)
    def mat_q(m):
        n = m.get('name', '')
        if n in ('M_Light', 'M_Decal_Screen', 'M_LightFade_Red', 'MI_Trim_03_Cables_Blue'):
            m['emissiveFactor'] = hexrgb(NEON_C if n != 'M_LightFade_Red' else NEON_M)
        if n == 'M_Glass':
            m['pbrMetallicRoughness']['baseColorFactor'] = hexrgb('3aa8c8') + [0.55]
            m['emissiveFactor'] = hexrgb('0a3a4a')
    curar_gltf(QM + '/glTF', qm, OUT + '/quaternius_scifi_modular', rc, tex_dir=QM + '/Textures', mat_fn=mat_q)
    shutil.copy(QM + '/License_Standard.txt', OUT + '/quaternius_scifi_modular/License_Standard.txt')

    # ---- Quaternius Sci-Fi Essentials Kit [Standard] (CC0): drones/robôs e props
    QE = DL + '/qess'
    qe = """Enemy_EyeDrone Enemy_QuadShell Enemy_Trilobite Prop_Locker Prop_Crate_Large Prop_Crate_Tarp_Large Prop_SatelliteDish
Prop_Shelves_WideTall Prop_Desk_L Prop_Barrel2_Closed""".split()
    rce = {'T_Enemies_BaseColor_png.png': lambda im: hue_shift(im, 188, 0.3, 0.1, 0.95),
           'T_Enemies_Large_BaseColor.png': lambda im: hue_shift(im, 300, 0.3, 0.1, 0.95),
           'T_Trim_01_BaseColor_Red.png': lambda im: hue_shift(im, 300, 0.3, 0.15, 0.92),
           'T_Trim_02_BaseColor_Red.png': lambda im: hue_shift(im, 300, 0.3, 0.15, 0.92),
           'T_Trim_02_BaseColor.png': lambda im: hue_shift(im, 188, 0.3, 0.2, 0.9),
           'T_Trim_03_BaseColor.png': lambda im: hue_shift(im, 188, 0.3, 0.2, 0.9),
           'T_Props_Crates_BaseColor.png': lambda im: hue_shift(im, 188, 0.3, 0.2, 0.9),
           'T_Props_Batch1_BaseColor.png': lambda im: hue_shift(im, 188, 0.3, 0.2, 0.9)}
    curar_gltf(QE + '/glTF', qe, OUT + '/quaternius_scifi_essentials', rce, tex_dir=QE + '/Textures', normal=False)
    shutil.copy(QE + '/License_Standard.txt', OUT + '/quaternius_scifi_essentials/License_Standard.txt')

    # ---- Poly Haven (CC0): texturas de metal para pisos e paredes procedurais
    PH = OUT + '/../materials/ilha_futurista'
    os.makedirs(PH, exist_ok=True)
    for a in ['metal_plate', 'metal_plate_02', 'corrugated_iron']:
        for t in ['diff', 'nor_gl']:
            src = f'{DL}/{a}_{t}_1k.jpg'
            im = Image.open(src)
            if t == 'diff':
                im = hue_shift(im, 200, 0.6, 0.35, 0.95)
            else:
                im = im.resize((512, 512), Image.LANCZOS)
            im.convert('RGB').save(f'{PH}/{a}_{t}.jpg', quality=88)
    print(PH, 'texturas Poly Haven')

if __name__ == '__main__':
    main()
