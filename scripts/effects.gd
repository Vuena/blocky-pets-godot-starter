class_name Effects
extends RefCounted
## Tiny visual effects. Everything is generated in code, so there are no extra assets.

# 7x6 pixel heart, X = filled, o = highlight.
const HEART := [
	".XX.XX.",
	"XoXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]

static var _heart_texture: Texture2D


static func heart_texture() -> Texture2D:
	if _heart_texture == null:
		var image := Image.create_empty(7, 6, false, Image.FORMAT_RGBA8)
		for y in HEART.size():
			for x in 7:
				var c: String = HEART[y][x]
				var color := Color(0, 0, 0, 0)
				if c == "X":
					color = Color("ff5d8f")
				elif c == "o":
					color = Color("ffd1e0")
				image.set_pixel(x, y, color)
		_heart_texture = ImageTexture.create_from_image(image)
	return _heart_texture


## Spawns a few hearts that float up and fade out above `position`.
static func spawn_hearts(parent: Node, position: Vector3, count: int = 5) -> void:
	for i in count:
		var heart := Sprite3D.new()
		heart.texture = heart_texture()
		heart.pixel_size = 0.07
		heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		heart.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		heart.shaded = false
		heart.position = position + Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
		parent.add_child(heart)
		var delay := i * 0.09
		var tween := heart.create_tween().set_parallel(true)
		tween.tween_property(heart, "position:y", position.y + 1.1 + randf() * 0.5, 1.1).set_delay(delay)
		tween.tween_property(heart, "modulate:a", 0.0, 0.4).set_delay(delay + 0.7)
		tween.chain().tween_callback(heart.queue_free)
