class_name ObjectiveStation
extends StaticBody3D

signal activated(station: ObjectiveStation)

var display_name := "Objective"
var action_text := "HOLD TO USE"
var completion_text := "COMPLETE"
var items: Array[Dictionary] = []
var required_item_id := ""
var required_quantity := 0
var requirement_text := ""
var score_reward := 0
var alert_amount := 0.0
var notification_text := "Objective complete"
var used := false
var _label: Label3D

func setup(size: Vector3, color: Color) -> void:
	collision_layer = 4
	collision_mask = 8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.42
	material.roughness = 0.38
	mesh.material = material
	visual.mesh = mesh
	add_child(visual)
	_label = Label3D.new()
	_label.text = "◆"
	_label.font_size = 42
	_label.modulate = Color("#f3c45f")
	_label.position.y = size.y * 0.8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

func get_interaction_text(_player: Node) -> String:
	if used:
		return completion_text
	return "%s  %s" % [action_text, display_name.to_upper()]

func interact(player: Node) -> void:
	if used:
		return
	var inventory: InventorySystem = player.get_inventory()
	if not required_item_id.is_empty() and inventory.count_item(required_item_id) < required_quantity:
		var message := requirement_text
		if message.is_empty():
			message = "Requires %d x %s" % [required_quantity, required_item_id.replace("_", " ")]
		GameManager.notification.emit(message, "warn")
		return
	var succeeded := items.is_empty()
	for item in items:
		succeeded = player.add_loot(item) or succeeded
	if not succeeded:
		GameManager.notification.emit("Make room in your inventory", "warn")
		return
	if not required_item_id.is_empty():
		inventory.remove_item(required_item_id, required_quantity)
	used = true
	_label.text = ""
	if score_reward != 0:
		GameManager.add_score(score_reward, display_name)
	if alert_amount > 0.0:
		GameManager.raise_alert(alert_amount, notification_text)
	else:
		GameManager.notification.emit(notification_text, "good")
	activated.emit(self)
