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

var shop: ColorRect
var shop_was_paused := false
var wallet_label: Label
var camera_yaw := PI
var camera_pitch := 0.42
var camera_distance := 11.5
var camera_dragging := false
var camera_mouse_origin := Vector2.ZERO
var orbit_yaw := PI
var orbit_pitch := 0.42

var player: IslandPlayer
var camera: Camera3D
var camera_target := Vector3.ZERO
var hud: CanvasLayer
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
	music_player.volume_db = -15.0
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
	Campaign.save_progress()
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
	goal_notice_cooldown = maxf(0,goal_notice_cooldown-delta)
	if player and camera:
		if get_tree().paused and camera_dragging: _stop_camera_drag()
		orbit_yaw=lerp_angle(orbit_yaw,camera_yaw,1.0-exp(-delta*18.0))
		orbit_pitch=lerpf(orbit_pitch,camera_pitch,1.0-exp(-delta*18.0))
		var forward := Vector3(sin(orbit_yaw),0,cos(orbit_yaw))
		var focus := player.global_position+Vector3.UP*.85
		camera_target=focus-forward*cos(orbit_pitch)*camera_distance+Vector3.UP*sin(orbit_pitch)*camera_distance
		# Pull the camera in at solid geometry instead of passing through it.
		var ray := PhysicsRayQueryParameters3D.create(focus,camera_target,1,[player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): camera_target=hit.position+hit.normal*.3
		camera.global_position=camera_target
		camera.look_at(focus,Vector3.UP)

	if game_started and not game_finished and not get_tree().paused:
		elapsed_time += delta
		time_left = maxf(0.0, time_left - delta)
		_update_time()
		if time_left <= 0.0:
			_end_game(false, "时间到")

func _configure_window_scaling() -> void:
	var window := get_window()
	window.content_scale_size = DISPLAY_BASE_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		_stop_camera_drag()
	if event is InputEventMouseMotion and camera_dragging and not get_tree().paused:
		camera_yaw=wrapf(camera_yaw-event.relative.x*.005,-PI,PI)
		camera_pitch=clampf(camera_pitch+event.relative.y*.004,.14,1.05)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: _stop_camera_drag()

func _stop_camera_drag() -> void:
	if not camera_dragging: return
	camera_dragging=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(camera_mouse_origin)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(shop):
		if event.is_action_pressed("pause"): _close_shop()
		return
	if event is InputEventMouseButton and game_started and not game_finished and not get_tree().paused:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			camera_mouse_origin=get_viewport().get_mouse_position()
			camera_dragging=true
			Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
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
	water.position = Vector3(0, -5.0, -24)
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

func _spawn_player() -> void:
	player = IslandPlayer.new()
	player.name = "Player"
	player.position = stage_spawn
	add_child(player)
	player.setup(camera, stage_spawn)
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

	var top_bar := PanelContainer.new()
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top_bar.add_child(row)
	health_label = _hud_label("生命 3/3", 18, Color("#ffd7d2"))
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(132, 20)
	health_bar.min_value = 0.0
	health_bar.max_value = IslandPlayer.MAX_HEALTH
	health_bar.step = IslandPlayer.ENEMY_DAMAGE
	health_bar.value = player.health
	health_bar.show_percentage = false
	health_bar.tooltip_text = "生命值"
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("#542a35")
	health_background.border_color = Color("#ffd7d2")
	health_background.set_border_width_all(1)
	health_background.set_corner_radius_all(5)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("#ff665e")
	health_fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", health_background)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	coin_label = _hud_label("本关 0/%d" % total_coins, 18, Color("#ffd54a"))
	time_label = _hud_label("05:00", 24, Color.WHITE)
	row.add_child(_hud_label("第 %d / %d 关 · %s" % [Campaign.level_index + 1, Campaign.LEVELS.size(), level_config["name"]], 19, Color("#d9f5ff")))
	row.add_child(health_label)
	row.add_child(health_bar)
	row.add_child(coin_label)
	wallet_label=_hud_label("",18,Color("ffd784"))
	row.add_child(wallet_label)
	Wardrobe.changed.connect(_update_wallet)
	_update_wallet()
	special_label = _hud_label("", 18, Color("#b7f0e5"))
	row.add_child(special_label)
	_update_special_label()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(time_label)

	sound_button = Button.new()
	sound_button.custom_minimum_size = Vector2(44, 42)
	sound_button.add_theme_font_size_override("font_size", 21)
	sound_button.pressed.connect(_toggle_audio)
	row.add_child(sound_button)
	_update_audio_button()

	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.custom_minimum_size = Vector2(44, 42)
	pause_button.add_theme_font_size_override("font_size", 22)
	pause_button.tooltip_text = "暂停"
	pause_button.pressed.connect(_toggle_pause)
	_bind_ui_sound(pause_button)
	row.add_child(pause_button)

	fullscreen_button = Button.new()
	fullscreen_button.text = "⛶"
	fullscreen_button.custom_minimum_size = Vector2(44, 42)
	fullscreen_button.add_theme_font_size_override("font_size", 22)
	fullscreen_button.tooltip_text = "全屏"
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	_bind_ui_sound(fullscreen_button)
	row.add_child(fullscreen_button)
	var worlds_button := Button.new()
	worlds_button.text = "关卡"
	worlds_button.custom_minimum_size = Vector2(64,42)
	worlds_button.pressed.connect(_show_selector)
	_bind_ui_sound(worlds_button)
	row.add_child(worlds_button)
	var shop_button := Button.new()
	shop_button.text="衣橱"
	shop_button.custom_minimum_size=Vector2(64,42)
	shop_button.pressed.connect(_show_shop)
	_bind_ui_sound(shop_button)
	row.add_child(shop_button)

	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_label.offset_top = 96
	banner_label.offset_bottom = 145
	banner_label.add_theme_font_size_override("font_size", 28)
	banner_label.add_theme_color_override("font_color", Color("#fff4bf"))
	banner_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	banner_label.add_theme_constant_override("shadow_offset_x", 2)
	banner_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(banner_label)
	_build_touch_controls()

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.065, 0.08, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(overlay)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-340, -180)
	center.size = Vector2(680, 360)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	overlay.add_child(center)

	overlay_title = Label.new()
	overlay_title.text = "星跃岛"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 42)
	overlay_title.add_theme_color_override("font_color", Color("#fff2ae"))
	center.add_child(overlay_title)

	overlay_subtitle = Label.new()
	overlay_subtitle.text = "拖动左下角摇杆移动   右下角按钮跳跃\nW / A / S / D 和方向键同样可用\n按住鼠标右键拖动视角 · 滚轮调整镜头距离\n沿金币路线到达旗塔即可过关"
	overlay_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_subtitle.add_theme_font_size_override("font_size", 21)
	overlay_subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	center.add_child(overlay_subtitle)

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
	_stop_camera_drag()
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
	overlay_subtitle.text = "%s\n\n拖动左下角摇杆移动   右下角按钮跳跃\nW / A / S / D 和方向键同样可用\n按住鼠标右键拖动视角 · 滚轮调整镜头距离\n%s\n每关 3 颗星晶可选收集 · 绿色旗帜是存档点" % [level_config["hint"], "找到 %d 把钥匙，再到达终点旗塔" % required_keys if required_keys > 0 else "沿金币路线到达旗塔即可过关"]
	overlay_button.text = "开始第 %d 关" % (Campaign.level_index + 1)
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
		player.active = true
		return
	get_tree().paused = false
	game_started = true
	elapsed_time = 0.0
	completion_score = 0
	completion_reward = 0
	player.active = true
	pause_button.disabled = false
	overlay.visible = false
	_flash_banner(level_config["hint"])

