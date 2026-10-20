#!/usr/bin/env python3
"""Gera data/forja/{materiais,itens,receitas}.json (PROPOSTA de forja, não é canon).
Determinístico. Uso: python3 tools/forja_gerar_dados.py
Fórmulas de balanceamento (ver docs/FORJA_E_ITENS.md):
  multiplicador_dano da Vale = 1 + ataque/25   (jogador_combate.gd usa multiplicador_dano; nada é ligado aqui)
  dano recebido = dano * 100 / (100 + defesa_total)
"""
import json, os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'forja')
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ locais
LOCAIS = {
    "minas_da_cinza": {"nome": "Minas da Cinza", "regiao": "Porto Velho (subsolo)", "cena": "", "descricao": "Dungeon sob Porto Velho. Entrada pela antiga cisterna atrás da Ferraria do Porto. Andares 1-5 cobre, 6-12 ferro, carvão em todos."},
    "coracao_soterrado": {"nome": "Coração Soterrado", "regiao": "Fundo das Minas da Cinza (andar 20+)", "cena": "", "descricao": "Onde a cinza é mais antiga. Veios de adamantium que 'sussurram horários'. Só abre depois da Bigorna Cronal."},
    "veio_das_cinzas": {"nome": "Veio das Cinzas", "regiao": "Vila dos Orcs", "cena": "res://scenes/vila_orcs/vila_orcs.tscn", "descricao": "Boca de mina do Clã Brasa-Velha, perto da Forja da Xamã. Ferro-brasa nasce perto da lava."},
    "criptas_de_cinzalta": {"nome": "Criptas de Cinzalta", "regiao": "Cidade Fantasma", "cena": "res://scenes/cidade_fantasma/cidade_fantasma.tscn", "descricao": "Cisternas e criptas sob o Campo das Cinzas. A prata dos túmulos foi benzida na noite da Queda."},
    "rochedos_da_rota": {"nome": "Rochedos da Rota do Âmbar", "regiao": "Rota Aérea (dirigível)", "cena": "", "descricao": "Pedras flutuantes no caminho do dirigível Andorinha. Ambarion cobra pedágio de quem minera ali."},
    "veio_da_fenda": {"nome": "Veio da Fenda", "regiao": "Estação Depois-de-Ontem", "cena": "res://scenes/ilha_futurista/ilha_futurista.tscn", "descricao": "Zona de extração da ilha caída do futuro. Cronóstio brota onde o tempo racha."},
    "fazenda": {"nome": "Fazenda da Vale", "regiao": "Ilha das Cinzas", "cena": "", "descricao": "Depois de tempestade de cinza, às vezes aparece um veio na fazenda (dica do Gaspar: 'não toca com a mão')."},
}

# ------------------------------------------------------------------ materiais
M = []
def mat(id, nome, tipo, tier, valor, local=None, picareta=None, **kw):
    d = {"id": id, "nome": nome, "tipo": tipo, "tier": tier, "valor_ouro": valor}
    if local: d["onde"] = local if isinstance(local, list) else [local]
    if picareta is not None: d["picareta_minima"] = picareta
    d.update(kw); M.append(d)

