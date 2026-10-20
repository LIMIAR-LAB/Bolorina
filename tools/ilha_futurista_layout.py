#!/usr/bin/env python3
"""Gera scripts/ilha_futurista/ilha_futurista_layout.json: Estação Depois-de-Ontem (PROPOSTA, não é canon).
Reaproveita a classe Mapa de tools/vila_grande_layouts.py (mesmo formato JSON lido por mapa_cc0.gd)
e acrescenta a lista "fut" (estruturas de ficção científica montadas por scripts/ilha_futurista/ilha_futurista.gd).
Uso: python3 tools/ilha_futurista_layout.py   (determinístico)
"""
import importlib.util, json, math, os
AQUI = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('vgl', os.path.join(AQUI, 'vila_grande_layouts.py'))
vgl = importlib.util.module_from_spec(spec); spec.loader.exec_module(vgl)
vgl.OUT = os.path.join(AQUI, '..', 'scripts', 'ilha_futurista')
Mapa = vgl.Mapa
Q = vgl.Q
KS = 'kenney_space_kit/'; KT = 'kenney_space_station/'; KM = 'kenney_modular_space/'
QM = 'quaternius_scifi_modular/'; QE = 'quaternius_scifi_essentials/'; VM = 'quaternius_vila_medieval/'; PR = 'quaternius_props/'
NEON_C, NEON_M, NEON_A = '3ae8ff', 'ff3df0', 'ffc23a'
MAT = json.load(open(os.path.join(AQUI, '..', 'data', 'forja', 'materiais.json')))

FUT = []
MAPA = [None]
def fut(tipo, x, z, **kw):
    d = {"tipo": tipo, "pos": [round(x, 2), round(z, 2)]}; d.update(kw); FUT.append(d)
    if MAPA[0] is not None:
        r = 1.2
        if "col" in kw and kw["col"]: r = max(kw["col"][0], kw["col"][2]) * 0.6 + 0.6
        MAPA[0].marca(x, z, r)
    return d
def mod(m, x, z, ang=0, escala=1.0, col=None, **kw):
    """modelo sci-fi; col = [largura, altura, profundidade] em METROS (caixa de colisão)."""
    d = fut("modelo", x, z, m=m, ang=ang, escala=escala, **kw)
    if col: d["col"] = col
    return d

def linha_neon(m, pts, cor, lado=None, larg=0.14):
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        if lado is None:
            fut("neon", ax, az, ate=[bx, bz], cor=cor, largura=larg)
        else:
            L = math.hypot(bx - ax, bz - az); nx, nz = -(bz - az) / L * lado, (bx - ax) / L * lado
            for s in (1, -1):
                fut("neon", ax + nx * s, az + nz * s, ate=[bx + nx * s, bz + nz * s], cor=cor, largura=larg)

