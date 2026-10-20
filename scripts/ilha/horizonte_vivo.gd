extends Node
## Horizonte vivo da Vila/Fazenda (mesmo lugar, clima muda por dia).
## Camadas (fundo do Environment em modo CANVAS; a luz 3D, o ambiente e os reflexos nao mudam):
##   1. ceu procedural (shader): gradiente, nuvens que derivam, sol/lua, estrelas a noite, cortinas de chuva
##   2. horizonte_base.png: ilhas distantes + mar de nuvens deste lugar (fixo; o clima so tinge)
##   3. ilha_flutuante_1..3.png: ilhas que derivam devagar no ceu (camadas separadas, parallax)
##   4. aurora 3D: cortinas aditivas presas a camera, POR CIMA da cena (clima "aurora" ou tecla U)
## Clima do dia = CLIMAS[(dia - 1) % 5] (estavel no mesmo dia). Noite pelo relogio (L) escurece o ceu.
## Teclas: K liga/desliga o horizonte vivo (volta ao ceu antigo) | Shift+K proximo clima (teste)
##         U aurora: auto (dia de aurora / noite) -> ligada -> desligada
## Env: HORIZONTE=0 desliga | HORIZONTE_CLIMA=<nome> forca o clima | AURORA=1/0 forca
const PASTA := "res://art/environment/"
const CLIMAS := ["ensolarado", "nublado", "chuva_leve", "por_do_sol", "aurora"]
const PRESET := {
	"ensolarado": {"topo": "4b82c4", "horiz": "cfe2ee", "luz": "ffffff", "sombra": "b4c2d6", "cob": 0.38, "sol": [0.78, 0.22], "sol_cor": "fff0c8", "sol_f": 0.9, "chuva": 0.0, "tinta": "f2f6ff", "ilhas": "ffffff", "aurora": 0.0},
	"nublado": {"topo": "7a8696", "horiz": "c4c9ce", "luz": "eceef0", "sombra": "8c939e", "cob": 0.82, "sol": [0.7, 0.25], "sol_cor": "ffffff", "sol_f": 0.15, "chuva": 0.0, "tinta": "c9ccd4", "ilhas": "c8ccd6", "aurora": 0.0},
	"chuva_leve": {"topo": "4b5664", "horiz": "939ea8", "luz": "b6bec6", "sombra": "59616d", "cob": 0.95, "sol": [0.7, 0.25], "sol_cor": "ffffff", "sol_f": 0.0, "chuva": 0.8, "tinta": "9aa2ae", "ilhas": "a0a8b4", "aurora": 0.0},
	"por_do_sol": {"topo": "4f5590", "horiz": "ffae6a", "luz": "ffd8a0", "sombra": "a8607a", "cob": 0.45, "sol": [0.28, 0.6], "sol_cor": "ffa848", "sol_f": 1.2, "chuva": 0.0, "tinta": "ffc9a0", "ilhas": "ffd2b0", "aurora": 0.0},
	"aurora": {"topo": "1c2a5a", "horiz": "8aa0c8", "luz": "d6def0", "sombra": "6a76a0", "cob": 0.25, "sol": [0.82, 0.2], "sol_cor": "dce6ff", "sol_f": 0.35, "chuva": 0.0, "tinta": "aab8dc", "ilhas": "b8c4e4", "aurora": 1.0},
}
const NOITE := {"topo": "0a1130", "horiz": "26365e", "luz": "56658f", "sombra": "1b2342", "tinta": "4a5680", "ilhas": "56628c"}

var game
var ativo := true
var clima := "ensolarado"
var dia_atual := -1
var aurora_modo := 0   # 0 auto, 1 ligada, 2 desligada
var camada: CanvasLayer
var ceu: ColorRect
var ceu_mat: ShaderMaterial
var base: TextureRect
var fundo: ColorRect
var ilhas: Array = []      # {no: TextureRect, x, y, vel, par}
var aurora: Node3D
var aurora_mats: Array = []
var aurora_f := 0.0
var t := 0.0
var env_antes := {}
var camada_mat: ShaderMaterial
var inv_tex: ImageTexture
var compensar := true
## nevoa do abismo (vila_modular._abismo: 4 planos 90x90 m, alfa 0,54-0,9) = o "veu lavado".
## Com o horizonte vivo ligado, afina (NEVOA_FATOR) e tinge pelo clima; desligado, volta ao original.
const NEVOA_FATOR := 0.05
var nevoa_orig: Array = []   # [material, cor original]

