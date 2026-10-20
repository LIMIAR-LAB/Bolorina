# Arte da madrugada: Ilha das Cinzas

Tudo aqui é arquivo novo. Nada foi editado no projeto, não houve commit nem push e nenhum serviço pago foi usado.
As imagens foram geradas com o gerador de imagens do Grok Bot e tratadas em Python/Pillow.

## O que tem no pacote (caminhos relativos à raiz do repositório)

| Pasta | Conteúdo | Tamanho |
|---|---|---|
| `art/ui/retratos/<id>.png` | 30 retratos chibi em busto, um por morador | 128×128 (grade de 64×64 px ampliada 2× em nearest), 32 cores, fundo escuro quente opaco |
| `art/ui/icones_forja/<id>.png` (movidos na integração de 20/10) | 24 ícones de minério, lingote e equipamento inicial | 32×32, fundo transparente, até 16 cores |
| `art/ui/telas/<area>.png` | 6 ilustrações para mapa-múndi e telas de carregamento | 1280×720, 128 cores |
| `art/ui/telas/<area>_640x360.png` | as mesmas, reduzidas para pixel art | 640×360, 96 cores |
| `docs/arte_noite/previews/` | folhas de contato de cada categoria | — |
| `docs/arte_noite/PROMPTS.md` | modelo de prompt e prompt de cada imagem | — |
| `tools/arte_noite/*.py` | scripts de tratamento (recorte, nearest, quantização, recorte das folhas de ícones) | — |

Os originais em alta resolução (JPG de 1024×1024 e 1280×720) e as versões rejeitadas estão no zip separado `arte_noite_fontes.zip`, em `_fontes/`. Esse zip não vai para dentro do projeto.

## Retratos (ids iguais aos de `scripts/dialogos/npcs_registro.gd`)

- **Os 12 principais:** mira, jardineira, guardia, sineiro, ferreiro, estalajadeira, arquimago, capitao, lider_orc, condessa, lobisomem, dragao
- **Os 18 genéricos:** mercador_praca, morador_1, morador_2, crianca_praca, gato, xama_orc, ferreiro_orc, guerreiro_orc_1, guerreiro_orc_2, cacadora_orc, anciao_orc, prisioneiro, espectro_sineiro, eco_arquimago, mercador_reliquias, coveiro, vampiro_menor_1, espectro_1

A Mira já tinha retrato, um recorte do sprite. Fiz um novo no mesmo molde para ela combinar com os outros. Usar ou não fica a seu critério.

### Como a caixa de diálogo escolhe o retrato hoje

- `scripts/dialogos/caixa_dialogo.gd`, linha ~75: `retrato.texture = Registro.retrato(id)`, ou `Registro.retrato_vale()` quando quem fala é a Vale.
- `Registro.retrato(id)` (`npcs_registro.gd`) faz assim:
  1. Se o morador tem `"arte"`, recorta a cabeça de `res://art/characters/<arte>/rotations/south.png` com um AtlasTexture.
  2. Se não tem, gera um busto provisório de 32×32 na cor do morador.
- Onde aparece: `TextureRect` de 160×160 (`EXPAND_IGNORE_SIZE`, `STRETCH_KEEP_ASPECT_CENTERED`, `TEXTURE_FILTER_NEAREST`) dentro de uma moldura de 176×176.

**Os PNGs novos ainda não estão ligados.** Não mexi em `npcs_registro.gd` porque o Claude pode estar editando. Para ligar, basta colocar isto no começo de `retrato(id)`:

```gdscript
var arquivo := "res://art/ui/retratos/%s.png" % id
if ResourceLoader.exists(arquivo):
    return load(arquivo)
```

**Dica de nitidez:** 128 px dentro de um TextureRect de 160 dá uma escala de 1,25×, e aí os pixels saem desiguais. Para pixels perfeitos, use o TextureRect com 128×128 ou 256×256, ou seja, múltiplos de 64.

## Ícones (ids de `data/forja/materiais.json` e `itens.json`, rascunho do trabalho da forja)

- **Minérios:** minerio_cobre, minerio_ferro, minerio_ferro_brasa (orc), minerio_prata_tumular, cristal_celeste_bruto, minerio_cronostio (futurista), minerio_adamantium, carvao
- **Lingotes:** lingote_cobre, lingote_ferro, lingote_ferro_brasa, lingote_prata_tumular, cristal_celeste (lapidado), lingote_cronostio, lingote_adamantium, lingote_aco_porto
- **Equipamento inicial (cobre, tier 1):** espada_cobre, escudo_cobre, elmo_cobre, peitoral_cobre, luvas_cobre, botas_cobre, picareta_cobre, adaga_cobre

Os ícones da fazenda (`art/ui/icones_fazenda`) têm 16×16. Estes têm 32×32, então mostre-os em 1× ou 2× (nearest) para ficarem no mesmo tamanho de tela.

## Telas (`art/ui/telas/`)

porto_velho, vila_orcs, cidade_fantasma, minas_da_cinza, ilha_do_tempo (a ilha futurista neon que caiu do futuro), arena_das_cinzas

Nenhuma tem texto, logo ou personagem real. O título de cada área pode ser escrito por cima no Godot, com a fonte Pixelify.

## Como foi feito

1. **Retratos:** gerei em 1024×1024 usando o sprite da Mira (ampliado 8×) como referência de estilo, sempre com o mesmo modelo de prompt (ver PROMPTS.md). Depois cortei 4% da borda, reduzi para 64×64 em nearest, quantizei para 32 cores sem dithering e ampliei 2× em nearest.
2. **Ícones:** gerei folhas 2×2 sobre verde chroma, recortei cada quadrante pela caixa do objeto, removi o verde e tirei o reflexo verde das bordas. Depois reduzi para 30×30 em nearest, quantizei para 16 cores e centralizei numa tela de 32×32 transparente.
3. **Telas:** gerei em 1280×720. A versão de 640 foi reduzida com Lanczos e quantizada para 96 cores (octree).
