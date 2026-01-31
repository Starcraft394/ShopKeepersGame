## TownScene.gd
## Town hub UI with location display, stash viewer, facilities, and dungeon actions.
## Routes through game_boot for phase-based scene transitions.
extends Control

const BOOT_SCENE_PATH = "res://Game/Boot/game_boot.tscn"

# ============================================================================
# NODE REFERENCES
# ============================================================================

# Location section
@onready var location_label: Label = %LocationLabel
@onready var town_name_label: Label = %TownNameLabel
@onready var progress_label: Label = %ProgressLabel

# Stash section (dual stash display)
@onready var banked_stash_label: Label = %BankedStashLabel
@onready var unbanked_stash_label: Label = %UnbankedStashLabel
@onready var stash_list_vbox: VBoxContainer = %StashListVBox

# Facilities section
@onready var facilities_vbox: VBoxContainer = %FacilitiesVBox

# Action buttons
@onready var enter_dungeon_button: Button = %EnterDungeonButton
@onready var continue_run_button: Button = %ContinueRunButton
@onready var exit_dungeon_button: Button = %ExitDungeonButton

# Town switch buttons
@onready var greenroot_button: Button = %GreenrootButton
@onready var timberfall_button: Button = %TimberfallButton

# Heroes section
@onready var heroes_vbox: VBoxContainer = %HeroesVBox

# Debug section
@onready var clear_stash_button: Button = %ClearStashButton
@onready var reset_save_button: Button = %ResetSaveButton
@onready var add_gold_button: Button = %AddGoldButton

# Facility window (modal popup)
@onready var facility_window: Window = %FacilityWindow
@onready var facility_name_label: Label = %FacilityNameLabel
@onready var facility_type_label: Label = %FacilityTypeLabel
@onready var facility_desc_label: Label = %FacilityDescLabel
@onready var facility_tier_label: Label = %FacilityTierLabel
@onready var facility_services_label: Label = %FacilityServicesLabel
@onready var close_facility_button: Button = %CloseFacilityButton

# Dynamic facility action container (created at runtime)
var _facility_actions_container: VBoxContainer = null
var _current_facility_type: String = ""
var _current_facility = null  # Current facility data (for recipes/shop)
var _current_facility_id: String = ""  # Facility ID for seeding/logging
var _last_facility_window_pos: Vector2i = Vector2i(-1, -1)  # -1 means use centered

# Storage filter state
var _storage_filter: String = "all"  # "all", "materials", "consumables", "equipment", "books"

# Training Hall: selected hero for class assignment
var _training_selected_hero_id: String = ""

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect button signals
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	continue_run_button.pressed.connect(_on_continue_run_pressed)
	exit_dungeon_button.pressed.connect(_on_exit_dungeon_pressed)
	greenroot_button.pressed.connect(_on_greenroot_pressed)
	timberfall_button.pressed.connect(_on_timberfall_pressed)
	clear_stash_button.pressed.connect(_on_clear_stash_pressed)
	reset_save_button.pressed.connect(_on_reset_save_pressed)
	add_gold_button.pressed.connect(_on_add_gold_pressed)
	close_facility_button.pressed.connect(_on_close_facility_pressed)
	facility_window.close_requested.connect(_on_close_facility_pressed)

	# Ensure all heroes are fully healed when entering town view
	if GameContext.get_phase() == GameContext.GamePhase.TOWN:
		GameContext.apply_town_entry_reset()

	# Initial UI refresh
	_refresh_ui()
	_populate_facilities_list()

	# Log state on load
	var region_id = GameContext.get_current_region_id()
	var town_id = GameContext.get_current_town_id()
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var rooms_per_floor = GameContext.get_rooms_per_floor()
	var dungeon_str = dungeon_id if dungeon_id != "" else "none"
	print("[TownScene] Loaded. Location=%s/%s Dungeon=%s Floor=%d Room=%d/%d" % [
		region_id, town_id, dungeon_str, floor_num, room_idx + 1, rooms_per_floor
	])


# ============================================================================
# UI REFRESH
# ============================================================================

func _refresh_ui() -> void:
	_update_location_labels()
	_update_button_states()
	_populate_stash_list()
	_populate_heroes_section()


func _update_location_labels() -> void:
	var region_id = GameContext.get_current_region_id()
	var town_id = GameContext.get_current_town_id()
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var rooms_per_floor = GameContext.get_rooms_per_floor()

	# Location label
	location_label.text = "Location: %s / %s" % [region_id, town_id]

	# Town name label (get display name from TownData)
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var town_name = town.display_name if town != null and town.display_name != "" else town_id
	town_name_label.text = "Town: %s" % town_name

	# Progress label
	if dungeon_id == "":
		progress_label.text = "Dungeon: none | Floor: 0/0 | Room: 0/0"
	else:
		# Get dungeon display name and floor count
		var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
		var dungeon_name = dungeon.display_name if dungeon != null and dungeon.display_name != "" else dungeon_id
		var floor_count = dungeon.floor_count if dungeon != null else 4
		progress_label.text = "%s | Floor %d/%d | Room %d/%d" % [
			dungeon_name, floor_num, floor_count, room_idx + 1, rooms_per_floor
		]


func _update_button_states() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()
	var in_dungeon = dungeon_id != ""
	var town_id = GameContext.get_current_town_id()

	# Get town's dungeon_id to check if town has a dungeon
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var town_has_dungeon = town != null and town.dungeon_id != ""

	# Enter Dungeon: enabled only if not in dungeon AND town has a dungeon
	enter_dungeon_button.disabled = in_dungeon or not town_has_dungeon

	# Continue Run: enabled only if in dungeon
	continue_run_button.disabled = not in_dungeon

	# Exit Dungeon: enabled only if in dungeon
	exit_dungeon_button.disabled = not in_dungeon

	# Highlight current town button
	greenroot_button.disabled = (town_id == "town_greenroot")
	timberfall_button.disabled = (town_id == "town_timberfall")


