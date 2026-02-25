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
@onready var choice_c_container: VBoxContainer = $MainVBox/MapSection/ChoiceCContainer
@onready var choice_c_label: Label = $MainVBox/MapSection/ChoiceCContainer/ChoiceCLabel
@onready var choice_c_button_container: VBoxContainer = $MainVBox/ButtonSection/ChoiceCButtonContainer
@onready var choice_c_button: Button = $MainVBox/ButtonSection/ChoiceCButtonContainer/ChoiceCButton
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

# Hero picker overlay for consumable targeting
var _consumable_picker_overlay: CanvasLayer = null

# State
var _can_extract: bool = false
var _is_dungeon_complete: bool = false

# Swap system (Feature K: Insurance UI)
var _swap_source: Dictionary = {}  # {type: "hero_bag"|"shopkeeper", hero_id: String, index: int}
var _swap_highlight_btn: Button = null  # Currently highlighted slot for swap

# Region theming
var _region_palette: Dictionary = {}

# Hero info overlay (CanvasLayer, not Window — per Godot 4 best practices)
var _hero_info_overlay: CanvasLayer = null

var _choices: Array = []  # 1-3 room choices (Combat always + optional Event/Elite)
var _is_descend_mode: bool = false  # True when at end of floor (descend instead of room choices)

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Switch to dungeon camp BGM
	UIAudio.play_bgm("dungeon_camp")

	# Apply background art (falls back to region-tinted ColorRect if image not found)
	var region_num: int = GameContext.get_current_region()
	BackgroundManager.apply_background(self, "dungeon", "R%d" % region_num)

	# Load region palette for theming
	_region_palette = RegionTheme.get_palette_for_current_region()
	_apply_region_theme()

	# Generate room choices for this camp visit
	_generate_room_choices()

	_update_display()
	choice_a_button.pressed.connect(_on_choice_a_pressed)
	choice_b_button.pressed.connect(_on_choice_b_pressed)
	choice_c_button.pressed.connect(_on_choice_c_pressed)
	extract_button.pressed.connect(_on_extract_pressed)
	# Flee from camp removed — flee only available mid-combat when a hero dies
	flee_button.visible = false
	# Hide room type legend (not needed)
	var legend_label = get_node_or_null("MainVBox/MapSection/LegendLabel")
	if legend_label:
		legend_label.visible = false
	# Hide "Choose Next Room" header and hotkey hint — buttons are self-explanatory
	var map_header = get_node_or_null("MainVBox/MapSection/MapHeader")
	if map_header:
		map_header.visible = false
	hotkey_hint.visible = false
	print("[DungeonCamp] Loaded. Dungeon=%s Floor=%d Room=%d/%d" % [
		GameContext.get_current_dungeon_id(),
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Show overlays sequentially — tutorial first, then campaign story
	call_deferred("_show_camp_overlays")


## Show tutorial then campaign overlays sequentially so they don't stack.
func _show_camp_overlays() -> void:
	var tut_overlay = TutorialOverlay.try_show(self, "tutorial_first_camp")
	if tut_overlay != null:
		await tut_overlay.tutorial_finished
	var floor_num: int = GameContext.get_current_floor()
	var campaign_overlay = CampaignDialog.try_show(self, "dungeon_camp_story", "", floor_num)
	if campaign_overlay != null:
		await campaign_overlay.dialog_finished


# ============================================================================
# REGION THEMING
# ============================================================================

func _apply_region_theme() -> void:
	# Background (only tint if still a ColorRect — TextureRect has baked-in art)
	var bg = $Background
	if bg is ColorRect:
		bg.color = _region_palette.get("bg_dark", Color(0.1, 0.12, 0.15, 1))

	var accent: Color = _region_palette.get("accent", Color(0.4, 0.65, 0.6, 0.5))
	var border: Color = _region_palette.get("border", Color(0.3, 0.3, 0.3, 0.4))
	var bg_medium: Color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
	var title_bar: Color = _region_palette.get("title_bar", Color(0.18, 0.22, 0.3, 0.9))

	# Title label
	var title_label: Label = $MainVBox/Title
	title_label.add_theme_color_override("font_color", Color(accent.r * 1.5, accent.g * 1.5, accent.b * 1.5, 1.0))
	title_label.add_theme_font_size_override("font_size", GameContext.fs(20))

	# Section headers styling
	var section_headers: Array = [
		$MainVBox/HeroesSection/HeroesHeader,
		$MainVBox/ShopkeeperSection/ShopkeeperHeader,
		$MainVBox/MapSection/MapHeader,
	]
	for header in section_headers:
		header.add_theme_color_override("font_color", Color(accent.r * 1.4, accent.g * 1.4, accent.b * 1.4, 0.9))
		header.add_theme_font_size_override("font_size", GameContext.fs(16))

	# Wrap main sections in themed panels
	_apply_section_panel(heroes_section, bg_medium, border)
	_apply_section_panel(shopkeeper_section, bg_medium, border)
	_apply_section_panel($MainVBox/MapSection, bg_medium, border)
	_apply_section_panel($MainVBox/InfoSection, bg_medium, border)
	_apply_section_panel($MainVBox/StashSection, bg_medium, border)

	# Style stash labels with theme-aware colors
	dungeon_stash_label.add_theme_color_override("font_color", Color(accent.r * 2.0, accent.g * 1.5, accent.b * 0.8, 1.0))
	dungeon_stash_label.modulate = Color.WHITE
	run_stash_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
	run_stash_label.modulate = Color.WHITE

	# Style buttons with theme accents
	_style_themed_button(extract_button, Color(0.3, 0.7, 0.4, 1.0))


func _apply_section_panel(section: Control, bg_color: Color, border_color: Color) -> void:
	if section == null:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	# Wrap in a PanelContainer if not already
	var parent = section.get_parent()
	var idx = section.get_index()
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.layout_mode = 2
	parent.remove_child(section)
	panel.add_child(section)
	parent.add_child(panel)
	parent.move_child(panel, idx)


func _style_themed_button(btn: Button, tint: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(tint.r * 0.3, tint.g * 0.3, tint.b * 0.3, 0.8)
	style.border_color = Color(tint.r * 0.6, tint.g * 0.6, tint.b * 0.6, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(tint.r * 0.45, tint.g * 0.45, tint.b * 0.45, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)


# ============================================================================
# ROOM CHOICE GENERATION
# ============================================================================

func _generate_room_choices() -> void:
	# Get RNG for deterministic choice generation
	var rng = SeededRng.get_dungeon_rng()

	# Generate the choices
	GameContext.generate_pending_room_choices(rng)

	# Cache locally for UI
	var data: Dictionary = GameContext.get_pending_room_choices()
	var mode: String = data.get("mode", "choose")

	if mode == "descend":
		# End of floor - descend mode (player completed all rooms on this floor)
		_is_descend_mode = true
		_choices = []

		# Unlock floors for future runs:
		# 1. The completed floor (selectable as start floor for farming)
		# 2. The next floor (for progression)
		var dungeon_id: String = GameContext.get_current_dungeon_id()
		var floor_num: int = GameContext.get_current_floor()
		if dungeon_id != "":
			GameContext.unlock_floor(dungeon_id, floor_num)      # Completed floor
			GameContext.unlock_floor(dungeon_id, floor_num + 1)  # Next floor
	else:
		# Normal choice mode — 1-3 options
		_is_descend_mode = false
		_choices = []
		for c in data.get("choices", []):
			_choices.append(c)


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
	dungeon_stash_label.text = "Dungeon Loot: %d gold, %d items" % [
		dungeon_stash.gold, dungeon_stash.items_count
	]
	run_stash_label.visible = false

	# Update button states based on game state
	if _is_dungeon_complete:
		# Dungeon complete: hide choice buttons, show only extract
		choice_a_button.visible = false
		choice_b_container.visible = false
		choice_b_button_container.visible = false
		choice_c_container.visible = false
		choice_c_button_container.visible = false
		no_alternate_hint.visible = false
		choice_a_label.visible = true
		choice_a_label.text = "Dungeon Complete!"
		extract_button.visible = true
		extract_button.disabled = false
		hotkey_hint.text = "E=Extract"
	elif _is_descend_mode:
		# First floor gate: first-ever floor completion forces extract only
		var force_extract_only: bool = not GameContext.has_completed_first_floor()
		if force_extract_only:
			choice_a_button.visible = false
			choice_b_container.visible = false
			choice_b_button_container.visible = false
			choice_c_container.visible = false
			choice_c_button_container.visible = false
			no_alternate_hint.visible = false
			choice_a_label.visible = true
			choice_a_label.text = "Floor Complete! Return to town to regroup."
			extract_button.visible = true
			extract_button.disabled = false
			hotkey_hint.text = "E=Return to Town"
		else:
			# End of floor, not final floor -> show Descend button (use A for descend)
			choice_a_button.visible = true
			choice_a_button.text = "Descend to Floor %d (A)" % (floor_num + 1)
			choice_b_container.visible = false
			choice_b_button_container.visible = false
			choice_c_container.visible = false
			choice_c_button_container.visible = false
			no_alternate_hint.visible = false
			extract_button.visible = true
			extract_button.disabled = false
			choice_a_label.visible = true
			choice_a_label.text = "Floor %d complete!" % floor_num
			hotkey_hint.text = "A=Descend | E=Extract"

			# Boss gate: if next floor is the final floor, check facility tier total
			var next_floor_is_boss: bool = (floor_num + 1 >= floor_count)
			if next_floor_is_boss:
				var town_id: String = GameContext.get_current_town_id()
				var gate: Dictionary = GameContext.can_challenge_boss(town_id)
				if not gate.get("ready", true):
					choice_a_button.disabled = true
					choice_a_label.text = "Boss Floor Locked! Need %d+ total facility tiers (%d/%d)" % [
						gate.required, gate.current, gate.required
					]
					hotkey_hint.text = "E=Extract"
				else:
					choice_a_button.disabled = false
			else:
				choice_a_button.disabled = false
	else:
		# Normal room choices mode — 1-3 options
		var next_room_num: int = room_idx + 2  # Next room is current + 1 (1-based display)

		# Find each choice type from the array
		var combat_choice: Dictionary = {}
		var event_choice: Dictionary = {}
		var elite_choice: Dictionary = {}
		for c in _choices:
			if c.get("type") == "event":
				event_choice = c
			elif c.get("is_elite", false):
				elite_choice = c
			elif c.get("forced_boss", false):
				combat_choice = c  # Boss forced — single option
			elif c.get("forced_elite", false):
				combat_choice = c  # Elite forced — single option
			else:
				combat_choice = c  # Normal combat

		# Hide labels — buttons are self-explanatory
		choice_a_label.visible = false

		# Button A: Combat (always present, or forced boss/elite)
		var a_display: String = combat_choice.get("display", "Combat")
		choice_a_button.text = "A: %s" % a_display
		choice_a_button.visible = true
		choice_a_button.disabled = false

		# Button B: Event (if rolled)
		var has_event: bool = not event_choice.is_empty()
		choice_b_container.visible = has_event
		choice_b_button_container.visible = has_event
		if has_event:
			choice_b_label.visible = false
			choice_b_button.text = "B: %s" % event_choice.get("display", "Event")
			choice_b_button.disabled = false

		# Button C: Elite (if rolled)
		var has_elite: bool = not elite_choice.is_empty()
		choice_c_container.visible = has_elite
		choice_c_button_container.visible = has_elite
		if has_elite:
			choice_c_label.visible = false
			choice_c_button.text = "C: %s" % elite_choice.get("display", "Elite Combat")
			choice_c_button.disabled = false

		# No alternate hint: show when only combat is available
		no_alternate_hint.visible = (not has_event and not has_elite)

		# Hotkey hint
		if has_event and has_elite:
			hotkey_hint.text = "A/B/C=Choose Room"
		elif has_event:
			hotkey_hint.text = "A/B=Choose Room"
		elif has_elite:
			hotkey_hint.text = "A/C=Choose Room"
		else:
			hotkey_hint.text = "A=Continue"

		# Extract only available at end of floor (descend mode), so hide here
		extract_button.visible = false

	# Populate hero rows (new layout: Name | Info | Bag)
	_populate_hero_rows()

	# Populate shopkeeper bag at bottom
	_populate_shopkeeper_bag()

	# Log state
	var choice_displays: Array = []
	for c in _choices:
		choice_displays.append(c.get("display", "?"))
	print("[Camp] floor=%d/%d room=%d/%d descend=%s choices=[%s] can_extract=%s complete=%s" % [
		floor_num, floor_count, room_idx + 1, rooms,
		str(_is_descend_mode),
		", ".join(choice_displays) if not _is_descend_mode else "descend",
		str(_can_extract), str(_is_dungeon_complete)
	])


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_choice_a_pressed() -> void:
	if _is_descend_mode:
		_do_descend()
	else:
		# Select the combat choice (or the first/only forced choice)
		for c in _choices:
			if c.get("type") == "combat" and not c.get("is_elite", false):
				_select_choice(c)
				return
		# Fallback: first choice (forced boss/elite single-option)
		if _choices.size() > 0:
			_select_choice(_choices[0])


func _on_choice_b_pressed() -> void:
	if _is_descend_mode:
		return
	# Select the event choice
	for c in _choices:
		if c.get("type") == "event":
			_select_choice(c)
			return


func _on_choice_c_pressed() -> void:
	if _is_descend_mode:
		return
	# Select the elite choice
	for c in _choices:
		if c.get("is_elite", false):
			_select_choice(c)
			return


func _on_extract_pressed() -> void:
	# Tutorial on first extraction
	var overlay = TutorialOverlay.try_show(self, "tutorial_first_extraction")
	if overlay != null:
		await overlay.tutorial_finished
	_do_extract()


func _on_flee_pressed() -> void:
	_do_flee()


# ============================================================================
# HOTKEYS
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# Cancel swap on Escape
	if not _swap_source.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_swap_highlight()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A:
				if choice_a_button.visible and not choice_a_button.disabled:
					_on_choice_a_pressed()
			KEY_B:
				if choice_b_button_container.visible and not choice_b_button.disabled:
					if not _is_descend_mode:
						_on_choice_b_pressed()
			KEY_C:
				if choice_c_button_container.visible and not choice_c_button.disabled:
					if not _is_descend_mode:
						_on_choice_c_pressed()
			KEY_E:
				if _can_extract:
					_do_extract()
				else:
					print("[Camp] Extract blocked - must complete floor first")
			# Flee from camp removed — only available mid-combat on hero death


# ============================================================================
# ACTIONS
# ============================================================================

func _select_choice(choice: Dictionary) -> void:
	# Guard: must be in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DungeonCamp] Not in dungeon, ignoring choice")
		return

	UIAudio.play_sfx("room_choice")
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

	UIAudio.play_sfx("descend_floor")
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
	UIAudio.play_sfx("extraction")

	# Mark first floor completion if applicable
	if not GameContext.has_completed_first_floor():
		GameContext.mark_first_floor_completed()

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
		hint.modulate = Color(0.7, 0.7, 0.7, 1)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hero_rows.add_child(hint)
		return

	# Build a row for each living hero (skip dead heroes)
	var shown: int = 0
	for i in range(party.size()):
		var hero_id: String = party[i]
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		if not hp_data.is_empty() and int(hp_data.get("current", 1)) <= 0:
			continue  # Dead hero — don't show in camp
		var row = _create_hero_row(hero_id, i, party.size())
		hero_rows.add_child(row)
		shown += 1

	print("[Camp] Populated %d hero rows (%d alive)" % [party.size(), shown])


## Create a single hero card: [Arrows | Portrait | Name + Class + HP Bar | Info | Bag Slots]
func _create_hero_row(hero_id: String, party_idx: int = 0, party_size: int = 1) -> PanelContainer:
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if hero else hero_id
	var class_id = hero.get("class_id", "") if hero else ""

	# Get class display name
	var cls_display = class_id.capitalize()
	if class_id != "" and DataRegistry.has_method("get_class_data"):
		var cls = DataRegistry.get_class_data(class_id)
		if cls != null and cls.display_name != "":
			cls_display = cls.display_name

	# Get HP data
	var hp_data = GameContext.get_hero_hp(hero_id)
	var hp_current: int = 0
	var hp_max: int = 100
	if not hp_data.is_empty():
		hp_current = int(hp_data.get("current", 0))
		hp_max = int(hp_data.get("max", 100))
	else:
		var stats = GameContext.get_hero_effective_stats(hero_id)
		if not stats.is_empty():
			hp_current = int(stats.get("health", 100))
			hp_max = int(stats.get("health", 100))

	# Card panel
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	var bg_medium: Color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
	card_style.bg_color = Color(bg_medium.r * 0.85, bg_medium.g * 0.85, bg_medium.b * 0.85, 0.7)
	card_style.border_color = _region_palette.get("border", Color(0.3, 0.3, 0.3, 0.3))
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(3)
	card_style.content_margin_left = 6
	card_style.content_margin_right = 6
	card_style.content_margin_top = 4
	card_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", card_style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	# Combat row selector (Front/Middle/Back)
	var row_select = OptionButton.new()
	row_select.custom_minimum_size = Vector2(65, 26)
	row_select.add_theme_font_size_override("font_size", GameContext.fs(12))
	row_select.add_item("Front", 0)
	row_select.add_item("Mid", 1)
	row_select.add_item("Back", 2)
	row_select.selected = GameContext.get_hero_row(hero_id)
	row_select.tooltip_text = "Combat row position\nFront: Targeted first by melee\nMiddle: Targeted after Front\nBack: Targeted last by melee"
	row_select.item_selected.connect(_on_hero_row_changed.bind(hero_id))
	row.add_child(row_select)

	# Portrait (28x28)
	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(28, 28)
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var portrait_path: String = hero.get("portrait_path", "") if hero else ""
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)
	row.add_child(portrait_rect)

	# Name + Class + HP bar column
	var info_col = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 2)
	info_col.custom_minimum_size = Vector2(110, 0)
	row.add_child(info_col)

	# Name label
	var name_label = Label.new()
	name_label.text = hero_name
	name_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	info_col.add_child(name_label)

	# Class label
	var class_label = Label.new()
	class_label.text = cls_display
	class_label.add_theme_font_size_override("font_size", GameContext.fs(12))
	class_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7, 0.8))
	info_col.add_child(class_label)

	# HP bar
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(100, 10)
	hp_bar.max_value = hp_max
	hp_bar.value = hp_current
	hp_bar.show_percentage = false
	# Color by HP ratio
	var hp_ratio: float = float(hp_current) / float(hp_max) if hp_max > 0 else 0.0
	var bar_color: Color
	if hp_ratio > 0.6:
		bar_color = Color(0.3, 0.8, 0.3, 1.0)
	elif hp_ratio > 0.3:
		bar_color = Color(0.9, 0.8, 0.2, 1.0)
	else:
		bar_color = Color(0.9, 0.3, 0.2, 1.0)
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = bar_color
	bar_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", bar_style)
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	bar_bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	info_col.add_child(hp_bar)

	# HP text
	var hp_label = Label.new()
	hp_label.text = "%d/%d" % [hp_current, hp_max]
	hp_label.add_theme_font_size_override("font_size", GameContext.fs(11))
	hp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	info_col.add_child(hp_label)

	# Level + XP progress
	var hero_level: int = int(hero.get("level", 1)) if hero else 1
	var xp_row = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 6)
	var lvl_lbl = Label.new()
	lvl_lbl.text = "Lv%d" % hero_level
	lvl_lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
	lvl_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.9))
	xp_row.add_child(lvl_lbl)

	var xp_prog: Dictionary = GameContext.get_hero_xp_progress(hero_id)
	if xp_prog.is_max:
		var xp_max_lbl = Label.new()
		xp_max_lbl.text = "MAX"
		xp_max_lbl.add_theme_font_size_override("font_size", GameContext.fs(10))
		xp_max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		xp_row.add_child(xp_max_lbl)
	else:
		var xp_bar = ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(80, 8)
		xp_bar.min_value = 0
		xp_bar.max_value = xp_prog.needed
		xp_bar.value = xp_prog.current
		xp_bar.show_percentage = false
		var xp_bar_bg = StyleBoxFlat.new()
		xp_bar_bg.bg_color = Color(0.15, 0.15, 0.2, 0.8)
		xp_bar_bg.set_corner_radius_all(2)
		xp_bar.add_theme_stylebox_override("background", xp_bar_bg)
		var xp_bar_fill = StyleBoxFlat.new()
		xp_bar_fill.bg_color = Color(0.3, 0.7, 1.0, 0.9)
		xp_bar_fill.set_corner_radius_all(2)
		xp_bar.add_theme_stylebox_override("fill", xp_bar_fill)
		xp_row.add_child(xp_bar)
		var xp_txt = Label.new()
		xp_txt.text = "%d/%d" % [xp_prog.current, xp_prog.needed]
		xp_txt.add_theme_font_size_override("font_size", GameContext.fs(10))
		xp_txt.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0, 0.8))
		xp_row.add_child(xp_txt)
	info_col.add_child(xp_row)

	# Info button
	var info_btn = Button.new()
	info_btn.text = "Info"
	info_btn.custom_minimum_size = Vector2(44, 26)
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

			# Item icon (Button.icon property)
			var has_icon = false
			if template != null:
				var icon_tex = template.get_icon_texture()
				if icon_tex != null:
					slot_btn.icon = icon_tex
					slot_btn.expand_icon = true
					has_icon = true

			# Show qty badge when icon present, otherwise abbreviated name
			if has_icon:
				slot_btn.text = str(qty) if qty > 1 else ""
			elif qty > 1:
				slot_btn.text = str(qty)
			else:
				slot_btn.text = display_name.substr(0, 3) if display_name.length() > 3 else display_name

			# Build detailed tooltip
			var tooltip_lines: Array[String] = ["%s x%d" % [display_name, qty]]
			if template != null:
				if template.description != "":
					tooltip_lines.append(template.description)
				# Consumable effects
				if template.use_effect != "":
					tooltip_lines.append("")
					tooltip_lines.append(template.get_effect_label())
				# Materials: show recipes
				if template.category == "materials":
					var recipes = GameContext.get_recipes_using_material(item_id)
					if recipes.size() > 0:
						tooltip_lines.append("")
						tooltip_lines.append("Used in recipes:")
						for recipe_info in recipes:
							tooltip_lines.append("  • %s" % recipe_info.recipe_name)
			# Consumable: left-click opens hero picker; others: right-click
			if template != null and template.category == "consumable":
				tooltip_lines.append("")
				tooltip_lines.append("Click to use")
				slot_btn.tooltip_text = "\n".join(tooltip_lines)
				slot_btn.pressed.connect(_on_consumable_slot_pressed.bind(item_id, hero_id))
			else:
				tooltip_lines.append("")
				tooltip_lines.append("Right-click to use")
				slot_btn.tooltip_text = "\n".join(tooltip_lines)

			# Connect right-click for non-consumable use and shift+click for swap
			slot_btn.gui_input.connect(_on_bag_slot_input.bind(hero_id, item_id, slot_idx))
			# Wire swap via shift+click
			slot_btn.gui_input.connect(_on_hero_bag_slot_gui_input.bind(hero_id, slot_idx, slot_btn))

			# Drag-and-drop forwarding for cross-bag transfers
			slot_btn.set_drag_forwarding(
				_hero_bag_get_drag.bind(hero_id, slot_idx, slot_btn),
				_hero_bag_can_drop,
				_hero_bag_drop.bind(hero_id, slot_idx)
			)

			_hero_bag_cache[hero_id].append({
				"slot_idx": slot_idx,
				"item_id": item_id,
				"qty": qty
			})
		else:
			# Empty slot — accept drops but cannot initiate drag
			slot_btn.text = "-"
			slot_btn.tooltip_text = "Empty slot (drop item here)"
			slot_btn.set_drag_forwarding(
				_hero_bag_get_drag_empty,
				_hero_bag_can_drop,
				_hero_bag_drop.bind(hero_id, slot_idx)
			)

		bag_container.add_child(slot_btn)

	row.add_child(bag_container)

	return card


