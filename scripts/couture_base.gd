extends RefCounted
const G=preload("res://scripts/couture_geometry.gd")
const S=preload("res://scripts/sculpt.gd")

static func apply(model: Node3D, data: Dictionary) -> void:
	# Retain the imported animation pivots, replace only their rendered geometry.
	for part in model.find_children("*","MeshInstance3D",true,false):
		if part.name in ["torso","leg-left","leg-right","arm-left","arm-right","antenna"]:
			part.mesh=null
	for name in ["CoutureBase","CoutureLimb"]:
		for child in model.find_children(name,"Node3D",true,false):
			child.get_parent().remove_child(child)
			child.queue_free()
	var torso:=model.find_child("torso",true,false) as Node3D
	var root:=Node3D.new()
	root.name="CoutureBase"
	torso.add_child(root)
	var color:=Color(data.color)
	var suit:=G.satin(color)
	var hood:=G.satin(Color("f5f0e9"))
	var face:=S.material(Color("f5dcc7"),.72)
	var gold:=G.satin(Color(data.accent),.42)
	var white:=S.material(Color("fffdfa"),.25)
	var iris:=G.satin(color.darkened(.40),.1)
	var ink:=S.material(Color("242335"),.24)
	var blush:=S.material(Color("e9a8af"),.86)
	G.orb(root,Vector3(0,.07,0),Vector3(.205,.225,.17),suit)
	G.orb(root,Vector3(0,.485,-.022),Vector3(.293,.283,.244),hood)
	G.orb(root,Vector3(0,.463,.104),Vector3(.242,.231,.177),face)
	# A few scalloped locks frame the face instead of a flat mask.
	for i in 5:
		var x:=float(i-2)*.072
		var lock:=G.orb(root,Vector3(x,.655-absf(x)*.23,.187),Vector3(.066,.065,.061),hood)
		lock.rotation.z=float(i-2)*-.17
	for side in [-1,1]:
		G.orb(root,Vector3(side*.266,.478,-.012),Vector3(.052,.080,.071),hood)
		G.orb(root,Vector3(side*.174,.399,.219),Vector3(.050,.023,.010),blush)
		var eye:=Node3D.new()
		eye.name="CoutureEyeL" if side<0 else "CoutureEyeR"
		eye.position=Vector3(side*.093,.486,.251)
		root.add_child(eye)
		G.orb(eye,Vector3.ZERO,Vector3(.065,.077,.031),ink)
		G.orb(eye,Vector3(0,-.004,.020),Vector3(.052,.061,.019),white)
		G.orb(eye,Vector3(side*.003,-.003,.035),Vector3(.033,.050,.014),iris)
		G.orb(eye,Vector3(side*.003,0,.045),Vector3(.020,.034,.007),ink)
		G.orb(eye,Vector3(-.011,.020,.052),Vector3(.011,.014,.004),white)
		G.orb(eye,Vector3(.014,-.021,.050),Vector3(.005,.006,.003),white)
		G.curve(root,Vector3(side*.057,.586,.235),Vector3(side*.102,.604,.249),Vector3(side*.146,.584,.222),.009,iris)
		G.orb(root,Vector3(side*.15,.204,.11),Vector3(.080,.044,.055),hood).rotation.z=side*.4
	G.orb(root,Vector3(0,.422,.281),Vector3(.019,.016,.014),face)
	G.curve(root,Vector3(-.043,.366,.259),Vector3(0,.337,.285),Vector3(.043,.366,.259),.0065,S.material(Color("915e67"),.65))
	G.gem(root,Vector3(0,.145,.177),.032,gold)
	S.ring(root,Vector3(0,.035,0),.202,.009,gold).scale.z=.80
	for side in [-1,1]:
		var arm:=model.find_child("arm-right" if side>0 else "arm-left",true,false) as Node3D
		var limb:=Node3D.new()
		limb.name="CoutureLimb"
		arm.add_child(limb)
		# After swapping the source pivots, the right source shoulder needs the lift.
		if side>0: limb.position.y=.0555
		# Overlap the torso with a shoulder cap, then continue into a centered
		# upper arm and glove so the arm never appears detached in a walk pose.
		# The shoulder cap slightly overlaps the torso silhouette, removing the
		# hairline gap visible during side-facing walk poses.
		G.orb(limb,Vector3(0,-.018,0),Vector3(.108,.078,.082),suit).rotation.z=side*-.10
		G.orb(limb,Vector3(0,-.082,0),Vector3(.067,.112,.067),suit).rotation.z=side*-.16
		G.orb(limb,Vector3(0,-.180,.012),Vector3(.073,.067,.065),hood)
		S.ring(limb,Vector3(0,-.145,.005),.062,.008,gold)
		var leg:=model.find_child("leg-left" if side>0 else "leg-right",true,false) as Node3D
		var boot:=Node3D.new()
		boot.name="CoutureLimb"
		leg.add_child(boot)
		G.orb(boot,Vector3(0,-.015,0),Vector3(.065,.11,.065),suit)
		G.orb(boot,Vector3(0,-.124,.038),Vector3(.089,.077,.128),suit)
		G.orb(boot,Vector3(0,-.177,.041),Vector3(.090,.020,.13),hood)
		S.ring(boot,Vector3(0,-.065,0),.066,.008,gold)
		G.gem(boot,Vector3(0,-.103,.153),.018,gold)
