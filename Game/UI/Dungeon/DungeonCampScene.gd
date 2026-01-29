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

# Consumables section
@onready var consumables_section: VBoxContainer = %ConsumablesSection
@onready var consumables_list: VBoxContainer = %ConsumablesList

# Equipment section
@onready var equipment_section: VBoxContainer = %EquipmentSection
@onready var equipment_slots: VBoxContainer = %EquipmentSlots
@onready var equippable_items: VBoxContainer = %EquippableItems

# Cache of current consumable items for hotkey access
var _consumable_slots: Array[Dictionary] = []  # [ { "item_id": String, "qty": int, "use_effect": String }, ... ]

# Currently selected hero for consumable targeting (MVP: first party hero)
var _selected_hero_idx: int = 0

# Cache of equippable items for hotkey access
var _equippable_weapon_items: Array[String] = []  # item_ids that can go in weapon slot
var _equippable_offhand_items: Array[String] = []  # item_ids that can go in offhand slot

# State
var _can_extract: bool = false
var _is_dungeon_complete: bool = false
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

	# Populate consumables list
	_populate_consumables()

	# Populate equipment section
	_populate_equipment()

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
			KEY_1:
				_use_consumable_slot(0)
			KEY_2:
				_use_consumable_slot(1)
			KEY_3:
				_use_consumable_slot(2)
			KEY_W:
				_equip_first_weapon()
			KEY_O:
				_equip_first_offhand()
			KEY_U:
				_unequip_all()


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
# CONSUMABLES
# ============================================================================

## Populate the consumables list from dungeon stash (Consumables v2: data-driven)
func _populate_consumables() -> void:
	# Clear existing items
	for child in consumables_list.get_children():
		child.queue_free()
	_consumable_slots.clear()

	# Get party for hero targeting
	var party = GameContext.get_party()
	if party.is_empty():
		var hint = Label.new()
		hint.text = "(No party selected)"
		hint.modulate = Color(0.5, 0.5, 0.5, 1)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		consumables_list.add_child(hint)
		return

	# Get consumables from GameContext (data-driven)
	var consumables = GameContext.get_camp_consumables()

	# If no consumables, show hint
	if consumables.is_empty():
		var hint = Label.new()
		hint.text = "(No consumables in stash)"
		hint.modulate = Color(0.5, 0.5, 0.5, 1)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		consumables_list.add_child(hint)
		return

	# Show target hero selection (MVP: just show current target)
	var target_hero_id = party[_selected_hero_idx] if _selected_hero_idx < party.size() else party[0]
	var hero_data = GameContext.get_hero(target_hero_id)
	var hero_name = hero_data.get("name", target_hero_id) if not hero_data.is_empty() else target_hero_id

	# Get hero HP status for display
	var hp_display = ""
	var hp_data = GameContext.get_hero_hp(target_hero_id)
	if not hp_data.is_empty():
		hp_display = " (HP: %d/%d)" % [hp_data.get("current", 0), hp_data.get("max", 0)]
	else:
		var stats = GameContext.get_hero_effective_stats(target_hero_id)
		if not stats.is_empty():
			hp_display = " (HP: %d/%d)" % [stats.get("health", 100), stats.get("health", 100)]

	var target_label = Label.new()
	target_label.text = "Target: %s%s" % [hero_name, hp_display]
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	consumables_list.add_child(target_label)

	# Build UI for each consumable
	var slot_idx = 0
	for cons in consumables:
		var item_id = cons.get("item_id", "")
		var display_name = cons.get("display_name", item_id)
		var qty = cons.get("qty", 0)
		var use_effect = cons.get("use_effect", "")
		var use_value = cons.get("use_value", 0)

		_consumable_slots.append({ "item_id": item_id, "qty": qty, "use_effect": use_effect })

		# Create row
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		# Hotkey label
		var hotkey_label = Label.new()
		hotkey_label.text = "[%d]" % (slot_idx + 1)
		hotkey_label.modulate = Color(0.7, 0.7, 0.7, 1)
		row.add_child(hotkey_label)

		# Item name + qty + effect summary
		var effect_hint = _get_effect_hint(use_effect, use_value)
		var name_label = Label.new()
		name_label.text = "%s x%d %s" % [display_name, qty, effect_hint]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Use button
		var btn = Button.new()
		btn.text = "Use"
		btn.custom_minimum_size = Vector2(60, 26)
		btn.pressed.connect(_on_consumable_use_pressed.bind(item_id))
		row.add_child(btn)

		consumables_list.add_child(row)
		slot_idx += 1

	print("[Camp] Populated %d consumables from dungeon stash (target=%s)" % [_consumable_slots.size(), hero_name])


