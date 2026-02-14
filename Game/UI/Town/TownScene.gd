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

# Facility overlay (CanvasLayer-based modal — built at runtime)
var _facility_overlay: CanvasLayer = null
var _facility_panel: PanelContainer = null
var _facility_backdrop: ColorRect = null
var _facility_content_vbox: VBoxContainer = null
var facility_name_label: Label = null
var facility_type_label: Label = null
var facility_desc_label: Label = null
var facility_tier_label: Label = null
var facility_services_label: Label = null
var close_facility_button: Button = null

# ============================================================================
# CRAFTPIX SKIN (optional visual override — default false)
# ============================================================================
@export var use_craftpix_skin: bool = false

# Dynamic facility action container (created at runtime)
var _facility_actions_container: VBoxContainer = null
var _current_facility_type: String = ""
var _current_facility = null  # Current facility data (for recipes/shop)
var _current_facility_id: String = ""  # Facility ID for seeding/logging

# Storage filter state
var _storage_filter: String = "all"  # "all", "materials", "consumables", "equipment", "books"

# Training Hall: selected hero for class assignment
var _training_selected_hero_id: String = ""

# Equipment Facility: filter and tab state
var _equipment_tab: String = "all"  # "all", "locked", "unlocked"
var _equipment_type_filter: String = "all"  # "all", "1h_weapon", "2h_weapon", "helmet", "armor", "legs", "offhand", "accessory", "backpack"

# ============================================================================
# HELPERS
# ============================================================================

## Immediately remove all children from a container so they vanish from the tree
## in the current frame.  queue_free() alone defers removal to end-of-frame,
## which lets ghost nodes stay visible when the container is repopulated in the
## same frame (e.g. _refresh_facility_panel → _build_inn_ui).
func _clear_children_immediate(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ============================================================================
# FACILITY OVERLAY — CanvasLayer-based modal (replaces Window node)
# ============================================================================
# Godot 4 Window nodes break when the scene is embedded inside another scene
# (popup_centered() silently fails). This overlay renders on a high CanvasLayer
# so it always appears on top, regardless of scene nesting depth.

func _build_facility_overlay() -> void:
	# CanvasLayer — renders above everything else
	_facility_overlay = CanvasLayer.new()
	_facility_overlay.layer = 10
	_facility_overlay.name = "FacilityOverlay"
	add_child(_facility_overlay)

	# Semi-transparent backdrop (click to close)
	# IMPORTANT: We toggle _facility_backdrop.visible for show/hide.
	# CanvasLayer.visible may not propagate correctly in all Godot 4 builds,
	# so we toggle the first CanvasItem child instead.
	_facility_backdrop = ColorRect.new()
	_facility_backdrop.name = "FacilityBackdrop"
	_facility_backdrop.color = Color(0, 0, 0, 0.5)
	_facility_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_facility_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_facility_backdrop.gui_input.connect(_on_facility_backdrop_input)
	_facility_overlay.add_child(_facility_backdrop)

	# CenterContainer to auto-center the panel
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_facility_backdrop.add_child(center)

	# Main panel — fixed size matching the old Window (520 x 420)
	_facility_panel = PanelContainer.new()
	_facility_panel.custom_minimum_size = Vector2(520, 420)
	_facility_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# CanvasLayer breaks theme propagation — apply theme explicitly
	if use_craftpix_skin:
		_facility_panel.theme = _CRAFTPIX_THEME
	else:
		_facility_panel.theme = preload("res://Themes/game_theme.tres")
	center.add_child(_facility_panel)

	# MarginContainer inside panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_facility_panel.add_child(margin)

	# ScrollContainer for long content
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	# Main content VBox
	_facility_content_vbox = VBoxContainer.new()
	_facility_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_facility_content_vbox)

	# --- Content labels (same as old Window) ---
	facility_name_label = Label.new()
	facility_name_label.text = "Facility Name"
	facility_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_content_vbox.add_child(facility_name_label)

	facility_type_label = Label.new()
	facility_type_label.text = "Type: production"
	facility_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	facility_type_label.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_content_vbox.add_child(facility_type_label)

	var sep := HSeparator.new()
	_facility_content_vbox.add_child(sep)

	facility_desc_label = Label.new()
	facility_desc_label.text = "Description goes here..."
	facility_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facility_content_vbox.add_child(facility_desc_label)

	facility_tier_label = Label.new()
	facility_tier_label.text = "Max Tier: 4"
	_facility_content_vbox.add_child(facility_tier_label)

	facility_services_label = Label.new()
	facility_services_label.text = "Tier 1 Services: (none)"
	_facility_content_vbox.add_child(facility_services_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_facility_content_vbox.add_child(spacer)

	# Close button
	close_facility_button = Button.new()
	close_facility_button.text = "Close"
	close_facility_button.custom_minimum_size = Vector2(100, 30)
	close_facility_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_facility_content_vbox.add_child(close_facility_button)

	# Start hidden (toggle backdrop, NOT CanvasLayer)
	_facility_backdrop.visible = false
	print("[TownScene] Facility overlay built (CanvasLayer layer=10, backdrop toggle)")


func _show_facility_overlay() -> void:
	_facility_backdrop.visible = true
	print("[FacilityOverlay] SHOW backdrop.visible=%s" % str(_facility_backdrop.visible))


func _hide_facility_overlay() -> void:
	if _facility_backdrop != null:
		_facility_backdrop.visible = false
		print("[FacilityOverlay] HIDE")


func _is_facility_overlay_visible() -> bool:
	return _facility_backdrop != null and _facility_backdrop.visible


func _on_facility_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_facility_pressed()


# ============================================================================
# CRAFTPIX SKIN — runtime visual override (no .tscn changes)
# ============================================================================

const _CRAFTPIX_THEME = preload("res://Themes/CraftPix/craftpix_ui_tinted.tres")
const _CRAFTPIX_HEADER = preload("res://Themes/CraftPix/header_bar_teal_tinted.tres")


func _apply_craftpix_skin() -> void:
	# 1) Swap root theme to CraftPix
	theme = _CRAFTPIX_THEME

	# 2) Update background colour to CraftPix standard
	var bg: ColorRect = get_node_or_null("Background")
	if bg:
		bg.color = Color(0.15, 0.15, 0.2, 1)

	# 3) Tighten margins (20 → 16, CraftPix standard)
	var margin: MarginContainer = get_node_or_null("MarginContainer")
	if margin:
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 16)

	# 4) Get the main VBox that holds all sections
	var main_vbox: VBoxContainer = get_node_or_null("MarginContainer/ScrollContainer/MainVBox")
	if main_vbox == null:
		push_warning("[TownScene] CraftPix skin: MainVBox not found")
		return

	main_vbox.add_theme_constant_override("separation", 12)

	# 5) Hide the debug-style title label (TownHub shell has its own header)
	var title_label: Label = main_vbox.get_node_or_null("TitleLabel")
	if title_label:
		title_label.visible = false

	# 6) Hide all HSeparators (sections now separated by panel wrappers)
	for child in main_vbox.get_children():
		if child is HSeparator:
			child.visible = false

	# 7) Hide all sections — TownHub nav rail / map grid / facilities replaces everything
	for section_name in ["LocationSection", "StashSection", "FacilitiesSection", "HeroesSection", "ActionSection", "TownSwitchSection", "DebugSection"]:
		var section = main_vbox.get_node_or_null(section_name)
		if section:
			section.visible = false

	print("[TownScene] CraftPix skin applied")


## Wraps an existing section VBox inside a CraftPix panel with a teal header bar.
## The section is reparented: MainVBox > PanelContainer > VBox > [header, section].
func _craftpix_wrap_section(parent: VBoxContainer, section_name: String, header_text: String) -> void:
	var section: Control = parent.get_node_or_null(section_name)
	if section == null:
		return

	var idx: int = section.get_index()

	# Hide the old "=== Section ===" header label (first child of each section VBox)
	if section is VBoxContainer and section.get_child_count() > 0:
		var first_child: Node = section.get_child(0)
		if first_child is Label:
			var label_text: String = first_child.text
			if label_text.begins_with("===") or label_text.begins_with("--"):
				first_child.visible = false

	# Create wrapper: PanelContainer > MarginContainer > InnerVBox
	var panel := PanelContainer.new()
	panel.name = section_name + "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 8)
	inner_margin.add_theme_constant_override("margin_top", 0)
	inner_margin.add_theme_constant_override("margin_right", 8)
	inner_margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(inner_margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	inner_margin.add_child(inner_vbox)

	# Create teal header bar
	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 28)
	header_panel.add_theme_stylebox_override("panel", _CRAFTPIX_HEADER)

	var header_label := Label.new()
	header_label.text = header_text
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 13)
	header_panel.add_child(header_label)

	inner_vbox.add_child(header_panel)

	# Reparent the section into the wrapper
	parent.remove_child(section)
	inner_vbox.add_child(section)

	# Insert wrapper at the original index
	if idx >= parent.get_child_count():
		parent.add_child(panel)
	else:
		parent.add_child(panel)
		parent.move_child(panel, idx)


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Build the facility overlay (CanvasLayer — replaces old Window node)
	_build_facility_overlay()

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

	# Apply CraftPix skin before any UI population (when embedded in TownHub)
	if use_craftpix_skin:
		_apply_craftpix_skin()

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
	print("[TownScene] script=%s" % get_script().resource_path)
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

	# Clear existing items in list (immediate removal prevents ghost nodes)
	_clear_children_immediate(stash_list_vbox)

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
			# Items v7: HBox with icon + label
			var tpl = DataRegistry.get_item_template(entry.template_id)
			var item_row = HBoxContainer.new()
			item_row.add_theme_constant_override("separation", 4)

			# Add item icon if available
			if tpl != null:
				var icon_rect = tpl.create_icon_rect(16)
				if icon_rect != null:
					item_row.add_child(icon_rect)

			var item_label = Label.new()
			# Add quality indicator if quality > 0
			var q_indicator = ""
			if entry.quality_tier > 0 and entry.quality_tier < quality_names.size():
				q_indicator = " [Q%d]" % entry.quality_tier
			item_label.text = "%s x%d%s" % [entry.display_name, entry.qty, q_indicator]

			# Items v6: Build tooltip with item details (equipment + consumable aware)
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
			item_label.tooltip_text = "\n".join(tooltip_parts)
			item_label.mouse_filter = Control.MOUSE_FILTER_STOP

			item_row.add_child(item_label)
			stash_list_vbox.add_child(item_row)
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

	# Guard: Require at least one party member
	if GameContext.selected_party.size() == 0:
		print("[TownUI] EnterDungeon BLOCKED - no heroes in party! Visit Inn to recruit.")
		progress_label.text = "Need at least 1 hero! Visit Inn to recruit."
		progress_label.modulate = Color(1, 0.5, 0.5, 1)
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
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


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
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


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

	# Close facility overlay if open
	if _is_facility_overlay_visible():
		_hide_facility_overlay()

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
	if _is_facility_overlay_visible():
		_refresh_facility_panel()


