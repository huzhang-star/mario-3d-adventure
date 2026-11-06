extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const COIN_SCRIPT := preload("res://scripts/coin.gd")
const MODEL_FLAG := preload("res://assets/kenney/models/flag.glb")
const STAGE_BUILDER := preload("res://scripts/stage_builder.gd")
const SHOP_SCRIPT = preload("res://scripts/skin_shop.gd")
const SOUND_BGM := preload("res://assets/audio/starbound_isle_theme.wav")
const SOUND_UI_CLICK := preload("res://assets/audio/ui_click.wav")
const SOUND_KEY := preload("res://assets/audio/key.wav")
const SOUND_GOAL := preload("res://assets/audio/goal.wav")
const SOUND_FAIL := preload("res://assets/audio/fail.wav")
const SOUND_LAND := preload("res://assets/kenney/sounds/land.ogg")
const VIRTUAL_JOYSTICK := preload("res://scripts/virtual_joystick.gd")
const DISPLAY_BASE_SIZE := Vector2i(1280, 720)
const CAMERA_MAX_DISTANCE := 15.0
const WORLD_SURFACE_Y := -5.0
const FALL_SURFACE_CLEARANCE := 0.5

var tutorial: RefCounted
var postal: Node3D
var settings_panel: ColorRect
var settings_was_paused := false
var input_hint: Label
var medal_row: HBoxContainer
var device_kind := "keyboard"
var touch_camera_index := -1
var focus_height := 0.0
var camera_focus_valid := false
var camera_arm := 11.5
var reward_data: Dictionary = {}
var reward_saved := false
var result_pending := false
var result_text := ""
var shop: ColorRect
var shop_was_paused := false
var wallet_label: Label
var camera_yaw := PI
var camera_pitch := 0.42
var camera_distance := 11.5
var application_focused := true
var orbit_yaw := PI
var orbit_pitch := 0.42

var player: IslandPlayer
var camera: Camera3D
var camera_target := Vector3.ZERO
var hud: CanvasLayer
var top_bar: PanelContainer
var coin_label: Label
var health_label: Label
var health_bar: ProgressBar
var time_label: Label
var banner_label: Label
var overlay: ColorRect
var overlay_title: Label
var overlay_subtitle: Label
var overlay_button: Button
var pause_button: Button
var fullscreen_button: Button
var sound_button: Button
var touch_controls: Control
var virtual_joystick: Control
var time_left := 300.0
var elapsed_time := 0.0
var game_started := false
var game_finished := false
var game_won := false
var completion_score := 0
var completion_reward := 0
var transition_pending := false
var respawn_pending := false
var level_config: Dictionary
var total_coins := 0
var stars := 0
var keys := 0
var required_keys := 0
var stage_spawn := Vector3.ZERO
var stage_spawn_yaw := PI
var stage_goal := Vector3.ZERO
var route_surfaces: Array = []
var special_label: Label
var selector: ColorRect
var selector_was_paused := false
var selector_page := 0
var selector_grid: GridContainer
var selector_heading: Label
var selector_previous: Button
var selector_next: Button
var banner_tween: Tween
var goal_notice_cooldown := 0.0
var music_player: AudioStreamPlayer
var audio_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_config = Campaign.current_level()
	audio_enabled = Campaign.audio_enabled
	time_left = float(level_config["time"])
	_configure_window_scaling()
	_setup_audio()
	_setup_environment()
	_build_level()
	_spawn_player()
	_build_hud()
	if level_config.get("tutorial",false):
		tutorial = preload("res://scripts/tutorial.gd").new()
		tutorial.setup(self)
	# Keep menu/input responsive while the world is frozen at stage boundaries.
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_update_time()
	_show_intro()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	if "--autoplay" in OS.get_cmdline_user_args():
		_on_overlay_button.call_deferred()

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -15.0 if audio_enabled else -80.0
	var music_stream := SOUND_BGM.duplicate()
	if music_stream is AudioStreamWAV:
		music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_player.stream = music_stream
	add_child(music_player)
	music_player.play()

func play_sfx(stream: AudioStream, volume_db := -3.0, pitch := 1.0) -> void:
	if not audio_enabled:
		return
	var sound := AudioStreamPlayer.new()
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	sound.stream = stream
	sound.volume_db = volume_db
	sound.pitch_scale = pitch
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)

func _play_ui_click() -> void:
	play_sfx(SOUND_UI_CLICK, -5.0, 1.0)

func _bind_ui_sound(button: Button) -> void:
	button.pressed.connect(_play_ui_click)

func _toggle_audio() -> void:
	audio_enabled = not audio_enabled
	Campaign.audio_enabled = audio_enabled
	Campaign.save_settings()
	if music_player:
		music_player.volume_db = -15.0 if audio_enabled else -80.0
	if player:
		player.sound_enabled = audio_enabled
	_update_audio_button()
	if audio_enabled:
		_play_ui_click()

func _update_audio_button() -> void:
	if not is_instance_valid(sound_button):
		return
	sound_button.text = "♫" if audio_enabled else "×"
	sound_button.tooltip_text = "关闭音乐与音效" if audio_enabled else "开启音乐与音效"