func _populate_stash_list() -> void:
	# Items v6: Get detailed stash summaries
	var run_summary = {}
	var dungeon_summary = {}
	if GameContext.has_method("get_run_stash_detailed_summary"):
		run_summary = GameContext.get_run_stash_detailed_summary()
	else:
		var run_stash = GameContext.get_run_stash_summary()
		run_summary = { "gold": run_stash.gold, "total_items": run_stash.items_count }

	if GameContext.has_method("get_dungeon_stash_detailed_summary"):
		dungeon_summary = GameContext.get_dungeon_stash_detailed_summary()
	else:
		var dungeon_stash = GameContext.get_dungeon_stash_summary()
		dungeon_summary = { "gold": dungeon_stash.gold, "total_items": dungeon_stash.items_count }

	# Items v6: Format banked stash with detailed summary
	banked_stash_label.text = "Run Stash (Banked): %d gold | Items: %d | Gear: %d Mats: %d Cons: %d" % [
		run_summary.get("gold", 0),
		run_summary.get("total_items", 0),
		run_summary.get("gear_count", 0),
		run_summary.get("mat_count", 0),
		run_summary.get("cons_count", 0)]

	# Items v6: Format dungeon stash (only show if in dungeon or has items)
	var in_dungeon = GameContext.current_dungeon_id != ""
	if in_dungeon or dungeon_summary.get("total_items", 0) > 0 or dungeon_summary.get("gold", 0) > 0:
		unbanked_stash_label.text = "Dungeon Stash (Unbanked): %d gold | Items: %d | Gear: %d Mats: %d Cons: %d" % [
			dungeon_summary.get("gold", 0),
			dungeon_summary.get("total_items", 0),
			dungeon_summary.get("gear_count", 0),
			dungeon_summary.get("mat_count", 0),
			dungeon_summary.get("cons_count", 0)]
		unbanked_stash_label.visible = true
	else:
		unbanked_stash_label.text = "(No dungeon stash - in town)"
		unbanked_stash_label.visible = true

	# Clear existing items in list
	for child in stash_list_vbox.get_children():
		child.queue_free()

	# Aggregate items by template_id + quality_tier
	# Key format: "template_id:quality_tier" for ItemInstance, "template_id:0" for Dictionary
	var aggregated: Dictionary = {}  # key -> { display_name, qty, quality_tier }
	var items = GameContext.run_items
	print("[TownUI] Populating stash with %d raw items" % items.size())

	for item in items:
		var template_id := ""
		var quality_tier := 0
		var display_name := ""
		var qty := 1

		if item is ItemInstance:
			# ItemInstance from dungeon loot
			template_id = item.template_id
			quality_tier = item.quality_tier
			display_name = item.display_name  # Already has quality prefix
			qty = item.quantity
		elif item is Dictionary:
			# Dictionary from shop purchase { item_id, qty }
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
			# Look up template for display name
			if template_id != "":
				var tpl = DataRegistry.get_item_template(template_id)
				if tpl != null:
					display_name = tpl.display_name
				else:
					print("[TownUI] Missing item template for id=%s" % template_id)
					display_name = template_id
			else:
				display_name = "(unknown)"
		else:
			print("[TownUI] Unknown item type in stash: %s" % str(item))
			continue

		# Aggregate by template_id + quality_tier
		var key = "%s:%d" % [template_id, quality_tier]
		if aggregated.has(key):
			aggregated[key].qty += qty
		else:
			aggregated[key] = {
				"template_id": template_id,
				"display_name": display_name,
				"qty": qty,
				"quality_tier": quality_tier
			}

	# Populate list from aggregated data with tooltips
	if aggregated.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "(empty)"
		empty_label.modulate = Color(0.6, 0.6, 0.6, 1)
		stash_list_vbox.add_child(empty_label)
	else:
		var quality_names = ["Common", "Fine", "Rare", "Epic"]
		for key in aggregated.keys():
			var entry = aggregated[key]
			var item_label = Label.new()
			# Add quality indicator if quality > 0
			var q_indicator = ""
			if entry.quality_tier > 0 and entry.quality_tier < quality_names.size():
				q_indicator = " [Q%d]" % entry.quality_tier
			item_label.text = "%s x%d%s" % [entry.display_name, entry.qty, q_indicator]

			# Items v6: Build tooltip with item details (equipment + consumable aware)
			var tpl = DataRegistry.get_item_template(entry.template_id)
			var tooltip_parts: Array[String] = []
			tooltip_parts.append(entry.display_name)
			tooltip_parts.append("ID: %s" % entry.template_id)
			tooltip_parts.append("Qty: %d" % entry.qty)
			if tpl != null:
				# Equipment-specific info: slot, quality with multiplier
				if tpl.equip_slot != "":
					tooltip_parts.append("Slot: %s" % tpl.equip_slot)
					const QUALITY_MULT := [1.0, 1.1, 1.2, 1.35]
					var q_tier = clampi(entry.quality_tier, 0, 3)
					var mult = QUALITY_MULT[q_tier]
					tooltip_parts.append("Quality: Q%d %s (x%.2f)" % [q_tier, quality_names[q_tier] if q_tier < quality_names.size() else "???", mult])
					# Final stat bonuses
					var bonuses = tpl.get_stat_bonuses_with_quality(entry.quality_tier)
					if not bonuses.is_empty():
						var bonus_parts: Array[String] = []
						if bonuses.get("health", 0) > 0:
							bonus_parts.append("HP +%d" % bonuses.health)
						if bonuses.get("attack", 0) > 0:
							bonus_parts.append("ATK +%d" % bonuses.attack)
						if bonuses.get("defense", 0) > 0:
							bonus_parts.append("DEF +%d" % bonuses.defense)
						if bonuses.get("speed", 0) > 0:
							bonus_parts.append("SPD +%d" % bonuses.speed)
						if not bonus_parts.is_empty():
							tooltip_parts.append("Stats (final): %s" % ", ".join(bonus_parts))
				# Items v6: Consumable-specific info
				elif tpl.item_type == "consumable" and tpl.use_effect != "":
					tooltip_parts.append("Type: Consumable")
					tooltip_parts.append("Use Effect: %s" % tpl.use_effect.replace("_", " ").capitalize())
					if tpl.use_value > 0:
						tooltip_parts.append("Power: %d" % tpl.use_value)
				else:
					# Non-equipment quality
					if entry.quality_tier > 0 and entry.quality_tier < quality_names.size():
						tooltip_parts.append("Quality: %s" % quality_names[entry.quality_tier])
				tooltip_parts.append("Sell: %d gold" % tpl.base_value)
				tooltip_parts.append("Buy: %d gold" % tpl.get_buy_value())
			item_label.tooltip_text = "\n".join(tooltip_parts)

			stash_list_vbox.add_child(item_label)
		print("[TownUI] Stash list populated with %d unique item types" % aggregated.size())


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_enter_dungeon_pressed() -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null or town.dungeon_id == "":
		print("[TownUI] EnterDungeon FAILED - no dungeon for town '%s'" % town_id)
		return

	# Enter dungeon
	GameContext.enter_dungeon(town.dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[TownUI] EnterDungeon -> dungeon_id=%s floor=%d room=%d/%d" % [
		GameContext.get_current_dungeon_id(),
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _on_continue_run_pressed() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[TownUI] ContinueRun FAILED - not in a dungeon")
		return

	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[TownUI] ContinueRun -> dungeon_id=%s floor=%d room=%d/%d" % [
		dungeon_id,
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _on_exit_dungeon_pressed() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[TownUI] ExitDungeon ignored - not in a dungeon")
		return

	print("[TownUI] ExitDungeon -> from dungeon_id=%s" % dungeon_id)

	# Exit to town (this sets phase to TOWN internally)
	GameContext.exit_to_town()

	# Refresh UI
	_refresh_ui()


func _on_greenroot_pressed() -> void:
	_switch_town("town_greenroot")


func _on_timberfall_pressed() -> void:
	_switch_town("town_timberfall")


func _switch_town(new_town_id: String) -> void:
	var current_dungeon = GameContext.get_current_dungeon_id()

	# If in dungeon, exit first to avoid inconsistent state
	if current_dungeon != "":
		print("[TownUI] SwitchTown -> exiting dungeon first")
		GameContext.exit_to_town()

	# Set new location
	GameContext.set_location("region_1", new_town_id)

	print("[TownUI] SwitchTown -> town_id=%s" % new_town_id)

	# Refresh UI and facilities list
	_refresh_ui()
	_populate_facilities_list()


func _on_clear_stash_pressed() -> void:
	# Safe call guard
	if GameContext.has_method("clear_run_stash"):
		GameContext.clear_run_stash()
		print("[TownUI] ClearStash -> stash cleared")
	else:
		print("[TownUI] ClearStash FAILED - method not available")

	# Refresh UI
	_refresh_ui()


## DEV TOOL: Reset save data and reinitialize to fresh state.
## This deletes the save file and clears all runtime state.
func _on_reset_save_pressed() -> void:
	print("[TownUI] RESET SAVE button pressed")

	# Call GameContext reset function
	if GameContext.has_method("reset_save_game"):
		GameContext.reset_save_game()
	else:
		push_warning("[TownUI] reset_save_game not found in GameContext")
		return

	# Close facility window if open
	if facility_window.visible:
		facility_window.hide()

	# Clear training hall selection state
	_training_selected_hero_id = ""

	# Refresh entire UI
	_refresh_ui()
	_populate_facilities_list()

	print("[TownUI] UI refreshed after save reset")


func _on_add_gold_pressed() -> void:
	print("[TownUI] +100 GOLD (DEV) button pressed")
	GameContext.add_run_gold(100)
	GameContext.save_game()  # Persist banked gold
	print("[TownUI] Added 100 gold to run stash (saved). New total: %d" % GameContext.get_run_gold())
	_refresh_ui()
	# Refresh facility panel if open (to update gold display)
	if facility_window.visible:
		_refresh_facility_panel()


func _on_close_facility_pressed() -> void:
	# Save position for next open
	_last_facility_window_pos = facility_window.position
	facility_window.hide()
	print("[FacilityUI] Close")


# ============================================================================
# FACILITIES
# ============================================================================

func _populate_facilities_list() -> void:
	# Clear existing facility buttons (except placeholder)
	for child in facilities_vbox.get_children():
		child.queue_free()

	# Get current town
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null or town.facility_ids.size() == 0:
		# No facilities - show placeholder
		var placeholder = Label.new()
		placeholder.text = "(no facilities)"
		placeholder.modulate = Color(0.6, 0.6, 0.6, 1)
		facilities_vbox.add_child(placeholder)
		return

	# Create button for each facility
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null

		var button = Button.new()
		if facility != null:
			button.text = "%s (%s)" % [facility.display_name, facility.facility_type]
		else:
			button.text = facility_id + " (unknown)"

		button.custom_minimum_size = Vector2(200, 28)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Store facility_id in metadata for the click handler
		button.set_meta("facility_id", facility_id)
		button.pressed.connect(_on_facility_button_pressed.bind(facility_id))

		facilities_vbox.add_child(button)

	print("[TownUI] Populated %d facilities for town '%s'" % [town.facility_ids.size(), town_id])


func _on_facility_button_pressed(facility_id: String) -> void:
	_show_facility_panel(facility_id)


func _show_facility_panel(facility_id: String) -> void:
	var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null

	# Store facility for recipes/shop access
	_current_facility = facility
	_current_facility_id = facility_id

	if facility == null:
		facility_name_label.text = facility_id
		facility_type_label.text = "Type: unknown"
		facility_desc_label.text = "Facility data not found."
		facility_tier_label.text = "Max Tier: ?"
		facility_services_label.text = "Tier 1 Services: (none)"
		_current_facility_type = ""
	else:
		facility_name_label.text = facility.display_name
		facility_type_label.text = "Type: %s" % facility.facility_type
		facility_desc_label.text = facility.description if facility.description != "" else "(no description)"
		facility_tier_label.text = "Max Tier: %d" % facility.max_tier
		_current_facility_type = facility.facility_type

		# Get tier 1 services
		var tier_1_services = []
		if facility.services_per_tier.has("1"):
			tier_1_services = facility.services_per_tier["1"]
		elif facility.services_per_tier.has(1):
			tier_1_services = facility.services_per_tier[1]

		if tier_1_services.size() == 0:
			facility_services_label.text = "Tier 1 Services: (none)"
		else:
			facility_services_label.text = "Tier 1 Services: %s" % ", ".join(tier_1_services)

	# Create dynamic action UI based on facility type
	_create_facility_actions(facility)

	# Update window title with facility name
	facility_window.title = facility.display_name if facility != null else "Facility"

	# Show window (restore position if we have one, otherwise center)
	if _last_facility_window_pos.x >= 0:
		facility_window.position = _last_facility_window_pos
		facility_window.show()
	else:
		facility_window.popup_centered()

	print("[FacilityUI] Open %s" % facility_id)


func _create_facility_actions(facility) -> void:
	# Clear previous actions container
	if _facility_actions_container != null:
		_facility_actions_container.queue_free()
		_facility_actions_container = null

	# Create new container
	_facility_actions_container = VBoxContainer.new()
	_facility_actions_container.add_theme_constant_override("separation", 6)

	# Insert before close button (VBox is inside MarginContainer/ScrollContainer)
	var vbox = facility_window.get_node("MarginContainer/ScrollContainer/VBox")
	var close_idx = close_facility_button.get_index()
	vbox.add_child(_facility_actions_container)
	vbox.move_child(_facility_actions_container, close_idx)

	# Add separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Add type-specific UI
	if facility == null:
		return

	match facility.facility_type:
		"dungeon":
			_build_dungeon_ui()
		"storage":
			_build_storage_ui()
		"shop":
			_build_shop_ui()
		"alchemist":
			_build_alchemist_ui()
		"blacksmith":
			_build_blacksmith_ui()
		"training_hall":
			_build_training_ui()
		"inn":
			_build_inn_ui()
		"woodsman":
			_build_woodsman_ui()
		"production":
			_build_production_ui()
		_:
			var info = Label.new()
			info.text = "(No actions available)"
			info.modulate = Color(0.6, 0.6, 0.6, 1)
			_facility_actions_container.add_child(info)


# ============================================================================
# FACILITY UI BUILDERS
# ============================================================================

func _build_storage_ui() -> void:
	print("[Storage] opened")

	var header = Label.new()
	header.text = "=== Storage (Bank) ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	# Show gold balance
	var run_gold = GameContext.get_run_gold()
	var gold_label = Label.new()
	gold_label.text = "Bank Gold: %d" % run_gold
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# v2: Equipment display section
	var equip_header = Label.new()
	equip_header.text = "-- Equipped Gear --"
	equip_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(equip_header)

	var equip_summary = GameContext.get_equipment_summary()
	var weapon_id = equip_summary.get("weapon_id", "")
	var weapon_quality = equip_summary.get("weapon_quality", 0)
	var offhand_id = equip_summary.get("offhand_id", "")
	var offhand_quality = equip_summary.get("offhand_quality", 0)

	# Weapon display
	var weapon_label = Label.new()
	if weapon_id != "":
		var weapon_tpl = DataRegistry.get_item_template(weapon_id)
		var weapon_name = weapon_id
		if weapon_tpl != null:
			weapon_name = weapon_tpl.display_name
		weapon_label.text = "Weapon: %s (Q%d)" % [weapon_name, weapon_quality]
		weapon_label.modulate = Color(0.8, 1.0, 0.8, 1)
	else:
		weapon_label.text = "Weapon: (none)"
		weapon_label.modulate = Color(0.5, 0.5, 0.5, 1)
	_facility_actions_container.add_child(weapon_label)

	# Offhand display
	var offhand_label = Label.new()
	if offhand_id != "":
		var offhand_tpl = DataRegistry.get_item_template(offhand_id)
		var offhand_name = offhand_id
		if offhand_tpl != null:
			offhand_name = offhand_tpl.display_name
		offhand_label.text = "Offhand: %s (Q%d)" % [offhand_name, offhand_quality]
		offhand_label.modulate = Color(0.8, 1.0, 0.8, 1)
	else:
		offhand_label.text = "Offhand: (none)"
		offhand_label.modulate = Color(0.5, 0.5, 0.5, 1)
	_facility_actions_container.add_child(offhand_label)

	# Gear bonus display
	var gear_bonus = GameContext._get_equipment_stat_bonuses()
	var bonus_label = Label.new()
	bonus_label.text = "Gear Bonus: HP +%d, ATK +%d, DEF +%d, SPD +%d" % [
		gear_bonus.get("health", 0), gear_bonus.get("attack", 0),
		gear_bonus.get("defense", 0), gear_bonus.get("speed", 0)
	]
	bonus_label.modulate = Color(0.6, 0.9, 1.0, 1)
	_facility_actions_container.add_child(bonus_label)

	# Unequip buttons
	var unequip_row = HBoxContainer.new()
	unequip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	unequip_row.add_theme_constant_override("separation", 8)
	_facility_actions_container.add_child(unequip_row)

	var unequip_weapon_btn = Button.new()
	unequip_weapon_btn.text = "Unequip Weapon"
	unequip_weapon_btn.custom_minimum_size = Vector2(120, 26)
	unequip_weapon_btn.disabled = weapon_id == ""
	unequip_weapon_btn.pressed.connect(_on_unequip_weapon_pressed)
	unequip_row.add_child(unequip_weapon_btn)

	var unequip_offhand_btn = Button.new()
	unequip_offhand_btn.text = "Unequip Offhand"
	unequip_offhand_btn.custom_minimum_size = Vector2(120, 26)
	unequip_offhand_btn.disabled = offhand_id == ""
	unequip_offhand_btn.pressed.connect(_on_unequip_offhand_pressed)
	unequip_row.add_child(unequip_offhand_btn)

	var equip_sep = HSeparator.new()
	_facility_actions_container.add_child(equip_sep)

	# Player inventory section (if exists) - for transfers
	var player_gold = GameContext.get_player_gold()
	var player_items = GameContext.get_player_items()
	var has_player_inventory = player_gold > 0 or not player_items.is_empty()

	if has_player_inventory:
		var transfer_header = Label.new()
		transfer_header.text = "-- Personal Wallet --"
		transfer_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		transfer_header.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(transfer_header)

		var wallet_label = Label.new()
		wallet_label.text = "Personal Gold: %d" % player_gold
		_facility_actions_container.add_child(wallet_label)

		# Gold transfer buttons
		var gold_row = HBoxContainer.new()
		gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
		gold_row.add_theme_constant_override("separation", 8)
		_facility_actions_container.add_child(gold_row)

		var deposit_btn = Button.new()
		deposit_btn.text = "Deposit 10"
		deposit_btn.custom_minimum_size = Vector2(100, 26)
		deposit_btn.disabled = player_gold < 10
		deposit_btn.pressed.connect(_on_storage_deposit_pressed)
		gold_row.add_child(deposit_btn)

		var withdraw_btn = Button.new()
		withdraw_btn.text = "Withdraw 10"
		withdraw_btn.custom_minimum_size = Vector2(100, 26)
		withdraw_btn.disabled = run_gold < 10
		withdraw_btn.pressed.connect(_on_storage_withdraw_pressed)
		gold_row.add_child(withdraw_btn)

		# Player items with transfer buttons
		if not player_items.is_empty():
			for item_id in player_items.keys():
				var qty = player_items[item_id]
				var item_row = _create_item_transfer_row(item_id, qty, "wallet", "deposit")
				_facility_actions_container.add_child(item_row)

	# Separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Category filter buttons
	var filter_header = Label.new()
	filter_header.text = "-- Bank Stash --"
	filter_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	filter_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(filter_header)

	var filter_row = HBoxContainer.new()
	filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row)

	var filters = ["all", "materials", "consumables", "equipment", "books"]
	for f in filters:
		var btn = Button.new()
		btn.text = f.capitalize()
		btn.custom_minimum_size = Vector2(70, 24)
		btn.disabled = (_storage_filter == f)
		btn.pressed.connect(_on_storage_filter_pressed.bind(f))
		filter_row.add_child(btn)

	# Compact stash button
	var compact_btn = Button.new()
	compact_btn.text = "Compact Stash"
	compact_btn.custom_minimum_size = Vector2(120, 26)
	compact_btn.pressed.connect(_on_storage_compact_pressed)
	_facility_actions_container.add_child(compact_btn)

	# Build stash display grouped by template + quality
	var stash_items = _get_aggregated_stash_items()
	var filtered_items = _filter_stash_items(stash_items, _storage_filter)

	var count_label = Label.new()
	count_label.text = "Showing %d / %d item stacks" % [filtered_items.size(), stash_items.size()]
	count_label.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(count_label)

	if filtered_items.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "(No items in this category)"
		empty_label.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(empty_label)
	else:
		for item in filtered_items:
			var row = _create_stash_item_row(item)
			_facility_actions_container.add_child(row)

	# Transfer hint if player inventory exists
	if has_player_inventory:
		var hint = Label.new()
		hint.text = "(Transfer items between bank and personal wallet)"
		hint.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(hint)


func _get_aggregated_stash_items() -> Array:
	# Returns Array of { template_id, quality_tier, qty, display_name, category }
	var result: Array = []
	var aggregated: Dictionary = {}  # key -> { template_id, quality_tier, qty, display_name, category }

	for item in GameContext.run_items:
		var template_id := ""
		var quality_tier := 0
		var display_name := ""
		var qty := 1

		if item is ItemInstance:
			template_id = item.template_id
			quality_tier = item.quality_tier
			display_name = item.display_name
			qty = item.quantity
		elif item is Dictionary:
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
			var tpl = DataRegistry.get_item_template(template_id)
			if tpl != null:
				display_name = tpl.display_name
			else:
				display_name = template_id
		else:
			continue

		var key = "%s:%d" % [template_id, quality_tier]
		if aggregated.has(key):
			aggregated[key].qty += qty
		else:
			var category = _get_item_category(template_id)
			aggregated[key] = {
				"template_id": template_id,
				"quality_tier": quality_tier,
				"qty": qty,
				"display_name": display_name,
				"category": category
			}

	for key in aggregated.keys():
		result.append(aggregated[key])

	# Sort by category priority: materials first, then equipment, then consumables, then books, then other
	result.sort_custom(_sort_stash_items_by_category)

	return result


## Sort comparator for stash items by category (materials first, then equipment, then consumables)
func _sort_stash_items_by_category(a: Dictionary, b: Dictionary) -> bool:
	var category_order = {
		"materials": 0,
		"equipment": 1,
		"consumables": 2,
		"books": 3,
		"other": 4
	}
	var a_order = category_order.get(a.category, 5)
	var b_order = category_order.get(b.category, 5)
	if a_order != b_order:
		return a_order < b_order
	# Secondary sort: alphabetical by display_name
	return a.display_name.naturalnocasecmp_to(b.display_name) < 0


func _get_item_category(template_id: String) -> String:
	# Determine category from template tags or item_type
	var tpl = DataRegistry.get_item_template(template_id)
	if tpl == null:
		# Fallback for known IDs
		if template_id.begins_with("book_"):
			return "books"
		if template_id in ["herb", "mushroom", "wood", "iron_scrap", "wood_bundle"]:
			return "materials"
		return "other"

	# Check tags first
	for tag in tpl.tags:
		if tag == "book":
			return "books"
		if tag in ["material", "resource", "crafting"]:
			return "materials"

	# Fallback to item_type
	match tpl.item_type:
		"consumable":
			return "consumables"
		"weapon", "armor", "accessory", "offhand":
			return "equipment"
		"tool", "backpack":
			return "equipment"
		_:
			# Check if it has an equip slot
			if tpl.equip_slot != "":
				return "equipment"
			# Default to materials for unknown
			return "materials"


func _filter_stash_items(items: Array, filter: String) -> Array:
	if filter == "all":
		return items
	var result: Array = []
	for item in items:
		if item.category == filter:
			result.append(item)
	return result


