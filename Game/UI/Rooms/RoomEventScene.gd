## RoomEventScene.gd
## Non-combat room handler for choice-based events.
## Loads event from DataRegistry, displays choices, applies effects to dungeon stash.
extends Control

const BOOT_SCENE_PATH = "res://Game/Boot/game_boot.tscn"

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var title_label: Label = $MainVBox/TitleLabel
@onready var description_label: Label = $MainVBox/DescriptionLabel
@onready var choices_header: Label = $MainVBox/ChoicesHeader
@onready var choices_container: VBoxContainer = $MainVBox/ChoicesContainer
@onready var choice_buttons: Array[Button] = [
	$MainVBox/ChoicesContainer/Choice1Button,
	$MainVBox/ChoicesContainer/Choice2Button,
	$MainVBox/ChoicesContainer/Choice3Button,
	$MainVBox/ChoicesContainer/Choice4Button
]
@onready var outcome_label: Label = $MainVBox/OutcomeLabel
@onready var return_button: Button = $MainVBox/ReturnButton
@onready var hotkey_hint: Label = $MainVBox/HotkeyHint

# Event state
var _current_event: EventData = null
var _event_rng: RandomNumberGenerator = null
var _choice_made: bool = false
var _outcome_text: String = ""

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect buttons
	for i in range(choice_buttons.size()):
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
	return_button.pressed.connect(_on_return_pressed)

	# Load and display event
	_load_and_display_event()

	var payload = GameContext.current_room_payload
	print("[RoomEvent] type=%s dungeon=%s floor=%d room=%d" % [
		payload.get("type", "unknown"),
		payload.get("dungeon_id", "unknown"),
		payload.get("floor", 0),
		payload.get("room", 0)
	])


# ============================================================================
# EVENT LOADING
# ============================================================================

func _load_and_display_event() -> void:
	var payload = GameContext.current_room_payload
	var dungeon_id = payload.get("dungeon_id", "")
	var floor_num = payload.get("floor", 1)
	var room_num = payload.get("room", 1)

	# Get deterministic RNG for this event
	_event_rng = _get_event_rng(dungeon_id, floor_num, room_num)

	# Get event table from dungeon
	var event_table = _get_event_table_for_dungeon(dungeon_id)

	if event_table == null:
		_display_placeholder_event(floor_num)
		return

	# Roll event_id from table
	var event_id = event_table.roll_event_id(_event_rng)

	if event_id == "":
		_display_placeholder_event(floor_num)
		return

	# Load full event data
	_current_event = DataRegistry.get_event(event_id)

	if _current_event == null:
		print("[RoomEvent] WARNING: Event '%s' not found in DataRegistry" % event_id)
		_display_placeholder_event(floor_num)
		return

	print("[RoomEvent] Rolled event: %s (%s)" % [event_id, _current_event.title])
	_display_event()


func _get_event_table_for_dungeon(dungeon_id: String):
	if dungeon_id == "":
		return null

	var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	if dungeon == null:
		return null

	var event_table_id = dungeon.event_table_id if dungeon.event_table_id != "" else ""
	if event_table_id == "":
		return null

	return DataRegistry.get_event_table(event_table_id)


func _get_event_rng(dungeon_id: String, floor_num: int, room_num: int) -> RandomNumberGenerator:
	var base_seed = GameContext.get_run_seed()
	var key = "event:%s:%d:%d" % [dungeon_id, floor_num, room_num]
	var derived_seed = SeededRNG.derive_seed(key, base_seed)
	return SeededRNG.create_rng(derived_seed)


# ============================================================================
# DISPLAY
# ============================================================================

func _display_event() -> void:
	title_label.text = "-- %s --" % _current_event.title
	description_label.text = _current_event.description

	# Setup choice buttons
	var choices = _current_event.choices
	for i in range(choice_buttons.size()):
		if i < choices.size():
			var choice = choices[i]
			var label = choice.get("label", "Choice %d" % (i + 1))
			var desc = choice.get("description", "")
			if desc != "":
				choice_buttons[i].text = "%d: %s - %s" % [i + 1, label, desc]
			else:
				choice_buttons[i].text = "%d: %s" % [i + 1, label]
			choice_buttons[i].visible = true
			choice_buttons[i].disabled = false

			# Check requirements (if any)
			var requires = choice.get("requires", {})
			if not _check_requirements(requires):
				choice_buttons[i].disabled = true
				choice_buttons[i].modulate = Color(0.5, 0.5, 0.5, 1)
		else:
			choice_buttons[i].visible = false

	# Update UI state
	choices_header.visible = true
	outcome_label.text = ""
	return_button.visible = false
	hotkey_hint.text = "Press 1-%d to choose" % mini(choices.size(), 4)


