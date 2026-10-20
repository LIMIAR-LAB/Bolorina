extends "res://scripts/actor_visual.gd"
## Vale V6 coerente para a vila de fidelidade (nao altera a V6 original).
## Diagnostico (medido em art/characters/original_vale_v6):
##  - walk/ (= walking/) traz um corpo diferente, mais magro e baixo (cabeca/altura ~0,47
##    contra ~0,57 de idle/run): era o "personagem antigo" que aparecia ao andar;
##  - rotations/ (idle) desenha o mesmo corpo com 48 px de altura, as animacoes com ~45 px.
##    Com pixel_size unico, parar/andar/agir mudava a altura em tela (48 -> 41 px = -15%).
## Correcao: andar usa os quadros de run (mesmo corpo, fps menor) e cada familia de animacao
## e normalizada pela altura de referencia do corpo em pe (idle 48 px, demais 45 px).
## Vale unica (20/10/2026): a arte da vila/fazenda/masmorra agora e o desenho do combate (Gamelab, sem espada),
## art/characters/vale_unica/ (tools/vale_unica_quadros.py). Ali parada, correndo e agindo ja tem a mesma
## altura (45 px); para voltar a V6: PASTA = "original_vale_v6" e idle 48.
const PASTA := "vale_unica"
const ALTURA_REF := {"idle": 45.0, "walk": 45.0, "run": 45.0, "tend": 45.0}
const FPS_ANDAR := 9.0

func preparar(altura_mundo: float) -> void:
	setup(PASTA)
	manifest.world_height = altura_mundo
	for d: String in DIRECTIONS:
		var run := "run_" + d
		var walk := "walk_" + d
		if not sprite_frames.has_animation(run):
			continue
		if sprite_frames.has_animation(walk):
			sprite_frames.clear(walk)
		else:
			sprite_frames.add_animation(walk)
		for i in sprite_frames.get_frame_count(run):
			sprite_frames.add_frame(walk, sprite_frames.get_frame_texture(run, i))
		sprite_frames.set_animation_speed(walk, FPS_ANDAR)
		sprite_frames.set_animation_loop(walk, true)
		var info: Dictionary = manifest.anims[run].duplicate(true)
		info.fps = FPS_ANDAR
		manifest.anims[walk] = info
	for a: String in manifest.anims:
		manifest.anims[a]["altura_ref"] = float(ALTURA_REF.get(a.get_slice("_", 0), 48.0))
	_ground_frame()

func altura_ref(anim: String) -> float:
	return float(manifest.anims.get(anim, {}).get("altura_ref", 48.0))

func _ground_frame() -> void:
	super._ground_frame()
	if manifest.is_empty() or not manifest.anims.has(str(animation)):
		return
	pixel_size = float(manifest.get("world_height", 1.48)) / altura_ref(str(animation))
