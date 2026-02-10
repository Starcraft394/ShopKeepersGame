## DungeonCampScene.gd
## Campsite between dungeon rooms/floors. Displays dungeon info and both stashes.
## Shows 2 room choices (A=Combat, B=Event or Elite). Player picks one to continue.
## Can extract (bank loot) after completing floor, or flee (lose loot).
extends Control

const BOOT_SCENE_PATH = "res://Game/Boot/game_boot.tscn"

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var dungeon_label: Label = $MainVBox/InfoSection/DungeonLabel
@onready var floor_label: Label = $MainVBox/InfoSection/FloorLabel
@onready var room_label: Label = $MainVBox/InfoSection/RoomLabel
@onready var dungeon_stash_label: Label = $MainVBox/StashSection/DungeonStashLabel
@onready var run_stash_label: Label = $MainVBox/StashSection/RunStashLabel
@onready var choice_a_label: Label = $MainVBox/MapSection/ChoiceALabel
@onready var choice_b_container: VBoxContainer = $MainVBox/MapSection/ChoiceBContainer
@onready var choice_b_label: Label = $MainVBox/MapSection/ChoiceBContainer/ChoiceBLabel
@onready var no_alternate_hint: Label = $MainVBox/MapSection/NoAlternateHint
@onready var choice_a_button: Button = $MainVBox/ButtonSection/ChoiceAButton
@onready var choice_b_button_container: VBoxContainer = $MainVBox/ButtonSection/ChoiceBButtonContainer
@onready var choice_b_button: Button = $MainVBox/ButtonSection/ChoiceBButtonContainer/ChoiceBButton
@onready var extract_button: Button = $MainVBox/ButtonSection/ExtractButton
@onready var flee_button: Button = $MainVBox/ButtonSection/FleeButton
@onready var hotkey_hint: Label = $MainVBox/HotkeyHint

# Heroes section (new layout)
@onready var heroes_section: VBoxContainer = %HeroesSection
@onready var hero_rows: VBoxContainer = %HeroRows

# Shopkeeper bag section
@onready var shopkeeper_section: VBoxContainer = %ShopkeeperSection
@onready var shopkeeper_bag: HBoxContainer = %ShopkeeperBag

# Cache of hero bag items per hero for right-click access
var _hero_bag_cache: Dictionary = {}  # { hero_id: [ { slot_idx, item_id, button } ] }

# Cache of shopkeeper bag items for display
var _shopkeeper_items: Array[Dictionary] = []

# Popup for consumable use confirmation
var _consumable_use_popup: PopupMenu = null
var _pending_consumable_hero_id: String = ""
var _pending_consumable_item_id: String = ""

# State
var _can_extract: bool = false
var _is_dungeon_complete: bool = false

# Hero info window
var _hero_info_window: Window = null

var _choice_a: Dictionary = {}
var _choice_b: Dictionary = {}
var _is_descend_mode: bool = false  # True when at end of floor (descend instead of room choices)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Generate room choices for this camp visit
	_generate_room_choices()

	_update_display()
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	flee_button.pressed.connect(_on_flee_pressed)
	print("[DungeonCamp] Loaded. Dungeon=%s Floor=%d Room=%d/%d" % [
		GameContext.get_current_dungeon_id(),
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])


# ============================================================================
# ROOM CHOICE GENERATION
# ============================================================================

func _generate_room_choices() -> void:
	# Get RNG for deterministic choice generation
	var rng = SeededRng.get_dungeon_rng()

	# Generate the choices
	GameContext.generate_pending_room_choices(rng)

	# Cache locally for UI
	var choices = GameContext.get_pending_room_choices()
	var mode = choices.get("mode", "choose")

	if mode == "descend":
		# End of floor - descend mode (player completed all rooms on this floor)
		_is_descend_mode = true
		_choice_a = {}
		_choice_b = {}

		# Unlock floors for future runs:
		# 1. The completed floor (selectable as start floor for farming)
		# 2. The next floor (for progression)
		var dungeon_id = GameContext.get_current_dungeon_id()
		var floor_num = GameContext.get_current_floor()
		if dungeon_id != "":
			GameContext.unlock_floor(dungeon_id, floor_num)      # Completed floor
			GameContext.unlock_floor(dungeon_id, floor_num + 1)  # Next floor (clamped to 4)
	else:
		# Normal choice mode
		_is_descend_mode = false
		_choice_a = choices.get("choice_a", { "type": "combat", "is_elite": false, "display": "Combat" })
		_choice_b = choices.get("choice_b", { "type": "combat", "is_elite": false, "display": "Combat" })