func _create_stash_item_row(item: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label = Label.new()
	var quality_prefix = ""
	if item.quality_tier > 0:
		quality_prefix = "[Q%d] " % item.quality_tier
	label.text = "%s%s x%d" % [quality_prefix, item.display_name, item.qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Items v5: Improved tooltip with slot, quality multiplier, and stats for equipment
	var tpl = DataRegistry.get_item_template(item.template_id)
	if tpl != null:
		var tooltip_parts: Array[String] = []
		tooltip_parts.append(item.display_name)
		tooltip_parts.append("ID: %s" % item.template_id)
		tooltip_parts.append("Qty: %d" % item.qty)

		# Equipment-specific info: slot, quality with multiplier
		if tpl.equip_slot != "":
			tooltip_parts.append("Slot: %s" % tpl.equip_slot)
			# Quality line with multiplier info
			const QUALITY_MULT := [1.0, 1.1, 1.2, 1.35]
			var quality_names = ["Common", "Uncommon", "Rare", "Epic"]
			var q_tier = clampi(item.quality_tier, 0, 3)
			var mult = QUALITY_MULT[q_tier]
			tooltip_parts.append("Quality: Q%d %s (x%.2f)" % [q_tier, quality_names[q_tier], mult])
			# Final stat bonuses after quality multiplier
			var bonuses = tpl.get_stat_bonuses_with_quality(item.quality_tier)
			if not bonuses.is_empty():
				var bonus_parts: Array[String] = []
				if bonuses.get("health", 0) > 0:
					bonus_parts.append("HP +%d" % bonuses.health)
				if bonuses.get("attack", 0) > 0:
					bonus_parts.append("ATK +%d" % bonuses.attack)
				if bonuses.get("defense", 0) > 0:
					bonus_parts.append("DEF +%d" % bonuses.defense)
				if bonuses.get("speed", 0) > 0:
					bonus_parts.append("SPD +%d" % bonuses.speed)
				if not bonus_parts.is_empty():
					tooltip_parts.append("Stats (final): %s" % ", ".join(bonus_parts))
		else:
			# Non-equipment items: simpler quality display
			if item.quality_tier > 0:
				var quality_names = ["Common", "Uncommon", "Rare", "Epic"]
				if item.quality_tier < quality_names.size():
					tooltip_parts.append("Quality: %s" % quality_names[item.quality_tier])

		tooltip_parts.append("Sell: %d gold" % tpl.base_value)
		tooltip_parts.append("Buy: %d gold" % tpl.get_buy_value())
		label.tooltip_text = "\n".join(tooltip_parts)
	row.add_child(label)

	# Category tag
	var cat_label = Label.new()
	cat_label.text = "(%s)" % item.category
	cat_label.modulate = Color(0.6, 0.6, 0.6, 1)
	row.add_child(cat_label)

	# v2: Equip button for equipment items
	if tpl != null and tpl.equip_slot in ["weapon", "offhand"]:
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(60, 24)
		equip_btn.pressed.connect(_on_equip_item_pressed.bind(item.template_id, tpl.equip_slot))
		row.add_child(equip_btn)

	# Withdraw button (to player inventory if it exists)
	var player_items = GameContext.get_player_items()
	var player_gold = GameContext.get_player_gold()
	if player_gold > 0 or not player_items.is_empty():
		var btn = Button.new()
		btn.text = "To Wallet"
		btn.custom_minimum_size = Vector2(80, 24)
		btn.pressed.connect(_on_item_transfer_pressed.bind(item.template_id, "withdraw"))
		row.add_child(btn)

	return row


func _on_storage_filter_pressed(filter: String) -> void:
	_storage_filter = filter
	print("[Storage] filter=%s" % filter)
	_refresh_facility_panel()


func _on_storage_compact_pressed() -> void:
	# Re-aggregate display (no actual data change needed since we aggregate on display)
	print("[Storage] compacted")
	_refresh_facility_panel()


func _create_item_transfer_row(item_id: String, qty: int, source: String, action: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label = Label.new()
	var display_name = item_id
	var template = DataRegistry.get_item_template(item_id) if DataRegistry.has_method("get_item_template") else null
	if template != null and template.display_name != "":
		display_name = template.display_name
	label.text = "%s x%d (%s)" % [display_name, qty, source]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var btn = Button.new()
	btn.text = action.capitalize()
	btn.custom_minimum_size = Vector2(80, 24)
	btn.pressed.connect(_on_item_transfer_pressed.bind(item_id, action))
	row.add_child(btn)

	return row


func _build_unlock_ui(facility_name: String) -> void:
	# Header
	var header = Label.new()
	header.text = "=== %s ===" % facility_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No facility data)"
		no_data.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_data)
		return

	# Get tier info
	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)
	var max_tier = GameContext.get_facility_max_tier(facility_id)

	# Tier display
	var tier_label = Label.new()
	tier_label.text = "Tier %d / %d" % [current_tier, max_tier]
	tier_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(tier_label)

	# Upgrade section (if not at max tier)
	if current_tier < max_tier:
		var next_tier = current_tier + 1
		var cost = GameContext.get_facility_upgrade_cost(facility_id, next_tier)
		var can_upgrade = GameContext.can_afford_facility_upgrade(cost)

		# Format cost text
		var cost_parts: Array[String] = []
		var gold_cost = cost.get("gold", 0)
		if gold_cost > 0:
			cost_parts.append("%d gold" % gold_cost)
		var items_cost = cost.get("items", [])
		for item in items_cost:
			var item_id = item.get("item_id", "")
			var qty = item.get("qty", 1)
			var item_name = item_id
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null and tpl.display_name != "":
				item_name = tpl.display_name
			cost_parts.append("%s x%d" % [item_name, qty])

		var cost_text = ", ".join(cost_parts) if cost_parts.size() > 0 else "Free"

		var upgrade_row = HBoxContainer.new()
		upgrade_row.add_theme_constant_override("separation", 8)

		var upgrade_label = Label.new()
		upgrade_label.text = "Upgrade to Tier %d: %s" % [next_tier, cost_text]
		upgrade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_row.add_child(upgrade_label)

		var upgrade_btn = Button.new()
		upgrade_btn.text = "Upgrade" if can_upgrade else "Cannot Afford"
		upgrade_btn.custom_minimum_size = Vector2(100, 28)
		upgrade_btn.disabled = not can_upgrade
		upgrade_btn.pressed.connect(_on_facility_upgrade_pressed.bind(town_id, facility_id))
		upgrade_row.add_child(upgrade_btn)

		_facility_actions_container.add_child(upgrade_row)

	# Show run stash resources
	var run_gold = GameContext.get_run_gold()
	var run_items = GameContext.get_run_items_dict()

	var gold_label = Label.new()
	gold_label.text = "Banked Gold: %d" % run_gold
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	var materials_label = Label.new()
	if run_items.is_empty():
		materials_label.text = "Banked Materials: (none)"
	else:
		var mat_parts: Array[String] = []
		for item_id in run_items.keys():
			var template = DataRegistry.get_item_template(item_id)
			var mat_name = template.display_name if template != null and template.display_name != "" else item_id
			mat_parts.append("%s x%d" % [mat_name, run_items[item_id]])
		materials_label.text = "Banked: %s" % ", ".join(mat_parts)
	materials_label.modulate = Color(0.8, 0.9, 1, 1)
	_facility_actions_container.add_child(materials_label)

	# Unlocks section (group-based unlocks)
	# Filter by required_tier, required_town_tier, required_dungeon_floor_unlocked
	# Exclude already-unlocked groups
	var all_unlocks = _current_facility.unlocks if _current_facility != null else []
	var unlocks: Array = []
	var gated_count = 0
	for unlock in all_unlocks:
		var unlock_group = unlock.get("unlock_group", "")
		var required_tier = unlock.get("required_tier", 1)
		var required_town_tier = unlock.get("required_town_tier", 1)
		var required_floor = unlock.get("required_dungeon_floor_unlocked", 1)

		# Skip if group already unlocked (including defaults)
		if GameContext.has_unlocked_group(unlock_group):
			continue
		# Skip unlocks requiring higher facility tier
		if required_tier > current_tier:
			gated_count += 1
			continue
		# Check town tier gating (optional - if > 1)
		if required_town_tier > 1:
			if not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
				var have = GameContext.get_town_tier(town_id)
				print("[Gate] unlock=%s reason=town_tier required=%d have=%d" % [unlock_group, required_town_tier, have])
				gated_count += 1
				continue
		# Check dungeon floor gating (optional - if > 1)
		if required_floor > 1:
			# Use current dungeon or first available dungeon in town
			var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
			var dungeon_id = town.dungeon_id if town != null else ""
			if not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
				var have = GameContext.get_unlocked_floor(dungeon_id)
				print("[Gate] unlock=%s reason=dungeon_floor required=%d have=%d dungeon=%s" % [unlock_group, required_floor, have, dungeon_id])
				gated_count += 1
				continue
		unlocks.append(unlock)

	if gated_count > 0:
		print("[Unlock] shown=%d gated=%d total=%d" % [unlocks.size(), gated_count, all_unlocks.size()])

	if unlocks.size() > 0:
		var unlocks_header = Label.new()
		unlocks_header.text = "-- Unlocks --"
		unlocks_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlocks_header.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(unlocks_header)

		for unlock in unlocks:
			var row = _create_unlock_row(unlock)
			_facility_actions_container.add_child(row)
	else:
		var no_unlocks = Label.new()
		no_unlocks.text = "(No unlocks available at this tier)"
		no_unlocks.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_unlocks)


func _build_shop_ui() -> void:
	# Header
	var header = Label.new()
	header.text = "=== General Store ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No shop available)"
		no_data.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_data)
		return

	# Show run stash gold (shop uses banked gold)
	var gold_label = Label.new()
	gold_label.text = "Banked Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Current stash capacity bonus
	var capacity_bonus = GameContext.bonus_stash_capacity
	var capacity_label = Label.new()
	capacity_label.text = "Stash Bonus: +%d" % capacity_bonus
	capacity_label.modulate = Color(0.5, 1, 0.5, 1) if capacity_bonus > 0 else Color(0.6, 0.6, 0.6, 1)
	_facility_actions_container.add_child(capacity_label)

	# Get context for seeded RNG
	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)
	var max_tier = GameContext.get_facility_max_tier(facility_id)

	# Tier display
	var tier_label = Label.new()
	tier_label.text = "Store Tier: %d / %d" % [current_tier, max_tier]
	tier_label.modulate = Color(0.8, 0.9, 1.0, 1)
	_facility_actions_container.add_child(tier_label)

	# Upgrade section (if not at max tier)
	if current_tier < max_tier:
		var next_tier = current_tier + 1
		var cost = GameContext.get_facility_upgrade_cost(facility_id, next_tier)
		var can_upgrade = GameContext.can_afford_facility_upgrade(cost)

		# Format cost text
		var cost_parts: Array[String] = []
		var gold_cost = cost.get("gold", 0)
		if gold_cost > 0:
			cost_parts.append("%d gold" % gold_cost)
		var items_cost = cost.get("items", [])
		for item in items_cost:
			var item_id = item.get("item_id", "")
			var qty = item.get("qty", 1)
			var item_name = item_id
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null and tpl.display_name != "":
				item_name = tpl.display_name
			cost_parts.append("%s x%d" % [item_name, qty])

		var cost_text = ", ".join(cost_parts) if cost_parts.size() > 0 else "Free"

		var upgrade_row = HBoxContainer.new()
		upgrade_row.add_theme_constant_override("separation", 8)

		var upgrade_label = Label.new()
		upgrade_label.text = "Upgrade to Tier %d: %s" % [next_tier, cost_text]
		upgrade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_row.add_child(upgrade_label)

		var upgrade_btn = Button.new()
		upgrade_btn.text = "Upgrade" if can_upgrade else "Cannot Afford"
		upgrade_btn.custom_minimum_size = Vector2(100, 28)
		upgrade_btn.disabled = not can_upgrade
		upgrade_btn.pressed.connect(_on_facility_upgrade_pressed.bind(town_id, facility_id))
		upgrade_row.add_child(upgrade_btn)

		_facility_actions_container.add_child(upgrade_row)

	# Separator before shop items
	var tier_sep = HSeparator.new()
	_facility_actions_container.add_child(tier_sep)
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var dungeon_id = town.dungeon_id if town != null else ""
	var shop_id = _current_facility_id
	var town_tier = GameContext.get_town_tier(town_id)
	var highest_floor = GameContext.get_unlocked_floor(dungeon_id) if dungeon_id != "" else 1
	var refresh_count = GameContext.get_shop_refresh_count(shop_id)

	# Get shop profile for town-unique inventory
	var shop_profile = _current_facility.shop_profile
	var profile_id = shop_profile.get("profile_id", "default") if shop_profile else "default"

	# Generate deterministic seed including refresh count
	var seed_str = "%s_%s_%d_%d_%d" % [town_id, shop_id, town_tier, highest_floor, refresh_count]
	var shop_seed = seed_str.hash()
	var shop_rng = RandomNumberGenerator.new()
	shop_rng.seed = shop_seed

	print("[ShopRNG] shop=%s town=%s profile=%s refresh=%d" % [shop_id, town_id, profile_id, refresh_count])

	# Load pool data and generate inventory
	var unlocked_shop_items: Array = _generate_pool_inventory(shop_rng, town_id, dungeon_id)

	# Shop items section (items and locked placeholders)
	var has_items = false
	for entry in unlocked_shop_items:
		if entry.get("type", "item") == "item":
			has_items = true
			break

	if unlocked_shop_items.size() > 0:
		var shop_header = Label.new()
		shop_header.text = "-- Items for Sale --"
		shop_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_header.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(shop_header)

		for entry in unlocked_shop_items:
			var entry_type = entry.get("type", "item")
			if entry_type == "locked":
				# Show locked category placeholder
				var locked_row = HBoxContainer.new()
				locked_row.add_theme_constant_override("separation", 8)
				var locked_label = Label.new()
				var category = entry.get("category", "items")
				var reason = entry.get("reason", "Locked")
				locked_label.text = "(%s: %s)" % [category.capitalize(), reason]
				locked_label.modulate = Color(0.5, 0.5, 0.5, 1)
				locked_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				locked_row.add_child(locked_label)
				_facility_actions_container.add_child(locked_row)
			else:
				# Normal item row
				var row = _create_shop_row(entry)
				_facility_actions_container.add_child(row)
	else:
		var no_items = Label.new()
		no_items.text = "(No items for sale)"
		no_items.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_items)

	# Stash upgrades section
	var stash_upgrades = _current_facility.stash_upgrades
	if stash_upgrades.size() > 0:
		var sep = HSeparator.new()
		_facility_actions_container.add_child(sep)

		var upgrades_header = Label.new()
		upgrades_header.text = "-- Stash Upgrades --"
		upgrades_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrades_header.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(upgrades_header)

		for upgrade in stash_upgrades:
			var row = _create_stash_upgrade_row(upgrade)
			_facility_actions_container.add_child(row)

	# Sell Items section (from run stash)
	var sell_sep = HSeparator.new()
	_facility_actions_container.add_child(sell_sep)

	var sell_header = Label.new()
	sell_header.text = "-- Sell Items --"
	sell_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sell_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(sell_header)

	var sellable_items = _get_sellable_stash_items()
	if sellable_items.size() == 0:
		var no_sell = Label.new()
		no_sell.text = "(No items to sell)"
		no_sell.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_sell)
	else:
		for item in sellable_items:
			var row = _create_sell_item_row(item)
			_facility_actions_container.add_child(row)

	# Refresh Stock button with cost from Run Stash
	var refresh_sep = HSeparator.new()
	_facility_actions_container.add_child(refresh_sep)

	var refresh_row = HBoxContainer.new()
	refresh_row.add_theme_constant_override("separation", 8)

	var refresh_cost = GameContext.get_shop_refresh_cost(shop_id)
	var can_afford_refresh = GameContext.can_afford_shop_refresh(shop_id)

	var refresh_label = Label.new()
	refresh_label.text = "Refresh stock for new items"
	refresh_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_label.modulate = Color(0.7, 0.7, 0.7, 1)
	refresh_row.add_child(refresh_label)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh (%dg)" % refresh_cost
	refresh_btn.custom_minimum_size = Vector2(100, 26)
	refresh_btn.disabled = not can_afford_refresh
	refresh_btn.pressed.connect(_on_shop_refresh_pressed.bind(shop_id))
	if not can_afford_refresh:
		refresh_btn.tooltip_text = "Not enough gold"
	refresh_row.add_child(refresh_btn)

	_facility_actions_container.add_child(refresh_row)


