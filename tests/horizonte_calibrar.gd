extends SceneTree
## Mede a curva da cena (exposicao + filmic + ajustes + LUT) sobre o fundo CANVAS no viewport real
## e grava art/environment/curva_inversa.png (256x1, inversa por canal) usada pelo horizonte vivo.
## Rodar de novo se mudar a grade de fidelidade. 32 faixas verticais de cinza, amostra no meio de cada.
const N := 32
var v
func _init() -> void:
	call_deferred("_run")
func fr(n: int) -> void:
	for i in n:
		await process_frame
func _run() -> void:
	OS.set_environment("ILHA_SAVE", "user://ilha_horizonte_teste.json")
	OS.set_environment("ILHA_AREA", "vila")
	OS.set_environment("ILHA_SPAWN", "da_masmorra")
	OS.set_environment("HORIZONTE_COMPENSAR", "0")
	var jogo = load("res://jogo_ilha.tscn").instantiate()
	root.add_child(jogo)
	for i in 200:
		await process_frame
		if jogo.atual and jogo.atual.get("horizonte") != null and jogo.atual.horizonte != null:
			break
	v = jogo.atual
	await create_timer(1.0).timeout
	var hz = v.horizonte
	hz.set_process(false)
	hz.base.visible = false
	hz.fundo.visible = false
	for il in hz.ilhas: il.no.visible = false
	hz.ceu.visible = false
	for q in v.vila.nevoa: q.visible = false
	for c in v.get_children():
		if c is Node3D and not (c is Camera3D):
			c.visible = false
	for c in v.find_children("*", "CanvasLayer", true, false):
		if c.layer >= -1 and c.layer != 1:
			c.visible = false
	v.atmosphere.settings.fog_sky_affect = 0.0
	var tela: Vector2 = root.get_viewport().get_visible_rect().size
	var faixas := []
	for i in N:
		var r := ColorRect.new()
		var g := float(i) / float(N - 1)
		r.color = Color(g, g, g)
		r.position = Vector2(tela.x * i / N, 0)
		r.size = Vector2(tela.x / N + 1, tela.y)
		hz.camada.add_child(r)
		faixas.append(r)
	await fr(8)
	var img: Image = root.get_viewport().get_texture().get_image()
	var sx := float(img.get_width()) / tela.x
	var med := [[], [], []]
	var txt := ""
	for i in N:
		var c := img.get_pixel(int((tela.x * (i + 0.5) / N) * sx), int(img.get_height() * 0.5))
		med[0].append(c.r)
		med[1].append(c.g)
		med[2].append(c.b)
		txt += " %d:%s" % [i, c.to_html(false)]
	print("CAL medido", txt)
	var out := Image.create(256, 1, false, Image.FORMAT_RGB8)
	for ch in 3:
		var a: Array = med[ch]
		for i in range(1, N):
			a[i] = maxf(float(a[i]), float(a[i - 1]) + 0.0001)
	for j in 256:
		var alvo := j / 255.0
		var res := [0.0, 0.0, 0.0]
		for ch in 3:
			var a: Array = med[ch]
			if alvo <= float(a[0]):
				res[ch] = 0.0
			elif alvo >= float(a[N - 1]):
				res[ch] = 1.0
			else:
				var k := 0
				while k < N - 2 and float(a[k + 1]) < alvo:
					k += 1
				var f: float = (alvo - float(a[k])) / maxf(float(a[k + 1]) - float(a[k]), 0.0001)
				res[ch] = clampf((k + f) / float(N - 1), 0.0, 1.0)
		out.set_pixel(j, 0, Color(res[0], res[1], res[2]))
	out.save_png(ProjectSettings.globalize_path("res://art/environment/curva_inversa.png"))
	var t := ""
	for j in [32, 64, 128, 192, 224, 250]:
		t += " %d:%s" % [j, out.get_pixel(j, 0).to_html(false)]
	print("CAL inversa", t)
	quit(0)
