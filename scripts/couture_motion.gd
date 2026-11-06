extends Node3D
var elapsed := 0.0
var wings: Array[Node3D] = []
var ornaments: Array[Node3D] = []
var eyes: Array[Node3D] = []
var effects: Array[Node3D] = []

func _ready() -> void:
	refresh.call_deferred()

func refresh() -> void:
	wings.clear()
	ornaments.clear()
	eyes.clear()
	effects.clear()
	for item in get_parent().find_children("CoutureWing*","Node3D",true,false):
		wings.append(item)
	for item in get_parent().find_children("CoutureOrbit*","Node3D",true,false):
		ornaments.append(item)
	for item in get_parent().find_children("CoutureEye*","Node3D",true,false):
		eyes.append(item)
	for item in get_parent().find_children("CoutureFX*","Node3D",true,false):
		effects.append(item)

func _process(delta: float) -> void:
	elapsed+=delta
	for effect in effects:
		if not is_instance_valid(effect): continue
		var phase: float=effect.get_meta("phase",0.0)
		var origin: Vector3=effect.get_meta("origin",Vector3.ZERO)
		var t:=fmod(elapsed,TAU*100.0)
		effect.position=origin+Vector3(sin(t*.55+phase)*.014,sin(t*.72+phase)*.026,0)
		effect.rotation.z=sin(t*.65+phase)*.22
		effect.scale=Vector3.ONE*(.70+.30*pow(.5+.5*sin(t*1.1+phase),2))
	for i in wings.size():
		if is_instance_valid(wings[i]): wings[i].rotation.y=sin(elapsed*1.7)*.055*(-1 if i%2==0 else 1)
	for i in ornaments.size():
		if is_instance_valid(ornaments[i]):
			var angle:=elapsed*(.13 if i%2==0 else -.10)
			# The large rear halo spins in its own plane and never sweeps through the face.
			if ornaments[i].get_meta("vertical",false): ornaments[i].rotation.z=angle
			else: ornaments[i].rotation.y=angle
	var cycle:=fmod(elapsed,4.8)
	var blink:=1.0
	if cycle>4.57:
		var opening:=clampf(absf((cycle-4.685)/.115),0.0,1.0)
		blink=lerpf(.08,1.0,smoothstep(0.0,1.0,opening))
	for eye in eyes:
		if is_instance_valid(eye): eye.scale.y=blink