func _on_close_facility_pressed() -> void:
	_hide_facility_overlay()
	print("[FacilityUI] Close")


# ============================================================================
# FACILITIES
# ============================================================================

func _populate_facilities_list() -> void:
	# Clear existing facility buttons (immediate removal prevents ghost nodes)
	_clear_children_immediate(facilities_vbox)

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

	# CraftPix skin: use 2-column grid of styled buttons
	if use_craftpix_skin:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		facilities_vbox.add_child(grid)

		for facility_id in town.facility_ids:
			var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
			var button = Button.new()
			if facility != null:
				button.text = facility.display_name
				button.tooltip_text = "%s — %s" % [facility.display_name, facility.facility_type]
			else:
				button.text = facility_id
			button.custom_minimum_size = Vector2(0, 36)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.set_meta("facility_id", facility_id)
			button.pressed.connect(_on_facility_button_pressed.bind(facility_id))
			grid.add_child(button)
	else:
		# Default layout: centered buttons in a VBox
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
	print("[FacilityUI] Button pressed: %s" % facility_id)
	_show_facility_panel(facility_id)


## Public API: open a facility by type (e.g. "shop", "storage", "dungeon").
## Finds the matching facility_id for the current town and opens it.
func show_facility_by_type(facility_type: String) -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	if town == null:
		return
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		if facility != null and facility.facility_type == facility_type:
			_show_facility_panel(facility_id)
			return
	print("[TownUI] No facility of type '%s' in town '%s'" % [facility_type, town_id])


## Public API: open a facility by its exact ID (used by TownHub nav rail / map grid).
func show_facility_by_id(facility_id: String) -> void:
	_show_facility_panel(facility_id)


## Public API: switch to another town (used by TownHub travel buttons).
func switch_town(new_town_id: String) -> void:
	_switch_town(new_town_id)


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

	# Show overlay
	_show_facility_overlay()

	print("[FacilityUI] Open %s" % facility_id)


func _create_facility_actions(facility) -> void:
	# Reuse the same container — only clear its children.  Destroying and
	# recreating the container every refresh caused ghost duplicates when
	# Godot's Window viewport retained the old node for an extra frame.
	if _facility_actions_container == null:
		_facility_actions_container = VBoxContainer.new()
		_facility_actions_container.add_theme_constant_override("separation", 6)
		var close_idx = close_facility_button.get_index()
		_facility_content_vbox.add_child(_facility_actions_container)
		_facility_content_vbox.move_child(_facility_actions_container, close_idx)
	else:
		_clear_children_immediate(_facility_actions_container)

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
		"equipment":
			_build_equipment_ui()
		"training_hall":
			_build_training_ui()
		"inn":
			_build_inn_ui()
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

		# Materials: Show what recipes can be crafted with this item
		if item.category == "materials":
			var recipes = GameContext.get_recipes_using_material(item.template_id)
			if recipes.size() > 0:
				tooltip_parts.append("")
				tooltip_parts.append("Used in recipes:")
				for recipe_info in recipes:
					tooltip_parts.append("  • %s (%s)" % [recipe_info.recipe_name, recipe_info.facility_name])

		tooltip_parts.append("")
		tooltip_parts.append("Sell: %d gold" % tpl.base_value)
		label.tooltip_text = "\n".join(tooltip_parts)
		label.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable tooltip on hover
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

	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id
	var shop_id = _current_facility_id

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

	# Get shop tier and max tier
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)
	var max_tier = GameContext.get_facility_max_tier(facility_id)

	# Tier display with slot capacity
	var max_slots = GameContext.get_shop_max_slots(town_id)
	var allocated_slots = GameContext.get_shop_allocated_slots(town_id)
	var tier_label = Label.new()
	tier_label.text = "Store Tier: %d / %d" % [current_tier, max_tier]
	tier_label.modulate = Color(0.8, 0.9, 1.0, 1)
	_facility_actions_container.add_child(tier_label)

	# Slot capacity display
	var slots_label = Label.new()
	slots_label.text = "Shop Slots: %d / %d" % [allocated_slots, max_slots]
	slots_label.modulate = Color(0.7, 1.0, 0.7, 1) if allocated_slots < max_slots else Color(1.0, 0.9, 0.5, 1)
	_facility_actions_container.add_child(slots_label)

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
		var current_slots = GameContext.SHOP_TIER_MAX_SLOTS.get(current_tier, 4)
		var next_slots = GameContext.SHOP_TIER_MAX_SLOTS.get(next_tier, max_slots)
		var bonus_slots = next_slots - current_slots

		var upgrade_row = HBoxContainer.new()
		upgrade_row.add_theme_constant_override("separation", 8)

		var upgrade_label = Label.new()
		upgrade_label.text = "Tier %d (+%d slots): %s" % [next_tier, bonus_slots, cost_text]
		upgrade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_row.add_child(upgrade_label)

		var upgrade_btn = Button.new()
		upgrade_btn.text = "Upgrade" if can_upgrade else "Cannot Afford"
		upgrade_btn.custom_minimum_size = Vector2(100, 28)
		upgrade_btn.disabled = not can_upgrade
		upgrade_btn.pressed.connect(_on_facility_upgrade_pressed.bind(town_id, facility_id))
		upgrade_row.add_child(upgrade_btn)

		_facility_actions_container.add_child(upgrade_row)

	# Separator before facility slot allocation
	var alloc_sep = HSeparator.new()
	_facility_actions_container.add_child(alloc_sep)

	# Facility Slot Allocation Section
	var alloc_header = Label.new()
	alloc_header.text = "-- Facility Slot Allocation --"
	alloc_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alloc_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(alloc_header)

	# Show each contributing facility with +/- controls
	for contrib_facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		var facility_data = DataRegistry.get_facility(contrib_facility_id)
		var display_name = facility_data.display_name if facility_data != null else contrib_facility_id.capitalize()
		var current_alloc = GameContext.get_facility_slot_allocation(town_id, contrib_facility_id)
		var recipe_count = GameContext.get_facility_unlocked_recipes(contrib_facility_id).size()

		var alloc_row = HBoxContainer.new()
		alloc_row.add_theme_constant_override("separation", 8)

		# Facility name with recipe count
		var fac_label = Label.new()
		fac_label.text = "%s (%d recipes)" % [display_name, recipe_count]
		fac_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if recipe_count == 0:
			fac_label.modulate = Color(0.5, 0.5, 0.5, 1)
		alloc_row.add_child(fac_label)

		# Minus button
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(28, 28)
		minus_btn.disabled = current_alloc <= 0
		minus_btn.pressed.connect(_on_shop_slot_minus.bind(contrib_facility_id))
		alloc_row.add_child(minus_btn)

		# Slot count display
		var slot_count = Label.new()
		slot_count.text = "%d" % current_alloc
		slot_count.custom_minimum_size = Vector2(24, 0)
		slot_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alloc_row.add_child(slot_count)

		# Plus button
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(28, 28)
		# Disable if at max slots or no recipes unlocked
		plus_btn.disabled = allocated_slots >= max_slots or recipe_count == 0
		plus_btn.pressed.connect(_on_shop_slot_plus.bind(contrib_facility_id))
		alloc_row.add_child(plus_btn)

		_facility_actions_container.add_child(alloc_row)

	# Separator before items
	var items_sep = HSeparator.new()
	_facility_actions_container.add_child(items_sep)

	# Get context for seeded RNG
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var dungeon_id = town.dungeon_id if town != null else ""
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

	print("[ShopRNG] shop=%s town=%s profile=%s refresh=%d slots=%d/%d" % [shop_id, town_id, profile_id, refresh_count, allocated_slots, max_slots])

	# Facility-allocated equipment section (items based on slot allocation)
	var facility_items = _generate_facility_allocated_items(town_id, shop_rng)
	if facility_items.size() > 0:
		var equip_header = Label.new()
		equip_header.text = "-- Equipment for Sale --"
		equip_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_header.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(equip_header)

		for entry in facility_items:
			var slot_key = entry.get("slot_key", "")
			# Check if this slot was already purchased
			if slot_key != "" and GameContext.is_shop_slot_purchased(shop_id, slot_key):
				var empty_row = _create_empty_shop_slot_row()
				_facility_actions_container.add_child(empty_row)
			else:
				var row = _create_shop_row(entry, shop_id)
				_facility_actions_container.add_child(row)
	elif allocated_slots == 0:
		var no_alloc = Label.new()
		no_alloc.text = "(Allocate slots to facilities above to stock equipment)"
		no_alloc.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_alloc)
	else:
		var no_recipes = Label.new()
		no_recipes.text = "(No items available - unlock recipes at facilities)"
		no_recipes.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_recipes)

	# Bottom buttons row
	var bottom_sep = HSeparator.new()
	_facility_actions_container.add_child(bottom_sep)

	var buttons_row = HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 12)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Sell button - opens sell window
	var sell_btn = Button.new()
	sell_btn.text = "Sell Items"
	sell_btn.custom_minimum_size = Vector2(120, 32)
	sell_btn.pressed.connect(_on_shop_sell_pressed)
	buttons_row.add_child(sell_btn)

	# Note: Stock refreshes automatically when returning from dungeon

	_facility_actions_container.add_child(buttons_row)


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


## Generate shop items from unlocked recipes.
## Quality is rolled based on the source facility's tier at time of unlock.
func _generate_recipe_shop_items() -> Array:
	var result: Array = []
	var unlocked_recipe_ids = GameContext.get_all_unlocked_recipes()

	for item_id in unlocked_recipe_ids:
		var recipe_data = GameContext.get_recipe_data(item_id)
		if recipe_data.is_empty():
			continue

		var template = DataRegistry.get_item_template(item_id)
		if template == null:
			continue

		# Only include equipment items (not consumables which are in the regular pool)
		if template.equip_slot == "":
			continue

		# Get facility tier from recipe data
		var facility_tier = recipe_data.get("facility_tier", 1)

		# Roll quality based on facility tier
		var quality_tier = GameContext.roll_quality_for_facility_tier(facility_tier)

		# Calculate price based on template value and quality
		var base_price = template.get_buy_value()
		var quality_mult = [1.0, 1.2, 1.5, 2.0]  # Price multiplier per quality
		var final_price = int(base_price * quality_mult[quality_tier])

		result.append({
			"type": "item",
			"item_id": item_id,
			"price_gold": final_price,
			"quality_tier": quality_tier,
			"source_facility": recipe_data.get("source_facility", ""),
			"from_recipe": true
		})

	# Sort by item name for consistent display
	result.sort_custom(func(a, b):
		var name_a = DataRegistry.get_item_template(a.get("item_id", ""))
		var name_b = DataRegistry.get_item_template(b.get("item_id", ""))
		var display_a = name_a.display_name if name_a else a.get("item_id", "")
		var display_b = name_b.display_name if name_b else b.get("item_id", "")
		return display_a < display_b
	)

	print("[ShopRecipes] generated %d items from unlocked recipes" % result.size())
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