## Generate shop inventory from pool data using weighted random selection.
## Uses shop_profile for town-unique category rolls and weight multipliers.
## Returns array of: { "type": "item", ...item_data } or { "type": "locked", "category": cat, "reason": reason }
func _generate_pool_inventory(rng: RandomNumberGenerator, town_id: String, dungeon_id: String) -> Array:
	var result: Array = []

	# Get pool ID and shop rolls from FacilityData
	var pool_id = _current_facility.shop_pool_id
	var base_shop_rolls = _current_facility.shop_rolls
	var shop_profile = _current_facility.shop_profile

	# Extract profile settings (town-unique)
	var rolls_override: Dictionary = shop_profile.get("rolls_override", {}) if shop_profile else {}
	var category_weight_mult: Dictionary = shop_profile.get("category_weight_mult", {}) if shop_profile else {}

	if pool_id == "":
		print("[ShopRNG] No pool_id configured, using legacy shop_items")
		# Fallback to legacy shop_items_legacy
		var legacy_items = _current_facility.shop_items_legacy
		var facility_id = _current_facility.facility_id if _current_facility != null else ""
		return _filter_legacy_items(legacy_items, town_id, dungeon_id, facility_id)

	# Load pool JSON
	var pool_data = _load_shop_pool(pool_id)
	if pool_data.is_empty():
		print("[ShopRNG] Failed to load pool: %s" % pool_id)
		return result

	# Extract weight_by_tier from pool (for tier-based weight multipliers)
	var weight_by_tier: Dictionary = pool_data.get("weight_by_tier", {})

	# Determine which categories to process (union of base rolls and overrides)
	var categories_to_process: Array = []
	for cat in base_shop_rolls.keys():
		if cat not in categories_to_process:
			categories_to_process.append(cat)
	for cat in rolls_override.keys():
		if cat not in categories_to_process:
			categories_to_process.append(cat)

	# Process each category
	for category in categories_to_process:
		# Use rolls_override if present, otherwise base_shop_rolls
		var roll_count: int = 0
		if rolls_override.has(category):
			roll_count = int(rolls_override[category])
		elif base_shop_rolls.has(category):
			roll_count = int(base_shop_rolls[category])

		if roll_count <= 0:
			continue

		var category_pool = pool_data.get(category, [])
		if category_pool.size() == 0:
			print("[ShopRNG] category=%s candidates=0 picked=[] rolls=%d (empty pool)" % [category, roll_count])
			continue

		# Filter candidates by unlock/gates BEFORE selection, track gate reasons
		var filter_result = _filter_pool_candidates_with_reason(category_pool, town_id, dungeon_id)
		var candidates = filter_result.candidates
		var gate_reasons = filter_result.gate_reasons

		if candidates.size() == 0:
			# All items gated - add a "(Locked)" placeholder
			var reason = gate_reasons[0] if gate_reasons.size() > 0 else "No stock"
			print("[ShopRNG] category=%s candidates=0 picked=[] rolls=%d (all gated: %s)" % [category, roll_count, reason])
			result.append({"type": "locked", "category": category, "reason": reason})
			continue

		# Get category weight multiplier from shop profile (town-unique selection bias)
		var cat_weight_mult: float = category_weight_mult.get(category, 1.0) if category_weight_mult else 1.0

		# Pick items using weighted random with tier multipliers and category multiplier
		var picked = _weighted_pick_with_tier(rng, candidates, roll_count, weight_by_tier, cat_weight_mult)

		var picked_ids: Array = []
		for item in picked:
			picked_ids.append(item.get("item_id", "?"))
			# Mark as item type for UI rendering
			var item_copy = item.duplicate()
			item_copy["type"] = "item"
			result.append(item_copy)

		print("[ShopRNG] category=%s rolls=%d candidates=%d picked=%s" % [
			category, roll_count, candidates.size(), str(picked_ids)
		])

	return result


## Load shop pool JSON file.
func _load_shop_pool(pool_id: String) -> Dictionary:
	var pool_path = "res://Data/Shops/Pools/%s.json" % pool_id
	if not FileAccess.file_exists(pool_path):
		push_warning("[ShopRNG] Pool file not found: %s" % pool_path)
		return {}

	var file = FileAccess.open(pool_path, FileAccess.READ)
	if file == null:
		push_warning("[ShopRNG] Failed to open pool file: %s" % pool_path)
		return {}

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		push_warning("[ShopRNG] Failed to parse pool JSON: %s" % pool_path)
		return {}

	var data = json.get_data()
	return data if data is Dictionary else {}


## Filter pool candidates by unlock groups and progression gating.
## Returns { candidates: Array, gate_reasons: Array } where gate_reasons are human-readable strings.
func _filter_pool_candidates_with_reason(pool: Array, town_id: String, dungeon_id: String) -> Dictionary:
	var candidates: Array = []
	var gate_reasons: Array = []

	for item in pool:
		var item_id = item.get("item_id", "")
		var requires_group = item.get("requires_unlock_group", "")
		var required_town_tier = item.get("required_town_tier", 1)
		var required_floor = item.get("required_dungeon_floor_unlocked", 1)

		# Check unlock group requirement
		if requires_group != "" and not GameContext.has_unlocked_group(requires_group):
			print("[Gate] item=%s reason=unlock_group required=%s" % [item_id, requires_group])
			gate_reasons.append("Unlock: %s" % requires_group)
			continue

		# Check town tier gating
		if required_town_tier > 1:
			if not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
				var have = GameContext.get_town_tier(town_id)
				print("[Gate] item=%s reason=town_tier required=%d have=%d" % [item_id, required_town_tier, have])
				gate_reasons.append("Town tier %d required" % required_town_tier)
				continue

		# Check dungeon floor gating
		if required_floor > 1:
			if not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
				var have = GameContext.get_unlocked_floor(dungeon_id)
				print("[Gate] item=%s reason=dungeon_floor required=%d have=%d dungeon=%s" % [item_id, required_floor, have, dungeon_id])
				gate_reasons.append("Floor %d required" % required_floor)
				continue

		candidates.append(item)

	return { "candidates": candidates, "gate_reasons": gate_reasons }


## Legacy filter (for backwards compat).
func _filter_pool_candidates(pool: Array, town_id: String, dungeon_id: String) -> Array:
	return _filter_pool_candidates_with_reason(pool, town_id, dungeon_id).candidates


## Weighted random pick with tier-based and category weight multipliers.
## effective_weight = base_weight * tier_mult * category_weight_mult
## No duplicates unless pool < count (then duplicates allowed).
func _weighted_pick_with_tier(rng: RandomNumberGenerator, candidates: Array, count: int, weight_by_tier: Dictionary, cat_weight_mult: float) -> Array:
	var picked: Array = []
	var pool = candidates.duplicate()

	for i in range(count):
		if pool.size() == 0:
			# Pool exhausted, allow duplicates from original candidates
			if candidates.size() > 0:
				pool = candidates.duplicate()
				print("[ShopRNG] Pool exhausted, allowing duplicate")
			else:
				break

		# Calculate total weight with tier and category multipliers
		var total_weight = 0.0
		for item in pool:
			total_weight += _get_effective_weight(item, weight_by_tier, cat_weight_mult)

		if total_weight <= 0:
			break

		# Roll weighted random
		var roll = rng.randf() * total_weight
		var cumulative = 0.0
		var selected_idx = -1

		for j in range(pool.size()):
			cumulative += _get_effective_weight(pool[j], weight_by_tier, cat_weight_mult)
			if roll <= cumulative:
				selected_idx = j
				break

		if selected_idx >= 0:
			picked.append(pool[selected_idx])
			pool.remove_at(selected_idx)

	return picked


## Calculate effective weight: base_weight * tier_mult * category_weight_mult
## tier can be int, float, or string in JSON - handle all robustly.
func _get_effective_weight(item: Dictionary, weight_by_tier: Dictionary, cat_weight_mult: float) -> float:
	var base_weight = float(item.get("weight", 10))

	# Get tier from item (default 1), handle int/float/string
	var tier_raw = item.get("tier", 1)
	var tier_str = str(int(tier_raw))  # Normalize to string key

	# Get tier multiplier from weight_by_tier (default 1.0)
	var tier_mult = 1.0
	if weight_by_tier.has(tier_str):
		tier_mult = float(weight_by_tier[tier_str])
	elif weight_by_tier.has(int(tier_raw)):  # Also try int key
		tier_mult = float(weight_by_tier[int(tier_raw)])

	return base_weight * tier_mult * cat_weight_mult


## Legacy weighted pick (for backwards compat).
func _weighted_pick(rng: RandomNumberGenerator, candidates: Array, count: int) -> Array:
	return _weighted_pick_with_tier(rng, candidates, count, {}, 1.0)


## Filter legacy shop items (fallback when no pool configured).
func _filter_legacy_items(items: Array, town_id: String, dungeon_id: String, facility_id: String = "") -> Array:
	var result: Array = []
	var facility_tier = 1
	if facility_id != "":
		facility_tier = GameContext.get_facility_tier(town_id, facility_id)

	for item in items:
		var item_id = item.get("item_id", "")
		var requires_group = item.get("requires_unlock_group", "")
		var required_town_tier = item.get("required_town_tier", 1)
		var required_floor = item.get("required_dungeon_floor_unlocked", 1)
		var required_facility_tier = item.get("required_facility_tier", 1)

		if requires_group != "" and not GameContext.has_unlocked_group(requires_group):
			continue
		if required_town_tier > 1 and not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
			continue
		if required_floor > 1 and not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
			continue
		if required_facility_tier > facility_tier:
			print("[Gate] item=%s reason=facility_tier required=%d have=%d" % [item_id, required_facility_tier, facility_tier])
			continue

		result.append(item)

	return result


## Handle shop refresh button press - spends gold and regenerates inventory.
func _on_shop_refresh_pressed(shop_id: String) -> void:
	var success = GameContext.spend_shop_refresh(shop_id)
	if success:
		_refresh_facility_panel()
	# If failed, button should have been disabled - just refresh UI to sync state
	else:
		_refresh_facility_panel()


