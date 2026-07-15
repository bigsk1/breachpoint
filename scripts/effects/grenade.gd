class_name TacticalGrenade
extends RigidBody3D

var fuse := 2.2
var blast_radius := 5.5
var damage := 95.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius = 0.13; shape.shape = sphere; add_child(shape)
	var visual := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius = 0.13; mesh.height = 0.26
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("#263229"); mat.metallic = 0.7; mesh.material = mat; visual.mesh = mesh; add_child(visual)

func _physics_process(delta: float) -> void:
	fuse -= delta
	if fuse <= 0.0:
		explode()

func explode() -> void:
	GameManager.raise_alert(28.0, "Explosion reported")
	for body in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(body) or not body.has_method("take_damage"):
			continue
		var distance := global_position.distance_to(body.global_position)
		if distance <= blast_radius:
			body.take_damage(damage * (1.0 - distance / blast_radius * 0.65), false, self)
	var flash := OmniLight3D.new(); flash.light_color = Color("#ff9944"); flash.light_energy = 20.0; flash.omni_range = blast_radius * 2.0
	get_parent().add_child(flash); flash.global_position = global_position
	var tween := flash.create_tween(); tween.tween_property(flash, "light_energy", 0.0, 0.22); tween.tween_callback(flash.queue_free)
	queue_free()
