extends SceneTree
## Headless smoke test:
##   godot --headless --path . --script res://tools/smoke_test.gd
## Loads the main scene, walks the character, swaps through all 8 characters and
## clicks every pet through the same raycast the mouse uses. Exits with code 1 if
## any check fails.

var _failures := 0


func _init() -> void:
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(30)

	var player: Player = main.get_node("Player")
	var pets: Array = main.get_node("Pets").get_children()
	_check(pets.size() == 3, "3 pets spawned (got %d)" % pets.size())

	# --- walking: hold "move_forward", the player must move and play walk ----------
	var start := player.global_position
	Input.action_press("move_forward")
	await _frames(60)
	_check(player.global_position.distance_to(start) > 1.0, "player moved while walking")
	_check(player._current_clip == "walk", "player plays 'walk' (got '%s')" % player._current_clip)
	Input.action_press("run")
	await _frames(40)
	_check(player._current_clip == "run", "player plays 'run' (got '%s')" % player._current_clip)
	Input.action_release("run")
	Input.action_release("move_forward")
	await _frames(60)
	_check(player._current_clip == "idle", "player goes back to 'idle' (got '%s')" % player._current_clip)

	# --- pets follow the player ----------------------------------------------------
	for pet: Pet in pets:
		var distance := pet.global_position.distance_to(player.global_position)
		_check(distance < 5.0, "%s follows the player (distance %.1f m)" % [pet.species, distance])

	# --- resting pets sit down after `sit_after` seconds ----------------------------
	await _frames(420)
	for pet: Pet in pets:
		_check(pet._current_clip == "sit", "%s sits after resting (got '%s')" % [pet.species, pet._current_clip])

	# --- clicking a pet (same raycast as the mouse) --------------------------------
	var camera := (main.get_node("CameraRig") as CameraRig).camera
	for pet: Pet in pets:
		var screen_position := camera.unproject_position(pet.global_position + Vector3.UP * 0.5)
		var hit: Pet = main._pet_under_mouse(screen_position)
		_check(hit == pet, "click ray hits the %s" % pet.species)
		main.pet_pet(pet)
		_check(pet._current_clip == pet._config["happy_clip"],
				"%s plays its happy clip (got '%s')" % [pet.species, pet._current_clip])
	_check(main._pet_count == 3, "petting counter is 3 (got %d)" % main._pet_count)

	# --- swapping through every character ------------------------------------------
	for i in Player.CHARACTERS.size():
		player.set_character(i)
		await _frames(5)
		_check(player._animation_player != null and player._animation_player.has_animation("walk"),
				"character %s has a walk clip" % Player.CHARACTERS[i]["name"])

	# --- emotes ----------------------------------------------------------------------
	player.play_emote("wave")
	await _frames(3)
	_check(player._current_clip == "wave", "wave emote plays (got '%s')" % player._current_clip)

	print("SMOKE TEST: %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
	main.queue_free()
	await _frames(2)
	quit(1 if _failures > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok    ", message)
	else:
		print("  FAIL  ", message)
		_failures += 1