func _create_shop_row(shop_item: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = shop_item.get("item_id", "")
	var price = shop_item.get("price_gold", 0)

	# Get display name from template
	var display_name = item_id
	var template = DataRegistry.get_item_template(item_id) if DataRegistry.has_method("get_item_template") else null
	if template != null and template.display_name != "":
		display_name = template.display_name

	# Item name label
	var name_label = Label.new()
	name_label.text = "%s (%d gold)" % [display_name, price]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Buy button (uses run stash gold)
	var can_afford = GameContext.get_run_gold() >= price
	var btn = Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(60, 26)
	btn.disabled = not can_afford
	btn.pressed.connect(_on_shop_buy_pressed.bind(item_id, price))
	row.add_child(btn)

	return row


func _on_shop_buy_pressed(item_id: String, price: int) -> void:
	var had_gold = GameContext.get_run_gold()
	if had_gold < price:
		print("[Store] buy item=%s qty=1 cost=%d gold_before=%d gold_after=FAIL (insufficient)" % [item_id, price, had_gold])
		return

	GameContext.spend_run_gold(price)
	GameContext.add_run_item(item_id, 1)
	print("[Store] buy item=%s qty=1 cost=%d gold_before=%d gold_after=%d" % [item_id, price, had_gold, GameContext.get_run_gold()])
	_refresh_facility_panel()


## Get sellable items from run stash (excludes books for now).
func _get_sellable_stash_items() -> Array:
	var result: Array = []
	var aggregated: Dictionary = {}

	for item in GameContext.run_items:
		var template_id := ""
		var quality_tier := 0
		var display_name := ""
		var qty := 1

		if item is ItemInstance:
			template_id = item.template_id
			quality_tier = item.quality_tier
			display_name = item.display_name
			qty = item.quantity
		elif item is Dictionary:
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
			var tpl = DataRegistry.get_item_template(template_id)
			if tpl != null:
				display_name = tpl.display_name
			else:
				display_name = template_id
		else:
			continue

		# Skip books (not sellable)
		if template_id.begins_with("book_"):
			continue

		var key = "%s:%d" % [template_id, quality_tier]
		if aggregated.has(key):
			aggregated[key].qty += qty
		else:
			var category = _get_item_category(template_id)
			aggregated[key] = {
				"template_id": template_id,
				"quality_tier": quality_tier,
				"qty": qty,
				"display_name": display_name,
				"category": category
			}

	for key in aggregated.keys():
		result.append(aggregated[key])

	# Sort by category: materials first, then equipment, then consumables
	result.sort_custom(_sort_stash_items_by_category)

	return result


## Create a row for selling an item.
func _create_sell_item_row(item: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var template_id = item.template_id
	var qty = item.qty
	var quality_tier = item.quality_tier
	var display_name = item.display_name

	# Get sell price from template with quality multiplier
	var sell_price: int = 1  # Minimum fallback
	var base_price: int = 1
	var quality_mult: float = 1.0
	var tpl = DataRegistry.get_item_template(template_id)
	if tpl != null:
		base_price = tpl.base_value
		# Apply quality multiplier for equipment (same as ItemTemplate.QUALITY_MULTIPLIERS)
		if tpl.equip_slot != "" and quality_tier > 0:
			var quality_mults = [1.0, 1.1, 1.2, 1.35]
			var q_idx = clampi(quality_tier, 0, quality_mults.size() - 1)
			quality_mult = quality_mults[q_idx]
		sell_price = int(base_price * quality_mult)
		# Debug logging (rate-limited by only logging when creating UI row)
		if quality_tier > 0:
			print("[Economy] sell_price item=%s q=%d base=%d mult=%.2f final=%d" % [template_id, quality_tier, base_price, quality_mult, sell_price])

	# Quality prefix if applicable
	var q_prefix = ""
	if quality_tier > 0:
		q_prefix = "[Q%d] " % quality_tier

	# Item label
	var label = Label.new()
	label.text = "%s%s x%d" % [q_prefix, display_name, qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Price label
	var price_label = Label.new()
	price_label.text = "%dg ea" % sell_price
	price_label.modulate = Color(0.8, 0.8, 0.5, 1)
	row.add_child(price_label)

	# Sell 1 button
	var sell_btn = Button.new()
	sell_btn.text = "Sell 1"
	sell_btn.custom_minimum_size = Vector2(60, 24)
	sell_btn.pressed.connect(_on_sell_item_pressed.bind(template_id, 1, sell_price))
	row.add_child(sell_btn)

	# Sell All button (if qty > 1)
	if qty > 1:
		var sell_all_btn = Button.new()
		sell_all_btn.text = "Sell All"
		sell_all_btn.custom_minimum_size = Vector2(70, 24)
		sell_all_btn.pressed.connect(_on_sell_item_pressed.bind(template_id, qty, sell_price))
		row.add_child(sell_all_btn)

	return row


## Handle sell item button press.
func _on_sell_item_pressed(template_id: String, qty: int, unit_price: int) -> void:
	var gold_before = GameContext.get_run_gold()
	var total_gain = unit_price * qty

	# Remove items from stash
	var removed = GameContext.remove_run_item(template_id, qty)
	if removed == 0:
		print("[Store] sell item=%s qty=%d gain=0 gold_before=%d gold_after=FAIL (no items)" % [template_id, qty, gold_before])
		_refresh_facility_panel()
		return

	# Add gold
	GameContext.add_run_gold(total_gain)
	var gold_after = GameContext.get_run_gold()

	print("[Store] sell item=%s qty=%d gain=%d gold_before=%d gold_after=%d" % [template_id, removed, total_gain, gold_before, gold_after])
	GameContext.save_game()
	_refresh_facility_panel()


func _create_stash_upgrade_row(upgrade: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var upgrade_id = upgrade.get("upgrade_id", "")
	var display_name = upgrade.get("display_name", upgrade_id)
	var price = upgrade.get("price_gold", 0)
	var bonus_value = upgrade.get("bonus_value", 0)
	var is_purchased = GameContext.has_housing_upgrade(upgrade_id)
	var can_afford = GameContext.get_run_gold() >= price

	# Upgrade label
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_purchased:
		label.text = "%s (Owned)" % display_name
		label.modulate = Color(0.5, 1, 0.5, 1)
	else:
		label.text = "%s (%d gold)" % [display_name, price]
	row.add_child(label)

	# Purchase button
	if not is_purchased:
		var btn = Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(60, 26)
		btn.disabled = not can_afford
		btn.pressed.connect(_on_stash_upgrade_pressed.bind(upgrade_id, price, bonus_value))
		row.add_child(btn)

	return row


func _on_stash_upgrade_pressed(upgrade_id: String, price: int, bonus_value: int) -> void:
	if GameContext.purchase_housing_upgrade(upgrade_id, price, "stash_capacity", bonus_value):
		print("[Shop] stash_upgrade=%s cost=%d bonus=%d success=true" % [upgrade_id, price, bonus_value])
	_refresh_facility_panel()


func _build_alchemist_ui() -> void:
	_build_unlock_ui("Alchemist")


func _build_blacksmith_ui() -> void:
	_build_unlock_ui("Blacksmith")

	# Add crafting recipes section
	if _current_facility == null:
		return

	var crafting_recipes = _current_facility.crafting_recipes
	if crafting_recipes.size() == 0:
		return

	# Get current facility tier
	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# Facilities v4: Separate recipes into available and locked
	var available_recipes: Array = []
	var locked_recipes: Array = []
	for recipe in crafting_recipes:
		var required_tier = recipe.get("required_tier", 1)
		if required_tier <= current_tier:
			available_recipes.append(recipe)
		else:
			locked_recipes.append(recipe)

	# Separator and header
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var craft_header = Label.new()
	craft_header.text = "-- Crafting (Tier %d / %d) --" % [current_tier, _current_facility.max_tier]
	craft_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(craft_header)

	# Show available recipes
	if available_recipes.size() == 0:
		var no_recipes = Label.new()
		no_recipes.text = "(No recipes available at this tier)"
		no_recipes.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_recipes)
	else:
		for recipe in available_recipes:
			var recipe_row = _create_crafting_recipe_row(recipe)
			_facility_actions_container.add_child(recipe_row)

	# Facilities v4: Show locked recipes as grayed-out rows
	for recipe in locked_recipes:
		var locked_row = _create_locked_recipe_row(recipe)
		_facility_actions_container.add_child(locked_row)

	print("[Blacksmith] tier=%d recipes_shown=%d recipes_locked=%d" % [current_tier, available_recipes.size(), locked_recipes.size()])


func _create_crafting_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var output_id = recipe.get("output_id", "")
	var output_qty = recipe.get("output_qty", 1)
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Recipe name
	var name_label = Label.new()
	if output_qty > 1:
		name_label.text = "Craft: %s x%d" % [output_name, output_qty]
	else:
		name_label.text = "Craft: %s" % output_name
	container.add_child(name_label)

	# Cost display (materials from run stash)
	var cost_parts = []
	var run_items_dict = GameContext.get_run_items_dict()
	var can_afford = true

	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	cost_label.text = "  Materials: %s" % ", ".join(cost_parts)
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	container.add_child(cost_label)

	# v2: Gold cost display (if any)
	if cost_gold > 0:
		var current_gold = GameContext.get_run_gold()
		var gold_label = Label.new()
		gold_label.text = "  Gold: %d / %d" % [current_gold, cost_gold]
		if current_gold < cost_gold:
			gold_label.modulate = Color(1, 0.5, 0.5, 1)
			can_afford = false
		else:
			gold_label.modulate = Color(0.8, 0.8, 0.8, 1)
		container.add_child(gold_label)

	# Craft button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 28)
	if can_afford:
		btn.text = "Craft"
		btn.disabled = false
		btn.pressed.connect(_on_craft_recipe_pressed.bind(recipe))
	else:
		btn.text = "Missing Materials"
		btn.disabled = true
	container.add_child(btn)

	return container


## Facilities v4: Create a grayed-out row for a locked recipe.
func _create_locked_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.modulate = Color(0.5, 0.5, 0.5, 1)  # Gray out

	var output_id = recipe.get("output_id", "")
	var required_tier = recipe.get("required_tier", 1)
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Locked header label
	var name_label = Label.new()
	name_label.text = "Locked (Tier %d): %s" % [required_tier, output_name]
	name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	container.add_child(name_label)

	# Cost display (grayed, for preview)
	var cost_parts = []
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name
		cost_parts.append("%s x%d" % [item_name, qty_needed])

	var cost_label = Label.new()
	var cost_text = "  Cost: %s" % ", ".join(cost_parts)
	if cost_gold > 0:
		cost_text += " + %dg" % cost_gold
	cost_label.text = cost_text
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	container.add_child(cost_label)

	return container


func _on_craft_recipe_pressed(recipe: Dictionary) -> void:
	var output_id = recipe.get("output_id", "")
	var output_qty = recipe.get("output_qty", 1)
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Verify gold cost
	if cost_gold > 0 and GameContext.get_run_gold() < cost_gold:
		print("[Blacksmith] craft_failed item=%s reason=insufficient_gold need=%d have=%d" % [output_id, cost_gold, GameContext.get_run_gold()])
		return

	# Verify materials and consume
	var run_items_dict = GameContext.get_run_items_dict()
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		if qty_have < qty_needed:
			print("[Blacksmith] craft_failed item=%s reason=missing_%s need=%d have=%d" % [output_id, item_id, qty_needed, qty_have])
			return

	# Consume gold (if any)
	if cost_gold > 0:
		GameContext.spend_run_gold(cost_gold)

	# Consume materials
	var consumed_parts = []
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		GameContext.remove_run_item(item_id, qty_needed)
		consumed_parts.append("%s=%d" % [item_id, qty_needed])

	# Add crafted item to stash
	GameContext.add_run_item(output_id, output_qty)

	print("[Blacksmith] craft item=%s qty=%d consumed=[%s] gold_spent=%d" % [output_id, output_qty, ", ".join(consumed_parts), cost_gold])

	# Refresh UI
	_refresh_facility_panel()


func _create_unlock_row(unlock: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Get unlock group info
	var unlock_group = unlock.get("unlock_group", "")
	var is_unlocked = GameContext.has_unlocked_group(unlock_group)

	# Unlock label with status
	var name_label = Label.new()
	var display_label = unlock.get("label", "Unlock %s" % unlock_group)
	name_label.text = display_label
	if is_unlocked:
		name_label.modulate = Color(0.5, 1, 0.5, 1)
	container.add_child(name_label)

	# Cost display (from run stash materials)
	var costs = unlock.get("costs", [])
	var cost_parts = []
	var run_items_dict = GameContext.get_run_items_dict()
	var debug_have: Dictionary = {}
	for cost_item in costs:
		var item_id = cost_item.get("item_id", "")
		var qty_needed = cost_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		debug_have[item_id] = qty_have
		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name
		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])

	var cost_label = Label.new()
	cost_label.text = "  Cost: %s" % ", ".join(cost_parts) if cost_parts.size() > 0 else "  Cost: Free"
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1)
	container.add_child(cost_label)

	# Check if player can afford from run stash
	var can_afford = GameContext.can_afford_run_materials(costs)

	# Debug logging
	print("[UnlockDebug] unlock_group=%s cost=%s have=%s can_unlock=%s" % [unlock_group, str(costs), str(debug_have), str(can_afford)])

	# Unlock button with appropriate state
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 28)
	if is_unlocked:
		btn.text = "Unlocked"
		btn.disabled = true
		btn.modulate = Color(0.5, 1, 0.5, 1)
	elif can_afford:
		btn.text = "Unlock"
		btn.disabled = false
		btn.pressed.connect(_on_unlock_pressed.bind(unlock))
	else:
		btn.text = "Missing Materials"
		btn.disabled = true
	container.add_child(btn)

	return container


func _build_training_ui() -> void:
	var header = Label.new()
	header.text = "=== Training Hall ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No training hall data)"
		no_data.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_data)
		return

	# Show run stash gold
	var gold_label = Label.new()
	gold_label.text = "Banked Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Section 1: Hero Roster (select a hero to assign class)
	var roster_header = Label.new()
	roster_header.text = "-- Select Hero --"
	roster_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(roster_header)

	var owned_heroes = GameContext.get_owned_heroes()
	if owned_heroes.size() == 0:
		var no_heroes = Label.new()
		no_heroes.text = "(No heroes recruited - visit the Inn first!)"
		no_heroes.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_heroes)
	else:
		for hero in owned_heroes:
			var row = _create_training_hero_row(hero)
			_facility_actions_container.add_child(row)

	# Show selected hero indicator
	if _training_selected_hero_id != "":
		var selected_hero = GameContext.get_hero(_training_selected_hero_id)
		if not selected_hero.is_empty():
			var selected_label = Label.new()
			selected_label.text = "Selected: %s (%s %s)" % [
				selected_hero.get("name", "?"),
				selected_hero.get("race_id", "human").capitalize(),
				selected_hero.get("class_id", "none").capitalize()
			]
			selected_label.modulate = Color(0.5, 1, 0.5, 1)
			selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_facility_actions_container.add_child(selected_label)

	# Separator
	var sep1 = HSeparator.new()
	_facility_actions_container.add_child(sep1)

	# Section 2: Books Owned (from stash) - assign to selected hero
	var books_header = Label.new()
	books_header.text = "-- Books Owned --"
	books_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	books_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(books_header)

	var stash_dict = GameContext.get_run_items_dict()
	var owned_books: Array = []
	for book_id in GameContext.BOOK_TO_CLASS_MAP.keys():
		var qty = stash_dict.get(book_id, 0)
		if qty > 0:
			owned_books.append({ "book_id": book_id, "qty": qty })

	if owned_books.size() == 0:
		var no_books = Label.new()
		no_books.text = "(No books in stash - buy some below!)"
		no_books.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_books)
	else:
		for book_data in owned_books:
			var row = _create_book_assign_row(book_data.book_id, book_data.qty)
			_facility_actions_container.add_child(row)

	# Separator
	var sep2 = HSeparator.new()
	_facility_actions_container.add_child(sep2)

	# Section 3: Books for Sale
	var shop_header = Label.new()
	shop_header.text = "-- Books for Sale --"
	shop_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(shop_header)

	# Filter shop items by unlock groups + optional progression gating (Class Books)
	var all_shop_items = _current_facility.shop_items if _current_facility != null else []
	var unlocked_shop_items: Array = []
	var locked_count = 0
	var gated_count = 0
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var dungeon_id = town.dungeon_id if town != null else ""
	var current_region = GameContext.get_current_region()

	for shop_item in all_shop_items:
		var item_id = shop_item.get("item_id", "")
		var requires_group = shop_item.get("requires_unlock_group", "")
		var required_town_tier = shop_item.get("required_town_tier", 1)
		var required_floor = shop_item.get("required_dungeon_floor_unlocked", 1)

		# Check class unlock_region for books (must be <= current_region)
		var class_id = GameContext.get_class_for_book(item_id)
		if class_id != "":
			var class_data = DataRegistry.get_class_data(class_id)
			if class_data != null and class_data.unlock_region > current_region:
				print("[TrainingHall] gated_book item=%s class=%s reason=unlock_region required=%d have=%d" % [
					item_id, class_id, class_data.unlock_region, current_region
				])
				gated_count += 1
				continue

		# Check unlock group requirement
		if not GameContext.has_unlocked_group(requires_group):
			locked_count += 1
			continue

		# Check town tier gating (optional - if > 1)
		if required_town_tier > 1:
			if not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
				var have = GameContext.get_town_tier(town_id)
				print("[Gate] item=%s reason=town_tier required=%d have=%d" % [item_id, required_town_tier, have])
				gated_count += 1
				continue

		# Check dungeon floor gating (optional - if > 1)
		if required_floor > 1:
			if not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
				var have = GameContext.get_unlocked_floor(dungeon_id)
				print("[Gate] item=%s reason=dungeon_floor required=%d have=%d dungeon=%s" % [item_id, required_floor, have, dungeon_id])
				gated_count += 1
				continue

		unlocked_shop_items.append(shop_item)

	print("[TrainingHall] shown=%d locked=%d gated=%d total=%d" % [unlocked_shop_items.size(), locked_count, gated_count, all_shop_items.size()])

	if unlocked_shop_items.size() > 0:
		for shop_item in unlocked_shop_items:
			var row = _create_shop_row(shop_item)
			_facility_actions_container.add_child(row)
	else:
		var no_items = Label.new()
		no_items.text = "(No books available for purchase)"
		no_items.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_items)