## Get effect hint for consumable display
func _get_effect_hint(use_effect: String, use_value: int) -> String:
	match use_effect:
		"heal", "heal_small", "heal_large":
			return "(+%d HP)" % use_value
		"cure_poison":
			return "(cure poison)"
		"cure_bleeding":
			return "(cure bleeding)"
		"cleanse", "cure_all":
			return "(cure DOT)"
		"buff_speed":
			return "(+SPD next combat)"
		"buff_defense":
			return "(+DEF next combat)"
		_:
			return ""


## Use consumable by slot index (for hotkeys)
func _use_consumable_slot(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _consumable_slots.size():
		print("[Camp] No consumable in slot %d" % (slot_idx + 1))
		return

	var slot = _consumable_slots[slot_idx]
	_use_consumable(slot.item_id)


## Button handler for Use button
func _on_consumable_use_pressed(item_id: String) -> void:
	_use_consumable(item_id)


## Use a consumable item from dungeon stash (Consumables v2: data-driven with persistence)
func _use_consumable(item_id: String) -> void:
	# Check if we have this item
	if not GameContext.has_dungeon_item(item_id, 1):
		print("[Consumable] No %s in dungeon stash" % item_id)
		return

	# Get target hero
	var party = GameContext.get_party()
	if party.is_empty():
		print("[Consumable] No party to use consumable on")
		return

	var target_hero_id = party[_selected_hero_idx] if _selected_hero_idx < party.size() else party[0]

	# Get template to check effect type
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		print("[Consumable] Unknown item template: %s" % item_id)
		return

	# Handle special effects that don't use the standard system
	var use_effect = template.use_effect
	if use_effect in ["buff_speed", "stamina"]:
		_apply_combat_modifier(item_id, "player_spd_bonus", 2, "Stamina Draught", "+2 SPD")
		return
	elif use_effect in ["buff_defense", "resistance"]:
		_apply_combat_modifier(item_id, "player_def_bonus", 3, "Resistance Salve", "+3 DEF")
		return

	# Use the data-driven consumable system
	var result = GameContext.use_consumable_on_hero(item_id, target_hero_id, "dungeon")

	if result.get("success", false):
		print("[Camp] Consumable used successfully: %s" % result.get("detail", ""))
	else:
		print("[Camp] Consumable use failed: %s" % result.get("detail", "error"))

	# Refresh UI
	_update_display()


## Apply combat modifier effect (buffs for next combat)
func _apply_combat_modifier(item_id: String, modifier_key: String, modifier_value: int, label: String, effect_desc: String) -> void:
	if GameContext.has_pending_combat_modifier():
		print("[Consumable] %s - replacing existing combat modifier" % label)

	var modifier = {
		"id": item_id,
		"label": label,
		modifier_key: modifier_value
	}
	GameContext.set_pending_combat_modifier(modifier)

	# Consume the item
	GameContext.consume_stash_item(item_id, "dungeon")

	print("[Consumable] %s used - %s for next combat" % [label, effect_desc])
	_update_display()


# ============================================================================
# EQUIPMENT
# ============================================================================

## Populate the equipment section with current equipped items and equippable items from run stash
func _populate_equipment() -> void:
	# Clear existing UI
	for child in equipment_slots.get_children():
		child.queue_free()
	for child in equippable_items.get_children():
		child.queue_free()
	_equippable_weapon_items.clear()
	_equippable_offhand_items.clear()

	# Show currently equipped items
	var weapon_id = GameContext.get_equipped_weapon()
	var offhand_id = GameContext.get_equipped_offhand()

	# Weapon slot row
	var weapon_row = HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 8)
	var weapon_label = Label.new()
	var weapon_name = _get_item_display_name(weapon_id) if weapon_id != "" else "(empty)"
	weapon_label.text = "Weapon: %s" % weapon_name
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_row.add_child(weapon_label)
	if weapon_id != "":
		var unequip_btn = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(70, 24)
		unequip_btn.pressed.connect(_on_unequip_pressed.bind("weapon"))
		weapon_row.add_child(unequip_btn)
	equipment_slots.add_child(weapon_row)

	# Offhand slot row
	var offhand_row = HBoxContainer.new()
	offhand_row.add_theme_constant_override("separation", 8)
	var offhand_label = Label.new()
	var offhand_name = _get_item_display_name(offhand_id) if offhand_id != "" else "(empty)"
	offhand_label.text = "Offhand: %s" % offhand_name
	offhand_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offhand_row.add_child(offhand_label)
	if offhand_id != "":
		var unequip_btn = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(70, 24)
		unequip_btn.pressed.connect(_on_unequip_pressed.bind("offhand"))
		offhand_row.add_child(unequip_btn)
	equipment_slots.add_child(offhand_row)

	# Gather equippable items from run stash
	var run_items_dict = GameContext.get_run_items_dict()
	for item_id in run_items_dict.keys():
		var template = DataRegistry.get_item_template(item_id)
		if template == null:
			continue
		var equip_slot = template.equip_slot
		if equip_slot == "weapon":
			_equippable_weapon_items.append(item_id)
		elif equip_slot == "offhand":
			_equippable_offhand_items.append(item_id)

	# Build UI for equippable items
	if _equippable_weapon_items.is_empty() and _equippable_offhand_items.is_empty():
		var hint = Label.new()
		hint.text = "(No equippable items in stash)"
		hint.modulate = Color(0.5, 0.5, 0.5, 1)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equippable_items.add_child(hint)
	else:
		# Show weapons
		for item_id in _equippable_weapon_items:
			var row = _create_equip_row(item_id, "weapon", "[W]")
			equippable_items.add_child(row)

		# Show offhands
		for item_id in _equippable_offhand_items:
			var row = _create_equip_row(item_id, "offhand", "[O]")
			equippable_items.add_child(row)

	print("[Camp] Equipment: weapon=%s offhand=%s equippable_wpn=%d equippable_off=%d" % [
		weapon_id if weapon_id != "" else "(none)",
		offhand_id if offhand_id != "" else "(none)",
		_equippable_weapon_items.size(),
		_equippable_offhand_items.size()
	])


