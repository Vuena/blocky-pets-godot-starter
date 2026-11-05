class_name Garden
extends Node3D
## Builds the snowy garden entirely from code: sky and light, a checkerboard
## snow lawn, a cross path, a fence (which is also the invisible wall), falling
## snow, presents and the CC0 props. Edit the PROPS table to rearrange it.

const HALF_SIZE := 14.0  # the garden is 28 x 28 m

const MODELS := {
	"pine": "res://assets/props/prop_pine_snow_small.glb",
	"tree": "res://assets/props/prop_tree_small.glb",
	"lantern": "res://assets/props/prop_lantern_post.glb",
	"snowman": "res://assets/props/prop_snowman_classic.glb",
	"sled": "res://assets/props/prop_sled.glb",
	"igloo": "res://assets/props/prop_igloo.glb",
	"candy_cane": "res://assets/props/prop_candy_cane.glb",
	"present_red": "res://assets/props/prop_present_red.glb",
	"present_blue": "res://assets/props/prop_present_blue.glb",
}

## [model, x, z, yaw degrees, scale, collider]
## collider: 0 = none, > 0 = round collider with that radius, < 0 = box collider
## (see _place() for the box size).
const PROPS := [
	# snowy pines along the edge
	["pine", -12.0, -11.5, 0, 2.0, 0.4], ["pine", -6.0, -12.5, 40, 2.3, 0.4],
	["pine", 4.5, -12.0, 90, 1.9, 0.4], ["pine", 11.5, -10.5, 20, 2.2, 0.4],
	["pine", 12.5, -3.0, 70, 2.0, 0.4], ["pine", 11.0, 7.5, 10, 2.3, 0.4],
	["pine", 5.5, 12.0, 55, 1.9, 0.4], ["pine", -5.0, 12.5, 100, 2.2, 0.4],
	["pine", -12.0, 9.0, 30, 2.0, 0.4], ["pine", -12.5, 1.0, 75, 2.3, 0.4],
	# decorated trees near the paths
	["tree", 7.5, -3.5, 0, 1.8, 0.35], ["tree", -7.5, 3.5, 0, 1.8, 0.35],
	["tree", 3.0, 8.5, 0, 1.8, 0.35], ["tree", -3.0, -8.5, 0, 1.8, 0.35],
	# lanterns around the middle of the cross path
	["lantern", 2.2, 2.2, 0, 0.9, 0.2], ["lantern", -2.2, 2.2, 0, 0.9, 0.2],
	["lantern", 2.2, -2.2, 0, 0.9, 0.2], ["lantern", -2.2, -2.2, 0, 0.9, 0.2],
	# the rest of the yard
	["snowman", 8.0, 6.0, 215, 1.2, 0.55], ["igloo", -9.0, -6.5, 35, 1.0, 1.9],
	["sled", 6.5, -6.0, 25, 1.6, -1.0], ["sled", -7.0, 6.5, -30, 1.6, -1.0],
	# candy canes along the paths
	["candy_cane", 1.5, -6.0, 0, 1.0, 0.0], ["candy_cane", -1.5, 6.0, 180, 1.0, 0.0],
	["candy_cane", 6.0, 1.5, 90, 1.0, 0.0], ["candy_cane", -6.0, -1.5, -90, 1.0, 0.0],
	# presents
	["present_red", 3.5, 4.5, 20, 0.8, 0.0], ["present_blue", 4.3, 5.0, 70, 0.8, 0.0],
	["present_blue", -4.0, -4.5, 15, 0.8, 0.0], ["present_red", -4.8, -5.2, 55, 0.7, 0.0],
	["present_red", 9.0, -3.0, 40, 0.8, 0.0], ["present_blue", -8.5, 3.5, 110, 0.8, 0.0],
	["present_red", -3.0, 9.5, 30, 0.7, 0.0], ["present_blue", 3.0, -9.5, 80, 0.7, 0.0],
]

const SNOWBALL_RADIUS := 0.3

# Collision layers (bit values): 1 = world, 2 = player, 4 = pets, 8 = snowball.
const LAYER_WORLD := 1
const LAYER_SNOWBALL := 8


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_fence()
	_build_snowfall()
	for prop: Array in PROPS:
		_place(prop[0], Vector3(prop[1], 0.0, prop[2]), prop[3], prop[4], prop[5])
	_build_snowball(Vector3(3.5, 1.0, 3.5))


# --- sky, light --------------------------------------------------------------
func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4f86c6")
	sky_material.sky_horizon_color = Color("d6e6f2")
	sky_material.ground_horizon_color = Color("d6e6f2")
	sky_material.ground_bottom_color = Color("c9d8e6")
	var sky := Sky.new()
	sky.sky_material = sky_material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.93, 1.0)
	environment.ambient_light_energy = 0.35

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	# Note: with the Compatibility renderer a directional light this low already looks
	# fully lit, because the sky ambient adds to it. Raise it if your scene looks flat.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 0.22
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	add_child(sun)


