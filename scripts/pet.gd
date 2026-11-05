class_name Pet
extends CharacterBody3D
## A pet that follows the player and picks idle / walk / run animations from its speed.
##
## Behaviour in short:
##   * It walks to a spot behind the player (every pet has its own slot).
##   * Far away it runs (the owl flies), close by it walks, when it arrives it idles.
##   * Every few seconds it plays `idle_alt`; after a long rest it sits down.
##   * pet_me() plays the species' "happy" clip and makes it hop.

## Per species: model, scale, speeds, the clip used when running and when petted.
const SPECIES := {
	"cat": {
		"path": "res://assets/pets/animal_cat.glb",
		"scale": 1.8, "walk_speed": 2.4, "run_speed": 5.4,
		"run_clip": "run", "happy_clip": "jump", "hover": 0.0,
	},
	"fox": {
		"path": "res://assets/pets/animal_fox.glb",
		"scale": 1.8, "walk_speed": 2.6, "run_speed": 5.8,
		"run_clip": "run", "happy_clip": "jump", "hover": 0.0,
	},
	"owl": {
		"path": "res://assets/pets/animal_owl.glb",
		"scale": 1.8, "walk_speed": 2.2, "run_speed": 5.2,
		"run_clip": "fly", "happy_clip": "call", "hover": 0.9,
	},
}

const LOOPING_CLIPS := ["idle", "walk", "run", "fly"]

@export_enum("cat", "fox", "owl") var species := "cat"
## Where the pet wants to stand, relative to the player (x = right, z = forward).
@export var slot_offset := Vector3(-1.3, 0.0, -1.8)
## Seconds standing still before the pet sits down.
@export var sit_after := 5.0

## Set by main.gd: the node to follow. It must expose `facing_yaw`.
var leader: Player

var _config: Dictionary
var _model: Node3D
var _animation_player: AnimationPlayer
var _current_clip := ""
var _yaw := 0.0
var _moving := false
var _idle_time := 0.0
var _next_idle_alt := 4.0
var _one_shot_time := 0.0   # a one-shot clip (idle_alt, sit) is playing
var _happy_time := 0.0      # being petted: stand still and play the happy clip
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_config = SPECIES[species]
	_model = $Model
	_model.scale = Vector3.ONE * _config["scale"]
	var instance: Node3D = (load(_config["path"]) as PackedScene).instantiate()
	_model.add_child(instance)
	_animation_player = AnimUtil.find_animation_player(instance)
	AnimUtil.set_looping(_animation_player, LOOPING_CLIPS)
	AnimUtil.setup_lod(instance)
	_next_idle_alt = randf_range(3.0, 7.0)
	_play("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _happy_time > 0.0:
		_happy_time -= delta
		_stand_still(delta)
		_face(_leader_direction(), delta * 0.5)
	elif leader != null:
		_follow(delta)

	move_and_slide()
	_update_hover(delta)


## Called when the player clicks the pet. Returns true if it reacted.
func pet_me() -> bool:
	if _happy_time > 0.0:
		return false
	var clip: String = _config["happy_clip"]
	_happy_time = maxf(AnimUtil.clip_length(_animation_player, clip), 0.8)
	_one_shot_time = 0.0
	_idle_time = 0.0
	_play(clip, true)
	if is_on_floor():
		velocity.y = 3.2  # a little hop
	return true


func _follow(delta: float) -> void:
	var anchor := leader.global_position + Basis(Vector3.UP, leader.facing_yaw) * slot_offset
	var to_anchor := anchor - global_position
	to_anchor.y = 0.0
	var distance := to_anchor.length()

	# Hysteresis: start moving when far, stop when close, so it never jitters.
	if distance > 1.2:
		_moving = true
	elif distance < 0.4:
		_moving = false

	if _moving:
		var speed := clampf(distance * 1.6, 0.8, _config["run_speed"])
		var direction := to_anchor / maxf(distance, 0.001)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		_face(direction, delta)
		_idle_time = 0.0
		_one_shot_time = 0.0
		var running: bool = speed > _config["walk_speed"] * 1.15
		_play(_config["run_clip"] if running else "walk")
	else:
		_stand_still(delta)
		_idle_time += delta
		_update_idle(delta)


func _stand_still(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)


func _update_idle(delta: float) -> void:
	if _one_shot_time > 0.0:
		_one_shot_time -= delta
		return
	if _idle_time > sit_after:
		if _current_clip != "sit":
			_play("sit", true)  # one-shot; the pose is held until the pet moves again
		return
	_play("idle")
	_next_idle_alt -= delta
	if _next_idle_alt <= 0.0:
		_next_idle_alt = randf_range(4.0, 8.0)
		_one_shot_time = AnimUtil.clip_length(_animation_player, "idle_alt")
		_play("idle_alt", true)


## Birds hover while "flying" and settle back down when they stop.
func _update_hover(delta: float) -> void:
	var target_height := 0.0
	if _moving and _current_clip == _config["run_clip"]:
		target_height = _config["hover"]
	_model.position.y = lerpf(_model.position.y, target_height, 6.0 * delta)


func _face(direction: Vector3, weight: float) -> void:
	if direction.length() < 0.01:
		return
	_yaw = lerp_angle(_yaw, atan2(direction.x, direction.z), clampf(weight * 10.0, 0.0, 1.0))
	_model.rotation.y = _yaw


func _leader_direction() -> Vector3:
	if leader == null:
		return Vector3.ZERO
	var d := leader.global_position - global_position
	d.y = 0.0
	return d.normalized()


func _play(clip: String, restart := false) -> void:
	if _animation_player == null or not _animation_player.has_animation(clip):
		return
	if clip == _current_clip and not restart:
		return
	_current_clip = clip
	_animation_player.play(clip, 0.2)