## Handle shop slot allocation plus button.
func _on_shop_slot_plus(facility_id: String) -> void:
	var town_id = GameContext.get_current_town_id()
	var success = GameContext.increment_facility_slots(town_id, facility_id)
	if success:
		print("[Shop] slot_plus facility=%s" % facility_id)
		_refresh_facility_panel()


## Handle shop slot allocation minus button.
func _on_shop_slot_minus(facility_id: String) -> void:
	var town_id = GameContext.get_current_town_id()
	var success = GameContext.decrement_facility_slots(town_id, facility_id)
	if success:
		print("[Shop] slot_minus facility=%s" % facility_id)
		_refresh_facility_panel()


## Handle shop sell button - opens sell items window.
func _on_shop_sell_pressed() -> void:
	_show_sell_window()


## Show sell items window with all sellable items from storage.
func _show_sell_window() -> void:
	# Create popup window
	var popup = Window.new()
	popup.title = "Sell Items"
	popup.size = Vector2i(400, 500)
	popup.transient = true
	popup.exclusive = true

	# Center on screen
	var screen_size = DisplayServer.screen_get_size()
	popup.position = Vector2i((screen_size.x - popup.size.x) / 2, (screen_size.y - popup.size.y) / 2)

	# Main container with margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	popup.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Gold display
	var gold_label = Label.new()
	gold_label.text = "Current Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	vbox.add_child(gold_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Scroll container for items
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)

	var items_vbox = VBoxContainer.new()
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(items_vbox)

	# Get sellable items
	var sellable_items = _get_sellable_stash_items()

	if sellable_items.size() == 0:
		var no_items = Label.new()
		no_items.text = "(No items to sell)"
		no_items.modulate = Color(0.6, 0.6, 0.6, 1)
		items_vbox.add_child(no_items)
	else:
		for item in sellable_items:
			var row = _create_sell_window_row(item, popup, gold_label, items_vbox)
			items_vbox.add_child(row)

	# Close button at bottom
	var close_sep = HSeparator.new()
	vbox.add_child(close_sep)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func():
		popup.queue_free()
		_refresh_facility_panel()  # Refresh shop to update gold display
	)
	vbox.add_child(close_btn)

	# Handle window close
	popup.close_requested.connect(func():
		popup.queue_free()
		_refresh_facility_panel()
	)

	add_child(popup)
	popup.show()


## Create a row for the sell window.
func _create_sell_window_row(item: Dictionary, popup: Window, gold_label: Label, items_container: VBoxContainer) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var template_id = item.get("item_id", "")
	var qty = item.get("qty", 0)
	var quality_tier = item.get("quality_tier", 0)

	# Get display name
	var display_name = template_id
	var template = DataRegistry.get_item_template(template_id)
	if template != null and template.display_name != "":
		display_name = template.display_name

	# Quality prefix
	var quality_prefix = ItemInstance.QUALITY_PREFIXES[quality_tier] if quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
	if quality_prefix != "":
		display_name = "%s %s" % [quality_prefix, display_name]

	# Calculate sell price
	var sell_price = 1
	if template != null:
		sell_price = template.get_sell_value()
		var quality_mult = [1.0, 1.1, 1.2, 1.35]
		sell_price = int(sell_price * quality_mult[quality_tier])

	# Item name and quantity
	var name_label = Label.new()
	name_label.text = "%s x%d" % [display_name, qty]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Quality color
	var quality_colors = [Color.WHITE, Color(0.4, 0.8, 0.4), Color(0.4, 0.6, 1.0), Color(0.8, 0.4, 1.0)]
	name_label.modulate = quality_colors[quality_tier] if quality_tier < quality_colors.size() else Color.WHITE
	row.add_child(name_label)

	# Price label
	var price_label = Label.new()
	price_label.text = "%dg ea" % sell_price
	price_label.modulate = Color(0.8, 0.8, 0.8, 1)
	row.add_child(price_label)

	# Sell 1 button
	var sell_one_btn = Button.new()
	sell_one_btn.text = "Sell 1"
	sell_one_btn.custom_minimum_size = Vector2(60, 26)
	sell_one_btn.pressed.connect(func():
		_do_sell_item(template_id, 1, quality_tier)
		_refresh_sell_window(popup, gold_label, items_container)
	)
	row.add_child(sell_one_btn)

	# Sell All button (if qty > 1)
	if qty > 1:
		var sell_all_btn = Button.new()
		sell_all_btn.text = "Sell All"
		sell_all_btn.custom_minimum_size = Vector2(70, 26)
		sell_all_btn.pressed.connect(func():
			_do_sell_item(template_id, qty, quality_tier)
			_refresh_sell_window(popup, gold_label, items_container)
		)
		row.add_child(sell_all_btn)

	return row


## Execute selling an item.
func _do_sell_item(template_id: String, qty: int, quality_tier: int) -> void:
	var template = DataRegistry.get_item_template(template_id)
	if template == null:
		return

	var sell_price = template.get_sell_value()
	var quality_mult = [1.0, 1.1, 1.2, 1.35]
	sell_price = int(sell_price * quality_mult[quality_tier])

	var gold_before = GameContext.get_run_gold()
	var removed = GameContext.remove_run_items(template_id, qty)
	var total_gain = removed * sell_price
	GameContext.add_run_gold(total_gain)
	var gold_after = GameContext.get_run_gold()

	print("[Store] sell item=%s qty=%d gain=%d gold_before=%d gold_after=%d" % [
		template_id, removed, total_gain, gold_before, gold_after])


## Refresh the sell window contents.
func _refresh_sell_window(popup: Window, gold_label: Label, items_container: VBoxContainer) -> void:
	# Update gold display
	gold_label.text = "Current Gold: %d" % GameContext.get_run_gold()

	# Clear and rebuild items list
	for child in items_container.get_children():
		child.queue_free()

	var sellable_items = _get_sellable_stash_items()

	if sellable_items.size() == 0:
		var no_items = Label.new()
		no_items.text = "(No items to sell)"
		no_items.modulate = Color(0.6, 0.6, 0.6, 1)
		items_container.add_child(no_items)
	else:
		for item in sellable_items:
			var row = _create_sell_window_row(item, popup, gold_label, items_container)
			items_container.add_child(row)


## Generate equipment items based on facility slot allocations.
## Each allocated slot generates one item from that facility's unlocked recipes.
## Each facility gets its own seeded RNG to avoid cross-contamination when allocations change.
func _generate_facility_allocated_items(town_id: String, base_rng: RandomNumberGenerator) -> Array:
	var result: Array = []

	for facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		var slots = GameContext.get_facility_slot_allocation(town_id, facility_id)
		if slots <= 0:
			continue

		# Get unlocked recipes for this facility
		var recipes = GameContext.get_facility_unlocked_recipes(facility_id)
		if recipes.is_empty():
			continue

		# Create a separate RNG for this facility so allocations don't affect other facilities
		var facility_seed = ("%s_%s" % [base_rng.seed, facility_id]).hash()
		var facility_rng = RandomNumberGenerator.new()
		facility_rng.seed = facility_seed

		# Generate one item per allocated slot
		for i in range(slots):
			# Create unique slot key for tracking purchases
			var slot_key = "%s:%d" % [facility_id, i]

			# Pick a random recipe (seeded per facility)
			var recipe_idx = facility_rng.randi() % recipes.size()
			var item_id = recipes[recipe_idx]

			var template = DataRegistry.get_item_template(item_id)
			if template == null:
				continue

			# Get facility tier for quality roll
			var recipe_data = GameContext.get_recipe_data(item_id)
			var facility_tier = recipe_data.get("facility_tier", 1)

			# Roll quality based on facility tier (seeded per facility)
			var quality_roll = facility_rng.randf() * 100.0
			var quality_tier = _roll_quality_seeded(quality_roll, facility_tier)

			# Calculate price based on template value and quality
			var base_price = template.get_buy_value()
			var quality_mult = [1.0, 1.2, 1.5, 2.0]  # Price multiplier per quality
			var final_price = int(base_price * quality_mult[quality_tier])

			result.append({
				"type": "item",
				"item_id": item_id,
				"price_gold": final_price,
				"quality_tier": quality_tier,
				"source_facility": facility_id,
				"slot_key": slot_key,
				"from_recipe": true
			})

	# Sort by facility then item name for consistent display
	result.sort_custom(func(a, b):
		var fac_a = a.get("source_facility", "")
		var fac_b = b.get("source_facility", "")
		if fac_a != fac_b:
			return fac_a < fac_b
		var name_a = DataRegistry.get_item_template(a.get("item_id", ""))
		var name_b = DataRegistry.get_item_template(b.get("item_id", ""))
		var display_a = name_a.display_name if name_a else a.get("item_id", "")
		var display_b = name_b.display_name if name_b else b.get("item_id", "")
		return display_a < display_b
	)

	print("[ShopFacility] generated %d items from %d allocated slots" % [result.size(), GameContext.get_shop_allocated_slots(town_id)])
	return result


## Roll quality tier based on facility tier using a seeded roll value.
func _roll_quality_seeded(roll: float, facility_tier: int) -> int:
	match facility_tier:
		1:  # 85% Common, 14% Uncommon, 1% Rare, 0% Epic
			if roll < 85.0: return 0
			elif roll < 99.0: return 1
			else: return 2
		2:  # 55% Common, 30% Uncommon, 10% Rare, 5% Epic
			if roll < 55.0: return 0
			elif roll < 85.0: return 1
			elif roll < 95.0: return 2
			else: return 3
		3:  # 35% Common, 40% Uncommon, 15% Rare, 10% Epic
			if roll < 35.0: return 0
			elif roll < 75.0: return 1
			elif roll < 90.0: return 2
			else: return 3
		_:
			return 0  # Unknown tier = common