# minérios (tipo minerio) -> lingotes/ligas
mat("minerio_cobre", "Minério de Cobre", "minerio", 1, 4, "minas_da_cinza", 0, andares=[1, 5])
mat("minerio_ferro", "Minério de Ferro", "minerio", 2, 8, "minas_da_cinza", 1, andares=[6, 12])
mat("carvao", "Carvão", "auxiliar", 1, 3, ["minas_da_cinza", "veio_das_cinzas"], 0, andares=[1, 20], nota="Também sai de troncos queimados na fazenda.")
mat("minerio_ferro_brasa", "Minério de Ferro-Brasa", "minerio", 4, 22, "veio_das_cinzas", 3)
mat("minerio_prata_tumular", "Prata Tumular Bruta", "minerio", 5, 35, "criptas_de_cinzalta", 4, nota="Boa contra vampiros e lobisomens.")
mat("cristal_celeste_bruto", "Cristal Celeste Bruto", "minerio", 6, 55, "rochedos_da_rota", 5, nota="Cresce em pedras flutuantes; Ambarion cobra 1 em cada 5 como pedágio.")
mat("minerio_cronostio", "Minério de Cronóstio", "minerio", 7, 90, "veio_da_fenda", 6, nota="Metal que guarda segundos. Some se ficar mais de 1 dia fora do baú de estase.")
mat("minerio_adamantium", "Veio de Adamantium", "minerio", 8, 160, ["coracao_soterrado", "fazenda"], 7, nota="Canon: o avô de Gaspar forjava adamantium para os Arquimagos do Relógio.")
# lingotes
mat("lingote_cobre", "Lingote de Cobre", "lingote", 1, 16)
mat("lingote_ferro", "Lingote de Ferro", "lingote", 2, 30)
mat("lingote_aco_porto", "Lingote de Aço do Porto", "liga", 3, 70, nota="Ferro + carvão, temperado na água do porto.")
mat("lingote_ferro_brasa", "Lingote de Ferro-Brasa", "lingote", 4, 80, nota="Só a forja do clã (lava) funde.")
mat("lingote_prata_tumular", "Lingote de Prata Tumular", "lingote", 5, 125)
mat("cristal_celeste", "Cristal Celeste Lapidado", "lingote", 6, 130)
mat("lingote_cronostio", "Lingote de Cronóstio", "lingote", 7, 300)
mat("lingote_adamantium", "Lingote de Adamantium", "lingote", 8, 520)
mat("lingote_liga_paradoxal", "Lingote de Liga Paradoxal", "liga", 9, 1300, nota="Adamantium + cronóstio. Existe em dois instantes ao mesmo tempo.")
# auxiliares (alguns já existem na fazenda: madeira, pedra, fibra)
mat("madeira", "Madeira", "auxiliar", 0, 2, nota="Item já existente na fazenda.")
mat("pedra", "Pedra", "auxiliar", 0, 1, nota="Item já existente na fazenda.")
mat("fibra", "Fibra", "auxiliar", 0, 2, nota="Item já existente na fazenda.")
mat("couro", "Couro Curtido", "auxiliar", 1, 12, ["veio_das_cinzas"], nota="Caçadora Orc troca por legumes.")
mat("presa_vampirica", "Presa Vampírica", "drop", 5, 45, ["criptas_de_cinzalta"], nota="Cai de Vampiro Menor.")
mat("pelo_de_lua", "Pelo de Lua", "drop", 5, 50, nota="Presente do Tobias do Ermo (missão), nunca de combate.")
mat("escama_ambar", "Escama de Âmbar", "drop", 6, 90, ["rochedos_da_rota"], nota="Ambarion dá uma por pedágio pago 3 vezes.")
mat("chip_anomalia", "Chip de Anomalia", "drop", 7, 70, ["veio_da_fenda"], nota="Cai de drones com defeito temporal.")
mat("engrenagem_quantica", "Engrenagem Quântica", "auxiliar", 7, 110, ["veio_da_fenda"], nota="Vendida por Zé Antes-Depois.")
# essências (encantamento)
for id, nome, quem, ef in [
    ("essencia_raiz_brasa", "Essência de Raiz-de-Brasa", "mira", "Golpes queimam (+6% dano ao longo de 2 s)."),
    ("essencia_orvalho_lunar", "Essência de Orvalho-Lunar", "mira", "+25% de dano contra amaldiçoados (vampiros, lobisomens, espectros)."),
    ("essencia_musgo_sereno", "Essência de Musgo-Sereno", "mira", "Regenera 1 de vida a cada 4 s fora de combate."),
    ("po_de_segundo", "Pó de Segundo", "arquimago", "-12% na recarga do dash."),
    ("areia_de_ontem", "Areia de Ontem", "arquimago", "Cura 1 de vida a cada 5 acertos."),
    ("eco_de_amanha", "Eco de Amanhã", "arquimago", "+8% de chance de crítico (dano x1,5)."),
]:
    mat(id, nome, "essencia", 0, 60, nota=f"Feita por {'Mira (Botica)' if quem == 'mira' else 'Ozório (Torre Torta)'}. {ef}", fornecedor=quem, efeito=ef)

