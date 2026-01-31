## CombatController.gd
## Main combat engine controller.
## Manages turn-based combat loop, unit actions, and combat resolution.
##
## Source: MVP_Milestones.md (M1), GDD Section 23
## Updated: M2.1 Hardening Pass - Clean API for UI
## Updated: M3 Grid Implementation - 4x2 formation, position-based targeting
## Updated: M4 Class Kit Integration - passive behaviors, active abilities
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal combat_started(player_units: Array, enemy_units: Array)
signal turn_started(unit: CombatUnit)
signal action_performed(action: CombatAction)
signal turn_ended(unit: CombatUnit)
signal round_ended(round_number: int)
signal combat_ended(result: CombatResult)
signal passive_triggered(unit: CombatUnit, passive_id: String, effect_desc: String)
signal status_changed(unit_id: String)  # Status UI v1.6: Emitted when status applied/stacked/expired
signal all_statuses_ticked()  # Status UI v1.6: Emitted after round-start status tick
signal intent_decided(actor_id: String, action_type: String, ability_id: String, target_id: String)  # v1.9B: Intent surface

# ============================================================================
# HERO CLASS MAPPING (Legacy fallback for hardcoded hero_ids)
# ============================================================================

const LEGACY_HERO_CLASS_MAP = {
	"hero_1": "defender",
	"hero_2": "striker",
	"hero_3": "defender",
}

# ============================================================================
# STATE
# ============================================================================

var _player_units: Array = []
var _enemy_units: Array = []
var _all_units: Array = []
var _turn_queue: TurnQueue = null
var _rng: RandomNumberGenerator = null
var _result: CombatResult = null
var _targeting_policy: TargetingPolicy = null

var _is_combat_active: bool = false
var _current_round: int = 0
var _current_turn: int = 0
var _pending_actions: Array = []  # Actions from last step

# Encounter snapshot (frozen at combat start, used for rewards)
var _encounter_dungeon_id: String = ""
var _encounter_floor: int = 0
var _encounter_floor_count: int = 4
var _encounter_is_boss: bool = false
var _encounter_boss_id: String = ""

# Configuration
const MAX_ROUNDS = 100  # Safety limit

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[CombatController] Ready.")


## Initialize combat without running the loop (for step-based UI).
## Optional modifier dict can contain: player_spd_bonus, enemy_spd_bonus, player_start_damage, bonus_gold
func initialize_combat(hero_ids: Array, enemy_ids: Array, rng: RandomNumberGenerator = null, modifier: Dictionary = {}) -> void:
	print("\n" + "=".repeat(50))
	print("        COMBAT INITIALIZED")
	print("=".repeat(50) + "\n")

	_is_combat_active = true
	_current_round = 1
	_current_turn = 0
	_pending_actions.clear()

	# Set up RNG
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()

	# Set up targeting policy (M3: use grid-based targeting)
	_targeting_policy = TargetingPolicy.new(TargetingPolicy.TargetMode.GRID_DEFAULT, _rng)

	# Create units
	_create_units(hero_ids, enemy_ids)

	# Assign grid positions (M3)
	FormationAssigner.assign_default_formation(_player_units, _enemy_units)
	print("[CombatController] Formation assigned (4x2 grid)")

	# Apply passive stat bonuses (M4)
	_apply_all_passives()

	# Apply race passives (v1)
	_apply_race_passives()

	# Apply equipment stat bonuses from equipped items
	_apply_equipment_bonuses()

	# Apply combat modifier speed bonuses BEFORE TurnQueue is built
	_apply_combat_modifier_speeds(modifier)

	# Initialize result tracking
	_result = CombatResult.new()

	# Initialize turn queue (uses unit.speed for ordering)
	_turn_queue = TurnQueue.new()
	_turn_queue.initialize(_all_units)

	# Apply combat modifier damage/gold AFTER units are set up
	_apply_combat_modifier_effects(modifier)

	combat_started.emit(_player_units, _enemy_units)


## Set encounter context snapshot (call after initialize_combat, before combat runs).
## These values are frozen and used for reward calculation regardless of GameContext changes.
func set_encounter_context(dungeon_id: String, floor_num: int, floor_count: int, is_boss: bool, boss_id: String) -> void:
	_encounter_dungeon_id = dungeon_id
	_encounter_floor = floor_num
	_encounter_floor_count = floor_count
	_encounter_is_boss = is_boss
	_encounter_boss_id = boss_id


## Start a combat encounter (runs to completion).
func start_combat(hero_ids: Array, enemy_ids: Array, rng: RandomNumberGenerator = null) -> CombatResult:
	initialize_combat(hero_ids, enemy_ids, rng)

	# Run combat loop
	_run_combat_loop()

	# Finalize result
	_result.set_outcome_from_combat(_player_units, _enemy_units)
	_result.set_rng(_rng)
	_result.is_boss_encounter = _encounter_is_boss
	_result.calculate_rewards(_enemy_units)

	# Health Persistence v1: Save surviving heroes' HP
	_persist_hero_hp()

	_is_combat_active = false
	combat_ended.emit(_result)

	return _result


## Create combat units from IDs.
func _create_units(hero_ids: Array, enemy_ids: Array) -> void:
	_player_units.clear()
	_enemy_units.clear()
	_all_units.clear()

	# Consumables v1: Reset consumable usage tracking at combat start
	if GameContext.has_method("reset_combat_consumables"):
		GameContext.reset_combat_consumables()

	# Create hero units with effective stats (level-scaled + race modifiers)
	print("\n[HeroStats] === Combat Spawning ===")
	for i in range(hero_ids.size()):
		var hero_id = hero_ids[i]
		var class_id = "defender"  # Default fallback
		var effective_stats: Dictionary = {}

		# Try to get hero data and effective stats from GameContext
		var hero_data = GameContext.get_hero(hero_id) if GameContext.has_method("get_hero") else {}
		if not hero_data.is_empty():
			class_id = hero_data.get("class_id", "defender")
			# Get level-scaled + race-modified stats
			effective_stats = GameContext.get_hero_effective_stats(hero_id)
			var level = effective_stats.get("level", 1)
			var race_id = effective_stats.get("race_id", "human")
			print("[HeroStats] %s (Lv%d %s %s): HP=%d ATK=%d DEF=%d SPD=%d" % [
				effective_stats.get("name", hero_id), level, race_id, class_id,
				effective_stats.get("health", 0), effective_stats.get("attack", 0),
				effective_stats.get("defense", 0), effective_stats.get("speed", 0)])
		else:
			# Legacy fallback for hardcoded hero_1, hero_2, etc.
			class_id = LEGACY_HERO_CLASS_MAP.get(hero_id, "defender")
			print("[HeroStats] %s (legacy %s): using base class stats" % [hero_id, class_id])

		var hero = CombatUnit.create_hero(hero_id, class_id, i, effective_stats)

		# Health Persistence v1: Apply persisted HP if hero fought before in this dungeon run
		if GameContext.has_method("has_hero_hp") and GameContext.has_hero_hp(hero_id):
			var hp_data = GameContext.get_hero_hp(hero_id)
			hero.current_health = hp_data.get("current", hero.max_health)
			print("[HP] restore_for_combat hero=%s hp=%d/%d (from_persistence)" % [hero_id, hero.current_health, hero.max_health])
		else:
			print("[HP] new_hero_in_run hero=%s hp=%d/%d (first_combat)" % [hero_id, hero.current_health, hero.max_health])

		_player_units.append(hero)
		_all_units.append(hero)

	print("[HeroStats] === End Hero Stats ===\n")

	# Create enemy units
	for i in range(enemy_ids.size()):
		var enemy = CombatUnit.create_monster(enemy_ids[i], i)
		_enemy_units.append(enemy)
		_all_units.append(enemy)

	print("[CombatController] Created %d heroes vs %d enemies" % [
		_player_units.size(), _enemy_units.size()])


# ============================================================================
# M4 CLASS KIT - PASSIVE BEHAVIORS
# ============================================================================

## Apply all passive stat bonuses to player units.
func _apply_all_passives() -> void:
	print("[CombatController] Applying passive bonuses...")
	for unit in _player_units:
		_apply_passives_to_unit(unit)


## Apply passive stat bonuses to a single unit.
func _apply_passives_to_unit(unit: CombatUnit) -> void:
	if unit.passive_a_id != "":
		_apply_single_passive(unit, unit.passive_a_id)
	if unit.passive_b_id != "":
		_apply_single_passive(unit, unit.passive_b_id)


