# Forja e Itens — Ilha das Cinzas

> **PROPOSTA — não é canon.** Documento gerado por `tools/forja_gerar_doc.py` a partir de `data/forja/*.json` (gerados por `tools/forja_gerar_dados.py`). Nada aqui está ligado ao `main.tscn`, ao Vale ou ao combate; `scripts/forja/forja.gd` é um sistema isolado, testado por `tests/forja_testes.gd`.

**Totais:** 32 materiais · 87 itens (45 peças de armadura, 17 armas, 17 ferramentas, 8 acessórios) · 87 receitas de forja + 9 de fundição.

## 1. Ciclo do jogador

1. **Minerar** (picareta com nível ≥ `picareta_minima` do minério) na dungeon (Minas da Cinza) ou em outras ilhas.
2. **Fundir** minério + carvão em lingote na forja certa.
3. **Forjar** o item no ferreiro (cada forja tem níveis; cada nível libera tiers).
4. **Reforjar** (+1..+3) e **encantar** com essências da Mira (Botica) ou do Ozório (Torre Torta).
5. Vestir 3 ou 5 peças do mesmo conjunto para o **bônus de conjunto**.

## 2. Metais (9 tiers) e onde minerar

| Tier | Metal | Minério / origem | Onde | Picareta mínima | Lingote (fundição) |
|---|---|---|---|---|---|
| 1 | Cobre | Minério de Cobre | Minas da Cinza (Porto Velho (subsolo)) — andares 1–5 | 0 | Lingote de Cobre: 3× Minério de Cobre, 1× Carvão + 5 ouro — Gaspar Bigorna (Ferraria do Porto N1) |
| 2 | Ferro | Minério de Ferro | Minas da Cinza (Porto Velho (subsolo)) — andares 6–12 | 1 | Lingote de Ferro: 3× Minério de Ferro, 1× Carvão + 10 ouro — Gaspar Bigorna (Ferraria do Porto N2) |
| 3 | Aço do Porto | liga (sem minério) | feita na forja | — | Lingote de Aço do Porto: 2× Lingote de Ferro, 2× Carvão + 25 ouro — Gaspar Bigorna (Ferraria do Porto N3) |
| 4 | Ferro-Brasa | Minério de Ferro-Brasa | Veio das Cinzas (Vila dos Orcs) | 3 | Lingote de Ferro-Brasa: 3× Minério de Ferro-Brasa, 1× Carvão + 30 ouro — Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| 5 | Prata Tumular | Prata Tumular Bruta | Criptas de Cinzalta (Cidade Fantasma) | 4 | Lingote de Prata Tumular: 3× Prata Tumular Bruta, 1× Carvão, 1× Essência de Orvalho-Lunar + 45 ouro — Gaspar Bigorna (Ferraria do Porto N4) |
| 6 | Cristal Celeste | Cristal Celeste Bruto | Rochedos da Rota do Âmbar (Rota Aérea (dirigível)) | 5 | Cristal Celeste Lapidado: 2× Cristal Celeste Bruto + 50 ouro — Gaspar Bigorna (Ferraria do Porto N4) |
| 7 | Cronóstio | Minério de Cronóstio | Veio da Fenda (Estação Depois-de-Ontem) | 6 | Lingote de Cronóstio: 3× Minério de Cronóstio, 1× Chip de Anomalia + 120 ouro — Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| 8 | Adamantium | Veio de Adamantium | Coração Soterrado (Fundo das Minas da Cinza (andar 20+)); Fazenda da Vale (Ilha das Cinzas) | 7 | Lingote de Adamantium: 3× Veio de Adamantium, 2× Carvão, 1× Pó de Segundo + 200 ouro — Gaspar Bigorna (Ferraria do Porto N5) |
| 9 | Liga Paradoxal | liga (sem minério) | feita na forja | — | Lingote de Liga Paradoxal: 1× Lingote de Adamantium, 2× Lingote de Cronóstio, 1× Eco de Amanhã + 500 ouro — Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |

### Locais de mineração