func _process(delta: float) -> void:
	_sync_mouse_look()
	if tutorial: tutorial.update()
	goal_notice_cooldown = maxf(0,goal_notice_cooldown-delta)
	if player and camera:
		if get_tree().paused:
			touch_camera_index=-1
		if game_started and not game_finished and not get_tree().paused:
			var pads := Input.get_connected_joypads()
			if not pads.is_empty():
				var axes := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_X), Input.get_joy_axis(pads[0], JOY_AXIS_RIGHT_Y))
				if axes.length() > .18:
					var look := axes.normalized()*clampf((axes.length()-.18)/.82,0,1)
					_rotate_camera(look*delta*320.0)
		orbit_yaw=lerp_angle(orbit_yaw,camera_yaw,1.0-exp(-delta*18.0))
		orbit_pitch=lerpf(orbit_pitch,camera_pitch,1.0-exp(-delta*18.0))
		var forward := Vector3(sin(orbit_yaw),0,cos(orbit_yaw))
		var target_height := player.global_position.y+.85
		if not camera_focus_valid or absf(target_height-focus_height)>5.0 or delta<=0:
			focus_height=target_height
			camera_focus_valid=true
		else:
			focus_height=lerpf(focus_height,target_height,1-exp(-delta*(12.0 if player.is_on_floor() else 6.0)))
		var focus := Vector3(player.global_position.x,focus_height,player.global_position.z)
		var arm := -forward*cos(orbit_pitch)+Vector3.UP*sin(orbit_pitch)
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius=.28
		query.shape=sphere
		query.transform.origin=focus
		query.motion=arm*camera_distance
		query.collision_mask=1
		query.exclude=[player.get_rid()]
		var collision := get_world_3d().direct_space_state.cast_motion(query)
		var safe_distance := camera_distance*collision[0] if collision.size()>0 else camera_distance
		if safe_distance<camera_arm or delta<=0: camera_arm=safe_distance
		else: camera_arm=lerpf(camera_arm,safe_distance,1-exp(-delta*5))
		camera_target=focus+arm*maxf(.35,camera_arm-.12)
		camera_target.y=maxf(camera_target.y,WORLD_SURFACE_Y+FALL_SURFACE_CLEARANCE)
		camera.global_position=camera_target
		camera.look_at(focus,Vector3.UP)

	if game_started and not game_finished and not get_tree().paused:
		elapsed_time += delta
		if not tutorial: time_left = maxf(0.0, time_left - delta)
		_update_time()
		if not tutorial and time_left <= 0.0:
			_end_game(false, "时间到")

func _configure_window_scaling() -> void:
	var window := get_window()
	window.content_scale_size = DISPLAY_BASE_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag: _set_device("touch")
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>.25): _set_device("gamepad")
	elif event is InputEventKey or ((event is InputEventMouseButton or event is InputEventMouseMotion) and event.device!=-1): _set_device("keyboard")
	_sync_mouse_look()
	if event is InputEventScreenTouch and (not event.pressed or event.canceled) and event.index==touch_camera_index: touch_camera_index=-1
	if event is InputEventScreenDrag and event.index==touch_camera_index and game_started and not game_finished and not get_tree().paused:
		_rotate_camera(event.relative)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and event.device!=-1 and _mouse_look_enabled():
		_rotate_camera(event.relative)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		application_focused=false
		touch_camera_index=-1
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		application_focused=true

func _mouse_look_enabled() -> bool:
	return application_focused and game_started and not game_finished and not transition_pending and not respawn_pending and not get_tree().paused and device_kind=="keyboard" and touch_camera_index==-1

func _sync_mouse_look() -> void:
	var mode := Input.MOUSE_MODE_CAPTURED if _mouse_look_enabled() else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode!=mode:
		Input.mouse_mode=mode

func _exit_tree() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(settings_panel):
		if event.is_action_pressed("pause"): _close_settings()
		return
	if game_started and not game_finished and not get_tree().paused:
		if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Q) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_RIGHT_STICK):
			_recenter_camera()
		# GUI controls consume their touches first; any remaining empty area can look.
		if event is InputEventScreenTouch and event.pressed and not event.canceled and touch_camera_index==-1:
			touch_camera_index=event.index
			get_viewport().set_input_as_handled()
	if is_instance_valid(shop):
		if event.is_action_pressed("pause"): _close_shop()
		return
	if event is InputEventMouseButton and event.device!=-1 and game_started and not game_finished and not get_tree().paused:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_distance=clampf(camera_distance+(-.7 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .7),7.0,CAMERA_MAX_DISTANCE)
	if is_instance_valid(selector):
		if event.is_action_pressed("pause"): _close_selector()
		return
	if event.is_action_pressed("pause") and game_started and not game_finished:
		_toggle_pause()
	elif event.is_action_pressed("restart"):
		_reload_stage()
	elif event.is_action_pressed("fullscreen"):
		_toggle_fullscreen()

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_shader := Shader.new()
	sky_shader.code = """
shader_type sky;
uniform vec4 zenith : source_color;
uniform vec4 horizon : source_color;
uniform float night = 0.0;
uniform float aurora = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void sky() {
    float elevation = max(EYEDIR.y,0.0);
    vec3 gradient = mix(horizon.rgb,zenith.rgb,pow(elevation,0.55));
    float haze = pow(1.0-abs(EYEDIR.y),12.0);
    vec2 uv = vec2(atan(EYEDIR.z,EYEDIR.x),asin(EYEDIR.y))*vec2(110.0,90.0);
    vec2 cell = floor(uv);
    float star = smoothstep(0.16,0.01,length(fract(uv)-vec2(0.5)))*step(0.983,hash(cell));
    float ribbon = exp(-pow((EYEDIR.y-0.35-sin(EYEDIR.x*7.0+EYEDIR.z*3.0)*0.1)*18.0,2.0));
    COLOR = gradient + horizon.rgb*haze*0.12 + vec3(0.8,0.9,1.0)*star*night;
    COLOR += vec3(0.10,0.42,0.29)*ribbon*aurora;
}
"""
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("zenith",Color(level_config.palette[3]))
	sky_material.set_shader_parameter("horizon",Color(level_config.palette[4]))
	sky_material.set_shader_parameter("night",1.0 if level_config.theme in ["bamboo","crystal","astral","ice"] else 0.0)
	sky_material.set_shader_parameter("aurora",1.0 if level_config.theme == "ice" else 0.0)
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(level_config.palette[4]).lightened(.3)
	environment.ambient_light_energy = 0.34
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.9
	environment.glow_enabled = true
	environment.glow_intensity = 1.05
	environment.glow_bloom = 0.08
	environment.ssao_enabled = true
	environment.ssao_radius = 0.88
	environment.ssao_intensity = 1.65
	environment.ssao_power = 2.2
	environment.ssr_enabled = true
	environment.ssr_max_steps = 48
	environment.ssr_fade_in = 0.12
	environment.ssr_fade_out = 2.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(level_config.palette[4])
	environment.fog_light_energy = 0.78
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.1
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.96
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.08
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("#fff0cf")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.64
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	var sky_fill := DirectionalLight3D.new()
	sky_fill.rotation_degrees = Vector3(-24, 142, 8)
	sky_fill.light_color = Color("#8fd7e5")
	sky_fill.light_energy = 0.2
	sky_fill.shadow_enabled = false
	add_child(sky_fill)

	camera = Camera3D.new()
	camera.name = "AdventureCamera"
	camera.fov = 51.0
	camera.near = 0.12
	camera.far = 320.0
	camera.position = Vector3(10, 8, 20)
	camera.current = true
	add_child(camera)

	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(400, 400)
	water_mesh.subdivide_width = 160
	water_mesh.subdivide_depth = 160
	water.mesh = water_mesh
	water.position = Vector3(0, WORLD_SURFACE_Y, -24)
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color;
varying float wave_height;

