class_name LootContainer
extends StaticBody3D

var display_name := "Supply Case"
var items: Array[Dictionary] = []
var opened := false
var _label: Label3D

func setup(size: Vector3, color: Color) -> void:
	collision_layer = 4; collision_mask = 8
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = size; collision.shape = shape; add_child(collision)
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.metallic = 0.3; mat.roughness = 0.5; mesh.material = mat; visual.mesh = mesh; add_child(visual)
	_label = Label3D.new(); _label.text = "◆"; _label.font_size = 42; _label.modulate = Color("#e7c46d"); _label.position.y = size.y * 0.75; _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; _label.no_depth_test = true; add_child(_label)

func get_interaction_text(_player: Node) -> String:
	return "EMPTY" if opened else "HOLD TO SEARCH  %s" % display_name.to_upper()

func interact(player: Node) -> void:
	if opened: return
	var anything := false
	for item in items:
		anything = player.add_loot(item) or anything
	if anything:
		opened = true; _label.text = ""; GameManager.notification.emit("Container cleared", "good")
	else:
		GameManager.notification.emit("Make room in your inventory", "warn")
