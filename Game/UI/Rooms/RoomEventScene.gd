## RoomEventScene.gd
## Non-combat room handler for choice-based events.
## Loads event from DataRegistry, displays choices, applies weighted outcome effects.
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

# Combat trigger state (from trigger_combat effect)
var _trigger_combat_after: bool = false
var _trigger_combat_type: String = ""  # "basic" or "elite"

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Connect buttons
	for i in range(choice_buttons.size()):
		choice_buttons[i].pressed.connect(_on_choice_pressed.bind(i))
	return_button.pressed.connect(_on_return_pressed)

	# SFX: Event room entered
	UIAudio.play_sfx("event_trigger")

	# Load and display event
	_load_and_display_event()

	# Tutorial on first event room (non-blocking overlay)
	TutorialOverlay.try_show(self, "tutorial_first_event")


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
# CHOICE HANDLING (v2 — weighted outcomes)
# ============================================================================

func _on_choice_pressed(choice_index: int) -> void:
	if _choice_made:
		return
	if _current_event == null:
		return
	if choice_index >= _current_event.choices.size():
		return

	_choice_made = true
	UIAudio.play_sfx("event_choice")
	var choice = _current_event.choices[choice_index]
	print("[RoomEvent] Player chose: %s" % choice.get("label", "?"))

	# Disable all choice buttons
	for btn in choice_buttons:
		btn.disabled = true

	# Roll weighted outcome
	var outcome: Dictionary = EventData.roll_outcome(choice, _event_rng)
	print("[RoomEvent] Rolled outcome (weight=%.0f)" % outcome.get("weight", 0))

	# Display outcome narrative text
	var outcome_narrative: String = outcome.get("text", "")
	if outcome_narrative != "":
		_outcome_text += outcome_narrative + "\n\n"

	# Legacy v1 support: handle risk/modifier if present in outcome
	var legacy_risk = outcome.get("_legacy_risk", {})
	if not legacy_risk.is_empty():
		_check_and_apply_risk(legacy_risk)
	var legacy_modifier = outcome.get("_legacy_modifier", {})
	if not legacy_modifier.is_empty():
		GameContext.set_pending_combat_modifier(legacy_modifier)
		var mod_label = legacy_modifier.get("label", legacy_modifier.get("id", "unknown"))
		_outcome_text += "[Next Combat: %s]\n" % mod_label

	# Apply effects from the rolled outcome
	var effects: Array = outcome.get("effects", [])
	_apply_effects(effects)

	# Build outcome display
	_build_outcome_text(effects)

	# Show return button
	choices_header.visible = false
	return_button.visible = true
	if _trigger_combat_after:
		return_button.text = "Prepare for Battle!"
		hotkey_hint.text = "Press R or Enter to fight"
	else:
		return_button.text = "Return to Camp"
		hotkey_hint.text = "Press R or Enter to continue"


## Legacy risk handling (for v1 events not yet migrated to outcomes).
func _check_and_apply_risk(risk: Dictionary) -> bool:
	if risk.is_empty():
		return false

	var trap_chance = risk.get("trap_chance", 0.0)
	var damage_chance = risk.get("damage_chance", 0.0)
	var fight_chance = risk.get("fight_chance", 0.0)
	var ambush_chance = risk.get("ambush_chance", 0.0)
	var catch_chance = risk.get("catch_chance", 0.0)
	var chance = maxf(trap_chance, maxf(damage_chance, maxf(fight_chance, maxf(ambush_chance, catch_chance))))

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