void vertex() {
	float broad_wave = sin(VERTEX.x * 0.17 + TIME * 0.72) * 0.11;
	float cross_wave = cos(VERTEX.z * 0.21 - TIME * 0.58) * 0.08;
	float ripple = sin((VERTEX.x + VERTEX.z) * 0.48 + TIME * 1.22) * 0.025;
	wave_height = broad_wave + cross_wave + ripple;
	VERTEX.y += wave_height;
}

void fragment() {
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.2);
	float shimmer = 0.5 + wave_height;
	vec3 deep_color = water_color.rgb * 0.45;
	vec3 lagoon_color = water_color.rgb;
	vec3 horizon_color = mix(water_color.rgb, vec3(0.8), 0.3);
	ALBEDO = mix(deep_color, lagoon_color, 0.46 + wave_height * 0.8);
	ALBEDO = mix(ALBEDO, horizon_color, fresnel * 0.72);
	EMISSION = horizon_color * shimmer * fresnel * 0.055;
	ROUGHNESS = 0.38;
	METALLIC = 0.05;
	SPECULAR = 0.72;
}
"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	water_material.set_shader_parameter("water_color",Color("be532c") if level_config.theme == "forge" else Color(level_config.palette[4]).darkened(.18))
	water.material_override = water_material
	add_child(water)
	_make_ambient_particles()

func _build_level() -> void:
	STAGE_BUILDER.build(self, level_config)
	if level_config.theme=="cloud":
		postal=load("res://scripts/postal_route.gd").new()
		postal.game=self
		add_child(postal)


func _spawn_player() -> void:
	player = IslandPlayer.new()
	player.name = "Player"
	player.position = stage_spawn
	add_child(player)
	player.setup(camera, stage_spawn)
	# Stop above the highest water waves, before the visible world is crossed.
	player.fall_boundary_y = WORLD_SURFACE_Y + FALL_SURFACE_CLEARANCE
	player.sound_enabled=audio_enabled
	player.spawn_yaw = stage_spawn_yaw
	player.facing_yaw = stage_spawn_yaw
	player._visual.rotation.y = stage_spawn_yaw
	camera_yaw=stage_spawn_yaw
	orbit_yaw=camera_yaw
	camera.position = stage_spawn - player.get_facing_direction()*10 + Vector3.UP*5.5
	player.coin_collected.connect(_on_coin_collected)
	player.health_changed.connect(_on_health_changed)
	player.fell.connect(_on_player_fell)

func _spawn_coin(pos: Vector3, parent: Node3D = null) -> void:
	var coin := StarCoin.new()
	coin.position = pos
	if parent:
		parent.add_child(coin)
	else:
		add_child(coin)
	total_coins += 1

func _make_goal(pos: Vector3) -> void:
	var goal := Area3D.new()
	goal.name = "Goal"
	goal.position = pos
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 2.2
	cylinder.height = 7.0
	shape.shape = cylinder
	shape.position.y = 3.2
	goal.add_child(shape)
	goal.body_entered.connect(_on_goal_entered)
	add_child(goal)

	var flag := MODEL_FLAG.instantiate()
	flag.name = "FinishFlag"
	flag.position.y = 0.22
	flag.scale = Vector3.ONE * 1.55
	_polish_model(flag, 0.58)
	goal.add_child(flag)
	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.72
	halo_mesh.outer_radius = 0.92
	halo.mesh = halo_mesh
	halo.position = Vector3(0, 6.5, 0)
	halo.rotation.x = PI / 2.0
	var halo_material := _make_material(Color("#ffd95a"), 0.22)
	halo_material.emission_enabled = true
	halo_material.emission = Color("#d78f16")
	halo_material.emission_energy_multiplier = 0.65
	halo.material_override = halo_material
	goal.add_child(halo)

func _polish_model(root: Node, target_roughness: float) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material is StandardMaterial3D:
				var polished := source_material.duplicate() as StandardMaterial3D
				polished.roughness = target_roughness
				polished.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mesh_instance.set_surface_override_material(surface_index, polished)