## Apply a single passive effect to a unit.
func _apply_single_passive(unit: CombatUnit, passive_id: String) -> void:
	var passive = DataRegistry.get_passive(passive_id)
	if passive == null:
		push_warning("[CombatController] Passive not found: %s" % passive_id)
		return

	# Handle level-scaled stat bonus (e.g., bulwark_stance)
	if passive.passive_type == "level_scaled_stat_bonus":
		_apply_level_scaled_passive(unit, passive)
		return

	# Skip non-stat-bonus types (on_kill, round_start handled elsewhere)
	if not passive.is_stat_bonus():
		return

	# Check trigger conditions
	if passive.is_conditional():
		if passive.requires_front_row() and not unit.is_front_row():
			print("[CombatController] %s: %s requires front row (unit in row %d)" % [
				unit.display_name, passive.display_name, unit.grid_y])
			return

	# Apply stat bonus
	var stat = passive.get_bonus_stat()
	var bonus = passive.get_bonus_value()

	match stat:
		"health":
			unit.max_health += bonus
			unit.current_health += bonus
			print("[CombatController] %s: +%d HP from %s" % [unit.display_name, bonus, passive.display_name])
		"attack":
			unit.attack += bonus
			print("[CombatController] %s: +%d ATK from %s" % [unit.display_name, bonus, passive.display_name])
		"defense":
			unit.defense += bonus
			print("[CombatController] %s: +%d DEF from %s" % [unit.display_name, bonus, passive.display_name])
		"speed":
			unit.speed += bonus
			print("[CombatController] %s: +%d SPD from %s" % [unit.display_name, bonus, passive.display_name])

	passive_triggered.emit(unit, passive_id, "+%d %s" % [bonus, stat.to_upper()])


## Apply a level-scaled stat bonus passive (e.g., bulwark_stance).
## Formula: bonus = base_bonus + level
func _apply_level_scaled_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var stat = passive.get_bonus_stat()
	var base_bonus = passive.get_bonus_value()
	var level = unit.hero_level
	var scaled_bonus = base_bonus + level

	var before_val: int = 0
	var after_val: int = 0

	match stat:
		"defense":
			before_val = unit.defense
			unit.defense += scaled_bonus
			after_val = unit.defense
		"attack":
			before_val = unit.attack
			unit.attack += scaled_bonus
			after_val = unit.attack
		"health":
			before_val = unit.max_health
			unit.max_health += scaled_bonus
			unit.current_health += scaled_bonus
			after_val = unit.max_health
		"speed":
			before_val = unit.speed
			unit.speed += scaled_bonus
			after_val = unit.speed

	print("[Passive] %s hero=%s name=%s level=%d %s_before=%d %s_after=%d" % [
		passive.passive_id, unit.source_id, unit.display_name, level,
		stat, before_val, stat, after_val])
	passive_triggered.emit(unit, passive.passive_id, "+%d %s (level-scaled)" % [scaled_bonus, stat.to_upper()])


# ============================================================================
# RACE PASSIVES
# ============================================================================

## Apply race passives to all player units at combat start.
## Race passives are applied AFTER class passives and BEFORE equipment bonuses.
func _apply_race_passives() -> void:
	print("[CombatController] Applying race passives...")
	for unit in _player_units:
		_apply_race_passive_to_unit(unit)


## Apply race passive to a single player unit.
func _apply_race_passive_to_unit(unit: CombatUnit) -> void:
	if unit.race_id == "":
		return

	var race_data = DataRegistry.get_race(unit.race_id)
	if race_data == null:
		return

	var passive_id = race_data.racial_passive_id
	if passive_id == "":
		return

	var passive = DataRegistry.get_passive(passive_id)
	if passive == null:
		push_warning("[RacePassive] Passive not found: %s for race %s" % [passive_id, unit.race_id])
		return

	# Handle race_multi_stat_bonus type (human, dwarf)
	if passive.passive_type == "race_multi_stat_bonus":
		_apply_race_multi_stat_passive(unit, passive)
		return

	# Handle simple stat_bonus type (elf)
	if passive.passive_type == "stat_bonus":
		_apply_race_stat_bonus_passive(unit, passive)
		return


## Apply race multi-stat bonus passive (human_adaptability, dwarf_deep_miner).
func _apply_race_multi_stat_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var level = unit.hero_level
	var changes: Array[String] = []
	var before_stats = {
		"health": unit.max_health,
		"attack": unit.attack,
		"defense": unit.defense,
		"speed": unit.speed
	}

	# Apply flat stat bonuses
	if passive.effect.has("attack"):
		var bonus = int(passive.effect.get("attack", 0))
		if bonus != 0:
			unit.attack += bonus
			changes.append("+%d ATK" % bonus)

	if passive.effect.has("defense"):
		var bonus = int(passive.effect.get("defense", 0))
		if bonus != 0:
			unit.defense += bonus
			changes.append("+%d DEF" % bonus)

	if passive.effect.has("health"):
		var bonus = int(passive.effect.get("health", 0))
		if bonus != 0:
			unit.max_health += bonus
			unit.current_health += bonus
			changes.append("+%d HP" % bonus)

	if passive.effect.has("speed"):
		var bonus = int(passive.effect.get("speed", 0))
		if bonus != 0:
			unit.speed += bonus
			changes.append("+%d SPD" % bonus)

	# Apply conditional speed bonus at level threshold (human_adaptability)
	if passive.effect.has("speed_at_level"):
		var speed_data = passive.effect.get("speed_at_level", {})
		var min_level = int(speed_data.get("min_level", 99))
		var spd_bonus = int(speed_data.get("bonus", 0))
		if level >= min_level and spd_bonus != 0:
			unit.speed += spd_bonus
			changes.append("+%d SPD (Lv%d+)" % [spd_bonus, min_level])

	# Apply level-scaled health bonus (dwarf_deep_miner)
	if passive.effect.has("health_scaled"):
		var hp_data = passive.effect.get("health_scaled", {})
		var base_hp = int(hp_data.get("base", 0))
		var per_level = int(hp_data.get("per_level", 0))
		var hp_bonus = base_hp + (per_level * level)
		if hp_bonus > 0:
			unit.max_health += hp_bonus
			unit.current_health += hp_bonus
			changes.append("+%d HP (scaled)" % hp_bonus)

	var after_stats = {
		"health": unit.max_health,
		"attack": unit.attack,
		"defense": unit.defense,
		"speed": unit.speed
	}

	if changes.size() > 0:
		print("[RacePassive] id=%s hero=%s name=%s race=%s level=%d before={HP:%d ATK:%d DEF:%d SPD:%d} after={HP:%d ATK:%d DEF:%d SPD:%d}" % [
			passive.passive_id, unit.source_id, unit.display_name, unit.race_id, level,
			before_stats["health"], before_stats["attack"], before_stats["defense"], before_stats["speed"],
			after_stats["health"], after_stats["attack"], after_stats["defense"], after_stats["speed"]])
		passive_triggered.emit(unit, passive.passive_id, ", ".join(changes))


## Apply simple race stat bonus passive (elf_keen_sight).
func _apply_race_stat_bonus_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var stat = passive.get_bonus_stat()
	var bonus = passive.get_bonus_value()
	var level = unit.hero_level

	var before_val: int = 0
	var after_val: int = 0

	match stat:
		"health":
			before_val = unit.max_health
			unit.max_health += bonus
			unit.current_health += bonus
			after_val = unit.max_health
		"attack":
			before_val = unit.attack
			unit.attack += bonus
			after_val = unit.attack
		"defense":
			before_val = unit.defense
			unit.defense += bonus
			after_val = unit.defense
		"speed":
			before_val = unit.speed
			unit.speed += bonus
			after_val = unit.speed

	print("[RacePassive] id=%s hero=%s name=%s race=%s level=%d before={%s:%d} after={%s:%d}" % [
		passive.passive_id, unit.source_id, unit.display_name, unit.race_id, level,
		stat, before_val, stat, after_val])
	passive_triggered.emit(unit, passive.passive_id, "+%d %s" % [bonus, stat.to_upper()])


## Apply round-start passives (e.g., verdant_renewal).
## Called at the beginning of each round (after round 1).
func _apply_round_start_passives() -> void:
	for unit in _player_units:
		if not unit.is_alive:
			continue
		for passive_id in [unit.passive_a_id, unit.passive_b_id]:
			if passive_id == "":
				continue
			var passive = DataRegistry.get_passive(passive_id)
			if passive == null:
				continue
			if passive.passive_type == "round_start_heal":
				_apply_verdant_renewal(unit, passive)


## Apply verdant_renewal: heal lowest HP% ally by (3 + level).
func _apply_verdant_renewal(healer: CombatUnit, passive: PassiveData) -> void:
	# Find lowest HP% ally (including self)
	var lowest_unit: CombatUnit = null
	var lowest_hp_pct: float = 2.0  # > 100%

	for ally in _player_units:
		if not ally.is_alive:
			continue
		var hp_pct = float(ally.current_health) / float(ally.max_health)
		if hp_pct < lowest_hp_pct:
			lowest_hp_pct = hp_pct
			lowest_unit = ally

	if lowest_unit == null:
		return

	# Calculate heal amount: base_bonus (3) + level
	var base_heal = passive.get_bonus_value()  # Should be 3
	var level = healer.hero_level
	var heal_amount = base_heal + level

	var hp_before = lowest_unit.current_health
	var actual_heal = lowest_unit.heal(heal_amount)
	var hp_after = lowest_unit.current_health

	if actual_heal > 0:
		print("[Passive] %s healer=%s level=%d target=%s hp_before=%d hp_after=%d" % [
			passive.passive_id, healer.source_id, level, lowest_unit.source_id, hp_before, hp_after])
		passive_triggered.emit(healer, passive.passive_id, "Healed %s +%d HP" % [lowest_unit.display_name, actual_heal])