func _create_shop_row(shop_item: Dictionary, shop_id: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = shop_item.get("item_id", "")
	var price = shop_item.get("price_gold", 0)
	var quality_tier = int(shop_item.get("quality_tier", 0))
	var slot_key = shop_item.get("slot_key", "")

	# Get display name from template
	var display_name = item_id
	var template = DataRegistry.get_item_template(item_id) if DataRegistry.has_method("get_item_template") else null
	if template != null and template.display_name != "":
		display_name = template.display_name

	# Quality prefix and color
	var quality_prefix = ItemInstance.QUALITY_PREFIXES[quality_tier] if quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
	var quality_colors = [Color.WHITE, Color.GREEN, Color.CORNFLOWER_BLUE, Color.MEDIUM_PURPLE]
	var text_color = quality_colors[quality_tier] if quality_tier < quality_colors.size() else Color.WHITE

	# Build tooltip with item stats
	var tooltip_text = _build_item_tooltip(template, quality_tier)

	# Item icon + name label with quality
	if template != null:
		var icon_rect = template.create_icon_rect(18)
		if icon_rect != null:
			row.add_child(icon_rect)

	var name_label = Label.new()
	if quality_tier > 0 or shop_item.get("from_recipe", false):
		name_label.text = "Q%d %s%s (%d gold)" % [quality_tier, quality_prefix, display_name, price]
	else:
		name_label.text = "%s (%d gold)" % [display_name, price]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.modulate = text_color
	name_label.tooltip_text = tooltip_text
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable tooltip on hover
	row.add_child(name_label)

	# Buy button (uses run stash gold)
	var can_afford = GameContext.get_run_gold() >= price
	var btn = Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(60, 26)
	btn.disabled = not can_afford
	btn.pressed.connect(_on_shop_buy_pressed.bind(item_id, price, quality_tier, shop_id, slot_key))
	row.add_child(btn)

	return row


## Create an empty slot row to show where a purchased item was.
func _create_empty_shop_slot_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var empty_label = Label.new()
	empty_label.text = "[Empty Slot]"
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_label.modulate = Color(0.4, 0.4, 0.4, 1)
	row.add_child(empty_label)

	# Placeholder for button alignment
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(60, 26)
	row.add_child(spacer)

	return row


## Build tooltip text showing item stats.
func _build_item_tooltip(template, quality_tier: int) -> String:
	if template == null:
		return ""

	var lines: Array[String] = []

	# Item name and description
	lines.append(template.display_name)
	if template.description != "":
		lines.append(template.description)
	lines.append("")

	# Equipment slot
	var slot = template.equip_slot if template.equip_slot != "" else template.slot
	if slot != "":
		lines.append("Slot: %s" % slot.capitalize())

	# Quality multiplier
	var quality_names = ["Common", "Uncommon", "Rare", "Epic"]
	var quality_mults = [1.0, 1.1, 1.2, 1.35]
	var quality_name = quality_names[quality_tier] if quality_tier < quality_names.size() else "Common"
	var quality_mult = quality_mults[quality_tier] if quality_tier < quality_mults.size() else 1.0
	lines.append("Quality: %s (x%.2f stats)" % [quality_name, quality_mult])
	lines.append("")

	# Stats with quality scaling
	var base_stats = template.base_stats if template.base_stats != null else {}
	var stat_bonuses = template.stat_bonuses if template.stat_bonuses != null else {}

	# Combine base_stats and stat_bonuses (they often contain the same data)
	var all_stats = {}
	for key in base_stats.keys():
		all_stats[key] = base_stats[key]
	for key in stat_bonuses.keys():
		if not all_stats.has(key):
			all_stats[key] = stat_bonuses[key]

	if all_stats.size() > 0:
		lines.append("Stats:")
		for stat_name in all_stats.keys():
			var base_value = int(all_stats[stat_name])
			var scaled_value = int(base_value * quality_mult)
			lines.append("  +%d %s" % [scaled_value, stat_name.capitalize()])

	return "\n".join(lines)


func _on_shop_buy_pressed(item_id: String, price: int, quality_tier: int = 0, shop_id: String = "", slot_key: String = "") -> void:
	var had_gold = GameContext.get_run_gold()
	if had_gold < price:
		print("[Store] buy item=%s qty=1 cost=%d gold_before=%d gold_after=FAIL (insufficient)" % [item_id, price, had_gold])
		return

	GameContext.spend_run_gold(price)

	# Add item with quality tier
	if quality_tier > 0:
		GameContext._add_item_with_quality(item_id, quality_tier)
	else:
		GameContext.add_run_item(item_id, 1)

	# Mark the slot as purchased so it shows as empty
	if shop_id != "" and slot_key != "":
		GameContext.mark_shop_slot_purchased(shop_id, slot_key)

	print("[Store] buy item=%s qty=1 q=%d cost=%d gold_before=%d gold_after=%d slot=%s" % [item_id, quality_tier, price, had_gold, GameContext.get_run_gold(), slot_key])
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


# ============================================================================
# EQUIPMENT FACILITY UI (Blacksmith, Huntsman, Enchanter - Per-Recipe Unlocking)
# ============================================================================

func _build_equipment_ui() -> void:
	if _current_facility == null:
		return

	var facility = _current_facility
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)
	var max_tier = facility.max_tier

	# Header with facility info
	var header = Label.new()
	header.text = "=== %s (Tier %d / %d) ===" % [facility.display_name, current_tier, max_tier]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	# Gold display
	var run_gold = GameContext.get_run_gold()
	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % run_gold
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Upgrade button (if not max tier)
	if current_tier < max_tier:
		var upgrade_row = _create_equipment_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

	var sep1 = HSeparator.new()
	_facility_actions_container.add_child(sep1)

	# Explanation label
	var explain_label = Label.new()
	explain_label.text = "Unlock recipes to add items to the General Store"
	explain_label.add_theme_font_size_override("font_size", 11)
	explain_label.modulate = Color(0.6, 0.8, 0.6, 1)
	explain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(explain_label)

	# Tab buttons: All | Locked | Unlocked
	var tab_row = HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tab_row)

	var tabs = ["all", "locked", "unlocked"]
	var tab_labels = {"all": "All Recipes", "locked": "Locked", "unlocked": "Unlocked"}
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab_labels[tab]
		btn.custom_minimum_size = Vector2(90, 26)
		btn.disabled = (_equipment_tab == tab)
		btn.pressed.connect(_on_equipment_tab_pressed.bind(tab))
		tab_row.add_child(btn)

	# Equipment type filter buttons
	var filter_label = Label.new()
	filter_label.text = "-- Filter by Type --"
	filter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	filter_label.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(filter_label)

	var filter_row1 = HBoxContainer.new()
	filter_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row1.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row1)

	var filter_row2 = HBoxContainer.new()
	filter_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row2.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row2)

	# Filter buttons organized in two rows
	var filters_row1 = ["all", "1h_weapon", "2h_weapon", "offhand"]
	var filters_row2 = ["helmet", "armor", "legs", "accessory", "backpack"]
	var filter_labels = {
		"all": "All",
		"1h_weapon": "1H Weps",
		"2h_weapon": "2H Weps",
		"offhand": "Off Hand",
		"helmet": "Helm",
		"armor": "Body",
		"legs": "Legs",
		"accessory": "Accessory",
		"backpack": "Backpack"
	}

	for f in filters_row1:
		var btn = Button.new()
		btn.text = filter_labels.get(f, f.capitalize())
		btn.custom_minimum_size = Vector2(70, 24)
		btn.disabled = (_equipment_type_filter == f)
		btn.pressed.connect(_on_equipment_filter_pressed.bind(f))
		filter_row1.add_child(btn)

	for f in filters_row2:
		var btn = Button.new()
		btn.text = filter_labels.get(f, f.capitalize())
		btn.custom_minimum_size = Vector2(70, 24)
		btn.disabled = (_equipment_type_filter == f)
		btn.pressed.connect(_on_equipment_filter_pressed.bind(f))
		filter_row2.add_child(btn)

	var sep2 = HSeparator.new()
	_facility_actions_container.add_child(sep2)

	# Get and filter recipes
	var recipes = _get_filtered_equipment_recipes(facility, current_tier)

	# Recipe count
	var count_label = Label.new()
	count_label.text = "Showing %d recipes" % recipes.size()
	count_label.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(count_label)

	if recipes.size() == 0:
		var no_recipes = Label.new()
		no_recipes.text = "(No recipes match current filters)"
		no_recipes.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_recipes)
	else:
		for recipe in recipes:
			var recipe_row = _create_equipment_recipe_row(recipe, facility_id, current_tier)
			_facility_actions_container.add_child(recipe_row)

	print("[EquipmentUI] facility=%s tier=%d tab=%s filter=%s recipes_shown=%d" % [
		facility_id, current_tier, _equipment_tab, _equipment_type_filter, recipes.size()])


func _get_filtered_equipment_recipes(facility, current_tier: int) -> Array:
	var all_recipes = facility.crafting_recipes
	var filtered: Array = []

	for recipe in all_recipes:
		var output_id = recipe.get("output_id", "")
		var required_tier = recipe.get("required_tier", 1)
		var equipment_type = recipe.get("equipment_type", "")
		var is_unlocked = GameContext.is_recipe_unlocked(output_id)
		var is_tier_locked = required_tier > current_tier

		# Filter by tab
		match _equipment_tab:
			"locked":
				if is_unlocked:
					continue
			"unlocked":
				if not is_unlocked:
					continue
			# "all" shows everything

		# Filter by equipment type
		if _equipment_type_filter != "all":
			if equipment_type != _equipment_type_filter:
				continue

		# Add to filtered list with metadata
		filtered.append({
			"recipe": recipe,
			"is_unlocked": is_unlocked,
			"is_tier_locked": is_tier_locked
		})

	return filtered


func _create_equipment_recipe_row(recipe_data: Dictionary, facility_id: String, current_tier: int) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var recipe = recipe_data.get("recipe", {})
	var is_unlocked = recipe_data.get("is_unlocked", false)
	var is_tier_locked = recipe_data.get("is_tier_locked", false)

	var output_id = recipe.get("output_id", "")
	var required_tier = recipe.get("required_tier", 1)
	var equipment_type = recipe.get("equipment_type", "")
	var unlock_cost = recipe.get("unlock_cost", [])

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Type label
	var type_str = _get_equipment_type_label(equipment_type)

	# Icon + name row with status
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)

	if output_template != null:
		var icon_rect = output_template.create_icon_rect(18)
		if icon_rect != null:
			name_row.add_child(icon_rect)

	var name_label = Label.new()
	if is_unlocked:
		var status = "[DEFAULT]" if GameContext.DEFAULT_UNLOCKED_RECIPES.has(output_id) else "[UNLOCKED]"
		name_label.text = "%s %s (%s)" % [status, output_name, type_str]
		name_label.modulate = Color(0.5, 0.9, 0.5, 1)
	elif is_tier_locked:
		name_label.text = "[TIER %d] %s (%s)" % [required_tier, output_name, type_str]
		name_label.modulate = Color(0.5, 0.5, 0.5, 1)
		container.modulate = Color(0.6, 0.6, 0.6, 1)
	else:
		name_label.text = "%s (%s)" % [output_name, type_str]
	name_row.add_child(name_label)
	container.add_child(name_row)

	# Add tooltip with item stats
	if output_template != null:
		name_label.tooltip_text = _build_equipment_item_tooltip(output_template)
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP

	# If unlocked, just show availability message
	if is_unlocked:
		var unlocked_label = Label.new()
		unlocked_label.text = "  Available in General Store"
		unlocked_label.add_theme_font_size_override("font_size", 11)
		unlocked_label.modulate = Color(0.6, 0.8, 0.6, 1)
		container.add_child(unlocked_label)
		return container

	# If tier locked, show what tier is needed
	if is_tier_locked:
		var tier_label = Label.new()
		tier_label.text = "  Requires Tier %d facility" % required_tier
		tier_label.add_theme_font_size_override("font_size", 11)
		tier_label.modulate = Color(0.6, 0.6, 0.6, 1)
		container.add_child(tier_label)
		return container

	# Show unlock cost
	var cost_parts = []
	var run_items_dict = GameContext.get_run_items_dict()
	var can_afford = true

	for cost_entry in unlock_cost:
		var item_id = cost_entry.get("item_id", "")
		var qty_needed = cost_entry.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	cost_label.text = "  Unlock cost: %s" % ", ".join(cost_parts)
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	container.add_child(cost_label)

	# Unlock button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 28)
	if can_afford:
		btn.text = "Unlock Recipe"
		btn.disabled = false
		btn.pressed.connect(_on_equipment_unlock_pressed.bind(output_id, unlock_cost, facility_id, current_tier))
	else:
		btn.text = "Need Materials"
		btn.disabled = true
	container.add_child(btn)

	return container