def postes(m, pts, passo, lado, cor):
    lista = []
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, bz - az); n = max(1, int(L // passo)); nx, nz = -(bz - az) / L, (bx - ax) / L
        for k in range(1, n + 1):
            x = ax + (bx - ax) * k / n + nx * lado; z = az + (bz - az) * k / n + nz * lado
            if m.dentro(x, z, 3):
                fut("poste_energia", x, z, cor=cor); m.marca(x, z, 0.8); lista.append([round(x, 2), round(z, 2)])
    for a, b in zip(lista, lista[1:]):
        if math.hypot(a[0] - b[0], a[1] - b[1]) < passo * 1.6:
            fut("cabo", a[0], a[1], ate=b, altura=4.1, cor=cor)

def construir():
    m = Mapa('ilha_futurista', 104, 47, 7777, 0.085)
    MAPA[0] = m
    # ---------------- canal de refrigeração (rio luminoso) a sudoeste, cai pela borda
    m.rio([(-8, 20), (-16, 26), (-28, 28), (-40, 32), (-60, 40)], 2.6)
    # ---------------- relevo: platô do laboratório e morros da mina
    m.colina(-38, -14, 9, 1.6); m.colina(-44, 8, 7, 1.2); m.colina(30, -36, 8, 1.0)
    # ---------------- praça dos segundos
    m.disco(0, 0, 12, 'c', True, 0.0)
    estradas = {
        'sul': [(0, 12), (0, 30), (2, 40)], 'norte': [(0, -12), (-3, -18), (-4, -22)], 'leste': [(12, 0), (34, 0), (42, 0)],
        'oeste': [(-12, 0), (-22, 0)], 'nordeste': [(8, -9), (18, -18)], 'pods': [(0, 22), (14, 22), (24, 18)],
    }
    for nome, pts in estradas.items():
        m.estrada(pts, 4.0 if nome in ('sul', 'leste', 'norte') else 3.2, 'c')
    m.estrada([(-12, 0), (-30, 0)], 3.4, 'h')
    m.peca('ponte', -15.5, 25.5, 0, escala=1.0)  # ponte de madeira antiga (choque de linhas do tempo)
    mod(QM + 'Platform_Round1.gltf', 0, 0, 0, 2.1, dy=0.03)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        mod(QM + 'Platform_Metal.gltf', math.cos(a) * 8.6, math.sin(a) * 8.6, math.degrees(-a), 0.9, dy=0.02)
    fut("holo_relogio", 0, 0, raio=3.2, altura=4.2, rotulo="PRAÇA DOS SEGUNDOS")
    # bancas dos mercadores do tempo (mistura de épocas)
    bancas = [(6.5, 5.5, 225, KT + 'table-display-planet.glb', 3.2), (-6.5, 5.5, 135, PR + 'Stall_Empty.gltf', 1.1),
              (8.5, -3.0, 270, KT + 'display-wall-wide.glb', 3.0), (-8.5, -3.0, 90, KT + 'computer-system.glb', 2.6),
              (4.0, -8.0, 0, KT + 'container-wide.glb', 2.6), (-4.0, -8.5, 0, KT + 'table-display.glb', 2.4)]
    for x, z, a, mm, e in bancas:
        mod(mm, x, z, a, e, col=[1.8, 1.2, 1.4], tinta='ffffff' if 'Stall' not in mm else 'c8b0e0')
    for x, z in [(10.5, 4), (-10.5, 4), (3, 10.5), (-3, -10.8)]:
        mod(KT + 'container-tall.glb', x, z, m.rng.uniform(0, 360), 2.2, col=[1.2, 2.0, 1.2])
    for x, z in [(7, 9), (-9, -7), (10, -7)]:
        mod(KS + 'barrels.glb', x, z, m.rng.uniform(0, 360), 2.4)
    mod(KS + 'astronautA.glb', -3.5, 3.5, 30, 2.0, col=[0.9, 1.6, 0.8], rotulo="Estátua do Fundador\n(ainda vai nascer)", altura_rotulo=2.6, cor_rotulo='b8f0ff')
    # ---------------- Forja Quântica (fabricador) ao norte
    FX = -4
    m.retangulo(FX, -33, 22, 16, h=0.0)
    mod(KS + 'hangar_largeB.glb', FX, -34, 90, 5.0, col=[15, 5.5, 11])
    mod(KS + 'structure_detailed.glb', FX - 10.5, -33, 0, 4.0, col=[4, 4, 4])
    mod(KS + 'structure_closed.glb', FX + 10.5, -33, 0, 4.0, col=[4, 4, 4])
    for x in (FX - 10.5, FX + 10.5):
        mod(KS + 'chimney_detailed.glb', x, -35, 0, 3.0, emissao_extra=True)
    mod(KS + 'machine_generatorLarge.glb', FX - 6.5, -26.0, 0, 3.0, col=[3, 2, 3.9])
    mod(KS + 'machine_generator.glb', FX + 6.5, -26.0, 180, 3.0, col=[3, 2, 3])
    mod(PR + 'Anvil.gltf', FX - 1.8, -25.0, 0, 1.6, tinta='9ab0d0', col=[1.6, 0.9, 0.7])
    mod(QM + 'Prop_Computer.gltf', FX + 2.2, -25.4, 180, 1.0, col=[0.8, 1.6, 0.6])
    mod(QM + 'Platform_DarkPlates.gltf', FX, -25.0, 0, 2.0, dy=0.02)
    fut("forja_nucleo", FX, -27.2, cor=NEON_M)
    fut("holo_placa", FX, -27.8, texto="FORJA QUÂNTICA", altura=7.8, cor=NEON_M)
    for x in (FX - 4, FX + 4):
        mod(QM + 'Column_Pipes.gltf', x, -27.0, 0, 1.0, col=[0.9, 5, 0.9])
    # ---------------- Veio da Fenda (mina) a oeste
    m.disco(-32, 0, 13, 'h', False)
    for x, z, e in [(-33, 0, 10), (-40, -8, 6), (-27, 10, 5)]:
        mod(KS + 'craterLarge.glb', x, z, m.rng.uniform(0, 360), e, dy=-0.3)
    for x, z, a in [(-24, -9, 30), (-38, 14, 200)]:
        mod(KS + 'craft_miner.glb', x, z, a, 2.6, col=[4.4, 1.8, 6.4])
    mod(QE + 'Enemy_Trilobite.gltf', -42, 6, 120, 1.2, col=[3, 2.6, 3], rotulo="Escavadeira T-R1L0\n(desligada desde amanhã)", altura_rotulo=3.6, cor_rotulo='b8f0ff')
    mod(KS + 'machine_barrelLarge.glb', -21, 6, 0, 3.0, col=[2.2, 1.8, 2.2])
    mod(KT + 'skip-rocks.glb', -26, -2, 70, 2.6, col=[1.8, 1.8, 3.1])
    mod(KT + 'skip-rocks.glb', -29, 5, 100, 2.6, col=[1.8, 1.8, 3.1])
    mod(QE + 'Prop_Crate_Large.gltf', -20, -7, 90, 1.0, col=[1.5, 1.5, 3.5])
    mod(KS + 'supports_high.glb', -36, -18, 0, 4, col=[3.3, 4, 3.3])
    mod(KS + 'rover.glb', -30, 15, 140, 3.0)
    fut("holo_placa", -24, 0, texto="VEIO DA FENDA", altura=4.5, cor=NEON_A)
    # trilho de vagonete da mina até a forja
    trilho = [(-22, -4), (-19, -13), (-15, -21), (-14, -25)]
    fut("trilho", trilho[0][0], trilho[0][1], pontos=trilho, modelo=KS + 'monorail_trackStraight.glb', escala=3.0)
    mod(KS + 'monorail_trainCargo.glb', -18.0, -16.0, math.degrees(math.atan2(4, 8)), 2.6)
    # nós de minério (gancho data/forja/materiais.json)
    for n in MAT['nos_de_minerio']['veio_da_fenda']:
        x, z = n['pos']
        fut("veio_minerio", x, z, id=n['id'], material=n['material'])
        m.marca(x, z, 1.2)
    # ---------------- Laboratório de Anomalias a nordeste + zona de anomalia
    m.retangulo(25, -27, 16, 14, h=0.0)
    mod(KS + 'hangar_roundGlass.glb', 25, -28, 200, 4.0, col=[12, 5.6, 10.5])
    mod(KS + 'satelliteDish_large.glb', 35, -20, 225, 4.0, col=[2.8, 3, 2.6])
    mod(QE + 'Prop_SatelliteDish.gltf', 15, -33, 160, 0.9, col=[1.6, 5, 2.4])
    mod(QE + 'Prop_Locker.gltf', 19, -21, 210, 1.0, col=[1, 2.6, 0.6])
    mod(QE + 'Prop_Shelves_WideTall.gltf', 30.5, -19.5, 200, 1.0, col=[2, 2.6, 0.6])
    mod(KM + 'gate-lasers.glb', 21.5, -20.5, 225, 0.9)
    fut("holo_placa", 24, -21, texto="LABORATÓRIO DE ANOMALIAS", altura=7.0, cor=NEON_C)
    fut("anomalia", 13, -40, raio=3.4)
    # fragmentos de outras épocas presos na anomalia (choque de linhas do tempo)
    mod(VM + 'Wall_UnevenBrick_Window_Wide_Round.gltf', 8.5, -43, 20, 1.0, glitch=True, inclina=[8, 0, -12])
    mod(VM + 'Prop_Wagon.gltf', 18.5, -37.0, 70, 1.0, glitch=True, tinta='ffffff')
    mod(Q + 'CommonTree_3.gltf', 8.0, -37.5, 0, 0.8, glitch=True)
    fut("totem_orc", 17.0, -42.0, altura=3.6)
    for k in range(7):
        a = k / 7 * math.tau
        fut("detrito_flutuante", 13 + math.cos(a) * 5.5, -40 + math.sin(a) * 4.5, altura=2.5 + (k % 3) * 1.4, escala=1.2 + (k % 2), fase=k)
    # ---------------- Doca de pouso a leste
    m.retangulo(37, 0, 16, 14, h=0.0, tipo='c')
    for i in range(3):
        for j in range(2):
            mod(KS + 'platform_large.glb', 31 + i * 6, -3 + j * 6, 0, 3.0, dy=0.0)
    mod(KS + 'craft_cargoA.glb', 37, 4.0, 90, 2.6, col=[6.4, 2.2, 4.2])
    for k, peca in enumerate(['rocket_finsA', 'rocket_fuelA', 'rocket_sidesA', 'rocket_topA']):
        mod(KS + peca + '.glb', 41, -4.5, 0, 2.2, dy=[0, 1.54, 2.64, 4.84][k], col=[2.4, 6.6, 2.4] if k == 0 else None)
    mod(KS + 'gate_complex.glb', 28, 0, 90, 4.0)
    mod(KS + 'turret_double.glb', 30, -6, 210, 2.2, col=[2, 1.6, 1.4])
    m.especial('doca', 51, 0, 0, comprimento=16, largura=7, y=0.0, tinta='8090b0')
    m.especial('dirigivel', 70, 7.5, 90, y=-1.5)
    fut("holo_placa", 34, 6.5, texto="DOCA DE POUSO · ROTA DO ÂMBAR", altura=4.2, cor=NEON_A)
    # ---------------- Pods habitacionais (sul e sudeste)
    pods = [(12, 29, 190, 'hangar_roundA'), (24, 26, 230, 'hangar_roundB'), (28, 12, 260, 'hangar_roundGlass'),
            (-10, 36, 160, 'hangar_roundA'), (12, 40, 200, 'hangar_roundB'), (-22, 12, 120, 'hangar_roundGlass')]
    for x, z, a, k in pods:
        m.retangulo(x, z, 8, 7, h=0.0, ocupa=True)
        mod(KS + k + '.glb', x, z, a, 2.3, col=[7.0, 3.6, 6.0])
    fut("holo_placa", 17, 20, texto="PODS · PROIBIDO EXISTIR EM DUPLICATA", altura=3.8, cor=NEON_M)
    fut("holo_lua", -14, 10, altura=6.5)
    mod(QE + 'Enemy_QuadShell.gltf', 20, 34, 300, 0.8)
    # ---------------- energia: faixas neon e postes
    linha_neon(m, estradas['sul'], NEON_C, lado=2.3)
    linha_neon(m, estradas['leste'][:2], NEON_C, lado=2.3)
    linha_neon(m, estradas['norte'], NEON_M, lado=2.3)
    linha_neon(m, estradas['nordeste'], NEON_C, lado=1.9)
    linha_neon(m, [(-12, 0), (-22, 0)], NEON_A, lado=2.0)
    fut("anel_neon", 0, 0, raio=12.2, cor=NEON_C)
    postes(m, [(0, 14), (0, 38)], 9, 3.4, NEON_C)
    postes(m, [(14, 0), (32, 0)], 9, -3.4, NEON_C)
    postes(m, [(-14, 0), (-28, 0)], 8, 3.2, NEON_A)
    postes(m, [(10, -10), (19, -19)], 7, 2.6, NEON_C)
    # drones zelando
    for x, z, h in [(4, -4, 3.2), (-7, 8, 3.8), (-30, -6, 3.0), (22, -14, 3.5), (34, 3, 4.2), (-4, 26, 3.4)]:
        fut("drone", x, z, altura=h, m=QE + 'Enemy_EyeDrone.gltf', escala=0.6)
    # ---------------- vegetação alienígena e pedras
    roxo, ciano = 'a890ff', '60d8e8'
    m.espalhar(60, [Q + 'Mushroom_Common.gltf'], 1.4, None, escala=(2.5, 4.5), tinta=ciano, cat='flora')
    m.espalhar(40, [Q + 'Plant_7_Big.gltf', Q + 'Fern_1.gltf', Q + 'Plant_1.gltf'], 1.2, None, escala=(1.2, 2.0), tinta='4ac0c8')
    m.espalhar(20, [Q + 'TwistedTree_1.gltf', Q + 'TwistedTree_3.gltf'], 2.6, None, escala=(0.35, 0.55), tinta=roxo, col='tronco', cat='arvore')
    m.espalhar(14, [KS + 'rock_largeA.glb', KS + 'rock_largeB.glb', KS + 'meteor_detailed.glb'], 1.6, None, escala=(2.0, 3.2), col='rocha', tinta='9090b0')
    m.espalhar(16, [KS + 'rock_crystals.glb', KS + 'rocks_smallA.glb'], 1.0, None, escala=(1.6, 2.6), tinta='a0a0c0')
    # ---------------- marcadores
    m.marcador('spawn_jogador', 0, 34, 'spawn', 'Chegada pela passarela sul, de frente para a praça', 180)
    m.marcador('spawn_doca', 46, 0, 'spawn', 'Desembarque na doca de pouso', 270)
    for ident, x, z, papel, desc in [
        ('fabricadora', -4, -22.6, 'ferreira', 'Bancada da Forja Quântica, diante do fabricador'),
        ('mercador_temporal', 4.6, 3.4, 'comerciante', 'Banca dos hologramas na Praça dos Segundos'),
        ('robo_lobisomem', -12, 13, 'robo', 'Uivando para o holograma da lua, perto dos pods'),
        ('cientista_mira', 19, -17, 'cientista', 'Portão de lasers do Laboratório de Anomalias'),
        ('drone_zelador', -5, -4.5, 'drone', 'Varrendo paradoxos na praça'),
        ('fiscal_linhas', 25, 3.2, 'fiscal', 'Posto de fiscalização na entrada da doca'),
        ('minerador_fenda', -22, 3, 'minerador', 'Entrada do Veio da Fenda'),
    ]:
        m.marcador(ident, x, z, papel, desc)
    ilhas = [[-150, -10, -130, True], [140, -14, -150, True], [170, -18, 60, False], [-170, -16, 80, True]]
    for e in FUT:
        x, z = e['pos']
        if not m.dentro(x, z, 1.0) and e['tipo'] not in ('cabo',):
            print('AVISO fora da ilha:', e['tipo'], e.get('m', e.get('id', '')), x, z)
    return m.salvar({"nome_no": "IlhaFuturista", "sem_placas": True, "ilhas_distantes": ilhas, "fut": FUT,
        "tema": {"hora": 19.4, "tom_grama": "2c4656", "tom_terra": "3a3450", "tom_pedra": "8e98b6", "tom_rocha": "4a4864",
                 "tufos": ["1c3644", "3a98a8"], "flores": ["ff3df0", "3ae0ff", "b8f0ff"], "folhas_chao": ["2a2a44", "3a3a5c", "4a2a5c", "1a3a4a"],
                 "densidade_tufos": 0.8, "materiais": {"wood": "3a3448", "brown_planks_03": "6a6480", "lichen_rock": "5a5678", "iron": "8a94b0"},
                 "sol_energia": 0.55, "sol_cor": "ff8ad8", "sol_elevacao": 32, "lua_energia": 0.9, "lua_cor": "8af4ff",
                 "ambiente": "6a74c0", "ambiente_energia": 1.15,
                 "ceu": ["0a0c2a", "c0388a", "1a1240"], "nevoa_cor": "5a3a9a", "nevoa_densidade": 0.0018, "nevoa_volumetrica": 0.003,
                 "nevoa_abismo": ["120c30", "2a1a5a", "6a2a8a"], "rocha_base": "3e3a5a", "agua_raso": "1aa8c8", "agua_fundo": "0a2a5a",
                 "lajes": "7a86a8", "cinzas": {"quantidade": 1100, "cor": "8af4ff", "emissao": 2.2}, "saturacao": 1.08, "raios_sol": False,
                 "cor_janelas": "3ae0ff", "brilho_janelas": 2.0, "energia_luzes": 2.4,
                 "bruma_local": [[10, -40, 18, 5, 0.02], [-32, 0, 26, 3, 0.008]]},
        "capturas": [{"nome": "visao_geral", "alvo": [0, 0], "tamanho": 112},
                     {"nome": "praca_dos_segundos", "alvo": [0, 1], "tamanho": 28},
                     {"nome": "forja_quantica", "alvo": [-4, -28], "tamanho": 30},
                     {"nome": "veio_da_fenda", "alvo": [-30, 0], "tamanho": 32},
                     {"nome": "laboratorio_anomalia", "alvo": [16, -32], "tamanho": 32}]})

if __name__ == '__main__':
    os.makedirs(vgl.OUT, exist_ok=True)
    d = construir()
    print('fut:', len(FUT), 'objetos')
