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

func fall(game: Node) -> void:
	game.player.position = Vector3(200, -10, 200)
	game.player.velocity = Vector3(3, -25, 2)
	await frames(2)
	check(not game.player.active and fall_count == 1, "A fall disables the player and emits once")

func check_settled(game: Node, expected_health: float) -> void:
	await frames(70)
	check(game.player.active and not game.game_finished, "Respawn restores gameplay")
	check(game.player.is_on_floor(), "Respawn lands safely on the island")
	check(game.player.position.distance_to(game.player.spawn_position) < .3, "Respawn returns to the saved spawn")
	check(is_equal_approx(game.player.health, expected_health), "One fall applies the expected health loss exactly once")
	check(fall_count == 1, "Respawn does not trigger another fall")
	game.player.set_virtual_move(Vector2(1, 0))
	await frames(8)
	game.player.set_virtual_move(Vector2.ZERO)
	await frames(70)
	check(game.player.position.distance_to(game.player.spawn_position) > .35, "No stale timer teleports the player back after moving away")
	check(fall_count == 1, "Player remains stable after respawn")

func run() -> void:
	root.get_node("Campaign").save_enabled = false
	root.get_node("Wardrobe").save_enabled = false
	var game := await stage(0)
	await fall(game)
	var waiting_position: Vector3 = game.player.position
	await frames(10)
	check(game.player.position.is_equal_approx(waiting_position), "Player stops falling while waiting to respawn")
	check(game.player.velocity.is_zero_approx(), "Death clears motion instead of accelerating into the void")
	await check_settled(game, IslandPlayer.MAX_HEALTH)

	# Resuming with the Continue button must not start a second fall timer.
	game = await stage(0)
	await fall(game)
	game._toggle_pause()
	game._on_overlay_button()
	check(not game.player.active, "Continue cannot reactivate a player waiting to respawn")
	await check_settled(game, IslandPlayer.MAX_HEALTH)

	# The respawn countdown belongs to gameplay time, including while menus pause it.
	game = await stage(0)
	await fall(game)
	waiting_position = game.player.position
	game._toggle_pause()
	await frames(60)
	check(not game.player.active and game.player.position.is_equal_approx(waiting_position), "Pause does not teleport or reactivate a dead player")
	game._on_overlay_button()
	await check_settled(game, IslandPlayer.MAX_HEALTH)

	# Use an actual checkpoint in a normal stage, preserving its one-heart fall cost.
	game = await stage(3)
	for item in get_nodes_in_group("adventure_item"):
		if item.kind == "checkpoint":
			game.player.position = item.global_position + Vector3.UP * .1
			game.player.velocity = Vector3.ZERO
			break
	await frames(12)
	check(game.player.checkpoint_index >= 0, "Checkpoint activates before the fall")
	await fall(game)
	game._on_player_fell()
	await check_settled(game, IslandPlayer.MAX_HEALTH - 1.0)

	# Old jump/grounding state must not leak into the first frame after teleporting.
	game.player.coyote_time = .13
	game.player.jump_buffer = .14
	game.player._was_on_floor = true
	game.player._pose_landed = true
	game.player.respawn()
	check(game.player.coyote_time == 0 and game.player.jump_buffer == 0, "Respawn clears buffered jumps and coyote time")
	check(not game.player._was_on_floor and not game.player._pose_landed, "Respawn clears stale grounding and landing state")
	await frames(15)
	check(game.player.is_on_floor(), "Respawn does not replay a buffered jump")

	# A fatal hit and a final-heart fall end once and never schedule a resurrection.
	game.player.health = IslandPlayer.ENEMY_DAMAGE
	game.player.invulnerable = 0
	game.player.take_damage(game.player.position + Vector3.FORWARD)
	check(game.game_finished and not game.player.active, "Fatal hit ends the run")
	waiting_position = game.player.position
	game.player._physics_process(1.0 / 60.0)
	check(game.player.position.is_equal_approx(waiting_position), "Inactive dead player cannot keep moving")

	game = await stage(3)
	game.player.health = 1.0
	await fall(game)
	waiting_position = game.player.position
	await frames(70)
	check(game.game_finished and not game.player.active and game.player.health == 0, "Final-heart fall remains on the failure screen")
	check(game.player.position.is_equal_approx(waiting_position) and fall_count == 1, "Fatal fall never teleports or emits repeatedly")

	game = await stage(3)
	await fall(game)
	game._end_game(false, "时间到")
	waiting_position = game.player.position
	# Let the old timer expire even if another caller unpauses the world.
	paused = false
	await frames(70)
	check(game.game_finished and not game.player.active, "Pending respawn cannot revive a finished run")
	check(game.player.position.is_equal_approx(waiting_position), "Finished run ignores its pending teleport")

	game = await stage(0)
	await fall(game)
	game._reload_stage()
	await scene_changed
	await frames(4)
	game = current_scene
	game.audio_enabled = false
	game.player.sound_enabled = false
	check(not game.respawn_pending, "Retry starts with no pending respawn")
	game._on_overlay_button()
	await frames(70)
	check(game.player.active and game.player.is_on_floor(), "Retry during respawn starts a stable new run")
	check(game.player.position.distance_to(game.stage_spawn) < .3, "Old respawn cannot teleport the restarted player")

	paused = false
	current_scene.queue_free()
	await frames(4)
	print("Respawn failures: ", failures)
	quit(1 if failures else 0)
