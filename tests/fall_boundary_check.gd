extends SceneTree

var failures := 0
var fall_count := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func stage(index: int) -> Node:
	paused = false
	root.get_node("Campaign").level_index = index
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(4)
	var game := current_scene
	game.audio_enabled = false
	game.player.sound_enabled = false
	game._on_overlay_button()
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	fall_count = 0
	game.player.fell.connect(func(): fall_count += 1)
	await frames(12)
	return game

func check_above_surface(game: Node, message: String) -> void:
	# The visible waves reach -4.785, above the base plane at -5.
	check(game.player.position.y >= -4.785, message + ": player stays above the surface")
	game._process(0.0)
	check(game.camera.position.y > -4.785, message + ": camera stays above the surface")

func run() -> void:
	root.get_node("Campaign").save_enabled = false
	root.get_node("Wardrobe").save_enabled = false
	var game := await stage(0)
	game.camera_pitch = .14
	game.orbit_pitch = .14
	var lowest_y: float = game.player.position.y
	for i in 120:
		game.player.set_virtual_move(Vector2(1, 0))
		await frames(1)
		lowest_y = minf(lowest_y, game.player.position.y)
		if fall_count > 0:
			break
	game.player.set_virtual_move(Vector2.ZERO)
	check(fall_count == 1 and not game.player.active, "Walking off an island triggers one fall")
	check(lowest_y >= -4.785, "Natural falling never crosses the visible map surface")
	check_above_surface(game, "Natural fall")
	await frames(70)
	check(game.player.is_on_floor() and game.player.active and fall_count == 1, "Natural fall respawns safely once")

	for index in [0, 5, 49]:
		game = await stage(index)
		game.camera_pitch = .14
		game.orbit_pitch = .14
		game.player.position = Vector3(120, -4.4, 120)
		game.player.velocity = Vector3(0, -180, 0)
		await frames(2)
		check(fall_count == 1 and not game.player.active, "Fast fall stops before crossing the map in level %d" % (index + 1))
		check_above_surface(game, "Fast fall in level %d" % (index + 1))
		await frames(70)
		check(game.player.active and game.player.is_on_floor() and fall_count == 1, "Fast fall has one safe respawn")

	game = await stage(3)
	game.player.health = 1.0
	game.player.position = Vector3(120, -4.4, 120)
	game.player.velocity = Vector3(0, -180, 0)
	await frames(2)
	check(game.game_finished and game.player.health == 0, "Fatal fall ends at the map boundary")
	check_above_surface(game, "Fatal fall")
	await frames(70)
	check_above_surface(game, "Failure screen")
	check(fall_count == 1 and not game.player.active, "Fatal fall stays stopped")

	paused = false
	current_scene.queue_free()
	await frames(4)
	print("Fall boundary failures: ", failures)
	quit(1 if failures else 0)
