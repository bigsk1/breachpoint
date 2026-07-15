class_name ArtifactPickup
extends StaticBody3D

var artifact_id := ""
var display_name := "Artifact"
var sell_value := 500
var weight := 1.0
var artifact_color := Color("#d8b85a")
var visual_target: Node
var collected := false
var _label: Label3D

func setup(id: String, title: String, value: int, weight_value: float, color: Color) -> void:
	artifact_id = id
	display_name = title
	sell_value = value
	weight = weight_value
	artifact_color = color
	collision_layer = 4
	collision_mask = 8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(1.45, 1.9, 1.45)
	collision.shape = shape
	collision.position.y = 0.25
	add_child(collision)
	_label = Label3D.new()
	_label.text = "◇"
	_label.font_size = 38
	_label.modulate = Color("#f1ca62")
	_label.position.y = 1.25
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	add_child(_label)

func get_interaction_text(_player: Node) -> String:
	return "COLLECTED" if collected else "HOLD TO TAKE  %s  [VALUE %d]" % [display_name.to_upper(), sell_value]

func interact(player: Node) -> void:
	if collected:
		return
	var item := InventorySystem.artifact(artifact_id, display_name, sell_value, weight, artifact_color)
	if not player.add_loot(item):
		GameManager.notification.emit("Make room for the artifact", "warn")
		return
	collected = true
	collision_layer = 0
	if is_instance_valid(visual_target):
		visual_target.queue_free()
	GameManager.notification.emit("%s secured — extract it before visiting the pawn shop" % display_name, "good")
	queue_free()
