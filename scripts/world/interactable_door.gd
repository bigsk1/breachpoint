class_name InteractableDoor
extends AnimatableBody3D

signal opened(door: InteractableDoor)

var display_name := "Door"
var locked_item_id := ""
var is_vault := false
var is_open := false
var _busy := false

func setup(size: Vector3, color: Color) -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	var width_along_z := size.z > size.x
	var panel_center := Vector3(0.0, 0.0, size.z * 0.5) if width_along_z else Vector3(size.x * 0.5, 0.0, 0.0)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box; shape.position = panel_center; add_child(shape)
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.metallic = 0.62 if is_vault else 0.18; mat.roughness = 0.38; mesh.material = mat
	visual.mesh = mesh; visual.position = panel_center; add_child(visual)
	var handle := MeshInstance3D.new(); var handle_mesh := SphereMesh.new(); handle_mesh.radius = 0.07; handle_mesh.height = 0.14
	var handle_mat := StandardMaterial3D.new(); handle_mat.albedo_color = Color("#c6a15b"); handle_mat.metallic = 0.9; handle_mesh.material = handle_mat; handle.mesh = handle_mesh
	handle.position = Vector3(size.x * 0.6, 0.0, size.z * 0.86) if width_along_z else Vector3(size.x * 0.86, 0.0, size.z * 0.6)
	add_child(handle)
	if is_vault:
		_build_vault_face(size, panel_center)

func _build_vault_face(size: Vector3, center: Vector3) -> void:
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color("#aeb8bd"); steel.metallic = 0.92; steel.roughness = 0.22
	var hub := MeshInstance3D.new(); var hub_mesh := CylinderMesh.new(); hub_mesh.top_radius = 0.78; hub_mesh.bottom_radius = 0.78; hub_mesh.height = 0.16; hub_mesh.material = steel; hub.mesh = hub_mesh
	hub.position = center + Vector3(0, 0, size.z * 0.62); hub.rotation_degrees.x = 90.0; add_child(hub)
	for angle in [0.0, 45.0, 90.0, 135.0]:
		var spoke := MeshInstance3D.new(); var spoke_mesh := BoxMesh.new(); spoke_mesh.size = Vector3(1.85, 0.09, 0.09); spoke_mesh.material = steel; spoke.mesh = spoke_mesh; spoke.position = center + Vector3(0, 0, size.z * 0.84); spoke.rotation_degrees.z = angle; add_child(spoke)
	var lock_light := OmniLight3D.new(); lock_light.light_color = Color("#e1b95d"); lock_light.light_energy = 2.8; lock_light.omni_range = 4.0; lock_light.position = center + Vector3(0, 0.5, size.z * 1.4); add_child(lock_light)

func get_interaction_text(player: Node) -> String:
	if is_open: return "CLOSE  %s" % display_name.to_upper()
	if not locked_item_id.is_empty() and player.get_inventory().count_item(locked_item_id) <= 0:
		return "LOCKED — KEYCARD REQUIRED"
	return "HOLD TO OPEN  %s" % display_name.to_upper()

func interact(player: Node) -> void:
	if _busy: return
	if not locked_item_id.is_empty():
		if player.get_inventory().count_item(locked_item_id) <= 0:
			GameManager.notification.emit("Access denied — locate the security keycard", "warn"); GameManager.raise_alert(2.0); return
		player.get_inventory().remove_item(locked_item_id, 1)
		locked_item_id = ""
	_set_open(not is_open)

func request_open_for_actor(_actor: Node) -> bool:
	if is_open:
		return true
	if _busy or is_vault or not locked_item_id.is_empty():
		return false
	_set_open(true)
	return is_open

func _set_open(value: bool) -> void:
	if _busy or is_open == value:
		return
	_busy = true
	is_open = value
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", deg_to_rad(-96.0) if is_open else 0.0, 0.55)
	tween.tween_callback(func(): _busy = false)
	if is_open:
		opened.emit(self)
