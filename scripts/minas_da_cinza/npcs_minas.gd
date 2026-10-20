extends RefCounted
## Moradores das Minas da Cinza (PROPOSTA, não é canon).
## Lido por scripts/dialogos/npcs_registro.gd (bloco MINAS), então os marcadores dos andares
## viram moradores pelo mesmo InteracaoNpcs.spawn_em_marcadores dos outros mapas.
## "modelo" (opcional): modelo 3D CC0 no lugar do boneco provisório (ver minas_da_cinza.gd).
## "fantasma": deixa o boneco translúcido e flutuando. "glitch": o boneco "pula" no tempo.

const NPCS := {
	"minerador_aposentado": {"nome": "Seu Tião Lamparina", "titulo": "Mineiro aposentado · Elevador da cisterna", "regiao": "Minas da Cinza", "arte": "", "cor": "b07a3a"},
	"fantasma_mineiro": {"nome": "Zeca Sem-Volta", "titulo": "Mineiro fantasma, perdido desde a Queda", "regiao": "Minas da Cinza", "arte": "", "cor": "7a9ab8", "fantasma": true},
	"mercador_minerio": {"nome": "Quinquilho do Talvez", "titulo": "Negociante de minério (de hoje, de ontem, de talvez)", "regiao": "Minas da Cinza", "arte": "", "cor": "6a8a3a", "escala_visual": 0.72, "glitch": true},
	"vagoneta_falante": {"nome": "Dona Vagoneta", "titulo": "Vagoneta falante dos trilhos", "regiao": "Minas da Cinza", "arte": "", "cor": "8a6a4a",
		"modelo": "kenney_train_kit/train-carriage-coal.glb", "escala_modelo": 0.62},
}