# ============================================================================
# EFFECT APPLICATION (v2 — all effect types)
# ============================================================================

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
					var dname: String = template.display_name if template != null else item_id
					_outcome_text += "+%d %s\n" % [qty, dname]

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
				var heal_amt = effect.get("value", effect.get("amount", 0))
				if heal_amt > 0:
					_apply_party_heal(heal_amt)
					_outcome_text += "Party healed for %d HP\n" % heal_amt

			"heal_hero":
				var heal_amt = effect.get("amount", 0)
				if heal_amt > 0:
					_apply_hero_heal(heal_amt)

			"damage_party":
				var dmg_amt = effect.get("value", effect.get("amount", 0))
				if dmg_amt > 0:
					_apply_party_damage(dmg_amt)
					_outcome_text += "Party took %d damage!\n" % dmg_amt

			"damage_hero":
				var dmg_amt = effect.get("amount", 0)
				if dmg_amt > 0:
					_apply_hero_damage(dmg_amt)

			"apply_status":
				var status_id = effect.get("status_id", "")
				var duration = effect.get("duration", 2)
				var target = effect.get("target", "random_hero")
				if status_id != "":
					GameContext.add_pending_combat_status(status_id, duration, target)
					var status_name: String = status_id.capitalize()
					var status_data = DataRegistry.get_status_effect(status_id) if DataRegistry.has_method("get_status_effect") else null
					if status_data != null and status_data.display_name != "":
						status_name = status_data.display_name
					var scope: String = "party" if target == "party" else "a hero"
					_outcome_text += "[Next Combat: %s on %s (%d turns)]\n" % [status_name, scope, duration]

			"remove_equipment":
				_apply_equipment_removal()

			"trigger_combat":
				var encounter_type = effect.get("encounter_type", "basic")
				_trigger_combat_after = true
				_trigger_combat_type = encounter_type
				var combat_label: String = "Elite Combat" if encounter_type == "elite" else "Combat"
				_outcome_text += "[%s Incoming!]\n" % combat_label

			"modifier":
				var modifier = effect.duplicate()
				modifier.erase("type")
				if not modifier.is_empty():
					GameContext.set_pending_combat_modifier(modifier)
					var mod_label = modifier.get("label", modifier.get("id", "unknown"))
					_outcome_text += "[Next Combat: %s]\n" % mod_label

			"nothing":
				pass  # Outcome text handles flavor via the outcome's "text" field


# ============================================================================
# DAMAGE / HEAL HELPERS
# ============================================================================

## Distribute damage evenly across all living party heroes.
func _apply_party_damage(total_damage: int) -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		print("[RoomEvent] TRAP damage=%d but party is empty" % total_damage)
		return
	var per_hero: int = maxi(1, total_damage / party.size())
	for hero_id in party:
		var stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
		var max_hp: int = int(stats.get("health", 100))
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		var current_hp: int = int(hp_data.get("current", max_hp)) if not hp_data.is_empty() else max_hp
		var new_hp: int = maxi(1, current_hp - per_hero)  # Don't kill from events (min 1 HP)
		GameContext.set_hero_hp(hero_id, new_hp, max_hp)
		print("[RoomEvent] DMG hero=%s hp=%d->%d (-%d)" % [hero_id, current_hp, new_hp, current_hp - new_hp])


## Heal all living party heroes by a flat amount (clamped to max).
func _apply_party_heal(amount: int) -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		return
	for hero_id in party:
		var stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
		var max_hp: int = int(stats.get("health", 100))
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		var current_hp: int = int(hp_data.get("current", max_hp)) if not hp_data.is_empty() else max_hp
		var new_hp: int = mini(current_hp + amount, max_hp)
		GameContext.set_hero_hp(hero_id, new_hp, max_hp)
		print("[RoomEvent] HEAL hero=%s hp=%d->%d (+%d)" % [hero_id, current_hp, new_hp, new_hp - current_hp])


## Damage a single random party hero.
func _apply_hero_damage(amount: int) -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		return
	var hero_id: String = party[_event_rng.randi() % party.size()]
	var stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
	var max_hp: int = int(stats.get("health", 100))
	var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
	var current_hp: int = int(hp_data.get("current", max_hp)) if not hp_data.is_empty() else max_hp
	var new_hp: int = maxi(1, current_hp - amount)
	GameContext.set_hero_hp(hero_id, new_hp, max_hp)
	var hero = GameContext.get_hero(hero_id)
	var hero_name: String = hero.get("name", hero_id) if not hero.is_empty() else hero_id
	_outcome_text += "%s took %d damage!\n" % [hero_name, current_hp - new_hp]
	print("[RoomEvent] DMG hero=%s hp=%d->%d (-%d)" % [hero_id, current_hp, new_hp, current_hp - new_hp])