- **Minas da Cinza** — Porto Velho (subsolo). Dungeon sob Porto Velho. Entrada pela antiga cisterna atrás da Ferraria do Porto. Andares 1-5 cobre, 6-12 ferro, carvão em todos. (cena ainda não existe)
- **Coração Soterrado** — Fundo das Minas da Cinza (andar 20+). Onde a cinza é mais antiga. Veios de adamantium que 'sussurram horários'. Só abre depois da Bigorna Cronal. (cena ainda não existe)
- **Veio das Cinzas** — Vila dos Orcs. Boca de mina do Clã Brasa-Velha, perto da Forja da Xamã. Ferro-brasa nasce perto da lava. Cena: `res://scenes/vila_orcs/vila_orcs.tscn`.
- **Criptas de Cinzalta** — Cidade Fantasma. Cisternas e criptas sob o Campo das Cinzas. A prata dos túmulos foi benzida na noite da Queda. Cena: `res://scenes/cidade_fantasma/cidade_fantasma.tscn`.
- **Rochedos da Rota do Âmbar** — Rota Aérea (dirigível). Pedras flutuantes no caminho do dirigível Andorinha. Ambarion cobra pedágio de quem minera ali. (cena ainda não existe)
- **Veio da Fenda** — Estação Depois-de-Ontem. Zona de extração da ilha caída do futuro. Cronóstio brota onde o tempo racha. Cena: `res://scenes/ilha_futurista/ilha_futurista.tscn`.
- **Fazenda da Vale** — Ilha das Cinzas. Depois de tempestade de cinza, às vezes aparece um veio na fazenda (dica do Gaspar: 'não toca com a mão'). (cena ainda não existe)

### Outros materiais (auxiliares, drops, essências)

| Material | Tipo | Tier | Onde / fornecedor | Nota |
|---|---|---|---|---|
| Carvão | auxiliar | 1 | Minas da Cinza, Veio das Cinzas | Também sai de troncos queimados na fazenda. |
| Lingote de Cobre | lingote | 1 | fundição (Gaspar Bigorna (Ferraria do Porto N1)) |  |
| Lingote de Ferro | lingote | 2 | fundição (Gaspar Bigorna (Ferraria do Porto N2)) |  |
| Lingote de Aço do Porto | liga | 3 | fundição (Gaspar Bigorna (Ferraria do Porto N3)) | Ferro + carvão, temperado na água do porto. |
| Lingote de Ferro-Brasa | lingote | 4 | fundição (Krag Martelo-Torto (Forja do Clã Brasa-Velha N1)) | Só a forja do clã (lava) funde. |
| Lingote de Prata Tumular | lingote | 5 | fundição (Gaspar Bigorna (Ferraria do Porto N4)) |  |
| Cristal Celeste Lapidado | lingote | 6 | fundição (Gaspar Bigorna (Ferraria do Porto N4)) |  |
| Lingote de Cronóstio | lingote | 7 | fundição (Mestra Ione Têmpera (Forja Quântica (Fabricador) N1)) |  |
| Lingote de Adamantium | lingote | 8 | fundição (Gaspar Bigorna (Ferraria do Porto N5)) |  |
| Lingote de Liga Paradoxal | liga | 9 | fundição (Mestra Ione Têmpera (Forja Quântica (Fabricador) N2)) | Adamantium + cronóstio. Existe em dois instantes ao mesmo tempo. |
| Madeira | auxiliar | 0 | fazenda | Item já existente na fazenda. |
| Pedra | auxiliar | 0 | fazenda | Item já existente na fazenda. |
| Fibra | auxiliar | 0 | fazenda | Item já existente na fazenda. |
| Couro Curtido | auxiliar | 1 | Veio das Cinzas | Caçadora Orc troca por legumes. |
| Presa Vampírica | drop | 5 | Criptas de Cinzalta | Cai de Vampiro Menor. |
| Pelo de Lua | drop | 5 | — | Presente do Tobias do Ermo (missão), nunca de combate. |
| Escama de Âmbar | drop | 6 | Rochedos da Rota do Âmbar | Ambarion dá uma por pedágio pago 3 vezes. |
| Chip de Anomalia | drop | 7 | Veio da Fenda | Cai de drones com defeito temporal. |
| Engrenagem Quântica | auxiliar | 7 | Veio da Fenda | Vendida por Zé Antes-Depois. |
| Essência de Raiz-de-Brasa | essencia | 0 | mira | Feita por Mira (Botica). Golpes queimam (+6% dano ao longo de 2 s). |
| Essência de Orvalho-Lunar | essencia | 0 | mira | Feita por Mira (Botica). +25% de dano contra amaldiçoados (vampiros, lobisomens, espectros). |
| Essência de Musgo-Sereno | essencia | 0 | mira | Feita por Mira (Botica). Regenera 1 de vida a cada 4 s fora de combate. |
| Pó de Segundo | essencia | 0 | arquimago | Feita por Ozório (Torre Torta). -12% na recarga do dash. |
| Areia de Ontem | essencia | 0 | arquimago | Feita por Ozório (Torre Torta). Cura 1 de vida a cada 5 acertos. |
| Eco de Amanhã | essencia | 0 | arquimago | Feita por Ozório (Torre Torta). +8% de chance de crítico (dano x1,5). |

### Nós de minério na Estação Depois-de-Ontem (`veio_da_fenda`)

