extends Area3D
const S := preload("res://scripts/sculpt.gd")
const VENT := preload("res://scripts/vent_effect.gd")
const WIND := preload("res://scripts/wind_effect.gd")
var kind := "fire"
var rate := 1.0
var platform_width := 4.5
var elapsed := 0.0
var visual: Node3D
var hot := false
var warning: MeshInstance3D

func _ready() -> void:
	add_to_group("adventure_hazard")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6,2.6,1.6) if kind == "fire" else Vector3(4.5,3,4.5)
	shape.shape = box
	shape.position.y = 1.2
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	if kind == "fire":
		S.cylinder(self,Vector3(0,.05,0),.75,.1,S.material(Color("#554e59"),.6,.5))
		S.cylinder(self,Vector3(0,.115,0),.52,.025,S.material(Color("211e26"),.9))
		S.ring(self,Vector3(0,.14,0),.54,.065,S.material(Color("ad784e"),.38,.65))
		for i in 8:
			var a:=TAU*i/8
			S.orb(self,Vector3(cos(a)*.67,.12,sin(a)*.67),Vector3(.04,.025,.04),S.material(Color("d9ba8a"),.4,.55))
		warning = S.ring(self,Vector3(0,.12,0),.64,.06,S.material(Color("#ffb34f"),.3,0,1.1))
		var effect:=VENT.new()
		visual.add_child(effect)
	else:
		var effect:=WIND.new()
		effect.platform_width = platform_width
		visual.add_child(effect)

func _physics_process(delta: float) -> void:
	elapsed += delta*rate
	if kind == "fire":
		var phase := fmod(elapsed,4.6)
		hot = phase > 3.0
		warning.visible = phase > 2.0 and (hot or int(phase*10)%2==0)
		visual.get_child(0).update_effect(elapsed,hot)
	else:
		visual.get_child(0).update_effect(elapsed)
	for body in get_overlapping_bodies():
		if body is IslandPlayer and body.active:
			if kind == "fire" and hot:
				body.take_damage(global_position)
			elif kind == "wind":
				body.external_drift += Vector3(1.0+(sin(elapsed*1.1)+1.0)*.65,0,0)