## Handle input on bag slots (right-click to use consumable via hero picker)
func _on_bag_slot_input(event: InputEvent, hero_id: String, item_id: String, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var template = DataRegistry.get_item_template(item_id)
		if template != null and template.category == "consumable":
			_show_hero_picker_for_consumable(item_id, hero_id, "hero_bag")
		else:
			print("[Camp] Right-click on non-consumable %s — ignored" % item_id)


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
	elif use_effect in ["buff_evasion", "buff_evasion_and_stealth"]:
		_apply_combat_modifier_from_bag(hero_id, item_id, "player_eva_bonus", template.use_value, template.display_name, "+%d EVA" % template.use_value)
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


# ============================================================================
# CONSUMABLE HERO PICKER OVERLAY
# ============================================================================

## Called when a consumable slot is left-clicked (hero bag or shopkeeper bag).
func _on_consumable_slot_pressed(item_id: String, source_hero_id: String) -> void:
	var source: String = "hero_bag" if source_hero_id != "" else "shopkeeper_bag"
	_show_hero_picker_for_consumable(item_id, source_hero_id, source)


## Show overlay to pick which hero receives the consumable effect.
func _show_hero_picker_for_consumable(item_id: String, source_hero_id: String, source: String) -> void:
	_close_consumable_picker()

	var template = DataRegistry.get_item_template(item_id)
	var item_name: String = template.display_name if template else item_id

	_consumable_picker_overlay = CanvasLayer.new()
	_consumable_picker_overlay.layer = 10
	add_child(_consumable_picker_overlay)
	UIAudio.register_closeable(_consumable_picker_overlay, _close_consumable_picker)

	# Root control for input blocking
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_consumable_picker_overlay.add_child(root)

	# Dark backdrop
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_consumable_picker_backdrop)
	root.add_child(backdrop)

	# Centered panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	style.border_color = Color(0.3, 0.6, 0.3, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Use %s on:" % item_name
	title.add_theme_font_size_override("font_size", GameContext.fs(16))
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Hero buttons
	var party: Array = GameContext.get_selected_party()
	for hero_id in party:
		var hero: Dictionary = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		var current_hp: int = int(hp_data.get("current", 1))
		var max_hp: int = int(hp_data.get("max", 1))
		if current_hp <= 0:
			continue  # Skip dead heroes

		var hero_name: String = hero.get("name", hero_id)
		var btn = Button.new()
		btn.text = "%s  (%d/%d HP)" % [hero_name, current_hp, max_hp]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_consumable_hero_chosen.bind(item_id, hero_id, source_hero_id, source))
		vbox.add_child(btn)

	# Cancel button
	vbox.add_child(HSeparator.new())
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_close_consumable_picker)
	vbox.add_child(cancel_btn)