func _make_ambient_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.position = Vector3(0, 5, -26)
	particles.amount = 72
	particles.lifetime = 12.0
	particles.preprocess = 12.0
	particles.visibility_aabb = AABB(Vector3(-22, -8, -42), Vector3(44, 22, 84))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(18, 7, 38)
	process_material.direction = Vector3.UP
	process_material.spread = 35.0
	process_material.initial_velocity_min = 0.08
	process_material.initial_velocity_max = 0.28
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.35
	process_material.scale_max = 1.0
	process_material.color = Color(1.0, 0.91, 0.55, 0.42)
	particles.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var mote_material := StandardMaterial3D.new()
	mote_material.albedo_color = Color(1.0, 0.9, 0.5, 0.48)
	mote_material.emission_enabled = true
	mote_material.emission = Color("#ffd66b")
	mote_material.emission_energy_multiplier = 0.8
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mote_material
	particles.draw_pass_1 = quad
	add_child(particles)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 24
	top_bar.offset_top = 20
	top_bar.offset_right = -24
	top_bar.offset_bottom = 78
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.04, 0.09, 0.12, 0.84)
	bar_style.corner_radius_top_left = 8
	bar_style.corner_radius_top_right = 8
	bar_style.corner_radius_bottom_left = 8
	bar_style.corner_radius_bottom_right = 8
	bar_style.border_width_left = 1
	bar_style.border_width_top = 1
	bar_style.border_width_right = 1
	bar_style.border_width_bottom = 1
	bar_style.border_color = Color(1, 1, 1, 0.16)
	top_bar.add_theme_stylebox_override("panel", bar_style)
	hud.add_child(top_bar)

	var padding := MarginContainer.new()
	for edge in ["left","right"]: padding.add_theme_constant_override("margin_"+edge,16)
	for edge in ["top","bottom"]: padding.add_theme_constant_override("margin_"+edge,10)
	top_bar.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	padding.add_child(stack)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation",8)
	stack.add_child(heading)
	var title := _hud_label("%02d  %s" % [Campaign.level_index+1,level_config.name],22,Color("fff1ce"))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_hud_label("普通闯关",15,Color("aed9cb")))
	for entry in [["♫","声音"],["Ⅱ","暂停"],["⛶","全屏"],["地图","关卡"],["衣橱","衣橱"],["设置","设置"]]:
		var button := Button.new()
		button.text=entry[0]
		button.tooltip_text=entry[1]
		button.custom_minimum_size=Vector2(44 if entry[0].length()==1 else 56,34)
		button.add_theme_font_size_override("font_size",17)
		button.add_theme_stylebox_override("normal",_button_style(Color("263f4b"),Color("49616a"),8))
		heading.add_child(button)
		_bind_ui_sound(button)
		match entry[1]:
			"声音": sound_button=button; button.pressed.connect(_toggle_audio)
			"暂停": pause_button=button; button.pressed.connect(_toggle_pause)
			"全屏": fullscreen_button=button; button.pressed.connect(_toggle_fullscreen)
			"关卡": button.pressed.connect(_show_selector)
			"衣橱": button.pressed.connect(_show_shop)
			"设置": button.pressed.connect(_show_settings)
	_update_audio_button()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	stack.add_child(row)
	health_label=_hud_label("生命 3/3",17,Color("ffd7d2"))
	row.add_child(health_label)
	health_bar=ProgressBar.new()
	health_bar.custom_minimum_size=Vector2(86,12)
	health_bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	health_bar.max_value=IslandPlayer.MAX_HEALTH
	health_bar.step=IslandPlayer.ENEMY_DAMAGE
	health_bar.value=player.health
	health_bar.show_percentage=false
	health_bar.add_theme_stylebox_override("background",_button_style(Color("542a35"),Color("542a35"),6))
	health_bar.add_theme_stylebox_override("fill",_button_style(Color("f58286"),Color("f58286"),6))
	row.add_child(health_bar)
	coin_label=_hud_label("金币 0 / %d" % total_coins,17,Color("ffd784"))
	row.add_child(coin_label)
	wallet_label=_hud_label("",17,Color("ffd784"))
	wallet_label.hide()
	hud.add_child(wallet_label)
	Wardrobe.changed.connect(_update_wallet)
	_update_wallet()
	special_label=_hud_label("",17,Color("b7f0e5"))
	row.add_child(special_label)
	_update_special_label()
	var spacer := Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_hud_label(("可选竞速 %s" if level_config.get("tutorial",false) else "竞速目标 %s") % _format_duration(Campaign.speed_target()),15,Color("adbec5")))
	time_label=_hud_label("07:00",20,Color.WHITE)
	row.add_child(time_label)

	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_label.offset_top = 128
	banner_label.offset_bottom = 178
	banner_label.add_theme_font_size_override("font_size", 22)
	banner_label.add_theme_color_override("font_color", Color("#fff4bf"))
	banner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	banner_label.add_theme_constant_override("shadow_offset_x", 2)
	banner_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(banner_label)
	_build_touch_controls()
	input_hint=_hud_label("",15,Color("e4eee8"))
	input_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	input_hint.offset_left=24
	input_hint.offset_top=-34
	input_hint.offset_bottom=-8
	input_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	input_hint.add_theme_color_override("font_shadow_color",Color("182b35"))
	input_hint.add_theme_constant_override("shadow_offset_y",1)
	hud.add_child(input_hint)
	_refresh_input_hint()

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.065, 0.08, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-410, -230)
	center.size = Vector2(820, 460)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	overlay.add_child(center)

	overlay_title = Label.new()
	overlay_title.text = "星跃岛"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 42)
	overlay_title.add_theme_color_override("font_color", Color("#fff2ae"))
	center.add_child(overlay_title)

	overlay_subtitle = Label.new()
	overlay_subtitle.text = "拖动左下角摇杆移动   右下角按钮跳跃\nW / A / S / D 和方向键同样可用\n触控板单指滑动或移动鼠标转动视角（无需按下） · 滚轮调整镜头距离\n沿金币路线到达旗塔即可过关"
	overlay_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_subtitle.add_theme_font_size_override("font_size", 19)
	overlay_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	center.add_child(overlay_subtitle)
	medal_row=HBoxContainer.new()
	medal_row.alignment=BoxContainer.ALIGNMENT_CENTER
	medal_row.add_theme_constant_override("separation",12)
	center.add_child(medal_row)
	medal_row.hide()

	overlay_button = Button.new()
	overlay_button.text = "开始冒险"
	overlay_button.custom_minimum_size = Vector2(260, 54)
	overlay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_button.add_theme_font_size_override("font_size", 21)
	overlay_button.add_theme_stylebox_override("normal", _button_style(Color("#e4a733"), Color("#ffe59a"), 8))
	overlay_button.add_theme_stylebox_override("hover", _button_style(Color("#f1b947"), Color.WHITE, 8))
	overlay_button.add_theme_stylebox_override("pressed", _button_style(Color("#c98425"), Color("#ffe59a"), 8))
	overlay_button.add_theme_color_override("font_color", Color("#182b2f"))
	overlay_button.add_theme_color_override("font_hover_color", Color("#102326"))
	overlay_button.pressed.connect(_on_overlay_button)
	_bind_ui_sound(overlay_button)
	center.add_child(overlay_button)
	var select_button := Button.new()
	select_button.text = "冒险地图 · 选择关卡"
	select_button.custom_minimum_size = Vector2(260,42)
	select_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	select_button.pressed.connect(_show_selector)
	_bind_ui_sound(select_button)
	center.add_child(select_button)
	var menu_shop_button := Button.new()
	menu_shop_button.text="星光衣橱 · 金币换装"
	menu_shop_button.custom_minimum_size=Vector2(260,42)
	menu_shop_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	menu_shop_button.pressed.connect(_show_shop)
	_bind_ui_sound(menu_shop_button)
	center.add_child(menu_shop_button)
	var settings_button := Button.new()
	settings_button.text="操作设置 · 镜头与按键"
	settings_button.custom_minimum_size=Vector2(260,36)
	settings_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	settings_button.pressed.connect(_show_settings)
	center.add_child(settings_button)

