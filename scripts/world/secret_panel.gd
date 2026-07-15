class_name SecretPanel
extends AnimatableBody3D

signal revealed(panel: SecretPanel)

var display_name := "Hidden cache"
var required_weapon := "pipe_wrench"
var open_offset := Vector3(0.0, 3.2, 0.0)
var score_reward := 750
var opened := false
var _notice_cooldown := 0.0

func setup(size: Vector3, color: Color) -> void:
	collision_layer = 1
	collision_mask = 2 | 8
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = size
	collision.shape = shape; add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.metallic = 0.08; material.roughness = 0.9
	mesh.material = material; visual.mesh = mesh; add_child(visual)

func _process(delta: float) -> void:
	_notice_cooldown = maxf(0.0, _notice_cooldown - delta)

func take_damage(_amount: float, _headshot := false, source: Object = null) -> void:
	if opened:
		return
	var weapon_id := ""
	if source and source.has_method("get_current_weapon_id"):
		weapon_id = str(source.get_current_weapon_id())
	if not required_weapon.is_empty() and weapon_id != required_weapon:
		if _notice_cooldown <= 0.0:
			_notice_cooldown = 1.5
			GameManager.notification.emit("A hollow wall panel — a heavy wrench might shift it", "warn")
		return
	opened = true
	collision_layer = 0
	collision_mask = 0
	GameManager.add_score(score_reward, "Easter egg discovered: %s" % display_name)
	GameManager.notification.emit("SECRET FOUND — %s" % display_name.to_upper(), "good")
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", position + open_offset, 0.72)
	revealed.emit(self)