func _display_placeholder_event(floor_num: int) -> void:
	title_label.text = "-- Mysterious Event --"
	description_label.text = "You encounter something unusual in the dungeon depths, but nothing eventful occurs.\n\n(Event tables not configured for this dungeon)"

	# Hide all choice buttons, show return button directly
	for btn in choice_buttons:
		btn.visible = false
	choices_header.visible = false

	# Give consolation gold
	var consolation_gold = floor_num * 5
	GameContext.add_dungeon_gold(consolation_gold)
	outcome_label.text = "You found %d gold while exploring." % consolation_gold

	_choice_made = true
	return_button.visible = true
	hotkey_hint.text = "Press R or Enter to continue"


# ============================================================================
# REQUIREMENTS CHECKING
# ============================================================================

func _check_requirements(requires: Dictionary) -> bool:
	if requires.is_empty():
		return true

	# Check gold requirement
	var gold_req = requires.get("gold", 0)
	if gold_req > 0 and not GameContext.has_dungeon_gold(gold_req):
		return false

	# Check item requirement by id
	var item_id = requires.get("item_id", "")
	var item_qty = requires.get("item_qty", 1)
	if item_id != "" and not GameContext.has_dungeon_item(item_id, item_qty):
		return false

	# Check item requirement by tag
	var item_tag = requires.get("item_tag", "")
	if item_tag != "" and not GameContext.has_dungeon_item_by_tag(item_tag, item_qty):
		return false

	return true


# ============================================================================
# CHOICE HANDLING
# ============================================================================

func _on_choice_pressed(choice_index: int) -> void:
	if _choice_made:
		return
	if _current_event == null:
		return
	if choice_index >= _current_event.choices.size():
		return

	_choice_made = true
	var choice = _current_event.choices[choice_index]
	print("[RoomEvent] Player chose: %s" % choice.get("label", "?"))

	# Disable all choice buttons
	for btn in choice_buttons:
		btn.disabled = true

	# Handle risk/trap first
	var risk = choice.get("risk", {})
	var trap_triggered = _check_and_apply_risk(risk)

	# Apply effects (even if trap triggered, effects still apply)
	var effects = choice.get("effects", [])
	_apply_effects(effects)

	# Check for combat modifier (Part C - Event-Driven Next-Combat Modifiers)
	var modifier = choice.get("modifier", {})
	if not modifier.is_empty():
		GameContext.set_pending_combat_modifier(modifier)
		var mod_label = modifier.get("label", modifier.get("id", "unknown"))
		_outcome_text += "[Next Combat: %s]\n" % mod_label
		print("[RoomEvent][Modifier] Set pending modifier: %s" % modifier.get("id", "unknown"))

	# Build outcome text
	_build_outcome_text(choice, trap_triggered)

	# Show return button
	choices_header.visible = false
	return_button.visible = true
	hotkey_hint.text = "Press R or Enter to continue"


func _check_and_apply_risk(risk: Dictionary) -> bool:
	if risk.is_empty():
		return false

	var trap_chance = risk.get("trap_chance", 0.0)
	var damage_chance = risk.get("damage_chance", 0.0)
	var chance = maxf(trap_chance, damage_chance)

	if chance <= 0.0:
		return false

	var roll = _event_rng.randf()
	if roll >= chance:
		return false

	# Trap/risk triggered — distribute damage across party
	var damage_amount = risk.get("damage_amount", 0)
	if damage_amount > 0:
		_apply_party_damage(damage_amount)
		_outcome_text += "But you triggered a trap! (-%d HP)\n" % damage_amount

	var gold_loss = risk.get("gold_loss", 0)
	if gold_loss > 0:
		var lost = GameContext.remove_dungeon_gold(gold_loss)
		if lost > 0:
			_outcome_text += "You lost %d gold!\n" % lost

	return true