# nós de minério marcados na ilha futurista (gancho: ilha_futurista.gd lê isto)
NOS = {"veio_da_fenda": [
    {"id": "veio_cronostio_1", "material": "minerio_cronostio", "pos": [-30, -6], "quantidade": [2, 4], "renasce_dias": 2},
    {"id": "veio_cronostio_2", "material": "minerio_cronostio", "pos": [-36, 2], "quantidade": [2, 4], "renasce_dias": 2},
    {"id": "veio_cronostio_3", "material": "minerio_cronostio", "pos": [-27, 8], "quantidade": [2, 4], "renasce_dias": 2},
    {"id": "veio_cronostio_4", "material": "minerio_cronostio", "pos": [-40, -10], "quantidade": [3, 5], "renasce_dias": 3},
    {"id": "veio_chip_1", "material": "chip_anomalia", "pos": [-22, -14], "quantidade": [1, 2], "renasce_dias": 1},
    {"id": "veio_carvao_1", "material": "carvao", "pos": [-33, 12], "quantidade": [3, 6], "renasce_dias": 1},
    {"id": "veio_cristal_1", "material": "cristal_celeste_bruto", "pos": [-44, -2], "quantidade": [1, 2], "renasce_dias": 4, "nota": "Pedaço da Rota do Âmbar que caiu aqui."},
    {"id": "veio_adamantium_1", "material": "minerio_adamantium", "pos": [14.5, -35.5], "quantidade": [1, 1], "renasce_dias": 7, "nota": "Na zona de anomalia; só com picareta de cronóstio."},
]}

# ------------------------------------------------------------------ forjas
FORJAS = {
    "ferraria_porto": {"nome": "Ferraria do Porto", "ferreiro": "ferreiro", "ferreiro_nome": "Gaspar Bigorna", "regiao": "Porto Velho",
        "niveis": [
            {"nivel": 1, "nome": "Forja de barro", "custo_ouro": 0, "materiais": {}, "libera_tier": [1]},
            {"nivel": 2, "nome": "Fornalha de tijolo", "custo_ouro": 400, "materiais": {"pedra": 40, "lingote_cobre": 10}, "libera_tier": [2]},
            {"nivel": 3, "nome": "Tanque de têmpera do porto", "custo_ouro": 1200, "materiais": {"lingote_ferro": 15, "madeira": 30}, "libera_tier": [3]},
            {"nivel": 4, "nome": "Fole de Ferro-Brasa", "custo_ouro": 3000, "materiais": {"lingote_ferro_brasa": 8, "couro": 10}, "libera_tier": [5, 6], "nota": "Krag Martelo-Torto faz o fole; troca entre ilhas."},
            {"nivel": 5, "nome": "Bigorna Cronal", "custo_ouro": 9000, "materiais": {"lingote_cronostio": 6, "engrenagem_quantica": 2}, "libera_tier": [8], "nota": "Comprada da Mestra Ione. Abre o Coração Soterrado e o adamantium."},
        ]},
    "forja_cla": {"nome": "Forja do Clã Brasa-Velha", "ferreiro": "ferreiro_orc", "ferreiro_nome": "Krag Martelo-Torto", "regiao": "Vila dos Orcs",
        "niveis": [
            {"nivel": 1, "nome": "Bigorna de basalto", "custo_ouro": 0, "materiais": {}, "libera_tier": [4], "requisito": "Confiança do clã (Grusha Dente-de-Ferro)"},
            {"nivel": 2, "nome": "Poço de lava domado", "custo_ouro": 2500, "materiais": {"lingote_ferro_brasa": 12, "pedra": 60}, "libera_tier": [4], "nota": "Libera reforja +3 em equipamento orc."},
        ]},
    "forja_quantica": {"nome": "Forja Quântica (Fabricador)", "ferreiro": "fabricadora", "ferreiro_nome": "Mestra Ione Têmpera", "regiao": "Estação Depois-de-Ontem",
        "niveis": [
            {"nivel": 1, "nome": "Fabricador ligado", "custo_ouro": 0, "materiais": {}, "libera_tier": [7]},
            {"nivel": 2, "nome": "Núcleo paradoxal", "custo_ouro": 15000, "materiais": {"lingote_adamantium": 4, "chip_anomalia": 10}, "libera_tier": [9]},
        ]},
}
TIER_FORJA = {1: ("ferraria_porto", 1), 2: ("ferraria_porto", 2), 3: ("ferraria_porto", 3), 4: ("forja_cla", 1),
              5: ("ferraria_porto", 4), 6: ("ferraria_porto", 4), 7: ("forja_quantica", 1), 8: ("ferraria_porto", 5), 9: ("forja_quantica", 2)}