# ============================================================================
# EQUIPMENT STAT BONUSES
# ============================================================================

## Apply equipment stat bonuses to all player units.
## Equipment is shared across the party (all heroes benefit from equipped items).
func _apply_equipment_bonuses() -> void:
	var weapon_id = GameContext.get_equipped_weapon()
	var offhand_id = GameContext.get_equipped_offhand()

	if weapon_id == "" and offhand_id == "":
		print("[CombatController] No equipment equipped")
		return

	print("[CombatController] Applying equipment bonuses...")

	# Get item templates
	var weapon_template = DataRegistry.get_item_template(weapon_id) if weapon_id != "" else null
	var offhand_template = DataRegistry.get_item_template(offhand_id) if offhand_id != "" else null

	# Apply to all player units
	for unit in _player_units:
		if weapon_template != null:
			_apply_item_stats(unit, weapon_template, "weapon")
		if offhand_template != null:
			_apply_item_stats(unit, offhand_template, "offhand")


## Apply stats from a single item template to a unit.
func _apply_item_stats(unit: CombatUnit, template: ItemTemplate, slot: String) -> void:
	var stats = template.base_stats
	var changes: Array[String] = []

	var atk_bonus = stats.get("attack", 0)
	if atk_bonus > 0:
		unit.attack += atk_bonus
		changes.append("+%d ATK" % atk_bonus)

	var def_bonus = stats.get("defense", 0)
	if def_bonus > 0:
		unit.defense += def_bonus
		changes.append("+%d DEF" % def_bonus)

	var spd_bonus = stats.get("speed", 0)
	if spd_bonus > 0:
		unit.speed += spd_bonus
		changes.append("+%d SPD" % spd_bonus)

	if changes.size() > 0:
		print("[CombatController] %s: %s from %s (%s)" % [
			unit.display_name, ", ".join(changes), template.display_name, slot])


# ============================================================================
# COMBAT MODIFIER APPLICATION
# ============================================================================

## Apply speed bonuses from combat modifier (call BEFORE TurnQueue initialization).
func _apply_combat_modifier_speeds(modifier: Dictionary) -> void:
	if modifier.is_empty():
		return

	print("[CombatMod] Consumed modifier: %s" % str(modifier))

	# Apply player speed bonus
	var player_spd_bonus = modifier.get("player_spd_bonus", 0)
	if player_spd_bonus != 0:
		for unit in _player_units:
			unit.speed += player_spd_bonus
			print("[CombatMod] %s SPD: %d -> %d (+%d)" % [
				unit.display_name, unit.speed - player_spd_bonus, unit.speed, player_spd_bonus])
		print("[CombatMod] Applied player_spd_bonus=%d to %d heroes" % [player_spd_bonus, _player_units.size()])

	# Apply enemy speed bonus
	var enemy_spd_bonus = modifier.get("enemy_spd_bonus", 0)
	if enemy_spd_bonus != 0:
		for unit in _enemy_units:
			unit.speed += enemy_spd_bonus
			print("[CombatMod] %s SPD: %d -> %d (+%d)" % [
				unit.display_name, unit.speed - enemy_spd_bonus, unit.speed, enemy_spd_bonus])
		print("[CombatMod] Applied enemy_spd_bonus=%d to %d enemies" % [enemy_spd_bonus, _enemy_units.size()])


## Apply non-speed modifier effects (call AFTER units are fully set up).
func _apply_combat_modifier_effects(modifier: Dictionary) -> void:
	if modifier.is_empty():
		return

	# Apply player start damage (damage at combat start, clamp HP to 1 minimum)
	var player_start_damage = modifier.get("player_start_damage", 0)
	if player_start_damage > 0:
		for unit in _player_units:
			# Calculate damage, but clamp so HP never goes below 1
			var max_damage = unit.current_health - 1
			var actual_damage = mini(player_start_damage, max_damage)
			if actual_damage > 0:
				unit.current_health -= actual_damage
				print("[CombatMod] %s takes %d start damage (HP: %d/%d)" % [
					unit.display_name, actual_damage, unit.current_health, unit.max_health])
		print("[CombatMod] Applied player_start_damage=%d to %d heroes (clamped to 1 HP min)" % [
			player_start_damage, _player_units.size()])

	# Apply bonus gold (add directly to dungeon stash)
	var bonus_gold = modifier.get("bonus_gold", 0)
	if bonus_gold > 0:
		GameContext.add_dungeon_gold(bonus_gold)
		print("[CombatMod] Applied bonus_gold=%d to dungeon stash" % bonus_gold)


## Determine which ability a unit should use (priority: Active A > Active B > Weapon > Basic).
func _get_ability_to_use(unit: CombatUnit) -> Dictionary:
	# Priority 1: Class Active A
	if unit.is_ability_a_ready():
		var ability = DataRegistry.get_ability(unit.ability_a_id)
		if ability != null:
			return {"type": "ability_a", "ability": ability}

	# Priority 2: Class Active B
	if unit.is_ability_b_ready():
		var ability = DataRegistry.get_ability(unit.ability_b_id)
		if ability != null:
			return {"type": "ability_b", "ability": ability}

	# Priority 3: Weapon Ability
	if unit.is_weapon_ability_ready():
		return {"type": "weapon", "ability": null}

	# Fallback: Basic Attack
	return {"type": "basic", "ability": null}


## Calculate damage for an ability.
## Uses effective attack (base + buff bonuses) for scaling.
func _calculate_ability_damage(unit: CombatUnit, ability: AbilityData) -> int:
	var base = ability.base_damage
	var scaling = ability.attack_scaling
	var eff_atk = unit.get_effective_attack()
	var total = int(base + (eff_atk * scaling))
	return maxi(1, total)


## Compute internal status duration from designer-specified duration.
## Adds +1 to account for round-start tick timing, ensuring the status
## produces the intended number of ticks/blocks before expiring.
## e.g., duration=2 → internal=3 → ticks 3→2→1→0 (2 meaningful ticks)
func _compute_internal_status_duration(requested_duration: int) -> int:
	return requested_duration + 1


## Apply status effect from an ability.
## For Status Hooks v1 statuses (like "stunned"), uses apply_status_v1().
## For legacy statuses ("stun", "doom"), uses the old StatusRuntime system.
## Status v1.3: Checks for immunity/resist from race trait_tags before applying.
func _apply_ability_status(target: CombatUnit, ability: AbilityData, source: CombatUnit) -> void:
	var status_id = ability.applies_status_id
	var stacks = ability.status_stacks
	var duration = ability.applies_status_duration

	# Legacy statuses bypass v1.3 resist system
	if status_id == "stun":
		if target.apply_stun(stacks, source.unit_id):
			print("  %s is stunned for %d turn(s)!" % [target.display_name, stacks])
		return
	elif status_id == "doom":
		target.apply_doom(stacks, 5, source.unit_id)
		print("  %s is doomed! (+%d stacks)" % [target.display_name, stacks])
		return

	# Status Hooks v1+ statuses: check resist/immunity first (Status v1.3)
	if not target.is_alive:
		return  # Don't apply statuses to dead targets

	var resist_result = target.would_block_status(status_id)

	# Check immunity
	if resist_result["blocked"]:
		print("[Status] blocked unit=%s id=%s reason=%s source=%s" % [
			target.display_name, status_id, resist_result["reason"], ability.ability_id])
		return

	# Apply duration adjustment from resist (clamp minimum to 1)
	var adjusted_duration = duration + resist_result["duration_delta"]
	adjusted_duration = maxi(1, adjusted_duration)

	if resist_result["duration_delta"] != 0:
		print("[Status] resist unit=%s id=%s requested=%d adjusted=%d reason=%s source=%s" % [
			target.display_name, status_id, duration, adjusted_duration, resist_result["reason"], ability.ability_id])

	# Apply status with adjusted duration
	if adjusted_duration > 0:
		var internal_duration = _compute_internal_status_duration(adjusted_duration)
		target.apply_status_v1(status_id, internal_duration, ability.ability_id)
		if resist_result["duration_delta"] == 0:
			print("[Status] applied unit=%s id=%s duration=%d (internal=%d) source=%s" % [
				target.display_name, status_id, adjusted_duration, internal_duration, ability.ability_id])
		status_changed.emit(target.unit_id)  # Status UI v1.6: Notify UI of status change
	else:
		print("  Applied %s to %s" % [status_id, target.display_name])