## Create a hero row for Training Hall roster (Name + Race + Class + Select button)
func _create_training_hero_row(hero: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var hero_id = hero.get("hero_id", "")
	var hero_name = hero.get("name", hero_id)
	var race_id = hero.get("race_id", "human")
	var class_id = hero.get("class_id", "none")
	var is_selected = (hero_id == _training_selected_hero_id)

	# Label: Name (Race Class)
	var label = Label.new()
	label.text = "%s (%s %s)" % [hero_name, race_id.capitalize(), class_id.capitalize()]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_selected:
		label.modulate = Color(0.5, 1, 0.5, 1)
	row.add_child(label)

	# Select button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 26)
	if is_selected:
		btn.text = "Selected"
		btn.disabled = true
		btn.modulate = Color(0.5, 1, 0.5, 1)
	else:
		btn.text = "Select"
		btn.pressed.connect(_on_training_select_hero_pressed.bind(hero_id))
	row.add_child(btn)

	return row


## Create a book row for assigning class to selected hero
func _create_book_assign_row(book_id: String, qty: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var class_id = GameContext.get_class_for_book(book_id)

	# Get display name from item template
	var display_name = book_id
	var tpl = DataRegistry.get_item_template(book_id)
	if tpl != null and tpl.display_name != "":
		display_name = tpl.display_name

	# Label: book name x qty
	var label = Label.new()
	label.text = "%s x%d" % [display_name, qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Assign button - depends on selected hero state
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 26)

	if _training_selected_hero_id == "":
		# No hero selected
		btn.text = "Select a hero"
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6, 1)
	else:
		# Hero selected - check if already has this class
		var selected_hero = GameContext.get_hero(_training_selected_hero_id)
		var hero_class = selected_hero.get("class_id", "none")

		if hero_class == class_id:
			btn.text = "Already %s" % class_id.capitalize()
			btn.disabled = true
			btn.modulate = Color(0.5, 1, 0.5, 1)
		elif hero_class == "none" or hero_class == "":
			btn.text = "Assign %s" % class_id.capitalize()
			btn.pressed.connect(_on_assign_book_pressed.bind(book_id))
		else:
			btn.text = "Change to %s" % class_id.capitalize()
			btn.pressed.connect(_on_assign_book_pressed.bind(book_id))

	row.add_child(btn)

	return row


func _on_training_select_hero_pressed(hero_id: String) -> void:
	_training_selected_hero_id = hero_id
	var hero = GameContext.get_hero(hero_id)
	print("[TrainingHall] selected hero=%s name=%s class=%s" % [
		hero_id, hero.get("name", "?"), hero.get("class_id", "none")
	])
	_refresh_facility_panel()


func _on_assign_book_pressed(book_id: String) -> void:
	if _training_selected_hero_id == "":
		print("[TrainingHall] assign failed - no hero selected")
		return

	var success = GameContext.assign_class_from_book(_training_selected_hero_id, book_id)
	# Logging is handled by GameContext.assign_class_from_book
	_refresh_facility_panel()


# ============================================================================
# HEROES SECTION (Main Town View - Minimal Party Summary + Visit Inn)
# ============================================================================

func _populate_heroes_section() -> void:
	# Clear existing dynamic content
	for child in heroes_vbox.get_children():
		child.queue_free()

	var party = GameContext.get_selected_party()
	var roster_size = GameContext.get_roster().size()

	# Party summary line
	var summary_label = Label.new()
	summary_label.text = "Party: %d / %d  |  Roster: %d  |  Gold: %d" % [
		party.size(), GameContext.MAX_PARTY_SIZE, roster_size, GameContext.get_player_gold()
	]
	summary_label.modulate = Color(0.5, 1, 0.5, 1) if party.size() > 0 else Color(0.8, 0.8, 0.8, 1)
	heroes_vbox.add_child(summary_label)

	# Compact party member names
	if party.size() > 0:
		for hero_id in party:
			var hero = GameContext.get_hero(hero_id)
			if hero.is_empty():
				continue
			var hero_name = hero.get("name", hero_id)
			var class_id = hero.get("class_id", "")
			var cls_name = class_id.capitalize()
			var class_data = DataRegistry.get_class_data(class_id)
			if class_data != null and class_data.display_name != "":
				cls_name = class_data.display_name
			var member_label = Label.new()
			member_label.text = "  %s (%s)" % [hero_name, cls_name]
			member_label.modulate = Color(0.6, 1, 0.6, 1)
			member_label.add_theme_font_size_override("font_size", 13)
			heroes_vbox.add_child(member_label)
	else:
		var empty_label = Label.new()
		empty_label.text = "  (No party selected - visit Inn to recruit)"
		empty_label.modulate = Color(0.6, 0.6, 0.6, 1)
		heroes_vbox.add_child(empty_label)

	# "Visit Inn" button to open Inn facility popup
	var inn_btn = Button.new()
	inn_btn.text = "Visit Inn (Recruit / Party)"
	inn_btn.custom_minimum_size = Vector2(200, 30)
	inn_btn.pressed.connect(_on_visit_inn_pressed)
	heroes_vbox.add_child(inn_btn)


## Open the Inn facility popup from the main town view.
func _on_visit_inn_pressed() -> void:
	# Find the inn facility_id for this town
	var town_id = GameContext.get_current_town_id()
	var inn_id = ""
	if DataRegistry.has_method("get_facilities_for_town"):
		var facilities = DataRegistry.get_facilities_for_town(town_id)
		for fac in facilities:
			if fac.facility_type == "inn":
				inn_id = fac.facility_id
				break
	if inn_id == "":
		inn_id = "inn"  # Fallback to default inn ID
	_show_facility_panel(inn_id)


# ============================================================================
# INN UI (Hero Recruitment & Party Management)
# ============================================================================

func _build_inn_ui() -> void:
	print("[Inn] opened")

	var header = Label.new()
	header.text = "=== Wanderer's Rest Inn ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	# Get tier info
	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id if _current_facility != null else "inn"
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)
	var max_tier = _current_facility.max_tier if _current_facility != null else 2

	# Tier display
	var tier_label = Label.new()
	tier_label.text = "Tier %d / %d" % [current_tier, max_tier]
	tier_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(tier_label)

	# Upgrade section (if not at max tier)
	if current_tier < max_tier:
		var next_tier = current_tier + 1
		var cost = GameContext.get_facility_upgrade_cost(facility_id, next_tier)
		var can_upgrade = GameContext.can_afford_facility_upgrade(cost)

		# Format cost text with item display names
		var cost_parts: Array[String] = []
		var gold_cost = cost.get("gold", 0)
		if gold_cost > 0:
			cost_parts.append("%d gold" % gold_cost)
		var items_cost = cost.get("items", [])
		for item in items_cost:
			var item_id = item.get("item_id", "")
			var qty = item.get("qty", 1)
			var item_name = item_id
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null and tpl.display_name != "":
				item_name = tpl.display_name
			cost_parts.append("%s x%d" % [item_name, qty])

		var cost_text = ", ".join(cost_parts) if cost_parts.size() > 0 else "Free"

		var upgrade_row = HBoxContainer.new()
		upgrade_row.add_theme_constant_override("separation", 8)

		var upgrade_label = Label.new()
		upgrade_label.text = "Upgrade to Tier %d: %s" % [next_tier, cost_text]
		upgrade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_row.add_child(upgrade_label)

		var upgrade_btn = Button.new()
		upgrade_btn.text = "Upgrade" if can_upgrade else "Cannot Afford"
		upgrade_btn.custom_minimum_size = Vector2(100, 28)
		upgrade_btn.disabled = not can_upgrade
		upgrade_btn.pressed.connect(_on_facility_upgrade_pressed.bind(town_id, facility_id))
		upgrade_row.add_child(upgrade_btn)

		_facility_actions_container.add_child(upgrade_row)

	# Show run stash gold
	var gold_label = Label.new()
	gold_label.text = "Banked Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Section 1: Owned Heroes
	var owned_header = Label.new()
	owned_header.text = "-- Owned Heroes --"
	owned_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(owned_header)

	var owned_heroes = GameContext.get_owned_heroes()
	var selected_party = GameContext.get_selected_party()

	if owned_heroes.size() == 0:
		var no_heroes = Label.new()
		no_heroes.text = "(No heroes recruited yet)"
		no_heroes.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_heroes)
	else:
		for hero in owned_heroes:
			var row = _create_hero_row(hero, selected_party)
			_facility_actions_container.add_child(row)

	# Party status
	var party_label = Label.new()
	party_label.text = "Party: %d / %d" % [selected_party.size(), GameContext.MAX_PARTY_SIZE]
	party_label.modulate = Color(0.5, 1, 0.5, 1) if selected_party.size() > 0 else Color(0.8, 0.8, 0.8, 1)
	_facility_actions_container.add_child(party_label)

	# Separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Section 2: Recruit Candidates
	var recruit_header = Label.new()
	recruit_header.text = "-- Recruit Heroes --"
	recruit_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recruit_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(recruit_header)

	# Get recruit level from facility tier (reuse current_tier from above)
	var recruit_level = 1
	if _current_facility != null:
		var level_by_tier = _current_facility.recruit_level_by_tier
		if level_by_tier.has(str(current_tier)):
			recruit_level = int(level_by_tier[str(current_tier)])

	# Dynamic recruit candidates from DataRegistry (races + classes filtered by unlock_region)
	var current_region = GameContext.get_current_region()
	var candidates = _generate_inn_recruit_candidates(current_region, recruit_level)

	for candidate in candidates:
		var row = _create_recruit_row(candidate)
		_facility_actions_container.add_child(row)

	print("[Inn] owned=%d party=%d" % [owned_heroes.size(), selected_party.size()])


