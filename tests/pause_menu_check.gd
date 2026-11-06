extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)

func run() -> void:
	var campaign := root.get_node("Campaign")
	campaign.save_enabled = false
	campaign.settings_path = OS.get_environment("TMPDIR").path_join("island_pause_settings_%d.cfg" % OS.get_process_id())
	campaign.level_index = 0
	root.get_node("Wardrobe").save_enabled = false
	change_scene_to_file("res://main.tscn")
	await frames(30)
	var game := current_scene
	game.audio_enabled = false
	game.player.sound_enabled = false
	click(game.overlay_button)
	await frames(2)
	check(game.game_started and not paused, "Start button enters gameplay")
	escape()
	await frames(2)
	check(paused and game.overlay.visible, "Escape opens pause screen")
	var yaw: float = game.camera_yaw
	for entry in [["地图", "selector"], ["衣橱", "shop"], ["设置", "settings_panel"]]:
		var button: Button
		for candidate in game.top_bar.find_children("*", "Button", true, false):
			if candidate.text == entry[0]: button = candidate
		check(is_instance_valid(button), "Toolbar button exists: " + entry[0])
		if not is_instance_valid(button): continue
		click(button)
		await frames(3)
		check(is_instance_valid(game.get(entry[1])), "Real pointer click opens toolbar panel: " + entry[0])
		check(paused and not game._mouse_look_enabled(), "Panel keeps gameplay paused and cursor free")
		check(is_equal_approx(yaw, game.camera_yaw), "Navigating menus does not move camera")
		# A modal must cover the toolbar, including its resume button.
		click(game.pause_button)
		await frames(2)
		check(paused and is_instance_valid(game.get(entry[1])), "Modal prevents clicking through to resume")
		escape()
		await frames(3)
		check(not is_instance_valid(game.get(entry[1])), "Escape closes only current panel")
		check(paused and game.overlay.visible, "Closing panel returns to pause menu")
	click(game.overlay_button)
	await frames(2)
	check(not paused and not game.overlay.visible and game._mouse_look_enabled(), "Continue restores gameplay and free look")
	escape()
	await frames(2)
	click(game.pause_button)
	await frames(2)
	check(not paused and game._mouse_look_enabled(), "Toolbar pause button can resume too")
	game.queue_free()
	await frames(3)
	if FileAccess.file_exists(campaign.settings_path): DirAccess.remove_absolute(campaign.settings_path)
	print("Pause menu failures: ", failures)
	quit(1 if failures else 0)
