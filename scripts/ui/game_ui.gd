class_name GameUI
extends CanvasLayer

const SAVE_PATHS := preload("res://scripts/core/save_paths.gd")

signal deploy_requested(map_id: String, difficulty_id: String)
signal resume_requested
signal quit_to_menu_requested

const C_BG := Color("#0b1014")
const C_PANEL := Color("#141c21e8")
const C_LINE := Color("#40505a")
const C_TEXT := Color("#e6edf0")
const C_MUTED := Color("#8999a2")
const C_GOLD := Color("#d2ad61")
const C_RED := Color("#d24b49")
const C_BLUE := Color("#58a8c2")

var player: PlayerController
var inventory_open := false
var pause_open := false

var _root: Control
var _menu: Control
var _hud: Control
var _pause: Control
var _inventory_panel: Control
var _settings: Control
var _upgrades: Control
var _shop: Control
var _report: Control
var _reset_confirm: ConfirmationDialog
var _objective: Label
var _score: Label
var _cash: Label
var _alert_label: Label
var _alert_bar: ProgressBar
var _health_bar: ProgressBar
var _armor_bar: ProgressBar
var _ammo: Label
var _weapon_name: Label
var _interaction: Label
var _interaction_bar: ProgressBar
var _notification: Label
var _crosshair: Label
var _damage_feedback: Label
var _hotbar: HBoxContainer
var _inventory_grid: GridContainer
var _inventory_close_button: Button
var _weight: Label
var _civilian_warning: Label
var _upgrade_funds: Label
var _shop_funds: Label
var _scope_overlay: ScopeOverlay
var _remap_target := ""
var _remap_button: Button
var _notification_tween: Tween
var _hit_tween: Tween
var _progression_refresh_queued := false
var _map_select: OptionButton
var _difficulty_select: OptionButton
var _mission_brief: Label

func _ready() -> void:
	layer = 20
	_build_theme()
	_build_main_menu()
	_build_hud()
	_build_pause()
	_build_inventory()
	_build_settings()
	_build_upgrades()
	_build_shop()
	_build_report()
	_connect_global_signals()
	SettingsManager.settings_changed.connect(_apply_accessibility)
	_apply_accessibility()
	show_main_menu()

func bind_player(value: PlayerController) -> void:
	player = value
	player.health_changed.connect(_on_health_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.interaction_changed.connect(_on_interaction_changed)
	player.inventory_changed.connect(func(_inv): _refresh_inventory_contents())
	player.hit_marker.connect(_on_hit_marker)
	player.ads_changed.connect(_on_ads_changed)
	player.emit_status()
	_refresh_inventory()

func _unhandled_input(event: InputEvent) -> void:
	if not _remap_target.is_empty():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if event.is_pressed():
				SettingsManager.rebind_action(_remap_target, event)
				_remap_button.text = SettingsManager.get_binding_text(_remap_target)
				_remap_target = ""; _remap_button = null
				get_viewport().set_input_as_handled()
		return
	if inventory_open and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and event.pressed:
		if _activate_focused_inventory_slot():
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") and _close_controller_overlay():
		get_viewport().set_input_as_handled()
		return
	if not GameManager.run_active: return
	if event.is_action_pressed("inventory") and not pause_open:
		set_inventory_open(not inventory_open); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if inventory_open: set_inventory_open(false)
		else: set_pause_open(not pause_open)
		get_viewport().set_input_as_handled()

func _activate_focused_inventory_slot() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is InventorySlotUI:
		(focused as InventorySlotUI).activate()
		return true
	return false

func _close_controller_overlay() -> bool:
	if _report.visible:
		quit_to_menu_requested.emit()
		return true
	if _settings.visible:
		_settings.hide()
		_focus_first_button(_pause if pause_open else _menu)
		return true
	if _upgrades.visible:
		_upgrades.hide()
		_focus_first_button(_menu)
		return true
	if _shop.visible:
		_shop.hide()
		_focus_first_button(_menu)
		return true
	if inventory_open:
		set_inventory_open(false)
		return true
	if pause_open:
		set_pause_open(false)
		resume_requested.emit()
		return true
	return false

func _build_theme() -> void:
	_root = Control.new(); _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_root)
	var theme := Theme.new(); theme.default_font = load("res://fonts/lilita_one_regular.ttf"); theme.default_font_size = 18
	var button_normal := _style(Color("#1a252b"), C_LINE, 5, 1)
	var button_hover := _style(Color("#263840"), C_GOLD, 5, 1)
	var button_pressed := _style(Color("#31444a"), C_GOLD, 5, 2)
	theme.set_stylebox("normal", "Button", button_normal); theme.set_stylebox("hover", "Button", button_hover); theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_color("font_color", "Button", C_TEXT); theme.set_color("font_hover_color", "Button", Color.WHITE); theme.set_font_size("font_size", "Button", 18)
	theme.set_stylebox("panel", "Panel", _style(C_PANEL, C_LINE, 8, 1)); theme.set_color("font_color", "Label", C_TEXT)
	_root.theme = theme