## Handle hero selection from the consumable picker.
func _on_consumable_hero_chosen(item_id: String, target_hero_id: String, source_hero_id: String, source: String) -> void:
	_close_consumable_picker()

	# Check for combat modifier consumables (buff_speed, buff_defense, etc.)
	var template = DataRegistry.get_item_template(item_id)
	if template != null and template.category == "consumable":
		var use_effect: String = template.use_effect
		if use_effect in ["buff_speed", "stamina"]:
			if source == "hero_bag" and source_hero_id != "":
				_apply_combat_modifier_from_bag(source_hero_id, item_id, "player_spd_bonus", 2, "Stamina Draught", "+2 SPD")
			else:
				# Shopkeeper bag: consume from shopkeeper bag and apply modifier
				GameContext.consume_stash_item(item_id, "shopkeeper_bag")
				var modifier = {"id": item_id, "label": "Stamina Draught", "player_spd_bonus": 2}
				GameContext.set_pending_combat_modifier(modifier)
				print("[Camp] Used Stamina Draught from shopkeeper bag - +2 SPD for next combat")
			_update_display()
			return
		elif use_effect in ["buff_defense", "resistance"]:
			if source == "hero_bag" and source_hero_id != "":
				_apply_combat_modifier_from_bag(source_hero_id, item_id, "player_def_bonus", 3, "Resistance Salve", "+3 DEF")
			else:
				# Shopkeeper bag: consume from shopkeeper bag and apply modifier
				GameContext.consume_stash_item(item_id, "shopkeeper_bag")
				var modifier = {"id": item_id, "label": "Resistance Salve", "player_def_bonus": 3}
				GameContext.set_pending_combat_modifier(modifier)
				print("[Camp] Used Resistance Salve from shopkeeper bag - +3 DEF for next combat")
			_update_display()
			return
		elif use_effect in ["buff_evasion", "buff_evasion_and_stealth"]:
			var eva_val: int = template.use_value
			if source == "hero_bag" and source_hero_id != "":
				_apply_combat_modifier_from_bag(source_hero_id, item_id, "player_eva_bonus", eva_val, template.display_name, "+%d EVA" % eva_val)
			else:
				GameContext.consume_stash_item(item_id, "shopkeeper_bag")
				var modifier = {"id": item_id, "label": template.display_name, "player_eva_bonus": eva_val}
				GameContext.set_pending_combat_modifier(modifier)
				print("[Camp] Used %s from shopkeeper bag - +%d EVA for next combat" % [template.display_name, eva_val])
			_update_display()
			return

	var result: Dictionary = GameContext.use_consumable_on_hero(item_id, target_hero_id, source, source_hero_id)
	if result.get("success", false):
		print("[Camp] Used %s on %s: %s" % [item_id, target_hero_id, result.get("detail", "")])
	else:
		print("[Camp] Failed to use %s on %s: %s" % [item_id, target_hero_id, result.get("detail", "")])
	_update_display()


