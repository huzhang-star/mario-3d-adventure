extends RefCounted
const G=preload("res://scripts/couture_geometry.gd")
const S=preload("res://scripts/sculpt.gd")
const FX=preload("res://scripts/couture_effects.gd")

static func build(root: Node3D, data: Dictionary) -> void:
	var cut:=int(data.get("cut",0))
	var breadth: float=[1.0,.90,1.06,1.16,.98][cut]
	var color:=Color(data.color)
	var accent:=Color(data.accent)
	var fabric:=G.satin(color)
	var gold:=G.satin(accent,.65)
	var silver:=G.satin(Color("dae7ee"),.7)
	var pearl:=G.satin(Color("fff1e6"),.20)
	var jewel:=G.satin(color.lightened(.24),.33,.10)
	var luminous:=G.satin(accent.lightened(.20),.30,.18)
	if data.id=="platinum_dragon":
		gold=silver
		jewel=G.satin(accent,.25,.06)
	# Every couture outfit has a fitted bodice, embroidered hem and a clasp.
	G.gem(root,Vector3(0,.14,.185),.044,jewel,gold)
	G.chain(root,Vector3(-.16,.19,.13),Vector3(0,.09,.25),Vector3(.16,.19,.13),pearl,11,.012)
	for side in [-1,1]:
		G.curve(root,Vector3(side*.12,.20,.15),Vector3(side*.21,.04,.17),Vector3(side*.11,-.05,.16),.007,gold)
	match data.id:
		"rose_seraph":
			_gown(root,data,gold,3)
			for side in [-1,1]:
				G.rosette(root,Vector3(side*.24,.685,.10),.078,fabric,pearl)
				G.chain(root,Vector3(side*.23,.64,.07),Vector3(side*.39,.40,.11),Vector3(side*.23,.27,.05),pearl,15,.014)
			var flower_count: int=[5,7,5,9,3][cut]
			for i in flower_count:
				var a:=PI*(float(i)/(flower_count-1))
				G.rosette(root,Vector3(cos(a)*.21*breadth,.72+sin(a)*[.045,.09,.16,.07,.12][cut],.05),.047,G.satin(color.lightened(.15)),gold)
			_ribbon(root,Vector3(-.14,.13,-.16),Vector3(-.35,-.28,-.23),color,gold)
			_ribbon(root,Vector3(.14,.13,-.16),Vector3(.35,-.28,-.23),color,gold)
		"moon_empress":
			_gown(root,data,silver,3)
			var moon:=PackedVector3Array()
			for i in 29:
				var a:=lerpf([-.95,-.7,-1.15,-.4,-.85][cut],[4.05,3.8,4.35,3.5,3.95][cut],i/28.0)
				moon.append(Vector3(cos(a)*.17*breadth,.85+sin(a)*.17,.018))
			G.tube(root,moon,.022,silver)
			G.gem(root,Vector3(0,.83,.033),.052,jewel,silver)
			for side in [-1,1]:
				G.chain(root,Vector3(side*.23,.71,.02),Vector3(side*.35,.47,.10),Vector3(side*.24,.30,.05),silver,17,.009)
				G.gem(root,Vector3(side*.24,.29,.06),.037,luminous,silver)
			_orbit(root,Vector3(0,.61,-.10),.34,silver,luminous,7)
			for i in 5:
				var x:=float(i-2)*.13
				_ribbon(root,Vector3(x*.5,.2,-.20),Vector3(x,-.35,-.33),color.lightened(i*.07),silver)
		"glass_butterfly":
			_gown(root,data,gold,2)
			_butterfly(root,color,accent,gold,cut)
			for side in [-1,1]:
				G.curve(root,Vector3(side*.14,.71,0),Vector3(side*.37,1.02,0),Vector3(side*.22,.95,.02),.009,gold)
				G.gem(root,Vector3(side*.22,.95,.02),.029,jewel,gold)
			G.rosette(root,Vector3(0,.73,.09),.048,pearl,gold)
		"phoenix":
			_gown(root,data,gold,2)
			for side in [-1,1]:
				for i in 3:
					G.petal(root,Vector3(side*.14,.68,0),Vector3(side*(.12+i*.09),.99-i*.04,-.03),.039,gold)
			var feather_count: int=[7,9,5,11,7][cut]
			for i in feather_count:
				var t:=float(i)*2.0/(feather_count-1)-1.0
				var start:=Vector3(t*.08,.14,-.18)
				var end:=Vector3(t*.39*breadth,-.12-absf(t)*.025,-.40)
				G.petal(root,start,end,.07,G.satin(color.lerp(Color("ffdd89"),absf(t))),.10)
				G.curve(root,start,(start+end)*.5+Vector3(0,0,.08),end,.006,gold)
			G.gem(root,Vector3(0,.725,.18),.044,jewel,gold)
			G.crown(root,gold,jewel)
		"ocean_pearl":
			_gown(root,data,pearl,3)
			var shell_count: int=[9,7,11,9,5][cut]
			for i in shell_count:
				var t:=float(i)/(shell_count-1)
				var a:=PI*t
				G.petal(root,Vector3(cos(a)*.10,.69,0),Vector3(cos(a)*.31*breadth,.75+sin(a)*[.21,.18,.27,.21,.22][cut],-.06),.055,G.satin(Color("ecc8c6").lerp(Color("e7e9d3"),t)),.035)
				G.orb(root,Vector3(cos(a)*.23,.735+sin(a)*.06,.11),Vector3.ONE*.018,pearl)
			G.gem(root,Vector3(0,.755,.16),.06,jewel,silver)
			for side in [-1,1]:
				# Pearl-coral tassels replace the old side fins, giving this skin a
				# distinctly marine silhouette without another wing-like outline.
				for i in 3:
					var end:=Vector3(side*(.29+i*.048),.53-i*.14,-.16)
					G.curve(root,Vector3(side*.18,.26,-.12),Vector3(side*(.24+i*.03),.36-i*.05,-.10),end,.009,silver)
					G.gem(root,end,.022,pearl,silver)
				G.chain(root,Vector3(side*.25,.65,0),Vector3(side*.41,.30,.18),Vector3(side*.19,.12,.17),pearl,19,.014)
		"sakura_deity":
			_gown(root,data,gold,3)
			for side in [-1,1]:
				G.curve(root,Vector3(side*.13,.70,-.02),Vector3(side*.29,.91,-.02),Vector3(side*.42*breadth,.86+(.06 if cut==2 else 0),0),.012,gold)
				for i in (5 if cut==3 else 4):
					G.rosette(root,Vector3(side*(.17+i*.075*breadth),.76+sin(i*.8)*.10,.03),.05,G.satin(Color("f4b5cd").lightened(i*.05)),pearl)
				G.chain(root,Vector3(side*.29,.79,.02),Vector3(side*.4,.60,.08),Vector3(side*.32,.41,.13),gold,15,.008)
				G.rosette(root,Vector3(side*.32,.40,.14),.039,fabric,pearl)
				_ribbon(root,Vector3(side*.17,.12,-.17),Vector3(side*.46,-.30,-.30),color,gold)
		"star_weaver":
			_gown(root,data,silver,3)
			_orbit(root,Vector3(0,.43,-.28),.58*breadth,silver,luminous,[12,8,10,16,7][cut])
			_orbit(root,Vector3(0,.85,0),.26,silver,luminous,5)
			for side in [-1,1]:
				_ribbon(root,Vector3(side*.14,.13,-.18),Vector3(side*.43,-.34,-.32),Color("9f8acb"),silver)
			G.gem(root,Vector3(0,.73,.19),.041,luminous,silver)
		"platinum_dragon":
			_gown(root,data,gold,2)
			for side in [-1,1]:
				G.curve(root,Vector3(side*.18,.7,-.05),Vector3(side*.41,.82,-.12),Vector3(side*.24*breadth,[1.0,.94,1.08,1.0,.97][cut],-.05),.025,gold,.06)
				G.curve(root,Vector3(side*.28,.84,-.08),Vector3(side*.46,.9,-.03),Vector3(side*.42,.96,.02),.014,gold,.06)
				for i in (4 if cut==2 else 3):
					G.petal(root,Vector3(side*.21,.21-i*.07,.09),Vector3(side*.34,.21-i*.07,.13),.040,silver,.025)
			G.curve(root,Vector3(0,.05,-.15),Vector3(.57,-.25,-.5),Vector3(.49,.07,-.57),.036,fabric)
			G.petal(root,Vector3(.49,.04,-.57),Vector3(.50,.19,-.56),.06,gold)
			G.crown(root,gold,jewel)
		"jade_peacock":
			_gown(root,data,gold,3)
			var tail_count: int=[11,9,11,13,7][cut]
			for i in tail_count:
				var a:=lerpf(-1.35,1.35,float(i)/(tail_count-1))
				# Lean the fan away from the head; the raised study otherwise lets
				# the back of the head poke through its central feather.
				var end:=Vector3(sin(a)*.76*breadth,.18+cos(a)*[.82,.78,.95,.82,.86][cut],-.50)
				var origin:=Vector3(0,.10,-.22)
				G.petal(root,origin,end,.086,G.satin(color.lightened(.07)),.025)
				G.curve(root,origin,(origin+end)*.5,end,.006,gold)
				var eye:=end+(origin-end).normalized()*.10+Vector3(0,0,.025)
				var mesh:=G.orb(root,eye,Vector3(.059,.093,.016),gold)
				mesh.rotation.z=-a
				G.orb(root,eye+Vector3(0,0,.015),Vector3(.042,.065,.013),G.satin(Color("4b78b1"),.4)).rotation.z=-a
				G.orb(root,eye+Vector3(0,0,.027),Vector3(.025,.039,.009),G.satin(Color("153f57"),.25)).rotation.z=-a
				G.orb(root,eye+Vector3(-.009,.018,.035),Vector3.ONE*.009,pearl)
			G.crown(root,gold,jewel)
		"eternal_dawn":
			_dawn_gown(root,data,gold,pearl)
			_dawn_diadem(root,data,gold,pearl)
			for side in [-1,1]:
				G.chain(root,Vector3(side*.255,.70,.02),Vector3(side*.365,.48,.12),Vector3(side*.257,.29,.09),pearl,15,.010)
				G.gem(root,Vector3(side*.257,.28,.10),.032,G.satin(Color(data.get("opal","9ce8df")),.3,.10),gold)
			G.gem(root,Vector3(0,.125,.238),.039,G.satin(Color(data.get("opal","9ce8df")),.30,.10),gold)

	# Recessed jewel buttons make the back of the outfit readable during play.
	for i in 3:
		G.gem(root,Vector3(0,.13-i*.06,-.184),.014,gold)

	FX.build(root,data)

