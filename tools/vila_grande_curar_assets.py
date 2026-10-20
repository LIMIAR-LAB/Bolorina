#!/usr/bin/env python3
"""Cura os packs CC0 baixados para art/models/ do Bolorina (Vila Grande).
- copia so os modelos escolhidos (glTF + .bin)
- reduz texturas para 1024 px (JPG para cor sem alfa, PNG para normal/alfa)
- remove mapas ORM/roughness e fixa roughness ~0.9 (paleta do projeto)
- recolore cores-base para a paleta (ardosia azul-acinzentada, reboco creme, madeira escura, pedra cinza)
- vidro das janelas vira ambar emissivo
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image

DL = '/workspace/dl'
REPO = '/workspace/bolorina'
MAX = 1024

def grad(img, dark, light, keep=0.25, lo=2, hi=98):
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255.0
    rgb, al = a[..., :3], a[..., 3:]
    L = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    mask = al[..., 0] > 0.1
    p0, p1 = np.percentile(L[mask] if mask.any() else L, [lo, hi])
    t = np.clip((L - p0) / max(p1 - p0, 1e-3), 0, 1)[..., None]
    d = np.array([int(dark[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255
    l = np.array([int(light[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255
    out = d + (l - d) * t
    out = out * (1 - keep) + rgb * keep * (out.mean() / max(rgb.mean(), 1e-3))
    out = np.clip(out, 0, 1)
    return Image.fromarray((np.concatenate([out, al], -1) * 255).astype(np.uint8), 'RGBA')

def darken(img, f=0.82, sat=0.85):
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255.0
    rgb = a[..., :3]
    g = rgb.mean(-1, keepdims=True)
    rgb = np.clip((g + (rgb - g) * sat) * f, 0, 1)
    return Image.fromarray((np.concatenate([rgb, a[..., 3:]], -1) * 255).astype(np.uint8), 'RGBA')

def autumn(img):
    a = np.asarray(img.convert('RGBA')).astype(np.float32) / 255.0
    rgb = a[..., :3]
    L = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    t = np.clip(L / max(np.percentile(L[a[..., 3] > 0.1], 98), 1e-3), 0, 1)[..., None]
    d = np.array([0x5a, 0x1e, 0x10], np.float32) / 255
    l = np.array([0xe0, 0x82, 0x2c], np.float32) / 255
    out = d + (l - d) * t
    return Image.fromarray((np.concatenate([np.clip(out, 0, 1), a[..., 3:]], -1) * 255).astype(np.uint8), 'RGBA')

def save_tex(src, dst_dir, name, fn=None, normal=False):
    im = Image.open(src)
    if fn:
        im = fn(im)
    if max(im.size) > MAX:
        im = im.resize((MAX, MAX * im.size[1] // im.size[0]) if im.size[0] >= im.size[1] else (MAX * im.size[0] // im.size[1], MAX), Image.LANCZOS)
    has_alpha = im.mode in ('RGBA', 'LA') and np.asarray(im.convert('RGBA'))[..., 3].min() < 250
    base = os.path.splitext(name)[0]
    if normal or has_alpha:
        out = base + '.png'
        (im.convert('RGBA') if has_alpha else im.convert('RGB')).save(os.path.join(dst_dir, out), optimize=True)
    else:
        out = base + '.jpg'
        im.convert('RGB').save(os.path.join(dst_dir, out), quality=88)
    return out

def curate(pack_src, names, dst, recolor, mat_rules=None, rename=None):
    os.makedirs(dst, exist_ok=True)
    done_tex = {}
    rename = rename or {}
    for n in names:
        src_name, out_name, tex_override = n, n, {}
        if n in rename:
            src_name, tex_override = rename[n]
        d = json.load(open(os.path.join(pack_src, src_name + '.gltf')))
        for b in d['buffers']:
            shutil.copy(os.path.join(pack_src, b['uri']), os.path.join(dst, b['uri']))
        used_as = {}
        for m in d.get('materials', []):
            pbr = m.get('pbrMetallicRoughness', {})
            if 'baseColorTexture' in pbr: used_as[pbr['baseColorTexture']['index']] = 'base'
            if 'normalTexture' in m: used_as[m['normalTexture']['index']] = 'normal'
        drop = set()
        for m in d.get('materials', []):
            pbr = m.setdefault('pbrMetallicRoughness', {})
            for k in ('metallicRoughnessTexture',):
                if k in pbr:
                    drop.add(d['textures'][pbr.pop(k)['index']]['source'])
            if 'occlusionTexture' in m:
                drop.add(d['textures'][m.pop('occlusionTexture')['index']]['source'])
            pbr['roughnessFactor'] = 0.9
            pbr['metallicFactor'] = 0.0
            name = m.get('name', '')
            if 'Metal' in name:
                pbr['roughnessFactor'] = 0.65
                pbr['metallicFactor'] = 0.35
            if 'Glass' in name:
                pbr.pop('baseColorTexture', None)
                pbr['baseColorFactor'] = [0.97, 0.70, 0.33, 1.0]
                m['emissiveFactor'] = [1.0, 0.62, 0.2]
                m.pop('alphaMode', None)
            if mat_rules and name in mat_rules:
                mat_rules[name](m)
        for ti, t in enumerate(d.get('textures', [])):
            img = d['images'][t['source']]
            if t['source'] in drop:
                continue
            uri = img['uri']
            role = used_as.get(ti, 'base')
            key = tex_override.get(uri, uri)
            fn = recolor.get(uri) if role == 'base' else None
            if key != uri:  # textura alternativa (ex.: outono)
                fn = tex_override['_fn']
            if key not in done_tex:
                done_tex[key] = save_tex(os.path.join(pack_src, uri), dst, key, fn, role == 'normal')
            img['uri'] = done_tex[key]
            img['mimeType'] = 'image/png' if done_tex[key].endswith('.png') else 'image/jpeg'
        # remove imagens/texturas descartadas mantendo indices (substitui por 1x1 nao referenciado)
        for i, img in enumerate(d.get('images', [])):
            if i in drop:
                img['uri'] = done_tex.setdefault('_px', _pixel(dst))
                img['mimeType'] = 'image/png'
        json.dump(d, open(os.path.join(dst, out_name + '.gltf'), 'w'))
    if '_px' in done_tex and not any(True for _ in []):
        pass
    print(dst, len(names), 'modelos')

def _pixel(dst):
    Image.new('RGB', (1, 1), (230, 230, 230)).save(os.path.join(dst, 'px.png'))
    return 'px.png'

# ---------------------------------------------------------------- vila medieval
QMV = DL + '/qmv/Medieval Village MegaKit[Standard]/glTF'
vila = """Wall_Plaster_Straight Wall_Plaster_Straight_Base Wall_Plaster_WoodGrid Wall_Plaster_Window_Wide_Round
Wall_Plaster_Window_Thin_Round Wall_Plaster_Door_Round Wall_UnevenBrick_Straight Wall_UnevenBrick_Door_Round
Wall_UnevenBrick_Window_Wide_Round Wall_UnevenBrick_Window_Thin_Round Corner_Exterior_Wood Corner_Exterior_Brick
Roof_RoundTiles_4x4 Roof_RoundTiles_4x6 Roof_RoundTiles_4x8 Roof_RoundTiles_6x6 Roof_RoundTiles_6x8 Roof_RoundTiles_6x10
Roof_RoundTiles_8x8 Roof_RoundTiles_8x10 Roof_Front_Brick4 Roof_Front_Brick6 Roof_Front_Brick8 Roof_Tower_RoundTiles
Prop_Chimney Prop_Chimney2 Prop_Vine1 Prop_Vine2 Prop_Vine4 Prop_Wagon Prop_WoodenFence_Single Prop_WoodenFence_Extension1
Prop_MetalFence_Ornament Prop_Crate Prop_ExteriorBorder_Straight1 Prop_ExteriorBorder_Corner Window_Wide_Round1
Window_Thin_Round1 WindowShutters_Wide_Round_Open WindowShutters_Thin_Round_Open Door_1_Round Door_2_Round
Floor_WoodDark Floor_Brick Balcony_Simple_Straight Overhang_Plaster_Long Prop_Support Stairs_Exterior_Straight""".split()
rc_vila = {
    'T_RoundTiles_BaseColor.png': lambda im: grad(im, '232a36', '7f91a3', 0.15),
    'T_Plaster_BaseColor.png': lambda im: grad(im, 'a8946f', 'e6d3ad', 0.2),
    'T_WoodTrim_BaseColor.png': lambda im: grad(im, '1f1710', '6a5440', 0.25),
    'T_UnevenBrick_BaseColor.png': lambda im: grad(im, '4a4945', 'a6a296', 0.25),
    'T_Brick_BaseColor.png': lambda im: grad(im, '4a4945', 'a6a296', 0.25),
    'T_RockTrim_BaseColor.png': lambda im: grad(im, '4f4e49', 'aaa69a', 0.25),
    'T_RedBrick_BaseColor.png': lambda im: grad(im, '4a4945', 'a6a296', 0.25),
}
curate(QMV, vila, REPO + '/art/models/quaternius_vila_medieval', rc_vila)

# ---------------------------------------------------------------- natureza
QN = DL + '/qn/glTF'
nat = """CommonTree_1 CommonTree_2 CommonTree_3 CommonTree_4 CommonTree_5 Pine_1 Pine_2 Pine_3 Pine_4 Pine_5
TwistedTree_1 TwistedTree_2 TwistedTree_3 DeadTree_1 DeadTree_2 Bush_Common Bush_Common_Flowers Fern_1
Flower_3_Group Flower_4_Group Plant_1 Plant_1_Big Plant_7 Plant_7_Big Rock_Medium_1 Rock_Medium_2 Rock_Medium_3
RockPath_Round_Wide RockPath_Round_Small_1 RockPath_Round_Small_2 RockPath_Round_Small_3 RockPath_Square_Wide
Mushroom_Common Clover_1 Grass_Common_Tall Grass_Wispy_Tall Pebble_Round_1 Pebble_Round_2
CommonTree_1_Outono CommonTree_3_Outono CommonTree_4_Outono Bush_Common_Outono""".split()
out_tex = {'Leaves_NormalTree_C.png': 'Leaves_NormalTree_Outono.png', '_fn': autumn}
out_bush = {'Leaves_TwistedTree_C.png': 'Leaves_TwistedTree_Outono.png', '_fn': autumn}
rn = {'CommonTree_1_Outono': ('CommonTree_1', out_tex), 'CommonTree_3_Outono': ('CommonTree_3', out_tex),
      'CommonTree_4_Outono': ('CommonTree_4', out_tex), 'Bush_Common_Outono': ('Bush_Common', out_bush)}
rc_nat = {'Bark_NormalTree.png': lambda im: darken(im, 0.8, 0.8), 'Rocks_Diffuse.png': lambda im: darken(im, 0.85, 0.6),
          'PathRocks_Diffuse.png': lambda im: darken(im, 0.85, 0.6), 'Bark_TwistedTree.png': lambda im: darken(im, 0.8, 0.8),
          'Bark_DeadTree.png': lambda im: darken(im, 0.8, 0.8)}
curate(QN, nat, REPO + '/art/models/quaternius_natureza', rc_nat, rename=rn)

# ---------------------------------------------------------------- props
QP = DL + '/qp/Exports/glTF'
props = """Barrel Barrel_Apples Barrel_Holder Crate_Wooden FarmCrate_Apple FarmCrate_Carrot FarmCrate_Empty Stall_Empty
Stall_Cart_Empty Banner_1 Banner_2 Bench Anvil Anvil_Log Workbench Lantern_Wall Torch_Metal Cauldron WeaponStand Dummy
Bucket_Wooden_1 Table_Large Stool Bag Pot_1 Vase_2 Chest_Wood Shield_Wooden Rope_1 Cage_Small""".split()
rc_props = {'T_Trim_Furniture_BaseColor.png': lambda im: darken(im, 0.85, 0.85),
            'T_Trim_Props_BaseColor.png': lambda im: darken(im, 0.88, 0.85),
            'T_Trim_Cloth_BaseColor.png': lambda im: darken(im, 0.9, 0.9)}
curate(QP, props, REPO + '/art/models/quaternius_props', rc_props)
