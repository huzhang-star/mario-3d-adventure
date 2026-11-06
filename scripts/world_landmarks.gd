extends RefCounted
const S := preload("res://scripts/sculpt.gd")
# Each world has its own recognisable silhouette; these are scenery, not colliders.
static func build(root: Node3D, theme: String, index: int, base: Material, body: Material, trim: Material, glow: Material, cream: Material) -> void:
	match theme:
		"windmill":
			S.cylinder(root,Vector3(0,2,0),1.2,4,cream,.7)
			S.cylinder(root,Vector3(0,4.5,0),1.5,1.2,trim,0,12)
			for i in 4:
				var blade:=Node3D.new();blade.position=Vector3(0,3.6,1);blade.rotation.z=i*PI*.5+.3;root.add_child(blade)
				S.box(blade,Vector3(0,1.3,0),Vector3(.55,2.6,.16),body)
				S.box(blade,Vector3(0,1.4,.1),Vector3(.025,2.3,.03),trim)
			S.orb(root,Vector3(0,3.6,1.1),Vector3.ONE*.25,glow)
		"coral":
			for i in 5:
				var branch:=S.cylinder(root,Vector3((i-2)*.65,1.2+sin(i),0),.22,2.8+sin(i)*1.4,glow,.12)
				branch.rotation.z=(i-2)*.2
				S.orb(root,Vector3((i-2)*.9,2.7+sin(i),0),Vector3.ONE*.3,glow)
			S.orb(root,Vector3(0,.5,1),Vector3(.7,.55,.55),cream)
			for i in 7: S.cylinder(root,Vector3(cos(i)*1.6,.3,sin(i)*1.6),.3,.5,body,.1,8)
		"honey":
			for i in 5: S.cylinder(root,Vector3(0,i*.5+.3,0),1.9-absf(i-2)*.3,.52,trim,-1,6)
			S.orb(root,Vector3(0,1,-1.7),Vector3(.4,.5,.05),base)
			for i in 3: S.orb(root,Vector3(2+i*.3,2+sin(i),0),Vector3(.25,.18,.18),glow)
		"library":
			S.box(root,Vector3(0,2,0),Vector3(3.8,4.2,1),base)
			for shelf in 4:
				S.box(root,Vector3(0,shelf+0.3,.2),Vector3(4,.12,1.5),trim)
				for i in 6:
					var book:=S.box(root,Vector3((i-2.5)*.5,shelf+.75,.5),Vector3(.35,.8,.5),body if (i+shelf)%2==0 else glow)
					book.rotation.z=.07*sin(i)
					S.box(book,Vector3(0,.23,.26),Vector3(.24,.045,.02),cream)
		"waterfall":
			for x in [-2,2]: S.box(root,Vector3(x,2,0),Vector3(.9,5,1.4),base)
			var arch:=S.ring(root,Vector3(0,3.8,0),2,.35,trim);arch.rotation.x=PI*.5
			for i in 6: S.box(root,Vector3((i-2.5)*.45,.2,0),Vector3(.35,6.8,.09),glow if i%2==0 else cream)
		"greenhouse":
			for x in [-2,2]:
				for z in [-1.4,1.4]: S.cylinder(root,Vector3(x,1.5,z),.075,3,trim)
			S.box(root,Vector3(0,3,0),Vector3(4.2,.1,3),trim)
			for x in [-1.5,-.5,.5,1.5]:
				S.cylinder(root,Vector3(x,.3,0),.35,.6,body,.45)
				S.orb(root,Vector3(x,1,0),Vector3(.55,.7,.45),glow)
				var rib:=S.box(root,Vector3(x,3.5,0),Vector3(.06,.06,3.5),trim);rib.rotation.x=.25
		"pirate":
			S.orb(root,Vector3(0,.5,0),Vector3(3,.7,1.3),base)
			S.box(root,Vector3(0,1,0),Vector3(5,.14,2.2),body)
			S.cylinder(root,Vector3(0,3,0),.1,5.5,trim)
			for side in [-1,1]:
				var sail:=S.box(root,Vector3(side*.8,3.3,0),Vector3(1.5,2.4,.06),cream);sail.rotation.z=side*.1
			S.orb(root,Vector3(0,3.5,.06),Vector3(.35,.4,.05),base)
		"candy":
			S.box(root,Vector3(0,1.3,0),Vector3(3,2.6,2.6),body)
			S.cylinder(root,Vector3(0,3,0),2.5,1.6,trim,0,4)
			for x in [-1.1,1.1]:
				S.cylinder(root,Vector3(x,1.5,1.4),.13,3,cream)
				S.orb(root,Vector3(x,3,1.4),Vector3.ONE*.45,glow)
			S.orb(root,Vector3(0,1,1.32),Vector3(.6,.9,.08),cream)
		"shrine":
			for x in [-1.8,1.8]: S.cylinder(root,Vector3(x,2,0),.2,4,glow)
			S.box(root,Vector3(0,4,0),Vector3(5,.28,.55),base)
			S.box(root,Vector3(0,3.25,0),Vector3(4.4,.18,.4),glow)
			for x in [-2.5,2.5]: S.orb(root,Vector3(x,1.8,-1),Vector3(1.3,1.6,1.1),body)
		"music":
			S.cylinder(root,Vector3(0,.4,0),2.5,.8,base)
			for i in 9: S.box(root,Vector3((i-4)*.48,.9,0),Vector3(.43,.16,2),cream if i%3!=1 else base)
			S.cylinder(root,Vector3(-1,2.6,-.6),.10,3.4,trim)
			S.orb(root,Vector3(-1.35,1.15,-.6),Vector3(.5,.32,.22),glow)
			S.box(root,Vector3(-.4,4.2,-.6),Vector3(1.3,.3,.16),glow)
		"balloon":
			S.orb(root,Vector3(0,5,0),Vector3(2,2.5,2),body)
			for i in 6:
				var a:=i*TAU/6
				S.orb(root,Vector3(cos(a)*.7,5,sin(a)*.7),Vector3(1.35,2.45,1.35),trim if i%2==0 else body)
			for x in [-.7,.7]: S.cylinder(root,Vector3(x,1.9,0),.035,2,cream)
			S.box(root,Vector3(0,.7,0),Vector3(1.8,1.2,1.4),base)
		"lotus":
			for i in 8:
				var a:=i*TAU/8
				var petal:=S.orb(root,Vector3(cos(a)*1.2,.6,sin(a)*1.2),Vector3(.7,.3,1.1),cream);petal.rotation.y=-a+PI*.5
			S.orb(root,Vector3(0,.7,0),Vector3(.7,.3,.7),glow)
			S.cylinder(root,Vector3(0,.1,0),2.5,.13,body)
		"fossil":
			S.box(root,Vector3(0,.5,0),Vector3(6,1,2),base)
			for i in 7:
				var rib:=S.ring(root,Vector3((i-3)*.7,1.9,0),1.5-absf(i-3)*.14,.10,cream);rib.rotation.z=PI*.5
			S.orb(root,Vector3(3,1.4,0),Vector3(.9,.7,.6),trim)
			S.orb(root,Vector3(3.6,1.55,.42),Vector3(.2,.18,.08),base)
		"igloo":
			S.orb(root,Vector3(0,.1,0),Vector3(2.4,2.2,2.4),cream)
			for y in [.5,1,1.5]: S.ring(root,Vector3(0,y,0),sqrt(5.76-y*y),.025,trim)
			S.orb(root,Vector3(0,.5,2.1),Vector3(.8,.9,.65),body)
			S.orb(root,Vector3(0,.43,2.7),Vector3(.5,.65,.06),base)
		"anvil":
			S.cylinder(root,Vector3(0,.7,0),1.3,1.4,base,-1,8)
			S.box(root,Vector3(0,1.8,0),Vector3(3,.9,1.4),trim)
			var horn:=S.cylinder(root,Vector3(2,1.9,0),.6,1.8,trim,0,16);horn.rotation.z=-PI*.5
			S.box(root,Vector3(-.3,3,0),Vector3(.14,2.2,.3),cream)
			S.box(root,Vector3(-.3,2.65,0),Vector3(1.1,.13,.4),glow)
		"biolume":
			for i in 3:
				S.cylinder(root,Vector3((i-1)*1.8,1.7+i*.25,0),.15,3.4+i*.5,body,.09)
				S.orb(root,Vector3((i-1)*1.8,3.4+i*.5,0),Vector3(1.2,.45,1.2),glow)
				S.ring(root,Vector3((i-1)*1.8,3.2+i*.5,0),.9,.035,cream)
		"astrolabe":
			S.cylinder(root,Vector3(0,.5,0),1.6,1,base)
			for i in 3:
				var ring:=S.ring(root,Vector3(0,3,0),2.1-i*.3,.09,trim);ring.rotation=Vector3(i*.8,.4,i*.9)
			S.orb(root,Vector3(0,3,0),Vector3.ONE*.5,glow)
		"train":
			S.box(root,Vector3(0,1.1,0),Vector3(5,1.1,2),body)
			for x in [-1.6,0,1.6]:
				for z in [-1.05,1.05]:
					var wheel:=S.cylinder(root,Vector3(x,.4,z),.55,.18,base);wheel.rotation.x=PI*.5
			S.box(root,Vector3(-1.3,2.4,0),Vector3(1.8,2,2),trim)
			S.cylinder(root,Vector3(1.6,2.4,0),.35,1.8,base)
			S.box(root,Vector3(-1.3,2.7,1.02),Vector3(1.1,.8,.03),cream)
		"stalactite":
			for i in 5:
				S.cylinder(root,Vector3((i-2)*1.1,0,0),.9,3+i*.4,base,.1,8)
				S.cylinder(root,Vector3((i-2)*1.1,6,0),.02,3+i*.25,trim,.6,8)
		"sakura":
			S.cylinder(root,Vector3(-1,1.8,0),.25,3.6,base,.16)
			for i in 5: S.orb(root,Vector3(-1+cos(i)*1.1,3.6+sin(i)*.5,sin(i)*.7),Vector3(1.2,.9,1),glow)
			var wheel:=S.ring(root,Vector3(1.7,1.6,0),1.7,.2,trim);wheel.rotation.x=PI*.5
			for i in 8:
				var spoke:=S.box(root,Vector3(1.7,1.6,0),Vector3(.1,3.2,.2),body);spoke.rotation.z=i*PI/8
		"neon":
			for i in 3:
				S.box(root,Vector3((i-1)*1.7,2.4+i*.6,0),Vector3(1.4,4.8+i*1.2,1.8),base)
				for y in 5: S.box(root,Vector3((i-1)*1.7,y+.7,.92),Vector3(1.1,.05,.035),glow)
			S.ring(root,Vector3(0,6,0),2,.045,glow)
		"treetop":
			S.cylinder(root,Vector3(0,2,0),.75,5,base,.4)
			for i in 5:
				var a:=i*TAU/5
				S.orb(root,Vector3(cos(a)*1.7,4+sin(i)*.5,sin(a)*1.7),Vector3(1.7,1.0,1.5),body)
			S.box(root,Vector3(0,3.5,1),Vector3(2,1.6,1.8),trim)
			S.cylinder(root,Vector3(0,4.5,1),1.7,1.2,glow,0,4)
		"kite":
			for i in 3:
				var kite:=Node3D.new();kite.position=Vector3((i-1)*1.5,3+i*.8,0);kite.rotation.z=.25;root.add_child(kite)
				var diamond:=S.cylinder(kite,Vector3.ZERO,1.2,.09,body if i%2==0 else glow,-1,4);diamond.rotation.x=PI*.5
				S.box(kite,Vector3(0,-1.9,0),Vector3(.035,2.5,.035),cream)
				for j in 3: S.orb(kite,Vector3(0,-1.5-j*.6,0),Vector3(.23,.07,.06),trim)
		"teapot":
			S.orb(root,Vector3(0,1.4,0),Vector3(1.5,1.3,1.2),cream)
			S.cylinder(root,Vector3(0,2.65,0),1.0,.23,glow,.7)
			S.orb(root,Vector3(0,2.95,0),Vector3.ONE*.22,trim)
			var handle:=S.ring(root,Vector3(-1.5,1.5,0),.85,.15,glow);handle.rotation.x=PI*.5
			var spout:=S.cylinder(root,Vector3(1.5,1.6,0),.4,1.7,cream,.2);spout.rotation.z=-.8
		"carrot":
			for i in 4:
				S.cylinder(root,Vector3((i-1.5)*1.1,1,0),.04,2.3,glow,.48,12)
				for j in 3:
					var leaf:=S.orb(root,Vector3((i-1.5)*1.1,2.5,j*.1),Vector3(.1,.8,.25),body);leaf.rotation.z=(j-1)*.35
		"jellyfish":
			S.orb(root,Vector3(0,4,0),Vector3(2,.8,2),glow)
			S.ring(root,Vector3(0,3.8,0),1.85,.08,cream)
			for i in 8:
				var a:=i*TAU/8
				for j in 5: S.orb(root,Vector3(cos(a)*(1.2+sin(j)*.2),3.4-j*.5,sin(a)*1.2),Vector3(.07,.33,.07),trim)
		"volcano":
			S.cylinder(root,Vector3(0,1.5,0),3.3,4,base,1.5,12)
			S.ring(root,Vector3(0,3.5,0),1.4,.22,glow)
			for i in 4:
				var lava:=S.box(root,Vector3(cos(i*1.6)*2,1.8,sin(i*1.6)*2),Vector3(.18,3,.18),glow);lava.rotation.z=.3*sin(i)
		"chess":
			S.cylinder(root,Vector3(0,.2,0),1.2,.4,cream)
			S.cylinder(root,Vector3(0,1.3,0),.7,2.1,cream,.4)
			S.orb(root,Vector3(0,2.7,0),Vector3(.75,.7,.75),cream)
			S.box(root,Vector3(0,3.65,0),Vector3(.18,1.0,.18),trim)
			S.box(root,Vector3(0,3.8,0),Vector3(.8,.17,.18),trim)
		"hourglass":
			for y in [0,4]: S.cylinder(root,Vector3(0,y,0),1.6,.25,trim)
			for x in [-1.2,1.2]: S.cylinder(root,Vector3(x,2,0),.08,4,trim)
			S.cylinder(root,Vector3(0,1,0),1.25,1.8,body,.1,24)
			S.cylinder(root,Vector3(0,3,0),.1,1.8,cream,1.25,24)
			S.cylinder(root,Vector3(0,2.1,0),.025,1.7,glow)
		"prism":
			for i in 4:
				var prism:=S.cylinder(root,Vector3((i-1.5)*1.2,2+i*.3,0),.85,3.7+i*.5,glow if i%2==0 else trim,0,3);prism.rotation.z=.15*(i-1.5)
			for i in 5: S.box(root,Vector3(0,.1+i*.1,1.4),Vector3(5,.06,.13),body if i%2==0 else cream)
		"satellite":
			S.box(root,Vector3(0,3,0),Vector3(1.2,1.5,1.2),trim)
			for side in [-1,1]:
				S.box(root,Vector3(side*2.1,3,0),Vector3(2.5,.12,2.3),body)
				for i in 5: S.box(root,Vector3(side*2.1,3.08,(i-2)*.4),Vector3(2.45,.02,.035),glow)
			S.cylinder(root,Vector3(0,4.3,0),.03,1.6,cream)
			S.orb(root,Vector3(0,5.1,0),Vector3.ONE*.15,glow)
		"dragon":
			for i in 6:
				S.orb(root,Vector3((i-2.5)*.8,1+sin(i*.5),0),Vector3(.65,.55,.65),trim)
				S.cylinder(root,Vector3((i-2.5)*.8,1.9+sin(i*.5),0),.25,.9,glow,0,5)
			S.orb(root,Vector3(2.6,1.8,0),Vector3(.9,.6,.7),body)
			for z in [-.5,.5]: S.orb(root,Vector3(2.9,2.05,z),Vector3(.13,.15,.09),glow)
		"vortex":
			for i in 9:
				var ring:=S.ring(root,Vector3(sin(i*.7)*.35,i*.6,0),2.5-i*.19,.14,trim if i%2==0 else glow);ring.rotation.z=sin(i)*.1
		"meteor":
			S.cylinder(root,Vector3(0,.6,0),2.7,1.6,base,2.1,7)
			for i in 4: S.cylinder(root,Vector3((i-1.5)*.65,2+i*.35,0),.42,2.5+i*.4,glow,0,5)
			for i in 3: S.orb(root,Vector3(3+i*.8,4+i*.5,0),Vector3.ONE*(.6-i*.12),trim)
		"aurora":
			for i in 5:
				var arc:=S.ring(root,Vector3(0,3+i*.1,0),2.6-i*.3,.06,glow if i%2==0 else cream);arc.rotation.x=PI*.5
			for x in [-2.4,2.4]: S.cylinder(root,Vector3(x,1.4,0),.15,3,trim)
			for i in 4: S.orb(root,Vector3((i-1.5)*1.2,.25,0),Vector3(.55,.2,.55),body)
		"solar":
			S.orb(root,Vector3(0,3,0),Vector3.ONE*1.2,glow)
			for i in 12:
				var a:=i*TAU/12
				var ray:=S.cylinder(root,Vector3(cos(a)*2,3+sin(a)*2,0),.18,1.2,trim,0,6);ray.rotation.z=a-PI*.5
		"portal":
			for i in 3:
				var ring:=S.ring(root,Vector3(0,2.6,-i*.6),2.4-i*.3,.14,glow if i%2==0 else trim);ring.rotation.x=PI*.5
			for side in [-1,1]: S.box(root,Vector3(side*2.6,1.8,0),Vector3(.6,4,.8),base)
		"crown":
			S.cylinder(root,Vector3(0,.7,0),2,1.4,trim,-1,12)
			for i in 7:
				var a:=i*TAU/7
				S.cylinder(root,Vector3(cos(a)*1.8,2.2,sin(a)*1.8),.55,2.3,trim,0,4)
				S.orb(root,Vector3(cos(a)*1.8,3.4,sin(a)*1.8),Vector3.ONE*.18,glow)
			S.orb(root,Vector3(0,2,0),Vector3.ONE*.65,glow)
	# Keep the plinth separate so the caller can ground the building body against
	# its top surface even when a theme uses geometry below local y = 0.
	var plinth := Node3D.new()
	plinth.name = "LandmarkPlinth"
	root.add_child(plinth)
	S.cylinder(plinth,Vector3(0,-.3,0),3.0,.5,base,3.2,12)