static func _ribbon(root: Node3D, start: Vector3, end: Vector3, color: Color, trim: Material) -> void:
	# Trails stay clear of the floor through the walk cycle.
	end.y=maxf(end.y,-.13)
	G.petal(root,start,end,.065,G.satin(color),.08)
	G.curve(root,start,(start+end)*.5+Vector3(.03,0,.07),end,.005,trim)

static func _butterfly(root: Node3D, color: Color, accent: Color, trim: Material, cut := 0) -> void:
	for side in [-1,1]:
		var wing:=Node3D.new()
		wing.name="CoutureWingButterfly"+str(side)
		wing.position=Vector3(side*.14,.28,-.17)
		root.add_child(wing)
		for lobe in 2:
			var breadth: float=[1.0,.86,1.02,1.13,.95][cut]
			var end:=Vector3(side*(.60 if lobe==0 else .46)*breadth,(.56 if cut==2 else .47) if lobe==0 else -.23,-.08)
			var mat:=G.satin(color.lerp(accent,.35 if lobe==0 else .65),.18)
			G.petal(wing,Vector3.ZERO,end,.21 if lobe==0 else .15,mat,.06)
			var middle:=end*.50
			for rib in [-1,0,1]:
				G.curve(wing,Vector3.ZERO,middle+Vector3(side*absf(rib)*.13,rib*.09,.08),end*.95,.006,trim)
			for j in 5:
				var t:=.33+j*.11
				G.orb(wing,end*t+Vector3(side*.09,sin(t*PI)*.05,.065),Vector3.ONE*.017,G.satin(Color("f5eedf"),.18))