## Trigger on_kill passives when a unit kills an enemy.
## target_id is the enemy that was killed.
func _trigger_on_kill_passives(killer: CombatUnit, target_id: String = "") -> void:
	if killer.team != CombatUnit.Team.PLAYER:
		return  # Only player units have class passives

	for passive_id in [killer.passive_a_id, killer.passive_b_id]:
		if passive_id == "":
			continue

		var passive = DataRegistry.get_passive(passive_id)
		if passive == null:
			continue

		if not passive.is_on_kill():
			continue

		# Handle killer_instinct: stacking ATK buff on kill
		if passive.passive_type == "on_kill_stacking_buff":
			var level = killer.hero_level
			var atk_per_stack = 1 + int(level / 2)  # (1 + floor(level/2))
			var atk_before = killer.attack
			killer.killer_instinct_stacks += 1
			killer.attack += atk_per_stack
			var atk_after = killer.attack
			print("[Passive] %s hero=%s name=%s level=%d stacks=%d atk_before=%d atk_after=%d target=%s" % [
				passive_id, killer.source_id, killer.display_name, level,
				killer.killer_instinct_stacks, atk_before, atk_after, target_id])
			passive_triggered.emit(killer, passive_id, "+%d ATK (stack %d)" % [atk_per_stack, killer.killer_instinct_stacks])
			continue

		# Legacy: Apply on_kill weapon cooldown reduction
		var cd_reduction = passive.get_weapon_cooldown_reduction()
		if cd_reduction > 0:
			killer.reduce_weapon_cooldown(cd_reduction)
			print("[CombatController] %s: %s triggered! Weapon CD reduced by %d" % [
				killer.display_name, passive.display_name, cd_reduction])
			passive_triggered.emit(killer, passive_id, "Weapon CD -%d" % cd_reduction)


# ============================================================================
# CLEAN API FOR UI (M2.1)
# ============================================================================

## Step exactly one turn. Returns array of CombatActions that occurred.
func step_one_turn() -> Array:
	_pending_actions.clear()

	if not _is_combat_active:
		return _pending_actions

	# Check if round is complete, start new round if needed
	if _turn_queue.is_round_complete():
		_current_round += 1
		_result.total_rounds = _current_round
		# Tick temporary buffs BEFORE rebuilding turn order (speed buffs affect order)
		_tick_all_buffs()
		# Tick status effects AFTER buffs (Status Hooks v1)
		_tick_all_statuses()
		_turn_queue.start_new_round()
		_apply_round_start_passives()  # Trigger round-start passives (e.g., verdant_renewal)
		round_ended.emit(_current_round)

	# Get next unit
	var unit = _turn_queue.get_next_unit()
	if unit == null:
		return _pending_actions

	# Process this unit's turn
	_process_unit_turn_step(unit)

	# Advance queue
	_turn_queue.advance()

	# Check combat end
	_check_combat_end()

	return _pending_actions


## Tick temporary buffs on all units (called at round start).
func _tick_all_buffs() -> void:
	for unit in _all_units:
		if unit.is_alive and unit.has_active_buffs():
			unit.tick_buffs()


## Tick status effects on all units (called at round start, after buffs).
## Status Hooks v1.2.1 - lifecycle ticking with DOT damage handled internally.
func _tick_all_statuses() -> void:
	for unit in _all_units:
		if unit.active_statuses.size() > 0:
			var _expired = unit.tick_statuses()  # Returns Array of expired status IDs
	all_statuses_ticked.emit()  # Status UI v1.6: Notify UI to refresh all badges


## Get snapshot of all units for UI display.
func get_units_snapshot() -> Dictionary:
	var player_data: Array = []
	var enemy_data: Array = []

	for unit in _player_units:
		player_data.append(_unit_to_snapshot(unit))

	for unit in _enemy_units:
		enemy_data.append(_unit_to_snapshot(unit))

	return {
		"player": player_data,
		"enemy": enemy_data
	}


## Convert a unit to a snapshot dictionary.
func _unit_to_snapshot(unit: CombatUnit) -> Dictionary:
	var statuses: Array = []

	if unit.statuses.is_stunned():
		var stun = unit.statuses.get_status("stun")
		statuses.append({
			"id": "stun",
			"duration": stun.duration
		})

	if unit.statuses.has_status("doom"):
		statuses.append({
			"id": "doom",
			"stacks": unit.statuses.get_doom_stacks(),
			"countdown": unit.statuses.get_doom_countdown()
		})

	# Status v1.6: get sorted snapshot of active_statuses for UI badges
	var v1_statuses = unit.get_status_snapshot_sorted()

	# Status UI v1.7: get sorted snapshot of active_buffs for UI badges
	var v1_buffs = unit.get_buff_snapshot_sorted()

	var team_str = "player" if unit.team == CombatUnit.Team.PLAYER else "enemy"

	# Include effective stats (base + buff bonuses) for UI display
	return {
		"id": unit.unit_id,
		"source_id": unit.source_id,
		"class_id": unit.class_id,
		"name": unit.display_name,
		"hp": unit.current_health,
		"max_hp": unit.max_health,
		"speed": unit.get_effective_speed(),
		"attack": unit.get_effective_attack(),
		"defense": unit.get_effective_defense(),
		"base_speed": unit.speed,
		"base_attack": unit.attack,
		"base_defense": unit.defense,
		"weapon_cooldown": unit.weapon_ability_cooldown,
		"weapon_max_cooldown": unit.weapon_ability_max_cooldown,
		"ability_a_cooldown": unit.ability_a_cooldown,
		"ability_b_cooldown": unit.ability_b_cooldown,
		"statuses": statuses,
		"active_statuses_v1": v1_statuses,
		"active_buffs": unit.active_buffs.size(),
		"active_buffs_v1": v1_buffs,  # Status UI v1.7: Buff snapshots for UI
		"is_alive": unit.is_alive,
		"team": team_str,
		"pos": {"x": unit.grid_x, "y": unit.grid_y},
		"team_pos_key": "%s:%d,%d" % [team_str, unit.grid_x, unit.grid_y]
	}


## Get current turn info for UI.
func get_turn_info() -> Dictionary:
	var current_actor = _turn_queue.get_next_unit() if _turn_queue != null else null

	return {
		"round": _current_round,
		"turn": _current_turn,
		"current_actor_id": current_actor.unit_id if current_actor else "",
		"current_actor_name": current_actor.display_name if current_actor else "",
		"current_actor_team": "player" if current_actor and current_actor.team == CombatUnit.Team.PLAYER else "enemy",
		"is_round_complete": _turn_queue.is_round_complete() if _turn_queue else true
	}


## Check if combat is over.
func is_combat_over() -> bool:
	return not _is_combat_active


## Get the combat result (only valid after combat ends).
func get_result() -> CombatResult:
	return _result


## Apply status effect to a unit by ID (for demo/testing).
func apply_status_to_unit(unit_id: String, status_id: String, value: int) -> bool:
	var unit = _find_unit_by_id(unit_id)
	if unit == null:
		return false

	if status_id == "stun":
		unit.apply_stun(value, "demo")
		return true
	elif status_id == "doom":
		unit.apply_doom(value, 5, "demo")
		return true

	return false


func _find_unit_by_id(unit_id: String) -> CombatUnit:
	for unit in _all_units:
		if unit.unit_id == unit_id:
			return unit
	return null


## Status UI v1.6.1: Public accessor for CombatUnit by ID.
## Returns the CombatUnit or null if not found.
func get_unit_by_id(unit_id: String) -> CombatUnit:
	return _find_unit_by_id(unit_id)


## Status UI v1.6.2: Get sorted status snapshot for a specific unit.
## Returns empty Array if unit not found. Used by CombatScene for efficient badge refresh.
func get_unit_status_snapshot_sorted(unit_id: String) -> Array:
	var unit = _find_unit_by_id(unit_id)
	if unit == null:
		return []
	return unit.get_status_snapshot_sorted()


## Status UI v1.7: Get sorted buff snapshot for a specific unit.
## Returns empty Array if unit not found. Used by CombatScene for buff badge refresh.
func get_unit_buff_snapshot_sorted(unit_id: String) -> Array:
	var unit = _find_unit_by_id(unit_id)
	if unit == null:
		return []
	return unit.get_buff_snapshot_sorted()


## v1.9B: Get turn timeline snapshot showing upcoming N units.
## Returns Array of {unit_id, name, team, speed, is_current}.
func get_turn_timeline_snapshot(count: int = 6) -> Array:
	if _turn_queue == null:
		return []
	return _turn_queue.get_upcoming_units_snapshot(count)


# ============================================================================
# COMBAT LOOP (Full auto-run)
# ============================================================================

func _run_combat_loop() -> void:
	while _is_combat_active and _current_round < MAX_ROUNDS:
		_result.total_rounds = _current_round
		print("\n--- ROUND %d ---" % _current_round)

		# Process each unit's turn
		while not _turn_queue.is_round_complete():
			var unit = _turn_queue.get_next_unit()
			if unit == null:
				break

			_process_unit_turn(unit)
			_turn_queue.advance()

			# Check for combat end
			if _check_combat_end():
				return

		round_ended.emit(_current_round)
		_current_round += 1
		# Tick temporary buffs BEFORE rebuilding turn order (speed buffs affect order)
		_tick_all_buffs()
		# Tick status effects AFTER buffs (Status Hooks v1)
		_tick_all_statuses()
		_turn_queue.start_new_round()
		_apply_round_start_passives()  # Trigger round-start passives (e.g., verdant_renewal)

	if _current_round >= MAX_ROUNDS:
		print("[CombatController] Combat ended: MAX ROUNDS reached")


