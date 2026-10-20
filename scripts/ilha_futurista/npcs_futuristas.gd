extends RefCounted
## Moradores da Estação Depois-de-Ontem (ilha futurista). PROPOSTA, não é canon.
## Lido por scripts/dialogos/npcs_registro.gd (bloco FUTURISTAS), então os marcadores da ilha
## viram moradores pelo mesmo InteracaoNpcs.spawn_em_marcadores dos outros mapas.
## "modelo" (opcional): modelo 3D CC0 que substitui o boneco provisório (ver ilha_futurista.gd).

const NPCS := {
	"fabricadora": {"nome": "Mestra Ione Têmpera", "titulo": "Fabricadora-chefe · Forja Quântica", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "e0604a"},
	"mercador_temporal": {"nome": "Zé Antes-Depois", "titulo": "Mercador do Tempo · Praça dos Segundos", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "d4b23a"},
	"robo_lobisomem": {"nome": "L-0B0", "titulo": "Robô de carga (lobisomem, segundo ele)", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "6a8aa8",
		"modelo": "quaternius_scifi_essentials/Enemy_QuadShell.gltf", "escala_modelo": 0.75},
	"cientista_mira": {"nome": "Dra. Mira de Depois", "titulo": "Botânica temporal · Laboratório de Anomalias", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "8a3fb5"},
	"drone_zelador": {"nome": "Z-12", "titulo": "Drone zelador de paradoxos", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "3ab8c8",
		"modelo": "quaternius_scifi_essentials/Enemy_EyeDrone.gltf", "escala_modelo": 0.7, "flutua": 1.3},
	"fiscal_linhas": {"nome": "Agente Vera Bis", "titulo": "Fiscal das Linhas do Tempo", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "2a4a8a"},
	"minerador_fenda": {"nome": "Bento Picareta-Quântica", "titulo": "Minerador · Veio da Fenda", "regiao": "Estação Depois-de-Ontem", "arte": "", "cor": "a86a2a"},
}