static func _dragon_wing(root: Node3D, side: int, mat: Material, trim: Material) -> void:
	var wing:=Node3D.new()
	wing.name="CoutureWingDragon"+str(side)
	wing.position=Vector3(side*.14,.23,-.18)
	root.add_child(wing)
	for i in 4:
		var end:=Vector3(side*(.63-i*.06),.43-i*.20,-.07)
		G.petal(wing,Vector3.ZERO,end,.12,mat,.025)
		G.curve(wing,Vector3.ZERO,end*.6+Vector3(0,.10,0),end,.013,trim)
		G.gem(wing,end,.025,trim)

static func _orbit(root: Node3D, pos: Vector3, radius: float, metal: Material, stars: Material, count: int) -> void:
	var orbit:=Node3D.new()
	orbit.name="CoutureOrbit"+str(root.get_child_count())
	orbit.set_meta("vertical",radius>.4)
	orbit.position=pos
	root.add_child(orbit)
	var ring:=S.ring(orbit,Vector3.ZERO,radius,.009,metal)
	if radius>.4: ring.rotation.x=PI/2
	else: ring.rotation.z=.12
	for i in count:
		var a:=TAU*i/count
		var p:=Vector3(cos(a)*radius,sin(a)*radius,0) if radius>.4 else Vector3(cos(a)*radius,sin(a)*.04,sin(a)*radius)
		G.star(orbit,p,.034 if i%3 else .045,stars)