| Nó | Material | Posição (x,z) m | Quantidade | Renasce (dias) |
|---|---|---|---|---|
| veio_cronostio_1 | Minério de Cronóstio | -30, -6 | 2–4 | 2 |
| veio_cronostio_2 | Minério de Cronóstio | -36, 2 | 2–4 | 2 |
| veio_cronostio_3 | Minério de Cronóstio | -27, 8 | 2–4 | 2 |
| veio_cronostio_4 | Minério de Cronóstio | -40, -10 | 3–5 | 3 |
| veio_chip_1 | Chip de Anomalia | -22, -14 | 1–2 | 1 |
| veio_carvao_1 | Carvão | -33, 12 | 3–6 | 1 |
| veio_cristal_1 | Cristal Celeste Bruto | -44, -2 | 1–2 | 4 |
| veio_adamantium_1 | Veio de Adamantium | 14.5, -35.5 | 1–1 | 7 |

## 3. Picaretas e ferramentas

Nível de mineração da picareta precisa ser ≥ `picareta_minima` do minério (cobre 0, ferro 1, ferro-brasa 3, prata 4, cristal celeste 5, cronóstio 6, adamantium 7).

| Ferramenta | Tier | Nível mineração | Efeito | Valor | Receita | Ferreiro / forja |
|---|---|---|---|---|---|---|
| Enxada de Cobre | 1 | — | Área 1x3: ara mais canteiros por golpe. | 40 | 2× Lingote de Cobre, 1× Madeira + 20 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Machado de Cobre | 1 | — | Área 1x3: corta tocos e troncos maiores. | 40 | 2× Lingote de Cobre, 1× Madeira + 20 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Picareta de Cobre | 1 | 1 | Minera materiais com picareta mínima até 1. Golpes na mina: 3. | 40 | 2× Lingote de Cobre, 2× Madeira + 20 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Regador de Cobre | 1 | — | Área 1x3: rega mais canteiros. | 40 | 3× Lingote de Cobre, 1× Madeira + 20 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Enxada de Ferro | 2 | — | Área 3x3: ara mais canteiros por golpe. | 90 | 2× Lingote de Ferro, 1× Madeira + 45 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Machado de Ferro | 2 | — | Área 3x3: corta tocos e troncos maiores. | 90 | 2× Lingote de Ferro, 1× Madeira + 45 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Picareta de Ferro | 2 | 2 | Minera materiais com picareta mínima até 2. Golpes na mina: 4. | 90 | 2× Lingote de Ferro, 2× Madeira + 45 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Regador de Ferro | 2 | — | Área 3x3: rega mais canteiros. | 90 | 3× Lingote de Ferro, 1× Madeira + 45 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Enxada de Aço | 3 | — | Área 5x5: ara mais canteiros por golpe. | 180 | 2× Lingote de Aço do Porto, 1× Madeira + 90 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Machado de Aço | 3 | — | Área 5x5: corta tocos e troncos maiores. | 180 | 2× Lingote de Aço do Porto, 1× Madeira + 90 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Picareta de Aço | 3 | 3 | Minera materiais com picareta mínima até 3. Golpes na mina: 5. | 180 | 2× Lingote de Aço do Porto, 2× Madeira + 90 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Regador de Aço | 3 | — | Área 5x5: rega mais canteiros. | 180 | 3× Lingote de Aço do Porto, 1× Madeira + 90 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Machado Ferro-Brasa | 4 | — | Área 5x5 + 1 tronco grande: corta tocos e troncos maiores. | 320 | 2× Lingote de Ferro-Brasa, 1× Madeira + 160 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Picareta Ferro-Brasa | 4 | 4 | Minera materiais com picareta mínima até 4. Golpes na mina: 6. | 320 | 2× Lingote de Ferro-Brasa, 2× Madeira + 160 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Picareta de Prata | 5 | 5 | Minera materiais com picareta mínima até 5. Golpes na mina: 7. | 520 | 2× Lingote de Prata Tumular, 2× Madeira + 260 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Picareta Celeste | 6 | 6 | Minera materiais com picareta mínima até 6. Golpes na mina: 8. | 800 | 2× Cristal Celeste Lapidado, 2× Madeira + 400 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Picareta de Cronóstio | 7 | 7 | Minera materiais com picareta mínima até 7. Golpes na mina: 9. | 1300 | 2× Lingote de Cronóstio, 2× Madeira + 650 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |

## 4. Armas

