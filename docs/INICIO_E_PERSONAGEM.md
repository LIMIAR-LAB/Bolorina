# Início, partidas e personagem — 20/10/2026

## Fluxo implementado

O jogo agora abre `inicio.tscn`: Novo jogo, Carregar jogo, Configurações e Sair. Novo jogo leva ao criador com nome do personagem, nome da fazenda, tons de pele, cor do cabelo, roupa e calça. A prévia usa os quadros reais, oito direções, corrida/repouso e teste de armadura + elmo ou couro + capuz. O teste de equipamento não concede os itens à partida.

A aparência fica em `extras.aparencia` no mesmo estado usado na exploração e no combate. O gerenciador aplica o perfil antes das camadas de equipamento. Não há um segundo conjunto de sprites do jogador. Novos cortes de cabelo e tipos de corpo ainda não foram produzidos: esta entrega oferece o penteado base e personalização por cores.

Cada nova partida grava `user://partida_<timestamp>.json`, com sufixo em caso de colisão. Não substitui saves existentes. Carregar lista essas partidas e os dois saves anteriores identificados (save anterior / cópia de testes). Arquivos de teste, capturas e outros protótipos não entram na lista. Nome, fazenda, dia, ouro e região ajudam a escolher.

`Esc` abre a pausa, com Continuar, Configurações e Salvar e voltar ao início. Ao carregar, o personagem retorna à entrada da última região salva; a posição exata no terreno ainda não é persistida. Inventário, diálogo e mapa continuam consumindo Esc antes da pausa quando abertos.

Configurações: volume geral, tela cheia e sincronização vertical, persistidos em `user://configuracoes.cfg`. Os atalhos principais aparecem nessa tela. Tanto o projeto quanto `Jogar-interface.ps1` e `Jogar-ilha.ps1` apontam para o menu inicial desta cópia.

## Equipamentos revisados

A revisão derivada `art/characters/vale_trajes/correcao_v3/` substitui a v2 na composição. A coroa do elmo acompanha a posição da cabeça nos quadros de corrida, corrigindo deslocamentos da âncora anterior. Foram reduzidos realces quase brancos e removidas ilhas de pixels que não encostavam no corpo. As folhas de combate também recebem a limpeza de material/silhueta, preservando os efeitos da arte base.

Nada foi editado nos sprites originais. O processo é reproduzível por `tools/equipamento_revisao_v3.py`; as fontes e a v2 ficam preservadas. As imagens antes/depois em `docs/avatar/diagnostico-*.png` mostram corrida sul/leste com armadura e elmo.

## Verificação

- Fluxo de início/personagem: 28/28, incluindo configurações persistidas, nomes vazios, partidas distintas, aparência real no mundo e combate, carregar progresso e pausa/retomar e salvar/voltar ao menu.
- Equipamento: 97/97.
- Inventário e baú: 90/90.
- Inspeção automatizada de 275 imagens derivadas: dimensões compatíveis e alfa binário; realces neutros quase brancos nas camadas de equipamento passaram de 6.145 para zero.
- Integridade de 200 arquivos originais conferida por hash.
- Capturas nativas: início, carregar, configurações, criador e criador com armadura em `docs/avatar/`.
- Saves reais preservados nas verificações. Testes criam e apagam partidas próprias.

Os avisos herdados do Godot sobre UIDs e recursos retidos ao encerrar testes continuam registrados em `work/`. As execuções finais não tiveram erros de script. Mudanças locais, sem push/merge. `main.tscn` e reference_village não foram alterados.