# ------------------------------------------------------------------ tiers
T = [  # tier, chave, adjetivo, lingote, aux, ataque, defesa_conjunto, ouro_base, especial
    (1, "cobre", "de Cobre", "lingote_cobre", "madeira", 5, 10, 40, ""),
    (2, "ferro", "de Ferro", "lingote_ferro", "couro", 9, 18, 90, ""),
    (3, "aco", "de Aço do Porto", "lingote_aco_porto", "couro", 14, 28, 180, "Aço temperado: +5% de dano no 3º golpe do combo."),
    (4, "brasa", "Ferro-Brasa", "lingote_ferro_brasa", "couro", 20, 40, 320, "Brasa: golpes pesados empurram 20% mais."),
    (5, "prata", "de Prata Tumular", "lingote_prata_tumular", "presa_vampirica", 26, 52, 520, "+50% de dano contra vampiros, lobisomens e espectros."),
    (6, "celeste", "Celeste", "cristal_celeste", "escama_ambar", 32, 66, 800, "Leve: +8% de velocidade de movimento."),
    (7, "cronostio", "de Cronóstio", "lingote_cronostio", "engrenagem_quantica", 40, 82, 1300, "Eco: 10% de chance de o golpe repetir 0,3 s depois."),
    (8, "adamantium", "de Adamantium", "lingote_adamantium", "eco_de_amanha", 50, 100, 2000, "Enche a barra ADAMANTIUM 25% mais rápido."),
    (9, "paradoxal", "Paradoxal", "lingote_liga_paradoxal", "chip_anomalia", 62, 122, 3200, "Paradoxo: o primeiro golpe fatal recebido a cada 3 min volta 2 s no tempo (vida restaurada ao valor de 2 s antes)."),
]
ITENS, REC = [], []
def item(d, receita):
    ITENS.append(d)
    r = {"id": "forjar_" + d["id"], "resultado": d["id"], "quantidade": 1}
    r.update(receita); REC.append(r)

def forja_de(t):
    f, n = TIER_FORJA[t]; return {"forja": f, "nivel_forja": n, "ferreiro": FORJAS[f]["ferreiro"]}

ESPADAS = {1: "Espada de Cobre", 2: "Espada de Ferro", 3: "Espada de Aço do Porto", 4: "Lâmina Ferro-Brasa",
           5: "Espada de Prata Tumular", 6: "Espada Celeste", 7: "Lâmina de Cronóstio", 8: "Espada de Adamantium", 9: "Espada Paradoxal"}