func _create_equipment_facility_upgrade_row(facility, current_tier: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var next_tier = current_tier + 1
	var tier_key = str(next_tier)

	# Get upgrade cost
	var upgrade_cost = {}
	if facility.upgrade_costs.has(tier_key):
		upgrade_cost = facility.upgrade_costs[tier_key]
	elif facility.upgrade_costs.has(next_tier):
		upgrade_cost = facility.upgrade_costs[next_tier]

	var gold_cost = int(upgrade_cost.get("gold", 0))
	var item_costs = upgrade_cost.get("items", [])

	# Cost display
	var cost_parts = []
	if gold_cost > 0:
		cost_parts.append("%dg" % gold_cost)

	var can_afford = GameContext.get_run_gold() >= gold_cost
	var run_items_dict = GameContext.get_run_items_dict()

	for item_cost in item_costs:
		var item_id = item_cost.get("item_id", "")
		var qty_needed = item_cost.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	cost_label.text = "Upgrade to Tier %d: %s" % [next_tier, ", ".join(cost_parts)]
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	row.add_child(cost_label)

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(80, 26)
	upgrade_btn.disabled = not can_afford
	upgrade_btn.pressed.connect(_on_equipment_facility_upgrade_pressed.bind(facility.facility_id, next_tier, gold_cost, item_costs))
	row.add_child(upgrade_btn)

	return row


func _get_equipment_type_label(equipment_type: String) -> String:
	var labels = {
		"1h_weapon": "1H Weapon",
		"2h_weapon": "2H Weapon",
		"offhand": "Off Hand",
		"helmet": "Helmet",
		"armor": "Body Armor",
		"legs": "Legs",
		"accessory": "Accessory",
		"backpack": "Backpack"
	}
	return labels.get(equipment_type, equipment_type.capitalize())


func _build_equipment_item_tooltip(template) -> String:
	var lines = []
	lines.append(template.display_name)

	if template.description != "":
		lines.append(template.description)

	# Stats - use get_stat_bonuses_with_quality() for proper dictionary access
	var bonuses = template.get_stat_bonuses_with_quality(0)  # 0 = common quality
	if bonuses.get("attack", 0) > 0:
		lines.append("ATK: +%d" % bonuses.get("attack", 0))
	if bonuses.get("defense", 0) > 0:
		lines.append("DEF: +%d" % bonuses.get("defense", 0))
	if bonuses.get("health", 0) > 0:
		lines.append("HP: +%d" % bonuses.get("health", 0))
	if bonuses.get("speed", 0) > 0:
		lines.append("SPD: +%d" % bonuses.get("speed", 0))

	# Slot type - use modern equip_slot property
	if template.equip_slot != "":
		lines.append("Slot: %s" % template.equip_slot.capitalize())

	return "\n".join(lines)


func _on_equipment_tab_pressed(tab: String) -> void:
	_equipment_tab = tab
	_refresh_facility_panel()


func _on_equipment_filter_pressed(filter: String) -> void:
	_equipment_type_filter = filter
	_refresh_facility_panel()


func _on_equipment_unlock_pressed(output_id: String, unlock_cost: Array, facility_id: String, facility_tier: int) -> void:
	var success = GameContext.purchase_recipe_unlock(output_id, unlock_cost, facility_id, facility_tier)
	if success:
		print("[EquipmentUI] unlocked recipe=%s facility=%s tier=%d" % [output_id, facility_id, facility_tier])
	else:
		print("[EquipmentUI] unlock_failed recipe=%s" % output_id)
	_refresh_facility_panel()


func _on_equipment_facility_upgrade_pressed(facility_id: String, new_tier: int, gold_cost: int, item_costs: Array) -> void:
	var town_id = GameContext.get_current_town_id()
	var tier_before = GameContext.get_facility_tier(town_id, facility_id)

	# Use the centralized upgrade_facility which handles validation, spending, and saving
	if GameContext.upgrade_facility(town_id, facility_id):
		var tier_after = GameContext.get_facility_tier(town_id, facility_id)
		print("[EquipmentUI] upgraded facility=%s tier=%d->%d gold_cost=%d" % [facility_id, tier_before, tier_after, gold_cost])
	else:
		print("[EquipmentUI] upgrade_failed facility=%s tier=%d" % [facility_id, tier_before])

	_refresh_facility_panel()


func _create_crafting_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var output_id = recipe.get("output_id", "")
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Check if already unlocked
	var is_unlocked = GameContext.is_recipe_unlocked(output_id)

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Recipe name with unlock status
	var name_label = Label.new()
	if is_unlocked:
		var status = "[DEFAULT]" if GameContext.DEFAULT_UNLOCKED_RECIPES.has(output_id) else "[UNLOCKED]"
		name_label.text = "Recipe: %s %s" % [output_name, status]
		name_label.modulate = Color(0.5, 0.9, 0.5, 1)  # Green for unlocked
	else:
		name_label.text = "Recipe: %s" % output_name
	container.add_child(name_label)

	# If already unlocked, show craft option (if recipe has inputs) or shop message
	if is_unlocked:
		if inputs.size() > 0:
			# Recipe has material inputs - show Craft button
			var run_items_dict = GameContext.get_run_items_dict()
			var can_craft = true
			var cost_parts = []

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
					can_craft = false

			var cost_label = Label.new()
			cost_label.text = "  Craft cost: %s" % ", ".join(cost_parts)
			cost_label.add_theme_font_size_override("font_size", 11)
			cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_craft else Color(1, 0.5, 0.5, 1)
			container.add_child(cost_label)

			var craft_btn = Button.new()
			craft_btn.custom_minimum_size = Vector2(120, 28)
			if can_craft:
				craft_btn.text = "Craft"
				craft_btn.disabled = false
				craft_btn.pressed.connect(_on_craft_recipe_pressed.bind(recipe))
			else:
				craft_btn.text = "Need Materials"
				craft_btn.disabled = true
			container.add_child(craft_btn)
		else:
			# No inputs - just show shop availability
			var unlocked_label = Label.new()
			unlocked_label.text = "  Available in General Store"
			unlocked_label.add_theme_font_size_override("font_size", 11)
			unlocked_label.modulate = Color(0.6, 0.8, 0.6, 1)
			container.add_child(unlocked_label)
		return container

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

	# Gold cost display (if any)
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

	# Unlock button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 28)
	if can_afford:
		btn.text = "Unlock"
		btn.disabled = false
		btn.pressed.connect(_on_unlock_recipe_pressed.bind(recipe))
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


## Unlock a recipe so its item appears in the General Store.
func _on_unlock_recipe_pressed(recipe: Dictionary) -> void:
	var output_id = recipe.get("output_id", "")
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Check if already unlocked
	if GameContext.is_recipe_unlocked(output_id):
		print("[Recipe] Already unlocked: %s" % output_id)
		_refresh_facility_panel()
		return

	# Verify gold cost
	if cost_gold > 0 and GameContext.get_run_gold() < cost_gold:
		print("[Recipe] unlock_failed item=%s reason=insufficient_gold need=%d have=%d" % [output_id, cost_gold, GameContext.get_run_gold()])
		return

	# Verify materials
	var run_items_dict = GameContext.get_run_items_dict()
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		if qty_have < qty_needed:
			print("[Recipe] unlock_failed item=%s reason=missing_%s need=%d have=%d" % [output_id, item_id, qty_needed, qty_have])
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

	# Get facility info for recipe unlock
	var facility_id = _current_facility.facility_id if _current_facility != null else "unknown"
	var town_id = GameContext.get_current_town_id()
	var facility_tier = GameContext.get_facility_tier(town_id, facility_id)

	# Unlock the recipe
	GameContext.unlock_recipe(output_id, facility_id, facility_tier)

	print("[Recipe] unlocked item=%s facility=%s tier=%d consumed=[%s] gold_spent=%d" % [
		output_id, facility_id, facility_tier, ", ".join(consumed_parts), cost_gold])

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

	# Label: book name x qty with icon
	if tpl != null:
		var icon_rect = tpl.create_icon_rect(18)
		if icon_rect != null:
			row.add_child(icon_rect)
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
	# Clear existing dynamic content (immediate removal prevents ghost nodes)
	_clear_children_immediate(heroes_vbox)

	var party = GameContext.get_selected_party()
	var roster_size = GameContext.get_roster().size()

	# Party summary line
	var summary_label = Label.new()
	summary_label.text = "Party: %d / %d  |  Roster: %d" % [
		party.size(), GameContext.MAX_PARTY_SIZE, roster_size
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

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	heroes_vbox.add_child(btn_row)

	# "Visit Inn" button to open Inn facility popup
	var inn_btn = Button.new()
	inn_btn.text = "Visit Inn (Recruit / Party)"
	inn_btn.custom_minimum_size = Vector2(200, 30)
	inn_btn.pressed.connect(_on_visit_inn_pressed)
	btn_row.add_child(inn_btn)

	# "Manage Bags" button to open hero bag management (only if party exists)
	if party.size() > 0:
		var bags_btn = Button.new()
		bags_btn.text = "Manage Hero Bags"
		bags_btn.custom_minimum_size = Vector2(150, 30)
		bags_btn.pressed.connect(_on_manage_bags_pressed)
		btn_row.add_child(bags_btn)


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
# HERO BAG MANAGEMENT (Town Consumable Transfer)
# ============================================================================

var _bag_management_window: Window = null

## Open the hero bag management popup to transfer consumables.
func _on_manage_bags_pressed() -> void:
	if _bag_management_window != null and is_instance_valid(_bag_management_window):
		_bag_management_window.queue_free()
		_bag_management_window = null

	_bag_management_window = Window.new()
	_bag_management_window.title = "Manage Hero Bags"
	_bag_management_window.size = Vector2i(600, 500)
	_bag_management_window.position = Vector2i(
		int((get_viewport().get_visible_rect().size.x - 600) / 2),
		int((get_viewport().get_visible_rect().size.y - 500) / 2)
	)
	_bag_management_window.transient = true
	_bag_management_window.exclusive = false
	_bag_management_window.close_requested.connect(_close_bag_management_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 10
	main_vbox.offset_top = 10
	main_vbox.offset_right = -10
	main_vbox.offset_bottom = -10
	main_vbox.add_theme_constant_override("separation", 12)
	_bag_management_window.add_child(main_vbox)

	_populate_bag_management_ui(main_vbox)

	add_child(_bag_management_window)
	_bag_management_window.popup_centered()
	print("[BagMgmt] opened")


func _close_bag_management_window() -> void:
	if _bag_management_window != null and is_instance_valid(_bag_management_window):
		_bag_management_window.queue_free()
		_bag_management_window = null
	print("[BagMgmt] closed")


func _populate_bag_management_ui(container: VBoxContainer) -> void:
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# --- Section 1: Shopkeeper Stash Consumables ---
	var stash_header = Label.new()
	stash_header.text = "-- Stash Consumables --"
	stash_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stash_header.modulate = Color(1, 0.9, 0.5, 1)
	container.add_child(stash_header)

	var run_items = GameContext.get_run_items_dict()
	var consumables_in_stash: Array = []

	for item_id in run_items.keys():
		var template = DataRegistry.get_item_template(item_id)
		if template != null and template.item_type == "consumable":
			consumables_in_stash.append({
				"item_id": item_id,
				"qty": run_items[item_id],
				"template": template
			})

	if consumables_in_stash.size() == 0:
		var no_items = Label.new()
		no_items.text = "(No consumables in stash)"
		no_items.modulate = Color(0.6, 0.6, 0.6, 1)
		container.add_child(no_items)
	else:
		for item_info in consumables_in_stash:
			var row = _create_stash_consumable_row(item_info, container)
			container.add_child(row)

	# Separator
	var sep = HSeparator.new()
	container.add_child(sep)

	# --- Section 2: Party Hero Bags ---
	var party_header = Label.new()
	party_header.text = "-- Party Hero Bags --"
	party_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_header.modulate = Color(0.5, 1, 0.5, 1)
	container.add_child(party_header)

	var party = GameContext.get_selected_party()
	if party.size() == 0:
		var no_party = Label.new()
		no_party.text = "(No heroes in party)"
		no_party.modulate = Color(0.6, 0.6, 0.6, 1)
		container.add_child(no_party)
	else:
		for hero_id in party:
			var hero_section = _create_hero_bag_section(hero_id, container)
			container.add_child(hero_section)


func _create_stash_consumable_row(item_info: Dictionary, parent_container: VBoxContainer) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = item_info.get("item_id", "")
	var qty = item_info.get("qty", 0)
	var template = item_info.get("template")
	var display_name = template.display_name if template else item_id

	# Item label
	var label = Label.new()
	label.text = "%s x%d" % [display_name, qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# "Give to" dropdown for each hero in party
	var party = GameContext.get_selected_party()
	for hero_id in party:
		var hero_data = GameContext.get_hero(hero_id)
		var hero_name = hero_data.get("name", hero_id) if hero_data else hero_id

		var give_btn = Button.new()
		give_btn.text = "→ %s" % hero_name
		give_btn.custom_minimum_size = Vector2(90, 24)

		# Check if hero can receive item
		var can_add = GameContext.can_add_to_hero_bag(hero_id, item_id, 1)
		give_btn.disabled = not can_add
		if can_add:
			give_btn.pressed.connect(_on_give_to_hero_pressed.bind(item_id, hero_id, parent_container))

		row.add_child(give_btn)

	return row


func _create_hero_bag_section(hero_id: String, parent_container: VBoxContainer) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var hero_data = GameContext.get_hero(hero_id)
	var hero_name = hero_data.get("name", hero_id) if hero_data else hero_id
	var bag = GameContext.get_hero_bag(hero_id)
	var capacity = GameContext.get_hero_bag_capacity(hero_id)
	var used = bag.size()

	# Hero header with bag capacity
	var header = Label.new()
	header.text = "%s's Bag (%d/%d)" % [hero_name, used, capacity]
	header.modulate = Color(0.8, 0.8, 1, 1)
	section.add_child(header)

	if bag.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "  (Empty)"
		empty_label.modulate = Color(0.5, 0.5, 0.5, 1)
		section.add_child(empty_label)
	else:
		for entry in bag:
			var entry_row = _create_hero_bag_item_row(hero_id, entry, parent_container)
			section.add_child(entry_row)

	return section


func _create_hero_bag_item_row(hero_id: String, entry: Dictionary, parent_container: VBoxContainer) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = entry.get("item_id", "")
	var quality = entry.get("quality", 0)
	var template = DataRegistry.get_item_template(item_id)
	var display_name = template.display_name if template else item_id

	# Indent
	var indent = Label.new()
	indent.text = "  "
	row.add_child(indent)

	# Item name
	var label = Label.new()
	label.text = display_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Return to stash button
	var return_btn = Button.new()
	return_btn.text = "Return to Stash"
	return_btn.custom_minimum_size = Vector2(110, 24)
	return_btn.pressed.connect(_on_return_to_stash_pressed.bind(hero_id, item_id, quality, parent_container))
	row.add_child(return_btn)

	return row


func _on_give_to_hero_pressed(item_id: String, hero_id: String, parent_container: VBoxContainer) -> void:
	var success = GameContext.move_item_stash_to_hero_bag(hero_id, item_id, 1)
	if success:
		print("[BagMgmt] transferred item=%s to hero=%s" % [item_id, hero_id])
		GameContext.save_game()
		_populate_bag_management_ui(parent_container)
	else:
		print("[BagMgmt] transfer_failed item=%s hero=%s" % [item_id, hero_id])


func _on_return_to_stash_pressed(hero_id: String, item_id: String, quality: int, parent_container: VBoxContainer) -> void:
	var success = GameContext.move_item_hero_bag_to_stash(hero_id, item_id, 1, quality)
	if success:
		print("[BagMgmt] returned item=%s from hero=%s to stash" % [item_id, hero_id])
		GameContext.save_game()
		_populate_bag_management_ui(parent_container)
	else:
		print("[BagMgmt] return_failed item=%s hero=%s" % [item_id, hero_id])


# ============================================================================
# INN UI (Hero Recruitment & Party Management)
# ============================================================================

func _build_inn_ui() -> void:
	print("[Inn] opened  phase=%s" % str(GameContext.get_phase()))

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

	# Permadeath warning
	var permadeath_warning = Label.new()
	permadeath_warning.text = "⚠ Heroes who fall in the dungeon are lost forever!"
	permadeath_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	permadeath_warning.add_theme_font_size_override("font_size", 11)
	permadeath_warning.modulate = Color(1.0, 0.6, 0.4, 1)
	_facility_actions_container.add_child(permadeath_warning)

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

	# Log container child count to detect accidental double-population
	print("[Inn] owned=%d party=%d container_children=%d" % [owned_heroes.size(), selected_party.size(), _facility_actions_container.get_child_count()])


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

	# Check if hero is dead (only matters outside town phase)
	var is_hero_dead = false
	if GameContext.get_phase() != GameContext.GamePhase.TOWN:
		var hp_check = GameContext.get_hero_hp(hero_id)
		if not hp_check.is_empty() and int(hp_check.get("current", 1)) <= 0:
			is_hero_dead = true

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

	# Add subtle border style based on party status and death
	var style = StyleBoxFlat.new()
	if is_hero_dead:
		style.bg_color = Color(0.3, 0.1, 0.1, 1)  # Dark red background
		style.border_color = Color(0.6, 0.2, 0.2, 1)  # Red border
	elif in_party:
		style.bg_color = Color(0.1, 0.25, 0.1, 1)
		style.border_color = Color(0.3, 0.6, 0.3, 1)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 1)
		style.border_color = Color(0.3, 0.3, 0.3, 1)
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

	# XP progress label — uses static format_xp_line() for testability
	var xp_label = Label.new()
	var is_max_level = hero_level >= GameContext.MAX_HERO_LEVEL
	if is_max_level:
		xp_label.text = format_xp_line(hero_xp, 0, true)
		xp_label.modulate = Color(1.0, 0.85, 0.3, 1)  # Gold color for max
	else:
		var next_level_xp = GameContext.get_xp_for_level(hero_level + 1)
		xp_label.text = format_xp_line(hero_xp, next_level_xp, false)
		xp_label.modulate = Color(0.5, 0.8, 1.0, 1)  # Cyan-blue (distinct from green HP)
	# GUARD: If format_xp_line returns wrong prefix, force-correct it
	if not xp_label.text.begins_with("XP:"):
		print("[InnUI] BUG xp_label wrong prefix: '%s' hero=%s  FORCING XP prefix" % [xp_label.text, hero_id])
		xp_label.text = "XP" + xp_label.text.substr(xp_label.text.find(":")) if ":" in xp_label.text else "XP: ???"
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
	hp_label.text = format_hp_line(current_hp, max_hp)
	hp_label.tooltip_text = build_inn_stat_tooltip("Health", hero_id)
	hp_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if current_hp >= max_hp:
		hp_label.modulate = Color(0.5, 1.0, 0.5, 1)  # Green = full
	elif current_hp > max_hp * 0.5:
		hp_label.modulate = Color(1.0, 0.9, 0.4, 1)  # Yellow = wounded
	else:
		hp_label.modulate = Color(1.0, 0.4, 0.4, 1)  # Red = critical
	info_vbox.add_child(hp_label)
	print("[InnUI] hero=%s xp_text='%s' hp_text='%s' phase=%s" % [hero_id, xp_label.text, hp_label.text, str(GameContext.get_phase())])

	# Combat stats summary (ATK/DEF/SPD with individual tooltips)
	var atk = int(eff_stats.get("attack", 0))
	var def = int(eff_stats.get("defense", 0))
	var spd = int(eff_stats.get("speed", 0))

	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 4)

	var atk_label = Label.new()
	atk_label.text = "ATK: %d" % atk
	atk_label.add_theme_font_size_override("font_size", 12)
	atk_label.modulate = Color(1.0, 0.6, 0.6, 1)  # Red for attack
	atk_label.tooltip_text = build_inn_stat_tooltip("Attack", hero_id)
	atk_label.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_hbox.add_child(atk_label)

	var sep1 = Label.new()
	sep1.text = "|"
	sep1.add_theme_font_size_override("font_size", 12)
	sep1.modulate = Color(0.6, 0.6, 0.6, 1)
	stats_hbox.add_child(sep1)

	var def_label = Label.new()
	def_label.text = "DEF: %d" % def
	def_label.add_theme_font_size_override("font_size", 12)
	def_label.modulate = Color(0.6, 0.8, 1.0, 1)  # Blue for defense
	def_label.tooltip_text = build_inn_stat_tooltip("Defense", hero_id)
	def_label.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_hbox.add_child(def_label)

	var sep2 = Label.new()
	sep2.text = "|"
	sep2.add_theme_font_size_override("font_size", 12)
	sep2.modulate = Color(0.6, 0.6, 0.6, 1)
	stats_hbox.add_child(sep2)

	var spd_label = Label.new()
	spd_label.text = "SPD: %d" % spd
	spd_label.add_theme_font_size_override("font_size", 12)
	spd_label.modulate = Color(0.6, 1.0, 0.6, 1)  # Green for speed
	spd_label.tooltip_text = build_inn_stat_tooltip("Speed", hero_id)
	spd_label.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_hbox.add_child(spd_label)

	info_vbox.add_child(stats_hbox)

	# Equipment display (all 7 slots + bag)
	var equip = GameContext.get_hero_equipment(hero_id)
	var total_stats = { "health": 0, "attack": 0, "defense": 0, "speed": 0 }

	# Slot abbreviations for compact display
	var slot_abbrevs = {
		"weapon": "WPN", "offhand": "OFF", "helmet": "HLM",
		"armor": "ARM", "legs": "LEG", "ring": "RNG", "amulet": "AMU"
	}

	# Display each equipment slot
	for slot in GameContext.EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var item_id = slot_data.get("id", "")
		var quality = int(slot_data.get("quality", 0))
		var abbrev = slot_abbrevs.get(slot, slot.to_upper().left(3))

		var slot_text = "%s: None" % abbrev
		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				var prefix = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""
				var stats = tpl.get_stat_bonuses_with_quality(quality)
				# Accumulate total stats
				for stat_key in stats:
					if total_stats.has(stat_key):
						total_stats[stat_key] += stats[stat_key]
				# Build stat abbreviations
				var stat_abbrevs: Array = []
				if stats.get("attack", 0) > 0: stat_abbrevs.append("+%dA" % stats.get("attack", 0))
				if stats.get("defense", 0) > 0: stat_abbrevs.append("+%dD" % stats.get("defense", 0))
				if stats.get("speed", 0) > 0: stat_abbrevs.append("+%dS" % stats.get("speed", 0))
				if stats.get("health", 0) > 0: stat_abbrevs.append("+%dH" % stats.get("health", 0))
				var stat_str = " " + " ".join(stat_abbrevs) if stat_abbrevs.size() > 0 else ""
				slot_text = "%s: Q%d %s%s%s" % [abbrev, quality, prefix, tpl.display_name, stat_str]

		var slot_label = Label.new()
		slot_label.text = slot_text
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.modulate = Color(0.9, 0.7, 0.5, 1) if item_id != "" else Color(0.5, 0.5, 0.5, 1)
		info_vbox.add_child(slot_label)

	# Gear Bonus summary line (totals from all 7 equipment slots)
	var gear_bonus_label = Label.new()
	if total_stats.health > 0 or total_stats.attack > 0 or total_stats.defense > 0 or total_stats.speed > 0:
		gear_bonus_label.text = "Gear: HP+%d ATK+%d DEF+%d SPD+%d" % [
			total_stats.health, total_stats.attack, total_stats.defense, total_stats.speed]
		gear_bonus_label.modulate = Color(0.6, 0.9, 0.6, 1)  # Light green
	else:
		gear_bonus_label.text = "Gear: (none equipped)"
		gear_bonus_label.modulate = Color(0.5, 0.5, 0.5, 1)
	gear_bonus_label.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(gear_bonus_label)

	# Backpack display (equipped bag + contents summary)
	var bag_item_id = GameContext.get_hero_bag_item(hero_id)
	var bag_quality = GameContext.get_hero_bag_quality(hero_id)
	var bag_equip_text = "None"
	if bag_item_id != "":
		var bag_tpl = DataRegistry.get_item_template(bag_item_id)
		if bag_tpl != null:
			var prefix = ItemInstance.QUALITY_PREFIXES[bag_quality] if bag_quality < ItemInstance.QUALITY_PREFIXES.size() else ""
			bag_equip_text = "Q%d %s%s" % [bag_quality, prefix, bag_tpl.display_name]
	var bag_summary = GameContext.get_hero_bag_summary(hero_id)
	var bag_label = Label.new()
	bag_label.text = "BAG: %s | %s" % [bag_equip_text, bag_summary]
	bag_label.add_theme_font_size_override("font_size", 12)
	bag_label.modulate = Color(0.9, 0.7, 0.5, 1) if bag_item_id != "" else Color(0.5, 0.5, 0.5, 1)
	info_vbox.add_child(bag_label)

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

	# Row selector (3-Row Formation v1) - only for party members
	if in_party:
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 4)

		var row_label = Label.new()
		row_label.text = "Row:"
		row_label.add_theme_font_size_override("font_size", 11)
		row_hbox.add_child(row_label)

		var row_select = OptionButton.new()
		row_select.custom_minimum_size = Vector2(70, 24)
		row_select.add_item("Front", 0)
		row_select.add_item("Middle", 1)
		row_select.add_item("Back", 2)
		row_select.selected = GameContext.get_hero_row(hero_id)
		row_select.item_selected.connect(_on_hero_row_changed.bind(hero_id))
		row_hbox.add_child(row_select)

		btn_vbox.add_child(row_hbox)

		# Row explanation text (3-Row Formation v1)
		var row_explain = Label.new()
		row_explain.text = "Front: Targeted first by melee.\nMiddle: Targeted after Front.\nBack: Targeted last by melee."
		row_explain.add_theme_font_size_override("font_size", 9)
		row_explain.add_theme_color_override("font_color", Color.GRAY)
		btn_vbox.add_child(row_explain)

	# Equipment buttons (only for party members)
	if in_party:
		# Manage Gear button opens slot selection popup
		var manage_gear_btn = Button.new()
		manage_gear_btn.custom_minimum_size = Vector2(100, 28)
		manage_gear_btn.text = "Manage Gear"
		manage_gear_btn.pressed.connect(_on_manage_gear_pressed.bind(hero_id))
		btn_vbox.add_child(manage_gear_btn)

		# Quick Equip Bag button (most common action)
		var equip_bag_btn = Button.new()
		equip_bag_btn.custom_minimum_size = Vector2(100, 28)
		equip_bag_btn.text = "Equip Bag"
		equip_bag_btn.pressed.connect(_on_equip_slot_pressed.bind(hero_id, "bag"))
		btn_vbox.add_child(equip_bag_btn)

		# Unequip Bag button (only show if bag slot has item)
		if bag_item_id != "":
			var unequip_bag_btn = Button.new()
			unequip_bag_btn.custom_minimum_size = Vector2(100, 28)
			unequip_bag_btn.text = "Unequip Bag"
			unequip_bag_btn.pressed.connect(_on_unequip_slot_pressed.bind(hero_id, "bag"))
			btn_vbox.add_child(unequip_bag_btn)

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

	# --- DUP_HP sanity check + full label dump (debug only, non-fatal) ---
	var hp_count := 0
	var all_labels: Array[String] = []
	for child_node in info_vbox.get_children():
		if child_node is Label:
			var lbl := child_node as Label
			all_labels.append(lbl.text)
			if lbl.text.begins_with("HP:"):
				hp_count += 1
	if hp_count != 1:
		print("[InnUI] DUP_HP hero=%s count=%d all_labels=%s node=%s" % [hero_id, hp_count, str(all_labels), str(panel.get_path()) if panel.is_inside_tree() else "not_in_tree"])

	# Add DEAD overlay if hero is dead
	if is_hero_dead:
		var dead_label = Label.new()
		dead_label.text = "DEAD — Lost Forever"
		dead_label.add_theme_font_size_override("font_size", 28)
		dead_label.modulate = Color(1.0, 0.3, 0.3, 0.9)
		dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dead_label.set_anchors_preset(Control.PRESET_CENTER)
		dead_label.z_index = 10
		panel.add_child(dead_label)
		# Dim the content behind
		hbox.modulate = Color(0.5, 0.5, 0.5, 0.7)

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


## Handle hero row assignment change (3-Row Formation v1)
func _on_hero_row_changed(row_index: int, hero_id: String) -> void:
	GameContext.set_hero_row(hero_id, row_index)
	var row_names = ["Front", "Middle", "Back"]
	print("[Inn] Hero %s assigned to %s row" % [hero_id, row_names[row_index]])


func _on_equip_slot_pressed(hero_id: String, slot: String) -> void:
	# Show equip selection popup for this hero and slot
	_show_equip_selection_popup(hero_id, slot)


## Show popup to manage all 8 equipment slots for a hero.
func _on_manage_gear_pressed(hero_id: String) -> void:
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if not hero.is_empty() else hero_id
	var equip = GameContext.get_hero_equipment(hero_id)

	# Slot display names
	var slot_names = {
		"weapon": "Weapon", "offhand": "Offhand", "helmet": "Helmet",
		"armor": "Armor", "legs": "Legs", "ring": "Ring", "amulet": "Amulet", "bag": "Bag"
	}

	# Create popup
	var popup = PopupPanel.new()
	popup.name = "ManageGearPopup"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	popup.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Manage Gear - %s" % hero_name
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Create row for each slot
	for slot in GameContext.ALL_EQUIP_SLOTS:
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(slot_hbox)

		# Slot label
		var slot_label = Label.new()
		slot_label.text = "%s:" % slot_names.get(slot, slot.capitalize())
		slot_label.custom_minimum_size = Vector2(60, 0)
		slot_hbox.add_child(slot_label)

		# Current item display
		var slot_data = equip.get(slot, {})
		var item_id = slot_data.get("id", "")
		var quality = int(slot_data.get("quality", 0))

		var item_label = Label.new()
		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				var prefix = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""
				item_label.text = "Q%d %s%s" % [quality, prefix, tpl.display_name]
				item_label.modulate = Color(0.9, 0.7, 0.5, 1)
			else:
				item_label.text = "(unknown)"
		else:
			item_label.text = "(empty)"
			item_label.modulate = Color(0.5, 0.5, 0.5, 1)
		item_label.custom_minimum_size = Vector2(150, 0)
		slot_hbox.add_child(item_label)

		# Equip button
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(60, 24)
		equip_btn.pressed.connect(func():
			popup.hide()
			popup.queue_free()
			_on_equip_slot_pressed(hero_id, slot)
		)
		slot_hbox.add_child(equip_btn)

		# Unequip button (only if slot has item)
		if item_id != "":
			var unequip_btn = Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(70, 24)
			unequip_btn.pressed.connect(func():
				GameContext.unequip_hero_item(hero_id, slot)
				popup.hide()
				popup.queue_free()
				_refresh_facility_panel()
			)
			slot_hbox.add_child(unequip_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.pressed.connect(func():
		popup.hide()
		popup.queue_free()
	)
	vbox.add_child(close_btn)

	# Show popup
	add_child(popup)
	popup.popup_centered(Vector2(350, 400))


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

	# Get currently equipped item info for comparison (generic for all slots)
	var current_id = GameContext.get_hero_slot_item(hero_id, slot)
	var current_quality = GameContext.get_hero_slot_quality(hero_id, slot)
	var current_stats: Dictionary = {}

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
# PRODUCTION UI (Huntsman, Enchanter, etc.)
# ============================================================================

func _build_production_ui() -> void:
	print("[Production] opened")

	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No facility data)"
		no_data.modulate = Color(0.6, 0.6, 0.6, 1)
		_facility_actions_container.add_child(no_data)
		return

	var facility = _current_facility
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)
	var max_tier = facility.max_tier

	# Header with tier info
	var header = Label.new()
	header.text = "=== %s (Tier %d / %d) ===" % [facility.display_name, current_tier, max_tier]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	# Gold display
	var run_gold = GameContext.get_run_gold()
	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % run_gold
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Upgrade button (if not max tier)
	if current_tier < max_tier:
		var upgrade_row = _create_production_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

	# === UNLOCKS SECTION (v1) ===
	_build_facility_unlocks_section()

	# === CRAFTING RECIPES SECTION ===
	_build_crafting_recipes_section()


