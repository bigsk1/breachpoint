class_name PawnBroker
extends StaticBody3D

signal transaction_completed(payout: int)

var display_name := "Artifact appraisal counter"
var _label: Label3D

func setup() -> void:
	collision_layer = 4
	collision_mask = 8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(5.4, 1.15, 1.2)
	collision.shape = shape; collision.position.y = 0.58; add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(5.4, 1.15, 1.2)
	var material := StandardMaterial3D.new(); material.albedo_color = Color("#5b402b"); material.roughness = 0.68
	mesh.material = material; visual.mesh = mesh; visual.position.y = 0.58; add_child(visual)
	_label = Label3D.new(); _label.font_size = 25; _label.outline_size = 9; _label.position = Vector3(0, 1.55, 0.0); _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _label.no_depth_test = true; add_child(_label)
	_refresh_label()

func get_interaction_text(_player: Node) -> String:
	var totals := GameManager.get_artifact_totals()
	if int(totals.count) <= 0:
		return "APPRAISAL COUNTER — NO STORED ARTIFACTS"
	return "HOLD TO SELL  %d ARTIFACTS FOR $%d CASH" % [int(totals.count), int(totals.value)]

func interact(_player: Node) -> void:
	var totals := GameManager.get_artifact_totals()
	if int(totals.count) <= 0:
		GameManager.notification.emit("No extracted artifacts stored — bring valuables back from another operation", "warn")
		transaction_completed.emit(0)
		return
	var payout := GameManager.sell_all_artifacts()
	_refresh_label()
	transaction_completed.emit(payout)

func _refresh_label() -> void:
	var totals := GameManager.get_artifact_totals()
	_label.text = "ARTIFACT APPRAISAL\n%d ITEMS  •  %d CASH" % [int(totals.count), int(totals.value)]