func _build_touch_controls() -> void:
	touch_controls = Control.new()
	touch_controls.name = "TouchControls"
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(touch_controls)

	virtual_joystick = VIRTUAL_JOYSTICK.new()
	virtual_joystick.name = "MoveJoystick"
	virtual_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	virtual_joystick.offset_left = 18
	virtual_joystick.offset_top = -198
	virtual_joystick.offset_right = 198
	virtual_joystick.offset_bottom = -18
	virtual_joystick.value_changed.connect(_on_virtual_move_changed)
	touch_controls.add_child(virtual_joystick)

	var jump_button := _make_control_button("↑", "jump", "跳跃", Vector2(112, 112))
	jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_button.offset_left = -148
	jump_button.offset_top = -156
	jump_button.offset_right = -36
	jump_button.offset_bottom = -44
	jump_button.add_theme_font_size_override("font_size", 44)
	touch_controls.add_child(jump_button)

func _on_virtual_move_changed(value: Vector2) -> void:
	if player:
		player.set_virtual_move(value)

func _make_control_button(symbol: String, action: String, hint: String, size := Vector2(58, 58)) -> Button:
	var button := Button.new()
	button.text = symbol
	button.custom_minimum_size = size
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = hint
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.94))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := _button_style(Color(0.035, 0.10, 0.13, 0.66), Color(1, 1, 1, 0.2), 29)
	var hover := _button_style(Color(0.06, 0.18, 0.21, 0.82), Color(1, 1, 1, 0.4), 29)
	var pressed := _button_style(Color(0.95, 0.63, 0.20, 0.92), Color.WHITE, 29)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.button_down.connect(_set_control_action.bind(action, true))
	button.button_up.connect(_set_control_action.bind(action, false))
	button.button_down.connect(_play_ui_click)
	return button

func _button_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func _set_control_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_control_actions() -> void:
	touch_camera_index=-1
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if virtual_joystick and virtual_joystick.has_method("_release_stick"):
		virtual_joystick._release_stick()
	if player:
		player.set_virtual_move(Vector2.ZERO)
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		Input.action_release(action)

func _hud_label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _show_intro() -> void:
	overlay_title.text = "第 %d 关 · %s" % [Campaign.level_index + 1, level_config["name"]]
	medal_row.hide()
	overlay_subtitle.text = "%s\n\n%s\n探索奖章：收齐 3 颗星晶 · 竞速奖章：%s 内到达\n绿色旗帜记录本关复活位置" % [level_config.hint, "找到 %d 把钥匙，开启终点" % required_keys if required_keys>0 else "沿金币路线前进，抵达终点旗塔", _format_duration(Campaign.speed_target())]
	if tutorial:
		overlay_subtitle.text="欢迎来到星跃岛！跟着左侧教学卡片，一步步熟悉操作。\n\n移动与金币 → 跳跃 → 检查点 → 星晶 → 终点\n这里没有敌人、不限时间，掉落不扣生命。\n星晶和竞速奖章都是可选挑战，可以慢慢练习。"
	overlay_button.text = "开始新手教程" if tutorial else "开始第 %d 关" % (Campaign.level_index + 1)
	overlay.visible = true
	pause_button.disabled = true
	player.active = false
	get_tree().paused = true

func _reload_stage() -> void:
	if transition_pending:
		return
	transition_pending = true
	_release_control_actions()
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()

func _on_overlay_button() -> void:
	if result_pending:
		_save_completion()
		return
	if transition_pending:
		return
	if game_finished:
		if game_won:
			if Campaign.is_last_level():
				Campaign.reset()
			else:
				Campaign.advance()
		_reload_stage()
		return
	if get_tree().paused and game_started:
		get_tree().paused = false
		overlay.visible = false
		hud.move_child(top_bar,0)
		player.active = not respawn_pending
		return
	get_tree().paused = false
	game_started = true
	elapsed_time = 0.0
	completion_score = 0
	completion_reward = 0
	player.active = true
	pause_button.disabled = false
	overlay.visible = false
	if tutorial: tutorial.update()
	else: _flash_banner(level_config["hint"])