func _process_unit_turn(unit: CombatUnit) -> void:
	_current_turn += 1
	_result.total_turns = _current_turn

	print("\n[Turn %d] %s's turn" % [_current_turn, unit.display_name])
	turn_started.emit(unit)

	# Process turn start - check if stunned (legacy StatusRuntime)
	var can_act = unit.statuses.process_turn_start()

	# Also check Status Hooks v1 "stunned" status
	if can_act and unit.is_action_blocked_by_status():
		can_act = false

	if not can_act:
		var action = CombatAction.create_skip(unit, "Stunned!")
		_result.add_action(action)
		action_performed.emit(action)
		print("  %s is stunned and cannot act!" % unit.display_name)
	else:
		_execute_unit_action(unit)

	# Process turn end
	unit.tick_cooldowns()
	var doom_damage = unit.statuses.process_turn_end()

	if doom_damage > 0:
		var actual_damage = unit.take_damage(doom_damage, "true")
		var doom_action = CombatAction.create_doom_trigger(unit, actual_damage)
		_result.add_action(doom_action)
		action_performed.emit(doom_action)

		if not unit.is_alive:
			var death_action = CombatAction.create_death(unit)
			_result.add_action(death_action)
			action_performed.emit(death_action)

	turn_ended.emit(unit)


## Process unit turn for step-based combat (stores actions in _pending_actions).
func _process_unit_turn_step(unit: CombatUnit) -> void:
	_current_turn += 1
	_result.total_turns = _current_turn

	turn_started.emit(unit)

	# Consumables v1: Auto-use consumable for player heroes at turn start
	if unit.team == CombatUnit.Team.PLAYER:
		_try_auto_use_consumable(unit)

	# Process turn start - check if stunned (legacy StatusRuntime)
	var can_act = unit.statuses.process_turn_start()

	# Also check Status Hooks v1 "stunned" status
	if can_act and unit.is_action_blocked_by_status():
		can_act = false

	if not can_act:
		var action = CombatAction.create_skip(unit, "Stunned!")
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
	else:
		_execute_unit_action_step(unit)

	# Process turn end
	unit.tick_cooldowns()
	var doom_damage = unit.statuses.process_turn_end()

	if doom_damage > 0:
		var actual_damage = unit.take_damage(doom_damage, "true")
		var doom_action = CombatAction.create_doom_trigger(unit, actual_damage)
		_pending_actions.append(doom_action)
		_result.add_action(doom_action)
		action_performed.emit(doom_action)

		if not unit.is_alive:
			var death_action = CombatAction.create_death(unit)
			_pending_actions.append(death_action)
			_result.add_action(death_action)
			action_performed.emit(death_action)

	turn_ended.emit(unit)


func _execute_unit_action(unit: CombatUnit) -> void:
	# Use targeting policy
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		print("  No valid target found")
		return

	# M4: Determine ability to use (priority: Active A > Active B > Weapon > Basic)
	var ability_choice = _get_ability_to_use(unit)
	var ability_type = ability_choice["type"]
	var ability: AbilityData = ability_choice["ability"]

	var raw_damage: int
	var damage_type: String = "physical"
	var is_ability: bool = ability_type != "basic"
	var eff_atk = unit.get_effective_attack()

	if ability != null:
		# Class ability damage (uses effective attack via _calculate_ability_damage)
		raw_damage = _calculate_ability_damage(unit, ability)
		damage_type = ability.damage_type
		print("  %s uses %s!" % [unit.display_name, ability.display_name])
	elif ability_type == "weapon":
		# Weapon ability damage (1.5x effective attack)
		raw_damage = int(eff_atk * 1.5)
	else:
		# Basic attack (uses effective attack)
		raw_damage = eff_atk

	var actual_damage = target.take_damage(raw_damage, damage_type)

	var action = CombatAction.create_attack(unit, target, actual_damage, is_ability)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	match ability_type:
		"ability_a":
			unit.use_ability_a()
		"ability_b":
			unit.use_ability_b()
		"weapon":
			unit.use_weapon_ability()

	# Apply status effect if ability has one
	if ability != null and ability.applies_status_id != "":
		_apply_ability_status(target, ability, unit)

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)  # M4: on_kill passive trigger


func _execute_unit_action_step(unit: CombatUnit) -> void:
	# M4: Determine ability to use (priority: Active A > Active B > Weapon > Basic)
	var ability_choice = _get_ability_to_use(unit)
	var ability_type = ability_choice["type"]
	var ability: AbilityData = ability_choice["ability"]

	# Log AI decision in required format
	var chose_id = ability.ability_id if ability != null else ability_type
	print("[AI] actor=%s chose=%s cdA=%d cdB=%d" % [
		unit.display_name, chose_id, unit.ability_a_cooldown, unit.ability_b_cooldown])

	# Route class abilities to specialized handler
	if ability != null:
		_execute_class_ability_step(unit, ability, ability_type)
		return

	# Use targeting policy for weapon/basic attacks
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		# v1.9B: Emit intent even with no target
		intent_decided.emit(unit.unit_id, ability_type, "", "")
		return

	# v1.9B: Emit intent before execution
	intent_decided.emit(unit.unit_id, ability_type, "", target.unit_id)

	var raw_damage: int
	var is_ability: bool = ability_type != "basic"
	var eff_atk = unit.get_effective_attack()

	if ability_type == "weapon":
		# Weapon ability damage (1.5x effective attack)
		raw_damage = int(eff_atk * 1.5)
	else:
		# Basic attack (uses effective attack)
		raw_damage = eff_atk

	var actual_damage = target.take_damage(raw_damage, "physical")

	var action = CombatAction.create_attack(unit, target, actual_damage, is_ability)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	if ability_type == "weapon":
		unit.use_weapon_ability()

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)


# ============================================================================
# ABILITY TARGETING v1 - Data-driven target selection
# ============================================================================

## Pick a target for an ability based on its targeting data.
## Returns the selected target, or null if no valid target exists.
## Logs: [Target] ability=<id> caster=<name> picked=<target_name|none> team=<ally/enemy/self> rule=<rule> reason=<ok|no_valid_target|fallback_attack>
func _pick_target_for_ability(caster: CombatUnit, ability: AbilityData) -> CombatUnit:
	var target_team = ability.target_team
	var target_rule = ability.target_rule
	var allow_self = ability.allow_self_target

	# Determine candidate pool based on target_team
	var candidates: Array = []

	if target_team == "self":
		# Self-targeting: only the caster
		candidates = [caster] if caster.is_alive else []
	elif target_team == "ally":
		# Ally targeting: same team as caster
		candidates = _player_units if caster.team == CombatUnit.Team.PLAYER else _enemy_units
		candidates = candidates.filter(func(u): return u.is_alive)
		# Remove self unless allowed
		if not allow_self:
			candidates = candidates.filter(func(u): return u != caster)
		# If no allies remain and self is allowed, include self
		if candidates.is_empty() and allow_self and caster.is_alive:
			candidates = [caster]
	elif target_team == "enemy":
		# Enemy targeting: opposite team
		candidates = _enemy_units if caster.team == CombatUnit.Team.PLAYER else _player_units
		candidates = candidates.filter(func(u): return u.is_alive)

	# If no candidates, log and return null
	if candidates.is_empty():
		print("[Target] ability=%s caster=%s picked=none team=%s rule=%s reason=no_valid_target" % [
			ability.ability_id, caster.display_name, target_team, target_rule])
		return null

	# Apply target_rule to select from candidates
	var target: CombatUnit = null

	match target_rule:
		"any":
			# Pick first for determinism
			target = candidates[0]
		"lowest_hp_pct":
			# Pick ally/enemy with lowest HP percentage
			var lowest_pct: float = 2.0
			for c in candidates:
				var pct = float(c.current_health) / float(c.max_health)
				if pct < lowest_pct:
					lowest_pct = pct
					target = c
		"lowest_hp_abs":
			# Pick target with lowest absolute HP
			var lowest_hp: int = 999999
			for c in candidates:
				if c.current_health < lowest_hp:
					lowest_hp = c.current_health
					target = c
		"highest_atk":
			# Pick target with highest attack
			var highest_atk: int = -1
			for c in candidates:
				var atk = c.get_effective_attack()
				if atk > highest_atk:
					highest_atk = atk
					target = c
		"unbuffed":
			# Pick an unbuffed ally (no active_buffs); fallback to lowest_hp_pct if all buffed
			for c in candidates:
				if not c.has_active_buffs():
					target = c
					break
			# Fallback: lowest HP% if all are buffed
			if target == null:
				var lowest_pct: float = 2.0
				for c in candidates:
					var pct = float(c.current_health) / float(c.max_health)
					if pct < lowest_pct:
						lowest_pct = pct
						target = c
		_:
			# Default: pick first
			target = candidates[0]

	# Log target selection
	if target != null:
		print("[Target] ability=%s caster=%s picked=%s team=%s rule=%s reason=ok" % [
			ability.ability_id, caster.display_name, target.display_name, target_team, target_rule])
	else:
		print("[Target] ability=%s caster=%s picked=none team=%s rule=%s reason=no_valid_target" % [
			ability.ability_id, caster.display_name, target_team, target_rule])

	return target


