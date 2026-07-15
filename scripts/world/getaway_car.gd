class_name GetawayCar
extends AnimatableBody3D

signal drive_requested(car: GetawayCar, player: Node)
signal escaped

var display_name := "Garage getaway car"
var driving := false
var _body_root: Node3D
var _headlights: Array[SpotLight3D] = []

func setup() -> void:
	add_to_group("getaway_car")
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.25, 1.55, 6.1)
	collision.shape = shape
	collision.position.y = 0.78
	add_child(collision)
	_body_root = Node3D.new()
	add_child(_body_root)
	var paint := _material(Color("#243d51"), 0.64, 0.25)
	var dark := _material(Color("#11181d"), 0.15, 0.28)
	var glass := _material(Color("#183242"), 0.38, 0.16)
	_add_box(_body_root, Vector3(3.25, 0.78, 5.9), Vector3(0, 0.72, 0), paint)
	_add_box(_body_root, Vector3(2.75, 0.82, 2.9), Vector3(0, 1.38, -0.35), paint)
	_add_box(_body_root, Vector3(2.48, 0.56, 0.08), Vector3(0, 1.52, 1.13), glass, Vector3(deg_to_rad(-19.0), 0, 0))
	_add_box(_body_root, Vector3(2.48, 0.52, 0.08), Vector3(0, 1.50, -1.83), glass, Vector3(deg_to_rad(18.0), 0, 0))
	_add_box(_body_root, Vector3(3.34, 0.24, 0.28), Vector3(0, 0.48, 3.02), dark)
	_add_box(_body_root, Vector3(3.34, 0.24, 0.28), Vector3(0, 0.48, -3.02), dark)
	for x in [-1.68, 1.68]:
		for z in [-1.85, 1.85]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.48
			wheel_mesh.bottom_radius = 0.48
			wheel_mesh.height = 0.32
			wheel_mesh.material = dark
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(x, 0.48, z)
			wheel.rotation_degrees.z = 90.0
			_body_root.add_child(wheel)
	for x in [-0.95, 0.95]:
		var lamp := SpotLight3D.new()
		lamp.light_color = Color("#fff1c0")
		lamp.light_energy = 5.5
		lamp.spot_range = 18.0
		lamp.spot_angle = 28.0
		lamp.position = Vector3(x, 0.82, 3.0)
		lamp.rotation_degrees.y = 180.0
		lamp.visible = false
		add_child(lamp)
		_headlights.append(lamp)
	var plate := Label3D.new()
	plate.text = "R17-GO"
	plate.font_size = 20
	plate.outline_size = 5
	plate.modulate = Color("#d8d1b7")
	plate.position = Vector3(0, 0.72, 3.12)
	plate.rotation_degrees.x = -90.0
	add_child(plate)

func get_interaction_text(player: Node) -> String:
	if driving:
		return "GETAWAY IN PROGRESS"
	if player.get_inventory().count_item("route17_car_keys") <= 0:
		return "LOCKED - FIND THE ROUTE 17 SERVICE KEYS"
	return "HOLD TO START  GETAWAY CAR"

func interact(player: Node) -> void:
	if driving:
		return
	if player.get_inventory().count_item("route17_car_keys") <= 0:
		GameManager.notification.emit("The ignition is locked - the service keys are hidden somewhere on the property", "warn")
		return
	drive_requested.emit(self, player)

func begin_escape(player: Node) -> void:
	if driving:
		return
	driving = true
	player.get_inventory().remove_item("route17_car_keys", 1)
	if player.has_method("set_controls_enabled"):
		player.set_controls_enabled(false)
	player.visible = false
	collision_layer = 0
	for light in _headlights:
		light.visible = true
	GameManager.notification.emit("ENGINE STARTED - GETAWAY ROUTE CLEAR", "good")
	var start_position := position
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", start_position + Vector3(0, 0, 48.0), 2.6)
	tween.tween_callback(func(): escaped.emit())

func _add_box(parent: Node, size: Vector3, pos: Vector3, material: Material, rotation_value := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rotation_value
	parent.add_child(instance)

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
