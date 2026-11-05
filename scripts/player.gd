class_name Player
extends CharacterBody3D
## Third-person character controller for the rigged Blocky characters.
##
## - Camera-relative WASD movement, Shift to run, Space to jump.
## - The animation follows the state: idle / walk / run / jump / fall.
## - F plays "wave", G plays "dance"; petting an animal plays "cheer".
## - Press C to swap the character model at runtime (all 8 share one skeleton and
##   the same clip names, so the code never changes).

signal character_changed(display_name: String)

## The 8 free CC0 characters. They all use the same 22-bone skeleton.
const CHARACTERS: Array[Dictionary] = [
	{"name": "Hero", "path": "res://assets/characters/blocky_01_hero.glb"},
	{"name": "Knight", "path": "res://assets/characters/blocky_03_knight.glb"},
	{"name": "Wizard", "path": "res://assets/characters/blocky_05_wizard.glb"},
	{"name": "Pirate", "path": "res://assets/characters/blocky_06_pirate.glb"},
	{"name": "Astronaut", "path": "res://assets/characters/blocky_07_astronaut.glb"},
	{"name": "Robot", "path": "res://assets/characters/blocky_08_robot.glb"},
	{"name": "Zombie", "path": "res://assets/characters/blocky_09_zombie.glb"},
	{"name": "Princess", "path": "res://assets/characters/blocky_19_princess.glb"},
]

## Clips that should loop. The rest (jump, cheer, wave ...) play once.
const LOOPING_CLIPS := ["idle", "walk", "run", "fall", "dance"]
## How many times each emote clip repeats before the character goes back to idle.
const EMOTE_REPEATS := {"wave": 1, "cheer": 1, "dance": 3}

@export var walk_speed := 2.8
@export var run_speed := 5.6
@export var jump_velocity := 5.0
@export var acceleration := 30.0
@export var turn_speed := 12.0
## How hard walking into a RigidBody (the ball) pushes it.
@export var push_force := 1.2

## Yaw of the camera in radians. main.gd keeps this up to date so that
## "forward" always means "away from the camera".
var camera_yaw := 0.0
## Direction the character is facing (yaw, radians). Pets use it to find "behind me".
var facing_yaw := 0.0
var character_index := 0

## Scripted control, used by the autopilot that records the README GIF.
var ai_active := false
var ai_direction := Vector3.ZERO
var ai_run := false

var _model: Node3D
var _animation_player: AnimationPlayer
var _current_clip := ""
var _emote := ""
var _emote_time := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_model = $Model
	set_character(0)


func _unhandled_input(event: InputEvent) -> void:
	if ai_active:
		return
	if event.is_action_pressed("next_character"):
		set_character(character_index + 1)
	elif event.is_action_pressed("emote_wave"):
		play_emote("wave")
	elif event.is_action_pressed("emote_dance"):
		play_emote("dance")


func _physics_process(delta: float) -> void:
	# --- read input -------------------------------------------------------
	var direction := Vector3.ZERO
	var running := false
	if ai_active:
		direction = ai_direction
		running = ai_run
	else:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0.0, input.y)
		running = Input.is_action_pressed("run")
	var moving := direction.length() > 0.1
	var speed := run_speed if running else walk_speed

	# --- horizontal movement ----------------------------------------------
	var target := direction.limit_length(1.0) * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if moving:
		facing_yaw = lerp_angle(facing_yaw, atan2(direction.x, direction.z), turn_speed * delta)
		_model.rotation.y = facing_yaw

	# --- gravity and jumping ----------------------------------------------
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif not ai_active and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	move_and_slide()
	_push_rigid_bodies()
	_update_animation(delta, moving)


## Plays an emote ("wave", "cheer", "dance"). Moving or jumping cancels it.
func play_emote(emote: String) -> void:
	if _animation_player == null or not _animation_player.has_animation(emote):
		return
	_emote = emote
	_emote_time = AnimUtil.clip_length(_animation_player, emote) * EMOTE_REPEATS.get(emote, 1)
	_play(emote, true)


## Swaps the character model. `index` wraps around the CHARACTERS list.
func set_character(index: int) -> void:
	character_index = posmod(index, CHARACTERS.size())
	for child in _model.get_children():
		child.queue_free()
	var entry: Dictionary = CHARACTERS[character_index]
	var scene: PackedScene = load(entry["path"])
	var instance := scene.instantiate()
	_model.add_child(instance)
	_animation_player = AnimUtil.find_animation_player(instance)
	AnimUtil.set_looping(_animation_player, LOOPING_CLIPS)
	_current_clip = ""
	_model.rotation.y = facing_yaw
	character_changed.emit(entry["name"])


func _update_animation(delta: float, moving: bool) -> void:
	var clip := "idle"
	var grounded := is_on_floor()
	if moving or not grounded:
		_emote_time = 0.0  # moving or jumping cancels an emote
	if not grounded:
		clip = "jump" if velocity.y > 0.5 else "fall"
	elif moving:
		var planar_speed := Vector2(velocity.x, velocity.z).length()
		clip = "run" if planar_speed > (walk_speed + run_speed) * 0.5 else "walk"
	elif _emote_time > 0.0:
		_emote_time -= delta
		clip = _emote
	_play(clip)


## Plays a clip with a short cross-fade. Does nothing if it is already playing,
## unless `restart` is set.
func _play(clip: String, restart := false) -> void:
	if _animation_player == null or not _animation_player.has_animation(clip):
		return
	if clip == _current_clip and not restart:
		return
	_current_clip = clip
	_animation_player.play(clip, 0.15)


func _push_rigid_bodies() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		if body is RigidBody3D:
			body.apply_central_impulse(-collision.get_normal() * push_force)