## Attempt to pick a target for ability; fallback to basic attack if needed.
## Returns a dict with "target" and "fallback" keys.
func _pick_target_with_fallback(caster: CombatUnit, ability: AbilityData) -> Dictionary:
	var target = _pick_target_for_ability(caster, ability)

	if target != null:
		return {"target": target, "fallback": false}

	# Fallback logic based on ability type
	# For heal/buff: fallback to self if allow_self_target, else skip ability and use basic attack
	if ability.effect_type in ["heal", "buff"]:
		if ability.allow_self_target and caster.is_alive:
			print("[Target] ability=%s caster=%s picked=%s team=self rule=fallback_self reason=fallback_attack" % [
				ability.ability_id, caster.display_name, caster.display_name])
			return {"target": caster, "fallback": false}
		else:
			# Fall back to basic attack on enemy
			print("[Target] ability=%s caster=%s picked=none team=%s rule=%s reason=fallback_attack" % [
				ability.ability_id, caster.display_name, ability.target_team, ability.target_rule])
			return {"target": null, "fallback": true}

	# For damage: fallback to any alive enemy
	if ability.effect_type == "damage":
		var enemies = _enemy_units if caster.team == CombatUnit.Team.PLAYER else _player_units
		for e in enemies:
			if e.is_alive:
				print("[Target] ability=%s caster=%s picked=%s team=enemy rule=any reason=fallback_attack" % [
					ability.ability_id, caster.display_name, e.display_name])
				return {"target": e, "fallback": false}

	return {"target": null, "fallback": true}


# ============================================================================
# CLASS ABILITY EXECUTION (Ability Execution v1)
# ============================================================================

## Execute a class ability based on its effect_type and target_type.
func _execute_class_ability_step(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	print("[Ability] %s uses %s (effect=%s, target=%s, team=%s, rule=%s)" % [
		unit.display_name, ability.display_name, ability.effect_type, ability.target_type,
		ability.target_team, ability.target_rule])

	# v1.9B: Pre-determine target for intent signal
	var intent_target_id = ""
	if ability.effect_type == "damage":
		var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
		var intent_target = _targeting_policy.select_target(unit, enemies)
		if intent_target != null:
			intent_target_id = intent_target.unit_id
	elif ability.effect_type in ["heal", "buff"]:
		var pick_result = _pick_target_for_ability(unit, ability)
		if pick_result != null:
			intent_target_id = pick_result.unit_id
	intent_decided.emit(unit.unit_id, "class_ability", ability.ability_id, intent_target_id)

	# Route based on effect_type
	match ability.effect_type:
		"damage":
			_execute_damage_ability(unit, ability, ability_type)
		"heal":
			_execute_heal_ability(unit, ability, ability_type)
		"buff":
			_execute_buff_ability(unit, ability, ability_type)
		_:
			# Fallback: treat as damage ability
			_execute_damage_ability(unit, ability, ability_type)


## Execute a damage-type ability (guardian_challenge, aegis_slam, twin_strike).
func _execute_damage_ability(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	# Get enemy target
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		return

	# Handle multi-hit abilities (twin_strike)
	var hits = ability.hit_count if ability.hit_count > 0 else 1
	var total_damage = 0
	var hits_landed = 0

	for i in range(hits):
		# Check if target died mid-combo (skip remaining hits)
		if not target.is_alive:
			# Log skipped hits
			for j in range(i, hits):
				print("[Ability] %s caster=%s target=%s dmg=0 hit=%d/%d (skipped - target dead)" % [
					ability.ability_id, unit.display_name, target.display_name, j + 1, hits])
			break

		var raw_damage = _calculate_ability_damage(unit, ability)
		var actual_damage = target.take_damage(raw_damage, ability.damage_type)
		total_damage += actual_damage
		hits_landed += 1

		# Log in required format
		print("[Ability] %s caster=%s target=%s dmg=%d hit=%d/%d" % [
			ability.ability_id, unit.display_name, target.display_name, actual_damage, i + 1, hits])

	# Create action for UI
	var action = CombatAction.create_ability_attack(unit, target, ability.ability_id, ability.display_name, total_damage)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown and log
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])

	# Apply status effect if ability has one
	if ability.applies_status_id != "":
		_apply_ability_status(target, ability, unit)

	# Handle death
	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)


## Execute a heal-type ability (natures_grace).
## Uses data-driven targeting via _pick_target_for_ability().
func _execute_heal_ability(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	# Use data-driven targeting (Ability Targeting v1)
	var pick_result = _pick_target_with_fallback(unit, ability)
	var target = pick_result["target"]

	# If fallback to basic attack (no valid heal target)
	if pick_result["fallback"]:
		_execute_basic_attack_fallback(unit)
		return

	if target == null:
		return

	# Calculate heal amount
	var hp_before = target.current_health
	var heal_amount = ability.base_heal
	var actual_heal = target.heal(heal_amount)
	var hp_after = target.current_health

	# Log in required format
	print("[Ability] %s caster=%s target=%s heal=%d hp_before=%d hp_after=%d" % [
		ability.ability_id, unit.display_name, target.display_name, actual_heal, hp_before, hp_after])

	# Create action for UI
	var action = CombatAction.create_heal(unit, target, ability.ability_id, ability.display_name, actual_heal)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown and log
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Execute a buff-type ability (shadowstep, barkskin_blessing).
## Buffs are tracked with duration and expire automatically at round start.
## Uses data-driven targeting via _pick_target_for_ability().
func _execute_buff_ability(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	# Use data-driven targeting (Ability Targeting v1)
	var pick_result = _pick_target_with_fallback(unit, ability)
	var target = pick_result["target"]

	# If fallback to basic attack (no valid buff target)
	if pick_result["fallback"]:
		_execute_basic_attack_fallback(unit)
		return

	if target == null:
		return

	# Apply buff using tracking system (duration-based expiry)
	var duration = ability.buff_duration if ability.buff_duration > 0 else 99  # 0 = permanent for combat
	target.apply_buff(ability.ability_id, ability.buff_stats, duration)

	# Log in required format
	print("[Ability] %s caster=%s target=%s buff=%s duration=%d" % [
		ability.ability_id, unit.display_name, target.display_name,
		JSON.stringify(ability.buff_stats), duration])

	# Build description for UI action
	var buff_desc_parts: Array[String] = []
	if ability.buff_stats.has("attack"):
		buff_desc_parts.append("+%d ATK" % int(ability.buff_stats.get("attack", 0)))
	if ability.buff_stats.has("defense"):
		buff_desc_parts.append("+%d DEF" % int(ability.buff_stats.get("defense", 0)))
	if ability.buff_stats.has("speed"):
		buff_desc_parts.append("+%d SPD" % int(ability.buff_stats.get("speed", 0)))
	if ability.buff_stats.has("health"):
		buff_desc_parts.append("+%d HP" % int(ability.buff_stats.get("health", 0)))

	var buff_desc = ", ".join(buff_desc_parts)
	if ability.buff_duration > 0:
		buff_desc += " for %d rounds" % ability.buff_duration

	# Create action for UI
	var action = CombatAction.create_buff(unit, target, ability.ability_id, ability.display_name, buff_desc)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown and log
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Find the lowest HP% ally (including caster).
func _find_lowest_hp_ally(caster: CombatUnit) -> CombatUnit:
	var allies = _player_units if caster.team == CombatUnit.Team.PLAYER else _enemy_units
	var lowest_unit: CombatUnit = null
	var lowest_hp_pct: float = 2.0  # > 100%

	for ally in allies:
		if not ally.is_alive:
			continue
		var hp_pct = float(ally.current_health) / float(ally.max_health)
		if hp_pct < lowest_hp_pct:
			lowest_hp_pct = hp_pct
			lowest_unit = ally

	return lowest_unit


## Put the used ability on cooldown.
func _put_ability_on_cooldown(unit: CombatUnit, ability_type: String) -> void:
	match ability_type:
		"ability_a":
			unit.use_ability_a()
		"ability_b":
			unit.use_ability_b()


## Execute a basic attack as fallback when ability targeting fails.
## Used when heal/buff has no valid target and allow_self_target is false.
func _execute_basic_attack_fallback(unit: CombatUnit) -> void:
	var enemies = _enemy_units if unit.team == CombatUnit.Team.PLAYER else _player_units
	var target: CombatUnit = null

	for e in enemies:
		if e.is_alive:
			target = e
			break

	if target == null:
		print("[Combat] %s has no valid attack target (fallback failed)" % unit.display_name)
		return

	var eff_atk = unit.get_effective_attack()
	var actual_damage = target.take_damage(eff_atk, "physical")

	var action = CombatAction.create_attack(unit, target, actual_damage, false)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	print("[Combat] %s performs basic attack (fallback) on %s for %d damage" % [
		unit.display_name, target.display_name, actual_damage])

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)


func _check_combat_end() -> bool:
	if _turn_queue.is_team_wiped(CombatUnit.Team.ENEMY):
		print("\n[CombatController] All enemies defeated!")
		_is_combat_active = false
		_result.set_outcome_from_combat(_player_units, _enemy_units)
		_result.set_rng(_rng)
		# Set context for loot bias (look up dungeon from town)
		var ctx = { "region_id": GameContext.get_current_region_id() }
		var town = DataRegistry.get_town(GameContext.get_current_town_id())
		if town != null:
			ctx["dungeon_id"] = town.dungeon_id
		_result.set_context(ctx)
		_result.is_boss_encounter = _encounter_is_boss
		_result.calculate_rewards(_enemy_units)
		# Apply rewards to run stash (guarded against double-add)
		if not _result._stash_applied:
			_result._stash_applied = true
			GameContext.add_rewards(_result.gold_earned, _result.items_dropped)
			# Apply dungeon floor bonus using SNAPSHOT values (not mutable GameContext state)
			GameContext.apply_dungeon_floor_reward_snapshot(
				_encounter_dungeon_id,
				_encounter_floor,
				_encounter_floor_count,
				_encounter_is_boss,
				_encounter_boss_id,
				_rng
			)
			print("[RunStash] Gold=%d Items=%d" % [GameContext.run_gold, GameContext.run_items.size()])
		# Health Persistence v1: Save surviving heroes' HP
		_persist_hero_hp()
		combat_ended.emit(_result)
		return true

	if _turn_queue.is_team_wiped(CombatUnit.Team.PLAYER):
		print("\n[CombatController] All heroes defeated!")
		_is_combat_active = false
		_result.set_outcome_from_combat(_player_units, _enemy_units)
		# Health Persistence v1: Save surviving heroes' HP (even on defeat, for dead heroes)
		_persist_hero_hp()
		combat_ended.emit(_result)
		return true

	return false


## Health Persistence v1: Save all player unit HP to GameContext.
## Uses source_id (actual hero_id like "hero_warrior_1") for consistent key.
func _persist_hero_hp() -> void:
	for unit in _player_units:
		if GameContext.has_method("set_hero_hp"):
			# Use source_id (actual hero_id) not unit_id (combat index)
			var hero_id = unit.source_id if unit.source_id != "" else unit.unit_id
			GameContext.set_hero_hp(hero_id, unit.current_health, unit.max_health)
			print("[HP] persist_after_combat hero=%s hp=%d/%d" % [hero_id, unit.current_health, unit.max_health])


# ============================================================================
# CONSUMABLES v1 - AUTO USE
# ============================================================================

## Try to auto-use a consumable for a player hero at turn start.
## Rules:
## - Each hero can use 1 consumable per combat
## - HP <= 50%: use healing consumable
## - Has DOT status: use cleanse consumable
## - Has stunned: use stun removal (if available)
func _try_auto_use_consumable(unit: CombatUnit) -> void:
	var hero_id = unit.unit_id

	# Check if this hero has already used a consumable this combat
	if not GameContext.can_hero_use_consumable(hero_id):
		return

	# Check HP ratio - if <= 50%, look for healing
	var hp_ratio = float(unit.current_health) / float(unit.max_health)
	if hp_ratio <= 0.5:
		var heal_info = GameContext.find_healing_consumable()
		if not heal_info.is_empty():
			_use_healing_consumable(unit, heal_info)
			return

	# Check for DOT statuses (poisoned, bleeding)
	if _unit_has_dot_status(unit):
		var cleanse_info = GameContext.find_cleanse_consumable("dot")
		if not cleanse_info.is_empty():
			_use_cleanse_consumable(unit, cleanse_info, "dot")
			return

	# Check for stunned status
	if unit.is_action_blocked_by_status():
		var stun_info = GameContext.find_cleanse_consumable("stun")
		if not stun_info.is_empty():
			_use_cleanse_consumable(unit, stun_info, "stun")
			return


## Check if unit has a DOT status (poisoned or bleeding).
func _unit_has_dot_status(unit: CombatUnit) -> bool:
	for status in unit.active_statuses:
		var status_id = status.get("id", "")
		if status_id in ["poisoned", "bleeding"]:
			return true
	return false


## Use a healing consumable on a unit.
func _use_healing_consumable(unit: CombatUnit, heal_info: Dictionary) -> void:
	var item_id = heal_info.get("item_id", "")
	var heal_amount = heal_info.get("use_value", 12)  # Default 12 for heal_small
	var source = heal_info.get("source", "dungeon")

	var hp_before = unit.current_health
	var actual_heal = unit.heal(heal_amount)
	var hp_after = unit.current_health

	# Consume item from stash
	GameContext.consume_stash_item(item_id, source)
	GameContext.mark_consumable_used(unit.unit_id)

	print("[Consumable] use unit=%s hero=%s item=%s effect=heal hp_before=%d hp_after=%d removed_statuses=[]" % [
		unit.display_name, unit.unit_id, item_id, hp_before, hp_after])

	# Create action for UI (using ITEM_USE type for consumables)
	var action = CombatAction.new()
	action.action_type = CombatAction.ActionType.ITEM_USE
	action.actor_id = unit.unit_id
	action.actor_name = unit.display_name
	action.target_id = unit.unit_id
	action.target_name = unit.display_name
	action.healing_done = actual_heal
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)