func _apply_effects(effects: Array) -> void:
	for effect in effects:
		if effect is not Dictionary:
			continue

		var effect_type = effect.get("type", "")
		match effect_type:
			"add_gold":
				var amount = effect.get("amount", 0)
				if amount > 0:
					GameContext.add_dungeon_gold(amount)
					_outcome_text += "+%d gold\n" % amount

			"add_gold_range":
				var min_gold = effect.get("min", 0)
				var max_gold = effect.get("max", 0)
				var amount = _event_rng.randi_range(min_gold, max_gold)
				if amount > 0:
					GameContext.add_dungeon_gold(amount)
					_outcome_text += "+%d gold\n" % amount

			"add_item":
				var item_id = effect.get("item_id", "")
				var min_qty = effect.get("min_qty", 1)
				var max_qty = effect.get("max_qty", 1)
				var qty = _event_rng.randi_range(min_qty, max_qty)
				if item_id != "" and qty > 0:
					GameContext.add_dungeon_item(item_id, qty)
					var template = DataRegistry.get_item_template(item_id)
					var name = template.display_name if template != null else item_id
					_outcome_text += "+%d %s\n" % [qty, name]

			"lose_gold":
				var min_loss = effect.get("min", 0)
				var max_loss = effect.get("max", 0)
				var amount = _event_rng.randi_range(min_loss, max_loss)
				if amount > 0:
					var lost = GameContext.remove_dungeon_gold(amount)
					if lost > 0:
						_outcome_text += "-%d gold\n" % lost

			"lose_item":
				var item_id = effect.get("item_id", "")
				var qty = effect.get("qty", 1)
				if item_id != "":
					var removed = GameContext.remove_dungeon_item_by_id(item_id, qty)
					if removed > 0:
						_outcome_text += "Lost %d %s\n" % [removed, item_id]

			"heal_party":
				var amount = effect.get("amount", 0)
				if amount > 0:
					_apply_party_heal(amount)
					_outcome_text += "Party healed for %d HP\n" % amount

			"nothing":
				_outcome_text += "Nothing happens.\n"


## Distribute damage evenly across all living party heroes.
func _apply_party_damage(total_damage: int) -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		print("[RoomEvent] TRAP damage=%d but party is empty" % total_damage)
		return
	var per_hero: int = maxi(1, total_damage / party.size())
	for hero_id in party:
		var stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
		var max_hp: int = int(stats.get("hp", 100))
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		var current_hp: int = int(hp_data.get("current", max_hp)) if not hp_data.is_empty() else max_hp
		var new_hp: int = maxi(1, current_hp - per_hero)  # Don't kill from traps (min 1 HP)
		GameContext.set_hero_hp(hero_id, new_hp, max_hp)
		print("[RoomEvent] TRAP hero=%s hp=%d→%d (-%d)" % [hero_id, current_hp, new_hp, current_hp - new_hp])


## Heal all living party heroes by a flat amount (clamped to max).
func _apply_party_heal(amount: int) -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		return
	for hero_id in party:
		var stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
		var max_hp: int = int(stats.get("hp", 100))
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		var current_hp: int = int(hp_data.get("current", max_hp)) if not hp_data.is_empty() else max_hp
		var new_hp: int = mini(current_hp + amount, max_hp)
		GameContext.set_hero_hp(hero_id, new_hp, max_hp)
		print("[RoomEvent] HEAL hero=%s hp=%d→%d (+%d)" % [hero_id, current_hp, new_hp, new_hp - current_hp])


func _build_outcome_text(choice: Dictionary, trap_triggered: bool) -> void:
	if _outcome_text == "":
		_outcome_text = "You chose: %s\n" % choice.get("label", "?")

	outcome_label.text = _outcome_text.strip_edges()

	# Color based on outcome
	if trap_triggered:
		outcome_label.modulate = Color(1, 0.7, 0.5, 1)  # Orange for trap
	elif _outcome_text.find("+") >= 0:
		outcome_label.modulate = Color(0.7, 1, 0.7, 1)  # Green for rewards
	else:
		outcome_label.modulate = Color(0.7, 0.8, 0.9, 1)  # Blue-ish neutral


# ============================================================================
# RETURN HANDLING
# ============================================================================

func _on_return_pressed() -> void:
	_return_to_camp()


func _return_to_camp() -> void:
	if not _choice_made:
		return

	# Award event completion XP
	GameContext.grant_party_xp(20, "event")

	print("[RoomEvent] Returning to camp")
	GameContext.set_phase(GameContext.GamePhase.DUNGEON_CAMP)
	get_tree().change_scene_to_file(BOOT_SCENE_PATH)


# ============================================================================
# HOTKEYS
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if not _choice_made:
			# Choice hotkeys
			match event.keycode:
				KEY_1:
					if choice_buttons[0].visible and not choice_buttons[0].disabled:
						_on_choice_pressed(0)
				KEY_2:
					if choice_buttons[1].visible and not choice_buttons[1].disabled:
						_on_choice_pressed(1)
				KEY_3:
					if choice_buttons[2].visible and not choice_buttons[2].disabled:
						_on_choice_pressed(2)
				KEY_4:
					if choice_buttons[3].visible and not choice_buttons[3].disabled:
						_on_choice_pressed(3)
		else:
			# Return hotkeys
			match event.keycode:
				KEY_R, KEY_ENTER, KEY_SPACE:
					_return_to_camp()
