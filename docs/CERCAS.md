# Cercas modulares (V7)

Sistema data-driven em `scripts/modular/cercas.gd`, configurado por JSON
(`vila_cercas.json` na vila, `scripts/ilha/fazenda_cercas.json` na fazenda).

- Polilinhas em arestas de celula (postes em x.5 / z.5), subdividas em vaos de 1 m.
- Postes em cada no (cantos e portoes mais grossos, com chapeu); enterrados 0,15 m.
- Duas travessas (y 0,4 / 0,8) seguindo a inclinacao do terreno.
- Portao: folha aberta (~100°) sem colisao; o restante do vao tem StaticBody (meta `cerca`).
- Flag `cercas_v1: true` em `fidelidade-camera.json` / `FID_CONFIG_EXTRA` volta as pecas antigas.

Teste automatico: `tests/vila_travamento.gd` (grade, postes, vaos, portoes, rotas).
