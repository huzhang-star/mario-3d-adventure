extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func reset_player(game: Node, yaw: float) -> void:
	game._release_control_actions()
	game.player.position=Vector3(40,.05,40)
	game.player.velocity=Vector3.ZERO
	game.player.external_drift=Vector3.ZERO
	game.player.facing_yaw=yaw
	game.camera_yaw=yaw
	game.orbit_yaw=yaw
	game.player._input_axes=Vector2.ZERO
	game.camera.position=game.player.position-game.player.get_facing_direction()*10+Vector3.UP*5.5
	game.camera.look_at(game.player.position+Vector3.UP)
	await frames(12)
func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=pressed
	root.push_input(event,true)
func drag(index: int, point: Vector2) -> void:
	var event:=InputEventScreenDrag.new()
	event.index=index
	event.position=point
	event.relative=Vector2(40,12)
	root.push_input(event,true)
func check_camera_input(game: Node) -> void:
	var point:=Vector2(400,450)
	var yaw: float=game.camera_yaw
	touch(0,point,true)
	drag(0,point+Vector2(40,12))
	check(not is_equal_approx(yaw,game.camera_yaw),"One finger rotates from left-side empty space")
	touch(1,Vector2(950,450),true)
	yaw=game.camera_yaw
	drag(1,Vector2(990,462))
	check(is_equal_approx(yaw,game.camera_yaw),"Second finger cannot steal camera")
	touch(1,Vector2(990,462),false)
	drag(0,point)
	check(not is_equal_approx(yaw,game.camera_yaw),"Original finger retains camera after second finger release")
	touch(0,point,false)
	yaw=game.camera_yaw
	drag(0,point)
	check(is_equal_approx(yaw,game.camera_yaw),"Lifting camera finger stops rotation")
	var stick: Vector2=game.virtual_joystick.get_global_rect().get_center()
	touch(2,stick,true)
	drag(2,stick+Vector2(40,12))
	check(game.touch_camera_index==-1 and not game.virtual_joystick._value.is_zero_approx(),"Joystick touch moves without rotating camera")
	touch(3,Vector2(950,450),true)
	drag(3,Vector2(990,462))
	check(not is_equal_approx(yaw,game.camera_yaw),"Camera works while another finger holds joystick")
	touch(2,stick,false)
	touch(3,Vector2(990,462),false)
	touch(0,point,true)
	game._toggle_pause()
	check(game.touch_camera_index==-1,"Pause releases camera touch")
	game._toggle_pause()
	yaw=game.camera_yaw
	drag(0,point)
	check(is_equal_approx(yaw,game.camera_yaw),"Resume does not revive stale touch")
	touch(0,point,false)
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	motion.relative=Vector2(40,12)
	yaw=game.camera_yaw
	root.push_input(motion,true)
	check(not is_equal_approx(yaw,game.camera_yaw),"Trackpad motion rotates camera without any button press")
	check(game._mouse_look_enabled(),"Free look activates without pressing a button")
	# The headless display server does not implement pointer capture.
	if DisplayServer.get_name()!="headless":
		check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Free look captures pointer for continuous motion")
	yaw=game.camera_yaw
	motion.device=-1
	root.push_input(motion,true)
	check(is_equal_approx(yaw,game.camera_yaw),"Emulated touch mouse motion does not rotate twice")
	motion.device=0
	game._toggle_pause()
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Pause releases pointer for menus")
	root.push_input(motion,true)
	check(is_equal_approx(yaw,game.camera_yaw),"Pointer motion in pause menu cannot rotate camera")
	game._toggle_pause()
	root.push_input(motion,true)
	check(not is_equal_approx(yaw,game.camera_yaw),"Resume restores free look without clicking")
	yaw=game.camera_yaw
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	root.push_input(motion,true)
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and is_equal_approx(yaw,game.camera_yaw),"Unfocused game releases pointer and ignores motion")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	root.push_input(motion,true)
	check(not is_equal_approx(yaw,game.camera_yaw),"Returning to game restores free look")

	game._release_control_actions()
func run() -> void:
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	root.get_node("Campaign").level_index=0
	change_scene_to_file("res://main.tscn")
	await frames(30)
	var game=current_scene
	game._on_overlay_button()
	check_camera_input(game)
	var floor_body:=StaticBody3D.new()
	floor_body.position=Vector3(40,-.5,40)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(100,1,100)
	collision.shape=shape
	floor_body.add_child(collision)
	game.add_child(floor_body)
	var p=game.player
	p.sound_enabled=false
	for yaw in [PI,PI*.5,-.73]:
		for action in ["move_left","move_right","move_forward","move_back"]:
			await reset_player(game,yaw)
			var origin: Vector3=p.position
			var right: Vector3=game.camera.global_basis.x
			var camera_yaw: float=game.camera.rotation.y
			var forward: Vector3=p.get_facing_direction()
			var expected: Vector3=right*(-1 if action=="move_left" else 1) if action in ["move_left","move_right"] else forward*(-1 if action=="move_back" else 1)
			Input.action_press(action)
			await frames(55)
			var displacement: Vector3=p.position-origin
			check(displacement.dot(expected)>4.0,action+" moves instead of turning in place")
			check(p.get_facing_direction().dot(expected)>.97,"Character faces travel direction")
			check(displacement.normalized().dot(expected)>.98,"Held input stays straight")
			check(p._animation.current_animation=="walk","Authored walk cycle plays")
			if action in ["move_left","move_right"]:
				check(absf(angle_difference(camera_yaw,game.camera.rotation.y))<.02,"Walking never rotates the mouse-owned camera")
			game._release_control_actions()
			await frames(30)
			check(Vector2(p.velocity.x,p.velocity.z).length()<.01,"Release brakes to a stop")
			check(p._animation.current_animation=="idle","Stop blends to idle")
	await reset_player(game,PI)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await frames(30)
	check(Vector2(p.velocity.x,p.velocity.z).length()<=IslandPlayer.SPEED+.01,"Diagonal speed is capped")
	await reset_player(game,PI)
	Input.action_press("jump")
	Input.action_press("move_left")
	await frames(12)
	check(p.position.x<39.75 and p.position.y>1,"Airborne left correction")
	check(p._animation.current_animation=="jump","Jump pose")
	game._release_control_actions()
	await frames(70)
	check(p.is_on_floor() and p._animation.current_animation=="idle","Landing resumes idle")
	check(p._visual.scale.is_equal_approx(Vector3.ONE*IslandPlayer.MODEL_SCALE),"Cute character retains stable body proportions")
	paused=false
	current_scene.queue_free()
	await frames(6)
	print("Cute player/control failures: ",failures)
	quit(1 if failures else 0)
