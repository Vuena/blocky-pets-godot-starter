class_name Autopilot
extends Node
## Scripted demo used to record the README GIF (see tools/record.sh). It is only
## added when the game is started with the user argument `--autopilot`.
## It walks the character in a curve, runs, stops, then pets every animal.

var main: Node3D
var player: Player
var rig: CameraRig

const WALK_TURN_RATE := 0.85  # rad/s; speed / turn rate = circle radius
const RUN_TURN_RATE := 1.7    # twice as fast, so the circle stays the same size
const START_HEADING := 0.8

var _time := 0.0
var _heading := START_HEADING
var _pet_times := [6.0, 7.6, 9.2]  # when each animal gets petted (seconds)
var _next_pet := 0


func _ready() -> void:
	player.ai_active = true
	# Start on a circle (radius ~3.3 m) around the middle of the garden.
	var radius := player.walk_speed / WALK_TURN_RATE
	player.global_position = Vector3(-cos(START_HEADING), 0.0, sin(START_HEADING)) * radius


func _process(delta: float) -> void:
	_time += delta

	# Chase camera: swing round to look the way the character is facing.
	rig.yaw = lerp_angle(rig.yaw, player.facing_yaw + PI, 1.5 * delta)

	# Walk (0-3 s), run (3-5.2 s), stand still afterwards.
	player.ai_direction = Vector3.ZERO
	player.ai_run = false
	if _time < 5.2:
		player.ai_run = _time > 3.0
		_heading += delta * (RUN_TURN_RATE if player.ai_run else WALK_TURN_RATE)
		player.ai_direction = Vector3(sin(_heading), 0.0, cos(_heading))

	if _next_pet < _pet_times.size() and _time >= _pet_times[_next_pet]:
		var pets := main.get_node("Pets").get_children()
		if _next_pet < pets.size():
			main.pet_pet(pets[_next_pet])
		_next_pet += 1