# ============================================================================
# UI UPDATE
# ============================================================================

func _update_display() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var rooms = GameContext.get_rooms_per_floor()
	var dungeon_stash = GameContext.get_dungeon_stash_summary()
	var run_stash = GameContext.get_run_stash_summary()

	# Get dungeon display name and floor count
	var dungeon_name = dungeon_id
	var floor_count = 4
	if DataRegistry.has_method("get_dungeon"):
		var dungeon = DataRegistry.get_dungeon(dungeon_id)
		if dungeon != null:
			if dungeon.display_name != "":
				dungeon_name = dungeon.display_name
			floor_count = dungeon.floor_count

	# Compute extraction eligibility: only after last room of current floor
	_can_extract = GameContext.is_last_room_on_floor()

	# Check if dungeon is complete (last room of last floor)
	_is_dungeon_complete = _can_extract and floor_num >= floor_count

	# Update info labels
	dungeon_label.text = "Dungeon: %s" % dungeon_name
	floor_label.text = "Floor: %d/%d" % [floor_num, floor_count]
	room_label.text = "Room: %d/%d (completed)" % [room_idx + 1, rooms]
	dungeon_stash_label.text = "Unbanked Loot: %d gold, %d items" % [
		dungeon_stash.gold, dungeon_stash.items_count
	]
	run_stash_label.text = "Banked Loot: %d gold, %d items" % [
		run_stash.gold, run_stash.items_count
	]

	# Update button states based on game state
	if _is_dungeon_complete:
		# Dungeon complete: hide choice buttons, show only extract
		choice_a_button.visible = false
		choice_b_container.visible = false
		choice_b_button_container.visible = false
		no_alternate_hint.visible = false
		choice_a_label.text = "Dungeon Complete!"
		extract_button.visible = true
		extract_button.disabled = false
		hotkey_hint.text = "E=Extract | F=Flee"
	elif _is_descend_mode:
		# End of floor, not final floor -> show Descend button (use A for descend)
		choice_a_button.visible = true
		choice_a_button.disabled = false
		choice_a_button.text = "Descend to Floor %d (A)" % (floor_num + 1)
		choice_b_container.visible = false
		choice_b_button_container.visible = false
		no_alternate_hint.visible = false
		extract_button.visible = true
		extract_button.disabled = false
		choice_a_label.text = "Floor %d complete!" % floor_num
		hotkey_hint.text = "A=Descend | E=Extract | F=Flee"
	else:
		# Normal room choices mode
		var choice_b_disabled = _choice_b.get("disabled", false)

		# Update choice labels
		var next_room_num = room_idx + 2  # Next room is current + 1 (1-based display)
		choice_a_label.text = "A: Room %d - %s" % [next_room_num, _choice_a.get("display", "Combat")]

		# Update choice buttons
		choice_a_button.text = "A: %s (A)" % _choice_a.get("display", "Combat")
		choice_a_button.visible = true
		choice_a_button.disabled = false

		if choice_b_disabled:
			# Hide B entirely - no label, no button, no gap
			choice_b_container.visible = false
			choice_b_button_container.visible = false
			no_alternate_hint.visible = true
			hotkey_hint.text = "A=Continue | F=Flee"
		else:
			# Show B normally
			choice_b_label.text = "B: Room %d - %s" % [next_room_num, _choice_b.get("display", "Event")]
			choice_b_button.text = "B: %s (B)" % _choice_b.get("display", "Event")
			choice_b_container.visible = true
			choice_b_button_container.visible = true
			choice_b_button.disabled = false
			no_alternate_hint.visible = false
			hotkey_hint.text = "A/B=Choose Room | F=Flee"

		# Extract only available at end of floor (descend mode), so hide here
		extract_button.visible = false

	# Populate hero rows (new layout: Name | Info | Bag)
	_populate_hero_rows()

	# Populate shopkeeper bag at bottom
	_populate_shopkeeper_bag()

	# Log state
	var b_display = "-"
	if not _is_descend_mode:
		if _choice_b.get("disabled", false):
			b_display = "(hidden)"
		else:
			b_display = _choice_b.get("display", "-")
	print("[Camp] floor=%d/%d room=%d/%d descend=%s choices=[A:%s B:%s] can_extract=%s complete=%s" % [
		floor_num, floor_count, room_idx + 1, rooms,
		str(_is_descend_mode),
		_choice_a.get("display", "-") if not _is_descend_mode else "descend",
		b_display,
		str(_can_extract), str(_is_dungeon_complete)
	])


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_choice_a_pressed() -> void:
	if _is_descend_mode:
		_do_descend()
	else:
		_select_choice(_choice_a)


