extends SceneTree
const STYLES=preload("res://scripts/skin_style.gd")
const MODEL=preload("res://assets/kenney/models/character.glb")
const G=preload("res://scripts/couture_geometry.gd")
const S=preload("res://scripts/sculpt.gd")
var viewport: SubViewport
var model: Node3D
var cam: Camera3D
var output_dir:="res://docs/couture"
var clip_skins:=PackedStringArray()
var drafts_path:=""
var only_skins:=PackedStringArray()
var animation_name:="idle"
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for i in 6: await process_frame
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(path)
func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(600,700)
	root.content_scale_size=Vector2i(600,700)
	root.gui_disable_input=true
	root.get_node("Campaign").save_enabled=false
	root.get_node("Wardrobe").save_enabled=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output_dir=arg.trim_prefix("--out=")
		if arg.begins_with("--clip="): clip_skins=arg.trim_prefix("--clip=").split(",")
		if arg.begins_with("--drafts="): drafts_path=arg.trim_prefix("--drafts=")
		if arg.begins_with("--only="): only_skins=arg.trim_prefix("--only=").split(",")
		if arg.begins_with("--animation="): animation_name=arg.trim_prefix("--animation=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	viewport=SubViewport.new()
	viewport.size=Vector2i(600,700)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var live_preview:=SubViewportContainer.new()
	live_preview.size=Vector2(600,700)
	root.add_child(live_preview)
	live_preview.add_child(viewport)
	var world:=Node3D.new()
	viewport.add_child(world)
	var envnode:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("18263b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e1ddec")
	env.ambient_light_energy=.40
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure=.95
	env.glow_enabled=true
	env.glow_intensity=.25
	env.ssao_enabled=true
	env.ssao_radius=.4
	env.ssao_intensity=1.0
	envnode.environment=env
	world.add_child(envnode)
	for data in [[Vector3(-35,-35,0),Color("fff0da"),1.1],[Vector3(-15,145,0),Color("adbfe7"),.6]]:
		var light:=DirectionalLight3D.new()
		light.rotation_degrees=data[0]
		light.light_color=data[1]
		light.light_energy=data[2]
		light.shadow_enabled=data[2]>1.0
		light.directional_shadow_max_distance=8.0
		light.shadow_opacity=.6
		world.add_child(light)
	S.cylinder(world,Vector3(0,-.09,0),.73,.18,G.satin(Color("354565"),.3))
	S.ring(world,Vector3(0,.006,0),.66,.013,G.satin(Color("d4c5e6"),.55))
	model=MODEL.instantiate()
	model.scale=Vector3.ONE*1.5
	world.add_child(model)
	var animation: AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	animation.play("idle")
	animation.seek(.15,true)
	animation.pause()
	cam=Camera3D.new()
	cam.position=Vector3(0,1.55,4.8)
	world.add_child(cam)
	cam.look_at(Vector3(0,.94,0))
	cam.fov=38
	var catalog: Array=STYLES.SKINS.duplicate()
	catalog.push_front(STYLES.get_skin("classic"))
	if not drafts_path.is_empty():
		catalog=JSON.parse_string(FileAccess.get_file_as_string(drafts_path))
	for skin in catalog:
		if not only_skins.is_empty() and not skin.id in only_skins: continue
		if not clip_skins.is_empty() and not skin.id in clip_skins: continue
		animation.play("idle")
		animation.seek(.15,true)
		animation.pause()
		STYLES.apply_data(model,skin)
		var motion:=model.get_node("CoutureMotion")
		motion.set_process(false)
		motion.refresh()
		motion.elapsed=0
		motion._process(0)
		model.rotation.y=-.18
		if not clip_skins.is_empty():
			animation.play(animation_name)
			animation.pause()
			for frame in 144:
				var t:=frame/24.0
				animation.seek(fmod(t,animation.current_animation_length),true)
				motion.elapsed=t
				motion._process(0)
				model.rotation.y=-.18+sin(t*.7)*.22
				await capture(output_dir+"/"+skin.id+"_%04d.png" % frame)
			print("Animated ",skin.id)
			continue
		var basename: String=skin.get("draft_id",skin.id)
		await capture(output_dir+"/"+basename+".png")
		if skin.id!="classic" and drafts_path.is_empty():
			model.rotation.y=-.72
			await capture(output_dir+"/"+skin.id+"_angle.png")
			model.rotation.y=PI-.35
			if skin.id=="jade_peacock":
				cam.position.z=5.4
				cam.look_at(Vector3(0,.94,0))
			await capture(output_dir+"/"+skin.id+"_back.png")
			cam.position.z=4.8
			cam.look_at(Vector3(0,.94,0))
			animation.play("walk")
			animation.seek(animation.current_animation_length*.25,true)
			animation.pause()
			model.rotation.y=-.55
			await capture(output_dir+"/"+skin.id+"_walk.png")
			animation.play("jump")
			animation.seek(animation.current_animation_length*.45,true)
			animation.pause()
			await capture(output_dir+"/"+skin.id+"_jump.png")
		print("Rendered ",basename)
	quit()
