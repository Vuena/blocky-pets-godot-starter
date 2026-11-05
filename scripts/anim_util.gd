class_name AnimUtil
extends RefCounted
## Small helpers shared by the player and the pets for the imported .glb models.


## Returns the AnimationPlayer that Godot creates for a rigged .glb.
static func find_animation_player(root: Node) -> AnimationPlayer:
	return root.find_child("AnimationPlayer", true, false) as AnimationPlayer


## glTF clips are imported with "no loop". Call this once per model to make the
## given clips (idle, walk, run ...) loop. The Animation resources are shared by
## every instance of the same .glb, so doing it again is harmless.
static func set_looping(player: AnimationPlayer, clip_names: Array) -> void:
	for clip_name: String in clip_names:
		if player.has_animation(clip_name):
			player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR


## The animals ship two meshes in one file: <name>_LOD0 (detailed) and
## <name>_LOD1 (mobile). Show LOD0 up close and swap to LOD1 beyond `distance`
## metres using Godot's built-in visibility ranges.
static func setup_lod(root: Node, distance: float = 18.0) -> void:
	for node in root.find_children("*_LOD0", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visibility_range_end = distance
	for node in root.find_children("*_LOD1", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visibility_range_begin = distance


## Length of a clip in seconds (0.0 if the clip does not exist).
static func clip_length(player: AnimationPlayer, clip_name: String) -> float:
	if player != null and player.has_animation(clip_name):
		return player.get_animation(clip_name).length
	return 0.0
