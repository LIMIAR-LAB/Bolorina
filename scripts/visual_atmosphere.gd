extends RefCounted
## Direcao de luz em uma unica configuracao, separada da logica do jogo.
var settings: Environment
var sun: DirectionalLight3D
var beams: Array[SpotLight3D] = []
var shafts: Array[MeshInstance3D] = []
var mode := 0
var root: Node3D
var sky_colors: ProceduralSkyMaterial
var moon: DirectionalLight3D
var probe: ReflectionProbe
var hour := 16.0
var transition_active := false
var transition_elapsed := 0.0
var transition_duration := 35.0
var transition_from := 16.0
var transition_to := 20.2

func install(scene: Node3D) -> void:
	root = scene
	var world := WorldEnvironment.new()
	world.name = "AtmosferaDaIlha"
	settings = Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_colors=sky_material
	sky_material.sky_top_color = Color("506a89")
	sky_material.sky_horizon_color = Color("e1bc88")
	sky_material.ground_bottom_color = Color("242e3b")
	sky_material.ground_horizon_color = Color("c6b492")
	sky_material.sun_angle_max = 0.2
	sky_material.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_material
	settings.background_mode = Environment.BG_SKY
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("819ab6")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.0
	settings.tonemap_white = 4.0
	settings.adjustment_enabled=true
	settings.adjustment_contrast=1.06
	settings.adjustment_saturation=1.12
	settings.ssao_enabled = true
	settings.ssao_radius = 1.1
	settings.ssao_intensity = 1.4
	settings.ssil_enabled = true
	settings.ssil_radius = 3.0
	settings.ssil_intensity = 0.45
	settings.ssr_enabled = true
	settings.ssr_max_steps = 48
	settings.ssr_depth_tolerance = 0.25
	settings.glow_enabled = true
	settings.glow_intensity = 0.6
	settings.glow_bloom = 0.06
	settings.glow_hdr_threshold = 1.15
	settings.fog_enabled = true
	settings.fog_light_color = Color("a7b6c0")
	settings.fog_density = 0.0005
	settings.fog_sky_affect = 0.1
	settings.volumetric_fog_enabled = true
	settings.volumetric_fog_density = 0.0012
	settings.volumetric_fog_albedo = Color("c7c9bd")
	settings.volumetric_fog_anisotropy = 0.45
	settings.volumetric_fog_length = 90
	settings.volumetric_fog_ambient_inject = 0.15
	settings.volumetric_fog_sky_affect = 0.0
	world.environment = settings
	root.add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "SolDoFimDaTarde"
	sun.rotation_degrees = Vector3(-27,-128,0)
	sun.light_color = Color("ffe0ae")
	sun.light_energy = 1.35
	sun.light_volumetric_fog_energy = 1.1
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	root.add_child(sun)
	# Luz solar dirigida entre copas e arcos; volumes reais, sem filtro laranja global.
	for entry in [[Vector3(-14,14,-11),Vector3(-1,0,5)],[Vector3(-9,17,-17),Vector3(4,0,2)]]:
		var beam := SpotLight3D.new()
		beam.position = entry[0]
		beam.light_color = Color("ffd596")
		beam.light_energy = 0.65
		beam.light_volumetric_fog_energy = 35.0
		beam.spot_range = 40
		beam.spot_angle = 6
		beam.spot_angle_attenuation = 0.7
		beam.spot_attenuation = 0.6
		beam.shadow_enabled = true
		root.add_child(beam)
		beam.look_at(entry[1])
		beams.append(beam)
	probe = ReflectionProbe.new()
	probe.name = "ReflexosDoCanal"
	probe.position = Vector3(0,3,5)
	probe.size = Vector3(50,22,48)
	probe.max_distance = 70
	probe.mesh_lod_threshold = 3
	probe.intensity = 0.7
	probe.enable_shadows = false
	root.add_child(probe)
	var grove_mist := FogVolume.new()
	grove_mist.name = "BrumaEntreAsCopas"
	grove_mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	grove_mist.size = Vector3(32,10,25)
	grove_mist.position = Vector3(-5,3,-8)
	var mist := FogMaterial.new()
	mist.density = 0.0025
	mist.albedo = Color("a1b4c1")
	mist.height_falloff = 0.8
	grove_mist.material = mist
	root.add_child(grove_mist)
	moon=DirectionalLight3D.new()
	moon.name="LuzDaLua"
	moon.rotation_degrees=Vector3(-42,35,0)
	moon.light_color=Color("7594d1")
	moon.light_energy=0
	root.add_child(moon)
	_sunshafts()
	_dust()
	set_hour(16.0)