## Use a cleanse consumable to remove status effects.
func _use_cleanse_consumable(unit: CombatUnit, cleanse_info: Dictionary, effect_type: String) -> void:
	var item_id = cleanse_info.get("item_id", "")
	var use_effect = cleanse_info.get("use_effect", "")
	var source = cleanse_info.get("source", "dungeon")

	var hp_before = unit.current_health
	var removed_statuses: Array = []

	# Remove appropriate statuses
	if effect_type == "dot":
		removed_statuses = _remove_dot_statuses(unit)
	elif effect_type == "stun":
		removed_statuses = _remove_stun_status(unit)

	# Consume item from stash
	GameContext.consume_stash_item(item_id, source)
	GameContext.mark_consumable_used(unit.unit_id)

	print("[Consumable] use unit=%s hero=%s item=%s effect=%s hp_before=%d hp_after=%d removed_statuses=%s" % [
		unit.display_name, unit.unit_id, item_id, use_effect, hp_before, unit.current_health, str(removed_statuses)])

	# Create action for UI (using SKIP type with descriptive reason)
	var action = CombatAction.create_skip(unit, "Used " + item_id.replace("_", " ").capitalize())
	action.status_applied = "cleanse"  # Signal to UI
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)


## Remove DOT statuses from unit.
func _remove_dot_statuses(unit: CombatUnit) -> Array:
	var removed: Array = []
	var i = 0
	while i < unit.active_statuses.size():
		var status = unit.active_statuses[i]
		var status_id = status.get("id", "")
		if status_id in ["poisoned", "bleeding"]:
			removed.append(status_id)
			unit.active_statuses.remove_at(i)
		else:
			i += 1
	return removed


## Remove stun status from unit.
func _remove_stun_status(unit: CombatUnit) -> Array:
	var removed: Array = []
	var i = 0
	while i < unit.active_statuses.size():
		var status = unit.active_statuses[i]
		var status_id = status.get("id", "")
		if status_id == "stunned":
			removed.append(status_id)
			unit.active_statuses.remove_at(i)
		else:
			i += 1
	return removed


# ============================================================================
# PUBLIC API - TEST BATTLE
# ============================================================================

func start_test_battle() -> CombatResult:
	print("[CombatController] Starting test battle...")
	var seed_val = GameContext.get_run_seed() if GameContext.get_run_seed() > 0 else 12345
	var rng = SeededRNG.create_rng(seed_val)
	var heroes = ["hero_1", "hero_2", "hero_3"]
	var enemies = ["goblin", "goblin"]
	return start_combat(heroes, enemies, rng)


# ============================================================================
# SMOKE TEST
# ============================================================================