# Five constructed tailoring studies; selected cuts use the exact same geometry in play.
static func _gown(root: Node3D, data: Dictionary, trim: Material, layers: int) -> void:
	var cut:=int(data.get("cut",0))
	var color:=Color(data.color)
	if cut==0:
		G.skirt(root,color,trim,layers)
		return
	var hem: float=[.31,.32,.29,.355,.325][cut]
	var pleat: float=[0,.008,.018,.010,.024][cut]
	var cloth:=G.cloth(root,[Vector2(.17,.13),Vector2(.22,.015),Vector2(hem,-.12)],G.silk(color,color.lightened(.36)),trim,0,TAU,pleat)
	cloth.name="TailoredGown"
	if cut==1 or cut==3:
		var count:=8 if cut==1 else 6
		var panels:=Node3D.new()
		root.add_child(panels)
		panels.scale.z=.78
		for i in count:
			var panel:=Node3D.new()
			panels.add_child(panel)
			panel.rotation.y=TAU*i/count
			var start:=Vector3(0,.10,.19)
			var end:=Vector3(0,-.102,hem+.007)
			var width:=.105 if cut==1 else .135
			G.petal(panel,start,end,width,G.satin(color.lightened(.20)),.024)
			G.petal_border(panel,start,end,width,.024,trim)
	else:
		for i in 10:
			var a:=TAU*i/10
			G.curve(root,Vector3(cos(a)*.19,.09,sin(a)*.15),Vector3(cos(a)*.27,-.05,sin(a)*.21),Vector3(cos(a)*hem,-.12,sin(a)*hem*.78),.004,trim)

