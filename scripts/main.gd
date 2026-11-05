extends Node3D
## Wires the demo together: input, pets, camera, picking and the HUD.
##
## Scene tree (scenes/main.tscn):
##   Main  (this script)
##   |- Garden       builds sky, lawn, fence and props       (garden.gd)
##   |- Player       the controllable Blocky character       (player.tscn)
##   |- CameraRig    third-person orbit camera               (camera_rig.gd)
##   |- Pets         the animals are spawned in here
##   `- HUD          controls hint + petting counter

const PET_SCENE := preload("res://scenes/pet.tscn")
## Which animals to spawn, and where each one stands relative to the player.
const PET_SLOTS := [
	{"species": "cat", "offset": Vector3(-1.3, 0.0, -1.8)},
	{"species": "fox", "offset": Vector3(1.4, 0.0, -2.2)},
	{"species": "owl", "offset": Vector3(0.0, 0.0, -3.4)},
]
## Collision layer the pets live on (see Pet / pet.tscn). The click ray only hits this layer.
const PET_LAYER := 4

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _pets: Node3D = $Pets
@onready var _info: Label = $HUD/Info

var _pet_count := 0
var _character_name := ""
var _hovered_pet: Pet


func _ready() -> void:
	InputSetup.register()
	_rig.target = _player
	_player.character_changed.connect(_on_character_changed)
	_on_character_changed(Player.CHARACTERS[_player.character_index]["name"])

	# `--autopilot` (used by tools/record.sh) drives the demo by script. See autopilot.gd.
	if "--autopilot" in OS.get_cmdline_user_args():
		var autopilot := Autopilot.new()
		autopilot.main = self
		autopilot.player = _player
		autopilot.rig = _rig
		add_child(autopilot)

	for slot: Dictionary in PET_SLOTS:
		var pet: Pet = PET_SCENE.instantiate()
		pet.species = slot["species"]
		pet.slot_offset = slot["offset"]
		pet.leader = _player
		# Start next to the player so the pets do not have to run in from the corner.
		pet.position = _player.position + Basis(Vector3.UP, _player.facing_yaw) * slot["offset"]
		_pets.add_child(pet)
	_refresh_hud()


func _process(_delta: float) -> void:
	_player.camera_yaw = _rig.yaw


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Show a hand cursor while the mouse is over a pet.
		_hovered_pet = _pet_under_mouse(event.position)
		Input.set_default_cursor_shape(
				Input.CURSOR_POINTING_HAND if _hovered_pet != null else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pet := _pet_under_mouse(event.position)
		if pet != null:
			pet_pet(pet)


## Pets a pet: it plays its happy clip and hops, hearts pop up, and the player cheers
## if they are standing close enough. Public so the autopilot can call it too.
func pet_pet(pet: Pet) -> void:
	if not pet.pet_me():
		return
	_pet_count += 1
	Effects.spawn_hearts(self, pet.global_position + Vector3.UP * 0.9)
	if pet.global_position.distance_to(_player.global_position) < 5.0:
		_player.play_emote("cheer")
	_refresh_hud()


## Casts a ray from the camera through the mouse position and returns the Pet it hits.
func _pet_under_mouse(mouse_position: Vector2) -> Pet:
	var camera := _rig.camera
	var from := camera.project_ray_origin(mouse_position)
	var to := from + camera.project_ray_normal(mouse_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to, PET_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Pet


func _on_character_changed(display_name: String) -> void:
	_character_name = display_name
	_refresh_hud()


func _refresh_hud() -> void:
	_info.text = "Blocky Pets Godot Starter  -  Pets petted: %d  -  Character: %s\n" % [_pet_count, _character_name] \
		+ "WASD / arrows: move   Shift: run   Space: jump   Left click a pet: pet it\n" \
		+ "Right mouse drag or Q/E: orbit   Wheel: zoom   F: wave   G: dance   C: change character"
