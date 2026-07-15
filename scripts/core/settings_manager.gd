extends Node

const SAVE_PATHS := preload("res://scripts/core/save_paths.gd")

signal settings_changed
signal bindings_changed

const SAVE_FILE := "breachpoint_settings.cfg"

var values := {
	"mouse_sensitivity": 0.11,
	"controller_sensitivity": 2.4,
	"master_volume": 0.8,
	"sfx_volume": 0.9,
	"music_enabled": true,
	"music_volume": 0.75,
	"fullscreen": false,
	"subtitles": true,
	"reduced_motion": false,
	"high_contrast": false,
	"toggle_crouch": true,
	"difficulty": "easy",
	"selected_map": "bank",
	"fov": 82.0,
}

var _defaults: Dictionary
var _custom_bindings := {}
var _settings_path := ""

func _ready() -> void:
	_settings_path = SAVE_PATHS.resolve_file(SAVE_FILE)
	_defaults = values.duplicate(true)
	_install_default_actions()
	_load_settings()
	_apply_settings()

func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)

func set_value(key: String, value: Variant, persist := true) -> void:
	values[key] = value
	_apply_settings()
	settings_changed.emit()
	if persist:
		save_settings()

func get_settings_path() -> String:
	return _settings_path

func reset_to_defaults() -> void:
	values = _defaults.duplicate(true)
	_custom_bindings.clear()
	_install_default_actions(true)
	_apply_settings()
	save_settings()
	settings_changed.emit()
	bindings_changed.emit()

func _action(action: StringName, deadzone := 0.25) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)

func _key(action: StringName, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action, event)

func _mouse(action: StringName, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _joy_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func _ensure_key(action: StringName, code: Key) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing.physical_keycode == code or existing.keycode == code):
			return
	_key(action, code)

func _ensure_joy_button(action: StringName, button: JoyButton) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button:
			return
	_joy_button(action, button)

func _ensure_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and existing.axis == axis and is_equal_approx(existing.axis_value, value):
			return
	_joy_axis(action, axis, value)

func _install_default_actions(clear_existing := false) -> void:
	var actions := [
		"move_forward", "move_back", "move_left", "move_right", "look_left", "look_right",
		"look_up", "look_down", "jump", "crouch", "sprint", "fire", "ads", "reload",
		"interact", "inventory", "pause", "grenade", "melee", "flashlight",
		"weapon_next", "weapon_prev", "quick_left", "quick_right",
		"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
		"slot_1", "slot_2", "slot_3", "slot_4", "slot_5", "slot_6", "slot_7", "slot_8", "slot_9"
	]
	for action in actions:
		_action(action)
		if clear_existing and not str(action).begins_with("ui_"):
			InputMap.action_erase_events(action)

	if InputMap.action_get_events("move_forward").is_empty():
		_key("move_forward", KEY_W); _joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
		_key("move_back", KEY_S); _joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
		_key("move_left", KEY_A); _joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
		_key("move_right", KEY_D); _joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
		_joy_axis("look_left", JOY_AXIS_RIGHT_X, -1.0); _joy_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
		_joy_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0); _joy_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
		_key("jump", KEY_SPACE); _joy_button("jump", JOY_BUTTON_A)
		_key("crouch", KEY_CTRL); _key("crouch", KEY_C); _joy_button("crouch", JOY_BUTTON_B)
		_key("sprint", KEY_SHIFT); _joy_button("sprint", JOY_BUTTON_LEFT_STICK)
		_mouse("fire", MOUSE_BUTTON_LEFT); _joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
		_mouse("ads", MOUSE_BUTTON_RIGHT); _joy_axis("ads", JOY_AXIS_TRIGGER_LEFT, 1.0)
		_key("reload", KEY_R); _joy_button("reload", JOY_BUTTON_X)
		_key("interact", KEY_E); _joy_button("interact", JOY_BUTTON_Y)
		_key("inventory", KEY_TAB); _joy_button("inventory", JOY_BUTTON_BACK)
		_key("pause", KEY_ESCAPE); _joy_button("pause", JOY_BUTTON_START)
		_key("grenade", KEY_G); _joy_button("grenade", JOY_BUTTON_LEFT_SHOULDER)
		_key("melee", KEY_V); _joy_button("melee", JOY_BUTTON_RIGHT_SHOULDER)
		_key("flashlight", KEY_F); _joy_button("flashlight", JOY_BUTTON_DPAD_UP)
		_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN); _joy_button("weapon_next", JOY_BUTTON_DPAD_RIGHT)
		_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP); _joy_button("weapon_prev", JOY_BUTTON_DPAD_LEFT)
		_joy_button("quick_left", JOY_BUTTON_DPAD_LEFT); _joy_button("quick_right", JOY_BUTTON_DPAD_RIGHT)
		for i in range(1, 10):
			_key("slot_%d" % i, KEY_0 + i)

	# Exported builds now have a guaranteed, controller-complete menu input map.
	_ensure_key("ui_accept", KEY_ENTER)
	_ensure_key("ui_accept", KEY_SPACE)
	_ensure_key("ui_cancel", KEY_ESCAPE)
	_ensure_key("ui_up", KEY_UP)
	_ensure_key("ui_down", KEY_DOWN)
	_ensure_key("ui_left", KEY_LEFT)
	_ensure_key("ui_right", KEY_RIGHT)
	_ensure_joy_button("ui_accept", JOY_BUTTON_A)
	_ensure_joy_button("ui_cancel", JOY_BUTTON_B)
	_ensure_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)

func rebind_action(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	_erase_device_family(action, event)
	InputMap.action_add_event(action, event)
	_custom_bindings[action] = event_to_dict(event)
	save_settings()
	bindings_changed.emit()

func get_binding_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "UNBOUND"
	for event in events:
		if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			return event.as_text().trim_suffix(" (Physical)")
	return events[0].as_text().trim_suffix(" (Physical)")

func _erase_device_family(action: StringName, replacement: InputEvent) -> void:
	var replacing_controller := replacement is InputEventJoypadButton or replacement is InputEventJoypadMotion
	for existing in InputMap.action_get_events(action):
		var existing_controller := existing is InputEventJoypadButton or existing is InputEventJoypadMotion
		if replacing_controller == existing_controller:
			InputMap.action_erase_event(action, existing)

func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical_keycode": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button_index": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button_index": event.button_index}
	return {}

func dict_to_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var event := InputEventKey.new(); event.physical_keycode = int(data.get("physical_keycode", 0)); return event
		"mouse":
			var event := InputEventMouseButton.new(); event.button_index = int(data.get("button_index", 1)); return event
		"joy_button":
			var event := InputEventJoypadButton.new(); event.button_index = int(data.get("button_index", 0)); return event
	return InputEventAction.new()

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings", key, values[key])
	for action in _custom_bindings:
		config.set_value("bindings", action, _custom_bindings[action])
	var result := config.save(_settings_path)
	if result != OK:
		push_warning("Could not save settings: %s" % error_string(result))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(_settings_path) != OK:
		return
	for key in values:
		values[key] = config.get_value("settings", key, values[key])
	if config.has_section("bindings"):
		for action in config.get_section_keys("bindings"):
			var data: Dictionary = config.get_value("bindings", action, {})
			var event := dict_to_event(data)
			if not data.is_empty():
				_erase_device_family(action, event)
				InputMap.action_add_event(action, event)
				_custom_bindings[action] = data

func _apply_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var music_bus := AudioServer.get_bus_index("Music")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(float(values.master_volume)))
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(float(values.sfx_volume)))
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, not bool(values.music_enabled))
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(float(values.music_volume)))
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