## Close the consumable hero picker overlay.
func _close_consumable_picker() -> void:
	if _consumable_picker_overlay != null and is_instance_valid(_consumable_picker_overlay):
		UIAudio.unregister_closeable(_consumable_picker_overlay)
		_consumable_picker_overlay.queue_free()
		_consumable_picker_overlay = null


## Handle backdrop click to dismiss the consumable picker.
func _on_consumable_picker_backdrop(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_consumable_picker()


## Handle hero row assignment change (combat position: Front/Middle/Back).
func _on_hero_row_changed(row_index: int, hero_id: String) -> void:
	GameContext.set_hero_row(hero_id, row_index)
	var row_names = ["Front", "Middle", "Back"]
	print("[Camp] Hero %s assigned to %s row" % [hero_id, row_names[row_index]])


## Show hero info overlay (stats, equipment, abilities, etc.)
## Uses CanvasLayer overlay instead of Window (avoids Godot 4 Window embedding issues).
func _on_hero_info_pressed(hero_id: String) -> void:
	# Close existing overlay if open
	if _hero_info_overlay != null and is_instance_valid(_hero_info_overlay):
		_hero_info_overlay.queue_free()
		_hero_info_overlay = null

	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if hero else hero_id
	var class_id = hero.get("class_id", "") if hero else ""
	var race_id = hero.get("race_id", "human") if hero else "human"
	var hero_level: int = int(hero.get("level", 1)) if hero else 1

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

	# Create CanvasLayer overlay (layer 10)
	_hero_info_overlay = CanvasLayer.new()
	_hero_info_overlay.layer = 10
	add_child(_hero_info_overlay)
	UIAudio.register_closeable(_hero_info_overlay, _close_hero_info_overlay)

	# Root control for input blocking
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_hero_info_overlay.add_child(root)

	# Backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_hero_info_backdrop_input)
	root.add_child(backdrop)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = _region_palette.get("bg_dark", Color(0.08, 0.08, 0.12, 0.97))
	panel_style.border_color = _region_palette.get("border", Color(0.4, 0.4, 0.4, 0.7))
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0, 0, 0, 0.4)
	panel_style.shadow_size = 6
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	# Scroll container for content
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 400)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# === HERO NAME AND CLASS ===
	var accent: Color = _region_palette.get("accent", Color(0.4, 0.65, 0.6, 0.5))
	var name_label = Label.new()
	name_label.text = "%s (%s %s)" % [hero_name, race_display_name, cls_display_name]
	name_label.add_theme_font_size_override("font_size", GameContext.fs(18))
	name_label.add_theme_color_override("font_color", Color(accent.r * 1.6, accent.g * 1.6, accent.b * 1.6, 1.0))
	vbox.add_child(name_label)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# === STATS ===
	var stats_title = Label.new()
	stats_title.text = "Stats"
	stats_title.add_theme_font_size_override("font_size", GameContext.fs(16))
	stats_title.add_theme_color_override("font_color", Color(accent.r * 1.8, accent.g * 1.4, accent.b * 0.8, 1.0))
	vbox.add_child(stats_title)

	var hp_data = GameContext.get_hero_hp(hero_id)
	var stats = GameContext.get_hero_effective_stats(hero_id)

	_add_camp_stat_line(vbox, "HP", "%d / %d" % [hp_data.get("current", 0), hp_data.get("max", 0)], Color.LIGHT_GREEN, _build_camp_stat_tooltip("Health", hero_id))
	_add_camp_stat_line(vbox, "Attack", str(stats.get("attack", 0)), Color.SALMON, _build_camp_stat_tooltip("Attack", hero_id))
	_add_camp_stat_line(vbox, "Defense", str(stats.get("defense", 0)), Color.LIGHT_BLUE, _build_camp_stat_tooltip("Defense", hero_id))
	_add_camp_stat_line(vbox, "Speed", str(stats.get("speed", 0)), Color.YELLOW, _build_camp_stat_tooltip("Speed", hero_id))
	# New stats (only show if > 0)
	var camp_new_stats = [
		{"key": "crit_chance", "label": "Crit", "color": Color(1.0, 0.7, 0.3)},
		{"key": "evasion", "label": "Evasion", "color": Color(0.6, 0.9, 0.6)},
		{"key": "resist", "label": "Resist", "color": Color(0.7, 0.5, 0.9)},
		{"key": "thorns", "label": "Thorns", "color": Color(0.8, 0.4, 0.4)},
		{"key": "armor_penetration", "label": "Pen", "color": Color(0.9, 0.6, 0.5)},
		{"key": "life_steal", "label": "Life Steal", "color": Color(0.8, 0.3, 0.3)},
	]
	for ns in camp_new_stats:
		var ns_val = int(stats.get(ns.key, 0))
		if ns_val > 0:
			var suffix: String = "%%" if ns.key in ["crit_chance", "evasion", "life_steal"] else ""
			_add_camp_stat_line(vbox, ns.label, "%d%s" % [ns_val, suffix], ns.color, _build_camp_stat_tooltip(ns.key.capitalize(), hero_id))

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# === EQUIPMENT ===
	var equip_title = Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", GameContext.fs(16))
	equip_title.add_theme_color_override("font_color", Color(accent.r * 1.4, accent.g * 1.4, accent.b * 1.4, 1.0))
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
		var equip_color: Color = Color.DIM_GRAY
		if item_id != "" and quality > 0:
			equip_color = ItemInstance.QUALITY_COLORS[clampi(quality, 0, 3)]
		elif item_id != "":
			equip_color = Color.SANDY_BROWN
		_add_camp_equipment_line(vbox, slot_display, slot_text, equip_color, tooltip_text)

	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# === ABILITIES ===
	var ability_title = Label.new()
	ability_title.text = "Abilities"
	ability_title.add_theme_font_size_override("font_size", GameContext.fs(16))
	ability_title.add_theme_color_override("font_color", Color(accent.r * 1.4, accent.g * 1.4, accent.b * 1.4, 1.0))
	vbox.add_child(ability_title)

	var cls_data = DataRegistry.get_class_data(class_id) if class_id != "" and DataRegistry.has_method("get_class_data") else null
	var ability_a_id = cls_data.ability_a_id if cls_data else ""
	var ability_b_id = cls_data.ability_b_id if cls_data else ""
	var has_abilities = false

	if ability_a_id != "":
		var ability_a = DataRegistry.get_ability(ability_a_id) if DataRegistry.has_method("get_ability") else null
		var a_name = ability_a.display_name if ability_a else ability_a_id
		var a_desc = ability_a.description if ability_a else ""
		if GameContext.is_ability_slot_unlocked("ability_a", hero_level):
			_add_camp_ability_line(vbox, "[A] %s" % a_name, a_desc)
		else:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_a", 5)
			_add_camp_ability_line(vbox, "[A] %s (Lv %d)" % [a_name, req_lv], a_desc, Color(0.7, 0.7, 0.7, 1))
		has_abilities = true

	if ability_b_id != "":
		var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
		var b_name = ability_b.display_name if ability_b else ability_b_id
		var b_desc = ability_b.description if ability_b else ""
		if GameContext.is_ability_slot_unlocked("ability_b", hero_level):
			_add_camp_ability_line(vbox, "[B] %s" % b_name, b_desc)
		else:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_b", 25)
			_add_camp_ability_line(vbox, "[B] %s (Lv %d)" % [b_name, req_lv], b_desc, Color(0.7, 0.7, 0.7, 1))
		has_abilities = true

	if not has_abilities:
		var none_lbl = Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		vbox.add_child(none_lbl)

	# === CLOSE BUTTON ===
	var sep4 = HSeparator.new()
	vbox.add_child(sep4)
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 30)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_hero_info_overlay)
	vbox.add_child(close_btn)


