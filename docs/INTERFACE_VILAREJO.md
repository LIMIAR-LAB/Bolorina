# Interface do vilarejo — 20/10/2026

Base: origin/main 354d3b4 (PR #3, inventário e baú). Branch local: codex/interface-vilarejo-atual.

## Entrega

Tema nativo Godot com molduras de bronze, painéis carvão, faixas de madeira, slots em pergaminho, abas douradas e fonte Georgia. Aplicado ao inventário, equipamento, fabricar, baú, forja, diálogos, balcões e mapa. As onze abas usam a mesma estrutura. As funções e os atalhos existentes foram mantidos.

O inventário mostra no mínimo 60 espaços visuais, sem criar itens nem capacidade artificial. Grades maiores continuam rolando. O baú conserva seus 36 espaços, transferência de unidades/pilhas/metades, ordenar e guardar iguais. Equipamento mantém a prévia animada, rotação, comparação e composição do mesmo personagem usado no mundo e combate.

A arte `art/ui/vilarejo/clareira.png` é um fundo ilustrado original gerado nesta sessão para a prévia. Personagem, textos, itens e botões são elementos reais do jogo. Os SVGs são originais e gerados por `tools/ui_vilarejo_assets.py`; nenhum texto funcional foi rasterizado. Nenhum crédito PixelLab/Meshy foi utilizado.

Foram trazidas as correções locais anteriores das camadas do equipamento e a dependência de aparência, necessárias para manter a prévia e a composição atualizadas. Sprites originais, main.tscn, reference_village e CronosMemories não foram editados. A integração canônica de mapas, forja e baús foi preservada.

## Validação

- Inventário e baú: 90/90.
- Equipamento: 97/97, inclusive mundo/combate e saves reais intactos.
- Forja: 85/85.
- Conferência visual em 1600×900 e 1280×720, sem corte das abas ou painéis.
- Capturas de todas as categorias principais, equipamento animado, fabricar e baú em `docs/interface/`.
- Capturas no Porto Velho real, mapa, conversa, balcão e forja em `docs/interface/mundo-*.png`.

A verificação antiga que exigia exatamente uma célula por item foi atualizada para o contrato de no mínimo 60 células visuais. O modelo de itens não mudou.

O Godot ainda emite avisos de UIDs herdados (resolve pelo caminho) e de recursos retidos ao encerrar alguns testes. Não houve erro de script nos fluxos finais capturados. Não houve alteração de main ou push.

## Testar

Execute `Jogar-interface.ps1`. O iniciador usa `ilha_interface_preview.json`, copiando o save principal apenas na primeira execução. O progresso real não é alterado. I abre o inventário na última aba; B abre Tudo; Tab alterna abas; E abre um baú próximo. A pasta está preparada para abrir `jogo_ilha.tscn` no editor também.

Backups dos arquivos anteriores: `work/backups/interface-atual/` (locais, não versionados).