static func _dawn_diadem(root: Node3D, data: Dictionary, gold: Material, pearl: Material) -> void:
	var cut:=int(data.get("cut",0))
	var crown:=Node3D.new()
	crown.name="DawnSunDiadem"
	root.add_child(crown)
	var opal:=G.opal(Color(data.get("opal","9ce8df")))
	var enamel:=G.satin(Color(data.accent).lightened(.26),.40)
	var count: int=[11,9,13,15,7][cut]
	var width: float=[1.0,.92,.97,1.10,1.04][cut]
	var height: float=[1.0,.93,1.13,1.0,.96][cut]
	for i in count:
		var a:=PI*float(i)/(count-1)
		var inner:=Vector3(cos(a)*.17*width,.73+sin(a)*.11,.045)
		var outer:=Vector3(cos(a)*.33*width,.73+sin(a)*.32*height,.018)
		G.petal(crown,inner,outer,.032 if cut!=4 else .044,enamel,.015)
		G.curve(crown,inner,inner.lerp(outer,.5)+Vector3(0,0,.025),outer,.0045,gold)
		G.orb(crown,outer,Vector3.ONE*.012,pearl)
	var arc:=PackedVector3Array()
	for i in 33:
		var a:=PI*i/32.0
		arc.append(Vector3(cos(a)*.242*width,.74+sin(a)*.21*height,.065))
	G.tube(crown,arc,.010,gold)
	S.ring(crown,Vector3(0,.729,.01),.237,.010,gold).scale.z=.80
	G.gem(crown,Vector3(0,.818,.119),.067,opal,gold)
	G.star(crown,Vector3(0,1.075*height,.023),.039,pearl)
	for side in [-1,1]:
		G.gem(crown,Vector3(side*.155,.768,.127),.030,opal,gold)

static func _dawn_gown(root: Node3D, data: Dictionary, gold: Material, pearl: Material) -> void:
	var cut:=int(data.get("cut",0))
	var color:=Color(data.color)
	var opal:=Color(data.get("opal","9ce8df"))
	var gown:=Node3D.new()
	gown.name="DawnOpalGown"
	root.add_child(gown)
	var radius: float=[.34,.32,.31,.36,.33][cut]
	G.cloth(gown,[Vector2(.17,.14),Vector2(.215,.035),Vector2(radius,-.125)],G.silk(color,opal),gold,0,TAU,.008)
	var count: int=[8,8,10,6,8][cut]
	var panels:=Node3D.new()
	gown.add_child(panels)
	panels.scale.z=.78
	for i in count:
		# Back panels would intersect the short mantle; keep its rear surface clean.
		if cos(TAU*i/count)<-.05: continue
		var panel:=Node3D.new()
		panels.add_child(panel)
		panel.rotation.y=TAU*i/count
		var width:=.114 if cut!=3 else .146
		var start:=Vector3(0,.115,.187)
		var end:=Vector3(0,-.098,radius+.014)
		G.petal(panel,start,end,width,G.silk(Color("efe6d5"),opal),.024)
		G.petal_border(panel,start,end,width,.024,gold)
		G.gem(panel,start.lerp(end,.82)+Vector3(0,0,.031),.014,G.satin(opal,.26,.06),gold)
	# A short open-front mantle frames the silhouette without obscuring the hands.
	G.cloth(gown,[Vector2(.20,.18),Vector2(.27,.055),Vector2(radius+.065,-.09)],G.silk(color.darkened(.24),opal),gold,PI+.16,PI-.32,.012)
	var clasp:=Node3D.new()
	gown.add_child(clasp)
	clasp.position=Vector3(0,.044,-.238)
	clasp.rotation.y=PI
	G.gem(clasp,Vector3.ZERO,.032,G.satin(opal,.3,.08),gold)
	for i in 7:
		var a:=TAU*i/7
		G.petal(clasp,Vector3(cos(a)*.039,sin(a)*.039,0),Vector3(cos(a)*.072,sin(a)*.072,0),.010,gold,.006)
	for side in [-1,1]:
		G.chain(gown,Vector3(side*.12,.17,.175),Vector3(side*.17,.065,.235),Vector3(side*.08,-.007,.247),pearl,7,.009)