PECAS = [  # slot, nome, fração da defesa do conjunto, lingotes, aux, fator ouro
    ("elmo", "Elmo", 0.15, 2, 1, 0.8), ("peitoral", "Peitoral", 0.35, 5, 2, 1.6), ("luvas", "Luvas", 0.12, 2, 1, 0.7),
    ("botas", "Botas", 0.13, 2, 1, 0.7), ("escudo", "Escudo", 0.25, 3, 2, 1.0)]
NOMES_CONJ = {1: "Conjunto de Cobre", 2: "Conjunto de Ferro", 3: "Conjunto do Porto", 4: "Conjunto Brasa-Velha", 5: "Conjunto Tumular",
              6: "Conjunto Celeste", 7: "Conjunto Cronal", 8: "Conjunto de Adamantium", 9: "Conjunto Paradoxal"}
BONUS = {
    1: ["+5 de vida máxima", "+5% de dano de ferramentas na mina"],
    2: ["+10 de vida máxima", "Postura: o primeiro golpe recebido por sala causa -30%"],
    3: ["+15 de vida máxima", "Dash 10% mais longo"],
    4: ["+20 de vida máxima", "Fúria do clã: +10% de dano com vida abaixo de 40%"],
    5: ["Imune a dreno de vida vampírico", "+15% de dano contra amaldiçoados (soma com a arma)"],
    6: ["+10% de velocidade", "Queda suave: não toma dano ao cair de plataformas"],
    7: ["Dash deixa um eco que bloqueia 1 projétil", "-15% na recarga do especial"],
    8: ["Forma Adamantium dura +5 s", "+20% de dano do Raio de Adamantium"],
    9: ["Uma segunda chance por mapa (volta 3 s no tempo)", "+10% em todos os atributos"],
}
for (t, k, adj, lingote, aux, atk, dfs, ouro, esp) in T:
    fj = forja_de(t)
    # espada
    nome = ESPADAS[t]
    item({"id": f"espada_{k}", "nome": nome, "tipo": "arma", "categoria": "espada", "tier": t, "ataque": atk,
          "velocidade": 1.0 + (0.05 if t in (6, 7) else 0.0), "especial": esp, "multiplicador_dano": round(1 + atk / 25, 2),
          "valor_ouro": ouro * 2, "arte_pixellab": None},
         {"materiais": {lingote: 3, aux: 1 if t > 1 else 2}, "ouro": ouro, **fj})
    # armaduras
    for slot, nm, fr, nl, na, fo in PECAS:
        nome_p = f"{nm} {adj}" if t not in (4, 6, 9) else f"{nm} {adj}"
        d = {"id": f"{slot}_{k}", "nome": nome_p, "tipo": "armadura", "categoria": slot, "tier": t, "defesa": max(1, round(dfs * fr)),
             "conjunto": f"conjunto_{k}", "valor_ouro": int(ouro * fo * 1.5), "arte_pixellab": None}
        mats = {lingote: nl}
        mats[aux if slot != "escudo" else "madeira"] = na if slot != "escudo" else 4
        if slot in ("luvas", "botas") and t >= 2:
            mats["couro"] = mats.get("couro", 0) + 1
        item(d, {"materiais": mats, "ouro": int(ouro * fo), **fj})