## Build the crafting recipes section for a production facility.
## Shows available recipes with craft buttons.
func _build_crafting_recipes_section() -> void:
	if _current_facility == null:
		return

	var crafting_recipes = _current_facility.crafting_recipes
	if crafting_recipes.size() == 0:
		return

	# Get current facility tier
	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# Separate recipes into available and locked by tier
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
	craft_header.text = "-- Recipes (Tier %d / %d) --" % [current_tier, _current_facility.max_tier]
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
			var recipe_row = _create_production_recipe_row(recipe)
			_facility_actions_container.add_child(recipe_row)

	# Show locked recipes as grayed-out
	for recipe in locked_recipes:
		var locked_row = _create_locked_recipe_row(recipe)
		_facility_actions_container.add_child(locked_row)

	print("[Production] tier=%d recipes_shown=%d recipes_locked=%d" % [current_tier, available_recipes.size(), locked_recipes.size()])


## Create the upgrade row for a production facility (Chef, Alchemist)
func _create_production_facility_upgrade_row(facility, current_tier: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var town_id = GameContext.get_current_town_id()
	var next_tier = current_tier + 1
	var tier_key = str(next_tier)

	# Get upgrade cost
	var upgrade_cost = {}
	if facility.upgrade_costs.has(tier_key):
		upgrade_cost = facility.upgrade_costs[tier_key]
	elif facility.upgrade_costs.has(next_tier):
		upgrade_cost = facility.upgrade_costs[next_tier]

	var gold_cost = int(upgrade_cost.get("gold", 0))
	var item_costs = upgrade_cost.get("items", [])

	# Cost display
	var cost_parts = []
	if gold_cost > 0:
		cost_parts.append("%dg" % gold_cost)

	var can_afford = GameContext.get_run_gold() >= gold_cost
	var run_items_dict = GameContext.get_run_items_dict()

	for item_cost in item_costs:
		var item_id = item_cost.get("item_id", "")
		var qty_needed = item_cost.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	var cost_text = ", ".join(cost_parts) if cost_parts.size() > 0 else "Free"
	cost_label.text = "Upgrade to Tier %d: %s" % [next_tier, cost_text]
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	row.add_child(cost_label)

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(80, 26)
	upgrade_btn.disabled = not can_afford
	# Use the generic facility upgrade handler which calls GameContext.upgrade_facility()
	upgrade_btn.pressed.connect(_on_facility_upgrade_pressed.bind(town_id, facility.facility_id))
	row.add_child(upgrade_btn)

	return row


## Create a row for a production recipe (direct crafting, no unlock required)
func _create_production_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var output_id = recipe.get("output_id", "")
	var output_qty = recipe.get("output_qty", 1)
	var inputs = recipe.get("inputs", [])

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Recipe name with icon
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	if output_template != null:
		var icon_rect = output_template.create_icon_rect(18)
		if icon_rect != null:
			name_row.add_child(icon_rect)
	var name_label = Label.new()
	name_label.text = "Recipe: %s" % output_name
	name_row.add_child(name_label)
	container.add_child(name_row)

	# Show material costs and craft button
	var run_items_dict = GameContext.get_run_items_dict()
	var can_craft = true
	var cost_parts = []

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
			can_craft = false

	if inputs.size() > 0:
		var cost_label = Label.new()
		cost_label.text = "  Materials: %s" % ", ".join(cost_parts)
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_craft else Color(1, 0.5, 0.5, 1)
		container.add_child(cost_label)

	var craft_btn = Button.new()
	craft_btn.custom_minimum_size = Vector2(120, 28)
	if can_craft:
		craft_btn.text = "Craft"
		craft_btn.disabled = false
		craft_btn.pressed.connect(_on_craft_recipe_pressed.bind(recipe))
	else:
		craft_btn.text = "Need Materials"
		craft_btn.disabled = true
	container.add_child(craft_btn)

	return container


## Build the unlocks section for a production facility.
## Shows available unlocks with purchase buttons.
func _build_facility_unlocks_section() -> void:
	if _current_facility == null or _current_facility_id == "":
		return

	var town_id = GameContext.get_current_town_id()
	var available_unlocks = GameContext.get_available_facility_unlocks(_current_facility_id, town_id)

	if available_unlocks.is_empty():
		return

	# Separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Header
	var unlock_header = Label.new()
	unlock_header.text = "-- Available Unlocks --"
	unlock_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_header.modulate = Color(0.9, 0.8, 0.5, 1)
	_facility_actions_container.add_child(unlock_header)

	# Each unlock as a row
	for unlock in available_unlocks:
		var unlock_id = unlock.get("id", "")
		var label_text = unlock.get("label", unlock_id)
		var costs = unlock.get("costs", [])

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_facility_actions_container.add_child(row)

		# Unlock label
		var unlock_label = Label.new()
		unlock_label.text = label_text
		unlock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(unlock_label)

		# Cost display
		var cost_parts: Array = []
		for cost in costs:
			var item_id = cost.get("item_id", "")
			var qty = cost.get("qty", 0)
			var tpl = DataRegistry.get_item_template(item_id)
			var item_name = tpl.display_name if tpl != null else item_id
			var have = GameContext.get_run_item_count(item_id)
			var color_code = "green" if have >= qty else "red"
			cost_parts.append("[color=%s]%s x%d[/color]" % [color_code, item_name, qty])

		var cost_label = RichTextLabel.new()
		cost_label.bbcode_enabled = true
		cost_label.fit_content = true
		cost_label.scroll_active = false
		cost_label.custom_minimum_size.x = 200
		cost_label.text = " | ".join(cost_parts) if cost_parts.size() > 0 else "(free)"
		row.add_child(cost_label)

		# Purchase button
		var can_afford = GameContext.can_afford_facility_unlock(unlock)
		var purchase_btn = Button.new()
		purchase_btn.text = "Purchase"
		purchase_btn.disabled = not can_afford
		purchase_btn.pressed.connect(_on_facility_unlock_purchase.bind(unlock_id))
		row.add_child(purchase_btn)


## Handler for facility unlock purchase button.
func _on_facility_unlock_purchase(unlock_id: String) -> void:
	if _current_facility_id == "":
		return

	var town_id = GameContext.get_current_town_id()
	var success = GameContext.purchase_facility_unlock(_current_facility_id, unlock_id, town_id)

	if success:
		print("[TownScene] Unlock purchased: %s" % unlock_id)
		# Refresh the facility panel to update UI
		_show_facility_panel(_current_facility_id)
	else:
		print("[TownScene] Unlock purchase failed: %s" % unlock_id)


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
	var has_party: bool = GameContext.selected_party.size() > 0
	var enter_btn = Button.new()
	enter_btn.text = "Enter Dungeon"
	enter_btn.custom_minimum_size = Vector2(180, 32)
	enter_btn.disabled = current_dungeon != "" or not has_party
	enter_btn.pressed.connect(_on_dungeon_enter_pressed.bind(dungeon_id))
	_facility_actions_container.add_child(enter_btn)

	if not has_party:
		var warn = Label.new()
		warn.text = "Recruit heroes at the Inn first!"
		warn.modulate = Color(1, 0.6, 0.4, 1)
		_facility_actions_container.add_child(warn)

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
	if GameContext.selected_party.size() == 0:
		print("[DungeonFacility] Enter BLOCKED - no heroes in party!")
		facility_desc_label.text = "Need at least 1 hero! Visit Inn to recruit."
		facility_desc_label.modulate = Color(1, 0.5, 0.5, 1)
		return
	GameContext.enter_dungeon(dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	print("[DungeonFacility] Entering %s at floor %d" % [dungeon_id, GameContext.get_current_floor()])
	_hide_facility_overlay()
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _on_dungeon_continue_pressed() -> void:
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	print("[DungeonFacility] Continuing run at floor %d" % GameContext.get_current_floor())
	_hide_facility_overlay()
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


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
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


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
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


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
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


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


## Static helper: format the XP progress line for a hero card.
## Used by _create_hero_row and tested by the headless suite.
static func format_xp_line(xp: int, next_level_xp: int, is_max_level: bool) -> String:
	if is_max_level:
		return "XP: MAX"
	return "XP: %d / %d" % [xp, next_level_xp]


## Static helper: format the HP line for a hero card.
static func format_hp_line(current_hp: int, max_hp: int) -> String:
	return "HP: %d / %d" % [current_hp, max_hp]


## Build a stat breakdown tooltip for Inn hero cards.
## Shows where each stat comes from: class base, race modifiers, gear bonuses.
static func build_inn_stat_tooltip(stat_name: String, hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return stat_name

	var class_id = hero.get("class_id", "")
	var race_id = hero.get("race_id", "human")
	var level = int(hero.get("level", 1))

	var class_data = DataRegistry.get_class_data(class_id)
	var race_data = DataRegistry.get_race(race_id)

	var stat_key = stat_name.to_lower()  # "attack", "defense", "speed"

	# Get class base at level
	var base_value = 0
	if class_data != null:
		var base_stats = class_data.get_stats_at_level(level)
		base_value = int(base_stats.get(stat_key, 0))

	# Get race modifier
	var race_bonus = 0
	var race_name = race_id.capitalize()
	if race_data != null:
		race_bonus = int(race_data.stat_modifiers.get(stat_key, 0))
		if race_data.display_name != "":
			race_name = race_data.display_name

	# Get gear bonus
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var gear_bonus_dict = eff_stats.get("gear_bonus", {})
	var gear_bonus = int(gear_bonus_dict.get(stat_key, 0))

	# Build tooltip
	var parts: Array = [stat_name]
	parts.append("Base (Lv %d): %d" % [level, base_value])

	if race_bonus != 0:
		if race_bonus > 0:
			parts.append("%s: +%d" % [race_name, race_bonus])
		else:
			parts.append("%s: %d" % [race_name, race_bonus])

	if gear_bonus != 0:
		if gear_bonus > 0:
			parts.append("Gear: +%d" % gear_bonus)
		else:
			parts.append("Gear: %d" % gear_bonus)

	var total = base_value + race_bonus + gear_bonus
	if race_bonus != 0 or gear_bonus != 0:
		parts.append("Total: %d" % total)

	return "\n".join(parts)


## Build a combined stat breakdown tooltip for all combat stats (ATK/DEF/SPD).
## Used for the single stats line in Inn hero cards.
static func build_inn_stats_combined_tooltip(hero_id: String) -> String:
	var sections: Array = []
	sections.append(build_inn_stat_tooltip("Attack", hero_id))
	sections.append("")
	sections.append(build_inn_stat_tooltip("Defense", hero_id))
	sections.append("")
	sections.append(build_inn_stat_tooltip("Speed", hero_id))
	return "\n".join(sections)