const SKY_SHADER := """
shader_type canvas_item;
uniform vec3 topo : source_color; uniform vec3 horiz : source_color;
uniform vec3 nuvem_luz : source_color; uniform vec3 nuvem_sombra : source_color;
uniform float cobertura = 0.4; uniform vec2 sol_pos = vec2(0.7, 0.25);
uniform vec3 sol_cor : source_color; uniform float sol_forca = 1.0;
uniform float estrelas = 0.0; uniform float chuva = 0.0; uniform vec2 desloc = vec2(0.0);
uniform float aspecto = 1.7778;
uniform sampler2D inv : filter_linear, repeat_disable;
uniform float compensar = 1.0;
// hash inteiro (PCG): o antigo fract(sin(dot(p, ...)) * 43758) com argumentos grandes muda com 1 ulp
// (FMA/arredondamento diferente entre celulas vizinhas) e cortava o ruido em "quadrados" no ceu.
uint pcg(uint v){ uint s = v * 747796405u + 2891336453u; uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u; return (w >> 22u) ^ w; }
float hs(vec2 p){ ivec2 i = ivec2(floor(p)); return float(pcg(uint(i.x) + pcg(uint(i.y)))) * (1.0 / 4294967295.0); }
float ns(vec2 p){ vec2 i = floor(p), f = fract(p); vec2 u = f*f*(3.0-2.0*f);
	return mix(mix(hs(i), hs(i+vec2(1,0)), u.x), mix(hs(i+vec2(0,1)), hs(i+vec2(1,1)), u.x), u.y); }
float fbm(vec2 p){ float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++){ v += a*ns(p); p = p*2.03 + 1.7; a *= 0.5; } return v; }
void fragment(){
	vec2 uv = UV;
	vec3 c = mix(topo, horiz, pow(clamp(uv.y / 0.62, 0.0, 1.0), 1.4));
	vec2 d = (uv - sol_pos) * vec2(aspecto, 1.0);
	float r = length(d);
	c += sol_cor * sol_forca * (exp(-r * 5.0) * 0.55 + smoothstep(0.032, 0.024, r) * 1.0);
	vec2 sp = floor(uv * vec2(533.0, 300.0));
	float tw = 0.6 + 0.4 * sin(TIME * 2.0 + hs(sp) * 40.0);
	c += vec3(step(0.9965, hs(sp)) * estrelas * (1.0 - smoothstep(0.3, 0.6, uv.y)) * tw);
	vec2 q = vec2(uv.x * aspecto * 1.6 + TIME * 0.006 + desloc.x, uv.y * 4.2 + desloc.y);
	float n = fbm(q) + 0.3 * fbm(q * 2.6 + 3.1);
	float faixa = smoothstep(0.02, 0.2, uv.y) * (1.0 - smoothstep(0.5, 0.66, uv.y));
	float m = smoothstep(1.05 - cobertura, 1.25 - cobertura, n * (0.55 + 0.45 * faixa) + cobertura * 0.2);
	float luz = clamp((fbm(q + vec2(0.0, -0.12)) - n) * 2.2 + 0.6, 0.0, 1.0);
	c = mix(c, mix(nuvem_sombra, nuvem_luz, luz), m * 0.94);
	c += sol_cor * sol_forca * 0.25 * m * exp(-r * 3.0);
	if (chuva > 0.0) {
		float col = floor(uv.x * 260.0 + uv.y * 30.0);
		float y = uv.y * 14.0 + TIME * 6.0 + hs(vec2(col, 3.0)) * 9.0;
		float risco = step(0.9, hs(vec2(col, floor(y)))) * smoothstep(0.0, 0.5, fract(y));
		c = mix(c, nuvem_luz * 1.1, risco * chuva * 0.22 * smoothstep(0.1, 0.5, uv.y));
	}
	c = clamp(c, 0.0, 1.0);
	vec3 k = vec3(texture(inv, vec2(c.r, 0.5)).r, texture(inv, vec2(c.g, 0.5)).g, texture(inv, vec2(c.b, 0.5)).b);
	vec3 o = mix(c, k, compensar);
	// dither leve contra faixas de 8 bits (a curva da cena e ingreme)
	float dz = hs(FRAGCOORD.xy + vec2(floor(fract(TIME) * 61.0) * 1733.0, 0.0)) + hs(FRAGCOORD.yx + vec2(4099.0, 0.0)) - 1.0;
	COLOR = vec4(o + dz * (2.5 / 255.0), 1.0);
}
"""

