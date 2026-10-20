#!/usr/bin/env python3
"""Curadoria dos packs CC0 das Minas da Cinza (PROPOSTA).
Copia só as peças usadas, com as licenças originais, para art/models/* e art/materials/minas_da_cinza.
Uso: MINAS_DL=/workspace/dl_minas MINAS_REPO=. python3 tools/minas_da_cinza_curar_assets.py
Espera em MINAS_DL: kaykit/KayKit_Dungeon_Pack_1.1_FREE, kenney_mini-dungeon, kenney_train-kit,
kenney_survival-kit (zips extraídos) e as texturas Poly Haven *_1k.jpg."""
import os, shutil, json
from PIL import Image
DL = os.environ.get('MINAS_DL', '/workspace/dl_minas')
REPO = os.environ.get('MINAS_REPO', '.')
OUT = os.path.join(REPO, 'art/models')

KAYKIT = """torch_mounted torch_lit candle_lit candle_triple barrel_large barrel_small barrel_small_stack box_large box_small
crates_stacked keg rubble_large rubble_half pillar column stairs stairs_wood floor_dirt_large floor_dirt_large_rocky
floor_dirt_small_A floor_dirt_small_B floor_wood_large wall wall_broken wall_cracked wall_scaffold wall_open_scaffold
chest chest_gold shelf_small_candles table_small stool coin_stack_small keyring_hanging sword_shield_broken bed_floor
trunk_small_A""".split()
KENNEY = {
    'kenney_mini-dungeon': ('kenney_mini_dungeon', 'wood-support wood-structure rocks stones dirt gate column banner'.split()),
    'kenney_train-kit': ('kenney_train_kit', 'track-single track-single-detailed railroad-rail-straight railroad-rail-curve train-carriage-coal train-carriage-dirt'.split()),
    'kenney_survival-kit': ('kenney_survival_kit', 'tool-pickaxe tool-shovel bucket box-large rock-a rock-b rock-c resource-stone-large signpost workbench-anvil barrel-open'.split()),
}
POLYHAVEN = ['rock_wall_10', 'rocky_trail']

def main():
    kk = f'{DL}/kaykit/KayKit_Dungeon_Pack_1.1_FREE'
    dst = f'{OUT}/kaykit_dungeon'
    os.makedirs(dst, exist_ok=True)
    for n in KAYKIT:
        g = json.load(open(f'{kk}/Assets/gltf/{n}.gltf'))
        shutil.copy(f'{kk}/Assets/gltf/{n}.gltf', dst)
        for b in g['buffers']:
            shutil.copy(f'{kk}/Assets/gltf/{b["uri"]}', dst)
    # textura única do pack, reduzida para 512 (é um atlas de cores chapadas)
    Image.open(f'{kk}/Assets/gltf/dungeon_texture.png').convert('RGBA').resize((512, 512), Image.NEAREST).save(f'{dst}/dungeon_texture.png')
    shutil.copy(f'{kk}/License.txt', dst)
    print(dst, len(KAYKIT))
    for src, (pasta, nomes) in KENNEY.items():
        d = f'{OUT}/{pasta}'
        os.makedirs(d + '/Textures', exist_ok=True)
        for n in nomes:
            shutil.copy(f'{DL}/{src}/Models/GLB format/{n}.glb', d)
        shutil.copy(f'{DL}/{src}/Models/GLB format/Textures/colormap.png', d + '/Textures/')
        shutil.copy(f'{DL}/{src}/License.txt', d)
        print(d, len(nomes))
    ph = f'{REPO}/art/materials/minas_da_cinza'
    os.makedirs(ph, exist_ok=True)
    for a in POLYHAVEN:
        for t, tam in [('diff', 1024), ('nor_gl', 512)]:
            im = Image.open(f'{DL}/{a}_{t}_1k.jpg').convert('RGB').resize((tam, tam), Image.LANCZOS)
            im.save(f'{ph}/{a}_{t}.jpg', quality=88)
    print(ph, 'Poly Haven', POLYHAVEN)

if __name__ == '__main__':
    main()
