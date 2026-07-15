class_name InventorySlotUI
extends PanelContainer

signal activated(index: int)

var inventory: InventorySystem
var slot_index := 0
var hotbar := false
var _number: Label
var _title: Label
var _quantity: Label
var _focused := false

func setup(source: InventorySystem, index: int, is_hotbar := false) -> void:
	inventory = source; slot_index = index; hotbar = is_hotbar
	custom_minimum_size = Vector2(76, 76)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var stack := VBoxContainer.new(); stack.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(stack)
	_number = Label.new(); _number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _number.add_theme_font_size_override("font_size", 11); _number.mouse_filter = Control.MOUSE_FILTER_IGNORE; stack.add_child(_number)
	_title = Label.new(); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; _title.size_flags_vertical = Control.SIZE_EXPAND_FILL; _title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _title.add_theme_font_size_override("font_size", 12); _title.mouse_filter = Control.MOUSE_FILTER_IGNORE; stack.add_child(_title)
	_quantity = Label.new(); _quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _quantity.add_theme_font_size_override("font_size", 12); _quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE; stack.add_child(_quantity)
	gui_input.connect(_on_gui_input)
	focus_entered.connect(func(): _focused = true; refresh())
	focus_exited.connect(func(): _focused = false; refresh())
	refresh()

func refresh() -> void:
	if not inventory or slot_index >= inventory.slots.size(): return
	var item: Dictionary = inventory.slots[slot_index]
	var base_color := Color("#20272d")
	if item.is_empty():
		_title.text = ""
		_quantity.text = ""
	else:
		_title.text = str(item.get("title", item.get("id", "ITEM"))).to_upper()
		_quantity.text = "×%d" % int(item.get("quantity", 1)) if int(item.get("quantity", 1)) > 1 else ""
		base_color = item.get("color", Color.WHITE).lerp(Color("#171d21"), 0.72)
	_number.text = ("▶ %d ◀" % (slot_index + 1) if hotbar else "▶ SELECT ◀") if _focused else (str(slot_index + 1) if hotbar else "")
	_number.modulate = Color("#fff200") if _focused else Color("#8d9aa2")
	_title.add_theme_color_override("font_color", Color.WHITE if _focused else Color("#e6edf0"))
	_quantity.add_theme_color_override("font_color", Color("#fff200") if _focused else Color("#e6edf0"))
	var fill := base_color.lightened(0.38) if _focused else base_color
	var border := Color("#fff200") if _focused else Color("#40505a")
	add_theme_stylebox_override("panel", _panel_style(fill, border, 5 if _focused else 1))
	z_index = 5 if _focused else 0

func _panel_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

func activate() -> void:
	activated.emit(slot_index)

func _on_gui_input(event: InputEvent) -> void:
	var mouse_accept: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var physical_controller_accept: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed
	if mouse_accept or physical_controller_accept or event.is_action_pressed("ui_accept"):
		activate()
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not inventory or inventory.slots[slot_index].is_empty(): return null
	var preview := Label.new(); preview.text = str(inventory.slots[slot_index].get("title", "ITEM")); preview.add_theme_color_override("font_color", Color("#f2d58a")); set_drag_preview(preview)
	return {"inventory": inventory, "slot": slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("inventory") == inventory and int(data.get("slot", -1)) != slot_index

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	inventory.move_slot(int(data.slot), slot_index)