func _build_main_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_menu)
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color("#1f363f")
	stripe.position = Vector2(0, 0)
	stripe.size = Vector2(180, 900)
	_menu.add_child(stripe)
	var accent := ColorRect.new()
	accent.color = C_GOLD
	accent.position = Vector2(180, 0)
	accent.size = Vector2(5, 900)
	_menu.add_child(accent)
	var content := VBoxContainer.new()
	content.position = Vector2(260, 62)
	content.size = Vector2(700, 790)
	content.add_theme_constant_override("separation", 10)
	_menu.add_child(content)
	var eyebrow := Label.new()
	eyebrow.text = "BREACHPOINT // OPERATIONS BOARD"
	eyebrow.modulate = C_GOLD
	eyebrow.add_theme_font_size_override("font_size", 18)
	content.add_child(eyebrow)
	var title := Label.new()
	title.text = "ZERO HOUR"
	title.add_theme_font_size_override("font_size", 62)
	content.add_child(title)
	var line := HSeparator.new()
	line.custom_minimum_size.y = 12
	content.add_child(line)
	_map_select = OptionButton.new()
	_map_select.add_item("MESA BANK & TRUST — BANK")
	_map_select.add_item("ROUTE 17 FUEL & SERVICE— GAS STATION")
	_map_select.add_item("MESA GRAND MUSEUM - ARTIFACT HEIST")
	_map_select.add_item("MESA EXCHANGE - PAWN & LOAN")
	_map_select.add_item("BLACKTIDE ISLAND — ENDLESS UNDEAD")
	_map_select.custom_minimum_size = Vector2(430, 46)
	var stored_map := str(SettingsManager.get_value("selected_map", "bank"))
	var map_ids := ["bank", "gas_station", "museum", "pawn_shop", "zombie_island"]
	_map_select.select(map_ids.find(stored_map) if stored_map in map_ids else 0)
	content.add_child(_selector_row("MISSION", _map_select))
	_difficulty_select = OptionButton.new()
	_difficulty_select.add_item("EASY — MORE ARMOR, SLOWER RESPONSE")
	_difficulty_select.add_item("MEDIUM — STANDARD OPERATION")
	_difficulty_select.add_item("HARD — AGGRESSIVE RESPONSE, HIGH REWARDS")
	_difficulty_select.custom_minimum_size = Vector2(430, 46)
	var stored_difficulty := str(SettingsManager.get_value("difficulty", "easy"))
	_difficulty_select.select(["easy", "medium", "hard"].find(stored_difficulty) if stored_difficulty in ["easy", "medium", "hard"] else 0)
	content.add_child(_selector_row("DIFFICULTY", _difficulty_select))
	_mission_brief = Label.new()
	_mission_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_brief.custom_minimum_size = Vector2(650, 72)
	_mission_brief.modulate = C_MUTED
	_mission_brief.add_theme_font_size_override("font_size", 16)
	content.add_child(_mission_brief)
	_map_select.item_selected.connect(func(_index): _remember_selection(); _update_mission_brief())
	_difficulty_select.item_selected.connect(func(_index): _remember_selection(); _update_mission_brief())
	_update_mission_brief()
	content.add_child(_menu_button("DEPLOY SELECTED OPERATION", _deploy_selected))
	content.add_child(_menu_button("LOADOUT & UPGRADES", func(): _show_overlay(_upgrades)))
	content.add_child(_menu_button("WEAPON SHOP", func(): _show_overlay(_shop)))
	content.add_child(_menu_button("SETTINGS & CONTROLS", func(): _show_overlay(_settings)))
	content.add_child(_menu_button("QUIT", func(): get_tree().quit()))
	var footer := Label.new()
	footer.text = "5 PLAYABLE MISSIONS  •  3 DIFFICULTIES •  KEYBOARD, MOUSE & CONTROLLER"
	footer.modulate = Color("#56666e")
	footer.position = Vector2(260, 860)
	_menu.add_child(footer)

func _selector_row(title_text: String, selector: OptionButton) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title_text
	label.modulate = C_GOLD
	label.custom_minimum_size.x = 150
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(selector)
	return row

func _selected_map_id() -> String:
	if not _map_select:
		return "bank"
	match _map_select.selected:
		1: return "gas_station"
		2: return "museum"
		3: return "pawn_shop"
		4: return "zombie_island"
		_: return "bank"

func _selected_difficulty_id() -> String:
	if not _difficulty_select:
		return "easy"
	return ["easy", "medium", "hard"][_difficulty_select.selected]

func _remember_selection() -> void:
	SettingsManager.set_value("selected_map", _selected_map_id(), false)
	SettingsManager.set_value("difficulty", _selected_difficulty_id())

func _update_mission_brief() -> void:
	if not _mission_brief:
		return
	match _selected_map_id():
		"gas_station":
			_mission_brief.text = "GETAWAY RUN — Search a randomized hiding place, break the reinforced service-key lockbox with fists or a pipe wrench, empty the register, then start the garage car and drive away."
		"museum":
			_mission_brief.text = "ARTIFACT HEIST — Explore Mesa Grand Museum's looping galleries and dead-end archive, steal the Golden Sun Disk, and uncover hidden rooms."
		"pawn_shop":
			_mission_brief.text = "MESA EXCHANGE — Sell extracted artifacts for persistent cash. Pawnkeepers stay neutral unless attacked; browse the displays, find the hidden property room, or risk the register."
		"zombie_island":
			_mission_brief.text = "ENDLESS UNDEAD — Roam an open moonlit island, use ruins and huts for cover, raid supply caches, and survive escalating waves of zombies and skeletons. No extraction timer."
		_:
			_mission_brief.text = "BANK HEIST — Enter Mesa Bank & Trust, secure the management keycard, breach the vault, take cash, and extract through the lobby."
	_mission_brief.text += "\nSelected: %s difficulty." % _selected_difficulty_id().to_upper()

func _deploy_selected() -> void:
	_remember_selection()
	deploy_requested.emit(_selected_map_id(), _selected_difficulty_id())