# armas extras
EXTRAS = [
    ("adaga_cobre", "Adaga de Cobre", "adaga", 1, 4, 1.25, "Golpes rápidos: combo 25% mais veloz, alcance curto.", {"lingote_cobre": 2, "couro": 1}, 30),
    ("lanca_ferro", "Lança de Ferro", "lanca", 2, 10, 0.9, "Alcance +40%, arco estreito.", {"lingote_ferro": 3, "madeira": 3}, 80),
    ("machado_guerra_brasa", "Machado de Guerra Brasa-Velha", "machado", 4, 24, 0.8, "Golpe pesado quebra postura de orc em 1 acerto.", {"lingote_ferro_brasa": 4, "madeira": 2, "couro": 1}, 360),
    ("martelo_torto", "Martelo Martelo-Torto", "martelo", 4, 27, 0.7, "Assinatura do Krag. Atordoa 0,6 s.", {"lingote_ferro_brasa": 5, "pedra": 10}, 400),
    ("besta_prata", "Besta de Prata", "besta", 5, 18, 1.0, "Arma à distância; virotes de prata (+50% contra amaldiçoados).", {"lingote_prata_tumular": 3, "madeira": 4, "fibra": 6}, 560),
    ("lanca_celeste", "Lança Celeste", "lanca", 6, 34, 0.95, "Investida atravessa inimigos.", {"cristal_celeste": 3, "lingote_aco_porto": 2}, 820),
    ("pistola_ontem", "Pistola de Ontem", "pistola", 7, 30, 1.1, "Dispara um projétil que acerta 0,5 s antes de você apertar. Não pergunte.", {"lingote_cronostio": 2, "chip_anomalia": 2, "engrenagem_quantica": 1}, 1400),
    ("martelo_paradoxal", "Martelo Paradoxal", "martelo", 9, 70, 0.7, "Cada golpe acontece duas vezes, em dois instantes.", {"lingote_liga_paradoxal": 4, "chip_anomalia": 3}, 3600),
]
for id, nome, cat, t, atk, vel, esp, mats, ouro in EXTRAS:
    fj = forja_de(t)
    if cat in ("machado", "martelo") and t == 4: fj = {"forja": "forja_cla", "nivel_forja": 1, "ferreiro": "ferreiro_orc"}
    item({"id": id, "nome": nome, "tipo": "arma", "categoria": cat, "tier": t, "ataque": atk, "velocidade": vel, "especial": esp,
          "multiplicador_dano": round(1 + atk / 25, 2), "valor_ouro": ouro * 2, "arte_pixellab": None},
         {"materiais": mats, "ouro": ouro, **fj})
# acessórios
ACESS = [
    ("anel_cobre", "Anel de Cobre", 1, "+3 de defesa", {"lingote_cobre": 1}, 50, "ferraria_porto", 1),
    ("amuleto_raiz_brasa", "Amuleto de Raiz-de-Brasa", 2, "Resistência a fogo +20%", {"lingote_ferro": 1, "essencia_raiz_brasa": 1}, 150, "ferraria_porto", 2),
    ("presa_do_cla", "Colar Presa-do-Clã", 4, "+6% de dano; os orcs te cumprimentam", {"lingote_ferro_brasa": 1, "couro": 2}, 300, "forja_cla", 1),
    ("colar_prata_lunar", "Colar de Prata Lunar", 5, "Imune à maldição da lua; +10% contra amaldiçoados", {"lingote_prata_tumular": 1, "pelo_de_lua": 1, "essencia_orvalho_lunar": 1}, 600, "ferraria_porto", 4),
    ("anel_ambar", "Anel de Âmbar Dracônico", 6, "Resistência a fogo +40%; Ambarion cobra metade do pedágio", {"cristal_celeste": 1, "escama_ambar": 2}, 900, "ferraria_porto", 4),
    ("relogio_bolso_cronal", "Relógio de Bolso Cronal", 7, "-20% na recarga do dash", {"lingote_cronostio": 1, "engrenagem_quantica": 1}, 1500, "forja_quantica", 1),
    ("brinco_eco", "Brinco de Eco", 7, "+10% de chance de crítico", {"lingote_cronostio": 1, "eco_de_amanha": 1}, 1500, "forja_quantica", 1),
    ("coracao_engrenagem", "Coração-Engrenagem", 9, "+25 de vida máxima e regeneração lenta", {"lingote_liga_paradoxal": 1, "areia_de_ontem": 2}, 4000, "forja_quantica", 2),
]
for id, nome, t, ef, mats, ouro, f, n in ACESS:
    item({"id": id, "nome": nome, "tipo": "acessorio", "categoria": "acessorio", "tier": t, "efeito": ef, "valor_ouro": ouro * 2, "arte_pixellab": None},
         {"materiais": mats, "ouro": ouro, "forja": f, "nivel_forja": n, "ferreiro": FORJAS[f]["ferreiro"]})