func _toggle_pause() -> void:
	if not game_started or game_finished:
		return
	if is_instance_valid(selector) or is_instance_valid(shop) or is_instance_valid(settings_panel):
		return
	_release_control_actions()
	var paused := not get_tree().paused
	get_tree().paused = paused
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if paused:
		medal_row.hide()
		overlay_title.text = "暂 停"
		overlay_subtitle.text = "鼠标已显示，可以点击上方的地图、衣橱或设置。\n点击继续或按 Esc 返回游戏。"
		overlay_button.text = "继续"
		overlay.visible = true
		# Sibling order controls both drawing and GUI hit testing.
		hud.move_child(top_bar,overlay.get_index())
	else:
		overlay.visible = false
		hud.move_child(top_bar,0)

func _toggle_fullscreen() -> void:
	if Engine.is_embedded_in_editor():
		_flash_banner("编辑器游戏视图已启用拉伸适配")
		return
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_viewport_resized() -> void:
	if not camera:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	camera.keep_aspect = Camera3D.KEEP_WIDTH if aspect < 1.25 else Camera3D.KEEP_HEIGHT
	camera.fov = 59.0 if aspect < 1.25 else 51.0

func _on_coin_collected(value: int) -> void:
	coin_label.text = "金币 %d / %d" % [value, total_coins]
	if value == total_coins:
		_flash_banner("全部星币已收集！")

func _on_health_changed(value: float) -> void:
	if is_instance_valid(health_bar):
		health_bar.value = clampf(value, 0.0, IslandPlayer.MAX_HEALTH)
	var value_text := str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	health_label.text = "生命 %s/%d" % [value_text, int(IslandPlayer.MAX_HEALTH)]
	if value <= 0:
		_end_game(false, "再试一次")

func _on_player_fell() -> void:
	if respawn_pending or not player.active or game_finished or transition_pending:
		return
	respawn_pending = true
	_release_control_actions()
	player.active = false
	player.velocity = Vector3.ZERO
	player.external_drift = Vector3.ZERO
	if not tutorial: player.lose_life()
	if player.health > 0:
		_flash_banner(("放心练习，不扣生命 · " if tutorial else "") + ("回到存档点" if player.spawn_position.distance_to(stage_spawn)>1 else "再来一次，回到起点"))
		# Freeze the countdown in pause menus and teleport on a physics frame.
		await get_tree().create_timer(0.55, false, true).timeout
		if not game_finished and not transition_pending:
			player.respawn()
			_recenter_camera()
			camera_focus_valid=false
			player.active = true
	respawn_pending = false

func _on_goal_entered(body: Node3D) -> void:
	if body == player and game_started and not game_finished:
		if is_instance_valid(postal) and not postal.is_complete():
			if goal_notice_cooldown<=0:
				_flash_banner("还有信件未投递 · 跟随邮亭上方的信封标记")
				goal_notice_cooldown=2.0
			return
		if keys < required_keys:
			if goal_notice_cooldown <= 0:
				_flash_banner("还差 %d 把钥匙，沿途寻找金色钥匙" % (required_keys-keys))
				goal_notice_cooldown = 2.0
			return
		_end_game(true, "登岛成功")

func _end_game(won: bool, title: String) -> void:
	if game_finished:
		return
	hud.move_child(top_bar,0)
	play_sfx(SOUND_GOAL if won else SOUND_FAIL, -1.5, 1.0)
	_release_control_actions()
	game_finished = true
	game_won = won
	player.active = false
	pause_button.disabled = true
	get_tree().paused = true
	overlay_title.text = title
	medal_row.hide()
	if won:
		var fast := elapsed_time<=Campaign.speed_target()
		reward_data=Wardrobe.completion_reward(stars,fast)
		completion_reward=int(reward_data.coins)
		completion_score=100 if fast else 0
		for child in medal_row.get_children(): child.queue_free()
		for entry in [["旅程完成",true],["探索大师",stars==3],["疾风旅人",fast]]:
			var badge := PanelContainer.new()
			badge.custom_minimum_size=Vector2(190,56)
			badge.add_theme_stylebox_override("panel",_button_style(Color("32594f") if entry[1] else Color("26333f"),Color("d7c284") if entry[1] else Color("4f626c"),12))
			var label := _hud_label(("★  " if entry[1] else "☆  ")+entry[0],20,Color("fff0c1") if entry[1] else Color("91a2b2"))
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			badge.add_child(label)
			medal_row.add_child(badge)
		medal_row.show()
		var all_done := Campaign.is_last_level() and (Campaign.unlock_all_levels or Campaign.completed.slice(0,Campaign.LEVELS.size()-1).count(true)==Campaign.LEVELS.size()-1)
		overlay_title.text=("全部 %d 关通关！" % Campaign.LEVELS.size() if all_done else "第 %d 关通过！" % (Campaign.level_index+1))
		if tutorial: overlay_title.text="新手教程完成！"
		result_text="用时 %s  ·  竞速目标 %s\n金币 %d / %d  ·  星晶 %d / 3\n%s" % [_format_duration(elapsed_time),_format_duration(Campaign.speed_target()),player.coins,total_coins,stars,"通关奖励 %d 金币 · 首通、首次星晶与竞速分别奖励" % completion_reward]
		if not Campaign.unlock_all_levels:
			var total := Campaign.total_stars()+maxi(0,stars-Campaign.stars_by_level[Campaign.level_index])
			result_text+="\n星晶收藏 %d / 150 · 9 / 30 / 75 颗领取主题皮肤" % total
		_save_completion()
	else:
		overlay_subtitle.text="第 %d 关 · %s\n本次收集 %d 枚金币，已放入钱包。再试一次吧！" % [Campaign.level_index+1,level_config.name,player.coins]
		overlay_button.text="重试本关"
	overlay.visible=true