func _on_choice_b_pressed() -> void:
	if _is_descend_mode:
		return  # B is hidden in descend mode
	_select_choice(_choice_b)


func _on_extract_pressed() -> void:
	_do_extract()


func _on_flee_pressed() -> void:
	_do_flee()


# ============================================================================
# HOTKEYS
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A:
				if choice_a_button.visible and not choice_a_button.disabled:
					if _is_descend_mode:
						_do_descend()
					else:
						_select_choice(_choice_a)
			KEY_B:
				# Check container visibility (not just button) since container hides entire B choice
				if choice_b_button_container.visible and not choice_b_button.disabled:
					if not _is_descend_mode:
						_select_choice(_choice_b)
				elif _choice_b.get("disabled", false):
					print("[Camp] B pressed but hidden (no alternate route)")
			KEY_E:
				if _can_extract:
					_do_extract()
				else:
					print("[Camp] Extract blocked - must complete floor first")
			KEY_F, KEY_F7:
				_do_flee()


# ============================================================================
# ACTIONS
# ============================================================================

func _select_choice(choice: Dictionary) -> void:
	# Guard: must be in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DungeonCamp] Not in dungeon, ignoring choice")
		return

	# Health Persistence v1: Log that no healing occurs between rooms
	print("[HP] dungeon_camp_no_heal (proceeding to next room)")

	# Set the selected choice in GameContext
	GameContext.set_next_room_choice(choice)

	var floor_num = GameContext.get_current_floor()
	var rooms = GameContext.get_rooms_per_floor()

	# Get dungeon floor count
	var dungeon = DataRegistry.get_dungeon(GameContext.get_current_dungeon_id()) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4

	# More rooms on this floor -> advance room
	GameContext.advance_room()
	# Consume the choice to set room type
	GameContext.consume_next_room_choice()
	_route_to_room()
	print("[DungeonCamp] Choice selected: %s -> room=%d/%d floor=%d/%d type=%s elite=%s" % [
		choice.get("display", "?"),
		GameContext.get_current_room_index() + 1, rooms, floor_num, floor_count,
		GameContext.get_current_room_type(),
		str(GameContext.is_current_room_elite())
	])
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _do_descend() -> void:
	# Guard: must be in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DungeonCamp] Not in dungeon, ignoring descend")
		return

	# Guard: must be at end of floor
	if not _is_descend_mode:
		print("[DungeonCamp] Not in descend mode, ignoring")
		return

	# Health Persistence v1: Log that no healing occurs when descending
	print("[HP] dungeon_camp_no_heal (descending to next floor)")

	var floor_num = GameContext.get_current_floor()

	# Get dungeon floor count
	var dungeon = DataRegistry.get_dungeon(GameContext.get_current_dungeon_id()) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4

	if floor_num >= floor_count:
		# Boss floor completed - shouldn't reach here in descend mode
		print("[DungeonCamp] Dungeon completed! Auto-extracting...")
		_do_extract()
		return

	# Descend to next floor - room 1 is always normal combat (no choice needed)
	GameContext.advance_floor()
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DungeonCamp] Descending to floor=%d/%d (room 1 = normal combat)" % [
		GameContext.get_current_floor(), floor_count
	])
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _route_to_room() -> void:
	# Route to appropriate phase based on current room type
	var room_type = GameContext.get_current_room_type()
	if room_type == "combat":
		GameContext.set_phase(GameContext.GamePhase.COMBAT)
	else:
		# Non-combat room: prepare payload and route to ROOM_EVENT
		GameContext.prepare_room_event_payload()
		GameContext.set_phase(GameContext.GamePhase.ROOM_EVENT)


