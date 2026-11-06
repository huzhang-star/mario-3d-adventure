class_name IslandPlayer
extends CharacterBody3D

const CHARACTER_MODEL := preload("res://assets/kenney/models/character.glb")
const MODEL_SCALE := 1.50
const SKIN_STYLE = preload("res://scripts/skin_style.gd")
const SHADOW_TEXTURE := preload("res://assets/kenney/sprites/blob_shadow.png")
const SOUND_JUMP := preload("res://assets/kenney/sounds/jump.ogg")
const SOUND_LAND := preload("res://assets/kenney/sounds/land.ogg")
const SOUND_WALK := preload("res://assets/kenney/sounds/walking.ogg")
const SOUND_FALL := preload("res://assets/kenney/sounds/fall.ogg")
const SOUND_HURT := preload("res://assets/audio/hurt.wav")

signal coin_collected(total: int)
signal health_changed(value: float)
signal reached_goal
signal fell

const SPEED := 7.0
const ACCELERATION := 34.0
const AIR_ACCELERATION := 14.0
const JUMP_VELOCITY := 11.7
const GRAVITY := 27.5
const MAX_HEALTH := 3.0
const ENEMY_DAMAGE := 0.5

@export var sound_enabled := true

var health := MAX_HEALTH
var coins := 0
var active := false
var invulnerable := 0.0
var coyote_time := 0.0
var jump_buffer := 0.0
var spawn_position := Vector3.ZERO
var fall_boundary_y := -4.5
var checkpoint_index := -1
var landing_marker: MeshInstance3D

var facing_yaw := PI
var spawn_yaw := PI
var launch_protection := 0.0
var surface_ice := false
var external_drift := Vector3.ZERO

var _camera: Camera3D
var _visual: Node3D
var _dust: GPUParticles3D
var _sound_effect: AudioStreamPlayer3D
var _footsteps: AudioStreamPlayer3D
var _was_on_floor := false
var _pose_landed := false
var _animation: AnimationPlayer
var _input_axes := Vector2.ZERO
var virtual_move := Vector2.ZERO
var _input_forward := Vector3.FORWARD
var _input_right := Vector3.RIGHT
var move_direction := Vector3.ZERO
var _landing_compression := 0.0

func _ready() -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	_build_collision()
	_build_visual()

func setup(camera: Camera3D, start: Vector3) -> void:
	_camera = camera
	spawn_position = start
	global_position = start
	facing_yaw = PI
	_visual.rotation.y = facing_yaw

func set_virtual_move(value: Vector2) -> void:
	virtual_move = value.limit_length()

func _process(delta: float) -> void:
	_update_landing_marker()
	_update_animation(delta,_pose_landed)
	_pose_landed = false