## Create a hero tile/card for the Inn UI.
## Displays: Name, Race, Class, Level, XP progress, and party controls.
func _create_hero_row(hero: Dictionary, selected_party: Array) -> PanelContainer:
	var hero_id = hero.get("hero_id", "")
	var race_id = hero.get("race_id", "human")
	var class_id = hero.get("class_id", "")
	var hero_name = hero.get("name", "Unknown")
	var hero_level = int(hero.get("level", 1))
	var hero_xp = int(hero.get("xp", 0))
	var in_party = hero_id in selected_party

	# Get display names from DataRegistry with fallback
	var race_name = race_id.capitalize()
	var race_data = DataRegistry.get_race(race_id)
	if race_data != null and race_data.display_name != "":
		race_name = race_data.display_name

	var cls_name = class_id.capitalize()
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data != null and class_data.display_name != "":
		cls_name = class_data.display_name

	# Create tile container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)

	# Add subtle border style based on party status
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 1) if not in_party else Color(0.1, 0.25, 0.1, 1)
	style.border_color = Color(0.3, 0.3, 0.3, 1) if not in_party else Color(0.3, 0.6, 0.3, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Main content HBox (info on left, buttons on right)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Info VBox (left side)
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name label (larger, bold-ish)
	var name_label = Label.new()
	name_label.text = hero_name
	name_label.add_theme_font_size_override("font_size", 16)
	if in_party:
		name_label.modulate = Color(0.6, 1, 0.6, 1)
	info_vbox.add_child(name_label)

	# Race label
	var race_label = Label.new()
	race_label.text = "Race: %s" % race_name
	race_label.modulate = Color(0.8, 0.8, 0.8, 1)
	info_vbox.add_child(race_label)

	# Class label
	var class_label = Label.new()
	class_label.text = "Class: %s" % cls_name
	class_label.modulate = Color(0.8, 0.8, 0.8, 1)
	info_vbox.add_child(class_label)

	# Level label
	var level_label = Label.new()
	level_label.text = "Lv: %d" % hero_level
	level_label.modulate = Color(0.7, 0.7, 0.9, 1)
	info_vbox.add_child(level_label)

	# XP progress label
	var xp_label = Label.new()
	if hero_level >= GameContext.MAX_HERO_LEVEL:
		xp_label.text = "XP: MAX"
		xp_label.modulate = Color(1.0, 0.85, 0.3, 1)  # Gold color for max
	else:
		var next_level_xp = GameContext.get_xp_for_level(hero_level + 1)
		xp_label.text = "XP: %d / %d" % [hero_xp, next_level_xp]
		xp_label.modulate = Color(0.6, 0.8, 0.6, 1)  # Light green
	info_vbox.add_child(xp_label)

	# NOTE: Only one HP label in Inn row; always authoritative.
	# In town phase, always show full HP (town reset clears hero_hp on entry).
	# In dungeon, show persisted HP from combat if available.
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var max_hp = int(eff_stats.get("health", 80)) if not eff_stats.is_empty() else 80
	var current_hp = max_hp
	if GameContext.get_phase() != GameContext.GamePhase.TOWN:
		var hp_data = GameContext.get_hero_hp(hero_id)
		if not hp_data.is_empty():
			current_hp = int(hp_data.get("current", max_hp))
	var hp_label = Label.new()
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
	if current_hp >= max_hp:
		hp_label.modulate = Color(0.5, 1.0, 0.5, 1)  # Green = full
	elif current_hp > max_hp * 0.5:
		hp_label.modulate = Color(1.0, 0.9, 0.4, 1)  # Yellow = wounded
	else:
		hp_label.modulate = Color(1.0, 0.4, 0.4, 1)  # Red = critical
	info_vbox.add_child(hp_label)

	# Equipment display (per-hero gear) with stat info
	var weapon_id = GameContext.get_hero_weapon(hero_id)
	var offhand_id = GameContext.get_hero_offhand(hero_id)
	var weapon_quality = GameContext.get_hero_weapon_quality(hero_id)
	var offhand_quality = GameContext.get_hero_offhand_quality(hero_id)

	# Build weapon display with stats
	var weapon_text = "WPN: None"
	var weapon_stats: Dictionary = {}
	if weapon_id != "":
		var weapon_tpl = DataRegistry.get_item_template(weapon_id)
		if weapon_tpl != null:
			var prefix = ItemInstance.QUALITY_PREFIXES[weapon_quality] if weapon_quality < ItemInstance.QUALITY_PREFIXES.size() else ""
			weapon_stats = weapon_tpl.get_stat_bonuses_with_quality(weapon_quality)
			var stat_abbrevs: Array = []
			if weapon_stats.get("attack", 0) > 0: stat_abbrevs.append("+ATK")
			if weapon_stats.get("defense", 0) > 0: stat_abbrevs.append("+DEF")
			if weapon_stats.get("speed", 0) > 0: stat_abbrevs.append("+SPD")
			if weapon_stats.get("health", 0) > 0: stat_abbrevs.append("+HP")
			var stat_str = "(" + ", ".join(stat_abbrevs) + ")" if stat_abbrevs.size() > 0 else ""
			weapon_text = "WPN: Q%d %s %s" % [weapon_quality, prefix + weapon_tpl.display_name, stat_str]

	# Build offhand display with stats
	var offhand_text = "OFF: None"
	var offhand_stats: Dictionary = {}
	if offhand_id != "":
		var offhand_tpl = DataRegistry.get_item_template(offhand_id)
		if offhand_tpl != null:
			var prefix = ItemInstance.QUALITY_PREFIXES[offhand_quality] if offhand_quality < ItemInstance.QUALITY_PREFIXES.size() else ""
			offhand_stats = offhand_tpl.get_stat_bonuses_with_quality(offhand_quality)
			var stat_abbrevs: Array = []
			if offhand_stats.get("attack", 0) > 0: stat_abbrevs.append("+ATK")
			if offhand_stats.get("defense", 0) > 0: stat_abbrevs.append("+DEF")
			if offhand_stats.get("speed", 0) > 0: stat_abbrevs.append("+SPD")
			if offhand_stats.get("health", 0) > 0: stat_abbrevs.append("+HP")
			var stat_str = "(" + ", ".join(stat_abbrevs) + ")" if stat_abbrevs.size() > 0 else ""
			offhand_text = "OFF: Q%d %s %s" % [offhand_quality, prefix + offhand_tpl.display_name, stat_str]

	var weapon_label = Label.new()
	weapon_label.text = weapon_text
	weapon_label.modulate = Color(0.9, 0.7, 0.5, 1) if weapon_id != "" else Color(0.5, 0.5, 0.5, 1)
	info_vbox.add_child(weapon_label)

	var offhand_label = Label.new()
	offhand_label.text = offhand_text
	offhand_label.modulate = Color(0.9, 0.7, 0.5, 1) if offhand_id != "" else Color(0.5, 0.5, 0.5, 1)
	info_vbox.add_child(offhand_label)

	# Gear Bonus summary line
	var total_hp = weapon_stats.get("health", 0) + offhand_stats.get("health", 0)
	var total_atk = weapon_stats.get("attack", 0) + offhand_stats.get("attack", 0)
	var total_def = weapon_stats.get("defense", 0) + offhand_stats.get("defense", 0)
	var total_spd = weapon_stats.get("speed", 0) + offhand_stats.get("speed", 0)

	var gear_bonus_label = Label.new()
	if total_hp > 0 or total_atk > 0 or total_def > 0 or total_spd > 0:
		gear_bonus_label.text = "Gear Bonus: HP +%d ATK +%d DEF +%d SPD +%d" % [total_hp, total_atk, total_def, total_spd]
		gear_bonus_label.modulate = Color(0.6, 0.9, 0.6, 1)  # Light green
	else:
		gear_bonus_label.text = "Gear Bonus: (none)"
		gear_bonus_label.modulate = Color(0.5, 0.5, 0.5, 1)
	gear_bonus_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(gear_bonus_label)

	# Buttons VBox (right side)
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(btn_vbox)

	# Party button
	var party_btn = Button.new()
	party_btn.custom_minimum_size = Vector2(100, 28)
	if in_party:
		party_btn.text = "Remove"
		party_btn.pressed.connect(_on_remove_from_party_pressed.bind(hero_id))
	else:
		party_btn.text = "Add to Party"
		party_btn.disabled = selected_party.size() >= GameContext.MAX_PARTY_SIZE
		party_btn.pressed.connect(_on_add_to_party_pressed.bind(hero_id))
	btn_vbox.add_child(party_btn)

	# Equipment buttons (only for party members)
	if in_party:
		# Equip Weapon button
		var equip_weapon_btn = Button.new()
		equip_weapon_btn.custom_minimum_size = Vector2(100, 28)
		equip_weapon_btn.text = "Equip Wpn"
		equip_weapon_btn.pressed.connect(_on_equip_slot_pressed.bind(hero_id, "weapon"))
		btn_vbox.add_child(equip_weapon_btn)

		# Equip Offhand button
		var equip_offhand_btn = Button.new()
		equip_offhand_btn.custom_minimum_size = Vector2(100, 28)
		equip_offhand_btn.text = "Equip Off"
		equip_offhand_btn.pressed.connect(_on_equip_slot_pressed.bind(hero_id, "offhand"))
		btn_vbox.add_child(equip_offhand_btn)

		# Unequip buttons (only show if slot has item)
		if weapon_id != "":
			var unequip_weapon_btn = Button.new()
			unequip_weapon_btn.custom_minimum_size = Vector2(100, 28)
			unequip_weapon_btn.text = "Unequip Wpn"
			unequip_weapon_btn.pressed.connect(_on_unequip_slot_pressed.bind(hero_id, "weapon"))
			btn_vbox.add_child(unequip_weapon_btn)

		if offhand_id != "":
			var unequip_offhand_btn = Button.new()
			unequip_offhand_btn.custom_minimum_size = Vector2(100, 28)
			unequip_offhand_btn.text = "Unequip Off"
			unequip_offhand_btn.pressed.connect(_on_unequip_slot_pressed.bind(hero_id, "offhand"))
			btn_vbox.add_child(unequip_offhand_btn)

	# Rename button
	var rename_btn = Button.new()
	rename_btn.custom_minimum_size = Vector2(100, 28)
	rename_btn.text = "Rename"
	rename_btn.pressed.connect(_on_rename_hero_pressed.bind(hero_id))
	btn_vbox.add_child(rename_btn)

	# Dismiss button (disabled if in party)
	var dismiss_btn = Button.new()
	dismiss_btn.custom_minimum_size = Vector2(100, 28)
	dismiss_btn.text = "Dismiss"
	dismiss_btn.disabled = in_party
	dismiss_btn.modulate = Color(1, 0.6, 0.6, 1) if not in_party else Color(0.5, 0.5, 0.5, 1)
	dismiss_btn.pressed.connect(_on_inn_dismiss_hero_pressed.bind(hero_id))
	btn_vbox.add_child(dismiss_btn)

	return panel


func _create_recruit_row(candidate: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var race_id = candidate.get("race_id", "human")  # Default to human for Region 1
	var class_id = candidate.get("class_id", "")
	var cost = candidate.get("cost_gold", 50)
	var level = candidate.get("level", 1)
	var can_afford = GameContext.get_run_gold() >= cost

	# Get display names from DataRegistry with fallback to capitalize()
	var race_name = race_id.capitalize()
	var race_data = DataRegistry.get_race(race_id)
	if race_data != null and race_data.display_name != "":
		race_name = race_data.display_name

	var cls_name = class_id.capitalize()
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data != null and class_data.display_name != "":
		cls_name = class_data.display_name

	# Race + Class + Level label
	var label = Label.new()
	label.text = "%s %s Lv %d (%d gold)" % [race_name, cls_name, level, cost]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Recruit button
	var btn = Button.new()
	btn.text = "Recruit"
	btn.custom_minimum_size = Vector2(80, 26)
	btn.disabled = not can_afford
	btn.pressed.connect(_on_recruit_hero_pressed.bind(class_id, cost, race_id, level))
	row.add_child(btn)

	return row


func _on_add_to_party_pressed(hero_id: String) -> void:
	GameContext.add_to_party(hero_id)
	_refresh_facility_panel()


func _on_remove_from_party_pressed(hero_id: String) -> void:
	GameContext.remove_from_party(hero_id)
	_refresh_facility_panel()


func _on_equip_slot_pressed(hero_id: String, slot: String) -> void:
	# Show equip selection popup for this hero and slot
	_show_equip_selection_popup(hero_id, slot)


func _on_unequip_slot_pressed(hero_id: String, slot: String) -> void:
	GameContext.unequip_hero_item(hero_id, slot)
	_refresh_facility_panel()


## Show popup to select an item from stash to equip in the given slot.
## Shows stat preview, compare vs currently equipped, and detailed tooltips.
func _show_equip_selection_popup(hero_id: String, slot: String) -> void:
	# Get compatible items from stash (use equip_slot field for validation)
	var compatible_items: Array = []

	for item in GameContext.run_items:
		var template: ItemTemplate = null
		var item_id: String = ""
		var quality_tier: int = 0

		if item is ItemInstance:
			item_id = item.template_id
			quality_tier = item.quality_tier
			template = DataRegistry.get_item_template(item_id)
		elif item is Dictionary:
			item_id = item.get("item_id", "")
			quality_tier = item.get("quality_tier", 0)
			template = DataRegistry.get_item_template(item_id)

		# Use equip_slot field for proper slot validation
		if template != null and template.equip_slot == slot:
			compatible_items.append({
				"item_id": item_id,
				"quality_tier": quality_tier,
				"template": template
			})

	if compatible_items.is_empty():
		print("[Equip] No compatible %s items in stash for hero=%s" % [slot, hero_id])
		return

	# Get hero name for display
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if not hero.is_empty() else hero_id

	# Get currently equipped item info for comparison
	var current_id = ""
	var current_quality = 0
	var current_stats: Dictionary = {}
	if slot == "weapon":
		current_id = GameContext.get_hero_weapon(hero_id)
		current_quality = GameContext.get_hero_weapon_quality(hero_id)
	else:
		current_id = GameContext.get_hero_offhand(hero_id)
		current_quality = GameContext.get_hero_offhand_quality(hero_id)

	if current_id != "":
		var current_template = DataRegistry.get_item_template(current_id)
		if current_template != null:
			current_stats = current_template.get_stat_bonuses_with_quality(current_quality)

	# Create selection popup
	var popup = PopupPanel.new()
	popup.name = "EquipPopup"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)

	# Title with hero name and slot
	var title = Label.new()
	title.text = "Equip %s - %s" % [slot.capitalize(), hero_name]
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1, 0.9, 0.6)
	vbox.add_child(title)

	# Currently equipped section
	var current_label = Label.new()
	if current_id != "":
		var current_template = DataRegistry.get_item_template(current_id)
		var current_prefix = ItemInstance.QUALITY_PREFIXES[current_quality] if current_quality < ItemInstance.QUALITY_PREFIXES.size() else ""
		var current_name = current_prefix + (current_template.display_name if current_template else current_id)
		current_label.text = "Current: %s" % current_name
	else:
		current_label.text = "Current: None"
	current_label.modulate = Color(0.7, 0.7, 0.9)
	vbox.add_child(current_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Item buttons with stat preview and compare
	for item_data in compatible_items:
		var item_vbox = VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 2)

		var btn = Button.new()
		var prefix = ItemInstance.QUALITY_PREFIXES[item_data.quality_tier] if item_data.quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
		var item_stats = item_data.template.get_stat_bonuses_with_quality(item_data.quality_tier)

		# Build stat text
		var stat_parts: Array = []
		for stat_key in ["health", "attack", "defense", "speed"]:
			var val = item_stats.get(stat_key, 0)
			if val > 0:
				var abbrev = {"health": "HP", "attack": "ATK", "defense": "DEF", "speed": "SPD"}
				stat_parts.append("%s+%d" % [abbrev.get(stat_key, stat_key), val])

		var stat_text = " ".join(stat_parts) if stat_parts.size() > 0 else "(no stats)"
		btn.text = "%s%s  [%s]" % [prefix, item_data.template.display_name, stat_text]
		btn.custom_minimum_size = Vector2(300, 32)
		btn.pressed.connect(_on_equip_item_selected.bind(hero_id, slot, item_data.item_id, popup))

		# Build tooltip with full info (Items v5: include quality multiplier)
		const QUALITY_MULT := [1.0, 1.1, 1.2, 1.35]
		var q_tier = clampi(item_data.quality_tier, 0, 3)
		var mult = QUALITY_MULT[q_tier]
		var tooltip_lines: Array = [
			"Item: %s%s" % [prefix, item_data.template.display_name],
			"ID: %s" % item_data.item_id,
			"Slot: %s" % item_data.template.equip_slot,
			"Quality: Q%d (x%.2f)" % [q_tier, mult],
			"Stats (final): %s" % stat_text
		]
		btn.tooltip_text = "\n".join(tooltip_lines)

		item_vbox.add_child(btn)

		# Compare line (delta stats)
		var compare_label = Label.new()
		var delta_parts: Array = []
		for stat_key in ["health", "attack", "defense", "speed"]:
			var new_val = item_stats.get(stat_key, 0)
			var old_val = current_stats.get(stat_key, 0)
			var delta = new_val - old_val
			if delta != 0:
				var abbrev = {"health": "HP", "attack": "ATK", "defense": "DEF", "speed": "SPD"}
				var sign_str = "+" if delta > 0 else ""
				delta_parts.append("Δ%s %s%d" % [abbrev.get(stat_key, stat_key), sign_str, delta])

		if delta_parts.size() > 0:
			compare_label.text = "  " + " ".join(delta_parts)
			# Color based on net positive/negative
			var total_delta = 0
			for stat_key in ["health", "attack", "defense", "speed"]:
				total_delta += item_stats.get(stat_key, 0) - current_stats.get(stat_key, 0)
			if total_delta > 0:
				compare_label.modulate = Color(0.5, 1, 0.5)  # Green for upgrade
			elif total_delta < 0:
				compare_label.modulate = Color(1, 0.5, 0.5)  # Red for downgrade
			else:
				compare_label.modulate = Color(0.8, 0.8, 0.8)  # Neutral
		else:
			compare_label.text = "  (no stat change)"
			compare_label.modulate = Color(0.6, 0.6, 0.6)

		compare_label.add_theme_font_size_override("font_size", 12)
		item_vbox.add_child(compare_label)

		vbox.add_child(item_vbox)

	# Separator before cancel
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(300, 32)
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	add_child(popup)
	popup.popup_centered()


func _on_equip_item_selected(hero_id: String, slot: String, item_id: String, popup: PopupPanel) -> void:
	popup.queue_free()
	GameContext.equip_hero_item(hero_id, slot, item_id)
	_refresh_facility_panel()


func _on_recruit_hero_pressed(class_id: String, cost: int, race_id: String = "human", level: int = 1) -> void:
	var hero_id = GameContext.recruit_hero(class_id, cost, race_id, level)
	if hero_id != "":
		print("[Inn] recruited %s Lv %d hero_id=%s" % [class_id, level, hero_id])
	_refresh_facility_panel()


func _on_rename_hero_pressed(hero_id: String) -> void:
	# Build a rename popup with LineEdit, Confirm, Cancel
	var popup = PopupPanel.new()
	popup.name = "RenamePopup"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "Rename Hero"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "New name (max 18 chars)"
	line_edit.max_length = 18
	line_edit.custom_minimum_size = Vector2(220, 30)
	# Pre-fill with current name
	var hero = GameContext.get_hero(hero_id)
	if not hero.is_empty():
		line_edit.text = hero.get("name", "")
	vbox.add_child(line_edit)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(80, 28)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	btn_row.add_child(cancel_btn)

	# Wire buttons
	confirm_btn.pressed.connect(func():
		var new_name = line_edit.text
		GameContext.set_hero_name(hero_id, new_name)
		popup.queue_free()
		_refresh_facility_panel()
	)
	cancel_btn.pressed.connect(func():
		popup.queue_free()
	)

	add_child(popup)
	popup.popup_centered(Vector2i(280, 130))


func _on_inn_dismiss_hero_pressed(hero_id: String) -> void:
	var in_party = GameContext.is_in_party(hero_id)
	if in_party:
		print("[Inn] cannot dismiss hero in party: %s" % hero_id)
		return
	var removed = GameContext.remove_hero_from_roster(hero_id)
	if removed:
		# Refund partial gold (25g) to run stash (same pool as recruit cost)
		GameContext.add_run_gold(25)
		print("[Inn] dismissed hero=%s refunded 25 gold" % hero_id)
	_refresh_facility_panel()


## Generate recruit candidates from DataRegistry (races + classes filtered by unlock_region).
## Returns array of { race_id, class_id, cost_gold, level } dictionaries.
func _generate_inn_recruit_candidates(current_region: int, recruit_level: int) -> Array:
	var candidates: Array = []

	# Get all races and classes unlocked for current region
	var available_races: Array = []
	var available_classes: Array = []

	for race_data in DataRegistry.get_all_races():
		if race_data.unlock_region <= current_region:
			available_races.append(race_data.race_id)

	for class_data in DataRegistry.get_all_classes():
		if class_data.unlock_region <= current_region:
			# Skip legacy classes not in GDD
			if class_data.is_legacy:
				continue
			available_classes.append(class_data.class_id)

	# If no data loaded, fallback to hardcoded defaults
	if available_races.is_empty():
		available_races = ["human", "elf", "dwarf"]
	if available_classes.is_empty():
		available_classes = ["defender", "striker", "warden"]

	# Base cost per recruit (could be tier-based in future)
	var base_cost = 50

	# Generate all race+class combinations as potential candidates
	var all_combinations: Array = []
	for race_id in available_races:
		for class_id in available_classes:
			all_combinations.append({
				"race_id": race_id,
				"class_id": class_id,
				"cost_gold": base_cost,
				"level": recruit_level
			})

	# For MVP: Show a subset of candidates (one per class, varying races)
	# Use seeded RNG for determinism based on town_id + refresh counter
	var town_id = GameContext.get_current_town_id()
	if town_id == "":
		town_id = "default"
	var base_seed = GameContext.get_run_seed() if GameContext.get_run_seed() != 0 else 42
	var recruit_seed = SeededRNG.derive_seed("inn_recruit:" + town_id, base_seed)
	var rng = SeededRNG.create_rng(recruit_seed)

	# Shuffle combinations deterministically
	all_combinations.shuffle()  # Note: Not seeded, but stable for single session

	# Select one candidate per class to ensure variety
	var selected_classes: Dictionary = {}
	for combo in all_combinations:
		var class_id = combo.get("class_id", "")
		if not selected_classes.has(class_id):
			candidates.append(combo)
			selected_classes[class_id] = true
		if candidates.size() >= 5:  # Cap at 5 candidates max
			break

	# If we have fewer than 3 candidates, just use what we have
	print("[Inn] pool races=%d classes=%d candidates=%d region=%d" % [
		available_races.size(), available_classes.size(), candidates.size(), current_region
	])

	# Validate data references for visible candidates (non-blocking warnings)
	_validate_candidate_data(candidates)

	return candidates