func _do_extract() -> void:
	# Guard: must be in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DungeonCamp] Not in dungeon, ignoring extract")
		return

	# Guard: can only extract after completing floor
	if not _can_extract:
		print("[DungeonCamp] Cannot extract - must complete floor first")
		return

	print("[DungeonCamp] Extracting - committing dungeon stash to run stash...")

	# Commit dungeon stash to run stash
	GameContext.commit_dungeon_stash_to_run()

	# Exit to town
	GameContext.exit_to_town()
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


func _do_flee() -> void:
	# Guard: must be in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DungeonCamp] Not in dungeon, ignoring flee")
		return

	print("[DungeonCamp] Fleeing - losing dungeon stash...")

	# Flee (this clears dungeon stash and exits)
	GameContext.flee_to_town()
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


# ============================================================================
# HERO ROWS (New Layout: Name | Info | Bag Slots)
# ============================================================================

## Populate hero rows with name, info button, and bag slots
func _populate_hero_rows() -> void:
	# Clear existing rows
	for child in hero_rows.get_children():
		child.queue_free()
	_hero_bag_cache.clear()

	var party = GameContext.get_selected_party()
	if party.is_empty():
		var hint = Label.new()
		hint.text = "(No heroes in party)"
		hint.modulate = Color(0.5, 0.5, 0.5, 1)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_rows.add_child(hint)
		return

	# Build a row for each hero
	for hero_id in party:
		var row = _create_hero_row(hero_id)
		hero_rows.add_child(row)

	print("[Camp] Populated %d hero rows" % party.size())


## Create a single hero row: [Name + HP | Info Button | Bag Slots (horizontal)]
func _create_hero_row(hero_id: String) -> HBoxContainer:
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if hero else hero_id

	# Get HP display
	var hp_text = ""
	var hp_data = GameContext.get_hero_hp(hero_id)
	if not hp_data.is_empty():
		hp_text = " (%d/%d)" % [hp_data.get("current", 0), hp_data.get("max", 0)]
	else:
		var stats = GameContext.get_hero_effective_stats(hero_id)
		if not stats.is_empty():
			hp_text = " (%d/%d)" % [stats.get("health", 100), stats.get("health", 100)]

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Hero name + HP (fixed width for alignment)
	var name_label = Label.new()
	name_label.text = "%s%s" % [hero_name, hp_text]
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)

	# Info button (shows hero details popup like in combat)
	var info_btn = Button.new()
	info_btn.text = "Info"
	info_btn.custom_minimum_size = Vector2(50, 26)
	info_btn.pressed.connect(_on_hero_info_pressed.bind(hero_id))
	row.add_child(info_btn)

	# Separator before bag
	var sep = VSeparator.new()
	row.add_child(sep)

	# Bag slots container (horizontal)
	var bag_container = HBoxContainer.new()
	bag_container.add_theme_constant_override("separation", 4)
	bag_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Get hero's bag contents
	var bag = GameContext.get_hero_bag(hero_id)
	var bag_size = GameContext.get_hero_bag_capacity(hero_id)

	_hero_bag_cache[hero_id] = []

	for slot_idx in range(bag_size):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(32, 32)

		if slot_idx < bag.size():
			var entry = bag[slot_idx]
			var item_id = entry.get("item_id", "")
			var qty = entry.get("qty", 1)
			var template = DataRegistry.get_item_template(item_id)
			var display_name = template.display_name if template else item_id

			# Show abbreviated name (first 3 chars) or qty
			if qty > 1:
				slot_btn.text = str(qty)
			else:
				slot_btn.text = display_name.substr(0, 3) if display_name.length() > 3 else display_name

			# Build detailed tooltip
			var tooltip_lines: Array[String] = ["%s x%d" % [display_name, qty]]
			if template != null:
				if template.description != "":
					tooltip_lines.append(template.description)
				# Consumable effects
				if template.category == "consumable" and template.use_effect != "":
					tooltip_lines.append("")
					tooltip_lines.append("Effect: %s" % template.use_effect.replace("_", " ").capitalize())
					if template.use_value > 0:
						tooltip_lines.append("Value: %d" % template.use_value)
				# Materials: show recipes
				if template.category == "materials":
					var recipes = GameContext.get_recipes_using_material(item_id)
					if recipes.size() > 0:
						tooltip_lines.append("")
						tooltip_lines.append("Used in recipes:")
						for recipe_info in recipes:
							tooltip_lines.append("  • %s" % recipe_info.recipe_name)
			tooltip_lines.append("")
			tooltip_lines.append("Right-click to use")
			slot_btn.tooltip_text = "\n".join(tooltip_lines)

			# Connect right-click for consumable use
			slot_btn.gui_input.connect(_on_bag_slot_input.bind(hero_id, item_id, slot_idx))

			_hero_bag_cache[hero_id].append({
				"slot_idx": slot_idx,
				"item_id": item_id,
				"qty": qty
			})
		else:
			# Empty slot
			slot_btn.text = "-"
			slot_btn.disabled = true
			slot_btn.tooltip_text = "Empty slot"

		bag_container.add_child(slot_btn)

	row.add_child(bag_container)

	return row


