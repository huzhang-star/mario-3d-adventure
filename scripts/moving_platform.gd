class_name MovingIslandPlatform
extends AnimatableBody3D

const PLATFORM_MODEL := preload("res://assets/kenney/models/platform-medium.glb")

var origin := Vector3.ZERO
var travel := Vector3.ZERO
var duration := 2.0
var elapsed := 0.0

func setup(size: Vector3, movement: Vector3, seconds: float, material: Material) -> void:
	origin = position
	travel = movement
	duration = seconds
	sync_to_physics = true

	var model := PLATFORM_MODEL.instantiate()
	model.position.y = -size.y * 0.5
	model.scale = Vector3(size.x / 3.0, size.y / 0.55, size.z / 3.0)
	add_child(model)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	elapsed += delta
	var t := (sin(elapsed * TAU / duration - PI / 2.0) + 1.0) * 0.5
	position = origin + travel * t
