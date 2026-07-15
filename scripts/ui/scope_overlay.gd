class_name ScopeOverlay
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func _draw() -> void:
	var center := size * 0.5
	var radius := 112.0
	draw_arc(center, radius + 8.0, 0.0, TAU, 96, Color(0.01, 0.015, 0.02, 0.82), 18.0, true)
	draw_arc(center, radius, 0.0, TAU, 96, Color("#82949c"), 2.5, true)
	draw_arc(center, radius - 5.0, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.58), 3.0, true)
	draw_line(center + Vector2(-radius, 0), center + Vector2(-24, 0), Color(0.05, 0.07, 0.08, 0.9), 2.0, true)
	draw_line(center + Vector2(24, 0), center + Vector2(radius, 0), Color(0.05, 0.07, 0.08, 0.9), 2.0, true)
	draw_line(center + Vector2(0, -radius), center + Vector2(0, -24), Color(0.05, 0.07, 0.08, 0.9), 2.0, true)
	draw_line(center + Vector2(0, 24), center + Vector2(0, radius), Color(0.05, 0.07, 0.08, 0.9), 2.0, true)
	draw_circle(center, 2.5, Color("#d9b45d"))

func set_aiming(active: bool) -> void:
	visible = active
	if active:
		queue_redraw()