func _save_completion() -> void:
	if not reward_saved:
		var total := Campaign.total_stars()+maxi(0,stars-Campaign.stars_by_level[Campaign.level_index])
		reward_saved=Wardrobe.grant_completion(reward_data,total)
	var saved := reward_saved and Campaign.record_win(player.coins,stars,elapsed_time)
	result_pending=not saved
	overlay_subtitle.text=result_text+("\n保存未完成，请重试；已到账奖励不会重复发放。" if not saved else "")
	overlay_button.text="重试保存" if not saved else ("返回第一关" if Campaign.is_last_level() else "进入下一关")

func _completion_result(duration: float) -> Dictionary:
	return Wardrobe.completion_reward(stars,duration<=Campaign.speed_target())

func _format_duration(duration: float) -> String:
	var seconds := maxi(0, int(floor(duration)))
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func _update_time() -> void:
	if tutorial:
		time_label.text = "练习不限时"
		return
	var seconds := int(ceil(time_left))
	time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if seconds <= 30:
		time_label.add_theme_color_override("font_color", Color("#ff776e"))

func _flash_banner(message: String) -> void:
	banner_label.text = message
	banner_label.modulate = Color.WHITE
	if banner_tween: banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_interval(3.3)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.5)

static func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func collect_special(kind: String) -> void:
	if kind == "star":
		stars += 1
		if not tutorial: time_left += 10
		play_sfx(SOUND_KEY, -2.5, 1.12)
		_flash_banner("星晶 %d / 3 · %s" % [stars,"全部找到！" if stars == 3 else ("探索收集，不影响通关" if tutorial else "时间 +10 秒！")])
	elif kind == "key":
		keys += 1
		play_sfx(SOUND_KEY, -2.5, 0.94)
		_flash_banner("钥匙 %d / %d · %s" % [keys,required_keys,"终点已解锁！" if keys == required_keys else "继续寻找"])
	_update_special_label()

func _update_special_label() -> void:
	special_label.text = "星晶 %d / 3" % stars
	if is_instance_valid(postal): special_label.text += "   信件 %d / 2" % postal.delivered_count()
	if required_keys > 0: special_label.text += "  钥匙 %d/%d" % [keys,required_keys]

func _on_enemy_stomped(_pos: Vector3) -> void:
	time_left += 3.0
	play_sfx(SOUND_LAND, -4.0, 1.35)
	_flash_banner("漂亮的踩踏！时间 +3 秒")