func _on_hero_info_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_hero_info_overlay()


func _close_hero_info_overlay() -> void:
	if _hero_info_overlay != null and is_instance_valid(_hero_info_overlay):
		UIAudio.unregister_closeable(_hero_info_overlay)
		_hero_info_overlay.queue_free()
		_hero_info_overlay = null


## Helper: Add a stat line to the hero info window with optional tooltip
func _add_camp_stat_line(container: VBoxContainer, stat_name: String, value: String, color: Color, tooltip: String = "") -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	val_lbl.add_theme_color_override("font_color", color)
	if tooltip != "":
		val_lbl.tooltip_text = tooltip
		val_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_child(val_lbl)

	container.add_child(hbox)


## Helper: Add an ability line with name and description
func _add_camp_ability_line(container: VBoxContainer, ability_name: String, desc: String, color_override: Color = Color.WHITE) -> void:
	var ability_vbox = VBoxContainer.new()
	ability_vbox.add_theme_constant_override("separation", 2)

	var name_lbl = Label.new()
	name_lbl.text = ability_name
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_lbl.add_theme_color_override("font_color", color_override)
	ability_vbox.add_child(name_lbl)

	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
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
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	val_lbl.add_theme_color_override("font_color", color)
	if tooltip != "":
		val_lbl.tooltip_text = tooltip
		val_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_child(val_lbl)

	container.add_child(hbox)


