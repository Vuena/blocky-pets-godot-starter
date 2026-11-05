class_name CameraRig
extends Node3D
## Simple third-person orbit camera.
## The rig node sits on the target and is rotated (yaw / pitch); the Camera3D is a
## child pushed back along local +Z by `distance`.
##   Right mouse drag or Q / E : orbit        Mouse wheel : zoom

@export var target: Node3D
@export var distance := 8.5
@export var min_distance := 4.0
@export var max_distance := 16.0
@export_range(5.0, 80.0) var pitch_degrees := 26.0
@export var height_offset := 1.0
@export var follow_speed := 7.0
@export var mouse_sensitivity := 0.006
@export var key_orbit_speed := 1.8

var camera: Camera3D
var yaw := 0.0
var _pitch := 0.0
var _target_distance := 8.5


func _ready() -> void:
	_pitch = deg_to_rad(pitch_degrees)
	_target_distance = distance
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 55.0
	camera.near = 0.1
	camera.far = 150.0
	add_child(camera)
	if target != null:
		global_position = target.global_position + Vector3.UP * height_offset
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch + event.relative.y * mouse_sensitivity, deg_to_rad(8.0), deg_to_rad(75.0))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance - 0.8, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance + 0.8, min_distance, max_distance)


func _process(delta: float) -> void:
	yaw += Input.get_axis("camera_right", "camera_left") * key_orbit_speed * delta
	if target != null:
		var goal := target.global_position + Vector3.UP * height_offset
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	distance = lerpf(distance, _target_distance, 1.0 - exp(-10.0 * delta))
	_apply()


func _apply() -> void:
	rotation = Vector3(-_pitch, yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, distance)
