# Relatório da madrugada (20/10/2026) — branch `noite-2026-10-20`

Trabalho local, sem push, sem merge, sem créditos pagos. Backups em `work/backups/noite/`.
Testes headless: `work/noite_logs/suites.ps1 -Etapa <nome>` (logs em `work/noite_logs/<etapa>/`).

## Antes da noite (referência)
Estado commitado como "Estado antes da noite" (`ce2bbd3`), já com a Vale única e as peças do PixelLab.
Equipamento 79/79 · combate 53/54 (falha antiga do `.import` do vale_combate_gamelab) · fazenda_terra 19/20 (falha antiga:
terra arada sem mato) · demais suítes 100%.

## Etapa 0 — entregas da Bolorina
**Pulada.** Os zips `ilha_entrega_1..4` não estão na máquina (procurei no projeto, Documentos, Downloads, Desktop e D:).
Não existem `scenes/`, `dialogos/` nem o addon Dialogue Manager. O registro de áreas já aponta para as cenas que eles
trazem (`scenes/vila_grande.tscn`, `scenes/vila_orcs.tscn`, `scenes/cidade_fantasma.tscn`): quando chegarem, aparecem
no mapa e no teleporte sem mexer em código.

## Etapa 1 — mapa-múndi + teleporte
- **Mapa "bonito"**: não achei nenhuma versão pintada anterior (git tem só o commit inicial; procurei em `art/ui`,
  `docs`, `work/`, release e zips). O jogo previa `art/ui/mapa_mundi_arte.png` (arte do usuário) que nunca existiu.
  Fiz um mapa pintado novo por código, `tools/mapa_mundi_pintado.py` → `art/ui/mapa_mundi_pintado.png` (1200×800):
  relevo sombreado, serra com neve, floresta, rio, névoa da Cidade Fantasma, ilhota dos orcs, ilha flutuante, trilhas
  e selos por área. O esquemático (`mapa_esquematico.png`) continua intacto e é o reserva. Ordem: arte do usuário >
  pintado > esquemático.
- **Registro único**: `data/areas.json` + `scripts/mundo/registro_areas.gd` (id, nome, cena, chegada, posição no
  mapa, bioma, descrição). Áreas: fazenda, vila, arena, masmorra, Porto Velho, Vila dos Orcs, Cidade Fantasma, Minas da
  Cinza, Ilha Futurista. Área sem cena = "em breve" (desligada no mapa).
- **Teleporte**: M abre o mapa; ◀ ▶/Tab escolhe, Enter ou clique viaja (`jogo_ilha.gd → viajar(id)`). Área nova do
  registro carrega por uma rota genérica (instancia a cena, passa `estado`/`gerenciador`, chama `nascer(chegada)`).
- **Chegada e volta**: cada área ganha uma **pedra de viagem** (cristal azul) no ponto de chegada
  (`scripts/mundo/pedra_viagem.gd`); perto dela, **T** abre o mapa no modo viagem.
- **Teste**: `tests/mundo_areas_testes.gd` 19/19 (registro, mapa com todas as áreas, em breve recusado, entra e sai de
  fazenda → vila → arena → masmorra → fazenda, pedra em cada uma, T abre o modo viagem, save real intacto).
- Suítes depois da etapa: iguais às de antes (equipamento 79/79, combate 53/54, fazenda_terra 19/20, resto 100%).