## Handle input on bag slots (right-click to use consumable)
func _on_bag_slot_input(event: InputEvent, hero_id: String, item_id: String, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_use_hero_bag_item(hero_id, item_id)


## Use a consumable from hero's bag
func _use_hero_bag_item(hero_id: String, item_id: String) -> void:
	# Check if this is a usable consumable
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		print("[Camp] Unknown item: %s" % item_id)
		return

	if template.category != "consumable":
		print("[Camp] %s is not a consumable" % item_id)
		return

	# Handle special effects
	var use_effect = template.use_effect
	if use_effect in ["buff_speed", "stamina"]:
		_apply_combat_modifier_from_bag(hero_id, item_id, "player_spd_bonus", 2, "Stamina Draught", "+2 SPD")
		return
	elif use_effect in ["buff_defense", "resistance"]:
		_apply_combat_modifier_from_bag(hero_id, item_id, "player_def_bonus", 3, "Resistance Salve", "+3 DEF")
		return

	# Use the consumable on the hero who owns it
	var result = GameContext.use_consumable_on_hero(item_id, hero_id, "hero_bag")

	if result.get("success", false):
		print("[Camp] %s used %s: %s" % [hero_id, item_id, result.get("detail", "")])
	else:
		print("[Camp] Failed to use %s: %s" % [item_id, result.get("detail", "error")])

	_update_display()


## Apply combat modifier from hero bag item
func _apply_combat_modifier_from_bag(hero_id: String, item_id: String, modifier_key: String, modifier_value: int, label: String, effect_desc: String) -> void:
	if GameContext.has_pending_combat_modifier():
		print("[Camp] %s - replacing existing combat modifier" % label)

	var modifier = {
		"id": item_id,
		"label": label,
		modifier_key: modifier_value
	}
	GameContext.set_pending_combat_modifier(modifier)

	# Consume from hero bag using existing remove function
	GameContext.remove_item_from_hero_bag(hero_id, item_id, 1)

	print("[Camp] %s used %s - %s for next combat" % [hero_id, label, effect_desc])
	_update_display()


## Show hero info popup (stats, equipment, abilities, etc.)
func _on_hero_info_pressed(hero_id: String) -> void:
	# Close existing window if open
	if _hero_info_window != null and is_instance_valid(_hero_info_window):
		_hero_info_window.queue_free()
		_hero_info_window = null

	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if hero else hero_id
	var class_id = hero.get("class_id", "") if hero else ""
	var race_id = hero.get("race_id", "human") if hero else "human"

	# Get class and race display names
	var cls_display_name = class_id.capitalize()
	if class_id != "" and DataRegistry.has_method("get_class_data"):
		var cls = DataRegistry.get_class_data(class_id)
		if cls != null and cls.display_name != "":
			cls_display_name = cls.display_name

	var race_display_name = race_id.capitalize()
	var race_data: RaceData = null
	if DataRegistry.has_method("get_race"):
		race_data = DataRegistry.get_race(race_id)
		if race_data != null and race_data.display_name != "":
			race_display_name = race_data.display_name

	# Create floating window
	_hero_info_window = Window.new()
	_hero_info_window.title = "%s" % hero_name
	_hero_info_window.size = Vector2i(320, 450)
	_hero_info_window.position = Vector2i(100, 100)
	_hero_info_window.unresizable = false
	_hero_info_window.exclusive = false
	_hero_info_window.always_on_top = true
	_hero_info_window.transient = true
	_hero_info_window.close_requested.connect(_on_hero_info_window_closed)

	# Create scroll container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_info_window.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# === HERO NAME AND CLASS ===
	var name_label = Label.new()
	name_label.text = "%s (%s %s)" % [hero_name, race_display_name, cls_display_name]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(name_label)

	vbox.add_child(HSeparator.new())

	# === STATS ===
	var stats_title = Label.new()
	stats_title.text = "Stats"
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(stats_title)

	var hp_data = GameContext.get_hero_hp(hero_id)
	var stats = GameContext.get_hero_effective_stats(hero_id)

	_add_camp_stat_line(vbox, "HP", "%d / %d" % [hp_data.get("current", 0), hp_data.get("max", 0)], Color.LIGHT_GREEN)
	_add_camp_stat_line(vbox, "Attack", str(stats.get("attack", 0)), Color.SALMON)
	_add_camp_stat_line(vbox, "Defense", str(stats.get("defense", 0)), Color.LIGHT_BLUE)
	_add_camp_stat_line(vbox, "Speed", str(stats.get("speed", 0)), Color.YELLOW)

	vbox.add_child(HSeparator.new())

	# === EQUIPMENT ===
	var equip_title = Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(equip_title)

	var equipment = GameContext.get_hero_equipment(hero_id)
	var slots = ["weapon", "offhand", "helmet", "armor", "legs", "ring", "amulet"]
	var slot_names = {"weapon": "Weapon", "offhand": "Offhand", "helmet": "Helmet", "armor": "Armor", "legs": "Legs", "ring": "Ring", "amulet": "Amulet"}

	for slot in slots:
		var slot_data = equipment.get(slot, {})
		var item_id = slot_data.get("id", "") if slot_data is Dictionary else ""
		var quality = int(slot_data.get("quality", 0)) if slot_data is Dictionary else 0
		var slot_display = slot_names.get(slot, slot.capitalize())
		var slot_text = "(empty)"
		var tooltip_text = ""
		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				slot_text = tpl.display_name
				tooltip_text = _build_camp_item_tooltip(tpl, quality)
			else:
				slot_text = item_id
		_add_camp_equipment_line(vbox, slot_display, slot_text, Color.SANDY_BROWN if item_id != "" else Color.DIM_GRAY, tooltip_text)

	vbox.add_child(HSeparator.new())

	# === ABILITIES ===
	var ability_title = Label.new()
	ability_title.text = "Abilities"
	ability_title.add_theme_font_size_override("font_size", 14)
	ability_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(ability_title)

	var cls_data = DataRegistry.get_class_data(class_id) if class_id != "" and DataRegistry.has_method("get_class_data") else null
	var ability_a_id = cls_data.ability_a_id if cls_data else ""
	var ability_b_id = cls_data.ability_b_id if cls_data else ""
	var has_abilities = false

	if ability_a_id != "":
		var ability_a = DataRegistry.get_ability(ability_a_id) if DataRegistry.has_method("get_ability") else null
		var a_name = ability_a.display_name if ability_a else ability_a_id
		var a_desc = ability_a.description if ability_a else ""
		_add_camp_ability_line(vbox, "[A] %s" % a_name, a_desc)
		has_abilities = true

	if ability_b_id != "":
		var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
		var b_name = ability_b.display_name if ability_b else ability_b_id
		var b_desc = ability_b.description if ability_b else ""
		_add_camp_ability_line(vbox, "[B] %s" % b_name, b_desc)
		has_abilities = true

	if not has_abilities:
		var none_lbl = Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		vbox.add_child(none_lbl)

	# === CLOSE BUTTON ===
	vbox.add_child(HSeparator.new())
	var close_btn = Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.pressed.connect(_on_hero_info_window_closed)
	vbox.add_child(close_btn)

	# Show window
	add_child(_hero_info_window)
	_hero_info_window.popup_centered()


func _on_hero_info_window_closed() -> void:
	if _hero_info_window != null and is_instance_valid(_hero_info_window):
		_hero_info_window.queue_free()
		_hero_info_window = null


## Helper: Add a stat line to the hero info window
func _add_camp_stat_line(container: VBoxContainer, stat_name: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", color)
	hbox.add_child(val_lbl)

	container.add_child(hbox)


## Helper: Add an ability line with name and description
func _add_camp_ability_line(container: VBoxContainer, ability_name: String, desc: String) -> void:
	var ability_vbox = VBoxContainer.new()
	ability_vbox.add_theme_constant_override("separation", 2)

	var name_lbl = Label.new()
	name_lbl.text = ability_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	ability_vbox.add_child(name_lbl)

	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(260, 0)
		ability_vbox.add_child(desc_lbl)

	container.add_child(ability_vbox)


## Get display name for an item
func _get_item_display_name(item_id: String) -> String:
	if item_id == "":
		return "(empty)"
	var template = DataRegistry.get_item_template(item_id)
	if template != null and template.display_name != "":
		return template.display_name
	return item_id


## Helper: Add an equipment line with tooltip support
func _add_camp_equipment_line(container: VBoxContainer, slot_name: String, value: String, color: Color, tooltip: String = "") -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = slot_name + ":"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", color)
	if tooltip != "":
		val_lbl.tooltip_text = tooltip
		val_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_child(val_lbl)

	container.add_child(hbox)


## Build tooltip text showing item stats for equipment
func _build_camp_item_tooltip(template, quality_tier: int) -> String:
	if template == null:
		return ""

	var lines: Array[String] = []

	# Item name and description
	lines.append(template.display_name)
	if template.description != "":
		lines.append(template.description)
	lines.append("")

	# Quality multiplier
	var quality_names = ["Common", "Uncommon", "Rare", "Epic"]
	var quality_mults = [1.0, 1.1, 1.2, 1.35]
	var quality_name = quality_names[quality_tier] if quality_tier < quality_names.size() else "Common"
	var quality_mult = quality_mults[quality_tier] if quality_tier < quality_mults.size() else 1.0
	if quality_tier > 0:
		lines.append("Quality: %s (x%.2f stats)" % [quality_name, quality_mult])
		lines.append("")

	# Stats with quality scaling
	var base_stats = template.base_stats if template.base_stats != null else {}
	var stat_bonuses = template.stat_bonuses if template.stat_bonuses != null else {}

	# Combine base_stats and stat_bonuses
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


# ============================================================================
# SHOPKEEPER BAG (Dungeon Stash Items)
# ============================================================================

## Populate the shopkeeper bag section at the bottom
func _populate_shopkeeper_bag() -> void:
	# Clear existing
	for child in shopkeeper_bag.get_children():
		child.queue_free()
	_shopkeeper_items.clear()

	# Get shopkeeper bag items (items player sent to shop bag after combat)
	var bag_items = GameContext.get_shopkeeper_bag()

	if bag_items.is_empty():
		var hint = Label.new()
		hint.text = "(Empty)"
		hint.modulate = Color(0.5, 0.5, 0.5, 1)
		shopkeeper_bag.add_child(hint)
		return

	# Build slot buttons for each item in the bag
	for entry in bag_items:
		var item_id = entry.get("item_id", "")
		var qty = entry.get("qty", 1)
		var template = DataRegistry.get_item_template(item_id)
		var display_name = template.display_name if template else item_id

		_shopkeeper_items.append({
			"item_id": item_id,
			"qty": qty,
			"display_name": display_name
		})

		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(60, 32)

		# Show name + qty
		if qty > 1:
			slot_btn.text = "%s(%d)" % [display_name.substr(0, 4), qty]
		else:
			slot_btn.text = display_name.substr(0, 6) if display_name.length() > 6 else display_name

		# Build detailed tooltip
		var tooltip_lines: Array[String] = ["%s x%d" % [display_name, qty]]
		if template != null:
			if template.description != "":
				tooltip_lines.append(template.description)

			# Equipment stats
			if template.equip_slot != "":
				tooltip_lines.append("")
				tooltip_lines.append("Slot: %s" % template.equip_slot.capitalize())
				var base_stats = template.base_stats if template.base_stats != null else {}
				var stat_bonuses = template.stat_bonuses if template.stat_bonuses != null else {}
				var all_stats = {}
				for key in base_stats.keys():
					all_stats[key] = base_stats[key]
				for key in stat_bonuses.keys():
					if not all_stats.has(key):
						all_stats[key] = stat_bonuses[key]
				if all_stats.size() > 0:
					for stat_name in all_stats.keys():
						tooltip_lines.append("+%d %s" % [int(all_stats[stat_name]), stat_name.capitalize()])

			# Materials: show recipes
			if template.category == "materials":
				var recipes = GameContext.get_recipes_using_material(item_id)
				if recipes.size() > 0:
					tooltip_lines.append("")
					tooltip_lines.append("Used in recipes:")
					for recipe_info in recipes:
						tooltip_lines.append("  • %s" % recipe_info.recipe_name)

		slot_btn.tooltip_text = "\n".join(tooltip_lines)

		# Check if equippable
		if template != null and template.equip_slot in ["weapon", "offhand"]:
			slot_btn.tooltip_text += "\n\nClick to equip"
			slot_btn.pressed.connect(_on_shopkeeper_item_pressed.bind(item_id, template.equip_slot))
		elif template != null and template.category == "consumable":
			slot_btn.tooltip_text += "\n\nTransfer to hero bag (coming soon)"

		shopkeeper_bag.add_child(slot_btn)

	print("[Camp] Populated shopkeeper bag with %d items" % bag_items.size())


## Handle click on shopkeeper bag item (equip to hero)
func _on_shopkeeper_item_pressed(item_id: String, slot: String) -> void:
	var party = GameContext.get_selected_party()
	if party.is_empty():
		print("[Camp] No heroes to equip")
		return

	# If only one hero, equip directly
	if party.size() == 1:
		_equip_from_stash(party[0], slot, item_id)
		return

	# Multiple heroes - show selection popup
	_pending_consumable_item_id = item_id
	_pending_consumable_hero_id = slot  # Reusing this var for slot

	if _consumable_use_popup != null:
		_consumable_use_popup.queue_free()

	_consumable_use_popup = PopupMenu.new()
	add_child(_consumable_use_popup)

	for i in range(party.size()):
		var hero_id = party[i]
		var hero = GameContext.get_hero(hero_id)
		var hero_name = hero.get("name", hero_id) if hero else hero_id
		_consumable_use_popup.add_item("Equip to %s" % hero_name, i)

	_consumable_use_popup.id_pressed.connect(_on_shopkeeper_equip_hero_selected)
	_consumable_use_popup.popup_centered()


## Handle hero selection for equipping from shopkeeper bag
func _on_shopkeeper_equip_hero_selected(index: int) -> void:
	var party = GameContext.get_selected_party()
	if index >= 0 and index < party.size():
		var hero_id = party[index]
		_equip_from_stash(hero_id, _pending_consumable_hero_id, _pending_consumable_item_id)

	if _consumable_use_popup != null:
		_consumable_use_popup.queue_free()
		_consumable_use_popup = null


## Equip item from dungeon/run stash to a hero
func _equip_from_stash(hero_id: String, slot: String, item_id: String) -> void:
	# Try run stash first, then dungeon stash
	if GameContext.equip_hero_item(hero_id, slot, item_id):
		var hero = GameContext.get_hero(hero_id)
		var hero_name = hero.get("name", hero_id) if hero else hero_id
		print("[Camp] Equipped %s to %s's %s slot" % [item_id, hero_name, slot])
		_update_display()
	else:
		print("[Camp] Failed to equip %s" % item_id)