# --- ground ------------------------------------------------------------------
func _build_ground() -> void:
	# Snow: a 2x2 pixel checker texture repeated over the plane = 1 m tiles.
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	var light := Color("eef4fb")
	var dark := Color("dde8f4")
	image.set_pixel(0, 0, light)
	image.set_pixel(1, 1, light)
	image.set_pixel(1, 0, dark)
	image.set_pixel(0, 1, dark)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(40.0, 40.0, 1.0)
	material.roughness = 1.0

	var lawn := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	lawn.mesh = plane
	lawn.material_override = material
	add_child(lawn)

	# The same ground as a physics body (top surface at y = 0).
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)

	# Trampled cross path, slightly raised so it never z-fights with the snow.
	var path_material := _flat_material(Color("9fb2c8"))
	_add_box_mesh(Vector3(28.0, 0.06, 2.4), Vector3(0.0, 0.03, 0.0), path_material)
	_add_box_mesh(Vector3(2.4, 0.06, 28.0), Vector3(0.0, 0.03, 0.0), path_material)


# --- fence -------------------------------------------------------------------
func _build_fence() -> void:
	var wood := _flat_material(Color("b07a45"))
	var wood_dark := _flat_material(Color("8f5f33"))
	var step := 2.0
	var count := int(HALF_SIZE * 2.0 / step)
	for i in count + 1:
		var t := -HALF_SIZE + i * step
		for p: Vector3 in [Vector3(t, 0.0, -HALF_SIZE), Vector3(t, 0.0, HALF_SIZE),
				Vector3(-HALF_SIZE, 0.0, t), Vector3(HALF_SIZE, 0.0, t)]:
			_add_box_mesh(Vector3(0.22, 1.1, 0.22), p + Vector3(0.0, 0.55, 0.0), wood_dark)
	# Rails (two per side).
	var length := HALF_SIZE * 2.0
	for h in [0.4, 0.8]:
		_add_box_mesh(Vector3(length, 0.1, 0.08), Vector3(0.0, h, -HALF_SIZE), wood)
		_add_box_mesh(Vector3(length, 0.1, 0.08), Vector3(0.0, h, HALF_SIZE), wood)
		_add_box_mesh(Vector3(0.08, 0.1, length), Vector3(-HALF_SIZE, h, 0.0), wood)
		_add_box_mesh(Vector3(0.08, 0.1, length), Vector3(HALF_SIZE, h, 0.0), wood)

	# Invisible walls so nobody walks out of the garden.
	for wall: Array in [[Vector3(length, 4.0, 0.5), Vector3(0.0, 2.0, -HALF_SIZE)],
			[Vector3(length, 4.0, 0.5), Vector3(0.0, 2.0, HALF_SIZE)],
			[Vector3(0.5, 4.0, length), Vector3(-HALF_SIZE, 2.0, 0.0)],
			[Vector3(0.5, 4.0, length), Vector3(HALF_SIZE, 2.0, 0.0)]]:
		_add_static_box(wall[0], wall[1])


# --- snowfall ----------------------------------------------------------------
func _build_snowfall() -> void:
	var flake := QuadMesh.new()
	flake.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1, 1, 1, 0.9)
	flake.material = material

	var snow := CPUParticles3D.new()
	snow.mesh = flake
	snow.amount = 220
	snow.lifetime = 7.0
	snow.preprocess = 7.0  # start with the sky already full of flakes
	snow.position = Vector3(0.0, 9.0, 0.0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(HALF_SIZE, 0.5, HALF_SIZE)
	snow.direction = Vector3.DOWN
	snow.spread = 8.0
	snow.gravity = Vector3(0.3, -1.0, 0.0)
	snow.initial_velocity_min = 0.2
	snow.initial_velocity_max = 0.6
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.4
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snow)


# --- props -------------------------------------------------------------------
func _place(key: String, position: Vector3, yaw_degrees: float, scale_factor: float, collider: float) -> void:
	var instance: Node3D = (load(MODELS[key]) as PackedScene).instantiate()
	instance.position = position
	instance.rotation_degrees.y = yaw_degrees
	instance.scale = Vector3.ONE * scale_factor
	add_child(instance)
	if collider == 0.0:
		return
	var body := StaticBody3D.new()
	body.position = position
	body.rotation_degrees.y = yaw_degrees
	var shape := CollisionShape3D.new()
	if collider > 0.0:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = collider
		cylinder.height = 3.0
		shape.shape = cylinder
		shape.position.y = 1.5
	else:  # sled: a 0.71 x 0.28 x 1.67 m model, scaled
		var box := BoxShape3D.new()
		box.size = Vector3(0.71, 0.28, 1.67) * scale_factor
		shape.shape = box
		shape.position.y = 0.14 * scale_factor
	body.add_child(shape)
	add_child(body)


## A snowball you can kick around by walking into it (see Player._push_rigid_bodies).
## It has no model: a white sphere mesh made in code.
func _build_snowball(position: Vector3) -> void:
	var ball := RigidBody3D.new()
	ball.position = position
	ball.collision_layer = LAYER_SNOWBALL  # its own layer, so the pets ignore it
	ball.collision_mask = LAYER_WORLD
	ball.mass = 0.4
	ball.linear_damp = 0.6
	ball.angular_damp = 0.6
	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = 0.4
	physics_material.friction = 0.7
	ball.physics_material_override = physics_material
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SNOWBALL_RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = SNOWBALL_RADIUS
	sphere_mesh.height = SNOWBALL_RADIUS * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = _flat_material(Color("ffffff"))
	ball.add_child(mesh_instance)
	add_child(ball)


# --- tiny helpers ------------------------------------------------------------
func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _add_box_mesh(size: Vector3, position: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = position
	add_child(mesh_instance)


func _add_static_box(size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = position
	body.add_child(shape)
	add_child(body)