| Arma | Tier | Ataque | Mult. dano | Veloc. | Especial | Receita | Ferreiro / forja |
|---|---|---|---|---|---|---|---|
| Adaga de Cobre | 1 | 4 | 1.16 | 1.25 | Golpes rápidos: combo 25% mais veloz, alcance curto. | 2× Lingote de Cobre, 1× Couro Curtido + 30 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Espada de Cobre | 1 | 5 | 1.2 | 1.0 | — | 3× Lingote de Cobre, 2× Madeira + 40 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Espada de Ferro | 2 | 9 | 1.36 | 1.0 | — | 3× Lingote de Ferro, 1× Couro Curtido + 90 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Lança de Ferro | 2 | 10 | 1.4 | 0.9 | Alcance +40%, arco estreito. | 3× Lingote de Ferro, 3× Madeira + 80 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Espada de Aço do Porto | 3 | 14 | 1.56 | 1.0 | Aço temperado: +5% de dano no 3º golpe do combo. | 3× Lingote de Aço do Porto, 1× Couro Curtido + 180 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Lâmina Ferro-Brasa | 4 | 20 | 1.8 | 1.0 | Brasa: golpes pesados empurram 20% mais. | 3× Lingote de Ferro-Brasa, 1× Couro Curtido + 320 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Machado de Guerra Brasa-Velha | 4 | 24 | 1.96 | 0.8 | Golpe pesado quebra postura de orc em 1 acerto. | 4× Lingote de Ferro-Brasa, 2× Madeira, 1× Couro Curtido + 360 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Martelo Martelo-Torto | 4 | 27 | 2.08 | 0.7 | Assinatura do Krag. Atordoa 0,6 s. | 5× Lingote de Ferro-Brasa, 10× Pedra + 400 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Besta de Prata | 5 | 18 | 1.72 | 1.0 | Arma à distância; virotes de prata (+50% contra amaldiçoados). | 3× Lingote de Prata Tumular, 4× Madeira, 6× Fibra + 560 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Espada de Prata Tumular | 5 | 26 | 2.04 | 1.0 | +50% de dano contra vampiros, lobisomens e espectros. | 3× Lingote de Prata Tumular, 1× Presa Vampírica + 520 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Espada Celeste | 6 | 32 | 2.28 | 1.05 | Leve: +8% de velocidade de movimento. | 3× Cristal Celeste Lapidado, 1× Escama de Âmbar + 800 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Lança Celeste | 6 | 34 | 2.36 | 0.95 | Investida atravessa inimigos. | 3× Cristal Celeste Lapidado, 2× Lingote de Aço do Porto + 820 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Lâmina de Cronóstio | 7 | 40 | 2.6 | 1.05 | Eco: 10% de chance de o golpe repetir 0,3 s depois. | 3× Lingote de Cronóstio, 1× Engrenagem Quântica + 1300 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Pistola de Ontem | 7 | 30 | 2.2 | 1.1 | Dispara um projétil que acerta 0,5 s antes de você apertar. Não pergunte. | 2× Lingote de Cronóstio, 2× Chip de Anomalia, 1× Engrenagem Quântica + 1400 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Espada de Adamantium | 8 | 50 | 3.0 | 1.0 | Enche a barra ADAMANTIUM 25% mais rápido. | 3× Lingote de Adamantium, 1× Eco de Amanhã + 2000 ouro | Gaspar Bigorna (Ferraria do Porto N5) |
| Espada Paradoxal | 9 | 62 | 3.48 | 1.0 | Paradoxo: o primeiro golpe fatal recebido a cada 3 min volta 2 s no tempo (vida restaurada ao valor de 2 s antes). | 3× Lingote de Liga Paradoxal, 1× Chip de Anomalia + 3200 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |
| Martelo Paradoxal | 9 | 70 | 3.8 | 0.7 | Cada golpe acontece duas vezes, em dois instantes. | 4× Lingote de Liga Paradoxal, 3× Chip de Anomalia + 3600 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |

## 5. Armaduras (5 peças por tier: elmo, peitoral, luvas, botas, escudo)