func _build_hud() -> void:
	_hud = Control.new(); _hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; _root.add_child(_hud)
	var top := Panel.new(); top.position = Vector2(40, 34); top.size = Vector2(690, 92); top.mouse_filter = Control.MOUSE_FILTER_IGNORE; _hud.add_child(top)
	var objective_tag := Label.new(); objective_tag.text = "CURRENT OBJECTIVE"; objective_tag.modulate = C_GOLD; objective_tag.position = Vector2(18, 12); objective_tag.add_theme_font_size_override("font_size", 14); top.add_child(objective_tag)
	_objective = Label.new(); _objective.text = "Enter the bank"; _objective.position = Vector2(18, 38); _objective.size = Vector2(650, 44); _objective.add_theme_font_size_override("font_size", 21); top.add_child(_objective)
	_cash = Label.new(); _cash.position = Vector2(1260, 12); _cash.size = Vector2(290, 26); _cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _cash.add_theme_font_size_override("font_size", 18); _cash.modulate = C_GOLD; _hud.add_child(_cash)
	_score = Label.new(); _score.position = Vector2(1330, 40); _score.size = Vector2(220, 40); _score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _score.add_theme_font_size_override("font_size", 26); _score.text = "000000 PTS"; _hud.add_child(_score)
	_update_cash_display()
	_alert_label = Label.new(); _alert_label.position = Vector2(1260, 86); _alert_label.size = Vector2(290, 25); _alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _alert_label.modulate = C_MUTED; _hud.add_child(_alert_label)
	_alert_bar = ProgressBar.new(); _alert_bar.position = Vector2(1260, 116); _alert_bar.size = Vector2(290, 9); _alert_bar.show_percentage = false; _alert_bar.max_value = 100; _hud.add_child(_alert_bar)
	_crosshair = Label.new(); _crosshair.text = "+"; _crosshair.add_theme_font_size_override("font_size", 28); _crosshair.position = Vector2(790, 430); _crosshair.size = Vector2(40,40); _crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _crosshair.modulate = Color(1,1,1,0.72); _hud.add_child(_crosshair)
	_damage_feedback = Label.new(); _damage_feedback.position = Vector2(700, 472); _damage_feedback.size = Vector2(220, 34); _damage_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _damage_feedback.add_theme_font_size_override("font_size", 18); _damage_feedback.modulate = Color(1,1,1,0); _hud.add_child(_damage_feedback)
	var vitals := Panel.new(); vitals.position = Vector2(40, 750); vitals.size = Vector2(310, 112); _hud.add_child(vitals)
	var hlabel := Label.new(); hlabel.text = "HEALTH"; hlabel.position = Vector2(16,14); hlabel.modulate = C_MUTED; vitals.add_child(hlabel)
	_health_bar = ProgressBar.new(); _health_bar.position = Vector2(92,18); _health_bar.size = Vector2(195,12); _health_bar.max_value = 100; _health_bar.value = 100; _health_bar.show_percentage = false; vitals.add_child(_health_bar)
	var alabel := Label.new(); alabel.text = "ARMOR"; alabel.position = Vector2(16,48); alabel.modulate = C_MUTED; vitals.add_child(alabel)
	_armor_bar = ProgressBar.new(); _armor_bar.position = Vector2(92,52); _armor_bar.size = Vector2(195,12); _armor_bar.max_value = 150; _armor_bar.value = 50; _armor_bar.show_percentage = false; vitals.add_child(_armor_bar)
	_civilian_warning = Label.new(); _civilian_warning.text = "ROE: PROTECT CIVILIANS"; _civilian_warning.position = Vector2(16,78); _civilian_warning.modulate = C_BLUE; _civilian_warning.add_theme_font_size_override("font_size", 14); vitals.add_child(_civilian_warning)
	var weapon_panel := Panel.new(); weapon_panel.position = Vector2(1220, 730); weapon_panel.size = Vector2(330, 132); _hud.add_child(weapon_panel)
	_weapon_name = Label.new(); _weapon_name.position = Vector2(18, 15); _weapon_name.size = Vector2(295, 28); _weapon_name.modulate = C_MUTED; _weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; weapon_panel.add_child(_weapon_name)
	_ammo = Label.new(); _ammo.position = Vector2(18, 42); _ammo.size = Vector2(295, 60); _ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _ammo.add_theme_font_size_override("font_size", 42); weapon_panel.add_child(_ammo)
	var hint := Label.new(); hint.text = "R  RELOAD   •   RMB  ADS"; hint.position = Vector2(18, 104); hint.size = Vector2(295,22); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hint.modulate = C_MUTED; hint.add_theme_font_size_override("font_size", 12); weapon_panel.add_child(hint)
	_hotbar = HBoxContainer.new(); _hotbar.position = Vector2(420, 800); _hotbar.size = Vector2(760, 74); _hotbar.add_theme_constant_override("separation", 5); _hud.add_child(_hotbar)
	_interaction = Label.new(); _interaction.position = Vector2(550, 660); _interaction.size = Vector2(500, 40); _interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _interaction.add_theme_font_size_override("font_size", 18); _hud.add_child(_interaction)
	_interaction_bar = ProgressBar.new(); _interaction_bar.position = Vector2(680, 704); _interaction_bar.size = Vector2(240, 7); _interaction_bar.max_value = 1.0; _interaction_bar.show_percentage = false; _hud.add_child(_interaction_bar)
	_notification = Label.new(); _notification.position = Vector2(500, 145); _notification.size = Vector2(600, 42); _notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _notification.add_theme_font_size_override("font_size", 19); _hud.add_child(_notification)
	_scope_overlay = ScopeOverlay.new()
	_hud.add_child(_scope_overlay)
	_hud.move_child(_scope_overlay, 0)

