extends Node3D
## Alvo falso usado pela navegação dos inimigos da masmorra: inimigo_orc.gd persegue "alvo";
## quando a jogadora está atrás de uma parede, o alvo vira esta isca colocada na direção da
## próxima curva do caminho do navmesh (a lógica de ataque do orc continua intacta).
var estado := "livre"