## camadas (base, ilhas): mesma compensacao da curva da cena
const CAMADA_SHADER := """
shader_type canvas_item;
uniform sampler2D inv : filter_linear, repeat_disable;
uniform float compensar = 1.0;
void fragment(){
	vec4 c = texture(TEXTURE, UV) * COLOR;
	c.rgb = clamp(c.rgb, 0.0, 1.0);
	vec3 k = vec3(texture(inv, vec2(c.r, 0.5)).r, texture(inv, vec2(c.g, 0.5)).g, texture(inv, vec2(c.b, 0.5)).b);
	COLOR = vec4(mix(c.rgb, k, compensar), c.a);
}
"""

const AURORA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform float forca = 1.0; uniform float fase = 0.0;
uniform vec3 cor_a : source_color = vec3(0.25, 1.0, 0.6); uniform vec3 cor_b : source_color = vec3(0.7, 0.35, 1.0);
uint pcg(uint v){ uint s = v * 747796405u + 2891336453u; uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u; return (w >> 22u) ^ w; }
float h1(float x){ return float(pcg(uint(int(floor(x))))) * (1.0 / 4294967295.0); }
float n1(float x){ float i = floor(x), f = fract(x); return mix(h1(i), h1(i + 1.0), f*f*(3.0-2.0*f)); }
void vertex(){
	VERTEX.x += sin(UV.x * 7.0 + TIME * 0.22 + fase) * 1.4 * UV.y;
	VERTEX.z += sin(UV.x * 11.0 - TIME * 0.17 + fase * 2.0) * 1.2;
}
void fragment(){
	float x = UV.x * 46.0 + fase * 10.0;
	float t = TIME * 0.09;
	float raios = n1(x * 1.3 + t * 3.0) * 0.6 + n1(x * 4.7 - t * 5.0) * 0.4;
	raios = pow(raios, 2.0);
	float dobra = 0.55 + 0.45 * sin(UV.x * 16.0 + TIME * 0.12 + fase);
	float baixo = smoothstep(0.0, 0.5, UV.y);
	float corpo = 1.0 - smoothstep(0.3, 1.0, UV.y);
	float borda = exp(-pow((UV.y - 0.22) * 5.0, 2.0));
	float pontas = smoothstep(0.0, 0.15, UV.x) * (1.0 - smoothstep(0.85, 1.0, UV.x));
	float a = raios * dobra * baixo * (corpo * 0.55 + borda * 0.9) * pontas;
	vec3 c = mix(cor_a, cor_b, smoothstep(0.2, 0.95, UV.y));
	ALBEDO = c * a * forca;
}
"""

func montar(g) -> void:
	game = g
	if OS.get_environment("HORIZONTE") == "0" or game.config.get("horizonte", true) == false:
		ativo = false
	var am := OS.get_environment("AURORA")
	aurora_modo = 1 if am == "1" else (2 if am == "0" else 0)
	camada = CanvasLayer.new()
	camada.name = "HorizonteVivo"
	camada.layer = -20
	add_child(camada)
	ceu = ColorRect.new()
	ceu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ceu_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	ceu_mat.shader = sh
	ceu.material = ceu_mat
	camada.add_child(ceu)
	camada_mat = ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = CAMADA_SHADER
	camada_mat.shader = sh2
	if OS.get_environment("HORIZONTE_COMPENSAR") == "0":
		compensar = false
	_inv_identidade()
	base = TextureRect.new()
	base.texture = _tex("horizonte_base.png")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.material = camada_mat
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	for i in 3:
		var tr := TextureRect.new()
		tr.texture = _tex("ilha_flutuante_%d.png" % (i + 1))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.material = camada_mat
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		camada.add_child(tr)
		ilhas.append({"no": tr, "x": 0.0, "y": 0.0, "vel": 0.0, "par": 0.0, "esc": 1.0})
	fundo = ColorRect.new()
	fundo.color = Color("a7aec8")
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fundo)
	camada.move_child(fundo, 1)
	camada.add_child(base)
	camada.move_child(base, 2)   # base atras das ilhas que derivam
	_montar_aurora()
	_carregar_curva()
	if game.get("vila") != null and game.vila.get("nevoa") != null:
		for q in game.vila.nevoa:
			var m = q.material_override
			if m is ShaderMaterial:
				nevoa_orig.append([m, m.get_shader_parameter("cor")])
	_aplicar_ativo()
	_atualizar_dia(true)

# ---------------------------------------------------------------- compensacao da curva da cena
## A cena passa por exposicao + filmic + brilho/contraste/saturacao + LUT de fidelidade; isso "lava" o fundo.
## O ceu e as camadas aplicam a curva inversa por canal (256 px) medida no jogo; HORIZONTE_COMPENSAR=0 desliga.
func _inv_identidade() -> void:
	var img := Image.create(256, 1, false, Image.FORMAT_RGB8)
	for i in 256:
		img.set_pixel(i, 0, Color(i / 255.0, i / 255.0, i / 255.0))
	inv_tex = ImageTexture.create_from_image(img)
	_usar_inv()

func _usar_inv() -> void:
	for m in [ceu_mat, camada_mat]:
		m.set_shader_parameter("inv", inv_tex)
		m.set_shader_parameter("compensar", 1.0 if compensar else 0.0)

## curva inversa medida no viewport real por tests/horizonte_calibrar.gd (art/environment/curva_inversa.png)
func _carregar_curva() -> void:
	var t := _tex("curva_inversa.png")
	if t != null and compensar:
		inv_tex = t
	_usar_inv()

func _tex(nome: String) -> Texture2D:
	var p := ProjectSettings.globalize_path(PASTA + nome)
	if not FileAccess.file_exists(p):
		push_warning("horizonte: falta " + p)
		return null
	return ImageTexture.create_from_image(Image.load_from_file(p))

func _montar_aurora() -> void:
	aurora = Node3D.new()
	aurora.name = "Aurora3D"
	var sh := Shader.new()
	sh.code = AURORA_SHADER
	# 3 cortinas em profundidades diferentes (presas a camera; ficam no alto da tela)
	var cortinas := [[Vector3(-4, 0, -14), 46.0, 9.0, 0.0, Color(0.25, 1.0, 0.6), Color(0.7, 0.35, 1.0)],
		[Vector3(6, 1.5, -20), 40.0, 8.0, 2.1, Color(0.3, 0.95, 0.75), Color(0.85, 0.35, 0.9)],
		[Vector3(0, -1.0, -26), 56.0, 7.0, 4.3, Color(0.2, 0.85, 0.5), Color(0.5, 0.4, 1.0)]]
	for c in cortinas:
		var mi := MeshInstance3D.new()
		mi.mesh = _fita(float(c[1]), float(c[2]))
		mi.position = c[0]
		mi.rotation.y = float(c[3]) * 0.08 - 0.12
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("fase", float(c[3]))
		m.set_shader_parameter("cor_a", c[4])
		m.set_shader_parameter("cor_b", c[5])
		mi.material_override = m
		aurora_mats.append(m)
		aurora.add_child(mi)
	aurora.visible = false

## faixa vertical curva (UV.x ao longo, UV.y de baixo para cima)
func _fita(larg: float, alt: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	for i in n:
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		var a0 := Vector3((u0 - 0.5) * larg, 0, sin(u0 * 6.0) * 3.0)
		var a1 := Vector3((u1 - 0.5) * larg, 0, sin(u1 * 6.0) * 3.0)
		var b0 := a0 + Vector3(0, alt, -1.5)
		var b1 := a1 + Vector3(0, alt, -1.5)
		for v in [[a0, Vector2(u0, 0)], [b0, Vector2(u0, 1)], [b1, Vector2(u1, 1)], [a0, Vector2(u0, 0)], [b1, Vector2(u1, 1)], [a1, Vector2(u1, 0)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()

func _env() -> Environment:
	return game.atmosphere.settings

func _aplicar_ativo() -> void:
	var env := _env()
	camada.visible = ativo
	if ativo:
		if env_antes.is_empty():
			env_antes = {"bg": env.background_mode, "max": env.background_canvas_max_layer, "refl": env.reflected_light_source, "fog_sky": env.fog_sky_affect}
		env.background_mode = Environment.BG_CANVAS
		env.background_canvas_max_layer = -10
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY   # reflexos continuam do ceu antigo
		# o desfoque de distancia (DOF) em qualidade baixa vira "blocos" no ceu: qualidade alta + jitter
		RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, true)
	_nevoa()
	if not ativo and not env_antes.is_empty():
		env.background_mode = env_antes.bg
		env.background_canvas_max_layer = env_antes.max
		env.reflected_light_source = env_antes.refl
		env.fog_sky_affect = env_antes.fog_sky

func _nevoa() -> void:
	var tinta := Color(String(PRESET[clima].tinta)) if PRESET.has(clima) else Color.WHITE
	for par in nevoa_orig:
		var c0: Color = par[1]
		if ativo:
			var c := Color(c0.r, c0.g, c0.b).lerp(tinta, 0.5)
			par[0].set_shader_parameter("cor", Color(c.r, c.g, c.b, c0.a * NEVOA_FATOR))
		else:
			par[0].set_shader_parameter("cor", c0)

func _dia() -> int:
	if game.get("estado") != null and game.estado != null:
		return int(game.estado.dia)
	return int(game.get("day")) if game.get("day") != null else 1

func clima_do_dia(d: int) -> String:
	return CLIMAS[posmod(d - 1, CLIMAS.size())]

func _atualizar_dia(forcar := false) -> void:
	var d := _dia()
	if d == dia_atual and not forcar:
		return
	dia_atual = d
	var f := OS.get_environment("HORIZONTE_CLIMA")
	definir_clima(f if PRESET.has(f) else clima_do_dia(d))
	# ilhas: posicoes/velocidades do dia (semente = dia), derivam devagar
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + d * 97
	for i in ilhas.size():
		var il: Dictionary = ilhas[i]
		il.x = rng.randf_range(0.0, 1.0)
		il.y = rng.randf_range(0.08, 0.36)
		il.vel = rng.randf_range(0.004, 0.009) * (1.0 if rng.randf() < 0.7 else -1.0)
		il.esc = rng.randf_range(0.55, 1.0) * (0.75 + 0.25 * i / 2.0)
		il.par = 3.0 + il.esc * 9.0

func definir_clima(nome: String) -> void:
	clima = nome
	_cores(0.0)
	_nevoa()

func proximo_clima() -> String:
	definir_clima(CLIMAS[(CLIMAS.find(clima) + 1) % CLIMAS.size()])
	return clima

func _noite() -> float:
	var h: float = float(game.atmosphere.hour)
	return clampf(smoothstep(17.8, 19.8, h) + (1.0 - smoothstep(5.0, 6.5, h)), 0.0, 1.0)

func _cores(noite: float) -> void:
	var p: Dictionary = PRESET[clima]
	var c := func(k: String) -> Color:
		var a := Color(String(p[k]))
		return a.lerp(Color(String(NOITE[k])), clampf(noite, 0, 1)) if NOITE.has(k) else a
	ceu_mat.set_shader_parameter("topo", c.call("topo"))
	ceu_mat.set_shader_parameter("horiz", c.call("horiz"))
	ceu_mat.set_shader_parameter("nuvem_luz", c.call("luz"))
	ceu_mat.set_shader_parameter("nuvem_sombra", c.call("sombra"))
	ceu_mat.set_shader_parameter("cobertura", float(p.cob))
	ceu_mat.set_shader_parameter("sol_pos", Vector2(p.sol[0], p.sol[1]))
	ceu_mat.set_shader_parameter("sol_cor", Color(String(p.sol_cor)).lerp(Color("c8d4ff"), noite))
	ceu_mat.set_shader_parameter("sol_forca", lerpf(float(p.sol_f), 0.3, noite))
	ceu_mat.set_shader_parameter("estrelas", maxf(noite, 0.35 if clima == "aurora" else 0.0) * (1.0 - float(p.cob) * 0.6))
	ceu_mat.set_shader_parameter("chuva", float(p.chuva))
	base.modulate = c.call("tinta")
	fundo.modulate = c.call("tinta")
	for il in ilhas:
		il.no.modulate = c.call("ilhas")

func aurora_alvo() -> float:
	match aurora_modo:
		1: return 1.0
		2: return 0.0
	var p: Dictionary = PRESET[clima]
	return maxf(float(p.aurora) * (0.55 + 0.45 * _noite()), 0.0)

func _process(delta: float) -> void:
	if game == null:
		return
	t += delta
	_atualizar_dia()
	var cam := get_viewport().get_camera_3d()
	# aurora 3D: presa a camera, por cima de tudo
	aurora_f = move_toward(aurora_f, aurora_alvo() if ativo else 0.0, delta * 0.5)
	if cam and aurora.get_parent() != cam:
		if aurora.get_parent():
			aurora.get_parent().remove_child(aurora)
		cam.add_child(aurora)
	aurora.visible = aurora_f > 0.01
	if aurora.visible and cam:
		var meia: float = (cam.size if cam.projection == Camera3D.PROJECTION_ORTHOGONAL else 20.0) * 0.5
		aurora.position = Vector3(0, meia * 0.42, 0)
		aurora.scale = Vector3.ONE * (meia / 10.0)
		for m in aurora_mats:
			m.set_shader_parameter("forca", aurora_f * 0.3)
	if not ativo:
		return
	_env().fog_sky_affect = 0.0
	var tela: Vector2 = get_viewport().get_visible_rect().size
	ceu.position = Vector2.ZERO
	ceu.size = tela
	ceu_mat.set_shader_parameter("aspecto", tela.x / maxf(tela.y, 1.0))
	var noite := _noite()
	if int(t * 4.0) != int((t - delta) * 4.0):
		_cores(noite)
	# parallax: deslocamento da camera no plano da tela (metros)
	var par := Vector2.ZERO
	if cam:
		var b := cam.global_transform.basis
		par = Vector2(cam.global_position.dot(b.x), -cam.global_position.dot(b.y))
	ceu_mat.set_shader_parameter("desloc", par * 0.004)
	var bw := tela.x * 1.6
	var bh := bw * 0.25
	base.size = Vector2(bw, bh)
	base.position = Vector2(-tela.x * 0.3 - clampf(par.x * 2.0, -tela.x * 0.28, tela.x * 0.28), tela.y * 0.6 - bh * 0.45 - clampf(par.y * 1.5, -tela.y * 0.1, tela.y * 0.1))
	fundo.position = Vector2(0, base.position.y + bh - 4)
	fundo.size = Vector2(tela.x, tela.y)
	for il in ilhas:
		il.x = fposmod(float(il.x) + float(il.vel) * delta / 6.0, 1.0)
		var tr: TextureRect = il.no
		var tam: Vector2 = tr.texture.get_size() * float(il.esc) * (tela.y / 900.0) if tr.texture else Vector2.ZERO
		tr.size = tam
		var faixa := tela.x + tam.x * 2.0
		tr.position = Vector2(fposmod(float(il.x) * faixa - par.x * float(il.par), faixa) - tam.x, float(il.y) * tela.y - par.y * float(il.par) * 0.6)

func tecla(event: InputEventKey) -> String:
	if event.physical_keycode == KEY_K:
		if event.shift_pressed:
			if not ativo:
				ativo = true
				_aplicar_ativo()
			return "Horizonte: clima " + proximo_clima()
		ativo = not ativo
		_aplicar_ativo()
		return "Horizonte vivo: " + ("ligado (%s)" % clima if ativo else "desligado (ceu antigo)")
	if event.physical_keycode == KEY_U:
		aurora_modo = (aurora_modo + 1) % 3
		return "Aurora: " + ["automatica", "ligada", "desligada"][aurora_modo]
	return ""

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var m := tecla(event)
		if m != "":
			game.message.text = m
			get_viewport().set_input_as_handled()