func _build_pause() -> void:
	_pause = _modal_panel("OPERATION PAUSED", Vector2(520, 190), Vector2(560, 500))
	var box := _pause.get_node("Panel/Content") as VBoxContainer
	box.add_child(_body_label("Take a breath. The world is frozen until you resume."))
	box.add_child(_menu_button("RESUME", func(): set_pause_open(false); resume_requested.emit()))
	box.add_child(_menu_button("SETTINGS", func(): _show_overlay(_settings)))
	box.add_child(_menu_button("RESTART OPERATION", func(): set_pause_open(false); deploy_requested.emit(GameManager.current_mission, GameManager.difficulty)))
	box.add_child(_menu_button("ABORT TO MAIN MENU", func(): set_pause_open(false); quit_to_menu_requested.emit()))

func _build_inventory() -> void:
	_inventory_panel = _modal_panel("FIELD INVENTORY", Vector2(275, 120), Vector2(1050, 680))
	var box := _inventory_panel.get_node("Panel/Content") as VBoxContainer
	var instructions := _body_label("Move with the D-pad or left stick. Press A / Cross to equip weapons or use consumables. Slots 1–9 are the hotbar."); instructions.modulate = C_MUTED; box.add_child(instructions)
	_weight = Label.new(); _weight.modulate = C_GOLD; box.add_child(_weight)
	_inventory_grid = GridContainer.new(); _inventory_grid.columns = 9; _inventory_grid.add_theme_constant_override("h_separation", 7); _inventory_grid.add_theme_constant_override("v_separation", 7); box.add_child(_inventory_grid)
	box.add_child(_body_label("CLEAN PLAY EARNS MORE. CASH AND GEAR ADD WEIGHT."))
	_inventory_close_button = _menu_button("CLOSE INVENTORY", func(): set_inventory_open(false))
	box.add_child(_inventory_close_button)

func _build_settings() -> void:
	_settings = _modal_panel("SETTINGS & CONTROLS", Vector2(280, 20), Vector2(1040, 860))
	var box := _settings.get_node("Panel/Content") as VBoxContainer
	box.add_theme_constant_override("separation", 7)
	var storage_mode := "PORTABLE USB FOLDER" if SAVE_PATHS.is_portable_path(GameManager.get_profile_path()) else "WINDOWS USER PROFILE"
	var storage_note := _body_label("PROFILE STORAGE — %s" % storage_mode)
	storage_note.modulate = C_BLUE
	box.add_child(storage_note)
	box.add_child(_slider_row("MOUSE SENSITIVITY", "mouse_sensitivity", 0.03, 0.35, 0.01))
	box.add_child(_slider_row("CONTROLLER LOOK", "controller_sensitivity", 0.8, 5.0, 0.1))
	box.add_child(_slider_row("FIELD OF VIEW", "fov", 65, 105, 1))
	box.add_child(_slider_row("MASTER VOLUME", "master_volume", 0, 1, 0.05))
	box.add_child(_check_row("BACKGROUND MUSIC", "music_enabled"))
	box.add_child(_slider_row("MUSIC VOLUME", "music_volume", 0, 1, 0.05))
	box.add_child(_check_row("SUBTITLES / AUDIO CUES", "subtitles"))
	box.add_child(_check_row("REDUCED CAMERA MOTION", "reduced_motion"))
	box.add_child(_check_row("HIGH-CONTRAST HUD", "high_contrast"))
	box.add_child(_check_row("EXCLUSIVE FULLSCREEN", "fullscreen"))
	box.add_child(_check_row("TOGGLE CROUCH", "toggle_crouch"))
	var remap_title := Label.new(); remap_title.text = "KEY BINDINGS— CLICK TO REMAP"; remap_title.modulate = C_GOLD; box.add_child(remap_title)
	var remap_grid := GridContainer.new(); remap_grid.columns = 4; remap_grid.add_theme_constant_override("h_separation", 10); remap_grid.add_theme_constant_override("v_separation", 8); box.add_child(remap_grid)
	for entry in [["Fire","fire"], ["Aim","ads"], ["Reload","reload"], ["Interact","interact"], ["Jump","jump"], ["Crouch","crouch"], ["Sprint","sprint"], ["Inventory","inventory"]]:
		var label := Label.new(); label.text = entry[0]; label.modulate = C_MUTED; remap_grid.add_child(label)
		var button := Button.new(); button.text = SettingsManager.get_binding_text(entry[1]); button.custom_minimum_size = Vector2(150,34); button.pressed.connect(_begin_remap.bind(entry[1], button)); remap_grid.add_child(button)
	var reset_note := _body_label("PROFILE MANAGEMENT — resetting removes cash, purchases, upgrades, loadouts, and stored artifacts.")
	reset_note.modulate = C_RED
	reset_note.custom_minimum_size.y = 28
	box.add_child(reset_note)
	box.add_child(_menu_button("RESET ALL PROGRESSION...", _request_profile_reset))
	box.add_child(_menu_button("BACK", func(): _settings.hide(); _focus_first_button(_pause if pause_open else _menu)))
	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.title = "RESET ALL PROGRESSION?"
	_reset_confirm.dialog_text = "This permanently resets cash, weapons, rank upgrades, loadouts, and stored artifacts. Settings and controls are kept.\n\nThis cannot be undone."
	_reset_confirm.ok_button_text = "RESET EVERYTHING"
	_reset_confirm.get_cancel_button().text = "KEEP MY PROFILE"
	_reset_confirm.confirmed.connect(_confirm_profile_reset)
	_root.add_child(_reset_confirm)

