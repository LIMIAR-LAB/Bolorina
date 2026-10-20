#!/usr/bin/env python3
"""Curadoria dos assets CC0 da masmorra procedural (3 temas).

Fontes (todas CC0, baixadas para /workspace/dl_dungeon):
  * Quaternius (via poly.pizza, licença "Public Domain (CC0)"): Orc, Ghost, Ghost Skull
    (Ultimate Monsters), Zombie / Zombie Chubby (Ultimate Zombies), Robot Enemy, Robot Enemy
    Flying, Robot Enemy Large, Robot Enemy Legs Gun, Animated Robot.
  * KayKit Character Pack: Skeletons 1.0/1.1 (Kay Lousberg, CC0) - GitHub KayKit-Game-Assets.
  * Poly Haven metal_plate_02 (CC0) para o piso da Fenda Cronal (já baixado em dl_fut).
Uso: python3 tools/dungeon_curar_assets.py [raiz_do_projeto]
"""
import shutil, sys, os
RAIZ = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DL = "/workspace/dl_dungeon"
Q = {  # destino: origem
    "orc.glb": "q/orc.glb",
    "ghost.glb": "q/ghost.glb",
    "ghost_skull.glb": "q/ghost_skull.glb",
    "zombie.glb": "q/zombie_a.glb",
    "zombie_chubby.glb": "q/zombie_c.glb",
    "robot_enemy.glb": "q/robot_enemy.glb",
    "robot_legs_gun.glb": "q/robot_legs_gun.glb",
    "robot_flying.glb": "q/robot_flying.glb",
    "robot_large.glb": "q/robot_large.glb",
    "robot_humanoide.glb": "q/robot_anim.glb",
}
KK = ["Skeleton_Warrior.glb", "Skeleton_Rogue.glb", "Skeleton_Mage.glb", "Skeleton_Minion.glb", "skeleton_texture.png", "LICENSE.txt"]
KK_ARMAS = ["Skeleton_Blade", "Skeleton_Axe", "Skeleton_Crossbow", "Skeleton_Staff", "Skeleton_Shield_Small_A"]

def copiar(o, d):
    os.makedirs(os.path.dirname(d), exist_ok=True)
    shutil.copy2(o, d)
    print("  ", os.path.relpath(d, RAIZ), os.path.getsize(d) // 1024, "KB")

dq = os.path.join(RAIZ, "art/models/dungeon_quaternius")
for dst, src in Q.items():
    copiar(os.path.join(DL, src), os.path.join(dq, dst))
with open(os.path.join(dq, "LICENSE.txt"), "w") as f:
    f.write("Quaternius (quaternius.com) - modelos CC0 1.0 (Public Domain), baixados de poly.pizza.\n"
            "Ultimate Monsters (Orc, Ghost, Ghost Skull), Zombie (Ultimate Zombies), Robot Enemy pack,\n"
            "Animated Robot. https://creativecommons.org/publicdomain/zero/1.0/\n")
dk = os.path.join(RAIZ, "art/models/kaykit_skeletons")
for n in KK:
    copiar(os.path.join(DL, "kk", n), os.path.join(dk, n))
for n in KK_ARMAS:
    for ext in (".gltf", ".bin"):
        copiar(os.path.join(DL, "kk", n + ext), os.path.join(dk, n + ext))
dm = os.path.join(RAIZ, "art/materials/dungeon")
copiar("/workspace/dl_fut/metal_plate_02_diff_1k.jpg", os.path.join(dm, "metal_plate_02_diff.jpg"))
copiar("/workspace/dl_fut/metal_plate_02_nor_gl_1k.jpg", os.path.join(dm, "metal_plate_02_nor_gl.jpg"))
print("ok")