## Validate class/race data references for recruit candidates.
## Logs warnings for missing passive/ability IDs (non-blocking).
func _validate_candidate_data(candidates: Array) -> void:
	var validated_classes: Dictionary = {}
	var validated_races: Dictionary = {}

	for candidate in candidates:
		var class_id = candidate.get("class_id", "")
		var race_id = candidate.get("race_id", "")

		# Validate class (once per class_id)
		if class_id != "" and not validated_classes.has(class_id):
			validated_classes[class_id] = true
			var class_data = DataRegistry.get_class_data(class_id)
			if class_data == null:
				print("[DataWarn] missing class=%s" % class_id)
			else:
				# Check ability IDs (passive/ability registries may not exist yet)
				if class_data.ability_a_id != "" and not _ability_exists(class_data.ability_a_id):
					print("[DataWarn] class=%s missing ability=%s" % [class_id, class_data.ability_a_id])
				if class_data.ability_b_id != "" and not _ability_exists(class_data.ability_b_id):
					print("[DataWarn] class=%s missing ability=%s" % [class_id, class_data.ability_b_id])
				if class_data.passive_a_id != "" and not _passive_exists(class_data.passive_a_id):
					print("[DataWarn] class=%s missing passive=%s" % [class_id, class_data.passive_a_id])
				if class_data.passive_b_id != "" and not _passive_exists(class_data.passive_b_id):
					print("[DataWarn] class=%s missing passive=%s" % [class_id, class_data.passive_b_id])

		# Validate race (once per race_id)
		if race_id != "" and not validated_races.has(race_id):
			validated_races[race_id] = true
			var race_data = DataRegistry.get_race(race_id)
			if race_data == null:
				print("[DataWarn] missing race=%s" % race_id)
			elif race_data.racial_passive_id != "" and not _passive_exists(race_data.racial_passive_id):
				print("[DataWarn] race=%s missing passive=%s" % [race_id, race_data.racial_passive_id])


## Check if ability ID exists in registry. Returns true if found or if registry unavailable.
func _ability_exists(ability_id: String) -> bool:
	if ability_id == "":
		return true
	# Ability registry may not exist yet - allow placeholder
	if not DataRegistry.has_method("get_ability"):
		return true  # Can't validate, assume OK
	var ability = DataRegistry.get_ability(ability_id)
	return ability != null


## Check if passive ID exists in registry. Returns true if found or if registry unavailable.
func _passive_exists(passive_id: String) -> bool:
	if passive_id == "":
		return true
	# Passive registry may not exist yet - allow placeholder
	if not DataRegistry.has_method("get_passive"):
		return true  # Can't validate, assume OK
	var passive = DataRegistry.get_passive(passive_id)
	return passive != null


# ============================================================================
# WOODSMAN UI (Flavor/Placeholder - NO materials shop)
# ============================================================================

func _build_woodsman_ui() -> void:
	print("[Woodsman] opened")

	var header = Label.new()
	header.text = "=== Woodsman's Lodge ==="
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	# Flavor text - woodsman is placeholder, NOT a materials shop
	var desc_label = Label.new()
	desc_label.text = _current_facility.description if _current_facility != null else "A rustic lodge where rangers and hunters share tales of the forest."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(250, 0)
	desc_label.modulate = Color(0.8, 0.9, 0.7, 1)
	_facility_actions_container.add_child(desc_label)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Info about services coming soon
	var info_header = Label.new()
	info_header.text = "-- Services --"
	info_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(info_header)

	var coming_soon = Label.new()
	coming_soon.text = "(Services coming in a future update)"
	coming_soon.modulate = Color(0.6, 0.6, 0.6, 1)
	_facility_actions_container.add_child(coming_soon)

	# Tip about materials
	var tip = Label.new()
	tip.text = "Tip: Find materials in dungeon loot drops!"
	tip.modulate = Color(0.5, 0.7, 0.5, 1)
	_facility_actions_container.add_child(tip)


# ============================================================================
# PRODUCTION UI (Chef, Leatherworker - placeholder)
# ============================================================================

func _build_production_ui() -> void:
	print("[Production] opened")

	var header = Label.new()
	header.text = "=== %s ===" % (_current_facility.display_name if _current_facility != null else "Production")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	var info = Label.new()
	info.text = "(Production crafting coming soon!)"
	info.modulate = Color(0.6, 0.6, 0.6, 1)
	_facility_actions_container.add_child(info)

	if _current_facility != null:
		var services_label = Label.new()
		var tier_1_services = []
		if _current_facility.services_per_tier.has("1"):
			tier_1_services = _current_facility.services_per_tier["1"]
		elif _current_facility.services_per_tier.has(1):
			tier_1_services = _current_facility.services_per_tier[1]
		services_label.text = "Services: %s" % ", ".join(tier_1_services) if tier_1_services.size() > 0 else "Services: (none)"
		services_label.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(services_label)


func _build_dungeon_ui() -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null or town.dungeon_id == "":
		var no_dungeon = Label.new()
		no_dungeon.text = "(No dungeon available)"
		no_dungeon.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_dungeon)
		return

	var dungeon_id = town.dungeon_id
	var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var dungeon_name = dungeon.display_name if dungeon != null and dungeon.display_name != "" else dungeon_id
	var floor_count = dungeon.floor_count if dungeon != null else 4

	var unlocked_floor = GameContext.get_unlocked_floor(dungeon_id)
	var selected_floor = GameContext.get_selected_start_floor(dungeon_id)

	# Dungeon name
	var name_label = Label.new()
	name_label.text = "Dungeon: %s" % dungeon_name
	_facility_actions_container.add_child(name_label)

	# Unlocked floors
	var unlock_label = Label.new()
	if unlocked_floor > 1:
		unlock_label.text = "Unlocked: Floor 1-%d" % unlocked_floor
	else:
		unlock_label.text = "Unlocked: Floor 1"
	unlock_label.modulate = Color(0.5, 1, 0.5, 1)
	_facility_actions_container.add_child(unlock_label)

	# Selected start floor
	var selected_label = Label.new()
	selected_label.text = "Start Floor: %d" % selected_floor
	_facility_actions_container.add_child(selected_label)

	# Floor selection buttons
	var floor_header = Label.new()
	floor_header.text = "Select Starting Floor:"
	_facility_actions_container.add_child(floor_header)

	var floor_row = HBoxContainer.new()
	floor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	floor_row.add_theme_constant_override("separation", 6)
	_facility_actions_container.add_child(floor_row)

	for floor_num in range(1, floor_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(60, 28)

		if floor_num <= unlocked_floor:
			btn.text = "F%d" % floor_num
			if floor_num == selected_floor:
				btn.text += "*"
				btn.disabled = true
			else:
				btn.pressed.connect(_on_dungeon_floor_selected.bind(dungeon_id, floor_num))
		else:
			btn.text = "F%d" % floor_num
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 1)

		floor_row.add_child(btn)

	# Separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Check if currently in dungeon
	var current_dungeon = GameContext.get_current_dungeon_id()
	var in_this_dungeon = current_dungeon == dungeon_id

	# Enter Dungeon button
	var enter_btn = Button.new()
	enter_btn.text = "Enter Dungeon"
	enter_btn.custom_minimum_size = Vector2(180, 32)
	enter_btn.disabled = current_dungeon != ""
	enter_btn.pressed.connect(_on_dungeon_enter_pressed.bind(dungeon_id))
	_facility_actions_container.add_child(enter_btn)

	# Continue Run button (only if in this dungeon)
	if in_this_dungeon:
		var continue_btn = Button.new()
		continue_btn.text = "Continue Run (Floor %d)" % GameContext.get_current_floor()
		continue_btn.custom_minimum_size = Vector2(180, 32)
		continue_btn.pressed.connect(_on_dungeon_continue_pressed)
		_facility_actions_container.add_child(continue_btn)

		var exit_btn = Button.new()
		exit_btn.text = "Exit Dungeon"
		exit_btn.custom_minimum_size = Vector2(180, 32)
		exit_btn.pressed.connect(_on_dungeon_exit_pressed)
		_facility_actions_container.add_child(exit_btn)


func _on_dungeon_floor_selected(dungeon_id: String, floor_num: int) -> void:
	if GameContext.set_selected_start_floor(dungeon_id, floor_num):
		print("[DungeonFacility] Selected start floor=%d for %s" % [floor_num, dungeon_id])
		_refresh_facility_panel()


func _on_dungeon_enter_pressed(dungeon_id: String) -> void:
	GameContext.enter_dungeon(dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	print("[DungeonFacility] Entering %s at floor %d" % [dungeon_id, GameContext.get_current_floor()])
	facility_window.hide()
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _on_dungeon_continue_pressed() -> void:
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	print("[DungeonFacility] Continuing run at floor %d" % GameContext.get_current_floor())
	facility_window.hide()
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _on_dungeon_exit_pressed() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()
	GameContext.exit_to_town()
	print("[DungeonFacility] Exited dungeon %s" % dungeon_id)
	_refresh_facility_panel()
	_refresh_ui()


# ============================================================================
# FACILITY ACTION HANDLERS
# ============================================================================

func _on_storage_deposit_pressed() -> void:
	# Deposit gold from player wallet to bank (run stash)
	if GameContext.spend_player_gold(10):
		GameContext.add_run_gold(10)
		print("[Storage] deposit gold=10 wallet->bank")
		_refresh_facility_panel()

func _on_storage_withdraw_pressed() -> void:
	# Withdraw gold from bank (run stash) to player wallet
	if GameContext.spend_run_gold(10):
		GameContext.add_player_gold(10)
		print("[Storage] withdraw gold=10 bank->wallet")
		_refresh_facility_panel()


func _on_unequip_weapon_pressed() -> void:
	GameContext.unequip_item("weapon")
	_refresh_facility_panel()


func _on_unequip_offhand_pressed() -> void:
	GameContext.unequip_item("offhand")
	_refresh_facility_panel()


func _on_equip_item_pressed(item_id: String, slot: String) -> void:
	if GameContext.equip_item(slot, item_id):
		_refresh_facility_panel()
	else:
		print("[Storage] Failed to equip %s in %s slot" % [item_id, slot])


func _on_item_transfer_pressed(item_id: String, action: String) -> void:
	if action == "deposit":
		# Move from player inventory to run stash (bank)
		if GameContext.remove_player_item(item_id, 1):
			GameContext.add_run_item(item_id, 1)
			print("[Storage] transfer item=%s qty=1 wallet->bank" % item_id)
	else:  # withdraw
		# Move from run stash (bank) to player inventory
		if GameContext.remove_run_item(item_id, 1):
			GameContext.add_player_item(item_id, 1)
			print("[Storage] transfer item=%s qty=1 bank->wallet" % item_id)
	_refresh_facility_panel()


func _on_unlock_pressed(unlock: Dictionary) -> void:
	var unlock_group = unlock.get("unlock_group", "")
	if unlock_group == "":
		print("[Unlock] group=(empty) result=fail reason=no_group_id")
		return

	# Check if already unlocked
	if GameContext.has_unlocked_group(unlock_group):
		print("[Unlock] group=%s result=fail reason=already_unlocked" % unlock_group)
		return

	# Get costs and check affordability
	var costs = unlock.get("costs", [])
	if not GameContext.can_afford_run_materials(costs):
		print("[Unlock] group=%s result=fail reason=cannot_afford" % unlock_group)
		return

	# Spend materials from run stash
	if not GameContext.spend_run_materials(costs):
		print("[Unlock] group=%s result=fail reason=spend_failed" % unlock_group)
		return

	# Unlock the group
	GameContext.unlock_group(unlock_group)
	print("[Unlock] group=%s result=success" % unlock_group)
	_refresh_facility_panel()


func _on_facility_upgrade_pressed(town_id: String, facility_id: String) -> void:
	var tier_before = GameContext.get_facility_tier(town_id, facility_id)

	# Facilities v4: Get upgrade cost for logging
	var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
	var cost_gold = 0
	var cost_items_str = ""
	if facility != null:
		var next_tier = tier_before + 1
		var cost_data = facility.upgrade_costs.get(str(next_tier), {})
		cost_gold = int(cost_data.get("gold", 0))
		var item_parts: Array = []
		for key in cost_data.keys():
			if key != "gold":
				item_parts.append("%s=%s" % [key, str(cost_data[key])])
		cost_items_str = ", ".join(item_parts) if item_parts.size() > 0 else "none"

	if GameContext.upgrade_facility(town_id, facility_id):
		var tier_after = GameContext.get_facility_tier(town_id, facility_id)
		# Facilities v4: Log with standardized format
		print("[Facility] upgrade facility=%s town=%s tier_before=%d tier_after=%d cost_gold=%d cost_items=[%s]" % [
			facility_id, town_id, tier_before, tier_after, cost_gold, cost_items_str])
	else:
		print("[Facility] upgrade_failed facility=%s town=%s tier=%d" % [facility_id, town_id, tier_before])
	_refresh_facility_panel()


func _on_training_pressed(buff_type: String, cost: int) -> void:
	if GameContext.purchase_training_buff(buff_type, cost):
		print("[Training] Purchased %s buff for %d gold" % [buff_type, cost])
		_refresh_facility_panel()


func _refresh_facility_panel() -> void:
	# Re-get facility and rebuild UI
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	if town == null:
		return

	# Find facility with matching type
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		if facility != null and facility.facility_type == _current_facility_type:
			_create_facility_actions(facility)
			break

	# Also refresh main UI
	_refresh_ui()


# ============================================================================
# DEBUG HOTKEYS - Dungeon flow testing (kept for convenience)
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Shift+F6: advance room only (for testing multi-room floors)
		if event.keycode == KEY_F6 and event.shift_pressed:
			_debug_advance_room()
			return

		match event.keycode:
			KEY_F5:
				_debug_enter_dungeon()
			KEY_F6:
				_debug_advance_floor()
			KEY_F7:
				_debug_exit_to_town()


func _debug_enter_dungeon() -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null:
		print("[DEBUG] EnterDungeon FAILED - no town data for '%s'" % town_id)
		return

	if town.dungeon_id == "":
		print("[DEBUG] EnterDungeon FAILED - town '%s' has no dungeon_id" % town_id)
		return

	# Enter dungeon and set phase to COMBAT
	GameContext.enter_dungeon(town.dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DEBUG] EnterDungeon dungeon=%s floor=%d" % [
		GameContext.get_current_dungeon_id(),
		GameContext.get_current_floor()
	])

	# Route through boot
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _debug_advance_floor() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[DEBUG] AdvanceFloor FAILED - not in a dungeon")
		return

	# Advance floor and set phase to COMBAT
	GameContext.advance_floor()
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DEBUG] AdvanceFloor floor=%d room=%d/%d" % [
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _debug_advance_room() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[DEBUG] AdvanceRoom FAILED - not in a dungeon")
		return

	# Advance room and set phase to COMBAT
	GameContext.advance_room()
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DEBUG] AdvanceRoom floor=%d room=%d/%d" % [
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _debug_exit_to_town() -> void:
	# Guard: only allow exit if actually in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DEBUG] ExitToTown ignored (not in dungeon)")
		return

	# Exit to town (this sets phase to TOWN internally)
	GameContext.exit_to_town()

	print("[DEBUG] ExitToTown")

	# Refresh UI instead of reloading scene
	_refresh_ui()