func _build_upgrades() -> void:
	_upgrades = _modal_panel("LOADOUT & UPGRADES", Vector2(250, 18), Vector2(1100, 864))
	_populate_upgrades()

func _populate_upgrades() -> void:
	if not _upgrades:
		return
	var box := _upgrades.get_node("Panel/Content") as VBoxContainer
	for child in box.get_children():
		child.free()
	var title := Label.new(); title.text = "LOADOUT & UPGRADES"; title.add_theme_font_size_override("font_size", 34); title.modulate = C_GOLD; box.add_child(title)
	_upgrade_funds = Label.new(); _upgrade_funds.text = "AVAILABLE CASH  $%09d" % GameManager.lifetime_credits; _upgrade_funds.modulate = C_GOLD; box.add_child(_upgrade_funds)
	var loadout_title := Label.new(); loadout_title.text = "DEPLOYMENT LOADOUT — CHOOSE 3 WEAPONS + ALWAYS-AVAILABLE FISTS"; loadout_title.modulate = C_BLUE; box.add_child(loadout_title)
	var loadout_grid := GridContainer.new(); loadout_grid.columns = 3; loadout_grid.add_theme_constant_override("h_separation", 18); box.add_child(loadout_grid)
	var fists := CheckButton.new(); fists.text = "BARE FISTS  [ALWAYS]"; fists.button_pressed = true; fists.disabled = true; loadout_grid.add_child(fists)
	for id in GameManager.WEAPON_ORDER:
		if id == "fists" or not GameManager.is_weapon_owned(id):
			continue
		var data := GameManager.get_weapon_data(id)
		var check := CheckButton.new()
		check.text = str(data.get("title", id.capitalize())).to_upper()
		check.button_pressed = id in GameManager.selected_loadout
		check.toggled.connect(_toggle_loadout.bind(id, check))
		loadout_grid.add_child(check)
	var upgrade_title := Label.new(); upgrade_title.text = "PERMANENT UPGRADES — RANK 100 MAX, COMPOUNDING COST"; upgrade_title.modulate = C_BLUE; box.add_child(upgrade_title)
	for data in [
		["armor", "CERAMIC PLATES", "More starting and maximum armor"],
		["reload", "COMBAT MANIPULATION", "Faster reloads"],
		["stability", "RECOIL CONTROL", "Tighter shot spread"],
		["quiet_steps", "SIGNATURE CONTROL", "Less alert from weapons"],
		["capacity", "LOAD-BEARING VEST", "More inventory capacity"],
		["punch_power", "HEAVY HANDS", "Harder punches and stronger knockback"],
	]:
		var row := HBoxContainer.new()
		var text_label := Label.new(); text_label.text = "%s  •  %s" % [data[1], data[2]]; text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(text_label)
		var rank := int(GameManager.upgrades[data[0]])
		var buy := Button.new()
		buy.custom_minimum_size.x = 250
		buy.text = "MAX  [RANK %d/%d]" % [GameManager.MAX_UPGRADE_RANK, GameManager.MAX_UPGRADE_RANK] if rank >= GameManager.MAX_UPGRADE_RANK else "$%d CASH  [RANK %d/%d]" % [GameManager.get_upgrade_cost(data[0]), rank, GameManager.MAX_UPGRADE_RANK]
		buy.disabled = rank >= GameManager.MAX_UPGRADE_RANK
		buy.pressed.connect(_buy_upgrade.bind(data[0]))
		row.add_child(buy); box.add_child(row)
	box.add_child(_menu_button("BACK", func(): _upgrades.hide(); _focus_first_button(_menu)))

func _build_shop() -> void:
	_shop = _modal_panel("ARMORY & AMMUNITION", Vector2(300, 45), Vector2(1000, 810))
	_populate_shop()

func _populate_shop() -> void:
	if not _shop:
		return
	var box := _shop.get_node("Panel/Content") as VBoxContainer
	for child in box.get_children():
		child.free()
	var title := Label.new(); title.text = "WEAPON SHOP"; title.add_theme_font_size_override("font_size", 34); title.modulate = C_GOLD; box.add_child(title)
	_shop_funds = Label.new(); _shop_funds.text = "AVAILABLE CASH  $%09d" % GameManager.lifetime_credits; _shop_funds.modulate = C_GOLD; box.add_child(_shop_funds)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var note := _body_label("Buy ammo for your next deployment or purchase weapons permanently. Equip up to three weapons from Loadout & Upgrades; fists never use a slot."); note.modulate = C_MUTED; list.add_child(note)
	var supply_title := Label.new()
	supply_title.text = "NEXT-DEPLOYMENT AMMUNITION"
	supply_title.modulate = C_BLUE
	list.add_child(supply_title)
	for id in GameManager.SUPPLY_ORDER:
		var data := GameManager.get_supply_data(id)
		var row := HBoxContainer.new()
		var queued := int(GameManager.pending_supplies.get(id, 0))
		var info := Label.new(); info.text = "%s — %s\nQUEUED: %d" % [str(data.title).to_upper(), str(data.description), queued]; info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
		var buy := Button.new(); buy.custom_minimum_size = Vector2(210, 44)
		buy.text = "BUY +%d  $%d" % [int(data.quantity), int(data.cost)]
		buy.pressed.connect(_buy_supply.bind(id))
		row.add_child(buy); list.add_child(row)
	var weapon_title := Label.new()
	weapon_title.text = "PERMANENT WEAPONS"
	weapon_title.modulate = C_BLUE
	list.add_child(weapon_title)
	for id in GameManager.WEAPON_ORDER:
		if id == "fists":
			continue
		var data := GameManager.get_weapon_data(id)
		var row := HBoxContainer.new()
		var info := Label.new(); info.text = "%s\n%s" % [str(data.title).to_upper(), str(data.description)]; info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_font_size_override("font_size", 16); row.add_child(info)
		var buy := Button.new(); buy.custom_minimum_size = Vector2(210, 48)
		if GameManager.is_weapon_owned(id):
			buy.text = "OWNED"; buy.disabled = true
		else:
			buy.text = "BUY  $%d" % int(data.cost); buy.pressed.connect(_buy_weapon.bind(id))
		row.add_child(buy); list.add_child(row)
	box.add_child(_menu_button("BACK", func(): _shop.hide(); _focus_first_button(_menu)))

