#!/usr/bin/env python3
"""Gera os layouts JSON dos 3 mapas CC0 (formato de scripts/modular/vila_layout.json + extensoes):
  scripts/vila_grande/vila_grande_layout.json     Porto Velho (vila grande dos NPCs)
  scripts/vila_grande/vila_orcs_layout.json       Vila dos Orcs
  scripts/vila_grande/cidade_fantasma_layout.json Cidade Fantasma
Uso: python3 tools/vila_grande_layouts.py   (deterministico; sem dependencias alem de numpy)
"""
import json, math, os, random
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'vila_grande')
Q = 'quaternius_natureza/'
P = 'quaternius_props/'
V = 'quaternius_vila_medieval/'
K = 'kenney_fantasy_town/'

class Mapa:
    def __init__(self, ident, N, raio, seed, irregular=0.1):
        self.id = ident; self.N = N; self.o = -N // 2; self.R = raio
        self.rng = random.Random(seed)
        n = N + 1
        self.H = np.zeros((n, n)); self.T = np.full((n, n), 'g')
        self.ocup = np.zeros((n, n), bool)
        self.pecas, self.modelos, self.edificios, self.especiais = [], [], [], []
        self.casas_queimadas, self.lagos, self.marcadores = [], [], {}
        a1, a2, a3 = (self.rng.uniform(0, 6.28) for _ in range(3))
        self.borda_r = lambda t: raio * (1 + irregular * math.sin(3 * t + a1) + irregular * 0.6 * math.sin(5 * t + a2) + irregular * 0.35 * math.sin(9 * t + a3))
        for iz in range(n):
            for ix in range(n):
                x, z = ix + self.o, iz + self.o
                r = math.hypot(x, z); t = math.atan2(z, x)
                if r > self.borda_r(t):
                    self.H[iz, ix] = -30.0; self.T[iz, ix] = 'r'; self.ocup[iz, ix] = True
                else:
                    self.H[iz, ix] = 0.06 * math.sin(x * 0.37) * math.cos(z * 0.29) + 0.05 * math.sin(x * 0.11 + z * 0.13)
                    if r > self.borda_r(t) - 1.5:
                        self.H[iz, ix] -= 0.25
        self.borda = [[round(self.borda_r(t) * math.cos(t), 2), round(self.borda_r(t) * math.sin(t), 2)] for t in np.linspace(0, 2 * math.pi, 72, endpoint=False)]

    # ---- utilidades de grade
    def idx(self, x, z):
        return int(round(z)) - self.o, int(round(x)) - self.o
    def dentro(self, x, z, margem=0.0):
        r = math.hypot(x, z); return r < self.borda_r(math.atan2(z, x)) - margem
    def cells(self, cx, cz, rx, rz=None):
        rz = rx if rz is None else rz
        for z in range(int(math.floor(cz - rz)), int(math.ceil(cz + rz)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                iz, ix = z - self.o, x - self.o
                if 0 <= iz <= self.N and 0 <= ix <= self.N:
                    yield x, z, iz, ix
    def disco(self, cx, cz, r, tipo=None, ocupa=False, h=None):
        for x, z, iz, ix in self.cells(cx, cz, r):
            if math.hypot(x - cx, z - cz) <= r and self.H[iz, ix] > -20:
                if tipo: self.T[iz, ix] = tipo
                if ocupa: self.ocup[iz, ix] = True
                if h is not None: self.H[iz, ix] = h
    def retangulo(self, cx, cz, w, d, tipo=None, ocupa=True, h=0.0, margem=1.0):
        for x, z, iz, ix in self.cells(cx, cz, w / 2 + margem, d / 2 + margem):
            if self.H[iz, ix] < -20: continue
            if h is not None: self.H[iz, ix] = h
            if abs(x - cx) <= w / 2 + 0.5 and abs(z - cz) <= d / 2 + 0.5:
                if tipo: self.T[iz, ix] = tipo
                if ocupa: self.ocup[iz, ix] = True
            elif ocupa:
                self.ocup[iz, ix] = True
    def estrada(self, pts, largura, tipo='c', falhas=0.0):
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            L = math.hypot(bx - ax, bz - az); n = max(1, int(L * 2))
            for k in range(n + 1):
                x = ax + (bx - ax) * k / n; z = az + (bz - az) * k / n
                for cx, cz, iz, ix in self.cells(x, z, largura / 2):
                    if math.hypot(cx - x, cz - z) <= largura / 2 and self.H[iz, ix] > -20:
                        if falhas and self.rng.random() < falhas: continue
                        if self.T[iz, ix] != 'b': self.T[iz, ix] = tipo
                        self.ocup[iz, ix] = True
                        self.H[iz, ix] = min(self.H[iz, ix], 0.02) if self.H[iz, ix] < 0.3 else self.H[iz, ix]
    def colina(self, cx, cz, r, h):
        for x, z, iz, ix in self.cells(cx, cz, r):
            d = math.hypot(x - cx, z - cz)
            if d < r and self.H[iz, ix] > -20:
                t = 1 - d / r; self.H[iz, ix] += h * (t * t * (3 - 2 * t))
    def rio(self, pts, largura, nivel=-0.45):
        res = []
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            n = max(1, int(math.hypot(bx - ax, bz - az) / 0.5))
            res += [(ax + (bx - ax) * k / n, az + (bz - az) * k / n) for k in range(n)]
        res.append(pts[-1])
        # recorta o rio para dentro da ilha: nasce a 3 m da borda e termina exatamente na borda (cachoeira)
        dentro = [self.dentro(x, z, 0.4) for x, z in res]
        i0 = next(i for i, d in enumerate(dentro) if d and self.dentro(*res[i], 3.0))
        i1 = max(i for i, d in enumerate(dentro) if d)
        res = res[i0:i1 + 2]
        passo = max(1, len(res) // 8)
        pts = res[::passo]
        if pts[-1] != res[-1]: pts.append(res[-1])
        for x, z in res:
            for cx, cz, iz, ix in self.cells(x, z, largura / 2 + 2.0):
                d = math.hypot(cx - x, cz - z)
                if self.H[iz, ix] < -20: continue
                if d <= largura / 2 + 0.6:
                    self.H[iz, ix] = min(self.H[iz, ix], -1.0); self.T[iz, ix] = 'b'; self.ocup[iz, ix] = True
                elif d <= largura / 2 + 2.0:
                    self.H[iz, ix] = min(self.H[iz, ix], -0.35 * (1 - (d - largura / 2 - 0.6) / 1.4)); self.ocup[iz, ix] = True
                    if self.T[iz, ix] == 'g': self.T[iz, ix] = 'b'
        self.rio_dados = {"pontos": [[round(x, 2), round(z, 2)] for x, z in pts], "largura": largura, "nivel": nivel}
    def lago(self, cx, cz, r, achat=0.8):
        for x, z, iz, ix in self.cells(cx, cz, r + 2):
            d = math.hypot(x - cx, (z - cz) / achat)
            if self.H[iz, ix] < -20: continue
            if d <= r + 0.5: self.H[iz, ix] = -1.0; self.T[iz, ix] = 'b'; self.ocup[iz, ix] = True
            elif d <= r + 2: self.H[iz, ix] = min(self.H[iz, ix], -0.3); self.ocup[iz, ix] = True; self.T[iz, ix] = 'b' if self.T[iz, ix] == 'g' else self.T[iz, ix]
        self.lagos.append({"centro": [cx, cz], "raio": r + 0.9, "achatamento": achat, "nivel": -0.45})
    def livre(self, x, z, r=1.0, margem_borda=2.0):
        if not self.dentro(x, z, margem_borda): return False
        for cx, cz, iz, ix in self.cells(x, z, r):
            if math.hypot(cx - x, cz - z) <= r and self.ocup[iz, ix]: return False
        return True
    def marca(self, x, z, r):
        for cx, cz, iz, ix in self.cells(x, z, r):
            if math.hypot(cx - x, cz - z) <= r: self.ocup[iz, ix] = True

    # ---- objetos
    def peca(self, ident, x, z, rot=0, **kw):
        d = {"id": ident, "celula": [round(x, 2), round(z, 2)], "rot": rot}; d.update(kw); self.pecas.append(d)
    def modelo(self, m, x, z, ang=None, escala=1.0, **kw):
        d = {"m": m, "pos": [round(x, 2), round(z, 2)], "ang": round(self.rng.uniform(0, 360) if ang is None else ang, 1), "escala": round(escala, 3)}
        d.update(kw); self.modelos.append(d)
    def edificio(self, nome, x, z, ang, W, D, andares, terreo, superior, rotulo=None, **kw):
        d = {"nome": nome, "pos": [x, z], "ang": ang, "largura": W, "profundidade": D, "andares": andares, "terreo": terreo, "superior": superior}
        if rotulo: d["rotulo"] = rotulo
        d.update(kw); self.edificios.append(d)
        ww, dd = (W, D) if ang % 180 == 0 else (D, W)
        self.retangulo(x, z, ww + 0.6, dd + 0.6, tipo=None, h=0.0, margem=1.2)
    def casa_kit(self, x, z, rot, escala=1.0):
        self.peca("casa", x, z, rot, escala=escala)
        ww, dd = (6.4, 5.6) if rot % 2 == 0 else (5.6, 6.4)
        self.retangulo(x, z + (0.9 if rot == 0 else 0), ww * escala, dd * escala + 1.4, h=0.0, margem=1.0)
    def especial(self, tipo, x, z, ang=0, ocupa=0.0, **kw):
        d = {"tipo": tipo, "pos": [x, z], "ang": ang}; d.update(kw); self.especiais.append(d)
        if ocupa: self.marca(x, z, ocupa)
    def marcador(self, ident, x, z, papel, descricao, ang=0, y=None):
        self.marcadores[ident] = {"pos": [round(x, 2), round(z, 2)], "ang": ang, "papel": papel, "descricao": descricao}
        if y is not None: self.marcadores[ident]["y"] = y

    def espalhar(self, n, escolhas, raio, area=None, tentativas=20, escala=(0.8, 1.2), **kw):
        feitos = 0
        for _ in range(n * tentativas):
            if feitos >= n: break
            if area: x, z = area(self.rng)
            else:
                x = self.rng.uniform(self.o, -self.o); z = self.rng.uniform(self.o, -self.o)
            if not self.livre(x, z, raio): continue
            m = self.rng.choice(escolhas)
            if m.startswith('kit:'):
                self.peca(m[4:], x, z, self.rng.randint(0, 3), escala=round(self.rng.uniform(*escala), 2))
            else:
                self.modelo(m, x, z, escala=self.rng.uniform(*escala), **kw)
            self.marca(x, z, raio * 0.8); feitos += 1
        return feitos

    def salvar(self, extra):
        n = self.N + 1
        d = {"versao": "cc0_v1", "id": self.id, "grade_m": 1.0, "origem": [self.o, self.o], "tamanho": [n, n],
             "legenda_tipos": {"g": "grama", "c": "caminho de pedra", "t": "terra arada", "h": "terra batida", "b": "margem", "r": "rocha"},
             "camera": {"yaw": 45.0, "pitch": 35.264, "tamanho": 21.5, "alvo": [0, 0, 0]},
             "atores": {}, "rio": self.rio_dados,
             "alturas": [[round(float(v), 3) for v in row] for row in self.H],
             "tipos": [''.join(row) for row in self.T],
             "pecas": self.pecas, "modelos": self.modelos, "edificios": self.edificios, "especiais": self.especiais,
             "casas_queimadas": self.casas_queimadas, "lagos": self.lagos, "marcadores": self.marcadores, "borda": self.borda}
        d.update(extra)
        p = os.path.join(OUT, self.id + '_layout.json')
        json.dump(d, open(p, 'w'), ensure_ascii=False, separators=(',', ':'))
        arv = sum(1 for m in self.modelos if m.get('cat') == 'arvore') + sum(1 for q in self.pecas if q['id'].startswith('arvore'))
        print(f"{p}: pecas={len(self.pecas)} modelos={len(self.modelos)} edificios={len(self.edificios)} especiais={len(self.especiais)} "
              f"casas_kit={sum(1 for q in self.pecas if q['id']=='casa')} arvores~{arv} marcadores={len(self.marcadores)}")
        return d

ARV = [Q + f'CommonTree_{i}.gltf' for i in range(1, 6)] + [Q + 'CommonTree_1_Outono.gltf', Q + 'CommonTree_3_Outono.gltf', Q + 'CommonTree_4_Outono.gltf']
PIN = [Q + f'Pine_{i}.gltf' for i in range(1, 6)]
ARB = [Q + 'Bush_Common.gltf', Q + 'Bush_Common_Flowers.gltf', Q + 'Bush_Common_Outono.gltf', 'shrub_02/shrub_02_1k.gltf']
PED = [Q + 'Rock_Medium_1.gltf', Q + 'Rock_Medium_2.gltf', Q + 'Rock_Medium_3.gltf', 'boulder_01/boulder_01_1k.gltf']
FLO = [Q + 'Flower_3_Group.gltf', Q + 'Flower_4_Group.gltf', Q + 'Plant_1.gltf', Q + 'Fern_1.gltf', Q + 'Clover_1.gltf', Q + 'Grass_Wispy_Tall.gltf']

def anel_postes(m, pts, passo, lado=2.8, ident='poste_lampiao'):
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, bz - az); n = int(L // passo)
        nx, nz = -(bz - az) / L, (bx - ax) / L
        for k in range(1, n):
            s = 1 if k % 2 else -1
            x = ax + (bx - ax) * k / n + nx * lado * s; z = az + (bz - az) * k / n + nz * lado * s
            if m.livre(x, z, 0.4, 3):
                m.peca(ident, x, z, 0, ang=round(math.degrees(math.atan2(-nz * s, nx * s))))
                m.marca(x, z, 0.6)

# =====================================================================================
def porto_velho():
    m = Mapa('vila_grande', 128, 58, 2026)
    # rio (nasce ao norte, sai pela borda oeste em cachoeira) e lago das hortas
    m.rio([(-9, -66), (-11, -50), (-18, -38), (-31, -30), (-45, -22), (-66, -17)], 3.6)
    m.lago(-46, 38, 5.0, 0.75)
    m.colina(36, -38, 13, 3.2)                               # colina do Arquimago
    # praca central e estradas principais de pedra
    m.disco(0, 0, 11.5, 'c', True, 0.0)
    for pts in ([(0, -11), (0, -30), (1, -52)], [(0, 11), (0, 30), (-1, 54)], [(11, 0), (34, 0), (56, 0)], [(-11, 0), (-30, 0), (-53, 1)]):
        m.estrada(pts, 4.2, 'c')
    # caminhos de terra batida
    for pts in ([(-28, -42), (-27, -20), (-28, 0), (-27, 24), (-28, 46)], [(24, -24), (25, 0), (24, 24), (25, 44)],
                [(-46, 24), (-28, 24), (0, 24), (24, 24), (46, 23)], [(24, -24), (30, -30), (35, -33)], [(-27, -20), (-12, -20), (0, -20)]):
        m.estrada(pts, 3.0, 'h')
    # ponte onde o caminho oeste cruza o rio
    m.peca('ponte', -27.5, -31.5, 0); m.marca(-27.5, -31.5, 4)
    m.peca('ponte', -11.0, -49.0, 1); m.estrada([(-20, -49), (-1, -49)], 3.0, 'h')

    # --- construcoes de destaque (kit Quaternius recolorido)
    m.edificio('EstalagemDaLanterna', 14, -19, 0, 8, 10, 2, 'tijolo', 'enxaimel', 'Estalagem da Lanterna', trepadeira=True, janelas_fundo=True)
    m.edificio('BoticaDaMira', -18, -13, 90, 6, 6, 2, 'reboco', 'enxaimel', 'Botica da Mira', trepadeira=True)
    m.edificio('PostoDaGuarda', 35, -9, 0, 6, 8, 2, 'tijolo', 'reboco', 'Posto da Guarda')
    m.edificio('FerrariaDoPorto', -38, -9, 0, 6, 8, 1, 'tijolo', 'reboco', 'Ferraria do Porto')
    m.edificio('CeleiroDasSementes', -40, 14, 90, 8, 10, 1, 'reboco', 'reboco', 'Celeiro das Sementes', porta_lateral=True)
    m.edificio('CasaGrandeDoPorto', 17, 16, 0, 6, 8, 2, 'reboco', 'enxaimel', None, trepadeira=True)
    m.edificio('CasaDoSineiro', -15, 16, 0, 4, 6, 2, 'tijolo', 'enxaimel')
    m.edificio('CasaDaCosta', 44, 16, 270, 4, 6, 2, 'reboco', 'enxaimel')
    m.edificio('ArmazemDaDoca', 46, -8, 0, 6, 6, 1, 'tijolo', 'reboco', 'Armazém da Doca')
    # --- casas do kit (scripts/modular/kit_modular.gd "casa"), rotacoes/escala variadas
    casas = [(8, 18, 0, 1.0), (32, 17, 0, 0.9), (8, 32, 0, 0.95), (15, 32, 0, 0.9), (33, 32, 0, 1.0), (41, 31, 3, 0.9),
             (10, 43, 1, 0.9), (36, 43, 0, 0.85), (-7, -28, 1, 0.9), (-7, -39, 1, 0.95), (8, -30, 3, 0.9), (8, -41, 3, 1.0),
             (16, -46, 0, 0.85), (-16, 31, 0, 0.9), (-16, 42, 1, 0.85)]
    for x, z, r, e in casas:
        m.casa_kit(x, z, r, e)

    # --- especiais
    m.especial('torre_arquimago', 36, -38, 0, ocupa=5, y=3.2, rotulo='Torre do Arquimago', altura_placa=17)
    m.retangulo(36, -38, 7, 7, h=None, ocupa=True)
    m.especial('doca', 51, 0, 0, comprimento=18, largura=7, y=0.0, rotulo='Doca de Dirigíveis', altura_placa=4)
    m.especial('dirigivel', 71, 7.5, 90, y=-1.5)
    m.especial('quadro_missoes', 31, -2.6, 0, ocupa=1.5, rotulo='Mural de Pedidos', altura_placa=3.2)
    # praca: chafariz Kenney (escalado), poco do kit, barracas, estandartes, bancos
    m.modelo(K + 'fountain-round-detail.glb', 0, 0, 0, 3.2, col='rocha', tinta='c9c3b4')
    m.peca('poco', -7.5, 6.5, 0)
    barracas = [P + 'Stall_Empty.gltf', P + 'Stall_Cart_Empty.gltf', K + 'stall-red.glb', K + 'stall-green.glb']
    for i in range(10):
        a = math.radians(i * 36 + 18); r = 8.6
        if i in (2, 7): continue
        x, z = math.cos(a) * r, math.sin(a) * r
        b = barracas[i % 4]
        esc = 3.0 if b.startswith(K) else 1.2
        m.modelo(b, x, z, (90 - math.degrees(a)) % 360 + 180, esc, col='caixa', cx=2.0, cy=2.0, cz=1.2, tinta='d8cfc0' if b.startswith(K) else 'ffffff')
        for k in range(2):
            m.modelo(m.rng.choice([P + 'Barrel.gltf', P + 'Barrel_Apples.gltf', P + 'Crate_Wooden.gltf', P + 'FarmCrate_Apple.gltf', P + 'FarmCrate_Carrot.gltf']),
                     x + math.cos(a + 0.5 + k) * 1.6, z + math.sin(a + 0.5 + k) * 1.6, None, 1.0)
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        m.peca('estandarte', math.cos(r) * 11, math.sin(r) * 11, 0, ang=a)
    for a in (0, 90, 180, 270):
        r = math.radians(a + 20)
        m.modelo(P + 'Bench.gltf', math.cos(r) * 5.5, math.sin(r) * 5.5, -a + 90, 0.9)
    m.peca('carroca_abobora', 6, -6.5, 1)
    m.peca('menir_runa', -5.5, -6, 0)
    # postes de lampiao ao longo das estradas
    for pts in ([(0, -12), (0, -52)], [(0, 12), (0, 54)], [(12, 0), (52, 0)], [(-12, 0), (-52, 0)]):
        anel_postes(m, pts, 9, 2.9)
    # mercado/oficios: props tematicos
    for (x, z) in [(-33, -3.5), (-35, -3), (-31.5, -4)]:
        pass
    m.modelo(P + 'Anvil_Log.gltf', -34, -3.6, 20, 1.2); m.modelo(P + 'Workbench.gltf', -41.5, -3.4, 0, 1.0)
    m.peca('pilar_braseiro', -36.5, -3.2, 0); m.modelo(P + 'WeaponStand.gltf', -42.5, -6, 90, 1.0)
    m.modelo(P + 'Barrel_Holder.gltf', 18.5, -12.8, 0, 1.0); m.modelo(P + 'Table_Large.gltf', 10, -12.5, 0, 0.9)
    for x in (8.5, 11.5): m.modelo(P + 'Stool.gltf', x, -11.6, None, 1.0)
    m.modelo(P + 'Cauldron.gltf', -13.5, -9, 0, 1.0); m.modelo(P + 'Vase_2.gltf', -13.6, -16.5, 0, 1.0)
    m.modelo(P + 'Dummy.gltf', 39.5, -3.6, 200, 1.0); m.modelo(P + 'Dummy.gltf', 41.2, -3.8, 160, 1.0)
    m.modelo(P + 'Chest_Wood.gltf', 44, -3.5, 0, 1.0)
    for i in range(10):
        m.modelo(m.rng.choice([P + 'Crate_Wooden.gltf', P + 'Barrel.gltf', V + 'Prop_Crate.gltf']), 51 + m.rng.uniform(1, 15), m.rng.choice([-2.6, 2.6]) + m.rng.uniform(-0.3, 0.3), None, 0.9, y=0.18)
    m.modelo(V + 'Prop_Wagon.gltf', 28, 4.5, 90, 1.0, col='caixa', cx=2, cy=1.5, cz=4)
    m.modelo(K + 'cart-high.glb', -24, 4, 30, 2.4, tinta='cfc5b5')
    # hortas: canteiros, cercas, moinho Kenney, roda d'agua
    for i in range(6):
        for j in range(8):
            x, z = -38 + i * 1.2, 27 + j * 1.1
            m.peca('canteiro', x, z, 0, cultura='abobora' if (i + j) % 3 else 'couve', estagio=1 + (i * j) % 3)
            m.T[m.idx(x, z)] = 't'; m.ocup[m.idx(x, z)] = True
    for x0, z0, x1, z1 in [(-39.5, 25.5, -31.5, 25.5), (-39.5, 25.5, -39.5, 36.5), (-31.5, 25.5, -31.5, 36.5)]:
        n = int(max(abs(x1 - x0), abs(z1 - z0)))
        for k in range(n):
            x = x0 + (x1 - x0) * k / n; z = z0 + (z1 - z0) * k / n
            m.peca('cerca', x, z, 0, de=[x, z], ate=[x + (x1 - x0) / n, z + (z1 - z0) / n])
    m.modelo(K + 'windmill.glb', -52, 26, 60, 4.0, dy=6.2, col='caixa', cx=3, cy=6, cz=3, tinta='d9cfbf'); m.marca(-52, 26, 3)
    m.modelo(K + 'watermill.glb', -36.5, -26.4, 70, 3.0, dy=2.6, tinta='d9cfbf')
    m.modelo(P + 'FarmCrate_Carrot.gltf', -30.2, 30, 0, 1.0); m.modelo(P + 'Bucket_Wooden_1.gltf', -30.4, 31.2, 0, 1.2)
    # pomar (fileiras de macieiras) a sudoeste da estrada sul
    for i in range(4):
        for j in range(3):
            x, z = -22 + i * 5.0, 30 + j * 5.5
            if m.livre(x, z, 1.5):
                m.modelo(m.rng.choice(ARV[:5]), x, z, None, 0.62, col='tronco', cat='arvore'); m.marca(x, z, 2)
    # torre: caminho em degraus e luzes
    m.modelo(P + 'Lantern_Wall.gltf', 33, -33, 0, 1.0, y=2.4)
    # vegetacao: borda de floresta, bosques, arbustos, pedras, flores
    borda_flor = lambda r: (lambda a, rr: (math.cos(a) * rr, math.sin(a) * rr))(r.uniform(0, 6.283), r.uniform(44, 58))
    m.espalhar(230, ARV + PIN + PIN + ['kit:arvore_escura', 'kit:arvore_outono'], 2.0, borda_flor, tentativas=60, escala=(0.75, 1.15), col='tronco', cat='arvore')
    m.espalhar(90, ARV + ['kit:arvore_outono', 'kit:arvore_escura'], 2.2, None, tentativas=60, escala=(0.65, 1.0), col='tronco', cat='arvore')
    m.espalhar(110, ARB + ['kit:arbusto_flor', 'kit:arbusto_escuro'], 1.0, None, escala=(0.6, 1.0))
    m.espalhar(40, PED + ['kit:rocha'], 1.2, None, escala=(0.4, 0.8))
    m.espalhar(170, FLO, 0.6, None, escala=(0.4, 0.7))
    m.espalhar(6, ['island_tree_02/island_tree_02_optimized.glb'], 3.0, borda_flor, escala=(1.0, 1.0), col='tronco', cat='arvore')
    for mm in m.modelos:
        if mm['m'].startswith('island_tree_02'): mm['escala'] = 1.0; mm['nota'] = 'altura ~ escala do glb'
    # marcadores (spawn + NPCs)
    m.marcador('spawn_jogador', 0, 14, 'spawn', 'Chegada pela estrada sul, de frente para a praca', 180)
    m.marcador('spawn_doca', 50, 0, 'spawn', 'Desembarque na doca de dirigiveis', 270)
    for ident, x, z, papel, desc in [
        ('mira', -13.5, -12, 'herbalista', 'Botica da Mira, balcao da frente'),
        ('jardineira', -32.5, 31, 'horticultora', 'Hortas junto ao Celeiro das Sementes'),
        ('guardia', 33, -3.5, 'guarda', 'Mural de pedidos do Posto da Guarda'),
        ('sineiro', -15, 20.5, 'sineiro', 'Porta da Casa do Sineiro'),
        ('ferreiro', -35, -2.5, 'ferreiro', 'Bigorna da Ferraria do Porto'),
        ('estalajadeira', 13, -12.5, 'estalajadeira', 'Mesa em frente a Estalagem da Lanterna'),
        ('arquimago', 36, -33, 'arquimago', 'Porta da Torre do Arquimago'),
        ('capitao', 62, 1.5, 'comerciante', 'Ponta da doca, ao lado do dirigivel'),
        ('mercador_praca', 6.5, 5.5, 'comerciante', 'Barracas da praca central'),
        ('morador_1', 9, 22, 'morador', 'Frente das casas do bairro sul'),
        ('morador_2', -4.5, -33, 'morador', 'Rua norte, perto da ponte'),
        ('crianca_praca', -3, 3, 'morador', 'Brincando perto do chafariz'),
        ('gato', 2.5, -4, 'animal', 'Gato da praca'),
        ('dragao', 54.5, -2.6, 'guardiao_rota', 'Entrada da doca de dirigiveis, lado da Rota do Ambar (cobra pedagio de quem embarca)')]:
        m.marcador(ident, x, z, papel, desc, y=0.25 if x > 52 else None)
    ilhas = [[-150, -12, -140, True], [-60, -14, -190, False], [60, -10, -200, True], [170, -16, -110, False], [-190, -18, 40, False], [150, -12, 120, True], [20, -20, 210, False]]
    return m.salvar({"nome_no": "VilaGrandePortoVelho", "ilhas_distantes": ilhas,
        "tema": {"hora": 16.6, "sol_elevacao": 40, "nevoa_volumetrica": 0.0004, "tom_grama": "6b8636", "tufos": ["3f5f22", "8a9b38"], "flores": ["ece2b6", "9a86c8", "e3b43a", "c2452c"]},
        "capturas": [{"nome": "praca", "alvo": [2, 2], "tamanho": 26},
                     {"nome": "estalagem_e_torre", "alvo": [22, -24], "tamanho": 30},
                     {"nome": "hortas_e_oficios", "alvo": [-34, 10], "tamanho": 32},
                     {"nome": "doca", "alvo": [52, 0], "tamanho": 30},
                     {"nome": "visao_geral", "alvo": [0, 0], "tamanho": 150}]})

# =====================================================================================
def vila_orcs():
    m = Mapa('vila_orcs', 100, 44, 666, 0.13)
    m.rio([(30, -52), (26, -36), (32, -24), (40, -14), (52, -10)], 2.6)
    m.colina(-26, -24, 10, 2.0)
    m.disco(0, 0, 9, 'h', True, 0.0)
    for pts in ([(0, 9), (0, 30), (2, 46)], [(9, 0), (29, 0), (46, 3)], [(0, -9), (0, -14)], [(-9, 0), (-20, 0)]):
        m.estrada(pts, 3.4, 'h')
    m.peca('ponte', 33.5, -21.0, 1)
    m.especial('palicada', 0, 0, 0, raio=29, portoes=[90, 0])
    for t in np.linspace(0, 2 * math.pi, 120, endpoint=False):
        m.marca(math.cos(t) * 29, math.sin(t) * 29, 1.2)
    m.especial('fogueira', 0, 0, 0, ocupa=2.0, escala=1.6, rotulo='Fogueira do Conselho', altura_placa=3.5)
    for a in range(4):
        r = math.radians(a * 90 + 45)
        m.especial('totem', math.cos(r) * 6, math.sin(r) * 6, -a * 90, ocupa=1.0, altura=4.5)
    m.especial('salao_guerra', 0, -19, 0, ocupa=0, largura=10, comprimento=14, rotulo='Salão de Guerra', altura_placa=9)
    m.retangulo(0, -19, 11, 16, h=0.0)
    cab = [(-16, -10, 2.8), (-20, 2, 2.4), (-16, 14, 2.6), (-6, 19, 2.4), (14, 15, 2.8), (19, 4, 2.4), (16, -10, 2.6), (-22, -18, 2.2), (21, -18, 2.4), (8, 23, 2.2), (-12, 23, 2.0)]
    for i, (x, z, r) in enumerate(cab):
        ang = math.degrees(math.atan2(x, z)) + 180  # porta (+z local) voltada para o centro
        m.especial('cabana_orc', x, z, ang, ocupa=r + 0.8, raio=r, altura=2.0 + r * 0.15)
        m.disco(x, z, r + 1, 'h', True, 0.0)
    # campo de treino e forja
    m.modelo(P + 'Dummy.gltf', 12, -2.5, 0, 1.3, tinta='b07a5a'); m.modelo(P + 'Dummy.gltf', 13.5, -4.5, 30, 1.3, tinta='b07a5a')
    m.modelo(P + 'WeaponStand.gltf', 10.5, -5.8, 10, 1.2, tinta='9a6a50'); m.modelo(P + 'Shield_Wooden.gltf', 9.5, -5.8, 0, 1.4, y=1.0)
    m.modelo(P + 'Anvil_Log.gltf', -9, -8, 0, 1.3, tinta='9a6a50'); m.especial('fogueira', -11, -10, 0, ocupa=1.5, escala=0.9)
    m.modelo(P + 'Cauldron.gltf', -4.5, 7.5, 0, 1.3); m.modelo(P + 'Cage_Small.gltf', 6, 8, 20, 1.6)
    for x, z in [(-10, 10), (10, 10), (0, 25), (25, 0)]:
        m.peca('pilar_braseiro', x, z, 0)
    for i in range(14):
        m.modelo(m.rng.choice([P + 'Barrel.gltf', P + 'Crate_Wooden.gltf', P + 'Bag.gltf', P + 'Rope_1.gltf', 'tree_stump_01/tree_stump_01_1k.gltf']),
                 m.rng.uniform(-22, 22), m.rng.uniform(-22, 22), None, 1.0, tinta='b8896a')
    for x, z in [(0, 33), (33, 0), (-33, -10), (-10, -33), (20, 27)]:
        m.especial('totem', x, z, m.rng.uniform(0, 360), ocupa=1.0, altura=3.5)
    # floresta selvagem fora da palicada
    fora = lambda r: (lambda a, rr: (math.cos(a) * rr, math.sin(a) * rr))(r.uniform(0, 6.283), r.uniform(32, 44))
    m.espalhar(110, PIN + [Q + 'TwistedTree_1.gltf', Q + 'DeadTree_1.gltf', Q + 'DeadTree_2.gltf', 'kit:arvore_seca', 'kit:arvore_outono'] + ARV[5:], 2.6, fora, escala=(0.7, 1.1), col='tronco', cat='arvore', tinta='e8c8a8')
    for mm in m.modelos:
        if 'TwistedTree' in mm['m']: mm['escala'] = round(mm['escala'] * 0.45, 3)
    m.espalhar(40, PED + ['rock_moss_set_01/rock_moss_set_01_1k.gltf'], 1.6, fora, escala=(0.6, 1.1), tinta='d0a080')
    m.espalhar(60, ARB + [Q + 'Grass_Wispy_Tall.gltf', Q + 'Fern_1.gltf'], 0.9, None, escala=(0.5, 0.9), tinta='d8b080')
    for mm in m.modelos:
        if 'Fern_1' in mm['m']: mm['escala'] = round(mm['escala'] * 0.25, 3)
    m.marcador('spawn_jogador', 0, 38, 'spawn', 'Portao sul da palicada (chegada pela trilha)', 180)
    m.marcador('spawn_portao_leste', 38, 1, 'spawn', 'Portao leste', 270)
    for ident, x, z, papel, desc in [
        ('lider_orc', 0, -10.5, 'lider', 'Diante do Salao de Guerra'),
        ('xama_orc', -4, 6, 'xama', 'Caldeirao ao lado da fogueira do conselho'),
        ('ferreiro_orc', -8, -6.5, 'ferreiro', 'Bigorna e forja improvisada'),
        ('guerreiro_orc_1', 11.5, -1, 'guerreiro', 'Campo de treino'),
        ('guerreiro_orc_2', 3, 30, 'sentinela', 'Torre de vigia do portao sul'),
        ('cacadora_orc', 18, 7, 'cacadora', 'Entre as cabanas a leste'),
        ('anciao_orc', 5, 3, 'anciao', 'Junto a fogueira do conselho'),
        ('prisioneiro', 6, 9.5, 'prisioneiro', 'Jaula perto da fogueira (missao de resgate)')]:
        m.marcador(ident, x, z, papel, desc)
    ilhas = [[-140, -14, -120, False], [120, -12, -150, True], [160, -16, 60, False], [-120, -18, 140, False]]
    return m.salvar({"nome_no": "VilaDosOrcs", "ilhas_distantes": ilhas, "sem_placas": False,
        "tema": {"hora": 17.5, "tom_grama": "8a7a3a", "tom_terra": "8a4a2a", "tom_pedra": "a06a44", "tom_rocha": "7a5a48",
                 "tufos": ["6a5a22", "a8853a"], "flores": ["c2452c", "e0a040"], "folhas_chao": ["8a3a18", "b05a20", "6a2a14", "c08a3a"],
                 "materiais": {"wood": "4a2a1c", "brown_planks_03": "8a5a3a", "castle_brick_01": "9a6e58", "lichen_rock": "a07a64", "kit_palha": "a0703c", "grey_roof_tiles": "6a4a3a"},
                 "sol_cor": "ffa060", "sol_energia": 1.6, "ambiente": "9a7a70", "ambiente_energia": 0.6,
                 "ceu": ["5a3a4a", "e08a4a", "6a4a3a"], "nevoa_cor": "c09070", "nevoa_densidade": 0.0005, "nevoa_volumetrica": 0.0007,
                 "nevoa_abismo": ["6a4a40", "9a6a50", "c09070"], "rocha_base": "8a6050", "agua_raso": "4a3a24", "agua_fundo": "1a1208",
                 "lajes": "b08060", "cinzas": {"quantidade": 900, "cor": "ff7a2a", "emissao": 2.0}, "saturacao": 1.05},
        "capturas": [{"nome": "fogueira_e_salao", "alvo": [0, -6], "tamanho": 28},
                     {"nome": "cabanas_portao_sul", "alvo": [-4, 18], "tamanho": 28},
                     {"nome": "visao_geral", "alvo": [0, 0], "tamanho": 115}]})

# =====================================================================================
def cidade_fantasma():
    m = Mapa('cidade_fantasma', 110, 48, 1313, 0.09)
    m.rio([(-56, 30), (-40, 26), (-26, 30), (-10, 38), (4, 46), (8, 60)], 3.0)
    m.disco(0, 0, 10, 'c', True, 0.0)
    for pts in ([(0, -10), (0, -40)], [(0, 10), (0, 30)], [(10, 0), (44, 0)], [(-10, 0), (-44, 0)], [(-24, -22), (24, -22)], [(-24, 16), (26, 16)]):
        m.estrada(pts, 4.0, 'c', falhas=0.18)
    m.peca('ponte', -8.5, 36, 1, escala=1.0)
    m.estrada([(0, 30), (-6, 34), (-10, 40)], 3, 'h', falhas=0.2)
    # capela em ruinas ao norte, cemiterio a nordeste
    m.especial('capela_ruina', 0, -34, 0, ocupa=0, rotulo='Capela do Relógio Partido', altura_placa=9)
    m.retangulo(0, -35, 9, 22, h=0.0)
    for i in range(7):
        for j in range(6):
            x, z = 20 + i * 2.2 + m.rng.uniform(-0.3, 0.3), -40 + j * 2.6 + m.rng.uniform(-0.3, 0.3)
            if m.livre(x, z, 0.5, 3):
                m.especial('lapide', x, z, m.rng.uniform(-20, 20), ocupa=0.8, variante=m.rng.randint(0, 2))
    for k in range(10):
        m.modelo(V + 'Prop_MetalFence_Ornament.gltf', 19 + k * 2, -44, 0, 0.7, tinta='6a6070')
        m.modelo(V + 'Prop_MetalFence_Ornament.gltf', 19 + k * 2, -24, 0, 0.7, tinta='6a6070')
    for k in range(10):
        if k in (4, 5): continue
        m.modelo(V + 'Prop_MetalFence_Ornament.gltf', 18, -43 + k * 2, 90, 0.7, tinta='6a6070')
        m.modelo(V + 'Prop_MetalFence_Ornament.gltf', 38, -43 + k * 2, 90, 0.7, tinta='6a6070')
    m.retangulo(28, -34, 21, 21, h=0.0, ocupa=False)
    # mansao da condessa (intacta, sombria) a oeste
    m.edificio('MansaoDaCondessa', -30, -8, 90, 8, 10, 2, 'tijolo', 'reboco', 'Mansão da Condessa', tinta='8a7f96', trepadeira=True, janelas_fundo=True)
    for k in range(6):
        m.modelo(V + 'Prop_MetalFence_Ornament.gltf', -23, -16 + k * 2.0 + (4 if k > 2 else 0), 90, 0.8, tinta='5a5068')
    # casas Quaternius queimadas (ruina) + casas do kit em esqueleto queimado
    ru = [(-16, -14, 0, 6, 8), (16, -12, 0, 6, 6), (-18, 24, 0, 4, 6), (18, 26, 270, 6, 6), (34, 10, 0, 4, 6), (-38, 12, 90, 6, 6), (32, -8, 0, 4, 4), (-8, -50, 0, 4, 6)]
    for i, (x, z, a, W, D) in enumerate(ru):
        m.edificio(f'RuinaQueimada{i+1}', x, z, a, W, D, 2 if i % 2 == 0 else 1, 'reboco' if i % 3 else 'tijolo', 'enxaimel', None, ruina=True, tinta='4a4450')
    for x, z, a, e in [(-10, 22, 0, 1.0), (8, 24, 0, 0.9), (-28, 6, 90, 1.0), (26, -2, 270, 0.9), (-14, -26, 90, 0.9), (12, -28, 270, 1.0), (42, -16, 0, 0.85), (-40, -26, 0, 0.9)]:
        m.casas_queimadas.append({"pos": [x, z], "ang": a, "escala": e}); m.retangulo(x, z, 6.4 * e, 5.6 * e, h=0.0)
    # praca: chafariz seco, estatua quebrada, arcos e pilares em ruina
    m.modelo(K + 'fountain-round-detail.glb', 0, 0, 0, 3.0, col='rocha', tinta='6a6676')
    m.peca('pilar_pedra', 0, 0.2, 0, escala=0.7)
    for x, z, a in [(-8, -6, 0), (8, 6, 90)]:
        m.peca('ruina_pilar', x, z, 0)
    for x, z, r in [(0, -14, 0), (-22, -2, 1), (22, 4, 1)]:
        m.peca('ruina_arco', x, z, r, fundo=0.4)
    for x, z in [(5, 5), (-5, 5), (5, -5), (-5, -5), (0, 12), (0, -18), (12, 0), (-12, 0), (-24, -18), (24, 16), (10, -40), (30, -20), (-20, 30)]:
        m.especial('lanterna_espectral', x, z, m.rng.uniform(0, 360), ocupa=0.6)
    m.modelo(V + 'Prop_Wagon.gltf', 6, 13, 120, 1.0, tinta='4a4450'); m.modelo(P + 'Stall_Empty.gltf', -6, 13, 200, 1.1, tinta='5a5464')
    for i in range(16):
        m.modelo(m.rng.choice([P + 'Barrel.gltf', P + 'Crate_Wooden.gltf', P + 'Vase_2.gltf', P + 'Chest_Wood.gltf', V + 'Prop_Crate.gltf']),
                 m.rng.uniform(-30, 30), m.rng.uniform(-30, 30), None, 1.0, tinta='5a5464')
    # arvores mortas, pedras e arbustos secos
    m.espalhar(90, [Q + 'DeadTree_1.gltf', Q + 'DeadTree_2.gltf', 'kit:arvore_seca', 'kit:arvore_seca', Q + 'TwistedTree_2.gltf'], 2.4, None, escala=(0.55, 0.9), col='tronco', cat='arvore', tinta='6a6070')
    for mm in m.modelos:
        if 'TwistedTree' in mm['m']: mm['escala'] = round(mm['escala'] * 0.45, 3)
    m.espalhar(40, PED + ['tree_stump_01/tree_stump_01_1k.gltf'], 1.3, None, escala=(0.5, 0.9), tinta='7a7488')
    m.espalhar(50, ['kit:arbusto_escuro', Q + 'Grass_Wispy_Tall.gltf', Q + 'Mushroom_Common.gltf'], 0.9, None, escala=(0.5, 0.9), tinta='7a7088')
    m.marcador('spawn_jogador', 0, 26, 'spawn', 'Entrada sul da antiga capital', 180)
    for ident, x, z, papel, desc in [
        ('condessa', -24, -8, 'condessa', 'Escadaria da Mansao da Condessa (mercado noturno de reliquias)'),
        ('espectro_sineiro', 0, -22, 'espectro', 'Portal da Capela do Relogio Partido'),
        ('eco_arquimago', 0, -40, 'eco', 'Altar da capela (versao alternativa do Arquimago)'),
        ('mercador_reliquias', -6, 11, 'comerciante', 'Barraca abandonada na praca'),
        ('coveiro', 22, -27, 'coveiro', 'Portao do cemiterio'),
        ('lobisomem', -19, 30, 'eremita', 'Margem do rio, a montante da ponte'),
        ('vampiro_menor_1', 14, -7.5, 'inimigo', 'Diante das ruinas a leste (patrulha noturna)'),
        ('espectro_1', -16, -8.5, 'inimigo', 'Porta da ruina queimada a oeste')]:
        m.marcador(ident, x, z, papel, desc)
    ilhas = [[-150, -10, -130, True], [140, -14, -140, True], [170, -18, 60, False], [-160, -16, 90, True]]
    return m.salvar({"nome_no": "CidadeFantasma", "ilhas_distantes": ilhas,
        "tema": {"hora": 21.3, "tom_grama": "4a4a50", "tom_terra": "3a3438", "tom_pedra": "7a7480", "tom_rocha": "5a5664",
                 "tufos": ["2a2a30", "5a5868"], "flores": ["8a7ab0", "b8b0c8"], "folhas_chao": ["3a3440", "5a5060", "6a6474", "2a2630"],
                 "densidade_tufos": 0.7, "materiais": {"wood": "2a2228", "brown_planks_03": "5a5060", "castle_brick_01": "7a7488", "plastered_stone_wall": "8a8298", "grey_roof_tiles": "3a3448", "lichen_rock": "7a7488"},
                 "tinta_queimado": "4a4450", "sol_energia": 0.0, "lua_energia": 1.5, "lua_cor": "9a90f0", "ambiente": "7a74b8", "ambiente_energia": 1.1,
                 "ceu": ["0a0a1e", "3a2a5a", "1a1830"], "nevoa_cor": "6a5a9a", "nevoa_densidade": 0.0025, "nevoa_volumetrica": 0.005,
                 "nevoa_abismo": ["1a1830", "2a2448", "4a3a6a"], "rocha_base": "4a4658", "agua_raso": "1a1a30", "agua_fundo": "05050c",
                 "lajes": "8a8498", "cinzas": {"quantidade": 2200, "cor": "b9b4c4"}, "saturacao": 0.8, "raios_sol": False,
                 "cor_janelas": "8c7bff", "brilho_janelas": 1.2, "energia_luzes": 2.2,
                 "bruma_local": [[0, -34, 30, 6, 0.012], [28, -34, 26, 5, 0.015], [0, 0, 40, 4, 0.006]]},
        "capturas": [{"nome": "praca_e_ruinas", "alvo": [0, 2], "tamanho": 28},
                     {"nome": "capela_e_cemiterio", "alvo": [14, -32], "tamanho": 32},
                     {"nome": "visao_geral", "alvo": [0, 0], "tamanho": 120}]})

if __name__ == '__main__':
    porto_velho(); vila_orcs(); cidade_fantasma()