## Build tooltip showing stat breakdown (class base + race + gear)
func _build_camp_stat_tooltip(stat_name: String, hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return stat_name

	var class_id = hero.get("class_id", "")
	var race_id = hero.get("race_id", "human")
	var level = int(hero.get("level", 1))

	var class_data = DataRegistry.get_class_data(class_id)
	var race_data = DataRegistry.get_race(race_id)

	var stat_key = stat_name.to_lower()  # "health", "attack", "defense", "speed"

	# Get class base at level
	var base_value = 0
	if class_data != null:
		var base_stats = class_data.get_stats_at_level(level)
		base_value = int(base_stats.get(stat_key, 0))

	# Get race modifier and name
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
	var quality_mults = [1.0, 1.1, 1.2, 1.35]
	var quality_name = ItemInstance.QUALITY_NAMES[clampi(quality_tier, 0, 3)]
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
	var safe_count: int = GameContext.SHOPKEEPER_SAFE_SLOTS
	var cap: int = GameContext.SHOPKEEPER_BAG_CAPACITY_DEFAULT

	if bag_items.is_empty():
		# Show empty slots with safe/unsafe tinting
		for i in range(cap):
			var empty_btn = Button.new()
			empty_btn.custom_minimum_size = Vector2(60, 32)
			empty_btn.text = ""
			var is_safe: bool = i < safe_count
			if is_safe:
				empty_btn.tooltip_text = "Safe Slot (empty)"
				var safe_disabled = StyleBoxFlat.new()
				safe_disabled.bg_color = Color(0.08, 0.15, 0.08, 0.5)
				safe_disabled.border_color = Color(0.2, 0.5, 0.2, 0.3)
				safe_disabled.set_border_width_all(1)
				safe_disabled.set_corner_radius_all(2)
				empty_btn.add_theme_stylebox_override("normal", safe_disabled)
			else:
				empty_btn.tooltip_text = "Unsafe Slot (empty)"
			# Empty slots accept drops
			empty_btn.set_drag_forwarding(
				_camp_bag_get_drag_empty,
				_camp_bag_can_drop,
				_camp_bag_drop.bind(i)
			)
			shopkeeper_bag.add_child(empty_btn)
		return

	# Build slot buttons for each item in the bag (and empty trailing slots)
	for i in range(cap):
		var is_safe: bool = i < safe_count

		if i >= bag_items.size():
			# Empty slot beyond bag contents
			var empty_btn = Button.new()
			empty_btn.custom_minimum_size = Vector2(60, 32)
			empty_btn.text = ""
			if is_safe:
				empty_btn.tooltip_text = "Safe Slot (empty)"
				var safe_disabled = StyleBoxFlat.new()
				safe_disabled.bg_color = Color(0.08, 0.15, 0.08, 0.5)
				safe_disabled.border_color = Color(0.2, 0.5, 0.2, 0.3)
				safe_disabled.set_border_width_all(1)
				safe_disabled.set_corner_radius_all(2)
				empty_btn.add_theme_stylebox_override("normal", safe_disabled)
			else:
				empty_btn.tooltip_text = "Unsafe Slot (empty)"
			# Empty slots accept drops
			empty_btn.set_drag_forwarding(
				_camp_bag_get_drag_empty,
				_camp_bag_can_drop,
				_camp_bag_drop.bind(i)
			)
			shopkeeper_bag.add_child(empty_btn)
			continue

		var entry = bag_items[i]
		var item_id = entry.get("item_id", "")
		var qty = entry.get("qty", 1)
		var quality_tier = int(entry.get("quality_tier", 0))
		var template = DataRegistry.get_item_template(item_id)
		var display_name: String = template.display_name if template else item_id

		_shopkeeper_items.append({
			"item_id": item_id,
			"qty": qty,
			"display_name": display_name
		})

		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(60, 32)

		# Item icon (Button.icon property)
		var has_icon = false
		if template != null:
			var icon_tex = template.get_icon_texture()
			if icon_tex != null:
				slot_btn.icon = icon_tex
				slot_btn.expand_icon = true
				has_icon = true

		# Apply quality border for equipment (only if no safe-slot override needed)
		if not is_safe:
			ItemInstance.apply_quality_border_to_button(slot_btn, quality_tier)

		# Show qty badge when icon present, otherwise abbreviated name
		if has_icon:
			slot_btn.text = str(qty) if qty > 1 else ""
		elif qty > 1:
			slot_btn.text = "%s(%d)" % [display_name.substr(0, 4), qty]
		else:
			slot_btn.text = display_name.substr(0, 6) if display_name.length() > 6 else display_name

		# Build detailed tooltip with [SAFE]/[UNSAFE] prefix
		var safe_prefix: String = "[SAFE] " if is_safe else ""
		var tooltip_lines: Array[String] = ["%s%s x%d" % [safe_prefix, display_name, qty]]
		if template != null:
			if template.description != "":
				tooltip_lines.append(template.description)

			# Quality info for equipment
			if quality_tier > 0:
				var q_name = ItemInstance.QUALITY_NAMES[clampi(quality_tier, 0, 3)]
				tooltip_lines.append("Quality: %s" % q_name)

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
					for sname in all_stats.keys():
						tooltip_lines.append("+%d %s" % [int(all_stats[sname]), sname.capitalize()])

			# Materials: show recipes
			if template.category == "materials":
				var recipes = GameContext.get_recipes_using_material(item_id)
				if recipes.size() > 0:
					tooltip_lines.append("")
					tooltip_lines.append("Used in recipes:")
					for recipe_info in recipes:
						tooltip_lines.append("  • %s" % recipe_info.recipe_name)

		slot_btn.tooltip_text = "\n".join(tooltip_lines)

		# Apply safe-slot green tinting
		if is_safe:
			var safe_style = StyleBoxFlat.new()
			safe_style.bg_color = Color(0.1, 0.25, 0.1, 0.9)
			safe_style.border_color = Color(0.3, 0.7, 0.3, 0.6)
			safe_style.set_border_width_all(1)
			safe_style.set_corner_radius_all(2)
			slot_btn.add_theme_stylebox_override("normal", safe_style)

		# Check if equippable or consumable (original click behavior)
		if template != null and template.equip_slot in ["weapon", "offhand"]:
			slot_btn.tooltip_text += "\n\nClick to equip | Shift+Click to swap"
			slot_btn.pressed.connect(_on_shopkeeper_item_pressed.bind(item_id, template.equip_slot))
		elif template != null and template.category == "consumable":
			slot_btn.tooltip_text += "\n\nClick to use | Shift+Click to swap"
			slot_btn.pressed.connect(_on_consumable_slot_pressed.bind(item_id, ""))
		else:
			# Non-equippable, non-consumable: wire up swap click directly
			slot_btn.pressed.connect(_on_bag_slot_swap_click.bind("shopkeeper", "", i, slot_btn))

		# Wire up swap via gui_input (shift+click) for equippable/consumable slots
		slot_btn.gui_input.connect(_on_shopkeeper_slot_gui_input.bind(i, slot_btn))

		# Drag-and-drop reordering
		slot_btn.set_drag_forwarding(
			_camp_bag_get_drag.bind(i, slot_btn),
			_camp_bag_can_drop,
			_camp_bag_drop.bind(i)
		)

		shopkeeper_bag.add_child(slot_btn)

	print("[Camp] Populated shopkeeper bag with %d items (safe=%d)" % [bag_items.size(), safe_count])


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


# ============================================================================
# FEATURE K: SWAP SYSTEM (Camp — Shopkeeper + Hero Bag Swaps)
# ============================================================================

## Handle shift+click on shopkeeper bag slot to start/complete swap.
func _on_shopkeeper_slot_gui_input(event: InputEvent, index: int, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed:
			_on_bag_slot_swap_click("shopkeeper", "", index, btn)
			get_viewport().set_input_as_handled()


## Handle shift+click on hero bag slot to start/complete swap.
func _on_hero_bag_slot_gui_input(event: InputEvent, hero_id: String, slot_idx: int, btn: Button) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.shift_pressed:
			_on_bag_slot_swap_click("hero_bag", hero_id, slot_idx, btn)
			get_viewport().set_input_as_handled()


## Unified swap click handler for both shopkeeper and hero bag slots.
func _on_bag_slot_swap_click(slot_type: String, hero_id: String, index: int, btn: Button) -> void:
	if _swap_source.is_empty():
		# Start swap
		_swap_source = {"type": slot_type, "hero_id": hero_id, "index": index}
		_highlight_swap_slot(btn)
	elif _swap_source.get("type") == slot_type and _swap_source.get("hero_id") == hero_id and _swap_source.get("index") == index:
		# Cancel: clicked same slot
		_clear_swap_highlight()
	else:
		# Perform swap
		var src = _swap_source
		_clear_swap_highlight()
		_perform_swap(src, {"type": slot_type, "hero_id": hero_id, "index": index})


## Execute the actual swap between two bag slots.
func _perform_swap(src: Dictionary, dst: Dictionary) -> void:
	if src.type == "shopkeeper" and dst.type == "shopkeeper":
		# Skip no-op when target is an empty trailing slot (compact array)
		if dst.index < GameContext.shopkeeper_bag.size():
			GameContext.swap_shopkeeper_bag_items(src.index, dst.index)
			print("[Camp] Swapped shopkeeper bag slots %d <-> %d" % [src.index, dst.index])
	elif src.type == "hero_bag" and dst.type == "shopkeeper":
		GameContext.move_item_hero_to_shopkeeper(src.hero_id, src.index)
		print("[Camp] Moved hero %s bag[%d] -> shopkeeper" % [src.hero_id, src.index])
	elif src.type == "shopkeeper" and dst.type == "hero_bag":
		GameContext.move_item_shopkeeper_to_hero(src.index, dst.hero_id)
		print("[Camp] Moved shopkeeper[%d] -> hero %s" % [src.index, dst.hero_id])
	elif src.type == "hero_bag" and dst.type == "hero_bag":
		if src.hero_id == dst.hero_id:
			# Same hero bag swap (both must be filled)
			var bag: Array = GameContext.hero_bags.get(src.hero_id, [])
			if src.index < bag.size() and dst.index < bag.size():
				var temp: Dictionary = bag[src.index]
				bag[src.index] = bag[dst.index]
				bag[dst.index] = temp
				print("[Camp] Swapped hero %s bag[%d] <-> bag[%d]" % [src.hero_id, src.index, dst.index])
		else:
			# Cross-hero bag transfer — ensure dict entries exist so we get real references
			if not GameContext.hero_bags.has(src.hero_id):
				GameContext.hero_bags[src.hero_id] = []
			if not GameContext.hero_bags.has(dst.hero_id):
				GameContext.hero_bags[dst.hero_id] = []
			var src_bag: Array = GameContext.hero_bags[src.hero_id]
			var dst_bag: Array = GameContext.hero_bags[dst.hero_id]
			if src.index < src_bag.size():
				if dst.index < dst_bag.size():
					# Both filled: swap items between heroes
					var temp: Dictionary = src_bag[src.index]
					src_bag[src.index] = dst_bag[dst.index]
					dst_bag[dst.index] = temp
					print("[Camp] Swapped hero %s bag[%d] <-> hero %s bag[%d]" % [src.hero_id, src.index, dst.hero_id, dst.index])
				else:
					# Dst is empty slot: move src item to dst hero
					var dst_cap: int = GameContext.get_hero_bag_capacity(dst.hero_id)
					if dst_bag.size() < dst_cap:
						dst_bag.append(src_bag[src.index].duplicate())
						src_bag.remove_at(src.index)
						print("[Camp] Moved hero %s bag[%d] -> hero %s" % [src.hero_id, src.index, dst.hero_id])
	_update_display()


## Highlight a slot button as selected for swap.
func _highlight_swap_slot(btn: Button) -> void:
	if _swap_highlight_btn != null and is_instance_valid(_swap_highlight_btn):
		_clear_swap_highlight()
	_swap_highlight_btn = btn
	var highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.3, 0.3, 0.1, 0.8)
	highlight_style.border_color = Color(1.0, 0.85, 0.0, 0.9)
	highlight_style.set_border_width_all(2)
	highlight_style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", highlight_style)


## Clear swap selection and remove highlight.
func _clear_swap_highlight() -> void:
	_swap_source = {}
	if _swap_highlight_btn != null and is_instance_valid(_swap_highlight_btn):
		_swap_highlight_btn.remove_theme_stylebox_override("normal")
	_swap_highlight_btn = null


# --- Drag-and-drop handlers for camp shopkeeper bag reordering ---

## Creates drag data + preview for a filled bag slot.
func _camp_bag_get_drag(at_pos: Vector2, index: int, origin_btn: Button) -> Variant:
	var bag: Array = GameContext.get_shopkeeper_bag()
	if index >= bag.size():
		return null
	var entry: Dictionary = bag[index]
	var item_id: String = entry.get("item_id", "")
	var template = DataRegistry.get_item_template(item_id)
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if template:
		var tex = template.get_icon_texture()
		if tex:
			preview.texture = tex
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return {"type": "shopkeeper", "index": index}


## Empty slots return null — they cannot initiate a drag.
func _camp_bag_get_drag_empty(at_pos: Vector2) -> Variant:
	return null


## Accept drops from shopkeeper or hero bag slots.
func _camp_bag_can_drop(at_pos: Vector2, data) -> bool:
	if data is Dictionary and data.get("type") in ["shopkeeper", "hero_bag"]:
		return true
	return false


## Perform the swap when an item is dropped onto a shopkeeper bag slot.
func _camp_bag_drop(at_pos: Vector2, data, target_index: int) -> void:
	if not (data is Dictionary):
		return
	var src_type: String = data.get("type", "")
	if src_type == "shopkeeper":
		var src_index: int = int(data.get("index", -1))
		if src_index < 0 or src_index == target_index:
			return
		_perform_swap(
			{"type": "shopkeeper", "hero_id": "", "index": src_index},
			{"type": "shopkeeper", "hero_id": "", "index": target_index}
		)
	elif src_type == "hero_bag":
		var src_hero: String = data.get("hero_id", "")
		var src_index: int = int(data.get("index", -1))
		if src_hero == "" or src_index < 0:
			return
		_perform_swap(
			{"type": "hero_bag", "hero_id": src_hero, "index": src_index},
			{"type": "shopkeeper", "hero_id": "", "index": target_index}
		)


# --- Drag-and-drop handlers for hero bag slots ---

## Creates drag data + preview for a filled hero bag slot.
func _hero_bag_get_drag(at_pos: Vector2, hero_id: String, index: int, origin_btn: Button) -> Variant:
	var bag: Array = GameContext.get_hero_bag(hero_id)
	if index >= bag.size():
		return null
	var entry: Dictionary = bag[index]
	var item_id: String = entry.get("item_id", "")
	var template = DataRegistry.get_item_template(item_id)
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if template:
		var tex = template.get_icon_texture()
		if tex:
			preview.texture = tex
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return {"type": "hero_bag", "hero_id": hero_id, "index": index}


## Empty hero bag slots return null — they cannot initiate a drag.
func _hero_bag_get_drag_empty(at_pos: Vector2) -> Variant:
	return null


## Accept drops from shopkeeper or hero bag slots onto hero bag.
func _hero_bag_can_drop(at_pos: Vector2, data) -> bool:
	if data is Dictionary and data.get("type") in ["shopkeeper", "hero_bag"]:
		return true
	return false


## Perform the swap when an item is dropped onto a hero bag slot.
func _hero_bag_drop(at_pos: Vector2, data, target_hero_id: String, target_index: int) -> void:
	if not (data is Dictionary):
		return
	var src_type: String = data.get("type", "")
	if src_type == "shopkeeper":
		var src_index: int = int(data.get("index", -1))
		if src_index < 0:
			return
		_perform_swap(
			{"type": "shopkeeper", "hero_id": "", "index": src_index},
			{"type": "hero_bag", "hero_id": target_hero_id, "index": target_index}
		)
	elif src_type == "hero_bag":
		var src_hero: String = data.get("hero_id", "")
		var src_index: int = int(data.get("index", -1))
		if src_hero == "" or src_index < 0:
			return
		if src_hero == target_hero_id and src_index == target_index:
			return
		_perform_swap(
			{"type": "hero_bag", "hero_id": src_hero, "index": src_index},
			{"type": "hero_bag", "hero_id": target_hero_id, "index": target_index}
		)