func _physics_process(delta: float) -> void:
	if not active:
		# A dead player must stay still until the single respawn completes.
		velocity = Vector3.ZERO
		external_drift = Vector3.ZERO
		if _footsteps and _footsteps.playing:
			_footsteps.stop()
		return

	launch_protection = maxf(0, launch_protection - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	if invulnerable > 0.0:
		_visual.visible = int(invulnerable * 12.0) % 2 == 0
	else:
		_visual.visible = true

	if is_on_floor():
		coyote_time = 0.13
	else:
		coyote_time = maxf(0.0, coyote_time - delta)
		var gravity_scale := 1.18 if velocity.y < 0.0 else 0.92
		velocity.y -= GRAVITY * gravity_scale * delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.14
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)

	if jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0.0
		coyote_time = 0.0
		_play_sound(SOUND_JUMP, 1.05)

	if Input.is_action_just_released("jump") and velocity.y > 3.5 and launch_protection <= 0:
		velocity.y *= 0.55

	# A mouse-owned camera never steers itself from character rotation.
	# Movement is relative to the view, including while dragging it.
	var axes := Vector2(Input.get_axis("move_left","move_right"),Input.get_axis("move_back","move_forward")).limit_length()
	if virtual_move.length_squared() > 0.0001:
		axes = virtual_move
	_input_forward = get_facing_direction()
	_input_right = _input_forward.cross(Vector3.UP)
	if is_instance_valid(_camera):
		_input_right = (_camera.global_basis.x*Vector3(1,0,1)).normalized()
		_input_forward = Vector3.UP.cross(_input_right)
	_input_axes = axes
	var direction := (_input_forward*axes.y+_input_right*axes.x).limit_length()
	move_direction=direction
	if direction.length_squared()>.01:
		facing_yaw=lerp_angle(facing_yaw,atan2(direction.x,direction.z),1-exp(-delta*14))
	_visual.rotation.y = facing_yaw
	var desired_velocity := direction * SPEED + external_drift
	external_drift = Vector3.ZERO
	var accel := (7.0 if surface_ice else ACCELERATION) if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, desired_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, accel * delta)

	var falling_speed := velocity.y
	move_and_slide()
	if global_position.y <= fall_boundary_y:
		# Clamp fast falls before rendering or pausing on the failure screen.
		global_position.y = fall_boundary_y
		velocity = Vector3.ZERO
		external_drift = Vector3.ZERO
		_play_sound(SOUND_FALL, 1.0)
		fell.emit()
		return
	var just_landed := is_on_floor() and not _was_on_floor and velocity.y <= 0.0
	if just_landed:
		_dust.restart()
		_play_sound(SOUND_LAND, 1.0)
	_pose_landed = _pose_landed or just_landed
	_was_on_floor = is_on_floor()

	surface_ice = false
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("ice") and collision.get_normal().y > .5:
			surface_ice = true
		if collider and collider.is_in_group("enemy"):
			var enemy_position: Vector3 = collider.global_position
			if falling_speed < 0.0 and (collision.get_normal().y > .5 or global_position.y > enemy_position.y + .95):
				collider.call("squash")
				velocity.y = 8.0
			else:
				take_damage(enemy_position)

func launch(strength: float) -> void:
	velocity.y = strength
	launch_protection = .7
	coyote_time = 0
	jump_buffer = 0
	_play_sound(SOUND_JUMP, 1.2)

func get_facing_direction() -> Vector3:
	return Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))

func take_damage(source: Vector3, amount: float = ENEMY_DAMAGE) -> void:
	if invulnerable > 0.0 or not active:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	_play_sound(SOUND_HURT, 1.0)
	invulnerable = 1.6
	var knockback := (global_position - source).normalized()
	velocity = Vector3(knockback.x * 8.0, 7.5, knockback.z * 8.0)

func lose_life() -> void:
	health = maxf(0.0, health - 1.0)
	health_changed.emit(health)

func collect_coin() -> bool:
	if not get_node("/root/Wardrobe").earn(1): return false
	coins += 1
	coin_collected.emit(coins)
	return true

func respawn() -> void:
	global_position = spawn_position
	facing_yaw = spawn_yaw
	_visual.rotation.y = facing_yaw
	velocity = Vector3.ZERO
	external_drift = Vector3.ZERO
	launch_protection = 0
	coyote_time = 0.0
	jump_buffer = 0.0
	_was_on_floor = false
	_pose_landed = false
	_landing_compression = 0.0
	_visual.visible = true
	_input_axes=Vector2.ZERO
	virtual_move=Vector2.ZERO
	move_direction=Vector3.ZERO
	surface_ice = false
	invulnerable = 1.2

func reset_stats() -> void:
	checkpoint_index = -1
	health = MAX_HEALTH
	coins = 0
	health_changed.emit(health)
	coin_collected.emit(coins)
	respawn()

func _build_collision() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.60
	collider.shape = capsule
	collider.position.y = 0.8
	add_child(collider)

func _build_visual() -> void:
	_visual = CHARACTER_MODEL.instantiate()
	_visual.name = "CuteExplorer"
	_visual.scale = Vector3.ONE*MODEL_SCALE
	add_child(_visual)
	for child in _visual.find_children("*","MeshInstance3D",true,false):
		for surface in child.mesh.get_surface_count():
			var source=child.get_active_material(surface)
			if source is StandardMaterial3D:
				var material=source.duplicate()
				material.roughness=.68
				child.set_surface_override_material(surface,material)
	_animation=_visual.find_child("AnimationPlayer",true,false)
	for clip in ["idle","walk"]:
		_animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	_animation.play("idle")
	apply_skin(get_node("/root/Wardrobe").equipped)
	get_node("/root/Wardrobe").changed.connect(_refresh_skin)

	var shadow := Decal.new()
	shadow.name = "SoftShadow"
	shadow.size = Vector3(1.15, 2.0, 1.15)
	shadow.position.y = 0.05
	shadow.texture_albedo = SHADOW_TEXTURE
	shadow.modulate = Color(1, 1, 1, 0.58)
	shadow.normal_fade = 0.5
	add_child(shadow)

	_sound_effect = AudioStreamPlayer3D.new()
	_sound_effect.volume_db = -3.0
	add_child(_sound_effect)
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.stream = SOUND_WALK
	_footsteps.volume_db = -10.0
	add_child(_footsteps)
	_build_dust()
	_build_landing_marker()