func _toggle_loadout(enabled: bool, id: String, check: CheckButton) -> void:
	if not GameManager.set_weapon_selected(id, enabled):
		check.set_pressed_no_signal(id in GameManager.selected_loadout)

func _request_profile_reset() -> void:
	if _reset_confirm:
		_reset_confirm.popup_centered(Vector2i(640, 330))

func _confirm_profile_reset() -> void:
	GameManager.reset_profile()
	_settings.hide()
	show_notification("Fresh profile ready — cash and progression are back to zero", "good")
	_focus_first_button(_menu)

func _buy_upgrade(key: String) -> void:
	if not GameManager.buy_upgrade(key):
		show_notification("Not enough cash or maximum rank reached", "warn")

func _buy_weapon(id: String) -> void:
	if not GameManager.buy_weapon(id):
		show_notification("Not enough cash or weapon already owned", "warn")

func _buy_supply(id: String) -> void:
	if not GameManager.buy_supply(id):
		show_notification("Not enough cash for that ammunition", "warn")

func _queue_progression_refresh() -> void:
	if _progression_refresh_queued:
		return
	_progression_refresh_queued = true
	_refresh_progression_panels.call_deferred()

func _refresh_progression_panels() -> void:
	_progression_refresh_queued = false
	# Runs after the purchase/toggle signal finishes, so its source button is no longer on the call stack.
	_populate_shop()
	_populate_upgrades()

func _build_report() -> void:
	_report = _modal_panel("AFTER-ACTION REPORT", Vector2(440, 120), Vector2(720, 660))

func _connect_global_signals() -> void:
	GameManager.score_changed.connect(func(value: int): _score.text = "%06d PTS" % value)
	GameManager.alert_changed.connect(_on_alert_changed)
	GameManager.objective_changed.connect(func(text: String): _objective.text = text)
	GameManager.civilian_count_changed.connect(func(value: int): _civilian_warning.text = "CIVILIAN CASUALTIES: %d / %d" % [value, GameManager.get_civilian_limit()]; _civilian_warning.modulate = C_RED if value > 0 else C_BLUE)
	GameManager.notification.connect(show_notification)
	GameManager.profile_changed.connect(_on_profile_changed)

func _on_profile_changed() -> void:
	_update_cash_display()
	_queue_progression_refresh()

func _update_cash_display() -> void:
	if _cash:
		_cash.text = "CASH  $%09d" % maxi(GameManager.lifetime_credits, 0)

func show_main_menu() -> void:
	for panel in [_hud, _pause, _inventory_panel, _settings, _upgrades, _shop, _report]: panel.hide()
	_menu.show(); inventory_open = false; pause_open = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first_button(_menu)