| Peça | Tier | Defesa | Receita | Ferreiro / forja |
|---|---|---|---|---|
| Botas de Cobre | 1 | 1 | 2× Lingote de Cobre, 1× Madeira + 28 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Elmo de Cobre | 1 | 2 | 2× Lingote de Cobre, 1× Madeira + 32 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Escudo de Cobre | 1 | 2 | 3× Lingote de Cobre, 4× Madeira + 40 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Luvas de Cobre | 1 | 1 | 2× Lingote de Cobre, 1× Madeira + 28 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Peitoral de Cobre | 1 | 4 | 5× Lingote de Cobre, 2× Madeira + 64 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Botas de Ferro | 2 | 2 | 2× Lingote de Ferro, 2× Couro Curtido + 62 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Elmo de Ferro | 2 | 3 | 2× Lingote de Ferro, 1× Couro Curtido + 72 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Escudo de Ferro | 2 | 4 | 3× Lingote de Ferro, 4× Madeira + 90 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Luvas de Ferro | 2 | 2 | 2× Lingote de Ferro, 2× Couro Curtido + 62 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Peitoral de Ferro | 2 | 6 | 5× Lingote de Ferro, 2× Couro Curtido + 144 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Botas de Aço do Porto | 3 | 4 | 2× Lingote de Aço do Porto, 2× Couro Curtido + 125 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Elmo de Aço do Porto | 3 | 4 | 2× Lingote de Aço do Porto, 1× Couro Curtido + 144 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Escudo de Aço do Porto | 3 | 7 | 3× Lingote de Aço do Porto, 4× Madeira + 180 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Luvas de Aço do Porto | 3 | 3 | 2× Lingote de Aço do Porto, 2× Couro Curtido + 125 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Peitoral de Aço do Porto | 3 | 10 | 5× Lingote de Aço do Porto, 2× Couro Curtido + 288 ouro | Gaspar Bigorna (Ferraria do Porto N3) |
| Botas Ferro-Brasa | 4 | 5 | 2× Lingote de Ferro-Brasa, 2× Couro Curtido + 224 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Elmo Ferro-Brasa | 4 | 6 | 2× Lingote de Ferro-Brasa, 1× Couro Curtido + 256 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Escudo Ferro-Brasa | 4 | 10 | 3× Lingote de Ferro-Brasa, 4× Madeira + 320 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Luvas Ferro-Brasa | 4 | 5 | 2× Lingote de Ferro-Brasa, 2× Couro Curtido + 224 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Peitoral Ferro-Brasa | 4 | 14 | 5× Lingote de Ferro-Brasa, 2× Couro Curtido + 512 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Botas de Prata Tumular | 5 | 7 | 2× Lingote de Prata Tumular, 1× Presa Vampírica, 1× Couro Curtido + 364 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Elmo de Prata Tumular | 5 | 8 | 2× Lingote de Prata Tumular, 1× Presa Vampírica + 416 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Escudo de Prata Tumular | 5 | 13 | 3× Lingote de Prata Tumular, 4× Madeira + 520 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Luvas de Prata Tumular | 5 | 6 | 2× Lingote de Prata Tumular, 1× Presa Vampírica, 1× Couro Curtido + 364 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Peitoral de Prata Tumular | 5 | 18 | 5× Lingote de Prata Tumular, 2× Presa Vampírica + 832 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Botas Celeste | 6 | 9 | 2× Cristal Celeste Lapidado, 1× Escama de Âmbar, 1× Couro Curtido + 560 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Elmo Celeste | 6 | 10 | 2× Cristal Celeste Lapidado, 1× Escama de Âmbar + 640 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Escudo Celeste | 6 | 16 | 3× Cristal Celeste Lapidado, 4× Madeira + 800 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Luvas Celeste | 6 | 8 | 2× Cristal Celeste Lapidado, 1× Escama de Âmbar, 1× Couro Curtido + 560 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Peitoral Celeste | 6 | 23 | 5× Cristal Celeste Lapidado, 2× Escama de Âmbar + 1280 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Botas de Cronóstio | 7 | 11 | 2× Lingote de Cronóstio, 1× Engrenagem Quântica, 1× Couro Curtido + 909 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Elmo de Cronóstio | 7 | 12 | 2× Lingote de Cronóstio, 1× Engrenagem Quântica + 1040 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Escudo de Cronóstio | 7 | 20 | 3× Lingote de Cronóstio, 4× Madeira + 1300 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Luvas de Cronóstio | 7 | 10 | 2× Lingote de Cronóstio, 1× Engrenagem Quântica, 1× Couro Curtido + 909 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Peitoral de Cronóstio | 7 | 29 | 5× Lingote de Cronóstio, 2× Engrenagem Quântica + 2080 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Botas de Adamantium | 8 | 13 | 2× Lingote de Adamantium, 1× Eco de Amanhã, 1× Couro Curtido + 1400 ouro | Gaspar Bigorna (Ferraria do Porto N5) |
| Elmo de Adamantium | 8 | 15 | 2× Lingote de Adamantium, 1× Eco de Amanhã + 1600 ouro | Gaspar Bigorna (Ferraria do Porto N5) |
| Escudo de Adamantium | 8 | 25 | 3× Lingote de Adamantium, 4× Madeira + 2000 ouro | Gaspar Bigorna (Ferraria do Porto N5) |
| Luvas de Adamantium | 8 | 12 | 2× Lingote de Adamantium, 1× Eco de Amanhã, 1× Couro Curtido + 1400 ouro | Gaspar Bigorna (Ferraria do Porto N5) |
| Peitoral de Adamantium | 8 | 35 | 5× Lingote de Adamantium, 2× Eco de Amanhã + 3200 ouro | Gaspar Bigorna (Ferraria do Porto N5) |
| Botas Paradoxal | 9 | 16 | 2× Lingote de Liga Paradoxal, 1× Chip de Anomalia, 1× Couro Curtido + 2240 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |
| Elmo Paradoxal | 9 | 18 | 2× Lingote de Liga Paradoxal, 1× Chip de Anomalia + 2560 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |
| Escudo Paradoxal | 9 | 30 | 3× Lingote de Liga Paradoxal, 4× Madeira + 3200 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |
| Luvas Paradoxal | 9 | 15 | 2× Lingote de Liga Paradoxal, 1× Chip de Anomalia, 1× Couro Curtido + 2240 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |
| Peitoral Paradoxal | 9 | 43 | 5× Lingote de Liga Paradoxal, 2× Chip de Anomalia + 5120 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |

### Bônus de conjunto

| Conjunto | Tier | 3 peças | 5 peças |
|---|---|---|---|
| Conjunto de Cobre | 1 | +5 de vida máxima | +5% de dano de ferramentas na mina |
| Conjunto de Ferro | 2 | +10 de vida máxima | Postura: o primeiro golpe recebido por sala causa -30% |
| Conjunto do Porto | 3 | +15 de vida máxima | Dash 10% mais longo |
| Conjunto Brasa-Velha | 4 | +20 de vida máxima | Fúria do clã: +10% de dano com vida abaixo de 40% |
| Conjunto Tumular | 5 | Imune a dreno de vida vampírico | +15% de dano contra amaldiçoados (soma com a arma) |
| Conjunto Celeste | 6 | +10% de velocidade | Queda suave: não toma dano ao cair de plataformas |
| Conjunto Cronal | 7 | Dash deixa um eco que bloqueia 1 projétil | -15% na recarga do especial |
| Conjunto de Adamantium | 8 | Forma Adamantium dura +5 s | +20% de dano do Raio de Adamantium |
| Conjunto Paradoxal | 9 | Uma segunda chance por mapa (volta 3 s no tempo) | +10% em todos os atributos |

## 6. Acessórios

| Acessório | Tier | Efeito | Valor | Receita | Ferreiro / forja |
|---|---|---|---|---|---|
| Anel de Cobre | 1 | +3 de defesa | 100 | 1× Lingote de Cobre + 50 ouro | Gaspar Bigorna (Ferraria do Porto N1) |
| Amuleto de Raiz-de-Brasa | 2 | Resistência a fogo +20% | 300 | 1× Lingote de Ferro, 1× Essência de Raiz-de-Brasa + 150 ouro | Gaspar Bigorna (Ferraria do Porto N2) |
| Colar Presa-do-Clã | 4 | +6% de dano; os orcs te cumprimentam | 600 | 1× Lingote de Ferro-Brasa, 2× Couro Curtido + 300 ouro | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| Colar de Prata Lunar | 5 | Imune à maldição da lua; +10% contra amaldiçoados | 1200 | 1× Lingote de Prata Tumular, 1× Pelo de Lua, 1× Essência de Orvalho-Lunar + 600 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Anel de Âmbar Dracônico | 6 | Resistência a fogo +40%; Ambarion cobra metade do pedágio | 1800 | 1× Cristal Celeste Lapidado, 2× Escama de Âmbar + 900 ouro | Gaspar Bigorna (Ferraria do Porto N4) |
| Relógio de Bolso Cronal | 7 | -20% na recarga do dash | 3000 | 1× Lingote de Cronóstio, 1× Engrenagem Quântica + 1500 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Brinco de Eco | 7 | +10% de chance de crítico | 3000 | 1× Lingote de Cronóstio, 1× Eco de Amanhã + 1500 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| Coração-Engrenagem | 9 | +25 de vida máxima e regeneração lenta | 8000 | 1× Lingote de Liga Paradoxal, 2× Areia de Ontem + 4000 ouro | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |

## 7. Ferreiros e níveis de forja

### Ferraria do Porto — Gaspar Bigorna (Porto Velho)

| Nível | Nome | Custo | Libera tier | Nota |
|---|---|---|---|---|
| 1 | Forja de barro | 0 ouro | 1 |  |
| 2 | Fornalha de tijolo | 400 ouro + 40× Pedra, 10× Lingote de Cobre | 2 |  |
| 3 | Tanque de têmpera do porto | 1200 ouro + 15× Lingote de Ferro, 30× Madeira | 3 |  |
| 4 | Fole de Ferro-Brasa | 3000 ouro + 8× Lingote de Ferro-Brasa, 10× Couro Curtido | 5, 6 | Krag Martelo-Torto faz o fole; troca entre ilhas. |
| 5 | Bigorna Cronal | 9000 ouro + 6× Lingote de Cronóstio, 2× Engrenagem Quântica | 8 | Comprada da Mestra Ione. Abre o Coração Soterrado e o adamantium. |