## Create a row for an equippable item
func _create_equip_row(item_id: String, slot: String, hotkey: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Hotkey hint
	var hk_label = Label.new()
	hk_label.text = hotkey
	hk_label.modulate = Color(0.7, 0.7, 0.7, 1)
	row.add_child(hk_label)

	# Item name with stats
	var name_label = Label.new()
	var display_name = _get_item_display_name(item_id)
	var stats_str = _get_item_stats_string(item_id)
	name_label.text = "%s %s" % [display_name, stats_str]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# Equip button
	var btn = Button.new()
	btn.text = "Equip"
	btn.custom_minimum_size = Vector2(60, 24)
	btn.pressed.connect(_on_equip_pressed.bind(slot, item_id))
	row.add_child(btn)

	return row


## Get display name for an item
func _get_item_display_name(item_id: String) -> String:
	if item_id == "":
		return "(empty)"
	var template = DataRegistry.get_item_template(item_id)
	if template != null and template.display_name != "":
		return template.display_name
	return item_id


## Get stats string for an item (e.g., "+3 ATK")
func _get_item_stats_string(item_id: String) -> String:
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		return ""
	var parts: Array[String] = []
	var stats = template.base_stats
	if stats.get("attack", 0) > 0:
		parts.append("+%d ATK" % stats.attack)
	if stats.get("defense", 0) > 0:
		parts.append("+%d DEF" % stats.defense)
	if stats.get("speed", 0) > 0:
		parts.append("+%d SPD" % stats.speed)
	if parts.is_empty():
		return ""
	return "(%s)" % ", ".join(parts)


## Button handler for Equip button
func _on_equip_pressed(slot: String, item_id: String) -> void:
	if GameContext.equip_item(slot, item_id):
		print("[Equipment] Equipped %s in %s slot" % [item_id, slot])
		_update_display()


## Button handler for Unequip button
func _on_unequip_pressed(slot: String) -> void:
	GameContext.unequip_item(slot)
	print("[Equipment] Unequipped %s slot" % slot)
	_update_display()


## Hotkey: Equip first available weapon
func _equip_first_weapon() -> void:
	if _equippable_weapon_items.is_empty():
		print("[Equipment] No weapons in stash to equip")
		return
	var item_id = _equippable_weapon_items[0]
	if GameContext.equip_item("weapon", item_id):
		print("[Equipment] Equipped %s via hotkey W" % item_id)
		_update_display()


## Hotkey: Equip first available offhand
func _equip_first_offhand() -> void:
	if _equippable_offhand_items.is_empty():
		print("[Equipment] No offhands in stash to equip")
		return
	var item_id = _equippable_offhand_items[0]
	if GameContext.equip_item("offhand", item_id):
		print("[Equipment] Equipped %s via hotkey O" % item_id)
		_update_display()


## Hotkey: Unequip both slots
func _unequip_all() -> void:
	var weapon = GameContext.get_equipped_weapon()
	var offhand = GameContext.get_equipped_offhand()
	if weapon == "" and offhand == "":
		print("[Equipment] Nothing equipped to unequip")
		return
	if weapon != "":
		GameContext.unequip_item("weapon")
	if offhand != "":
		GameContext.unequip_item("offhand")
	print("[Equipment] Unequipped all via hotkey U")
	_update_display()