func _toggle_pause() -> void:
	if not game_started or game_finished:
		return
	_release_control_actions()
	var paused := not get_tree().paused
	get_tree().paused = paused
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if paused:
		overlay_title.text = "暂 停"
		overlay_subtitle.text = ""
		overlay_button.text = "继续"
		overlay.visible = true
	else:
		overlay.visible = false

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
	coin_label.text = "本关 %d/%d" % [value, total_coins]
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
	if not player.active:
		return
	_release_control_actions()
	player.active = false
	player.lose_life()
	if player.health > 0:
		_flash_banner("回到存档点" if player.spawn_position.distance_to(stage_spawn)>1 else "再来一次，回到起点")
		await get_tree().create_timer(0.55).timeout
		if not game_finished:
			player.respawn()
			player.active = true

func _on_goal_entered(body: Node3D) -> void:
	if body == player and game_started and not game_finished:
		if keys < required_keys:
			if goal_notice_cooldown <= 0:
				_flash_banner("还差 %d 把钥匙，沿途寻找金色钥匙" % (required_keys-keys))
				goal_notice_cooldown = 2.0
			return
		_end_game(true, "登岛成功")

func _end_game(won: bool, title: String) -> void:
	if game_finished:
		return
	play_sfx(SOUND_GOAL if won else SOUND_FAIL, -1.5, 1.0)
	_release_control_actions()
	game_finished = true
	game_won = won
	player.active = false
	pause_button.disabled = true
	get_tree().paused = true
	overlay_title.text = title
	if won:
		var result := _completion_result(elapsed_time)
		completion_score = int(result["score"])
		completion_reward = int(result["coins"])
		var reward_granted := Wardrobe.earn(completion_reward)
		Campaign.record_win(player.coins, stars)
		var reward_text := "奖励 %d 金币" % completion_reward if reward_granted else "金币保存失败，请稍后重试"
		if Campaign.is_last_level():
			overlay_title.text = "全部 %d 关通关！" % Campaign.LEVELS.size()
			overlay_subtitle.text = "全部 %d 个世界已征服！\n本次用时 %s · 评分 %d 分 · %s\n最佳记录：%d 枚金币 · %d / %d 颗星晶\n可以在冒险地图重玩，补齐隐藏星晶" % [Campaign.LEVELS.size(), _format_duration(elapsed_time), completion_score, reward_text, Campaign.total_collected(), Campaign.total_stars(), Campaign.LEVELS.size()*3]
			overlay_button.text = "从第一关再玩"
		else:
			overlay_title.text = "第 %d 关通过！" % (Campaign.level_index + 1)
			overlay_subtitle.text = "用时 %s · 评分 %d 分 · %s\n本关金币 %d / %d · 星晶 %d / 3\n下一关 · %s\n%s" % [_format_duration(elapsed_time), completion_score, reward_text, player.coins, total_coins, stars, Campaign.LEVELS[Campaign.level_index + 1]["name"], Campaign.LEVELS[Campaign.level_index + 1]["hint"]]
			overlay_button.text = "进入第 %d 关" % (Campaign.level_index + 2)
	else:
		overlay_subtitle.text = "第 %d 关 · %s\n本次收集 %d 枚星币，再试一次吧" % [Campaign.level_index + 1, level_config["name"], player.coins]
		overlay_button.text = "重试本关"
	overlay.visible = true