### Forja do Clã Brasa-Velha — Krag Martelo-Torto (Vila dos Orcs)

| Nível | Nome | Custo | Libera tier | Nota |
|---|---|---|---|---|
| 1 | Bigorna de basalto | 0 ouro | 4 | Confiança do clã (Grusha Dente-de-Ferro) |
| 2 | Poço de lava domado | 2500 ouro + 12× Lingote de Ferro-Brasa, 60× Pedra | 4 | Libera reforja +3 em equipamento orc. |

### Forja Quântica (Fabricador) — Mestra Ione Têmpera (Estação Depois-de-Ontem)

| Nível | Nome | Custo | Libera tier | Nota |
|---|---|---|---|---|
| 1 | Fabricador ligado | 0 ouro | 7 |  |
| 2 | Núcleo paradoxal | 15000 ouro + 4× Lingote de Adamantium, 10× Chip de Anomalia | 9 |  |

**Quem forja o quê:** tiers 1–3 Gaspar (N1–N3) · tier 4 Krag (Forja do Clã) · tiers 5–6 Gaspar N4 (fole feito pelo Krag) · tier 7 Mestra Ione (Forja Quântica N1) · tier 8 Gaspar N5 (Bigorna Cronal comprada da Ione) · tier 9 Forja Quântica N2.

## 8. Mecânicas

### Fundição

| Receita | Resultado | Materiais | Ouro | Onde |
|---|---|---|---|---|
| fundir_cobre | 1× Lingote de Cobre | 3× Minério de Cobre, 1× Carvão | 5 | Gaspar Bigorna (Ferraria do Porto N1) |
| fundir_ferro | 1× Lingote de Ferro | 3× Minério de Ferro, 1× Carvão | 10 | Gaspar Bigorna (Ferraria do Porto N2) |
| ligar_aco_porto | 1× Lingote de Aço do Porto | 2× Lingote de Ferro, 2× Carvão | 25 | Gaspar Bigorna (Ferraria do Porto N3) |
| fundir_ferro_brasa | 1× Lingote de Ferro-Brasa | 3× Minério de Ferro-Brasa, 1× Carvão | 30 | Krag Martelo-Torto (Forja do Clã Brasa-Velha N1) |
| fundir_prata_tumular | 1× Lingote de Prata Tumular | 3× Prata Tumular Bruta, 1× Carvão, 1× Essência de Orvalho-Lunar | 45 | Gaspar Bigorna (Ferraria do Porto N4) |
| lapidar_cristal_celeste | 1× Cristal Celeste Lapidado | 2× Cristal Celeste Bruto | 50 | Gaspar Bigorna (Ferraria do Porto N4) |
| fundir_cronostio | 1× Lingote de Cronóstio | 3× Minério de Cronóstio, 1× Chip de Anomalia | 120 | Mestra Ione Têmpera (Forja Quântica (Fabricador) N1) |
| fundir_adamantium | 1× Lingote de Adamantium | 3× Veio de Adamantium, 2× Carvão, 1× Pó de Segundo | 200 | Gaspar Bigorna (Ferraria do Porto N5) |
| ligar_liga_paradoxal | 1× Lingote de Liga Paradoxal | 1× Lingote de Adamantium, 2× Lingote de Cronóstio, 1× Eco de Amanhã | 500 | Mestra Ione Têmpera (Forja Quântica (Fabricador) N2) |

### Reforja (+1 a +3)

| Nível | Bônus no atributo | Lingotes do tier | Ouro (fração do valor) | Extra |
|---|---|---|---|---|
| +1 | +10% | 1 | 20% | — |
| +2 | +20% | 2 | 40% | — |
| +3 | +35% | 3 | 70% | 1× Pó de Segundo |

Reforja na mesma forja que fez o item (ou superior). +3 em itens orc só na Forja do Clã nível 2.

### Encantamento

1 encanto por item. Trocar o encanto destrói o anterior. Mira encanta na Botica; Ozório na Torre Torta; a Dra. Mira de Depois aplica os dois tipos no Laboratório, com efeito x1,5. Custo: 40 ouro × tier do item + 1 essência.