func run_smoke_test() -> bool:
	print("\n" + "=".repeat(60))
	print("    CombatController M4 SMOKE TEST (Class Kit Integration)")
	print("=".repeat(60) + "\n")

	var passed = true
	var total_checks = 0
	var passed_checks = 0

	var test_seed = 12345
	var rng = SeededRNG.create_rng(test_seed)

	# Check 1: Initialize combat
	print("--- Check 1: Initialize Combat ---")
	total_checks += 1
	initialize_combat(["hero_1", "hero_2"], ["goblin", "goblin"], rng)
	if _is_combat_active and _player_units.size() == 2 and _enemy_units.size() == 2:
		print("[PASS] Combat initialized: 2v2")
		passed_checks += 1
	else:
		print("[FAIL] Combat not initialized correctly")
		passed = false

	# Check 2: Hero class mapping
	print("\n--- Check 2: Hero Class Mapping ---")
	total_checks += 1
	var hero1_class = _player_units[0].display_name
	var hero2_class = _player_units[1].display_name
	if hero1_class == "Defender" and hero2_class == "Striker":
		print("[PASS] Hero classes: %s, %s" % [hero1_class, hero2_class])
		passed_checks += 1
	else:
		print("[FAIL] Expected Defender/Striker, got %s/%s" % [hero1_class, hero2_class])
		passed = false

	# Check 3: Formation assignment - no overlap within each team (M3.1)
	print("\n--- Check 3: Formation - Per-Team No Overlap ---")
	total_checks += 1
	if FormationAssigner.validate_no_overlap_per_team(_player_units, _enemy_units):
		print("[PASS] No overlap within each team formation")
		passed_checks += 1
	else:
		print("[FAIL] Position overlap detected within a team")
		passed = false

	# Check 4: Separate grids - player(0,0) and enemy(0,0) both allowed (M3.1)
	print("\n--- Check 4: Separate Grids - Same Coords OK ---")
	total_checks += 1
	var player_pos = _player_units[0].get_team_pos_key()
	var enemy_pos = _enemy_units[0].get_team_pos_key()
	# Both should be at (0,0) on their respective grids
	if player_pos == "player:0,0" and enemy_pos == "enemy:0,0":
		print("[PASS] player(0,0) and enemy(0,0) coexist on separate grids")
		passed_checks += 1
	else:
		print("[FAIL] Expected player:0,0 and enemy:0,0, got %s and %s" % [player_pos, enemy_pos])
		passed = false

	# Check 5: All units positioned with team_pos_key
	print("\n--- Check 5: All Units Positioned ---")
	total_checks += 1
	var all_positioned = true
	for unit in _all_units:
		if not unit.has_position():
			all_positioned = false
			break
	if all_positioned:
		print("[PASS] All units have grid positions")
		for unit in _player_units:
			print("  %s" % unit.get_team_pos_key())
		for unit in _enemy_units:
			print("  %s" % unit.get_team_pos_key())
		passed_checks += 1
	else:
		print("[FAIL] Some units missing positions")
		passed = false

	# Check 6: Snapshot includes team_pos_key
	print("\n--- Check 6: Snapshot Has team_pos_key ---")
	total_checks += 1
	var snapshot = get_units_snapshot()
	var has_key = snapshot["player"][0].has("team_pos_key") and snapshot["enemy"][0].has("team_pos_key")
	if has_key:
		print("[PASS] Snapshot has team_pos_key: %s" % snapshot["player"][0]["team_pos_key"])
		passed_checks += 1
	else:
		print("[FAIL] Snapshot missing team_pos_key")
		passed = false

	# Check 7: Melee cannot target back row if front row alive
	print("\n--- Check 7: Melee Blocked by Front Row ---")
	total_checks += 1
	# Set up: 3 enemies, 2 front, 1 back
	# Reset for clean test
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1"], ["goblin", "goblin", "goblin"], rng)
	# Hero 1 has sword = melee
	# Manually position enemies: 2 front, 1 back
	_enemy_units[0].set_position(0, 0)  # front
	_enemy_units[1].set_position(1, 0)  # front
	_enemy_units[2].set_position(0, 1)  # back
	# Make back row enemy lowest HP
	_enemy_units[2].current_health = 1

	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, CombatUnit.Team.PLAYER)
	var melee_target = _targeting_policy.select_target(_player_units[0], enemies)
	# Melee should NOT target back row enemy despite lowest HP
	if melee_target != _enemy_units[2]:
		print("[PASS] Melee attacker cannot target back row (front row blocks)")
		passed_checks += 1
	else:
		print("[FAIL] Melee attacker incorrectly targeted back row")
		passed = false

	# Check 8: Melee can target back row if front row empty
	print("\n--- Check 8: Melee Can Target Back Row (Front Empty) ---")
	total_checks += 1
	# Kill front row units
	_enemy_units[0].is_alive = false
	_enemy_units[1].is_alive = false
	enemies = TargetingPolicy.get_enemies_for_team(_all_units, CombatUnit.Team.PLAYER)
	melee_target = _targeting_policy.select_target(_player_units[0], enemies)
	if melee_target == _enemy_units[2]:
		print("[PASS] Melee attacker can target back row when front empty")
		passed_checks += 1
	else:
		print("[FAIL] Melee attacker could not target back row")
		passed = false

	# Check 9: Ranged can target back row even if front row alive
	print("\n--- Check 9: Ranged Can Target Back Row ---")
	total_checks += 1
	# Reset and use ranged attacker
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1"], ["goblin", "goblin", "goblin"], rng)
	# Make hero ranged by clearing weapon ability id (no sword = ranged)
	_player_units[0].weapon_ability_id = "bow_shot"  # Not sword = ranged
	# Position enemies
	_enemy_units[0].set_position(0, 0)  # front
	_enemy_units[1].set_position(1, 0)  # front
	_enemy_units[2].set_position(0, 1)  # back
	# Make back row enemy lowest HP
	_enemy_units[2].current_health = 1

	enemies = TargetingPolicy.get_enemies_for_team(_all_units, CombatUnit.Team.PLAYER)
	var ranged_target = _targeting_policy.select_target(_player_units[0], enemies)
	if ranged_target == _enemy_units[2]:
		print("[PASS] Ranged attacker can target back row (lowest HP)")
		passed_checks += 1
	else:
		print("[FAIL] Ranged attacker did not target lowest HP back row")
		passed = false

	# Check 10: Step and complete combat
	print("\n--- Check 10: Combat Runs to Completion ---")
	total_checks += 1
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1", "hero_2"], ["goblin", "goblin"], rng)
	var step_count = 0
	while not is_combat_over() and step_count < 50:
		step_one_turn()
		step_count += 1

	if is_combat_over():
		print("[PASS] Combat completed in %d steps" % step_count)
		passed_checks += 1
	else:
		print("[FAIL] Combat did not complete")
		passed = false

	# ========================================
	# M4 CLASS KIT CHECKS
	# ========================================

	# Check 11: Class kit loaded (passives and abilities)
	print("\n--- Check 11: M4 Class Kit Loaded ---")
	total_checks += 1
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1", "hero_2"], ["goblin"], rng)
	var defender = _player_units[0]
	var striker = _player_units[1]

	var kit_loaded = (
		defender.passive_a_id == "def_iron_skin" and
		defender.passive_b_id == "def_front_line_bonus" and
		defender.ability_a_id == "def_shield_bash" and
		striker.passive_a_id == "str_killer_instinct" and
		striker.ability_a_id == "str_precise_strike"
	)
	if kit_loaded:
		print("[PASS] Class kits loaded: Defender passives=[%s, %s], Striker passives=[%s, %s]" % [
			defender.passive_a_id, defender.passive_b_id,
			striker.passive_a_id, striker.passive_b_id])
		passed_checks += 1
	else:
		print("[FAIL] Class kits not loaded correctly")
		passed = false

	# Check 12: Passive stat bonus applied (Defender +2 DEF)
	print("\n--- Check 12: M4 Passive Stat Bonus Applied ---")
	total_checks += 1
	# Defender base DEF from JSON is 15, passive adds +2 = 17
	# Also +10 HP if front row
	var expected_def = 15 + 2  # base + iron_skin
	if defender.defense == expected_def:
		print("[PASS] Defender DEF = %d (base 15 + 2 from Iron Skin)" % defender.defense)
		passed_checks += 1
	else:
		print("[FAIL] Defender DEF = %d, expected %d" % [defender.defense, expected_def])
		passed = false

	# Check 13: Striker passive applied (+2 ATK)
	print("\n--- Check 13: M4 Striker Passive Applied ---")
	total_checks += 1
	# Striker base ATK from JSON is 14, passive adds +2 = 16
	var expected_atk = 14 + 2
	if striker.attack == expected_atk:
		print("[PASS] Striker ATK = %d (base 14 + 2 from Killer Instinct)" % striker.attack)
		passed_checks += 1
	else:
		print("[FAIL] Striker ATK = %d, expected %d" % [striker.attack, expected_atk])
		passed = false

	# Check 14: Ability cooldowns initialized
	print("\n--- Check 14: M4 Ability Cooldowns Initialized ---")
	total_checks += 1
	# Shield Bash has cooldown 4, Fortify has cooldown 3
	var cooldowns_ok = (
		defender.ability_a_max_cooldown == 4 and
		defender.ability_b_max_cooldown == 3 and
		defender.ability_a_cooldown == 0 and  # Should start at 0 (ready)
		striker.ability_a_max_cooldown == 3
	)
	if cooldowns_ok:
		print("[PASS] Ability cooldowns: Defender A=%d/%d, B=%d/%d" % [
			defender.ability_a_cooldown, defender.ability_a_max_cooldown,
			defender.ability_b_cooldown, defender.ability_b_max_cooldown])
		passed_checks += 1
	else:
		print("[FAIL] Ability cooldowns not initialized correctly")
		passed = false

	# Check 15: Front row conditional passive (+10 HP)
	print("\n--- Check 15: M4 Front Row Conditional Passive ---")
	total_checks += 1
	# Defender in front row should get +10 HP from def_front_line_bonus
	# Base HP is 120, +10 = 130
	var expected_hp = 120 + 10
	if defender.is_front_row() and defender.max_health == expected_hp:
		print("[PASS] Defender front row HP = %d (base 120 + 10 from Front Line Bonus)" % defender.max_health)
		passed_checks += 1
	else:
		print("[FAIL] Defender HP = %d (front_row=%s), expected %d" % [defender.max_health, defender.is_front_row(), expected_hp])
		passed = false

	# Final result
	print("\n" + "=".repeat(60))
	if passed:
		print("  M4 SMOKE TEST PASSED (%d/%d checks)" % [passed_checks, total_checks])
	else:
		print("  M4 SMOKE TEST FAILED (%d/%d checks)" % [passed_checks, total_checks])
	print("=".repeat(60) + "\n")

	return passed