# ferramentas (picareta: o tier da picareta é o maior "picareta_minima" que ela minera)
PIC = [(1, "cobre", "Picareta de Cobre", "lingote_cobre"), (2, "ferro", "Picareta de Ferro", "lingote_ferro"), (3, "aco", "Picareta de Aço", "lingote_aco_porto"),
       (4, "brasa", "Picareta Ferro-Brasa", "lingote_ferro_brasa"), (5, "prata", "Picareta de Prata", "lingote_prata_tumular"),
       (6, "celeste", "Picareta Celeste", "cristal_celeste"), (7, "cronostio", "Picareta de Cronóstio", "lingote_cronostio")]
for t, k, nome, l in PIC:
    fj = forja_de(t)
    item({"id": f"picareta_{k}", "nome": nome, "tipo": "ferramenta", "categoria": "picareta", "tier": t, "nivel_mineracao": t,
          "efeito": f"Minera materiais com picareta mínima até {t}. Golpes na mina: {2 + t}.", "valor_ouro": T[t - 1][7], "arte_pixellab": None},
         {"materiais": {l: 2, "madeira": 2}, "ouro": T[t - 1][7] // 2, **fj})
for cat, nome_base, bonus in [("machado", "Machado", "corta tocos e troncos maiores"), ("enxada", "Enxada", "ara mais canteiros por golpe"), ("regador", "Regador", "rega mais canteiros")]:
    lim = 4 if cat == "machado" else 3
    for t, k, adj, l in [(1, "cobre", "de Cobre", "lingote_cobre"), (2, "ferro", "de Ferro", "lingote_ferro"), (3, "aco", "de Aço", "lingote_aco_porto"), (4, "brasa", "Ferro-Brasa", "lingote_ferro_brasa")][:lim]:
        fj = forja_de(t)
        area = {1: "1x3", 2: "3x3", 3: "5x5", 4: "5x5 + 1 tronco grande"}[t]
        item({"id": f"{cat}_{k}", "nome": f"{nome_base} {adj}", "tipo": "ferramenta", "categoria": cat, "tier": t,
              "efeito": f"Área {area}: {bonus}.", "valor_ouro": T[t - 1][7], "arte_pixellab": None},
             {"materiais": {l: 2 if cat != "regador" else 3, "madeira": 1}, "ouro": T[t - 1][7] // 2, **fj})

# ------------------------------------------------------------------ fundição (minério -> lingote)
FUND = [
    ("fundir_cobre", "lingote_cobre", {"minerio_cobre": 3, "carvao": 1}, 5, "ferraria_porto", 1),
    ("fundir_ferro", "lingote_ferro", {"minerio_ferro": 3, "carvao": 1}, 10, "ferraria_porto", 2),
    ("ligar_aco_porto", "lingote_aco_porto", {"lingote_ferro": 2, "carvao": 2}, 25, "ferraria_porto", 3),
    ("fundir_ferro_brasa", "lingote_ferro_brasa", {"minerio_ferro_brasa": 3, "carvao": 1}, 30, "forja_cla", 1),
    ("fundir_prata_tumular", "lingote_prata_tumular", {"minerio_prata_tumular": 3, "carvao": 1, "essencia_orvalho_lunar": 1}, 45, "ferraria_porto", 4),
    ("lapidar_cristal_celeste", "cristal_celeste", {"cristal_celeste_bruto": 2}, 50, "ferraria_porto", 4),
    ("fundir_cronostio", "lingote_cronostio", {"minerio_cronostio": 3, "chip_anomalia": 1}, 120, "forja_quantica", 1),
    ("fundir_adamantium", "lingote_adamantium", {"minerio_adamantium": 3, "carvao": 2, "po_de_segundo": 1}, 200, "ferraria_porto", 5),
    ("ligar_liga_paradoxal", "lingote_liga_paradoxal", {"lingote_adamantium": 1, "lingote_cronostio": 2, "eco_de_amanha": 1}, 500, "forja_quantica", 2),
]
FUNDICAO = []
for id, res, mats, ouro, f, n in FUND:
    FUNDICAO.append({"id": id, "resultado": res, "quantidade": 1, "materiais": mats, "ouro": ouro, "forja": f, "nivel_forja": n, "ferreiro": FORJAS[f]["ferreiro"], "etapa": "fundicao"})

REFORJA = {"niveis": [
    {"nivel": 1, "bonus_atributo": 0.10, "lingotes_do_tier": 1, "ouro_fracao": 0.2},
    {"nivel": 2, "bonus_atributo": 0.20, "lingotes_do_tier": 2, "ouro_fracao": 0.4},
    {"nivel": 3, "bonus_atributo": 0.35, "lingotes_do_tier": 3, "ouro_fracao": 0.7, "extra": {"po_de_segundo": 1}},
], "regra": "Reforja na mesma forja que fez o item (ou superior). +3 em itens orc só na Forja do Clã nível 2."}
ENCANTO = {"regra": "1 encanto por item. Trocar o encanto destrói o anterior. Mira encanta na Botica; Ozório na Torre Torta; a Dra. Mira de Depois aplica os dois tipos no Laboratório, com efeito x1,5.",
           "ouro_por_tier": 40, "essencias": [m["id"] for m in M if m["tipo"] == "essencia"]}

MVP = {"descricao": "Primeira fatia: só Porto Velho + Minas da Cinza (andares 1-12) + Gaspar Bigorna (forja nível 1-3).",
       "materiais": ["minerio_cobre", "minerio_ferro", "carvao", "lingote_cobre", "lingote_ferro", "lingote_aco_porto", "madeira", "couro"],
       "receitas": ["fundir_cobre", "fundir_ferro", "ligar_aco_porto", "forjar_espada_cobre", "forjar_espada_ferro", "forjar_espada_aco",
                    "forjar_picareta_cobre", "forjar_picareta_ferro", "forjar_peitoral_cobre", "forjar_peitoral_ferro", "forjar_escudo_ferro", "forjar_anel_cobre"],
       "mecanicas": ["fundir", "forjar", "reforja +1", "subir forja para nível 2 e 3"]}

ids_mat = {m["id"] for m in M}
for r in REC + FUNDICAO:
    for k in r["materiais"]:
        assert k in ids_mat, (r["id"], k)

json.dump({"versao": 1, "status": "PROPOSTA (não é canon)", "locais": LOCAIS, "materiais": M, "nos_de_minerio": NOS},
          open(os.path.join(OUT, 'materiais.json'), 'w'), ensure_ascii=False, indent=1)
json.dump({"versao": 1, "status": "PROPOSTA (não é canon)", "formula": {"multiplicador_dano": "1 + ataque/25", "dano_recebido": "dano * 100 / (100 + defesa_total)"},
           "conjuntos": {f"conjunto_{t[1]}": {"nome": NOMES_CONJ[t[0]], "tier": t[0], "bonus_3_pecas": BONUS[t[0]][0], "bonus_5_pecas": BONUS[t[0]][1]} for t in T},
           "itens": ITENS}, open(os.path.join(OUT, 'itens.json'), 'w'), ensure_ascii=False, indent=1)
json.dump({"versao": 1, "status": "PROPOSTA (não é canon)", "forjas": FORJAS, "fundicao": FUNDICAO, "receitas": REC,
           "reforja": REFORJA, "encantamento": ENCANTO, "mvp": MVP},
          open(os.path.join(OUT, 'receitas.json'), 'w'), ensure_ascii=False, indent=1)
from collections import Counter
print("materiais", len(M), Counter(m['tipo'] for m in M))
print("itens", len(ITENS), Counter(i['tipo'] for i in ITENS))
print("receitas de forja", len(REC), "fundicao", len(FUNDICAO))