## Heal a single random party hero.
func _apply_hero_heal(amount: int) -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		return
	var hero_id: String = party[_event_rng.randi() % party.size()]
	var stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
	var max_hp: int = int(stats.get("health", 100))
	var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
	var current_hp: int = int(hp_data.get("current", max_hp)) if not hp_data.is_empty() else max_hp
	var new_hp: int = mini(current_hp + amount, max_hp)
	GameContext.set_hero_hp(hero_id, new_hp, max_hp)
	var hero = GameContext.get_hero(hero_id)
	var hero_name: String = hero.get("name", hero_id) if not hero.is_empty() else hero_id
	_outcome_text += "%s healed for %d HP\n" % [hero_name, new_hp - current_hp]
	print("[RoomEvent] HEAL hero=%s hp=%d->%d (+%d)" % [hero_id, current_hp, new_hp, new_hp - current_hp])


## Remove a random piece of equipment from a random hero → stash.
func _apply_equipment_removal() -> void:
	var party: Array[String] = GameContext.get_party()
	if party.is_empty():
		_outcome_text += "No equipment to lose.\n"
		return
	# Find heroes with at least one equipped item (excluding bag)
	var equipped_heroes: Array = []
	for hero_id in party:
		var equip: Dictionary = GameContext.get_hero_equipment(hero_id)
		for slot in GameContext.EQUIPMENT_SLOTS:
			var slot_data = equip.get(slot, {})
			if slot_data.get("id", "") != "":
				equipped_heroes.append(hero_id)
				break
	if equipped_heroes.is_empty():
		_outcome_text += "No equipment to lose.\n"
		return
	# Pick random hero with gear
	var hero_id: String = equipped_heroes[_event_rng.randi() % equipped_heroes.size()]
	var equip: Dictionary = GameContext.get_hero_equipment(hero_id)
	# Find filled slots
	var filled_slots: Array = []
	for slot in GameContext.EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		if slot_data.get("id", "") != "":
			filled_slots.append(slot)
	if filled_slots.is_empty():
		return
	var slot: String = filled_slots[_event_rng.randi() % filled_slots.size()]
	var item_id: String = equip[slot].get("id", "")
	var template = DataRegistry.get_item_template(item_id)
	var item_name: String = template.display_name if template != null else item_id
	var hero = GameContext.get_hero(hero_id)
	var hero_name: String = hero.get("name", hero_id) if not hero.is_empty() else hero_id
	GameContext.unequip_hero_item(hero_id, slot)
	_outcome_text += "%s lost their %s! (sent to storage)\n" % [hero_name, item_name]
	print("[RoomEvent] UNEQUIP hero=%s slot=%s item=%s -> stash" % [hero_id, slot, item_id])


# ============================================================================
# OUTCOME DISPLAY
# ============================================================================

func _build_outcome_text(effects: Array) -> void:
	if _outcome_text == "":
		_outcome_text = "Nothing of note happened.\n"

	outcome_label.text = _outcome_text.strip_edges()

	# Determine tone from effects for coloring and SFX
	var has_negative: bool = false
	var has_positive: bool = false
	for effect in effects:
		var etype: String = effect.get("type", "")
		if etype in ["damage_party", "damage_hero", "apply_status", "remove_equipment", "trigger_combat", "lose_gold", "lose_item"]:
			has_negative = true
		if etype in ["add_gold", "add_gold_range", "add_item", "heal_party", "heal_hero"]:
			has_positive = true

	if has_negative and not has_positive:
		outcome_label.modulate = Color(1, 0.5, 0.5, 1)  # Red for bad
		UIAudio.play_sfx("event_outcome_bad")
	elif has_negative and has_positive:
		outcome_label.modulate = Color(1, 0.7, 0.5, 1)  # Orange for mixed
		UIAudio.play_sfx("event_outcome_bad")
	elif has_positive:
		outcome_label.modulate = Color(0.7, 1, 0.7, 1)  # Green for rewards
		UIAudio.play_sfx("event_outcome_good")
	else:
		outcome_label.modulate = Color(0.7, 0.8, 0.9, 1)  # Blue-ish neutral
		UIAudio.play_sfx("event_outcome_neutral")


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

	if _trigger_combat_after:
		# Route to combat instead of camp
		print("[RoomEvent] Triggering %s combat from event" % _trigger_combat_type)
		if _trigger_combat_type == "elite":
			GameContext.current_room_is_elite = true
		else:
			GameContext.current_room_is_elite = false
		GameContext.current_room_type = "combat"
		GameContext.set_phase(GameContext.GamePhase.COMBAT)
	else:
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
