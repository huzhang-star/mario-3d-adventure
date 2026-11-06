extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,msg: String) -> void:
	if not ok: failures+=1;push_error(msg)
func run() -> void:
	var catalog=root.get_node("Campaign").LEVELS
	check(catalog.size()==50,"Exactly fifty worlds")
	var names:={}
	var themes:={}
	var routes:={}
	for i in catalog.size():
		var data: Dictionary=catalog[i]
		check(not names.has(data.name) and not themes.has(data.theme),"Unique name and landmark theme")
		names[data.name]=true;themes[data.theme]=true
		# Compare normalised turn sequences, so colour changes, translation and
		# whole-route scaling alone cannot satisfy the uniqueness requirement.
		var turns: Array=[]
		for j in data.route.size()-1:
			var a: Array=data.route[j]
			var b: Array=data.route[j+1]
			turns.append(roundi(rad_to_deg(atan2(b[0]-a[0],b[2]-a[2]))/5))
		var signature:=str(turns)
		check(not routes.has(signature),"Route is not a scaled copy: "+str(i+1))
		routes[signature]=true
		check(data.features.get(str(data.checkpoint),"normal") not in ["lift","ferry","crumble","fire","wind"],"Stable checkpoint "+str(i+1))
		if i>0:
			var prev: Dictionary=catalog[i-1]
			check(float(data.width)<float(prev.width),"Narrower platforms at "+str(i+1))
			check(float(data.enemy_speed)>float(prev.enemy_speed),"Increasing enemy speed at "+str(i+1))
			check(data.enemy_nodes.size()>=prev.enemy_nodes.size(),"Nondecreasing enemy count at "+str(i+1))
			check(float(data.moving_period)<=float(prev.moving_period),"Mover timing progression")
			check(float(data.crumble_delay)<=float(prev.crumble_delay),"Crumble timing progression")
			check(float(data.hazard_rate)>=float(prev.hazard_rate),"Hazard timing progression")
	print("Fifty-world design failures: ",failures)
	quit(1 if failures else 0)
