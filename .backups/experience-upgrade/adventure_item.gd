extends Area3D
const S := preload("res://scripts/sculpt.gd")
const CHECKPOINT := preload("res://scripts/checkpoint_model.gd")
const SOUND_CHECKPOINT := preload("res://assets/audio/checkpoint.wav")
var kind := "star"
var game: Node3D
var visual: Node3D
var activated := false
var elapsed := 0.0
var cooldown := 0.0
var checkpoint_yaw := PI
var checkpoint_model: Node3D

func _ready() -> void:
	add_to_group("adventure_item")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .75 if kind != "spring" else 1.05
	shape.shape = sphere
	shape.position.y = .6 if kind in ["spring","checkpoint"] else 0
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	var gold := S.material(Color("#ffcd65"),.3,.5,.35)
	var pearl := S.material(Color("#fff1c8"),.38)
	if kind == "star":
		var gem := S.cylinder(visual,Vector3.ZERO,.45,.65,gold,0,5)
		var lower := S.cylinder(visual,Vector3(0,-.46,0),.01,.32,gold,.45,5)
		S.ring(visual,Vector3(0,-.72,0),.48,.025,pearl)
	elif kind == "key":
		var ring := S.ring(visual,Vector3(0,.25,0),.25,.07,gold)
		ring.rotation.x = PI*.5
		S.box(visual,Vector3(0,-.19,0),Vector3(.11,.6,.11),gold)
		S.box(visual,Vector3(.1,-.37,0),Vector3(.25,.1,.11),gold)
	elif kind == "spring":
		S.cylinder(visual,Vector3(0,.15,0),.3,.3,pearl)
		S.lathe(visual,Vector3.ZERO,[Vector2(0,.3),Vector2(.85,.3),Vector2(1,.42),Vector2(.78,.62),Vector2(.3,.76),Vector2(0,.78)],S.material(Color("#ee647a"),.38))
		for i in 5:
			var a := i*TAU/5
			S.orb(visual,Vector3(cos(a)*.48,.69,sin(a)*.48),Vector3(.14,.045,.14),pearl)
	elif kind == "checkpoint":
		checkpoint_model = CHECKPOINT.new()
		visual.add_child(checkpoint_model)
	body_entered.connect(_entered)

func _process(delta: float) -> void:
	elapsed += delta
	cooldown = maxf(0,cooldown-delta)
	if kind in ["star","key"]:
		visual.rotation.y += delta*1.6
		visual.position.y = sin(elapsed*2.3)*.14
	if kind == "checkpoint":
		checkpoint_model.update_effect(elapsed,activated)
	if kind == "spring":
		visual.scale = visual.scale.lerp(Vector3.ONE,delta*8)
		# Re-evaluate overlap so a player landing on a mushroom can bounce again.
		if cooldown <= 0:
			for body in get_overlapping_bodies(): _entered(body)

func _entered(body: Node3D) -> void:
	if not body is IslandPlayer or not body.active: return
	if kind == "spring":
		if cooldown > 0 or body.velocity.y > 1.0 or body.position.y < global_position.y-.2: return
		body.launch(17.0)
		visual.scale = Vector3(1.18,.62,1.18)
		cooldown = .6
		return
	if activated: return
	activated = true
	if kind == "checkpoint":
		body.spawn_position = global_position + Vector3(0,.12,0)
		body.spawn_yaw = checkpoint_yaw
		checkpoint_model.update_effect(elapsed,true)
		if game and game.has_method("play_sfx"):
			game.play_sfx(SOUND_CHECKPOINT, -2.5, 1.0)
		game._flash_banner("存档点已点亮 · 掉落后从这里继续")
		return
	game.collect_special(kind)
	set_deferred("monitoring",false)
	var tween := create_tween()
	tween.tween_property(visual,"scale",Vector3.ONE*.01,.22)
	tween.tween_callback(queue_free)