- **Essência de Raiz-de-Brasa** — Golpes queimam (+6% dano ao longo de 2 s). (fornecedor: mira)
- **Essência de Orvalho-Lunar** — +25% de dano contra amaldiçoados (vampiros, lobisomens, espectros). (fornecedor: mira)
- **Essência de Musgo-Sereno** — Regenera 1 de vida a cada 4 s fora de combate. (fornecedor: mira)
- **Pó de Segundo** — -12% na recarga do dash. (fornecedor: arquimago)
- **Areia de Ontem** — Cura 1 de vida a cada 5 acertos. (fornecedor: arquimago)
- **Eco de Amanhã** — +8% de chance de crítico (dano x1,5). (fornecedor: arquimago)

## 9. Tabela de balanceamento

Fórmulas: multiplicador de dano = `1 + ataque/25` (aplicado em `jogador_combate.multiplicador_dano`); dano recebido = `dano * 100 / (100 + defesa_total)`. Referência do combate atual: combo 10/12/24 (46 por combo), Vale 100 de vida, orc 60 de vida e 14 de dano.

| Tier | Melhor arma (ataque) | Mult. | Dano do combo | Combos p/ orc (60) | Defesa do conjunto (5 peças) | Dano do orc (14) recebido | Golpes do orc p/ derrubar Vale (100) |
|---|---|---|---|---|---|---|---|
| 1 | Espada de Cobre (5) | 1.20 | 55 | 1.1 | 10 | 12.7 | 8 |
| 2 | Lança de Ferro (10) | 1.40 | 65 | 1.0 | 17 | 12.0 | 9 |
| 3 | Espada de Aço do Porto (14) | 1.56 | 72 | 0.9 | 28 | 10.9 | 10 |
| 4 | Martelo Martelo-Torto (27) | 2.08 | 96 | 0.7 | 40 | 10.0 | 10 |
| 5 | Espada de Prata Tumular (26) | 2.04 | 93 | 0.7 | 52 | 9.2 | 12 |
| 6 | Lança Celeste (34) | 2.36 | 109 | 0.6 | 66 | 8.4 | 13 |
| 7 | Lâmina de Cronóstio (40) | 2.60 | 119 | 0.6 | 82 | 7.7 | 13 |
| 8 | Espada de Adamantium (50) | 3.00 | 138 | 0.5 | 100 | 7.0 | 15 |
| 9 | Martelo Paradoxal (70) | 3.80 | 175 | 0.4 | 122 | 6.3 | 17 |

> Inimigos de tiers altos devem escalar vida/dano junto (sugestão: vida do orc × 1,6 por tier) — senão o tier 9 vira trivial.

## 10. MVP (primeira fatia)

Primeira fatia: só Porto Velho + Minas da Cinza (andares 1-12) + Gaspar Bigorna (forja nível 1-3).

- Materiais: Minério de Cobre, Minério de Ferro, Carvão, Lingote de Cobre, Lingote de Ferro, Lingote de Aço do Porto, Madeira, Couro Curtido
- Receitas: `fundir_cobre`, `fundir_ferro`, `ligar_aco_porto`, `forjar_espada_cobre`, `forjar_espada_ferro`, `forjar_espada_aco`, `forjar_picareta_cobre`, `forjar_picareta_ferro`, `forjar_peitoral_cobre`, `forjar_peitoral_ferro`, `forjar_escudo_ferro`, `forjar_anel_cobre`
- Mecânicas: fundir, forjar, reforja +1, subir forja para nível 2 e 3

## 11. Peças de equipamento da PixelLab

Todo item tem `arte_pixellab: null` no JSON, pronto para receber o caminho do sprite. As 5 peças geradas na PixelLab **não estão no clone** (LIMIAR-LAB/Bolorina @96314ad); só existe a forma `experimental_adamantium_v99` do combate, que casa com o **Conjunto de Adamantium (tier 8)**. Mapeamento sugerido assim que as peças aparecerem: elmo → `elmo_<tier>`, peitoral → `peitoral_<tier>`, luvas → `luvas_<tier>`, botas → `botas_<tier>`, escudo → `escudo_<tier>` do tier cujo visual combinar (preencher `arte_pixellab` em `tools/forja_gerar_dados.py` e regenerar). Nenhum crédito pago foi usado.

## 12. Como usar no código

```gdscript
const Forja = preload("res://scripts/forja/forja.gd")
var f = Forja.new()                        # carrega data/forja/*.json
var inv := {"ouro": 200, "itens": {"minerio_cobre": 9, "carvao": 3}}
var niveis := {"ferraria_porto": 1}
if f.pode_fazer("fundir_cobre", inv, niveis, 3).ok:
    f.fazer("fundir_cobre", inv, niveis, 3)
f.pode_minerar("minerio_ferro", "picareta_cobre")  # true: nível 1 ≥ mínimo 1
```

Testes: `godot --headless --path . -s res://tests/forja_testes.gd`.