func show_game() -> void:
	_menu.hide()
	_pause.hide()
	_inventory_panel.hide()
	_settings.hide()
	_upgrades.hide()
	_shop.hide()
	_report.hide()
	_hud.show()
	_scope_overlay.set_aiming(false)
	var endless_mode := GameManager.current_mission == "zombie_island"
	_alert_label.visible = not endless_mode
	_alert_bar.visible = not endless_mode
	if endless_mode:
		_civilian_warning.text = "ENDLESS MODE • NO CIVILIANS • SURVIVE"
		_civilian_warning.modulate = C_GOLD
	else:
		_civilian_warning.text = "ROE: PROTECT CIVILIANS"
		_civilian_warning.modulate = C_BLUE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_pause_open(open: bool) -> void:
	pause_open = open; get_tree().paused = open
	_pause.visible = open
	if player: player.set_controls_enabled(not open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if open: _focus_first_button(_pause)

func set_inventory_open(open: bool) -> void:
	inventory_open = open; _inventory_panel.visible = open
	if player: player.set_controls_enabled(not open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if open:
		_refresh_inventory()
		_focus_inventory_slot.call_deferred()

func show_report(won: bool, report: Dictionary) -> void:
	_hud.hide(); _pause.hide(); _inventory_panel.hide(); _scope_overlay.set_aiming(false); _report.show(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var box := _report.get_node("Panel/Content") as VBoxContainer
	for child in box.get_children(): child.free()
	var verdict := Label.new(); verdict.text = "EXTRACTION SUCCESSFUL" if won else "OPERATION FAILED"; verdict.modulate = C_GOLD if won else C_RED; verdict.add_theme_font_size_override("font_size", 34); box.add_child(verdict)
	box.add_child(_body_label(str(report.get("reason", ""))))
	box.add_child(_stat_row("MISSION", str(report.get("mission", ""))))
	box.add_child(_stat_row("DIFFICULTY", str(report.get("difficulty", ""))))
	box.add_child(_stat_row("FINAL SCORE", "%06d" % int(report.score)))
	box.add_child(_stat_row("HOSTILES NEUTRALIZED", str(report.hostiles)))
	box.add_child(_stat_row("HEADSHOTS", str(report.headshots)))
	box.add_child(_stat_row("ACCURACY", "%.1f%%" % float(report.accuracy)))
	box.add_child(_stat_row("CIVILIAN CASUALTIES", str(report.civilians)))
	box.add_child(_stat_row("CLEAN-RUN BONUS", "+%d" % int(report.clean_bonus)))
	var replay := _menu_button("RUN IT AGAIN", func(): deploy_requested.emit(GameManager.current_mission, GameManager.difficulty))
	var main_menu := _menu_button("RETURN TO MAIN MENU", func(): quit_to_menu_requested.emit())
	box.add_child(replay)
	box.add_child(main_menu)
	replay.focus_neighbor_bottom = replay.get_path_to(main_menu)
	main_menu.focus_neighbor_top = main_menu.get_path_to(replay)
	replay.grab_focus.call_deferred()

func show_notification(text: String, tone: String = "") -> void:
	_notification.text = text
	_notification.modulate = C_RED if tone == "bad" else (C_GOLD if tone == "warn" else (C_BLUE if tone == "voice" else C_TEXT))
	_notification.modulate.a = 1.0
	if _notification_tween: _notification_tween.kill()
	_notification_tween = create_tween(); _notification_tween.tween_interval(2.4); _notification_tween.tween_property(_notification, "modulate:a", 0.0, 0.5)

func _on_health_changed(health: float, armor: float) -> void:
	_health_bar.value = health; _armor_bar.value = armor

func _on_weapon_changed(title: String, mag: int, reserve: int) -> void:
	_weapon_name.text = title
	_ammo.text = "MELEE" if mag == 0 and reserve == 0 else "%02d / %03d" % [mag, reserve]

func _on_interaction_changed(text: String, progress: float) -> void:
	_interaction.text = text; _interaction_bar.value = progress; _interaction_bar.visible = not text.is_empty()

func _on_alert_changed(value: float, tier: int) -> void:
	_alert_bar.value = value; _alert_label.text = ["UNDETECTED", "SUSPICIOUS", "POLICE RESPONSE", "TACTICAL ASSAULT"][tier]
	_alert_label.modulate = [C_MUTED, C_GOLD, Color("#e2814f"), C_RED][tier]

func _on_ads_changed(active: bool) -> void:
	if _scope_overlay:
		_scope_overlay.set_aiming(active)
	_crosshair.visible = not active

func _on_hit_marker(damage_amount: float, headshot: bool) -> void:
	if _hit_tween:
		_hit_tween.kill()
	_crosshair.text = "✦" if headshot else "×"
	_crosshair.add_theme_font_size_override("font_size", 38 if headshot else 34)
	_crosshair.modulate = C_GOLD if headshot else Color.WHITE
	_damage_feedback.text = "%s  -%d" % ["HEADSHOT" if headshot else "HIT", roundi(damage_amount)]
	_damage_feedback.modulate = C_GOLD if headshot else Color("#f3e7d3")
	_damage_feedback.modulate.a = 1.0
	_damage_feedback.scale = Vector2(1.16, 1.16)
	_hit_tween = create_tween().set_parallel(true)
	_hit_tween.tween_property(_damage_feedback, "scale", Vector2.ONE, 0.12)
	_hit_tween.tween_property(_damage_feedback, "modulate:a", 0.0, 0.52).set_delay(0.22)
	_hit_tween.tween_interval(0.14)
	_hit_tween.chain().tween_callback(func():
		_crosshair.text = "+"
		_crosshair.add_theme_font_size_override("font_size", 28)
		_crosshair.modulate = Color(1,1,1,0.72)
	)

func _refresh_inventory() -> void:
	if not player:
		return
	for child in _hotbar.get_children():
		child.free()
	for i in range(9):
		var hotbar_slot := InventorySlotUI.new()
		hotbar_slot.setup(player.inventory, i, true)
		hotbar_slot.activated.connect(player.select_hotbar)
		_hotbar.add_child(hotbar_slot)
	for child in _inventory_grid.get_children():
		child.free()
	for i in InventorySystem.SLOT_COUNT:
		var inventory_slot := InventorySlotUI.new()
		inventory_slot.setup(player.inventory, i, i < 9)
		inventory_slot.activated.connect(player.select_hotbar)
		_inventory_grid.add_child(inventory_slot)
	_wire_inventory_controller_focus()
	_refresh_inventory_contents()

func _refresh_inventory_contents() -> void:
	if not player:
		return
	for child in _hotbar.get_children():
		if child is InventorySlotUI:
			(child as InventorySlotUI).refresh()
	for child in _inventory_grid.get_children():
		if child is InventorySlotUI:
			(child as InventorySlotUI).refresh()
	_weight.text = "CARRY WEIGHT  %.1f / %.1f KG" % [player.inventory.current_weight(), player.inventory.max_weight]

func _wire_inventory_controller_focus() -> void:
	var slots := _inventory_grid.get_children()
	for index in slots.size():
		var slot := slots[index] as Control
		var column := index % InventorySystem.COLUMNS
		var row := index / InventorySystem.COLUMNS
		if column > 0:
			slot.focus_neighbor_left = slot.get_path_to(slots[index - 1])
		if column < InventorySystem.COLUMNS - 1:
			slot.focus_neighbor_right = slot.get_path_to(slots[index + 1])
		if row > 0:
			slot.focus_neighbor_top = slot.get_path_to(slots[index - InventorySystem.COLUMNS])
		if row < InventorySystem.ROWS - 1:
			slot.focus_neighbor_bottom = slot.get_path_to(slots[index + InventorySystem.COLUMNS])
		elif _inventory_close_button:
			slot.focus_neighbor_bottom = slot.get_path_to(_inventory_close_button)
	if _inventory_close_button and slots.size() >= InventorySystem.COLUMNS:
		_inventory_close_button.focus_neighbor_top = _inventory_close_button.get_path_to(slots[slots.size() - InventorySystem.COLUMNS])

func _focus_inventory_slot() -> void:
	if not _inventory_panel.visible:
		return
	for child in _inventory_grid.get_children():
		if child is InventorySlotUI and not (child as InventorySlotUI).inventory.slots[(child as InventorySlotUI).slot_index].is_empty():
			(child as InventorySlotUI).grab_focus()
			return
	if _inventory_grid.get_child_count() > 0:
		(_inventory_grid.get_child(0) as Control).grab_focus()

func _show_overlay(panel: Control) -> void:
	if panel == _upgrades:
		_populate_upgrades()
	elif panel == _shop:
		_populate_shop()
	panel.show()
	panel.move_to_front()
	_focus_first_button(panel)

func _apply_accessibility() -> void:
	if not _crosshair: return
	var high_contrast := bool(SettingsManager.get_value("high_contrast", false))
	_crosshair.add_theme_color_override("font_color", Color("#fff200") if high_contrast else Color.WHITE)
	_crosshair.add_theme_constant_override("outline_size", 5 if high_contrast else 2)
	if _objective:
		_objective.add_theme_color_override("font_color", Color.WHITE if high_contrast else C_TEXT)

func _begin_remap(action: String, button: Button) -> void:
	_remap_target = action; _remap_button = button; button.text = "PRESS A KEY..."

func _modal_panel(title_text: String, pos: Vector2, panel_size: Vector2) -> Control:
	var overlay := Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.process_mode = Node.PROCESS_MODE_ALWAYS; _root.add_child(overlay)
	var shade := ColorRect.new(); shade.color = Color(0.01,0.015,0.02,0.82); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var panel := Panel.new(); panel.name = "Panel"; panel.position = pos; panel.size = panel_size; overlay.add_child(panel)
	var box := VBoxContainer.new(); box.name = "Content"; box.position = Vector2(32, 28); box.size = panel_size - Vector2(64, 56); box.add_theme_constant_override("separation", 14); panel.add_child(box)
	var title := Label.new(); title.text = title_text; title.add_theme_font_size_override("font_size", 36); title.modulate = C_GOLD; box.add_child(title)
	overlay.hide(); return overlay

func _menu_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text_value; button.custom_minimum_size = Vector2(360, 52); button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.pressed.connect(callback); return button

func _body_label(text_value: String) -> Label:
	var label := Label.new(); label.text = text_value; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.custom_minimum_size.y = 42; return label

func _stat_row(left: String, right: String) -> Control:
	var row := HBoxContainer.new(); var a := Label.new(); a.text = left; a.modulate = C_MUTED; a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(a); var b := Label.new(); b.text = right; b.modulate = C_GOLD; row.add_child(b); return row

func _slider_row(title: String, key: String, minimum: float, maximum: float, step: float) -> Control:
	var row := HBoxContainer.new(); var label := Label.new(); label.text = title; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label); var slider := HSlider.new(); slider.min_value = minimum; slider.max_value = maximum; slider.step = step; slider.value = float(SettingsManager.get_value(key)); slider.custom_minimum_size.x = 320; slider.value_changed.connect(func(value): SettingsManager.set_value(key, value)); row.add_child(slider); return row

func _check_row(title: String, key: String) -> Control:
	var check := CheckButton.new(); check.text = title; check.button_pressed = bool(SettingsManager.get_value(key)); check.toggled.connect(func(value): SettingsManager.set_value(key, value)); return check

func _style(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = color; style.border_color = border; style.set_border_width_all(width); style.set_corner_radius_all(radius); style.content_margin_left = 14; style.content_margin_right = 14; style.content_margin_top = 9; style.content_margin_bottom = 9; return style

func _focus_first_button(control: Control) -> void:
	var buttons := control.find_children("*", "Button", true, false)
	for candidate in buttons:
		var button := candidate as Button
		if button and not button.disabled and button.focus_mode != Control.FOCUS_NONE and button.is_visible_in_tree() and not button.is_queued_for_deletion():
			button.grab_focus()
			return

func _input(event: InputEvent) -> void:
	if not inventory_open or not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var direction := Vector2i.ZERO
	if event.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT
	elif event.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	if direction != Vector2i.ZERO:
		_move_inventory_focus(direction)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if _activate_focused_inventory_slot():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		set_inventory_open(false)
		get_viewport().set_input_as_handled()

func _move_inventory_focus(direction: Vector2i) -> void:
	if _inventory_grid.get_child_count() == 0:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := 0
	if focused is InventorySlotUI:
		index = (focused as InventorySlotUI).slot_index
	var column := index % InventorySystem.COLUMNS
	var row := index / InventorySystem.COLUMNS
	column = clampi(column + direction.x, 0, InventorySystem.COLUMNS - 1)
	row = clampi(row + direction.y, 0, InventorySystem.ROWS - 1)
	var target_index := row * InventorySystem.COLUMNS + column
	var target := _inventory_grid.get_child(target_index) as InventorySlotUI
	target.grab_focus()
