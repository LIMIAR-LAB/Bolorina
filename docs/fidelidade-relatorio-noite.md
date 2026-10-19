# Relatório da noite — Fidelidade da vila V7 (Fases 2–5)
Data: 19/10/2026 (madrugada, horário de Brasília). Cena: `fidelity_village.tscn`, com `modo: "v7"` em `docs/fidelidade-camera.json`.
A pontuação usa a mesma ferramenta da Fase 1 (`tools/fidelidade_pontuacao.py`): composição 40% (checklist de 60 itens), cor/luz 30% (ΔE Lab + histograma L* numa grade 8×6), detalhe 20% (Sobel) e avaliação do usuário 10% (**pendente**; o total abaixo é o "total sem avaliação").

## Pontuação por fase
| Fase | Total | Composição | Cor/Luz | Detalhe | Checklist (P/Q/A) |
|---|---|---|---|---|---|
| 1 — base V6 | 55,2 | 46,1 | 61,2 | 64,3 | — |
| 2 — layout modular | 45,0 | 51,3 | 54,7 | 18,0 | ver json fase2 |
| 3 — fundo / bordas | 55,7 | 65,2 | 60,7 | 28,9 | ver json fase3 |
| 4 — luz / paleta | 63,3 | 66,5 | 67,7 | 50,3 | ver json fase4 |
| 5 — props / textura | 69,0 | 73,5 | 68,7 | 60,4 | 28/29/3 |
| 5b — ajustes | **70,3** | 75,7 | 69,1 | 61,3 | 30/30/0 |
| 5c — tentativa | 70,0 | — | — | — | revertida |
| Recaptura final (estado 5b) | 70,0 | 75,7 | 68,9 | 60,3 | 30/30/0 (68,0 com avaliação neutra 0,5) |

As partículas fazem a pontuação variar cerca de ±0,3 entre capturas.
Na Fase 2 a nota caiu porque o chão novo ficou liso (o detalhe despencou para 18); as Fases 3–5 recuperaram isso.

### Tentativas da Fase 4
LUT manual: 50,0 (ficou magenta). Sem LUT: 54,0. LUT calibrada por histograma (iteração 1): 60,9. LUT iteração 2 + DOF 0,03: 62,7, ou 63,3 com o checklist da fase 4.
### Tentativas da Fase 5
Filtro pixel: 68,1 contra 69,0 sem ele, e 69,4 contra 70,0 na versão com contorno, por isso ficou **desligado** por padrão. Cores mais escuras e LUT3 (5c): 70,0, sem ganho, então **voltei ao estado 5b** (backup em `work/backup_fase5`).

## Gate: platô atingido
5b ganhou +1,3 e 5c perdeu 0,3: foram duas tentativas seguidas com ganho abaixo de ~1,5. **Parei o trabalho de fidelidade.** Melhor nota: 70,3; recaptura final: 70,0. **Não chegou a 90.**
Maiores lacunas restantes (itens parciais de peso 3 do checklist): a vila não preenche a tela toda; ruínas; penhascos com névoa; luz de entardecer quente; aspecto de pixel art; densidade. Por região: falta detalhe no canto inferior esquerdo e o canto superior direito está escuro demais.

## O que mudou em cada fase
- **Fase 2 — layout:**
  - nova câmera V7 (ortográfica, yaw 50°, pitch 28°, size 20, ajustada pelas bordas do campo lavrado da referência);
  - layout escrito em pixels da referência e convertido para o mundo (`tools/fidelidade_mapa.py`, `tools/fidelidade_layout.py`), resultando em `scripts/modular/vila_layout.json` com 136 peças;
  - terreno com pesos nas cores dos vértices (`fid_terreno`), rio em fita com o shader `fid_agua`;
  - kit modular (`kit_modular.gd`) com peças de construção, cerca, luz, decoração e cultivo.
  - O mundo foi deslocado (DELTA -4,67/-7,0) para o rio e a ponte coincidirem com as restrições de movimento já existentes em `island.gd`.
- **Fase 3 — fundo/bordas:** borda do platô que desce para o abismo (h −30); 4 camadas de névoa; colunas de rocha e arcos distantes; cachoeira com saliência; ruínas (arcos e pilares afunilados); moldura de arbustos nas bordas; árvores e rochas.
- **Fase 4 — luz/paleta:** sol quente de golden hour vindo do alto à esquerda (energia 1,7); ambiente índigo `6c6aa3` (0,5); LUT de cor calibrada por histograma; saturação e exposição; sombras de contato; efeitos de fogo, orvalho, vaga-lumes e DOF.
- **Fase 5 — props/textura:** barris, caixote, bancos, mesa, cogumelos e deck; MultiMesh de tufos, flores e lajes de pedra; corvos extras; brilhos especulares e emissivos na água (5b).