func toggle() -> String:
	transition_from=hour
	transition_to=20.2 if hour<19.0 else 16.0
	transition_duration=35.0 if transition_to>19 else 8.0
	transition_elapsed=0
	transition_active=true
	return "Por do sol em movimento: sombras e folhas acompanham a luz." if transition_to>19 else "Retornando suavemente a luz da tarde."

func advance(delta: float) -> void:
	if not transition_active:
		return
	transition_elapsed=minf(transition_elapsed+delta,transition_duration)
	set_hour(lerpf(transition_from,transition_to,transition_elapsed/transition_duration))
	if transition_elapsed>=transition_duration:
		transition_active=false

func set_hour(value: float) -> void:
	hour=clampf(value,6,22)
	var elevation:=sin((hour-6)*PI/12)*65
	var day_light:=smoothstep(-4,12,elevation)
	var night:=smoothstep(17.8,19.8,hour)
	var warmth:=1.0-smoothstep(0,35,elevation)
	mode=1 if hour>=18.5 else 0
	sun.rotation_degrees=Vector3(-elevation,lerpf(-142,-98,clampf((hour-16)/4,0,1)),0)
	sun.light_energy=1.5*day_light
	sun.light_color=Color("ffe7bd").lerp(Color("ffac58"),warmth)
	moon.light_energy=night*0.27
	probe.intensity=lerpf(0.7,0.15,night)
	for actor in root.ground.get_children():
		if actor is AnimatedSprite3D:
			actor.modulate=Color.WHITE.lerp(Color("a1b2d9"),night)
	settings.ambient_light_energy=lerpf(0.55,0.32,night)
	settings.ambient_light_color=Color("899eae").lerp(Color("6686b6"),night)
	sky_colors.sky_top_color=Color("506a89").lerp(Color("0e1834"),night)
	sky_colors.sky_horizon_color=Color("d4b38a").lerp(Color("273455"),night)
	sky_colors.ground_horizon_color=Color("9eaaaf").lerp(Color("18243b"),night)
	settings.fog_light_color=Color("a7b6c0").lerp(Color("344c70"),night)
	for beam in beams:
		beam.visible=day_light>0.05
		beam.light_energy=0.65*day_light
	for shaft in shafts:
		shaft.visible=day_light>0.05
		shaft.rotation.y=deg_to_rad((hour-16)*3)
		shaft.material_override.set_shader_parameter("intensity",day_light)
	for light in root.get_tree().get_nodes_in_group("night_lights"):
		light.light_energy=lerpf(0.6,2.0,night)
	if root.get("art_world")!=null:
		root.art_world.materials.glow.emission_energy_multiplier=lerpf(0.7,1.8,night)

func _dust() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "PoeiraNoSol"
	particles.amount = 80
	particles.lifetime = 12
	particles.preprocess = 12
	particles.visibility_aabb = AABB(Vector3(-20,-2,-20),Vector3(40,14,40))
	particles.position = Vector3(0,2,-2)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(13,3,11)
	process.direction = Vector3(1,0.1,0.1)
	process.spread = 25
	process.initial_velocity_min = 0.12
	process.initial_velocity_max = 0.25
	process.gravity = Vector3.ZERO
	process.scale_min = 0.015
	process.scale_max = 0.045
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025,0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(1.0,0.85,0.52,0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1,0.65,0.24)
	mat.emission_energy_multiplier = 0.45
	quad.material = mat
	particles.draw_pass_1 = quad
	root.add_child(particles)





func _sunshafts() -> void:
	# Planos de luz estilizados com teste de profundidade; complementam o volume nativo.
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sunshaft.gdshader")
	var side := Vector3(1,0,-1).normalized()
	for i in range(3):
		var start := Vector3(-14+i*3,13,-9-i*2)
		var end := start+Vector3(11,-13,16)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var points := [start-side*0.3,start+side*0.3,end-side*1.2,end+side*1.2]
		var uv := [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]
		for index in [0,1,2,1,3,2]:
			surface.set_uv(uv[index])
			surface.add_vertex(points[index])
		var ray := MeshInstance3D.new()
		ray.name = "RaioSolarEstilizado"
		ray.mesh = surface.commit()
		ray.material_override = material
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ray)
		shafts.append(ray)
