class_name InventorySystem
extends RefCounted

signal changed
signal capacity_reached

const COLUMNS := 9
const ROWS := 3
const SLOT_COUNT := COLUMNS * ROWS

var slots: Array[Dictionary] = []
var max_weight := 24.0

func _init() -> void:
	for _i in SLOT_COUNT:
		slots.append({})

func current_weight() -> float:
	var total := 0.0
	for slot in slots:
		if not slot.is_empty():
			total += float(slot.get("weight", 0.0)) * int(slot.get("quantity", 1))
	return total

func add_item(item: Dictionary) -> int:
	var incoming := item.duplicate(true)
	var remaining := int(incoming.get("quantity", 1))
	var unit_weight := float(incoming.get("weight", 0.0))
	var by_weight := floori(maxf(0.0, max_weight - current_weight()) / maxf(unit_weight, 0.001))
	remaining = mini(remaining, by_weight)
	if remaining <= 0:
		capacity_reached.emit()
		return int(item.get("quantity", 1))

	if bool(incoming.get("stackable", false)):
		for slot in slots:
			if slot.get("id", "") == incoming.get("id", ""):
				var room := int(slot.get("max_stack", 99)) - int(slot.get("quantity", 0))
				var moved := mini(room, remaining)
				slot["quantity"] = int(slot.get("quantity", 0)) + moved
				remaining -= moved
				if remaining <= 0:
					changed.emit()
					return 0

	for i in slots.size():
		if slots[i].is_empty():
			var max_stack := int(incoming.get("max_stack", 1))
			var moved := mini(remaining, max_stack)
			incoming["quantity"] = moved
			slots[i] = incoming.duplicate(true)
			remaining -= moved
			if remaining <= 0:
				changed.emit()
				return 0
	changed.emit()
	return remaining

func remove_item(item_id: String, quantity := 1) -> int:
	var remaining := quantity
	for i in slots.size():
		if slots[i].get("id", "") != item_id:
			continue
		var taken := mini(remaining, int(slots[i].get("quantity", 1)))
		slots[i]["quantity"] = int(slots[i].get("quantity", 1)) - taken
		remaining -= taken
		if int(slots[i].get("quantity", 0)) <= 0:
			slots[i] = {}
		if remaining <= 0:
			break
	changed.emit()
	return quantity - remaining

func count_item(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot.get("id", "") == item_id:
			total += int(slot.get("quantity", 1))
	return total

func move_slot(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= SLOT_COUNT or to_index < 0 or to_index >= SLOT_COUNT or from_index == to_index:
		return
	var source := slots[from_index]
	var target := slots[to_index]
	if not source.is_empty() and source.get("id", "") == target.get("id", "") and bool(source.get("stackable", false)):
		var room := int(target.get("max_stack", 99)) - int(target.get("quantity", 0))
		var moved := mini(room, int(source.get("quantity", 0)))
		target["quantity"] = int(target.get("quantity", 0)) + moved
		source["quantity"] = int(source.get("quantity", 0)) - moved
		if int(source.get("quantity", 0)) <= 0:
			source = {}
		slots[from_index] = source
		slots[to_index] = target
	else:
		slots[from_index] = target
		slots[to_index] = source
	changed.emit()

func use_slot(index: int, user: Node) -> bool:
	if index < 0 or index >= SLOT_COUNT or slots[index].is_empty():
		return false
	var item := slots[index]
	match item.get("id", ""):
		"medkit":
			if user.has_method("heal") and user.heal(45):
				remove_item("medkit", 1); return true
		"armor_plate":
			if user.has_method("restore_armor") and user.restore_armor(35):
				remove_item("armor_plate", 1); return true
		"snack":
			if user.has_method("heal") and user.heal(18):
				remove_item("snack", 1); return true
		"soda":
			if user.has_method("heal") and user.heal(10):
				remove_item("soda", 1); return true
	return false

static func item(id: String, title: String, kind: String, quantity := 1, weight := 0.1, stackable := true, max_stack := 99, color := Color.WHITE) -> Dictionary:
	return {
		"id": id, "title": title, "kind": kind, "quantity": quantity,
		"weight": weight, "stackable": stackable, "max_stack": max_stack, "color": color,
	}

static func ammo_item(ammo_id: String, quantity: int) -> Dictionary:
	var title := "Standard Ammunition"
	var weight := 0.015
	var max_stack := 180
	var color := Color("#d8ad5b")
	var compatible_weapons: Array[String] = []
	match ammo_id:
		"shells":
			title = "12-Gauge Shells"
			weight = 0.04
			max_stack = 48
			color = Color("#b84f43")
			compatible_weapons = ["shotgun"]
		"rockets":
			title = "Launcher Rockets"
			weight = 1.2
			max_stack = 6
			color = Color("#77834f")
			compatible_weapons = ["bazooka"]
		"fuel_cell":
			title = "Flamethrower Fuel"
			weight = 0.015
			max_stack = 240
			color = Color("#e07c3e")
			compatible_weapons = ["flamethrower"]
		_:
			compatible_weapons = ["sidearm", "carbine", "smg", "marksman"]

	var result := item(ammo_id, title, "ammo", quantity, weight, true, max_stack, color)
	result["compatible_weapons"] = compatible_weapons
	return result

static func artifact(id: String, title: String, sell_value: int, weight := 1.0, color := Color("#d8b85a")) -> Dictionary:
	var result := item(id, title, "artifact", 1, weight, false, 1, color)
	result["sell_value"] = sell_value
	return result