## Efeitos (todos alternáveis)
| Tecla | Efeito |
|---|---|
| 1 | grade de cor (sol quente + LUT + ambiente índigo) |
| 2 | orvalho: 900 partículas de 1–3 px, brancas, diagonal do canto superior direito para o inferior esquerdo, sem brilho |
| 3 | vaga-lumes (46) + orbes ciano (7) com bloom aditivo |
| 4 | fogo cintilante + faíscas (braseiro, lampiões, fumaça das chaminés) |
| 5 | vento na folhagem (shader `fid_folhagem`) |
| 6 | água: normais rolando, especular, espuma, brilhos |
| 7 | DOF tilt-shift leve (CameraAttributesPractical, intensidade 0,03) |
| 8 | sombras de contato (blobs) |
| 9 | filtro pixel (desligado por padrão) |
| 0 | névoa |
Abaixo da fase 4 só vento, água e névoa ficam ligados. `efeitos_off: true` no config, ou a variável de ambiente `FID_EFEITOS_OFF=1`, desliga tudo. A tecla O continua mostrando a referência.

## Desempenho (`tests/fidelity_perf.gd`, notebook "alien")
| Fase | GPU ms (efeitos ligados) | GPU ms (desligados) | Draw calls |
|---|---|---|---|
| 2 | 3,82 | 3,87 | 1602 |
| 3 | 4,43 | 4,45 | 2242 |
| 4 | 5,13 | 4,44 | 2083 |
| 5 | 5,58 (CPU 5,36) | 5,31 | 2289 |
| V6 original | 9,58 (CPU 2,72) | — | 1292 |
Os efeitos custam cerca de +0,3 a 0,7 ms de GPU. As draw calls estão altas por causa das muitas malhas de caixa individuais; vale juntar em MultiMesh ou mesclar malhas no futuro.

## Testes
- `tests/fidelity_capture.gd`: 6/6.
- `tests/reference_village.gd` (V6): 47/47.
- `tests/fidelity_mechanics.gd` (novo): **9/9**. Cobre modo V7, 136 peças, encaixe na grade de 1 m, 24 recursos marcados, plantar e regar na horta, árvore cai com 3 golpes, tecla 2 e tecla O. O teste falhava antes porque esperava poucos quadros entre os golpes, menos que a recarga de 0,5 s do machado; agora usa um timer de 0,6 s. A mecânica em si não foi alterada.
- `main.tscn` não foi alterado (hash 9277F464F494). `reference_village.tscn` também não foi editado.

## Limitações e ressalvas
- O checklist de composição é subjetivo (avaliado por mim), e a avaliação do usuário (10%) está pendente.
- A LUT foi calibrada a partir da própria imagem de referência, o que tende a inflar a nota de cor/luz. Fica em `scripts/modular/lut_fidelidade.png` e é carregada com `Image.load_from_file`.
- As restrições de movimento de `island.gd` (disco e faixa do rio) foram contornadas pelo layout. Não verifiquei se existem paredes invisíveis na borda do abismo.
- Draw calls altas; variância de ±0,3 por causa das partículas; filtro pixel desligado.
- PixelLab: **0 gerações usadas.** Não usei Meshy nem Gamelab, e não toquei na pasta `art/characters/vale_combate_gamelab/`.

## Arquivos
- Novos:
  - `scripts/modular/` (`kit_modular.gd`, `vila_modular.gd`, `efeitos_fidelidade.gd`, `vila_layout.json`, `lut_fidelidade.png`);
  - `shaders/fid_*.gdshader`;
  - `tools/fidelidade_{mapa,layout,lut,checklist}.py`;
  - `tests/fidelity_{perf,mechanics,probe}.gd`;
  - `docs/modulos.md`, este relatório.
- Capturas:
  - `docs/fid-v7-fase{2,3,4,5}.png`, `fid-v7-f5b.png`, `fid-v7-final.png`, `fid-v7-final-sem-efeitos.png`;
  - os `-lado-a-lado.png`, `-mapa-calor.png` e `-pontuacao.json` de cada captura;
  - `fid-efeitos-recortes.png`, `fid-efeitos-liga-desliga.png`, `fid-perf-fase*.json`, `fidelidade-checklist-*.json`.
- Modificados: `scripts/fidelity_village.gd`, `tests/fidelity_capture.gd`, `docs/fidelidade-camera.json`, `tools/fidelidade_pontuacao.py`.
- Backups: `work/backup_fase2`, `work/backup_fase5`, `work/backup_docs_v6`, `work/lut_iter1.png`, `work/lut_iter2.png`.
