class_name StarCoin
extends Area3D

const COIN_MODEL := preload("res://assets/kenney/models/coin.glb")
const PARTICLE_TEXTURE := preload("res://assets/kenney/sprites/particle.png")
const COIN_SOUND := preload("res://assets/kenney/sounds/coin.ogg")

var base_y := 0.0
var elapsed := 0.0
var collected := false

func _ready() -> void:
	base_y = position.y
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_coin()

func _process(delta: float) -> void:
	if collected:
		return
	elapsed += delta
	rotation.y += delta * 2.8
	position.y = base_y + sin(elapsed * 2.5) * 0.16

func _on_body_entered(body: Node3D) -> void:
	if body is IslandPlayer and body.active and not collected:
		if not body.collect_coin(): return
		collected = true
		if body.sound_enabled: _play_collect_sound()
		set_deferred("monitoring", false)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18)
		tween.tween_property(self, "position:y", position.y + 1.2, 0.18)
		tween.chain().tween_callback(queue_free)

func _build_coin() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	shape.shape = sphere
	add_child(shape)

	var model := COIN_MODEL.instantiate()
	model.name = "CoinModel"
	model.scale = Vector3.ONE * 1.65
	model.position.y = -0.35
	add_child(model)

	var particles := GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 1.5
	particles.preprocess = 1.5
	particles.position.y = 0.1
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.08
	process_material.initial_velocity_max = 0.28
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.35
	process_material.scale_max = 0.9
	process_material.color = Color("#fff3a0")
	particles.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var sparkle_material := StandardMaterial3D.new()
	sparkle_material.albedo_texture = PARTICLE_TEXTURE
	sparkle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparkle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sparkle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparkle_material.emission_enabled = true
	sparkle_material.emission = Color("#ffd85e")
	sparkle_material.emission_energy_multiplier = 1.2
	quad.material = sparkle_material
	particles.draw_pass_1 = quad
	add_child(particles)

func _play_collect_sound() -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = COIN_SOUND
	sound.volume_db = -2.0
	get_tree().current_scene.add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