func _update_animation(delta: float, just_landed: bool) -> void:
	var speed := Vector2(velocity.x,velocity.z).length()
	var moving := active and speed>.25 and move_direction.length_squared()>.01
	var clip := "walk" if moving else "idle"
	if not is_on_floor() and active: clip="jump"
	if _animation.current_animation != clip: _animation.play(clip,.16)
	# Authored paired-leg animation replaces independent IK feet. Walk cadence
	# follows actual speed; the body keeps its natural shape while landing.
	var playback := clampf(speed/SPEED, .45, 1.05) if clip=="walk" else 1.0
	_animation.speed_scale=lerpf(_animation.speed_scale,playback,1-exp(-delta*12))
	if just_landed: _landing_compression=.035
	_landing_compression=move_toward(_landing_compression,0,delta*.22)
	_visual.position.y=-_landing_compression
	if sound_enabled and active and is_on_floor() and moving:
		_footsteps.pitch_scale=clampf(speed/SPEED,.8,1.2)
		if not _footsteps.playing: _footsteps.play()
	elif _footsteps.playing: _footsteps.stop()

func _play_sound(stream: AudioStream, pitch: float) -> void:
	if not sound_enabled: return
	_sound_effect.stream = stream
	_sound_effect.pitch_scale = pitch
	_sound_effect.play()

func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.amount = 12
	_dust.lifetime = 0.48
	_dust.one_shot = true
	_dust.emitting = false
	_dust.explosiveness = 0.95
	_dust.position.y = 0.08
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.42
	process_material.direction = Vector3.UP
	process_material.spread = 78.0
	process_material.initial_velocity_min = 0.7
	process_material.initial_velocity_max = 1.8
	process_material.gravity = Vector3(0, -2.5, 0)
	process_material.scale_min = 0.45
	process_material.scale_max = 1.15
	process_material.color = Color(0.95, 0.88, 0.72, 0.62)
	_dust.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.95, 0.9, 0.78, 0.62)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = dust_material
	_dust.draw_pass_1 = quad
	add_child(_dust)

var applied_skin := ""

func apply_skin(id: String) -> void:
	applied_skin=id
	SKIN_STYLE.apply(_visual,id)

func _refresh_skin() -> void:
	if applied_skin!=get_node("/root/Wardrobe").equipped: apply_skin(get_node("/root/Wardrobe").equipped)

func _build_landing_marker() -> void:
	landing_marker=MeshInstance3D.new()
	landing_marker.name="LandingGuide"
	var quad := PlaneMesh.new()
	quad.size=Vector2(1.25,1.25)
	landing_marker.mesh=quad
	var shader := Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment(){
 float r=length(UV-vec2(.5))*2.0;
 float ring=1.0-smoothstep(.035,.09,abs(r-.72));
 float core=1.0-smoothstep(.1,.48,r);
 ALBEDO=mix(vec3(.08,.17,.22),vec3(.92,1.0,.82),ring);
 ALPHA=max(ring*.8,core*.32);
}"""
	var mat := ShaderMaterial.new()
	mat.shader=shader
	landing_marker.material_override=mat
	landing_marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(landing_marker)
	landing_marker.top_level=true

func _update_landing_marker() -> void:
	if not is_instance_valid(landing_marker): return
	landing_marker.hide()
	if not active or is_on_floor(): return
	# Shows the surface directly below, never promises a ballistic landing.
	var from := global_position+Vector3.UP*.15
	var ray := PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*18,1,[get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y<.7 or not hit.collider.is_in_group("course_surface"): return
	landing_marker.global_position=hit.position+Vector3.UP*.035
	landing_marker.show()