func _completion_result(duration: float) -> Dictionary:
	# Under one minute earns the top rating; one to two minutes earns the middle rating.
	if duration < 60.0:
		return {"score": 100, "coins": 100}
	if duration < 120.0:
		return {"score": 85, "coins": 85}
	return {"score": 50, "coins": 50}

func _format_duration(duration: float) -> String:
	var seconds := maxi(0, int(floor(duration)))
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func _update_time() -> void:
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
		time_left += 10
		play_sfx(SOUND_KEY, -2.5, 1.12)
		_flash_banner("星晶 %d / 3 · %s" % [stars,"全部找到！" if stars == 3 else "时间 +10 秒！"])
	elif kind == "key":
		keys += 1
		play_sfx(SOUND_KEY, -2.5, 0.94)
		_flash_banner("钥匙 %d / %d · %s" % [keys,required_keys,"终点已解锁！" if keys == required_keys else "继续寻找"])
	_update_special_label()

func _update_special_label() -> void:
	special_label.text = "◆ %d/3" % stars
	if required_keys > 0: special_label.text += "  钥匙 %d/%d" % [keys,required_keys]

func _on_enemy_stomped(_pos: Vector3) -> void:
	time_left += 3.0
	play_sfx(SOUND_LAND, -4.0, 1.35)
	_flash_banner("漂亮的踩踏！时间 +3 秒")

func _show_selector() -> void:
	if is_instance_valid(selector): return
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
	var help := _hud_label("全部关卡已开放 · 每关 3 颗星晶 · 最佳成绩自动保存",18,Color("9fb6c8"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help)
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
		button.disabled = not unlocked
		button.tooltip_text = data.hint
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
	if is_instance_valid(shop) or is_instance_valid(selector): return
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