func _show_selector() -> void:
	if is_instance_valid(selector) or is_instance_valid(shop) or is_instance_valid(settings_panel): return
	_release_control_actions()
	selector_was_paused = get_tree().paused
	selector_page = Campaign.level_index / 10
	get_tree().paused = true
	selector = ColorRect.new()
	selector.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selector.color = Color("101f30")
	hud.add_child(selector)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position = Vector2(-500,-265)
	column.size = Vector2(1000,530)
	column.add_theme_constant_override("separation",20)
	selector.add_child(column)
	var title := _hud_label("五十世界 · 冒险地图",34,Color("ffdda3"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	selector_heading = _hud_label("",22,Color("c7dae6"))
	selector_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(selector_heading)
	selector_grid = GridContainer.new()
	selector_grid.columns = 5
	selector_grid.add_theme_constant_override("h_separation",12)
	selector_grid.add_theme_constant_override("v_separation",18)
	column.add_child(selector_grid)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation",24)
	column.add_child(navigation)
	selector_previous = Button.new()
	selector_previous.text = "← 上一章"
	selector_previous.custom_minimum_size = Vector2(200,48)
	selector_previous.pressed.connect(_change_selector_page.bind(-1))
	_bind_ui_sound(selector_previous)
	navigation.add_child(selector_previous)
	var back := Button.new()
	back.text = "返回游戏"
	back.custom_minimum_size = Vector2(240,48)
	back.pressed.connect(_close_selector)
	_bind_ui_sound(back)
	navigation.add_child(back)
	selector_next = Button.new()
	selector_next.text = "下一章 →"
	selector_next.custom_minimum_size = Vector2(200,48)
	selector_next.pressed.connect(_change_selector_page.bind(1))
	_bind_ui_sound(selector_next)
	navigation.add_child(selector_next)
	_draw_selector_page()

func _change_selector_page(direction: int) -> void:
	selector_page = clampi(selector_page+direction,0,(Campaign.LEVELS.size()-1)/10)
	_draw_selector_page()

func _draw_selector_page() -> void:
	for child in selector_grid.get_children():
		selector_grid.remove_child(child)
		child.queue_free()
	var chapters := ["启程 · 熟悉跳跃","奇境 · 新的机关","险途 · 掌握节奏","挑战 · 连续应变","星冠 · 综合试炼"]
	selector_heading.text = "第 %d / 5 章   %s   ·   关卡 %02d—%02d" % [selector_page+1,chapters[selector_page],selector_page*10+1,mini(selector_page*10+10,Campaign.LEVELS.size())]
	selector_previous.disabled = selector_page==0
	selector_next.disabled = selector_page==(Campaign.LEVELS.size()-1)/10
	for i in range(selector_page*10,mini((selector_page+1)*10,Campaign.LEVELS.size())):
		var data: Dictionary = Campaign.LEVELS[i]
		var button := Button.new()
		button.name = "Level_%02d" % (i+1)
		button.custom_minimum_size = Vector2(190,118)
		var unlocked := Campaign.unlock_all_levels or i <= Campaign.unlocked
		button.text = "%02d  %s\n\n%s" % [i+1,data.name,"◆ ".repeat(Campaign.stars_by_level[i])+"◇ ".repeat(3-Campaign.stars_by_level[i]) if unlocked else "通过前一关解锁"]
		if unlocked:
			button.text+="\n"+("★通关 " if Campaign.completed[i] else "☆通关 ")+("★探索 " if Campaign.stars_by_level[i]==3 else "☆探索 ")+("★竞速" if Campaign.speed_medals[i] else "☆竞速")
		button.disabled = not unlocked
		button.tooltip_text = data.hint+"\n竞速目标 "+_format_duration(Campaign.speed_target(i))
		button.add_theme_font_size_override("font_size",17)
		_bind_ui_sound(button)
		button.add_theme_stylebox_override("normal",_button_style(Color(data.palette[2]).lightened(.08),Color(data.palette[5]),12))
		button.add_theme_stylebox_override("hover",_button_style(Color(data.palette[0]),Color("fff0c0"),12))
		button.add_theme_stylebox_override("disabled",_button_style(Color(data.palette[2]).darkened(.35),Color(data.palette[5]).darkened(.65),12))
		button.pressed.connect(_select_stage.bind(i))
		selector_grid.add_child(button)

func _close_selector() -> void:
	if not is_instance_valid(selector): return
	selector.queue_free()
	selector = null
	get_tree().paused = selector_was_paused

func _select_stage(index: int) -> void:
	Campaign.select_level(index)
	_reload_stage()

func _update_wallet() -> void:
	wallet_label.text="钱包 ∞" if Wardrobe.infinite_coins else "钱包 %d" % Wardrobe.balance

func _show_shop() -> void:
	if is_instance_valid(shop) or is_instance_valid(selector) or is_instance_valid(settings_panel): return
	_release_control_actions()
	shop_was_paused=get_tree().paused
	get_tree().paused=true
	shop=SHOP_SCRIPT.new()
	hud.add_child(shop)
	shop.closed.connect(_close_shop)

func _close_shop() -> void:
	if not is_instance_valid(shop): return
	shop.queue_free()
	shop=null
	get_tree().paused=shop_was_paused

func _rotate_camera(motion: Vector2) -> void:
	camera_yaw=wrapf(camera_yaw-motion.x*.005*Campaign.camera_sensitivity,-PI,PI)
	camera_pitch=clampf(camera_pitch+motion.y*.004*Campaign.camera_sensitivity,.14,1.05)

func _recenter_camera() -> void:
	camera_yaw=player.facing_yaw
	camera_pitch=.42

func _set_device(kind: String) -> void:
	if device_kind==kind: return
	device_kind=kind
	_refresh_input_hint()
	if kind=="gamepad" and is_instance_valid(overlay) and overlay.visible: overlay_button.grab_focus()

func _refresh_input_hint() -> void:
	if not is_instance_valid(touch_controls): return
	touch_controls.visible=Campaign.touch_preference==1 or (Campaign.touch_preference==0 and (device_kind=="touch" or DisplayServer.is_touchscreen_available()))
	if Campaign.touch_preference==2: touch_controls.hide()
	if not touch_controls.visible: _on_virtual_move_changed(Vector2.ZERO)
	if not is_instance_valid(input_hint): return
	match device_kind:
		"gamepad": input_hint.text="左摇杆 移动    A 跳跃    右摇杆 视角    按下右摇杆 回正"
		"touch": input_hint.text="左侧摇杆 移动    右侧按钮 跳跃    单指滑动空白处 转动视角"
		_: input_hint.text="WASD 移动    空格 跳跃    滑动触控板 / 移动鼠标 转视角    Q 镜头回正    Esc 暂停 / 显示鼠标"
	input_hint.visible=not touch_controls.visible

func _show_settings() -> void:
	if is_instance_valid(settings_panel) or is_instance_valid(selector) or is_instance_valid(shop): return
	_release_control_actions()
	settings_was_paused=get_tree().paused
	get_tree().paused=true
	settings_panel=ColorRect.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel.color=Color(.04,.08,.13,.97)
	hud.add_child(settings_panel)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.position=Vector2(-260,-170)
	column.size=Vector2(520,340)
	column.add_theme_constant_override("separation",22)
	settings_panel.add_child(column)
	column.add_child(_hud_label("让操作更顺手",32,Color("fff0d3")))
	var sensitivity := _hud_label("镜头灵敏度  %.1f×" % Campaign.camera_sensitivity,20,Color.WHITE)
	column.add_child(sensitivity)
	var slider := HSlider.new()
	slider.min_value=.4; slider.max_value=2.0; slider.step=.1
	slider.value=Campaign.camera_sensitivity
	slider.custom_minimum_size.y=28
	slider.value_changed.connect(func(value: float): Campaign.camera_sensitivity=value; sensitivity.text="镜头灵敏度  %.1f×" % value)
	column.add_child(slider)
	var touch := OptionButton.new()
	for label in ["屏幕摇杆：自动识别设备","屏幕摇杆：始终显示","屏幕摇杆：隐藏"]: touch.add_item(label)
	touch.selected=Campaign.touch_preference
	touch.custom_minimum_size.y=46
	touch.item_selected.connect(func(value: int): Campaign.touch_preference=value; _refresh_input_hint())
	column.add_child(touch)
	column.add_child(_hud_label("镜头回正：Q / 按下手柄右摇杆\n通关后解锁下一关，可在冒险地图重玩已解锁关卡",17,Color("bdced7")))
	var back := Button.new()
	back.text="保存并返回"
	back.custom_minimum_size.y=48
	back.pressed.connect(_close_settings)
	column.add_child(back)
	back.grab_focus()

func _close_settings() -> void:
	if not is_instance_valid(settings_panel): return
	if not Campaign.save_settings():
		_flash_banner("设置保存失败，请重试")
		return
	settings_panel.queue_free()
	settings_panel=null
	get_tree().paused=settings_was_paused
